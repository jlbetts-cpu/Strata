import SwiftUI

/// **Tonight's Story, watched** (the spec, 1.4 and 3; the plan, R9 to R11).
///
/// One win a page, full screen, with segments at the top that fill on their
/// own; a hold pauses, a tap on the right goes on and on the left goes back,
/// a swipe across goes to the next friend and a swipe down closes. Under the
/// picture, the block's own label (its name, Quick, Regular or Deep, its
/// colour), and under that the same reactions a crew's tower has, with Reply
/// into the crew's chat. On the page, not on black, as every photograph in
/// the app is shown (`PhotoViewer`), so a story is the tower's blocks seen at
/// night rather than a second app inside this one.
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

    var body: some View {
        TabView(selection: Binding(get: { shown }, set: { current = $0 })) {
            ForEach(people) { person in
                StoryPage(person: person, isCurrent: shown == person.id,
                          next: { step(from: person.id, by: 1) },
                          back: { step(from: person.id, by: -1) },
                          close: onClose)
                    .tag(person.id)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
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
    }

    /// The next friend, or the one before; past the last, the viewer closes.
    private func step(from id: UUID, by offset: Int) {
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
        held || busy || !isCurrent || scenePhase != .active || reporting != nil || blocking || voiceOver
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
        VStack(spacing: GridConstants.gapItem) {
            top
            card
            label
            foot
        }
        .padding(.horizontal, hPad)
        .padding(.top, GridConstants.gapTight)
        .padding(.bottom, GridConstants.gapItem)
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
            guard now else { return }
            page = person.stories.firstIndex { !store.storiesSeen.contains($0.id) } ?? 0
            seen()
        }
        .onChange(of: page) { seen() }
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

    private var top: some View {
        VStack(spacing: GridConstants.gapTight) {
            StoryProgress(count: person.stories.count, index: page, paused: paused,
                          length: Self.pageLength, finished: forward)
                .id("\(person.id)-\(page)-\(isCurrent)")
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
                    .foregroundStyle(AppColors.inkPrimary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                actions
                GlassIconButton(systemName: "xmark", onPage: true, accessibilityLabel: "Close story", action: close)
            }
            .buttonStyle(.plain)
        }
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
            GlassIconLabel(systemName: "ellipsis", tint: .primary, onPage: true)
        }
        .accessibilityLabel("Story actions")
    }

    // MARK: The picture

    private var card: some View {
        GeometryReader { geo in
            let shape = RoundedRectangle(cornerRadius: GridConstants.cornerRadius, style: .continuous)
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
    /// and Doodle into the crew's chat, and who reacted.
    private var foot: some View {
        CrewReactionsPanel(winID: story.id, crewID: story.win.crewID, mine: mine,
                           onDark: scheme == .dark, onBusy: { busy = $0 })
            .id(story.id)
            .frame(maxWidth: .infinity)
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
                        Capsule().fill(AppColors.inkPrimary.opacity(0.18))
                            .overlay(alignment: .leading) {
                                Capsule().fill(AppColors.inkPrimary)
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
