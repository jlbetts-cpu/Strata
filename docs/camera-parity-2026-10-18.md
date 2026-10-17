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
| 1 | Double tap the viewfinder to flip | missing | |
| 2 | Tap to focus and expose | missing | |
| 3 | Focus square with the exposure sun, gone after 4s | missing | |
| 4 | Focus square leaves when the camera refocuses itself | missing | |
| 5 | Drag up or down to set exposure, only while the square shows | missing | |
| 6 | Pinch to zoom | missing | |
| 7 | Zoom pill showing the lens (1x, 1.4x) | missing | |
| 8 | Tap the pill for the lens row (.5, 1, 2, 3), glide to a lens | missing | |
| 9 | Lens row folds after 3s, on pinch, focus or flip | missing | |
| 10 | Two lenses toggle; one lens shows a readout after a pinch | missing | |
| 11 | Lens accessibility labels and hints | missing | |
| 12 | Simulator fake lenses for screenshots | missing | |
| 13 | Flash off, auto, on (front: off, on), filled symbols, dimmed when off | partial | |
| 14 | Front flash as the warm ring light held while composing, screen to full brightness, no shutter delay | partial, regressed to the rejected white blast | |
| 15 | Flip button | present | present |
| 16 | Timer off, 3, 10, persisted, its number shown | partial (no number shown) | |
| 17 | Grid toggle, persisted | partial (in the menu) | |
| 18 | Grid drawn out from the middle, faded above the controls | partial | |
| 19 | Close | present | present |
| 20 | Press feedback on the camera's buttons | partial | |
| 21 | Controls step aside while drawing a bigger block | not needed (room kept) | not needed |
| 22 | Library, Draw It, Today's Photos, Just Words | new in the card | present |
| 23 | Tap the shutter for one cell, drag out for a bigger block, shoots on release | present | present |
| 24 | Drawing during a countdown resizes the shot instead of cancelling | partial | |
| 25 | Shutter enabled only when the camera can shoot | present | present |
| 26 | Shutter press squash | present | present |
| 27 | Haptics: a snap at the shutter, a light tap when the photo arrives | partial | |
| 28 | One-time cue: "Drag out for a bigger block" | missing | |
| 29 | Shutter accessibility | present | present |
| 30 | Volume buttons and Camera Control shoot | partial (no live check) | |
| 31 | A failed capture puts the size back | present | present |
| 32 | No double fire | present | present |
| 33 | Countdown: start, cancel, tick each second | present | present |
| 34 | Countdown in the app's own numerals | partial | |
| 35 | Countdown cancelled when leaving | present | present |
| 36 | Nothing saved until confirmed | present | present |
| 37 | Crop by dragging and pinching the photo | present | present |
| 38 | Crop context: the whole photo with the outside dimmed (CropBox) | partial | |
| 39 | Size on the review | present | present |
| 40 | Film looks | present | present |
| 41 | Doodle | present | present |
| 42 | Sticker button | removed by the owner (in Draw) | removed |
| 43 | Head button shows your head | partial | |
| 44 | Head lands inside the visible crop | partial | |
| 45 | A word under each tool | partial | |
| 46 | Retake | present | present |
| 47 | Use Photo: head, look, marks, saved to the camera roll | present | present |
| 48 | Review in the phone's own light or dark | present | present |
| 49 | Debug review hooks for screenshots | missing | |
| 50 | Mirrored front capture and preview | present | present |
| 51 | Live retouch on the front preview | partial | |
| 52 | Portrait polish | present | present |
| 53 | Camera refused: a way to Settings | present | present |
| 54 | Simulator video lens | present | present |
| 55 | Location of the shot | present | present |
| 56 | Entrance motion | present | present |
| 57 | Reduce Motion | present | present |
| 58 | Largest text | present | present |
| 59 | Tab bar told of the review | not needed (no tab) | not needed |
