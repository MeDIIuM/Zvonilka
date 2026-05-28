import SwiftUI

struct MasonryLayout: Layout {
    let columns: Int
    let unitHeight: CGFloat
    let spacing: CGFloat

    struct Cache {
        var frames: [CGRect] = []
        var totalHeight: CGFloat = 0
        var lastWidth: CGFloat = -1
    }

    func makeCache(subviews: Subviews) -> Cache { Cache() }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> CGSize {
        let width = proposal.width ?? 0
        recompute(&cache, width: width, subviews: subviews)
        return CGSize(width: width, height: cache.totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) {
        recompute(&cache, width: bounds.width, subviews: subviews)
        for (i, subview) in subviews.enumerated() where i < cache.frames.count {
            let f = cache.frames[i]
            subview.place(
                at: CGPoint(x: bounds.minX + f.minX, y: bounds.minY + f.minY),
                proposal: ProposedViewSize(f.size)
            )
        }
    }

    private func recompute(_ cache: inout Cache, width: CGFloat, subviews: Subviews) {
        guard cache.lastWidth != width || cache.frames.count != subviews.count else { return }

        let colWidth = max(0, (width - spacing * CGFloat(columns - 1)) / CGFloat(columns))
        var colUnits = Array(repeating: 0, count: columns)
        var frames: [CGRect] = []

        for subview in subviews {
            let span = subview[SpanKey.self]
            let col = colUnits.indices.min(by: { colUnits[$0] < colUnits[$1] }) ?? 0
            let x = CGFloat(col) * (colWidth + spacing)
            let y = CGFloat(colUnits[col]) * (unitHeight + spacing)
            let h = CGFloat(span) * unitHeight + CGFloat(span - 1) * spacing
            frames.append(CGRect(x: x, y: y, width: colWidth, height: h))
            colUnits[col] += span
        }

        let maxUnits = colUnits.max() ?? 0
        cache.frames = frames
        cache.totalHeight = maxUnits > 0 ? CGFloat(maxUnits) * (unitHeight + spacing) - spacing : 0
        cache.lastWidth = width
    }
}

enum SpanKey: LayoutValueKey {
    static let defaultValue: Int = 1
}
