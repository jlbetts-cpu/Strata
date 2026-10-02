#!/usr/bin/env python3
"""Launch the app with the given arguments and photograph it once it has SETTLED.

    SHOT_SIM=<udid> SHOT_BID=<bundle id> SHOT_OUT=<path.png> [SHOT_FLOOR=<s>] \
        tools/settle-shot.py -strataStartTab memories -strataSeedHistory 6

**Why this is not a `sleep`.** `tools/capture-screens.sh` used to sleep a stated
number of seconds after `simctl launch` returned. On 2026-10-01 that put seven of
twenty-four captures on the wrong screen, and three of those were written down as
broken FIXTURES — wrong launch flags — when the flags were right and the sleep
was short. With four simulators running on one Mac, `simctl launch` took 11 to 45
seconds to return and the app needed another 36 to 66 seconds to seed and draw.

Two tests, both cheap, and a capture has to pass both:

- **Structure.** The launch screen is a near-uniform warm black: rgb(8, 8, 8) at
  a standard deviation of about nothing. Any real screen, light or dark, has
  tens of levels of spread. `std > 12` separates them, and it does not assume the
  screen is light — the map at night and the photo viewer are dark and both pass
  it easily.
- **Stillness.** Two consecutive frames six seconds apart that differ by less
  than 0.6 of a level on average. This is what catches a page mid-fade, a block
  still falling, or a photograph that has not decoded yet. It is deliberately
  loose: the map's slideshow and a blinking head would never be byte-identical.

`SHOT_FLOOR` is a minimum wait before the first shot, so a screen whose subject
arrives on a known delay is not photographed before it. It is a floor, never a
deadline.

Exit code 1 and a loud NEVER SETTLED line if it runs out of attempts, with the
last frame written anyway so there is something to look at.
"""
import os
import subprocess
import sys
import time

import numpy as np
from PIL import Image

SIM = os.environ["SHOT_SIM"]
BID = os.environ["SHOT_BID"]
OUT = os.environ["SHOT_OUT"]
FLOOR = float(os.environ.get("SHOT_FLOOR", 0))

STEP = 6.0          # seconds between frames
ATTEMPTS = 60       # six minutes, which is well past the worst launch measured
STRUCTURE = 12.0    # standard deviation; the launch screen cannot reach it
STILLNESS = 0.6     # mean absolute difference between consecutive frames


def shoot(path):
    subprocess.run(["xcrun", "simctl", "io", SIM, "screenshot", "--type=png", path],
                   capture_output=True)
    return np.asarray(Image.open(path).convert("RGB")).astype(np.int16)


def app_is_running():
    """**Is the app actually running, as opposed to a still frame of anything?**

    Added 2026-10-02. The settle test above asks two things — does the frame
    have structure, and has it stopped moving — and **a home screen passes
    both.** A wallpaper is detailed and perfectly still. Three of twenty-four
    captures in one evening's set were of the springboard, and this script
    reported each of them as a settled screenshot of the screen it was asked
    for. Only the mean colour and `page-room.py --signature` caught them.

    So it asks the simulator's launchd whether the app's job exists. This
    catches the failure that produced every one of those three: a launch that
    did not happen, or an app that crashed while seeding. It does NOT catch an
    app that is running and backgrounded, because a backgrounded app keeps its
    job; nothing here backgrounds the app, so that case has never occurred.
    """
    out = subprocess.run(["xcrun", "simctl", "spawn", SIM, "launchctl", "list"],
                         capture_output=True, text=True).stdout
    return any(f"UIKitApplication:{BID}" in line for line in out.splitlines())


def main():
    name = os.path.basename(OUT)
    began = time.time()
    subprocess.run(["xcrun", "simctl", "launch", "--terminate-running-process", SIM, BID]
                   + sys.argv[1:], capture_output=True)
    launched = time.time() - began
    if FLOOR > 0:
        time.sleep(FLOOR)
    tmp = OUT + ".settling.png"
    prev = None
    for i in range(ATTEMPTS):
        frame = shoot(tmp)
        std = float(frame.std())
        still = prev is not None and float(np.abs(frame - prev).mean()) < STILLNESS
        if std > STRUCTURE and still:
            if not app_is_running():
                Image.fromarray(frame.astype(np.uint8)).save(OUT)
                os.remove(tmp)
                print(f"  {name}  APP NOT RUNNING  the settled frame is not the app; "
                      f"launch {launched:.0f}s")
                return 2
            Image.fromarray(frame.astype(np.uint8)).save(OUT)
            os.remove(tmp)
            dom = tuple(int(c) for c in frame.reshape(-1, 3).mean(axis=0))
            print(f"  {name}  {frame.shape[1]}x{frame.shape[0]}  mean {dom}  "
                  f"launch {launched:.0f}s  settled {(i + 1) * STEP + FLOOR:.0f}s")
            return 0
        prev = frame
        time.sleep(STEP)
    Image.fromarray(prev.astype(np.uint8)).save(OUT)
    os.remove(tmp)
    print(f"  {name}  NEVER SETTLED  std {float(prev.std()):.1f}  launch {launched:.0f}s")
    return 1


sys.exit(main())
