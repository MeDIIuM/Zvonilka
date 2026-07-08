import SwiftUI
import ContactsUI

struct NewContactView: View {
    let phoneNumber: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NewContactRepresentable(phoneNumber: phoneNumber, onComplete: { dismiss() })
            .ignoresSafeArea()
    }
}

private struct NewContactRepresentable: UIViewControllerRepresentable {
    let phoneNumber: String
    let onComplete: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onComplete: onComplete) }

    func makeUIViewController(context: Context) -> UINavigationController {
        let contact = CNMutableContact()
        contact.givenName = phoneNumber
        contact.phoneNumbers = [
            CNLabeledValue(label: CNLabelPhoneNumberMain,
                           value: CNPhoneNumber(stringValue: phoneNumber))
        ]
        let vc = CNContactViewController(forNewContact: contact)
        vc.delegate = context.coordinator
        return UINavigationController(rootViewController: vc)
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}

    class Coordinator: NSObject, CNContactViewControllerDelegate {
        let onComplete: () -> Void
        init(onComplete: @escaping () -> Void) { self.onComplete = onComplete }

        func contactViewController(_ viewController: CNContactViewController,
                                   didCompleteWith contact: CNContact?) {
            onComplete()
        }
    }
}
