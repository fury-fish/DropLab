#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

export CLANG_MODULE_CACHE_PATH="/tmp/clang-module-cache"
swift build -c release --disable-sandbox --cache-path /tmp/swiftpm-cache -Xswiftc -module-cache-path -Xswiftc /tmp/clang-module-cache

BIN_DIR="$(swift build -c release --show-bin-path --disable-sandbox --cache-path /tmp/swiftpm-cache)"
BIN_PATH="$BIN_DIR/DropLabApp"
CLI_PATH="$BIN_DIR/droplab"

APP_DIR="$ROOT_DIR/build/DropLab.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$BIN_PATH" "$MACOS_DIR/DropLab"
cp "$CLI_PATH" "$MACOS_DIR/droplab-cli"
cp "$CLI_PATH" "$ROOT_DIR/build/droplab"

"$MACOS_DIR/DropLab" --generate-app-icon "$RESOURCES_DIR/AppIcon.icns"

cat > "$CONTENTS_DIR/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>vi</string>
    <key>CFBundleExecutable</key>
    <string>DropLab</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.furyfish.droplab</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>DropLab</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>100</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSAppleEventsUsageDescription</key>
    <string>DropLab cần quyền đọc file đang chọn trong Finder để mở nhanh Vòng Xoay Trọng Lực.</string>
    <key>NSDownloadsFolderUsageDescription</key>
    <string>DropLab cần quyền đọc và xuất file chuyển đổi trong thư mục Downloads của bạn.</string>
    <key>NSDesktopFolderUsageDescription</key>
    <string>DropLab cần quyền đọc và xuất file chuyển đổi trên Desktop của bạn.</string>
    <key>NSDocumentsFolderUsageDescription</key>
    <string>DropLab cần quyền đọc và xuất file chuyển đổi trong thư mục Documents của bạn.</string>
</dict>
</plist>
EOF

codesign --force --deep --sign - "$APP_DIR" 2>/dev/null || true

cd "$ROOT_DIR/build"
rm -f DropLab-1.0.0-macOS.zip
ditto -c -k --sequesterRsrc --keepParent DropLab.app DropLab-1.0.0-macOS.zip

echo "✓ Built $APP_DIR (v1.0.0) and $ROOT_DIR/build/DropLab-1.0.0-macOS.zip"
