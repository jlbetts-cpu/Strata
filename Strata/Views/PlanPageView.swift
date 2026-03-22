import SwiftUI
import SwiftData

struct PlanPageView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allHabits: [Habit]
    @State private var viewModel = PlanPageViewModel()
    @FocusState private var isInputFocused: Bool

    var body: some View {
        List {
            // MARK: - Input Row
            HStack(spacing: 12) {
                Circle()
                    .fill(viewModel.suggestedColor)
                    .frame(width: 12, height: 12)
                    .animation(.easeInOut(duration: 0.2), value: viewModel.effectiveCategory)

                TextField("Type a habit or task...", text: $viewModel.newItemText)
                    .font(Typography.bodyLarge)
                    .focused($isInputFocused)
                    .onSubmit {
                        viewModel.commitNewItem(context: modelContext)
                        // Re-focus for next item (like Apple Notes checklist)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            isInputFocused = true
                        }
                    }
            }
            .listRowSeparator(.hidden)

            // MARK: - Existing Items
            ForEach(viewModel.orderedItems(from: allHabits)) { item in
                PlanItemRow(
                    item: item,
                    isExpanded: viewModel.expandedItemID == item.id,
                    schedule: viewModel.scheduleDescription(for: item.habit),
                    onTapOptions: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            viewModel.expandedItemID = viewModel.expandedItemID == item.id ? nil : item.id
                        }
                    },
                    onDelete: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            viewModel.deleteItem(item.habit, context: modelContext)
                        }
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
                    onToggleTodo: {
                        viewModel.toggleTodo(item.habit, context: modelContext)
                    }
                )
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets())
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        viewModel.deleteItem(item.habit, context: modelContext)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }

            // MARK: - Empty State
            if allHabits.isEmpty {
                VStack(spacing: 16) {
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

                    Text("Type above to add your first habit")
                        .font(Typography.bodyMedium)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Habits")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            isInputFocused = true
        }
    }
}
