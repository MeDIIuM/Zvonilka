import Contacts
import Foundation

protocol ContactsServiceProtocol {
    func requestAccess() async throws -> Bool
    func fetchContacts() async throws -> [RawContact]
}

final class ContactsService: ContactsServiceProtocol {
    func requestAccess() async throws -> Bool {
        let status = CNContactStore.authorizationStatus(for: .contacts)

        // Уже выдан полный доступ.
        if status == .authorized { return true }
        // iOS 18+: ограниченный доступ тоже пригоден — enumerate вернёт выбранные контакты.
        if #available(iOS 18.0, *), status == .limited { return true }
        // Доступ явно запрещён.
        if status == .denied || status == .restricted { return false }

        // .notDetermined — показываем системный запрос.
        let store = CNContactStore()
        let granted: Bool = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Bool, Error>) in
            store.requestAccess(for: .contacts) { granted, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: granted)
                }
            }
        }
        if granted { return true }
        // На iOS 18+ выбор «Ограниченный доступ» может вернуть granted == false,
        // но контакты при этом доступны — перепроверяем реальный статус.
        if #available(iOS 18.0, *) {
            return CNContactStore.authorizationStatus(for: .contacts) == .limited
        }
        return false
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
                                avatarData: avatar,
                                imageDataAvailable: contact.imageDataAvailable
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
