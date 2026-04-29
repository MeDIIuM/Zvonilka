import SwiftUI

struct ContactsGridView: View {
    @StateObject var viewModel: ContactsGridViewModel
    @Environment(\.openURL) private var openURL
    @State private var isSettingsPresented = false

    var body: some View {
        NavigationStack {
            content
                .background(Color(.systemBackground).ignoresSafeArea())
                .toolbar(.hidden, for: .navigationBar)
        }
        .task {
            await viewModel.requestAccessAndLoad()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            viewModel.refresh()
        }
        .sheet(isPresented: $isSettingsPresented) {
            SettingsView(
                onResetStats: {
                    viewModel.resetStatistics()
                }
            )
        }
        .alert("Ошибка", isPresented: errorPresentedBinding) {
            Button("OK") {
                viewModel.loadingErrorMessage = nil
            }
        } message: {
            Text(viewModel.loadingErrorMessage ?? "")
        }
    }

    private var content: some View {
        VStack(spacing: 12) {
            topBar
                .padding(.horizontal, 16)
                .padding(.top, 8)

            if viewModel.permissionDenied {
                Spacer()
                permissionDeniedView
                Spacer()
            } else {
                gridContent
            }
        }
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            TextField("Поиск по имени или номеру", text: $viewModel.searchText)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            Button {
                isSettingsPresented = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 42, height: 42)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Настройки")
        }
    }

    private var gridContent: some View {
        ScrollView {
            LazyVGrid(columns: gridColumns, spacing: 12) {
                ForEach(viewModel.filteredContacts) { contact in
                    ContactGridCard(contact: contact) { phoneNumber in
                        call(contact, phoneNumber: phoneNumber)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
        .scrollDismissesKeyboard(.immediately)
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

    private var errorPresentedBinding: Binding<Bool> {
        Binding(
            get: { viewModel.loadingErrorMessage != nil },
            set: { newValue in
                if !newValue {
                    viewModel.loadingErrorMessage = nil
                }
            }
        )
    }

    private var gridColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 142, maximum: 220), spacing: 12)]
    }

    private func call(_ contact: ContactItem, phoneNumber: String) {
        viewModel.registerOutgoingTap(for: contact, phoneNumber: phoneNumber)
        let digits = phoneNumber.filter { "+0123456789".contains($0) }
        guard let url = URL(string: "tel://\(digits)") else { return }
        openURL(url)
    }
}



