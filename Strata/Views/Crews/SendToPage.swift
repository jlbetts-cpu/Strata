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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: GridConstants.gapSection) {
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
                detail: TonightsStoryRow.lesson, hint: onStory ? "Takes the win off tonight's story." : "Your friends see it from 8pm.") {
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
            if onStory, hasPhoto, !CrewAge.current.sendsPhotos {
                Text(TonightsStoryRow.teenLine)
                    .font(Typography.screenSubtitle)
                    .foregroundStyle(AppColors.inkSecondary)
                    .padding(.leading, 56 + GridConstants.gapItem)
                    .transition(.opacity)
            }
        }
    }

    // MARK: Crews

    private var crewList: some View {
        VStack(alignment: .leading, spacing: GridConstants.gapTight) {
            HStack {
                Text("Crews")
                    .font(Typography.sectionLabel)
                    .foregroundStyle(AppColors.inkSecondary)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                if store.crews.count > 1 { everyCrew }
            }
            ForEach(store.crews) { crew in
                let names = crew.members.filter { $0.profileID != store.me }.map(\.firstName).filter { !$0.isEmpty }
                row(on: crews.contains(crew.id),
                    label: crew.displayName(excluding: store.me),
                    detail: names.isEmpty ? "Just you so far" : names.formatted(.list(type: .and)),
                    hint: "") {
                    CrewFaces(crew: crew, me: store.me, side: 56)
                } toggle: {
                    if crews.contains(crew.id) { crews.remove(crew.id) } else { crews.insert(crew.id) }
                }
            }
        }
    }

    private var everyCrew: some View {
        let all = Set(store.crews.map(\.id))
        let on = all.isSubset(of: crews)
        return Button {
            HapticsEngine.tick()
            withAnimation(motion) { crews = on ? crews.subtracting(all) : crews.union(all) }
        } label: {
            Text(on ? "None" : CrewPicker.everyCrewWord)
                .font(Typography.headerSmall)
                .foregroundStyle(AppColors.inkPrimary)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.pressWord)
        .accessibilityHint(on ? "Takes the win off every crew." : "Sends the win to every crew.")
    }

    // MARK: Who was there

    private var with: some View {
        VStack(alignment: .leading, spacing: GridConstants.gapTight) {
            Text("Who Was There")
                .font(Typography.sectionLabel)
                .foregroundStyle(AppColors.inkSecondary)
                .accessibilityAddTraits(.isHeader)
            CrewWithRow(crews: crews, selection: $withPeople, stacked: false)
        }
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
        HStack(spacing: GridConstants.gapItem) {
            Text(summary)
                .font(Typography.headerSmall)
                .foregroundStyle(AppColors.inkSecondary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentTransition(.opacity)
            Button {
                HapticsEngine.lightTap()
                send()
            } label: {
                HStack(spacing: GridConstants.gapTight) {
                    Text(crews.isEmpty && !onStory ? "Add" : "Send")
                    Image(systemName: "arrow.up")
                }
                .font(Typography.headerSmall)
                .foregroundStyle(WarmBackground.top)
                .padding(.horizontal, GridConstants.gapWide)
                .frame(minHeight: 44)
                .background(Capsule().fill(AppColors.inkPrimary))
                .contentShape(Capsule())
            }
            .buttonStyle(.press)
            .disabled(sending)
            .accessibilityHint(summary)
        }
        .padding(.horizontal, hPad)
        .padding(.vertical, GridConstants.gapItem)
        .background(.bar)
        .animation(motion, value: summary)
    }

    // MARK: One row, every choice

    /// **A recipient**: its picture, its name and who is in it, and a tick.
    /// The whole row is the button, 56pt tall.
    private func row<Leading: View>(on: Bool, label: String, detail: String, hint: String,
                                    @ViewBuilder leading: () -> Leading, toggle: @escaping () -> Void) -> some View {
        Button {
            HapticsEngine.tick()
            withAnimation(motion) { toggle() }
        } label: {
            HStack(spacing: GridConstants.gapItem) {
                leading()
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(Typography.headerMedium)
                        .foregroundStyle(AppColors.inkPrimary)
                        .lineLimit(1)
                    Text(detail)
                        .font(Typography.screenSubtitle)
                        .foregroundStyle(AppColors.inkSecondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
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
        .accessibilityLabel("\(label), \(detail)")
        .accessibilityHint(hint)
        .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
    }
}
