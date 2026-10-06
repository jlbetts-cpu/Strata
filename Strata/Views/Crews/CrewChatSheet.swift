import SwiftUI

/// **Today's crew chat** (the owner, 2026-10-05).
///
/// Opened from the glass `bubble.left` in the crew screen's top right. One
/// day long: it clears at the crew's midnight (`SocialStore.prune`), and no
/// phone shows a line from another day (`SocialStore.messages(in:)`). Text and
/// emoji up to 280 characters, a doodle, and replies on a win, which arrive
/// here quoting it ("↪ Morning run"); a tap on the quote opens that win.
///
/// **The sheets' chrome**, as `DaySheet` wears it: full
/// height, the drag indicator, the page's own ground as the material, Done top
/// right in `sheetAction`. The title is the crew and "Today" under it.
///
/// **Minimal and airy**: yours on the right in ink, everyone else on the left
/// with their small face and name, told apart by space and never by lines.
/// Liquid Glass only on the controls (the field and Send). No read receipts
/// and no seen marks: nothing says who has opened it.
struct CrewChatSheet: View {
    let crewID: CrewID
    /// A quoted win was tapped: the crew screen closes this sheet and opens
    /// that win in its viewer.
    var onOpenWin: (UUID) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// What is in the field. Seeded from `CrewDrafts` and written back to it
    /// on every keystroke (`draftField`), so the words outlive the sheet.
    @State private var draft: String
    @State private var refused = false
    @State private var reporting: CrewMessage?
    @State private var reported: CrewMessage?
    @State private var blocking: CrewMessage?
    @FocusState private var writing: Bool

    private var store: SocialStore { SocialStore.shared }
    private let hPad = GridConstants.horizontalPadding

    /// Bubbles never run to the far edge: the other side keeps this much air,
    /// the ladder's page rung.
    private static let otherSide: CGFloat = GridConstants.gapPage
    /// A friend's face beside their line: small, a name tag, not a portrait.
    private static let faceSide: CGFloat = 28
    /// A doodle's largest side in the chat: a mark, never a second photograph.
    private static let doodleSide: CGFloat = 160

    init(crewID: CrewID, onOpenWin: @escaping (UUID) -> Void = { _ in }) {
        self.crewID = crewID
        self.onOpenWin = onOpenWin
        _draft = State(initialValue: CrewDrafts.chat(crewID))
    }

    var body: some View {
        let crew = store.visible(crewID)
        let messages = store.messages(in: crewID)
        NavigationStack {
            thread(messages, crew: crew)
                .safeAreaInset(edge: .bottom, spacing: 0) { composer }
                .navigationTitle(crew?.displayName(excluding: store.me) ?? "Chat")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ChatSheetToolbar(name: crew?.displayName(excluding: store.me) ?? "", done: { dismiss() })
                }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground { WarmBackground().ignoresSafeArea() }
        // Open is seen: the dot goes, and the hour's held alert with it. And
        // again as lines arrive while it is open, from the crew screen's
        // live sync underneath (`refreshLive`, every 3 seconds).
        .onAppear { store.markChatSeen(crewID) }
        .onChange(of: messages.map(\.messageID)) { _, _ in store.markChatSeen(crewID) }
        .alert("Try other words", isPresented: $refused) {
            Button("OK", role: .cancel) {}
        }
        .overlay(alignment: .bottom) { dialogs }
    }

    // MARK: - The thread

