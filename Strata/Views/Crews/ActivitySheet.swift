import SwiftUI

/// **Your notifications, the Crews corner** (the owner's add-on to the
/// launch pass). Everything waiting on you socially (`ActivityFeed`), newest
/// first under Today, Yesterday and Earlier, each line their head, who and
/// what, and when; a tap goes where it happened. Calm on purpose: no counts,
/// no red, and an empty page in the app's voice.
struct ActivitySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var store: SocialStore { SocialStore.shared }
    /// The grouped rows opened out (`ActivityItem.children`).
    @State private var opened: Set<String> = []

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
                                    Button {
                                        if item.children.isEmpty { open(item) } else { toggle(item) }
                                    } label: { row(item) }
                                        .buttonStyle(.press)
                                        .listRowBackground(Color.clear)
                                        .listRowSeparator(.hidden)
                                        .accessibilityHint(item.children.isEmpty ? ""
                                                           : opened.contains(item.id) ? "Folds these away." : "Shows each one.")
                                    // Opened out: each one, a little in, a
                                    // tap from where it happened.
                                    if opened.contains(item.id) {
                                        ForEach(item.children) { child in
                                            Button { open(child) } label: { row(child, small: true) }
                                                .buttonStyle(.press)
                                                .listRowBackground(Color.clear)
                                                .listRowSeparator(.hidden)
                                                .listRowInsets(EdgeInsets(top: 4, leading: 56, bottom: 4, trailing: 16))
                                        }
                                    }
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

    private func toggle(_ item: ActivityItem) {
        HapticsEngine.tick()
        withAnimation(reduceMotion ? GridConstants.crossFade : GridConstants.motionSnappy) {
            if opened.contains(item.id) { opened.remove(item.id) } else { opened.insert(item.id) }
        }
    }

    private func row(_ item: ActivityItem, small: Bool = false) -> some View {
        HStack(alignment: .top, spacing: GridConstants.gapItem) {
            if let first = item.people.first, let member = store.crews.lazy.compactMap({ $0.member(first) }).first {
                PersonHead(person: .member(member, crew: item.crewID, me: store.me), side: small ? 28 : 40)
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
            if !item.children.isEmpty {
                Image(systemName: "chevron.down")
                    .font(Typography.headerSmall)
                    .imageScale(.small)
                    .foregroundStyle(AppColors.inkTertiary)
                    .rotationEffect(.degrees(opened.contains(item.id) ? 180 : 0))
                    .padding(.top, 4)
                    .accessibilityHidden(true)
            }
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
