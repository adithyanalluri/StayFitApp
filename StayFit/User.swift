import Foundation
import SwiftUI
import AuthenticationServices
import LocalAuthentication
import GoogleSignIn
import FirebaseCore

// MARK: - User Model
struct User: Codable, Identifiable {
    let id: String
    var email: String
    var name: String
    var photoURL: String?
    var provider: AuthProvider
    
    enum AuthProvider: String, Codable {
        case apple, google, email
    }
}

// MARK: - Authentication Manager
@MainActor
final class AuthenticationManager: ObservableObject {
    static let shared = AuthenticationManager()
    
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    @Published var isLoading = true
    @Published var authError: AuthError?
    
    private let keychain = KeychainManager.shared
    private let biometricAuth = BiometricAuthManager()
    
    // MARK: - Init
    private init() {
        Task {
            await checkAuthStatus()
        }
    }
    
    // MARK: - Check Auth Status
    func checkAuthStatus() async {
        isLoading = true
        
        // Check if we have a stored token
        if let token = keychain.getToken(),
           let userData = keychain.getUserData() {
            // Validate token with backend
            do {
                let isValid = try await validateToken(token)
                if isValid {
                    self.currentUser = userData
                    self.isAuthenticated = true
                } else {
                    // Token expired, clear data
                    await signOut()
                }
            } catch {
                await signOut()
            }
        }
        
        isLoading = false
    }
    
    // MARK: - Email Authentication
    func signInWithEmail(email: String, password: String) async throws {
        isLoading = true
        authError = nil
        
        do {
            // Call your backend API
            let response = try await APIClient.shared.signIn(email: email, password: password)
            
            // Store token and user data securely
            keychain.saveToken(response.token)
            keychain.saveUserData(response.user)
            
            // Update state
            self.currentUser = response.user
            self.isAuthenticated = true
            
            isLoading = false
        } catch {
            isLoading = false
            authError = .signInFailed(error.localizedDescription)
            throw error
        }
    }
    
    func signUpWithEmail(name: String, email: String, password: String) async throws {
        isLoading = true
        authError = nil
        
        do {
            // Call your backend API
            let response = try await APIClient.shared.signUp(name: name, email: email, password: password)
            
            // Store token and user data securely
            keychain.saveToken(response.token)
            keychain.saveUserData(response.user)
            
            // Update state
            self.currentUser = response.user
            self.isAuthenticated = true
            
            isLoading = false
        } catch {
            isLoading = false
            authError = .signUpFailed(error.localizedDescription)
            throw error
        }
    }
    
    // MARK: - Apple Sign In
    func signInWithApple(_ authorization: ASAuthorization) async throws {
        isLoading = true
        authError = nil
        
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            authError = .invalidCredentials
            isLoading = false
            throw AuthError.invalidCredentials
        }
        
        guard let identityToken = appleIDCredential.identityToken,
              let tokenString = String(data: identityToken, encoding: .utf8) else {
            authError = .invalidToken
            isLoading = false
            throw AuthError.invalidToken
        }
        
        do {
            // Send token to your backend
            let response = try await APIClient.shared.signInWithApple(
                token: tokenString,
                userIdentifier: appleIDCredential.user,
                email: appleIDCredential.email,
                fullName: appleIDCredential.fullName
            )
            
            keychain.saveToken(response.token)
            keychain.saveUserData(response.user)
            
            self.currentUser = response.user
            self.isAuthenticated = true
            
            isLoading = false
        } catch {
            isLoading = false
            authError = .appleSignInFailed(error.localizedDescription)
            throw error
        }
    }
    
    // MARK: - Google Sign In
    func signInWithGoogle() async throws {
        isLoading = true
        authError = nil

        do {
            // Read clientID from Firebase config (GoogleService-Info.plist)
            guard let clientID = FirebaseApp.app()?.options.clientID else {
                throw AuthError.googleSignInFailed("Missing Google clientID. Check GoogleService-Info.plist.")
            }

            // Configure Google Sign-In
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

            // Present Google Sign-In UI
            let presentingVC = getRootViewController()
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presentingVC)

            // Extract Google ID token for backend
            guard let idToken = result.user.idToken?.tokenString else {
                throw AuthError.invalidToken
            }

            // Call your backend with Google ID token
            let response = try await APIClient.shared.signInWithGoogle(token: idToken)

            // Persist and update app state
            keychain.saveToken(response.token)
            keychain.saveUserData(response.user)

            self.currentUser = response.user
            self.isAuthenticated = true
            isLoading = false
        } catch {
            isLoading = false
            authError = .googleSignInFailed(error.localizedDescription)
            throw error
        }
    }
    
    // MARK: - Biometric Auth
    func enableBiometricAuth() async throws -> Bool {
        guard isAuthenticated else { return false }
        
        let success = try await biometricAuth.authenticate(reason: "Enable biometric login")
        if success {
            UserDefaults.standard.set(true, forKey: "biometricAuthEnabled")
        }
        return success
    }
    
    func signInWithBiometrics() async throws {
        guard UserDefaults.standard.bool(forKey: "biometricAuthEnabled") else {
            throw AuthError.biometricsNotEnabled
        }
        
        let success = try await biometricAuth.authenticate(reason: "Sign in to StayFit")
        
        if success {
            await checkAuthStatus()
        } else {
            throw AuthError.biometricsFailed
        }
    }
    
    // MARK: - Password Reset
    func resetPassword(email: String) async throws {
        do {
            try await APIClient.shared.resetPassword(email: email)
        } catch {
            authError = .passwordResetFailed(error.localizedDescription)
            throw error
        }
    }
    
    // MARK: - Sign Out
    func signOut() async {
        keychain.deleteToken()
        keychain.deleteUserData()
        
        self.currentUser = nil
        self.isAuthenticated = false
        self.authError = nil
    }
    
    // MARK: - Token Validation
    private func validateToken(_ token: String) async throws -> Bool {
        // Validate with your backend
        return try await APIClient.shared.validateToken(token)
    }
}

