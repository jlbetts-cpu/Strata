# Instagram sharing: what ships, what the research says, what to change

Written 2026-10-14 from the owner's ask: "I want the app to also be more
sharable in terms of on instagram". Research only; no Swift was changed.
Tags as in the other research docs: (a) published spec or data, (b) what a
real app does, (c) inference. Audience is college students, so the target is
the Story first, the feed second.

## 1. What exists now

Every way a picture or video leaves the app.

| Surface | Where | What leaves | Size and shape | Mark on it |
|---|---|---|---|---|
| **Photo strip, posed** | `Strata/Views/Strip/StripStory.swift:89-106` (render), `:272-283` (share), `:314-321` (file) | A transparent PNG of the strip at the pose you turned it to, trimmed to the paper, named `Some Wins <day>.png` | 220pt strip at up to 5x, long side held near 4200px (`:47-50`, `:102`). Shape follows the strip, roughly 1:2.5 to 1:4, not 9:16 | Wordmark and date on the strip's foot (`StripView.swift:118-140`). No name, no link, no QR, by his Launch Pack call |
| Strip, saved flat | `StripBooth.swift:585-602`, `:660-667` | Flat transparent PNG | 360pt at 4x, 1440px wide | Same foot |
| Strip to a friend | `StripMessage.swift:24-57` | Messages compose with the PNG and "Today was a good one. Some of it's in here." plus `https://somewins.xyz/` | n/a | The app's page link, never a crew link |
| Strip into a crew | `CrewStripShare.swift:33-62` | Flat PNG as a chat picture | 3x of 120pt | n/a |
| **Replay video** | `ReplayVideoExporter.swift:9`, `:44-47`, `:287-301`; shared at `ReplayView.swift:846-895` | MP4, H.264 + AAC landings, 30fps, 8 Mbps | 1080x1920 (9:16). Day up to 12s, week 18s, month 28s, each plus a 2s hold (`ReplayScript.swift:142-145`) | None ("No watermark", `ReplayCard.swift:4`). Count and numeric range at the top |
| Replay still | `ReplayCard.swift:86-92` | PNG, used as the share sheet's preview frame | 1080x1920 | None |
| Tower card | `ShareTowerCard.swift:37`, `:105-128` | 9:16 tower on the warm ground | 1080x1920 | None, on purpose (`:24-27`) |
| Photo viewer | `PhotoViewer.swift:449-455` | One photo via `ShareLink` | The photo | None |
| Chat picture | `Crews/ChatPictureViewer.swift:98-104` | Your own chat picture or strip via `ShareLink` | As sent | None |

Findings that matter for Instagram:

1. **Nothing talks to Instagram directly.** Every share goes through the
   system sheet (`UIActivityViewController`). `Info.plist` has no
   `LSApplicationQueriesSchemes` and there is no Meta App ID. This was a
   decision: `docs/crew-plus-design.md:134-136` lists "Instagram's own sticker
   hand-off" under what not to build, because it needs an app registered with
   Meta.
2. **The tower card has no way out.** It renders at a true 1080x1920 but is
   only used as the picture on a crew invite link (`MainAppView.swift:795-804`,
   `FirstWinInviteCard.swift:103`, `CrewSharing.swift:25-31`). The root
   `CLAUDE.md` still says the tower header carries a share button; no such
   button exists in the code.
3. **The strip is not a Story shape.** It leaves as a clear-background cut-out.
   That is right for "drop it onto your own Story", but through the share sheet
   Instagram decides what goes behind it (c, untested on his phone).
4. **The develop video does not exist.** `docs/launch-plan.md:19-22` and its
   app table item 2 call for "a short video of it developing: the motion is the
   hook". Only the replay has a video.
5. **The replay's story insets are thin.** 48pt top and bottom
   (`ReplayCard.swift:22-28`) is 144px at 1080x1920. Instagram's own chrome
   covers more than that (section 2).
6. **The Instagram destination is never counted.** `Analytics.swift:401` has a
   `.instagram` case, but the strip signals `.other` when the sheet OPENS
   (`StripStory.swift:273`), before anything is chosen. Share rate by
   destination, the launch plan's metric (`launch-plan.md:91`), cannot be read.
