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

WHAT THE VERDICT MEANS.  `RISK` is anything over 40,000 ratings in the results:
big enough that a reviewer knows it.  `clean` means the biggest neighbour is
small enough that nobody would confuse the two.  Zero results is the best
possible answer -- it means the word is genuinely yours.

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
ENDPOINT = ("https://itunes.apple.com/search"
            "?term=%s&entity=software&country=us&limit=8")


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
    verdict = "RISK " if famous else ("CLEAN" if results else "CLEAN (nothing at all)")
    print("%-10s  %s   %d results" % (term, verdict, len(results)))
    for r in results[:4]:
        print("      %-36s %9s ratings"
              % ((r.get("trackName") or "")[:36], r.get("userRatingCount") or 0))
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
