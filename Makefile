export PACKAGE_VERSION := 1.6

ifeq ($(THEOS_DEVICE_SIMULATOR),1)
TARGET := simulator:clang:latest:14.0
INSTALL_TARGET_PROCESSES := SpringBoard
ARCHS := arm64 x86_64
else
TARGET := iphone:clang:latest:14.0
INSTALL_TARGET_PROCESSES := SpringBoard
ARCHS := arm64 arm64e
endif

include $(THEOS)/makefiles/common.mk

SUBPROJECTS += SingleVPNPrefs

include $(THEOS_MAKE_PATH)/aggregate.mk

TWEAK_NAME := SingleVPN

SingleVPN_FILES += SingleVPN.x
SingleVPN_FILES += UIColor+.m
SingleVPN_CFLAGS += -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk

export THEOS_OBJ_DIR
after-all::
	@devkit/sim-install.sh