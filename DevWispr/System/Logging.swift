//
//  Logging.swift
//  DevWispr
//

import Foundation

func debugLog(_ message: @autoclosure () -> String) {
    #if DEBUG
    print("[DevWispr] \(message())")
    #endif
}

func infoLog(_ message: @autoclosure () -> String) {
    #if DEBUG
    print("[DevWispr] \(message())")
    #endif
}
