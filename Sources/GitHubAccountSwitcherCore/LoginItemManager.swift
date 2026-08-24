import Foundation
import ServiceManagement

public enum LoginItemStatus: Equatable, Sendable {
    case enabled
    case disabled
    case requiresApproval
    case unavailable
}

public struct LoginItemManager {
    private let statusProvider: () -> LoginItemStatus
    private let registerAction: () throws -> Void
    private let unregisterAction: () throws -> Void
    private let openSettingsAction: () -> Void

    public static var live: LoginItemManager {
        guard Bundle.main.bundleURL.pathExtension == "app" else {
            return LoginItemManager(status: { .unavailable })
        }
        let service = SMAppService.mainApp
        return LoginItemManager(
            status: {
                switch service.status {
                case .enabled: .enabled
                case .requiresApproval: .requiresApproval
                case .notRegistered, .notFound: .disabled
                @unknown default: .disabled
                }
            },
            register: { try service.register() },
            unregister: { try service.unregister() },
            openSettings: { SMAppService.openSystemSettingsLoginItems() }
        )
    }

    public init(
        status: @escaping () -> LoginItemStatus,
        register: @escaping () throws -> Void = {},
        unregister: @escaping () throws -> Void = {},
        openSettings: @escaping () -> Void = {}
    ) {
        statusProvider = status
        registerAction = register
        unregisterAction = unregister
        openSettingsAction = openSettings
    }

    public var status: LoginItemStatus { statusProvider() }
    public var isEnabled: Bool { status == .enabled }

    public func setEnabled(_ enabled: Bool) throws {
        if enabled {
            if status == .requiresApproval {
                openSettingsAction()
                return
            }
            try registerAction()
        } else {
            try unregisterAction()
        }
    }

    public func openSystemSettings() {
        openSettingsAction()
    }
}
