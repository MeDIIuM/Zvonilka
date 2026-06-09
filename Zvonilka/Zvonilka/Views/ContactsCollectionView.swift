import UIKit
import SwiftUI
import Contacts

// MARK: - Masonry Layout

final class MasonryCollectionLayout: UICollectionViewLayout {
    var contacts: [ContactItem] = []
    var columns = 3
    var unitHeight: CGFloat = 68
    var spacing: CGFloat = 10

    private var cachedAttributes: [UICollectionViewLayoutAttributes] = []
    private var contentHeight: CGFloat = 0

    override func prepare() {
        super.prepare()
        guard let cv = collectionView, !contacts.isEmpty else {
            cachedAttributes = []; contentHeight = 0; return
        }
        let inset = cv.contentInset
        let availableWidth = cv.bounds.width - inset.left - inset.right
        let colWidth = (availableWidth - spacing * CGFloat(columns - 1)) / CGFloat(columns)
        var colHeights = [CGFloat](repeating: 0, count: columns)
        cachedAttributes = []

        for (i, contact) in contacts.enumerated() {
            let span = contact.hasAvatar ? 2 : 1
            let col = colHeights.indices.min(by: { colHeights[$0] < colHeights[$1] }) ?? 0
            let x = CGFloat(col) * (colWidth + spacing)
            let y = colHeights[col]
            let h = CGFloat(span) * unitHeight + CGFloat(span - 1) * spacing
            let attrs = UICollectionViewLayoutAttributes(forCellWith: IndexPath(item: i, section: 0))
            attrs.frame = CGRect(x: x, y: y, width: colWidth, height: h)
            cachedAttributes.append(attrs)
            colHeights[col] = y + h + spacing
        }

        contentHeight = (colHeights.max() ?? 0)
        if contentHeight > spacing { contentHeight -= spacing }
    }

    override var collectionViewContentSize: CGSize {
        guard let cv = collectionView else { return .zero }
        let inset = cv.contentInset
        return CGSize(width: cv.bounds.width - inset.left - inset.right, height: contentHeight)
    }

    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        guard !cachedAttributes.isEmpty else { return nil }
        return cachedAttributes.filter { $0.frame.intersects(rect) }
    }

    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        cachedAttributes.first { $0.indexPath == indexPath }
    }

    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        collectionView?.bounds.width != newBounds.width
    }
}

// MARK: - Cell

final class ContactCardCell: UICollectionViewCell {
    private let givenLabel = UILabel()
    private let familyLabel = UILabel()
    private let avatarView = UIImageView()
    private let badgeBack = UIView()
    private let badgeIcon = UIImageView()
    private let badgeText = UILabel()

    private var contactID: String = ""
    var onCall: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setupViews() {
        contentView.layer.cornerRadius = 16
        contentView.layer.cornerCurve = .continuous
        contentView.clipsToBounds = true

        for label in [givenLabel, familyLabel] {
            label.font = .preferredFont(forTextStyle: .subheadline)
            label.textAlignment = .center
            label.lineBreakMode = .byTruncatingTail
            label.textColor = .label
            contentView.addSubview(label)
        }

        avatarView.contentMode = .scaleAspectFill
        avatarView.clipsToBounds = true
        avatarView.layer.cornerRadius = 32
        contentView.addSubview(avatarView)

        badgeIcon.image = UIImage(systemName: "phone.fill",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 10))
        badgeIcon.tintColor = .secondaryLabel
        badgeText.font = .preferredFont(forTextStyle: .caption1)
        badgeText.textColor = .secondaryLabel
        badgeBack.backgroundColor = UIColor.systemFill
        badgeBack.layer.cornerRadius = 10
        badgeBack.clipsToBounds = true
        [badgeIcon, badgeText].forEach { badgeBack.addSubview($0) }
        contentView.addSubview(badgeBack)

