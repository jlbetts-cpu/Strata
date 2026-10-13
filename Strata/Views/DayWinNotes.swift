import SwiftData
import SwiftUI

/// **The day's wins and their notes, at the head of that day's journal**
/// (`WinNote`). Nothing at all until a win of the day has a note. Then each
/// win is its name, and its note under it; a press on a name writes that
/// win's note in place.
///
/// No heading, no bullets, no card and no count: it is the page's own type,
/// above the page's own words.
struct DayWinNotes: View {
    @Query private var logs: [HabitLog]
    @Environment(\.modelContext) private var modelContext
    /// Told to the journal, so its empty line steps aside for these.
    @Binding var shown: Bool
    /// The win whose note is being written.
    @State private var writing: UUID?
    @FocusState private var focused: UUID?

    init(dateString: String, shown: Binding<Bool>) {
        _logs = Query(filter: #Predicate<HabitLog> { $0.dateString == dateString && $0.completed })
        _shown = shown
    }

    private var lines: [WinNote.Line] {
        WinNote.lines(logs.map {
            WinNote.Win(id: $0.id, title: $0.habit?.title ?? QuickWinService.untitled, note: $0.note,
                        createdAt: $0.createdAt, completedAt: $0.completedAt)
        })
    }

    var body: some View {
        let lines = lines
        VStack(alignment: .leading, spacing: GridConstants.gapItem) {
            ForEach(lines) { line in row(line) }
        }
        .padding(.horizontal, GridConstants.horizontalPadding)
        .padding(.top, lines.isEmpty ? 0 : GridConstants.gapItem)
        .padding(.bottom, lines.isEmpty ? 0 : GridConstants.gapWide)
        .onChange(of: !lines.isEmpty, initial: true) { _, has in if shown != has { shown = has } }
        .onChange(of: focused) { was, now in
            // Left with nothing written: the line folds away again.
            if now == nil, let was, writing == was { writing = nil }
        }
    }

    private func row(_ line: WinNote.Line) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Button {
                HapticsEngine.lightTap()
                writing = line.id
                focused = line.id
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: GridConstants.spacing) {
                    Text(line.title)
                        .font(Typography.headerMedium)
                        .foregroundStyle(AppColors.inkPrimary)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: GridConstants.spacing)
                    if let time = line.time {
                        Text(time, format: .dateTime.hour().minute())
                            .font(Typography.screenSubtitle)
                            .foregroundStyle(AppColors.inkTertiary)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.pressWord)
            .accessibilityHint(line.note == nil ? "Adds a note to this win." : "Changes this win's note.")
            if line.note != nil || writing == line.id {
                TextField(WinNote.prompt, text: note(of: line.id),
                          prompt: Text(WinNote.prompt).foregroundStyle(AppColors.inkTertiary), axis: .vertical)
                    .font(Typography.bodyLarge)
                    .foregroundStyle(AppColors.inkSecondary)
                    .lineLimit(1...6)
                    .focused($focused, equals: line.id)
            }
        }
    }

    /// The win's own note, written straight to the win.
    private func note(of id: UUID) -> Binding<String> {
        Binding(get: { logs.first { $0.id == id }?.note ?? "" },
                set: { text in
                    guard let log = logs.first(where: { $0.id == id }) else { return }
                    // Kept as typed while it is being typed; an empty one is none.
                    let kept = text.isEmpty ? nil : String(text.prefix(WinNote.limit))
                    if log.note != kept {
                        log.note = kept
                        try? modelContext.save()
                    }
                })
    }
}
