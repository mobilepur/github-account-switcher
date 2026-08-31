import AppKit
import GitHubAccountSwitcherCore
import Observation
import SwiftUI

enum DeviceSignInCode {
    static func parse(_ value: String?) -> String? {
        guard let value,
              value.range(
                  of: #"^[A-Z0-9]{4}-[A-Z0-9]{4}$"#,
                  options: .regularExpression
              ) != nil else {
            return nil
        }
        return value
    }
}

enum GitHubSignInFeedback {
    static func message(for error: Error) -> String {
        if error.localizedDescription.localizedCaseInsensitiveContains("context deadline exceeded") {
            return "GitHub sign-in timed out. Click Add Account… to try again."
        }
        return "GitHub sign-in could not be completed. Click Add Account… to try again."
    }
}

enum GitHubDeviceBrowser {
    @MainActor
    static func open() {
        NSWorkspace.shared.open(AppLinks.deviceSignIn, configuration: openConfiguration())
    }

    @MainActor
    static func openConfiguration() -> NSWorkspace.OpenConfiguration {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        return configuration
    }
}

enum SettingsLayout {
    static func contentHeight(isAddingAccount: Bool) -> CGFloat {
        isAddingAccount ? 480 : 368
    }
}

enum SettingsWindow {
    @MainActor
    static func find(in windows: [NSWindow]) -> NSWindow? {
        windows.first { $0.title.localizedCaseInsensitiveContains("settings") }
    }

    @MainActor
    static func bringToFront() {
        guard let window = find(in: NSApplication.shared.windows) else { return }
        NSApplication.shared.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}

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
                    guard let window = SettingsWindow.find(in: NSApplication.shared.windows) else { return }
                    window.setContentSize(NSSize(
                        width: 520,
                        height: SettingsLayout.contentHeight(isAddingAccount: model.isAddingAccount)
                    ))
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
    static let avatarRect = NSRect(x: 7.5, y: 2.5, width: 13, height: 13)
    private static let badgeRect = NSRect(x: 6.5, y: 1.5, width: 15, height: 15)
    static let abbreviationFontSize: CGFloat = 10
    private static let abbreviationVerticalPixelOffset: CGFloat = -2
    private static let baseIconOpacity: CGFloat = 0.9

    static func image(for abbreviation: String, avatar: NSImage?) -> NSImage {
        let size = NSSize(width: 28, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            let topShaft = NSBezierPath()
            topShaft.move(to: NSPoint(x: 2, y: 12))
            topShaft.line(to: NSPoint(x: 27, y: 12))
            topShaft.lineWidth = 2
            topShaft.lineCapStyle = .round

            let topArrowhead = NSBezierPath()
            topArrowhead.move(to: NSPoint(x: 23, y: 8))
            topArrowhead.line(to: NSPoint(x: 27, y: 12))
            topArrowhead.line(to: NSPoint(x: 23, y: 16))
            topArrowhead.lineWidth = 2
            topArrowhead.lineCapStyle = .round
            topArrowhead.lineJoinStyle = .round

            let bottomShaft = NSBezierPath()
            bottomShaft.move(to: NSPoint(x: 1, y: 6))
            bottomShaft.line(to: NSPoint(x: 26, y: 6))
            bottomShaft.lineWidth = 2
            bottomShaft.lineCapStyle = .round

            let bottomArrowhead = NSBezierPath()
            bottomArrowhead.move(to: NSPoint(x: 5, y: 2))
            bottomArrowhead.line(to: NSPoint(x: 1, y: 6))
            bottomArrowhead.line(to: NSPoint(x: 5, y: 10))
            bottomArrowhead.lineWidth = 2
            bottomArrowhead.lineCapStyle = .round
            bottomArrowhead.lineJoinStyle = .round

            let baseIconColor = NSColor.labelColor.withAlphaComponent(baseIconOpacity)
            baseIconColor.setStroke()
            topShaft.stroke()
            topArrowhead.stroke()
            bottomShaft.stroke()
            bottomArrowhead.stroke()
            baseIconColor.setFill()
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
                    .font: NSFont.systemFont(ofSize: abbreviationFontSize, weight: .bold),
                    .foregroundColor: NSColor.black,
                ]
                let text = abbreviation as NSString
                let textBounds = text.boundingRect(
                    with: rect.size,
                    options: .usesDeviceMetrics,
                    attributes: attributes
                )
                NSGraphicsContext.current?.compositingOperation = .destinationOut
                text.draw(
                    at: NSPoint(
                        x: (rect.midX - textBounds.midX).rounded(),
                        y: (rect.midY - textBounds.midY).rounded()
                            + abbreviationVerticalPixelOffset
                    ),
                    withAttributes: attributes
                )
                NSGraphicsContext.current?.compositingOperation = .sourceOver
            }
            return true
        }
        image.isTemplate = avatar == nil
        return image
    }
}

struct MainPanelNavigationLabel: View {
    let title: String
    var detail: String?

    init(title: String, detail: String? = nil) {
        self.title = title
        self.detail = detail
    }

