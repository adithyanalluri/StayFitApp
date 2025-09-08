import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var timer: TimerManager

    private let presets: [Int] = [60, 90, 120, 180, 300] // 1m, 1m30, 2m, 3m, 5m

    var body: some View {
        NavigationStack {
            Form {

                // MARK: Rest Timer
                Section("Rest Timer") {

                    // Quick presets (scrollable chips)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(presets, id: \.self) { v in
                                Button {
                                    settings.defaultRestSeconds = v
                                } label: {
                                    Text(presetLabel(v))
                                        .font(.subheadline)
                                        .padding(.horizontal, 12).padding(.vertical, 6)
                                        .background(
                                            Capsule()
                                                .fill(settings.defaultRestSeconds == v ? Color.blue.opacity(0.18) : Color.gray.opacity(0.15))
                                        )
                                        .overlay(
                                            Capsule()
                                                .stroke(settings.defaultRestSeconds == v ? Color.blue : .clear, lineWidth: 1)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                        .padding(.leading, 2)
                    }

                    // Fine-grained adjust (1:00–5:00, 15s steps; clamped in SettingsStore too)
                    Stepper(value: $settings.defaultRestSeconds, in: 60...300, step: 15) {
                        Text("Default Rest: \(format(settings.defaultRestSeconds))")
                            .monospacedDigit()
                    }

                    Text("Used when a new rest timer starts after logging a set. Range: 1–5 minutes.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                // MARK: Test
                Section("Test") {
                    Button {
                        timer.start(seconds: 10)
                    } label: {
                        Label("Start 10s Test Timer", systemImage: "timer")
                    }

                    Button {
                        timer.cancel()
                    } label: {
                        Label("Cancel Active Timer", systemImage: "xmark.circle")
                    }
                    .tint(.red)
                }
            }
            .navigationTitle("Settings")
        }
    }

    // MARK: Helpers
    private func presetLabel(_ seconds: Int) -> String {
        seconds % 60 == 0 ? "\(seconds/60)m" : "\(seconds)s"
    }

    private func format(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return "\(m)m \(String(format: "%02d", s))s"
    }
}
