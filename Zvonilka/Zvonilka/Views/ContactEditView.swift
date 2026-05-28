import SwiftUI
import ContactsUI

struct ContactEditView: View {
    let contactID: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ContactEditRepresentable(contactID: contactID, onComplete: { dismiss() })
            .ignoresSafeArea()
    }
}

private struct ContactEditRepresentable: UIViewControllerRepresentable {
    let contactID: String
    let onComplete: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onComplete: onComplete) }

    func makeUIViewController(context: Context) -> UINavigationController {
        let store = CNContactStore()
        let keys = [CNContactViewController.descriptorForRequiredKeys()]
        guard let contact = try? store.unifiedContact(withIdentifier: contactID, keysToFetch: keys) else {
            return UINavigationController()
        }
        let vc = CNContactViewController(for: contact)
        vc.delegate = context.coordinator
        vc.allowsEditing = true
        return UINavigationController(rootViewController: vc)
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}

    class Coordinator: NSObject, CNContactViewControllerDelegate {
        let onComplete: () -> Void
        init(onComplete: @escaping () -> Void) { self.onComplete = onComplete }

        func contactViewController(_ viewController: CNContactViewController, didCompleteWith contact: CNContact?) {
            onComplete()
        }
    }
}
