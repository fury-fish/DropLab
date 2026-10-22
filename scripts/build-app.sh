#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

export CLANG_MODULE_CACHE_PATH="/tmp/clang-module-cache"
swift build -c release --disable-sandbox --cache-path /tmp/swiftpm-cache -Xswiftc -module-cache-path -Xswiftc /tmp/clang-module-cache

BIN_PATH="$(swift build -c release --show-bin-path --disable-sandbox --cache-path /tmp/swiftpm-cache)/DropLabApp"
CLI_PATH="$(swift build -c release --show-bin-path --disable-sandbox --cache-path /tmp/swiftpm-cache)/droplab"

APP_DIR="$ROOT_DIR/build/DropLab.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$BIN_PATH" "$MACOS_DIR/DropLab"
cp "$CLI_PATH" "$MACOS_DIR/droplab-cli"
cp "$CLI_PATH" "$ROOT_DIR/build/droplab"

cat > "$CONTENTS_DIR/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>vi</string>
    <key>CFBundleExecutable</key>
    <string>DropLab</string>
    <key>CFBundleIdentifier</key>
    <string>com.furyfish.droplab</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>DropLab</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.2.0</string>
    <key>CFBundleVersion</key>
    <string>2</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

echo "✓ Built $APP_DIR"
