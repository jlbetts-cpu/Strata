import SwiftUI
import SwiftData

struct NewHabitMenu: View {
    @Binding var isPresented: Bool
    let modelContext: ModelContext
    let onCreated: () -> Void
    var prefillTime: String? = nil

    @State private var isOneTime = false
    @State private var title = ""
    @State private var selectedCategory: HabitCategory = .health
    @State private var selectedSize: BlockSize = .small
    @State private var selectedDays: Set<DayCode> = Set(DayCode.allCases)
    @State private var scheduledDate = Date()
    @State private var useTimePicker = false
    @State private var scheduledTime = Date()
    @Environment(\.colorScheme) private var colorScheme

    private let categories = HabitCategory.allCases

    var body: some View {
        ScrollView {
        VStack(alignment: .leading, spacing: 16) {
            // Toggle: One-Time Task / Recurring Habit
            HStack(spacing: 0) {
                togglePill("Recurring", selected: !isOneTime) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { isOneTime = false }
                }
                togglePill("One-Time", selected: isOneTime) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { isOneTime = true }
                }
            }
            .padding(3)
            .background(Color.primary.opacity(0.06), in: .capsule)

            // Title
            TextField("Habit name", text: $title)
                .font(Typography.bodyLarge)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            // Category colors
            VStack(alignment: .leading, spacing: 6) {
                Text("Category")
                    .font(Typography.bodySmall)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    ForEach(categories, id: \.self) { cat in
                        Circle()
                            .fill(cat.style.baseColor)
                            .frame(width: 32, height: 32)
                            .overlay(
                                Circle()
                                    .stroke(Color.primary, lineWidth: selectedCategory == cat ? 2.5 : 0)
                                    .frame(width: 38, height: 38)
                            )
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.15)) { selectedCategory = cat }
                            }
                    }
                }
            }

            // Duration pills
            VStack(alignment: .leading, spacing: 6) {
                Text("Duration")
                    .font(Typography.bodySmall)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    durationPill("15 min", size: .small)
                    durationPill("30 min", size: .medium)
                    durationPill("60 min", size: .hard)
                }
            }

            // Schedule
            if isOneTime {
                DatePicker("Date", selection: $scheduledDate, displayedComponents: .date)
                    .font(Typography.bodyMedium)
            } else {
                // Day-of-week picker
                VStack(alignment: .leading, spacing: 6) {
                    Text("Days")
                        .font(Typography.bodySmall)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 6) {
                        ForEach(DayCode.allCases, id: \.self) { day in
                            let isSelected = selectedDays.contains(day)
                            Text(day.rawValue)
                                .font(Typography.bodySmall)
                                .foregroundStyle(isSelected ? .white : Color.primary)
                                .frame(width: 34, height: 34)
                                .background(
                                    isSelected ? selectedCategory.style.baseColor : Color.primary.opacity(0.06),
                                    in: Circle()
                                )
                                .onTapGesture {
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        if isSelected {
                                            selectedDays.remove(day)
                                        } else {
                                            selectedDays.insert(day)
                                        }
                                    }
                                }
                        }
                    }
                }
            }

            // Optional time picker
            Toggle(isOn: $useTimePicker) {
                Text("Set time")
                    .font(Typography.bodyMedium)
            }
            .tint(selectedCategory.style.baseColor)

            if useTimePicker {
                DatePicker("Time", selection: $scheduledTime, displayedComponents: .hourAndMinute)
                    .font(Typography.bodyMedium)
            }

            // Create button
            Button {
                createHabit()
            } label: {
                Text("Create")
                    .font(Typography.blockTitle)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        selectedCategory.style.baseColor,
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
            }
            .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
            .opacity(title.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
        }
        .padding(20)
        }
        .onAppear {
            if let prefill = prefillTime {
                useTimePicker = true
                let parts = prefill.split(separator: ":")
                if let h = Int(parts.first ?? ""), let m = Int(parts.last ?? "") {
                    var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
                    comps.hour = h
                    comps.minute = m
                    if let date = Calendar.current.date(from: comps) {
                        scheduledTime = date
                    }
                }
            }
        }
    }

    // MARK: - Sub-views

    private func togglePill(_ label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Text(label)
            .font(Typography.bodySmall)
            .foregroundStyle(selected ? .white : Color.primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(selected ? selectedCategory.style.baseColor : .clear, in: .capsule)
            .onTapGesture { action() }
    }

    private func durationPill(_ label: String, size: BlockSize) -> some View {
        let isSelected = selectedSize == size
        return Text(label)
            .font(Typography.bodySmall)
            .foregroundStyle(isSelected ? .white : Color.primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                isSelected ? selectedCategory.style.baseColor : Color.primary.opacity(0.06),
                in: .capsule
            )
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.15)) { selectedSize = size }
            }
    }

    // MARK: - Create

    private func createHabit() {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        var timeStr: String? = nil
        if useTimePicker {
            let cal = Calendar.current
            let h = cal.component(.hour, from: scheduledTime)
            let m = cal.component(.minute, from: scheduledTime)
            timeStr = String(format: "%02d:%02d", h, m)
        }

        let habit = Habit(
            title: trimmed,
            category: selectedCategory,
            blockSize: selectedSize,
            frequency: isOneTime ? [] : Array(selectedDays),
            scheduledTime: timeStr,
            isTodo: isOneTime,
            scheduledDate: isOneTime ? TimelineViewModel.dateString(from: scheduledDate) : nil
        )

        modelContext.insert(habit)
        try? modelContext.save()

        HapticsEngine.snap()
        onCreated()

        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isPresented = false
        }
    }
}
