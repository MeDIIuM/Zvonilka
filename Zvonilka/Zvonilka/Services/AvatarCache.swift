import UIKit

final class AvatarCache {
    static let shared = AvatarCache()
    private init() {}

    private let cache = NSCache<NSString, UIImage>()

    func image(for id: String) -> UIImage? {
        cache.object(forKey: id as NSString)
    }

    func store(_ image: UIImage, for id: String) {
        cache.setObject(image, forKey: id as NSString)
    }

    func clear() {
        cache.removeAllObjects()
    }
}

extension UIImage {
    func avatarThumbnail(size: CGFloat = 128) -> UIImage {
        let scale = max(size / self.size.width, size / self.size.height)
        let w = self.size.width * scale, h = self.size.height * scale
        return UIGraphicsImageRenderer(size: CGSize(width: size, height: size)).image { _ in
            self.draw(in: CGRect(x: (size - w) / 2, y: (size - h) / 2, width: w, height: h))
        }
    }
}
