import AVFoundation
import Observation
import SwiftUI

/// **Making a head is a must, with a way through when it cannot be done**
/// (the owner, 2026-10-14: "make the head making a must"). The calls he took
/// from `docs/heads-as-identity-2026-10-14.md` §5:
///
/// 1. No skip on the head page as first seen. A quiet Later appears only once
///    the camera is refused or unavailable, or making one failed, so nobody
///    (an App Review reviewer with the camera denied, guideline 5.1.1(iv),
///    included) is stuck on step 4.
/// 2. A photo you choose is a second way to make one (`HeadFromPhoto`).
/// 3. Somebody who finished onboarding before this sees one page over Wins,
///    once, with the maker and Later. After that the standing asks are the
///    crew's Make Your Head pill and a press on your own blank head.
@MainActor
@Observable
final class HeadAsk {
    static let shared = HeadAsk()

    /// The maker reached "camera refused", "no camera" or "could not make
    /// one" this launch. Not kept across launches: a later try may work.
    private(set) var hadTrouble = false
    /// Something on Wins asked for the maker (a press on your blank head in
    /// the crest); `HeadCatchUpPrompt` presents it and clears this.
    var makerAsked = false

    func noteTrouble() { hadTrouble = true }

    /// Asks Wins to open the maker.
    func askForMaker() { makerAsked = true }

    /// **Whether Later is offered.** After trouble, or when the camera can
    /// already be known not to work: refused or restricted, or no front lens
    /// at all (the simulator). A camera not yet asked about is tried first.
    var offersLater: Bool { hadTrouble || Self.cameraBlocked }

    static var cameraBlocked: Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .denied || status == .restricted { return true }
        return AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) == nil
    }

    // MARK: - The page over Wins, once

    /// Set when the page has been shown, and when onboarding's head page was
    /// passed either way, so somebody new never sees it after making a head
    /// or choosing Later there.
    static let catchUpShownKey = "heads.catchUpShown"

    /// Once, and only to somebody with no head.
    nonisolated static func showsCatchUp(alreadyShown: Bool, hasHead: Bool) -> Bool {
        !alreadyShown && !hasHead
    }

    static func markCatchUpShown(_ defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: catchUpShownKey)
    }

    // MARK: - Words

    /// Held to `docs/voice.md`: spare, no exclamation marks, no long dashes,
    /// and nothing about the camera that reads as watching (never scan,
    /// detect, recognise, track, analyse, watch or face data).
    enum Copy {
        // Not "how your crews see you" (2026-10-14: the voice test caught
        // it; nothing about a face may read as being looked at).
        static let pageLine = "It's you, in every crew. About fifteen seconds with the front camera."
        static let pageMade = "That's you, on your wins and in your crews."
        static let usePhoto = "Use a Photo"
        static let later = "Later"
        static let cameraOff = "Turn the camera on for Some Wins in Settings, or use a photo of you."
        static let noCamera = "The camera isn't available here. Use a photo of you instead."
        static let photoFailed = "That one didn't make a head. Try a photo of just you, close up."
        static let catchUpTitle = "Make your head"
        static let catchUpLine = "Your crews see this until you make yours. About fifteen seconds with the front camera."
        static let makeMyHead = "Make My Head"
        static let profileFooter = "About fifteen seconds with the front camera, or one photo of you."
    }
}

/// **The one-time page over Wins** for somebody who has used the app without
/// a head (decision 3 of the owner's 2026-10-14 calls). Your blank head, one
/// sentence, Make My Head, and Later. Built from the app's own pieces: the
/// crew rules page's layout, `PrimaryCapsule`, `QuietWord`.
struct HeadCatchUpPage: View {
    var onDone: () -> Void

    @State private var making = false
    @Environment(\.headsAwake) private var coveringHeadsAwake

    private static let headSide: CGFloat = 140

