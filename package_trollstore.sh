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
CUSTOM_IPA="${1:-}"
TEMPLATE_IPA="$WORK_DIR/template.ipa"
if [ -n "$CUSTOM_IPA" ] && [ -f "$CUSTOM_IPA" ]; then
    echo "[+] Using user-provided GamePigeon IPA: $CUSTOM_IPA"
    cp "$CUSTOM_IPA" "$TEMPLATE_IPA"
elif [ -f "/tmp/inspect_ipa/GameSeagull.ipa" ]; then
    echo "[+] Using cached base GameSeagull container..."
    cp "/tmp/inspect_ipa/GameSeagull.ipa" "$TEMPLATE_IPA"
else
    echo "[+] Fetching base GamePigeon / GameSeagull TrollStore container..."
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

# 4b. Ensure CydiaSubstrate.framework (fresh dylib needs it via @rpath)
if [ ! -d "$FRAMEWORKS_DIR/CydiaSubstrate.framework" ]; then
    echo "[+] CydiaSubstrate.framework missing - fetching from v2.1 release..."
    mkdir -p "$WORK_DIR/substrate_src"
    curl -sSL -L -o "$WORK_DIR/old_gs.ipa" "$BASE_IPA_URL"
    unzip -q "$WORK_DIR/old_gs.ipa" -d "$WORK_DIR/substrate_src"
    SUBSTRATE_DIR="$(find "$WORK_DIR/substrate_src" -name "CydiaSubstrate.framework" -type d | head -1)"
    if [ -z "$SUBSTRATE_DIR" ]; then echo "[-] CydiaSubstrate.framework not found!"; exit 1; fi
    cp -R "$SUBSTRATE_DIR" "$FRAMEWORKS_DIR/CydiaSubstrate.framework"
    echo "[+] CydiaSubstrate.framework injected"
fi

# 4c+4d. Patch dylib substrate ref to @rpath + ensure LC_LOAD_DYLIB in appex binary
echo "[+] Patching Mach-O load commands..."
python3 - "$FRAMEWORKS_DIR/gameseagull.dylib" "$APP_PATH" <<'PYEOF'
import struct, sys, os, glob

dylib_path, app_path = sys.argv[1], sys.argv[2]
OLD = b'/Library/Frameworks/CydiaSubstrate.framework/CydiaSubstrate\x00'
NEW = b'@rpath/CydiaSubstrate.framework/CydiaSubstrate\x00'

data = bytearray(open(dylib_path, 'rb').read())
if data.find(NEW) != -1:
    print('dylib substrate ref already @rpath, skipping')
elif data.count(OLD) == 1:
    idx = data.find(OLD)
    data[idx:idx+len(NEW)] = NEW
    for i in range(idx+len(NEW), idx+len(OLD)):
        data[i] = 0
    open(dylib_path, 'wb').write(data)
    print('patched dylib substrate ref to @rpath')
else:
    raise SystemExit('unexpected substrate refs in dylib: old=%d new=%d' % (data.count(OLD), data.count(NEW)))

def find_appex_binary(app):
    for ap in glob.glob(os.path.join(app, 'PlugIns', '*.appex')):
        cand = os.path.join(ap, os.path.basename(ap).replace('.appex', ''))
        if os.path.isfile(cand):
            return cand
    best, bestsz = None, 0
    for ap in glob.glob(os.path.join(app, 'PlugIns', '*.appex')):
        for root, _, files in os.walk(ap):
            for f in files:
                p = os.path.join(root, f)
                if '.' not in os.path.basename(f) and os.path.isfile(p):
                    sz = os.path.getsize(p)
                    if sz > bestsz:
                        best, bestsz = p, sz
    return best

binary = find_appex_binary(app_path)
print('appex binary:', binary)
if not binary:
    raise SystemExit('no appex binary found')
data = bytearray(open(binary, 'rb').read())
magic, _, _, _, ncmds, sizeofcmds, _, _ = struct.unpack('<IIIIIIII', data[:32])
assert magic == 0xFEEDFACF, 'not a 64-bit Mach-O'
if b'gameseagull.dylib' in data[32:32+sizeofcmds]:
    print('LC_LOAD_DYLIB already present, skipping')
else:
    name = b'@rpath/gameseagull.dylib\x00'
    name += b'\x00' * ((8 - (len(name) % 8)) % 8)
    cmdsize = 24 + len(name)
    cmd = struct.pack('<IIIIII', 0x0C, cmdsize, 24, 2, 0x10000, 0x10000) + name
    off = 32 + sizeofcmds
    assert data[off:off+cmdsize] == b'\x00' * cmdsize, 'no zero padding for new load command'
    data[off:off+cmdsize] = cmd
    struct.pack_into('<II', data, 16, ncmds + 1, sizeofcmds + cmdsize)
    open(binary, 'wb').write(data)
    print('injected LC_LOAD_DYLIB @rpath/gameseagull.dylib')
PYEOF

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
