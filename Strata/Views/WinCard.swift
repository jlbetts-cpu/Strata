import SwiftData
import SwiftUI

/// **A win, the Hinge way** (the owner, 2026-10-16: "the Hinge treatment,
/// full sized, in a container"; "they make people's profiles captivating
/// ... winning goes hand in hand with being interesting"). One container:
/// an optional prompt and the win's name inside its top, its day and size
/// quiet beside them, then the photograph full width at 4:5. The one card
/// for a photographed win shown large: the month's page and your profile.
struct WinCard: View {
    let fileName: String
    let title: String?
    let detail: String
    var prompt: String? = nil

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: GridConstants.radiusSurface, style: .continuous)
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                if let prompt {
                    Text(prompt)
                        .font(Typography.screenSubtitle)
                        .foregroundStyle(AppColors.inkSecondary)
                }
                HStack(alignment: .firstTextBaseline, spacing: GridConstants.gapItem) {
                    Text(title ?? "A win")
                        .font(Typography.headerMedium)
                        .foregroundStyle(AppColors.inkPrimary)
                        .lineLimit(2)
                    Spacer(minLength: 0)
                    Text(detail)
                        .font(Typography.screenSubtitle)
                        .foregroundStyle(AppColors.inkSecondary)
                        .fixedSize()
                }
            }
            .padding(GridConstants.horizontalPadding)
            Color.clear
                .aspectRatio(4 / 5, contentMode: .fit)
                .overlay {
                    GeometryReader { geo in
                        CachedImageView(fileName: fileName, width: geo.size.width, height: geo.size.height, cornerRadius: 0)
                    }
                }
                .clipped()
        }
        .pageCard()
        .clipShape(shape)
        .contentShape(shape)
    }

    static func detail(date: Date, size: BlockSize) -> String {
        date.formatted(.dateTime.month(.abbreviated).day()) + " \u{00B7} " + size.effortLabel
    }
}

/// **Your featured wins** (2026-10-16): up to three of your photographed
/// wins at the top of your profile, each under a prompt, so the profile
/// says who you are by what you did. Chosen in Edit Profile; until then
/// your latest Deep ones, then any.
enum FeaturedWins {
    static let prompts = ["Proudest win lately", "A small win that made my day", "On the right track with"]

    /// The wins to show: the chosen, where their photographs are still here;
    /// else the latest Deep, then the latest of any size.
    static func pick(from logs: [HabitLog], chosen: [String]) -> [HabitLog] {
        let photographed = logs.filter { $0.imageFileName != nil }
            .sorted { ($0.completedAt ?? $0.createdAt) > ($1.completedAt ?? $1.createdAt) }
        let byFile = Dictionary(photographed.compactMap { log in log.imageFileName.map { ($0, log) } },
                                uniquingKeysWith: { first, _ in first })
        let kept = chosen.compactMap { byFile[$0] }
        if !kept.isEmpty { return Array(kept.prefix(prompts.count)) }
        let deep = photographed.filter { $0.habit?.blockSize == .hard }
        var out = Array(deep.prefix(prompts.count))
        for log in photographed where out.count < prompts.count && !out.contains(where: { $0.id == log.id }) {
            out.append(log)
        }
        return out
    }
}

/// **Choosing your featured wins** (Edit Profile, nothing over it): the
/// three prompts, a tap on one to choose for it, and your photographed wins
/// three across, a tap putting one under the chosen prompt.
struct FeaturedEditor: View {
    @Query(filter: #Predicate<HabitLog> { $0.completed && $0.imageFileName != nil },
           sort: \HabitLog.createdAt, order: .reverse) private var photographed: [HabitLog]
    @State private var slot = 0
    private var store: ProfileStore { .shared }

    var body: some View {
        let _ = store.bannerChanged
        let shown = FeaturedWins.pick(from: photographed, chosen: store.featuredFiles)
        let files = Array(photographed.compactMap(\.imageFileName).prefix(30))
        VStack(alignment: .leading, spacing: GridConstants.gapItem) {
            ForEach(FeaturedWins.prompts.indices, id: \.self) { index in
                let log = index < shown.count ? shown[index] : nil
                Button {
                    HapticsEngine.tick()
                    slot = index
                } label: {
                    HStack(spacing: GridConstants.gapItem) {
                        Group {
                            if let file = log?.imageFileName {
                                CachedImageView(fileName: file, width: 48, height: 48, cornerRadius: GridConstants.cornerRadius)
                            } else {
                                RoundedRectangle(cornerRadius: GridConstants.cornerRadius, style: .continuous)
                                    .fill(AppColors.quietFill)
                            }
                        }
                        .frame(width: 48, height: 48)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(FeaturedWins.prompts[index])
                                .font(Typography.screenSubtitle)
                                .foregroundStyle(AppColors.inkSecondary)
                            Text(log?.habit?.title ?? "Choose a win")
                                .font(Typography.bodyLarge)
                                .foregroundStyle(AppColors.inkPrimary)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(GridConstants.gapTight)
                    .background {
                        RoundedRectangle(cornerRadius: GridConstants.radiusControl + 4, style: .continuous)
                            .strokeBorder(slot == index ? AppColors.inkPrimary : .clear, lineWidth: 2)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.press)
            }
            if !files.isEmpty {
                let gap = GridConstants.spacing
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: gap), count: 3), spacing: gap) {
                    ForEach(files, id: \.self) { file in
                        let at = shown.firstIndex { $0.imageFileName == file }
                        Button { place(file, shown: shown) } label: {
                            GeometryReader { geo in
                                CachedImageView(fileName: file, width: geo.size.width, height: geo.size.width,
                                                cornerRadius: GridConstants.cornerRadius)
                                    .overlay(alignment: .topTrailing) {
                                        if let at {
                                            Text(verbatim: "\(at + 1)")
                                                .font(Typography.headerSmall)
                                                .foregroundStyle(WarmBackground.top)
                                                .frame(width: 24, height: 24)
                                                .background(Circle().fill(AppColors.inkPrimary))
                                                .padding(6)
                                        }
                                    }
                            }
                            .aspectRatio(1, contentMode: .fit)
                        }
                        .buttonStyle(.press)
                    }
                }
            }
        }
    }

    private func place(_ file: String, shown: [HabitLog]) {
        HapticsEngine.tick()
        var next = shown.compactMap(\.imageFileName)
        let target = min(slot, FeaturedWins.prompts.count - 1)
        if let was = next.firstIndex(of: file) {
            if was != target, target < next.count { next.swapAt(was, target) }
        } else if target < next.count {
            next[target] = file
        } else {
            next.append(file)
        }
        store.setFeatured(next)
        slot = (target + 1) % FeaturedWins.prompts.count
    }
}