7. **A crew's strip can be posted to Instagram.** The booth opens the same
   composer for `.crew` strips (`StripBooth.swift:157-160`, reached from
   `ChatPlus.swift:389`, `CrewChatSheet.swift:341`, `CrewInfoSheet.swift:183`),
   and a crew strip is made of friends' photos (`CrewStrip.swift:14-27`). Only
   the crew rows are limited to your own strip (`StripStory.swift:275`).
8. **Location does not leak, as far as the code shows.** Every shared picture
   is a fresh `ImageRenderer` drawing, saved photos are re-encoded with no
   metadata (`ImageManager.swift:401-417`), and the video writer adds no
   metadata items. Worth one check with `exiftool` on an exported file before
   launch (c).

## 2. What the research says

**The Stories hand-off (a).** Meta's iOS spec: put data on `UIPasteboard`
under `com.instagram.sharedSticker.backgroundImage`,
`com.instagram.sharedSticker.stickerImage`,
`com.instagram.sharedSticker.backgroundVideo` (H.264 or H.265, up to 1080p,
**20 seconds**, under 50 MB), and `backgroundTopColor` /
`backgroundBottomColor` as hex strings, then open
`instagram-stories://share?source_application=<Meta App ID>`. Since January
2023 an App ID is required or the person sees "this app doesn't support
sharing to Stories". `instagram-stories` must be in
`LSApplicationQueriesSchemes`. Background minimum 720x1280 at 9:16; sticker
recommended 640x480; with a sticker and no colours the ground is `#222222`.
Meta's sample expires the pasteboard after 5 minutes. [M1]

**The Reels hand-off (a).** `instagram-reels://share`, keys
`backgroundVideo`, optional `stickerImage`, and
`com.instagram.sharedSticker.appID`. Video 3 to 60 seconds. The app must be
**live** before people can share this way. [M2]

**No link travels (a, c).** The current Stories spec lists no attribution or
content URL key for iOS [M1]. Anyone who wants the app from a Story asks, or
the poster adds Instagram's own link sticker, which every account has had
since October 2021 [L1].

