# Tonight's Story and Friends: design spec

Written 2026-10-15 against `5f0c2af`. Design only, no Swift changed. Tags: **(a)** a primary rule, paper or Apple doc, **(b)** a shipping product or its press, **(c)** inference.

## Summary

1. **Tonight's Story** is a timed story. Any of today's wins can be marked for it all day; it opens to friends at 8pm in the viewer's zone and is gone by 9am.
2. At 8pm a friend's head in the Today row becomes a round preview of their story's first photo, Snapchat style, and turns back into a head in the morning.
3. The selector is its own full-width row in its own evening colour, under the block on Add a Win, away from the crews row, and off for every new win.
4. Story reactions are the ordinary reactions and land on that block on the poster's tower; Reply opens the personal chat.
5. Friends: @usernames with exact-match search, requests, and a two-person crew per friendship whose chat is the DM. 13 to 15 cannot be found.
6. Everything runs on the public database with sealed records. The one world-readable addition is a handle card that cannot be listed, only fetched by its exact name.

---

## 0. What this builds on, and one reversal

Reused as shipped: sealed `CrewItem` records (`PublicCrewCloud.swift`), HPKE key wraps and each member's public key (`CrewRekey.swift`), one-way ping tags (`NotifyShared/CrewNotes.swift`), the Today row (`TodayHeads.swift`), the friend's profile tower (`FriendProfileSheet.swift`), reactions gathered onto your own blocks (`MyWinReactions.swift`), the age rules (`CrewAge.swift`) and the 14-day cloud window with local tallies (`CrewDay.keptDays`, `CrewHistory`).

**The reversal.** `docs/friends-research-2026-10-14.md` recommended codes and no usernames, because a directory lets strangers find a 13 year old. Jayden has chosen usernames and search. This spec builds the safest version (section 4) and says the cost: discovery is what most state social media laws key on, so section 7 has more to do (c).

---

## 1. Tonight's Story

### 1.1 What others do, and what we take

