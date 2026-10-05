import SwiftUI

// Small, quiet charts for the table. One accent (PD3 red) marks the point that
// matters — today, the weakest, the latest — and everything else stays in ink or grey.

/// Readiness over recent days: a 2pt line with the latest day as a red dot.
struct Sparkline: View {
    let values: [Double]
    var height: CGFloat = 34

    var body: some View {
        GeometryReader { geo in
            let pts = points(in: geo.size)
            ZStack(alignment: .topLeading) {
                Path { p in
                    guard let first = pts.first else { return }
                    p.move(to: first)
                    for pt in pts.dropFirst() { p.addLine(to: pt) }
                }
                .stroke(Theme.pencil, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                if let last = pts.last {
                    Circle()
                        .fill(Theme.red)
                        .overlay(Circle().strokeBorder(Theme.paper, lineWidth: 2))
                        .frame(width: 10, height: 10)
                        .position(last)
                }
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }

    private func points(in size: CGSize) -> [CGPoint] {
        guard values.count > 1 else { return [] }
        let lo = (values.min() ?? 0) - 0.02, hi = (values.max() ?? 1) + 0.02
        let span = max(hi - lo, 0.05)
        let inset: CGFloat = 5
        return values.enumerated().map { i, v in
            CGPoint(x: inset + (size.width - inset * 2) * CGFloat(i) / CGFloat(values.count - 1),
                    y: inset + (size.height - inset * 2) * (1 - CGFloat((v - lo) / span)))
        }
    }
}

/// A part-to-whole bar: one segment per part, 2pt gaps, the emphasised part in red.
struct CompositionBar: View {
    struct Part: Identifiable {
        let id: String
        let value: Int
        let emphasised: Bool
    }

    let parts: [Part]
    var height: CGFloat = 10

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 2) {
                ForEach(Array(parts.enumerated()), id: \.element.id) { i, part in
                    RoundedRectangle(cornerRadius: height / 2.5, style: .continuous)
                        .fill(fill(for: part, at: i))
                        .frame(width: width(of: part, in: geo.size.width))
                }
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }

    private func fill(for part: Part, at i: Int) -> Color {
        if part.emphasised { return Theme.red }
        return Theme.ink.opacity(i.isMultiple(of: 2) ? 0.82 : 0.4)
    }

    private func width(of part: Part, in total: CGFloat) -> CGFloat {
        let sum = CGFloat(max(1, parts.map(\.value).reduce(0, +)))
        let gaps = CGFloat(max(0, parts.count - 1)) * 2
        return max(height, (total - gaps) * CGFloat(part.value) / sum)
    }
}

/// Recent mock-paper scores as small columns, the latest in ink, the rest grey.
struct ScoreColumns: View {
    let scores: [Double]          // 0…1, oldest first
    var height: CGFloat = 30

    var body: some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(Array(scores.enumerated()), id: \.offset) { i, s in
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(i == scores.count - 1 ? Theme.ink : Theme.ink.opacity(0.25))
                    .frame(width: 7, height: max(3, height * s))
            }
        }
        .frame(height: height, alignment: .bottom)
        .accessibilityHidden(true)
    }
}

/// A single ratio against its whole, on a lighter track.
struct Meter: View {
    let value: Double
    var tint: Color = Theme.ink
    var height: CGFloat = 6

    var body: some View {
        ReadinessBar(value: value, tint: tint, height: height)
            .accessibilityHidden(true)
    }
}
