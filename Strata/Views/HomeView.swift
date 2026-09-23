import SwiftUI
import SwiftData

/// **Home: the Wins screen, become a page.**
///
/// The owner, 2026-09-22: "since we are turning the Wins page into like an
/// actual home page... a folder standalone doesn't look all too good."
///
/// He is right, and it is worth writing down why rather than just doing it.
/// A single folder in the middle of a screen has no scale: nothing tells you
/// whether it is full, whether it is a good day, whether there were other
/// days. It is a logo of a folder. Put six of them in a row and every one of
/// those questions answers itself by comparison — today's is open and the
/// others are shut, today's is fuller, yesterday's is a different colour
/// because somebody chose one.
///
/// **This is the top of the page and only the top.** His words: "I just want
/// just this top part for now and we can work down as we go." What is below
/// Recents is deliberately empty; it is not a layout waiting to be finished
/// so much as the next conversation.
///
/// **Light, on a warm white, with the dark bar underneath.** See `HomeGround`
/// for why Home has a ground of its own rather than rebinding the app's.
struct HomeView: View {
    /// Today's wins, from the same view model the tower was given, so the
    /// count on Home and the count everywhere else cannot disagree.
    var todayBlocks: [PlacedBlock]
    var onOpenWin: (UUID) -> Void = { _ in }
    /// Told to the screen, so its header can get out of the way while a
    /// folder is open.
    @Binding var isOpenExternally: Bool

    /// **Its own query, over its own window, on purpose.**
    ///
    /// `MainAppView`'s `logs` is filtered to the current month, which on the
    /// first of the month is one day: Recents would show a single folder and
    /// look broken. Widening that query would change what the tower, the
    /// timeline and the perfect-day set are each handed. A second query with
    /// its own predicate changes nothing upstream, and `dateString` is
    /// indexed, so a range over two weeks is the index scan it was designed
    /// for rather than a table scan.
    @Query private var recentLogs: [HabitLog]

    /// How far back Recents reaches. Two weeks is the span a person still
    /// thinks of as "lately" — beyond it you want a calendar, not a shelf,
    /// and that is what Memories is.
    private static let window = 14

    @State private var store = FolderStyleStore()
    /// Small thumbnails for what shows through the glass. A peeking card is
    /// 38% of a 150pt folder, so 57pt, so 171px on a 3x screen: the 320 tier
    /// is already nearly twice what is drawn.
    @State private var peeks: [String: UIImage] = [:]
    /// The day whose folder is open, and the bigger photographs it needs.
    @State private var openDay: RecentDay?
    @State private var openPhotos: [String: UIImage] = [:]
    @State private var customising: RecentDay?
    @State private var mood = FolderMood()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The camera's own corner. See `CameraView.cornerRadius`.
    private static let panelRadius: CGFloat = 40

