import SwiftUI
import UserNotifications
import FirebaseCore

// MARK: - AppDelegate for Notifications
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        
        FirebaseApp.configure()
        
        #if DEBUG
        if let app = FirebaseApp.app() {
            let name = app.name
            let projectID = app.options.projectID ?? "(no projectID)"
            let googleAppID = app.options.googleAppID
            print("[Firebase] Configured app=\(name), projectID=\(projectID), googleAppID=\(googleAppID)")
        } else {
            assertionFailure("[Firebase] FirebaseApp.configure() appears to have failed. Check GoogleService-Info.plist target membership and location.")
        }
        #endif
        
        // Set the delegate
        UNUserNotificationCenter.current().delegate = self
        
        // Register rest-timer notification actions
        let add30  = UNNotificationAction(identifier: "ADD_30", title: "+30s", options: [])
        let cancel = UNNotificationAction(identifier: "CANCEL_REST", title: "Stop", options: [.destructive])
        let cat = UNNotificationCategory(identifier: "REST_CATEGORY", actions: [add30, cancel], intentIdentifiers: [], options: [])
        UNUserNotificationCenter.current().setNotificationCategories([cat])
        
        return true
    }
    
    // Handle notification actions
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let actionID = response.actionIdentifier
        
        switch actionID {
        case "ADD_30":
            NotificationCenter.default.post(name: .restAdd30, object: nil)
        case "CANCEL_REST":
            NotificationCenter.default.post(name: .restCancel, object: nil)
        default:
            break
        }
        
        completionHandler()
    }
}

@main
struct StayFitApp: App {
    // Connect our AppDelegate
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    @StateObject private var authManager = AuthenticationManager.shared
    @StateObject private var store = DataStore()
    @StateObject private var settings = SettingsStore()
    @StateObject private var timer = TimerManager()

    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Firebase is configured in AppDelegate.didFinishLaunching
        
        // Request notification permissions
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authManager)
                .environmentObject(store)
                .environmentObject(settings)
                .environmentObject(timer)
                .tint(Color.blue)
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background:
                settings.save()
            case .active:
                Task {
                    await authManager.checkAuthStatus()
                }
            default:
                break
            }
        }
    }
}

// MARK: - Root View (Handles Navigation)
struct RootView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var settings: SettingsStore
    
    @State private var showWelcome = false
    
    var body: some View {
        Group {
            if authManager.isLoading {
                // Splash screen while checking auth
                SplashView()
            } else if authManager.isAuthenticated {
                // Main app
                MainAppView()
            } else {
                // Login screen
                LoginView()
            }
        }
        .animation(.easeInOut, value: authManager.isAuthenticated)
        .animation(.easeInOut, value: authManager.isLoading)
        .sheet(isPresented: $showWelcome) {
            WelcomeView()
                .environmentObject(settings)
        }
        .onAppear {
            showWelcome = !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        }
    }
}

// MARK: - Splash View
struct SplashView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.blue.opacity(0.6), Color.blue.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 80, weight: .bold))
                    .foregroundStyle(.white)
                
                Text("StayFit")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(.white)
                
                ProgressView()
                    .scaleEffect(1.2)
                    .tint(.white)
                    .padding(.top, 20)
            }
        }
    }
}

// MARK: - Main App View (Your existing HomeView with Settings integration)
struct MainAppView: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var timer: TimerManager
    @EnvironmentObject var authManager: AuthenticationManager
    
    var body: some View {
        HomeView()
    }
}
