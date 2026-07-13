import SwiftUI
import Contacts

struct ContactsGridView: View {
    @StateObject var viewModel: ContactsGridViewModel
    @Environment(\.openURL) private var openURL
    @Environment(\.colorScheme) private var systemColorScheme
    @AppStorage("zvonilka_theme_mode") private var themeModeRaw = ThemeMode.system.rawValue
    @State private var isSettingsPresented = false
    @State private var isNewContactPresented = false
    @State private var editingContactID: String? = nil
    @FocusState private var isSearchFocused: Bool
    private let defaultPhoneStore = DefaultPhoneStore()

    var body: some View {
        NavigationStack {
            content
                .background(appBackground.ignoresSafeArea())
                .toolbar(.hidden, for: .navigationBar)
        }
        .environment(\.colorScheme, effectiveColorScheme)
        .task {
            await viewModel.requestAccessAndLoad()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            viewModel.syncAuthorizationState()
        }
        .sheet(isPresented: $isSettingsPresented) {
            SettingsView(onResetStats: { viewModel.resetStatistics() })
                .preferredColorScheme(effectiveColorScheme)
        }
        .sheet(isPresented: $isNewContactPresented) {
            NewContactView(phoneNumber: viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        .sheet(isPresented: Binding(
            get: { editingContactID != nil },
            set: { if !$0 { editingContactID = nil } }
        )) {
            if let id = editingContactID {
                ContactEditView(contactID: id)
            }
        }
        .alert("Ошибка", isPresented: errorPresentedBinding) {
            Button("OK") { viewModel.loadingErrorMessage = nil }
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
            } else if viewModel.contacts.isEmpty
                        && viewModel.searchText.trimmingCharacters(in: .whitespaces).isEmpty
                        && viewModel.isContactsAuthorized {
                Spacer()
                emptyContactsView
                Spacer()
            } else if viewModel.filteredContacts.isEmpty && !viewModel.searchText.trimmingCharacters(in: .whitespaces).isEmpty {
                Spacer()
                emptySearchView
                Spacer()
            } else {
                gridContent
                    .blur(radius: viewModel.isReloading ? 12 : 0)
                    .animation(.easeInOut(duration: 0.25), value: viewModel.isReloading)
            }
        }
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            if !viewModel.permissionDenied && !viewModel.contacts.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.secondary)

                    TextField("Поиск по имени или номеру", text: $viewModel.searchText)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .focused($isSearchFocused)

                    if !viewModel.searchText.isEmpty {
                        Button {
                            viewModel.searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Очистить")
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .adaptiveGlass(cornerRadius: 12)
            } else {
                Spacer()
            }

            if isSearchFocused {
                Button("Отмена") {
                    viewModel.searchText = ""
                    isSearchFocused = false
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                Button {
                    isSettingsPresented = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(width: 42, height: 42)
                        .adaptiveGlass(cornerRadius: 12)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Настройки")
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSearchFocused)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: viewModel.searchText.isEmpty)
    }

    private var gridContent: some View {
        ContactsCollectionView(
            contacts: viewModel.filteredContacts,
            colorScheme: effectiveColorScheme,
            defaultPhoneStore: defaultPhoneStore,
            callAction: { contact, phoneNumber in call(contact, phoneNumber: phoneNumber) },
            editAction: { id in editingContactID = id }
        )
    }

    private var emptySearchView: some View {
        VStack(spacing: 16) {
            if viewModel.isPhoneNumberQuery {
                let number = viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
                Image(systemName: "phone.circle")
                    .font(.system(size: 52, weight: .light))
                    .foregroundStyle(.secondary)
                Text("Контакт не найден")
                    .font(.headline)
                Button {
                    callRawNumber(number)
                } label: {
                    Label("Позвонить на \(number)", systemImage: "phone.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal, 32)
                Button {
                    isNewContactPresented = true
                } label: {
                    Label("Создать контакт", systemImage: "person.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .padding(.horizontal, 32)
            } else {
                Image(systemName: "person.slash")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(.secondary)
                Text("Контакты не найдены")
                    .font(.headline)
                Text("Попробуйте изменить запрос")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }

    private func callRawNumber(_ number: String) {
        let digits = number.filter { "+0123456789".contains($0) }
        guard let url = URL(string: "tel://\(digits)") else { return }
        openURL(url)
        createContact(name: number, phone: digits)
    }

    private func createContact(name: String, phone: String) {
        Task.detached(priority: .utility) {
            let contact = CNMutableContact()
            contact.givenName = name
            contact.phoneNumbers = [CNLabeledValue(
                label: CNLabelPhoneNumberMobile,
                value: CNPhoneNumber(stringValue: phone)
            )]
            let request = CNSaveRequest()
            request.add(contact, toContainerWithIdentifier: nil)
            try? CNContactStore().execute(request)
        }
    }

    private var permissionDeniedView: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.circle")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.secondary)
            Text("Нет доступа к контактам")
                .font(.headline)
            Text("Разрешите доступ к контактам в настройках iOS.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Открыть настройки") { openAppSettings() }
                .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 32)
    }

    private var emptyContactsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.secondary)
            Text("Нет доступных контактов")
                .font(.headline)
            Text("Приложению доступны не все контакты. Откройте настройки, чтобы разрешить доступ ко всем контактам.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Открыть настройки") { openAppSettings() }
                .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 32)
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }

    private var errorPresentedBinding: Binding<Bool> {
        Binding(
            get: { viewModel.loadingErrorMessage != nil },
            set: { if !$0 { viewModel.loadingErrorMessage = nil } }
        )
    }

    private var effectiveColorScheme: ColorScheme {
        switch ThemeMode(rawValue: themeModeRaw) ?? .system {
        case .light:  return .light
        case .dark:   return .dark
        case .system: return systemColorScheme
        }
    }

    private var appBackground: LinearGradient {
        effectiveColorScheme == .dark
            ? LinearGradient(
                stops: [
                    .init(color: Color(red: 0.04, green: 0.08, blue: 0.20), location: 0.0),
                    .init(color: Color(red: 0.05, green: 0.14, blue: 0.22), location: 0.45),
                    .init(color: Color(red: 0.10, green: 0.08, blue: 0.06), location: 1.0)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              )
            : LinearGradient(
                stops: [
                    .init(color: Color(red: 0.55, green: 0.75, blue: 1.0), location: 0.0),
                    .init(color: Color(red: 0.70, green: 0.88, blue: 0.95), location: 0.45),
                    .init(color: Color(red: 0.88, green: 0.85, blue: 0.78), location: 1.0)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              )
    }

    private func call(_ contact: ContactItem, phoneNumber: String) {
        viewModel.registerOutgoingTap(for: contact, phoneNumber: phoneNumber)
        let digits = phoneNumber.filter { "+0123456789".contains($0) }
        guard let url = URL(string: "tel://\(digits)") else { return }
        openURL(url)
    }
}
