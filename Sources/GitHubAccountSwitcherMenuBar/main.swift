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
            ForEach(model.accounts) { account in
                Button {
                    model.select(account.login)
                } label: {
                    Text("\(account.isActive ? "✓ " : "")\(account.displayName)")
                }
                .disabled(account.sshKeyPath == nil)
            }
            Divider()
            SettingsLink { Text("Settings…") }
            Button("Refresh") { model.reload() }
            Button("Quit") { NSApplication.shared.terminate(nil) }
        } label: {
            VStack(spacing: -3) {
                Text(model.activeAccount?.menuBarAbbreviation ?? "---")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 7, weight: .semibold))
            }
            .frame(width: 25, height: 20)
            .accessibilityLabel(model.activeAccount.map { "Active GitHub account: \($0.displayName)" } ?? "No active GitHub account")
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView(model: model)
        }
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
    var needsAttention: Bool { accounts.isEmpty || accounts.contains(where: { $0.sshKeyPath == nil }) }
    var activeAccount: GitHubAccount? { accounts.first(where: \.isActive) }

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
        panel.title = "Select SSH key for \(account.login)"
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser.appending(path: ".ssh")
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

struct SettingsView: View {
    let model: MenuBarModel
    @State private var aliases: [String: String] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("GitHub Accounts").font(.title2)
            if model.accounts.isEmpty {
                ContentUnavailableView("No GitHub accounts", systemImage: "person.crop.circle.badge.exclamationmark")
            } else {
                ForEach(model.accounts) { account in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(account.login).font(.headline)
                            Text(account.sshKeyPath ?? "No SSH key linked")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        TextField("Alias (optional)", text: aliasBinding(for: account))
                            .frame(width: 140)
                        Button(account.sshKeyPath == nil ? "Link SSH key…" : "Change…") {
                            model.link(account, alias: aliases[account.login] ?? account.alias ?? "")
                        }
                    }
                }
            }
            if let error = model.error {
                Text(error).foregroundStyle(.red).font(.caption)
            }
        }
        .padding(20)
        .frame(minWidth: 620)
    }

    private func aliasBinding(for account: GitHubAccount) -> Binding<String> {
        Binding(
            get: { aliases[account.login] ?? account.alias ?? "" },
            set: { aliases[account.login] = $0 }
        )
    }
}
