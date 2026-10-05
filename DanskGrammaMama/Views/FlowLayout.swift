import SwiftUI

/// Lays out subviews left to right, wrapping to the next line like text.
/// Used so every word in a sentence can be its own tappable view.
struct FlowLayout: Layout {
    var lineSpacing: CGFloat = 6
    var itemSpacing: CGFloat = 0

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, lineHeight: CGFloat = 0, widest: CGFloat = 0
        for view in subviews {
            let size = Self.size(of: view, maxWidth: maxWidth)
            if x + size.width > maxWidth, x > 0 {
                widest = max(widest, x - itemSpacing)
                x = 0
                y += lineHeight + lineSpacing
                lineHeight = 0
            }
            x += size.width + itemSpacing
            lineHeight = max(lineHeight, size.height)
        }
        widest = max(widest, x - itemSpacing)
        return CGSize(width: min(widest, maxWidth), height: y + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, lineHeight: CGFloat = 0
        for view in subviews {
            let size = Self.size(of: view, maxWidth: bounds.width)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += lineHeight + lineSpacing
                lineHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(size))
            x += size.width + itemSpacing
            lineHeight = max(lineHeight, size.height)
        }
    }

    /// A piece's natural size, unless it is wider than a line: then it gets the line's
    /// width and may wrap (a long correction inside a gap, for example).
    private static func size(of view: LayoutSubview, maxWidth: CGFloat) -> CGSize {
        let natural = view.sizeThatFits(.unspecified)
        guard natural.width > maxWidth, maxWidth.isFinite else { return natural }
        return view.sizeThatFits(ProposedViewSize(width: maxWidth, height: nil))
    }
}
