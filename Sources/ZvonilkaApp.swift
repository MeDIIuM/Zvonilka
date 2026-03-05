import SwiftUI

@main
struct ZvonilkaApp: App {
    @AppStorage("zvonilka_theme_mode") private var themeModeRaw = ThemeMode.system.rawValue

    var body: some Scene {
        WindowGroup {
            ContactsGridView(
                viewModel: ContactsGridViewModel(
                    contactsService: ContactsService(),
                    statsStore: CallStatsStore()
                )
            )
            .preferredColorScheme(ThemeMode(rawValue: themeModeRaw)?.colorScheme)
        }
    }
}
