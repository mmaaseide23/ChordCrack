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
            case .none: return "None"
            case .touchID: return "Touch ID"
            case .faceID: return "Face ID"
            case .opticID: return "Optic ID"
            }
        }
        
        var icon: String {
            switch self {
            case .none: return "lock"
            case .touchID: return "touchid"
            case .faceID: return "faceid"
            case .opticID: return "opticid"
            }
        }
    }
    
    enum AuthError: LocalizedError {
        case notAvailable, notEnrolled, failed, userCancel, userFallback
        case systemCancel, passcodeNotSet, biometryNotAvailable
        case biometryNotEnrolled, biometryLockout, unknown
        
        var errorDescription: String? {
            switch self {
            case .notAvailable: return "Biometric authentication is not available on this device"
            case .notEnrolled: return "No biometric data is enrolled. Please set up Face ID or Touch ID in Settings"
            case .failed: return "Authentication failed. Please try again"
            case .userCancel: return "Authentication cancelled by user"
            case .userFallback: return "User chose to use passcode"
            default: return "An unknown error occurred"
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
        
        // Use deviceOwnerAuthenticationWithBiometrics for broader compatibility
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            biometricType = .none
            return
        }
        
        if #available(iOS 11.0, *) {
            switch context.biometryType {
            case .none:
                biometricType = .none
            case .touchID:
                biometricType = .touchID
            case .faceID:
                biometricType = .faceID
            @unknown default:
                // Handle potential future biometric types
                if #available(iOS 17.0, *) {
                    // Check for Optic ID or other new types in the future
                    biometricType = .none
                } else {
                    biometricType = .none
                }
            }
        } else {
            biometricType = .touchID // Fallback for older iOS versions
        }
    }
    
    func authenticate() async throws {
        let context = LAContext()
        context.localizedCancelTitle = "Use Passcode"
        context.localizedFallbackTitle = "Use Passcode"
        
        let reason = "Authenticate to access ChordCrack"
        
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
            try await authenticate()
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
    
    private func mapLAError(_ error: Error) -> AuthError {
        guard let laError = error as? LAError else { return .unknown }
        
        switch laError.code {
        case .biometryNotAvailable: return .biometryNotAvailable
        case .biometryNotEnrolled: return .biometryNotEnrolled
        case .biometryLockout: return .biometryLockout
        case .userCancel: return .userCancel
        case .userFallback: return .userFallback
        case .systemCancel: return .systemCancel
        case .passcodeNotSet: return .passcodeNotSet
        case .authenticationFailed: return .failed
        default: return .unknown
        }
    }
    
    private func loadSettings() {
        isEnabled = userDefaults.bool(forKey: biometricEnabledKey)
    }
    
    private func saveSettings() {
        userDefaults.set(isEnabled, forKey: biometricEnabledKey)
    }
}
