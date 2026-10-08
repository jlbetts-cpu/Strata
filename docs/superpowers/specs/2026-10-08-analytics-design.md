# Anonymous product analytics

2026-10-08. The owner chose in-app analytics over Apple's numbers alone: "we
can understand problem areas in the app for users and features people use or
dont use." This reverses the "no analytics" line the app has said in public,
so the promise is rewritten, not quietly broken (section 6).

## 1. What it is

`Analytics` (Strata/Services/Analytics.swift): one call, `Analytics.signal(_
event:, _ fields:)`, from anywhere. Events go to **TelemetryDeck** over its
ingest API, sent by our own `URLSession` code: no SDK, no dependency, nothing
else in the binary. TelemetryDeck's dashboard is the owner's dashboard; a free
account (50,000 events a month for accounts made after 2026-07-01) is enough
for launch.

Off, and sends nothing, until the owner puts his app ID in Info.plist
(`SomeWinsTelemetryAppID`, optional `SomeWinsTelemetryNamespace`). An empty or
missing ID is a build that collects nothing, which is what tests and every
build before he signs up are.

## 2. What may be sent, and what never is

**Never**: a win's title, a note, a chat line, a crew's or a person's name, a
photo, a place, a date anyone wrote, the head, a contact, anything typed.
`AnalyticsField` is a closed enum of keys; a value is a small enum, a bucketed
number or a bool, so free text cannot be passed by accident
(`AnalyticsTests.noFreeText`).

**Events** (snake_case `type`):

| Event | Fields |
|---|---|
| `win_logged` | size (quick, regular, deep), source (slot, camera, widget, siri, lock_screen, crew), has_photo, has_doodle |
| `goal_reached` | goal (bucket) |
| `strip_printed`, `strip_developed`, `strip_shared` | destination for shared (when the share sheet says) |
| `journal_written`, `doodle_drawn` | none |
| `crew_created`, `crew_invite_sent`, `crew_joined`, `crew_message_sent`, `crew_reaction` | none |
| `onboarding_step` | step (name), action (shown, done, skipped) |
| `trailer` | action (played, finished, skipped, sound_on) |
| `head_made`, `replay_saved` | none |
| `tip_jar_shown`, `tip_purchased`, `tip_ask` | tier for purchased; action (shown, tipped, dismissed) for ask |
| `screen` | name (wins, camera, memories, settings, crews, chat, profile, journal) |

TelemetryDeck's own signals so its built-in views work: `TelemetryDeck.Session.started`
on a cold launch or a return after 5 minutes away, and
`TelemetryDeck.Acquisition.newInstallDetected` once, with the first session's
day. Default context on every event: app version and build, iOS version,
device model, locale, whether TestFlight, debug or simulator. (TelemetryDeck
reserves the `TelemetryDeck.` prefix for its SDKs; we use the SDK's own keys so
the dashboard's insights fill, and say so to them if it ever matters.)

## 3. Identity

`clientUser` is SHA-256 of a random UUID made on first launch and kept in
UserDefaults, plus a fixed salt; TelemetryDeck hashes it again on its server.
**Not** `identifierForVendor`: a random install id is less, and deleting the
app resets it. A session is a fresh UUID per cold launch or after 5 minutes in
the background. `isTestMode` is true in debug and on the simulator.

## 4. Sending

In memory, flushed every 10 seconds and when the app goes to the background,
at most 100 signals a request, as the SDK does. A failed send keeps the batch
for the next attempt; a 4xx that means "bad request" drops it. At most 500
held, oldest dropped first. Persisting the queue across launches is not worth
a file for a launch build: a lost batch is a few events.

## 5. The switch

Settings > Privacy: **Share Anonymous Usage**, on by default, with one line:
"Counts of what is used, never what you write or photograph." Off means
nothing is queued or sent from that moment and the queue is emptied.

## 6. What the app says in public, rewritten

- Description: "No account. No ads. Anonymous usage counts only, never what
  you log." replaces "No account. No ads. No analytics."
- `docs/privacy.html`: a paragraph naming TelemetryDeck, what is counted, the
  switch, and that it is not linked to you or used for tracking.
- App Privacy label: **Identifiers > Device ID** and **Usage Data > Product
  Interaction**, both "not linked to you", "not used for tracking", purpose
  Analytics (TelemetryDeck's own guidance). Tips add **Purchases > Purchase
  History**, same answers.
- `PrivacyInfo.xcprivacy`: the same two collected types, and UserDefaults
  (CA92.1) if not already declared.

## 7. Tests

`AnalyticsTests` (no network): the body has the fields TelemetryDeck needs;
an empty app ID sends nothing; the switch off sends nothing and empties the
queue; no field accepts free text; a batch splits at 100; the client user is
stable across calls and is not the raw UUID.

## 8. For the owner, in the morning

1. Make a TelemetryDeck account (free), create the app, copy its App ID into
   Info.plist `SomeWinsTelemetryAppID` (it is not a secret, but it is his).
2. In App Store Connect, update App Privacy with section 6's answers before
   the build ships.
