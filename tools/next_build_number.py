#!/usr/bin/env python3
"""Set CURRENT_PROJECT_VERSION to one above the highest build App Store Connect has.

**This exists because two upload paths kept their own counters.** Xcode Cloud
numbers its builds from CI_BUILD_NUMBER; a local archive numbers from whatever
is committed in the project file. On 2026-09-10 that produced build 9 from the
cloud and build 1 from this Mac — the newer code carrying the lower number,
because App Store Connect orders by build number and not by upload time. The
next collision would have been a rejected upload twenty minutes after anyone
stopped watching.

Asking the server is the only answer that cannot drift: whatever uploaded the
last build, and from wherever, the next number is one higher.

Usage, before a local archive:

    ASC_KEY_ID=... ASC_ISSUER_ID=... python3 tools/next_build_number.py

Reads the private key from ~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8.
Requires pyjwt. Prints the number it set and rewrites the project file in place.
"""
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request

try:
    import jwt
except ImportError:
    sys.exit("pyjwt is not installed: pip install pyjwt cryptography")

KEY_ID = os.environ.get("ASC_KEY_ID")
ISSUER = os.environ.get("ASC_ISSUER_ID")
APP_ID = os.environ.get("ASC_APP_ID", "6810905858")
if not (KEY_ID and ISSUER):
    sys.exit("set ASC_KEY_ID and ASC_ISSUER_ID")

KEY_PATH = os.path.expanduser(f"~/.appstoreconnect/private_keys/AuthKey_{KEY_ID}.p8")
PROJECT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                       "Strata.xcodeproj", "project.pbxproj")


def token():
    now = int(time.time())
    with open(KEY_PATH) as f:
        return jwt.encode({"iss": ISSUER, "iat": now, "exp": now + 1200,
                           "aud": "appstoreconnect-v1"},
                          f.read(), algorithm="ES256",
                          headers={"kid": KEY_ID, "typ": "JWT"})


req = urllib.request.Request(
    f"https://api.appstoreconnect.apple.com/v1/builds"
    f"?filter[app]={APP_ID}&limit=200",
    headers={"Authorization": "Bearer " + token()})
try:
    with urllib.request.urlopen(req, timeout=60) as f:
        data = json.load(f).get("data", [])
except urllib.error.HTTPError as e:
    sys.exit(f"App Store Connect returned {e.code}: {e.read().decode()[:300]}")

numbers = []
for d in data:
    v = d["attributes"].get("version")
    if v and v.isdigit():
        numbers.append(int(v))

highest = max(numbers) if numbers else 0
nxt = highest + 1
print(f"highest build on App Store Connect: {highest} -> using {nxt}")

with open(PROJECT) as f:
    text = f.read()
patched, count = re.subn(r"CURRENT_PROJECT_VERSION = [^;]*;",
                         f"CURRENT_PROJECT_VERSION = {nxt};", text)
with open(PROJECT, "w") as f:
    f.write(patched)
print(f"set CURRENT_PROJECT_VERSION = {nxt} in {count} configurations")
