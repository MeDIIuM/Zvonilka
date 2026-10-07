import Foundation

final class ContactsCacheStore {
    static let shared = ContactsCacheStore()
    private init() {}
    private let ioQueue = DispatchQueue(label: "zvonilka.contacts-cache", qos: .utility)

    private var cacheURL: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("zvonilka_contacts.plist")
    }

    func save(_ contacts: [RawContact]) {
        let url = cacheURL
        ioQueue.async {
            guard let data = try? PropertyListEncoder().encode(contacts) else { return }
            try? data.write(to: url, options: .atomic)
        }
    }

    func clear() {
        let url = cacheURL
        ioQueue.async { try? FileManager.default.removeItem(at: url) }
    }

    func load() async -> [RawContact]? {
        let url = cacheURL
        return await withCheckedContinuation { continuation in
            ioQueue.async {
                guard let data = try? Data(contentsOf: url),
                      let contacts = try? PropertyListDecoder().decode([RawContact].self, from: data) else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: contacts)
            }
        }
    }

}
