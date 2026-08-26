import AppKit
import GitHubAccountSwitcherCore
import Observation
import SwiftUI

@main
struct GitHubAccountSwitcherMenuBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.openSettings) private var openSettings
    @State private var model = MenuBarModel()
    @State private var activeAvatar = ActiveAvatarState()
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
            let account = model.activeAccount
            Image(nsImage: MenuBarIconRenderer.image(
                for: account?.menuBarAbbreviation ?? "--",
                avatar: useGitHubAvatars ? activeAvatar.image : nil
            ))
            .accessibilityLabel(account.map { "Active GitHub account: \($0.displayName)" } ?? "No active GitHub account")
            .task(id: account?.login) {
                await activeAvatar.load(for: account?.login) {
                    await AvatarLoader.load(for: account)
                }
            }
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(model: model)
        }
        .windowResizability(.contentSize)
    }
}

@MainActor
@Observable
final class ActiveAvatarState {
    private(set) var image: NSImage?
    private var loadingLogin: String?

    func load(for login: String?, operation: @MainActor () async -> NSImage?) async {
        guard !Task.isCancelled else { return }
        beginLoading(for: login)
        let image = await operation()
        guard !Task.isCancelled else { return }
        finishLoading(image, for: login)
    }

    func beginLoading(for login: String?) {
        loadingLogin = login
        image = nil
    }

    func finishLoading(_ image: NSImage?, for login: String?) {
        guard loadingLogin == login else { return }
        self.image = image
    }
}

enum AvatarLoader {
    private static let session = URLSession(configuration: sessionConfiguration())

    static func sessionConfiguration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.default
        configuration.waitsForConnectivity = true
        return configuration
    }

    @MainActor
    static func load(for account: GitHubAccount?) async -> NSImage? {
        guard let url = account?.avatarURL else { return nil }
        guard let (data, response) = try? await session.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return NSImage(data: data)
    }
}

enum MenuBarIconRenderer {
    static let avatarRect = NSRect(x: 9, y: 3, width: 14, height: 14)
    private static let badgeRect = NSRect(x: 7, y: 1, width: 18, height: 18)

    static func image(for abbreviation: String, avatar: NSImage?) -> NSImage {
        let size = NSSize(width: 32, height: 20)
        let image = NSImage(size: size, flipped: false) { rect in
            let topShaft = NSBezierPath()
            topShaft.move(to: NSPoint(x: 2, y: 13))
            topShaft.line(to: NSPoint(x: 31, y: 13))
            topShaft.lineWidth = 2
            topShaft.lineCapStyle = .round

            let topArrowhead = NSBezierPath()
            topArrowhead.move(to: NSPoint(x: 27, y: 9))
            topArrowhead.line(to: NSPoint(x: 31, y: 13))
            topArrowhead.line(to: NSPoint(x: 27, y: 17))
            topArrowhead.lineWidth = 2
            topArrowhead.lineCapStyle = .round
            topArrowhead.lineJoinStyle = .round

            let bottomShaft = NSBezierPath()
            bottomShaft.move(to: NSPoint(x: 1, y: 7))
            bottomShaft.line(to: NSPoint(x: 30, y: 7))
            bottomShaft.lineWidth = 2
            bottomShaft.lineCapStyle = .round

            let bottomArrowhead = NSBezierPath()
            bottomArrowhead.move(to: NSPoint(x: 5, y: 3))
            bottomArrowhead.line(to: NSPoint(x: 1, y: 7))
            bottomArrowhead.line(to: NSPoint(x: 5, y: 11))
            bottomArrowhead.lineWidth = 2
            bottomArrowhead.lineCapStyle = .round
            bottomArrowhead.lineJoinStyle = .round

            NSColor.black.setStroke()
            topShaft.stroke()
            topArrowhead.stroke()
            bottomShaft.stroke()
            bottomArrowhead.stroke()
            NSColor.black.setFill()
            NSBezierPath(
                roundedRect: badgeRect,
                xRadius: 5,
                yRadius: 5
            ).fill()

            if let avatar {
                NSGraphicsContext.saveGraphicsState()
                NSBezierPath(ovalIn: avatarRect).addClip()
                avatar.draw(in: avatarRect)
                NSGraphicsContext.restoreGraphicsState()
            } else {
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: 10, weight: .bold),
                    .foregroundColor: NSColor.white,
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
            if let loginItemError {
                Text(loginItemError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            Divider()
            Text("About")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Text("GitHub Account Switcher")
                Spacer()
                Link(destination: AppLinks.releaseNotes(version: appVersion)) {
                    HStack(spacing: 4) {
                        Text(appVersion)
                        Image(systemName: "chevron.right")
                            .font(.caption.bold())
                    }
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("View GitHub release notes for version \(appVersion)")
                .accessibilityLabel("Version \(appVersion), GitHub Release Notes")
            }
            Link("Report a Problem…", destination: AppLinks.newIssue)
                .buttonStyle(.plain)
            Spacer(minLength: 8)
            Divider()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .frame(width: 240, height: 368)
        .onAppear {
            startsAtLogin = loginItemManager.isEnabled
        }
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
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
