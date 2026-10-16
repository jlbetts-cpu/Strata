import SwiftData
import SwiftUI

/// **Tonight's Story, made in one go** (2026-10-16; the research: the crew
/// already saw what happened, so a story has to say what it meant, Burke and
/// Kraut 2016 on what close friends' words do, Bayer et al. 2016 on why
/// small private sharing feels good).
///
/// The best of today, up to three wins you pick, and one line in your words,
/// "Best part of today". The picks start as a sensible guess (the ones with
/// photographs, newest first, or the latest win), so it is one tap when that
/// is right. Nothing is ever posted without the tap.
struct PostMyDaySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var wins: [HabitLog] = []
    @State private var picked: [UUID] = []
    @State private var line = ""
    @State private var low = ""
    @State private var buffalo = ""
    /// The words page, made yours (`StoryPageEditor`): a photograph behind
    /// it, and its ink and stickers as one picture.
    @State private var photo: UUID?
    @State private var art: String?
    @State private var artWins: [UUID] = []
    @State private var editing = false
    @State private var pageRefused = false
    @State private var notSent = false
    @FocusState private var field: Field?
    enum Field { case high, low, buffalo }
    @State private var posting = false
    @State private var refused = false
    @FocusState private var writing: Bool

    private var store: SocialStore { SocialStore.shared }
    private let hPad = GridConstants.horizontalPadding
    static let most = 3
    private var today: String { DateUtils.dateString(from: Date()) }
    private var wasPosted: Bool { !store.myStory.isEmpty }

    var body: some View {
        NavigationStack {
            ScrollView {
                // **Two cards, as every page is now** (the owner, 2026-10-16:
                // "the Tonight's Story section is really ugly and not
                // organized well"): the line, then the wins, each with its
                // title inside; when your friends see it, quiet at the foot.
                VStack(alignment: .leading, spacing: PageCard.gap) {
                    // **High, low, buffalo** (the owner, 2026-10-16): the best of
                    // today, the hardest part and a random fact, each a line,
                    // each optional; together a page of your story.
                    card {
                        wordsRow(StoryLine.high, prompt: StoryLine.highPrompt, text: $line, field: .high)
                        Divider().overlay(AppColors.inkPrimary.opacity(0.06))
                        wordsRow(StoryLine.low, prompt: StoryLine.lowPrompt, text: $low, field: .low)
                        Divider().overlay(AppColors.inkPrimary.opacity(0.06))
                        wordsRow(StoryLine.buffalo, prompt: StoryLine.buffaloPrompt, text: $buffalo, field: .buffalo)
                    }
                    card {
                        if wins.isEmpty {
                            // **Nothing to post yet, said plainly** (the owner,
                            // 2026-10-16: "add the empty state for when you had
                            // no wins today in the tonight story").
                            EmptyPageLine("No wins today yet", icon: "square.stack",
                                          detail: "Log a win, and it can go on tonight's story.")
                                .padding(.vertical, GridConstants.gapWide)
                        } else {
                            title("Today's wins, up to three")
                            picks
                            Text(TonightsStoryRow.lesson)
                                .font(Typography.screenSubtitle)
                                .foregroundStyle(AppColors.inkSecondary)
                                .padding(.top, GridConstants.gapTight)
                        }
                    }
                    // Only where photos may go: the page leaves as a picture.
                    if (hasWords || art != nil), store.photosAllowed() {
                        card { yourPage }
                            .transition(.opacity)
                    }
                }
                .animation(reduceMotion ? GridConstants.crossFade : GridConstants.motionSnappy, value: hasWords)
                .padding(.horizontal, hPad)
                .padding(.top, GridConstants.gapItem)
                .padding(.bottom, GridConstants.gapPage)
            }
            .scrollDismissesKeyboard(.immediately)
            .background { WarmBackground().ignoresSafeArea() }
            .sheetTitle("Tonight's Story", drawn: true)
            .toolbar {
                BareToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Text("Cancel").sheetAction(.cancel) }
                        .buttonStyle(.pressWord)
                }
                BareToolbarItem(placement: .confirmationAction) {
                    Button { Task { await post() } } label: {
                        Text(wasPosted ? "Update" : "Post").sheetAction()
                    }
                    .buttonStyle(.pressWord)
                    .disabled(picked.isEmpty || posting)
                }
            }
            .alert("Try other words", isPresented: $refused) { Button("OK", role: .cancel) {} }
            .alert("That page stays with you", isPresented: $pageRefused) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Something on it can't be sent. Change the page and post again.")
            }
            .alert("Your story didn't post", isPresented: $notSent) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Your words are kept. Try again in a moment.")
            }
        }
        .task { load() }
    }

    // MARK: The line

    private var lineField: some View {
        // Written on the card itself, no field drawn round it.
        TextField("Line", text: Binding(get: { line }, set: { line = String($0.prefix(StoryLine.limit)) }),
                  prompt: Text("One line, in your words").foregroundStyle(AppColors.inkTertiary), axis: .vertical)
            .font(Typography.headerMedium)
            .foregroundStyle(AppColors.inkPrimary)
            .lineLimit(1...3)
            .focused($writing)
            .submitLabel(.done)
            .frame(minHeight: 44, alignment: .leading)
            .accessibilityLabel(StoryLine.prompt)
    }

    /// One of the three: its name small above, the line written under it.
    private func wordsRow(_ name: String, prompt: String, text: Binding<String>, field: Field) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(name)
                .font(Typography.headerSmall)
                .foregroundStyle(AppColors.inkSecondary)
            TextField(name, text: Binding(get: { text.wrappedValue },
                                          set: { text.wrappedValue = String($0.prefix(StoryLine.limit)) }),
                      prompt: Text(prompt).foregroundStyle(AppColors.inkTertiary), axis: .vertical)
                .font(Typography.bodyLarge)
                .foregroundStyle(AppColors.inkPrimary)
                .lineLimit(1...3)
                .focused($field, equals: field)
                .submitLabel(.next)
                .onSubmit {
                    switch field {
                    case .high: self.field = .low
                    case .low: self.field = .buffalo
                    case .buffalo: self.field = nil
                    }
                }
                .frame(minHeight: 32, alignment: .leading)
                .accessibilityLabel(name == StoryLine.high ? StoryLine.prompt : "\(name), \(prompt)")
        }
    }

    // MARK: Your page

    private var hasWords: Bool {
        !(line + low + buffalo).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Tonight's photographs that can go behind the words: the picked ones,
    /// since those are the pictures your friends' phones will have.
    private var photoWins: [HabitLog] {
        picked.compactMap { id in wins.first { $0.id == id && $0.imageFileName != nil } }
    }

    private var chosenPhoto: HabitLog? { photo.flatMap { id in photoWins.first { $0.id == id } } }

    /// **The words page, made yours** (the owner, 2026-10-16: "like
    /// Instagram, where you can easily doodle, add stickers in a full screen
    /// editing format, add a photo strip"). The page small, as your friends
    /// will see it; a tap opens it full screen to draw on.
    private var yourPage: some View {
        Button {
            HapticsEngine.tick()
            field = nil
            editing = true
        } label: {
            HStack(spacing: GridConstants.gapLabel) {
                preview
                VStack(alignment: .leading, spacing: GridConstants.spacing) {
                    Text(art == nil ? "Make it yours" : "Your page")
                        .font(Typography.bodyLarge)
                        .foregroundStyle(AppColors.inkPrimary)
                    Text("Draw on it, add stickers, your head or tonight's strip.")
                        .font(Typography.screenSubtitle)
                        .foregroundStyle(AppColors.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.forward")
                    .font(Typography.screenSubtitle)
                    .foregroundStyle(AppColors.inkTertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.press)
        .accessibilityLabel(art == nil ? "Make your page yours" : "Edit your page")
        .accessibilityIdentifier("editPage")
        .fullScreenCover(isPresented: $editing) {
            StoryPageEditor(high: line, low: low, buffalo: buffalo, day: today, photos: photoWins,
                            photo: chosenPhoto?.id) { chosen, made, wins in
                photo = chosen
                art = made
                artWins = wins
            }
        }
    }

    private static let page = CGSize(width: 360, height: 640)
    private static let small: CGFloat = 72

    /// Drawn at a phone's page size and shrunk, so the words sit as they will.
    private var preview: some View {
        let k = Self.small / Self.page.width
        return StoryWordsPage(high: line.isEmpty ? nil : line, low: low.isEmpty ? nil : low,
                              buffalo: buffalo.isEmpty ? nil : buffalo,
                              hasPicture: chosenPhoto != nil) { box in
            if let name = chosenPhoto?.imageFileName {
                CachedImageView(fileName: name, width: box.width, height: box.height, cornerRadius: 0)
            }
        } art: { _ in
            if let art { StoryArtImage(url: StoryPageFiles.directory.appending(path: art)) }
        }
        .environment(\.colorScheme, .dark)
        .frame(width: Self.page.width, height: Self.page.height)
        .scaleEffect(k, anchor: .topLeading)
        .frame(width: Self.small, height: Self.page.height * k, alignment: .topLeading)
        .clipShape(RoundedRectangle(cornerRadius: GridConstants.cornerRadius, style: .continuous))
        .accessibilityHidden(true)
    }

    // MARK: The cards

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: GridConstants.gapItem) { content() }
            .padding(PageCard.inset)
            .frame(maxWidth: .infinity, alignment: .leading)
            .pageCard()
    }

    private func title(_ words: String) -> some View {
        Text(words)
            .font(Typography.headerSmall)
            .foregroundStyle(AppColors.inkSecondary)
            .accessibilityAddTraits(.isHeader)
    }

    // MARK: The picks

    private var picks: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: GridConstants.spacing * 2), count: 3)
        return VStack(alignment: .leading, spacing: GridConstants.gapTight) {
            LazyVGrid(columns: columns, spacing: GridConstants.gapItem) {
                ForEach(wins, id: \.id) { log in tile(log) }
            }
        }
    }

    private func tile(_ log: HabitLog) -> some View {
        let on = picked.contains(log.id)
        let full = picked.count >= Self.most && !on
        let category = log.habit?.displayCategory ?? .unlabeled
        return Button {
            HapticsEngine.tick()
            withAnimation(reduceMotion ? GridConstants.crossFade : GridConstants.motionSnappy) {
                if on { picked.removeAll { $0 == log.id } } else if !full { picked.append(log.id) }
            }
        } label: {
            VStack(alignment: .leading, spacing: GridConstants.gapTight) {
                GeometryReader { geo in
                    ZStack {
                        if let name = log.imageFileName {
                            CachedImageView(fileName: name, width: geo.size.width, height: geo.size.width,
                                            cornerRadius: GridConstants.blockCornerRadius)
                        } else {
                            RoundedRectangle(cornerRadius: GridConstants.blockCornerRadius, style: .continuous)
                                .fill(category.style.baseColor)
                            if let icon = category.iconName {
                                Image(systemName: icon)
                                    .font(.system(size: geo.size.width * 0.28, weight: .medium))
                                    .foregroundStyle(category.style.text)
                            }
                        }
                    }
                    .frame(width: geo.size.width, height: geo.size.width)
                    .overlay(alignment: .topTrailing) {
                        Image(systemName: on ? "checkmark.circle.fill" : "circle")
                            .font(.title2)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(on ? WarmBackground.top : Color.white, on ? AppColors.inkPrimary : Color.black.opacity(0.25))
                            .padding(6)
                            .contentTransition(.symbolEffect(.replace))
                    }
                }
                .aspectRatio(1, contentMode: .fit)
                Text(log.habit?.title.isEmpty == false ? (log.habit?.title ?? "") : "A win")
                    .font(Typography.screenSubtitle)
                    .foregroundStyle(AppColors.inkPrimary)
                    .lineLimit(1)
            }
            .opacity(full ? 0.4 : 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.press)
        .accessibilityLabel(log.habit?.title ?? "A win")
        .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: Loading and posting

    private func load() {
        let day = today
        var d = FetchDescriptor<HabitLog>(predicate: #Predicate { $0.completed && $0.dateString == day },
                                          sortBy: [SortDescriptor(\.completedAt, order: .reverse)])
        d.relationshipKeyPathsForPrefetching = [\.habit]
        wins = (try? modelContext.fetch(d)) ?? []
        let words = store.storyWords(on: day)
        line = words.high
        low = words.low
        buffalo = words.buffalo
        photo = words.photo
        art = words.art
        artWins = words.artWins ?? []
        // What is on the story already; else a guess: the photographs,
        // newest first, or the latest win.
        let on = wins.filter { store.isOnStory($0.id) }.map(\.id)
        if !on.isEmpty {
            picked = Array(on.prefix(Self.most))
        } else {
            let photos = wins.filter { $0.imageFileName != nil }.map(\.id)
            picked = Array((photos.isEmpty ? wins.prefix(1).map(\.id) : photos).prefix(Self.most))
        }
    }

    /// Into today's journal entry too (`JournalWords`): made if there is none.
    private func keepInJournal(_ words: StoryWords) {
        guard !(words.high + words.low + words.buffalo).isEmpty else { return }
        let day = today
        let found = (try? modelContext.fetch(FetchDescriptor<MoodLog>(predicate: #Predicate { $0.dateString == day })))?.first
        let entry = found ?? MoodLog(dateString: day, mood: 3, motivation: 3)
        if found == nil { modelContext.insert(entry) }
        entry.note = JournalWords.merge(note: entry.note, words: words)
        try? modelContext.save()
    }

    private func post() async {
        posting = true
        defer { posting = false }
        let words = StoryWords(high: line, low: low, buffalo: buffalo, photo: chosenPhoto?.id, art: art,
                               artWins: artWins.isEmpty ? nil : artWins)
        // **Nothing says it posted unless it did** (the review, 2026-10-16:
        // a held-back page dropped all three lines while the sheet said "On
        // tonight's story").
        switch await store.setStoryWords(words, on: today) {
        case .sent: break
        case .refusedWords: refused = true; return
        case .refusedSketch: pageRefused = true; return
        default: notSent = true; return
        }
        keepInJournal(words)
        let chosen = Set(picked)
        for log in wins {
            let isOn = store.isOnStory(log.id)
            if chosen.contains(log.id), !isOn { CrewSync.setStory(log, on: true) }
            if !chosen.contains(log.id), isOn { CrewSync.setStory(log, on: false) }
        }
        HapticsEngine.success()
        // **Said where you are** (the owner, 2026-10-16: "they should know").
        let ids = Array(chosen)
        UndoLine.shared.show(wasPosted ? "Your story is updated" : "On tonight's story", undo: {
            Task { for id in ids { await SocialStore.shared.withdrawStory(winID: id) } }
        })
        dismiss()
    }
}
