import AppKit

let app = NSApplication.shared
app.setActivationPolicy(.accessory) // No Dock icon, events work normally

let delegate = AppDelegate()
app.delegate = delegate
app.run()
