import Foundation
import Combine
import Contacts
import UIKit

@MainActor
final class ContactsGridViewModel: ObservableObject {
    @Published var contacts: [ContactItem] = [] {
        didSet {
            contactSearchKeys = contacts.reduce(into: [:]) { keys, contact in
                keys[contact.id] = ContactSearch.Index(name: contact.displayName,
                                                     phoneNumbers: contact.phoneNumbers)
            }
        }
    }
    @Published var searchText: String = ""
    @Published var permissionDenied = false
    @Published var loadingErrorMessage: String?
    private let contactsService: ContactsServiceProtocol
    private let statsStore: CallStatsStoreProtocol
    private let authorizationStatus: () -> CNAuthorizationStatus
    private let usesContactCache: Bool
    private var rawContacts: [RawContact] = []
    private var contactSearchKeys: [String: ContactSearch.Index] = [:]
    private var cancellables = Set<AnyCancellable>()
    private var lastAuthorizationStatus: CNAuthorizationStatus?
    private var cachedContacts: [RawContact]?
    private var refreshTask: Task<Void, Never>?
    private var refreshPending = false
    private var applyRevision = 0
    private var callDisplayState = CallDisplayState()
    private let outgoingCallMonitor: OutgoingCallMonitoring

    init(contactsService: ContactsServiceProtocol, statsStore: CallStatsStoreProtocol,
         authorizationStatus: @escaping () -> CNAuthorizationStatus = { CNContactStore.authorizationStatus(for: .contacts) },
         usesContactCache: Bool = true, outgoingCallMonitor: OutgoingCallMonitoring? = nil) {
        self.contactsService = contactsService
        self.statsStore = statsStore
        self.authorizationStatus = authorizationStatus
        self.usesContactCache = usesContactCache
        self.outgoingCallMonitor = outgoingCallMonitor ?? OutgoingCallMonitor()
        self.outgoingCallMonitor.onCallStarted = { [weak self] confirmation in
            guard let self else { return }
            if let key = confirmation.statisticsKey { self.statsStore.incrementCall(for: key) }
            self.applyStoredStatistics()
        }

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
        let normalizedQuery = ContactSearch.normalized(query)
        let queryDigits = ContactSearch.phoneDigits(query)
        return contacts.filter { item in
            item.displayName.lowercased().contains(q) ||
            (!normalizedQuery.isEmpty &&
             (contactSearchKeys[item.id]?.name.contains(normalizedQuery) ?? false)) ||
            (contactSearchKeys[item.id]?.matchesPhoneNumber(queryDigits) ?? false)
        }
    }

    var isContactsAuthorized: Bool {
        let status = authorizationStatus()
        if status == .authorized { return true }
        if #available(iOS 18.0, *), status == .limited { return true }
        return false
    }

    func requestAccessAndLoad() async {
        if usesContactCache, isContactsAuthorized, let cached = await ContactsCacheStore.shared.load() {
            rawContacts = cached
            cachedContacts = cached
            await applyContacts()
        }

        do {
            _ = try await contactsService.requestAccess()
        } catch {
            loadingErrorMessage = "Ошибка доступа к контактам: \(error.localizedDescription)"
        }
        syncAuthorizationState()
    }

    /// Приводит состояние экрана к фактическому статусу доступа и грузит контакты, если доступ есть.
    @discardableResult
    func syncAuthorizationState(forceRefresh: Bool = false) -> Task<Void, Never>? {
        let status = authorizationStatus()
        let authorizationChanged = lastAuthorizationStatus != status
        lastAuthorizationStatus = status
        let denied = (status == .denied || status == .restricted)
        if permissionDenied != denied { permissionDenied = denied }
        guard isContactsAuthorized else {
            // Доступ отозван/запрещён — не держим устаревшие контакты в памяти и кэше.
            applyRevision += 1
            if !contacts.isEmpty { contacts = [] }
            rawContacts = []
            if cachedContacts != [] {
                cachedContacts = []
                if usesContactCache { ContactsCacheStore.shared.save([]) }
            }
            return nil
        }
        guard forceRefresh || authorizationChanged else { return nil }
        return refresh()
    }

