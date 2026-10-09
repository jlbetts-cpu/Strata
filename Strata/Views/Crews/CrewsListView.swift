import CloudKit
import DeclaredAgeRange
import PhotosUI
import SwiftUI

/// Where a crew is opened from: the push the tower's header leads to.
nonisolated enum CrewRoute: Hashable {
    case list
    case crew(CrewID)
}

/// Your crews, as Messages lists conversations: the crew's picture, its name,
/// its newest win and when, an unread dot. Swipe for Hide Alerts or Leave.
///
/// A native `List` under a native large title, because this is a list of
/// conversations and that is what one looks like on this phone.
struct CrewsListView: View {
    var open: (CrewID) -> Void

    @State private var startsCrew = false
    @State private var atCap = false
    @State private var leaving: Crew?
    @State private var problem: String?
    private var store: SocialStore { SocialStore.shared }

    @State private var age = CrewAge.current
    @State private var signedOut = false

    var body: some View {
        Group {
            // **Below iOS 26, one sentence and nothing else** (2026-10-08):
            // crews need the Declared Age Range, which only iOS 26 has.
            if !CrewsFlag.osSupportsCrews {
                needsNewerOS
            } else if !age.opensCrews {
                tooYoung
            } else if store.crews.isEmpty, CrewRouter.shared.joining || CrewRouter.shared.pendingInvite != nil {
                joiningState
            } else if store.crews.isEmpty {
                empty
            } else {
                List {
                    ForEach(store.crews) { crew in
                        Button { open(crew.id) } label: { row(store.visible(crew.id) ?? crew) }
                            .buttonStyle(.pressSurface)
                            .listRowBackground(Color.clear)
                            // Space between crews, never a rule: the app
                            // separates with room, not lines (the owner,
                            // 2026-10-03: "we dont use lines we use space").
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 12, leading: 8, bottom: 12, trailing: 16))
                            .swipeActions(edge: .trailing) {
                                Button(crew.isOwner(store.me) ? "End" : "Leave", role: .destructive) { leaving = crew }
                                Button {
                                    store.mute(crew.id, store.isMuted(crew.id) ? nil : .always)
                                } label: {
                                    Label(store.isMuted(crew.id) ? "Unmute" : "Mute",
                                          systemImage: store.isMuted(crew.id) ? "bell" : "bell.slash")
                                }
                            }
                    }
                    // Under the crews, the owner's drawing of three friends
                    // and its line (2026-10-03): what a crew is for, said
                    // once, where the list ends.
                    if let art = UIImage(named: "CrewsTogether") {
                        Illustration(art: art, line: "Winning is better together", height: 160,
                                     motion: UIImage(named: "CrewsTogetherCheer").map { .cheer(marks: $0) })
                            .padding(.top, GridConstants.gapSection)
                            .padding(.bottom, GridConstants.gapWide)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .selectionDisabled()
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .refreshable { await store.refresh() }
            }
        }
        .background(WarmBackground().ignoresSafeArea())
        .navigationTitle("Crews")
        // Small and centred, as Messages titles its list (the owner,
        // 2026-10-02: "it would look better in the middle like iMessages").
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            if age.opensCrews, CrewsFlag.osSupportsCrews { ToolbarItem(placement: .topBarTrailing) {
                // At the cap it still answers, with why (the crews audit,
                // 2026-10-08: it went grey and said nothing).
                Button {
                    if store.crews.count >= CrewCaps.crews { atCap = true } else { startsCrew = true }
                } label: {
                    Image(systemName: "square.and.pencil").sheetAction(.confirm, as: .glyph)
                }
                .accessibilityLabel("New Crew")
            } }
        }
        .task { await store.refresh() }
        // Seen once by any way in (an invitation, the first-win card): the
        // header's guiding dot has done its job (`CrewsButton.openedKey`).
        .onAppear { UserDefaults.standard.set(true, forKey: CrewsButton.openedKey) }
        // An invitation held for the rules and the age: joined here if both
        // were already settled by the time the list came up.
        .task { CrewRouter.shared.joinPendingIfReady() }
        // Opened from the first-win invitation with no crew to invite into:
        // straight to New Crew, whose Invite People carries the tower's
        // picture (`CrewSharing.nextCard`). After the rules and the age,
        // which this list already stands behind.
        .task {
            guard CrewRouter.shared.startsCrew else { return }
            // The rules sheet comes first on a first visit, and a second
            // sheet asked for under it would be dropped: wait for the agree,
            // and for it to have gone.
            while !CrewRules.accepted {
                try? await Task.sleep(for: .milliseconds(250))
                if Task.isCancelled { return }
            }
            try? await Task.sleep(for: .milliseconds(450))
            CrewRouter.shared.startsCrew = false
            if age.opensCrews { startsCrew = true }
        }
        #if DEBUG
        .onAppear { if DebugHarness.argument("-strataCrewSheet") == "new" { startsCrew = true } }
        #endif
        .modifier(AskAgeOnce(age: $age))
        .alert("You're in \(CrewCaps.crews) crews", isPresented: $atCap) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("That's the most you can be in. Leave one to start another.")
        }
        // **Crews' own film, once** (the owner, 2026-10-08: "the trailer at
        // the begining of the onboarding is so tasteful... we should have a
        // crews trailer when you click into it for the first time... or if
        // you dont have a crew yet"). The trailer's "Better with friends" and
        // its crew chat, 6 seconds, in the onboarding film's own player, Skip
        // from the first frame. Never for someone arriving by an invitation:
        // they came to join, and the join is waiting.
        .fullScreenCover(isPresented: Binding(get: { CrewsFilm.isDue(crews: store.crews.count) },
                                              set: { if !$0 { CrewsFilm.markSeen() } })) {
            OnboardingFilm(resource: "CrewsFilm", poster: "CrewsFilmPoster.jpg", reports: false) {
                CrewsFilm.markSeen()
            }
        }
        .sheet(isPresented: $startsCrew) {
            NewCrewSheet { crew in open(crew) }
        }
        // Hung on a point at the foot of the screen, not the whole list: iOS
        // 26 draws a dialog from the view it hangs on, and from a full-screen
        // one End Crew never appeared (the owner, 2026-10-03).
        .overlay(alignment: .bottom) {
            Color.clear.frame(width: 1, height: 1)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        .confirmationDialog(leaving.map { $0.isOwner(store.me) ? "End this crew for everyone?" : "Leave this crew?" } ?? "",
                            isPresented: Binding(get: { leaving != nil }, set: { if !$0 { leaving = nil } }),
                            titleVisibility: .visible, presenting: leaving) { crew in
            Button(crew.isOwner(store.me) ? "End Crew" : "Leave Crew", role: .destructive) {
                Task {
                    do {
                        if crew.isOwner(store.me) { try await store.end(crew.id) } else { try await store.leave(crew.id) }
                    } catch {
                        problem = "That did not work just now. Try again in a moment."
                    }
                }
            }
        }
        }
        .alert("Something went wrong", isPresented: Binding(get: { problem != nil }, set: { if !$0 { problem = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(problem ?? "") }
    }

    private func row(_ crew: Crew) -> some View {
        // **A new chat line lights it too** (the owner, 2026-10-06: "make
        // sure there is a notification icon also on the chat feature"). The
        // chat's dot was only inside the crew, so a message was invisible
        // until you happened to open that crew.
        let newWins = store.unread.contains(crew.id)
        let newChat = store.unreadChats.contains(crew.id)
        let unread = newWins || newChat
        let latest = store.latest(in: crew.id)
        return HStack(spacing: 12) {
            Circle()
                .fill(unread ? AppColors.inkPrimary : .clear)
                .frame(width: 9, height: 9)
                .accessibilityHidden(true)
            CrewFaces(crew: crew, me: store.me, side: 56)
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline) {
                    Text(crew.displayName(excluding: store.me))
                        .font(Typography.headerMedium)
                        .foregroundStyle(AppColors.inkPrimary)
                        .lineLimit(1)
                        .fitsLargeType(.body)
                    // **The crew's streak, tiny** (2026-10-09, unification
                    // §5c): a flame and the number, quiet ink, after the
                    // name, from three days on. Not the win count at the
                    // end of the row the owner had removed: a streak is the
                    // crew's together, and under three it says nothing.
                    let streak = CrewStats.current(for: crew, store: store)
                    if streak >= 3 {
                        HStack(spacing: 2) {
                            Image(systemName: "flame.fill").imageScale(.small)
                            Text("\(streak)").monospacedDigit()
                        }
                        .font(Typography.screenSubtitle)
                        .foregroundStyle(AppColors.inkSecondary)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(streak) day crew streak")
                    }
                    // Muted, marked as Messages marks it.
                    if store.isMuted(crew.id) {
                        Image(systemName: "bell.slash.fill")
                            .font(Typography.screenSubtitle)
                            .imageScale(.small)
                            .foregroundStyle(AppColors.inkTertiary)
                            .accessibilityLabel("Muted")
                    }
                    Spacer(minLength: 8)
                    if let latest {
                        Text(Self.when(latest.createdAt))
                            .font(Typography.screenSubtitle)
                            .foregroundStyle(AppColors.inkSecondary)
                    }
                }
                Text(Self.preview(latest, in: crew, me: store.me))
                    .font(Typography.screenSubtitle)
                    .foregroundStyle(AppColors.inkSecondary)
                    .lineLimit(2)
            }
            // **No count at the end of the row** (the owner, 2026-10-02: "I
            // dont like the big number of wins outside the chat... just
            // remove it"). It replaced a miniature tower and was removed in
            // its turn: a row is who, the latest win and when, as Messages'.
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        // A value, not a hint: hints can be turned off, and then the only
        // sign a crew had something new was a dot VoiceOver does not see.
        .accessibilityValue(newWins && newChat ? "New wins and messages"
                            : newWins ? "New wins" : newChat ? "New messages" : "")
    }

    /// "Sam: Gym", "Sam added a photo", "You: Read", or, before anything,
    /// who is in it.
    static func preview(_ win: SharedWin?, in crew: Crew, me: UUID) -> String {
        guard let win else {
            let count = crew.members.count
            return count <= 1 ? "Waiting for people to join" : "\(count) people. No wins yet today."
        }
        let who = win.senderProfileID == me ? "You"
            : (crew.member(win.senderProfileID)?.shortName).flatMap { $0.isEmpty ? nil : $0 } ?? "A friend"
        let title = win.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if title.isEmpty { return win.photo != nil ? "\(who) added a photo" : "\(who) added a win" }
        return "\(who): \(title)"
    }

    /// The time today, "Yesterday", or the weekday, as Messages does.
    static func when(_ date: Date, now: Date = .now) -> String {
        let calendar = Calendar.current
        if calendar.isDate(date, inSameDayAs: now) { return date.formatted(date: .omitted, time: .shortened) }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        return date.formatted(.dateTime.weekday(.wide))
    }

    private var needsNewerOS: some View {
        VStack(spacing: GridConstants.gapTight) {
            Spacer()
            Text(CrewGate.newerOSWords)
                .font(Typography.headerMedium)
                .foregroundStyle(AppColors.inkPrimary)
                .multilineTextAlignment(.center)
            Spacer()
            Spacer()
        }
        .padding(.horizontal, GridConstants.gapSection)
        .frame(maxWidth: .infinity)
    }

    private var tooYoung: some View {
        VStack(spacing: GridConstants.gapTight) {
            Spacer()
            Text("Crews are for 13 and up")
                .font(Typography.headerMedium)
                .foregroundStyle(AppColors.inkPrimary)
            Text("Your own tower is all yours, and nothing about it changes.")
                .font(Typography.screenSubtitle)
                .foregroundStyle(AppColors.inkSecondary)
                .multilineTextAlignment(.center)
            Spacer()
            Spacer()
        }
        .padding(.horizontal, GridConstants.gapSection)
        .frame(maxWidth: .infinity)
    }

    /// Arrived by an invitation: the crew is being opened.
    private var joiningState: some View {
        VStack(spacing: GridConstants.gapItem) {
            Spacer()
            ProgressView()
            Text("Joining your crew")
                .font(Typography.headerMedium)
                .foregroundStyle(AppColors.inkPrimary)
            Text("This takes a moment the first time.")
                .font(Typography.bodyLarge)
                .foregroundStyle(AppColors.inkSecondary)
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var empty: some View {
        VStack(spacing: GridConstants.gapWide) {
            Spacer()
            // **Signed out of iCloud, said first** (the 2026-10-03 audit). A
            // crew lives in your iCloud, and the page offered New Crew and
            // only failed once you had pressed it.
            if signedOut {
                Text("Crews are shared through iCloud. Sign in to iCloud in Settings to start one.")
                    .font(Typography.headerMedium)
                    .foregroundStyle(AppColors.inkPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, GridConstants.gapSection)
                PrimaryCapsule(title: "Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                }
                .frame(maxWidth: 240)
            } else {
                // **The drawing, then what a crew is, then the one action**
                // (the owner, 2026-10-08: "the drawing of the crew should be
                // in the empty state"; "crews is confusing to understand for
                // new users"). A first visit had one sentence and a button,
                // which told nobody what pressing it would make. Now: his
                // drawing of three friends, three lines that each answer one
                // question (who, what happens, who sees it), and New Crew where
                // every page keeps its action, at the foot.
                if let art = UIImage(named: "CrewsTogether") {
                    Illustration(art: art, line: "Winning is better together", height: 190,
                                 motion: UIImage(named: "CrewsTogetherCheer").map { .cheer(marks: $0) })
                }
                FeatureList(rows: [
                    ("MarkPeople", "Up to 8 friends", "You included."),
                    ("MarkLayers", "One tower for the day", "Send a win and it lands there."),
                    ("MarkLock", "Private", "Only people you invite can see it."),
                ])
                // On the page margin, the New Crew button's own edge.
                .padding(.horizontal, GridConstants.horizontalPadding)
            }
            Spacer()
            if !signedOut {
                PrimaryCapsule(title: "New Crew") { startsCrew = true }
                    .padding(.horizontal, GridConstants.horizontalPadding)
                    .padding(.bottom, GridConstants.gapWide)
            }
        }
        .frame(maxWidth: .infinity)
        .task {
            guard let cloud = store.cloud as? PublicCrewCloud else { return }
            let status = try? await cloud.container.accountStatus()
            signedOut = status != .available
        }
    }
}

/// Starting a crew: a name, then the system's share sheet to invite people.
struct NewCrewSheet: View {
    var started: (CrewID) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    /// A crew starts with its photo (the owner, 2026-10-02: "the photo would
    /// mean more and be more social"). 13 to 15 send no photos, so their
    /// crews show everyone's faces instead.
    @State private var photoItem: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var photo: UIImage?
    private var needsPhoto: Bool { CrewAge.current.sendsPhotos }
    @State private var working = false
    @State private var problem: String?
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: GridConstants.gapItem) {
                if needsPhoto { photoPicker.frame(maxWidth: .infinity).padding(.bottom, GridConstants.gapTight) }
                // Open, like Add Win's "What did you do?": a name is typed
                // onto the page, not into a box.
                TextField("Name (optional)", text: $name,
                          prompt: Text("Name (optional)").foregroundStyle(AppColors.inkTertiary))
                    .font(Typography.headerMedium)
                    .foregroundStyle(AppColors.inkPrimary)
                    .focused($focused)
                    .submitLabel(.go)
                    .onSubmit(start)
                Text("Up to 8 people, you included. Everyone sees the wins sent to the crew that day, with their photos.")
                    .font(Typography.screenSubtitle)
                    .foregroundStyle(AppColors.inkSecondary)
                // Red, as every error the app sets on the page is (the owner,
                // 2026-10-08), in the words `CrewErrorWords` chose.
                if let problem {
                    Text(problem)
                        .font(Typography.screenSubtitle)
                        .foregroundStyle(AppColors.destructiveInk)
                        .fixedSize(horizontal: false, vertical: true)
                        .transition(.opacity)
                }
                Spacer(minLength: 0)
                if working {
                    PrimaryCapsule(waiting: "Starting", because: "The crew is being made")
                } else {
                    PrimaryCapsule(title: "Invite People", action: start)
                }
            }
            .padding(GridConstants.horizontalPadding)
            .padding(.top, GridConstants.gapTight)
            .navigationTitle("New Crew")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Text("Cancel").sheetAction(.cancel) }
                }
            }
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                Task {
                    guard let data = try? await item.loadTransferable(type: Data.self) else { return }
                    photoData = data
                    photo = UIImage(data: data)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func start() {
        guard !working else { return }
        working = true
        problem = nil
        Task {
            do {
                let (crew, _) = try await SocialStore.shared.createCrew(name: name, photoJPEG: photoData)
                dismiss()
                started(crew.id)
                try? await Task.sleep(for: .milliseconds(450))
                await CrewSharing.invite(crew.id)
            } catch {
                // Plain words for what went wrong and what to do; CloudKit's
                // own text goes to the log (`CrewErrorWords`).
                problem = CrewErrorWords.say(error, while: .starting)
            }
            working = false
        }
    }
}

