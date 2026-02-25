import Foundation

protocol CallStatsStoreProtocol {
    func callsCount(for key: String) -> Int
    func incrementCall(for key: String)
}

final class CallStatsStore: CallStatsStoreProtocol {
    private let userDefaults: UserDefaults
    private let storageKey = "outgoing_call_stats"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func callsCount(for key: String) -> Int {
        storage[key] ?? 0
    }

    func incrementCall(for key: String) {
        var currentStorage = storage
        currentStorage[key, default: 0] += 1
        userDefaults.set(currentStorage, forKey: storageKey)
    }

    private var storage: [String: Int] {
        userDefaults.dictionary(forKey: storageKey) as? [String: Int] ?? [:]
    }
}
