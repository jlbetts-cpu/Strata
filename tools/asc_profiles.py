#!/usr/bin/env python3
"""App Store provisioning profiles, through the App Store Connect API.

    ASC_KEY_ID=... ASC_ISSUER_ID=... tools/asc_profiles.py list
    ... tools/asc_profiles.py install "<profile name>"
    ... tools/asc_profiles.py create <bundle identifier> "<profile name>"

`list` reads. `install` downloads a profile that already exists in the account
and puts it where xcodebuild looks. `create` makes a new App Store profile for
a bundle identifier, signed by the account's Apple Distribution certificate,
and installs it. Written 2026-10-02, when build 35 archived and then could not
be exported: the app's installed profile predated iCloud and the widget had
none, and this Mac has no Apple ID signed in to Xcode to make them.

Run with the python tools/ship.sh finds (one with pyjwt).
"""
import base64
import json
import os
import sys
import time
import urllib.error
import urllib.request

import jwt

KEY_ID = os.environ.get("ASC_KEY_ID")
ISSUER = os.environ.get("ASC_ISSUER_ID")
if not (KEY_ID and ISSUER):
    sys.exit("set ASC_KEY_ID and ASC_ISSUER_ID")
KEY_PATH = os.path.expanduser(f"~/.appstoreconnect/private_keys/AuthKey_{KEY_ID}.p8")
API = "https://api.appstoreconnect.apple.com/v1"
INSTALL_DIR = os.path.expanduser("~/Library/MobileDevice/Provisioning Profiles")


def token():
    now = int(time.time())
    with open(KEY_PATH) as f:
        return jwt.encode({"iss": ISSUER, "iat": now, "exp": now + 1200, "aud": "appstoreconnect-v1"},
                          f.read(), algorithm="ES256", headers={"kid": KEY_ID, "typ": "JWT"})


def call(method, path, body=None):
    req = urllib.request.Request(API + path, method=method,
                                 data=json.dumps(body).encode() if body else None,
                                 headers={"Authorization": "Bearer " + token(),
                                          "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=60) as f:
            return json.load(f)
    except urllib.error.HTTPError as e:
        sys.exit(f"{method} {path} -> {e.code}: {e.read().decode()[:600]}")


def profiles():
    out = call("GET", "/profiles?limit=200&include=bundleId&fields[bundleIds]=identifier")
    ids = {b["id"]: b["attributes"]["identifier"] for b in out.get("included", []) if b["type"] == "bundleIds"}
    rows = []
    for p in out["data"]:
        a = p["attributes"]
        bid = p["relationships"]["bundleId"]["data"]["id"]
        rows.append((a["name"], a["profileType"], a["profileState"], ids.get(bid, bid), a["expirationDate"][:10], p))
    return rows


def install(p):
    data = base64.b64decode(p["attributes"]["profileContent"])
    os.makedirs(INSTALL_DIR, exist_ok=True)
    path = os.path.join(INSTALL_DIR, p["attributes"]["uuid"] + ".mobileprovision")
    with open(path, "wb") as f:
        f.write(data)
    print(f"installed {p['attributes']['name']} -> {path}")


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "list"
    if cmd == "list":
        for name, kind, state, bundle, exp, _ in profiles():
            print(f"{name:40} {kind:20} {state:10} {bundle:36} {exp}")
    elif cmd == "install":
        name = sys.argv[2]
        match = [r[5] for r in profiles() if r[0] == name]
        if not match:
            sys.exit(f"no profile named {name!r}")
        install(match[0])
    elif cmd == "create":
        identifier, name = sys.argv[2], sys.argv[3]
        bundles = call("GET", f"/bundleIds?filter[identifier]={identifier}&limit=5")["data"]
        bundle = next((b for b in bundles if b["attributes"]["identifier"] == identifier), None)
        if not bundle:
            sys.exit(f"no bundle id {identifier} in the account")
        certs = [c for c in call("GET", "/certificates?limit=50")["data"]
                 if c["attributes"]["certificateType"] in ("DISTRIBUTION", "IOS_DISTRIBUTION")]
        if not certs:
            sys.exit("no Apple Distribution certificate in the account")
        body = {"data": {"type": "profiles",
                         "attributes": {"name": name, "profileType": "IOS_APP_STORE"},
                         "relationships": {
                             "bundleId": {"data": {"type": "bundleIds", "id": bundle["id"]}},
                             "certificates": {"data": [{"type": "certificates", "id": c["id"]} for c in certs]}}}}
        made = call("POST", "/profiles", body)["data"]
        print(f"created {name} for {identifier}")
        install(made)
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
