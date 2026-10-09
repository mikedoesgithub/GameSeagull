TARGET := iphone:clang:latest:14.0
INSTALL_TARGET_PROCESSES = MobileSMS

# arm64 only: arm64e slices need Apple ld64 + PAC codegen that mainline
# LLVM ld64.lld rejects (__cfstring relocations). arm64 runs on all devices.
ARCHS = arm64

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = GameSeagull

GameSeagull_FILES = Tweak.x Utils.m
GameSeagull_LIBRARIES = substrate
GameSeagull_CFLAGS = -fobjc-arc -Wno-error=deprecated-declarations -ferror-limit=0

# Linux (Omarchy/Arch) local builds: use LLVM Mach-O linker, defer
# __isPlatformVersionAtLeast to runtime (real libSystem on device has it).
# macOS/Xcode (Codemagic) needs neither flag.
ifeq ($(shell uname),Linux)
GameSeagull_LDFLAGS += -fuse-ld=lld -Wl,-U,___isPlatformVersionAtLeast
endif

include $(THEOS_MAKE_PATH)/tweak.mk
SUBPROJECTS += gameseagullprefs
include $(THEOS_MAKE_PATH)/aggregate.mk
