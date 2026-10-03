#!/bin/zsh
# Bans an iCloud account from Crews, everywhere: every phone drops them, and
# their wins and reactions, within the hour. Only the Moderator role can write
# a Ban, so only you can.
#
#   tools/cloudkit/ban.sh _abc123def456 "harassment"
#
# The account comes from tools/cloudkit/reports.sh. Same one-time setup.
set -euo pipefail
ACCOUNT=${1:?the sender account from reports.sh}
REASON=${2:-reported}
xcrun cktool create-record --team-id W34J6358L7 --container-id iCloud.JaydenBetts.Strata \
    --environment production --database-type public --record-type Ban \
    --fields-json "{\"account\":{\"type\":\"STRING\",\"value\":\"$ACCOUNT\"},\"reason\":{\"type\":\"STRING\",\"value\":\"$REASON\"}}" >/dev/null
echo "Banned $ACCOUNT. Every phone drops them within the hour."
