import SwiftUI

@main
struct ZvonilkaApp: App {
    var body: some Scene {
        WindowGroup {
            ContactsListView(
                viewModel: ContactsListViewModel(
                    contactsService: ContactsService(),
                    statsStore: CallStatsStore()
                )
            )
        }
    }
}
