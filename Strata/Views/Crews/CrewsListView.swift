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
    @State private var leaving: Crew?
    @State private var problem: String?
    private var store: SocialStore { SocialStore.shared }

    @State private var age = CrewAge.current

    var body: some View {
        Group {
            if !age.opensCrews {
                tooYoung
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
            if age.opensCrews { ToolbarItem(placement: .topBarTrailing) {
                Button { startsCrew = true } label: {
                    Image(systemName: "square.and.pencil").sheetAction(.confirm, as: .glyph)
                }
                .disabled(store.crews.count >= CrewCaps.crews)
                .accessibilityLabel("New Crew")
            } }
        }
        .task { await store.refresh() }
        #if DEBUG
        .onAppear { if DebugHarness.argument("-strataCrewSheet") == "new" { startsCrew = true } }
        #endif
        .modifier(AskAgeOnce(age: $age))
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
        let unread = store.unread.contains(crew.id)
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
        .accessibilityHint(unread ? "New wins." : "")
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

    private var empty: some View {
        VStack(spacing: GridConstants.gapWide) {
            Spacer()
            Text("Start a crew. Just the people you'd tell anyway.")
                .font(Typography.headerMedium)
                .foregroundStyle(AppColors.inkPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, GridConstants.gapSection)
            PrimaryCapsule(title: "New Crew") { startsCrew = true }
                .frame(maxWidth: 240)
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity)
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
                if let problem {
                    Text(problem)
                        .font(Typography.screenSubtitle)
                        .foregroundStyle(AppColors.inkPrimary)
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
            } catch let error as CrewError where error != .unknownCrew {
                problem = StrataSceneDelegate.words(for: error)
            } catch {
                // Say what iCloud said: on a tester's phone this line is the
                // only way to know why.
                problem = "The crew could not be started: \(error.localizedDescription)"
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

    var body: some View {
        GlassIconButton(systemName: "person.2", onPage: true,
                        accessibilityLabel: store.unread.isEmpty ? "Crews" : "Crews, new wins", action: action)
            .overlay(alignment: .topTrailing) {
                if !store.unread.isEmpty {
                    Circle()
                        .fill(AppColors.inkPrimary)
                        .frame(width: 10, height: 10)
                        .overlay(Circle().strokeBorder(.white, lineWidth: 1.5))
                        .offset(x: 1, y: -1)
                        .transition(.scale.combined(with: .opacity))
                        .accessibilityHidden(true)
                }
            }
            .animation(GridConstants.motionSnappy, value: store.unread.isEmpty)
            .task { await store.refresh() }
    }
}

/// The Wins tab's crew screens, and the router that opens one from outside
/// (an accepted invitation, a tapped notification). A modifier so
/// `MainAppView`'s body, already at the type-checker's ceiling, gains one line.
struct CrewDestinations: ViewModifier {
    @Binding var path: [CrewRoute]
    /// Add Win, with a crew ticked.
    var addWin: (CrewID) -> Void
    /// The empty slot's one-tap win, into a crew.
    var logWin: (CrewID, BlockSize, HabitCategory) -> Void = { _, _, _ in }
    private var router: CrewRouter { CrewRouter.shared }

    func body(content: Content) -> some View {
        content
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
                path = [.list, .crew(crew)]
                router.open = nil
            }
            .onAppear {
                if let crew = router.open {
                    path = [.list, .crew(crew)]
                    router.open = nil
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
                Text("It looked like something Sturdy doesn't send to crews. Your win was still sent, without it.")
            }
            .alert("Crews", isPresented: Binding(get: { router.joinProblem != nil },
                                                 set: { if !$0 { router.joinProblem = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(router.joinProblem ?? "")
            }
    }
}

/// Asks Apple's Declared Age Range once, the first time Crews opens, and
/// keeps the answer (spec 9.1). Declining, or a phone that cannot answer, is
/// kept as 13 to 15: crews work and photographs stay on the phone.
private struct AskAgeOnce: ViewModifier {
    @Binding var age: CrewAge

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.modifier(Ask(age: $age))
        } else {
            content.onAppear { if age == .unknown { age = .teen; CrewAge.save(.teen) } }
        }
    }

    @available(iOS 26.0, *)
    private struct Ask: ViewModifier {
        @Binding var age: CrewAge
        @Environment(\.requestAgeRange) private var requestAgeRange

        func body(content: Content) -> some View {
            content.task {
                guard age == .unknown else { return }
                let answer: CrewAge
                do {
                    switch try await requestAgeRange(ageGates: 13, 16) {
                    case .sharing(let range): answer = CrewAge.from(lowerBound: range.lowerBound)
                    case .declinedSharing: answer = .teen
                    @unknown default: answer = .teen
                    }
                } catch {
                    // The service could not answer (on TestFlight, because the
                    // Declared Age Range capability is not on the app ID yet):
                    // testers are adults the owner invited, so photos go. In
                    // the App Store the cautious answer stands.
                    answer = CrewsFlag.isTestFlight ? .adult : .teen
                }
                CrewAge.save(answer)
                age = answer
            }
        }
    }
}
