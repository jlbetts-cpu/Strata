import SwiftUI

/// **Your notifications, the Crews corner** (the owner's add-on to the
/// launch pass). Everything waiting on you socially (`ActivityFeed`), newest
/// first under Today, Yesterday and Earlier, each line their head, who and
/// what, and when; a tap goes where it happened. Calm on purpose: no counts,
/// no red, and an empty page in the app's voice.
struct ActivitySheet: View {
    @Environment(\.dismiss) private var dismiss
    private var store: SocialStore { SocialStore.shared }

    var body: some View {
        let items = store.activityFeed()
        NavigationStack {
            Group {
                if items.isEmpty {
                    VStack {
                        Spacer()
                        EmptyPageLine("Nothing waiting on you", icon: "bell",
                                      detail: "When a friend reacts, replies, plans or joins, it shows up here.")
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    List {
                        ForEach(sections(items), id: \.title) { section in
                            Section {
                                ForEach(section.items) { item in
                                    Button { open(item) } label: { row(item) }
                                        .buttonStyle(.press)
                                        .listRowBackground(Color.clear)
                                        .listRowSeparator(.hidden)
                                }
                            } header: {
                                Text(section.title)
                                    .font(Typography.headerSmall)
                                    .foregroundStyle(AppColors.inkSecondary)
                                    .textCase(nil)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background { WarmBackground().ignoresSafeArea() }
            .sheetTitle("Activity", drawn: false)
            .toolbar {
                BareToolbarItem(placement: .confirmationAction) {
                    Button { dismiss() } label: { Text("Done").sheetAction() }
                        .buttonStyle(.pressWord)
                }
            }
        }
        .onAppear { store.markActivitySeen() }
    }

    private struct DaySection { let title: String; let items: [ActivityItem] }

    private func sections(_ items: [ActivityItem]) -> [DaySection] {
        let calendar = Calendar.current
        let today = items.filter { calendar.isDateInToday($0.date) }
        let yesterday = items.filter { calendar.isDateInYesterday($0.date) }
        let earlier = items.filter { !calendar.isDateInToday($0.date) && !calendar.isDateInYesterday($0.date) }
        return [("Today", today), ("Yesterday", yesterday), ("Earlier", earlier)]
            .filter { !$0.1.isEmpty }.map { DaySection(title: $0.0, items: $0.1) }
    }

    private func row(_ item: ActivityItem) -> some View {
        HStack(alignment: .top, spacing: GridConstants.gapItem) {
            if let first = item.people.first, let member = store.crews.lazy.compactMap({ $0.member(first) }).first {
                PersonHead(person: .member(member, crew: item.crewID, me: store.me), side: 40)
            }
            VStack(alignment: .leading, spacing: 2) {
                (Text(store.names(item.people, in: item.crewID)).fontWeight(.semibold)
                 + Text(" " + item.words))
                    .font(Typography.bodyLarge)
                    .foregroundStyle(AppColors.inkPrimary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                Text(item.date.formatted(.relative(presentation: .named)))
                    .font(Typography.screenSubtitle)
                    .foregroundStyle(AppColors.inkTertiary)
            }
            Spacer(minLength: 0)
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    /// Where it happened: the crew, at the win; the chat for a plan; the
    /// person's page for a message.
    private func open(_ item: ActivityItem) {
        HapticsEngine.lightTap()
        dismiss()
        let router = CrewRouter.shared
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(400))
            switch item.kind {
            case .reacted, .replied: router.openWin = item.winID
            case .planned: router.openChat = true
            case .message, .joined: break
            }
            router.open = item.crewID
        }
    }
}
