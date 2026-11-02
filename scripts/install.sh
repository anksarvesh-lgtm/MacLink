#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# MacLink One-Line Terminal Installer & Launcher
# Usage: curl -fsSL https://raw.githubusercontent.com/anksarvesh-lgtm/MacLink/main/install.sh | bash

set -euo pipefail

# ANSI color codes
BOLD='\033[1m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
RESET='\033[0m'

echo -e "${BOLD}${CYAN}==> MacLink macOS Installer & Terminal Launcher${RESET}"

# 1. Platform verification
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo -e "${RED}Error: MacLink is designed for macOS.${RESET}" >&2
    exit 1
fi

ARCH="$(uname -m)"
if [[ "$ARCH" != "arm64" && "$ARCH" != "x86_64" ]]; then
    echo -e "${RED}Error: Unsupported architecture: ${ARCH}${RESET}" >&2
    exit 1
fi

# 2. Determine latest version from GitHub API (fallback to v0.0.6)
REPO="anksarvesh-lgtm/MacLink"
echo -e "${CYAN}--> Checking latest release...${RESET}"
LATEST_TAG=""
if command -v curl >/dev/null 2>&1; then
    LATEST_TAG="$(curl -sL --max-time 10 "https://api.github.com/repos/${REPO}/releases/latest" 2>/dev/null | grep '"tag_name":' | head -n 1 | cut -d '"' -f 4 || true)"
fi

if [[ -z "$LATEST_TAG" ]]; then
    LATEST_TAG="${MACLINK_VERSION:-v0.0.6}"
fi
if [[ "$LATEST_TAG" != v* ]]; then
    LATEST_TAG="v${LATEST_TAG}"
fi
VERSION="${LATEST_TAG#v}"
echo -e "    Target version: ${GREEN}${LATEST_TAG}${RESET} (${ARCH})"

# 3. Clean up running instances and legacy artifacts
echo -e "${CYAN}--> Preparing installation environment...${RESET}"
pkill -x "maclink-desktop" 2>/dev/null || true
pkill -x "NectarLink" 2>/dev/null || true
pkill -x "nectarlink" 2>/dev/null || true

LEGACY_APP="/Applications/NectarLink.app"
if [[ -d "$LEGACY_APP" ]]; then
    rm -rf "$LEGACY_APP"
fi

# 4. Check for local build first (if running from repo directory)
TMP_DIR="$(mktemp -d /tmp/maclink-install.XXXXXX)"
trap 'rm -rf "$TMP_DIR"' EXIT

SOURCE_APP=""
SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd || echo "")"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." 2>/dev/null && pwd || echo "")"

if [[ -n "$SCRIPT_DIR" && -d "${SCRIPT_DIR}/dist/MacLink.app" ]]; then
    echo -e "    Found local build at ${SCRIPT_DIR}/dist/MacLink.app"
    SOURCE_APP="${SCRIPT_DIR}/dist/MacLink.app"
elif [[ -n "$REPO_ROOT" && -d "${REPO_ROOT}/dist/MacLink.app" ]]; then
    echo -e "    Found local build at ${REPO_ROOT}/dist/MacLink.app"
    SOURCE_APP="${REPO_ROOT}/dist/MacLink.app"
elif [[ -d "./dist/MacLink.app" ]]; then
    echo -e "    Found local build at ./dist/MacLink.app"
    SOURCE_APP="./dist/MacLink.app"
fi

# 5. Download release if no local build found
if [[ -z "$SOURCE_APP" ]]; then
    ZIP_NAME="MacLink-${VERSION}-macos-${ARCH}.zip"
    DMG_NAME="MacLink-${VERSION}-macos-${ARCH}.dmg"
    RELEASE_BASE="https://github.com/${REPO}/releases/download/${LATEST_TAG}"

    DOWNLOAD_SUCCESS=false

    # Try ZIP first (faster download & instant unzipping)
    echo -e "${CYAN}--> Downloading MacLink ${LATEST_TAG}...${RESET}"
    if curl -# -fSL "${RELEASE_BASE}/${ZIP_NAME}" -o "${TMP_DIR}/${ZIP_NAME}" 2>/dev/null; then
        echo -e "    Extracting ${ZIP_NAME}..."
        unzip -q -o "${TMP_DIR}/${ZIP_NAME}" -d "${TMP_DIR}/extracted"
        if [[ -d "${TMP_DIR}/extracted/MacLink.app" ]]; then
            SOURCE_APP="${TMP_DIR}/extracted/MacLink.app"
            DOWNLOAD_SUCCESS=true
        fi
    fi

    # Fallback to DMG if ZIP was not available
    if [[ "$DOWNLOAD_SUCCESS" = false ]]; then
        echo -e "    Trying DMG package (${DMG_NAME})..."
        if curl -# -fSL "${RELEASE_BASE}/${DMG_NAME}" -o "${TMP_DIR}/${DMG_NAME}" 2>/dev/null; then
            MOUNT_POINT="${TMP_DIR}/mnt"
            mkdir -p "$MOUNT_POINT"
            hdiutil attach "${TMP_DIR}/${DMG_NAME}" -nobrowse -quiet -mountpoint "$MOUNT_POINT"
            if [[ -d "${MOUNT_POINT}/MacLink.app" ]]; then
                cp -R "${MOUNT_POINT}/MacLink.app" "${TMP_DIR}/"
                SOURCE_APP="${TMP_DIR}/MacLink.app"
                DOWNLOAD_SUCCESS=true
            fi
            hdiutil detach "$MOUNT_POINT" -quiet 2>/dev/null || true
        fi
    fi

    if [[ "$DOWNLOAD_SUCCESS" = false || -z "$SOURCE_APP" ]]; then
        echo -e "${RED}Error: Failed to download MacLink ${LATEST_TAG}. Please check your internet connection.${RESET}" >&2
        exit 1
    fi
