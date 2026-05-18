import Foundation
import ServiceManagement
import os

enum LaunchAtLogin {
    private static let log = Logger(subsystem: "com.hamiltonianlab.claudeusage", category: "launchAtLogin")

    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func set(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
