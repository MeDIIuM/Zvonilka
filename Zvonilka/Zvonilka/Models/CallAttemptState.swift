import Foundation

// CallKit не раскрывает номер. Новый исходящий вызов сопоставляется с текущим
// запросом приложения; уже существовавшие вызовы исключаются.
nonisolated struct CallAttemptState {
    struct Confirmation: Equatable {
        let requestID: UUID
        let statisticsKey: String?
    }

    private struct Attempt {
        let requestID: UUID
        let statisticsKey: String?
        let existingCallIDs: Set<UUID>
    }

    private var attempt: Attempt?

    var pendingRequestID: UUID? { attempt?.requestID }

    mutating func begin(requestID: UUID, statisticsKey: String?, existingCallIDs: Set<UUID>) {
        attempt = Attempt(requestID: requestID, statisticsKey: statisticsKey,
                          existingCallIDs: existingCallIDs)
    }

    mutating func cancel(requestID: UUID? = nil) {
        if requestID == nil || attempt?.requestID == requestID { attempt = nil }
    }

    mutating func observe(callID: UUID, isOutgoing: Bool, hasConnected: Bool,
                         hasEnded: Bool) -> Confirmation? {
        // Даже если первым пришло событие завершения без ответа, наличие нового
        // исходящего CXCall подтверждает попытку вызова. Отмена tel-попапа его не создаёт.
        guard let attempt, isOutgoing, !attempt.existingCallIDs.contains(callID) else { return nil }
        self.attempt = nil
        return Confirmation(requestID: attempt.requestID, statisticsKey: attempt.statisticsKey)
    }
}
