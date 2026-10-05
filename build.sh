#!/bin/bash
set -e

# Usage: ./build.sh              Build for this Mac. The updater is off.
#        ./build.sh --universal  The same, for arm64 + x86_64.
#        ./build.sh --release    Universal, updater on, signed for distribution with a
#                                Developer ID certificate. See RELEASING.md.

cd "$(dirname "$0")"

APP_NAME="Stackz"
BUNDLE_IDENTIFIER="io.github.indiefan.stackz"
APP_DIR="$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
FRAMEWORKS_DIR="$CONTENTS_DIR/Frameworks"
VERSION="$(cat VERSION)"

# Where release builds look for updates, and the public half of the key that signs them.
# Only --release puts these in Info.plist; without them the app has no updater.
FEED_URL="https://github.com/indiefan/stackz/releases/latest/download/appcast.xml"
PUBLIC_ED_KEY="a24immBeXyo76C/m2VqY2ghn34tczNRSoTnhGX0sSFI="

ARCHS="$(uname -m)"
RELEASE=0
case "$1" in
    --universal) ARCHS="arm64 x86_64" ;;
    --release)   ARCHS="arm64 x86_64"; RELEASE=1 ;;
esac

if [ "$RELEASE" = 1 ]; then
    # Find the signing certificate before spending time on the build
    IDENTITY="$CODESIGN_IDENTITY"
    if [ -z "$IDENTITY" ]; then
        IDENTITY=$(security find-identity -p codesigning -v | grep "Developer ID Application" | head -n 1 | awk -F '"' '{print $2}')
    fi
    if [ -z "$IDENTITY" ]; then
        echo "No Developer ID Application certificate found in the keychain. See RELEASING.md."
        exit 1
    fi
fi

# Compile one slice per architecture. SwiftPM also fetches Sparkle on the first run.
echo "Compiling Swift files ($ARCHS)..."
SLICES=()
for ARCH in $ARCHS; do
    swift build -c release --arch "$ARCH"
    BIN_DIR="$(swift build -c release --arch "$ARCH" --show-bin-path)"
    SLICES+=("$BIN_DIR/$APP_NAME")
done

# Clean up
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"
mkdir -p "$FRAMEWORKS_DIR"

# Generate Info.plist
cat <<EOF > "$CONTENTS_DIR/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_IDENTIFIER</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/> <!-- Run as menu bar agent, no dock icon -->
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

if [ "$RELEASE" = 1 ]; then
    /usr/libexec/PlistBuddy \
        -c "Add :SUFeedURL string $FEED_URL" \
        -c "Add :SUPublicEDKey string $PUBLIC_ED_KEY" \
        "$CONTENTS_DIR/Info.plist"
fi

# Copy the default config and the license notices into app bundle Resources
cp Resources/default_config.json "$RESOURCES_DIR/default_config.json"
cp LICENSE THIRD_PARTY_NOTICES.md "$RESOURCES_DIR/"

# Merge the slices into the final executable
if [ "${#SLICES[@]}" -gt 1 ]; then
    lipo -create "${SLICES[@]}" -output "$MACOS_DIR/$APP_NAME"
else
    cp "${SLICES[0]}" "$MACOS_DIR/$APP_NAME"
fi

# Embed Sparkle (ditto keeps the framework's symlinks) and point the executable at it.
# The linker's own signature comes off first, since the edits below would break it.
ditto "$BIN_DIR/Sparkle.framework" "$FRAMEWORKS_DIR/Sparkle.framework"
codesign --remove-signature "$MACOS_DIR/$APP_NAME"
install_name_tool -add_rpath "@executable_path/../Frameworks" "$MACOS_DIR/$APP_NAME"

# SwiftPM leaves the build machine's toolchain path in the executable. Drop it.
otool -l "$MACOS_DIR/$APP_NAME" | awk '/LC_RPATH/ { getline; getline; print $2 }' | sort -u | while read -r RPATH; do
    case "$RPATH" in
        /usr/lib/swift|@*) ;;
        *) install_name_tool -delete_rpath "$RPATH" "$MACOS_DIR/$APP_NAME" ;;
    esac
done

if [ "$RELEASE" = 1 ]; then
    # Distribution: a Developer ID signature with the hardened runtime and a secure
    # timestamp, which is what notarization requires
    echo "Codesigning app for release with: $IDENTITY"
    SIGN=(codesign --force --sign "$IDENTITY" --options runtime)
    if [ "$IDENTITY" != "-" ]; then
        # An ad-hoc identity (-) only rehearses the pipeline and cannot be timestamped
        SIGN+=(--timestamp)
    fi

    # Sparkle's helpers are signed one by one, innermost first. --deep would drop the
    # entitlements Downloader.xpc carries.
    SPARKLE="$FRAMEWORKS_DIR/Sparkle.framework"
    "${SIGN[@]}" "$SPARKLE/Versions/B/XPCServices/Installer.xpc"
    "${SIGN[@]}" --preserve-metadata=entitlements "$SPARKLE/Versions/B/XPCServices/Downloader.xpc"
    "${SIGN[@]}" "$SPARKLE/Versions/B/Autoupdate"
    "${SIGN[@]}" "$SPARKLE/Versions/B/Updater.app"
    "${SIGN[@]}" "$SPARKLE"
    "${SIGN[@]}" "$APP_DIR"
else
    # Local use: codesign with an Apple Development certificate to persist Accessibility permissions
    echo "Codesigning app for local use..."
    DEV_IDENTITY=$(security find-identity -p codesigning -v | grep "Apple Development" | head -n 1 | awk -F '"' '{print $2}')

    if [ -n "$DEV_IDENTITY" ]; then
        echo "Found Apple Development certificate: $DEV_IDENTITY"
        codesign --force --deep --sign "$DEV_IDENTITY" "$APP_DIR"
    else
        echo "No Apple Development certificate found, falling back to ad-hoc signature."
        codesign --force --deep --sign - "$APP_DIR"
    fi
fi

echo "Build successful: $APP_DIR ($VERSION)"
