import SwiftUI
import UIKit

struct ContactGridCard: View {
    let contact: ContactItem
    let callAction: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            avatar

            Text(contact.displayName)
                .font(.headline)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity)

            Text("Исходящих: \(contact.outgoingCallsCount)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button("Позвонить", action: callAction)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .padding(.top, 2)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 170)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    @ViewBuilder
    private var avatar: some View {
        if let data = contact.avatarData, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 84, height: 84)
                .clipShape(Circle())
        } else {
            Circle()
                .fill(avatarColor)
                .frame(width: 84, height: 84)
                .overlay {
                    Text(contact.initials)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                }
        }
    }

    private var avatarColor: Color {
        let palette: [Color] = [.teal, .blue, .green, .orange, .pink]
        let hash = abs(contact.id.hashValue)
        return palette[hash % palette.count]
    }
}