// MARK: - Auth Error
enum AuthError: LocalizedError, Identifiable {
    case signInFailed(String)
    case signUpFailed(String)
    case invalidCredentials
    case invalidToken
    case appleSignInFailed(String)
    case googleSignInFailed(String)
    case biometricsNotEnabled
    case biometricsFailed
    case passwordResetFailed(String)
    case notImplemented
    
    var id: String { errorDescription ?? "unknown" }
    
    var errorDescription: String? {
        switch self {
        case .signInFailed(let message):
            return "Sign in failed: \(message)"
        case .signUpFailed(let message):
            return "Sign up failed: \(message)"
        case .invalidCredentials:
            return "Invalid credentials provided"
        case .invalidToken:
            return "Invalid authentication token"
        case .appleSignInFailed(let message):
            return "Apple Sign In failed: \(message)"
        case .googleSignInFailed(let message):
            return "Google Sign In failed: \(message)"
        case .biometricsNotEnabled:
            return "Biometric authentication is not enabled"
        case .biometricsFailed:
            return "Biometric authentication failed"
        case .passwordResetFailed(let message):
            return "Password reset failed: \(message)"
        case .notImplemented:
            return "This feature is not yet implemented"
        }
    }
}

// MARK: - Keychain Manager
final class KeychainManager {
    static let shared = KeychainManager()
    private init() {}
    
    private let tokenKey = "com.stayfit.authToken"
    private let userDataKey = "com.stayfit.userData"
    
    func saveToken(_ token: String) {
        let data = Data(token.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: tokenKey,
            kSecValueData as String: data
        ]
        
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }
    
    func getToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: tokenKey,
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return token
    }
    
    func deleteToken() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: tokenKey
        ]
        SecItemDelete(query as CFDictionary)
    }
    
    func saveUserData(_ user: User) {
        guard let data = try? JSONEncoder().encode(user) else { return }
        UserDefaults.standard.set(data, forKey: userDataKey)
    }
    
    func getUserData() -> User? {
        guard let data = UserDefaults.standard.data(forKey: userDataKey),
              let user = try? JSONDecoder().decode(User.self, from: data) else {
            return nil
        }
        return user
    }
    
    func deleteUserData() {
        UserDefaults.standard.removeObject(forKey: userDataKey)
    }
}

// MARK: - Biometric Auth Manager
final class BiometricAuthManager {
    private let context = LAContext()
    
    func canUseBiometrics() -> Bool {
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }
    
    func biometricType() -> String {
        guard canUseBiometrics() else { return "None" }
        
        switch context.biometryType {
        case .faceID:
            return "Face ID"
        case .touchID:
            return "Touch ID"
        default:
            return "Biometrics"
        }
    }
    
    func authenticate(reason: String) async throws -> Bool {
        guard canUseBiometrics() else {
            throw AuthError.biometricsNotEnabled
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            ) { success, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: success)
                }
            }
        }
    }
}

// MARK: - API Client
final class APIClient {
    static let shared = APIClient()
    private init() {}
    
    // Replace with your actual backend URL
    private let baseURL = "https://api.yourdomain.com"
    
    struct AuthResponse: Codable {
        let token: String
        let user: User
    }
    
    func signIn(email: String, password: String) async throws -> AuthResponse {
        // TODO: Implement actual API call
        // This is a mock implementation
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // Mock response
        return AuthResponse(
            token: "mock_token_\(UUID().uuidString)",
            user: User(
                id: UUID().uuidString,
                email: email,
                name: email.components(separatedBy: "@").first ?? "User",
                photoURL: nil,
                provider: .email
            )
        )
    }
    
    func signUp(name: String, email: String, password: String) async throws -> AuthResponse {
        // TODO: Implement actual API call
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        return AuthResponse(
            token: "mock_token_\(UUID().uuidString)",
            user: User(
                id: UUID().uuidString,
                email: email,
                name: name,
                photoURL: nil,
                provider: .email
            )
        )
    }
    
    func signInWithApple(token: String, userIdentifier: String, email: String?, fullName: PersonNameComponents?) async throws -> AuthResponse {
        // TODO: Implement actual API call
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        let name = [fullName?.givenName, fullName?.familyName]
            .compactMap { $0 }
            .joined(separator: " ")
        
        return AuthResponse(
            token: "mock_token_\(UUID().uuidString)",
            user: User(
                id: userIdentifier,
                email: email ?? "user@apple.com",
                name: name.isEmpty ? "Apple User" : name,
                photoURL: nil,
                provider: .apple
            )
        )
    }
    
    func signInWithGoogle(token: String) async throws -> AuthResponse {
        // TODO: Implement actual API call
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        return AuthResponse(
            token: "mock_token_\(UUID().uuidString)",
            user: User(
                id: UUID().uuidString,
                email: "user@gmail.com",
                name: "Google User",
                photoURL: nil,
                provider: .google
            )
        )
    }
    
    func validateToken(_ token: String) async throws -> Bool {
        // TODO: Implement actual API call to validate token
        try await Task.sleep(nanoseconds: 500_000_000)
        return !token.isEmpty
    }
    
    func resetPassword(email: String) async throws {
        // TODO: Implement actual API call
        try await Task.sleep(nanoseconds: 1_000_000_000)
    }
}

// MARK: - Helper to get root view controller
extension AuthenticationManager {
    private func getRootViewController() -> UIViewController {
        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow }),
              let rootViewController = window.rootViewController else {
            return UIViewController()
        }
        return rootViewController
    }
}

