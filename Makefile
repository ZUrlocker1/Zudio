APP_NAME   = Zudio
APP_DIR    = /tmp/$(APP_NAME).app
BINARY     = .build/debug/$(APP_NAME)
PLIST_SRC  = Sources/Zudio/Info.plist

.PHONY: run build bundle clean

## Build + wrap in .app bundle + launch (primary dev workflow)
run: bundle
	open $(APP_DIR)

## Build only
build:
	swift build

## Wrap the built binary into a minimal .app bundle
bundle: build
	mkdir -p $(APP_DIR)/Contents/MacOS
	mkdir -p $(APP_DIR)/Contents/Resources
	cp $(BINARY)    $(APP_DIR)/Contents/MacOS/$(APP_NAME)
	cp $(PLIST_SRC) $(APP_DIR)/Contents/Info.plist
	cp -r assets    $(APP_DIR)/Contents/Resources/
	cp assets/images/icon/zudio-icon.icns $(APP_DIR)/Contents/Resources/
	cp assets/zudio-doc.icns             $(APP_DIR)/Contents/Resources/

## Run tests
test:
	swift test

clean:
	rm -rf $(APP_DIR)
	swift package clean
