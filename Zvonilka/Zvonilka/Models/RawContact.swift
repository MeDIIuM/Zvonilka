import Foundation

nonisolated struct RawContact: Equatable, Codable, Sendable {
    let id: String
    let givenName: String
    let familyName: String
    let phoneNumbers: [String]
    let avatarData: Data?
    let imageDataAvailable: Bool

    var withoutAvatarData: RawContact {
        RawContact(id: id, givenName: givenName, familyName: familyName,
                   phoneNumbers: phoneNumbers, avatarData: nil,
                   imageDataAvailable: imageDataAvailable)
    }

    init(id: String, givenName: String, familyName: String,
         phoneNumbers: [String], avatarData: Data?, imageDataAvailable: Bool = false) {
        self.id = id
        self.givenName = givenName
        self.familyName = familyName
        self.phoneNumbers = phoneNumbers
        self.avatarData = avatarData
        self.imageDataAvailable = imageDataAvailable
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        givenName = try c.decode(String.self, forKey: .givenName)
        familyName = try c.decode(String.self, forKey: .familyName)
        phoneNumbers = try c.decode([String].self, forKey: .phoneNumbers)
        avatarData = try c.decodeIfPresent(Data.self, forKey: .avatarData)
        imageDataAvailable = try c.decodeIfPresent(Bool.self, forKey: .imageDataAvailable) ?? false
    }
}
