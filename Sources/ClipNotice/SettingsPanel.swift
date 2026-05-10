import AppKit

final class SettingsPanel: NSWindow {
    static let shared = SettingsPanel()

    var onChanged: (() -> Void)?

    private let fontSlider = NSSlider(value: 13, minValue: 8, maxValue: 48, target: nil, action: nil)
    private let fontValueLabel = NSTextField(labelWithString: "13pt")
    private let textColorWell = NSColorWell()
    private let bgColorWell = NSColorWell()

    private init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 180),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        title = "ClipNotice 設定"
        isReleasedWhenClosed = false
        center()
        setupUI()
        loadFromSettings()
    }

    private func setupUI() {
        let cv = contentView!

        // --- Font size row ---
        let fontLabel = label("文字サイズ")
        fontSlider.isContinuous = true
        fontSlider.target = self
        fontSlider.action = #selector(fontChanged)
        fontValueLabel.alignment = .right

        // --- Text color row ---
        let textLabel = label("文字の色")
        textColorWell.target = self
        textColorWell.action = #selector(textColorChanged)

        // --- Background color row ---
        let bgLabel = label("背景の色")
        bgColorWell.target = self
        bgColorWell.action = #selector(bgColorChanged)

        for v in [fontLabel, fontSlider, fontValueLabel, textLabel, textColorWell, bgLabel, bgColorWell] {
            v.translatesAutoresizingMaskIntoConstraints = false
            cv.addSubview(v)
        }

        let p: CGFloat = 20
        let rowH: CGFloat = 30
        let labelW: CGFloat = 80

        NSLayoutConstraint.activate([
            // Row 1: font size
            fontLabel.leadingAnchor.constraint(equalTo: cv.leadingAnchor, constant: p),
            fontLabel.topAnchor.constraint(equalTo: cv.topAnchor, constant: p),
            fontLabel.widthAnchor.constraint(equalToConstant: labelW),

            fontSlider.leadingAnchor.constraint(equalTo: fontLabel.trailingAnchor, constant: 8),
            fontSlider.centerYAnchor.constraint(equalTo: fontLabel.centerYAnchor),
            fontSlider.trailingAnchor.constraint(equalTo: cv.trailingAnchor, constant: -p - 50),

            fontValueLabel.leadingAnchor.constraint(equalTo: fontSlider.trailingAnchor, constant: 8),
            fontValueLabel.trailingAnchor.constraint(equalTo: cv.trailingAnchor, constant: -p),
            fontValueLabel.centerYAnchor.constraint(equalTo: fontSlider.centerYAnchor),
            fontValueLabel.widthAnchor.constraint(equalToConstant: 42),

            // Row 2: text color
            textLabel.leadingAnchor.constraint(equalTo: cv.leadingAnchor, constant: p),
            textLabel.topAnchor.constraint(equalTo: fontLabel.bottomAnchor, constant: rowH),
            textLabel.widthAnchor.constraint(equalToConstant: labelW),

            textColorWell.leadingAnchor.constraint(equalTo: textLabel.trailingAnchor, constant: 8),
            textColorWell.centerYAnchor.constraint(equalTo: textLabel.centerYAnchor),
            textColorWell.widthAnchor.constraint(equalToConstant: 44),
            textColorWell.heightAnchor.constraint(equalToConstant: 28),

            // Row 3: background color
            bgLabel.leadingAnchor.constraint(equalTo: cv.leadingAnchor, constant: p),
            bgLabel.topAnchor.constraint(equalTo: textLabel.bottomAnchor, constant: rowH),
            bgLabel.widthAnchor.constraint(equalToConstant: labelW),

            bgColorWell.leadingAnchor.constraint(equalTo: bgLabel.trailingAnchor, constant: 8),
            bgColorWell.centerYAnchor.constraint(equalTo: bgLabel.centerYAnchor),
            bgColorWell.widthAnchor.constraint(equalToConstant: 44),
            bgColorWell.heightAnchor.constraint(equalToConstant: 28),
        ])
    }

    private func label(_ text: String) -> NSTextField {
        let f = NSTextField(labelWithString: text)
        f.alignment = .right
        return f
    }

    private func loadFromSettings() {
        let s = Settings.shared
        fontSlider.doubleValue = Double(s.fontSize)
        fontValueLabel.stringValue = "\(Int(s.fontSize))pt"
        textColorWell.color = s.textColor
        bgColorWell.color = s.backgroundColor
    }

    @objc private func fontChanged() {
        let size = CGFloat(fontSlider.doubleValue)
        Settings.shared.fontSize = size
        fontValueLabel.stringValue = "\(Int(size))pt"
        onChanged?()
    }

    @objc private func textColorChanged() {
        Settings.shared.textColor = textColorWell.color
        onChanged?()
    }

    @objc private func bgColorChanged() {
        Settings.shared.backgroundColor = bgColorWell.color
        onChanged?()
    }

    func open() {
        NSApp.activate(ignoringOtherApps: true)
        makeKeyAndOrderFront(nil)
    }
}
