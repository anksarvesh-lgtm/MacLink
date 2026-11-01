#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Builds MacLink.app for macOS from a release build of maclink-desktop:
# the bundle layout and Info.plist, the app icon, the Qt frameworks and QML
# modules (macdeployqt), an ad-hoc signature (Apple Silicon runs only signed
# code), and a zip of it in dist/.
#
#   cargo build --release --bin maclink-desktop
#   QT_ROOT_DIR=~/Qt/6.12.0/macos ./desktop/packaging/macos/build-app.sh
#
# The app isn't signed with a Developer ID or notarized, so the first time it
# opens macOS asks: Control-click it in Finder and choose Open.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$REPO_ROOT"

VERSION="$(awk -F'"' '/^\[workspace.package\]/{f=1} f && /^version = /{print $2; exit}' Cargo.toml)"
ARCH="$(uname -m)"
BIN="${BIN:-target/release/maclink-desktop}"
OUT_DIR="${OUT_DIR:-dist}"
APP="${OUT_DIR}/MacLink.app"

[[ -x "$BIN" ]] || { echo "build it first: cargo build --release --bin maclink-desktop" >&2; exit 1; }
MACDEPLOYQT="${QT_ROOT_DIR:+${QT_ROOT_DIR}/bin/}macdeployqt"
command -v "$MACDEPLOYQT" >/dev/null || { echo "macdeployqt not found; set QT_ROOT_DIR" >&2; exit 1; }

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/maclink-desktop"
# Translations, next to the executable where the app looks for them.
LRELEASE="${QT_ROOT_DIR:+${QT_ROOT_DIR}/bin/}lrelease"
command -v "$LRELEASE" >/dev/null || { echo "lrelease not found; set QT_ROOT_DIR" >&2; exit 1; }
for ts in desktop/app/i18n/nectarlink_*.ts; do
    name="$(basename "$ts" .ts)"
    "$LRELEASE" -silent "$ts" -qm "$APP/Contents/MacOS/${name}.qm"
done

# The icon: every size macOS asks for, from the 1024 px brand icon.
ICONSET="$(mktemp -d)/MacLink.iconset"
mkdir -p "$ICONSET"
SOURCE_ICON="assets/brand/icon-1024.png"
[[ -f "$SOURCE_ICON" ]] || SOURCE_ICON="assets/brand/icon-512.png"
for size in 16 32 128 256 512; do
    sips -z "$size" "$size" "$SOURCE_ICON" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
    double=$((size * 2))
    sips -z "$double" "$double" "$SOURCE_ICON" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/MacLink.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>MacLink</string>
    <key>CFBundleDisplayName</key><string>MacLink</string>
    <key>CFBundleIdentifier</key><string>in.maclink.srv</string>
    <key>CFBundleExecutable</key><string>maclink-desktop</string>
    <key>CFBundleIconFile</key><string>MacLink</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>${VERSION}</string>
    <key>CFBundleVersion</key><string>${VERSION}</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key><true/>
    <key>NSLocalNetworkUsageDescription</key>
    <string>MacLink finds your phone and connects to it on this network.</string>
    <key>NSBonjourServices</key>
    <array>
        <string>_maclink._udp</string>
        <string>_nectarlink._udp</string>
    </array>
    <key>NSMicrophoneUsageDescription</key>
    <string>MacLink uses the microphone for calls you take on this Mac.</string>
    <key>NSCameraUsageDescription</key>
    <string>MacLink uses the camera only when you start a feature that needs it.</string>
    <key>NSAppleEventsUsageDescription</key>
    <string>MacLink controls media players on this Mac when you ask it to from your phone.</string>
    <key>CFBundleURLTypes</key>
    <array>
        <dict>
            <key>CFBundleURLName</key><string>MacLink</string>
            <key>CFBundleURLSchemes</key>
            <array>
                <string>maclink</string>
                <string>nectarlink</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
PLIST

# Qt frameworks, plugins and the QML modules the app imports.
"$MACDEPLOYQT" "$APP" -qmldir=desktop/app/qml -always-overwrite

# Ad-hoc signature: no identity, but Apple Silicon won't run unsigned code.
codesign --force --deep --sign - "$APP"
codesign --verify --deep --strict "$APP"

# Apply Finder bundle icon via AppKit so macOS Finder displays it immediately
swift -e "
import AppKit
let ws = NSWorkspace.shared
if let img = NSImage(contentsOfFile: \"assets/brand/icon-512.png\") {
    _ = ws.setIcon(img, forFile: \"$APP\", options: [])
}
" || true

# Verify Apple Silicon Mach-O slice and signature with REA if available
if command -v rea >/dev/null 2>&1; then
    echo "Inspecting bundle binary with REA..."
    rea list-architectures "$APP/Contents/MacOS/maclink-desktop" || true
    rea inspect-signature "$APP/Contents/MacOS/maclink-desktop" || true
fi

ZIP="${OUT_DIR}/MacLink-${VERSION}-macos-${ARCH}.zip"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"
echo "Built $ZIP"
