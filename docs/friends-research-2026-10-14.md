# Adding friends (research, 2026-10-14)

The owner, verbatim: "are we working on adding friends on the app like how
snapchat or other social medias do it?"

Read-only pass over `~/Developer/Strata` at `7a493d3` (after Build 140).
Nothing in the app was changed to write this. It builds on
`docs/invites-research-2026-10-13.md` (which settled contact discovery as a
no) and does not repeat it. Tags, as the other research docs use them:
**(a)** a rule, guideline, paper or Apple's own docs, **(b)** seen in this
repo's code or in a shipping product's help pages, **(c)** inference. Sources
at the foot.

## The answer in six lines

1. **Not today, and nothing is in flight.** Friends exist only as "people in
   a crew with you". Adding one means New Crew and sending its link or its
   QR code. There is no list of your people, no way to add someone without
   making a crew, and no request to accept.
2. **The Snapchat model does not fit as a whole.** Usernames and search need
   a directory anyone can read, Quick Add needs a server that knows who knows
   whom, and contact sync needs a verified phone number. Each of those turns
   a small private app into one where strangers can find a 13 year old.
3. **Two parts of it do fit, with no server and no Console deploy.** Your
   people as a list (everyone you share a crew with), and **your own code,
   with your head on it**, the Snapcode idea, that a friend scans or taps to
   ask to add you. You accept or ignore.
4. **Friends are the list crews draw from, not a crew of two.** A crew of two
   already works for a one to one, but the five crew cap would make it a
   five friend cap.
5. **Recommended: build it in two steps.** Step 1, Your People (a list, no
   cloud change, a few days). Step 2, Your Code and requests (sealed
   requests on the existing `CrewItem` type, about two weeks with review and
   the two-phone test), after crews are live on the App Store.
6. **Never**: usernames with search, contact matching, Quick Add style
   suggestions, Add Nearby, friend counts.

---

## 1. What exists today

### 1.1 The social layer, in short (b)

| What | Where | Note |
|---|---|---|
| Crews: at most 5 a person, 8 people a crew | `Social/CrewModels.swift:25-33` (`CrewCaps`) | The owner's numbers, 2026-10-02 |
| Everything a crew holds is one record type, `CrewItem`, in the **public** database | `PublicCrewCloud.swift:5-26`; `tools/cloudkit/full-schema.ckdb:191-205` | Fields: `crew` (queryable string), `kind` (queryable string), `box` (sealed bytes), `a`/`b` (sealed assets). Anyone with iCloud may create; only the creator may change or delete; anyone may read, and what they read is sealed |
| One AES-256-GCM key per crew, carried only after the `#` of the invite link | `NotifyShared/CrewSeal.swift:4-40`, `Social/CrewKeys.swift:3-50` | `somewins.xyz/join#<crew>.<key>`; a universal link since build 135 |
| Pings for notifications: a plain `Ping` record with `crew`, `kind`, `recipient`, `sender` (queryable) | `full-schema.ckdb:84-99`, `PublicCrewCloud.swift:1820-1910` | Kinds today: win, reaction, message, joined, milestone (`NotifyShared/CrewNotes.swift:49`) |
| Identity: one profile id per person, kept in the private database and the Keychain | `PublicCrewCloud.swift:120-180` (`prepare`), `CrewVault` | No account, no username, no phone number |
| Block: a set of profile ids on this phone; their wins, names, heads and lines disappear | `SocialStore.swift:443-485` | Local only. It does not stop a blocked person holding a crew's link from joining it |
| Report: a create-only `Report` record read by the Moderator role, naming the iCloud account behind the thing | `Social/CrewSafety.swift:40-110` | Kind of thing rides in the title ("Person: Sam"), so new subjects need no schema change |
| Ban list: `Ban` records written by the Moderator, read by every phone | `PublicCrewCloud.swift:1774-1818`, `tools/cloudkit/ban.sh` | Removes an account everywhere |
| Gate before any crew: iOS 26, rules agreed, Declared Age Range answered, not under 13 | `Social/CrewGate.swift`, `Social/CrewAge.swift` | 13 to 15: no photographs leave the phone |

### 1.2 Every way to "add a friend" today (b)

