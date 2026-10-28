#!/usr/bin/env bash
set -e

# Detect Theos path if not explicitly provided
if [ -z "$THEOS" ]; then
    if [ -d "$HOME/theos" ]; then
        export THEOS="$HOME/theos"
    elif [ -d "/var/theos" ]; then
        export THEOS="/var/theos"
    elif [ -d "/opt/theos" ]; then
        export THEOS="/opt/theos"
    else
        echo "Error: THEOS environment variable is not set and Theos was not found in standard directories ($HOME/theos, /var/theos, /opt/theos)."
        echo "Please export THEOS=/path/to/theos before running this script."
        exit 1
    fi
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="/tmp/ReddsToolsBuild"

echo "=== Cleaning previous build directory ==="
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

echo "=== Staging source files to build directory ==="
cp "$SCRIPT_DIR/Makefile" "$BUILD_DIR/"
cp "$SCRIPT_DIR/control" "$BUILD_DIR/"
cp "$SCRIPT_DIR/ReddsTools.plist" "$BUILD_DIR/"
cp "$SCRIPT_DIR/Tweak.xm" "$BUILD_DIR/"
cp "$SCRIPT_DIR/FloatIconData.h" "$BUILD_DIR/"

if [ -d "$SCRIPT_DIR/layout" ]; then
    cp -r "$SCRIPT_DIR/layout" "$BUILD_DIR/"
fi

echo "=== Normalizing file and directory permissions ==="
find "$BUILD_DIR" -type d -exec chmod 755 {} +
find "$BUILD_DIR" -type f -exec chmod 644 {} +
chmod 755 "$BUILD_DIR/Makefile"

echo "=== Building rootless package with Theos ==="
cd "$BUILD_DIR"
make clean
make package FINALPACKAGE=1 THEOS_PACKAGE_SCHEME=rootless

echo "=== Copying generated package to output directory ==="
mkdir -p "$SCRIPT_DIR/packages"
cp -f "$BUILD_DIR"/packages/*.deb "$SCRIPT_DIR/packages/"

echo "=== Build finished successfully ==="
ls -lh "$SCRIPT_DIR"/packages/*.deb