        contentView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped)))
    }

    func configure(contact: ContactItem, colorScheme: ColorScheme, onCall: @escaping () -> Void) {
        let previousID = contactID
        contactID = contact.id
        self.onCall = onCall

        contentView.backgroundColor = UIColor.secondarySystemBackground.withAlphaComponent(0.85)

        givenLabel.text = contact.givenName.isEmpty ? nil : contact.givenName
        givenLabel.isHidden = contact.givenName.isEmpty
        familyLabel.text = contact.familyName.isEmpty ? nil : contact.familyName
        familyLabel.isHidden = contact.familyName.isEmpty
        badgeText.text = "\(contact.outgoingCallsCount)"

        if contact.hasAvatar {
            avatarView.isHidden = false
            if let cached = AvatarCache.shared.image(for: contact.id) {
                avatarView.image = cached
            } else if previousID == contact.id, avatarView.image != nil {
                // Тот же контакт перерисован повторно, кэш вытеснен — оставляем текущее фото
            } else {
                avatarView.image = nil
                loadAvatar(contactID: contact.id)
            }
        } else {
            avatarView.isHidden = true
            avatarView.image = nil
        }

        setNeedsLayout()
    }

    private func loadAvatar(contactID: String) {
        let id = contactID
        Task.detached(priority: .utility) { [weak self] in
            let store = CNContactStore()
            guard let cn = try? store.unifiedContact(
                    withIdentifier: id,
                    keysToFetch: [CNContactImageDataKey as CNKeyDescriptor]),
                  let data = cn.imageData,
                  let full = UIImage(data: data) else { return }
            let thumb = full.avatarThumbnail()
            AvatarCache.shared.store(thumb, for: id)
            await MainActor.run { [weak self] in
                if self?.contactID == id { self?.avatarView.image = thumb }
            }
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let b = contentView.bounds
        let pad: CGFloat = 10

        // Badge
        let iconSz: CGFloat = 10
        let textSz = badgeText.intrinsicContentSize
        let pH: CGFloat = 6, pV: CGFloat = 3
        let bW = iconSz + 3 + textSz.width + pH * 2
        let bH = max(iconSz, textSz.height) + pV * 2
        badgeBack.frame = CGRect(x: b.width - bW - 6, y: 6, width: bW, height: bH)
        badgeIcon.frame = CGRect(x: pH, y: (bH - iconSz) / 2, width: iconSz, height: iconSz)
        badgeText.frame = CGRect(x: pH + iconSz + 3, y: (bH - textSz.height) / 2,
                                 width: textSz.width, height: textSz.height)

        if !avatarView.isHidden {
            let sz: CGFloat = 64
            avatarView.frame = CGRect(x: (b.width - sz) / 2, y: pad, width: sz, height: sz)
            let top = avatarView.frame.maxY + 2
            let lineH = (b.height - top - pad) / 2
            givenLabel.frame = CGRect(x: pad, y: top, width: b.width - pad * 2, height: lineH)
            familyLabel.frame = CGRect(x: pad, y: top + lineH, width: b.width - pad * 2, height: lineH)
        } else {
            avatarView.frame = .zero
            let linesCount = (givenLabel.isHidden ? 0 : 1) + (familyLabel.isHidden ? 0 : 1)
            let lineH: CGFloat = 20
            let totalH = CGFloat(linesCount) * lineH + (linesCount > 1 ? 1 : 0)
            var y = (b.height - totalH) / 2
            if !givenLabel.isHidden {
                givenLabel.frame = CGRect(x: pad, y: y, width: b.width - pad * 2, height: lineH)
                y += lineH + 1
            }
            if !familyLabel.isHidden {
                familyLabel.frame = CGRect(x: pad, y: y, width: b.width - pad * 2, height: lineH)
            }
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        avatarView.image = nil
        contactID = ""
        onCall = nil
    }

    @objc private func tapped() { onCall?() }
}

// MARK: - UIViewRepresentable

struct ContactsCollectionView: UIViewRepresentable {
    let contacts: [ContactItem]
    let colorScheme: ColorScheme
    let defaultPhoneStore: DefaultPhoneStore
    let callAction: (ContactItem, String) -> Void
    let editAction: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UICollectionView {
        let layout = MasonryCollectionLayout()
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .clear
        cv.contentInset = UIEdgeInsets(top: 8, left: 12, bottom: 16, right: 12)
        cv.keyboardDismissMode = .onDrag
        cv.register(ContactCardCell.self, forCellWithReuseIdentifier: "cell")
        cv.dataSource = context.coordinator
        cv.delegate = context.coordinator
        cv.prefetchDataSource = context.coordinator
        return cv
    }

    func updateUIView(_ cv: UICollectionView, context: Context) {
        context.coordinator.parent = self
        cv.overrideUserInterfaceStyle = colorScheme == .dark ? .dark : .light

        let layout = cv.collectionViewLayout as! MasonryCollectionLayout
        let newIDs = contacts.map(\.id)

        if context.coordinator.lastIDs != newIDs {
            context.coordinator.lastIDs = newIDs
            context.coordinator.lastContacts = contacts
            layout.contacts = contacts
            layout.invalidateLayout()
            cv.reloadData()
        } else if context.coordinator.lastContacts != contacts {
            let spansChanged = zip(context.coordinator.lastContacts, contacts)
                .contains { $0.hasAvatar != $1.hasAvatar }
            context.coordinator.lastContacts = contacts
            if spansChanged {
                layout.contacts = contacts
                layout.invalidateLayout()
                cv.reloadData()
            } else {
                context.coordinator.reconfigureVisibleCells(in: cv)
            }
        }
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject,
                             UICollectionViewDataSource,
                             UICollectionViewDelegate,
                             UICollectionViewDataSourcePrefetching {
        var parent: ContactsCollectionView
        var lastIDs: [String] = []
        var lastContacts: [ContactItem] = []

        init(_ parent: ContactsCollectionView) { self.parent = parent }

        func reconfigureVisibleCells(in cv: UICollectionView) {
            for ip in cv.indexPathsForVisibleItems {
                guard ip.item < parent.contacts.count,
                      let cell = cv.cellForItem(at: ip) as? ContactCardCell else { continue }
                configureCell(cell, at: ip)
            }
        }

        func configureCell(_ cell: ContactCardCell, at ip: IndexPath) {
            let contact = parent.contacts[ip.item]
            let store = parent.defaultPhoneStore
            cell.configure(contact: contact, colorScheme: parent.colorScheme,
                onCall: { [weak self] in self?.triggerCall(contact: contact, store: store) })
        }

        // MARK: DataSource

        func collectionView(_ cv: UICollectionView, numberOfItemsInSection s: Int) -> Int {
            parent.contacts.count
        }

        func collectionView(_ cv: UICollectionView, cellForItemAt ip: IndexPath) -> UICollectionViewCell {
            let cell = cv.dequeueReusableCell(withReuseIdentifier: "cell", for: ip) as! ContactCardCell
            configureCell(cell, at: ip)
            return cell
        }

        // MARK: Context Menu (UICollectionViewDelegate, iOS 16+)

        func collectionView(_ cv: UICollectionView,
                            contextMenuConfigurationForItemsAt indexPaths: [IndexPath],
                            point: CGPoint) -> UIContextMenuConfiguration? {
            guard let ip = indexPaths.first, ip.item < parent.contacts.count else { return nil }
            let contact = parent.contacts[ip.item]
            let store = parent.defaultPhoneStore
            return UIContextMenuConfiguration(actionProvider: { [weak self] _ in
                guard let self else { return UIMenu(children: []) }
                var items: [UIMenuElement] = [
                    UIAction(title: "Редактировать контакт",
                             image: UIImage(systemName: "person.crop.circle")) { [weak self] _ in
                        self?.parent.editAction(contact.id)
                    }
                ]
                if contact.phoneNumbers.count > 1 {
                    let phoneActions = contact.phoneNumbers.map { phone -> UIAction in
                        let isCurrent = store.defaultPhone(for: contact.id) == phone
                        return UIAction(title: phone,
                                       image: UIImage(systemName: isCurrent ? "checkmark" : "phone")) { _ in
                            store.toggleDefaultPhone(phone, for: contact.id)
                        }
                    }
                    items.append(UIMenu(title: "Номер по умолчанию",
                                        image: UIImage(systemName: "phone.fill.badge.plus"),
                                        children: phoneActions))
                }
                return UIMenu(children: items)
            })
        }

        func collectionView(_ cv: UICollectionView,
                            contextMenuConfiguration configuration: UIContextMenuConfiguration,
                            highlightPreviewForItemAt indexPath: IndexPath) -> UITargetedPreview? {
            cellPreview(in: cv, at: indexPath)
        }

        func collectionView(_ cv: UICollectionView,
                            contextMenuConfiguration configuration: UIContextMenuConfiguration,
                            dismissalPreviewForItemAt indexPath: IndexPath) -> UITargetedPreview? {
            cellPreview(in: cv, at: indexPath)
        }

        private func cellPreview(in cv: UICollectionView, at indexPath: IndexPath) -> UITargetedPreview? {
            guard let cell = cv.cellForItem(at: indexPath) as? ContactCardCell else { return nil }
            let params = UIPreviewParameters()
            params.backgroundColor = cell.contentView.backgroundColor ?? .secondarySystemBackground
            params.visiblePath = UIBezierPath(roundedRect: cell.contentView.bounds, cornerRadius: 16)
            return UITargetedPreview(view: cell.contentView, parameters: params)
        }

        // MARK: Prefetch

        func collectionView(_ cv: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
            for ip in indexPaths {
                guard ip.item < parent.contacts.count else { continue }
                let contact = parent.contacts[ip.item]
                guard contact.hasAvatar,
                      AvatarCache.shared.image(for: contact.id) == nil else { continue }
                let id = contact.id
                Task.detached(priority: .background) {
                    let store = CNContactStore()
                    guard let cn = try? store.unifiedContact(
                            withIdentifier: id,
                            keysToFetch: [CNContactImageDataKey as CNKeyDescriptor]),
                          let data = cn.imageData,
                          let full = UIImage(data: data) else { return }
                    AvatarCache.shared.store(full.avatarThumbnail(), for: id)
                }
            }
        }

        func collectionView(_ cv: UICollectionView, cancelPrefetchingForItemsAt indexPaths: [IndexPath]) {}

        // MARK: Call

        private func triggerCall(contact: ContactItem, store: DefaultPhoneStore) {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            if contact.phoneNumbers.count == 1 {
                parent.callAction(contact, contact.phoneNumbers[0])
            } else if let def = store.defaultPhone(for: contact.id),
                      contact.phoneNumbers.contains(def) {
                parent.callAction(contact, def)
            } else {
                showNumberPicker(contact: contact, store: store)
            }
        }

        private func showNumberPicker(contact: ContactItem, store: DefaultPhoneStore) {
            guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let root = scene.windows.first(where: \.isKeyWindow)?.rootViewController else { return }
            let alert = UIAlertController(title: "Выберите номер", message: nil, preferredStyle: .actionSheet)
            for phone in contact.phoneNumbers {
                alert.addAction(UIAlertAction(title: phone, style: .default) { [weak self] _ in
                    store.setDefaultPhone(phone, for: contact.id)
                    self?.parent.callAction(contact, phone)
                })
            }
            alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
            root.present(alert, animated: true)
        }
    }
}
