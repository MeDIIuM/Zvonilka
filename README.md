# Звонилка (iOS MVP)

MVP iOS-приложения:
- один главный экран;
- сетка контактов;
- сортировка по количеству исходящих нажатий;
- быстрый вызов через системный dialer;
- локальное хранение без сервера.

## Что реализовано
- Доступ к контактам через `Contacts`
- Поиск по имени/фамилии/номеру, клавиатура скрывается при скролле
- Сетка карточек контактов (`LazyVGrid` adaptive)
- Круглые аватары: фото контакта или инициалы
- Имя контакта до 2 строк с усечением
- Выбор номера при звонке — если у контакта несколько номеров, появляется action sheet
- Локальный счётчик исходящих в `UserDefaults` (суммирует все номера контакта)
- Автообновление контактов при возврате приложения из фона
- Сортировка:
  1. больше исходящих выше
  2. при равенстве — по фамилии
  3. если фамилии нет — по имени
  4. если имени нет — fallback по номеру, затем в конец
- Настройки:
  - тема (системная / светлая / тёмная)
  - сброс счётчиков с подтверждением и тостом

## Ограничения MVP
- История звонков из системного приложения Телефон недоступна — Apple не предоставляет API
- Нет серверного хранения
- Нет аналитики/CRM
- Нет входящих звонков
- Нет кастомного редактирования контактов

## Файлы
- `Zvonilka/Zvonilka/ZvonilkaApp.swift`
- `Zvonilka/Zvonilka/Models/ContactItem.swift`
- `Zvonilka/Zvonilka/Models/ThemeMode.swift`
- `Zvonilka/Zvonilka/Services/ContactsService.swift`
- `Zvonilka/Zvonilka/Services/CallStatsStore.swift`
- `Zvonilka/Zvonilka/ViewModels/ContactsGridViewModel.swift`
- `Zvonilka/Zvonilka/Views/ContactsGridView.swift`
- `Zvonilka/Zvonilka/Views/ContactGridCard.swift`
- `Zvonilka/Zvonilka/Views/SettingsView.swift`

## Сборка в Xcode
1. Клонируй репозиторий
2. Открой `Zvonilka/Zvonilka.xcodeproj`
3. Выбери симулятор или подключи iPhone
4. Запусти `Cmd+R`

Примечание: симулятор не совершает реальные звонки по `tel://`, но вся логика нажатий и сортировки работает.
