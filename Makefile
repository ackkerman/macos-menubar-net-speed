SWIFT=swift
APP_NAME=MenubarNetSpeed
BUILD_DIR=$(PWD)/build
APP=$(BUILD_DIR)/$(APP_NAME).app
BIN=.build/release/$(APP_NAME)
ICON_SRC=assets/icon.png
ICONSET_DIR=$(BUILD_DIR)/AppIcon.iconset
APPICONSET_DIR=$(BUILD_DIR)/AppIcon.appiconset
ICON_ICNS=$(BUILD_DIR)/AppIcon.icns
SWIFT_SOURCES := $(shell find Sources -name '*.swift')

.PHONY: all build clean install run test

all: build

build: $(APP)

icons: $(ICON_ICNS) $(APPICONSET_DIR)

$(ICONSET_DIR): $(ICON_SRC)
	rm -rf $(ICONSET_DIR)
	mkdir -p $(ICONSET_DIR)
	sips -z 16 16 $(ICON_SRC) --out $(ICONSET_DIR)/icon_16x16.png
	sips -z 32 32 $(ICON_SRC) --out $(ICONSET_DIR)/icon_16x16@2x.png
	sips -z 32 32 $(ICON_SRC) --out $(ICONSET_DIR)/icon_32x32.png
	sips -z 64 64 $(ICON_SRC) --out $(ICONSET_DIR)/icon_32x32@2x.png
	sips -z 128 128 $(ICON_SRC) --out $(ICONSET_DIR)/icon_128x128.png
	sips -z 256 256 $(ICON_SRC) --out $(ICONSET_DIR)/icon_128x128@2x.png
	sips -z 256 256 $(ICON_SRC) --out $(ICONSET_DIR)/icon_256x256.png
	sips -z 512 512 $(ICON_SRC) --out $(ICONSET_DIR)/icon_256x256@2x.png
	sips -z 512 512 $(ICON_SRC) --out $(ICONSET_DIR)/icon_512x512.png
	sips -z 1024 1024 $(ICON_SRC) --out $(ICONSET_DIR)/icon_512x512@2x.png

$(APPICONSET_DIR): $(ICONSET_DIR)
	rm -rf $(APPICONSET_DIR)
	cp -R $(ICONSET_DIR) $(APPICONSET_DIR)
	printf '%s\n' \\\n\t\t'{' \\\n\t\t'  \"images\" : [' \\\n\t\t'    { \"idiom\" : \"mac\", \"size\" : \"16x16\",  \"scale\" : \"1x\", \"filename\" : \"icon_16x16.png\" },' \\\n\t\t'    { \"idiom\" : \"mac\", \"size\" : \"16x16\",  \"scale\" : \"2x\", \"filename\" : \"icon_16x16@2x.png\" },' \\\n\t\t'    { \"idiom\" : \"mac\", \"size\" : \"32x32\",  \"scale\" : \"1x\", \"filename\" : \"icon_32x32.png\" },' \\\n\t\t'    { \"idiom\" : \"mac\", \"size\" : \"32x32\",  \"scale\" : \"2x\", \"filename\" : \"icon_32x32@2x.png\" },' \\\n\t\t'    { \"idiom\" : \"mac\", \"size\" : \"128x128\", \"scale\" : \"1x\", \"filename\" : \"icon_128x128.png\" },' \\\n\t\t'    { \"idiom\" : \"mac\", \"size\" : \"128x128\", \"scale\" : \"2x\", \"filename\" : \"icon_128x128@2x.png\" },' \\\n\t\t'    { \"idiom\" : \"mac\", \"size\" : \"256x256\", \"scale\" : \"1x\", \"filename\" : \"icon_256x256.png\" },' \\\n\t\t'    { \"idiom\" : \"mac\", \"size\" : \"256x256\", \"scale\" : \"2x\", \"filename\" : \"icon_256x256@2x.png\" },' \\\n\t\t'    { \"idiom\" : \"mac\", \"size\" : \"512x512\", \"scale\" : \"1x\", \"filename\" : \"icon_512x512.png\" },' \\\n\t\t'    { \"idiom\" : \"mac\", \"size\" : \"512x512\", \"scale\" : \"2x\", \"filename\" : \"icon_512x512@2x.png\" }' \\\n\t\t'  ],' \\\n\t\t'  \"info\" : { \"version\" : 1, \"author\" : \"make\" }' \\\n\t\t'}' > $(APPICONSET_DIR)/Contents.json

$(ICON_ICNS): $(ICONSET_DIR)
	iconutil --convert icns --output $(ICON_ICNS) $(ICONSET_DIR)

$(APP): $(SWIFT_SOURCES) Info.plist Package.swift icons
	$(SWIFT) build -c release
	rm -rf $(APP)
	mkdir -p $(APP)/Contents/MacOS
	cp $(BIN) $(APP)/Contents/MacOS/$(APP_NAME)
	cp Info.plist $(APP)/Contents/Info.plist
	mkdir -p $(APP)/Contents/Resources
	cp $(ICON_ICNS) $(APP)/Contents/Resources/AppIcon.icns
	cp -R $(APPICONSET_DIR) $(APP)/Contents/Resources/AppIcon.appiconset

install: build
	@mkdir -p /Applications
	rm -rf /Applications/$(APP_NAME).app
	cp -R $(APP) /Applications/$(APP_NAME).app

run: build
	open $(APP)

test:
	$(SWIFT) test

clean:
	$(SWIFT) package clean
	rm -rf $(BUILD_DIR)