| Way | Path | Mutual consent |
|---|---|---|
| New Crew, Invite, share sheet | Crews tab, compose glyph top right (one way since `d760168`, the owner: "Merge into one") | Yes: the friend has to open the link and agree |
| Show a Code | Crew Info, QR glyph (`CrewCodeSheet`) for a friend beside you | Yes |
| First-win tip | "Your win is up. Who else should see it?" (`FirstWinInvite`) | Yes |
| A one to one | A crew of two. Works today, and uses one of the five crew slots | Yes |

What is missing, measured against what the owner asked about:

- **No list of your people.** Someone in three of your crews appears three
  times, once per crew, and nowhere as one person.
- **No way to bring a crewmate into another crew from inside the app.** You
  send the new crew's link through Messages like anyone else's. The earlier
  research proposed a sealed chat line for this (`invites-research` part 4,
  item C); it is private only in a crew of two.
- **No personal code.** Every code and link is a crew's, so "add me" always
  means "join this group".
- **No request to accept.** Opening a link is the consent; there is nothing
  to answer.

### 1.3 Owner rules this has to keep (b)

- No new CloudKit fields or record types without his deploy in CloudKit
  Console (Production rejects unknown types, and a deployed type is
  permanent; `invites-research` [C3][C4]).
- Crew cloud code gets an independent review and the two-phone test before
  it ships (`tasks/launch-checklist.md` section 5).
- No public feed. Small private circles (`strata-social-direction`).
- Never surveillance language: nothing like "see who's here", "who's
  online", "find people" (`docs/voice.md` line 93).
- No counts of people, no tallies, nothing that names the caps
  (`invites-research` "Avoid").
- The head is identity, mandatory, one `PersonHead` component
  (`docs/heads-as-identity-2026-10-14.md`).
- The audience is college students; App Review 1.2 (report, block) and
  5.1.1; the age rules in `CrewAge`.
- His corner calls: he did not want an add-friends button in a crew's top
  right ("its already in the middle"), and merged Invite a Friend into New
  Crew. A friends feature needs a home that is not another corner button.

---

## 2. How others add friends

### 2.1 The products

| Product | How you find someone | Request and accept | Code or link | Contacts | Suggestions | Tag |
|---|---|---|---|---|---|---|
| **Snapchat** | Search by username or name | One-way add; the other side sees "Added Me" and adds back to become friends | **Snapcode**, a QR in your profile next to your name, can be shared or saved; a profile link `snapchat.com/add/<username>` | Add from Contacts (phone number matched on Snap's servers) | Quick Add, now **Find Friends**, from mutual friends and contacts. Teens are only suggested to people with numerous mutual friends or who have them in an uploaded contact book; requests between teens and strangers without mutual friends are delayed and investigated | (b) [S1][S2][S3][S4][S5] |
| **BeReal** | Search by username | Friend request, accepted by the other side | Share your username or a profile link | "Add Your Contacts" list, shown only when there are matches | "People You May Know", including friends of friends; dismissible. Help centre: do not accept requests from people you do not know | (b) [B1][B2][B3] |
| **Locket** | Username (newer builds ask you to "claim your username") | Mutual | "Your personalized invite link" | Phone number sign-up; contacts were once required (2022) | Little | (b) [L1][L2][L3]. A **20 friend cap**, per its listings (an older one said 5) |
| **Instagram Close Friends** | Not a way to add anyone: a private subset of people who already follow you | None. Nobody is notified when added or removed, nobody can ask to join, and nobody but you can see the list | n/a | n/a | n/a | (b) [I1][I2] |
| **Game Center** (Apple) | Friend requests sent **through Messages** | Request, accepted in Game Center; an inbox for missed ones (WWDC21) | n/a | Through Messages | Games see your friends only if you and each friend grant it (`loadFriends` and `GKFriendsAuthorizationStatus`) | (a) [G1][G2] |
| **NameDrop** (Apple) | Bring two iPhones together | Each side chooses to send its card or only receive | n/a | Exchanges only name, the chosen number or email, and the Contact Poster | None | (a) [N1][N2] |
| **Shared with You** (Apple) | Not adding: links friends send you in Messages show up inside your app, with "From Sam" | n/a | Universal links of the app's own domain | Developers report it surfaces only senders in your Contacts, and only if Shared with You is on for the app and the conversation | n/a | (a) [W1][W2], contacts-only (b, forum and blog) [W3][W4] |
| **Limited Contacts access** (iOS 18) | `ContactAccessButton` adds one contact at a time from an in-app search; full access stays optional | n/a | n/a | Grants access to the picked contacts only | n/a | (a) [C1][C2] |
| **PermissionKit** (iOS 26) | For a child in Family Sharing with Communication Limits on: the app asks, the child sends the question to a parent in Messages, the parent approves or declines | n/a | n/a | n/a | n/a | (a) [P1][P2]. Returns a default answer when the child is not in Family Sharing or limits are off |

### 2.2 What the pattern actually is

- **Every "Snapchat way" has the same three parts**: a handle anyone can
  type (username), a code you hand to someone (Snapcode, link), and a
  server that matches people (contacts, Quick Add) (b). Some Wins can do the
  second part well and the first and third badly (section 3.2).
- **Requests are one-way adds that become mutual.** Snapchat's "Added Me"
  and BeReal's request are the same shape: one side asks, the other answers,
  nothing is shared until both have (b).
- **The safety work all sits on discovery.** Snap's teen rules restrict
  *suggestions* and *requests from strangers*; BeReal's only safety line is
  "don't accept requests from people you don't know" (b) [S3][S4][B2].
  Nothing in those rules is needed when the only way to reach someone is a
  code they handed you (c).
- **Small-circle apps cap friends.** Locket at 20 (b) [L1]; Some Wins already
  caps crews at 8 people and 5 crews (b). A friends list that crews draw from
  does not need a visible cap, but a quiet one bounds abuse (section 4.4).
- **Apple's own answers are code, proximity and Messages**, never a
  searchable directory: NameDrop for beside you, Game Center requests through
  Messages, Shared with You for links already sent (a).

### 2.3 The law and the guidelines, for this feature

- **Discovery is what most state "social media" laws key on.** The privacy
  review found most define a platform by public profiles or discovery of
  strangers; crews today have neither (`privacy-law-review` 2.4) (c).
  Usernames with search would add discovery; codes do not (c).
- **Apple's age rating now asks about social media capabilities** (from
  September 2026), which feeds a Social Media descriptor and iOS 27 Time
  Allowances (`privacy-law-review` appendix) (a). A friends graph is worth
  re-answering that questionnaire for, honestly (c).
