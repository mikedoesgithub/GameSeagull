#!/usr/bin/env bash
# ==============================================================================
# GameSeagull TrollStore / Sideloading IPA Packager
# Builds a standalone .ipa / .tipa for TrollStore and Sideloading
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="$(mktemp -d /tmp/trollstore_build.XXXXXX)"
OUTPUT_DIR="$SCRIPT_DIR/build"
OUTPUT_IPA="$OUTPUT_DIR/GameSeagull-v3.0-TrollStore.ipa"
BASE_IPA_URL="https://github.com/donato-fiore/TrollStoreGameSeagull/releases/download/v2.1/GameSeagull.ipa"

mkdir -p "$OUTPUT_DIR"

echo "=========================================="
echo "  GameSeagull TrollStore Packager"
echo "=========================================="

# 1. Locate or extract gameseagull.dylib
DYLIB_PATH=""
if [ -f "$SCRIPT_DIR/build/gameseagull.dylib" ]; then
    DYLIB_PATH="$SCRIPT_DIR/build/gameseagull.dylib"
elif [ -d "$SCRIPT_DIR/packages" ] && [ "$(ls -A "$SCRIPT_DIR/packages" 2>/dev/null)" ]; then
    LATEST_DEB="$(ls -dtr1 "$SCRIPT_DIR/packages/"*.deb | tail -1)"
    echo "[+] Extracting dylib from latest .deb: $LATEST_DEB"
    dpkg-deb -x "$LATEST_DEB" "$WORK_DIR/deb_extract" 2>/dev/null || ar -x "$LATEST_DEB" --output "$WORK_DIR/deb_extract"
    DYLIB_PATH="$(find "$WORK_DIR/deb_extract" -name "gameseagull.dylib" -o -name "GameSeagull.dylib" | head -1)"
fi

# 2. Download template IPA if needed
TEMPLATE_IPA="$WORK_DIR/template.ipa"
echo "[+] Fetching base GamePigeon / GameSeagull TrollStore container..."
if [ -f "/tmp/inspect_ipa/GameSeagull.ipa" ]; then
    cp "/tmp/inspect_ipa/GameSeagull.ipa" "$TEMPLATE_IPA"
else
    curl -sSL -L -o "$TEMPLATE_IPA" "$BASE_IPA_URL"
fi

# 3. Unpack template IPA
echo "[+] Unpacking IPA payload..."
mkdir -p "$WORK_DIR/unpacked"
unzip -q "$TEMPLATE_IPA" -d "$WORK_DIR/unpacked"

APP_PATH="$(find "$WORK_DIR/unpacked/Payload" -maxdepth 1 -name "*.app" | head -1)"
if [ ! -d "$APP_PATH" ]; then
    echo "[-] Error: No .app bundle found in IPA payload!"
    exit 1
fi

FRAMEWORKS_DIR="$APP_PATH/Frameworks"
mkdir -p "$FRAMEWORKS_DIR"

# 4. Inject / Replace gameseagull.dylib
if [ -n "$DYLIB_PATH" ] && [ -f "$DYLIB_PATH" ]; then
    echo "[+] Replacing gameseagull.dylib with updated build ($DYLIB_PATH)..."
    cp -f "$DYLIB_PATH" "$FRAMEWORKS_DIR/gameseagull.dylib"
else
    echo "[!] Notice: No newly compiled gameseagull.dylib found in ./build or ./packages."
    echo "[!] Using current Frameworks/gameseagull.dylib in template bundle."
fi

# 5. Pack final IPA
echo "[+] Repacking into TrollStore IPA: $OUTPUT_IPA..."
rm -f "$OUTPUT_IPA"
(cd "$WORK_DIR/unpacked" && zip -q -r "$OUTPUT_IPA" Payload)

# Cleanup
rm -rf "$WORK_DIR"

echo "=========================================="
echo "  SUCCESS! TrollStore IPA Created:"
echo "  $OUTPUT_IPA"
echo "=========================================="
ls -lh "$OUTPUT_IPA"
