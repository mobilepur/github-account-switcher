import AppKit
import GitHubAccountSwitcherCore
import Observation
import SwiftUI

@main
struct GitHubAccountSwitcherMenuBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
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
                        .frame(minWidth: 170, alignment: .leading)
                }
            }
            Divider()
            Menu("Settings") {
                Menu("GitHub Accounts") {
                    if model.accounts.isEmpty {
                        Text("No accounts found in gh")
                    }
                    ForEach(model.accounts) { account in
                        Menu {
                            if let keyPath = account.sshKeyPath {
                                Text(keyPath)
                                Button("Change private key…") {
                                    model.link(account, alias: account.alias ?? "")
                                }
                                Menu("Remove link") {
                                    Button("Confirm removal", role: .destructive) {
                                        model.unlink(account)
                                    }
                                }
                            } else {
                                Button("Link private key…") {
                                    model.link(account, alias: "")
                                }
                            }
                        } label: {
                            if account.isConfigured {
                                Label(account.displayName, systemImage: "checkmark.circle.fill")
                            } else {
                                Text(account.displayName)
                            }
                        }
                    }
                }
                Button("Refresh") {
                    model.reload()
                }
            }
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Text("Quit")
                    .frame(minWidth: 170, alignment: .leading)
            }
        } label: {
            Image(nsImage: menuBarImage(for: model.activeAccount?.menuBarAbbreviation ?? "---"))
            .accessibilityLabel(model.activeAccount.map { "Active GitHub account: \($0.displayName)" } ?? "No active GitHub account")
        }
        .menuBarExtraStyle(.menu)
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
