import SwiftUI

struct SettingsView: View {
    @AppStorage("zvonilka_theme_mode") private var themeModeRaw = ThemeMode.system.rawValue
    @Environment(\.dismiss) private var dismiss

    let onResetStats: () -> Void

    @State private var showConfirmAlert = false
    @State private var showClearCacheAlert = false
    @State private var showToast = false
    @State private var toastMessage = ""

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        return "\(version)"
    }

    private func toast(_ message: String) {
        toastMessage = message
        showToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { showToast = false }
    }

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

                Section("Кеш") {
                    Button(role: .destructive) {
                        showClearCacheAlert = true
                    } label: {
                        Text("Очистить кеш контактов")
                    }
                }

                Section {
                    HStack {
                        Text("Версия")
                        Spacer()
                        Text(appVersion)
                            .foregroundStyle(.secondary)
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
                    toast("Счётчики сброшены")
                }
                Button("Отмена", role: .cancel) {}
            } message: {
                Text("Статистика звонков будет удалена безвозвратно.")
            }
            .alert("Очистить кеш?", isPresented: $showClearCacheAlert) {
                Button("Очистить", role: .destructive) {
                    ContactsCacheStore.shared.clear()
                    AvatarCache.shared.clear()
                    toast("Кеш очищен")
                }
                Button("Отмена", role: .cancel) {}
            } message: {
                Text("Контакты будут заново загружены при следующем открытии.")
            }
            .overlay(alignment: .bottom) {
                if showToast {
                    Text(toastMessage)
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