- **5.1.1(v)**: an app that lets people create an account must let them
  delete it in the app (a) [A1]. A username is close to an account; a code
  that can be reset is not (c).
- **5.1.1(iii)/(iv) and 5.1.2(iv)/(v)**: prefer pickers over full access,
  never force consent, no contact database of your own, no bulk invites (a)
  [A1]; already applied in `invites-research` section 3.
- **1.2**: report, block, a filter, contact info (a) [A1]. Any new thing a
  person can send (a request, their name, their head) needs Report and Block
  on it (c).
- **Texas SB 2420** (in force) names PermissionKit for significant changes;
  a new way for minors to be contacted is the kind of change a lawyer should
  be asked about (`privacy-law-review` 2.3, appendix) (c).

---

## 3. Design for Some Wins

### 3.1 What "friends" means here

Three shapes were considered.

| Shape | What it is | Verdict |
|---|---|---|
| **A. A friend is a crew of two** | Add a friend means start a two-person crew. Works today | **No as the definition.** Five crews means five friends, a one to one and a group compete for the same slot, and a friends list made of crews is just the Crews list again (c) |
| **B. Friends are a list crews draw from** | Your People: everyone you share a crew with, plus anyone who added you by your code. From it you start a crew with chosen people, in one sheet, and they are asked in the app | **Yes.** It answers "who to add" before you commit to a crew, matches how people think ("friend", not "crew"), and needs no change to the crew model (c) |
| **C. Friends as followers** (Instagram) | One-way: you see what they post | **No.** A public feed by another name, ruled out (b) |

So: **friends are people, crews are where you share.** A one to one is still
a crew of two, started from a friend's row. Whether that pair counts against
the five is his call (section 6).

### 3.2 Username vs code vs contacts

