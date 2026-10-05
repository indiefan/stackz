#!/bin/bash
set -e

APP_NAME="Stackz"
BUNDLE_IDENTIFIER="io.github.indiefan.stackz"
APP_DIR="$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
SOURCES_DIR="Sources"

# Build for this Mac's architecture by default; pass --universal for arm64 + x86_64
ARCHS="$(uname -m)"
if [ "$1" = "--universal" ]; then
    ARCHS="arm64 x86_64"
fi

# Clean up
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

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
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/> <!-- Run as menu bar agent, no dock icon -->
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

# Copy default config into app bundle Resources
cp Resources/default_config.json "$RESOURCES_DIR/default_config.json"

# Compile Swift files (swiftc takes a single -target, so each architecture is its own slice)
echo "Compiling Swift files ($ARCHS)..."
SLICES=()
for ARCH in $ARCHS; do
    swiftc \
        -target "$ARCH-apple-macosx13.0" \
        -module-name "$APP_NAME" \
        -parse-as-library \
        -framework Cocoa \
        -framework SwiftUI \
        -framework Carbon \
        Sources/*.swift \
        -o "$MACOS_DIR/$APP_NAME.$ARCH"
    SLICES+=("$MACOS_DIR/$APP_NAME.$ARCH")
done

# Merge the slices into the final executable
if [ "${#SLICES[@]}" -gt 1 ]; then
    lipo -create "${SLICES[@]}" -output "$MACOS_DIR/$APP_NAME"
    rm -f "${SLICES[@]}"
else
    mv "${SLICES[0]}" "$MACOS_DIR/$APP_NAME"
fi

# Codesign with Apple Developer ID to persist Accessibility permissions
echo "Codesigning app with Developer ID..."
DEVELOPER_ID=$(security find-identity -p codesigning -v | grep "Apple Development" | head -n 1 | awk -F '"' '{print $2}')

if [ -n "$DEVELOPER_ID" ]; then
    echo "Found Apple Developer ID: $DEVELOPER_ID"
    codesign --force --deep --sign "$DEVELOPER_ID" "$APP_DIR"
else
    echo "No Apple Developer ID found, falling back to ad-hoc signature."
    codesign --force --deep --sign - "$APP_DIR"
fi

echo "Build successful: $APP_DIR"
