# Strata research

Every research pass from September 2026, kept so decisions have their evidence
next to them. Each file leads with its own summary.

## Direction
- `concept-and-social.md`: the one-sentence concept, the next features, the
  small-circles social model, and the schema changes made before iCloud went live.
- `goals.md`: invisible guidance toward what someone wants out of life. It speaks
  only about wins that happened, only where the person already looks, and never
  about an empty day.
- `apollo-and-north.md`: what Apollo was, what Strata inherited, and how North
  (Rildy's AI personality) fits: notifications that read like a text, on device,
  never on an empty day.
- `north-and-goals-spec.md`: the combined spec, with the owner's decisions
  recorded at the end. **Scheduled after the polish queue.**
- `game.md`: why a game was considered and set aside.

## Polish
- `visual-cohesion.md`: the typographic identity built on the owner's lettering,
  one shadow rule, and the unifying system.
- `font.md`: the owner's alphabet built into a font, where it is used, SF Pro
  Rounded for everything else, and the reduced type scale (5 sizes, 2 weights).
- `icons.md` and `icons-pilot.md`: the library comparison and the ten-icon custom
  pilot. Decision: SF Symbols, with weight matched to the adjacent text.
- `block-icons.md`: optional debossed glyphs on blocks without photographs.
- `screen-control.md`: bottom bands, title lines and margins as tokens.
- `motion-and-layering.md`: one press behaviour, transition fixes, and the map's
  layer order.

## Engineering
- `image-loading.md`: derivative tiers, prefetch, and the map showing blocks
  before their photographs.
- `head-parity.md`: one head engine, eye contact rules, and derived blinks.
- `icloud-backup.md`: SwiftData with the CloudKit private database, photographs
  as their own model, and the phased build.

## Order of work (agreed 2026-09-16)
One build at a time:
1. Image loading
2. Head blink registration, then merge head parity
3. The owner's font with weight-matched SF Symbols and the reduced type scale
4. Visual cohesion, screen control and motion polish
5. Push to main
6. North and goals v1