    var body: some View {
        HStack(spacing: 4) {
            Text(title)
            Spacer()
            if let detail {
                Text(detail)
                    .foregroundStyle(.secondary)
            }
            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
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
                MainPanelNavigationLabel(title: "Configure Accounts")
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
            Link(destination: AppLinks.releaseNotes(version: appVersion)) {
                MainPanelNavigationLabel(
                    title: "GitHub Account Switcher",
                    detail: appVersion
                )
            }
            .buttonStyle(.plain)
            .help("View GitHub release notes for version \(appVersion)")
            .accessibilityLabel("Version \(appVersion), GitHub Release Notes")
            Link(destination: AppLinks.newIssue) {
                MainPanelNavigationLabel(title: "Report a Problem…")
            }
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
    var signInError: String?
    var isAddingAccount = false
    var isCancellingAccountAddition = false
    var deviceCode: String?
    private var authentication: GHAuthentication?
    private var clipboardChangeCount: Int?
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

    func addAccount() {
        guard !isAddingAccount else { return }

        let authentication = AccountService.makeAuthentication()
        self.authentication = authentication
        isAddingAccount = true
        isCancellingAccountAddition = false
        deviceCode = nil
        clipboardChangeCount = NSPasteboard.general.changeCount
        error = nil
        signInError = nil
        loadDeviceCode(for: authentication, attemptsRemaining: 20)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = Result { try authentication.run() }
            DispatchQueue.main.async {
                guard let self else { return }
                guard self.authentication === authentication else { return }
                self.authentication = nil
                self.isAddingAccount = false
                self.isCancellingAccountAddition = false
                self.deviceCode = nil
                self.clipboardChangeCount = nil
                switch result {
                case .success:
                    self.reload()
                    SettingsWindow.bringToFront()
                case let .failure(error):
                    if !authentication.wasCancelled {
                        self.signInError = GitHubSignInFeedback.message(for: error)
                    }
                }
            }
        }
    }

    private func loadDeviceCode(for authentication: GHAuthentication, attemptsRemaining: Int) {
        guard self.authentication === authentication,
              isAddingAccount,
              !isCancellingAccountAddition else { return }

        if clipboardChangeCount != NSPasteboard.general.changeCount,
           let code = DeviceSignInCode.parse(NSPasteboard.general.string(forType: .string)) {
            deviceCode = code
            return
        }
        guard attemptsRemaining > 0 else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            self?.loadDeviceCode(for: authentication, attemptsRemaining: attemptsRemaining - 1)
        }
    }

    func cancelAccountAddition() {
        guard isAddingAccount, !isCancellingAccountAddition else { return }

        isCancellingAccountAddition = true
        authentication?.cancel()
    }

    func copyDeviceCode() {
        guard let deviceCode else { return }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(deviceCode, forType: .string)
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

enum SettingsCopy {
    static let privateKeyGuidance = "The linked SSH key authenticates Git pushes as this GitHub account."
}

struct SettingsView: View {
    let model: MenuBarModel
    @Environment(\.dismiss) private var dismiss
    @State private var accountToRemove: GitHubAccount?
    @State private var isShowingPrivateKeyHelp = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 6) {
                Text("GitHub Accounts")
                    .font(.title2)
                Button {
                    isShowingPrivateKeyHelp = true
                } label: {
                    Image(systemName: "questionmark.circle")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("About SSH keys")
                .accessibilityLabel("About SSH keys")
                .popover(isPresented: $isShowingPrivateKeyHelp) {
                    Text(SettingsCopy.privateKeyGuidance)
                        .font(.callout)
                        .padding(14)
                        .frame(width: 260, alignment: .leading)
                }
            }
            if model.accounts.isEmpty {
                Text("No accounts found in gh. Use Add Account… to sign in to GitHub.")
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
            if model.isAddingAccount {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        if model.isCancellingAccountAddition {
                            HStack(spacing: 8) {
                                ProgressView().controlSize(.small)
                                Text("Cancelling sign-in…")
                            }
                        } else {
                            Text("This signs GitHub CLI in on this Mac; your password and token stay with GitHub and gh.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                            Button("Sign in to GitHub") {
                                GitHubDeviceBrowser.open()
                            }
                            .font(.headline)
                            Text("Then enter this code:")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if let code = model.deviceCode {
                                Button {
                                    model.copyDeviceCode()
                                } label: {
                                    HStack(spacing: 8) {
                                        Text(code)
                                            .font(.system(.title2, design: .monospaced, weight: .semibold))
                                        Image(systemName: "doc.on.doc")
                                    }
                                }
                                .help("Copy sign-in code")
                                .accessibilityLabel("Copy sign-in code \(code)")
                            } else {
                                HStack(spacing: 8) {
                                    ProgressView().controlSize(.small)
                                    Text("Preparing code…")
                                        .font(.caption)
                                }
                            }
                        }
                        Spacer(minLength: 0)
                        HStack {
                            Spacer()
                            Button("Cancel") {
                                model.cancelAccountAddition()
                            }
                            .disabled(model.isCancellingAccountAddition)
                        }
                    }
                    .padding(14)
                    .frame(minWidth: 280, minHeight: 202)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                    Spacer()
                }
                Spacer(minLength: 0)
            }
            if !model.isAddingAccount {
                HStack {
                    Button {
                        model.addAccount()
                    } label: {
                        Text("Add Account…")
                    }
                    Spacer()
                    Button("Done") { dismiss() }
                        .keyboardShortcut(.defaultAction)
                }
            }
            if let error = model.signInError ?? model.error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(20)
        .frame(
            width: 520,
            height: SettingsLayout.contentHeight(isAddingAccount: model.isAddingAccount)
        )
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
