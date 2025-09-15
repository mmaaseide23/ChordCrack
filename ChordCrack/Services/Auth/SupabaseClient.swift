import Foundation
import Supabase
import Combine
import AuthenticationServices

class SupabaseClient: ObservableObject {
    static let shared = SupabaseClient()
    
    private let client: Supabase.SupabaseClient
    private let supabaseURL: URL
    private let supabaseKey: String
    
    @Published var isAuthenticated = false
    @Published var user: User?
    
    init() {
        let config = ConfigManager.shared
        let supabaseURLString = config.supabaseURL
        let supabaseAnonKey = config.supabaseAnonKey
        
        guard let url = URL(string: supabaseURLString) else {
            fatalError("Invalid Supabase URL")
        }
        
        self.supabaseURL = url
        self.supabaseKey = supabaseAnonKey
        
        self.client = Supabase.SupabaseClient(
            supabaseURL: url,
            supabaseKey: supabaseAnonKey
        )
        
        // Check for existing session
        Task {
            await checkSession()
        }
    }
    
    private func checkSession() async {
        do {
            let session = try await client.auth.session
            
            print("🔍 SupabaseClient.checkSession: Found existing session for user: \(session.user.id.uuidString)")
            
            // ALWAYS fetch the actual username from database for existing sessions
            let actualUsername = await fetchUsernameFromDatabase(userId: session.user.id.uuidString)
            
            print("🔍 SupabaseClient.checkSession: Database username: \(actualUsername ?? "nil")")
            
            await MainActor.run {
                self.isAuthenticated = true
                
                // Use database username if available, otherwise keep as nil to force re-fetch
                if let actualUsername = actualUsername, !actualUsername.isEmpty {
                    self.user = User(
                        id: session.user.id.uuidString,
                        email: session.user.email ?? "",
                        userMetadata: UserMetadata(username: actualUsername)
                    )
                    print("🔍 SupabaseClient.checkSession: Set user with username: \(actualUsername)")
                } else {
                    // Don't set a default username - let APIService handle it
                    print("🔍 SupabaseClient.checkSession: No username found, will fetch later")
                }
            }
        } catch {
            await MainActor.run {
                self.isAuthenticated = false
                self.user = nil
            }
        }
    }
    
    // Helper function to fetch username from database
    func fetchUsernameFromDatabase(userId: String) async -> String? {
        do {
            struct UsernameResponse: Codable {
                let username: String
            }
            
            let response: [UsernameResponse] = try await performRequest(
                method: "GET",
                path: "user_stats?id=eq.\(userId)&select=username",
                responseType: [UsernameResponse].self
            )
            
            let username = response.first?.username
            print("📊 fetchUsernameFromDatabase: Found username '\(username ?? "nil")' for user \(userId)")
            return username
        } catch {
            print("❌ fetchUsernameFromDatabase: Failed to fetch username: \(error)")
            return nil
        }
    }
    
    @MainActor
    private func updateUser(from authUser: Supabase.User, overrideUsername: String? = nil) {
        print("🔄 updateUser called with override: \(overrideUsername ?? "nil")")
        
        // ALWAYS use the override username if provided
        let username: String
        if let overrideUsername = overrideUsername, !overrideUsername.isEmpty {
            username = overrideUsername
            print("🔄 updateUser: Using override username: \(username)")
        } else {
            // Generate a temporary placeholder - this should be replaced by APIService
            username = "TempUser\(Int.random(in: 1000...9999))"
            print("⚠️ updateUser: No override provided, using temp: \(username)")
        }
        
        self.user = User(
            id: authUser.id.uuidString,
            email: authUser.email ?? "",
            userMetadata: UserMetadata(username: username)
        )
    }
    
    // MARK: - Authentication Methods
    
    func signUp(email: String, password: String, username: String) async throws -> User {
        let metadata: [String: AnyJSON] = ["username": .string(username)]
        
        do {
            let response = try await client.auth.signUp(
                email: email,
                password: password,
                data: metadata
            )
            
            // Create user model with the provided username
            let user = User(
                id: response.user.id.uuidString,
                email: email,
                userMetadata: UserMetadata(username: username)
            )
            
            await MainActor.run {
                self.user = user
                self.isAuthenticated = true
            }
            
            return user
            
        } catch {
            print("Supabase signup error: \(error)")
            
            if let supabaseError = error as? AuthError {
                switch supabaseError {
                case .weakPassword:
                    throw APIError.invalidCredentials
                default:
                    throw APIError.networkError
                }
            } else {
                throw APIError.networkError
            }
        }
    }
    
