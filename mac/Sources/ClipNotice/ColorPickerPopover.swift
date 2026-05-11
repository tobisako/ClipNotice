import AppKit

// NSPanel at .popUpMenu level (101) guarantees z-order:
//   ColorPickerPanel(101) > SettingsPanel(.modalPanel=8) > StickyNotePanel(.floating=3)
// NSPopover cannot achieve this — AppKit overrides _NSPopoverWindow.level regardless of
// window.level assignment or addChildWindow calls.
final class ColorPickerPanel: NSPanel {
    var onChange: ((NSColor) -> Void)?
    var onClose: (() -> Void)?
    private let vc = ColorPickerVC()
    private var clickMonitor: Any?

    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: style, backing: backing, defer: flag)
    }

    convenience init() {
        self.init(
            contentRect: .zero,
            styleMask: [.nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        level = .popUpMenu
        hasShadow = true
        isReleasedWhenClosed = false
        isMovable = false
        contentViewController = vc
        vc.onSelect = { [weak self] c in self?.onChange?(c) }
        setContentSize(vc.preferredSize)
    }

    func show(positionedRightOf anchor: NSWindow, current: NSColor) {
        guard !isVisible else { return }
        vc.setInitial(current)
        let size = vc.preferredSize
        let x = anchor.frame.maxX + 8
        let y = anchor.frame.midY - size.height / 2
        setFrame(NSRect(origin: NSPoint(x: x, y: y), size: size), display: false)
        orderFront(nil)
        startClickMonitor()
    }

    func hide() {
        guard isVisible else { return }
        stopClickMonitor()
        orderOut(nil)
        onClose?()
    }

    private func startClickMonitor() {
        clickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self, self.isVisible else { return event }
            if event.window !== self { self.hide() }
            return event
        }
    }

    private func stopClickMonitor() {
        if let m = clickMonitor { NSEvent.removeMonitor(m); clickMonitor = nil }
    }
}

private final class ColorPickerVC: NSViewController {
    var onSelect: ((NSColor) -> Void)?

    private let hexField: NSTextField = {
        let f = NSTextField()
        f.placeholderString = "#RRGGBB"
        f.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        return f
    }()

    // 4 rows × 8 cols
    static let palette: [[NSColor]] = [
        // Grays
        [.white,
         NSColor(white: 0.9, alpha: 1), NSColor(white: 0.75, alpha: 1),
         NSColor(white: 0.55, alpha: 1), NSColor(white: 0.35, alpha: 1),
         NSColor(white: 0.15, alpha: 1), .black,
         NSColor(red: 0.35, green: 0.3, blue: 0.45, alpha: 1)],
        // Reds / Oranges / Browns
        [NSColor(red: 1,    green: 0.8,  blue: 0.8, alpha: 1),
         NSColor(red: 1,    green: 0.5,  blue: 0.5, alpha: 1),
         .red,
         NSColor(red: 0.75, green: 0,    blue: 0,   alpha: 1),
         NSColor(red: 1,    green: 0.7,  blue: 0.4, alpha: 1),
         .orange,
         NSColor(red: 0.65, green: 0.35, blue: 0,   alpha: 1),
         .brown],
        // Yellows / Greens
        [NSColor(red: 1,    green: 0.98, blue: 0.6, alpha: 1),
         .yellow,
         NSColor(red: 0.7,  green: 0.9,  blue: 0.3, alpha: 1),
         NSColor(red: 0.3,  green: 0.75, blue: 0.3, alpha: 1),
         .green,
         NSColor(red: 0,    green: 0.5,  blue: 0,   alpha: 1),
         NSColor(red: 0.25, green: 0.8,  blue: 0.7, alpha: 1),
         NSColor(red: 0,    green: 0.5,  blue: 0.5, alpha: 1)],
        // Blues / Purples / Pinks
        [NSColor(red: 0.7,  green: 0.85, blue: 1,   alpha: 1),
         NSColor(red: 0.3,  green: 0.6,  blue: 1,   alpha: 1),
         .blue,
         NSColor(red: 0,    green: 0,    blue: 0.75, alpha: 1),
         NSColor(red: 0.6,  green: 0.3,  blue: 0.9, alpha: 1),
         .purple,
         NSColor(red: 1,    green: 0.4,  blue: 0.7, alpha: 1),
         NSColor(red: 1,    green: 0.75, blue: 0.87, alpha: 1)],
    ]

