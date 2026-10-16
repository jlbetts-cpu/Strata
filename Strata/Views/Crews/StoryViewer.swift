import SwiftUI

/// **Tonight's Story, watched** (the spec, 1.4 and 3; the plan, R9 to R11).
///
/// **As Snapchat and Instagram show a story, and as this app's camera is
/// framed** (the owner, 2026-10-16: "the story is most of the screen like it
/// is on the camera, light bottom black top, with the head in the corner with
/// the name and the bar up top"). One win a page as a card most of the screen
/// tall under the camera's black band, with the segments, their head and
/// their name over the top of the picture; under it, on the page, the
/// block's own label and the tower's reactions, with Reply into the crew's
/// chat. A hold pauses, a tap on the right goes on and on the left goes back,
/// a swipe across goes to the next friend and a swipe down closes.
///
/// **Never shown:** who watched, how many, a time, a count of stories.
struct StoryViewer: View {
    let people: [StoryPerson]
    let start: UUID
    let onClose: () -> Void

    @State private var current: UUID?
    @State private var drop: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var shown: UUID { current ?? start }
    private var store: SocialStore { SocialStore.shared }

    /// **The people as they stand now**, not as they stood when it opened
    /// (the review, 2026-10-15): someone blocked or hidden here drops out,
    /// and a story past its window goes, whatever was tapped. Yours stays.
    private var live: [StoryPerson] {
        let now = StoryClock.now(store.now())
        return people.compactMap { person in
            if person.profileID == store.me { return person }
            guard !store.blocked.contains(person.profileID) else { return nil }
            let stories = person.stories.filter {
                store.storiesHidden[person.profileID] != $0.day
                    && StoryClock.phase(of: $0, at: now, in: .current) == .open
            }
            return stories.isEmpty ? nil
                : StoryPerson(profileID: person.profileID, stories: stories, phase: .open, watched: person.watched)
        }
    }

