import SwiftUI
import StoreKit

/// Settings' **Support Some Wins** section: the three tips as plain rows, a
/// name and its price, the way every other Settings row reads. Nothing shows
/// until the App Store answers with prices (no agreement signed, or offline,
/// is the section's one line and no rows), so a row never offers something
/// that cannot be bought.
struct TipJarSection: View {
    @State private var jar = TipJar.shared
    @State private var thanked = false

    var body: some View {
        Section {
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
        } header: {
            FormSectionLabel(TipJar.Copy.section)
        } footer: {
            Text(thanked || jar.hasTipped ? TipJar.Copy.thanks : TipJar.Copy.line)
                .formFooter()
                .contentTransition(.opacity)
        }
        .task {
            if jar.products.isEmpty { await jar.loadProducts() }
            Analytics.shared.signal(.tipJarShown)
        }
    }
}

/// **The one ask** (spec section 5): once, ever, after a strip is developed,
/// from the third strip on. Quiet, at medium height, the three tips and a
/// plain "Not now". Whatever happens here, it is never shown again.
struct TipAskSheet: View {
    @State private var jar = TipJar.shared
    @State private var thanked = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: GridConstants.gapSection) {
            VStack(spacing: GridConstants.gapTight) {
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
                                    try? await Task.sleep(for: .seconds(1.4))
                                    dismiss()
                                }
                            }
                        }
                        .disabled(jar.isPurchasing)
                    }
                }
                Button(TipJar.Copy.notNow) {
                    Analytics.shared.signal(.tipAsk, [.action(.dismissed)])
                    dismiss()
                }
                .font(Typography.bodyLarge)
                .foregroundStyle(AppColors.inkSecondary)
                .frame(minHeight: 44)
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
