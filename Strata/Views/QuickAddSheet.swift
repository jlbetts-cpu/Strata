import Photos
import SwiftUI
import Vision

/// **The day in photos, onto the tower in a minute** (the launch pass, 6:
/// "Near the end of the day, offer a fast way to add several wins at once
/// from the camera roll ... give each a name and size in a second or two,
/// and drop them all onto the tower").
///
/// Today's photographs (screenshots never, near-duplicates once), one at a
/// time: keep it or skip it, a name if you want one, a size. A name is
/// offered by the phone's own reading of the picture (Vision) only when it
/// is sure; nothing leaves the phone. Kept ones drop onto your tower, your
/// tower only: sending any of them to a crew is a choice for later, as it is
/// on the block.
struct QuickAddSheet: View {
    /// The kept ones, in the order they were taken.
    let add: ([DroppedWin]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var access = TodaysPhotos.access
    @State private var assets: [PHAsset] = []
    @State private var pictures: [String: UIImage] = [:]
    @State private var names: [String: String] = [:]
    @State private var sizes: [String: BlockSize] = [:]
    @State private var skipped: Set<String> = []
    @State private var page = 0
    @State private var adding = false

    /// A second apart and nothing between: the same moment twice.
    static let sameMoment: TimeInterval = 2

    var body: some View {
        NavigationStack {
            Group {
                switch access {
                case .notAsked:
                    ask
                case .refused:
                    EmptyPageLine("Photos are off for \(AppName.display)", icon: "photo.on.rectangle",
                                  detail: "Turn them on in Settings and today's photos show up here.")
                        .frame(maxHeight: .infinity)
                case .allowed:
                    if assets.isEmpty {
                        EmptyPageLine("No photos from today yet", icon: "photo.on.rectangle",
                                      detail: "Take one, and it shows up here tonight.")
                            .frame(maxHeight: .infinity)
                    } else {
                        deck
                    }
                }
            }
            .background { WarmBackground().ignoresSafeArea() }
            .sheetTitle("Today's Photos", drawn: false)
            .toolbar {
                BareToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Text("Cancel").sheetAction(.cancel) }
                        .buttonStyle(.pressWord)
                }
            }
        }
        .presentationDetents([.large])
        .presentationBackground { WarmBackground().ignoresSafeArea() }
        .task(id: access) { await load() }
    }

    private var ask: some View {
        VStack(spacing: GridConstants.gapItem) {
            Spacer()
            EmptyPageLine("Your day in photos", icon: "photo.on.rectangle",
                          detail: "Some Wins can show today's photos here, so a few can go on your tower at once. They stay on your phone.")
            PrimaryCapsule(title: "Show Today's Photos") {
                Task { access = await TodaysPhotos.requestAccess() }
            }
            .padding(.horizontal, GridConstants.horizontalPadding)
            Spacer()
        }
    }

    // MARK: The deck

    private var kept: [PHAsset] { assets.filter { !skipped.contains($0.localIdentifier) } }

    private var deck: some View {
        VStack(spacing: GridConstants.gapItem) {
            TabView(selection: $page) {
                ForEach(Array(assets.enumerated()), id: \.element.localIdentifier) { index, asset in
                    card(asset).tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            PrimaryCapsule(title: kept.isEmpty ? "Add None" : kept.count == 1 ? "Add It to Your Tower" : "Add These to Your Tower") {
                finish()
            }
            .disabled(adding || kept.isEmpty)
            .padding(.horizontal, GridConstants.horizontalPadding)
            .padding(.bottom, GridConstants.gapTight)
        }
    }

    private func card(_ asset: PHAsset) -> some View {
        let id = asset.localIdentifier
        let size = sizes[id] ?? .small
        let isSkipped = skipped.contains(id)
        return VStack(spacing: GridConstants.gapItem) {
            ZStack {
                RoundedRectangle(cornerRadius: GridConstants.radiusSurface, style: .continuous)
                    .fill(AppColors.quietFill)
                if let picture = pictures[id] {
                    Color.clear.overlay {
                        Image(uiImage: picture)
                            .resizable()
                            .scaledToFill()
                    }
                    .clipped()
                    .opacity(isSkipped ? 0.35 : 1)
                }
            }
            .aspectRatio(size.cropAspectRatio, contentMode: .fit)
            .frame(maxHeight: 340)
            // Filled pictures run past their frame: held to it.
            .clipShape(RoundedRectangle(cornerRadius: GridConstants.radiusSurface, style: .continuous))
            .animation(GridConstants.slotSnap, value: size)
            .accessibilityLabel(isSkipped ? "Skipped photo" : "Today's photo")
            TextField("", text: Binding(get: { names[id] ?? "" }, set: { names[id] = $0 }),
                      prompt: Text("Name it, if you want").foregroundStyle(AppColors.inkTertiary))
                .font(Typography.headerMedium)
                .foregroundStyle(AppColors.inkPrimary)
                .multilineTextAlignment(.center)
                .submitLabel(.done)
                .frame(minHeight: 44)
            GlassChoiceBar(items: [BlockSize.small, .medium, .hard], chosen: size,
                           title: { $0.effortLabel }, spoken: { $0.effortLabel },
                           choose: { chosen in withAnimation(GridConstants.slotSnap) { sizes[id] = chosen } },
                           fills: true)
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Size")
            Button {
                HapticsEngine.tick()
                withAnimation(GridConstants.motionSnappy) {
                    if isSkipped { skipped.remove(id) } else { skipped.insert(id) }
                }
                if !isSkipped, page < assets.count - 1 {
                    withAnimation(GridConstants.motionSnappy) { page += 1 }
                }
            } label: {
                Text(isSkipped ? "Keep This One" : "Skip This One")
                    .font(Typography.headerSmall)
                    .foregroundStyle(AppColors.inkSecondary)
                    .frame(minHeight: 44)
            }
            .buttonStyle(.pressWord)
            Spacer(minLength: GridConstants.gapSection)
        }
        .padding(.horizontal, GridConstants.horizontalPadding)
        .task(id: id) { await read(asset) }
    }

    // MARK: Loading

    private func load() async {
        guard access == .allowed else { return }
        var fetched = TodaysPhotos.fetch()
        // Just allowed: the library can answer empty for a moment while it
        // opens. Asked again, briefly, before saying there is nothing.
        for _ in 0..<4 where fetched.isEmpty {
            try? await Task.sleep(for: .milliseconds(400))
            fetched = TodaysPhotos.fetch()
        }
        let found = fetched.reversed()
        // The same moment twice (a burst, a second try): the first only.
        var kept: [PHAsset] = []
        for asset in found {
            if let last = kept.last, let a = last.creationDate, let b = asset.creationDate,
               b.timeIntervalSince(a) < Self.sameMoment { continue }
            kept.append(asset)
        }
        assets = kept
    }

    /// The picture, and a name only when the phone is sure what it shows.
    private func read(_ asset: PHAsset) async {
        let id = asset.localIdentifier
        guard pictures[id] == nil else { return }
        guard let picture = await TodaysPhotos.thumbnail(for: asset, size: CGSize(width: 360, height: 360), scale: 2)
        else { return }
        pictures[id] = picture
        if names[id] == nil, let guess = await Self.guess(picture) { names[id] = guess }
    }

    /// Vision's own label for a picture, on the phone, when it is at least
    /// two thirds sure, said as a word a person would write.
    nonisolated static func guess(_ picture: UIImage) async -> String? {
        guard let cg = picture.cgImage else { return nil }
        return await Task.detached(priority: .utility) { () -> String? in
            let request = VNClassifyImageRequest()
            try? VNImageRequestHandler(cgImage: cg).perform([request])
            guard let best = request.results?.first(where: { $0.confidence >= 0.66 }) else { return nil }
            let words = best.identifier.split(separator: "_").joined(separator: " ")
            return words.prefix(1).uppercased() + words.dropFirst()
        }.value
    }

    // MARK: Adding

    private func finish() {
        guard !adding else { return }
        adding = true
        HapticsEngine.snap()
        let chosen = kept
        Task { @MainActor in
            var wins: [DroppedWin] = []
            for asset in chosen {
                guard let photo = await TodaysPhotos.full(for: asset) else { continue }
                let id = asset.localIdentifier
                wins.append(DroppedWin(photo: photo, size: sizes[id] ?? .small,
                                       title: (names[id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
                                       place: TodaysPhotos.place(of: asset), crews: [], colour: .unlabeled,
                                       colourChosen: false, note: nil, with: [], story: false))
            }
            add(wins)
            dismiss()
        }
    }
}

/// **The day in photos, offered as the day ends** (the launch pass, 6: "pick
/// the moment and wording so it feels like a gift, not a chore"). Once an
/// evening, after seven, on a clear tower, and only when there are a few of
/// today's photos and the library was already opened to the app: it never
/// asks for anything by itself. (b: Photos' "on this day" and journaling
/// apps surface the day's pictures in the evening; c: after seven is when a
/// day has photos and is not over.)
enum QuickAddCue {
    static let line = "Your day in photos"
    static let detail = "A few of today's photos could go on your tower."
    private static let shownKey = "quickAdd.cueDay"

    static func due(now: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard calendar.component(.hour, from: now) >= 19, TodaysPhotos.access == .allowed,
              UserDefaults.standard.string(forKey: shownKey) != DateUtils.dateString(from: now) else { return false }
        return TodaysPhotos.fetch(now: now).count >= 2
    }

    static func markShown(now: Date = Date()) {
        UserDefaults.standard.set(DateUtils.dateString(from: now), forKey: shownKey)
    }
}