extension NewCrewSheet {
    /// The crew's picture, first: a circle to tap, the photo in it once chosen.
    var photoPicker: some View {
        PhotosPicker(selection: $photoItem, matching: .images) {
            ZStack {
                Circle().fill(AppColors.quietFill)
                if let photo {
                    Image(uiImage: photo).resizable().scaledToFill()
                } else {
                    VStack(spacing: 6) {
                        Image(systemName: "photo.badge.plus")
                            .font(Typography.headerMedium)
                        Text("Add Photo")
                            .font(Typography.headerSmall)
                    }
                    .foregroundStyle(AppColors.inkSecondary)
                }
            }
            .frame(width: 112, height: 112)
            .clipShape(Circle())
            .contentShape(Circle())
        }
        .buttonStyle(.pressSurface)
        .accessibilityLabel(photo == nil ? "Add a photo for the crew" : "Change the crew's photo")
    }
}

/// The header's way in: a glass button with a dot when a crew has a win you
/// have not seen, the way Messages marks a thread. No number.
struct CrewsButton: View {
    var action: () -> Void
    private var store: SocialStore { SocialStore.shared }
    /// **Lit until Crews has been opened once** (the owner, 2026-10-08: "for
    /// the first time clicking the social icon the notification should be on
    /// just to guide the user"). The same dot a new win lights, so a new
    /// person's eye is led to the one place the app has not shown them.
    @AppStorage(Self.openedKey) private var opened = false
    static let openedKey = "crews.openedOnce"

