import SwiftUI
import SwiftData

// MARK: - Cross-Tab Navigation (Pirolli & Card 1999 — information scent)

private struct SwitchTabKey: EnvironmentKey {
    static let defaultValue: ((StrataTab) -> Void)? = nil
}

extension EnvironmentValues {
    var switchTab: ((StrataTab) -> Void)? {
        get { self[SwitchTabKey.self] }
        set { self[SwitchTabKey.self] = newValue }
    }
}

struct PlanPageView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var allHabits: [Habit]
    @Query private var allLogs: [HabitLog]
    @Query(sort: \PlanFolder.sortOrder) private var folders: [PlanFolder]
    @State private var viewModel = PlanPageViewModel()
    @FocusState private var editingItemID: UUID?
    @State private var activeSectionID: String? = nil
    @State private var hasAppeared = false
    @AppStorage("sectionExpanded") private var sectionExpandedData: Data = Data()
    @State private var sectionExpanded: [String: Bool] = [:]
    @State private var justCreatedID: UUID? = nil
    @State private var pulseTask: Task<Void, Never>? = nil
    @State private var lastExpandTime: Date = .distantPast
    @State private var cachedSections: [PlanSection] = []
    @State private var sectionAddText: [String: String] = [:]
    @State private var subtasksByParent: [UUID: [PlanItem]] = [:]
    @State private var dropTargetSectionID: String? = nil
    @State private var viewMode: PlanViewMode = .routines
    @State private var editingSection: PlanSection? = nil
    @State private var editName: String = ""
    @State private var editIcon: String = ""
    @State private var editColorHex: String = ""
    @AppStorage("smartViewOverrides") private var overridesData: Data = Data()
    @State private var habitToDelete: Habit? = nil
    @State private var sectionToDelete: PlanSection? = nil
    @State private var pendingDeleteHabit: Habit? = nil
    @State private var deleteUndoTask: Task<Void, Never>? = nil
    @State private var rebuildTask: Task<Void, Never>? = nil

    // Performance caches — computed once per data change, not per row (O(1) reads)
    @State private var todayCompletedIDs: Set<UUID> = []
    @State private var todaySkippedIDs: Set<UUID> = []
    @State private var siblingsByDate: [String: [Habit]] = [:]
    @State private var suggestedSlotsByDate: [String: String] = [:]

    @ScaledMetric(relativeTo: .body) private var sectionPadH: CGFloat = 16
    @ScaledMetric(relativeTo: .body) private var sectionPadV: CGFloat = 12
    @ScaledMetric(relativeTo: .footnote) private var snackbarPadH: CGFloat = 16
    @ScaledMetric(relativeTo: .footnote) private var snackbarPadV: CGFloat = 12

    private var gentle: Animation { reduceMotion ? GridConstants.motionReduced : GridConstants.motionGentle }

    var body: some View {
        ScrollViewReader { proxy in
            List {
                // MARK: - GTD Segmented Picker
                Picker("View", selection: $viewMode) {
                    ForEach(PlanViewMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("Plan view mode")
                .accessibilityHint("Switch between Routines and To-Dos")
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))

                // MARK: - Sections with Contextual "+ Add" Rows
                let sections = cachedSections
                if !sections.isEmpty {
                    ForEach(sections) { section in
                        DisclosureGroup(
                            isExpanded: sectionBinding(for: section.id)
                        ) {
                            // Items in section — draggable
                            if section.items.isEmpty && section.isPermanent {
                                Text("Nothing scheduled")
                                    .font(Typography.caption)
                                    .foregroundStyle(.quaternary)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 4)
                                    .listRowSeparator(.hidden)
                            }

                            ForEach(section.items) { item in
                                itemRow(for: item)
                                    .id(item.id)
                                    .draggable(item.id.uuidString)
                            }

                            // Contextual "+ Add to [Section]" row
                            sectionAddRow(for: section)
                        } label: {
                            sectionHeader(for: section)
                        }
                        // Drop target for drag-and-drop between sections
                        .dropDestination(for: String.self) { strings, _ in
                            guard let uuidString = strings.first,
                                  let habitID = UUID(uuidString: uuidString) else { return false }
                            return handleDrop(habitID: habitID, intoSection: section)
                        } isTargeted: { targeted in
                            dropTargetSectionID = targeted ? section.id : nil
                        }
                        .listRowBackground(
                            dropTargetSectionID == section.id
                                ? Color.accentColor.opacity(0.06)
                                : Color.clear
                        )
                        .listRowSeparator(.hidden)
                        .animation(GridConstants.motionSmooth, value: dropTargetSectionID)
                    }

                    // "New Section" button (Routines only — custom folders don't apply to To-Dos)
                    if viewMode == .routines {
                    Button {
                        createNewFolder()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                                .font(.body)
                                .foregroundStyle(.secondary)
                            Text("New Section")
                                .font(Typography.bodySmall)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, sectionPadH)
                        .padding(.vertical, sectionPadV)
                    }
                    .buttonStyle(.plain)
                    .listRowSeparator(.hidden)
                    } // end if viewMode == .routines
                }

                // MARK: - Empty State
                if allHabits.isEmpty {
                    emptyState
                        .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: viewModel.expandedItemID) { _, newID in
                if let newID {
                    withAnimation(gentle) {
                        proxy.scrollTo(newID, anchor: .top)
                    }
                }
            }
        }
        .navigationTitle("Plan")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { withAnimation(GridConstants.toggleSwitch) { viewModel.sortMode = .recent }; HapticsEngine.tick() } label: {
                        Label("Recent First", systemImage: viewModel.sortMode == .recent ? "checkmark" : "")
                    }
                    Button { withAnimation(GridConstants.toggleSwitch) { viewModel.sortMode = .category }; HapticsEngine.tick() } label: {
                        Label("By Category", systemImage: viewModel.sortMode == .category ? "checkmark" : "")
                    }
                    Button { withAnimation(GridConstants.toggleSwitch) { viewModel.sortMode = .oldest }; HapticsEngine.tick() } label: {
                        Label("Oldest First", systemImage: viewModel.sortMode == .oldest ? "checkmark" : "")
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease")
                        .font(.footnote.weight(.medium))
                }
                .buttonStyle(.glassProminent)
            }
        }
        .onAppear {
            if !hasAppeared {
                hasAppeared = true
                // Restore persisted section expansion state
                if let saved = try? JSONDecoder().decode([String: Bool].self, from: sectionExpandedData) {
                    sectionExpanded = saved
                }
                performRebuild() // Direct call on first load — no debounce
            }
        }
        .onChange(of: allHabits.count) { _, _ in
            scheduleRebuild()
        }
        .onChange(of: viewModel.sortMode) { _, _ in
            scheduleRebuild()
        }
        .onChange(of: folders.count) { _, _ in
            scheduleRebuild()
        }
        .onChange(of: viewMode) { _, _ in
            HapticsEngine.tick()
            scheduleRebuild()
        }
        .onChange(of: allLogs.count) { _, _ in
            scheduleRebuild()
        }
        .sheet(item: $editingSection) { section in
            SectionEditSheet(
                sectionID: section.id,
                isPermanent: section.isPermanent,
                name: $editName,
                icon: $editIcon,
                colorHex: $editColorHex,
                onSave: {
                    saveEditedSection(section)
                },
                onReset: section.isPermanent ? {
                    resetSmartViewOverride(sectionID: section.id)
                } : nil
            )
        }
        .confirmationDialog(
            "Delete \"\(habitToDelete?.title ?? "")\"?",
            isPresented: Binding(
                get: { habitToDelete != nil },
                set: { if !$0 { habitToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let habit = habitToDelete {
                    startPendingDelete(habit)
                }
                habitToDelete = nil
            }
            Button("Cancel", role: .cancel) { habitToDelete = nil }
        } message: {
            Text("This will permanently remove this habit and all its steps.")
        }
        .confirmationDialog(
            "Delete this section?",
            isPresented: Binding(
                get: { sectionToDelete != nil },
                set: { if !$0 { sectionToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let section = sectionToDelete { deleteFolder(id: section.folderID) }
                sectionToDelete = nil
            }
            Button("Cancel", role: .cancel) { sectionToDelete = nil }
        } message: {
            Text("Habits in this section will move to Inbox.")
        }
        .overlay(alignment: .bottom) {
            if pendingDeleteHabit != nil {
                HStack {
                    Text("Habit deleted")
                        .font(Typography.bodySmall)
                    Spacer()
                    Button("Undo") {
                        deleteUndoTask?.cancel()
                        withAnimation(gentle) { pendingDeleteHabit = nil }
                        HapticsEngine.lightTap()
                        scheduleRebuild()
                    }
                    .font(Typography.bodySmall)
                    .fontWeight(.semibold)
                }
                .padding(.horizontal, snackbarPadH)
                .padding(.vertical, snackbarPadV)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    // MARK: - Section Header (simplified — editing via SectionEditSheet)

    @ViewBuilder
    private func sectionHeader(for section: PlanSection) -> some View {
        HStack(spacing: 8) {
            Image(systemName: section.icon)
                .foregroundStyle(sectionIconColor(for: section))
            Text(section.title)
                .fontWeight(.semibold)
            Spacer()
            // Today section: show completion progress (Sweller 1988 — reduce cognitive load)
            if section.id == "today" && !section.items.isEmpty {
                let done = section.items.filter { todayCompletedIDs.contains($0.id) }.count
                Text("\(done)/\(section.items.count)")
                    .foregroundStyle(done == section.items.count ? AppColors.healthGreen : Color.secondary)
            } else {
                Text("\(section.items.count)")
                    .foregroundStyle(.tertiary)
            }
        }
        .font(Typography.bodySmall)
        .contextMenu {
            // "Edit Section" — all sections (Apple Reminders "Show List Info" pattern)
            Button {
                HapticsEngine.lightTap()
                openEditSheet(for: section)
            } label: {
                Label("Edit Section", systemImage: "slider.horizontal.3")
            }

            // "Delete Section" — user-created folders only
            if section.isUserCreated {
                Divider()
                Button(role: .destructive) {
                    sectionToDelete = section
                } label: {
                    Label("Delete Section", systemImage: "trash")
                }
            }
        }
    }

    private func sectionIconColor(for section: PlanSection) -> Color {
        if let hex = section.colorHex {
            let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
            guard let value = UInt64(cleaned, radix: 16) else { return .secondary }
            let r = Double((value >> 16) & 0xFF) / 255.0
            let g = Double((value >> 8) & 0xFF) / 255.0
            let b = Double(value & 0xFF) / 255.0
            return Color(red: r, green: g, blue: b)
        }
        return .secondary
    }

    // MARK: - Contextual "+ Add" Row (Apple Reminders Pattern)

    @ViewBuilder
    private func sectionAddRow(for section: PlanSection) -> some View {
        let isActive = activeSectionID == section.id

        if isActive {
            // Active: HighlightingTextField inline with focus bridge
            HStack(spacing: 12) {
                Image(systemName: "plus")
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                HighlightingTextField(
                    text: sectionAddBinding(for: section.id),
                    isFocused: Binding(
                        get: { activeSectionID == section.id },
                        set: { if !$0 { activeSectionID = nil } }
                    ),
                    accentColor: sectionAccentColor(section),
                    placeholder: "Add to \(section.title)...",
                    onSubmit: {
                        commitInSection(section)
                    }
                )
                .frame(minHeight: 24)
            }
            .padding(.horizontal, sectionPadH)
            .padding(.vertical, 8)
            .id("add-\(section.id)")
            .listRowSeparator(.hidden)
        } else {
            // Ghosted: tap to activate
            Button {
                activeSectionID = section.id
                HapticsEngine.lightTap()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.caption)
                    Text("Add to \(section.title)")
                        .font(Typography.caption)
                }
                .foregroundStyle(.tertiary)
                .padding(.horizontal, sectionPadH)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            .listRowSeparator(.hidden)
            .accessibilityLabel("Add habit to \(section.title)")
        }
    }

    // MARK: - Item Row

    @ViewBuilder
    private func itemRow(for item: PlanItem) -> some View {
        let subtasks = subtasksByParent[item.id] ?? []
        // O(1) cache reads — pre-computed in performRebuild()
        let todayStr = TimelineViewModel.dateString(from: Date.now)
        let dateKey = item.habit.isTodo ? (item.habit.scheduledDate ?? todayStr) : todayStr
        let siblings = siblingsByDate[dateKey] ?? []
        let suggestedSlot = suggestedSlotsByDate[dateKey]

        PlanItemRow(
            item: item,
            isExpanded: viewModel.expandedItemID == item.id,
            schedule: item.schedule,
            subtasks: subtasks,
            onTapOptions: {
                guard Date.now.timeIntervalSince(lastExpandTime) > 0.1 else { return }
                lastExpandTime = .now
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                HapticsEngine.lightTap()
                withAnimation(gentle) {
                    viewModel.expandedItemID = viewModel.expandedItemID == item.id ? nil : item.id
                }
            },
            onUpdateTitle: { newTitle in
                viewModel.updateTitle(item.habit, to: newTitle, context: modelContext)
            },
            onDelete: {
                startPendingDelete(item.habit)
            },
            onUpdateCategory: { cat in
                viewModel.updateCategory(item.habit, to: cat, context: modelContext)
            },
            onUpdateSize: { size in
                viewModel.updateSize(item.habit, to: size, context: modelContext)
            },
            onUpdateDays: { days in
                viewModel.updateDays(item.habit, to: days, context: modelContext)
            },
            onUpdateFrequencyPreset: { preset in
                viewModel.applyFrequencyPreset(item.habit, preset: preset, context: modelContext)
            },
            onUpdateTime: { time in
                viewModel.updateTime(item.habit, to: time, context: modelContext)
            },
            onAddSubTask: {
                addSubTask(parentID: item.id)
            },
            onDeleteSubTask: { subtaskHabit in
                viewModel.deleteItem(subtaskHabit, context: modelContext)
            },
            scheduledSiblings: siblings,
            suggestedSlot: suggestedSlot,
            isCompletedToday: todayCompletedIDs.contains(item.id),
            isSkippedToday: todaySkippedIDs.contains(item.id),
            editingItemID: $editingItemID
        )
        // Commitment Pulse
        .background(
            item.id == justCreatedID
                ? item.habit.category.style.baseColor.opacity(0.08)
                : Color.clear,
            in: RoundedRectangle(cornerRadius: GridConstants.cornerRadius, style: .continuous)
        )
        .animation(GridConstants.motionSettle, value: justCreatedID)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets())
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                habitToDelete = item.habit
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Empty State

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                MiniBlockPreview(category: .creativity, blockSize: .small, title: "Sketch")
                    .frame(width: 48, height: 48)
                MiniBlockPreview(category: .health, blockSize: .medium, title: "Exercise")
                    .frame(width: 72, height: 48)
                MiniBlockPreview(category: .focus, blockSize: .hard, title: "Deep Work")
                    .frame(width: 72, height: 72)
            }

            Text("Build your tower")
                .font(Typography.headerMedium)
                .foregroundStyle(.primary)

            Text("Type naturally — times and days are detected automatically")
                .font(Typography.bodyMedium)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            // Starter templates
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    templateButton("Morning Water", category: .health)
                    templateButton("10-min Walk", category: .health)
                }
                HStack(spacing: 8) {
                    templateButton("Read 15 min", category: .focus)
                    templateButton("Evening Reflect", category: .mindfulness)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    // MARK: - Helpers

    private func startPendingDelete(_ habit: Habit) {
        pendingDeleteHabit = habit
        deleteUndoTask?.cancel()
        deleteUndoTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            withAnimation(gentle) {
                if let h = pendingDeleteHabit {
                    viewModel.deleteItem(h, context: modelContext)
                }
                pendingDeleteHabit = nil
            }
            scheduleRebuild()
        }
        HapticsEngine.snap()
        scheduleRebuild()
    }

    private func sectionBinding(for id: String) -> Binding<Bool> {
        Binding(
            get: { sectionExpanded[id] ?? true },
            set: {
                sectionExpanded[id] = $0
                sectionExpandedData = (try? JSONEncoder().encode(sectionExpanded)) ?? Data()
                HapticsEngine.lightTap()
            }
        )
    }

    private func sectionAddBinding(for id: String) -> Binding<String> {
        Binding(
            get: { sectionAddText[id] ?? "" },
            set: { sectionAddText[id] = $0 }
        )
    }

    private func sectionAccentColor(_ section: PlanSection) -> Color {
        // Use health green for task sections, warm accent for habit sections
        switch section.id {
        case "today", "tomorrow", "upcoming", "nodate":
            return AppColors.warmBlack
        default:
            return AppColors.healthGreen
        }
    }

    private func commitInSection(_ section: PlanSection) {
        let text = sectionAddText[section.id] ?? ""
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        HapticsEngine.snap()

        let newID = viewModel.commitInContext(
            title: text,
            sectionID: section.id,
            folderID: section.folderID,
            context: modelContext
        )

        pulseTask?.cancel()
        justCreatedID = newID
        pulseTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            justCreatedID = nil
        }

        sectionAddText[section.id] = ""
        scheduleRebuild()
    }

    // MARK: - Performance: Debounced Rebuild (16ms coalesce)

    private func scheduleRebuild() {
        rebuildTask?.cancel()
        rebuildTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(16))
            guard !Task.isCancelled else { return }
            performRebuild()
        }
    }

    private func performRebuild() {
        let filteredHabits = allHabits.filter { $0.id != pendingDeleteHabit?.id }

        // Sections + subtasks (O(n log n) once)
        cachedSections = viewModel.groupedSections(
            from: filteredHabits,
            folders: folders,
            viewMode: viewMode,
            overrides: smartViewOverrides
        )
        subtasksByParent = Dictionary(
            grouping: allHabits.filter { $0.parentHabitID != nil },
            by: { $0.parentHabitID! }
        ).mapValues { habits in
            habits.sorted { $0.createdAt > $1.createdAt }
                .map { PlanItem(id: $0.id, habit: $0, schedule: viewModel.scheduleDescription(for: $0)) }
        }

        // Completion status — O(n) once, O(1) per row read
        let todayStr = TimelineViewModel.dateString(from: Date.now)
        todayCompletedIDs = Set(allLogs.filter { $0.dateString == todayStr && $0.completed }
            .compactMap { $0.habit?.id })
        todaySkippedIDs = Set(allLogs.filter { $0.dateString == todayStr && $0.skipped }
            .compactMap { $0.habit?.id })

        // Schedule context — siblings + slots, O(n log n) once, O(1) per row
        let scheduled = filteredHabits.filter { $0.scheduledTime != nil && $0.parentHabitID == nil }
        var byDate: [String: [Habit]] = [:]
        for habit in scheduled {
            let dateKey = habit.isTodo ? (habit.scheduledDate ?? todayStr) : todayStr
            byDate[dateKey, default: []].append(habit)
        }
        for (key, habits) in byDate {
            byDate[key] = habits.sorted {
                (TimelineViewModel.effectiveHour(for: $0) ?? 0) < (TimelineViewModel.effectiveHour(for: $1) ?? 0)
            }
        }
        siblingsByDate = byDate

        var slots: [String: String] = [:]
        for (key, siblings) in byDate {
            if let slot = viewModel.findNextOpenSlot(excluding: UUID(), siblings: siblings, duration: 15) {
                slots[key] = slot
            }
        }
        suggestedSlotsByDate = slots
    }

    // MARK: - Smart View Overrides (@AppStorage)

    private var smartViewOverrides: [String: SmartViewOverride] {
        (try? JSONDecoder().decode([String: SmartViewOverride].self, from: overridesData)) ?? [:]
    }

    private func saveSmartViewOverride(sectionID: String, icon: String, colorHex: String) {
        var overrides = smartViewOverrides
        overrides[sectionID] = SmartViewOverride(icon: icon, colorHex: colorHex)
        overridesData = (try? JSONEncoder().encode(overrides)) ?? Data()
        scheduleRebuild()
    }

    private func resetSmartViewOverride(sectionID: String) {
        var overrides = smartViewOverrides
        overrides.removeValue(forKey: sectionID)
        overridesData = (try? JSONEncoder().encode(overrides)) ?? Data()
        scheduleRebuild()
    }

    // MARK: - Section Edit Sheet Flow

    private func openEditSheet(for section: PlanSection) {
        editName = section.title
        editIcon = section.icon
        editColorHex = section.colorHex ?? "#8E8E93"
        editingSection = section
    }

    private func saveEditedSection(_ section: PlanSection) {
        if section.isUserCreated, let folderID = section.folderID {
            // User folder → write to SwiftData
            guard let folder = folders.first(where: { $0.id == folderID }) else { return }
            let trimmed = editName.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty { folder.name = trimmed }
            folder.icon = editIcon
            folder.colorHex = editColorHex
            try? modelContext.save()
        } else if section.isPermanent {
            // Smart View → write to @AppStorage
            saveSmartViewOverride(sectionID: section.id, icon: editIcon, colorHex: editColorHex)
        }
        scheduleRebuild()
    }

    // MARK: - Folder CRUD

    private func createNewFolder() {
        let folder = PlanFolder(name: "New Section", sortOrder: folders.count)
        modelContext.insert(folder)
        try? modelContext.save()
        HapticsEngine.snap()
        sectionExpanded["folder-\(folder.id.uuidString)"] = true
        // Open edit sheet immediately for the new folder
        let newSection = PlanSection(folder: folder, items: [])
        openEditSheet(for: newSection)
        scheduleRebuild()
    }

    private func deleteFolder(id: UUID?) {
        guard let id,
              let folder = folders.first(where: { $0.id == id }) else { return }
        // Move habits to Unassigned — never delete habits
        for habit in folder.habits {
            habit.planFolder = nil
        }
        modelContext.delete(folder)
        try? modelContext.save()
        HapticsEngine.snap()
        scheduleRebuild()
    }

    // MARK: - Drag-and-Drop Handler

    private func handleDrop(habitID: UUID, intoSection section: PlanSection) -> Bool {
        guard let habit = allHabits.first(where: { $0.id == habitID }) else { return false }

        if let folderID = section.folderID {
            // Into user folder
            guard let folder = folders.first(where: { $0.id == folderID }) else { return false }
            habit.planFolder = folder
            habit.isTodo = false
        } else if section.id == "inbox" {
            habit.planFolder = nil
        } else {
            // Into system task section — apply defaults
            let defaults = viewModel.defaultsForSection(section.id)
            habit.isTodo = defaults.isTodo
            habit.frequency = defaults.frequency
            if let date = defaults.scheduledDate { habit.scheduledDate = date }
            habit.planFolder = nil
        }

        try? modelContext.save()
        HapticsEngine.snap()
        scheduleRebuild()
        return true
    }

    private func scheduleSiblings(for habit: Habit) -> [Habit] {
        // Determine which date this habit applies to
        let date: Date
        if habit.isTodo, let dateStr = habit.scheduledDate {
            // Parse the date string
            let parts = dateStr.split(separator: "-")
            if parts.count == 3, let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2]) {
                var comps = DateComponents()
                comps.year = y; comps.month = m; comps.day = d
                date = Calendar.current.date(from: comps) ?? Date.now
            } else {
                date = Date.now
            }
        } else {
            date = Date.now
        }
        return viewModel.scheduledHabitsForDate(date, from: allHabits)
    }

    private func addSubTask(parentID: UUID) {
        let habit = Habit(
            title: "Sub-task",
            category: .health,
            blockSize: .small,
            frequency: DayCode.allCases,
            sortOrder: 0
        )
        habit.parentHabitID = parentID
        modelContext.insert(habit)
        try? modelContext.save()
        HapticsEngine.snap()
        editingItemID = habit.id
        scheduleRebuild()
    }

    private func templateButton(_ title: String, category: HabitCategory) -> some View {
        Button {
            let size = CategorySuggestionEngine.suggestSize(for: title) ?? .small
            let habit = Habit(
                title: title,
                category: category,
                blockSize: size,
                frequency: DayCode.allCases,
                sortOrder: 0
            )
            modelContext.insert(habit)
            try? modelContext.save()
            HapticsEngine.snap()
            scheduleRebuild()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: category.iconName)
                    .font(.caption.weight(.medium))
                Text(title)
                    .font(Typography.bodySmall)
            }
            .foregroundStyle(category.style.baseColor)
            .padding(.horizontal, sectionPadH)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(category.style.baseColor.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}
