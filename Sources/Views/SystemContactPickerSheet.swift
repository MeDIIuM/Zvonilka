import Contacts
import ContactsUI
import SwiftUI

struct SystemContactPickerSheet: UIViewControllerRepresentable {
    let onPick: (PickedContact) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }

    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        picker.displayedPropertyKeys = [CNContactPhoneNumbersKey]
        picker.predicateForEnablingContact = NSPredicate(format: "phoneNumbers.@count > 0")
        return picker
    }

    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {}

    final class Coordinator: NSObject, CNContactPickerDelegate {
        let onPick: (PickedContact) -> Void

        init(onPick: @escaping (PickedContact) -> Void) {
            self.onPick = onPick
        }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            guard let first = contact.phoneNumbers.first?.value.stringValue else { return }
            let fullName = [contact.givenName, contact.familyName]
                .joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            onPick(
                PickedContact(
                    id: contact.identifier,
                    fullName: fullName.isEmpty ? "Без имени" : fullName,
                    phoneNumber: first
                )
            )
        }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contactProperty: CNContactProperty) {
            guard let number = contactProperty.value as? CNPhoneNumber else { return }
            let contact = contactProperty.contact
            let fullName = [contact.givenName, contact.familyName]
                .joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            onPick(
                PickedContact(
                    id: contact.identifier,
                    fullName: fullName.isEmpty ? "Без имени" : fullName,
                    phoneNumber: number.stringValue
                )
            )
        }
    }
}

struct PickedContact {
    let id: String
    let fullName: String
    let phoneNumber: String
}
