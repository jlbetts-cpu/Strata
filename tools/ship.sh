#!/bin/bash
#
# Archive, sign, validate, upload to TestFlight, and wait for processing.
#
# **This is the uploader.** Xcode Cloud still builds every push as CI, but it
# is not the thing that ships — one uploader means one build-number sequence
# and no rejected duplicates. See tools/next_build_number.py for the history
# behind that.
#
#   ASC_KEY_ID=... ASC_ISSUER_ID=... tools/ship.sh
#
# Needs: the private key at ~/.appstoreconnect/private_keys/AuthKey_<ID>.p8,
# an Apple Distribution certificate in the keychain, and the App Store
# provisioning profile installed. A python with pyjwt is found automatically
# or passed as PYTHON=...
#
# Every step is checked. The script stops at the first failure rather than
# uploading something it could not verify.

set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO"

: "${ASC_KEY_ID:?set ASC_KEY_ID}"
: "${ASC_ISSUER_ID:?set ASC_ISSUER_ID}"

WORK="${WORK:-$(mktemp -d)}"
ARCHIVE="$WORK/Strata.xcarchive"
EXPORT="$WORK/export"

say() { printf '\n\033[1m==> %s\033[0m\n' "$1"; }

# Find a python that can sign a JWT, and say so NOW rather than after a
# fifteen-minute archive. The system python3 has no pyjwt; a venv usually does.
find_python() {
    for candidate in "${PYTHON:-}" "$REPO/.venv/bin/python" \
                     "$HOME/.strata-venv/bin/python" "$(command -v python3)"; do
        [ -n "$candidate" ] && [ -x "$candidate" ] || continue
        if "$candidate" -c "import jwt" 2>/dev/null; then
            echo "$candidate"
            return 0
        fi
    done
    return 1
}

if ! PYTHON="$(find_python)"; then
    echo "No python with pyjwt found. Create one once:" >&2
    echo "    python3 -m venv ~/.strata-venv" >&2
    echo "    ~/.strata-venv/bin/pip install pyjwt cryptography" >&2
    echo "Or pass PYTHON=/path/to/python with pyjwt installed." >&2
    exit 1
fi
echo "python: $PYTHON"

say "Working tree"
if [ -n "$(git status --porcelain)" ]; then
    echo "Uncommitted changes present. Shipping them anyway, but they are not on"
    echo "the remote, so nobody else can reproduce this build:"
    git status --short
fi
echo "HEAD: $(git log --oneline -1)"

say "Build number"
"$PYTHON" tools/next_build_number.py
BUILD_NUMBER="$(grep -o 'CURRENT_PROJECT_VERSION = [^;]*;' Strata.xcodeproj/project.pbxproj \
    | head -1 | sed -E 's/[^0-9]//g')"
[ -n "$BUILD_NUMBER" ] || { echo "could not read the build number back"; exit 1; }
echo "this build is $BUILD_NUMBER"

say "Archive (Release)"
xcodebuild archive -scheme Strata -configuration Release \
    -destination 'generic/platform=iOS' \
    -archivePath "$ARCHIVE" -quiet

say "Export"
cat > "$WORK/ExportOptions.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key><string>app-store-connect</string>
    <key>teamID</key><string>W34J6358L7</string>
    <key>signingStyle</key><string>manual</string>
    <key>signingCertificate</key><string>Apple Distribution</string>
    <key>provisioningProfiles</key>
    <dict>
        <key>JaydenBetts.Strata</key><string>Strata App Store (cli)</string>
    </dict>
    <key>uploadSymbols</key><true/>
    <key>destination</key><string>export</string>
</dict>
</plist>
PLIST
xcodebuild -exportArchive -archivePath "$ARCHIVE" \
    -exportOptionsPlist "$WORK/ExportOptions.plist" -exportPath "$EXPORT" -quiet

IPA="$EXPORT/Strata.ipa"
[ -f "$IPA" ] || { echo "no .ipa produced"; exit 1; }
echo "$IPA ($(du -h "$IPA" | cut -f1))"

say "Validate"
xcrun altool --validate-app -f "$IPA" -t ios \
    --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"

say "Upload"
xcrun altool --upload-app -f "$IPA" -t ios \
    --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"

say "Waiting for processing"
#
# **Poll for THIS build, never for "the newest".**
#
# The first version of this loop checked whether the top line of the build
# list said VALID. It reported success in 30 seconds — against a build Xcode
# Cloud had uploaded four minutes earlier, while the build this script had
# just uploaded had not even appeared yet. The check passed and the thing it
# claimed to verify had not happened.
#
# That is the failure CLAUDE.md names: an instrument aimed at the wrong thing
# looks exactly like success. So match the exact build number, anchored.
for _ in $(seq 1 40); do
    sleep 30
    line="$("$PYTHON" tools/build_status.py | grep -E "^${BUILD_NUMBER} " || true)"
    if [ -z "$line" ]; then
        echo "build ${BUILD_NUMBER}: not listed yet"
        continue
    fi
    echo "$line"
    case "$line" in
        *" VALID "*|*" VALID")
            echo
            echo "Build ${BUILD_NUMBER} is in TestFlight."
            exit 0
            ;;
        *INVALID*|*FAILED*)
            echo "Build ${BUILD_NUMBER} failed processing. Check your email for the reason." >&2
            exit 1
            ;;
    esac
done

echo "Build ${BUILD_NUMBER} still processing after 20 minutes. Check App Store Connect," >&2
echo "and your email — a rejected upload is reported by email and nowhere else." >&2
exit 1
