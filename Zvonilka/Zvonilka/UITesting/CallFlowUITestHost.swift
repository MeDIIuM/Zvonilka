#if DEBUG
import Contacts
import Combine
import SwiftUI
import UIKit

// UI-тесты используют настоящий экран и кнопки с подменой недоступного
// в симуляторе tel://. Системные контакты и сохранённая статистика не затрагиваются.
struct CallFlowUITestHost: View {
    @StateObject private var session = FixtureCallSession()

    var body: some View {
        ContactsGridView(viewModel: session.viewModel, openCallURL: presentConfirmation)
    }

    private func presentConfirmation(_ url: URL, completion: @escaping (Bool) -> Void) {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first(where: \.isKeyWindow)?.rootViewController else {
            completion(false)
            return
        }
        let arguments = ProcessInfo.processInfo.arguments
        let alert = UIAlertController(title: "Подтверждение вызова", message: url.absoluteString,
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel) { _ in
            if arguments.contains("--cancel-reactivates") {
                NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
            }
        })
        alert.addAction(UIAlertAction(title: "Позвонить", style: .default) { _ in
            if arguments.contains("--transient-active") {
                NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
            }
            // Разделяем уведомления так же, как при переходе между приложениями.
            DispatchQueue.main.async {
                if arguments.contains("--confirm-before-background") {
                    session.monitor.emitOutgoingCall()
                }
                NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
                if !arguments.contains("--confirm-on-return"), !arguments.contains("--no-observed-call") {
                    session.monitor.emitOutgoingCall(hasEnded: arguments.contains("--ended-without-connection"))
                }
                NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
                if arguments.contains("--confirm-on-return") {
                    DispatchQueue.main.async {
                        session.monitor.emitOutgoingCall()
                    }
                }
            }
        })
        if arguments.contains("--cancel-reactivates") {
            NotificationCenter.default.post(name: UIApplication.willResignActiveNotification, object: nil)
        }
        // Воспроизводим ранний callback: true ещё до выбора кнопки в подтверждении.
        completion(true)
        root.present(alert, animated: true)
    }
}

@MainActor
private final class FixtureCallSession: ObservableObject {
    let monitor: FixtureOutgoingCallMonitor
    let viewModel: ContactsGridViewModel

    init() {
        let monitor = FixtureOutgoingCallMonitor()
        self.monitor = monitor
        viewModel = ContactsGridViewModel(
            contactsService: FixtureContactsService(), statsStore: FixtureStatsStore(),
            authorizationStatus: { .authorized }, usesContactCache: false,
            outgoingCallMonitor: monitor)
    }
}

// Только транспорт событий подменён. Учёт запроса и защита от повторных
// событий используют тот же CallAttemptState, что и настоящий CXCallObserver.
@MainActor
private final class FixtureOutgoingCallMonitor: OutgoingCallMonitoring {
    var onCallStarted: ((CallAttemptState.Confirmation) -> Void)?
    private var state = CallAttemptState()

    func begin(requestID: UUID, statisticsKey: String?) {
        state.begin(requestID: requestID, statisticsKey: statisticsKey, existingCallIDs: [])
    }

    func cancel(requestID: UUID?) { state.cancel(requestID: requestID) }
    func synchronize() {}

    func emitOutgoingCall(hasEnded: Bool = false) {
        let callID = UUID()
        for _ in 0..<3 {
            if let confirmation = state.observe(callID: callID, isOutgoing: true,
                                                hasConnected: false, hasEnded: hasEnded) {
                onCallStarted?(confirmation)
            }
        }
    }
}

private final class FixtureContactsService: ContactsServiceProtocol {
    private var fetchCount = 0

    func requestAccess() async throws -> Bool { true }

    func fetchContacts() async throws -> [RawContact] {
        fetchCount += 1
        if fetchCount > 1 { try await Task.sleep(nanoseconds: 2_000_000_000) }
        if ProcessInfo.processInfo.arguments.contains("--uitesting-contact-layout") {
            return layoutContacts()
        }
        return [
            RawContact(id: "anna", givenName: "Анна", familyName: "",
                       phoneNumbers: ["+7 111 222-33-44"], avatarData: nil),
            RawContact(id: "sasha", givenName: "Саша", familyName: "",
                       phoneNumbers: ["+7 999 123-45-67"], avatarData: nil)
        ]
    }

    private func layoutContacts() -> [RawContact] {
        func contact(_ id: String, _ givenName: String, _ familyName: String,
                     photoText: String? = nil, missingPhoto: Bool = false) -> RawContact {
            let photo = photoText.map { text in
                UIGraphicsImageRenderer(size: CGSize(width: 256, height: 256)).image { _ in
                    UIColor.systemIndigo.setFill()
                    UIBezierPath(rect: CGRect(x: 0, y: 0, width: 256, height: 256)).fill()
                    let attributes: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: 90, weight: .medium),
                        .foregroundColor: UIColor.white
                    ]
                    let size = (text as NSString).size(withAttributes: attributes)
                    (text as NSString).draw(at: CGPoint(x: (256 - size.width) / 2,
                                                      y: (256 - size.height) / 2),
                                           withAttributes: attributes)
                }.pngData()
            }.flatMap { $0 }
            return RawContact(id: id, givenName: givenName, familyName: familyName,
                              phoneNumbers: ["+7 999 123-45-67"], avatarData: photo,
                              imageDataAvailable: photo != nil || missingPhoto)
        }
        return [
            contact("photo-full", "Анна", "Александрова", photoText: "АА"),
            contact("photo-given", "Богдан", "", photoText: "Б"),
            contact("photo-family", "", "Васильева", photoText: "В"),
            contact("photo-unavailable", "Григорий", "Громов", missingPhoto: true),
            contact("plain-full", "Дмитрий", "Даниленко"),
            contact("plain-given", "Екатерина", ""),
            contact("plain-family", " \n ", "Жукова"),
            contact("plain-empty", " ", "\n")
        ]
    }
}

private final class FixtureStatsStore: CallStatsStoreProtocol {
    private var counts: [String: Int] = [:]
    func callsCount(for key: String) -> Int { counts[key] ?? 0 }
    func snapshot() -> [String: Int] { counts }
    func incrementCall(for key: String) { counts[key, default: 0] += 1 }
    func resetAll() { counts = [:] }
}
#endif
