#!/bin/bash
#
# Builds, signs, notarizes and publishes a Stackz release. See RELEASING.md.
#
#   ./release.sh            Publish the version in VERSION as a GitHub release
#   ./release.sh --dry-run  Rehearse: build, package and write the appcast into dist/
#                           without notarizing or publishing. With CODESIGN_IDENTITY=-
#                           this works without a Developer ID certificate.
#
# Credentials come from the keychain on a Mac, or from the environment in CI:
#   CODESIGN_IDENTITY     Signing identity (default: the first Developer ID Application certificate)
#   NOTARY_PROFILE        notarytool keychain profile (default: stackz-notary)
#   NOTARY_KEY_PATH, NOTARY_KEY_ID, NOTARY_ISSUER_ID
#                         App Store Connect API key, used instead of the profile when set
#   SPARKLE_PRIVATE_KEY   Key that signs updates (default: read from the keychain)

set -euo pipefail
cd "$(dirname "$0")"

REPO="indiefan/stackz"
APP="Stackz.app"
DIST="dist"
VERSION="$(cat VERSION)"
TAG="v$VERSION"
SPARKLE_BIN=".build/artifacts/sparkle/Sparkle/bin"

DRY_RUN=0
if [ "${1:-}" = "--dry-run" ]; then
    DRY_RUN=1
fi

say()  { printf '==> %s\n' "$*"; }
fail() { printf 'Error: %s\n' "$*" >&2; exit 1; }

if [ "$DRY_RUN" = 0 ]; then
    [ -z "$(git status --porcelain)" ] || fail "There are uncommitted changes. Commit them so the release matches a commit."
    command -v gh >/dev/null || fail "The GitHub CLI (gh) is needed to publish. Install it or use the release workflow."
    if gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1; then
        fail "$TAG is already published. Raise the number in VERSION first."
    fi
    if [ -z "${GITHUB_ACTIONS:-}" ] && [ -z "$(git branch -r --contains HEAD)" ]; then
        fail "This commit has not been pushed. Push it so the release tag points at something on GitHub."
    fi
fi

say "Building Stackz $VERSION"
./build.sh --release
codesign --verify --deep --strict "$APP" || fail "The signed app does not verify."

rm -rf "$DIST"
mkdir -p "$DIST"

if [ "$DRY_RUN" = 0 ]; then
    # install.sh only accepts downloads signed by the team it names, so the two must agree
    TEAM="$(codesign -dv "$APP" 2>&1 | sed -n 's/^TeamIdentifier=//p')"
    grep -q "^TEAM_ID=\"$TEAM\"$" install.sh \
        || fail "install.sh does not trust this certificate's team. Set TEAM_ID=\"$TEAM\" in install.sh, commit, push, and run this again."

    if [ -n "${NOTARY_KEY_PATH:-}" ]; then
        NOTARY_ARGS=(--key "$NOTARY_KEY_PATH" --key-id "$NOTARY_KEY_ID" --issuer "$NOTARY_ISSUER_ID")
    else
        NOTARY_ARGS=(--keychain-profile "${NOTARY_PROFILE:-stackz-notary}")
    fi

    say "Notarizing (Apple usually answers within a few minutes)"
    ditto -c -k --keepParent "$APP" "$DIST/notarize.zip"
    xcrun notarytool submit "$DIST/notarize.zip" "${NOTARY_ARGS[@]}" --wait | tee "$DIST/notary.log"
    grep -q "status: Accepted" "$DIST/notary.log" \
        || fail "Apple did not accept the build. 'xcrun notarytool log <submission id>' shows why."
    xcrun stapler staple "$APP"
    rm "$DIST/notarize.zip" "$DIST/notary.log"
fi

say "Packaging"
ditto -c -k --keepParent "$APP" "$DIST/Stackz.zip"

# The appcast tells installed copies about this version. It lists only the newest
# release, and each release carries its own copy, so releases/latest/download/appcast.xml
# always describes the current one.
say "Writing the appcast"
APPCAST_ARGS=(
    --download-url-prefix "https://github.com/$REPO/releases/download/$TAG/"
    --link "https://github.com/$REPO"
    --full-release-notes-url "https://github.com/$REPO/releases"
    -o "$DIST/appcast.xml"
)
if [ -n "${SPARKLE_PRIVATE_KEY:-}" ]; then
    printf '%s' "$SPARKLE_PRIVATE_KEY" | "$SPARKLE_BIN/generate_appcast" --ed-key-file - "${APPCAST_ARGS[@]}" "$DIST"
else
    "$SPARKLE_BIN/generate_appcast" "${APPCAST_ARGS[@]}" "$DIST"
fi
grep -q 'sparkle:edSignature=' "$DIST/appcast.xml" || fail "The appcast was written without a signature."

if [ "$DRY_RUN" = 1 ]; then
    say "Dry run finished. Nothing was notarized or published."
    ls -lh "$DIST"
    exit 0
fi

say "Publishing $TAG"
gh release create "$TAG" "$DIST/Stackz.zip" "$DIST/appcast.xml" \
    --repo "$REPO" \
    --target "$(git rev-parse HEAD)" \
    --title "Stackz $VERSION" \
    --generate-notes

say "Released: https://github.com/$REPO/releases/tag/$TAG"
