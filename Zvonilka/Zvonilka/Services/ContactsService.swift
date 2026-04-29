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
    let phoneNumbers: [String]
    let avatarData: Data?
}

final class ContactsService: ContactsServiceProtocol {
    func requestAccess() async throws -> Bool {
        let store = CNContactStore()
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Bool, Error>) in
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
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[RawContact], Error>) in
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
                        let phones = contact.phoneNumbers.map { $0.value.stringValue }
                        let avatar = contact.imageDataAvailable ? contact.imageData : nil

                        result.append(
                            RawContact(
                                id: contact.identifier,
                                givenName: contact.givenName,
                                familyName: contact.familyName,
                                phoneNumbers: phones,
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
