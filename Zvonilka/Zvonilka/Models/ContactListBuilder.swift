import Foundation

nonisolated enum ContactListBuilder {
    static func statKey(contactID: String, phoneNumber: String) -> String {
        "\(contactID)_\(phoneNumber.filter(\.isNumber))"
    }

    static func build(_ rawContacts: [RawContact], statistics: [String: Int],
                      previousAvatarVersions: [String: Int]) -> [ContactItem] {
        rawContacts.map { raw in
            ContactItem(
                id: raw.id,
                givenName: raw.givenName,
                familyName: raw.familyName,
                phoneNumbers: raw.phoneNumbers,
                hasAvatar: raw.imageDataAvailable,
                outgoingCallsCount: raw.phoneNumbers.reduce(0) { sum, phone in
                    sum + (statistics[statKey(contactID: raw.id, phoneNumber: phone)] ?? 0)
                },
                avatarVersion: raw.imageDataAvailable
                    ? (raw.avatarData?.hashValue ?? previousAvatarVersions[raw.id] ?? 0) : 0
            )
        }
        .filter { $0.hasCallableNumber }
        .sorted(by: isOrderedBefore)
    }

    static func updatingStatistics(_ contacts: [ContactItem], statistics: [String: Int]) -> [ContactItem] {
        contacts.map { contact in
            ContactItem(id: contact.id, givenName: contact.givenName, familyName: contact.familyName,
                        phoneNumbers: contact.phoneNumbers, hasAvatar: contact.hasAvatar,
                        outgoingCallsCount: contact.phoneNumbers.reduce(0) { sum, phone in
                            sum + (statistics[statKey(contactID: contact.id, phoneNumber: phone)] ?? 0)
                        }, avatarVersion: contact.avatarVersion)
        }
        .sorted(by: isOrderedBefore)
    }

    private static func isOrderedBefore(_ lhs: ContactItem, _ rhs: ContactItem) -> Bool {
        if lhs.outgoingCallsCount != rhs.outgoingCallsCount {
            return lhs.outgoingCallsCount > rhs.outgoingCallsCount
        }
        if lhs.hasName != rhs.hasName { return lhs.hasName }
        if lhs.sortTitle != rhs.sortTitle { return lhs.sortTitle < rhs.sortTitle }
        return lhs.id < rhs.id
    }
}
