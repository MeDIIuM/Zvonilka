import Contacts
import Foundation

protocol ContactsServiceProtocol {
    func requestAccess() async throws -> Bool
    func fetchContacts() async throws -> [RawContact]
}

struct RawContact: Equatable {
    let id: String
    let givenName: String
    let familyName: String
    let phoneNumber: String?
    let avatarData: Data?
}

final class ContactsService: ContactsServiceProtocol {
    func requestAccess() async throws -> Bool {
        let store = CNContactStore()
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

    func fetchContacts() async throws -> [RawContact] {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let store = CNContactStore()
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

                do {
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

                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
