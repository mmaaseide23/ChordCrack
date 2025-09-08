import Foundation
import Supabase
import Combine

class SupabaseClient: ObservableObject {
    static let shared = SupabaseClient()
    
    private let client: Supabase.SupabaseClient
    private let supabaseURL: URL
    private let supabaseKey: String
    
    @Published var isAuthenticated = false
    @Published var user: User?
    
    init() {
        // REPLACE THESE WITH YOUR ACTUAL SUPABASE CREDENTIALS
        let supabaseURLString = "https://iyswoogivbvkqpdwdeuv.supabase.co"
        let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Iml5c3dvb2dpdmJ2a3FwZHdkZXV2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTcwODA3ODUsImV4cCI6MjA3MjY1Njc4NX0.boizWCVbtzpldr4g4oX0ZcbMpZTBg67aWpkmQ-_-t_A"
        
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
        
        let response = try await client.auth.signUp(
            email: email,
            password: password,
            data: metadata
        )
        
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
    }
    
    func signIn(email: String, password: String) async throws -> User {
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
        responseType: T.Type
    ) async throws -> T {
        // Get the current session
        let session = try await client.auth.session
        
        // Build the full URL - FIXED URL construction
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
            throw APIError.networkError
        }
        
        // Debug successful responses
        if let httpResponse = response as? HTTPURLResponse {
            print("Success \(httpResponse.statusCode) for \(fullURL)")
        }
        
        return try JSONDecoder().decode(T.self, from: data)
    }
    
    func performVoidRequest(
        method: String = "POST",
        path: String,
        body: [String: Any]
    ) async throws {
        // Get the current session
        let session = try await client.auth.session
        
        // Build the full URL - FIXED URL construction
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
            throw APIError.networkError
        }
    }
}
