import Foundation
import Combine
import Contacts

@MainActor
final class ContactsGridViewModel: ObservableObject {
    @Published var contacts: [ContactItem] = []
    @Published var searchText: String = ""
    @Published var permissionDenied = false
    @Published var loadingErrorMessage: String?
    @Published var isReloading = false

    private let contactsService: ContactsServiceProtocol
    private let statsStore: CallStatsStoreProtocol
    private var rawContacts: [RawContact] = []
    private var cancellables = Set<AnyCancellable>()

    init(contactsService: ContactsServiceProtocol, statsStore: CallStatsStoreProtocol) {
        self.contactsService = contactsService
        self.statsStore = statsStore

        NotificationCenter.default.publisher(for: .CNContactStoreDidChange)
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &cancellables)
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
            try await loadContacts()
        } catch {
            loadingErrorMessage = "Ошибка доступа к контактам: \(error.localizedDescription)"
        }
    }

    func refresh() {
        Task {
            isReloading = true
            do {
                try await loadContacts()
            } catch {
                loadingErrorMessage = "Ошибка обновления: \(error.localizedDescription)"
            }
            isReloading = false
        }
    }

    func registerOutgoingTap(for contact: ContactItem, phoneNumber: String) {
        let key = statKey(contactID: contact.id, phoneNumber: phoneNumber)
        statsStore.incrementCall(for: key)
    }

    func resetStatistics() {
        statsStore.resetAll()
        refresh()
    }

    private func loadContacts() async throws {
        rawContacts = try await contactsService.fetchContacts()

        contacts = rawContacts
            .map { raw in
                ContactItem(
                    id: raw.id,
                    givenName: raw.givenName,
                    familyName: raw.familyName,
                    phoneNumbers: raw.phoneNumbers,
                    avatarData: raw.avatarData,
                    outgoingCallsCount: callsCount(for: raw)
                )
            }
            .filter { $0.hasCallableNumber }
            .sorted(by: sortContacts)
    }

    private func callsCount(for raw: RawContact) -> Int {
        raw.phoneNumbers.reduce(0) { sum, number in
            sum + statsStore.callsCount(for: statKey(contactID: raw.id, phoneNumber: number))
        }
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
