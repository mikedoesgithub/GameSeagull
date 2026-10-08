#!/usr/bin/env bash
# ==============================================================================
# GameSeagull Local Linux Theos Build Script
# Supports Arch Linux (Omarchy), Ubuntu, Debian, and Fedora
# ==============================================================================

set -e

THEOS_DIR="${THEOS:-$HOME/theos}"
SDK_VERSION="16.5"
SDK_URL="https://github.com/theos/sdks/releases/download/latest/iPhoneOS${SDK_VERSION}.sdk.tar.xz"

echo "=========================================="
echo "  GameSeagull Linux Build Setup"
echo "=========================================="

# 1. Check core dependencies
echo "[1/5] Verifying system dependencies..."
MISSING_PKGS=()
for cmd in git curl tar xz clang perl; do
    if ! command -v "$cmd" &> /dev/null; then
        MISSING_PKGS+=("$cmd")
    fi
done

if [ ${#MISSING_PKGS[@]} -gt 0 ]; then
    echo "[-] Missing required tools: ${MISSING_PKGS[*]}"
    if command -v pacman &> /dev/null; then
        echo "[+] On Arch / Omarchy, install with: sudo pacman -S --needed git curl tar xz clang perl"
    elif command -v apt-get &> /dev/null; then
        echo "[+] On Debian/Ubuntu, install with: sudo apt-get install -y git curl tar xz-utils clang perl"
    fi
    exit 1
fi

# 2. Setup Theos
if [ ! -d "$THEOS_DIR" ]; then
    echo "[2/5] Cloning Theos into $THEOS_DIR..."
    git clone --recursive https://github.com/theos/theos.git "$THEOS_DIR"
else
    echo "[2/5] Theos already present at $THEOS_DIR."
fi

export THEOS="$THEOS_DIR"

# 3. Setup iOS SDK
mkdir -p "$THEOS/sdks"
if [ ! -d "$THEOS/sdks/iPhoneOS${SDK_VERSION}.sdk" ]; then
    echo "[3/5] Downloading iOS ${SDK_VERSION} SDK..."
    curl -sSL "$SDK_URL" | tar -xJ -C "$THEOS/sdks/"
else
    echo "[3/5] iOS ${SDK_VERSION} SDK is already installed."
fi

# 4. Setup Cephei headers
echo "[4/5] Setting up Cephei headers..."
mkdir -p "$THEOS/include"
if [ ! -d "/tmp/cephei" ]; then
    git clone --depth=1 https://github.com/hbang/libcephei.git /tmp/cephei 2>/dev/null || true
fi
if [ -d "/tmp/cephei/headers" ]; then
    cp -r /tmp/cephei/headers/* "$THEOS/include/" 2>/dev/null || true
fi

# 5. Build packages
echo "[5/5] Building GameSeagull packages..."
chmod +x ./build_release.sh
./build_release.sh

echo ""
echo "=========================================="
echo "  Build Complete! Check ./build/ for .deb"
echo "=========================================="
ls -lh ./build/*.deb 2>/dev/null || true