**Safe zones (a, sources disagree).** Stories: keep type and faces out of the
top 14% (about 250 to 270px of 1920) and the bottom 18 to 35% (340 to 670px;
the larger number is Meta's ad figure for Reels-style overlays) and about 65px
each side. [S1][S2][S3]

**Watermarks (b).** Instagram does not recommend Reels carrying OTHER apps'
logos (the 2021 TikTok penalty), but Mosseri said a creator's own logo is
fine. A Some Wins mark on a video the person posts is the "other app" case
when it reaches Reels; on a Story it only affects the poster's taste. [W1][W2]

**What spreads (b, c).**
- **Spotify Wrapped:** each card is 9:16, stands alone, has its own share
  button, and says something about the person; specific enough to feel
  personal, general enough to be safe to post. [P1][P2]
- **Strava:** the stats leave as a **sticker** laid over the person's own
  photo inside Instagram, not a finished picture. The picture is theirs; the
  app supplies the proof. [P3]
- **BeReal, Locket:** no designed Instagram card. People repost by hand, and
  Locket's monthly recap video is the thing that travels. The format did the
  work, and Instagram copied BeReal's dual camera. [P4][P5]
- **Letterboxd:** shares a film to Stories as a poster card; reported to drop
  the rating at times (b, weak source). [P6]
- **Duolingo:** "thousands share their streaks every day", from a celebration
  screen, not a share-first design (b). [P7]
- Partiful: nothing citable found; left out.

The pattern (c): the share is **one tap from the moment of pride**, the
object is **the person's own thing** with the app's mark small, and the
**sticker** form wins on Stories because it lets the person compose. The strip
already is that object. What it lacks is the one tap and the motion.

## 3. Recommended changes, ranked

**1. "Instagram Stories" as a row in the strip's existing share sheet.**
A `UIActivity` beside Text a Friend and the crews, so it is still one Share
button. It puts the posed transparent PNG on the pasteboard as `stickerImage`
(scaled to about 1080px on the long side) with `backgroundTopColor` and
`backgroundBottomColor` taken from the paper, and opens Instagram's Story
editor with the strip as a movable sticker. The person can drop a photo
behind it, resize it, add a link sticker. Shown only when Instagram is
installed, and only for your own strip (see 4).
Effort: small, about a day. Owner provides: a **Meta App ID** (free, a
developer account at developers.facebook.com, one app, no review needed for
Stories). **Needs his decision**: it reverses the "would not build" line in
`crew-plus-design.md:134-136`.

**2. The strip's develop as a short 9:16 video.** The shake and develop the
booth already plays, rendered with the `ReplayVideoExporter` pattern at
1080x1920, 6 to 10 seconds, so it fits Stories' 20 second hand-off and Reels'
3 second minimum. Offered beside the still in the composer. The launch plan
ranks it High impact.
Effort: medium, 3 to 5 days. **Needs his decision**: what stands behind the
strip (the warm ground, the paper colour, or flat white; his "flat ground"
rule rules out light and vignettes), and whether the booth's sound comes too.

**3. Move the replay's type and base out of Instagram's chrome.** Top inset
48pt to about 84pt (252px), bottom 48pt to about 112pt (336px)
(`ReplayCard.swift:22-28`). Today the count and the range sit under the
Story's progress bar and account row. Also: a month video runs up to 30
seconds, over the 20 second Stories hand-off, so the replay should keep using
the share sheet, not the pasteboard.
Effort: small, but the composition changes, so it needs a before and after
screenshot to him. Owner provides: one test post from his phone.

**4. Your own strip only, for one-tap Instagram.** A crew's strip is friends'
photographs. Either hide the Instagram row (and ideally the whole outward
sheet) for `.crew` strips, or keep it and say so. Effort: tiny.
**Needs his decision**: hide outward sharing of crew strips, or allow it.

**5. Count where shares actually go.** Use the sheet's
`completionWithItemsHandler` to send `.destination(.instagram)` when the
chosen activity is Instagram's (or the new row), and only when completed, as
the invite already does (`CrewSharing.swift:44-51`). Effort: tiny. Owner
provides: nothing.

**6. (Optional) A 4:5 feed version of the strip.** A tall strip in the feed
gets cropped to 4:5 at best. A "Post" export that sets the posed strip on a
flat 1080x1350 ground in the paper's colour. Effort: small. **Needs his
decision**: it adds a ground he has so far kept off the strip, and a second
choice in the composer. Premium is subtraction; skip unless students ask.

Not recommended: a watermark or QR on any share (his call, and Instagram
demotes other apps' marks in Reels), a crew invite link anywhere on a shared
picture (it carries the crew's key; anyone who sees the Story could join),
and a tower share button for its own sake unless he wants the tower card back.

## Sources

- [M1] Meta, Sharing to Stories (iOS): https://developers.facebook.com/docs/instagram-platform/sharing-to-stories/
- [M2] Meta, Instagram Sharing to Reels from iOS: https://developers.facebook.com/docs/ios/sharing-to-reels-instagram/
- [L1] Link stickers for all accounts, Oct 2021: https://www.tubefilter.com/2021/10/27/instagram-share-links-stories-everybody/
- [S1] Story safe zone, 250px buffers: https://www.inro.social/blog/instagram-story-size
- [S2] Meta percentages converted (14% top, 35% bottom): https://www.socialync.io/tools/safe-zones/instagram-stories
- [S3] Reels safe zone in percentages: https://www.hopperhq.com/blog/instagram-reel-size/
- [W1] Mosseri, your own logo on a Reel is fine: https://www.socialmediatoday.com/news/instagram-clarifies-including-your-own-logo-on-a-reel-is-ok/730852/
- [W2] 2021 penalty for other apps' watermarks: https://www.tubefilter.com/?p=155614
- [P1] Wrapped, built for Stories: https://nogood.io/2025/01/20/spotify-wrapped-marketing-strategy/
- [P2] Wrapped 2021 design analysis, each slide stands alone: https://itmagination.com/blog/spotify-wrapped-2021-design-analysis
- [P3] Strava stats sticker on a Story: https://www.remove.bg/fr/b/strava-overlay-for-instagram-stories-and-posts
- [P4] BeReal reposted to Instagram by hand: https://dashhudson.com/blog/what-is-bereal
- [P5] Locket monthly recap video: https://apps.apple.com/us/app/1600525061
- [P6] Letterboxd shares to Stories: https://ixd.prattsi.org/?p=13862
- [P7] Duolingo streak sharing: https://blog.duolingo.com/how-duolingo-streak-builds-habit
