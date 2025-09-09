// SecureErrorHandler.swift
import Foundation

class SecureErrorHandler {
    static func userFriendlyMessage(for error: Error) -> String {
        #if DEBUG
        print("Technical error: \(error)")
        #endif
        
        // Handle BiometricAuthManager.AuthError
        if let authError = error as? BiometricAuthManager.AuthError {
            return authError.errorDescription ?? "Authentication failed"
        }
         
        // Handle URLError
        if let urlError = error as? URLError {
            return handleURLError(urlError)
        }
        
        // Handle common error patterns
        let errorString = error.localizedDescription.lowercased()
        
        if errorString.contains("database") || errorString.contains("sql") {
            return "We're experiencing technical difficulties. Please try again later."
        }
        
        if errorString.contains("network") || errorString.contains("connection") {
            return "Please check your internet connection and try again."
        }
        
        if errorString.contains("invalid credentials") || errorString.contains("unauthorized") {
            return "The email or password you entered is incorrect."
        }
        
        if errorString.contains("user already exists") || errorString.contains("already registered") {
            return "An account with this email already exists. Try signing in instead."
        }
        
        if errorString.contains("not authenticated") || errorString.contains("sign in") {
            return "Please sign in to continue."
        }
        
        return "Something went wrong. Please try again or contact support if the problem continues."
    }
    
    private static func handleURLError(_ error: URLError) -> String {
        switch error.code {
        case .notConnectedToInternet:
            return "No internet connection. Please check your network settings."
        case .timedOut:
            return "The request timed out. Please try again."
        case .cannotFindHost, .cannotConnectToHost:
            return "Unable to connect to our servers. Please try again later."
        case .networkConnectionLost:
            return "Connection lost. Please check your network and try again."
        default:
            return "Network error. Please check your connection and try again."
        }
    }
}
