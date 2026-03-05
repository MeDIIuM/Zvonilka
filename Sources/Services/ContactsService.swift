import Contacts
import Foundation

protocol ContactsServiceProtocol {
    func requestAccess() async throws -> Bool
    func fetchContacts() throws -> [RawContact]
}

struct RawContact: Equatable {
    let id: String
    let givenName: String
    let familyName: String
    let phoneNumber: String?
    let avatarData: Data?
}

final class ContactsService: ContactsServiceProtocol {
    private let store = CNContactStore()

    func requestAccess() async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            store.requestAccess(for: .contacts) { granted, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: granted)
            }
        }
    }

    func fetchContacts() throws -> [RawContact] {
        let keys: [CNKeyDescriptor] = [
            CNContactIdentifierKey as CNKeyDescriptor,
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactImageDataKey as CNKeyDescriptor,
            CNContactImageDataAvailableKey as CNKeyDescriptor
        ]

        let request = CNContactFetchRequest(keysToFetch: keys)
        var result: [RawContact] = []

        try store.enumerateContacts(with: request) { contact, _ in
            let firstPhone = contact.phoneNumbers.first?.value.stringValue
            let avatar = contact.imageDataAvailable ? contact.imageData : nil

            result.append(
                RawContact(
                    id: contact.identifier,
                    givenName: contact.givenName,
                    familyName: contact.familyName,
                    phoneNumber: firstPhone,
                    avatarData: avatar
                )
            )
        }

        return result
    }
}