| Way | Can it be built without a server? | Privacy and safety | Verdict |
|---|---|---|---|
| **Username and search** | Technically: a world-readable record per handle, unique by record name, creator-only writes. CloudKit takes the first writer, so names can be claimed | Anyone can list every handle (the public database lets any user query a type), so it is a directory of every user, teens included. Squatting and impersonation with no one to settle them but him. Every handle needs the slur filter. Anyone can send a request to anyone, which is the stranger-contact problem Snap had to fix for teens [S3]. Arguably an account (5.1.1(v)) | **No** (c) |
| **Contacts** | No. The app cannot read its own user's number, CloudKit discoverability is gone since iOS 17, and hashed numbers in a public database are enumerable (`invites-research` section 3) | Adds Phone Number and maybe Contacts to the privacy label; the 2012 Path episode | **No** (settled 2026-10-13) |
| **Your code** (Snapcode style) | **Yes**: a link and a QR that carry a public key; requests are sealed to it and dropped in a letterbox on `CrewItem` (section 4) | Reachable only by people you handed it to. Reset it and old copies stop working. No discovery, no directory | **Yes** |
| **Shared with You** | Yes: an entitlement and `SWHighlightCenter` | Apple-mediated, user-controlled; the app never sees conversations (a) [W1] | **Yes, small, later**: shows crew links friends sent you in Messages on the Crews tab, so "open the link again" becomes a row with "From Sam". Contacts-only per developers, test on a device |
| **Nearby** (Snap's Add Nearby, NameDrop) | Possible with Nearby Interaction or Multipeer | Snap's version lets strangers nearby see you (b) [S1] | **No.** Show a Code already covers "beside you" |

### 3.3 The code, in the app's own language

- **Your Code** lives on your profile (Memories, the profile button), as
  Snapchat's sits in its profile [S2]. It is a QR with **your head in the
  middle**, the way a Snapcode carries a Bitmoji: the head is identity
  (`heads-as-identity`), and it is the one thing no other app's code has (c).
- Under it: **Share My Code** (share sheet, the link `somewins.xyz/add#...`)
  and **Reset My Code** (new key; anything sent to the old one is ignored).
- **Scan**: the Camera app already reads QR codes and the link is a
  universal link, so no scanner is needed in the app (b, the crew code works
  this way today).
- No new corner button. The places are the profile (your code), the New
  Crew sheet (your people), and a quiet row on the Crews tab when someone
  has asked (requests).

Copy, per `docs/voice.md` (Title Case buttons, no exclamation marks, no long
dashes, nothing counted, nothing watched):

| Moment | Words |
|---|---|
| Profile row | **Your Code** |
| Code sheet line | "Friends can scan this to add you." |
| Request row on Crews | "Sam wants to add you." **Add Back** / **Not Now** (the hold menu: **Block**, **Report**) |
| Push | "Sam wants to add you." |
| After Add Back | "You and Sam are friends." (shown once, not notified) |
| New Crew sheet, section | **Your People** |
| A crew sent to you | "Sam started Roommates with you." **Join** / **Not Now** |

Avoid: "people you may know", "X is on Some Wins", "3 friends", "online",
"active now", "last seen".

### 3.4 Requests, accept, block, report

- **Ask**: opening someone's code shows their head and name (from the code
  page, before anything is sent) and **Add**. That sends one sealed request
  carrying your name, your head and your own reply key.
- **Accept** (Add Back) sends a sealed yes to the asker's letterbox. Both
  phones keep the other as a friend. Nothing is shared between friends until
  they are in a crew together: a friend is someone you can pull into a crew,
  not a feed (c).
- **Not Now** hides the request on this phone. It is never told to the
  asker (Snap's and BeReal's pending state is the same silence) (b).
- **Block** on a request, a friend's row or a crew face: the existing local
  block, plus every later request and crew invitation from that profile is
  dropped unseen. Block also removes them from Your People.
- **Report** on a request: the existing `Report` record, title "Request:
  Sam", carrying the head, naming the asker's iCloud account (the record's
  creator, which every reader can see, as `account(of:)` does today). The
  ban list then applies to requests too.
- **Remove** a friend: local, silent, and a sealed "removed" note so their
  phone drops you too.
- **The gate**: a request can be sent and answered only with `CrewGate ==
  .open` (iOS 26, rules, age). Joining a crew from a friend's invitation still
  goes through `SocialStore.accept`, unchanged (b).
- **13 to 15**: codes cannot be searched for, so the Snap problem (strangers
  reaching teens) mostly does not arise (c). Still his call (section 6):
  codes for everyone 13+, or 16+ only. If teens keep codes, consider
  PermissionKit for a request to a teen with no crew in common, when the
  teen is in Family Sharing with Communication Limits on [P1].

---

## 4. Minimum viable build, no server

### 4.1 Step 1: Your People (no cloud change)

