import SwiftUI

/// **A rare moment with one of his drawings: one layout for all of them**
/// (the owner, 2026-10-14: "there needs to be consistency the buttons and
/// everything are all over the place"). The store that will not open, a
/// backup that cannot be read, Crews with no iCloud, a crew being joined:
/// each had its own arrangement, the drawing at the top left on some and
/// centred on others, the button under the words on one, at the foot on
/// another, narrow on a third.
///
/// Now: the drawing in the middle of the page, the title and its line
/// centred under it, and the one action, if there is one, the app's
/// primary button at the foot, where every page keeps its action.
struct DrawnMoment<Drawing: View, Extra: View>: View {
    let title: String
    var line: String? = nil
    var action: (title: String, run: () -> Void)? = nil
    @ViewBuilder var drawing: () -> Drawing
    /// Anything the moment says beside its line (a retry that failed, a
    /// spinner for Reduce Motion), under the line.
    @ViewBuilder var extra: () -> Extra

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: GridConstants.gapSection)
            drawing()
                .frame(maxWidth: .infinity)
                .padding(.bottom, GridConstants.gapWide)
            Text(title)
                .font(Typography.headerMedium)
                .foregroundStyle(AppColors.inkPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if let line {
                Text(line)
                    .font(Typography.bodyLarge)
                    .foregroundStyle(AppColors.inkSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, GridConstants.gapTight)
            }
            extra()
                .padding(.top, GridConstants.gapTight)
            Spacer(minLength: GridConstants.gapSection)
            if let action {
                PrimaryCapsule(title: action.title, action: action.run)
            }
        }
        .padding(.horizontal, GridConstants.horizontalPadding)
        .padding(.bottom, GridConstants.gapWide)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
    }
}

extension DrawnMoment where Extra == EmptyView {
    init(title: String, line: String? = nil, action: (title: String, run: () -> Void)? = nil,
         @ViewBuilder drawing: @escaping () -> Drawing) {
        self.init(title: title, line: line, action: action, drawing: drawing, extra: { EmptyView() })
    }
}
