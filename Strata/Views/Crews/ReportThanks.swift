import SwiftUI

/// **"Thanks for telling us", with his thumbs up** (the owner, 2026-10-14:
/// the thumbs up on the rare "it worked" moments, a report among them). An
/// alert cannot hold a drawing, so the three report alerts (a crew, a person
/// in the chat, a win on a crew's day) are this one card.
///
/// **A card over the page, not a sheet**: the places a report is made are
/// sheets and the chat's drawer already, and the owner does not want a sheet
/// opening on top of a sheet (2026-10-14). The card is a tip's materials
/// (`TipCard`): the page's raised ground, a hairline, no shadow, over a light
/// veil that a tap puts away. The same words the alerts had; "Done" as the
/// way out, the word every ending in the app uses; and, where the alert had
/// it, the offer to block.
struct ReportThanks: View {
    var message: String
    /// "Block Sam", and what it does; nil when there is nobody to block.
    var block: (title: String, action: () -> Void)? = nil
    let done: () -> Void

    static let title = "Thanks for telling us"

    var body: some View {
        VStack(spacing: GridConstants.gapItem) {
            ThumbsUp(height: 72)
            VStack(spacing: 2) {
                Text(Self.title)
                    .font(Typography.headerMedium)
                    .foregroundStyle(AppColors.inkPrimary)
                Text(message)
                    .font(Typography.screenSubtitle)
                    .foregroundStyle(AppColors.inkSecondary)
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .combine)
            VStack(spacing: 0) {
                if let block {
                    Button {
                        HapticsEngine.lightTap()
                        block.action()
                        done()
                    } label: {
                        Text(block.title)
                            .font(Typography.headerSmall)
                            .foregroundStyle(AppColors.destructiveInk)
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.pressWord)
                }
                Button {
                    HapticsEngine.lightTap()
                    done()
                } label: {
                    Text("Done")
                        .font(Typography.headerSmall)
                        .foregroundStyle(WarmBackground.top)
                        .padding(.horizontal, GridConstants.gapWide)
                        .frame(height: 34)
                        .background(Capsule(style: .continuous).fill(AppColors.inkPrimary))
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.pressWord)
            }
        }
        .padding(GridConstants.gapWide)
        .frame(maxWidth: 360)
        .background {
            RoundedRectangle(cornerRadius: GridConstants.radiusSurface, style: .continuous)
                .fill(TipCard.ground)
        }
        .overlay {
            RoundedRectangle(cornerRadius: GridConstants.radiusSurface, style: .continuous)
                .strokeBorder(TipCard.hairline, lineWidth: GridConstants.strokeThin)
        }
        .padding(.horizontal, GridConstants.gapSection)
        .accessibilityAddTraits(.isModal)
    }
}

extension View {
    /// The thanks after a report, for whatever was reported: shown while
    /// `item` is set, put away by Done, Block or a tap on the veil.
    func reportThanks<Item>(_ item: Binding<Item?>, message: String,
                            block: @escaping (Item) -> (title: String, action: () -> Void)? = { _ in nil }) -> some View {
        overlay {
            ZStack {
                if let shown = item.wrappedValue {
                    Color.black.opacity(0.18)
                        .ignoresSafeArea()
                        .onTapGesture { item.wrappedValue = nil }
                        .accessibilityHidden(true)
                    ReportThanks(message: message, block: block(shown)) { item.wrappedValue = nil }
                }
            }
            .animation(GridConstants.crossFade, value: item.wrappedValue != nil)
        }
    }

    /// The same, for a report with nobody to block.
    func reportThanks(_ isPresented: Binding<Bool>, message: String) -> some View {
        reportThanks(Binding<Bool?>(get: { isPresented.wrappedValue ? true : nil },
                                    set: { isPresented.wrappedValue = $0 != nil }),
                     message: message)
    }
}