    init(todayBlocks: [PlacedBlock],
         onOpenWin: @escaping (UUID) -> Void = { _ in },
         isOpenExternally: Binding<Bool>) {
        self.todayBlocks = todayBlocks
        self.onOpenWin = onOpenWin
        self._isOpenExternally = isOpenExternally
        let start = Calendar.current.date(byAdding: .day, value: -(Self.window - 1), to: Date()) ?? Date()
        let key = DateUtils.dateString(from: start)
        _recentLogs = Query(filter: #Predicate<HabitLog> { log in
            log.dateString >= key && (log.completed || log.skipped)
        })
    }

    // MARK: - The days

    private var todayKey: String { DateUtils.dateString(from: Date()) }

    /// **Today first, then the days behind it, newest to oldest.**
    ///
    /// Days with nothing in them are left out — a row of empty folders is a
    /// row of days you are being reminded you failed at, which is the exact
    /// thing this app does not do. Today is the one exception and is always
    /// present, because an empty folder for today is not a reproach, it is
    /// the place the next win goes.
    private var days: [RecentDay] {
        var byDate: [String: [HabitLog]] = [:]
        for log in recentLogs where log.habit != nil && log.dateString != todayKey {
            byDate[log.dateString, default: []].append(log)
        }

        let past = byDate.keys.sorted(by: >).compactMap { key -> RecentDay? in
            guard let date = DateUtils.date(from: key),
                  let logs = byDate[key], !logs.isEmpty else { return nil }
            let ordered = logs.sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
            return RecentDay(id: key, date: date, count: logs.count,
                             peek: ordered.prefix(5).compactMap(win(from:)))
        }

        let today = RecentDay(id: todayKey, date: Date(), count: todayBlocks.count,
                              peek: todayBlocks.reversed().prefix(5).map(win(from:)),
                              isToday: true)
        return [today] + past
    }

    private func win(from log: HabitLog) -> ScatterWin? {
        guard let habit = log.habit else { return nil }
        return ScatterWin(id: log.id.uuidString,
                          image: peeks[log.id.uuidString],
                          size: habit.blockSize,
                          title: habit.title,
                          colour: habit.displayCategory.style.baseColor)
    }

    private func win(from block: PlacedBlock) -> ScatterWin {
        ScatterWin(id: block.id.uuidString,
                   image: peeks[block.id.uuidString],
                   size: block.look.blockSize,
                   title: block.look.title,
                   colour: block.look.displayCategory.style.baseColor)
    }

    /// **The photographs come through `ImageManager`, not off the disk.** It
    /// is the app's bounded, cached, off-main decode path, and going round it
    /// is what froze the app the last time somebody did.
    ///
    /// Bounded twice over: five per day, and only the days on the row. A
    /// fortnight of twelve-win days is 70 thumbnails at 320px, not 168
    /// originals at whatever the camera shot.
    private func loadPeeks() async {
        var wanted: [(String, String)] = []
        for block in todayBlocks.reversed().prefix(5) {
            if let name = block.look.imageFileName { wanted.append((block.id.uuidString, name)) }
        }
        for day in days where !day.isToday {
            for win in day.peek {
                guard peeks[win.id] == nil else { continue }
                if let log = recentLogs.first(where: { $0.id.uuidString == win.id }),
                   let name = log.imageFileName {
                    wanted.append((win.id, name))
                }
            }
        }
        var loaded = peeks
        for (id, name) in wanted where loaded[id] == nil {
            if let image = await ImageManager.shared.loadThumbnail(fileName: name, maxWidth: 320) {
                loaded[id] = image
            }
        }
        if loaded.count != peeks.count { peeks = loaded }
    }

    /// The full-size-enough photographs for a day somebody actually opened.
    /// 640 is the tier baked beside every original and is bigger than any
    /// card inside the folder is drawn.
    private func loadOpen(_ day: RecentDay) async {
        var loaded: [String: UIImage] = [:]
        let names: [(String, String)] = day.isToday
            ? todayBlocks.compactMap { b in b.look.imageFileName.map { (b.id.uuidString, $0) } }
            : recentLogs.filter { $0.dateString == day.id }
                        .compactMap { l in l.imageFileName.map { (l.id.uuidString, $0) } }
        for (id, name) in names {
            if let image = await ImageManager.shared.loadThumbnail(fileName: name, maxWidth: 640) {
                loaded[id] = image
            }
        }
        openPhotos = loaded
    }

    /// Every win in the opened day, at the size the inside draws them.
    private func openWins(_ day: RecentDay) -> [ScatterWin] {
        if day.isToday {
            return todayBlocks.reversed().map { block in
                ScatterWin(id: block.id.uuidString,
                           image: openPhotos[block.id.uuidString],
                           size: block.look.blockSize,
                           title: block.look.title,
                           colour: block.look.displayCategory.style.baseColor)
            }
        }
        return recentLogs
            .filter { $0.dateString == day.id && $0.habit != nil }
            .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
            .compactMap { log in
                guard let habit = log.habit else { return nil }
                return ScatterWin(id: log.id.uuidString,
                                  image: openPhotos[log.id.uuidString],
                                  size: habit.blockSize,
                                  title: habit.title,
                                  colour: habit.displayCategory.style.baseColor)
            }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // **The page's floor is the camera's black, and the light part is
            // a sheet laid on top of it.**
            //
            // The owner: "I want the dark mode bottom to actually go all the
            // way up to under the folders text... make sure it's like that
            // rounded vibe just like the bottom of the camera, that black
            // part, how it curves up." Then, on the first attempt: "it's
            // curved the wrong way, and I don't think it's the same darkness
            // as the camera."
            //
            // Both notes were the same mistake. I drew the dark part as a
            // panel with its own rounded TOP corners, which curves the dark
            // down and away at the edges. The camera does the opposite and
            // that is why it looks right: its black is a plain full-bleed
            // rectangle, and the LIT thing in front of it — the viewfinder —
            // has rounded BOTTOM corners. The black is not shaped at all; it
            // is what shows around a shape. That is what makes it curve up.
            //
            // So the dark is the ground here, `Grey.g950` exactly as
            // `CameraView` uses it, and the warm white is a sheet over it
            // with two rounded bottom corners.
            Grey.g950.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                RecentsRow(days: days,
                           styles: { store.style(for: $0) },
                           onOpen: open(_:),
                           onCustomise: { customising = $0 })
                    .padding(.top, GridConstants.gapItem)
                    .padding(.bottom, GridConstants.gapWide)
                    .background(alignment: .bottom) { lightSheet }

                Spacer(minLength: 0)
            }

            if let day = openDay {
                FolderInside(title: day.title(),
                             wins: openWins(day),
                             tint: store.style(for: day.id).tint(for: day.id),
                             onClose: close,
                             onOpenWin: { id in
                                 if let uuid = UUID(uuidString: id) { onOpenWin(uuid) }
                             },
                             showsTitle: true,
                             bottomInset: 96)
                    .transition(.opacity)
                    .task(id: day.id) { await loadOpen(day) }
            }
        }
        .task(id: days.map(\.id).joined()) { await loadPeeks() }
        .task(id: todayBlocks.map(\.id)) { await loadPeeks() }
        .onAppear {
            mood.contents = FolderContents(count: todayBlocks.count)
            store.prune(before: FolderStyleStore.cutoff(from: Date()))
        }
        .onChange(of: todayBlocks.count) { old, new in
            mood.contents = FolderContents(count: new)
            if new > old { mood.react(to: .winAdded) }
        }
        .onDisappear { mood.stopDrifting() }
        .sheet(item: $customising) { day in
            FolderStyleSheet(title: day.title(),
                             dayKey: day.id,
                             count: day.count,
                             style: store.style(for: day.id),
                             onChange: { store.set($0, for: day.id) })
                .presentationDetents([.height(420)])
                .presentationDragIndicator(.visible)
        }
    }

    /// The warm white sheet the top of the page sits on.
    ///
    /// **It reaches a long way up on purpose.** The header is not inside this
    /// view — it is a `safeAreaInset` on the tab above — so the sheet has to
    /// extend past its own bounds and out under the status bar to get behind
    /// it. 1200 is more than any iPhone is tall, which is the point: there is
    /// no arithmetic here to get wrong on a different device, and the excess
    /// is off-screen.
    private var lightSheet: some View {
        UnevenRoundedRectangle(topLeadingRadius: 0,
                               bottomLeadingRadius: Self.panelRadius,
                               bottomTrailingRadius: Self.panelRadius,
                               topTrailingRadius: 0,
                               style: .continuous)
            .fill(HomeGround.top)
            .padding(.top, -1200)
            .ignoresSafeArea(edges: .top)
    }

    private func open(_ day: RecentDay) {
        openPhotos = [:]
        isOpenExternally = true
        guard !reduceMotion else { openDay = day; return }
        withAnimation(.easeOut(duration: 0.22)) { openDay = day }
    }

    private func close() {
        HapticsEngine.lightTap()
        isOpenExternally = false
        guard !reduceMotion else { openDay = nil; openPhotos = [:]; return }
        withAnimation(.easeIn(duration: 0.18)) { openDay = nil }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(200))
            openPhotos = [:]
        }
    }
}

