import Foundation
import Combine

@MainActor
final class ContactsGridViewModel: ObservableObject {
    @Published var contacts: [ContactItem] = []
    @Published var searchText: String = ""
    @Published var permissionDenied = false
    @Published var loadingErrorMessage: String?

    private let contactsService: ContactsServiceProtocol
    private let statsStore: CallStatsStoreProtocol
    private var rawContacts: [RawContact] = []

    init(contactsService: ContactsServiceProtocol, statsStore: CallStatsStoreProtocol) {
        self.contactsService = contactsService
        self.statsStore = statsStore
    }

    var filteredContacts: [ContactItem] {
        let prepared = contacts

        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return prepared
        }

        let query = searchText.lowercased()
        return prepared.filter { item in
            item.displayName.lowercased().contains(query) ||
            (item.phoneNumber?.lowercased().contains(query) ?? false)
        }
    }

    func requestAccessAndLoad() async {
        do {
            let granted = try await contactsService.requestAccess()
            permissionDenied = !granted
            guard granted else { return }
            try loadContacts()
        } catch {
            loadingErrorMessage = "Ошибка доступа к контактам: \(error.localizedDescription)"
        }
    }

    func refresh() {
        do {
            try loadContacts()
        } catch {
            loadingErrorMessage = "Ошибка обновления: \(error.localizedDescription)"
        }
    }

    func registerOutgoingTap(for contact: ContactItem) {
        guard let phoneNumber = contact.phoneNumber else { return }
        let key = statKey(contactID: contact.id, phoneNumber: phoneNumber)
        statsStore.incrementCall(for: key)
        refresh()
    }

    func resetStatistics() {
        statsStore.resetAll()
        refresh()
    }

    private func loadContacts() throws {
        rawContacts = try contactsService.fetchContacts()

        contacts = rawContacts
            .map { raw in
                ContactItem(
                    id: raw.id,
                    givenName: raw.givenName,
                    familyName: raw.familyName,
                    phoneNumber: raw.phoneNumber,
                    avatarData: raw.avatarData,
                    outgoingCallsCount: callsCount(for: raw)
                )
            }
            .filter { $0.hasCallableNumber }
            .sorted(by: sortContacts)
    }

    private func callsCount(for raw: RawContact) -> Int {
        guard let phoneNumber = raw.phoneNumber else { return 0 }
        let key = statKey(contactID: raw.id, phoneNumber: phoneNumber)
        return statsStore.callsCount(for: key)
    }

    private func statKey(contactID: String, phoneNumber: String) -> String {
        let normalized = phoneNumber.filter(\.isNumber)
        return "\(contactID)_\(normalized)"
    }

    private func sortContacts(_ lhs: ContactItem, _ rhs: ContactItem) -> Bool {
        if lhs.outgoingCallsCount != rhs.outgoingCallsCount {
            return lhs.outgoingCallsCount > rhs.outgoingCallsCount
        }

        if lhs.hasName != rhs.hasName {
            return lhs.hasName
        }

        if lhs.sortTitle != rhs.sortTitle {
            return lhs.sortTitle < rhs.sortTitle
        }

        return lhs.id < rhs.id
    }
}
