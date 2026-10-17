# The camera, 2026-10-17: decisions

Tags: (a) research, (b) seen in a shipping app, (c) my inference.

## Do we need a Camera tab? Recommendation: three tabs
- Photo-first apps without a camera tab put the camera one tap from home instead: Locket opens straight onto its camera; BeReal's camera opens from its one big button and its notification; iMessage's camera is in the + of every conversation; Instagram's newer layouts moved the camera off the bar to a swipe and a +. (b)
- Ours is already one tap from everywhere a win is made: the Wins slot, every crew's slot, a chat's Add a Win and the day's cue all open the camera card, and the card is the whole of Add a Win. (c)
- What the tab did, and where it lives now: the looks, drawing, stickers, your head and the crop are the card's tools; the size drag is the card's shutter; the review is the card's page; quick capture is the slot. The widgets and the Control Center control log a win by their own intent and never opened the tab. (c, read in code)
- What we lose: a camera glyph on the bar that says "this is a photo app" before anyone taps; the Camera Control and volume-button shot from the tab. The slot's + and onboarding carry the first; the second is worth wiring to the card on Wins next. (c)
- What we gain: one camera instead of two, no black drawing over the native bar (and so no lag or hidden glass), and one fewer tab for parents. (c)
- Built: Settings, Show the Camera Tab (on, today's four tabs). Off is Wins, Crews and Memories. Recommend turning it off after you have used the card for a day.
- Because three tabs is the recommendation, no more time went into the Camera tab's bar.

## The card is the camera
- Controls: close top left; Just Words and the extras top right (timer, grid, a library photo, draw it); flash, shutter, flip along the foot. (your layout)
- The shutter is a plain drag again; hold-to-commit stays on the tower only. (your correction)
- It stands on the tab bar, never over it; the dim stops at the bar. (your note)
- After the photo: one page, details above the photo, nothing written on it; tools in one quiet row on its foot (Looks, Draw, Stickers, Your Head; drag and pinch to crop). Essentials up front (name, size, who sees it), the rest under More (colour, a note, who you were with, tonight's high, low and buffalo, tonight's story). Mood is the journal's, a day's not a win's, so it stays there. (c)
- Words: the block itself, written on in the tower's own type, its colour one tap away. (your note)
- No colour flash: the ground before the lens is the slot's clear glass. Filmed. (measured)

## Photos in chats
- Take a Photo leads a chat's +, crew or person: the camera card opens in the chat and sends through the photo check. (your ask)
- A photograph in a conversation leaves after 24 hours; its words keep two weeks; a crew's chat already clears at midnight. Stickers and strips are not photos for the moment and keep. (your ask)
- Keeping one: open it, then Save to Photos or Add to My Tower. Yours always. (your ask)
- A friend's: Snapchat lets a friend save a snap in chat and tells the sender it was saved; Instagram tells the sender when a disappearing photo is screenshotted and lets nothing be saved; Locket keeps everything and tells no one. (b)
- Recommendation: let a friend keep your photo, and say so in your chat as a quiet line ("Sam kept your photo"), as Snapchat does. It is honest without watching anyone, and it lets a moment be kept on purpose. Built: the keeping, behind Keep Friends' Chat Photos (off). Not built: the line to the sender, which should come with the switch if you want it. (c)
- Hold vs open: the keep actions are in the photo's own menu (open it, then ⋯), because holding a chat line already opens its reactions. (c)
