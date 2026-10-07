#!/bin/bash
#
# Stackz installer.
#
#   curl -fsSL https://raw.githubusercontent.com/indiefan/stackz/main/install.sh | bash
#
# Installs the latest signed release, which keeps itself up to date afterwards. When no
# release is available it builds Stackz from source instead, and that needs Apple's
# Command Line Tools. Run from a clone (./install.sh) it always builds that checkout.
#
# Environment:
#   STACKZ_FROM_SOURCE  Set to 1 to build from source even when a release exists
#   STACKZ_REF          Branch, tag or commit to build from source (default: main)
#   STACKZ_INSTALL_DIR  Destination folder (default: /Applications, or ~/Applications if that isn't writable)
#   STACKZ_NO_LAUNCH    Set to 1 to install without quitting or launching Stackz
#
# Never uses sudo.

set -euo pipefail

REPO="indiefan/stackz"
APP="Stackz.app"
BUNDLE_ID="io.github.indiefan.stackz"
MIN_MACOS=13
TMP_DIR=""

# The Apple developer team that signs official releases. A download signed by anyone
# else is refused. While this is empty the installer always builds from source.
TEAM_ID="6P8F6NCJ3D"

say()  { printf '==> %s\n' "$*"; }
fail() { printf 'Error: %s\n' "$*" >&2; exit 1; }

cleanup() {
    if [ -n "$TMP_DIR" ]; then
        rm -rf "$TMP_DIR"
    fi
}
trap cleanup EXIT

# Downloads the latest release into $TMP_DIR/release and checks it.
# Returns 1 if no release has been published; any other problem is fatal.
fetch_release() {
    local zip="$TMP_DIR/Stackz.zip" status
    say "Downloading the latest release"
    status="$(curl -sSL -o "$zip" -w '%{http_code}' "https://github.com/$REPO/releases/latest/download/Stackz.zip")" \
        || fail "Could not reach GitHub."
    if [ "$status" = "404" ]; then
        return 1
    fi
    [ "$status" = "200" ] || fail "GitHub answered $status when asked for the latest release."

    mkdir "$TMP_DIR/release"
    ditto -x -k "$zip" "$TMP_DIR/release" || fail "The downloaded archive could not be unpacked."

    # Intact, the bundle we expect, and signed with a Developer ID certificate from our team
    local app="$TMP_DIR/release/$APP"
    local requirement="identifier \"$BUNDLE_ID\" and anchor apple generic and certificate 1[field.1.2.840.113635.100.6.2.6] exists and certificate leaf[field.1.2.840.113635.100.6.1.13] exists and certificate leaf[subject.OU] = \"$TEAM_ID\""
    if [ ! -d "$app" ] \
        || ! codesign --verify --deep --strict "$app" 2>/dev/null \
        || ! codesign --verify -R="$requirement" "$app" 2>/dev/null; then
        fail "The downloaded app is not a genuine Stackz release, so it was not installed. Please report this at https://github.com/$REPO/issues"
    fi
}

# Builds the checkout named by $1, or a freshly downloaded copy when $1 is empty.
build_from_source() {
    local here="$1" src

    if ! xcode-select -p >/dev/null 2>&1 || ! xcrun --find swiftc >/dev/null 2>&1; then
        fail "No working Swift compiler found. Install Apple's Command Line Tools with 'xcode-select --install' (or open Xcode once to finish its setup), then run this again."
    fi

    if [ -n "$here" ]; then
        src="$here"
        say "Using the source in $src"
    else
        local ref="${STACKZ_REF:-main}"
        src="$TMP_DIR/source"
        mkdir "$src"
        say "Downloading the Stackz source ($ref)"
        curl -fsSL "https://github.com/$REPO/archive/$ref.tar.gz" | tar -xz -C "$src" --strip-components 1 \
            || fail "Could not download '$ref' from https://github.com/$REPO"
    fi

    say "Building"
    ( cd "$src" && bash ./build.sh ) || fail "The build failed. The compiler output above says why."
    [ -d "$src/$APP" ] || fail "The build finished without producing $APP."
    BUILT_APP="$src/$APP"
}

