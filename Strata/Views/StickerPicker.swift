import PhotosUI
import SwiftUI

/// **The day's mark: a sticker of yours, or an emoji** (the owner,
/// 2026-10-06, "From your photos"). Opens from the journal's corner button.
/// Your stickers, newest first; New Sticker lifts one out of a photograph;
/// Emoji opens the keyboard, as the button always did. Choosing the day's
/// own mark again takes it off, as with an emoji.
///
/// **And a sticker for a drawing** (the owner, 2026-10-06: "make it so you
/// can add stickers to doodles when you are drawing them"): the same grid and
/// New Sticker from the ink canvas's row (`InkControls`), without Emoji,
/// because an emoji is the day's mark and not something drawn on.
struct StickerPicker: View {
    /// What a chosen sticker is for: the day's mark, or a drawing.
    enum Purpose { case day, drawing }

    /// The day's symbol as it stands.
    let current: String?
    var purpose: Purpose = .day
    let onPick: (_ symbol: String) -> Void
    /// Emoji, for the day's mark. Nil leaves the button out.
    var onEmoji: (() -> Void)? = nil

    @State private var store = StickerStore.shared
    @State private var choosingPhoto = false
    @State private var item: PhotosPickerItem?
    @State private var making = false
    @State private var failed = false

    private static let tile: CGFloat = 60
    private let columns = Array(repeating: GridItem(.fixed(Self.tile), spacing: GridConstants.gapTight), count: 4)

    var body: some View {
        VStack(alignment: .leading, spacing: GridConstants.gapItem) {
            if store.names.isEmpty, !making {
                Text("Lift a sticker out of one of your photos.")
                    .font(Typography.screenSubtitle)
                    .foregroundStyle(AppColors.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: GridConstants.gapTight) {
                        if making { makingTile }
                        ForEach(store.names, id: \.self) { tile($0) }
                    }
                }
                .frame(maxHeight: Self.tile * 3 + GridConstants.gapTight * 2)
            }
            if failed {
                Text("Couldn't find anything to lift. Try another photo.")
                    .font(Typography.screenSubtitle)
                    .foregroundStyle(AppColors.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                if let onEmoji {
                    Button { onEmoji() } label: {
                        Label("Emoji", systemImage: "face.smiling")
                            .frame(minHeight: GlassIconButton.defaultSide)
                    }
                    Spacer(minLength: GridConstants.gapItem)
                }
                Button {
                    failed = false
                    choosingPhoto = true
                } label: {
                    Label("New Sticker", systemImage: "plus")
                        .frame(minHeight: GlassIconButton.defaultSide)
                }
                .disabled(making)
                if onEmoji == nil { Spacer(minLength: 0) }
            }
            .font(Typography.headerMedium)
            .foregroundStyle(AppColors.inkPrimary)
            .buttonStyle(.pressWord)
        }
        .padding(GridConstants.gapWide)
        .frame(width: Self.tile * 4 + GridConstants.gapTight * 3 + GridConstants.gapWide * 2)
        .photosPicker(isPresented: $choosingPhoto, selection: $item, matching: .images)
        .onChange(of: item) { _, picked in
            guard let picked else { return }
            item = nil
            Task { await make(from: picked) }
        }
    }

    private func tile(_ name: String) -> some View {
        let symbol = StickerStore.symbol(for: name)
        return Button {
            HapticsEngine.lightTap()
            onPick(symbol)
        } label: {
            ZStack {
                if symbol == current {
                    Circle().fill(AppColors.inkPrimary.opacity(0.08))
                }
                if let image = store.image(name) {
                    Image(uiImage: image).resizable().scaledToFit().padding(6)
                }
            }
            .frame(width: Self.tile, height: Self.tile)
            .contentShape(Rectangle())
        }
        .buttonStyle(.press)
        .contextMenu {
            Button("Delete Sticker", systemImage: "trash", role: .destructive) { store.remove(name) }
        }
        .accessibilityLabel(symbol == current ? "Sticker, chosen" : "Sticker")
        .accessibilityHint(purpose == .drawing ? "Puts it on the drawing"
                           : symbol == current ? "Takes it off the day" : "Puts it on the day")
    }

    private var makingTile: some View {
        ProgressView()
            .frame(width: Self.tile, height: Self.tile)
            .accessibilityLabel("Making a sticker")
    }

    private func make(from picked: PhotosPickerItem) async {
        making = true
        defer { making = false }
        guard let data = try? await picked.loadTransferable(type: Data.self),
              let photo = UIImage(data: data),
              let sticker = await StickerMaker.lift(photo),
              let name = store.add(sticker) else {
            HapticsEngine.warning()
            failed = true
            return
        }
        HapticsEngine.success()
        onPick(StickerStore.symbol(for: name))
    }
}
