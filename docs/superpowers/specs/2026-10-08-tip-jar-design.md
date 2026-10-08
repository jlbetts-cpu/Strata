# Support Some Wins: the tip jar and one gentle ask

2026-10-08. The owner: "at launch I dont want to do too much since the app is
new and I want to build traction I do want some sort of way to donate to me."
His pick: a tip jar plus one gentle ask. Plus (`docs/monetization.md`) waits
for traction; nothing is gated.

## 1. Rules it is held to

- Tips to the developer go through in-app purchase (guideline 3.1.1); an
  outside link is rejected. Never called a "donation" (that word is for
  approved charities, 3.2.2(iv)).
- Nothing is unlocked by a tip and nothing is held back without one.
- The ask is never tied to a review prompt, never a notification, never
  mid-task, and appears at most once.

## 2. The products

Three consumables, created by the owner in App Store Connect:

| Product ID | Name | Price |
|---|---|---|
| `somewins.tip.small` | Small Tip | $1.99 |
| `somewins.tip.medium` | Kind Tip | $4.99 |
| `somewins.tip.large` | Generous Tip | $9.99 |

`Strata/SomeWins.storekit` holds the same three so the simulator can buy them.

## 3. The code

`TipJar` (Strata/Services/TipJar.swift), observable, started at launch:
listens to `Transaction.updates` and drains `Transaction.unfinished`, finishing
tip transactions; loads the three products sorted by price; `tip(_:)` buys one
and returns whether it went through; keeps `hasTipped` and the count in
UserDefaults. `PlusStore` is not started at launch today, so nothing else
finishes these transactions.

## 4. Where it lives

**Settings, a section of its own, "Support Some Wins"**, above About. One
line in his voice, then the three as the app's own pills, each its name and
price:

> Some Wins is made by one person. If it makes your days a little better, a
> tip keeps it going.

After a tip, the section's line becomes "Thank you, genuinely." (his words
from the onboarding thank-you page) and the pills stay, for anyone who wants
to again. Prices that will not load (no agreement signed, no network) hide the
pills and say nothing.

## 5. The one ask

Once, ever, after a strip is developed, **from the third developed strip on**
(the first strip is where the crew invite asks; two asks on one moment is one
too many, docs/launch-plan.md), and not on a day a crew invite was asked. A
quiet sheet at medium height:

- Title: "A small thank you"
- Line: "Some Wins is made by one person, and it's free. If it's been good to
  you, you can leave a tip."
- The three pills, and "Not now" as a plain word.

Shown or dismissed, it never comes back (`TipJar.askedKey`). Under Reduce
Motion it fades.

## 6. Tests

`TipJarTests` (no StoreKit network): the ask's rule (not before the third
strip, never twice, never after a tip, never on an invite day); product IDs
sorted by price; the copy has no long dash and no "donat".

## 7. For the owner

1. Sign the Paid Apps Agreement, banking and tax (IAP will not load without it).
2. Create the three consumables with these IDs and prices, a review screenshot
   of Settings, and the note "Optional tip to the developer. Unlocks nothing."
3. Attach them to the next version and submit with the build.
