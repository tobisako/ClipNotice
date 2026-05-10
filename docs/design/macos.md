# ClipNotice — macOS Design Document

Generated: 2026-05-10 by tobisako (/office-hours Builder Mode)
Branch: HEAD (new project)

## Problem

コピー操作のたびに「正しくコピーできたか？」という認知負荷がある。
確認のためにペーストするか、クリップボードマネージャーのホットキーを押す必要がある。

ClipNoticeはこれを解消する: コピーした瞬間に内容が見える。自動で消える。

## Differentiation

| カテゴリ | 例 | ClipNoticeとの違い |
|---------|-----|------------------|
| クリップボードマネージャー | Maccy, Clipy, Paste | 履歴蓄積+ホットキー呼び出し。能動操作が必要。 |
| **ClipNotice** | — | コピー即時表示 → 3秒後消去。受動型アンビエント通知。履歴不要。 |

## Core Feature (Phase 1 Confirmed)

- クリップボード変化を検知（0.5秒ポーリング）
- 画面左上に付箋UI表示（コピーした文字列）
- 3秒後自動消去
- クリックで即時消去
- 右クリック → 設定 / Quit メニュー

## UI Requirements

- **Dockアイコン**: なし（`.accessory` activation policy）
- **メニューバー**: なし（常駐しない）
- **付箋**: 画面左上フローティングウィンドウ（NSPanel）
- **起動**: ログイン時自動起動（Login Items）

## Architecture

```
AppDelegate
├── ClipboardMonitor
│   ├── Timer 0.5s → NSPasteboard.general.changeCount
│   ├── changeCount変化なし → スキップ
│   └── 変化あり → NSPasteboard.string(forType: .string) → StickyNotePanel.show(text)
│
└── StickyNotePanel (NSPanel subclass)
    ├── level: .floating
    ├── styleMask: .nonactivatingPanel | .fullSizeContentView
    ├── collectionBehavior: .canJoinAllSpaces | .stationary
    ├── position: top-left (visibleFrame.minX + 20, visibleFrame.maxY - height - 20)
    ├── content: NSTextField (最大300文字、wordWrap or clipping)
    ├── auto-dismiss: DispatchWorkItem after 3.0s
    ├── mouseDown → cancel work item, close()
    ├── rightClick → NSMenu ["設定...", "Quit ClipNotice"]
    └── SettingsPanel (singleton)
        ├── fontSize: 8–48pt slider
        ├── textColor: NSColorWell
        ├── backgroundColor: NSColorWell
        ├── wordWrap: checkbox
        └── live preview on change
```

## Tech Stack

| 要素 | 選択 | 理由 |
|------|------|------|
| 言語 | Swift 5.9+ | ネイティブ、AppKit直接利用 |
| UI | AppKit (NSPanel) | floating non-activating panelはAppKit必須 |
| 検知 | NSPasteboard.changeCount ポーリング | publicAPI、追加パーミッション不要 |
| ビルド | Swift Package Manager (swiftc直接) | Xcodeプロジェクト不要、CI簡単 |
| 設定永続化 | UserDefaults | シンプル、OS管理 |

## Distribution Strategy

**選択: Homebrew Formula (swiftc でソースビルド)**

理由: ビルド済みバイナリをダウンロードしないため quarantine 属性が付かない
→ Gatekeeper チェックなし → Apple Developer 認証不要で完全動作

```bash
brew tap tobisako/clipnotice
brew install clipnotice
clipnotice &
```

### Gatekeeper との関係

| 方法 | 仕組み | quarantine | Gatekeeper | notarization |
|------|--------|-----------|-----------|-------------|
| `brew install --cask maccy` | 既成.appダウンロード | あり | **対象** | **必要** |
| `brew install clipnotice` (Formula) | ソースビルド | **なし** | 対象外 | **不要** ✅ |
| GitHub Releases binary | ダウンロード | あり | 対象 | 不要（手動解除可） |

GitHub Releases バイナリの場合: `xattr -dr com.apple.quarantine ./clipnotice` または System Settings → Privacy & Security → "Open Anyway"

## NOT In Scope

- 画像・ファイルコピーの表示
- クリップボード履歴
- App Store配布
- iOS/iPadOS対応
- メニューバー常駐
- 複数モニター対応

## Edge Cases Handled

- 長い文字列 → 最大300文字で切り捨て（`…` 付加）
- 空文字列コピー → 表示しない
- 同じ内容の連続コピー → 表示しない（changeCountで自動検知）
- アプリ起動時の初回changeCount → 初期値として記録、表示しない
- wordWrap OFF → テキスト幅に合わせてパネル横幅自動拡張（画面幅上限）
- wordWrap ON → 固定幅320px、折り返し
- 付箋表示中に新コピー → 古いタイマーキャンセル、新テキスト表示