    func signIn(email: String, password: String) async throws -> User {
        do {
            let response = try await client.auth.signIn(
                email: email,
                password: password
            )
            
            // ALWAYS fetch the actual username from database for email/password sign in
            let actualUsername = await fetchUsernameFromDatabase(userId: response.user.id.uuidString)
            
            await MainActor.run {
                if let actualUsername = actualUsername {
                    self.user = User(
                        id: response.user.id.uuidString,
                        email: response.user.email ?? "",
                        userMetadata: UserMetadata(username: actualUsername)
                    )
                } else {
                    // This shouldn't happen for existing users
                    self.user = User(
                        id: response.user.id.uuidString,
                        email: response.user.email ?? "",
                        userMetadata: UserMetadata(username: "User")
                    )
                }
                self.isAuthenticated = true
            }
            
            guard let user = self.user else {
                throw APIError.invalidResponse
            }
            
            return user
            
        } catch {
            print("Supabase signin error: \(error)")
            
            if let supabaseError = error as? AuthError {
                print("Supabase auth error: \(supabaseError)")
                throw APIError.invalidCredentials
            } else {
                throw APIError.networkError
            }
        }
    }
    
    @MainActor
    func signInWithApple() async throws -> User {
        print("🍎 SupabaseClient.signInWithApple: Starting...")
        
        return try await withCheckedThrowingContinuation { continuation in
            let provider = ASAuthorizationAppleIDProvider()
            let request = provider.createRequest()
            request.requestedScopes = [.fullName, .email]
            
            let authorizationController = ASAuthorizationController(authorizationRequests: [request])
            let delegate = SupabaseAppleSignInDelegate(client: client) { result in
                continuation.resume(with: result)
            }
            
            // Store delegate to prevent deallocation
            SupabaseAppleSignInDelegateStore.shared.currentDelegate = delegate
            
            authorizationController.delegate = delegate
            authorizationController.presentationContextProvider = delegate
            authorizationController.performRequests()
        }
    }
    
    func signOut() async throws {
        try await client.auth.signOut()
        
        await MainActor.run {
            self.isAuthenticated = false
            self.user = nil
        }
    }
    
    // MARK: - Database Methods (unchanged)
    
    func performRequest<T: Decodable>(
        method: String = "GET",
        path: String,
        body: [String: Any]? = nil,
        responseType: T.Type,
        headers: [String: String] = [:]
    ) async throws -> T {
        do {
            let session = try await client.auth.session
            
            let baseURL = supabaseURL.appendingPathComponent("rest/v1")
            let components = path.split(separator: "?", maxSplits: 1)
            let tableName = String(components[0])
            let queryString = components.count > 1 ? "?" + String(components[1]) : ""
            let fullURL = baseURL.appendingPathComponent(tableName).absoluteString + queryString
            
            guard let url = URL(string: fullURL) else {
                throw APIError.invalidResponse
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = method
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
            request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
            
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
            
            if method == "POST" {
                request.setValue("return=representation", forHTTPHeaderField: "Prefer")
            }
            
            if let body = body {
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
            }
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode >= 400 {
                print("HTTP Error \(httpResponse.statusCode) for \(fullURL)")
                print("Response: \(String(data: data, encoding: .utf8) ?? "")")
                throw APIError.networkError
            }
            
            return try JSONDecoder().decode(T.self, from: data)
            
        } catch {
            if error is AuthError {
                throw APIError.notAuthenticated
            }
            throw error
        }
    }
    
    func performVoidRequest(
        method: String = "POST",
        path: String,
        body: [String: Any],
        headers: [String: String] = [:]
    ) async throws {
        do {
            let session = try await client.auth.session
            
            let baseURL = supabaseURL.appendingPathComponent("rest/v1")
            let components = path.split(separator: "?", maxSplits: 1)
            let tableName = String(components[0])
            let queryString = components.count > 1 ? "?" + String(components[1]) : ""
            let fullURL = baseURL.appendingPathComponent(tableName).absoluteString + queryString
            
            guard let url = URL(string: fullURL) else {
                throw APIError.invalidResponse
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = method
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
            request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
            
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
            
            if method == "POST" {
                request.setValue("return=representation", forHTTPHeaderField: "Prefer")
            }
            
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode >= 400 {
                print("HTTP Error \(httpResponse.statusCode) for \(fullURL)")
                print("Response: \(String(data: data, encoding: .utf8) ?? "")")
                throw APIError.networkError
            }
            
        } catch {
            if error is AuthError {
                throw APIError.notAuthenticated
            }
            throw error
        }
    }
}

// MARK: - Delegate Storage for Apple Sign-In

private class SupabaseAppleSignInDelegateStore {
    static let shared = SupabaseAppleSignInDelegateStore()
    var currentDelegate: SupabaseAppleSignInDelegate?
    
    private init() {}
    
    func clearDelegate() {
        currentDelegate = nil
    }
}

private class SupabaseAppleSignInDelegate: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private let client: Supabase.SupabaseClient
    private let completion: (Result<User, Error>) -> Void
    
    init(client: Supabase.SupabaseClient, completion: @escaping (Result<User, Error>) -> Void) {
        self.client = client
        self.completion = completion
        super.init()
        print("🍎 SupabaseAppleSignInDelegate initialized")
    }
    
    deinit {
        print("🍎 SupabaseAppleSignInDelegate deinitialized")
    }
    
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        if let windowScene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            if let keyWindow = windowScene.windows.first(where: { $0.isKeyWindow }) {
                return keyWindow
            }
            if let firstWindow = windowScene.windows.first {
                return firstWindow
            }
        }
        
