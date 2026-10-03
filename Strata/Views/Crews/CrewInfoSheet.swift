import PhotosUI
import SwiftUI

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

    private var store: SocialStore { SocialStore.shared }
    private var crew: Crew? { store.visible(crewID) }
    private var isOwner: Bool { crew?.isOwner(store.me) == true }

    var body: some View {
        NavigationStack {
            if let crew {
                List {
                    identity(crew)
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
                        Text(crew.members.count == 1 ? "1 Person" : "\(crew.members.count) People")
                    } footer: {
                        Text("Up to 8 people. Everyone here sees the wins sent to this crew today.")
                    }
                    Section {
                        Toggle("Hide Alerts", isOn: Binding(
                            get: { store.hidesAlerts(crewID) },
                            set: { store.setHidesAlerts($0, for: crewID) }))
                            .font(Typography.bodyLarge)
                            .tint(AppColors.switchTrack)
                    }
                    Section {
                        Button(isOwner ? "End Crew" : "Leave Crew", role: .destructive) { confirmsLeave = true }
                            .font(Typography.bodyLarge)
                    } footer: {
                        Text(isOwner ? "Ending the crew removes it, and every win in it, for everyone."
                                     : "Your wins leave the crew with you.")
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .background(WarmBackground().ignoresSafeArea())
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button { commitName(); dismiss() } label: { Text("Done").sheetAction(.confirm) }
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
                .confirmationDialog(isOwner ? "End this crew for everyone?" : "Leave this crew?",
                                    isPresented: $confirmsLeave, titleVisibility: .visible) {
                    Button(isOwner ? "End Crew" : "Leave Crew", role: .destructive) { leave() }
                }
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
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func identity(_ crew: Crew) -> some View {
        Section {
            VStack(spacing: GridConstants.gapTight) {
                CrewFaces(crew: crew, me: store.me, side: 96)
                    .accessibilityHidden(true)
                Menu {
                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        Label("Choose Photo", systemImage: "photo")
                    }
                    if crew.photo != nil {
                        Button("Use Everyone's Faces", systemImage: "person.2") {
                            Task { try? await store.setPhoto(crewID, jpeg: nil) }
                        }
                    }
                } label: {
                    Text("Edit")
                        .font(Typography.headerSmall)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .glassCapsule(onPage: true, carriesType: true)
                }
                .accessibilityLabel("Edit crew photo")
                TextField(crew.displayName(excluding: store.me), text: $name)
                    .font(Typography.headerMedium)
                    .multilineTextAlignment(.center)
                    .submitLabel(.done)
                    .focused($editingName)
                    .onSubmit(commitName)
                    .padding(.top, GridConstants.gapTight)
                    .accessibilityLabel("Crew name")
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
