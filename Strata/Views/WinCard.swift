import SwiftData
import SwiftUI

/// **A win, the Hinge way** (the owner, 2026-10-16: "the Hinge treatment,
/// full sized, in a container"; "they make people's profiles captivating
/// ... winning goes hand in hand with being interesting"). One container:
/// an optional prompt and the win's name inside its top, its day and size
/// quiet beside them, then the photograph full width at 4:5. The one card
/// for a photographed win shown large: the month's page and your profile.
struct WinCard: View {
    let picture: BannerPicture
    /// The words over it, or nil for the photograph alone (the owner: "they
    /// could leave it blank and it just show the photo").
    var prompt: String? = nil

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: GridConstants.radiusSurface, style: .continuous)
        VStack(alignment: .leading, spacing: 0) {
            // **The prompt, and nothing else** (the owner, 2026-10-16: "it
            // doesn't say the date, just proudest win lately, not the size").
            if let prompt, !prompt.isEmpty {
                Text(prompt)
                    .font(Typography.headerMedium)
                    .foregroundStyle(AppColors.inkPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(GridConstants.horizontalPadding)
            }
            // Square, not 4:5 ("lowkey too long, shorten the photo").
            Color.clear
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    GeometryReader { geo in
                        switch picture {
                        case let .mine(file):
                            CachedImageView(fileName: file, width: geo.size.width, height: geo.size.height, cornerRadius: 0)
                        case let .theirs(url):
                            CrewPhotoView(url: url, width: geo.size.width, height: geo.size.height)
                        }
                    }
                }
                .clipped()
        }
        .pageCard()
        .clipShape(shape)
        .contentShape(shape)
    }
}

/// **Your featured wins** (2026-10-16): up to three of your photographed
/// wins at the top of your profile, each under a prompt, so the profile
/// says who you are by what you did. Chosen in Edit Profile; until then
/// your latest Deep ones, then any.
enum FeaturedWins {
    static let prompts = ["Proudest win lately", "A small win that made my day", "On the right track with"]
    /// Every prompt one may choose; "" is the photograph alone.
    static let choices = prompts + ["Worth every minute", "Didn't think I'd do this", "My kind of day", ""]
    static let slots = 3

    /// The prompt under a slot: the one chosen, else its own.
    static func prompt(_ index: Int, chosen: [String]) -> String {
        index < chosen.count ? chosen[index] : prompts[min(index, prompts.count - 1)]
    }

    /// As your crews receive them: each win's id and its prompt, only prompts
    /// from the list (nothing typed crosses to anyone).
    nonisolated struct Shared: Codable, Equatable, Sendable {
        let win: UUID
        let prompt: String
    }

    nonisolated static func encode(_ items: [Shared]) -> String? {
        guard !items.isEmpty, let data = try? JSONEncoder().encode(Array(items.prefix(slots))) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    nonisolated static func decode(_ text: String?) -> [Shared] {
        guard let data = text?.data(using: .utf8),
              let items = try? JSONDecoder().decode([Shared].self, from: data) else { return [] }
        return Array(items.filter { choices.contains($0.prompt) }.prefix(slots))
    }

    /// The wins to show: the chosen, where their photographs are still here;
    /// else the latest Deep, then the latest of any size.
    static func pick(from logs: [HabitLog], chosen: [String]) -> [HabitLog] {
        let photographed = logs.filter { $0.imageFileName != nil }
            .sorted { ($0.completedAt ?? $0.createdAt) > ($1.completedAt ?? $1.createdAt) }
        let byFile = Dictionary(photographed.compactMap { log in log.imageFileName.map { ($0, log) } },
                                uniquingKeysWith: { first, _ in first })
        let kept = chosen.compactMap { byFile[$0] }
        if !kept.isEmpty { return Array(kept.prefix(slots)) }
        let deep = photographed.filter { $0.habit?.blockSize == .hard }
        var out = Array(deep.prefix(slots))
        for log in photographed where out.count < slots && !out.contains(where: { $0.id == log.id }) {
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
            ForEach(0..<FeaturedWins.slots, id: \.self) { index in
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
                            // The words over it, chosen from the list, or none.
                            Menu {
                                ForEach(FeaturedWins.choices, id: \.self) { choice in
                                    Button(choice.isEmpty ? "No words, just the photo" : choice) {
                                        store.setFeaturedPrompt(choice, at: index)
                                    }
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    let words = FeaturedWins.prompt(index, chosen: store.featuredPrompts)
                                    Text(words.isEmpty ? "No words" : words)
                                        .font(Typography.bodyLarge)
                                        .foregroundStyle(AppColors.inkPrimary)
                                        .lineLimit(1)
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(Typography.screenSubtitle)
                                        .foregroundStyle(AppColors.inkTertiary)
                                }
                            }
                            Text(log == nil ? "Tap a photo below" : "Tap a photo below to change it")
                                .font(Typography.screenSubtitle)
                                .foregroundStyle(AppColors.inkSecondary)
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
        let target = min(slot, FeaturedWins.slots - 1)
        if let was = next.firstIndex(of: file) {
            if was != target, target < next.count { next.swapAt(was, target) }
        } else if target < next.count {
            next[target] = file
        } else {
            next.append(file)
        }
        store.setFeatured(next)
        slot = (target + 1) % FeaturedWins.slots
    }
}
