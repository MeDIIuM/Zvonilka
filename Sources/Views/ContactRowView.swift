import SwiftUI
import UIKit

struct ContactRowView: View {
    let contact: ContactItem
    let callAction: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            avatar

            VStack(alignment: .leading, spacing: 2) {
                Text(contact.fullName)
                    .lineLimit(1)
                    .font(.body)
                Text("Исходящих: \(contact.outgoingCallsCount)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Позвонить", action: callAction)
                .buttonStyle(.borderedProminent)
                .font(.callout)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var avatar: some View {
        if let data = contact.avatarData, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 44, height: 44)
                .clipShape(Circle())
        } else {
            Circle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 44, height: 44)
                .overlay {
                    Text(initials(contact.fullName))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
        }
    }

    private func initials(_ name: String) -> String {
        let parts = name.split(separator: " ")
        let letters = parts.prefix(2).compactMap { $0.first }
        if letters.isEmpty { return "?" }
        return String(letters)
    }
}
