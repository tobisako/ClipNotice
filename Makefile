MAC_DIR := mac

.PHONY: mac mac-debug mac-run mac-kill mac-clean

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