    var body: some View {
        GlassIconButton(systemName: "person.2", onPage: true,
                        accessibilityLabel: hasNews ? "Crews, something new" : "Crews") {
            opened = true
            action()
        }
            .overlay(alignment: .topTrailing) {
                if hasNews {
                    Circle()
                        .fill(AppColors.inkPrimary)
                        .frame(width: 10, height: 10)
                        .overlay(Circle().strokeBorder(WarmBackground.top, lineWidth: 1.5))
                        .offset(x: 1, y: -1)
                        .transition(.scale.combined(with: .opacity))
                        .accessibilityHidden(true)
                }
            }
            .animation(GridConstants.motionSnappy, value: hasNews)
            .task { await store.refresh() }
    }

    /// A new win, a reaction to yours, or a chat line you have not read, in
    /// any crew (the owner, 2026-10-06: chat lights it too).
    private var hasNews: Bool {
        !opened || !store.unread.isEmpty || !store.unreadChats.isEmpty
    }
}

/// The Wins tab's crew screens, and the router that opens one from outside
/// (an accepted invitation, a tapped notification). A modifier so
/// `MainAppView`'s body, already at the type-checker's ceiling, gains one line.
struct CrewDestinations: ViewModifier {
    @Binding var path: [CrewRoute]
    /// The crew rules, once, the first time anything of Crews is opened:
    /// the list, a crew, or an invitation (`CrewRules`).
    @State private var rulesAccepted = CrewRules.accepted
    /// Add Win, with a crew ticked.
    var addWin: (CrewID) -> Void
    /// The empty slot's one-tap win, into a crew.
    var logWin: (CrewID, BlockSize, HabitCategory) -> Void = { _, _, _ in }
    private var router: CrewRouter { CrewRouter.shared }

