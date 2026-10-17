# The old camera, feature by feature, in the inline camera

The owner, 2026-10-18: "Make a written list of every feature and gesture the
old camera had, check each one off in the inline camera, and put that list in
the morning message."

Inventory read from `CameraView.swift`, `CameraService.swift`,
`ShutterBlock.swift`, `CameraLenses.swift` and `WarmRingLight.swift` against
`InlineCamera.swift`. Status before the port: PRESENT, PARTIAL, MISSING. The
last column is the state after the 2026-10-18 port, updated as each lands.

| # | Feature or gesture | Before | Now |
|---|---|---|---|
| 1 | Double tap the viewfinder to flip | missing | present (shared `LensGestureLayer`; needs a phone to feel) |
| 2 | Tap to focus and expose | missing | present |
| 3 | Focus square with the exposure sun, gone after 4s | missing | present (`FocusReticle`, shared) |
| 4 | Focus square leaves when the camera refocuses itself | missing | present |
| 5 | Drag up or down to set exposure, only while the square shows | missing | present; the card's swipe down waits for it |
| 6 | Pinch to zoom | missing | present |
| 7 | Zoom pill showing the lens (1x, 1.4x) | missing | present (`LensPill`, on the card's darker glass) |
| 8 | Tap the pill for the lens row (.5, 1, 2, 3), glide to a lens | missing | present (probe: .5, 2, 3 written out) |
| 9 | Lens row folds after 3s, on pinch, focus or flip | missing | present |
| 10 | Two lenses toggle; one lens shows a readout after a pinch | missing | present |
| 11 | Lens accessibility labels and hints | missing | present |
| 12 | Simulator fake lenses for screenshots | missing | present (`-strataFakeLenses`) |
| 13 | Flash off, auto, on (front: off, on), filled symbols, dimmed when off | partial | present: filled symbols, dimmed when off |
| 14 | Front flash as the warm ring light held while composing, screen to full brightness, no shutter delay | partial, regressed to the rejected white blast | present: the ring held while composing, full brightness, no blast, no wait |
| 15 | Flip button | present | present |
| 16 | Timer off, 3, 10, persisted, its number shown | partial (no number shown) | present: the seconds beside the glyph (probe) |
| 17 | Grid toggle, persisted | partial (in the menu) | present (in the ... menu, his 2026-10-17 layout) |
| 18 | Grid drawn out from the middle, faded above the controls | partial | partial: drawn plainly, not ruled out from the middle |
| 19 | Close | present | present |
| 20 | Press feedback on the camera's buttons | partial | present (the app's press) |
| 21 | Controls step aside while drawing a bigger block | not needed (room kept) | not needed |
| 22 | Library, Draw It, Today's Photos, Just Words | new in the card | present |
| 23 | Tap the shutter for one cell, drag out for a bigger block, shoots on release | present | present |
| 24 | Drawing during a countdown resizes the shot instead of cancelling | partial | present |
| 25 | Shutter enabled only when the camera can shoot | present | present |
| 26 | Shutter press squash | present | present |
| 27 | Haptics: a snap at the shutter, a light tap when the photo arrives | partial | present: snap at the shutter, light tap on arrival |
| 28 | One-time cue: "Drag out for a bigger block" | missing | present, above the lens pill (probe) |
| 29 | Shutter accessibility | present | present |
| 30 | Volume buttons and Camera Control shoot | partial (no live check) | present: only when the lens is live |
| 31 | A failed capture puts the size back | present | present |
| 32 | No double fire | present | present |
| 33 | Countdown: start, cancel, tick each second | present | present |
| 34 | Countdown in the app's own numerals | partial | present: his numerals |
| 35 | Countdown cancelled when leaving | present | present |
| 36 | Nothing saved until confirmed | present | present |
| 37 | Crop by dragging and pinching the photo | present | present |
| 38 | Crop context: the whole photo with the outside dimmed (CropBox) | partial | replaced by the edit screen's hero: the photo is moved and pinched under the block itself |
| 39 | Size on the review | present | present |
| 40 | Film looks | present | present |
| 41 | Doodle | present | present |
| 42 | Sticker button | removed by the owner (in Draw) | removed |
| 43 | Head button shows your head | partial | partial: a labelled Head pill, not a picture of your head |
| 44 | Head lands inside the visible crop | partial | present |
| 45 | A word under each tool | partial | present: each tool is a labelled pill |
| 46 | Retake | present | present |
| 47 | Use Photo: head, look, marks, saved to the camera roll | present | present |
| 48 | Review in the phone's own light or dark | present | present |
| 49 | Debug review hooks for screenshots | missing | partial: `-strataOpenSheet addphoto` and `adddeep` open the card holding a photo |
| 50 | Mirrored front capture and preview | present | present |
| 51 | Live retouch on the front preview | partial | partial: live retouch on, no debug still |
| 52 | Portrait polish | present | present |
| 53 | Camera refused: a way to Settings | present | present |
| 54 | Simulator video lens | present | present |
| 55 | Location of the shot | present | present |
| 56 | Entrance motion | present | present |
| 57 | Reduce Motion | present | present |
| 58 | Largest text | present | present |
| 59 | Tab bar told of the review | not needed (no tab) | not needed |