- A list on the New Crew sheet (and a Your People page off the profile):
  every person in any of your crews, once each, by profile id, with their
  head (`PersonHead`), name and the crews you share. Blocked people are
  absent (`SocialStore.visible` already strips them).
- **Start a Crew With**: pick heads, then New Crew as today. The invitation
  goes out by the share sheet, pre-addressed in the sense that the sheet's
  people row already ranks who you text (b). No in-app delivery yet.
- Block and Report on a row, reusing `CrewSafety.Subject.person` with the
  crew you share.
- Tests: dedupe across crews, blocked people absent, a person who left every
  shared crew (kept or dropped: section 6).
- **Effort: small**, two to three days with tests. **Risk: low.** No
  CloudKit, no review needed beyond the usual.

### 4.2 Step 2: Your Code and requests (no new record type)

The key finding of this pass: **`CrewItem` is already a generic sealed
envelope** (`crew` and `kind` are free strings, `box` is opaque bytes), so a
letterbox needs **no new record type, no new field and no Console deploy**
(b, `full-schema.ckdb:191-205`). New *values* in existing string fields are
not a schema change (a, CloudKit schema is fields and types) [K1].

| Piece | How | Cloud change |
|---|---|---|
| Your key pair | A Curve25519 key pair made on the phone, kept in the Keychain beside the crew keys and backed up by `CrewVault`, so a reinstall keeps your friends (c) | None |
| Your code | `somewins.xyz/add#<public key, base64url>` (43 characters), and the same as a QR with your head | Site: an `add` page beside `join.html`, and the `apple-app-site-association` path |
| Your letterbox | `CrewItem` records with `crew = "mail-" + first 16 bytes of SHA-256(public key)`, so the code alone tells a sender where to write | None (a new value) |
| A request | `kind = "Ask"`, record name from `CrewItemRecord.name(crew:kind:name:)`, `box` sealed to your public key with **HPKE** (CryptoKit, iOS 17+) [K2], bound to the record name like every box. Inside: the asker's profile id, name, reply key; their head pack in `a`, sealed with a content key from the box | None |
| An answer | `kind = "Yes"` or `"Removed"` in the asker's letterbox | None |
| A crew invitation to a friend | `kind = "Crew"` in the friend's letterbox: the crew's link, HPKE-sealed to that friend alone. **Private even in a crew of eight**, which the chat-line idea was not (`invites-research` item C) | None |
| Crewmates without codes | Each member adds their public key to their own sealed `Member` box (a new key inside the box, read as an extra field; older builds ignore keys they do not know, `CrewRecords.member` reads by name) | None in CloudKit; a change to the `memberKeys` contract and `CrewRecordTests` |
| A push for a request | A `Ping` with `kind = "ask"` and `recipient` set to a one-way tag of your letterbox (as pings tag today); a new `CKQuerySubscription` on it. The extension writes "Sam wants to add you." | None (subscriptions are not schema). The extension learns one kind |
| Reading | One query, `crew == mail-...` and modified since last look, on open and on that push | None |

**Effort: medium to large**, roughly two weeks with tests, an independent
review of the cloud code and the two-phone test (c, scaled from the crews
work in `tasks/unification-log.md`). **Risks**, each with its answer:

1. **A letterbox cannot be emptied by its owner.** Only a record's creator
   may delete it (b, the security roles), so declined and spam requests stay
   until the asker's app deletes its own. Answer: askers delete their Ask
   after an answer or 14 days; the reader asks only for what changed since
   it last looked; Reset My Code moves to a fresh letterbox (c).
2. **Spam from a leaked code.** Anyone with it can write. Answer: Reset My
   Code, Block, the ban list by iCloud account, and a quiet ceiling on
   pending requests shown (say the newest 20), never a number on screen (c).
3. **Metadata.** The letterbox is world-readable sealed bytes: someone
   holding your code can see that requests arrive and which iCloud accounts
   wrote them, never what they say (c). Same class as crews today
   (`privacy-law-review` 6.5). One line in the policy.
4. **Reusing `CrewItem` for something that is not a crew.** It works, and it
   is the zero-deploy path. The cleaner alternative is a dedicated type (say
   `Letter`, same fields, same roles), which needs his Console deploy and is
   permanent. His call (section 6).
5. **Older builds**: they never query `mail-` values, so they see nothing
   (b, crews are queried by their own ids). A friend on an old build simply
   gets no request until they update (c).
