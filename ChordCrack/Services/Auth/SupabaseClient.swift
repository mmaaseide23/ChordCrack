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
            await MainActor.run {
                self.isAuthenticated = true
                self.updateUser(from: session.user)
            }
        } catch {
            await MainActor.run {
                self.isAuthenticated = false
                self.user = nil
            }
        }
    }
    
    @MainActor
    private func updateUser(from authUser: Supabase.User) {
        var username = "User"
        
        // Handle the userMetadata properly - it's [String: AnyJSON]
        if let usernameJSON = authUser.userMetadata["username"],
           case let .string(usernameValue) = usernameJSON {
            username = usernameValue
        } else if let usernameJSON = authUser.userMetadata["full_name"],
                  case let .string(fullNameValue) = usernameJSON {
            username = fullNameValue
        } else if let email = authUser.email {
            username = email.components(separatedBy: "@").first ?? "User"
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
            
            // Create user model
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
            // Log the actual error for debugging
            print("Supabase signup error: \(error)")
            
            // Handle specific Supabase errors
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
            
            await MainActor.run {
                self.updateUser(from: response.user)
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
                // Handle based on error description or use generic handling
                throw APIError.invalidCredentials
            } else {
                throw APIError.networkError
            }
        }
    }
    
    @MainActor
    func signInWithApple() async throws -> User {
        print("Starting Supabase Apple OAuth...")
        
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
    
    // MARK: - Database Methods
    
    func performRequest<T: Decodable>(
        method: String = "GET",
        path: String,
        body: [String: Any]? = nil,
        responseType: T.Type,
        headers: [String: String] = [:]
    ) async throws -> T {
        // Ensure we have a valid session
        do {
            let session = try await client.auth.session
            
            // Build the full URL
            let baseURL = supabaseURL.appendingPathComponent("rest/v1")
            
            // Parse the path correctly - split table name from query params
            let components = path.split(separator: "?", maxSplits: 1)
            let tableName = String(components[0])
            let queryString = components.count > 1 ? "?" + String(components[1]) : ""
            
            // Build URL properly
            let fullURL = baseURL.appendingPathComponent(tableName).absoluteString + queryString
            
            guard let url = URL(string: fullURL) else {
                throw APIError.invalidResponse
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = method
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
            request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
            
            // Add any additional headers
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
            
            // For Supabase, we need this header for POST requests
            if method == "POST" {
                request.setValue("return=representation", forHTTPHeaderField: "Prefer")
            }
            
            if let body = body {
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
            }
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // Check for HTTP errors
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode >= 400 {
                print("HTTP Error \(httpResponse.statusCode) for \(fullURL)")
                print("Response: \(String(data: data, encoding: .utf8) ?? "")")
                
                // Try to parse error message from Supabase
                if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let message = errorJson["message"] as? String {
                    print("Supabase error message: \(message)")
                }
                
                throw APIError.networkError
            }
            
            // Debug successful responses
            if let httpResponse = response as? HTTPURLResponse {
                print("Success \(httpResponse.statusCode) for \(fullURL)")
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
        // Ensure we have a valid session
        do {
            let session = try await client.auth.session
            
            // Build the full URL
            let baseURL = supabaseURL.appendingPathComponent("rest/v1")
            
            // Parse the path correctly
            let components = path.split(separator: "?", maxSplits: 1)
            let tableName = String(components[0])
            let queryString = components.count > 1 ? "?" + String(components[1]) : ""
            
            // Build URL properly
            let fullURL = baseURL.appendingPathComponent(tableName).absoluteString + queryString
            
            guard let url = URL(string: fullURL) else {
                throw APIError.invalidResponse
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = method
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
            request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
            
            // Add any additional headers
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
            
            // For Supabase POST requests
            if method == "POST" {
                request.setValue("return=representation", forHTTPHeaderField: "Prefer")
            }
            
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // Check for HTTP errors
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode >= 400 {
                print("HTTP Error \(httpResponse.statusCode) for \(fullURL)")
                print("Response: \(String(data: data, encoding: .utf8) ?? "")")
                
                // Try to parse error message from Supabase
                if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let message = errorJson["message"] as? String {
                    print("Supabase error message: \(message)")
                }
                
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
        print("SupabaseAppleSignInDelegate initialized")
    }
    
    deinit {
        print("SupabaseAppleSignInDelegate deinitialized")
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
        print("Apple authorization completed, processing with Supabase...")
        
        defer {
            SupabaseAppleSignInDelegateStore.shared.clearDelegate()
        }
        
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            print("ERROR: Invalid Apple credential")
            completion(.failure(APIError.invalidResponse))
            return
        }
        
        Task {
            do {
                print("Authenticating with Supabase using Apple credentials...")
                
                // Get the identity token
                guard let identityTokenData = appleIDCredential.identityToken,
                      let identityToken = String(data: identityTokenData, encoding: .utf8) else {
                    print("ERROR: No identity token")
                    throw APIError.invalidResponse
                }
                
                print("Identity token retrieved")
                
                // Use Supabase's Apple Sign-In with the identity token
                let session = try await client.auth.signInWithIdToken(
                    credentials: .init(
                        provider: .apple,
                        idToken: identityToken
                    )
                )
                
                print("Supabase authentication successful")
                
                // Create display name
                var displayName = "Apple User"
                if let fullName = appleIDCredential.fullName {
                    let nameComponents = [
                        fullName.givenName,
                        fullName.familyName
                    ].compactMap { $0 }.joined(separator: " ")
                    
                    if !nameComponents.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        displayName = nameComponents
                    }
                }
                
                // Update user metadata if needed
                if displayName != "Apple User" {
                    try await client.auth.update(
                        user: UserAttributes(
                            data: ["username": .string(displayName)]
                        )
                    )
                }
                
                // Create user object
                let user = User(
                    id: session.user.id.uuidString,
                    email: session.user.email ?? appleIDCredential.email ?? "\(session.user.id.uuidString)@privaterelay.appleid.com",
                    userMetadata: UserMetadata(username: displayName)
                )
                
                print("User object created: \(user.id)")
                
                // Update SupabaseClient state
                await MainActor.run {
                    SupabaseClient.shared.user = user
                    SupabaseClient.shared.isAuthenticated = true
                    print("SupabaseClient state updated")
                }
                
                completion(.success(user))
                
            } catch {
                print("Supabase Apple authentication failed: \(error)")
                completion(.failure(APIError.networkError))
            }
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        print("Apple authorization failed: \(error)")
        
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