        return UIWindow()
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        print("🍎 Apple authorization completed, processing with Supabase...")
        
        defer {
            SupabaseAppleSignInDelegateStore.shared.clearDelegate()
        }
        
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            print("❌ Invalid Apple credential")
            completion(.failure(APIError.invalidResponse))
            return
        }
        
        Task {
            do {
                guard let identityTokenData = appleIDCredential.identityToken,
                      let identityToken = String(data: identityTokenData, encoding: .utf8) else {
                    print("❌ No identity token")
                    throw APIError.invalidResponse
                }
                
                print("🍎 Identity token retrieved")
                
                // Use Supabase's Apple Sign-In with the identity token
                let session = try await client.auth.signInWithIdToken(
                    credentials: .init(
                        provider: .apple,
                        idToken: identityToken
                    )
                )
                
                print("🍎 Supabase authentication successful for user: \(session.user.id.uuidString)")
                
                // Try to fetch the actual username from database
                let actualUsername = await SupabaseClient.shared.fetchUsernameFromDatabase(
                    userId: session.user.id.uuidString
                )
                
                print("🍎 Database lookup result: \(actualUsername ?? "nil")")
                
                // DON'T SET ANY USERNAME HERE - let APIService handle it
                // Create a minimal user object that will be updated by APIService
                let user = User(
                    id: session.user.id.uuidString,
                    email: session.user.email ?? appleIDCredential.email ?? "\(session.user.id.uuidString)@privaterelay.appleid.com",
                    userMetadata: UserMetadata(username: actualUsername ?? "PendingUsername")
                )
                
                print("🍎 Created user object with username: \(user.userMetadata.username)")
                
                // Update SupabaseClient state
                await MainActor.run {
                    SupabaseClient.shared.user = user
                    SupabaseClient.shared.isAuthenticated = true
                    print("🍎 SupabaseClient state updated")
                }
                
                completion(.success(user))
                
            } catch {
                print("❌ Supabase Apple authentication failed: \(error)")
                completion(.failure(APIError.networkError))
            }
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        print("❌ Apple authorization failed: \(error)")
        
        defer {
            SupabaseAppleSignInDelegateStore.shared.clearDelegate()
        }
        
        if let authError = error as? ASAuthorizationError {
            switch authError.code {
            case .canceled:
                completion(.failure(APIError.invalidCredentials))
            case .failed:
                completion(.failure(APIError.networkError))
            case .invalidResponse:
                completion(.failure(APIError.invalidResponse))
            case .notHandled:
                completion(.failure(APIError.networkError))
            case .unknown:
                completion(.failure(APIError.invalidResponse))
            case .notInteractive:
                completion(.failure(APIError.networkError))
            @unknown default:
                completion(.failure(APIError.networkError))
            }
        } else {
            completion(.failure(error))
        }
    }
}
