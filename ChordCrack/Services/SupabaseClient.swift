import Foundation
import Combine

// MARK: - Supabase Client Configuration
class SupabaseClient: ObservableObject {
    static let shared = SupabaseClient()
    
    private let supabaseURL = "https://iyswoogivbvkqpdwdeuv.supabase.co"
    private let supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Iml5c3dvb2dpdmJ2a3FwZHdkZXV2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTcwODA3ODUsImV4cCI6MjA3MjY1Njc4NX0.boizWCVbtzpldr4g4oX0ZcbMpZTBg67aWpkmQ-_-t_A"
    
    @Published var session: AuthSession?
    @Published var user: AuthUser?
    @Published var isAuthenticated: Bool = false
    
    private init() {
        loadSession()
    }
    
    // MARK: - Authentication Methods
    
    func signUp(email: String, password: String, username: String) async throws -> AuthUser {
        print("📝 Starting sign up for email: \(email), username: \(username)")
        
        let url = URL(string: "\(supabaseURL)/auth/v1/signup")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
        
        let body: [String: Any] = [
            "email": email,
            "password": password,
            "data": [
                "username": username
            ]
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            print("❌ JSON serialization error: \(error)")
            throw AuthError.networkError
        }
        
        print("📤 Sending request to: \(url)")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            print("📥 Response received")
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid response type")
                throw AuthError.networkError
            }
            
            print("📊 Status code: \(httpResponse.statusCode)")
            
            // Print response data for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                print("📄 Response body: \(responseString)")
            }
            
            if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
                do {
                    let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
                    print("✅ Successfully decoded auth response")
                    
                    let session = authResponse.session
                    await updateAuthState(session: session, user: authResponse.user)
                    return authResponse.user
                } catch {
                    print("❌ Decoding error: \(error)")
                    throw AuthError.networkError
                }
            } else {
                do {
                    let errorResponse = try JSONDecoder().decode(AuthErrorResponse.self, from: data)
                    print("❌ Auth error: \(errorResponse.message)")
                    
                    // Handle specific error cases
                    if errorResponse.errorCode == "user_already_exists" {
                        throw AuthError.userAlreadyExists
                    } else {
                        throw AuthError.signUpFailed(errorResponse.message)
                    }
                } catch let decodingError as DecodingError {
                    print("❌ Error parsing error response: \(decodingError)")
                    throw AuthError.signUpFailed("Sign up failed with status \(httpResponse.statusCode)")
                } catch {
                    throw error
                }
            }
        } catch {
            if error is AuthError {
                throw error
            } else {
                print("❌ Network error: \(error)")
                throw AuthError.networkError
            }
        }
    }
    
    func signIn(email: String, password: String) async throws -> AuthUser {
        print("🔓 Starting sign in for email: \(email)")
        
        let url = URL(string: "\(supabaseURL)/auth/v1/token?grant_type=password")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
        
        let body: [String: Any] = [
            "email": email,
            "password": password
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            print("❌ JSON serialization error: \(error)")
            throw AuthError.networkError
        }
        
        print("📤 Sending sign in request to: \(url)")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid response type")
                throw AuthError.networkError
            }
            
            print("📊 Sign in status code: \(httpResponse.statusCode)")
            
            // Print response data for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                print("📄 Sign in response body: \(responseString)")
            }
            
            if httpResponse.statusCode == 200 {
                do {
                    let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
                    print("✅ Successfully signed in")
                    
                    let session = authResponse.session
                    await updateAuthState(session: session, user: authResponse.user)
                    return authResponse.user
                } catch {
                    print("❌ Sign in decoding error: \(error)")
                    throw AuthError.networkError
                }
            } else {
                do {
                    let errorResponse = try JSONDecoder().decode(AuthErrorResponse.self, from: data)
                    print("❌ Sign in auth error: \(errorResponse.message)")
                    throw AuthError.signInFailed(errorResponse.message)
                } catch {
                    print("❌ Error parsing sign in error response: \(error)")
                    throw AuthError.signInFailed("Sign in failed with status \(httpResponse.statusCode)")
                }
            }
        } catch {
            if error is AuthError {
                throw error
            } else {
                print("❌ Sign in network error: \(error)")
                throw AuthError.networkError
            }
        }
    }
    
    func signOut() async throws {
        guard let session = session else { return }
        
        let url = URL(string: "\(supabaseURL)/auth/v1/logout")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        
        let (_, _) = try await URLSession.shared.data(for: request)
        
        await clearAuthState()
    }
    
    func refreshSession() async throws {
        guard let session = session else {
            throw AuthError.noSession
        }
        
        let url = URL(string: "\(supabaseURL)/auth/v1/token?grant_type=refresh_token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
        
        let body: [String: Any] = [
            "refresh_token": session.refreshToken
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            await clearAuthState()
            throw AuthError.sessionExpired
        }
        
        let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
        let newSession = authResponse.session
        await updateAuthState(session: newSession, user: authResponse.user)
    }
    
    // MARK: - Database Operations
    
    func performRequest<T: Codable>(
        method: String = "GET",
        path: String,
        body: [String: Any]? = nil,
        responseType: T.Type
    ) async throws -> T {
        let url = URL(string: "\(supabaseURL)/rest/v1\(path)")!
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        
        if let session = session {
            request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        } else {
            request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
        }
        
        if let body = body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              200...299 ~= httpResponse.statusCode else {
            print("❌ Database request failed with status: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
            throw AuthError.networkError
        }
        
        return try JSONDecoder().decode(T.self, from: data)
    }
    
    func performVoidRequest(
        method: String = "GET",
        path: String,
        body: [String: Any]? = nil
    ) async throws {
        let url = URL(string: "\(supabaseURL)/rest/v1\(path)")!
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        
        if let currentSession = session {
            request.setValue("Bearer \(currentSession.accessToken)", forHTTPHeaderField: "Authorization")
        } else {
            request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
        }
        
        if let body = body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              200...299 ~= httpResponse.statusCode else {
            print("❌ Database void request failed with status: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
            throw AuthError.networkError
        }
    }
    
    // MARK: - Private Methods
    
    @MainActor
    private func updateAuthState(session: AuthSession, user: AuthUser) {
        self.session = session
        self.user = user
        self.isAuthenticated = true
        saveSession()
    }
    
    @MainActor
    private func clearAuthState() {
        self.session = nil
        self.user = nil
        self.isAuthenticated = false
        UserDefaults.standard.removeObject(forKey: "supabase_session")
        UserDefaults.standard.removeObject(forKey: "supabase_user")
    }
    
    private func saveSession() {
        if let currentSession = session,
           let sessionData = try? JSONEncoder().encode(currentSession) {
            UserDefaults.standard.set(sessionData, forKey: "supabase_session")
        }
        
        if let currentUser = user,
           let userData = try? JSONEncoder().encode(currentUser) {
            UserDefaults.standard.set(userData, forKey: "supabase_user")
        }
    }
    
    private func loadSession() {
        if let sessionData = UserDefaults.standard.data(forKey: "supabase_session"),
           let storedSession = try? JSONDecoder().decode(AuthSession.self, from: sessionData) {
            
            if let userData = UserDefaults.standard.data(forKey: "supabase_user"),
               let storedUser = try? JSONDecoder().decode(AuthUser.self, from: userData) {
                
                Task { @MainActor in
                    self.session = storedSession
                    self.user = storedUser
                    self.isAuthenticated = true
                }
                
                // Check if session needs refresh
                if storedSession.expiresAt < Date() {
                    Task {
                        try? await refreshSession()
                    }
                }
            }
        }
    }
}

// MARK: - Data Models

struct AuthResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    let expiresAt: Int
    let tokenType: String
    let user: AuthUser
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case expiresAt = "expires_at"
        case tokenType = "token_type"
        case user
    }
    
    // Convert to AuthSession
    var session: AuthSession {
        return AuthSession(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresIn: expiresIn,
            expiresAt: Date(timeIntervalSince1970: TimeInterval(expiresAt)),
            tokenType: tokenType
        )
    }
}

