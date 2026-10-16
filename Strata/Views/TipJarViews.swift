import SwiftUI
import StoreKit

/// Settings' **Support Some Wins** section: the three tips as plain rows, a
/// name and its price, the way every other Settings row reads. Nothing shows
/// until the App Store answers with prices (no agreement signed, or offline,
/// is the section's one line and no rows), so a row never offers something
/// that cannot be bought.
struct TipJarSection: View {
    @State private var jar = TipJar.shared
    @State private var thanked = TipJarDebug.thanked

    var body: some View {
        // **Only with something to offer.** Before prices load (no agreement
        // signed yet, or offline) a heading and a sentence with nothing to
        // press is a sign on an empty shelf. `TipJar.start` loads them at
        // launch, so by the time Settings is open they are usually here.
        if !jar.products.isEmpty || thanked || jar.hasTipped {
            section
        }
    }

    /// Whether there is anything to show. Asked by Settings BEFORE it puts the
    /// section in its list (2026-10-08): an empty body still took a section's
    /// spacing, which measured as a blank band above Support.
    static var hasSomethingToShow: Bool {
        !TipJar.shared.products.isEmpty || TipJar.shared.hasTipped
    }

    private var section: some View {
        Section {
            FormSectionLabel(TipJar.Copy.section)
            ForEach(jar.products, id: \.id) { product in
                Button {
                    Task {
                        if await jar.tip(product) {
                            HapticsEngine.success()
                            withAnimation(GridConstants.crossFade) { thanked = true }
                        }
                    }
                } label: {
                    HStack {
                        Text(product.displayName.isEmpty ? TipJar.name(of: product.id) : product.displayName)
                            .foregroundStyle(AppColors.inkPrimary)
                        Spacer()
                        Text(product.displayPrice)
                            .foregroundStyle(AppColors.inkSecondary)
                            .monospacedDigit()
                    }
                }
                .disabled(jar.isPurchasing)
                .accessibilityLabel("\(TipJar.name(of: product.id)), \(product.displayPrice)")
            }
        } footer: {
            VStack(alignment: .leading, spacing: GridConstants.gapTight) {
                // His thumbs up over the thanks, the moment a tip goes
                // through (the owner, 2026-10-14). Only then: a tip from
                // another day is thanked in words alone.
                if thanked { ThumbsUp(height: 72) }
                Text(thanked || jar.hasTipped ? TipJar.Copy.thanks : TipJar.Copy.line)
                    .formFooter()
                    .contentTransition(.opacity)
            }
        }
        .task {
            if jar.products.isEmpty { await jar.loadProducts() }
            Analytics.shared.signal(.tipJarShown)
        }
    }
}

/// **The one ask** (spec section 5): once, ever, after a strip is developed,
/// from the third strip on. Quiet, at medium height, the three tips and a
/// plain "Not Now". Whatever happens here, it is never shown again.
struct TipAskSheet: View {
    @State private var jar = TipJar.shared
    @State private var thanked = TipJarDebug.thanked
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: GridConstants.gapSection) {
            VStack(spacing: GridConstants.gapTight) {
                // His thumbs up over the thanks (the owner, 2026-10-14).
                if thanked { ThumbsUp().padding(.bottom, GridConstants.gapTight) }
                Text(thanked ? TipJar.Copy.thanks : TipJar.Copy.askTitle)
                    .font(Typography.headerMedium)
                    .foregroundStyle(AppColors.inkPrimary)
                    .contentTransition(.opacity)
                if !thanked {
                    Text(TipJar.Copy.askLine)
                        .font(Typography.bodyLarge)
                        .foregroundStyle(AppColors.inkSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if !thanked {
                VStack(spacing: GridConstants.gapItem) {
                    ForEach(jar.products, id: \.id) { product in
                        PrimaryCapsule(outlined: "\(TipJar.name(of: product.id))  \(product.displayPrice)") {
                            Task {
                                if await jar.tip(product) {
                                    HapticsEngine.success()
                                    Analytics.shared.signal(.tipAsk, [.action(.tipped)])
                                    withAnimation(GridConstants.crossFade) { thanked = true }
                                    // Long enough for the thumbs up to play and be seen.
                                    try? await Task.sleep(for: .seconds(1.8))
                                    dismiss()
                                }
                            }
                        }
                        .disabled(jar.isPurchasing)
                    }
                }
                QuietWord(TipJar.Copy.notNow) {
                    Analytics.shared.signal(.tipAsk, [.action(.dismissed)])
                    dismiss()
                }
            }
        }
        .padding(.horizontal, GridConstants.gapWide)
        .padding(.vertical, GridConstants.gapSection)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(WarmBackground().ignoresSafeArea())
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .task {
            if jar.products.isEmpty { await jar.loadProducts() }
            // No prices, nothing to offer: the ask closes rather than asking
            // for something that cannot be bought, and is kept for later.
            guard !jar.products.isEmpty else { dismiss(); return }
            jar.markAsked()
            Analytics.shared.signal(.tipAsk, [.action(.shown)])
        }
    }
}

/// `-strataTipThanked`: the thanks after a tip, held, for photographs.
enum TipJarDebug {
    static var thanked: Bool {
        #if DEBUG
        DebugHarness.argument("-strataTipThanked") != nil
        #else
        false
        #endif
    }
}
