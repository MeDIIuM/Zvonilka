import Foundation

@main
struct CallAttemptStateTests {
    static func main() {
        var checks = 0
        func check(_ condition: @autoclosure () -> Bool, _ message: String) {
            assert(condition(), message)
            checks += 1
        }

        var state = CallAttemptState()
        let existingCall = UUID()
        let incomingCall = UUID()
        let firstRequest = UUID()
        let secondRequest = UUID()
        let outgoingCall = UUID()
        let key = "sasha_79991234567"
        var count = 0

        state.begin(requestID: firstRequest, statisticsKey: key, existingCallIDs: [existingCall])
        check(count == 0, "Opening the confirmation must not increment the counter")
        check(state.observe(callID: incomingCall, isOutgoing: false, hasConnected: false, hasEnded: false) == nil,
              "An incoming call must not count")
        check(state.observe(callID: existingCall, isOutgoing: true, hasConnected: true, hasEnded: false) == nil,
              "An existing outgoing call must not count")
        check(state.observe(callID: existingCall, isOutgoing: true, hasConnected: false, hasEnded: true) == nil,
              "Ending an existing call must not count")
        state.cancel(requestID: firstRequest)
        check(state.observe(callID: outgoingCall, isOutgoing: true, hasConnected: false, hasEnded: false) == nil,
              "A cancelled request must not be associated with a later outgoing call")

        state.begin(requestID: secondRequest, statisticsKey: key, existingCallIDs: [existingCall])
        let confirmation = state.observe(callID: outgoingCall, isOutgoing: true,
                                         hasConnected: false, hasEnded: false)
        if confirmation?.statisticsKey == key { count += 1 }
        check(confirmation?.requestID == secondRequest, "The confirmation belongs to the second request")
        check(count == 1, "Cancel then call must produce one increment")
        check(state.observe(callID: outgoingCall, isOutgoing: true, hasConnected: false, hasEnded: false) == nil,
              "Repeated dialing events must not count twice")
        check(state.observe(callID: outgoingCall, isOutgoing: true, hasConnected: true, hasEnded: false) == nil,
              "Connection must not count the same call again")
        check(state.observe(callID: outgoingCall, isOutgoing: true, hasConnected: true, hasEnded: true) == nil,
              "Ending must not count the same call again")
        check(count == 1, "The counter remains one")

        // Новый запрос заменяет отменённый даже если callback открытия URL задержался.
        state.begin(requestID: firstRequest, statisticsKey: "old", existingCallIDs: [])
        state.begin(requestID: secondRequest, statisticsKey: key, existingCallIDs: [])
        state.cancel(requestID: firstRequest)
        check(state.observe(callID: UUID(), isOutgoing: true, hasConnected: false, hasEnded: false)?.statisticsKey == key,
              "A delayed cancellation must not cancel the new request")

        state.begin(requestID: firstRequest, statisticsKey: nil, existingCallIDs: [])
        let unknown = state.observe(callID: UUID(), isOutgoing: true, hasConnected: false, hasEnded: false)
        check(unknown?.requestID == firstRequest, "Calling an unknown number can be observed")
        check(unknown?.statisticsKey == nil, "An unknown number must not create contact statistics")

        state.begin(requestID: firstRequest, statisticsKey: key, existingCallIDs: [])
        state.cancel()
        check(state.observe(callID: UUID(), isOutgoing: true, hasConnected: true, hasEnded: false) == nil,
              "Explicitly cancelling an attempt must prevent a later increment")

        state.begin(requestID: secondRequest, statisticsKey: key, existingCallIDs: [])
        check(state.observe(callID: UUID(), isOutgoing: true, hasConnected: true, hasEnded: true)?.statisticsKey == key,
              "A connected call delivered on return is evidence of a started call")
        state.begin(requestID: secondRequest, statisticsKey: key, existingCallIDs: [])
        check(state.observe(callID: UUID(), isOutgoing: true, hasConnected: false, hasEnded: true)?.statisticsKey == key,
              "An unanswered outgoing call delivered only after ending must count")
        print("CallAttemptState: all \(checks) checks passed")
    }
}