    @discardableResult
    func refresh() -> Task<Void, Never> {
        refreshPending = true
        if let refreshTask { return refreshTask }
        let task = Task { [weak self] in
            guard let self else { return }
            // События, пришедшие во время загрузки, объединяются в следующий проход.
            while self.refreshPending {
                self.refreshPending = false
                do {
                    try await self.loadContacts()
                } catch {
                    self.loadingErrorMessage = "Ошибка обновления: \(error.localizedDescription)"
                    await self.applyContacts()
                }
            }
            self.refreshTask = nil
        }
        refreshTask = task
        return task
    }

    func applicationDidEnterBackground() {
        outgoingCallMonitor.synchronize()
        callDisplayState.didEnterBackground()
    }

    func applicationDidBecomeActive() -> Bool {
        outgoingCallMonitor.synchronize()
        let returnedFromBackground = callDisplayState.didBecomeActive()
        if returnedFromBackground {
            applyStoredStatistics()
        }
        // Сортировка не ждёт чтения адресной книги и подготовки изображений.
        syncAuthorizationState(forceRefresh: returnedFromBackground)
        return returnedFromBackground
    }

    func beginCallAttempt(requestID: UUID, contact: ContactItem?, phoneNumber: String) {
        let key = contact.map { ContactListBuilder.statKey(contactID: $0.id, phoneNumber: phoneNumber) }
        outgoingCallMonitor.begin(requestID: requestID, statisticsKey: key)
    }

    func cancelCallAttempt(requestID: UUID) {
        outgoingCallMonitor.cancel(requestID: requestID)
    }

    func resetStatistics() {
        statsStore.resetAll()
        applyStoredStatistics()
    }

    private func loadContacts() async throws {
        let fetched = try await contactsService.fetchContacts()
        guard isContactsAuthorized else { return }
        rawContacts = fetched
        let cacheSnapshot = fetched.map(\.withoutAvatarData)
        if cachedContacts != cacheSnapshot {
            cachedContacts = cacheSnapshot
            if usesContactCache { ContactsCacheStore.shared.save(cacheSnapshot) }
        }
        await applyContacts()
    }

    private func applyStoredStatistics() {
        let updated = ContactListBuilder.updatingStatistics(contacts, statistics: statsStore.snapshot())
        if contacts != updated { contacts = updated }
    }

    private func applyContacts() async {
        applyRevision += 1
        let revision = applyRevision
        let snapshot = rawContacts
        let statistics = statsStore.snapshot()
        let avatarVersions = Dictionary(uniqueKeysWithValues: contacts.map { ($0.id, $0.avatarVersion) })
        let cachedAvatarIDs = Set(snapshot.filter { AvatarCache.shared.image(for: $0.id) != nil }.map(\.id))

        let (result, thumbnails) = await Task.detached(priority: .userInitiated) {
            let result = ContactListBuilder.build(snapshot, statistics: statistics,
                                                 previousAvatarVersions: avatarVersions)
            let rawByID = Dictionary(uniqueKeysWithValues: snapshot.map { ($0.id, $0) })
            var thumbnails: [String: UIImage] = [:]
            for item in result where item.hasAvatar {
                guard !cachedAvatarIDs.contains(item.id) || avatarVersions[item.id] != item.avatarVersion,
                      let data = rawByID[item.id]?.avatarData,
                      let full = UIImage(data: data) else { continue }
                thumbnails[item.id] = full.avatarThumbnail()
            }
            return (result, thumbnails)
        }.value

        // Более новая загрузка или отзыв доступа могут завершиться раньше этой задачи.
        guard revision == applyRevision else { return }
        for (id, thumbnail) in thumbnails { AvatarCache.shared.store(thumbnail, for: id) }
        // За время подготовки фото мог начаться звонок или сброситься статистика.
        let updated = ContactListBuilder.updatingStatistics(result, statistics: statsStore.snapshot())
        if contacts != updated { contacts = updated }
        rawContacts = snapshot.map(\.withoutAvatarData)
    }
}