    var body: some View {
        VStack(spacing: GridConstants.gapWide) {
            Spacer(minLength: 0)
            PersonHead(person: .me, side: Self.headSide, setting: .free)
            Text(HeadAsk.Copy.catchUpTitle)
                .font(Typography.screenTitle)
                .foregroundStyle(AppColors.inkPrimary)
                .multilineTextAlignment(.center)
            Text(HeadAsk.Copy.catchUpLine)
                .font(Typography.bodyLarge)
                .foregroundStyle(AppColors.inkSecondary)
                .multilineTextAlignment(.center)
            // **A head you made before, instead of a new one** (the owner,
            // 2026-10-14: "I deleted it to try the new feature I feel like the
            // app should save your previous three heads to go off of"). Taken,
            // it is yours and the page has done its job; its Undo waits on
            // Wins, under this page.
            if !HeadStore.shared.earlierEntries.isEmpty {
                VStack(spacing: GridConstants.gapTight) {
                    Text(EarlierHeads.instead)
                        .font(Typography.screenSubtitle)
                        .foregroundStyle(AppColors.inkSecondary)
                    EarlierHeadsRow(entries: HeadStore.shared.earlierEntries, alignment: .center) { id in
                        EarlierHeads.bringBack(id)
                        onDone()
                    }
                }
                .padding(.top, GridConstants.gapItem)
            }
            Spacer(minLength: 0)
            VStack(spacing: GridConstants.gapTight) {
                PrimaryCapsule(title: HeadAsk.Copy.makeMyHead) { making = true }
                QuietWord(HeadAsk.Copy.later, fills: true) { onDone() }
            }
        }
        .padding(.horizontal, GridConstants.horizontalPadding)
        .padding(.bottom, GridConstants.gapWide)
        .background(WarmBackground().ignoresSafeArea())
        // The page's head sleeps under the maker (CLAUDE.md: a head sleeps
        // when it cannot be seen). Before the cover, so the maker's own
        // preview head stays awake.
        .environment(\.headsAwake, coveringHeadsAwake && !making)
        .fullScreenCover(isPresented: $making, onDismiss: {
            // A made head is the answer; closing without one leaves the page
            // up, where Later is one press away.
            if HeadStore.shared.head != nil { onDone() }
        }) {
            HeadMakerView()
        }
    }
}

/// **Where Wins presents the head maker and the one-time page.** A modifier,
/// so `MainAppView` gains one line and not a body's worth of state.
struct HeadCatchUpPrompt: ViewModifier {
    private enum Cover: String, Identifiable {
        case catchUp, maker
        var id: String { rawValue }
    }

    @State private var cover: Cover?

    func body(content: Content) -> some View {
        content
            .task {
                guard await shouldShowCatchUp() else { return }
                HeadAsk.markCatchUpShown()
                cover = .catchUp
            }
            .onChange(of: HeadAsk.shared.makerAsked) { _, asked in
                guard asked else { return }
                HeadAsk.shared.makerAsked = false
                // **With earlier heads, the page that offers them** (the
                // owner, 2026-10-14): somebody who deleted a head and pressed
                // the blank one can take an earlier head back rather than
                // only make a new one. With none, the maker, as before.
                if cover == nil { cover = HeadStore.shared.earlierEntries.isEmpty ? .maker : .catchUp }
            }
            .fullScreenCover(item: $cover) { which in
                switch which {
                case .catchUp: HeadCatchUpPage { cover = nil }
                case .maker: HeadMakerView()
                }
            }
    }

    /// Once the launch has finished drawing, so the page never covers the
    /// first frame of Wins, and never under the harness unless asked for
    /// (`-strataHeadCatchUp 1`, which shows it whatever was shown before).
    private func shouldShowCatchUp() async -> Bool {
        #if DEBUG
        let forced = DebugHarness.argument("-strataHeadCatchUp") == "1"
        if DebugHarness.isActive && !forced { return false }
        #else
        let forced = false
        #endif
        let shown = UserDefaults.standard.bool(forKey: HeadAsk.catchUpShownKey)
        guard forced || HeadAsk.showsCatchUp(alreadyShown: shown, hasHead: !HeadStore.shared.entries.isEmpty) else {
            return false
        }
        for _ in 0..<40 where !LaunchMoment.shared.finished {
            try? await Task.sleep(for: .milliseconds(150))
        }
        try? await Task.sleep(for: .milliseconds(900))
        return !Task.isCancelled && HeadStore.shared.head == nil
    }
}
