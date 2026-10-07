import CallKit
import Foundation
import UIKit

@MainActor
protocol OutgoingCallMonitoring: AnyObject {
    var onCallStarted: ((CallAttemptState.Confirmation) -> Void)? { get set }
    func begin(requestID: UUID, statisticsKey: String?)
    func cancel(requestID: UUID?)
    func synchronize()
}

@MainActor
final class OutgoingCallMonitor: NSObject, CXCallObserverDelegate, OutgoingCallMonitoring {
    var onCallStarted: ((CallAttemptState.Confirmation) -> Void)?
    private let observer = CXCallObserver()
    private var state = CallAttemptState()
    private var observationTask: UIBackgroundTaskIdentifier = .invalid

    override init() {
        super.init()
        observer.setDelegate(self, queue: .main)
    }

    func begin(requestID: UUID, statisticsKey: String?) {
        finishObservationTask()
        state.begin(requestID: requestID, statisticsKey: statisticsKey,
                    existingCallIDs: Set(observer.calls.map(\.uuid)))
        // Даём приложению закончить учёт начала вызова после перехода в Телефон.
        // Системная задача ограничена по времени и завершается при первом событии.
        observationTask = UIApplication.shared.beginBackgroundTask(withName: "Observe outgoing call") { [weak self] in
            guard let self, self.state.pendingRequestID == requestID else { return }
            self.state.cancel(requestID: requestID)
            self.finishObservationTask()
        }
    }

    func cancel(requestID: UUID? = nil) {
        let pendingID = state.pendingRequestID
        state.cancel(requestID: requestID)
        if pendingID != nil, state.pendingRequestID == nil { finishObservationTask() }
    }

    func synchronize() {
        for call in observer.calls { observe(call) }
    }

    nonisolated func callObserver(_ callObserver: CXCallObserver, callChanged call: CXCall) {
        // Делегат настроен на main queue. Обрабатываем событие сразу, чтобы оно
        // не осталось в очереди за обработчиком возврата приложения из фона.
        MainActor.assumeIsolated { observe(call) }
    }

    private func observe(_ call: CXCall) {
        if let confirmation = state.observe(callID: call.uuid, isOutgoing: call.isOutgoing,
                                            hasConnected: call.hasConnected, hasEnded: call.hasEnded) {
            onCallStarted?(confirmation)
            finishObservationTask()
        }
    }

    private func finishObservationTask() {
        guard observationTask != .invalid else { return }
        UIApplication.shared.endBackgroundTask(observationTask)
        observationTask = .invalid
    }
}
