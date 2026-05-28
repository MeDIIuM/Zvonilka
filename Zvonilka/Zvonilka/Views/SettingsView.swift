import SwiftUI

struct SettingsView: View {
    @AppStorage("zvonilka_theme_mode") private var themeModeRaw = ThemeMode.system.rawValue
    @Environment(\.dismiss) private var dismiss

    let onResetStats: () -> Void

    @State private var showConfirmAlert = false
    @State private var showToast = false

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
                        showConfirmAlert = true
                    } label: {
                        Text("Сбросить счётчики")
                    }
                }
            }
            .navigationTitle("Настройки")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Готово") { dismiss() }
                }
            }
            .alert("Сбросить счётчики?", isPresented: $showConfirmAlert) {
                Button("Сбросить", role: .destructive) {
                    onResetStats()
                    showToast = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        showToast = false
                    }
                }
                Button("Отмена", role: .cancel) {}
            } message: {
                Text("Статистика звонков будет удалена безвозвратно.")
            }
            .overlay(alignment: .bottom) {
                if showToast {
                    Text("Счётчики сброшены")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color(.label).opacity(0.85), in: Capsule())
                        .padding(.bottom, 32)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .animation(.spring(), value: showToast)
                }
            }
            .animation(.spring(), value: showToast)
        }
    }
}
