MAC_DIR := mac
WIN_DIR := win

.PHONY: mac mac-debug mac-run mac-kill mac-clean
.PHONY: win-publish win-clean

# macOS targets
mac:
	bash $(MAC_DIR)/build.sh release

mac-debug:
	bash $(MAC_DIR)/build.sh debug

mac-run: mac-debug
	$(MAC_DIR)/.build/debug/clipnotice &

mac-kill:
	@pkill clipnotice 2>/dev/null && echo "Stopped" || echo "Not running"

mac-clean:
	rm -rf $(MAC_DIR)/.build

# Windows targets (requires .NET SDK; actual run/test needs Windows)
win-publish:
	cd $(WIN_DIR) && dotnet publish ClipNotice.csproj \
		-c Release -r win-x64 --self-contained true \
		-p:PublishSingleFile=true -p:EnableCompressionInSingleFile=true \
		-o publish

win-clean:
	rm -rf $(WIN_DIR)/bin $(WIN_DIR)/obj $(WIN_DIR)/publish