    var body: some View {
        let people = live
        TabView(selection: Binding(get: { shown }, set: { current = $0 })) {
            ForEach(people) { person in
                StoryPage(person: person, isCurrent: shown == person.id, dragging: drop > 0,
                          next: { step(from: person.id, by: 1) },
                          back: { step(from: person.id, by: -1) },
                          close: onClose)
                    .tag(person.id)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        // **Black above, the page below**, as the camera stands (its
        // `CameraCard`): the band runs from the top of the screen down behind
        // the card's top corners.
        .background(alignment: .top) {
            GeometryReader { geo in
                Color.black
                    .frame(height: geo.safeAreaInsets.top + GridConstants.radiusSurface)
                    .offset(y: -geo.safeAreaInsets.top)
            }
            .allowsHitTesting(false)
        }
        .background { WarmBackground().ignoresSafeArea() }
        .offset(y: drop)
        .scaleEffect(1 - min(drop, 400) / 4000, anchor: .top)
        // **Down to close**, as Photos and every story closes (`OneWayPan`:
        // it refuses to begin unless the finger is going down, so a swipe
        // across still goes to the next friend).
        .gesture(OneWayPan(way: .down, changed: { drop = $0 }, ended: { distance, speed in
            if distance > 120 || speed > 900 {
                onClose()
            } else {
                withAnimation(reduceMotion ? GridConstants.crossFade : GridConstants.motionSnappy) { drop = 0 }
            }
        }))
        .statusBarHidden()
        // Nobody left to show (all blocked, hidden or past 9am): close.
        .onChange(of: people.isEmpty) { _, empty in if empty { onClose() } }
        .onChange(of: people.map(\.id)) { _, ids in
            if !ids.contains(shown), let first = ids.first { current = first }
        }
    }

    /// The next friend, or the one before; past the last, the viewer closes.
    private func step(from id: UUID, by offset: Int) {
        let people = live
        guard let i = people.firstIndex(where: { $0.id == id }) else { return }
        let j = i + offset
        if people.indices.contains(j) {
            withAnimation(reduceMotion ? GridConstants.crossFade : GridConstants.motionSnappy) { current = people[j].id }
        } else if offset > 0 {
            onClose()
        }
    }
}

/// One friend's stories, a page at a time.
private struct StoryPage: View {
    let person: StoryPerson
    let isCurrent: Bool
    /// Being dragged down to close: the story waits.
    var dragging = false
    let next: () -> Void
    let back: () -> Void
    let close: () -> Void

    @State private var page = 0
    @State private var held = false
    /// The reaction bar, Reply, a doodle or a sticker is open: the story waits.
    @State private var busy = false
    @State private var reporting: SharedWin?
    @State private var blocking = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @Environment(\.colorScheme) private var scheme

    private var store: SocialStore { SocialStore.shared }
    private var mine: Bool { person.profileID == store.me }
    private var story: CrewStory { person.stories[min(page, person.stories.count - 1)] }
    private let hPad = GridConstants.horizontalPadding

    /// How long a page stands before the next.
    static let pageLength: TimeInterval = 5

    private var paused: Bool {
        held || busy || dragging || !isCurrent || scenePhase != .active || reporting != nil || blocking || voiceOver
    }

    private var member: CrewMember? {
        store.crew(story.win.crewID)?.member(person.profileID)
    }

    private var name: String {
        if mine { return "Your Story" }
        let short = member?.shortName ?? ""
        return short.isEmpty ? "A friend" : short
    }

    var body: some View {
        VStack(spacing: 0) {
            card
                .overlay(alignment: .top) { top }
            VStack(spacing: GridConstants.gapItem) {
                label
                foot
            }
            .padding(.horizontal, hPad)
            .padding(.vertical, GridConstants.gapItem)
        }
        .overlay(alignment: .bottom) { CrewReportAnchor(reporting: $reporting, crewID: story.win.crewID) }
        .confirmationDialog("Block \(name)?", isPresented: $blocking, titleVisibility: .visible) {
            Button("Block", role: .destructive) {
                let (who, crew) = (person.profileID, story.win.crewID)
                Task { await CrewSafety.block(who, from: crew) }
                next()
            }
        } message: {
            Text("They're hidden from you everywhere, and they are not told.")
        }
        // Back to the first page not yet watched, as a story resumes.
        .onChange(of: isCurrent, initial: true) { _, now in
            busy = false
            guard now else { return }
            page = person.stories.firstIndex { !store.storiesSeen.contains($0.id) } ?? 0
            seen()
        }
        .onChange(of: page) {
            busy = false
            seen()
        }
    }

    private func seen() {
        guard isCurrent, !mine else { return }
        store.markStorySeen(story.id)
    }

    private func forward() {
        if page + 1 < person.stories.count { page += 1 } else { next() }
    }

    private func backward() {
        if page > 0 { page -= 1 } else { back() }
    }

    // MARK: The top

    /// Over the top of the picture, in white, on a short shade of the
    /// picture itself so the words read on a bright sky.
    private var top: some View {
        VStack(spacing: GridConstants.gapTight) {
            StoryProgress(count: person.stories.count, index: page, paused: paused,
                          length: Self.pageLength, finished: forward)
                .id("\(person.id)-\(page)-\(isCurrent)")
                .padding(.top, GridConstants.gapTight)
            HStack(spacing: GridConstants.gapTight) {
                Group {
                    if mine {
                        PersonHead(person: .me, side: 32)
                    } else if let member {
                        PersonHead(person: .member(member, crew: story.win.crewID, me: store.me), side: 32)
                    }
                }
                .accessibilityHidden(true)
                Text(name)
                    .font(Typography.headerSmall)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Spacer(minLength: 0)
                actions
                Button(action: close) {
                    Image(systemName: "xmark")
                        .iconSize(GridConstants.iconToolbar, relativeTo: .body, weight: .semibold)
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.pressWord)
                .accessibilityLabel("Close story")
            }
        }
        .padding(.horizontal, GridConstants.gapItem)
        .padding(.bottom, GridConstants.gapWide)
        .background {
            // A shade of the picture, not a surface: it is drawn into the
            // card and goes with it, so white words read on a bright sky.
            LinearGradient(colors: [.black.opacity(0.38), .clear], startPoint: .top, endPoint: .bottom)
                .allowsHitTesting(false)
        }
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: GridConstants.radiusSurface,
                                          topTrailingRadius: GridConstants.radiusSurface, style: .continuous))
    }

