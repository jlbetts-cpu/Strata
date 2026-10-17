import SwiftUI

/// **Send To: the page after Add a Win** (the owner, 2026-10-16: "the add to
/// sheet I feel like needs another page after where you select who to send
/// it to, kinda like Snapchat, since we are adding a lot more people").
///
/// The win is made on the first page; who sees it is chosen here, as
/// Snapchat's Send To follows the shot: Tonight's Story at the top, then
/// your crews, each a row with its faces and a tick, and who was there once
/// a crew is chosen. The bar at the foot says where it is going and sends.
/// Nothing chosen sends it to you alone, and the button says so.
///
/// Edit keeps its one page and its Save: the choice there is a change, not a
/// send.
struct SendToPage: View {
    @Binding var crews: Set<CrewID>
    @Binding var onStory: Bool
    @Binding var withPeople: [UUID]
    /// Today's win, with a friend to see it (`AddWinSheet.storyCanTakeIt`).
    let storyAllowed: Bool
    let hasPhoto: Bool
    let sending: Bool
    let send: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var store: SocialStore { SocialStore.shared }
    private let hPad = GridConstants.horizontalPadding
    /// **High, low, buffalo, where you post** (the launch pass, 3½: "only if
    /// you tap the story icon before you post ... most people will never
    /// find them. Make them a natural, visible option at the moment of
    /// posting"). Optional, folded under the story until asked for.
    @State private var writingWords = false
    @State private var high = ""
    @State private var low = ""
    @State private var buffalo = ""
    @State private var wordsLoaded = false
    private var today: String { DateUtils.dateString(from: Date()) }

