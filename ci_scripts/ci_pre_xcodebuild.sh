#!/bin/sh
set -e

# Give every Xcode Cloud build a unique build number.
#
# **Without this the second upload is rejected.** App Store Connect
# refuses a CFBundleVersion it has already seen, and this project pins
# CURRENT_PROJECT_VERSION = 1 in the project file — so build 2, and
# every build after it, would arrive claiming to be build 1 and bounce.
# It is a twenty-minute round trip to find that out, which is why it is
# worth a five-line script.
#
# CFBundleVersion is not written anywhere in this repo: the target sets
# GENERATE_INFOPLIST_FILE = YES, so Xcode synthesises Info.plist and
# takes CFBundleVersion from CURRENT_PROJECT_VERSION. That build setting
# is therefore the thing to rewrite, not a plist.
#
# CI_BUILD_NUMBER is supplied by Xcode Cloud and increases per build.
# The marketing version (MARKETING_VERSION, "1.0") is deliberately left
# alone — that one is a product decision, not a counter.

if [ -z "$CI_BUILD_NUMBER" ]; then
    echo "Not running in Xcode Cloud; leaving the build number alone."
    exit 0
fi

PROJECT="${CI_PRIMARY_REPOSITORY_PATH:-$(cd "$(dirname "$0")/.." && pwd)}/Strata.xcodeproj/project.pbxproj"
echo "Setting CURRENT_PROJECT_VERSION to $CI_BUILD_NUMBER in $PROJECT"
sed -i '' -E "s/CURRENT_PROJECT_VERSION = [^;]*;/CURRENT_PROJECT_VERSION = $CI_BUILD_NUMBER;/g" "$PROJECT"
grep -c "CURRENT_PROJECT_VERSION = $CI_BUILD_NUMBER;" "$PROJECT"
