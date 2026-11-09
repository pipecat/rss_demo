#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift build --disable-sandbox --cache-path .build/cache --scratch-path .build -c debug
BIN_DIR="$(swift build --disable-sandbox --cache-path .build/cache --scratch-path .build -c debug --show-bin-path)"
APP="dist/Topic Reader.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/Licenses"
chmod -R u+w "$APP"
cp "$BIN_DIR/TopicReader" "$APP/Contents/MacOS/TopicReader"
cp -R "$BIN_DIR/TopicReader_ReaderAdapters.bundle" "$APP/Contents/Resources/"
cp "$BIN_DIR/TopicReader_ReaderAdapters.bundle/Resources/Readability.js" "$APP/Contents/Resources/Licenses/"
cp "$BIN_DIR/TopicReader_ReaderAdapters.bundle/Resources/JSDOMParser.js" "$APP/Contents/Resources/Licenses/"
cp Packages/ReaderAdapters/Resources/LICENSE-Readability.txt "$APP/Contents/Resources/Licenses/"
cp Packages/ReaderAdapters/Resources/LICENSE-JSDOMParser.txt "$APP/Contents/Resources/Licenses/"
cp .build/checkouts/FeedKit/LICENSE "$APP/Contents/Resources/Licenses/FeedKit-MIT.txt"
cp .build/checkouts/SwiftSoup/LICENSE "$APP/Contents/Resources/Licenses/SwiftSoup-MIT.txt"
cp THIRD_PARTY_NOTICES.md "$APP/Contents/Resources/Licenses/"
cp Apps/Info.plist "$APP/Contents/Info.plist"
if [ ! -f dist/TopicReader.icns ]; then
    swift scripts/make-icon.swift dist/TopicReader.iconset
    iconutil -c icns dist/TopicReader.iconset -o dist/TopicReader.icns
fi
cp dist/TopicReader.icns "$APP/Contents/Resources/TopicReader.icns"
codesign --force --deep --sign - "$APP"
codesign --verify --deep --strict "$APP"
printf 'Built: %s/%s\n' "$PWD" "$APP"
