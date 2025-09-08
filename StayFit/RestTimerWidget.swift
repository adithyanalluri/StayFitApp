import SwiftUI

struct RestTimerWidget: View {
    @EnvironmentObject var timer: TimerManager

    private var ringColor: Color {
        guard timer.total > 0 else { return .green }
        let pct = Double(timer.remaining) / Double(timer.total)
        if pct < 0.15 { return .red }
        if pct < 0.35 { return .yellow }
        return .green
    }

    var body: some View {
        if timer.isVisible {
            HStack(spacing: 10) {
                // Circle progress + icon
                ZStack {
                    Circle()
                        .trim(from: 0, to: timer.progress)
                        .stroke(ringColor, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 26, height: 26)

                    Image(systemName: timer.isPaused ? "pause.fill" : "timer")
                        .font(.system(size: 12, weight: .bold))
                }

                // Remaining time
                Text(timer.label())
                    .monospacedDigit()
                    .font(.headline)

                // +/- 10s quick adjust
                HStack(spacing: 6) {
                    Button(action: { timer.addTime(-10) }) {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    Button(action: { timer.addTime(10) }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
                .buttonStyle(.plain)

                // Pause / Resume
                Button(action: { timer.toggle() }) {
                    Image(systemName: timer.isPaused ? "play.fill" : "pause.fill")
                        .font(.system(size: 16, weight: .semibold))
                }
                .buttonStyle(.plain)

                // Cancel
                Button(action: { timer.cancel() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(Color.black.opacity(0.06)))
            .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 6)
            .padding(.horizontal)
            .transition(.move(edge: .top).combined(with: .opacity))
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: timer.isVisible)
            // Long-press quick presets
            .contextMenu {
                Button("60s")  { timer.start(seconds: 60) }
                Button("90s")  { timer.start(seconds: 90) }
                Button("120s") { timer.start(seconds: 120) }
                Button("180s") { timer.start(seconds: 180) }
                Button("300s") { timer.start(seconds: 300) }
            }
        }
    }
}
