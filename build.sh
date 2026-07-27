#!/bin/zsh
# Builds Oneko.app into build/. Requires Xcode command line tools.
set -euo pipefail
cd "$(dirname "$0")"

APP=build/Oneko.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

swiftc -O Sources/*.swift \
    -o "$APP/Contents/MacOS/Oneko" \
    -framework AppKit -framework ServiceManagement

cp Info.plist "$APP/Contents/Info.plist"
cp Resources/oneko.png "$APP/Contents/Resources/oneko.png"

# Ad-hoc signature so SMAppService (launch at login) works.
codesign --force -s - "$APP"

echo "Built $APP"
