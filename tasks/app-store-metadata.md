# App Store metadata, drafted for the 4.1(a) resubmission

Drafted 2026-09-23. **Nothing here is live.** App Store Connect is the owner's
to edit and this is text for him to paste, once he has settled the name by
saying it out loud a few times.

## The rejection, in one paragraph

Guideline **4.1(a) Copycats**: "the app's metadata contains third-party content
similar to a popular app or game already available on the App Store... This
creates a misleading association with another developer's app." Apple did not
say which part of the metadata, and the account is already under extended
review, so a guess that misses costs another cycle.

The strongest candidate found from outside App Store Connect: **there is
already an App Store app called Strata that captures everyday moments, and its
own feature is called Strata Capture.** Same word, same category, same verb.
Strava was the first guess and is weaker: it is a near-name but a different
category. The head maker was considered and ruled out by the owner as entirely
original work.

Note that the listing already reads "Strata Wins", so **adding a second word is
not on its own the remedy**. The distinguishing word has to be one the other
app cannot claim.

## Name

    Strata Neo

11 characters against the 30 allowed. Clear on the App Store. Chosen because
the owner's brief for the whole design is "that Tokyo neo aesthetic... the
1990s Japanese future": Neo Tokyo is Akira, 1988, and neo simply means new, so
the name points forward while the design language points back at how 1988
imagined forward.

**Before anyone prints it:** NEOSTRATA is a registered skincare mark, fifty
years old, built from the same two roots in the other order, sold in 85
countries. Different trademark class and a different industry, and it is not an
app, so App Review is unlikely to see an association. A lawyer rather than an
agent should confirm the trademark side.

**Both targets have to say it.** Today the app ships as "Strata" on the home
screen and the widget ships as "Strata Wins", because only the widget target
sets `INFOPLIST_KEY_CFBundleDisplayName`.

## Subtitle

    Proof you did something

23 of 30. Superseded the earlier "a photo for every small win", because this
one says what the app is FOR rather than what it contains, and it carries the
brand's whole argument in three words. See `docs/brand.md`. It says what the app does in its own words, names no category that
belongs to somebody else, and contains no comparison.

## Keywords

100 characters, comma separated, no spaces after the commas. **No other app's
name appears here, deliberately**: an irrelevant reference to a popular app in
the keywords is one of the examples Apple gives for this exact guideline.

    win,wins,photo,journal,diary,camera,film,memory,proof,daily,log,blocks,tower,record,evidence

**"Habit" and "streak" are deliberately absent.** The owner: "I don't want to
hear no habit in the description." Both words belong to the commodity category
this app is not in, and "streak" names the scoreboard the whole design refuses.
Losing them costs a little search traffic and buys the positioning.

## Promotional text

170 characters, and it can be changed without a review, so it is the right
place for anything seasonal.

    Photograph the small things that went right. They stack into a tower for
    the day, and the day keeps itself.

## Description, opening paragraph

The rest can follow the existing copy, but the opening has to carry the app on
its own:

    Strata Neo is a camera for the things that went right. Photograph a win,
    and it becomes a block: small, medium or big, in its own colour. The
    blocks stack into a tower for the day, the days keep themselves, and the
    photographs stay on your phone.

Rules the copy is held to, from `CLAUDE.md` and the owner: no em dashes, no
comparison to another app, and nothing that reads as watching or surveillance.

## The reply to App Review

Send in Resolution Center, with the resubmission. Short, factual, and it asks
the question rather than guessing twice:

    Thank you for the review. We have renamed the app to Strata Neo and
    updated the name, subtitle, keywords and screenshots so that the listing
    describes only our own app and references no other developer's app or
    product.

    We were not able to identify which element was read as third-party
    content, and we want to fix the right thing rather than guess. If any part
    of the metadata still creates a misleading association, please tell us
    which element it is and we will change it immediately.

    All artwork, photography, icon and interface design in this app is our own
    original work.

## What else to check before resubmitting

- **The screenshots.** They are metadata too. Nothing in a screenshot may show
  another app's interface, name or icon, including anything visible in a status
  bar or a share sheet.
- **The app preview video**, if there is one, under the same rule.
- **The support and marketing URLs.** `tasks/app-store-readiness.md` records
  that `strataapp.co` did not resolve at all. A dead support URL is its own
  rejection, separate from this one.
- **The widget's display name**, which today says something different from the
  app's.
