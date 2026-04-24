import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var showEmailLogin = false
    @State private var showError = false
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color.blue.opacity(0.6), Color.blue.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                // App branding
                VStack(spacing: 12) {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 70, weight: .bold))
                        .foregroundStyle(.white)
                    
                    Text("StayFit")
                        .font(.system(size: 42, weight: .bold))
                        .foregroundStyle(.white)
                    
                    Text("Track your strength journey")
                        .font(.system(size: 16))
                        .foregroundStyle(.white.opacity(0.9))
                }
                .padding(.bottom, 60)
                
                Spacer()
                
                // Auth buttons
                VStack(spacing: 16) {
                    // Apple Sign In
                    SignInWithAppleButton(
                        onRequest: { request in
                            request.requestedScopes = [.email, .fullName]
                        },
                        onCompletion: { result in
                            handleAppleSignIn(result)
                        }
                    )
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 50)
                    .cornerRadius(12)
                    
                    // Google Sign In
                    Button(action: handleGoogleSignIn) {
                        HStack(spacing: 12) {
                            Image(systemName: "g.circle.fill")
                                .font(.system(size: 20))
                            Text("Continue with Google")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(.white)
                        .cornerRadius(12)
                    }
                    
                    // Email Sign In
                    Button {
                        showEmailLogin = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "envelope.fill")
                                .font(.system(size: 20))
                            Text("Continue with Email")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(.white)
                        .cornerRadius(12)
                    }
                    
                    // Guest Login
                    Button {
                        authManager.isAuthenticated = true
                    } label: {
                        Text("Continue as Guest")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
                
                // Terms
                VStack(spacing: 8) {
                    Text("By continuing, you agree to our")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.8))

                    HStack(spacing: 4) {

                        // TERMS OF SERVICE BUTTON
                        Button("Terms of Service") {
                            if let url = URL(string:
                                "https://docs.google.com/document/d/18fiKyIqAVKCN51tZS5oLZakalAth54f6onBgKWZZ16Yg/view?usp=sharing"
                            ) {
                                UIApplication.shared.open(url)
                            }
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white)

                        Text("and")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.8))

                        // PRIVACY POLICY BUTTON
                        Button("Privacy Policy") {
                            if let url = URL(string:
                                "https://docs.google.com/document/d/1GgL7G55JxBYT0PUZk1BT2DZcNvhYmChaFT1kobMjuS8/view?usp=sharing"
                            ) {
                                UIApplication.shared.open(url)
                            }
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white)
                    }
                }
                .padding(.bottom, 32)

            }
            
            // Loading overlay
            if authManager.isLoading {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                    Text("Signing in...")
                        .foregroundStyle(.white)
                        .font(.system(size: 16, weight: .medium))
                }
            }
        }
        .sheet(isPresented: $showEmailLogin) {
            EmailLoginView()
                .environmentObject(authManager)
        }
        .alert("Authentication Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(authManager.authError?.errorDescription ?? "An error occurred")
        }
    }
    
    // MARK: - Handlers
    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        Task {
            switch result {
            case .success(let authorization):
                do {
                    try await authManager.signInWithApple(authorization)
                } catch {
                    showError = true
                }
            case .failure:
                showError = true
            }
        }
    }
    
    private func handleGoogleSignIn() {
        Task {
            do {
                try await authManager.signInWithGoogle()
            } catch {
                showError = true
            }
        }
    }
}

// MARK: - Email Login Sheet
struct EmailLoginView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authManager: AuthenticationManager
    
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    @State private var confirmPassword = ""
    @State private var name = ""
    @State private var showForgotPassword = false
    @State private var resetEmail = ""
    @State private var showResetSuccess = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Text(isSignUp ? "Create Account" : "Welcome Back")
                            .font(.system(size: 28, weight: .bold))
                        
                        Text(isSignUp ? "Sign up to start tracking" : "Sign in to continue")
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 24)
                    
                    // Form
                    VStack(spacing: 16) {
                        if isSignUp {
                            TextField("Full Name", text: $name)
                                .textContentType(.name)
                                .autocapitalization(.words)
                                .padding()
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(10)
                        }
                        
                        TextField("Email", text: $email)
                            .textContentType(.emailAddress)
                            .autocapitalization(.none)
                            .keyboardType(.emailAddress)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(10)
                        
                        SecureField("Password", text: $password)
                            .textContentType(isSignUp ? .newPassword : .password)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(10)
                        
                        if isSignUp {
                            SecureField("Confirm Password", text: $confirmPassword)
                                .textContentType(.newPassword)
                                .padding()
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(10)
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    // Error message
                    if let error = authManager.authError {
                        Text(error.errorDescription ?? "")
                            .font(.system(size: 13))
                            .foregroundStyle(.red)
                            .padding(.horizontal, 24)
                    }
                    
                    // Submit button
                    Button {
                        Task { await handleEmailAuth() }
                    } label: {
                        if authManager.isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text(isSignUp ? "Sign Up" : "Sign In")
                                .font(.system(size: 16, weight: .semibold))
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.blue)
                    .cornerRadius(12)
                    .padding(.horizontal, 24)
                    .disabled(authManager.isLoading || !isFormValid)
                    .opacity(isFormValid ? 1 : 0.5)
                    
                    // Toggle
                    Button {
                        withAnimation { isSignUp.toggle() }
                    } label: {
                        HStack(spacing: 4) {
                            Text(isSignUp ? "Already have an account?" : "Don't have an account?")
                                .foregroundStyle(.secondary)
                            Text(isSignUp ? "Sign In" : "Sign Up")
                                .fontWeight(.semibold)
                                .foregroundStyle(.blue)
                        }
                        .font(.system(size: 14))
                    }
                    
                    if !isSignUp {
                        Button("Forgot Password?") {
                            showForgotPassword = true
                        }
                        .font(.system(size: 14))
                        .foregroundStyle(.blue)
                    }
                }
                .padding(.bottom, 40)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
    
    private var isFormValid: Bool {
        if isSignUp {
            return !name.isEmpty && !email.isEmpty && !password.isEmpty &&
                   password == confirmPassword && password.count >= 6
        } else {
            return !email.isEmpty && !password.isEmpty
        }
    }
    
    private func handleEmailAuth() async {
        do {
            if isSignUp {
                try await authManager.signUpWithEmail(name: name, email: email, password: password)
            } else {
                try await authManager.signInWithEmail(email: email, password: password)
            }
            dismiss()
        } catch {
            // Error handled by authManager
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthenticationManager.shared)
}
