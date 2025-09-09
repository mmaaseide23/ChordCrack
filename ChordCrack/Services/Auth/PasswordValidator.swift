// PasswordValidator.swift
import Foundation
import SwiftUI

struct PasswordValidator {
    enum ValidationResult {
        case valid
        case tooShort
        case missingUppercase
        case missingLowercase
        case missingNumber
        case missingSpecialChar
        case containsCommonPassword
        
        var errorMessage: String {
            switch self {
            case .valid: return ""
            case .tooShort: return "Password must be at least 8 characters long"
            case .missingUppercase: return "Password must contain at least one uppercase letter"
            case .missingLowercase: return "Password must contain at least one lowercase letter"
            case .missingNumber: return "Password must contain at least one number"
            case .missingSpecialChar: return "Password must contain at least one special character (!@#$%^&*)"
            case .containsCommonPassword: return "Please choose a less common password"
            }
        }
        
        var isValid: Bool { return self == .valid }
    }
    
    static func validate(_ password: String) -> ValidationResult {
        guard password.count >= 8 else { return .tooShort }
        
        let hasUppercase = password.rangeOfCharacter(from: .uppercaseLetters) != nil
        let hasLowercase = password.rangeOfCharacter(from: .lowercaseLetters) != nil
        let hasNumber = password.rangeOfCharacter(from: .decimalDigits) != nil
        let specialCharacters = CharacterSet(charactersIn: "!@#$%^&*()_+-=[]{}|;:,.<>?")
        let hasSpecialChar = password.rangeOfCharacter(from: specialCharacters) != nil
        
        guard hasUppercase else { return .missingUppercase }
        guard hasLowercase else { return .missingLowercase }
        guard hasNumber else { return .missingNumber }
        guard hasSpecialChar else { return .missingSpecialChar }
        
        if commonPasswords.contains(password.lowercased()) {
            return .containsCommonPassword
        }
        
        return .valid
    }
    
    static func getStrengthScore(_ password: String) -> (score: Int, description: String) {
        var score = 0
        
        if password.count >= 8 { score += 1 }
        if password.count >= 12 { score += 1 }
        if password.rangeOfCharacter(from: .uppercaseLetters) != nil { score += 1 }
        if password.rangeOfCharacter(from: .lowercaseLetters) != nil { score += 1 }
        if password.rangeOfCharacter(from: .decimalDigits) != nil { score += 1 }
        let specialChars = CharacterSet(charactersIn: "!@#$%^&*()_+-=[]{}|;:,.<>?")
        if password.rangeOfCharacter(from: specialChars) != nil { score += 1 }
        
        score = max(0, min(6, score))
        
        let descriptions = ["Very Weak", "Weak", "Fair", "Good", "Strong", "Very Strong", "Excellent"]
        return (score, descriptions[score])
    }
    
    private static let commonPasswords: Set<String> = [
        "password", "123456", "123456789", "12345678", "12345",
        "1234567", "1234567890", "qwerty", "abc123", "million",
        "password1", "123123", "admin", "welcome", "login"
    ]
}

struct PasswordStrengthIndicator: View {
    let password: String
    
    var body: some View {
        let strength = PasswordValidator.getStrengthScore(password)
        
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Password Strength:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(strength.description)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(strengthColor(strength.score))
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 4)
                        .cornerRadius(2)
                    
                    Rectangle()
                        .fill(strengthColor(strength.score))
                        .frame(width: geometry.size.width * strengthProgress(strength.score), height: 4)
                        .cornerRadius(2)
                        .animation(.easeInOut(duration: 0.3), value: strength.score)
                }
            }
            .frame(height: 4)
        }
    }
    
    private func strengthColor(_ score: Int) -> Color {
        switch score {
        case 0...1: return Color.red
        case 2...3: return Color.orange
        case 4...5: return Color.yellow
        case 6: return Color.green
        default: return Color.green
        }
    }
    
    private func strengthProgress(_ score: Int) -> Double {
        return Double(score) / 6.0
    }
}
