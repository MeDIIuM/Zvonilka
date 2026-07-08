import Foundation

final class DefaultPhoneStore {
    private let key = "default_phone_numbers"

    func defaultPhone(for contactID: String) -> String? {
        storage[contactID]
    }

    func setDefaultPhone(_ phone: String, for contactID: String) {
        var current = storage
        current[contactID] = phone
        UserDefaults.standard.set(current, forKey: key)
    }

    func toggleDefaultPhone(_ phone: String, for contactID: String) {
        var current = storage
        if current[contactID] == phone {
            current.removeValue(forKey: contactID)
        } else {
            current[contactID] = phone
        }
        UserDefaults.standard.set(current, forKey: key)
    }

    private var storage: [String: String] {
        UserDefaults.standard.dictionary(forKey: key) as? [String: String] ?? [:]
    }
}
