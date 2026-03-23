import SwiftUI

/// Premium section editing sheet (Apple Reminders "Show List Info" pattern).
/// Research: Accot-Zhai Steering Law — flat grid beats nested submenus.
/// Shneiderman Direct Manipulation — live preview fulfills continuous representation.
/// Fitts' Law — 44pt+ grid targets reduce acquisition time.
struct SectionEditSheet: View {
    let sectionID: String
    let isPermanent: Bool
    @Binding var name: String
    @Binding var icon: String
    @Binding var colorHex: String
    let onSave: () -> Void
    var onReset: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

    @ScaledMetric(relativeTo: .body) private var gridIconSize: CGFloat = 44

    private let iconOptions = [
        "star.fill", "sunrise.fill", "moon.fill", "sun.max.fill",
        "bolt.fill", "flame.fill", "heart.fill", "leaf.fill",
        "book.fill", "graduationcap.fill", "dumbbell.fill", "figure.run",
        "paintbrush.fill", "music.note", "gamecontroller.fill", "house.fill",
        "briefcase.fill", "cup.and.saucer.fill", "brain.head.profile", "tray.and.arrow.down.fill"
    ]

    private let colorOptions: [(name: String, hex: String)] = [
        ("Gray", "#8E8E93"), ("Red", "#FF3B30"), ("Orange", "#FF9500"),
        ("Yellow", "#FFCC00"), ("Green", "#34C759"), ("Teal", "#5AC8FA"),
        ("Blue", "#007AFF"), ("Indigo", "#5856D6"), ("Purple", "#AF52DE"),
        ("Pink", "#FF2D55")
    ]

    private var resolvedColor: Color {
        let hex = colorHex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard let value = UInt64(hex, radix: 16) else { return .secondary }
        let r = Double((value >> 16) & 0xFF) / 255.0
        let g = Double((value >> 8) & 0xFF) / 255.0
        let b = Double(value & 0xFF) / 255.0
        return Color(red: r, green: g, blue: b)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // MARK: - Live Preview Header (Shneiderman: continuous representation)
                    HStack(spacing: 10) {
                        Image(systemName: icon)
                            .font(.title2.weight(.medium))
                            .foregroundStyle(resolvedColor)
                        Text(name.isEmpty ? "Section" : name)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.primary)
                    }
                    .padding(.top, 8)

                    // MARK: - Name Field
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Name")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                        TextField("Section name", text: $name)
                            .font(.body)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .disabled(isPermanent)
                            .opacity(isPermanent ? 0.5 : 1.0)
                    }

                    // MARK: - Icon Picker (Fitts' Law: 44pt+ targets)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Icon")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: gridIconSize))], spacing: 12) {
                            ForEach(iconOptions, id: \.self) { option in
                                Button {
                                    icon = option
                                    HapticsEngine.tick()
                                } label: {
                                    Image(systemName: option)
                                        .font(.body.weight(.medium))
                                        .foregroundStyle(icon == option ? .white : .primary)
                                        .frame(width: gridIconSize, height: gridIconSize)
                                        .background(
                                            icon == option ? resolvedColor : Color.primary.opacity(0.06),
                                            in: Circle()
                                        )
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(option)
                            }
                        }
                    }

                    // MARK: - Color Picker (Pre-attentive Processing: <200ms color search)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Color")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 12) {
                            ForEach(colorOptions, id: \.hex) { option in
                                let optionColor = resolveHex(option.hex)
                                Button {
                                    colorHex = option.hex
                                    HapticsEngine.tick()
                                } label: {
                                    ZStack {
                                        Circle()
                                            .fill(optionColor)
                                            .frame(width: 36, height: 36)
                                        if colorHex == option.hex {
                                            Image(systemName: "checkmark")
                                                .font(.caption.weight(.bold))
                                                .foregroundStyle(.white)
                                        }
                                    }
                                    .frame(width: 44, height: 44)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(option.name)
                            }
                        }
                    }

                    // MARK: - Reset to Default (permanent sections only)
                    if isPermanent, let onReset {
                        Button {
                            onReset()
                            HapticsEngine.lightTap()
                        } label: {
                            Text("Reset to Default")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 4)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .navigationTitle(isPermanent ? "Customize View" : "Edit Section")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        onSave()
                        HapticsEngine.snap()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func resolveHex(_ hex: String) -> Color {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard let value = UInt64(cleaned, radix: 16) else { return .secondary }
        let r = Double((value >> 16) & 0xFF) / 255.0
        let g = Double((value >> 8) & 0xFF) / 255.0
        let b = Double(value & 0xFF) / 255.0
        return Color(red: r, green: g, blue: b)
    }
}
