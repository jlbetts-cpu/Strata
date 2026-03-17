# Bug Fix: Typography Enforcement — Familjen Grotesk

## Failure Analysis

**Root cause:** The font files at `Strata/Fonts/FamiljenGrotesk-*.ttf` are **HTML pages, not valid font files.** The `curl` command downloaded GitHub's HTML preview instead of the raw binary. Running `file` on them confirms:

```
FamiljenGrotesk-Regular.ttf: HTML document text, Unicode text, UTF-8 text
FamiljenGrotesk-Medium.ttf:  HTML document text, Unicode text, UTF-8 text
```

SwiftUI's `Font.custom()` silently falls back to the system font when the named font can't be found — so the app compiles and runs fine, but every single text element is still San Francisco.

**Secondary issue:** The `Info.plist` registers fonts as `Fonts/FamiljenGrotesk-*.ttf`, but `fileSystemSynchronizedGroups` flattens the bundle — the files end up at the app root, not in a `Fonts/` subdirectory.

---

## Fix Plan

### Step 1: You Provide Valid Font Files

I cannot programmatically download these from Google Fonts — GitHub raw URLs for the `google/fonts` repo redirect through HTML pages that break `curl`.

**What you need to do:**

1. Go to [https://fonts.google.com/specimen/Familjen+Grotesk](https://fonts.google.com/specimen/Familjen+Grotesk)
2. Click **"Download family"** (top-right button)
3. Unzip the download — you'll find static TTF files inside `static/` folder:
   - `FamiljenGrotesk-Regular.ttf`
   - `FamiljenGrotesk-Medium.ttf`
4. **Replace** the fake files at:
   ```
   Strata/Fonts/FamiljenGrotesk-Regular.ttf
   Strata/Fonts/FamiljenGrotesk-Medium.ttf
   ```

**Verification you can run:**
```bash
file Strata/Fonts/FamiljenGrotesk-Regular.ttf
# Should say: TrueType Font data
# NOT: HTML document text
```

Once you confirm the real fonts are in place, tell me and I'll proceed to Step 2.

---

### Step 2: Fix Info.plist Font Paths

**Problem:** Registered as `Fonts/FamiljenGrotesk-*.ttf` but `fileSystemSynchronizedGroups` copies them to the bundle root without the `Fonts/` prefix.

**Fix:** Update `Info.plist` (at project root `/Users/jaydenbetts/Documents/Strata/Info.plist`):

```xml
<key>UIAppFonts</key>
<array>
    <string>FamiljenGrotesk-Regular.ttf</string>
    <string>FamiljenGrotesk-Medium.ttf</string>
</array>
```

Remove the `Fonts/` prefix from both entries.

---

### Step 3: Verify PostScript Names

**Problem:** `Font.custom()` requires the font's internal **PostScript name**, which may differ from the filename. We assumed `FamiljenGrotesk-Medium` and `FamiljenGrotesk-Regular` but never verified.

**Fix:** Add a temporary debug print in `StrataApp.swift` `init()` to dump all registered font names:

```swift
for family in UIFont.familyNames.sorted() {
    for name in UIFont.fontNames(forFamilyName: family) {
        print("  \(family) → \(name)")
    }
}
```

This will print the actual PostScript names to the console. If they differ from what's in `Typography.swift`, I'll update the `Font.custom()` calls to match.

---

### Step 4: Update Typography.swift If Needed

Once we have the real PostScript names from Step 3, update every `Font.custom(...)` call in `Typography.swift` to use the correct names. The current definitions:

```swift
Font.custom("FamiljenGrotesk-Medium", size: 34)   // might need adjustment
Font.custom("FamiljenGrotesk-Regular", size: 16)   // might need adjustment
```

---

### Step 5: Verify Kerning Application

**Problem:** `Typography.swift` defines kerning constants but they're only applied in `StrataHeaderView`. Every other call site uses `Typography.headerX` or `Typography.blockTitle` **without** `.kerning()`.

**Fix:** Audit and add `.kerning(Typography.headerKerning)` to all Medium-weight text:
- `StrataHeaderView` — "Strata" title (already has it)
- `FlippableBlockView` — block titles (`.kerning(Typography.headerKerning)`)
- `MainAppView` — expanded block detail title
- `BlockDetailSheet` — header title
- `TimelineSheetView` — week strip day numbers
- `BottomBarView` — tab labels

Regular-weight body text gets **no kerning** (0% tracking = default).

---

### Step 6: Build & Runtime Verification

```bash
xcodebuild -scheme Strata -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

**Runtime checks (in Simulator):**
1. Console output from Step 3 shows `FamiljenGrotesk` family with correct PostScript names
2. "Strata" header renders in Familjen Grotesk Medium, noticeably different from SF Pro
3. Block titles inside colored blocks render in Familjen Grotesk Medium
4. Date subtitle, body text, captions render in Familjen Grotesk Regular
5. SF Symbols (icons) remain unchanged — still system font
6. No "CoreText: Invalid font data" warnings in console

---

## Summary

| Step | Owner | Action |
|------|-------|--------|
| 1 | **You** | Download real `.ttf` files from Google Fonts, place in `Strata/Fonts/` |
| 2 | Me | Fix `Info.plist` paths (remove `Fonts/` prefix) |
| 3 | Me | Add font name debug dump, identify PostScript names |
| 4 | Me | Update `Typography.swift` with correct names if needed |
| 5 | Me | Add `.kerning()` to all Medium-weight text call sites |
| 6 | Both | Build + visual verification in Simulator |

**Awaiting your confirmation that real font files are in place before I execute Steps 2–6.**