    private func thread(_ messages: [CrewMessage], crew: Crew?) -> some View {
        GeometryReader { geo in
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    Group {
                        if messages.isEmpty {
                            Text("Quiet here. Yet.")
                                .font(Typography.bodyLarge)
                                .foregroundStyle(AppColors.inkTertiary)
                                .frame(maxWidth: .infinity, minHeight: geo.size.height)
                        } else {
                            LazyVStack(spacing: GridConstants.spacing) {
                                ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                                    row(message, after: index > 0 ? messages[index - 1] : nil, crew: crew)
                                        .id(message.id)
                                }
                            }
                            .padding(.horizontal, hPad)
                            .padding(.vertical, GridConstants.gapItem)
                            // **Bottom-anchored**: a short chat sits on the
                            // field, newest at the foot, as Messages sits.
                            .frame(maxWidth: .infinity, minHeight: geo.size.height, alignment: .bottom)
                        }
                    }
                }
                .defaultScrollAnchor(.bottom)
                .scrollDismissesKeyboard(.interactively)
                // Lines leave under the title softly, as the tower's do.
                .softScrollEdge(.top)
                .onChange(of: messages.last?.id) { _, last in
                    guard let last else { return }
                    withAnimation(reduceMotion ? GridConstants.crossFade : GridConstants.motionSnappy) {
                        proxy.scrollTo(last, anchor: .bottom)
                    }
                }
            }
        }
    }

    /// One line: yours on the right, a friend's on the left with their face
    /// and, at the start of their run, their name.
    @ViewBuilder
    private func row(_ message: CrewMessage, after previous: CrewMessage?, crew: Crew?) -> some View {
        let mine = message.senderProfileID == store.me
        let opensRun = previous?.senderProfileID != message.senderProfileID
        let member = crew?.member(message.senderProfileID)
        HStack(alignment: .bottom, spacing: GridConstants.gapTight) {
            if mine {
                Spacer(minLength: Self.otherSide)
            } else {
                Group {
                    if opensRun, let member, let crew {
                        CrewFace(member: member, crew: crew.id, me: store.me, side: Self.faceSide)
                    } else {
                        Color.clear
                    }
                }
                .frame(width: Self.faceSide, height: Self.faceSide)
                .accessibilityHidden(true)
            }
            VStack(alignment: mine ? .trailing : .leading, spacing: GridConstants.spacing) {
                if !mine, opensRun {
                    Text(name(of: message.senderProfileID))
                        .font(Typography.screenSubtitle)
                        .foregroundStyle(AppColors.inkTertiary)
                        .lineLimit(1)
                        .fitsLargeType(.subheadline)
                        .padding(.leading, GridConstants.gapLabel)
                        .accessibilityHidden(true)
                }
                bubble(message, mine: mine)
            }
            if !mine { Spacer(minLength: Self.otherSide) }
        }
        // Runs are told apart by air, never by a line.
        .padding(.top, opensRun && previous != nil ? GridConstants.gapItem : 0)
    }

    /// The bubble. **A tap opens the quoted win**, when there is one, so the
    /// whole bubble is the target and never a 15pt line; a hold on a friend's
    /// is Report and Block.
    @ViewBuilder
    private func bubble(_ message: CrewMessage, mine: Bool) -> some View {
        let quote = quoted(message)
        let face = bubbleFace(message, mine: mine, quote: quote?.title)
        Group {
            if let quote {
                Button {
                    HapticsEngine.lightTap()
                    onOpenWin(quote.winID)
                } label: { face }
                    .buttonStyle(.pressSurface)
                    .accessibilityHint("Opens the win")
            } else {
                face
            }
        }
        .contextMenu {
            if !mine {
                Button("Report", systemImage: "exclamationmark.bubble", role: .destructive) { reporting = message }
                Button("Block \(name(of: message.senderProfileID))", systemImage: "nosign", role: .destructive) {
                    blocking = message
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(spoken(message, quote: quote?.title))
    }

    private func bubbleFace(_ message: CrewMessage, mine: Bool, quote: String?) -> some View {
        // Yours in ink, with the page's own colour as its type, as the
        // filled `PrimaryCapsule` is; a friend's on a quiet fill in ink.
        let ink = mine ? WarmBackground.top : AppColors.inkPrimary
        // The quote steps down a rung on a friend's line (`inkTertiary`); on
        // yours it keeps the page's colour, since no ink token inverts onto
        // ink, and the arrow and the smaller size already make it the quote.
        let quoteInk = mine ? WarmBackground.top : AppColors.inkTertiary
        return VStack(alignment: .leading, spacing: GridConstants.spacing) {
            if let quote {
                // U+FE0E: the arrow as type, never the emoji tile it draws as bare.
                Text("\u{21AA}\u{FE0E} \(quote)")
                    .font(Typography.screenSubtitle)
                    .foregroundStyle(quoteInk)
                    .lineLimit(1)
                    .fitsLargeType(.subheadline)
            }
            if let sketch = message.sketch {
                InkImage(url: sketch, tint: ink)
                    .frame(maxWidth: Self.doodleSide, maxHeight: Self.doodleSide * 3 / 4)
            }
            if !message.text.isEmpty {
                Text(message.text)
                    .font(Typography.bodyLarge)
                    .foregroundStyle(ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
            }
        }
        .padding(.horizontal, GridConstants.gapLabel)
        .padding(.vertical, GridConstants.gapItem)
        .background {
            RoundedRectangle(cornerRadius: GridConstants.radiusSurface, style: .continuous)
                .fill(mine ? AppColors.inkPrimary : AppColors.quietFill)
        }
        .contentShape(RoundedRectangle(cornerRadius: GridConstants.radiusSurface, style: .continuous))
    }

    /// The win a line quotes, by its title, while it is still in the crew and
    /// still yours to see. A win taken back leaves the line with no quote.
    private func quoted(_ message: CrewMessage) -> (title: String, winID: UUID)? {
        guard let id = message.quoteWinID,
              let win = store.wins(in: crewID).first(where: { $0.winID == id }),
              store.wins(in: crewID, on: win.crewDay).contains(where: { $0.winID == id }) else { return nil }
        let title = win.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return (title.isEmpty ? "A win" : title, id)
    }

    private func name(of id: UUID) -> String {
        if id == store.me { return "You" }
        let short = store.crew(crewID)?.member(id)?.shortName ?? ""
        return short.isEmpty ? "A friend" : short
    }

    private func spoken(_ message: CrewMessage, quote: String?) -> String {
        var parts = [name(of: message.senderProfileID)]
        if let quote { parts.append("replying to \(quote)") }
        if message.sketch != nil { parts.append("a doodle") }
        if !message.text.isEmpty { parts.append(message.text) }
        return parts.joined(separator: ", ")
    }

    // MARK: - The field

    @ViewBuilder
    private var composer: some View {
        if store.canReply() {
            HStack(alignment: .bottom, spacing: GridConstants.gapTight) {
                TextField("Message", text: draftField, axis: .vertical)
                    .font(Typography.bodyLarge)
                    .foregroundStyle(AppColors.inkPrimary)
                    .lineLimit(1...5)
                    .focused($writing)
                    .padding(.horizontal, GridConstants.gapLabel)
                    .padding(.vertical, GridConstants.gapTight)
                    .frame(minHeight: GlassIconButton.defaultSide)
                    .glassCapsule(onPage: true, interactive: false)
                    .accessibilityLabel("Message")
                GlassIconButton(systemName: "arrow.up", onPage: true, accessibilityLabel: "Send") { send() }
                    .disabled(isEmpty)
            }
            .padding(.horizontal, hPad)
            .padding(.vertical, GridConstants.gapTight)
            // 280 characters, the owner's number: the field stops there
            // rather than letting a long paste be cut on the way out.
            .onChange(of: draft) { _, text in
                guard text.count > CrewMessage.textLimit else { return }
                draft = String(text.prefix(CrewMessage.textLimit))
                CrewDrafts.keepChat(draft, for: crewID)
            }
        } else {
            // Off for an age not shared (`canReply`): the chat reads, and
            // says so in one line.
            Text("Writing here is off on this phone.")
                .font(Typography.screenSubtitle)
                .foregroundStyle(AppColors.inkTertiary)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, hPad)
                .padding(.vertical, GridConstants.gapLabel)
        }
    }

    private var isEmpty: Bool { draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    /// The field's binding: a keystroke is the person's own edit, so it is
    /// the one thing that writes the kept draft. `send` empties the field
    /// without touching it, which is how the words survive a send that does
    /// not go.
    private var draftField: Binding<String> {
        Binding(get: { draft }, set: { draft = $0; CrewDrafts.keepChat($0, for: crewID) })
    }

    /// **A draft is cleared by a send that went, and by nothing else** (the
    /// QoL review, 2026-10-06). It lived in this sheet's `@State`, so a swipe
    /// down, a tap on a quoted win (which closes the sheet to open it) or a
    /// sheet closed while a refused send was coming back each lost what you
    /// had written. The field still empties at once, as Messages does; the
    /// kept copy goes only on `.sent`, and only if nothing new was typed
    /// since.
    private func send() {
        let text = draft
        guard !isEmpty else { return }
        draft = ""
        Task {
            if await store.send(text, in: crewID) == .sent {
                CrewDrafts.clearChat(crewID, ifStill: text)
            } else {
                // Refused words come back to the field, to be changed.
                if draft.isEmpty { draft = CrewDrafts.chat(crewID) }
                refused = true
            }
        }
    }

    // MARK: - Report and Block

    /// Hung on one point at the foot of the sheet, as the crew screen hangs
    /// its own: iOS 26 draws a dialog from the view it hangs on.
    private var dialogs: some View {
        Color.clear.frame(width: 1, height: 1)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .confirmationDialog("Report this message?",
                                isPresented: Binding(get: { reporting != nil }, set: { if !$0 { reporting = nil } }),
                                titleVisibility: .visible, presenting: reporting) { message in
                ForEach(CrewSafety.Reason.allCases) { reason in
                    Button(reason.words) {
                        Task {
                            await CrewSafety.report(.message(message), in: crewID, reason: reason)
                            reported = message
                        }
                    }
                }
            } message: { _ in
                Text("Your report goes to Some Wins. Nobody in the crew is told.")
            }
            .alert("Thanks for telling us",
                   isPresented: Binding(get: { reported != nil }, set: { if !$0 { reported = nil } }),
                   presenting: reported) { message in
                if !store.blocked.contains(message.senderProfileID) {
                    Button("Block \(name(of: message.senderProfileID))", role: .destructive) {
                        Task { await CrewSafety.block(message.senderProfileID, from: crewID) }
                    }
                }
                Button("Done", role: .cancel) {}
            } message: { _ in
                Text("Every report is looked at within a day. Blocking hides them from you everywhere, and they are not told.")
            }
            .confirmationDialog(blocking.map { "Block \(name(of: $0.senderProfileID))?" } ?? "",
                                isPresented: Binding(get: { blocking != nil }, set: { if !$0 { blocking = nil } }),
                                titleVisibility: .visible, presenting: blocking) { message in
                Button("Block", role: .destructive) {
                    Task { await CrewSafety.block(message.senderProfileID, from: crewID) }
                }
            } message: { _ in
                Text(store.crew(crewID)?.isOwner(store.me) == true
                     ? "You won't see their wins or words in any crew, and they leave this one. They are not told."
                     : "You won't see their wins or words in any crew. They are not told.")
            }
    }
}

/// The crew's name with "Today" under it in the principal slot, and Done.
/// Without the system's glass behind either, for the reason `DaySheet`'s
/// toolbar records: a glass word inside a glass capsule is two materials.
private struct ChatSheetToolbar: ToolbarContent {
    let name: String
    let done: () -> Void

    @ToolbarContentBuilder
    var body: some ToolbarContent {
        if #available(iOS 26.0, *) {
            ToolbarItem(placement: .principal) { title }
                .sharedBackgroundVisibility(.hidden)
            ToolbarItem(placement: .topBarTrailing) { doneButton }
                .sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: .principal) { title }
            ToolbarItem(placement: .topBarTrailing) { doneButton }
        }
    }

    private var title: some View {
        VStack(spacing: 0) {
            Text(verbatim: name)
                .font(Typography.headerMedium)
                .foregroundStyle(AppColors.inkPrimary)
                .lineLimit(1)
                .fitsLargeType(.body)
            Text("Today")
                .font(Typography.screenSubtitle)
                .foregroundStyle(AppColors.inkTertiary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private var doneButton: some View {
        Button(action: done) {
            Text("Done").sheetAction()
        }
        .buttonStyle(.pressWord)
    }
}

/// **Unsent words, per crew, for as long as the app is open** (the QoL
/// review, 2026-10-06). A chat's field and a win's Reply both lost their words
/// to anything that closed them; these hold them until a send goes through.
/// In memory on purpose: a draft is a sentence half written, not a record,
/// and a relaunch clearing it is what anyone would expect of a chat.
@MainActor
enum CrewDrafts {
    private static var chats: [CrewID: String] = [:]
    private struct ReplyKey: Hashable { let crew: CrewID; let win: UUID }
    private static var replies: [ReplyKey: String] = [:]

    static func chat(_ crew: CrewID) -> String { chats[crew] ?? "" }

    static func keepChat(_ text: String, for crew: CrewID) {
        chats[crew] = text.isEmpty ? nil : text
    }

    /// Only if the kept words are still the ones that were sent: anything
    /// typed while the send was in flight stays.
    static func clearChat(_ crew: CrewID, ifStill sent: String) {
        if chats[crew] == sent { chats[crew] = nil }
    }

    static func reply(_ crew: CrewID, to win: UUID) -> String {
        replies[ReplyKey(crew: crew, win: win)] ?? ""
    }

    static func keepReply(_ text: String, for crew: CrewID, to win: UUID) {
        replies[ReplyKey(crew: crew, win: win)] = text.isEmpty ? nil : text
    }

    static func clearReply(_ crew: CrewID, to win: UUID, ifStill sent: String) {
        let key = ReplyKey(crew: crew, win: win)
        if replies[key] == sent { replies[key] = nil }
    }
}
