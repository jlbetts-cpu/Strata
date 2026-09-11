#!/usr/bin/env python3
"""Print TestFlight builds, newest first, as `<version> <state>` lines.

The first line is the newest build, so `head -1 | grep VALID` is a usable
readiness check — that is what tools/ship.sh polls.

    ASC_KEY_ID=... ASC_ISSUER_ID=... python3 tools/build_status.py
"""
import json
import os
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


def token():
    now = int(time.time())
    with open(KEY_PATH) as f:
        return jwt.encode({"iss": ISSUER, "iat": now, "exp": now + 1200,
                           "aud": "appstoreconnect-v1"},
                          f.read(), algorithm="ES256",
                          headers={"kid": KEY_ID, "typ": "JWT"})


req = urllib.request.Request(
    "https://api.appstoreconnect.apple.com/v1/builds"
    f"?filter[app]={APP_ID}&limit=10&sort=-uploadedDate",
    headers={"Authorization": "Bearer " + token()})
try:
    with urllib.request.urlopen(req, timeout=60) as f:
        rows = json.load(f).get("data", [])
except urllib.error.HTTPError as e:
    sys.exit(f"App Store Connect returned {e.code}: {e.read().decode()[:300]}")

if not rows:
    print("none NO_BUILDS")
for d in rows:
    a = d["attributes"]
    print(f"{a.get('version')} {a.get('processingState')} uploaded={a.get('uploadedDate')}")
