# App Store readiness

Audited 2026-09-07 against the app as it actually builds, not against the
plan. Everything here was checked by running something — a `curl`, a `grep`
for whether a setting is read anywhere, a look in the asset catalogue — not
by reading the settings screen and assuming the switches were wired.

## Blockers I cannot fix from here

**1. There is no app icon.** `Strata/Assets.xcassets/AppIcon.appiconset/`
contains `Contents.json` and nothing else — no image at any size. An app
cannot be submitted without one, and it is the one asset that is a design
decision rather than a task, so it is yours to make.

**2. `strataapp.co` does not exist.** Not a 404 — no response at all:

    000  https://strataapp.co/privacy
    000  https://strataapp.co/terms
    000  https://strataapp.co

App Store Connect requires a privacy policy **URL**, and App Review opens it.
An in-app policy does not substitute. `support@strataapp.co`, used by Send
Feedback, is on the same dead domain, so support mail currently bounces.
Either register and host it, or point all three at somewhere that exists.

Until the domain is up, the in-app `PrivacyPolicyView` is the honest text and
can be copied to whatever gets hosted.

## Fixed in this pass

- **Two settings toggles were wired to nothing.** `towerShowParallax` and
  `hapticsEnabled` were `@AppStorage` keys that no other file read: the
  switches moved, the keys were written, the tower kept tilting and every
  haptic kept firing. Both are honoured now, and parallax also yields to
  Reduce Motion, which it should always have done.
- **"Customization — Coming soon"** removed. A row that does nothing reads as
  an unfinished app, to a reviewer and to everyone else.
- **Privacy and Terms** pointed at the dead domain. Replaced with an in-app
  privacy policy.
- **`ITSAppUsesNonExemptEncryption`** was missing, so every upload would stop
  and ask for export compliance. Declared `false` in `Info.plist`.
- **Calendar copy** promised events "on your timeline". There has been no
  timeline since the pivot.

## Present and correct

Usage descriptions for camera, photo library, Health, Calendar and motion;
launch screen; supported orientations; light-only interface style; version
1.0 (1); data export; permanent delete; rate-on-App-Store via `requestReview`.

## Worth deciding before submitting

- **Apple Health and Calendar are still offered** and still connect, but both
  were built to add context to Today and Plan, which no longer exist. They are
  two permission prompts and two privacy-label entries for something the app
  barely uses now. Keeping them is fine; it should be a decision.
- **Version is still 1.0 (1).** Fine for a first submission, worth a bump for
  anything after.
