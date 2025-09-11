// BiometricAuthManager.swift
import Foundation
import LocalAuthentication
import SwiftUI

@MainActor
class BiometricAuthManager: ObservableObject {
    @Published var biometricType: BiometricType = .none
    @Published var isEnabled: Bool = false
    
    enum BiometricType {
        case none, touchID, faceID, opticID
        
        var displayName: String {
            switch self {
            case .none:
                return "None Available"
            case .touchID:
                return "Touch ID"
            case .faceID:
                return "Face ID"
            case .opticID:
                return "Optic ID"
            }
        }
        
        var icon: String {
            switch self {
            case .none:
                return "lock"
            case .touchID:
                return "touchid"
            case .faceID:
                return "faceid"
            case .opticID:
                return "opticid"
            }
        }
    }
    
    enum AuthError: LocalizedError {
        case notAvailable, notEnrolled, failed, userCancel, userFallback
        case systemCancel, passcodeNotSet, biometryNotAvailable
        case biometryNotEnrolled, biometryLockout, unknown
        
        var errorDescription: String? {
            switch self {
            case .notAvailable:
                return "Biometric authentication is not available on this device"
            case .notEnrolled:
                return "No biometric data is enrolled. Please set up Face ID or Touch ID in Settings"
            case .failed:
                return "Authentication failed. Please try again"
            case .userCancel:
                return "Authentication cancelled by user"
            case .userFallback:
                return "User chose to use passcode"
            case .biometryNotAvailable:
                return "Biometric authentication is not available"
            case .biometryNotEnrolled:
                return "No biometric authentication is set up"
            case .biometryLockout:
                return "Biometric authentication is locked out"
            case .systemCancel:
                return "System cancelled authentication"
            case .passcodeNotSet:
                return "Passcode is not set on this device"
            case .unknown:
                return "An unknown error occurred"
            }
        }
    }
    
    private let userDefaults = UserDefaults.standard
    private let biometricEnabledKey = "biometric_auth_enabled"
    
    init() {
        loadSettings()
        checkBiometricType()
    }
    
    func checkBiometricType() {
        let context = LAContext()
        var error: NSError?
        
        // Check if biometric authentication is available
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            biometricType = .none
            isEnabled = false
            saveSettings()
            return
        }
        
        // Determine the specific biometric type
        switch context.biometryType {
        case .none:
            biometricType = .none
        case .touchID:
            biometricType = .touchID
        case .faceID:
            biometricType = .faceID
        @unknown default:
            // Handle potential future biometric types (like Optic ID)
            biometricType = .faceID // Default to Face ID for unknown types
        }
        
        // If biometric type changed to none, disable the setting
        if biometricType == .none && isEnabled {
            isEnabled = false
            saveSettings()
        }
    }
    
    func authenticate(reason: String = "Authenticate to access ChordCrack") async throws {
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"
        context.localizedFallbackTitle = "Use Passcode"
        
        // Check availability again before attempting
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            throw mapNSError(error) ?? AuthError.notAvailable
        }
        
        do {
            let success = try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)
            if !success {
                throw AuthError.failed
            }
        } catch {
            throw mapLAError(error)
        }
    }
    
    func enableBiometricAuth() async throws {
        // First check if biometrics are available
        guard biometricType != .none else {
            throw AuthError.notAvailable
        }
        
        do {
            try await authenticate(reason: "Enable biometric authentication for ChordCrack")
            await MainActor.run {
                isEnabled = true
                saveSettings()
            }
        } catch {
            await MainActor.run {
                isEnabled = false
            }
            throw error
        }
    }
    
    func disableBiometricAuth() {
        isEnabled = false
        saveSettings()
    }
    
    func shouldPromptBiometric() -> Bool {
        return isEnabled && biometricType != .none
    }
    
    func authenticateForAppAccess() async throws {
        guard shouldPromptBiometric() else { return }
        try await authenticate(reason: "Unlock ChordCrack")
    }
    
    private func mapLAError(_ error: Error) -> AuthError {
        guard let laError = error as? LAError else { return .unknown }
        
        switch laError.code {
        case .biometryNotAvailable:
            return .biometryNotAvailable
        case .biometryNotEnrolled:
            return .biometryNotEnrolled
        case .biometryLockout:
            return .biometryLockout
        case .userCancel:
            return .userCancel
        case .userFallback:
            return .userFallback
        case .systemCancel:
            return .systemCancel
        case .passcodeNotSet:
            return .passcodeNotSet
        case .authenticationFailed:
            return .failed
        case .invalidContext:
            return .failed
        case .notInteractive:
            return .systemCancel
        case .touchIDNotAvailable:
            return .biometryNotAvailable
        case .touchIDNotEnrolled:
            return .biometryNotEnrolled
        case .touchIDLockout:
            return .biometryLockout
        case .appCancel:
            return .systemCancel
        @unknown default:
            return .unknown
        }
    }
    
    private func mapNSError(_ error: NSError?) -> AuthError? {
        guard let error = error else { return nil }
        
        switch error.code {
        case Int(kLAErrorBiometryNotAvailable):
            return .biometryNotAvailable
        case Int(kLAErrorBiometryNotEnrolled):
            return .biometryNotEnrolled
        case Int(kLAErrorPasscodeNotSet):
            return .passcodeNotSet
        case Int(kLAErrorTouchIDNotAvailable):
            return .biometryNotAvailable
        case Int(kLAErrorTouchIDNotEnrolled):
            return .biometryNotEnrolled
        case Int(kLAErrorTouchIDLockout):
            return .biometryLockout
        default:
            return .notAvailable
        }
    }
    
    private func loadSettings() {
        isEnabled = userDefaults.bool(forKey: biometricEnabledKey)
    }
    
    private func saveSettings() {
        userDefaults.set(isEnabled, forKey: biometricEnabledKey)
        userDefaults.synchronize()
    }
}
