#!/usr/bin/env python3
"""Check a candidate app name against App Store search before committing to it.

WHY THIS EXISTS.  This app was rejected twice under guideline 4.1(a) -- "the
metadata creates a misleading association with another developer's app" -- and
the cause was almost certainly the name.  Search the store for `strata` and the
first result is STRAVA, 374,584 ratings, in an overlapping category.  Nobody
typed Strava; Apple's own index decided they were the same word.

So the gate is simple and it is not a matter of taste: **if searching your name
surfaces a giant, you are in that giant's neighbourhood whether you meant to be
or not.**

MEASURED, on 2026-09-30, over ten candidates the owner and I liked the sound of:

    mussy   -> Spotify (42M), Pandora, Apple Music     "muss" reads as "music"
    mussi   -> Apple Music, Spotify                    same
    tumo    -> Temu (2.2M), SHEIN, Amazon
    pilu    -> Instagram (29M)
    tobbi   -> Tubi (1.2M)
    puffi   -> Puffin Browser, Firefox, Aloha
    noli    -> Offroad Outlaws, Need for Speed
    anko    -> Quizlet
    wubbi   -> nothing over 8,600                      usable
    nubbi   -> nothing over 338                        clean

Six of ten would have been a rejection waiting to happen, and not one of them is
obvious by eye.  Run this before falling in love with a name, not after.

    python3 tools/name-check.py mochi sumi nubbi

WHAT THE VERDICT MEANS.

    RISK       something over 40,000 ratings is in the results.  Big enough
               that a reviewer knows it, which is the 4.1(a) failure mode.
    TAKEN      an app is already called EXACTLY this.
    CROWDED    two or more apps ship `Name: something`.  App Store Connect
               enforces unique names, so that pattern is what a developer does
               when the bare word is already gone.
    clean-ish  somebody uses the word, but small and once.
    CLEAN      nothing in the store carries the word at all.

The count that matters is the second column: HOW MANY apps carry the word, not
how loud the loudest one is.  A name nobody has heard of and six people already
use is not an original name.

The iTunes endpoint rate-limits, so this backs off and retries rather than
reporting a false clean.  A name that "returns nothing" because the request
failed is exactly the wrong answer to get, so a failure says so explicitly.
"""

import json
import sys
import time
import urllib.parse
import urllib.request

# Over this many ratings and a reviewer has heard of it.
FAMOUS = 40_000
# **FIFTY, NOT EIGHT.**  The first version asked for eight results and reported
# the biggest of them, and that is how `sturdy` came back as "seven results, the
# biggest a savings bank" when the truth is NINE apps already carry the word.
# Eight is roughly the number of results a store search returns before it starts
# listing loosely related apps, which made it a reasonable-looking cap and a
# silently wrong one: the thing this gate exists to find is not the loudest
# neighbour, it is HOW MANY people already took the word.
ENDPOINT = ("https://itunes.apple.com/search"
            "?term=%s&entity=software&country=us&limit=50")


def search(term, tries=4):
    for attempt in range(tries):
        try:
            request = urllib.request.Request(
                ENDPOINT % urllib.parse.quote(term),
                headers={"User-Agent": "Mozilla/5.0"})
            raw = urllib.request.urlopen(request, timeout=20).read()
            if raw.strip():
                return json.loads(raw)
        except Exception:
            pass
        time.sleep(4 * (attempt + 1))
    return None


def check(term):
    data = search(term)
    if data is None:
        # NOT a clean result. Say so loudly: a silent failure here is how a bad
        # name gets shipped.
        print("%-10s  COULD NOT CHECK -- the store did not answer" % term)
        return
    results = data.get("results", [])
    famous = [r for r in results if (r.get("userRatingCount") or 0) > FAMOUS]
    # **Apps whose NAME actually contains the word**, which is the question
    # somebody choosing a name is really asking. A search returns anything the
    # index thinks is related; only these are people who took the word.
    owns = [r for r in results
            if term.lower().replace(" ", "") in (r.get("trackName") or "").lower().replace(" ", "")]
    # **`Name: subtitle` is the tell that the bare name is gone.** App Store
    # Connect enforces unique app names, so a developer who wanted `Sturdy` and
    # could not have it ships `Sturdy: GLP-1 Tracker`. Two or three of these is
    # a strong sign the plain word is already reserved by somebody.
    colons = [r for r in owns if (r.get("trackName") or "").lower().startswith(term.lower() + ":")]
    exact = [r for r in owns if (r.get("trackName") or "").strip().lower() == term.lower()]

    if famous:
        verdict = "RISK "
    elif exact:
        verdict = "TAKEN"
    elif len(colons) >= 2:
        verdict = "CROWDED"
    elif owns:
        verdict = "clean-ish"
    else:
        verdict = "CLEAN"

    print("%-10s  %-9s  %d apps carry the word (%d results searched)"
          % (term, verdict, len(owns), len(results)))
    for r in owns[:6]:
        print("      %-40s %8s ratings" % ((r.get("trackName") or "")[:40],
                                           r.get("userRatingCount") or 0))
    if exact:
        print("      ^ SOMEBODY IS ALREADY CALLED EXACTLY THIS")
    elif colons:
        print("      ^ %d use `%s: something`, which is what people ship when the"
              " bare name is gone" % (len(colons), term))
    if famous:
        print("      ^ in the neighbourhood of: "
              + ", ".join((f.get("trackName") or "")[:28] for f in famous))


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(__doc__)
        raise SystemExit(2)
    for name in sys.argv[1:]:
        check(name)
        time.sleep(3)
