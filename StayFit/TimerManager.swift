import Foundation
import Combine
import UserNotifications
import AVFoundation
import UIKit
import AudioToolbox

// Global notifications used by StayFitApp’s UNUserNotificationCenter delegate
extension Notification.Name {
    static let restAdd30  = Notification.Name("REST_ADD_30")
    static let restCancel = Notification.Name("REST_CANCEL")
}

@MainActor
final class TimerManager: ObservableObject {
    // Visible pill state
    @Published var isVisible = false
    @Published var isPaused  = false
    @Published var remaining: Int = 0
    @Published var total: Int      = 0

    // User default rest (local only). Clamped to 60...300s.
    @Published var defaultRestSeconds: Int = 120 {
        didSet { saveDefaultRest() }
    }

    // Internals
    private var timer: Timer?
    private let notificationID = "stayfit.restTimer"
    private var audioPlayer: AVAudioPlayer?

    // MARK: - Init
    init() {
        if let saved = UserDefaults.standard.object(forKey: "defaultRestSeconds") as? Int {
            defaultRestSeconds = min(max(saved, 60), 300)
        }

        // Swift 6-safe: hop to main actor explicitly when responding to notifications
        NotificationCenter.default.addObserver(forName: .restAdd30, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.addTime(30) }
        }
        NotificationCenter.default.addObserver(forName: .restCancel, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.cancel() }
        }
    }

    // MARK: - Public API
    func start(seconds: Int? = nil) {
        let secs = min(max(seconds ?? defaultRestSeconds, 1), 300)
        cancel()
        total = secs
        remaining = secs
        isPaused = false
        isVisible = true
        tickStart()
        scheduleNotification()
    }

    func pause() {
        guard isVisible, !isPaused else { return }
        isPaused = true
        invalidate()
        removeScheduledNotification()
    }

    func resume() {
        guard isVisible, isPaused, remaining > 0 else { return }
        isPaused = false
        tickStart()
        scheduleNotification()
    }

    func cancel() {
        invalidate()
        removeScheduledNotification()
        remaining = 0
        total = 0
        isPaused = false
        isVisible = false
    }

    /// Quick +/- seconds from the pill.
    func addTime(_ delta: Int) {
        guard isVisible else { return }
        remaining = max(0, min(remaining + delta, 300))
        total = max(total, remaining)
        if !isPaused { tickStart() }
        scheduleNotification()
    }

    func toggle() { isPaused ? resume() : pause() }

    func label() -> String {
        let m = max(remaining, 0) / 60
        let s = max(remaining, 0) % 60
        return String(format: "%d:%02d", m, s)
    }

    var progress: Double {
        guard total > 0 else { return 0 }
        return 1 - Double(remaining) / Double(total)
    }

    // MARK: - Internals
    private func tickStart() {
        invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        if let t = timer {
            RunLoop.main.add(t, forMode: .common)
        }
    }

    private func tick() {
        guard !isPaused else { return }

        // Soft 3-2-1 haptics
        if [3, 2, 1].contains(remaining) { tickHaptic(for: remaining) }

        remaining -= 1
        if remaining <= 0 {
            end()
        }
    }

    private func end() {
        invalidate()
        removeScheduledNotification()
        haptic()                 // big buzz at 0
        playSoundWithDucking()   // audible even with headphones; ducks music briefly
        isVisible = false
        remaining = 0
        total = 0
        isPaused = false
    }

    private func invalidate() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Haptics
    private func haptic() {
        let gen = UINotificationFeedbackGenerator()
        gen.notificationOccurred(.success)
    }

    private func tickHaptic(for _: Int) {
        let gen = UIImpactFeedbackGenerator(style: .rigid)
        gen.impactOccurred()
    }

    // MARK: - Notifications
    private func scheduleNotification() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        guard remaining > 0 else { return }
        removeScheduledNotification()

        let content = UNMutableNotificationContent()
        content.title = "Rest finished"
        content.body  = "Time to hit your next set."
        content.sound = .default
        content.categoryIdentifier = "REST_CATEGORY" // actions are registered in StayFitApp

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(remaining), repeats: false)
        let req = UNNotificationRequest(identifier: notificationID, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(req, withCompletionHandler: nil)
    }

    private func removeScheduledNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationID])
    }

    // MARK: - Sound with music ducking
    private func playSoundWithDucking() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, options: [.duckOthers, .mixWithOthers])
            try session.setActive(true)

            if let url = Bundle.main.url(forResource: "ding", withExtension: "caf") {
                audioPlayer = try AVAudioPlayer(contentsOf: url)
                audioPlayer?.prepareToPlay()
                audioPlayer?.play()
            } else {
                AudioServicesPlaySystemSound(1005) // fallback if asset missing
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                try? session.setActive(false, options: [.notifyOthersOnDeactivation])
            }
        } catch {
            AudioServicesPlaySystemSound(1005)
        }
    }

    // MARK: - Persist default rest (local only)
    private func saveDefaultRest() {
        defaultRestSeconds = min(max(defaultRestSeconds, 60), 300) // clamp 1–5 min
        UserDefaults.standard.set(defaultRestSeconds, forKey: "defaultRestSeconds")
    }
}
