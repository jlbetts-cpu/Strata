#!/usr/bin/env python3
"""Every piece of motion in the app, counted.

    tools/motion-inventory.py            the summary
    tools/motion-inventory.py --sites    plus every call site, by token

What `docs/motion-audit.md` counted by hand on 2026-10-01, as a tool, so the
next pass starts from a number instead of from memory. It reads source, not
pixels: it says what the app asks for, never what it looks like. Filming is
the other half (`docs/motion-audit.md`, "Filmed").

Counted:
  - every `Animation` token in GridConstants, its value and its call sites
  - animations typed inline anywhere else (the one-system rule's failures)
  - `.animation(...)` with no `value:` (animates whatever changes)
  - `DispatchQueue.main.asyncAfter` (motion sequenced on a timer)
  - `.buttonStyle(.plain)` (a control with no press answer)
  - files that animate and never read Reduce Motion
"""
import os, re, sys
from collections import defaultdict

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
SRC = os.path.join(ROOT, "Strata")
GC = os.path.join(SRC, "Models", "GridConstants.swift")

CURVES = r"(spring|easeInOut|easeOut|easeIn|linear|interpolatingSpring|timingCurve|smooth|snappy|bouncy|interactiveSpring)"
TOKEN_DEF = re.compile(r"^\s*static (?:let|var) (\w+)\s*(?::\s*Animation)?\s*=\s*(?:Animation)?\.(" + CURVES[1:-1] + r")\b(.*)$")
# A token that resolves at use: `static var x: Animation { calm(.spring(...)) }`
# or `static func x(...) -> Animation { calm(...) }`. Calm tokens are the fade
# under Reduce Motion, so a file that only uses those is covered.
CALM_DEF = re.compile(r"^\s*static (?:var (\w+): Animation|func (\w+)\([^)]*\) -> Animation) \{\s*$|^\s*static var (\w+): Animation \{ calm\((.*)\) \}\s*$")
SPATIAL = re.compile(r"\.transition\(\s*\.(move|scale|slide|push|offset)")
INLINE = re.compile(r"(?:withAnimation\(|\.animation\(|animation:\s*|\?\s*|:\s*)\s*(?:Animation)?\.(" + CURVES[1:-1] + r")\s*[\(\n,)]")
BARE_ANIM = re.compile(r"\.animation\((?![^)]*value:)[^)]*\)\s*$")


def code_lines(path):
    """Lines with `//` comments stripped, so prose about a curve is not a curve."""
    out = []
    for n, line in enumerate(open(path, encoding="utf-8"), 1):
        s = line.split("//", 1)[0] if "//" in line and '"' not in line.split("//", 1)[0][-1:] else line
        if line.lstrip().startswith("///") or line.lstrip().startswith("//"):
            s = ""
        out.append((n, s))
    return out


def swift_files():
    for d, _, fs in os.walk(SRC):
        for f in fs:
            if f.endswith(".swift"):
                yield os.path.join(d, f)


def main():
    tokens, calm = {}, set()
    gc = code_lines(GC)
    for i, (n, line) in enumerate(gc):
        m = TOKEN_DEF.match(line)
        if m:
            tokens[m.group(1)] = (n, (m.group(2) + m.group(3)).strip())
            continue
        c = CALM_DEF.match(line)
        if c:
            name = c.group(1) or c.group(2) or c.group(3)
            value = c.group(4) or gc[i + 1][1].strip() if i + 1 < len(gc) else ""
            if name == "calm":
                continue
            tokens[name] = (n, "calm: " + (c.group(4) or value)[:60])
            calm.add(name)

    sites = defaultdict(list)
    inline, bare, timers, plain = [], [], [], []
    unguarded = []
    for path in sorted(swift_files()):
        rel = os.path.relpath(path, ROOT)
        lines = code_lines(path)
        text = "".join(s for _, s in lines)
        animates = False
        for n, s in lines:
            for t in tokens:
                if re.search(r"GridConstants\." + t + r"\b", s) or (path == GC and re.search(r"[^\w]" + t + r"\b", s) and not TOKEN_DEF.match(s) and not CALM_DEF.match(s)):
                    sites[t].append(f"{rel}:{n}")
                    if t not in calm and not (tokens[t][1].startswith("ease") and "repeatForever" not in tokens[t][1]):
                        animates = True
            if SPATIAL.search(s):
                animates = True
            if path != GC and INLINE.search(s) and "GridConstants" not in s:
                inline.append(f"{rel}:{n}: {s.strip()[:110]}")
                animates = True
            if BARE_ANIM.search(s.rstrip()):
                bare.append(f"{rel}:{n}: {s.strip()[:110]}")
            if "asyncAfter" in s:
                timers.append(f"{rel}:{n}")
            if ".buttonStyle(.plain)" in s:
                plain.append(f"{rel}:{n}")
        if animates and path != GC and "reduceMotion" not in text and "ReduceMotion" not in text:
            unguarded.append(rel)

    used = {t: v for t, v in sites.items() if v}
    total = sum(len(v) for v in used.values())
    print(f"Animation tokens: {len(tokens)} ({len(calm)} calm under Reduce Motion)   with a call site: {len(used)}   call sites: {total}")
    print(f"Inline (off-token) animations: {len(inline)}")
    print(f".animation without value: {len(bare)}")
    print(f"asyncAfter timers: {len(timers)}")
    print(f".buttonStyle(.plain): {len(plain)}")
    print(f"Files with uncalmed motion that never read Reduce Motion: {len(unguarded)}")
    print()
    print(f"{'token':24} {'sites':>5}  value")
    for t, (n, v) in sorted(tokens.items(), key=lambda kv: -len(sites[kv[0]])):
        print(f"{t:24} {len(sites[t]):>5}  {v[:70]}")
    for title, rows in [("Inline", inline), ("No value:", bare), ("Unguarded files", unguarded),
                        (".plain", plain), ("asyncAfter", timers)]:
        if rows:
            print(f"\n{title}")
            for r in rows:
                print("  " + r)
    if "--sites" in sys.argv:
        print("\nCall sites")
        for t in sorted(sites):
            print(f"  {t}: " + ", ".join(sites[t]))


if __name__ == "__main__":
    main()
