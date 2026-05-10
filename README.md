# ClipNotice

**Clipboard copy notifier for macOS — ambient, zero-UI.**

コピーした瞬間、画面の隅に付箋が表示される。3秒で消える。
Dockなし、メニューバーなし。確認のためにペーストする必要がなくなる。

> Differences from clipboard managers (Maccy, Clipy, Paste): ClipNotice stores **nothing**.
> No history. No hotkeys. Passive ambient notification only.

---

## Install

### Homebrew (推奨)

```bash
brew tap tobisako/clipnotice
brew install clipnotice
clipnotice &
```

### Build from source

```bash
git clone https://github.com/tobisako/ClipNotice.git
cd ClipNotice
bash build.sh release
.build/release/clipnotice &
```

**Requirements:** macOS 13+, Xcode (for swiftc)

---

## Usage

```
コピー → 左上に付箋表示 → 3秒後自動消去
クリック → 即時消去
右クリック → 設定 / Quit ClipNotice
```

---

## Settings

右クリック → **設定...** で変更可能（リアルタイムプレビュー付き）:

| 設定 | 内容 |
|------|------|
| 文字サイズ | 8〜48pt スライダー |
| 文字の色 | システムカラーピッカー |
| 背景の色 | システムカラーピッカー（デフォルト: 黄色） |
| 改行する | 長文の折り返し on/off |

設定パネルは10秒後に自動で閉じる。

---

## Auto-start at login

**System Settings → General → Login Items → "+" → `.build/release/clipnotice` を追加**

または LaunchAgent:

```bash
mkdir -p ~/Library/LaunchAgents
cat > ~/Library/LaunchAgents/com.tobisako.clipnotice.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.tobisako.clipnotice</string>
  <key>ProgramArguments</key>
  <array>
    <string>/path/to/.build/release/clipnotice</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
</dict>
</plist>
EOF
launchctl load ~/Library/LaunchAgents/com.tobisako.clipnotice.plist
```

---

## Distribution without Apple notarization

Homebrew Formula経由でインストールすると、ユーザーマシンでソースビルドされるため
`quarantine` 属性が付かない → Gatekeeperチェックなし → Apple Developer認証不要。

---

## Specs

| 項目 | 内容 |
|------|------|
| Dock | 非表示 |
| メニューバー | なし |
| 検知 | `NSPasteboard.changeCount` ポーリング (0.5秒) |
| 表示 | `NSPanel` (floating, nonactivating) |
| テキスト | 最大300文字（超過は末尾…） |
| 対象 | 文字列のみ（画像・ファイルは無視） |
| macOS | 13.0 Ventura 以降 |
| アーキテクチャ | Apple Silicon (arm64) |

---

## License

MIT — see [LICENSE](LICENSE)
