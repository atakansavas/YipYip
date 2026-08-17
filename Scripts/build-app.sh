#!/usr/bin/env bash
set -euo pipefail

# Build YipYip, assemble a .app bundle, and install to /Applications.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="${PROJECT_DIR}/.build"
APP_NAME="YipYip"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"
CONTENTS="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS}/MacOS"
INSTALL_DIR="/Applications"
INSTALLED_APP="${INSTALL_DIR}/${APP_NAME}.app"

# Single source of truth for the version: Sources/YipYipCore/AppInfo.swift.
VERSION="$(sed -n 's/.*fallbackVersion = "\([^"]*\)".*/\1/p' \
    "${PROJECT_DIR}/Sources/YipYipCore/AppInfo.swift" | head -1)"
if [[ -z "$VERSION" ]]; then
    echo "Could not read the version from AppInfo.swift" >&2
    exit 1
fi

echo "==> Building ${APP_NAME} ${VERSION} (release)..."
cd "$PROJECT_DIR"
swift build -c release 2>&1

echo "==> Assembling app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR" "${CONTENTS}/Resources"

cp "${BUILD_DIR}/release/${APP_NAME}" "${MACOS_DIR}/${APP_NAME}"

if [[ -f "${PROJECT_DIR}/Resources/AppIcon.icns" ]]; then
    cp "${PROJECT_DIR}/Resources/AppIcon.icns" "${CONTENTS}/Resources/AppIcon.icns"
else
    echo "    No Resources/AppIcon.icns — run: swift Scripts/generate-icon.swift Resources"
fi

cat > "${CONTENTS}/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>com.benatakan.yipyip</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright 2026 Atakan Savaş. MIT licensed.</string>
</dict>
</plist>
PLIST

# Sign the assembled bundle. A real identity is worth finding: unlike an ad-hoc
# signature it stays identical across builds, so the Keychain ACL for the
# encryption key and the Accessibility grant both survive a reinstall.
IDENTITY="${YIPYIP_SIGN_IDENTITY:-}"
if [[ -z "$IDENTITY" ]]; then
    IDENTITY="$(security find-identity -v -p codesigning \
        | awk -F'"' '/Developer ID Application|Apple Development/ { print $2; exit }')"
fi

if [[ -n "$IDENTITY" ]]; then
    echo "==> Signing as: ${IDENTITY}"
    codesign --force --sign "$IDENTITY" --identifier "com.benatakan.yipyip" "$APP_BUNDLE"
else
    echo "==> Signing (ad-hoc — no signing identity found)"
    echo "    Permissions will reset on every rebuild."
    codesign --force --sign - --identifier "com.benatakan.yipyip" "$APP_BUNDLE"
fi

# Install to /Applications — quit running instance first if present.
echo "==> Installing to ${INSTALL_DIR}..."
if pgrep -x "$APP_NAME" > /dev/null 2>&1; then
    echo "    Stopping running ${APP_NAME}..."
    killall "$APP_NAME" 2>/dev/null || true
    sleep 1
fi

rm -rf "$INSTALLED_APP"
cp -R "$APP_BUNDLE" "$INSTALLED_APP"

echo "==> Installed: ${INSTALLED_APP}"
echo ""
echo "Launch with:  open ${INSTALLED_APP}"
echo ""
echo "Hotkey:       Command+Option+V"
echo "Auto-paste needs Accessibility (System Settings > Privacy & Security)."
echo "Switching signing identity invalidates the stored Keychain ACL once —"
echo "choose 'Always Allow' on that prompt; until you do, the app blocks on it."
echo "If auto-paste stops working after a signing change, clear the stale grant:"
echo "  tccutil reset Accessibility com.benatakan.yipyip"
