import AppKit
import GitHubAccountSwitcherCore
import Observation
import SwiftUI

@main
struct GitHubAccountSwitcherMenuBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.openSettings) private var openSettings
    @State private var model = MenuBarModel()
    @State private var activeAvatar: NSImage?
    @AppStorage("useGitHubAvatars") private var useGitHubAvatars = true

    var body: some Scene {
        MenuBarExtra {
            MainPanelView(model: model) {
                NSApplication.shared.keyWindow?.orderOut(nil)
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
            Image(nsImage: MenuBarIconRenderer.image(
                for: model.activeAccount?.menuBarAbbreviation ?? "--",
                avatar: useGitHubAvatars ? activeAvatar : nil
            ))
            .accessibilityLabel(model.activeAccount.map { "Active GitHub account: \($0.displayName)" } ?? "No active GitHub account")
            .task(id: model.activeAccount?.login) {
                activeAvatar = await loadAvatar(for: model.activeAccount)
            }
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(model: model)
        }
        .windowResizability(.contentSize)
    }

    private func loadAvatar(for account: GitHubAccount?) async -> NSImage? {
        guard let url = account?.avatarURL else { return nil }
        guard let (data, response) = try? await URLSession.shared.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return NSImage(data: data)
    }
}

enum MenuBarIconRenderer {
    static func image(for abbreviation: String, avatar: NSImage?) -> NSImage {
        let size = NSSize(width: 30, height: 20)
        let image = NSImage(size: size, flipped: false) { rect in
            let arrow = NSBezierPath()
            arrow.move(to: NSPoint(x: 0, y: rect.midY))
            arrow.line(to: NSPoint(x: 6, y: 20))
            arrow.line(to: NSPoint(x: 6, y: 17))
            arrow.line(to: NSPoint(x: 24, y: 17))
            arrow.line(to: NSPoint(x: 24, y: 20))
            arrow.line(to: NSPoint(x: 30, y: rect.midY))
            arrow.line(to: NSPoint(x: 24, y: 0))
            arrow.line(to: NSPoint(x: 24, y: 3))
            arrow.line(to: NSPoint(x: 6, y: 3))
            arrow.line(to: NSPoint(x: 6, y: 0))
            arrow.close()

            NSGraphicsContext.saveGraphicsState()
            NSBezierPath(rect: NSRect(x: 0, y: 0, width: rect.midX, height: rect.height)).addClip()
            NSColor.white.setFill()
            arrow.fill()
            NSColor.black.setStroke()
            arrow.lineWidth = 1.5
            arrow.stroke()
            NSGraphicsContext.restoreGraphicsState()

            NSGraphicsContext.saveGraphicsState()
            NSBezierPath(rect: NSRect(x: rect.midX, y: 0, width: rect.midX, height: rect.height)).addClip()
            NSColor.black.setFill()
            arrow.fill()
            NSGraphicsContext.restoreGraphicsState()

            if let avatar {
                NSGraphicsContext.saveGraphicsState()
                NSBezierPath(ovalIn: NSRect(x: 8, y: 3, width: 14, height: 14)).addClip()
                avatar.draw(in: NSRect(x: 8, y: 3, width: 14, height: 14))
                NSGraphicsContext.restoreGraphicsState()
            } else {
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: 10, weight: .bold),
                    .foregroundColor: NSColor.black,
                ]
                let text = abbreviation as NSString
                let textSize = text.size(withAttributes: attributes)
                let origin = NSPoint(
                    x: (rect.width - textSize.width) / 2,
                    y: (rect.height - textSize.height) / 2
                )

                NSGraphicsContext.saveGraphicsState()
                NSBezierPath(rect: NSRect(x: 0, y: 0, width: rect.midX, height: rect.height)).addClip()
                text.draw(at: origin, withAttributes: attributes)
                NSGraphicsContext.restoreGraphicsState()

                NSGraphicsContext.saveGraphicsState()
                NSBezierPath(rect: NSRect(x: rect.midX, y: 0, width: rect.midX, height: rect.height)).addClip()
                var invertedAttributes = attributes
                invertedAttributes[.foregroundColor] = NSColor.white
                text.draw(at: origin, withAttributes: invertedAttributes)
                NSGraphicsContext.restoreGraphicsState()
            }
            return true
        }
        image.isTemplate = false
        return image
    }
}

struct MainPanelView: View {
    let model: MenuBarModel
    let showSettings: () -> Void
    private let loginItemManager = LoginItemManager.live
    @AppStorage("useGitHubAvatars") private var useGitHubAvatars = true
    @State private var startsAtLogin = false
    @State private var loginItemError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Accounts")
                .font(.caption)
                .foregroundStyle(.secondary)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    if model.configuredAccounts.isEmpty {
                        Text("No accounts configured.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(model.configuredAccounts) { account in
                            Button {
                                model.select(account.login)
                            } label: {
                                HStack {
                                    GitHubAvatarView(account: account, size: 24)
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
                }
            }
            .frame(height: accountListHeight)
            if let error = model.error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            Divider()
            Text("Settings")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button(action: showSettings) {
                HStack {
                    Text("Configure Accounts")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }
            }
                .buttonStyle(.plain)
            Toggle("Start at Login", isOn: startAtLoginBinding)
                .disabled(loginItemManager.status == .unavailable)
            Toggle("Use GitHub Avatars", isOn: $useGitHubAvatars)
            Link(destination: AppLinks.newIssue) {
                Label("Report a Problem…", systemImage: "exclamationmark.bubble")
            }
            .buttonStyle(.plain)
            if let loginItemError {
                Text(loginItemError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            Spacer(minLength: 8)
            Divider()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .frame(width: 240, height: 324)
        .onAppear {
            startsAtLogin = loginItemManager.isEnabled
        }
    }

    private var accountListHeight: CGFloat {
        min(CGFloat(max(model.configuredAccounts.count, 1)) * 32, 104)
    }

    private var startAtLoginBinding: Binding<Bool> {
        Binding(
            get: { startsAtLogin },
            set: { enabled in
                do {
                    try loginItemManager.setEnabled(enabled)
                    startsAtLogin = loginItemManager.isEnabled
                    loginItemError = nil
                } catch {
                    loginItemError = error.localizedDescription
                }
            }
        )
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
    @Environment(\.dismiss) private var dismiss
    @State private var accountToRemove: GitHubAccount?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("GitHub Accounts")
                .font(.title2)
            if model.accounts.isEmpty {
                Text("No accounts found in gh. Add one with gh auth login, then reopen Account Settings.")
                    .foregroundStyle(.secondary)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(model.accounts) { account in
                            HStack {
                                GitHubAvatarView(account: account)
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
                }
            }
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            if let error = model.error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(20)
        .frame(width: 520, height: 368)
        .onAppear { model.reload() }
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

struct GitHubAvatarView: View {
    let account: GitHubAccount
    var size: CGFloat = 36

    var body: some View {
        AsyncImage(url: account.avatarURL) { phase in
            if case let .success(image) = phase {
                image
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Circle().fill(.quaternary)
                    Text(account.menuBarAbbreviation)
                        .font(.caption.bold())
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityLabel("GitHub avatar for \(account.login)")
    }
}
