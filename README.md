# Звонилка (iOS MVP)

MVP iOS-приложения:
- один главный экран;
- сетка контактов;
- сортировка по количеству исходящих нажатий;
- быстрый вызов через системный dialer;
- локальное хранение без сервера.

## Что реализовано
- Доступ к контактам через `Contacts`
- Поиск по имени/фамилии/номеру
- Сетка карточек контактов (`LazyVGrid` adaptive)
- Круглые аватары: фото контакта или инициалы
- Кнопка `Позвонить` в карточке
- Локальный счетчик исходящих в `UserDefaults`
- Сортировка:
  1. больше исходящих выше
  2. при равенстве — по фамилии
  3. если фамилии нет — по имени
  4. если имени нет — fallback по номеру, затем в конец
- Настройки:
  - тема (системная / светлая / темная)
  - сброс счетчиков

## Ограничения MVP
- Нет записи звонков
- Нет серверного хранения
- Нет аналитики/CRM
- Нет входящих звонков
- Нет кастомного редактирования контактов

## Файлы
- `Sources/ZvonilkaApp.swift`
- `Sources/Models/ContactItem.swift`
- `Sources/Models/ThemeMode.swift`
- `Sources/Services/ContactsService.swift`
- `Sources/Services/CallStatsStore.swift`
- `Sources/ViewModels/ContactsGridViewModel.swift`
- `Sources/Views/ContactsGridView.swift`
- `Sources/Views/ContactGridCard.swift`
- `Sources/Views/SettingsView.swift`
- `Resources/Info.plist`

## Сборка в Xcode
1. Создайте iOS App (SwiftUI, iOS 16+).
2. Добавьте в target файлы из `Sources/`.
3. Убедитесь, что в `Info.plist` есть `NSContactsUsageDescription`.
4. Запустите на iPhone Simulator (iPhone 13 и выше).

Примечание: симулятор не делает реальный звонок по `tel://`, но логика нажатия и сортировки работает.
