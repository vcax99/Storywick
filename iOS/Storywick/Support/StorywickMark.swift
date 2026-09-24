import SwiftUI

// MARK: - Brand colours

extension Theme {
    static let brandLime  = Color(red: 0.639, green: 0.902, blue: 0.208)   // #A3E635
    static let brandGreen = Color(red: 0.063, green: 0.725, blue: 0.506)   // #10B981
    static let brandTeal  = Color(red: 0.024, green: 0.714, blue: 0.831)   // #06B6D4

    static var brandGradient: LinearGradient {
        LinearGradient(
            colors: [brandLime, brandGreen, brandTeal],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Mark

/// The Storywick logo — a row of waveform bars flowing into a play triangle,
/// filled with the lime → green → teal brand gradient. Matches the app icon.
struct StorywickMark: View {
    var animated = false

    private let bars: [CGFloat] = [0.42, 0.72, 1.0, 0.60]
    @State private var t: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)

            Theme.brandGradient
                .frame(width: s, height: s)
                .mask(alignment: .center) {
                    HStack(alignment: .center, spacing: s * 0.070) {
                        ForEach(bars.indices, id: \.self) { i in
                            Capsule()
                                .frame(width: s * 0.105, height: s * 0.88 * barHeight(i))
                        }
                        RoundedTriangle(cornerRadius: s * 0.05)
                            .frame(width: s * 0.25, height: s * 0.56)
                            .padding(.leading, s * 0.015)
                    }
                    .frame(width: s, height: s)
                }
                .frame(width: s, height: s)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .onAppear {
            guard animated else { return }
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) { t = 1 }
        }
    }

    private func barHeight(_ i: Int) -> CGFloat {
        guard animated else { return bars[i] }
        let wobble = 0.13 * sin(t * .pi + CGFloat(i) * 1.1)
        return min(1, max(0.3, bars[i] + wobble))
    }
}

/// An equilateral-ish right-pointing triangle with rounded corners.
struct RoundedTriangle: Shape {
    var cornerRadius: CGFloat = 6

    func path(in rect: CGRect) -> Path {
        let points = [
            CGPoint(x: rect.minX, y: rect.minY),
            CGPoint(x: rect.maxX, y: rect.midY),
            CGPoint(x: rect.minX, y: rect.maxY),
        ]
        var path = Path()
        for i in 0..<3 {
            let curr = points[i]
            let prev = points[(i + 2) % 3]
            let next = points[(i + 1) % 3]

            let toPrev = CGVector(dx: prev.x - curr.x, dy: prev.y - curr.y)
            let toNext = CGVector(dx: next.x - curr.x, dy: next.y - curr.y)
            let lenPrev = max(hypot(toPrev.dx, toPrev.dy), 0.001)
            let lenNext = max(hypot(toNext.dx, toNext.dy), 0.001)
            let r = min(cornerRadius, lenPrev / 2, lenNext / 2)

            let start = CGPoint(x: curr.x + toPrev.dx / lenPrev * r,
                                y: curr.y + toPrev.dy / lenPrev * r)
            let end = CGPoint(x: curr.x + toNext.dx / lenNext * r,
                              y: curr.y + toNext.dy / lenNext * r)

            if i == 0 { path.move(to: start) } else { path.addLine(to: start) }
            path.addQuadCurve(to: end, control: curr)
        }
        path.closeSubpath()
        return path
    }
}

#Preview {
    VStack(spacing: 30) {
        StorywickMark(animated: true).frame(width: 160, height: 160)
        HStack(spacing: 12) {
            StorywickMark().frame(width: 40, height: 40)
            Text("Storywick").font(.system(size: 40, weight: .bold))
        }
    }
    .padding(40)
    .background(Color.black)
}