| Product | Mechanic | What we take |
|---|---|---|
| Snapchat | Stories live 24 hours ([Engadget, 2013](https://www.engadget.com/2013-10-03-snapchat-introduces-stories-picture-feeds-that-last-24-hours.html)); by default only friends you added can view yours ([Snap Support](https://help.snapchat.com/hc/en-us/articles/7012304746644)) (a). Friends' stories sit with friends, apart from public content, since 2017 ([Engadget](https://engadget.com/2017/11/29/snapchat-redesign-separates-friend-media-content)) (b) | Friends only, where the friends already are |
| Snapchat bubbles | A friend with a new story shows a story preview and coloured ring in place of their Bitmoji; the ring greys once watched (b, observed; Snap publishes no doc) | The head becomes the preview; seen and unseen differ |
| Instagram Close Friends | Pick green when posting; viewers see a green ring and badge; nobody is told they were added ([Tom's Guide](https://tomsguide.com/us/instagram-stories-close-friends-how-to-use,news-28731.html), [Fortune](https://fortune.com/2018/12/01/instagram-close-friends-stories)) (b) | A distinct colour at posting says "this audience" |
| Instagram replies | A story reply lands in DMs; the photo leaves the thread after 24 hours, words stay ([secondary summary](https://instantdm.com/blog/instagram-story-replies-private-who-can-see-how-they-work-2026)) (b). More is shared in DMs than Stories ([Mosseri](https://www.businessinsider.nl/instagram-head-adam-mosseri-on-the-paradigm-shift-from-posting-in-public-to-sharing-in-private)) (b) | Reply goes to the personal chat; the quote keeps its words |
| BeReal | One prompt at an unknown time, two minutes to post; late posts labelled with how late, read by users as "a mark of shame" ([Wikipedia](https://en.wikipedia.org/wiki/BeReal)) (b) | A shared daily moment, never a clock you can fail. No late label |
| Locket | Friends' photos on your home screen widget ([TechCrunch](https://techcrunch.com/2022/01/11/locket-an-app-for-sharing-photos-to-friends-homescreens-hits-the-top-of-the-app-store)), 20 friends ([App Store](https://apps.apple.com/us/app/1600525061)) (b) | Later: tonight's previews on the crew widget |
| Retro | Moments grouped by week; a nudge to share one photo to see friends' weeks ([TechCrunch](https://techcrunch.com/2023/07/07/retro-is-a-deeply-personal-photo-journaling-app-for-close-friends/)) (b) | Not share-to-see: it punishes a quiet day |
| Lapse, Dispo | Lapse shows a roll 24 hours after it starts ([TechCrunch](https://techcrunch.com/2021/12/20/lapse-an-app-that-lets-you-snap-and-develop-rolls-of-film-with-groups-of-friends-raises-11m-from-gv-and-others)); Dispo develops at 9am, and after complaints let people choose immediate ([App Store](https://apple.co/3qCRWpk)) (b) | A fixed reveal hour; the poster sees their own story at once |

**What a delay does.** People value looking forward to a good thing and will postpone one to savour it (Loewenstein 1987, [paper](https://www.cmu.edu/dietrich/sds/docs/loewenstein/AnticipationDelayed.pdf)) (a). Savouring needs a known time; a random one is a summons (c). Telling friends good news lifts your day more when they answer actively (Gable et al. 2004, [PubMed](https://pubmed.ncbi.nlm.nih.gov/15301629/)) (a), so every story ends in a reaction and a reply. No study isolates a timed reveal's effect on retention, and Dispo's retreat says the delay must never block the poster (b, c).

### 1.2 When it opens

| Option | For | Against |
|---|---|---|
| Sunset in the viewer's zone | His image; feels natural | Davis sunset runs about 4:50pm in December to 8:35pm in June, so winter opens during class (c). Needs location or a table per zone; latitude splits one zone |
| **8pm in the viewer's zone** | One known moment; same for everyone nearby; no location; follows the crew evening cue (7:00 to 8:55pm, `CrewEvening.swift`) | Less poetic |

**Recommended: 8pm, with sunset as the look, not the clock.** A story posted after a viewer's 8pm appears at once.

**No new notification.** On a night when a friend has a story, the day's one evening cue is sent at 8:00 and says "Tonight's stories are open." Otherwise it is unchanged. Never who posted, never who did not.

### 1.3 How long it lives

- **Posting:** any of your today's wins, until midnight. Marked after 8pm, it shows at once.
- **Viewing:** 8pm until **9am** the next morning in the viewer's zone, Dispo's hour, so an early sleeper sees it at breakfast.
- **Hard end:** each item carries, sealed, an end of noon on the poster's next day. No phone shows it after that.
- **Your own story** opens any time, as it will look at 8pm.

### 1.4 What the viewer sees

- **Before 8pm:** heads and the green dot, as now; a friend with something waiting gets a thin unlit ring in the evening colour (question 3). No count.
- **From 8pm:** the head becomes a circle cropped from their first story photo, ring lit, their head small at the bottom edge. With no photo (a doodle, a plain block, anyone under 16) the circle shows the block's colour and category icon.
- **Order:** unseen stories newest first, then seen ones (ring thin and grey), then everyone else.
- **The viewer:** full screen, one win a page, segments at the top, the photo with the block's label at the foot (title, Quick, Regular or Deep, its colour). Tap on, swipe across to the next friend, swipe down to close.
- **At 9am** previews turn back into heads.
- **Never shown:** who viewed, how many, a late label, a count of stories.

---

## 2. The selector on Add a Win

The sheet reads: name, colour and size, the crews row (`CrewPicker`), the earlier-today row, the block. The story row goes **under the block, at the foot of the sheet**, the last decision on the page.

| | Off | On |
|---|---|---|
| Look | Outline in the evening colour, SF `sunset` symbol (tools stay SF) | Filled evening colour, symbol filled |
| Words | **Add to Tonight's Story** | **On Tonight's Story** |
| Line under | | "Your friends see it from 8pm. Gone by morning." |
| Under 16, with a photo | | "Your friends see the block, not the photo." |

- **Off for every new win**, never remembered (crews are; this is a decision each time) (c).
- **Hidden until you have a friend.**
- **The evening colour is a new token**, one flat colour checked against the six category colours and the Social coral. A dusk violet to start; the value is his.
- **Camera Review** gets the same row under its crews row, on dark.
- **Edit** shows it on for a story win; turning it off removes the win from the story at once. Deleting the win does too.
- The line under it is the whole lesson. No sheet.

The words pass `docs/voice.md`: Title Case buttons, a specific time, no exclamation mark, no long dash, nothing watched.

---

## 3. One tower, not a second feed

A story is not new content: **it is your tower's blocks, shown to friends at night.**

- **Same reactions.** Hold a page for the emoji row, + and the sticker (`TowerReactions`); double-tap for a heart. Sealed to the poster alone, it lands on that block on Wins and in Memories with the same `ReactionBadge`, and stays after the night.
- **Reply opens the personal chat.** The field reads "Reply to Sam" and sends a line into your two-person crew with the win quoted. Until 9am the quote shows the photo; after, the block alone.
- **The friend's profile** shows tonight's story wins on their tower after 8pm, edged in the evening colour.
- **Notifications** reuse the reaction ping: "Rildy reacted 🩷 to your win."

---

## 4. Friends

### 4.1 @usernames and search

- **Claim** on first opening Friends, after the age check: 3 to 20 characters, a to z, 0 to 9, dot, underscore, case folded; checked by `CrewWords.isAcceptable` and a bundled reserved list.
- **First come:** the card's record name comes from the name and is saved with `.ifServerRecordUnchanged`, as `pingOnce` does, so a second claim fails (b).
- **Changing it** keeps the old card as a "moved" mark you own for 30 days, so nobody takes it to pose as you.
- **Exact match only.** `@sam.k` gives one card or none. No prefix search, suggestions or contacts upload.
- **The card** shows head, first name and **Add**. No wins, crews or counts.

### 4.2 Requests

- **Add** sends a sealed request to their letterbox (the `mail-` design, friends research 4.2): "Sam wants to add you." with **Add Back** / **Not Now**, and **Block** / **Report** on hold. Not Now is silent to the asker (b).
- **Nothing in common** (no shared crew or friend your phone knows of): one line before sending, "You don't share a crew with Sam yet." Snapchat shows such a warning when you add someone with no mutual friends ([TechCrunch, 2024](https://techcrunch.com/2024/06/25/snapchat-introduces-new-safety-features-to-limit-strangers-contacting-users)) (b).
- **Quiet ceilings, never shown:** 50 friends, 20 requests sent a day, the newest 20 pending.

### 4.3 The personal crew

- **Each friendship makes a two-person crew** with its own key. Its chat is the DM; its tower is the wins you send each other.
- **It does not count against the five crews**, or five crews would mean five friends.
- **Reached** from a friend's head (profile, Message), a story's Reply, and a Friends list under the group crews. On Add a Win a friend appears as a head after the group crews.
- **The Today row needs no new source:** `TodayHeads.people` reads every crew's members.
- **Remove Friend** ends the pair on both phones. Block does that and files a report.

### 4.4 Inviting

- **A friend into a crew:** the Invite sheet lists friends by head; a press seals the crew's link to that friend (`kind = "Crew"` in their letterbox): "Sam started Roommates with you." **Join** / **Not Now**.
- **Someone not on the app:** the share sheet, or **Choose a Contact**, Apple's picker, which runs outside the app and returns only the picked contact with no Contacts permission ([Apple](https://developer.apple.com/documentation/contactsui/cncontactpickerviewcontroller)) (a).

| State | The invite row |
|---|---|
| Sent by link | A dashed circle, "Invited" |
| Sent to a picked contact | Their contact photo and name, faded, "Invited" |
| Accepted | Their head and chosen first name, then into the friends list |

The contact's photo and name **never leave your phone** and are dropped on accept or removal.

### 4.5 13 to 15

| | 16 and over | 13 to 15 |
|---|---|---|
| Findable by @name | On, with a Settings switch | **Off, no switch.** Added by code, link or crew |
| Search and send requests | Yes | Yes, with the nothing-in-common warning |
| Story photos | Sent | Block only, as crews today |
| Family Sharing child with Communication Limits | n/a | Requests go to a parent through PermissionKit ([Apple](https://developer.apple.com/documentation/permissionkit)) (a) |

Snap shows teens in search and suggestions only with several mutual friends and bars public teen profiles (TechCrunch, above) (b); its Family Center shows a parent the friend list, never messages ([Snap](https://values.snap.com/news/introducing-family-center-on-snapchat)) (b). With no server there is no mutual-friend count, so "not findable" is the honest equivalent (c).

---

## 5. The Together score

**The points of every win you two shared with each other**, Quick 1, Regular 2, Deep 3 (`BlockSize.massTier`). A win counts once when either of you sent it to your personal crew, or tagged the other in "who you were with" in any crew you share.

**Computed on each phone.** Both hold the same records, so both reach the same number. The cloud keeps 14 days, so the phone keeps a tally by day and person as `CrewHistory` does. Deleting a win lowers it.

**Shown** as one line under the friend's head on their profile and in the personal chat header: "Together 46". A press shows this week's part. Never ranked or notified; it only grows. Story wins do not count: a story goes to everyone.

---

## 6. Architecture

### 6.1 New records

| Record | Where | Sealed with | Writer | Lives |
|---|---|---|---|---|
| `Handle` (new type) | Public, **no queryable index** | Key derived from the normalized name (HKDF) | Claimant | Until changed |
| `Ask`, `Yes`, `Removed`, `Crew` | `CrewItem`, `crew = "mail-…"` | HPKE to the recipient | Sender | Deleted after an answer or 14 days |
| Personal crew | The usual kinds | That crew's key | Both | As any crew |
| `Tonight` (night key) | `CrewItem` in each personal crew | That crew's key | Poster | Until the hard end |
| `StoryWin` | `CrewItem`, `crew = "night-…"`, new each night | Night key | Poster | Until the hard end |
| Story `Reaction` | Same night space | HPKE to the poster | Viewer | 24 hours past the end |
| Reply | `CrewMessage`, new optional key `storyQuote` (title, colour, size) | Personal crew key | Viewer | As any line |

`Handle` must be a new type: every `CrewItem` field is queryable (`full-schema.ckdb`), so `kind == "Handle"` would list every card. A type with no queryable field, not even the record name, can only be fetched by exact name; developers meet "Field 'recordName' is not marked queryable" for this reason ([Apple Forums](https://developer.apple.com/forums/thread/79126)) (b). One Console deploy, mirrored in `full-schema.ckdb`.

### 6.2 What is world-readable, exactly

**The card.** Name: `h-` plus hex SHA-256 of `somewins.handle.v1|` and the normalized name. Fields: `box`, and `a` (sealed head, 16+ only). The box holds a first name, a head, the public key requests are sealed to, a version. Someone who knows the exact name learns those. Anyone else learns only that a card exists under a hash, its times, and the writer's app-scoped iCloud record name, which names no Apple ID. Never a profile id, age, wins, crews, friends or number.

**Everything else** is sealed bytes with the metadata crews already expose. A night space id is new each night, so nights do not link (c).

**Scraping.** No listing is possible; only guessing names one fetch at a time. CloudKit throttles busy clients with `requestRateLimited` ([Apple](https://developer.apple.com/documentation/cloudkit/ckerror/requestratelimited)) (a), and the app caps 30 lookups an hour. A modified client skips the app's cap, not CloudKit's, and a right guess yields one name and head of someone who chose to be findable (c).

### 6.3 How the story key reaches friends

1. The first win marked for tonight makes a random night key and night space id.
2. One `Tonight` record goes into each personal crew, sealed with that crew's key: fifty friends is one batched save.
3. Each friend's phone already syncs its personal crews, finds the key, and fetches the night space after its own 8pm.
4. **Hide My Story From** a friend is simply not writing theirs.
5. At the hard end every phone deletes the night key and cached photos.

### 6.4 Deletion

Only a record's creator can delete it. The poster's phone deletes its `StoryWin` and `Tonight` records at the hard end, from a background refresh and on next open; viewers delete their reactions. If the poster's phone is off for days, the records linger as sealed bytes no phone shows past the sealed end, whose key every friend has already discarded (c). Reactions are copied to the poster's phone when read, so they outlive the night.

### 6.5 Not possible without a server

Expiry the server enforces; prefix search and mutual-friend suggestions; per-account rate limits a modified client cannot skip; a mutual-friend count for teens; removing one item rather than banning a person; hash-scanning uploads, which are sealed first; Android.

**The promise holds:** we cannot read your wins, stories, requests or chats. All anyone outside your friends can read is a card you chose to make findable.

---

## 7. Moderation and compliance

**On a story:** **Report**, **Hide Sam's Story** (the friendship stays), **Block**. Report uses the existing `Report` record with title and photo, a "story" subject and a new "It involves a child" reason. Block removes the friend, ends the pair, drops their future requests, and files a report (compliance gap 3).

**Guideline 1.2** asks for a filter, reporting with timely responses, blocking and contact details, and removes apps used for "random or anonymous chat" ([Apple](https://developer.apple.com/app-store/review/guidelines/)) (a). New text to filter: handles, story titles, card names. Exact-match search, accepted requests and no stranger feed keep it clear of random chat (c).

**Age.** Declared Age Range at first open of Friends; under 13 gets no handle, friends or stories. The age-rating answer is social media capabilities, disabled under 13 ([Apple](https://developer.apple.com/news/?id=tlur8uvi)) (a). In Texas an update adding contact for minors is a likely significant change needing PermissionKit consent ([Apple](https://developer.apple.com/news/?id=sg176nne)) (a; LAWYER on what counts).

**COPPA.** The amended rule ([Federal Register](https://www.federalregister.gov/documents/2025/04/22/2025-05904/childrens-online-privacy-protection-rule)) (a) turns on actual knowledge; the under-13 gate is the control. A username is contact information, so settle the declined-age path (compliance item 12) before search ships (c).

**Deletion.** A handle is close to an account, so 5.1.1(v) applies (a): **Delete My @name and Friends** removes the card, letterbox, personal crews and any story; Reset All Data does too.

**App Review** looks for zero-tolerance terms agreed first, report and block everywhere, a 24-hour response, and a way in (b, the rejection in `2026-10-15-social-compliance.md`). Stories open at 8pm and Review may test at 10am, so Review Notes carry a seeded friend's @name, a recording of a story night, and the fact your own story previews any time.

Still open first, not changed here: NCMEC registration, the `Report` write grant, region scope (gaps 1 and 2).

---

## 8. Build plan

Each slice ships alone behind `CrewsFlag`, with the two-phone test. Measures are the existing anonymous counts (opt-out), never content.

| Slice | Accept when | Measure |
|---|---|---|
| **1. @names, requests, personal crews** | Two phones find each other by exact name, request, add back, chat; a taken name cannot be claimed; any query on `Handle` fails in Production; a 13 to 15 phone has no card; Block and Delete My @name clear every record | Crew users with a name by day 7; requests accepted within 48 hours (target 60%, c); friends per user; lookups per user a day (a scraping signal); reports per 1,000 requests |
| **2. Invites** | The row goes dashed, to contact photo and name, to head; a network capture shows no contact data leaving; a friend joins a crew with no link | Invite to join conversion, friend invites against links; time to first shared win |
| **3. Tonight's Story** | A 10am win is hidden at 7:59pm and shown at 8:00 viewer time; previews swap at 8 and back at 9am; teens show blocks only; a reaction lands on the block and survives the morning; Reply quotes and keeps its words; the poster's records are gone after the hard end; Hide and Report work | Weekly share of friend-having users who post; nights a story is opened; replies per story viewed; **guardrail: wins logged and crew sends must not fall more than 10% for story users**. If the tower loses, the story is wrong |
| **4. Together score** | Two phones agree; deleting a win lowers both; a "with" tag counts once; it outlives 14 days | Personal-crew sends a week, before and after; D30 for pairs with a score against without |

---

## 9. Decisions for Jayden

1. **The word:** "Story", with the row "Tonight's Story"? Recommended: yes, the word everyone knows.
2. **Unlock:** 8pm fixed, or sunset held between 7 and 9pm? Recommended: 8pm, sunset as the colour.
3. **An unlit ring before 8pm** on a friend with something waiting? Recommended: yes, no count; it is the anticipation.
4. **Audience:** every friend, or a Close Friends list? Recommended: every friend, plus question 5.
5. **Hide My Story From** one friend? Recommended: yes, one switch on their profile; it costs nothing (6.3).
6. **Personal crews and the five-crew cap:** Recommended: they do not count.
7. **Findable by default at 16+:** Recommended: on, with a Settings switch.
8. **Order:** Recommended: slices 1 and 2 after crews are live and compliance gaps 1 to 3 are closed, then 3, then 4.
