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
            MainPanelView(model: model) {
                openSettings()
                NSApplication.shared.activate(ignoringOtherApps: true)
                DispatchQueue.main.async {
                    guard let window = NSApplication.shared.windows.first(where: {
                        $0.title.localizedCaseInsensitiveContains("settings")
                    }) else { return }
                    window.setContentSize(NSSize(width: 520, height: 368))
                    window.center()
                    window.makeKeyAndOrderFront(nil)
                }
            }
        } label: {
            Image(nsImage: menuBarImage(for: model.activeAccount?.menuBarAbbreviation ?? "---"))
            .accessibilityLabel(model.activeAccount.map { "Active GitHub account: \($0.displayName)" } ?? "No active GitHub account")
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(model: model)
        }
        .windowResizability(.contentSize)
    }

    private func menuBarImage(for abbreviation: String) -> NSImage {
        let size = NSSize(width: 34, height: 20)
        let image = NSImage(size: size, flipped: false) { rect in
            let arrow = NSBezierPath()
            arrow.move(to: NSPoint(x: 0, y: rect.midY))
            arrow.line(to: NSPoint(x: 7, y: 20))
            arrow.line(to: NSPoint(x: 7, y: 18))
            arrow.line(to: NSPoint(x: 27, y: 18))
            arrow.line(to: NSPoint(x: 27, y: 20))
            arrow.line(to: NSPoint(x: 34, y: rect.midY))
            arrow.line(to: NSPoint(x: 27, y: 0))
            arrow.line(to: NSPoint(x: 27, y: 2))
            arrow.line(to: NSPoint(x: 7, y: 2))
            arrow.line(to: NSPoint(x: 7, y: 0))
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

struct MainPanelView: View {
    let model: MenuBarModel
    let showSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Accounts")
                .font(.headline)
            if model.configuredAccounts.isEmpty {
                Text("No accounts configured.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(model.configuredAccounts) { account in
                    Button {
                        model.select(account.login)
                    } label: {
                        HStack {
                            Text(account.displayName)
                            Spacer()
                            if account.isActive {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            if let error = model.error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            Spacer(minLength: 12)
            Divider()
            Button("Settings", action: showSettings)
                .buttonStyle(.plain)
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .frame(width: 240)
        .frame(minHeight: 200)
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
    @State private var accountToRemove: GitHubAccount?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("GitHub Accounts")
                .font(.title2)
            if model.accounts.isEmpty {
                Text("No accounts found in gh. Add one with gh auth login, then refresh.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(model.accounts) { account in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(account.login)
                                .font(.headline)
                            Text(account.sshKeyPath ?? "No private key linked")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(account.isConfigured ? "Change key…" : "Link key…") {
                            model.link(account, alias: account.alias ?? "")
                        }
                        if account.isConfigured {
                            Button(role: .destructive) {
                                accountToRemove = account
                            } label: {
                                Image(systemName: "xmark")
                            }
                            .buttonStyle(.borderless)
                            .help("Remove account link")
                            .accessibilityLabel("Remove \(account.login)")
                        }
                    }
                }
            }
            Spacer()
            HStack {
                Spacer()
                Button("Refresh") { model.reload() }
            }
            if let error = model.error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(20)
        .frame(width: 520, height: 368)
        .alert(
            "Remove \(accountToRemove?.login ?? "account")?",
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
            Text("This removes the local private-key link for \(account.login). The account remains signed in to gh.")
        }
    }
}
