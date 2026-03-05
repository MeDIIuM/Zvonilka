import Foundation

struct ContactItem: Identifiable, Equatable {
    let id: String
    let givenName: String
    let familyName: String
    let phoneNumber: String?
    let avatarData: Data?
    let outgoingCallsCount: Int

    var displayName: String {
        let parts = [givenName, familyName].filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        if parts.isEmpty { return "Без имени" }
        return parts.joined(separator: " ")
    }

    var sortTitle: String {
        let family = familyName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !family.isEmpty { return family.lowercased() }

        let given = givenName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !given.isEmpty { return given.lowercased() }

        let number = normalizedNumber
        if !number.isEmpty { return number }

        return "~~~~"
    }

    var hasName: Bool {
        !givenName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !familyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var normalizedNumber: String {
        phoneNumber?.filter(\.isNumber) ?? ""
    }

    var hasCallableNumber: Bool {
        guard let phoneNumber else { return false }
        return !phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var initials: String {
        let source = [givenName, familyName]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let letters = source.prefix(2).compactMap { $0.first }
        if letters.isEmpty { return "?" }
        return String(letters).uppercased()
    }
}
