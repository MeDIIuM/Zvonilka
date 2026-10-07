import Foundation

nonisolated enum ContactSearch {
    struct Index {
        let name: String
        private let phoneNumbers: [String]
        private let nationalPhoneNumbers: [String]

        init(name: String, phoneNumbers: [String]) {
            self.name = ContactSearch.normalized(name)
            self.phoneNumbers = phoneNumbers.map(ContactSearch.phoneDigits)
            self.nationalPhoneNumbers = self.phoneNumbers.map(ContactSearch.nationalPhoneDigits)
        }

        func matchesPhoneNumber(_ queryDigits: String) -> Bool {
            guard !queryDigits.isEmpty else { return false }
            return phoneNumbers.contains { $0.contains(queryDigits) } ||
                nationalPhoneNumbers.contains(ContactSearch.nationalPhoneDigits(queryDigits))
        }
    }

    // Общая форма для русского имени и его латинской транслитерации.
    // Многобуквенные сочетания сохраняются: «ш» → «sh», «щ» → «shch».
    private static let russianToLatin: [Character: String] = [
        "а": "a", "б": "b", "в": "v", "г": "g", "д": "d",
        "е": "e", "ё": "yo", "ж": "zh", "з": "z", "и": "i",
        "й": "y", "к": "k", "л": "l", "м": "m", "н": "n",
        "о": "o", "п": "p", "р": "r", "с": "s", "т": "t",
        "у": "u", "ф": "f", "х": "kh", "ц": "ts", "ч": "ch",
        "ш": "sh", "щ": "shch", "ъ": "", "ы": "y", "ь": "",
        "э": "e", "ю": "yu", "я": "ya"
    ]

    static func normalized(_ text: String) -> String {
        let latin = text.lowercased().map { russianToLatin[$0] ?? String($0) }.joined()
        return latin.folding(options: .diacriticInsensitive, locale: Locale(identifier: "en_US_POSIX"))
    }

    static func phoneDigits(_ text: String) -> String {
        text.filter(\.isNumber)
    }

    private static func nationalPhoneDigits(_ digits: String) -> String {
        // Полный российский номер с кодом +7 сопоставляем с десятизначным.
        // Короткие запросы оставляем целиком для поиска по части номера.
        guard digits.count == 11, digits.hasPrefix("7") else { return digits }
        return String(digits.dropFirst())
    }
}
