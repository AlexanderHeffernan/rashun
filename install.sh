#!/bin/bash
set -euo pipefail

REPO="alexanderheffernan/rashun"
APP_NAME="Rashun.app"
INSTALL_DIR="/Applications"
DOWNLOAD_URL="https://github.com/$REPO/releases/download/latest/Rashun.zip"

echo "Installing Rashun..."
echo ""

# Create temp directory and clean up on exit
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

echo "Downloading latest build..."
if ! curl -fsSL -o "$TMPDIR/Rashun.zip" "$DOWNLOAD_URL"; then
    echo "Error: Failed to download. Please check https://github.com/$REPO/releases"
    exit 1
fi

echo "Extracting..."
unzip -q "$TMPDIR/Rashun.zip" -d "$TMPDIR"

# Remove existing install if present
if [ -d "$INSTALL_DIR/$APP_NAME" ]; then
    echo "Removing existing installation..."
    rm -rf "$INSTALL_DIR/$APP_NAME"
fi

echo "Installing to $INSTALL_DIR..."
mv "$TMPDIR/$APP_NAME" "$INSTALL_DIR/"

# Clear macOS quarantine flag so Gatekeeper doesn't block it
xattr -cr "$INSTALL_DIR/$APP_NAME"

echo ""
echo "✅ Rashun installed successfully!"
echo "   Run it with: open /Applications/Rashun.app"
echo "   To update later, just run this command again."
echo "   Better update support coming soon!"