6. **The privacy policy and label** gain one paragraph (a code, a letterbox,
   sealed) but no new data type: name, head and an identifier are already
   declared (`privacy-law-review` 6.5) (c).

### 4.3 What it deliberately does not do

- No search, no username, no directory, no suggestions, no contacts, no
  nearby.
- No friend activity outside crews: friends do not see each other's wins
  until they share a crew (c). This keeps "no public feed" true.
- No counts: not of friends, not of requests, not of mutual friends.

### 4.4 The cap

Friends need no visible cap. A quiet ceiling (for example 50 friends, the
newest 20 pending requests) bounds a letterbox's cost and a spammer's reach
(c). Locket's 20 is the nearest precedent [L1]. Never shown as a number.

---

## 5. Options, ranked

| Rank | Option | Effort | Cloud change | Main risk | Verdict |
|---|---|---|---|---|---|
| 1 | **Your People**: one list of everyone you share a crew with; Start a Crew With from it | Small (2 to 3 days) | None | A person kept after leaving every shared crew could read as being kept track of; offer Remove | **Do first** |
| 2 | **Your Code** with your head, requests, Add Back, private crew invitations to friends | Medium to large (about 2 weeks with review and two phones) | None on `CrewItem`, or one new type if he prefers | Letterbox spam and cleanup (4.2); needs an independent review | **Do after crews are live on the App Store** |
| 3 | **Shared with You** on the Crews tab: crew links friends sent you in Messages, with "From Sam" | Small to medium (entitlement, device-only testing) | None | Works only for senders in Contacts, per developers; invisible when off | Good follow-up; it shrinks the install gap without the clipboard |
| 4 | Crew of two as the one to one, started from a friend's row | Tiny on top of 1 | None | The five crew cap | Yes, with his cap decision |
| 5 | App Clip that keeps an invitation across install (`invites-research` D) | Large | None | New target, App Store Connect setup | After launch |
| 6 | Usernames with search | Large plus ongoing moderation | New type or a new use of the public database as a directory | Stranger contact for teens, squatting, state-law "discovery", 5.1.1(v) | **No** |
| 7 | Contact matching, Quick Add | Large plus a server | Server, SMS verification | Label, policy, teen safety, 5.1.2 | **No** (settled 2026-10-13) |

### Recommendation

**Answer him: yes, the Snapchat idea without the Snapchat machinery.** Build
**Your People** now (no cloud change, a few days), and **Your Code** with
your head on it plus requests next, on the existing `CrewItem` envelope so
there is nothing to deploy, behind an independent review and the two-phone
test, after crews are switched on for the App Store. No usernames, no
contacts, no suggestions.

---

## 6. Needs his decision

1. **Friends as a list crews draw from** (recommended), or a friend as a
   crew of two everywhere?
2. **Does a one to one crew count against the five?** If yes, friends who
   want a pair space use a slot. If no, a separate quiet ceiling for pairs.
3. **Zero-deploy (`CrewItem` with a `mail-` value) or a new `Letter` record
   type** that he deploys in CloudKit Console (cleaner, permanent)?
