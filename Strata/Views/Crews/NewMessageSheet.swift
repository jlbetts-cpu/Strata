import SwiftUI

/// **New Message** (the owner, 2026-10-16: "I need just a way to message
/// individuals"): the compose button's sheet, as Messages has one. New Crew
/// at the top, then everyone you share a crew with, searchable. A tap starts
/// the conversation (`SocialStore.startPersonal`), or opens the one you
/// already have, and goes straight into it.
struct NewMessageSheet: View {
    let newCrew: () -> Void
    let opened: (CrewID) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    @State private var starting: UUID?
    @State private var failed = false
    private var store: SocialStore { SocialStore.shared }

    private var people: [(member: CrewMember, crew: CrewID)] {
        let all = store.messageablePeople
        let words = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !words.isEmpty else { return all }
        return all.filter { $0.member.firstName.localizedCaseInsensitiveContains(words)
            || ($0.member.handle ?? "").localizedCaseInsensitiveContains(words) }
    }

    var body: some View {
        NavigationStack {
            List {
                Button(action: newCrew) {
                    HStack(spacing: GridConstants.gapItem) {
                        Image(systemName: "person.3")
                            .font(Typography.bodyLarge)
                            .foregroundStyle(AppColors.inkPrimary)
                            .frame(width: 40, height: 40)
                            .background(Circle().fill(AppColors.quietFill))
                        Text(CrewLine.newCrew)
                            .font(Typography.bodyLarge)
                            .foregroundStyle(AppColors.inkPrimary)
                    }
                    .frame(minHeight: 44)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                Section {
                    ForEach(people, id: \.member.profileID) { person in
                        Button { start(person.member.profileID) } label: { row(person.member, in: person.crew) }
                            .disabled(starting != nil)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                } header: {
                    Text("People in your crews")
                        .font(Typography.headerSmall)
                        .foregroundStyle(AppColors.inkSecondary)
                        .textCase(nil)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always), prompt: "Name")
            .sheetTitle("New Message", drawn: false)
            .toolbar {
                BareToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Text("Cancel").sheetAction(.cancel) }
                        .buttonStyle(.pressWord)
                }
            }
            .alert("That didn't start", isPresented: $failed) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("They may need the latest Some Wins. Try again in a moment.")
            }
        }
    }

    private func row(_ member: CrewMember, in crew: CrewID) -> some View {
        HStack(spacing: GridConstants.gapItem) {
            PersonHead(person: .member(member, crew: crew, me: store.me), side: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(member.shortName.isEmpty ? "A friend" : member.shortName)
                    .font(Typography.bodyLarge)
                    .foregroundStyle(AppColors.inkPrimary)
                if let handle = store.shownHandle(of: member) {
                    Text("@\(handle)")
                        .font(Typography.screenSubtitle)
                        .foregroundStyle(AppColors.inkSecondary)
                }
            }
            Spacer(minLength: 0)
            if starting == member.profileID { ProgressView() }
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }

    private func start(_ friend: UUID) {
        HapticsEngine.lightTap()
        starting = friend
        Task {
            let crew = await store.startPersonal(with: friend)
            starting = nil
            if let crew { opened(crew.id) } else { failed = true }
        }
    }
}
