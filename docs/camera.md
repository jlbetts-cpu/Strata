# The camera, against the one people already know

The owner, 2026-10-12: "the camera seems to have some problem, sometimes
the orientation is wrong, and the zoom should be automatic like it is on
the native Apple camera. It should have most of the familiar features that
casual people use on the Apple camera."

Read against the code and Apple's documentation. **None of it can be run
on the simulator, which has no camera.** Every fix here needs a pass on a
real phone before friends get it.

## Why a photo comes out sideways

1. **The photo is never told which way up the phone is.** The capture
   sets mirroring and nothing else, so every photo carries the same
   orientation. Held upright it is right; held sideways or upside down it
   is a quarter or half turn off. (`CameraService.swift:599-604`)
2. **The front viewfinder reads the angle once**, from an object it throws
   away. Flip to the front camera while holding the phone sideways and the
   viewfinder is turned, and stays turned. (`CameraService.swift:289-298`)
3. **The preview's own rotation is never set.** It rides a default that
   Apple says differs on iPhone 17's front camera. (`CameraView.swift:1848`)

The fix for all three is one object Apple provides for exactly this
(`AVCaptureDevice.RotationCoordinator`), kept for as long as the camera is
open, feeding the preview and the photo.

## Zoom

The app already opens the phone's combined camera, so lenses hand over by
themselves as you pinch. What is not like Apple's: one pill that cycles
(from 1x a tap goes to telephoto, then wraps to 0.5x, so 0.5x is two taps
away), a jump instead of a glide between lenses, and no 2x stop.

## What casual people use, and whether it is here

| Feature | Here? |
|---|---|
| Pinch to zoom | Yes |
| Lens buttons (0.5, 1, 2, 3) | A cycling pill, not buttons |
| Tap to focus, with the square | Yes, but after one tap it stops refocusing by itself |
| Drag to brighten or darken | Yes |
| Flash | On and off; no Auto |
| Flip, and double tap to flip | Yes |
| Volume buttons take the photo | No |
| Camera Control button (iPhone 16) | No |
| Grid | Yes |
| Timer | Yes |
| Icons turn when the phone turns | No |

Build first: the orientation fix; the focus that locks; a row of lens
buttons that glide; the volume buttons; flash Auto. Not worth building
here: Live Photo, a night switch, a level, a last-photo thumbnail.

## The rubric

By test, no camera needed:
1. The lens stops for a phone with 0.5x, 1x and 3x are exactly those, with
   those labels.
2. A pinch never goes below the widest lens or past the limit.
3. Any lens is one press from any other.
4. A photo at each of the eight orientations comes out the right way up
   through every step the app puts it through.

On a real phone only:
5. Back and front camera, phone held four ways each: all eight photos are
   upright.
6. Turn sideways, lay the phone flat, shoot: it matches the last way it
   was held.
7. Flip to the front camera while sideways: the viewfinder is upright.
8. Pinch from 0.5x to the limit: no blink where the lens changes.
9. A lens button glides there in under a third of a second.
10. Tap to focus, then point somewhere else: it refocuses within a second.
11. A volume button takes one photo and shows no volume bar.
12. Flash on Auto fires in a dark room and not in daylight.

## Built on 2026-10-12, and what is proven

| Change | Proven here | Needs your phone |
|---|---|---|
| The photo is told which way up the phone is, by one kept rotation coordinator | The app's steps keep all eight orientations upright (`CameraLensTests.eightWays`) | Lines 5 and 6 |
| The viewfinder's angle is set from the same coordinator | Compiles; reads as Apple's sample does | That the viewfinder is unchanged held upright, on your phone |
| The front camera's live frames use the viewfinder's angle | The same | Line 7 |
| A row of lenses, one press each, with 2x where the main camera has a true one | Lines 1 to 3, by test; the row looked at with made-up lenses (`-strataFakeLenses 1,2,4,6`) | Lines 8 and 9; whether 2x appears on your phone |
| A lens press glides (`ramp`) | Compiles | Line 9 |
| A tap to focus lets go when the picture changes | Compiles | Line 10 |
| Volume buttons and Camera Control take the photo | Compiles | Line 11 |
| Flash: Off, Auto, On (back camera) | The three states and their bolts, by test | Line 12 |

**None of the right-hand column has been seen.** The simulator has no
camera. The one I am least sure of: the front camera, phone held sideways.
The photo is mirrored and turned in the same step, and whether that comes
out upright or upside down I could not find written down. It was a
quarter turn off before, every time.

Not built: icons that turn with the phone, Live Photo, a night switch.
The head maker's camera was left exactly as it was; its angles were tuned
on a phone.

**Because of that column this is in a build for you alone (128), not the
Friends build (127).** The camera is the first screen the app opens on.
