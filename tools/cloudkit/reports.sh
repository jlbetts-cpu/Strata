#!/bin/zsh
# The reports people have filed from Crews, newest first, in plain words.
#
#   tools/cloudkit/reports.sh            the last 2 days
#   tools/cloudkit/reports.sh 14         the last 14 days
#
# Needs your iCloud user token once (it reads as you, the Moderator):
#   xcrun cktool save-token --type user
# and your iCloud account given the Moderator role, once, in the CloudKit
# Console (Public Database > Records > Users > your record > roles).
set -euo pipefail
TEAM=W34J6358L7
CONTAINER=iCloud.JaydenBetts.Strata
DAYS=${1:-2}
xcrun cktool query-records --team-id $TEAM --container-id $CONTAINER --environment production \
    --database-type public --record-type Report --limit 200 \
  | python3 -c '
import json, sys, datetime
days = float(sys.argv[1])
data = json.load(sys.stdin)
records = data.get("records", data if isinstance(data, list) else [])
now = datetime.datetime.now(datetime.timezone.utc)
rows = []
for r in records:
    f = r.get("fields", {})
    v = lambda k: (f.get(k) or {}).get("value")
    created = r.get("created", {}).get("timestamp") or r.get("modified", {}).get("timestamp")
    when = datetime.datetime.fromtimestamp(created / 1000, datetime.timezone.utc) if created else None
    if when and (now - when).total_seconds() > days * 86400:
        continue
    photo = (v("photo") or {}).get("downloadURL") if isinstance(v("photo"), dict) else None
    rows.append((when, v("reason"), v("title"), v("crew"), v("senderAccount"), photo))
rows.sort(key=lambda x: x[0] or now, reverse=True)
if not rows:
    print(f"No reports in the last {days:g} days.")
for when, reason, title, crew, account, photo in rows:
    print(f"{when:%Y-%m-%d %H:%M} UTC  {reason}  \"{title or \"(no title)\"}\"")
    print(f"    sender account: {account or \"unknown\"}   crew: {crew}")
    if photo: print(f"    photo: {photo}")
    print(f"    to ban: tools/cloudkit/ban.sh {account} \"{reason}\"" if account else "")
' "$DAYS"
