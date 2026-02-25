import Foundation
import Combine

@MainActor
final class ContactsListViewModel: ObservableObject {
    @Published var contacts: [ContactItem] = []
    @Published var searchText: String = ""
    @Published var hasContactsPermission = false
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
        guard !searchText.isEmpty else {
            return contacts
        }

        return contacts.filter {
            $0.fullName.localizedCaseInsensitiveContains(searchText) ||
            ($0.phoneNumber?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    func requestAccessAndLoad() async {
        do {
            hasContactsPermission = try await contactsService.requestAccess()
            permissionDenied = !hasContactsPermission
            guard hasContactsPermission else { return }
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

    func registerOutgoingTapAndResort(for contact: ContactItem) {
        guard let phoneNumber = contact.phoneNumber else { return }
        let key = statKey(contactID: contact.id, phoneNumber: phoneNumber)
        statsStore.incrementCall(for: key)
        refresh()
    }

    private func loadContacts() throws {
        rawContacts = try contactsService.fetchContacts()

        contacts = rawContacts
            .map { raw in
                ContactItem(
                    id: raw.id,
                    fullName: raw.fullName,
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
        return lhs.fullName.localizedCaseInsensitiveCompare(rhs.fullName) == .orderedAscending
    }
}
