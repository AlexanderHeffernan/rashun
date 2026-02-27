#!/bin/bash
swift build -c release
rm -rf Rashun.app
mkdir -p Rashun.app/Contents/{MacOS,Resources}
cp .build/release/Rashun Rashun.app/Contents/MacOS/Rashun
cp Info.plist Rashun.app/Contents/ # (assuming you saved Info.plist in root)
# If you have an icon: cp AppIcon.icns Rashun.app/Contents/Resources/
codesign --force --deep --sign - Rashun.app
open Rashun.app