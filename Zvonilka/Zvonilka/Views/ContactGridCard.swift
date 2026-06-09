import SwiftUI

extension View {
    @ViewBuilder
    func adaptiveGlass(cornerRadius: CGFloat) -> some View {
        self
            .background(Color(.secondarySystemBackground).opacity(0.85))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}
