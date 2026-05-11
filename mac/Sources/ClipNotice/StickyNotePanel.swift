import AppKit

final class StickyNotePanel: NSPanel {
    private static let dismissDelay: TimeInterval = 3.0  // fallback only
    private static let maxTextLength = 300
    private static let panelWidth: CGFloat = 320
    private static let padding: CGFloat = 12
    private static let margin: CGFloat = 20

    private var dismissWorkItem: DispatchWorkItem?
    private let label: NSTextField
    private var dragStartLocation: NSPoint?
    private var customOrigin: NSPoint?

    override init(
        contentRect: NSRect,
        styleMask style: NSWindow.StyleMask,
        backing backingStoreType: NSWindow.BackingStoreType,
        defer flag: Bool
    ) {
        label = NSTextField(wrappingLabelWithString: "")
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
        setupWindow()
        setupContent()
        applySettings()
    }

    convenience init() {
        self.init(
            contentRect: NSRect(x: 0, y: 0, width: Self.panelWidth, height: 80),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
    }

    private func setupWindow() {
        isOpaque = false
        level = .floating
        isMovableByWindowBackground = true
        hasShadow = true
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        collectionBehavior = [.canJoinAllSpaces, .stationary]
    }

    private func setupContent() {
        label.isEditable = false
        label.isSelectable = false
        label.isBordered = false
        label.backgroundColor = .clear
        label.maximumNumberOfLines = 8
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false

        let cv = contentView!
        cv.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: cv.leadingAnchor, constant: Self.padding),
            label.trailingAnchor.constraint(equalTo: cv.trailingAnchor, constant: -Self.padding),
            label.topAnchor.constraint(equalTo: cv.topAnchor, constant: Self.padding + 4),
            label.bottomAnchor.constraint(equalTo: cv.bottomAnchor, constant: -Self.padding),
        ])

        let menu = NSMenu()
        let settingsItem = NSMenuItem(title: "設定...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: "Quit ClipNotice", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quitItem.target = NSApp
        menu.addItem(quitItem)
        cv.menu = menu
    }

    func applySettings() {
        let s = Settings.shared
        backgroundColor = s.backgroundColor
        label.font = NSFont.systemFont(ofSize: s.fontSize)
        label.textColor = s.textColor
        label.maximumNumberOfLines = 0
        label.lineBreakMode = s.wordWrap ? .byWordWrapping : .byClipping
    }

    func show(text: String) {
        let display = text.count > Self.maxTextLength
            ? String(text.prefix(Self.maxTextLength)) + "…"
            : text

        label.stringValue = display
        applySettings()

        let s = Settings.shared
        let lines = display.components(separatedBy: "\n")
        let lineCount = min(8, lines.count)
        let lineHeight = s.fontSize + 6
        let height = CGFloat(lineCount) * lineHeight + Self.padding * 2 + 4

        let panelWidth: CGFloat
        if s.wordWrap {
            panelWidth = Self.panelWidth
        } else {
            let font = NSFont.systemFont(ofSize: s.fontSize)
            let attrs: [NSAttributedString.Key: Any] = [.font: font]
            let maxLineW = lines.map { ($0 as NSString).size(withAttributes: attrs).width }.max() ?? 0
            let screenW = NSScreen.main?.visibleFrame.width ?? 800
            panelWidth = min(maxLineW + Self.padding * 2, screenW - Self.margin * 2)
        }

        let size = NSSize(width: max(panelWidth, 100), height: max(50, height))
        setContentSize(size)

        if let origin = customOrigin {
            setFrameOrigin(origin)
        } else if let screen = NSScreen.main {
            let x = screen.visibleFrame.minX + Self.margin
            let y = screen.visibleFrame.maxY - size.height - Self.margin
            setFrameOrigin(NSPoint(x: x, y: y))
        }

        dismissWorkItem?.cancel()
        orderFrontRegardless()

        let work = DispatchWorkItem { [weak self] in
            self?.close()
        }
        dismissWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Settings.shared.dismissDelay, execute: work)
    }

    @objc private func openSettings() {
        SettingsPanel.shared.onChanged = { [weak self] in
            self?.show(text: "プレビュー Preview\nABC abc 123 あいう")
        }
        SettingsPanel.shared.open()
    }

    override func mouseDown(with event: NSEvent) {
        dismissWorkItem?.cancel()
        dragStartLocation = NSEvent.mouseLocation
    }

    override func mouseUp(with event: NSEvent) {
        guard let start = dragStartLocation else { return }
        let d = NSEvent.mouseLocation
        if hypot(d.x - start.x, d.y - start.y) < 5 {
            close()
        } else {
            customOrigin = frame.origin
            let work = DispatchWorkItem { [weak self] in self?.close() }
            dismissWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + Settings.shared.dismissDelay, execute: work)
        }
        dragStartLocation = nil
    }
}
