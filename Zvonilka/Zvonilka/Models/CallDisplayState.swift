// Отличаем возврат из фона от смены активности при системном подтверждении.
nonisolated struct CallDisplayState {
    private var wasInBackground = false

    mutating func didEnterBackground() {
        wasInBackground = true
    }

    // Системный диалог переводит приложение в inactive, но не обязательно в background.
    // Повторное active без ухода в фон не должно пересортировывать карточки.
    mutating func didBecomeActive() -> Bool {
        guard wasInBackground else { return false }
        wasInBackground = false
        return true
    }
}
