import AppKit
import GitHubAccountSwitcherCore
import Observation
import SwiftUI

@main
struct GitHubAccountSwitcherMenuBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.openSettings) private var openSettings
    @State private var model = MenuBarModel()

    var body: some Scene {
        MenuBarExtra {
            if let error = model.error {
                Text(error)
            }
            ForEach(model.configuredAccounts) { account in
                Button {
                    model.select(account.login)
                } label: {
                    Text("\(account.isActive ? "✓ " : "")\(account.displayName)")
                }
            }
            Divider()
            Button("Settings…") {
                openSettings()
                NSApplication.shared.activate(ignoringOtherApps: true)
            }
            Button("Refresh") { model.reload() }
            Button("Quit") { NSApplication.shared.terminate(nil) }
        } label: {
            Image(nsImage: menuBarImage(for: model.activeAccount?.menuBarAbbreviation ?? "---"))
            .accessibilityLabel(model.activeAccount.map { "Active GitHub account: \($0.displayName)" } ?? "No active GitHub account")
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView(model: model)
        }
    }

    private func menuBarImage(for abbreviation: String) -> NSImage {
        let size = NSSize(width: 34, height: 20)
        let image = NSImage(size: size, flipped: false) { rect in
            let arrow = NSBezierPath()
            arrow.move(to: NSPoint(x: 0, y: rect.midY))
            arrow.line(to: NSPoint(x: 7, y: 18))
            arrow.line(to: NSPoint(x: 7, y: 16))
            arrow.line(to: NSPoint(x: 27, y: 16))
            arrow.line(to: NSPoint(x: 27, y: 18))
            arrow.line(to: NSPoint(x: 34, y: rect.midY))
            arrow.line(to: NSPoint(x: 27, y: 2))
            arrow.line(to: NSPoint(x: 27, y: 4))
            arrow.line(to: NSPoint(x: 7, y: 4))
            arrow.line(to: NSPoint(x: 7, y: 2))
            arrow.close()
            NSColor.black.setFill()
            arrow.fill()

            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 10, weight: .bold),
                .foregroundColor: NSColor.black,
            ]
            let text = abbreviation as NSString
            let textSize = text.size(withAttributes: attributes)
            NSGraphicsContext.current?.compositingOperation = .destinationOut
            text.draw(
                at: NSPoint(
                    x: (rect.width - textSize.width) / 2,
                    y: (rect.height - textSize.height) / 2
                ),
                withAttributes: attributes
            )
            NSGraphicsContext.current?.compositingOperation = .sourceOver
            return true
        }
        image.isTemplate = true
        return image
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
    }
}

@MainActor
@Observable
final class MenuBarModel {
    var accounts: [GitHubAccount] = []
    var error: String?
    var configuredAccounts: [GitHubAccount] { accounts.filter(\.isConfigured) }
    var needsAttention: Bool { configuredAccounts.isEmpty }
    var activeAccount: GitHubAccount? { configuredAccounts.first(where: \.isActive) }

    init() { reload() }

