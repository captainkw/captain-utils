APP_NAME = CaptainUtils
SRC_DIR = CaptainUtils
SOURCES = $(SRC_DIR)/main.swift $(SRC_DIR)/AppDelegate.swift $(SRC_DIR)/HotkeyManager.swift \
          $(SRC_DIR)/WindowManager.swift $(SRC_DIR)/ScreenManager.swift $(SRC_DIR)/SnapBackStore.swift
BUNDLE = $(APP_NAME).app
BINARY = $(BUNDLE)/Contents/MacOS/$(APP_NAME)

SWIFTC_FLAGS = -target arm64-apple-macosx13.0 -framework Cocoa -framework Carbon -framework ApplicationServices -framework ServiceManagement

# Use the stable self-signed identity if present (see setup-signing.sh), else ad-hoc.
SIGN_IDENTITY = CaptainUtils Dev
HAVE_IDENTITY = $(shell security find-identity -v -p codesigning 2>/dev/null | grep -c "$(SIGN_IDENTITY)")

.PHONY: build clean install run setup-signing

build: $(BINARY)

$(BINARY): $(SOURCES) $(SRC_DIR)/Info.plist
	@mkdir -p $(BUNDLE)/Contents/MacOS $(BUNDLE)/Contents/Resources
	@cp $(SRC_DIR)/Info.plist $(BUNDLE)/Contents/
	swiftc $(SWIFTC_FLAGS) $(SOURCES) -o $(BINARY)
	@if [ "$(HAVE_IDENTITY)" -gt 0 ]; then \
	  echo "Signing with stable identity '$(SIGN_IDENTITY)'"; \
	  codesign --force --sign "$(SIGN_IDENTITY)" $(BUNDLE); \
	else \
	  echo "Signing ad-hoc (run ./setup-signing.sh for a persistent Accessibility grant)"; \
	  codesign --force --sign - $(BUNDLE); \
	fi

setup-signing:
	./setup-signing.sh

clean:
	rm -rf $(BUNDLE)

install: build
	cp -r $(BUNDLE) /Applications/

run: build
	open $(BUNDLE)
