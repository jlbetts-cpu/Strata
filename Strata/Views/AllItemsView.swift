import SwiftUI
import SwiftData

struct AllItemsView: View {
    var tower: Tower?
    var prefillTime: String? = nil
    var onDismiss: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var allHabits: [Habit]
    @State private var viewModel = AllItemsViewModel()

    private let categories = HabitCategory.allCases

    var body: some View {
        NavigationStack {
            List {
                // MARK: - Quick Add
                quickAddSection

                // MARK: - Habits
                let habits = viewModel.filteredHabits(from: allHabits)
                if !habits.isEmpty {
                    Section {
                        ForEach(habits, id: \.id) { habit in
                            HabitItemRow(
                                habit: habit,
                                schedule: viewModel.scheduleDescription(for: habit)
                            )
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                            .onTapGesture { viewModel.editingHabit = habit }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    deleteHabit(habit)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                Button {
                                    viewModel.editingHabit = habit
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(habit.category.style.baseColor)
                            }
                        }
                    } header: {
                        Text("Habits")
                            .font(Typography.headerSmall)
                            .foregroundStyle(.secondary)
                            .textCase(nil)
                    }
                }

                // MARK: - Tasks
                let tasks = viewModel.filteredTasks(from: allHabits)
                if !tasks.isEmpty {
                    Section {
                        ForEach(tasks, id: \.id) { task in
                            TaskItemRow(
                                habit: task,
                                dateLabel: viewModel.scheduleDescription(for: task),
                                isOverdue: viewModel.isOverdue(task)
                            )
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                            .onTapGesture { viewModel.editingHabit = task }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    deleteHabit(task)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                Button {
                                    viewModel.editingHabit = task
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(task.category.style.baseColor)
                            }
                        }
                    } header: {
                        Text("Tasks")
                            .font(Typography.headerSmall)
                            .foregroundStyle(.secondary)
                            .textCase(nil)
                    }
                }

                // MARK: - Empty State
                if habits.isEmpty && tasks.isEmpty {
                    Section {
                        emptyState
                            .listRowSeparator(.hidden)
                    }
                }
            }
            .listStyle(.plain)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Habits & Tasks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { onDismiss() }
                        .font(Typography.bodyLarge)
                }
            }
            .sheet(item: $viewModel.editingHabit) { habit in
                HabitEditView(
                    habit: habit,
                    allHabits: allHabits,
                    onDelete: { deleteHabit(habit) }
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .onAppear {
                if let prefill = prefillTime {
                    viewModel.quickAddUseTime = true
                    let parts = prefill.split(separator: ":")
                    if let h = Int(parts.first ?? ""), let m = Int(parts.last ?? "") {
                        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
                        comps.hour = h
                        comps.minute = m
                        if let date = Calendar.current.date(from: comps) {
                            viewModel.quickAddTime = date
                        }
                    }
                }
            }
        }
    }

    // MARK: - Quick Add Section

