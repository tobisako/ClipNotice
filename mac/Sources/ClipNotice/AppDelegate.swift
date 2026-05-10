import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let monitor = ClipboardMonitor()
    private var panel: StickyNotePanel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        panel = StickyNotePanel()
        monitor.start { [weak self] text in
            self?.panel?.show(text: text)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        monitor.stop()
    }
}
