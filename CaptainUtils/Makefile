APP_NAME = CaptainUtils
SRC_DIR = CaptainUtils
SOURCES = $(SRC_DIR)/main.swift $(SRC_DIR)/AppDelegate.swift $(SRC_DIR)/HotkeyManager.swift \
          $(SRC_DIR)/WindowManager.swift $(SRC_DIR)/ScreenManager.swift $(SRC_DIR)/SnapBackStore.swift
BUNDLE = $(APP_NAME).app
BINARY = $(BUNDLE)/Contents/MacOS/$(APP_NAME)

SWIFTC_FLAGS = -target arm64-apple-macosx13.0 -framework Cocoa -framework Carbon -framework ApplicationServices -framework ServiceManagement

.PHONY: build clean install run

build: $(BINARY)

$(BINARY): $(SOURCES) $(SRC_DIR)/Info.plist
	@mkdir -p $(BUNDLE)/Contents/MacOS $(BUNDLE)/Contents/Resources
	@cp $(SRC_DIR)/Info.plist $(BUNDLE)/Contents/
	swiftc $(SWIFTC_FLAGS) $(SOURCES) -o $(BINARY)

clean:
	rm -rf $(BUNDLE)

install: build
	cp -r $(BUNDLE) /Applications/

run: build
	open $(BUNDLE)