    @ViewBuilder
    private var quickAddSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                // Input row
                HStack(spacing: 12) {
                    // Category dot (12pt, smooth color transition)
                    Circle()
                        .fill(viewModel.effectiveCategory.style.baseColor)
                        .frame(width: 12, height: 12)
                        .animation(.easeInOut(duration: 0.2), value: viewModel.effectiveCategory)

                    // TextField with subtle container
                    TextField(
                        "What do you want to build?",
                        text: $viewModel.quickAddTitle
                    )
                    .font(Typography.bodyLarge)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        Color.primary.opacity(0.04),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
                    .onSubmit { submitQuickAdd() }

                    // Mini block preview (32pt, signature moment)
                    if !viewModel.quickAddTitle.trimmingCharacters(in: .whitespaces).isEmpty {
                        MiniBlockPreview(
                            category: viewModel.effectiveCategory,
                            blockSize: viewModel.effectiveSize,
                            title: viewModel.quickAddTitle
                        )
                        .frame(width: 32, height: 32)
                        .transition(.scale.combined(with: .opacity))

                        // Submit button
                        Button { submitQuickAdd() } label: {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(viewModel.effectiveCategory.style.baseColor)
                        }
                        .buttonStyle(.plain)
                        .transition(.scale.combined(with: .opacity))
                        .accessibilityLabel("Add habit")
                    }

                    // Expand toggle (chevron, rotates)
                    Button {
                        // Dismiss keyboard before expanding
                        UIApplication.shared.sendAction(
                            #selector(UIResponder.resignFirstResponder),
                            to: nil, from: nil, for: nil
                        )
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            viewModel.isDetailsExpanded.toggle()
                        }
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                            .rotationEffect(.degrees(viewModel.isDetailsExpanded ? 180 : 0))
                            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: viewModel.isDetailsExpanded)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(viewModel.isDetailsExpanded ? "Collapse options" : "More options")
                }
                .animation(.spring(response: 0.35, dampingFraction: 0.85), value: viewModel.quickAddTitle)

                // Expanded details
                if viewModel.isDetailsExpanded {
                    expandedDetails
                        .transition(.opacity)
                }
            }
            .listRowSeparator(.hidden)
        }
    }

    // MARK: - Expanded Details

    @ViewBuilder
    private var expandedDetails: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Type toggle
            HStack(spacing: 0) {
                togglePill("Recurring", selected: !viewModel.quickAddIsTask) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        viewModel.quickAddIsTask = false
                    }
                }
                togglePill("One-Time", selected: viewModel.quickAddIsTask) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        viewModel.quickAddIsTask = true
                    }
                }
            }
            .padding(6)
            .background(Color.primary.opacity(0.06), in: .capsule)

            // Effort picker + Block preview
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Effort")
                        .font(Typography.bodySmall)
                        .foregroundStyle(.secondary)

                    VStack(spacing: 8) {
                        effortPill("Easy", detail: "1x1 · 15m", size: .small)
                        effortPill("Medium", detail: "2x1 · 30m", size: .medium)
                        effortPill("Hard", detail: "2x2 · 60m", size: .hard)
                    }
                }

                MiniBlockPreview(
                    category: viewModel.effectiveCategory,
                    blockSize: viewModel.effectiveSize,
                    title: viewModel.quickAddTitle.isEmpty ? "Preview" : viewModel.quickAddTitle
                )
                .frame(width: 80, height: 80)
                .animation(.spring(response: 0.35, dampingFraction: 0.85), value: viewModel.effectiveSize)
                .animation(.spring(response: 0.35, dampingFraction: 0.85), value: viewModel.effectiveCategory)
            }

            // Category picker with icons
            VStack(alignment: .leading, spacing: 8) {
                Text("Category")
                    .font(Typography.bodySmall)
                    .foregroundStyle(.secondary)

                HStack(spacing: 4) {
                    ForEach(categories, id: \.self) { cat in
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                viewModel.quickAddCategory = cat
                            }
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(cat.style.baseColor)
                                    .frame(width: 36, height: 36)
                                Image(systemName: cat.iconName)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.9))
                            }
                            .overlay(
                                Circle()
                                    .stroke(Color.primary, lineWidth: viewModel.effectiveCategory == cat ? 2.5 : 0)
                                    .frame(width: 40, height: 40)
                            )
                        }
                        .buttonStyle(.plain)
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                        .accessibilityLabel(cat.rawValue)
                        .accessibilityAddTraits(viewModel.effectiveCategory == cat ? .isSelected : [])
                    }
                }
            }

            // Schedule
            if viewModel.quickAddIsTask {
                DatePicker("Date", selection: $viewModel.quickAddScheduledDate, displayedComponents: .date)
                    .font(Typography.bodyMedium)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Days")
                        .font(Typography.bodySmall)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 0) {
                        ForEach(DayCode.allCases, id: \.self) { day in
                            let isSelected = viewModel.quickAddDays.contains(day)
                            Button {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    if isSelected {
                                        viewModel.quickAddDays.remove(day)
                                    } else {
                                        viewModel.quickAddDays.insert(day)
                                    }
                                }
                            } label: {
                                Text(day.rawValue)
                                    .font(Typography.bodySmall)
                                    .foregroundStyle(isSelected ? .white : Color.primary)
                                    .frame(width: 32, height: 32)
                                    .background(
                                        isSelected ? viewModel.effectiveCategory.style.baseColor : Color.primary.opacity(0.06),
                                        in: Circle()
                                    )
                            }
                            .buttonStyle(.plain)
                            .frame(width: 44, height: 44)
                            .contentShape(Circle())
                            .accessibilityLabel(day.rawValue)
                            .accessibilityAddTraits(isSelected ? .isSelected : [])
                        }
                    }
                }
            }

            // Time picker
            Toggle(isOn: $viewModel.quickAddUseTime) {
                Text("Set time")
                    .font(Typography.bodyMedium)
            }
            .tint(viewModel.effectiveCategory.style.baseColor)

            if viewModel.quickAddUseTime {
                DatePicker("Time", selection: $viewModel.quickAddTime, displayedComponents: .hourAndMinute)
                    .font(Typography.bodyMedium)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            // Create button
            Button { submitQuickAdd() } label: {
                Text("Add to Tower")
                    .font(Typography.blockTitle)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        viewModel.effectiveCategory.style.baseColor,
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
            }
            .disabled(viewModel.quickAddTitle.trimmingCharacters(in: .whitespaces).isEmpty)
            .opacity(viewModel.quickAddTitle.trimmingCharacters(in: .whitespaces).isEmpty ? 0.4 : 1)
            .saturation(viewModel.quickAddTitle.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
            .animation(.easeInOut(duration: 0.2), value: viewModel.quickAddTitle.trimmingCharacters(in: .whitespaces).isEmpty)

            // Reassurance copy (shame-free design)
            Text("You can always change this later")
                .font(Typography.caption)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity)
        }
        .padding(.top, 8)
    }

    // MARK: - Empty State

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 16) {
            VStack(spacing: 4) {
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

            Text("Add habits to start stacking blocks")
                .font(Typography.bodyMedium)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    // MARK: - Sub-views

    private func togglePill(_ label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Text(label)
            .font(Typography.bodySmall)
            .foregroundStyle(selected ? .white : Color.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(selected ? viewModel.effectiveCategory.style.baseColor : .clear, in: .capsule)
            .onTapGesture { action() }
    }

    private func effortPill(_ label: String, detail: String, size: BlockSize) -> some View {
        let isSelected = viewModel.effectiveSize == size
        return HStack(spacing: 6) {
            Text(label)
                .font(Typography.bodySmall)
                .fontWeight(isSelected ? .semibold : .regular)
            Text(detail)
                .font(Typography.caption)
        }
        .foregroundStyle(isSelected ? .white : Color.primary)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            isSelected ? viewModel.effectiveCategory.style.baseColor : Color.primary.opacity(0.06),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.15)) {
                viewModel.quickAddBlockSize = size
            }
        }
    }

    // MARK: - Actions

    private func submitQuickAdd() {
        viewModel.commitQuickAdd(context: modelContext, tower: tower)
        HapticsEngine.snap()
        // Dismiss keyboard so user sees their new habit in the list
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil, from: nil, for: nil
        )
    }

    private func deleteHabit(_ habit: Habit) {
        for log in habit.logs {
            if let fileName = log.imageFileName {
                ImageManager.shared.deleteImage(fileName: fileName)
            }
        }
        modelContext.delete(habit)
        try? modelContext.save()
    }
}
