# ClipNotice

クリップボードにコピーが発生したら、画面左上に付箋として表示。3秒後自動消去。

## 動作

```
コピー → 左上に黄色い付箋表示 → 3秒後消去
クリックで即時消去
右クリック → Quit ClipNotice
```

## ビルド & 起動

```bash
make debug
.build/debug/clipnotice &
```

リリースビルド:
```bash
make build
.build/release/clipnotice &
```

終了:
```bash
make kill
# または右クリック → Quit
```

## 配布（notarization不要）

Homebrew Formula経由で配布すると、ユーザーマシンでソースビルドされるため
`quarantine` 属性が付かない = Gatekeeperチェックなし = Apple認証不要。

```bash
brew tap tobisako/clipnotice
brew install clipnotice
```

## ログイン時自動起動

System Settings → General → Login Items → "+" → `.build/release/clipnotice` を追加。

または LaunchAgent:

```bash
cat > ~/Library/LaunchAgents/com.tobisako.clipnotice.plist << EOF
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

## 仕様

- Dock: 非表示（`NSApp.setActivationPolicy(.accessory)`）
- メニューバー: なし
- 検知: `NSPasteboard.changeCount` ポーリング 0.5秒
- 表示: `NSPanel` (floating, nonactivating)
- テキスト: 最大300文字（超過は末尾に…）
- 対象: 文字列のみ（画像・ファイルは無視）
