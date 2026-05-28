import SwiftUI
import UIKit

struct ContactGridCard: View {
    let contact: ContactItem
    let defaultPhoneStore: DefaultPhoneStore
    let callAction: (String) -> Void

    @State private var showNumberPicker = false
    @State private var showContactEdit = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if contact.avatarData != nil {
                fullCard
            } else {
                compactCard
            }
            callBadge
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .colorScheme(colorScheme)
        .contextMenu {
            Button {
                showContactEdit = true
            } label: {
                Label("Редактировать контакт", systemImage: "person.crop.circle")
            }
            if contact.phoneNumbers.count > 1 {
                Menu {
                    ForEach(contact.phoneNumbers, id: \.self) { number in
                        Button {
                            defaultPhoneStore.toggleDefaultPhone(number, for: contact.id)
                        } label: {
                            Label(
                                number,
                                systemImage: defaultPhoneStore.defaultPhone(for: contact.id) == number
                                    ? "checkmark" : "phone"
                            )
                        }
                    }
                } label: {
                    Label("Номер по умолчанию", systemImage: "phone.fill.badge.plus")
                }
            }
        }
        .sheet(isPresented: $showContactEdit) {
            ContactEditView(contactID: contact.id)
        }
        .confirmationDialog("Выберите номер", isPresented: $showNumberPicker, titleVisibility: .visible) {
            ForEach(contact.phoneNumbers, id: \.self) { number in
                Button(number) { callAction(number) }
            }
        }
    }

    // MARK: - Card variants

    private var fullCard: some View {
        VStack(spacing: 2) {
            Button { triggerCall() } label: { avatar }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            nameText
                .frame(height: 40, alignment: .center)
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .adaptiveGlass(cornerRadius: 16)
    }

    private var compactCard: some View {
        Button { triggerCall() } label: {
            nameText
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .padding(10)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .adaptiveGlass(cornerRadius: 16)
    }

    // MARK: - Shared components

    private var nameText: some View {
        VStack(spacing: 1) {
            if !contact.givenName.isEmpty {
                Text(contact.givenName)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            if !contact.familyName.isEmpty {
                Text(contact.familyName)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .font(.subheadline)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }

    private var callBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: "phone.fill")
                .font(.system(size: 10))
            Text("\(contact.outgoingCallsCount)")
                .font(.caption)
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(.ultraThinMaterial, in: Capsule())
        .padding(6)
    }

    @ViewBuilder
    private var avatar: some View {
        if let data = contact.avatarData, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 64, height: 64)
                .clipShape(Circle())
        }
    }

    private var avatarColor: Color {
        let palette: [Color] = [.teal, .blue, .green, .orange, .pink]
        let hash = abs(contact.id.hashValue)
        return palette[hash % palette.count]
    }

    private func triggerCall() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if contact.phoneNumbers.count == 1 {
            callAction(contact.phoneNumbers[0])
        } else if let defaultPhone = defaultPhoneStore.defaultPhone(for: contact.id),
                  contact.phoneNumbers.contains(defaultPhone) {
            callAction(defaultPhone)
        } else {
            showNumberPicker = true
        }
    }
}

extension View {
    @ViewBuilder
    func adaptiveGlass(cornerRadius: CGFloat) -> some View {
        if #available(iOS 26, *) {
            self.glassEffect(in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        } else {
            self
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }
}
