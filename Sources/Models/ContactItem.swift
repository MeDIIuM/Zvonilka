import Foundation

struct ContactItem: Identifiable, Equatable {
    let id: String
    let fullName: String
    let phoneNumber: String?
    let avatarData: Data?
    let outgoingCallsCount: Int

    var hasCallableNumber: Bool {
        guard let phoneNumber else { return false }
        return !phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
