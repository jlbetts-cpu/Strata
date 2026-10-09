import SwiftUI

/// **Why It Works This Way**, a page in Settings (the owner, 2026-10-05: the
/// ADHD positioning).
///
/// Some Wins is designed with ADHD brains as the target, and this page says
/// so in plain words: what each choice is, and the idea it came from. It is
/// the design's reasoning, not a claim about anyone's health. **No promises
/// and no medical claims**, which is App Review guideline 1.4.1 (an app that
/// makes health claims gets held to a medical standard) and 2.3.7 (metadata
/// must not overclaim), and the last line says it outright. Nothing here says
/// "helps", "improves", "treats" or "proven". Each section says what the app
/// does, and where the idea came from, and stops.
///
/// The same document shape as `PrivacyPolicyView`, the page beside it in
/// Settings: `FormSectionLabel` headings, `bodyLarge` prose in the secondary
/// ink, the page's own ground. Sources are plain text at the foot, not
/// links: a page about attention should not send you somewhere else.
///
/// Voice: warm, plain, a little deadpan. No long dashes (CLAUDE.md, "Words
/// the app says"). `WhyItWorksTests` holds the rules a sweep can check.
struct WhyItWorksView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: GridConstants.gapWide) {
                // Each reason with his drawn mark in a column beside it, the
                // way a feature list is set (2026-10-08, `MarkLine`).
                ForEach(Array(Self.sections.enumerated()), id: \.element.title) { index, section in
                    MarkLine(mark: Self.marks[index % Self.marks.count]) {
                        VStack(alignment: .leading, spacing: GridConstants.gapTight) {
                            Text(section.title)
                                .font(Typography.headerMedium)
                                .foregroundStyle(AppColors.inkPrimary)
                            Text(section.body)
                                .font(Typography.bodyLarge)
                                .foregroundStyle(AppColors.inkSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                Text(Self.notMedical)
                    .font(Typography.bodyLarge)
                    .foregroundStyle(AppColors.inkPrimary)

                VStack(alignment: .leading, spacing: GridConstants.gapTight) {
                    FormSectionLabel("Sources")
                    ForEach(Self.sources, id: \.self) { source in
                        Text(source)
                            .font(Typography.screenSubtitle)
                            .foregroundStyle(AppColors.inkTertiary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(GridConstants.horizontalPadding)
        }
        .background { WarmBackground().ignoresSafeArea() }
        .sheetTitle(Self.title, drawn: false)
    }

    static let title = "Why It Works This Way"
    /// One of his marks per section, in order: a list of what you did, right
    /// where it happens, it shows straight away, quiet days are fine, photos
    /// help you remember, friends without a feed.
    static let marks = ["MarkChecklist", "MarkPin", "TipSparkle", "MarkHeart", "MarkPhoto", "MarkPeople"]

    static let sections: [(title: String, body: String)] = [
        ("A list of what you did",
         "Most lists are of what you have not done yet, and they get longer. "
         + "This one is the other kind. ADDitude calls it a ta-da list: you write "
         + "down what you already did, and the list can only grow in the right "
         + "direction. To-do lists have a way of turning into a list of reasons "
         + "to feel bad. This one does not have the material."),
        ("Right where it happens",
         "Russell Barkley's phrase is the point of performance: put the help "
         + "where the thing actually happens, not in an app you have to remember "
         + "to open. So a win can go in from the Lock Screen, a widget or "
         + "Control Center, in one tap, before the thought wanders off."),
        ("It shows straight away",
         "A block lands the moment you log a win. Not at the end of the week, "
         + "not after a summary. You did a thing, and there it is."),
        ("Quiet days are fine",
         "A day with nothing on it stays empty, and that is all it does. There "
         + "is no penalty and nothing to make up. Research on streaks (Silverman "
         + "and Barasch, 2023) found that once a streak breaks, people tend to do "
         + "less of the thing afterwards, not more. So the streak here is a "
         + "forgiving one: a day off a week never breaks it, and nothing counts "
         + "against you."),
        ("Photos help you remember",
         "A picture is a cue: it brings back the rest of the moment better than "
         + "a few words can. A photo on a win is optional, and it is there for "
         + "the you who looks back later."),
        ("Friends, without a feed",
         "A crew is a few people you choose, up to eight. There is no feed to "
         + "scroll and nothing public. You see what your friends did today, they "
         + "see yours, and nobody is shown who didn't post."),
    ]

    static let notMedical = "Some Wins is not a medical app and does not diagnose or treat ADHD."

    static let sources = [
        "ADDitude, on to-do list shame: additudemag.com/to-do-list-shame",
        "Russell A. Barkley, fact sheet on ADHD and the point of performance: russellbarkley.org",
        "Silverman, J. and Barasch, A. (2023), on broken streaks. Journal of Consumer Research.",
    ]
}
