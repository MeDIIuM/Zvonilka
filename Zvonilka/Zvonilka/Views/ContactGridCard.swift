import SwiftUI
import UIKit

struct ContactGridCard: View {
    let contact: ContactItem
    let callAction: (String) -> Void

    @State private var showNumberPicker = false

    var body: some View {
        VStack(spacing: 10) {
            avatar

            VStack(spacing: 0) {
                Text(contact.displayName)
                    .font(.headline)
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .multilineTextAlignment(.center)
                    .frame(height: 44, alignment: .top)
                    .frame(maxWidth: .infinity)

                Text("Исходящих: \(contact.outgoingCallsCount)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button("Позвонить") {
                if contact.phoneNumbers.count == 1 {
                    callAction(contact.phoneNumbers[0])
                } else {
                    showNumberPicker = true
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .padding(.top, 2)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 170)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .confirmationDialog("Выберите номер", isPresented: $showNumberPicker, titleVisibility: .visible) {
            ForEach(contact.phoneNumbers, id: \.self) { number in
                Button(number) { callAction(number) }
            }
        }
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