    func reload() {
        do {
            accounts = try AccountService.accounts()
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    func select(_ login: String) {
        do {
            try AccountService.switchAccount(to: login)
            reload()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func link(_ account: GitHubAccount, alias: String) {
        let panel = NSOpenPanel()
        panel.title = "Choose the private key for \(account.login)"
        panel.message = "Choose the key file without .pub — for example, id_ed25519_mobilepur. Do not choose config, known_hosts, or a .pub file."
        panel.prompt = "Link Private Key"
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser.appending(path: ".ssh")
        let panelDelegate = PrivateKeyPanelDelegate()
        panel.delegate = panelDelegate
        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try AccountService.linkSSH(
                login: account.login,
                keyPath: url.path,
                alias: alias.isEmpty ? nil : alias
            )
            reload()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func unlink(_ account: GitHubAccount) {
        do {
            try AccountService.unlinkSSH(login: account.login)
            reload()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

final class PrivateKeyPanelDelegate: NSObject, NSOpenSavePanelDelegate {
    func panel(_ sender: Any, shouldEnable url: URL) -> Bool {
        if (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
            return true
        }
        return SSHKeyFile.isSelectable(url)
    }
}

struct SettingsView: View {
    let model: MenuBarModel
    @State private var aliases: [String: String] = [:]
    @State private var isAddingAccount = false
    @State private var accountToRemove: GitHubAccount?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("GitHub Accounts").font(.title2)
            if model.configuredAccounts.isEmpty {
                Text("No accounts linked yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(model.configuredAccounts) { account in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(account.displayName).font(.headline)
                            if account.alias != nil {
                                Text("GitHub: \(account.login)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text(account.sshKeyPath ?? "")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        TextField("Alias (optional)", text: aliasBinding(for: account))
                            .frame(width: 140)
                        Button("Change…") {
                            model.link(account, alias: aliases[account.login] ?? account.alias ?? "")
                        }
                        Button(role: .destructive) {
                            accountToRemove = account
                        } label: {
                            Image(systemName: "xmark")
                        }
                        .buttonStyle(.borderless)
                        .help("Remove account link")
                        .accessibilityLabel("Remove \(account.displayName)")
                    }
                }
            }
            Button("Add GitHub Account…") {
                isAddingAccount = true
            }
            if let error = model.error {
                Text(error).foregroundStyle(.red).font(.caption)
            }
        }
        .padding(20)
        .frame(minWidth: 460)
        .sheet(isPresented: $isAddingAccount) {
            AddAccountView(model: model)
        }
        .alert(
            "Remove \(accountToRemove?.displayName ?? "account")?",
            isPresented: Binding(
                get: { accountToRemove != nil },
                set: { if !$0 { accountToRemove = nil } }
            ),
            presenting: accountToRemove
        ) { account in
            Button("Remove", role: .destructive) {
                model.unlink(account)
                accountToRemove = nil
            }
            Button("Cancel", role: .cancel) {
                accountToRemove = nil
            }
        } message: { account in
            Text("This removes the local SSH key and alias link for \(account.login). The account remains signed in to gh.")
        }
    }

    private func aliasBinding(for account: GitHubAccount) -> Binding<String> {
        Binding(
            get: { aliases[account.login] ?? account.alias ?? "" },
            set: { aliases[account.login] = $0 }
        )
    }
}

struct AddAccountView: View {
    let model: MenuBarModel
    @Environment(\.dismiss) private var dismiss
    @State private var aliases: [String: String] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Add GitHub Account").font(.title2)
                Spacer()
                Button("Done") { dismiss() }
            }
            if model.accounts.isEmpty {
                Text("No accounts found in gh. Add one with gh auth login, then refresh.")
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Choose the private key belonging to the GitHub account.")
                        .font(.headline)
                    Text("It is usually in ~/.ssh and has a name like id_ed25519. Choose the file without .pub — never config or known_hosts.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                ForEach(model.accounts) { account in
                    HStack {
                        Text(account.displayName).font(.headline)
                        if account.isConfigured {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .accessibilityLabel("Linked")
                        }
                        Spacer()
                        if !account.isConfigured {
                            TextField("Alias (optional)", text: aliasBinding(for: account))
                                .frame(width: 140)
                            Button("Choose private key…") {
                                model.link(account, alias: aliases[account.login] ?? "")
                            }
                        }
                    }
                }
            }
            if let error = model.error {
                Text(error).foregroundStyle(.red).font(.caption)
            }
        }
        .padding(20)
        .frame(minWidth: 520, minHeight: 180)
    }

    private func aliasBinding(for account: GitHubAccount) -> Binding<String> {
        Binding(
            get: { aliases[account.login] ?? "" },
            set: { aliases[account.login] = $0 }
        )
    }
}
