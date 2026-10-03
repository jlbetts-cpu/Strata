import PhotosUI
import SwiftUI
import UserNotifications

/// A crew's details, laid out the way Messages lays out a group's: its
/// picture and name at the top, then its people, then the switches, then
/// leaving.
///
/// Anyone can rename the crew, change its picture and invite (the owner's
/// call, 2026-10-02: "like Messages"). Only the person who started it can
/// remove someone or end it.
struct CrewInfoSheet: View {
    let crewID: CrewID
    var onLeft: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var pickerItem: PhotosPickerItem?
    @State private var confirmsLeave = false
    @State private var problem: String?
    @FocusState private var editingName: Bool
    @State private var systemOff = false
    /// A crew day playing, presented from the page rather than a List row.
    @State private var replay: Replay?

    private var store: SocialStore { SocialStore.shared }
    private var crew: Crew? { store.visible(crewID) }
    private var isOwner: Bool { crew?.isOwner(store.me) == true }

    var body: some View {
        NavigationStack {
            if let crew {
                List {
                    identity(crew)
                    CrewStatsSections(crew: crew) { replay = $0 }
                    Section {
                        ForEach(members(crew)) { member in
                            memberRow(member, in: crew)
                        }
                        if crew.members.count < CrewCaps.members {
                            Button {
                                Task { await CrewSharing.invite(crewID) }
                            } label: {
                                Label("Add People", systemImage: "person.badge.plus")
                                    .font(Typography.bodyLarge)
                            }
                        }
                    } header: {
                        // The page's one header style, as Crew Streak and
                        // Days above it have.
                        FormSectionLabel(crew.members.count == 1 ? "1 Person" : "\(crew.members.count) People")
                    } footer: {
                        Text("Up to 8 people. Everyone here sees the wins sent to this crew today.")
                    }
                    Section {
                        Toggle(isOn: Binding(get: { store.showsHeads(crewID) },
                                             set: { on in withAnimation(GridConstants.motionSnappy) { store.setShowsHeads(on, for: crewID) } })) {
                            Label("Heads", systemImage: "face.smiling")
                                .font(Typography.bodyLarge)
                        }
                        .tint(AppColors.switchTrack)
                    } footer: {
                        Text(store.showsHeads(crewID) ? "Everyone's heads live on this crew's tower."
                                                     : "Only the wins, on your phone. Nobody else is told.")
                    }
                    notifications
                    Section {
                        Button(isOwner ? "End Crew" : "Leave Crew", role: .destructive) { confirmsLeave = true }
                            .font(Typography.bodyLarge)
                            // **On the button, not the List.** iOS 26 draws a
                            // dialog from the view it hangs on, and hung on the
                            // whole List it never appeared: End Crew did
                            // nothing at all (the owner, 2026-10-03).
                            .confirmationDialog(isOwner ? "End this crew for everyone?" : "Leave this crew?",
                                                isPresented: $confirmsLeave, titleVisibility: .visible) {
                                Button(isOwner ? "End Crew" : "Leave Crew", role: .destructive) { leave() }
                            }
                    } footer: {
                        Text(isOwner ? "Ending the crew removes it, and every win in it, for everyone."
                                     : "Your wins leave the crew with you.")
                    }
                }
                // No rules between rows: a card's rows are told apart by
                // their room, as everywhere else in the app (2026-10-03).
                .listRowSeparator(.hidden)
                .listSectionSeparator(.hidden)
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .background(WarmBackground().ignoresSafeArea())
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button { commitName(); dismiss() } label: { Text("Done").sheetAction(.confirm) }
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
                .alert("Something went wrong", isPresented: Binding(get: { problem != nil }, set: { if !$0 { problem = nil } })) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(problem ?? "")
                }
                .onAppear { name = crew.name }
                .onChange(of: pickerItem) { _, item in
                    guard let item else { return }
                    Task {
                        let data = try? await item.loadTransferable(type: Data.self)
                        do { try await store.setPhoto(crewID, jpeg: data) } catch CrewError.photoNotAllowed {
                            problem = "That photo stays with you. Pick another, or keep everyone's faces."
                        } catch { problem = "The picture could not be saved." }
                        pickerItem = nil
                    }
                }
            }
        }
        .fullScreenCover(item: $replay) { shown in
            ReplayView(replay: shown) { replay = nil }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    /// What this crew may tell you. Mute for a while or until you say, as
    /// Messages, WhatsApp and Discord offer it, and reactions apart from
    /// wins: the one switch Messages users keep asking Apple for.
    @ViewBuilder
    private var notifications: some View {
        Section {
            if systemOff {
                Button {
                    if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Notifications are off for Sturdy")
                            .font(Typography.bodyLarge)
                            .foregroundStyle(AppColors.inkPrimary)
                        Text("Turn On in Settings")
                            .font(Typography.screenSubtitle)
                            .foregroundStyle(AppColors.inkSecondary)
                    }
                }
            }
            Menu {
                Button("Off") { store.mute(crewID, nil) }
                ForEach(SocialStore.Mute.allCases) { length in
                    Button(length.words) { store.mute(crewID, length) }
                }
            } label: {
                HStack {
                    Label("Mute", systemImage: store.isMuted(crewID) ? "bell.slash" : "bell")
                        .font(Typography.bodyLarge)
                        .foregroundStyle(AppColors.inkPrimary)
                    Spacer()
                    Text(muteState)
                        .font(Typography.screenSubtitle)
                        .foregroundStyle(AppColors.inkSecondary)
                }
            }
            Toggle(isOn: Binding(get: { store.reactionAlerts(crewID) },
                                 set: { store.setReactionAlerts($0, for: crewID) })) {
                Label("Reactions to My Wins", systemImage: "heart")
                    .font(Typography.bodyLarge)
            }
            .tint(AppColors.switchTrack)
            .disabled(store.isMuted(crewID))
        } header: {
            FormSectionLabel("Notifications")
        } footer: {
            Text(store.isMuted(crewID) ? "Nothing from this crew until the mute ends. Its wins still arrive."
                                       : "A notification for every win, and for reactions to yours.")
        }
        .task {
            systemOff = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus == .denied
        }
    }

