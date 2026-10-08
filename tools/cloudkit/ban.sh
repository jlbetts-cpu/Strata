#!/bin/zsh
# Bans an iCloud account from Crews, everywhere: every phone drops them, and
# their wins and reactions, within a day, or as soon as it opens a crew. Only the Moderator role can write
# a Ban, so only you can.
#
#   tools/cloudkit/ban.sh _abc123def456 "harassment"
#
# The account comes from tools/cloudkit/reports.sh. Same one-time setup.
set -euo pipefail
ACCOUNT=${1:?the sender account from reports.sh}
REASON=${2:-reported}
# The Ban carries the account only: every phone reads Bans. Why goes in a
# BanNote, which only the Moderator role can read (2026-10-08).
xcrun cktool create-record --team-id W34J6358L7 --container-id iCloud.JaydenBetts.Strata \
    --environment production --database-type public --record-type Ban \
    --fields-json "{\"account\":{\"type\":\"STRING\",\"value\":\"$ACCOUNT\"}}" >/dev/null
xcrun cktool create-record --team-id W34J6358L7 --container-id iCloud.JaydenBetts.Strata \
    --environment production --database-type public --record-type BanNote \
    --fields-json "{\"account\":{\"type\":\"STRING\",\"value\":\"$ACCOUNT\"},\"reason\":{\"type\":\"STRING\",\"value\":\"$REASON\"}}" >/dev/null
echo "Banned $ACCOUNT. Every phone drops them within a day, or as soon as it opens a crew."
