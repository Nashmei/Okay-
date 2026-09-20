ARCHS = arm64
TARGET = iphone:clang:latest:15.1

include $(THEOS)/makefiles/common.mk

LIBRARY_NAME = EOSignal
EOSignal_FILES = Sources/Entry.mm Sources/EOOverlayView.mm Sources/EORuntimeInspector.mm Sources/EOProbe.mm
EOSignal_CFLAGS = -fobjc-arc
EOSignal_CCFLAGS = -std=c++17 -fobjc-arc
EOSignal_FRAMEWORKS = UIKit Foundation
EOSignal_INSTALL_PATH = /Frameworks

include $(THEOS_MAKE_PATH)/library.mk
