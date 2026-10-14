# Your checklist: everything outside the app (2026-10-13)

Only things I cannot do for you: they happen in an account, at the
registrar, in Procreate, or with a real friend and a real phone. Most
urgent first. Tick them off here.

Where I could not check whether something was already done, it says
**(check)**. This replaces the list of 2026-10-08; nothing on that one
was dropped.

## 1. This week

- [ ] **Push** whenever I say there are commits: `cd ~/Desktop/Strata && git push origin main`
      The site is whatever is pushed; nothing I change on it is live until you do.
- [ ] **Free some disk space, or move the repo off iCloud Desktop.** The Mac
      is 98% full (about 10 GB free). On 2026-10-13 iCloud evicted about
      4,000 of this repo's files to make room, which stalled a commit and
      slows every build while they download again. Either is enough:
  - free 30 GB or more (Xcode's DerivedData and old simulators are the
    usual big ones: Xcode, Settings, Platforms; and
    `~/Library/Developer/Xcode/DerivedData`), or
  - move `~/Desktop/Strata` to a folder iCloud does not manage (for example
    `~/Developer/Strata`) and tell me the new path.
- [ ] **Try the newest build on your phone**, then tell me to send it to
      Friends. What to look at:
  - A crew chat: plus, Plan. The plan stays in the chat, and on the crew's
    tower it is a checkbox block. Press it.
  - A crew chat: plus, Strip. Today's strip, then Send.
  - Add a Win with the keyboard up: press the block. The menu opens whole.
  - A repeating plan line: Edit, change the name, Done. Just Today or
    Every Time.
  - Memories: one "Shared with" album where there were two.
- [ ] **Two phones, one friend, ten minutes.** Nothing in crews has run on
      real iCloud between two people. Do these and tell me what happened:
  - Send an invite in Messages. Does it arrive as a card with the logo?
  - They tap it and join. Do they land in the crew?
  - You make a plan; they tap I'm In; they get a box on the crew's tower.
  - They finish it. Do you get "Name just did Workout"?
  - A win sent to two crews: is each crew told once?
  - A sticker on a win, and a strip sent to the chat.

## 2. somewins.xyz (about 20 minutes, in this order)

Done on 2026-10-13: the domain, GitHub Pages with HTTPS, and Associated
Domains. Invites are `somewins.xyz/join` from build 135. Two left: the
email, and the decision at the end.

- [x] **Namecheap**, Domain List, somewins.xyz, Manage, Advanced DNS.
  - Delete what is there for `@` and `www` (the parking redirect and the
    `www` CNAME to parkingpage.namecheap.com).
  - Add four **A** records, host `@`, values `185.199.108.153`,
    `185.199.109.153`, `185.199.110.153`, `185.199.111.153`.
  - Add one **CNAME**, host `www`, value `jlbetts-cpu.github.io`.
- [x] **GitHub**, the Strata repo, Settings, Pages, Custom domain: type
      `somewins.xyz`, Save. When the check goes green, tick **Enforce
      HTTPS**. Then `cd ~/Desktop/Strata && git pull`.
      Old github links keep working: GitHub forwards them.
- [x] **Apple Developer**, Certificates, IDs and Profiles, Identifiers,
      `JaydenBetts.Strata`: tick **Associated Domains**, Save.
- [x] **Tell me all three are done.** Then I make the new signing profile,
      switch the invite link to `somewins.xyz/join`, and a tapped invite
      opens the app with no web page in between. The card's thumbnail is
      already only the logo; the address under it becomes somewins.xyz.
- [ ] **Email:** Namecheap, Email Forwarding, `hello@somewins.xyz` to your
      own address. Tell me when a test mail arrives and I change the
      support address in the app (it is still your Hotmail).
