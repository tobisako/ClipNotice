import AppKit

final class SettingsPanel: NSWindow {
    static let shared = SettingsPanel()

    var onChanged: (() -> Void)?

    private let fontSlider = NSSlider(value: 13, minValue: 8, maxValue: 48, target: nil, action: nil)
    private let fontValueLabel = NSTextField(labelWithString: "13pt")
    private let textColorButton = SettingsPanel.makeColorButton()
    private let bgColorButton   = SettingsPanel.makeColorButton()
    private let colorPicker = ColorPickerPanel()
    private var isPerformingClose = false
    private let wordWrapCheckbox = NSButton(checkboxWithTitle: "改行する", target: nil, action: nil)
    private let dismissSlider = NSSlider(value: 6, minValue: 1, maxValue: 10, target: nil, action: nil)
    private let dismissValueLabel = NSTextField(labelWithString: "3秒")
    private let autoCloseSlider = NSSlider(value: 8, minValue: 2, maxValue: 10, target: nil, action: nil)
    private let autoCloseValueLabel = NSTextField(labelWithString: "8秒")

    private init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 325),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        title = "ClipNotice 設定"
        isReleasedWhenClosed = false
        level = .modalPanel
        center()
        setupUI()
        loadFromSettings()

        colorPicker.onClose = { [weak self] in
            guard let self, !self.isPerformingClose else { return }
            self.makeKeyAndOrderFront(nil)
            self.scheduleAutoClose()
        }
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
        textColorButton.target = self
        textColorButton.action = #selector(openTextColorPicker)

        // --- Background color row ---
        let bgLabel = label("背景の色")
        bgColorButton.target = self
        bgColorButton.action = #selector(openBgColorPicker)

        // --- Word wrap checkbox ---
        wordWrapCheckbox.target = self
        wordWrapCheckbox.action = #selector(wordWrapChanged)

        // --- Timer section header ---
        let timerSectionLabel = NSTextField(labelWithString: "表示時間")
        timerSectionLabel.alignment = .left
        timerSectionLabel.textColor = .secondaryLabelColor
        timerSectionLabel.font = NSFont.systemFont(ofSize: 11)

        // --- Dismiss delay row ---
        let dismissLabel = label("付箋")
        dismissSlider.isContinuous = true
        dismissSlider.numberOfTickMarks = 10
        dismissSlider.allowsTickMarkValuesOnly = true
        dismissSlider.target = self
        dismissSlider.action = #selector(dismissChanged)
        dismissValueLabel.alignment = .right

        // --- Settings auto-close row ---
        let autoCloseLabel = label("設定")
        autoCloseSlider.isContinuous = true
        autoCloseSlider.numberOfTickMarks = 5
        autoCloseSlider.allowsTickMarkValuesOnly = true
        autoCloseSlider.target = self
        autoCloseSlider.action = #selector(autoCloseChanged)
        autoCloseValueLabel.alignment = .right

        for v in [fontLabel, fontSlider, fontValueLabel, textLabel, textColorButton, bgLabel, bgColorButton, wordWrapCheckbox, timerSectionLabel, dismissLabel, dismissSlider, dismissValueLabel, autoCloseLabel, autoCloseSlider, autoCloseValueLabel] {
            v.translatesAutoresizingMaskIntoConstraints = false
            cv.addSubview(v)
        }

        // Layer properties require the view to be in a window hierarchy
        for btn in [textColorButton, bgColorButton] {
            btn.layer?.cornerRadius = 4
            btn.layer?.borderWidth = 0.5
            btn.layer?.borderColor = NSColor.black.withAlphaComponent(0.3).cgColor
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

            textColorButton.leadingAnchor.constraint(equalTo: textLabel.trailingAnchor, constant: 8),
            textColorButton.centerYAnchor.constraint(equalTo: textLabel.centerYAnchor),
            textColorButton.widthAnchor.constraint(equalToConstant: 44),
            textColorButton.heightAnchor.constraint(equalToConstant: 28),

            // Row 3: background color
            bgLabel.leadingAnchor.constraint(equalTo: cv.leadingAnchor, constant: p),
            bgLabel.topAnchor.constraint(equalTo: textLabel.bottomAnchor, constant: rowH),
            bgLabel.widthAnchor.constraint(equalToConstant: labelW),

            bgColorButton.leadingAnchor.constraint(equalTo: bgLabel.trailingAnchor, constant: 8),
            bgColorButton.centerYAnchor.constraint(equalTo: bgLabel.centerYAnchor),
            bgColorButton.widthAnchor.constraint(equalToConstant: 44),
            bgColorButton.heightAnchor.constraint(equalToConstant: 28),

            // Row 4: word wrap
            wordWrapCheckbox.leadingAnchor.constraint(equalTo: cv.leadingAnchor, constant: p + labelW + 8),
            wordWrapCheckbox.topAnchor.constraint(equalTo: bgLabel.bottomAnchor, constant: rowH),

            // Section header: 表示時間
            timerSectionLabel.leadingAnchor.constraint(equalTo: cv.leadingAnchor, constant: p),
            timerSectionLabel.topAnchor.constraint(equalTo: wordWrapCheckbox.bottomAnchor, constant: rowH),
            timerSectionLabel.trailingAnchor.constraint(equalTo: cv.trailingAnchor, constant: -p),

            // Row 5: 付箋 dismiss delay
            dismissLabel.leadingAnchor.constraint(equalTo: cv.leadingAnchor, constant: p),
            dismissLabel.topAnchor.constraint(equalTo: timerSectionLabel.bottomAnchor, constant: 8),
            dismissLabel.widthAnchor.constraint(equalToConstant: labelW),

            dismissSlider.leadingAnchor.constraint(equalTo: dismissLabel.trailingAnchor, constant: 8),
            dismissSlider.centerYAnchor.constraint(equalTo: dismissLabel.centerYAnchor),
            dismissSlider.trailingAnchor.constraint(equalTo: cv.trailingAnchor, constant: -p - 50),

            dismissValueLabel.leadingAnchor.constraint(equalTo: dismissSlider.trailingAnchor, constant: 8),
            dismissValueLabel.trailingAnchor.constraint(equalTo: cv.trailingAnchor, constant: -p),
            dismissValueLabel.centerYAnchor.constraint(equalTo: dismissSlider.centerYAnchor),
            dismissValueLabel.widthAnchor.constraint(equalToConstant: 42),

            // Row 6: 設定 auto-close
            autoCloseLabel.leadingAnchor.constraint(equalTo: cv.leadingAnchor, constant: p),
            autoCloseLabel.topAnchor.constraint(equalTo: dismissLabel.bottomAnchor, constant: rowH - 4),
            autoCloseLabel.widthAnchor.constraint(equalToConstant: labelW),

            autoCloseSlider.leadingAnchor.constraint(equalTo: autoCloseLabel.trailingAnchor, constant: 8),
            autoCloseSlider.centerYAnchor.constraint(equalTo: autoCloseLabel.centerYAnchor),
            autoCloseSlider.trailingAnchor.constraint(equalTo: cv.trailingAnchor, constant: -p - 50),

            autoCloseValueLabel.leadingAnchor.constraint(equalTo: autoCloseSlider.trailingAnchor, constant: 8),
            autoCloseValueLabel.trailingAnchor.constraint(equalTo: cv.trailingAnchor, constant: -p),
            autoCloseValueLabel.centerYAnchor.constraint(equalTo: autoCloseSlider.centerYAnchor),
            autoCloseValueLabel.widthAnchor.constraint(equalToConstant: 42),
        ])
    }

    private func label(_ text: String) -> NSTextField {
        let f = NSTextField(labelWithString: text)
        f.alignment = .right
        return f
    }

    private static func makeColorButton() -> NSButton {
        let b = NSButton(frame: .zero)
        b.isBordered = false
        b.title = ""
        b.wantsLayer = true
        return b
    }

    private func loadFromSettings() {
        let s = Settings.shared
        fontSlider.doubleValue = Double(s.fontSize)
        fontValueLabel.stringValue = "\(Int(s.fontSize))pt"
        textColorButton.layer?.backgroundColor = s.textColor.cgColor
        bgColorButton.layer?.backgroundColor = s.backgroundColor.cgColor
        wordWrapCheckbox.state = s.wordWrap ? .on : .off
        dismissSlider.doubleValue = s.dismissDelay * 2
        dismissValueLabel.stringValue = Self.formatDelay(s.dismissDelay)
        autoCloseSlider.doubleValue = Double(s.settingsAutoCloseSecs)
        autoCloseValueLabel.stringValue = "\(s.settingsAutoCloseSecs)秒"
    }

    @objc private func fontChanged() {
        let size = CGFloat(fontSlider.doubleValue)
        Settings.shared.fontSize = size
        fontValueLabel.stringValue = "\(Int(size))pt"
        onChanged?()
        scheduleAutoClose()
    }

    @objc private func openTextColorPicker() {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(timerClose), object: nil)
        colorPicker.onChange = { [weak self] c in
            Settings.shared.textColor = c
            self?.textColorButton.layer?.backgroundColor = c.cgColor
            self?.onChanged?()
        }
        colorPicker.show(positionedRightOf: self, current: Settings.shared.textColor, title: "文字の色")
    }

    @objc private func openBgColorPicker() {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(timerClose), object: nil)
        colorPicker.onChange = { [weak self] c in
            Settings.shared.backgroundColor = c
            self?.bgColorButton.layer?.backgroundColor = c.cgColor
            self?.onChanged?()
        }
        colorPicker.show(positionedRightOf: self, current: Settings.shared.backgroundColor, title: "背景の色")
    }

    @objc private func wordWrapChanged() {
        Settings.shared.wordWrap = wordWrapCheckbox.state == .on
        onChanged?()
        scheduleAutoClose()
    }

    @objc private func dismissChanged() {
        let secs = dismissSlider.doubleValue / 2
        Settings.shared.dismissDelay = secs
        dismissValueLabel.stringValue = Self.formatDelay(secs)
        scheduleAutoClose()
    }

    @objc private func autoCloseChanged() {
        let v = Int(autoCloseSlider.doubleValue)
        Settings.shared.settingsAutoCloseSecs = v
        autoCloseValueLabel.stringValue = "\(v)秒"
        scheduleAutoClose()
    }

    private static func formatDelay(_ secs: TimeInterval) -> String {
        secs.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(secs))秒" : "\(secs)秒"
    }

    private func scheduleAutoClose() {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(timerClose), object: nil)
        perform(#selector(timerClose), with: nil, afterDelay: Double(Settings.shared.settingsAutoCloseSecs))
    }

    @objc private func timerClose() {
        guard !colorPicker.isVisible else { return }
        close()
    }

    override func close() {
        isPerformingClose = true
        if colorPicker.isVisible { colorPicker.hide() }
        isPerformingClose = false
        super.close()
    }

    func open() {
        NSApp.activate(ignoringOtherApps: true)
        makeKeyAndOrderFront(nil)
        loadFromSettings()
        scheduleAutoClose()
    }
}
