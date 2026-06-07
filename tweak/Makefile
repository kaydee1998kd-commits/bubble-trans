ARCHS = arm64 arm64e
TARGET := iphone:clang:latest:15.0
PACKAGE_FORMAT = deb
INSTALL_TARGET_PROCESSES = Xianyu Taobao Pinduoduo

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = BubbleTrans
BubbleTrans_FILES = Tweak.xm
BubbleTrans_CFLAGS = -fobjc-arc
BubbleTrans_FRAMEWORKS = UIKit Foundation Vision QuartzCore CoreGraphics ImageIO

include $(THEOS_MAKE_PATH)/tweak.mk