struct AuthSession: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    let expiresAt: Date
    let tokenType: String
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case tokenType = "token_type"
        case expiresAt = "expires_at"
    }
    
    init(accessToken: String, refreshToken: String, expiresIn: Int, expiresAt: Date, tokenType: String) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresIn = expiresIn
        self.expiresAt = expiresAt
        self.tokenType = tokenType
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        accessToken = try container.decode(String.self, forKey: .accessToken)
        refreshToken = try container.decode(String.self, forKey: .refreshToken)
        expiresIn = try container.decode(Int.self, forKey: .expiresIn)
        tokenType = try container.decode(String.self, forKey: .tokenType)
        
        if let expiresAtTimestamp = try? container.decode(Int.self, forKey: .expiresAt) {
            expiresAt = Date(timeIntervalSince1970: TimeInterval(expiresAtTimestamp))
        } else {
            expiresAt = Date().addingTimeInterval(TimeInterval(expiresIn))
        }
    }
}

struct AuthUser: Codable {
    let id: String
    let email: String
    let userMetadata: UserMetadata
    
    enum CodingKeys: String, CodingKey {
        case id, email
        case userMetadata = "user_metadata"
    }
}

struct UserMetadata: Codable {
    let username: String
}

struct AuthErrorResponse: Codable {
    let msg: String
    let errorCode: String?
    let code: Int?
    
    // Computed property to match our usage
    var message: String { msg }
    
    enum CodingKeys: String, CodingKey {
        case msg
        case errorCode = "error_code"
        case code
    }
}

enum AuthError: Error, LocalizedError {
    case signUpFailed(String)
    case signInFailed(String)
    case networkError
    case noSession
    case sessionExpired
    case userAlreadyExists
    
    var errorDescription: String? {
        switch self {
        case .signUpFailed(let message):
            return message
        case .signInFailed(let message):
            return message
        case .networkError:
            return "Network connection error"
        case .noSession:
            return "No active session"
        case .sessionExpired:
            return "Session expired"
        case .userAlreadyExists:
            return "An account with this email already exists. Try signing in instead."
        }
    }
}
