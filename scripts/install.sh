#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# MacLink macOS Installer
# Downloads, verifies, and installs MacLink.app for macOS.
set -euo pipefail

VERSION="${MACLINK_VERSION:-0.0.1}"
ARCH="$(uname -m)"
REPO="anksarvesh-lgtm/MacLink"
RELEASE_URL="https://github.com/${REPO}/releases/download/v${VERSION}"
DMG_NAME="MacLink-${VERSION}-macos-${ARCH}.dmg"
SUMS_NAME="SHA256SUMS.txt"
INSTALL_DIR="/Applications"
CLI_DIR="/usr/local/bin"

echo "=== MacLink Installer for macOS (${ARCH}) ==="

# 1. Clean up old legacy installation if present
echo "--> Checking for legacy installations..."
pkill -x "NectarLink" 2>/dev/null || true
pkill -x "nectarlink" 2>/dev/null || true
pkill -x "maclink-desktop" 2>/dev/null || true

if [[ -d "/Applications/Nectarlink.app" ]]; then
    echo "    Removing legacy /Applications/Nectarlink.app..."
    rm -rf "/Applications/Nectarlink.app"
fi
if [[ -d "/Applications/NectarLink.app" ]]; then
    echo "    Removing legacy /Applications/NectarLink.app..."
    rm -rf "/Applications/NectarLink.app"
fi
for plist in ~/Library/LaunchAgents/*nectarlink*.plist; do
    if [[ -f "$plist" ]]; then
        echo "    Unloading legacy LaunchAgent: $plist"
        launchctl unload "$plist" 2>/dev/null || true
        rm -f "$plist"
    fi
done
if [[ -L "${CLI_DIR}/nectarlink" ]]; then
    rm -f "${CLI_DIR}/nectarlink"
fi

# 2. Download and verify DMG
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

echo "--> Downloading MacLink ${VERSION}..."
DMG_PATH="${TMP_DIR}/${DMG_NAME}"
SUMS_PATH="${TMP_DIR}/${SUMS_NAME}"

# If running locally from repo root with dist/ present, use local build
REPO_ROOT="$(cd "$(dirname "$0")/.." 2>/dev/null && pwd || echo "")"
if [[ -n "$REPO_ROOT" && -f "${REPO_ROOT}/dist/${DMG_NAME}" ]]; then
    echo "    Using local build from ${REPO_ROOT}/dist/${DMG_NAME}"
    cp "${REPO_ROOT}/dist/${DMG_NAME}" "$DMG_PATH"
    if [[ -f "${REPO_ROOT}/dist/${SUMS_NAME}" ]]; then
        cp "${REPO_ROOT}/dist/${SUMS_NAME}" "$SUMS_PATH"
    fi
else
    curl -fsSL "${RELEASE_URL}/${DMG_NAME}" -o "$DMG_PATH"
    curl -fsSL "${RELEASE_URL}/${SUMS_NAME}" -o "$SUMS_PATH"
fi

if [[ -f "$SUMS_PATH" ]]; then
    echo "--> Verifying SHA-256 checksum..."
    EXPECTED_HASH="$(grep "${DMG_NAME}" "$SUMS_PATH" | awk '{print $1}')"
    if [[ -n "$EXPECTED_HASH" ]]; then
        ACTUAL_HASH="$(shasum -a 256 "$DMG_PATH" | awk '{print $1}')"
        if [[ "$EXPECTED_HASH" != "$ACTUAL_HASH" ]]; then
            echo "ERROR: Checksum verification failed!" >&2
            echo "Expected: $EXPECTED_HASH" >&2
            echo "Actual:   $ACTUAL_HASH" >&2
            exit 1
        fi
        echo "    Checksum verified: OK ($ACTUAL_HASH)"
    fi
fi

# 3. Mount DMG and install
echo "--> Installing to ${INSTALL_DIR}/MacLink.app..."
MOUNT_POINT="${TMP_DIR}/mount"
mkdir -p "$MOUNT_POINT"
hdiutil attach "$DMG_PATH" -nobrowse -quiet -mountpoint "$MOUNT_POINT"

rm -rf "${INSTALL_DIR}/MacLink.app"
cp -R "${MOUNT_POINT}/MacLink.app" "${INSTALL_DIR}/"
hdiutil detach "$MOUNT_POINT" -quiet

# Clean extended attributes so Gatekeeper allows local execution
xattr -cr "${INSTALL_DIR}/MacLink.app"

# Optional CLI symlink
if [[ -d "$CLI_DIR" && -w "$CLI_DIR" ]]; then
    ln -sf "${INSTALL_DIR}/MacLink.app/Contents/MacOS/maclink-desktop" "${CLI_DIR}/maclink"
fi

echo ""
echo "=== MacLink installed successfully! ==="
echo "You can open it from Applications or run: open /Applications/MacLink.app"
echo ""
echo "Manual installation alternative:"
echo "1. Download ${DMG_NAME} from https://github.com/${REPO}/releases"
echo "2. Double-click the DMG and drag MacLink to your Applications folder"
echo "3. Control-click (or right-click) MacLink.app in Finder and choose Open on first launch"