# Everything runs from main, called on the last line, so a download that is cut
# off partway through never executes half a script.
main() {
    [ "$(uname -s)" = "Darwin" ] || fail "Stackz only runs on macOS."

    local macos_version macos_major
    macos_version="$(sw_vers -productVersion)"
    macos_major="${macos_version%%.*}"
    [ "$macos_major" -ge "$MIN_MACOS" ] || fail "Stackz needs macOS $MIN_MACOS or later (this Mac runs $macos_version)."

    TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/stackz-install.XXXXXX")"

    # A clone builds itself. Otherwise prefer the signed release.
    local here=""
    if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
        here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        if [ ! -f "$here/build.sh" ] || [ ! -d "$here/Sources" ]; then
            here=""
        fi
    fi

    local from_release=0
    BUILT_APP=""
    if [ -z "$here" ] && [ -n "$TEAM_ID" ] && [ "${STACKZ_FROM_SOURCE:-0}" != "1" ] && [ -z "${STACKZ_REF:-}" ]; then
        if fetch_release; then
            from_release=1
            BUILT_APP="$TMP_DIR/release/$APP"
        else
            say "No release has been published yet"
        fi
    fi
    if [ "$from_release" = "0" ]; then
        build_from_source "$here"
    fi

    local dest="${STACKZ_INSTALL_DIR:-}"
    if [ -z "$dest" ]; then
        if [ -w /Applications ]; then
            dest="/Applications"
        else
            dest="$HOME/Applications"
        fi
    fi
    mkdir -p "$dest"
    dest="$(cd "$dest" && pwd)"

    local updating=0
    if [ -d "$dest/$APP" ]; then
        updating=1
    fi

    local launch=1
    if [ "${STACKZ_NO_LAUNCH:-0}" = "1" ]; then
        launch=0
    fi

    # Two copies would both try to claim the same global shortcuts.
    if [ "$launch" = "1" ] && pgrep -x Stackz >/dev/null 2>&1; then
        say "Quitting the running copy of Stackz"
        pkill -x Stackz || true
        local waited=0
        while pgrep -x Stackz >/dev/null 2>&1 && [ "$waited" -lt 25 ]; do
            sleep 0.2
            waited=$((waited + 1))
        done
    fi

    say "Installing $dest/$APP"
    rm -rf "$dest/$APP"
    ditto "$BUILT_APP" "$dest/$APP"

    if [ "$launch" = "1" ]; then
        open "$dest/$APP"
    fi

    cat <<EOF

Stackz is installed in $dest.

  1. Allow it under System Settings > Privacy & Security > Accessibility.
     macOS asks the first time Stackz launches; it cannot move windows without this.
  2. Optional: allow Screen Recording in the same place so the Spin switcher
     can show window previews.
  3. Look for the grid icon in the menu bar. Settings opens on launch.

Your layout and shortcuts are stored in ~/.stackz.json.
EOF

    if [ "$from_release" = "1" ]; then
        cat <<EOF
Stackz checks for updates by itself. The switch is in Settings > General.
EOF
    else
        cat <<EOF
This copy was built from source and does not update itself. Run the installer
again to get a newer version.
EOF
    fi

    # macOS ties the Accessibility grant to the code signature, and an ad-hoc
    # signature changes with every build.
    local signature
    signature="$(codesign -dv "$dest/$APP" 2>&1 || true)"
    if [ "$updating" = "1" ] && [[ "$signature" == *"Signature=adhoc"* ]]; then
        cat <<EOF

This replaced an earlier copy, and this build is ad-hoc signed, so macOS treats it
as a different app. If shortcuts stop moving windows, run

    tccutil reset Accessibility $BUNDLE_ID

then reopen Stackz and allow it again.
EOF
    fi
}

main "$@"
