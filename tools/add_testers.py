#!/usr/bin/env python3
"""Add external TestFlight testers and submit a build for Beta App Review.

    ASC_KEY_ID=... ASC_ISSUER_ID=... python3 tools/add_testers.py a@b.com c@d.com

External testers need no App Store Connect account, which is the whole reason
to prefer them over internal testers for friends: an internal tester has to be
a user on the developer account, with real access to it.

**Only an APP_STORE_ELIGIBLE build can go to external testers**, and a build's
audience is fixed when it is uploaded — it cannot be patched afterwards
(the API answers 409, "the attribute 'buildAudienceType' can not be included
in a 'UPDATE' operation"). Xcode Cloud stamps its builds INTERNAL_ONLY, so the
newest build overall is often not submittable and this picks the newest one
that is. tools/ship.sh produces eligible builds.

Idempotent: the group is reused, testers already present are left alone, and a
build already submitted is not resubmitted.
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
GROUP_NAME = os.environ.get("ASC_GROUP", "Friends")
if not (KEY_ID and ISSUER):
    sys.exit("set ASC_KEY_ID and ASC_ISSUER_ID")

KEY_PATH = os.path.expanduser(f"~/.appstoreconnect/private_keys/AuthKey_{KEY_ID}.p8")
API = "https://api.appstoreconnect.apple.com"
TESTERS = sys.argv[1:]


def token():
    now = int(time.time())
    with open(KEY_PATH) as f:
        return jwt.encode({"iss": ISSUER, "iat": now, "exp": now + 1200,
                           "aud": "appstoreconnect-v1"},
                          f.read(), algorithm="ES256",
                          headers={"kid": KEY_ID, "typ": "JWT"})


def call(method, path, body=None):
    data = json.dumps(body).encode() if body else None
    req = urllib.request.Request(
        API + path, data=data, method=method,
        headers={"Authorization": "Bearer " + token(),
                 "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=60) as f:
            txt = f.read().decode()
            return f.status, (json.loads(txt) if txt else {})
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read().decode() or "{}")


def errors(body):
    return "; ".join(f"{e.get('title')}: {e.get('detail')}" for e in body.get("errors", []))


code, body = call("GET", f"/v1/apps/{APP_ID}/betaGroups?limit=50")
group_id = next((g["id"] for g in body.get("data", []) if code == 200
                 and g["attributes"].get("name") == GROUP_NAME), None)
if group_id:
    print(f"group '{GROUP_NAME}': exists")
else:
    code, body = call("POST", "/v1/betaGroups", {
        "data": {"type": "betaGroups",
                 "attributes": {"name": GROUP_NAME, "publicLinkEnabled": False,
                                "hasAccessToAllBuilds": True},
                 "relationships": {"app": {"data": {"type": "apps", "id": APP_ID}}}}})
    if code not in (200, 201):
        sys.exit(f"could not create group: {code} {errors(body)}")
    group_id = body["data"]["id"]
    print(f"group '{GROUP_NAME}': created")

code, body = call("GET", f"/v1/betaGroups/{group_id}/betaTesters?limit=200")
present = {d["attributes"].get("email", "").lower()
           for d in body.get("data", [])} if code == 200 else set()

for email in TESTERS:
    if email.lower() in present:
        print(f"  {email}: already a member")
        continue
    code, body = call("POST", "/v1/betaTesters", {
        "data": {"type": "betaTesters", "attributes": {"email": email},
                 "relationships": {"betaGroups": {
                     "data": [{"type": "betaGroups", "id": group_id}]}}}})
    print(f"  {email}: " + ("added" if code in (200, 201)
                            else f"FAILED ({code}) {errors(body)}"))

code, body = call("GET", f"/v1/builds?filter[app]={APP_ID}&limit=20&sort=-version")
valid = [d for d in body.get("data", [])
         if d["attributes"].get("processingState") == "VALID"]
eligible = [d for d in valid
            if d["attributes"].get("buildAudienceType") == "APP_STORE_ELIGIBLE"]
if not eligible:
    sys.exit("\nNo APP_STORE_ELIGIBLE build exists — every valid build is "
             "INTERNAL_ONLY, which is what Xcode Cloud produces.\n"
             "Run tools/ship.sh to upload one.")

skipped = [d["attributes"]["version"] for d in valid if d not in eligible]
if skipped:
    print("\nskipping internal-only builds:", ", ".join(skipped))

build = eligible[0]
print(f"build {build['attributes']['version']} (APP_STORE_ELIGIBLE)")
code, body = call("GET", f"/v1/builds/{build['id']}/betaAppReviewSubmission")
if code == 200 and body.get("data"):
    print("  already submitted; state:", body["data"]["attributes"].get("betaReviewState"))
else:
    code, body = call("POST", "/v1/betaAppReviewSubmissions", {
        "data": {"type": "betaAppReviewSubmissions",
                 "relationships": {"build": {"data": {"type": "builds", "id": build["id"]}}}}})
    print("  " + (f"submitted; state: {body['data']['attributes'].get('betaReviewState')}"
                  if code in (200, 201) else f"submit FAILED ({code}) {errors(body)}"))
