import Testing
@testable import GitHubAccountSwitcherCore

@Suite("Login item")
struct LoginItemManagerTests {
    @Test("Enabling registers the main app")
    func enableLoginItem() throws {
        let recorder = LoginItemRecorder()
        let manager = recorder.manager

        try manager.setEnabled(true)

        #expect(recorder.didRegister)
        #expect(manager.isEnabled)
    }

    @Test("Approval opens the system Login Items settings")
    func approvalOpensSystemSettings() throws {
        let recorder = LoginItemRecorder(status: .requiresApproval, statusAfterRegistration: .requiresApproval)
        let manager = recorder.manager

        try manager.setEnabled(true)

        #expect(recorder.didOpenSettings)
    }

    @Test("Disabling unregisters the main app")
    func disableLoginItem() throws {
        let recorder = LoginItemRecorder(status: .enabled)

        try recorder.manager.setEnabled(false)

        #expect(recorder.didUnregister)
    }
}

private final class LoginItemRecorder {
    var currentStatus: LoginItemStatus
    var didRegister = false
    var didUnregister = false
    var didOpenSettings = false
    let statusAfterRegistration: LoginItemStatus

    init(status: LoginItemStatus = .disabled, statusAfterRegistration: LoginItemStatus = .enabled) {
        currentStatus = status
        self.statusAfterRegistration = statusAfterRegistration
    }

    var manager: LoginItemManager {
        LoginItemManager(
            status: { self.currentStatus },
            register: {
                self.didRegister = true
                self.currentStatus = self.statusAfterRegistration
            },
            unregister: {
                self.didUnregister = true
                self.currentStatus = .disabled
            },
            openSettings: { self.didOpenSettings = true }
        )
    }
}
