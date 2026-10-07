import SwiftUI

@main
struct ZvonilkaApp: App {
    @AppStorage("zvonilka_theme_mode") private var themeModeRaw = ThemeMode.system.rawValue

    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--uitesting-call-flow") {
                CallFlowUITestHost()
            } else {
                mainView
            }
            #else
            mainView
            #endif
        }
    }

    private var mainView: some View {
        ContactsGridView(viewModel: ContactsGridViewModel(contactsService: ContactsService(),
                                                       statsStore: CallStatsStore()))
            .preferredColorScheme(ThemeMode(rawValue: themeModeRaw)?.colorScheme)
    }
}