- [ ] **Decide (checked live on 2026-10-13):** `docs/` is the website, so
      every planning note in it is a page on your domain. These all open
      for anyone today: `somewins.xyz/monetization-research` ("How Strata
      should make money"), `/launch-plan`, `/aso-plan`, `/launch-pack-log`,
      `/case-study`, and the specs under `/superpowers/specs/`. Say the
      word and I stop the site serving them: one line in `docs/_config.yml`,
      no file moves, and it can be undone. (They stay readable on GitHub
      for as long as the repo is public; that is a separate switch.)

## 3. Drawings (Procreate)

Black line on a clear background, exported as PNG, about 3000 px on the
long side, your pen's usual weight. Send them to me and I cut, clean and
fit them. In order of need:

- [ ] **November, for the top of Memories.** October has the skeleton and
      "Small wins still count". From 1 November that space is empty.
      One drawing and one short line of words. (Then one a month: December
      by 1 December.)
- [ ] **Head maker, no face found:** a figure holding a frame up to its own
      face. Drawn to show in **white** on a dark screen. The space is held
      open and empty today.
- [ ] **Camera not allowed:** a figure with a hand over the lens. Also
      **white** on dark. Used by the camera and the head maker.
- [ ] **Onboarding, six small corner marks**, one a page. The pages work
      without them; they are the one empty band left in the first run.
      Lowest priority.
- Already yours and in: the six category doodles, the sticker mark, the
  tip marks, the crews drawing ("Winning is better together") and its
  cheer, October.

## 4. App Store Connect

Entered on 2026-10-13 and read back: name, subtitle, description and
keywords, in three languages, on version 1.0. Still yours:

- [ ] **Screenshots** (6.9 inch iPhone at least). I can make the set from
      the simulator when you say which screens. Get a yes from any friend
      whose face is in one.
- [ ] **Choose the build** for version 1.0.
- [ ] **Support URL** and **Privacy Policy URL** (the github pages today,
      somewins.xyz after step 2).
- [ ] **Age rating:** yes to user-generated content and to messaging.
      Expect 13+.
- [ ] **App Privacy** answers. "Yes, we collect data"; every row is "not
      linked to you, not used for tracking". The rows are in
      `docs/crews-app-store-privacy.md`.
- [ ] **Agreements:** Paid Apps Agreement, banking and tax **(check)**.
- [ ] **Tips:** three consumables on version 1.0, `somewins.tip.small`
      $1.99, `.medium` $4.99, `.large` $9.99 **(check)**.
- [ ] **Availability:** United States, Canada, Australia, New Zealand
      (your earlier pick; it avoids the EU's published-address rule and
      the UK's safety paperwork).
- [ ] At the end of the description: "Terms of Use:" and the terms link.
      Keep Apple's standard licence agreement.
- App preview video: only footage recorded inside the app is allowed. The
  launch film is for TikTok and Instagram, not this slot.

## 5. Before 1.0 can ship with crews

- [ ] **CloudKit Console:** deploy `tools/cloudkit/full-schema.ckdb` and
      `crews-types.ckdb` to **Production** **(check)**, then file one
      Report from a phone and see it arrive (`tools/cloudkit/reports.sh`).
- [ ] **Tell me to switch crews on for the App Store.** Today crews are on
      only in TestFlight builds: a build from the App Store has no crews
      and an invite link does nothing in it. It is one line, after the
      two-phone test.
- [ ] After the app is live, the invite page's "Get Some Wins" button has
      to point at the App Store and not TestFlight. Send me the link.
- [ ] `Info.plist`: your TelemetryDeck app ID, and the App Store ID once
      the record has one. Send me both and I put them in. (Until then
      analytics send nothing and Rate on App Store stays hidden.)
- Know this: someone who declines to give an age is treated as 13 to 15,
  as the policy says, so an adult who declines sees friends' photos
  hidden unless Sensitive Content Warning is on.

## 6. Once strangers can join crews (an hour with a lawyer is worth it)

This is research, not legal advice.

- [ ] Register with NCMEC's CyberTipline as a service provider (18 U.S.C.
      2258A). A report of apparent child sexual abuse material must go
      there and be kept a year. Never forward or download it yourself.
- [ ] Look at reports every day (`tools/cloudkit/reports.sh`), act within a
      day; the app promises that. Delete reports older than a year. Ban
      with `tools/cloudkit/ban.sh`.
- [ ] TAKE IT DOWN Act: a "Removal request" email (it is in the Terms)
      means a non-consensual intimate image comes down within 48 hours.
- [ ] Ask about Texas SB 2420 and Apple's parental consent flow.

## 7. Launch material

- [ ] A written yes from every friend in the trailer or the screenshots.
- [ ] Keep the Pixabay download record for the film's music ("Product
      Launch", Monume).
- [ ] "Designed with ADHD brains in mind" is fine. Never "helps focus" or
      "treats". Only real testimonials, and say when one is a friend.
- [ ] TikTok and Instagram accounts for the app, if you want the name.

## 8. Calls I am waiting on from you (asked in chat)

- The planning notes on somewins.xyz (section 2): stop serving them, or leave.
- The landing page's two "Download on the App Store" badges open
  TestFlight until the app is on the Store. Fine for friends; Apple's badge
  rules want it to open the App Store, so swap the link the day it is live.
- Onboarding's first page: a plain hold drops a block but only a pulled
  block lets you go on. Let any block count, or keep it.
- Settings: Replays and Past Wins show as on before notifications were
  ever allowed. Draw them off until they are, or leave.
