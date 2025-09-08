import SwiftUI

struct Chip: View {
    let text: String
    let isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.subheadline)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(
                    Capsule().fill(isSelected ? Color.blue.opacity(0.2) : Color.gray.opacity(0.15))
                )
                .overlay(
                    Capsule().stroke(isSelected ? Color.blue : Color.clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}
