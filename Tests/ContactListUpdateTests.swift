import Foundation

@main
struct ContactListUpdateTests {
    static func main() {
        let anna = RawContact(id: "anna", givenName: "Анна", familyName: "",
                              phoneNumbers: ["+7 (111) 222-33-44"], avatarData: nil)
        let sasha = RawContact(id: "sasha", givenName: "Саша", familyName: "",
                               phoneNumbers: ["+7 (999) 123-45-67", "79995556677"], avatarData: nil)
        let noPhone = RawContact(id: "noPhone", givenName: "Без номера", familyName: "",
                                 phoneNumbers: [], avatarData: nil)
        let raw = [sasha, noPhone, anna]
        let key = ContactListBuilder.statKey(contactID: sasha.id, phoneNumber: sasha.phoneNumbers[0])
        var statistics = [key: 0]
        let initial = ContactListBuilder.build(raw, statistics: statistics, previousAvatarVersions: [:])
        assert(initial.map(\.id) == ["anna", "sasha"])
        assert(ContactListBuilder.build(raw.reversed(), statistics: statistics,
                                        previousAvatarVersions: [:]) == initial)

        var state = CallDisplayState()
        assert(!state.didBecomeActive())
        let duringConfirmation = ContactListBuilder.build(raw, statistics: statistics,
                                                           previousAvatarVersions: [:])
        assert(duringConfirmation == initial, "Tapping must not change displayed counters or order")

        // Отмена/закрытие системного диалога без ухода в фон не меняет сетку.
        assert(!state.didBecomeActive())
        assert(statistics[key] == 0)

        // CallKit подтвердил один новый исходящий вызов. Подготавливаем сетку
        // из уже отображённых контактов, не дожидаясь чтения адресной книги.
        statistics[key] = 1
        let preparedBeforeReturn = ContactListBuilder.updatingStatistics(initial, statistics: statistics)
        assert(preparedBeforeReturn.first?.id == "sasha")
        assert(preparedBeforeReturn.first?.outgoingCallsCount == 1)

        state.didEnterBackground()
        assert(state.didBecomeActive())
        let afterReturn = ContactListBuilder.build(raw, statistics: statistics, previousAvatarVersions: [:])
        assert(afterReturn.map(\.id) == ["sasha", "anna"])
        assert(afterReturn == preparedBeforeReturn)
        assert(ContactListBuilder.updatingStatistics(initial, statistics: statistics) == afterReturn,
               "A slow reload prepared with old counters must use current statistics before publishing")
        assert(!state.didBecomeActive(), "Repeated foreground events must not trigger a refresh")

        let secondKey = ContactListBuilder.statKey(contactID: sasha.id, phoneNumber: sasha.phoneNumbers[1])
        statistics[secondKey] = 3
        assert(ContactListBuilder.build(raw, statistics: statistics,
                                       previousAvatarVersions: [:]).first?.outgoingCallsCount == 4)
        assert(key == "sasha_79991234567")

        assert(ContactListBuilder.updatingStatistics(afterReturn, statistics: [:]) == initial)
        assert(ContactListBuilder.build(raw, statistics: [:], previousAvatarVersions: [:]) == initial)

        let photo = RawContact(id: "photo", givenName: "Фото", familyName: "",
                               phoneNumbers: ["123"], avatarData: Data([1, 2, 3]), imageDataAvailable: true)
        let withPhoto = ContactListBuilder.build([photo], statistics: [:], previousAvatarVersions: [:])
        let versions = ["photo": withPhoto[0].avatarVersion]
        assert(ContactListBuilder.build([photo.withoutAvatarData], statistics: [:],
                                        previousAvatarVersions: versions) == withPhoto)
        let changedPhoto = RawContact(id: photo.id, givenName: photo.givenName, familyName: photo.familyName,
                                      phoneNumbers: photo.phoneNumbers, avatarData: Data([4, 5, 6]),
                                      imageDataAvailable: true)
        assert(ContactListBuilder.build([changedPhoto], statistics: [:],
                                        previousAvatarVersions: versions) != withPhoto)
        print("ContactListUpdate: all checks passed")
    }
}
