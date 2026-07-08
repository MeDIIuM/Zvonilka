import Foundation

final class ContactsCacheStore {
    static let shared = ContactsCacheStore()
    private init() {}

    private var cacheURL: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("zvonilka_contacts.plist")
    }

    func save(_ contacts: [RawContact]) {
        Task.detached(priority: .utility) {
            guard let data = try? PropertyListEncoder().encode(contacts) else { return }
            try? data.write(to: self.cacheURL, options: .atomic)
        }
    }

    func clear() {
        try? FileManager.default.removeItem(at: cacheURL)
    }

    func load() async -> [RawContact]? {
        await Task.detached(priority: .utility) {
            guard
                let data = try? Data(contentsOf: self.cacheURL),
                let contacts = try? PropertyListDecoder().decode([RawContact].self, from: data)
            else { return nil }
            return contacts
        }.value
    }

}
