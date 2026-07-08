import Foundation
import Combine
import Contacts
import UIKit

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

    var isPhoneNumberQuery: Bool {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return false }
        let allowed = CharacterSet(charactersIn: "+0123456789 ()-")
        return query.unicodeScalars.allSatisfy { allowed.contains($0) }
            && query.filter(\.isNumber).count >= 1
    }

    var filteredContacts: [ContactItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return contacts }
        let q = query.lowercased()
        let queryDigits = q.filter(\.isNumber)
        return contacts.filter { item in
            item.displayName.lowercased().contains(q) ||
            (!queryDigits.isEmpty && item.phoneNumbers.contains {
                $0.filter(\.isNumber).contains(queryDigits)
            })
        }
    }

    func requestAccessAndLoad() async {
        if let cached = await ContactsCacheStore.shared.load() {
            rawContacts = cached
            applyContacts()
        }

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
        applyContacts()
    }

    func resetStatistics() {
        statsStore.resetAll()
        refresh()
    }

    private func loadContacts() async throws {
        rawContacts = try await contactsService.fetchContacts()
        ContactsCacheStore.shared.save(rawContacts.map {
            RawContact(id: $0.id, givenName: $0.givenName, familyName: $0.familyName,
                       phoneNumbers: $0.phoneNumbers, avatarData: nil,
                       imageDataAvailable: $0.imageDataAvailable)
        })
        applyContacts()
    }

    private func applyContacts() {
        var statsSnapshot: [String: Int] = [:]
        for raw in rawContacts {
            for phone in raw.phoneNumbers {
                let key = "\(raw.id)_\(phone.filter(\.isNumber))"
                statsSnapshot[key] = statsStore.callsCount(for: key)
            }
        }
        let snapshot = rawContacts

        Task.detached(priority: .userInitiated) { [weak self] in
            let result = snapshot
                .map { raw -> ContactItem in
                    let count = raw.phoneNumbers.reduce(0) { sum, phone in
                        sum + (statsSnapshot["\(raw.id)_\(phone.filter(\.isNumber))"] ?? 0)
                    }
                    return ContactItem(
                        id: raw.id,
                        givenName: raw.givenName,
                        familyName: raw.familyName,
                        phoneNumbers: raw.phoneNumbers,
                        hasAvatar: raw.imageDataAvailable,
                        outgoingCallsCount: count
                    )
                }
                .filter { $0.hasCallableNumber }
                .sorted { lhs, rhs in
                    if lhs.outgoingCallsCount != rhs.outgoingCallsCount {
                        return lhs.outgoingCallsCount > rhs.outgoingCallsCount
                    }
                    if lhs.hasName != rhs.hasName { return lhs.hasName }
                    if lhs.sortTitle != rhs.sortTitle { return lhs.sortTitle < rhs.sortTitle }
                    return lhs.id < rhs.id
                }
            let rawByID = Dictionary(uniqueKeysWithValues: snapshot.map { ($0.id, $0) })
            var didPrewarm = false
            for item in result where item.hasAvatar {
                guard AvatarCache.shared.image(for: item.id) == nil,
                      let data = rawByID[item.id]?.avatarData,
                      let full = UIImage(data: data) else { continue }
                AvatarCache.shared.store(full.avatarThumbnail(), for: item.id)
                didPrewarm = true
            }

            await MainActor.run { [weak self] in
                guard let self else { return }
                self.contacts = result
                if didPrewarm {
                    self.rawContacts = snapshot.map {
                        RawContact(id: $0.id, givenName: $0.givenName, familyName: $0.familyName,
                                   phoneNumbers: $0.phoneNumbers, avatarData: nil,
                                   imageDataAvailable: $0.imageDataAvailable)
                    }
                }
            }
        }
    }

    private func statKey(contactID: String, phoneNumber: String) -> String {
        "\(contactID)_\(phoneNumber.filter(\.isNumber))"
    }
}
