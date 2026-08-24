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
        let size = NSSize(width: 25, height: 20)
        let image = NSImage(size: size, flipped: false) { rect in
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 9, weight: .semibold),
                .foregroundColor: NSColor.labelColor,
            ]
            let text = abbreviation as NSString
            let textSize = text.size(withAttributes: attributes)
            text.draw(
                at: NSPoint(
                    x: (rect.width - textSize.width) / 2,
                    y: (rect.height - textSize.height) / 2
                ),
                withAttributes: attributes
            )
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
    var availableAccounts: [GitHubAccount] { accounts.filter { !$0.isConfigured } }
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
                            Text(account.login).font(.headline)
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
            if model.availableAccounts.isEmpty {
                ContentUnavailableView(
                    "No available GitHub accounts",
                    systemImage: "person.crop.circle.badge.checkmark",
                    description: Text("Add another account with gh auth login, then refresh.")
                )
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Choose the private key belonging to the GitHub account.")
                        .font(.headline)
                    Text("It is usually in ~/.ssh and has a name like id_ed25519. Choose the file without .pub — never config or known_hosts.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                ForEach(model.availableAccounts) { account in
                    HStack {
                        Text(account.login).font(.headline)
                        Spacer()
                        TextField("Alias (optional)", text: aliasBinding(for: account))
                            .frame(width: 140)
                        Button("Choose private key…") {
                            model.link(account, alias: aliases[account.login] ?? "")
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
