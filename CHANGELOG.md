# Changelog

All notable changes to ClipNotice are documented here.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)

---

## [Unreleased]

### Added
- Windows: system tray icon (NotifyIcon) — always-available access to Settings/Quit
- Windows: live preview while adjusting settings
- Windows: self-contained EXE (no .NET runtime install required)
- Windows: suppress showing pre-existing clipboard content on startup
- Windows: accurate sticky note sizing via TextRenderer
- docs/design/macos.md — macOS architecture design document
- docs/design/windows.md — Windows architecture design document

### Fixed
- .gitignore: exclude root-level `.build/` directory
- mac/build.sh: use absolute paths so the script works from any working directory

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
