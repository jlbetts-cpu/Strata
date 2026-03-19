import SwiftUI

/// L-shaped highlight for top + left tile bevel (light edge).
struct TileBevelShape: Shape {
    var topThickness: CGFloat = 2.5
    var leftThickness: CGFloat = 2

    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: .zero)
        p.addLine(to: CGPoint(x: rect.width, y: 0))
        p.addLine(to: CGPoint(x: rect.width, y: topThickness))
        p.addLine(to: CGPoint(x: leftThickness, y: topThickness))
        p.addLine(to: CGPoint(x: leftThickness, y: rect.height))
        p.addLine(to: CGPoint(x: 0, y: rect.height))
        p.closeSubpath()
        return p
    }
}

/// Inverted L-shaped shadow for bottom + right tile bevel (dark edge).
struct TileBevelDarkShape: Shape {
    var bottomThickness: CGFloat = 1.5
    var rightThickness: CGFloat = 1.5

    func path(in rect: CGRect) -> Path {
        var p = Path()
        // Start bottom-right corner
        p.move(to: CGPoint(x: rect.width, y: rect.height))
        // Go left along bottom
        p.addLine(to: CGPoint(x: 0, y: rect.height))
        // Up to inner bottom edge
        p.addLine(to: CGPoint(x: 0, y: rect.height - bottomThickness))
        // Right to inner corner
        p.addLine(to: CGPoint(x: rect.width - rightThickness, y: rect.height - bottomThickness))
        // Up along inner right edge
        p.addLine(to: CGPoint(x: rect.width - rightThickness, y: 0))
        // Right to outer top-right
        p.addLine(to: CGPoint(x: rect.width, y: 0))
        p.closeSubpath()
        return p
    }
}

/// Radial specular highlight spot — top-left corner light source.
struct SpecularHighlight: View {
    var opacity: Double = 0.10

    var body: some View {
        GeometryReader { geo in
            RadialGradient(
                colors: [
                    .white.opacity(opacity),
                    .white.opacity(opacity * 0.3),
                    .clear
                ],
                center: .topLeading,
                startRadius: 0,
                endRadius: max(geo.size.width, geo.size.height) * 0.6
            )
        }
        .allowsHitTesting(false)
    }
}
