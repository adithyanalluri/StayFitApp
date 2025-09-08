import Foundation

enum UnitSystem: String, Codable, CaseIterable, Identifiable {
    case kg, lb
    var id: String { rawValue }
    var label: String { rawValue.uppercased() }
}

// Codable payload we write/read to disk
private struct SettingsData: Codable {
    var unit: UnitSystem
    var defaultRestSeconds: Int
}

@MainActor
final class SettingsStore: ObservableObject {
    @Published var unit: UnitSystem = .kg
    @Published var defaultRestSeconds: Int = 120   // 2 minutes default

    // MARK: - Persistence
    private static var url: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("settings.json")
    }

    init() {
        load()
    }

    func load() {
        guard let data = try? Data(contentsOf: Self.url),
              let decoded = try? JSONDecoder().decode(SettingsData.self, from: data) else { return }
        unit = decoded.unit
        defaultRestSeconds = decoded.defaultRestSeconds
    }

    func save() {
        let payload = SettingsData(unit: unit, defaultRestSeconds: defaultRestSeconds)
        do {
            let data = try JSONEncoder().encode(payload)
            try data.write(to: Self.url, options: [.atomic])
        } catch {
            print("Settings save error:", error)
        }
    }

    // MARK: - Unit conversion helpers
    func toDisplayWeight(kg: Double) -> Double {
        unit == .kg ? kg : kg * 2.2046226218
    }
    func fromDisplayWeight(_ value: Double) -> Double {
        unit == .kg ? value : value / 2.2046226218
    }
}

