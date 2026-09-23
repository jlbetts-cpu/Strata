# The social feed, and the backend that already exists

Written 2026-09-22, after the owner said: "me and my friend Darius actually
completely built the backend and everything for Apollo — the photos, the post,
the login, everything... I honestly don't remember the full thing of what was
made."

This document is the inventory and the plan. **Read it before writing a line
of feed code.** The single most important thing in it is that the hard part is
not the backend.

---

## 1. Where it is

`~/Desktop/apollo-app` — a second, complete iOS app, own Xcode project, own
git history, 173 Swift files, with `supabase/` beside it. Its `README.md` is
500 lines and is accurate. Bundle id `DariusEhsani.Apollo`.

**It is not this repo and it must not be merged into it wholesale.** It is a
different app against a different data model; see section 3.

## 2. What is already built

**The daily ritual he described already exists.** `Apollo/Core/Sunset/SunsetClock.swift`,
192 lines, and its own header says the intent: *"Wins stay locked until sunset
and everyone's unlock at once — one fixed daily moment instead of a
compulsion."* Sunset is computed on device with the NOAA solar position
algorithm from coarse location — no network, no server — falling back to
7:42pm when location is refused. Guest mode uses a fixed offset so the locked
state matches the mockup and the unlock can be watched on demand.

He does not need this designed. He needs it ported.

**The backend**, Supabase:

| | |
|---|---|
| Tables | `users`, `posts` (one per user per UTC date), `photos` (many per post, per-photo caption), `reactions`, `comments` (one level of threading), `friendships`, `streaks`, `wins`, `win_completions`, `notifications`, `push_tokens`, `notification_prefs`, `notification_quota` |
| View | `feed_posts` — the feed's whole read surface, joins posts to users and streaks and aggregates photo urls, captions, reaction and comment counts |
| RPC | `publish_photo(...)` — upserts today's post, inserts the photo, writes the caption, logs a win completion and bumps the total, in one round trip per shutter tap |
| Storage | `avatars`, `banners`, `photos` |
| Edge functions | `notifications-send` (APNs), two `pg_cron` jobs for habit reminders and the weekly summary |
| Auth | Apple, Google, Phone |

**The app layer**: every data source is a protocol with a Supabase
implementation AND a mock one — `FeedRepository` / `SupabaseFeedRepository` /
`MockFeedRepository`, and the same for camera, comments, friends, memories,
notifications, post, profile, win list. Feed features already built: cursor
pagination, pull to refresh, realtime "new posts" banner, optimistic reactions
with rollback, full-screen photo viewer, skeletons, six empty and error
states, and **`reportPost`** — which matters, because Apple's user-generated
content rules require a report path and it is already there.

## 3. The hard part, and it is not the backend

**Two data models, and they do not line up.**

| | this app | apollo-app |
|---|---|---|
| Store | SwiftData, on device, offline-first | Supabase, network |
| A win | `Habit` + `HabitLog`, one log per habit per day | `wins` + `win_completions`, and a `posts` row per user per day holding many `photos` |
| A photograph | a file in `strata-images`, referenced by `HabitLog.imageFileName` | a row in `photos` with a `raw_url` in a bucket |
| Identity | none | `auth.users` |

Merging these by moving everything onto Supabase would throw away the offline
app that has just been polished, and would make the camera depend on a network
at the one moment it must not.

**The shape that works is additive.** SwiftData stays the source of truth for
your own wins and keeps working with the phone in flight mode. The social
layer is a SECOND, read-mostly source that Home shows underneath Recents:
friends' posts come from `feed_posts`, and publishing is a one-way push of a
local win up through `publish_photo`. Nothing about the folders changes.

That also means the feed can be built and reviewed with **no network at all**,
on `MockFeedRepository`, which is the reason the order in section 5 starts
where it does.

## 4. The obligation, stated plainly

Putting other people's photographs in the app is a permanent commitment, not a
feature: moderation, reports, blocking, deletion requests, and Apple's
user-generated content review. The account has already had a 4.1(a) rejection.
`apollo-app` has `reportPost` and a friendships table, which is most of what
review asks for, but it is worth knowing the cost is ongoing and is paid in
attention rather than in code.

This is not an argument against doing it. It is an argument for the order
below, where the app stays shippable at every step and the social layer is the
last thing that goes live.

## 5. The order

Each step leaves a working, releasable app.

1. **The polaroid.** Figma `13258-6988`, 342x452, thin border with a deep
   bottom edge and the mark in the corner. What a win becomes when you TAP it,
   not how it looks while scrolling. No backend, visible immediately, and the
   feed reuses it for every post.
2. **The locked feed, on mock data.** Port `SunsetClock` and the feed view in
   under Recents, running entirely on `MockFeedRepository`. The countdown, the
   unlock, the cards, the empty states — all of the design work, none of the
   risk. Nothing here can break the app that ships today.
3. **Identity.** Supabase session, Apple sign-in, the profile row. Gated so
   that a signed-out user gets exactly the app that exists now.
4. **Real reads.** Swap the mock repository for the Supabase one behind the
   same protocol.
5. **Publishing.** A local win pushed up through `publish_photo`, after the
   fact, never in the shutter's path.

## 6. What not to do

- Do not copy `apollo-app`'s views in and wire them to SwiftData. They are
  written against `FeedModels` and a repository protocol; bring the PROTOCOL
  and the models, and let the views follow.
- Do not put a network call anywhere in the capture path. The camera is the
  one thing in this app that must work with no signal.
- Do not make Home depend on being signed in. A signed-out Apollo is the app
  that ships today and it has to keep working.
- Do not start step 2 before step 1 is done and looked at. The feed's cards
  are polaroids; building them twice is the overload he asked to avoid.
