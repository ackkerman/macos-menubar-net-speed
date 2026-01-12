SWIFT=swift
APP_NAME=MenubarNetSpeed
BUILD_DIR=$(PWD)/build
APP=$(BUILD_DIR)/$(APP_NAME).app
BIN=.build/release/$(APP_NAME)
SWIFT_SOURCES := $(shell find Sources -name '*.swift')

.PHONY: all build clean install run test

all: build

build: $(APP)

$(APP): $(SWIFT_SOURCES) Info.plist Package.swift
	$(SWIFT) build -c release
	rm -rf $(APP)
	mkdir -p $(APP)/Contents/MacOS
	cp $(BIN) $(APP)/Contents/MacOS/$(APP_NAME)
	cp Info.plist $(APP)/Contents/Info.plist

install: build
	@mkdir -p /Applications
	cp -R $(APP) /Applications/$(APP_NAME).app

run: build
	open $(APP)

test:
	$(SWIFT) test

clean:
	$(SWIFT) package clean
	rm -rf $(BUILD_DIR)
