import SwiftUI

struct SettingsView: View {
    @AppStorage("zvonilka_theme_mode") private var themeModeRaw = ThemeMode.system.rawValue
    @Environment(\.dismiss) private var dismiss

    let onResetStats: () -> Void

    private var selectedTheme: Binding<ThemeMode> {
        Binding(
            get: { ThemeMode(rawValue: themeModeRaw) ?? .system },
            set: { themeModeRaw = $0.rawValue }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Тема") {
                    Picker("Режим", selection: selectedTheme) {
                        ForEach(ThemeMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Статистика") {
                    Button(role: .destructive) {
                        onResetStats()
                    } label: {
                        Text("Сбросить счетчики")
                    }
                }
            }
            .navigationTitle("Настройки")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Готово") {
                        dismiss()
                    }
                }
            }
        }
    }
}