    func body(content: Content) -> some View {
        content
            // Not below iOS 26 or for a known child: the rules are for
            // something they can join (2026-10-08).
            .sheet(isPresented: Binding(get: { !path.isEmpty && !rulesAccepted && !CrewGate.current.isFinal
                                                && !CrewsFilm.holdsRules },
                                        set: { _ in })) {
                CrewRulesSheet(onAgree: {
                    rulesAccepted = true
                    router.joinPendingIfReady()
                }, onNotNow: {
                    // Not Now is a no to the invitation too: it is not joined.
                    router.dropPendingInvite()
                    path = []
                })
            }
            .navigationDestination(for: CrewRoute.self) { route in
                switch route {
                case .list:
                    CrewsListView { path.append(.crew($0)) }
                case .crew(let id):
                    CrewTowerView(crewID: id, onBack: { if !path.isEmpty { path.removeLast() } },
                                  onAddWin: { addWin(id) },
                                  onLogWin: { logWin(id, $0, $1) })
                }
            }
            .onChange(of: router.open) { _, crew in
                guard let crew else { return }
                route(to: crew)
            }
            .onChange(of: router.opensList) { _, opens in
                guard opens else { return }
                router.opensList = false
                path = [.list]
            }
            .onAppear {
                if let crew = router.open { route(to: crew) }
                if router.opensList {
                    router.opensList = false
                    path = [.list]
                }
                #if DEBUG
                if DebugHarness.opensCrewList, path.isEmpty { path = [.list] }
                #endif
            }
            .alert("This photo stays with you", isPresented: Binding(
                get: { SocialStore.shared.heldBackPhoto != nil },
                set: { if !$0 { SocialStore.shared.clearHeldBackPhoto() } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("It looked like something Some Wins doesn't send to crews. Your win was still sent, without it.")
            }
            .alert("Crews", isPresented: Binding(get: { router.joinProblem != nil },
                                                 set: { if !$0 { router.joinProblem = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(router.joinProblem ?? "")
            }
    }

    /// **A crew asked for from outside, through the gate** (2026-10-08). A
    /// tapped notification on a phone below iOS 26, or a known child's,
    /// opens the list, which says why; it never pushes the crew itself.
    private func route(to crew: CrewID) {
        router.open = nil
        if CrewGate.current.isFinal {
            router.openWin = nil
            router.openChat = false
            path = [.list]
        } else {
            path = [.list, .crew(crew)]
        }
    }
}

/// Asks Apple's Declared Age Range once, the first time Crews opens, and
/// keeps the answer (spec 9.1). Declining, or a phone that cannot answer, is
/// kept as `declined`, which is treated exactly as 13 to 15 (`CrewAge.rule`).
///
/// **Nothing below iOS 26** (2026-10-08). It used to store `declined` there
/// without asking and open crews; crews need iOS 26 now, and the list says so
/// instead (`CrewGate.needsNewerOS`).
private struct AskAgeOnce: ViewModifier {
    @Binding var age: CrewAge

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.modifier(Ask(age: $age))
        } else {
            content
        }
    }

    @available(iOS 26.0, *)
    private struct Ask: ViewModifier {
        @Binding var age: CrewAge
        @Environment(\.requestAgeRange) private var requestAgeRange

        func body(content: Content) -> some View {
            content.task {
                guard CrewAge.needsAsking() else { return }
                let answer: CrewAge
                do {
                    switch try await requestAgeRange(ageGates: 13, 16) {
                    case .sharing(let range): answer = CrewAge.from(lowerBound: range.lowerBound)
                    case .declinedSharing: answer = .declined
                    @unknown default: answer = .declined
                    }
                } catch {
                    // The service could not answer (on TestFlight, because the
                    // Declared Age Range capability is not on the app ID yet):
                    // testers are adults the owner invited, so photos go. In
                    // the App Store the cautious answer stands.
                    answer = CrewsFlag.isTestFlight ? .adult : .declined
                }
                CrewAge.save(answer)
                age = answer
                // An invitation waiting on this answer joins now, or is let
                // go for an under-13.
                CrewRouter.shared.joinPendingIfReady()
            }
        }
    }
}

/// When Crews plays its film: once ever, with no crew yet, on iOS 26, for
/// someone old enough, and not while an invitation is waiting to be joined.
@MainActor @Observable
final class CrewsFilm {
    static let seenKey = "crews.filmSeen"
    private static let shared = CrewsFilm()
    private var seen = UserDefaults.standard.bool(forKey: seenKey)

    static func isDue(crews: Int) -> Bool {
        !shared.seen && crews == 0 && CrewsFlag.osSupportsCrews && CrewAge.current.opensCrews
            && CrewRouter.shared.pendingInvite == nil && !CrewRouter.shared.joining
    }

    /// The film is up or due: the crew rules wait for it to finish.
    static var holdsRules: Bool { isDue(crews: SocialStore.shared.crews.count) }

    static func markSeen() {
        shared.seen = true
        UserDefaults.standard.set(true, forKey: seenKey)
    }
}
