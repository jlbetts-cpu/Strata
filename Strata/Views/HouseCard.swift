import SwiftUI

/// **Some Wins' own card in the Memories slot** (the owner, 2026-10-08: "the
/// memories tab is the perfect place to place an ad... put the tasteful sketch
/// box outline around the ad so it feels apart of the app. and when it
/// disappears the skeleton can come back"; his pick, "House card now").
///
/// It stands where the month's drawing stands, inside a box drawn in his own
/// pen, and offers the app's own things rather than someone else's: start a
/// crew while you have none, or leave a tip. Closed, the drawing comes back.
/// The slot is built so a real ad could stand in it later, at scale, with
/// Plus taking it away (`docs`: the house-card memory note).
///
/// **Rare by rule**: never in the first three days of using the app, never
/// more than once a week, never on a visit that has another tip up, and only
/// when it has something true to offer.
nonisolated enum HouseCard: String, Equatable {
    case crew, tip

    static let firstSeenKey = "house.firstSeen"
    static let lastShownKey = "house.lastShown"
    static let quietDays = 3
    static let everyDays = 7

    /// The card for today, or nil.
    static func next(today: Date, firstSeen: Date?, lastShown: Date?,
                     hasCrew: Bool, crewsUsable: Bool, tipsReady: Bool,
                     calendar: Calendar = .current) -> HouseCard? {
        guard let firstSeen,
              let used = calendar.dateComponents([.day], from: firstSeen, to: today).day,
              used >= quietDays else { return nil }
        if let lastShown, let since = calendar.dateComponents([.day], from: lastShown, to: today).day,
           since < everyDays { return nil }
        if !hasCrew, crewsUsable { return .crew }
        if tipsReady { return .tip }
        return nil
    }

    var title: String {
        switch self {
        case .crew: "Winning is better together"
        case .tip: "Made by one person"
        }
    }

    var line: String {
        switch self {
        case .crew: "Start a crew with the people you'd tell anyway."
        case .tip: "If Some Wins helps, a tip keeps it going."
        }
    }

    var action: String {
        switch self {
        case .crew: "Start a Crew"
        case .tip: "Leave a Tip"
        }
    }
}

/// The card: his drawing, a title, one line, a small primary, a close
/// glyph, all inside a box drawn in his pen.
struct HouseCardView: View {
    let card: HouseCard
    var act: () -> Void
    var close: () -> Void

    var body: some View {
        VStack(spacing: GridConstants.gapItem) {
            art
            VStack(spacing: 4) {
                Text(card.title)
                    .font(Typography.headerMedium)
                    .foregroundStyle(AppColors.inkPrimary)
                Text(card.line)
                    .font(Typography.bodyLarge)
                    .foregroundStyle(AppColors.inkSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button {
                HapticsEngine.lightTap()
                act()
            } label: {
                Text(card.action)
                    .font(Typography.headerSmall)
                    .foregroundStyle(WarmBackground.top)
                    .padding(.horizontal, GridConstants.gapLabel)
                    .frame(height: 34)
                    .background(Capsule(style: .continuous).fill(AppColors.inkPrimary))
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.pressWord)
        }
        .padding(.horizontal, GridConstants.gapWide)
        .padding(.vertical, GridConstants.gapWide)
        .frame(maxWidth: .infinity)
        .background {
            SketchBox(seed: card == .crew ? 3 : 11)
                .stroke(AppColors.drawingInk, style: StrokeStyle(lineWidth: SketchBox.pen, lineCap: .round, lineJoin: .round))
        }
        .overlay(alignment: .topTrailing) {
            Button {
                HapticsEngine.lightTap()
                close()
            } label: {
                Image(systemName: "xmark")
                    .iconSize(GridConstants.iconMedium, relativeTo: .body, weight: .semibold)
                    .foregroundStyle(AppColors.inkTertiary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.press)
            .accessibilityLabel("Close")
            .padding(4)
        }
        .padding(.horizontal, GridConstants.horizontalPadding)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var art: some View {
        switch card {
        case .crew:
            if let drawing = UIImage(named: "CrewsTogether") {
                Image(uiImage: drawing)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(AppColors.drawingInk)
                    .frame(height: 96)
                    .accessibilityHidden(true)
            }
        case .tip:
            MarkWell(mark: "MarkHeart")
        }
    }
}

/// **A box drawn by hand**: a rounded rectangle walked in short steps, each
/// nudged off the true line by a smooth seeded wobble, the pen starting a
/// little before the corner it ends on so the two ends cross, as his lines
/// do. The wobble is a fraction of the pen, so it reads as a hand at any
/// size and never as a glitch.
struct SketchBox: Shape {
    var seed: Int = 1
    /// His pen on screen, the October skeleton's own line (~2.6pt).
    static let pen: CGFloat = 2.4

    func path(in rect: CGRect) -> Path {
        let inset = Self.pen
        let r = rect.insetBy(dx: inset, dy: inset)
        let radius: CGFloat = 26
        var points: [CGPoint] = []
        // The outline, as a list of points every ~6pt, clockwise from the
        // top edge's start.
        func arc(_ c: CGPoint, from a0: CGFloat, to a1: CGFloat) {
            let steps = 8
            for i in 0...steps {
                let a = a0 + (a1 - a0) * CGFloat(i) / CGFloat(steps)
                points.append(CGPoint(x: c.x + cos(a) * radius, y: c.y + sin(a) * radius))
            }
        }
        func line(_ p: CGPoint, _ q: CGPoint) {
            let n = max(2, Int(hypot(q.x - p.x, q.y - p.y) / 6))
            for i in 0...n {
                let t = CGFloat(i) / CGFloat(n)
                points.append(CGPoint(x: p.x + (q.x - p.x) * t, y: p.y + (q.y - p.y) * t))
            }
        }
        line(CGPoint(x: r.minX + radius, y: r.minY), CGPoint(x: r.maxX - radius, y: r.minY))
        arc(CGPoint(x: r.maxX - radius, y: r.minY + radius), from: -.pi / 2, to: 0)
        line(CGPoint(x: r.maxX, y: r.minY + radius), CGPoint(x: r.maxX, y: r.maxY - radius))
        arc(CGPoint(x: r.maxX - radius, y: r.maxY - radius), from: 0, to: .pi / 2)
        line(CGPoint(x: r.maxX - radius, y: r.maxY), CGPoint(x: r.minX + radius, y: r.maxY))
        arc(CGPoint(x: r.minX + radius, y: r.maxY - radius), from: .pi / 2, to: .pi)
        line(CGPoint(x: r.minX, y: r.maxY - radius), CGPoint(x: r.minX, y: r.minY + radius))
        arc(CGPoint(x: r.minX + radius, y: r.minY + radius), from: .pi, to: 1.5 * .pi)
        // The overlap: the pen runs on past where it began.
        line(CGPoint(x: r.minX + radius, y: r.minY), CGPoint(x: r.minX + radius + 22, y: r.minY + 0.6))

        // A smooth wobble across the walk: two slow sines, seeded.
        let s = CGFloat(seed)
        var path = Path()
        for (i, p) in points.enumerated() {
            let t = CGFloat(i)
            let nudge = sin(t * 0.21 + s) * 0.9 + sin(t * 0.053 + s * 1.7) * 1.3
            let q = CGPoint(x: p.x + nudge * 0.6, y: p.y + nudge * 0.8)
            if i == 0 { path.move(to: q) } else { path.addLine(to: q) }
        }
        return path
    }
}
