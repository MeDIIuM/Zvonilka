import SwiftUI

struct ContactsListView: View {
    @StateObject var viewModel: ContactsListViewModel
    @Environment(\.openURL) private var openURL
    @State private var isSystemPickerPresented = false

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.permissionDenied {
                    permissionDeniedView
                } else {
                    listView
                }
            }
            .navigationTitle("Звонилка")
            .searchable(text: $viewModel.searchText, prompt: "Поиск")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Системный выбор") {
                        isSystemPickerPresented = true
                    }
                }
            }
        }
        .task {
            await viewModel.requestAccessAndLoad()
        }
        .sheet(isPresented: $isSystemPickerPresented) {
            SystemContactPickerSheet { picked in
                let contact = ContactItem(
                    id: picked.id,
                    fullName: picked.fullName,
                    phoneNumber: picked.phoneNumber,
                    avatarData: nil,
                    outgoingCallsCount: 0
                )
                call(contact)
            }
        }
        .alert("Ошибка", isPresented: .constant(viewModel.loadingErrorMessage != nil)) {
            Button("OK") {
                viewModel.loadingErrorMessage = nil
            }
        } message: {
            Text(viewModel.loadingErrorMessage ?? "")
        }
    }

    private var listView: some View {
        List(viewModel.filteredContacts) { contact in
            ContactRowView(contact: contact) {
                call(contact)
            }
        }
        .listStyle(.plain)
    }

    private var permissionDeniedView: some View {
        VStack(spacing: 12) {
            Text("Нет доступа к контактам")
                .font(.headline)
            Text("Разрешите доступ к контактам в настройках iOS.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("Обновить") {
                viewModel.refresh()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private func call(_ contact: ContactItem) {
        guard let number = contact.phoneNumber else { return }

        // По MVP инкремент фиксируем в момент нажатия, до результата звонка.
        viewModel.registerOutgoingTapAndResort(for: contact)

        let digits = number.filter { "+0123456789".contains($0) }
        guard let url = URL(string: "tel://\(digits)") else { return }
        openURL(url)
    }
}
