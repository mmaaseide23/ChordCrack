import SwiftUI

/// Enhanced user onboarding with real email/password authentication
struct UsernameSetupView: View {
    @EnvironmentObject var userDataManager: UserDataManager
    @State private var inputUsername = ""
    @State private var inputEmail = ""
    @State private var inputPassword = ""
    @State private var isSignUp = true // Toggle between sign up and sign in
    @State private var showingPassword = false
    @State private var errorMessage = ""
    
    var body: some View {
        ZStack {
            ColorTheme.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                appBrandingSection
                
                Spacer()
                
                userInputSection
                
                Spacer()
                
                featureHighlightsSection
            }
            .padding(.horizontal, 24)
        }
    }
    
    // MARK: - View Components
    
    private var appBrandingSection: some View {
        VStack(spacing: 24) {
            ChordCrackLogo(size: .hero, style: .iconOnly)
            
            VStack(spacing: 8) {
                Text("ChordCrack")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(Color.white)
                
                Text(isSignUp ? "Create your account" : "Welcome back")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(ColorTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    private var userInputSection: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                Text(isSignUp ? "Create Your Account" : "Sign In")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(ColorTheme.textPrimary)
                
                Text(isSignUp ?
                     "Save your progress and compete with players worldwide" :
                     "Access your saved progress and continue your journey")
                    .font(.system(size: 14))
                    .foregroundColor(ColorTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            
            VStack(spacing: 16) {
                // Username field (only for sign up)
                if isSignUp {
                    HStack(spacing: 12) {
                        Image(systemName: "person.fill")
                            .font(.system(size: 16))
                            .foregroundColor(ColorTheme.textTertiary)
                            .frame(width: 20)
                        
                        TextField("Username", text: $inputUsername)
                            .font(.system(size: 16))
                            .foregroundColor(ColorTheme.textPrimary)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(inputFieldBackground)
                }
                
                // Email field
                HStack(spacing: 12) {
                    Image(systemName: "envelope.fill")
                        .font(.system(size: 16))
                        .foregroundColor(ColorTheme.textTertiary)
                        .frame(width: 20)
                    
                    TextField("Email", text: $inputEmail)
                        .font(.system(size: 16))
                        .foregroundColor(ColorTheme.textPrimary)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(inputFieldBackground)
                
                // Password field
                HStack(spacing: 12) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 16))
                        .foregroundColor(ColorTheme.textTertiary)
                        .frame(width: 20)
                    
                    if showingPassword {
                        TextField(isSignUp ? "Password (6+ characters)" : "Password", text: $inputPassword)
                            .font(.system(size: 16))
                            .foregroundColor(ColorTheme.textPrimary)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    } else {
                        SecureField(isSignUp ? "Password (6+ characters)" : "Password", text: $inputPassword)
                            .font(.system(size: 16))
                            .foregroundColor(ColorTheme.textPrimary)
                    }
                    
                    Button(action: { showingPassword.toggle() }) {
                        Image(systemName: showingPassword ? "eye.slash.fill" : "eye.fill")
                            .font(.system(size: 14))
                            .foregroundColor(ColorTheme.textTertiary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(inputFieldBackground)
                
                // Error message
                if !errorMessage.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(ColorTheme.error)
                            .font(.caption)
                        
                        Text(errorMessage)
                            .font(.system(size: 12))
                            .foregroundColor(ColorTheme.error)
                        
                        Spacer()
                    }
                    .transition(.opacity)
                }
                
                actionButton
                
                // Toggle between sign up and sign in
                Button(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up") {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isSignUp.toggle()
                        errorMessage = ""
                        inputPassword = ""
                        if isSignUp {
                            inputUsername = ""
                        }
                    }
                }
                .font(.system(size: 15))
                .foregroundColor(ColorTheme.primaryGreen)
            }
        }
    }
    
    private var inputFieldBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(ColorTheme.secondaryBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(borderColor, lineWidth: 1.5)
            )
    }
    
    private var borderColor: Color {
        if !errorMessage.isEmpty {
            return ColorTheme.error
        } else if canSubmit && isValidInput {
            return ColorTheme.primaryGreen.opacity(0.6)
        } else if !inputEmail.isEmpty || !inputPassword.isEmpty {
            return ColorTheme.primaryGreen.opacity(0.3)
        } else {
            return ColorTheme.textTertiary.opacity(0.2)
        }
    }
    
    private var actionButton: some View {
        Button(action: handleAuthentication) {
            HStack(spacing: 12) {
                if userDataManager.isLoading {
                    ProgressView()
                        .scaleEffect(0.9)
                        .tint(.white)
                }
                
                Text(userDataManager.isLoading ?
                     (isSignUp ? "Creating Account..." : "Signing In...") :
                     (isSignUp ? "Create Account" : "Sign In"))
                    .font(.system(size: 17, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(buttonBackground)
        }
        .disabled(!canSubmit)
        .scaleEffect(canSubmit ? 1.0 : 0.95)
        .animation(.easeInOut(duration: 0.2), value: canSubmit)
    }
    
    private var buttonBackground: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(canSubmit ?
                  LinearGradient(colors: [ColorTheme.primaryGreen, ColorTheme.lightGreen],
                                startPoint: .leading, endPoint: .trailing) :
                  LinearGradient(colors: [ColorTheme.textTertiary.opacity(0.5), ColorTheme.textTertiary.opacity(0.5)],
                                startPoint: .leading, endPoint: .trailing))
    }
    
    private var featureHighlightsSection: some View {
        VStack(spacing: 16) {
            HStack(spacing: 24) {
                FeatureHighlight(
                    icon: "icloud.fill",
                    title: "Cloud Sync"
                )
                
                FeatureHighlight(
                    icon: "shield.fill",
                    title: "Secure Login"
                )
                
                FeatureHighlight(
                    icon: "person.2.fill",
                    title: "Global Leaderboard"
                )
            }
            
            VStack(spacing: 4) {
                Text("Your progress is saved securely across all devices")
                    .font(.system(size: 12))
                    .foregroundColor(ColorTheme.textTertiary)
                
                HStack(spacing: 16) {
                    Label("Encrypted", systemImage: "lock.fill")
                        .font(.system(size: 10))
                        .foregroundColor(ColorTheme.textTertiary.opacity(0.8))
                    
                    Label("Cross-device", systemImage: "iphone")
                        .font(.system(size: 10))
                        .foregroundColor(ColorTheme.textTertiary.opacity(0.8))
                }
            }
        }
        .padding(.bottom, 32)
    }
    
    // MARK: - Helper Methods
    
    private var isValidInput: Bool {
        if isSignUp {
            return isValidUsername && isValidEmail && isValidPassword
        } else {
            return isValidEmail && !inputPassword.isEmpty
        }
    }
    
    private var isValidUsername: Bool {
        let trimmed = inputUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count >= 3 &&
               trimmed.count <= 20 &&
               trimmed.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" }
    }
    
    private var isValidEmail: Bool {
        let emailRegex = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return inputEmail.range(of: emailRegex, options: .regularExpression) != nil
    }
    
    private var isValidPassword: Bool {
        return inputPassword.count >= 6
    }
    
    private var canSubmit: Bool {
        isValidInput && !userDataManager.isLoading
    }
    
    private func handleAuthentication() {
        let trimmedEmail = inputEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUsername = inputUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard canSubmit else { return }
        
        errorMessage = ""
        
        // Validate input
        if isSignUp && !isValidUsername {
            errorMessage = "Username must be 3-20 characters (letters, numbers, - or _ only)"
            return
        }
        
        if !isValidEmail {
            errorMessage = "Please enter a valid email address"
            return
        }
        
        if isSignUp && !isValidPassword {
            errorMessage = "Password must be at least 6 characters"
            return
        }
        
        Task {
            do {
                if isSignUp {
                    try await userDataManager.createAccount(
                        email: trimmedEmail,
                        password: inputPassword,
                        username: trimmedUsername
                    )
                } else {
                    try await userDataManager.signIn(
                        email: trimmedEmail,
                        password: inputPassword
                    )
                }
                
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

struct FeatureHighlight: View {
    let icon: String
    let title: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(ColorTheme.primaryGreen)
            
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(ColorTheme.textSecondary)
        }
    }
}

#Preview {
    UsernameSetupView()
        .environmentObject(UserDataManager())
}
