#!/bin/bash
swift build -c release
rm -rf Rashun.app
mkdir -p Rashun.app/Contents/{MacOS,Resources}
cp .build/release/Rashun Rashun.app/Contents/MacOS/Rashun
cp Info.plist Rashun.app/Contents/ # (assuming you saved Info.plist in root)
# If you have an icon: cp AppIcon.icns Rashun.app/Contents/Resources/
# Re-sign the amp binary to avoid network volume alert when spawning it
codesign --force --sign - "$HOME/.amp/bin/amp" 2>/dev/null || true
codesign --force --deep --sign - --entitlements Rashun.entitlements Rashun.app
open Rashun.app