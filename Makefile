SWIFT := /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc
SDK   := $(shell ls -d /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX*.sdk 2>/dev/null | sort -V | tail -1)
SRC   := Sources/ClipNotice
OUT   := .build

SOURCES := $(SRC)/main.swift $(SRC)/AppDelegate.swift $(SRC)/ClipboardMonitor.swift $(SRC)/StickyNotePanel.swift

.PHONY: build run clean kill

build:
	@mkdir -p $(OUT)/release
	$(SWIFT) \
		-sdk "$(SDK)" \
		-target arm64-apple-macosx13.0 \
		-module-name clipnotice \
		-O \
		-framework AppKit \
		-framework Foundation \
		-o $(OUT)/release/clipnotice \
		$(SOURCES)
	@echo "Built: $(OUT)/release/clipnotice"

debug:
	@mkdir -p $(OUT)/debug
	$(SWIFT) \
		-sdk "$(SDK)" \
		-target arm64-apple-macosx13.0 \
		-module-name clipnotice \
		-framework AppKit \
		-framework Foundation \
		-o $(OUT)/debug/clipnotice \
		$(SOURCES)
	@echo "Built: $(OUT)/debug/clipnotice"

run: debug
	.build/debug/clipnotice &

kill:
	@pkill clipnotice 2>/dev/null && echo "Stopped" || echo "Not running"

clean:
	rm -rf $(OUT)
