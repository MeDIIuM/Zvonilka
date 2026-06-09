import Foundation

struct ContactItem: Identifiable, Equatable {
    let id: String
    let givenName: String
    let familyName: String
    let phoneNumbers: [String]
    let hasAvatar: Bool
    let outgoingCallsCount: Int

    var phoneNumber: String? { phoneNumbers.first }

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

    var hasCallableNumber: Bool { !phoneNumbers.isEmpty }
}
