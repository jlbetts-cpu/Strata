#!/bin/zsh
# Adds the Crews record types to the CloudKit DEVELOPMENT schema of
# iCloud.JaydenBetts.Strata, keeping every type already there (the SwiftData
# mirror's CD_ types among them). Then deploy development to production once,
# in the CloudKit Console: TestFlight and App Store builds use production, and
# production refuses a record type it has never seen.
#
# One-time setup (yours, it is a credential):
#   1. CloudKit Console > Settings > Tokens > Management token > create, copy.
#   2. xcrun cktool save-token --type management     (paste it at the prompt)
# Then:
#   tools/cloudkit/add-crews-schema.sh
#   CloudKit Console > iCloud.JaydenBetts.Strata > Deploy Schema Changes > Deploy
set -euo pipefail
TEAM=W34J6358L7
CONTAINER=iCloud.JaydenBetts.Strata
HERE=${0:A:h}
WORK=$(mktemp -d)
xcrun cktool export-schema --team-id $TEAM --container-id $CONTAINER --environment development \
    --output-file $WORK/current.ckdb
python3 - "$WORK/current.ckdb" "$HERE/crews-types.ckdb" "$WORK/merged.ckdb" <<'PY'
import re, sys
current, extra, out = (open(p).read() if i < 2 else p for i, p in enumerate(sys.argv[1:]))
have = set(re.findall(r'RECORD TYPE\s+(\w+)', current))
blocks = re.split(r'(?=\n\s*(?://[^\n]*\n\s*)*RECORD TYPE )', extra)
add = [b for b in blocks if (m := re.search(r'RECORD TYPE\s+(\w+)', b)) and m.group(1) not in have]
open(out, 'w').write(current.rstrip() + '\n' + '\n'.join(add) + '\n')
print('adding:', [re.search(r'RECORD TYPE\s+(\w+)', b).group(1) for b in add] or 'nothing, all present')
PY
xcrun cktool import-schema --team-id $TEAM --container-id $CONTAINER --environment development \
    --validate --file $WORK/merged.ckdb
echo "Development has the Crews types. Now deploy to production in the CloudKit Console."