4. **Codes for 13 to 15**, or 16+ only? (No search either way, so the risk
   is lower than Snap's; PermissionKit is available if he keeps teens in.)
5. **Someone who has left every shared crew**: stays in Your People until
   removed, or drops out?
6. **When**: Step 1 before the App Store launch with crews, Step 2 after
   (recommended), or both after?
7. **Confirm no usernames**, so a later pass does not reopen it.

---

## Sources

Apple
- [A1] App Review Guidelines (1.2, 5.1.1, 5.1.2): https://developer.apple.com/app-store/review/guidelines/
- [G1] Connecting players with their friends in your game: https://developer.apple.com/documentation/gamekit/connecting-players-with-their-friends-in-your-game
- [G2] `loadFriends(_:)` and WWDC21 "What's new in Game Center" (friend requests through Messages, the requests inbox): https://developer.apple.com/documentation/gamekit/gklocalplayer/loadfriends(_:) ; https://developer.apple.com/videos/play/wwdc2021/10066/
- [N1] Use NameDrop on iPhone: https://support.apple.com/guide/iphone/namedrop-iphone-share-contact-info-iph1b6c664b7/ios
- [N2] Secure NameDrop: https://support.apple.com/guide/personal-safety/secure-namedrop-ips97e16d3b1/web
- [W1] Shared with You, WWDC22 session 10094 (notes): https://nonstrict.eu/wwdcindex/wwdc2022/10094/ ; https://developer.apple.com/documentation/sharedwithyou
- [W2] Making your app content shareable: https://developer.apple.com/documentation/sharedwithyou/making-your-app-content-shareable
- [W3] Forums, "HighlightCenter returns no links" (contact and per-conversation checklist): https://developer.apple.com/forums/thread/707873
- [W4] Implementing Shared With You in SwiftUI (contacts only, device testing): https://digitalbunker.dev/shared-with-you/
- [C1] `ContactAccessButton`: https://developer.apple.com/documentation/contactsui/contactaccessbutton
- [C2] Meet the Contact Access Button, WWDC24 10121: https://developer.apple.com/videos/play/wwdc2024/10121/
- [P1] PermissionKit: https://developer.apple.com/documentation/permissionkit
- [P2] WWDC25 session 293 (PermissionKit): https://developer.apple.com/videos/play/wwdc2025/293/
- [K1] CloudKit schema and deployment (record types and fields, not values): https://developer.apple.com/videos/play/wwdc2021/10117/
- [K2] CryptoKit HPKE (iOS 17+): https://developer.apple.com/documentation/cryptokit/hpke ; https://developer.apple.com/documentation/cryptokit/hpke/sender

Products
- [S1] Snapchat, How to Add Friends: https://help.snapchat.com/hc/en-us/articles/7012328615828-How-to-Add-Friends-on-Snapchat
- [S2] Snapchat, What is a Snapcode / Share My QR Code: https://help.snapchat.com/hc/en-us/articles/7012342798612-What-is-a-Snapcode ; https://help.snapchat.com/hc/en-us/articles/7012378618388-How-to-Share-My-QR-Code-on-Snapchat
- [S3] Snapchat, What happened to Quick Add (Find Friends, teen limits): https://help.snapchat.com/hc/en-us/articles/34691800487316-What-happened-to-Quick-Add
- [S4] Snap, new safeguards (2023): https://values.snap.com/news/new-safeguards-for-snapchatters-2023 ; TechCrunch (2024): https://techcrunch.com/2024/06/25/snapchat-introduces-new-safety-features-to-limit-strangers-contacting-users/
- [S5] Snapchat, sharing a friend's Snapcode or profile link: https://help.snapchat.com/hc/en-us/articles/7012410433684-How-to-View-and-Share-a-Friend-s-Snapcode
- [B1] BeReal help, adding friends: https://help.bereal.com/hc/articles/7537949847069
- [B2] BeReal help, friend requests and suggestions: https://help.bereal.com/hc/articles/7350581733277
- [B3] BeReal help, friends of friends: https://help.bereal.com/hc/articles/16425353662365
- [L1] Locket listing (20 friend cap): https://appstore-library.rotato.app/ios/app/com.locket.Locket ; release notes (claim your username, personalized invite link): https://apkmirror.com/apk/locket-labs-inc/locket-widget/locket-widget-1-182-2-release
- [L2] TechCrunch on Locket onboarding (2022): https://techcrunch.com/2022/01/11/locket-an-app-for-sharing-photos-to-friends-homescreens-hits-the-top-of-the-app-store
- [L3] Locket App Store page: https://apps.apple.com/us/app/1600525061
- [I1] Instagram Close Friends, how the list works (secondary): https://www.inro.social/blog/what-are-instagram-close-friends
- [I2] Instagram Close Friends (secondary): https://www.guidingtech.com/instagram-close-friends/

In the repo: `Strata/Social/PublicCrewCloud.swift`, `SocialStore.swift`,
`CrewSafety.swift`, `CrewKeys.swift`, `CrewModels.swift`, `CrewGate.swift`,
`CrewAge.swift`, `CrewRecords.swift`, `NotifyShared/CrewSeal.swift`,
`NotifyShared/CrewNotes.swift`, `tools/cloudkit/full-schema.ckdb`,
`docs/invites-research-2026-10-13.md`, `docs/privacy-law-review-2026-10-14.md`,
`docs/heads-as-identity-2026-10-14.md`, `docs/crew-corner-new-feature-2026-10-14.md`,
`docs/crews-list-corner-research-2026-10-14.md`, `docs/voice.md`,
`tasks/launch-checklist.md`.
