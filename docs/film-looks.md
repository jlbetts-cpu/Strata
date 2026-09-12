# Film looks — research, decisions and numbers

**Status: built on 2026-09-11.** `FilmLook` (the colour, pure and tested),
`FilmLookRenderer` (Core Image), `FilmLookStrip` (choosing one on the camera's
photo review). Three looks and none; baked into the photograph when it is kept.

The owner's brief: Fujifilm's style and swagger, photographs that look and feel
better, nothing sad, grain that is realistic and not crazy, and "less is more".

---

## 1. Why most app filters look cheap

Every one of these is a thing the pipeline does differently.

1. **They work on the stored numbers, not on light.** Contrast and saturation
   applied to gamma-encoded values clip highlights and skew hue. Everything
   here is done in linear light.
2. **They use a straight contrast boost**, which is a wall at both ends. Film's
   characteristic curve has a toe and a shoulder, so highlights compress
   towards white rather than hitting it.
3. **They apply one saturation everywhere.** Film loses colour approaching
   white and falling into black. Saturation here tracks brightness.
4. **They tint the whole picture one colour.** A stock moves yellows one way
   and greens another; that crossover is what reads as a film rather than as a
   cast.
5. **They wreck memory colours.** Skin, sky and foliage are the three colours
   everybody has a fixed expectation of. Skin decides whether a photograph of a
   person is acceptable, and preferred skin sits near a CIELAB hue of 49
   degrees. **Skin is exempt from every colour move in every look**, and
   `FilmLookTests` fails if any look shifts it by more than a hair.
6. **Their grain is fake.** Real grain is a fluctuation in how much silver is
   there: densest in the midtones, gone in the highlights, and the same size
   whatever the file size.

## 2. The looks

Five were built and two were cut, because muted plus cool plus heavy shadows is
the recipe for gloom and the owner was right that they read as sad.

- **Air** — soft, warm, luminous. The one for people.
- **Bright** — Velvia's colour with the lights on: greens towards teal, blues
  deep, reds loud, skin held back so faces never go ruddy.
- **Silver** — black and white through a light orange filter, so skin stays
  light and a sky keeps its clouds. Lifted rather than gloomy.

Fuji's own names and profiles are Fujifilm's, so these are originals built from
how the stocks behave: Fuji greens shift towards teal where Kodak greens go
yellow-olive, and Velvia specifically swings yellows towards orange while
muting cyans.

## 3. The pipeline, in order

Colour (all of it in `FilmLook.graded(_:)`, baked into one 64-step colour cube):

1. **Partial white balance.** A warm look on a tungsten room is two casts
   stacked. Full correction is worse, because grey-world fails exactly when a
   picture really is one colour, so it is capped at 7% per channel and scaled
   by how neutral the picture already looks.
2. **AgX inset.** Colour is pulled towards grey before the curve and let back
   out after. Without it a per-channel curve skews bright colour towards
   whichever primary clips last — the "notorious six" — and blues go purple.
   Measured A/B: jerseys stay blue instead of going muddy.
3. **Tone**, per channel, in linear light, with an extended Reinhard shoulder
   that never clips and a contrast curve that turns about its own pivot.
4. **Clip guard.** Green clips first, which tips blown highlights magenta.
   Anything near the ceiling is eased to neutral.
5. **Crossover**, a 3x3 barely off identity.
6. **Hue moves and memory pull.** Published preferred hues: foliage 115 to 135
   degrees, sky 250 to 267, skin 49. The familiar colours are *pulled* towards
   those centres rather than shifted, so a sky already right is left alone.
7. **Saturation that tracks brightness**, then a split tone, both kept off skin.

Light and texture (`FilmLookRenderer`, Core Image):

8. **Shadow lift**, local, so a dim room keeps what is in it.
9. **Halation into the red channel.** Light passes through the emulsion,
   reflects off the back of the base and returns to the nearest layer, which in
   colour film is the red-sensitive one. Two blurs, a tight core and a wide
   veil, because a measured glare spread function has both.
10. **Bloom**, then **glow**: a soft lifted copy printed back over the lit half
    of the picture, which is the darkroom trick of printing through a diffused
    negative. This is where the "ethereal" comes from.
11. **Local contrast**, to pay for the softness.
12. **Grain**, at a real grain size (about two pixels on a 2560px photograph),
    densest in the midtones, thinned in bright flats where blotches read as a
    bad JPEG, and strongest in the blue record, which is the grainiest layer of
    a colour negative.
13. **Vignette**, on Silver only, and barely.

## 4. Decisions the owner made

- **Baked in**, not re-applied on display: the photo-loading path is tuned hard
  and every new step in it is a way for pictures to arrive slowly. The cost is
  that changing your mind later means re-adding the photo.
- **The camera roll gets the look too**, so what you saw is what you keep
  everywhere.
- **Three looks**, not five.
- **The look is remembered between shots**, the way Photographic Styles are.

## 5. Numbers worth keeping

- **Grain costs storage**, measured at the app's own encode quality: 4 to 18%
  on the colour looks, 23 to 58% on Silver. It survives encoding well (90 to
  95% of it intact).
- **Wide colour matters.** An iPhone photograph is Display P3, about a quarter
  more colour than sRGB, so the context works in extended linear Display P3 at
  half-float. In sRGB those colours would be clipped before the look ran.
- **Your photographs carry an HDR gain map.** `ImageManager` already re-encodes
  at 2560px and drops it, so the look costs nothing extra; the camera-roll copy
  is SDR where the original capture was HDR.

## 6. Still open

- Skin is found by hue, which can also catch wood, brick and sand. The app
  already runs Vision for the head maker, so faces could protect skin properly.
- Looks are offered on the camera review only. A photograph chosen from the
  library gets none.
- The look each win was shot with is not yet written on the win.

## Sources

- Fujifilm simulations, described — https://www.imaging-resource.com/news/fujifilm-film-simulations-definitive-guide/
- Fuji versus Kodak greens — https://legendarypresets.com/fuji-vs-kodak-color-science/
- Film emulation, a colourist's view — https://pixeltoolspost.com/blogs/resolve/film-emulation-explained
- AgX and the notorious six — https://docs.darktable.org/usermanual/development/en/module-reference/processing-modules/agx/
- Memory colours — https://fstoppers.com/education/three-colors-expose-every-bad-edit-and-why-your-brain-cant-ignore-them-903385
- Preferred skin colour — https://library.imaging.org/admin/apis/public/api/ist/website/downloadArticle/cic/18/1/art00033
- Preferred sky and foliage hues — https://graphics.cs.yale.edu/sites/default/files/hveisuppdoc.pdf
- Halation and the anti-halation layer — https://blog.dehancer.com/articles/halation/
- Veiling glare — https://graphics.stanford.edu/papers/glare_removal/glare_removal.pdf
- Stochastic film grain — https://www.lirmm.fr/~nfaraj/publications/film_grain_ipol/2017_Newson_film_grain.pdf
- Film grain and compression — https://norkin.org/research/film_grain/index.html
- Core Image and wide gamut — https://developer.apple.com/forums/thread/649637
- Apple's Photographic Styles undertones — https://www.dxomark.com/feature-focus-diving-into-the-apple-iphone-16-series-undertones-functionality/
