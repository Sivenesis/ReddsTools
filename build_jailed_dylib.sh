#!/usr/bin/env bash
set -e

export THEOS="${THEOS:-/root/theos}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="/tmp/ReddsToolsJailedBuild"

echo "=== Cleaning previous build directory ==="
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

echo "=== Staging source files to Linux ext4 ==="
python3 -c "
with open('$SCRIPT_DIR/Tweak.xm', 'r', encoding='utf-8') as f:
    lines = f.readlines()

out = []
skip = False
for line in lines:
    if line.strip().startswith('%hook') or line.strip().startswith('%ctor'):
        skip = True
    elif line.strip().startswith('%end'):
        skip = False
        continue
    if not skip:
        out.append(line)

with open('$BUILD_DIR/ReddsTools.mm', 'w', encoding='utf-8') as f:
    f.writelines(out)
"
cp "$SCRIPT_DIR/FloatIconData.h" "$BUILD_DIR/"
cp "$SCRIPT_DIR/EmbeddedVillagersData.h" "$BUILD_DIR/"

mkdir -p "$SCRIPT_DIR/jailed"

echo "=== Building Hybrid Jailed Dylib (-DJAILED=1) ==="
cat << 'MAKE' > "$BUILD_DIR/Makefile"
TARGET := iphone:clang:16.5:15.0
ARCHS = arm64

include $(THEOS)/makefiles/common.mk

LIBRARY_NAME = ReddsTools
ReddsTools_FILES = ReddsTools.mm
ReddsTools_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -Wno-error -DJAILED=1
ReddsTools_FRAMEWORKS = UIKit QuartzCore CoreGraphics Security Foundation
ReddsTools_INSTALL_PATH = @executable_path/Frameworks

include $(THEOS_MAKE_PATH)/library.mk
MAKE

cd "$BUILD_DIR"
make clean
make FINALPACKAGE=1

if [ -f "$BUILD_DIR/.theos/obj/ReddsTools.dylib" ]; then
    cp -f "$BUILD_DIR/.theos/obj/ReddsTools.dylib" "$SCRIPT_DIR/jailed/ReddsTools.dylib"
    cp -f "$BUILD_DIR/.theos/obj/ReddsTools.dylib" "$SCRIPT_DIR/jailed/ReddsTools_hybrid_inject.dylib"
elif [ -f "$BUILD_DIR/.theos/obj/debug/ReddsTools.dylib" ]; then
    cp -f "$BUILD_DIR/.theos/obj/debug/ReddsTools.dylib" "$SCRIPT_DIR/jailed/ReddsTools.dylib"
    cp -f "$BUILD_DIR/.theos/obj/debug/ReddsTools.dylib" "$SCRIPT_DIR/jailed/ReddsTools_hybrid_inject.dylib"
fi

echo "=== Building Lite Injected Dylib (-DJAILED=1 -DLITE_MODE=1) ==="
cat << 'MAKE_LITE' > "$BUILD_DIR/Makefile"
TARGET := iphone:clang:16.5:15.0
ARCHS = arm64

include $(THEOS)/makefiles/common.mk

LIBRARY_NAME = ReddsTools
ReddsTools_FILES = ReddsTools.mm
ReddsTools_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -Wno-error -DJAILED=1 -DLITE_MODE=1
ReddsTools_FRAMEWORKS = UIKit QuartzCore CoreGraphics Security Foundation
ReddsTools_INSTALL_PATH = @executable_path/Frameworks

include $(THEOS_MAKE_PATH)/library.mk
MAKE_LITE

cd "$BUILD_DIR"
make clean
make FINALPACKAGE=1

if [ -f "$BUILD_DIR/.theos/obj/ReddsTools.dylib" ]; then
    cp -f "$BUILD_DIR/.theos/obj/ReddsTools.dylib" "$SCRIPT_DIR/jailed/ReddsTools_lite_inject.dylib"
elif [ -f "$BUILD_DIR/.theos/obj/debug/ReddsTools.dylib" ]; then
    cp -f "$BUILD_DIR/.theos/obj/debug/ReddsTools.dylib" "$SCRIPT_DIR/jailed/ReddsTools_lite_inject.dylib"
fi

echo "=== Jailed dylib builds completed successfully ==="
ls -lh "$SCRIPT_DIR/jailed/"*.dylib
