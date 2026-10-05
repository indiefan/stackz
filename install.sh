#!/bin/bash
#
# Stackz installer: builds Stackz from source and installs Stackz.app.
#
#   curl -fsSL https://raw.githubusercontent.com/indiefan/stackz/main/install.sh | bash
#
# Run from a clone (./install.sh) it builds that checkout instead of downloading.
#
# Environment:
#   STACKZ_REF          Branch, tag or commit to install (default: main)
#   STACKZ_INSTALL_DIR  Destination folder (default: /Applications, or ~/Applications if that isn't writable)
#   STACKZ_NO_LAUNCH    Set to 1 to install without quitting or launching Stackz
#
# Never uses sudo.

set -euo pipefail

REPO="indiefan/stackz"
APP="Stackz.app"
MIN_MACOS=13
TMP_DIR=""

say()  { printf '==> %s\n' "$*"; }
fail() { printf 'Error: %s\n' "$*" >&2; exit 1; }

cleanup() {
    if [ -n "$TMP_DIR" ]; then
        rm -rf "$TMP_DIR"
    fi
}
trap cleanup EXIT

# Everything runs from main, called on the last line, so a download that is cut
# off partway through never executes half a script.
main() {
    [ "$(uname -s)" = "Darwin" ] || fail "Stackz only runs on macOS."

    local macos_version macos_major
    macos_version="$(sw_vers -productVersion)"
    macos_major="${macos_version%%.*}"
    [ "$macos_major" -ge "$MIN_MACOS" ] || fail "Stackz needs macOS $MIN_MACOS or later (this Mac runs $macos_version)."

    if ! xcode-select -p >/dev/null 2>&1 || ! xcrun --find swiftc >/dev/null 2>&1; then
        fail "No working Swift compiler found. Install Apple's Command Line Tools with 'xcode-select --install' (or open Xcode once to finish its setup), then run this again."
    fi

    # Use this checkout when run from a clone, otherwise download the source.
    local here="" src
    if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
        here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    fi
    if [ -n "$here" ] && [ -f "$here/build.sh" ] && [ -d "$here/Sources" ]; then
        src="$here"
        say "Using the source in $src"
    else
        local ref="${STACKZ_REF:-main}"
        TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/stackz-install.XXXXXX")"
        src="$TMP_DIR"
        say "Downloading Stackz ($ref)"
        curl -fsSL "https://github.com/$REPO/archive/$ref.tar.gz" | tar -xz -C "$src" --strip-components 1 \
            || fail "Could not download '$ref' from https://github.com/$REPO"
    fi

    say "Building"
    ( cd "$src" && bash ./build.sh ) || fail "The build failed. The compiler output above says why."
    [ -d "$src/$APP" ] || fail "The build finished without producing $APP."

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
    ditto "$src/$APP" "$dest/$APP"

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

    # macOS ties the Accessibility grant to the code signature, and an ad-hoc
    # signature changes with every build.
    local signature
    signature="$(codesign -dv "$dest/$APP" 2>&1 || true)"
    if [ "$updating" = "1" ] && [[ "$signature" == *"Signature=adhoc"* ]]; then
        local bundle_id
        bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$dest/$APP/Contents/Info.plist")"
        cat <<EOF

This replaced an earlier copy, and this build is ad-hoc signed, so macOS treats it
as a different app. If shortcuts stop moving windows, run

    tccutil reset Accessibility $bundle_id

then reopen Stackz and allow it again.
EOF
    fi
}

main "$@"