fi

# 6. Install to /Applications
INSTALL_DIR="/Applications"
TARGET_APP="${INSTALL_DIR}/MacLink.app"
echo -e "${CYAN}--> Installing to ${TARGET_APP}...${RESET}"
rm -rf "$TARGET_APP"
cp -R "$SOURCE_APP" "$TARGET_APP"

# Clear macOS Gatekeeper quarantine attribute
xattr -dr com.apple.quarantine "$TARGET_APP" 2>/dev/null || true
xattr -cr "$TARGET_APP" 2>/dev/null || true

# 7. Install 'maclink' CLI Launcher
echo -e "${CYAN}--> Setting up terminal command 'maclink'...${RESET}"

LAUNCHER_SCRIPT='#!/usr/bin/env bash
# MacLink CLI Launcher
APP_PATH="/Applications/MacLink.app"
BIN_PATH="${APP_PATH}/Contents/MacOS/maclink-desktop"

if [ ! -d "$APP_PATH" ]; then
    echo "Error: MacLink is not installed in /Applications/MacLink.app" >&2
    echo "Install it with: curl -fsSL https://raw.githubusercontent.com/anksarvesh-lgtm/MacLink/main/install.sh | bash" >&2
    exit 1
fi

case "${1:-}" in
    -h|--help)
        echo "MacLink CLI Launcher"
        echo ""
        echo "Usage: maclink [options]"
        echo ""
        echo "Options:"
        echo "  (no args)           Launch / focus MacLink application"
        echo "  --fg, --foreground  Run MacLink in terminal foreground (stream logs)"
        echo "  --ui-check          Run headless UI validation test"
        echo "  --version, -v       Show MacLink version"
        echo "  --help, -h          Show this help message"
        exit 0
        ;;
    -v|--version)
        if [ -x "$BIN_PATH" ]; then
            "$BIN_PATH" --version 2>/dev/null || defaults read "${APP_PATH}/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "MacLink"
        else
            defaults read "${APP_PATH}/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "MacLink"
        fi
        exit 0
        ;;
    --fg|--foreground)
        shift
        exec "$BIN_PATH" "$@"
        ;;
    --ui-check)
        exec "$BIN_PATH" --ui-check
        ;;
    *)
        open -a MacLink "$@"
        ;;
esac
'

# Candidate bin directories in priority order
USER_BIN="$HOME/.local/bin"
mkdir -p "$USER_BIN"
echo "$LAUNCHER_SCRIPT" > "${USER_BIN}/maclink"
chmod +x "${USER_BIN}/maclink"

# Try /usr/local/bin if writable
if [[ -w "/usr/local/bin" ]]; then
    echo "$LAUNCHER_SCRIPT" > "/usr/local/bin/maclink"
    chmod +x "/usr/local/bin/maclink"
fi

# Ensure ~/.local/bin is in PATH for future shells if not already present
SHELL_CONFIG=""
if [[ -f "$HOME/.zshrc" ]]; then
    SHELL_CONFIG="$HOME/.zshrc"
elif [[ -f "$HOME/.bash_profile" ]]; then
    SHELL_CONFIG="$HOME/.bash_profile"
elif [[ -f "$HOME/.profile" ]]; then
    SHELL_CONFIG="$HOME/.profile"
fi

if [[ -n "$SHELL_CONFIG" ]]; then
    if ! grep -q '\.local/bin' "$SHELL_CONFIG" 2>/dev/null; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$SHELL_CONFIG"
    fi
fi

# 8. Open MacLink application immediately
echo -e "${CYAN}--> Opening MacLink...${RESET}"
open -a MacLink

echo ""
echo -e "${BOLD}${GREEN}============================================================${RESET}"
echo -e "${BOLD}${GREEN}        MacLink successfully installed and opened!          ${RESET}"
echo -e "${BOLD}${GREEN}============================================================${RESET}"
echo -e "  App Location:    ${BOLD}/Applications/MacLink.app${RESET}"
echo -e "  Terminal Command:${BOLD} maclink${RESET}"
echo ""
echo -e "  You can open MacLink anytime from your terminal by typing:"
echo -e "      ${BOLD}${CYAN}maclink${RESET}"
echo ""
echo -e "${BOLD}${GREEN}============================================================${RESET}"
