import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject var settings: SettingsStore
    @Environment(\.dismiss) private var dismiss

    @State private var selectedUnit: UnitSystem = .kg

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 56, weight: .semibold))
                    .foregroundStyle(.blue)

                Text("Welcome to StayFit")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)

                Text("Log your workouts, celebrate PRs, and track your progress over time.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Preferred Units")
                        .font(.headline)
                    Picker("Units", selection: $selectedUnit) {
                        Text("Kilograms (kg)").tag(UnitSystem.kg)
                        Text("Pounds (lb)").tag(UnitSystem.lb)
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.horizontal)

                Spacer()

                Button {
                    // Save selection and mark onboarding complete
                    settings.unit = selectedUnit
                    settings.save()
                    UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                    dismiss()
                } label: {
                    Text("Get Started")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)
                .padding(.bottom)
            }
            .onAppear {
                selectedUnit = settings.unit
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    WelcomeView()
        .environmentObject(SettingsStore())
}