    var body: some View {
        ScrollView {
            // **Simpler** (the owner, 2026-10-16: "on the send to screen the
            // text gets cut off and make it look simpler"): one list, a name
            // and a tick a row, no headings and no second lines.
            VStack(alignment: .leading, spacing: GridConstants.gapTight) {
                if storyAllowed { story }
                crewList
                if !crews.isEmpty, !store.taggable(in: crews).isEmpty { with }
            }
            .padding(.horizontal, hPad)
            .padding(.top, GridConstants.gapItem)
            .padding(.bottom, GridConstants.gapPage)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom, spacing: 0) { sendBar }
        .background { WarmBackground().ignoresSafeArea() }
        .navigationTitle("Send To")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var motion: Animation { reduceMotion ? GridConstants.crossFade : GridConstants.motionSnappy }

    // MARK: Tonight's Story

    private var story: some View {
        VStack(alignment: .leading, spacing: GridConstants.gapTight) {
            row(on: onStory, label: "Tonight's Story",
                hint: onStory ? "Takes the win off tonight's story." : TonightsStoryRow.lesson) {
                // The story's own mark: the drawn ring a story wears in the row.
                DoodleRing()
                    .stroke(AppColors.drawingInk, style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
                    .padding(1.3)
                    .overlay {
                        Image(systemName: "sunset.fill")
                            .font(Typography.headerMedium)
                            .foregroundStyle(AppColors.inkPrimary)
                    }
                    .frame(width: 56, height: 56)
            } toggle: {
                onStory.toggle()
            }
            // The one line that is the whole lesson, while it is on: wrapped,
            // never cut.
            if onStory {
                Text(hasPhoto && !CrewAge.current.sendsPhotos
                     ? "\(TonightsStoryRow.lesson) \(TonightsStoryRow.teenLine)" : TonightsStoryRow.lesson)
                    .font(Typography.screenSubtitle)
                    .foregroundStyle(AppColors.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, 56 + GridConstants.gapItem)
                    .padding(.bottom, GridConstants.gapTight)
                    .transition(.opacity)
                if writingWords {
                    wordsFields
                } else {
                    Button {
                        HapticsEngine.lightTap()
                        if !wordsLoaded {
                            let words = store.storyWords(on: today)
                            (high, low, buffalo) = (words.high, words.low, words.buffalo)
                            wordsLoaded = true
                        }
                        withAnimation(motion) { writingWords = true }
                    } label: {
                        Label("Add your high, low and buffalo", systemImage: "plus")
                            .font(Typography.headerSmall)
                            .foregroundStyle(AppColors.inkPrimary)
                            .frame(minHeight: 44)
                    }
                    .buttonStyle(.pressWord)
                    .padding(.leading, 56 + GridConstants.gapItem)
                    .transition(.opacity)
                }
            }
        }
    }

    // MARK: Crews

    private var crewList: some View {
        VStack(alignment: .leading, spacing: GridConstants.gapTight) {
            if store.groupCrewCount > 1 { everyCrew }
            ForEach(store.groupCrews) { crew in
                row(on: crews.contains(crew.id),
                    label: crew.displayName(excluding: store.me),
                    hint: "") {
                    CrewFaces(crew: crew, me: store.me, side: 56)
                } toggle: {
                    if crews.contains(crew.id) { crews.remove(crew.id) } else { crews.insert(crew.id) }
                }
            }
        }
    }

    private var everyCrew: some View {
        let all = Set(store.groupCrews.map(\.id))
        let on = all.isSubset(of: crews)
        return row(on: on, label: CrewPicker.everyCrewWord,
                   hint: on ? "Takes the win off every crew." : "Sends the win to every crew.") {
            Image(systemName: "person.3.fill")
                .font(Typography.headerMedium)
                .foregroundStyle(AppColors.inkSecondary)
                .frame(width: 56, height: 56)
                .background(Circle().fill(AppColors.quietFill))
        } toggle: {
            crews = on ? crews.subtracting(all) : crews.union(all)
        }
    }

    // MARK: Who was there

    private var with: some View {
        CrewWithRow(crews: crews, selection: $withPeople, stacked: false)
            .padding(.top, GridConstants.gapItem)
            .transition(.opacity)
    }

    // MARK: The bar

    /// Where it is going, in words, and Send. Nothing chosen: it is yours.
    private var summary: String {
        var parts: [String] = []
        if onStory, storyAllowed { parts.append("Tonight's Story") }
        parts += store.crews.filter { crews.contains($0.id) }.map { $0.displayName(excluding: store.me) }
        return parts.isEmpty ? "Just you" : parts.formatted(.list(type: .and))
    }

    private var sendBar: some View {
        // The app's one primary action (`PrimaryCapsule`).
        PrimaryCapsule(title: crews.isEmpty && !onStory ? "Add" : "Send", action: sendWithWords)
        .disabled(sending)
        .accessibilityHint(summary)
        .padding(.horizontal, hPad)
        .padding(.vertical, GridConstants.gapItem)
    }

    /// The words go with the win, kept as the rest of tonight's are (its
    /// photo behind and its page, as they were).
    private func sendWithWords() {
        if onStory, wordsLoaded {
            var words = store.storyWords(on: today)
            if (words.high, words.low, words.buffalo) != (high, low, buffalo) {
                words.high = high; words.low = low; words.buffalo = buffalo
                let day = today
                Task { await SocialStore.shared.setStoryWords(words, on: day) }
            }
        }
        send()
    }

    private var wordsFields: some View {
        VStack(alignment: .leading, spacing: GridConstants.gapTight) {
            wordsField(StoryLine.high, prompt: StoryLine.highPrompt, text: $high)
            wordsField(StoryLine.low, prompt: StoryLine.lowPrompt, text: $low)
            wordsField(StoryLine.buffalo, prompt: StoryLine.buffaloPrompt, text: $buffalo)
        }
        .padding(PageCard.inset)
        .pageCard()
        .padding(.leading, 56 + GridConstants.gapItem)
        .transition(.opacity)
    }

    private func wordsField(_ name: String, prompt: String, text: Binding<String>) -> some View {
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
                .frame(minHeight: 32, alignment: .leading)
                .accessibilityLabel("\(name), \(prompt)")
        }
    }

    // MARK: One row, every choice

    /// **A recipient**: its picture, its name and who is in it, and a tick.
    /// The whole row is the button, 56pt tall.
    private func row<Leading: View>(on: Bool, label: String, hint: String,
                                    @ViewBuilder leading: () -> Leading, toggle: @escaping () -> Void) -> some View {
        Button {
            HapticsEngine.tick()
            withAnimation(motion) { toggle() }
        } label: {
            HStack(spacing: GridConstants.gapItem) {
                leading()
                Text(label)
                    .font(Typography.headerMedium)
                    .foregroundStyle(AppColors.inkPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: GridConstants.gapTight)
                Image(systemName: on ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(on ? AppColors.inkPrimary : AppColors.inkTertiary)
                    .contentTransition(.symbolEffect(.replace))
            }
            .frame(minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressWord)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityHint(hint)
        .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
    }
}