/// **Dressing one day's folder: a colour, and whether it has a face.**
///
/// Two controls, because those are the two things the owner asked to be
/// able to change. It is reached by holding a folder rather than by a button
/// on the page: a colour picker that is always on screen is a page about
/// customisation, and this page is about the week.
struct FolderStyleSheet: View {
    var title: String
    /// The day this folder belongs to, because a folder nobody has recoloured
    /// takes the colour that day was dealt. See `FolderTint.seeded`.
    var dayKey: String
    var count: Int
    @State var style: FolderStyle
    var onChange: (FolderStyle) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss

    /// The faces offered, out of the rig's own set. Not all nineteen: a
    /// picker with nineteen near-identical pairs of eyes is a test, not a
    /// choice. These are the ones that read apart from each other at 150pt.
    private static let faces = ["Idle", "Delighted", "Derp", "Wink", "Surprised", "Smug"]

    var body: some View {
        VStack(spacing: GridConstants.gapWide) {
            // The folder itself, live, so a colour is chosen by looking at
            // the thing rather than at a swatch.
            WinFolder(title: title, count: count,
                      tint: style.tint(for: dayKey),
                      openAmount: 1,
                      showsFace: style.faceName != nil,
                      expression: style.expression,
                      isAlive: true)
                .frame(width: 150)
                .padding(.top, GridConstants.gapWide)

            VStack(alignment: .leading, spacing: GridConstants.gapItem) {
                Text("Colour")
                    .font(Typography.sectionLabel)
                    .kerning(Typography.sectionKerning)
                    .textCase(.uppercase)
                    .foregroundStyle(AppColors.inkTertiary)

                HStack(spacing: GridConstants.gapItem) {
                    // **Auto first, and it is the way back.** Every other
                    // swatch writes a choice; without this one a folder
                    // recoloured by accident could never be returned to the
                    // colour its day was dealt, and the store would keep a
                    // row for it forever. It draws the dealt colour with a
                    // ring cut through it, so it is visibly "this one, but
                    // not pinned".
                    swatch(colour: FolderTint.seeded(for: dayKey).colour,
                           id: "", name: "Automatic")
                        .overlay {
                            Circle().strokeBorder(HomeGround.top.opacity(0.9), lineWidth: 2)
                                .frame(width: 16, height: 16)
                                .allowsHitTesting(false)
                        }
                    ForEach(FolderTint.all) { option in
                        swatch(colour: option.colour, id: option.id, name: option.name)
                    }
                }

                Text("Face")
                    .font(Typography.sectionLabel)
                    .kerning(Typography.sectionKerning)
                    .textCase(.uppercase)
                    .foregroundStyle(AppColors.inkTertiary)
                    .padding(.top, GridConstants.gapTight)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: GridConstants.gapTight) {
                        // Off first, because off is the default and the first
                        // chip is where the eye starts.
                        faceChip(label: "Off", name: nil)
                        ForEach(Self.faces, id: \.self) { name in
                            faceChip(label: name, name: name)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, GridConstants.horizontalPadding)

            Spacer(minLength: 0)
        }
        .background(HomeGround().ignoresSafeArea())
    }

    private func swatch(colour: Color, id: String, name: String) -> some View {
        Button {
            HapticsEngine.lightTap()
            style.tintID = id
            onChange(style)
        } label: {
            Circle()
                .fill(colour)
                .frame(width: 34, height: 34)
                .overlay {
                    Circle().strokeBorder(AppColors.inkPrimary,
                                          lineWidth: style.tintID == id ? 2 : 0)
                        .padding(-4)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(name)
    }

    private func faceChip(label: String, name: String?) -> some View {
        let on = style.faceName == name
        return Button {
            HapticsEngine.lightTap()
            style.faceName = name
            onChange(style)
        } label: {
            Text(label)
                .font(Typography.headerSmall)
                .foregroundStyle(on ? HomeGround.top : AppColors.inkPrimary)
                .padding(.horizontal, GridConstants.gapLabel)
                .frame(height: 36)
                .background {
                    Capsule().fill(on ? AnyShapeStyle(AppColors.inkPrimary)
                                      : AnyShapeStyle(AppColors.quietFill))
                }
        }
        .buttonStyle(.plain)
    }
}
