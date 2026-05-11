# Changelog

All notable changes to ClipNotice are documented here.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)

---

## [Unreleased]

---

## [0.3.1] — 2026-05-11

### Added (macOS)
- Custom color picker — 32-color swatch grid + hex input (replaces system NSColorPanel)
- Color picker title label: shows "文字の色" or "背景の色" to indicate which color is being edited
- Color picker opens instantly on mouseDown (not mouseUp)
- Color picker button toggles picker closed on repeat press
- Settings auto-close timer resets whenever any control is adjusted (slider, checkbox)

### Fixed (macOS)
- Color picker z-order: now always appears above settings window (NSPanel at `.popUpMenu` level)
- Preview sticky note respected wordWrap OFF (was still line-breaking due to `\n` in preview text)

### Added (Windows)
- Drag-to-move sticky note — drag preserves position for next display
- Dismiss delay slider (0.5–5s, default 3s)
- Context menu kept alive 2s after sticky disappears
- Custom color picker — Mac parity (32-color swatch grid + #RRGGBB hex input, mouseDown trigger, toggle on repeat press, click-outside dismiss, title label)
- Settings panel auto-close timer (2/4/6/8/10s, default 8s) — resets on any control interaction
- Settings panel "表示時間" section with dual sliders (付箋 dismiss + 設定 auto-close)
- Z-order guarantee: ColorPickerForm > SettingsForm > StickyForm via `Form.Owner` chain + `TopMost`

### Fixed (Windows)
- Sticky popup now displays `\n` line breaks even with WordWrap=OFF (removed `SingleLine` flag in TextRenderer.MeasureText)
- Sticky timer no longer pauses while context menu is open — sticky now hides (Opacity=0) at dismiss time, then force-closes the menu 2s later (Mac parity)

### Docs
- docs/design/macos.md: corrected drag-to-move mechanism, NSWindowDelegate, Login Items note, dismissDelay default 3s annotation
- docs/design/windows.md: full sync with Mac architecture (Z-order, click-outside, color picker lifetime, drag-to-move, context menu lifetime, settings persistence keys)
- README.md: Windows install no longer requires .NET runtime install (now self-contained EXE), direct download link added

---

## [0.3.0] — 2026-05-10

### Added
- **Windows support** — C# WinForms version (`win/`)
- GitHub Actions workflow (`build-windows.yml`) — auto-builds EXE and attaches to releases on `v*` tag push
- Monorepo structure: macOS sources moved to `mac/`, Windows sources in `win/`

### Fixed
- GitHub Actions: added `permissions: contents: write` so release asset upload works

---

## [0.2.0] — 2026-05-10

### Added
- Settings panel (right-click → 設定...) with real-time preview
  - Font size (8–48pt slider)
  - Text color (color picker)
  - Background color (color picker)
  - Word wrap toggle

### Fixed
- Word wrap OFF: panel width now auto-expands to fit text width (no more `…` truncation)
- Panel height correctly reflects word wrap setting

---

## [0.1.0] — 2026-05-10

### Added
- Initial release — macOS clipboard change notifier
- Floating sticky note appears on copy, auto-dismisses after 3 seconds
- Click to dismiss immediately
- Right-click → Quit ClipNotice
- Homebrew tap: `brew tap tobisako/clipnotice && brew install clipnotice`
- No Dock icon, no menu bar icon — pure background utility
