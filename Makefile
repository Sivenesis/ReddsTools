export THEOS_PACKAGE_SCHEME = rootless
TARGET := iphone:clang:16.5:15.0
ARCHS = arm64

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = ReddsTools

ReddsTools_FILES = Tweak.xm
ReddsTools_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -Wno-error
ReddsTools_FRAMEWORKS = UIKit QuartzCore CoreGraphics Security
ReddsTools_LIBRARIES = substrate

include $(THEOS_MAKE_PATH)/tweak.mk