    private var actions: some View {
        Menu {
            if mine {
                Button(role: .destructive) {
                    let id = story.id
                    Task { await store.withdrawStory(winID: id) }
                    if person.stories.count == 1 { close() } else { forward() }
                } label: {
                    Label("Take Off Story", systemImage: "minus.circle")
                }
            } else {
                Button {
                    store.hideStory(of: person.profileID, day: story.day)
                    next()
                } label: {
                    Label("Hide Their Story", systemImage: "eye.slash")
                }
                Button(role: .destructive) { reporting = story.win } label: {
                    Label("Report", systemImage: "exclamationmark.bubble")
                }
                Button(role: .destructive) { blocking = true } label: {
                    Label("Block", systemImage: "hand.raised")
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .iconSize(GridConstants.iconToolbar, relativeTo: .body, weight: .semibold)
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("Story actions")
    }

    // MARK: The picture

    private var card: some View {
        GeometryReader { geo in
            // The camera's own card (`CameraView`'s `radiusSurface`).
            let shape = RoundedRectangle(cornerRadius: GridConstants.radiusSurface, style: .continuous)
            Group {
                if let url = story.win.photo {
                    CrewPhotoView(url: url, width: geo.size.width, height: geo.size.height,
                                  crop: CGPoint(x: story.win.cropX ?? 0, y: story.win.cropY ?? 0))
                } else {
                    // A doodle, a plain block, or anyone under 16: the block.
                    ZStack {
                        story.win.colour.style.baseColor
                        if let icon = story.win.icon.iconName {
                            Image(systemName: icon)
                                .font(.system(size: min(geo.size.width, geo.size.height) * 0.22, weight: .medium))
                                .foregroundStyle(story.win.colour.style.text)
                        }
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipShape(shape)
            .id(story.id)
            .transition(.opacity)
            // **Tap on, tap back, hold to pause.** The left third goes back,
            // as every story does; the rest goes on.
            .contentShape(shape)
            .onTapGesture(coordinateSpace: .local) { point in
                HapticsEngine.tick()
                if point.x < geo.size.width / 3 { backward() } else { forward() }
            }
            .onLongPressGesture(minimumDuration: 0.25, maximumDistance: 24, perform: {}, onPressingChanged: { pressing in
                held = pressing
            })
        }
        .animation(GridConstants.crossFade, value: story.id)
        .accessibilityElement()
        .accessibilityLabel(spoken)
        .accessibilityHint("Swipe up or down for the next or the one before.")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: forward()
            case .decrement: backward()
            @unknown default: break
            }
        }
    }

    private var spoken: String {
        var parts = ["\(mine ? "Your story" : "\(name)'s story"), \(page + 1) of \(person.stories.count)"]
        if !story.win.title.isEmpty { parts.append(story.win.title) }
        parts.append(story.win.blockSize.effortLabel)
        parts.append(story.win.photo == nil ? "a block" : "a photo")
        return parts.joined(separator: ", ")
    }

    // MARK: The label and the reactions

    /// The block's own label: its colour, its name, and how big a win it was.
    private var label: some View {
        HStack(spacing: GridConstants.gapTight) {
            Circle()
                .fill(story.win.colour.style.baseColor)
                .frame(width: 10, height: 10)
            if !story.win.title.isEmpty {
                Text(story.win.title)
                    .font(Typography.headerSmall)
                    .foregroundStyle(AppColors.inkPrimary)
                    .lineLimit(1)
            }
            Text(story.win.blockSize.effortLabel)
                .font(Typography.screenSubtitle)
                .foregroundStyle(AppColors.inkSecondary)
            Spacer(minLength: 0)
        }
        .frame(minHeight: 24)
        .accessibilityHidden(true)
    }

    /// The tower's reactions, on this story's own crew copy: the bar, Reply
    /// and Doodle into the crew's chat, and who reacted. **On your own, who
    /// reacted in every crew it went to** (the review: one crew's copy left
    /// out a friend who is only in another), as your block on Wins shows.
    @ViewBuilder
    private var foot: some View {
        if mine {
            MyStoryReactions(reactions: store.reactionsToMyWins()[story.id] ?? [])
                .frame(maxWidth: .infinity, minHeight: 44)
        } else {
            CrewReactionsPanel(winID: story.id, crewID: story.win.crewID, mine: false,
                               onDark: scheme == .dark, onBusy: { busy = $0 })
                .id(story.id)
                .frame(maxWidth: .infinity)
        }
    }
}

/// **The segments**: one a page, the ones before it full, this one filling
/// over `length` seconds while not paused. Its own view with its own clock,
/// so only the bar redraws as it fills, never the page.
private struct StoryProgress: View {
    let count: Int
    let index: Int
    let paused: Bool
    let length: TimeInterval
    let finished: () -> Void

    @State private var elapsed: TimeInterval = 0
    @State private var last: Date?
    @State private var done = false

    var body: some View {
        TimelineView(.animation(paused: paused)) { context in
            HStack(spacing: 4) {
                ForEach(0..<count, id: \.self) { i in
                    GeometryReader { geo in
                        Capsule().fill(Color.white.opacity(0.35))
                            .overlay(alignment: .leading) {
                                Capsule().fill(Color.white)
                                    .frame(width: geo.size.width * fill(i))
                            }
                    }
                }
            }
            .frame(height: 3)
            .onChange(of: context.date) { _, now in tick(now) }
        }
        .onChange(of: paused) { last = nil }
        .accessibilityHidden(true)
    }

    private func fill(_ i: Int) -> CGFloat {
        i < index ? 1 : i > index ? 0 : CGFloat(min(1, elapsed / length))
    }

    private func tick(_ now: Date) {
        guard !paused, !done else { last = nil; return }
        if let last { elapsed += min(0.1, now.timeIntervalSince(last)) }
        last = now
        if elapsed >= length {
            done = true
            finished()
        }
    }
}

/// Who reacted to your story, across every crew it went to: their emoji and
/// their names, read only. Nothing about who opened it, ever.
private struct MyStoryReactions: View {
    let reactions: [Reaction]

    var body: some View {
        if !reactions.isEmpty {
            let ordered = reactions.sorted { $0.createdAt < $1.createdAt }
            var emoji: [String] = []
            let _ = ordered.forEach { if !emoji.contains($0.emoji) { emoji.append($0.emoji) } }
            let names = ordered.map { CrewReactionsPanel.name($0.profileID, crewID: $0.crewID) }
            let words = names.count > 3
                ? "\(names.prefix(2).joined(separator: ", ")) and \(names.count - 2) others"
                : names.formatted(.list(type: .and))
            HStack(spacing: 8) {
                HStack(spacing: -4) {
                    ForEach(Array(emoji.prefix(3).enumerated()), id: \.offset) { index, e in
                        Text(e).font(Typography.headerMedium).zIndex(Double(3 - index))
                    }
                }
                Text(words)
                    .font(Typography.headerSmall)
                    .foregroundStyle(AppColors.inkPrimary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .glassCapsule(onPage: true)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Reactions: " + zip(names, ordered).map { "\($0) \($1.emoji)" }.joined(separator: ", "))
        }
    }
}
