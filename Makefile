ARCHS = arm64
TARGET = iphone:clang:latest:15.1

include $(THEOS)/makefiles/common.mk

LIBRARY_NAME = EOSignal

EOSignal_FILES = \
	Sources/Entry.mm \
	Sources/EOOverlayView.mm \
	Sources/EORuntimeInspector.mm \
	Sources/EOProbe.mm

EOSignal_FRAMEWORKS = Foundation UIKit QuartzCore

EOSignal_CFLAGS = -fobjc-arc
EOSignal_CCFLAGS = -std=c++17

include $(THEOS_MAKE_PATH)/library.mk
