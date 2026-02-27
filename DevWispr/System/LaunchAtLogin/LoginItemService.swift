//
//  LoginItemService.swift
//  DevWispr
//

import ServiceManagement

/// Wraps `SMAppService.mainApp` to register/unregister the app as a login item.
enum LoginItemService {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // kSMErrorAlreadyRegistered / kSMErrorJobNotFound are benign —
            // they just mean the state is already what we asked for.
            let code = (error as NSError).code
            if code != kSMErrorAlreadyRegistered && code != kSMErrorJobNotFound {
                infoLog("LoginItemService: failed to \(enabled ? "register" : "unregister"): \(error)")
            }
        }
    }
}