    private var muteState: String {
        guard let until = store.mutedUntil(crewID) else { return "Off" }
        if until > Date().addingTimeInterval(365 * 86_400) { return "On" }
        return Calendar.current.isDateInToday(until)
            ? "Until \(until.formatted(date: .omitted, time: .shortened))"
            : "Until \(until.formatted(.dateTime.weekday(.wide).hour().minute()))"
    }

    private func identity(_ crew: Crew) -> some View {
        Section {
            VStack(spacing: GridConstants.gapTight) {
                CrewFaces(crew: crew, me: store.me, side: 96)
                    .accessibilityHidden(true)
                // A crew's picture is a photograph (the owner, 2026-10-02);
                // there is no colour or faces option to swap it for. 13 to
                // 15 send no photos, so their crews keep everyone's faces.
                if CrewAge.current.sendsPhotos {
                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        Text("Edit")
                            .font(Typography.headerSmall)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            // The page's clear glass, as the crew's name
                            // capsule has: the type-panel recipe is for words
                            // over a photograph and read as a grey pill here.
                            .glassCapsule(onPage: true)
                    }
                    .accessibilityLabel("Change the crew's photo")
                }
                TextField(crew.displayName(excluding: store.me), text: $name)
                    .font(Typography.headerMedium)
                    .multilineTextAlignment(.center)
                    .submitLabel(.done)
                    .focused($editingName)
                    .onSubmit(commitName)
                    .padding(.top, GridConstants.gapTight)
                    .accessibilityLabel("Crew name")
                // Only while you have no head: the crew's page is where its
                // people are, so it is where yours is asked for (the owner,
                // 2026-10-02: "only pops up if you havent made it... in the
                // middle menu not on the main page").
                if HeadStore.shared.headForCrews == nil {
                    MakeYourHeadPill(crew: crew, me: store.me)
                        .padding(.top, GridConstants.gapTight)
                }
            }
            .frame(maxWidth: .infinity)
            .listRowBackground(Color.clear)
        }
    }

    private func members(_ crew: Crew) -> [CrewMember] {
        crew.members.sorted { a, b in
            if a.profileID == store.me { return true }
            if b.profileID == store.me { return false }
            return a.joinedAt < b.joinedAt
        }
    }

    @ViewBuilder
    private func memberRow(_ member: CrewMember, in crew: Crew) -> some View {
        let isMe = member.profileID == store.me
        HStack(spacing: 12) {
            CrewFace(member: member, crew: crew.id, me: store.me, side: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(isMe ? "You" : (member.firstName.isEmpty ? "A friend" : member.firstName))
                    .font(Typography.bodyLarge)
                    .foregroundStyle(AppColors.inkPrimary)
                if crew.isOwner(member.profileID) {
                    Text("Started the crew")
                        .font(Typography.screenSubtitle)
                        .foregroundStyle(AppColors.inkSecondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .swipeActions {
            if !isMe {
                if isOwner {
                    Button("Remove", role: .destructive) {
                        Task {
                            do { try await store.remove(member: member.profileID, from: crewID) }
                            catch { problem = "They could not be removed. Try again in a moment." }
                        }
                    }
                }
                Button("Block") {
                    Task { await CrewSafety.block(member.profileID, from: crewID) }
                }
            }
        }
    }

    private func commitName() {
        guard let crew, name.trimmingCharacters(in: .whitespacesAndNewlines) != crew.name else { return }
        Task {
            do { try await store.rename(crewID, to: name) } catch { problem = "The name could not be saved." }
        }
    }

    private func leave() {
        Task {
            do {
                if isOwner { try await store.end(crewID) } else { try await store.leave(crewID) }
                dismiss()
                onLeft()
            } catch {
                problem = isOwner ? "The crew could not be ended. Try again in a moment."
                                  : "You could not leave just now. Try again in a moment."
            }
        }
    }
}