    var preferredSize: NSSize {
        let swatchSize: CGFloat = 24
        let gap: CGFloat = 4
        let cols = Self.palette[0].count
        let rows = Self.palette.count
        let inset: CGFloat = 8
        let width  = inset + CGFloat(cols) * swatchSize + CGFloat(cols - 1) * gap + inset
        let swatchH = CGFloat(rows) * swatchSize + CGFloat(rows - 1) * gap
        let height = inset + swatchH + gap + 24 + inset
        return NSSize(width: width, height: height)
    }

    func setInitial(_ color: NSColor) {
        hexField.stringValue = color.hexString
    }

    override func loadView() {
        let swatchSize: CGFloat = 24
        let gap: CGFloat = 4
        let cols = Self.palette[0].count
        let rows = Self.palette.count
        let inset: CGFloat = 8
        let width  = inset + CGFloat(cols) * swatchSize + CGFloat(cols - 1) * gap + inset
        let swatchH = CGFloat(rows) * swatchSize + CGFloat(rows - 1) * gap
        let hexRowH: CGFloat = 24
        let height = inset + swatchH + gap + hexRowH + inset

        let v = NSView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        view = v

        // Build swatches (NSView y=0 at bottom)
        for (ri, row) in Self.palette.enumerated() {
            let yFromTop = inset + CGFloat(ri) * (swatchSize + gap)
            let y = height - yFromTop - swatchSize
            for (ci, color) in row.enumerated() {
                let x = inset + CGFloat(ci) * (swatchSize + gap)
                let btn = NSButton(frame: NSRect(x: x, y: y, width: swatchSize, height: swatchSize))
                btn.wantsLayer = true
                btn.layer?.backgroundColor = color.cgColor
                btn.layer?.cornerRadius = 3
                btn.layer?.borderWidth = 0.5
                btn.layer?.borderColor = NSColor.black.withAlphaComponent(0.25).cgColor
                btn.isBordered = false
                btn.title = ""
                btn.target = self
                btn.action = #selector(swatchHit(_:))
                btn.tag = ri * cols + ci
                v.addSubview(btn)
            }
        }

        // Hex row at bottom
        let hexY: CGFloat = inset
        hexField.frame = NSRect(x: inset, y: hexY, width: 100, height: hexRowH)
        hexField.delegate = self
        v.addSubview(hexField)

        let applyBtn = NSButton(title: "適用", target: self, action: #selector(applyHex))
        applyBtn.frame = NSRect(x: inset + 108, y: hexY, width: 50, height: hexRowH)
        applyBtn.bezelStyle = .inline
        v.addSubview(applyBtn)
    }

    @objc private func swatchHit(_ sender: NSButton) {
        let ri = sender.tag / Self.palette[0].count
        let ci = sender.tag % Self.palette[0].count
        let c = Self.palette[ri][ci]
        hexField.stringValue = c.hexString
        onSelect?(c)
    }

    @objc private func applyHex() {
        guard let c = NSColor(hexString: hexField.stringValue) else { return }
        onSelect?(c)
    }
}

extension ColorPickerVC: NSTextFieldDelegate {
    func control(_ control: NSControl, textView: NSTextView, doCommandBy sel: Selector) -> Bool {
        if sel == #selector(NSResponder.insertNewline(_:)) { applyHex(); return true }
        return false
    }
}

// MARK: - NSColor hex helpers
extension NSColor {
    var hexString: String {
        guard let c = usingColorSpace(.sRGB) else { return "#000000" }
        return String(format: "#%02X%02X%02X",
            Int(c.redComponent * 255),
            Int(c.greenComponent * 255),
            Int(c.blueComponent * 255))
    }

    convenience init?(hexString: String) {
        var s = hexString.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s = String(s.dropFirst()) }
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
        self.init(
            red:   CGFloat((v >> 16) & 0xFF) / 255,
            green: CGFloat((v >>  8) & 0xFF) / 255,
            blue:  CGFloat( v        & 0xFF) / 255,
            alpha: 1)
    }
}
