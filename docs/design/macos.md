# ClipNotice — macOS Design Document

Generated: 2026-05-10 by tobisako (/office-hours Builder Mode)
Last updated: 2026-05-11 (color picker toggle / mouseDown / timer reset / preview fix)

## Problem

コピー操作のたびに「正しくコピーできたか？」という認知負荷がある。
確認のためにペーストするか、クリップボードマネージャーのホットキーを押す必要がある。

ClipNoticeはこれを解消する: コピーした瞬間に内容が見える。自動で消える。

## Differentiation

| カテゴリ | 例 | ClipNoticeとの違い |
|---------|-----|------------------|
| クリップボードマネージャー | Maccy, Clipy, Paste | 履歴蓄積+ホットキー呼び出し。能動操作が必要。 |
| **ClipNotice** | — | コピー即時表示 → 3秒後消去。受動型アンビエント通知。履歴不要。 |

## Core Feature (Implemented)

- クリップボード変化を検知（0.5秒ポーリング）
- 画面左上に付箋UI表示（コピーした文字列）
- 表示時間後自動消去（デフォルト3秒、0.5〜5秒で設定可能）
- クリックで即時消去
- ドラッグで付箋を移動（位置は次回表示に引き継ぐ）
- 右クリック → 設定 / Quit メニュー
- 付箋消滅後もメニューは2秒間維持（メニュー操作中は付箋が先に消える）

## UI Requirements

- **Dockアイコン**: なし（`.accessory` activation policy）
- **メニューバー**: なし（常駐しない）
- **付箋**: 画面左上フローティングウィンドウ（NSPanel）
- **起動**: ログイン時自動起動（Login Items）— アプリ内未実装。ユーザーが手動でシステム設定 → 一般 → ログイン項目に追加する

## Architecture

```
AppDelegate
├── ClipboardMonitor
│   ├── Timer 0.5s → NSPasteboard.general.changeCount
│   ├── changeCount変化なし → スキップ
│   └── 変化あり → NSPasteboard.string(forType: .string) → StickyNotePanel.show(text)
│
└── StickyNotePanel (NSPanel, NSMenuDelegate, NSWindowDelegate)
    ├── level: .floating
    ├── styleMask: .nonactivatingPanel | .fullSizeContentView
    ├── collectionBehavior: .canJoinAllSpaces | .stationary
    ├── isMovableByWindowBackground: true  ← AppKitがドラッグ処理
    │
    ├── show(text)
    │   ├── alphaValue = 1, ignoresMouseEvents = false  ← 前回の不可視状態をリセット
    │   ├── カスタム位置 or デフォルト左上配置
    │   └── scheduleDismiss()
    │
    ├── scheduleDismiss()
    │   └── DispatchWorkItem after Settings.dismissDelay
    │       ├── menuIsOpen == false → close()
    │       └── menuIsOpen == true  → alphaValue=0, ignoresMouseEvents=true
    │                                  + cancelTracking() after 2s
    │
    ├── mouseDown → dismissWorkItem.cancel(), mouseDownReceived=true, wasDrag=false
    ├── windowDidMove (NSWindowDelegate) → mouseDownReceived==true なら wasDrag=true, customOrigin=frame.origin
    ├── mouseUp
    │   ├── wasDrag == true  → scheduleDismiss()  (ドラッグ判定)
    │   └── wasDrag == false → close()             (クリック判定)
    │
    ├── NSMenuDelegate
    │   ├── menuWillOpen → menuIsOpen = true
    │   └── menuDidClose → menuIsOpen = false
    │                       alphaValue == 0 なら dismissWorkItem.cancel(), close()
    │
    ├── rightClick → NSMenu ["設定...", "Quit ClipNotice"]
    │
    └── SettingsPanel (singleton, level: .modalPanel = 8)
        ├── fontSize: 8–48pt slider
        ├── textColor: 色ボタン → ColorPickerPanel (カスタム32色 + hex入力)
        ├── backgroundColor: 色ボタン → ColorPickerPanel
        ├── wordWrap: checkbox
        ├── dismissDelay: 0.5–5秒 スライダー (0.5秒刻み、デフォルト3秒)
        ├── settingsAutoCloseSecs: 2/4/6/8/10秒 スライダー (デフォルト8秒)
        ├── live preview on change
        │
        ├── open()
        │   └── makeKeyAndOrderFront → loadFromSettings → scheduleAutoClose
        │
        ├── 操作時タイマーリセット: fontChanged / wordWrapChanged / dismissChanged / autoCloseChanged
        │   └── 各ハンドラ末尾で scheduleAutoClose() → スライダー操作・チェックボックス変更でタイマー延長
        │
        ├── timerClose() ← scheduleAutoClose が登録するセレクタ
        │   ├── colorPicker.isVisible == true → return (カラーピッカー中はスキップ)
        │   └── colorPicker.isVisible == false → close()
        │
        ├── close() ← X ボタン / プログラム的クローズ
        │   ├── isPerformingClose = true
        │   ├── colorPicker.hide() (先にピッカーを閉じる)
        │   ├── isPerformingClose = false
        │   └── super.close()
        │
        └── ColorPickerPanel (NSPanel, level: .popUpMenu = 101)
            ├── 設定ウィンドウの右隣に表示 (anchor.frame.maxX + 8)
            ├── 上部タイトルラベル: "文字の色" / "背景の色"（show()のtitle引数で切替）
            ├── 色ボタンは sendAction(on: .leftMouseDown) → mouseDown 瞬間に開く
            ├── 色ボタン再押し時: isVisible == true → hide() のみ（トグル閉じ）
            ├── show(positionedRightOf:current:title:) → timerClose キャンセル + orderFront + clickMonitor 開始
            ├── hide() → clickMonitor 停止 + orderOut + onClose?()
            ├── onClose callback → isPerformingClose == false → scheduleAutoClose
            └── click-outside → NSEvent.addLocalMonitorForEvents で検知 → hide()
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

## Settings Persistence

すべて `UserDefaults.standard` に保存:

| キー | 型 | デフォルト |
|------|-----|---------|
| `fontSize` | Double | 13 |
| `textColor` | Data (NSColor archive) | black |
| `backgroundColor` | Data (NSColor archive) | 薄黄色 |
| `wordWrap` | Bool | true |
| `dismissDelay` | Double | 3.0 |
| `settingsAutoCloseSecs` | Int | 8 |

## Drag-to-Move

- `isMovableByWindowBackground = true` → AppKit が window drag を処理
- `mouseDown`: `dismissWorkItem.cancel()`, `mouseDownReceived = true`, `wasDrag = false`
- `windowDidMove` (NSWindowDelegate): `mouseDownReceived == true` なら `wasDrag = true`, `customOrigin = frame.origin`
- `mouseUp`:
  - `wasDrag == true`  → ドラッグ判定 → `scheduleDismiss()`
  - `wasDrag == false` → クリック判定 → `close()`
- `customOrigin` があれば次回 `show()` でその位置に表示

**注意**: `isMovableByWindowBackground` 使用時、ドラッグ中の座標は AppKit が管理するため
`locationInWindow` / `NSEvent.mouseLocation` では正確なドラッグ量を取れない。
代わりに `windowDidMove` デリゲートでドラッグを検知する。

## Context Menu Lifetime

右クリックメニュー（設定 / Quit）と付箋の消滅タイミング:

1. dismiss タイマー発火、メニューが**閉じている** → `close()` 通常消滅
2. dismiss タイマー発火、メニューが**開いている**:
   - `alphaValue = 0`（付箋を不可視化）
   - `ignoresMouseEvents = true`（クリック透過）
   - 2秒後に `cancelTracking()` → メニューが閉じる → `menuDidClose` → `close()`
3. ユーザーがメニューを手動で閉じた場合（`menuDidClose`、`alphaValue == 0`）:
   - `dismissWorkItem.cancel()`（cancelTracking予約をキャンセル）
   - 即座に `close()`

## Window Z-Order 保証（必須仕様）

**ピッカー ＞ 設定 ＞ 付箋** — この順番で必ず重なる。ピッカーが最前面。

| ウィンドウ | クラス | level | 数値 |
|-----------|--------|-------|------|
| カラーピッカー | `ColorPickerPanel` (NSPanel) | `.popUpMenu` | 101 |
| 設定パネル | `SettingsPanel` (NSWindow) | `.modalPanel` | 8 |
| 付箋 | `StickyNotePanel` (NSPanel) | `.floating` | 3 |

**実装方針**: NSPopover は内部ウィンドウ(`_NSPopoverWindow`)の level を AppKit が上書きするため、
`window.level` 設定も `addChildWindow` も無効。`NSPanel` に置き換え `level = .popUpMenu` を直接指定することで保証する。

## Color Picker Lifetime

設定パネルの自動クローズタイマーとカラーピッカーの関係:

1. 色ボタン押下（mouseDown）→ `openTextColorPicker()` / `openBgColorPicker()`
   - ピッカーが既に表示中 → `colorPicker.hide()` のみ（トグル閉じ）、以下スキップ
   - `timerClose` セレクタのペンディングリクエストをキャンセル
   - `colorPicker.show(positionedRightOf: self, current:, title: "文字の色"/"背景の色")` でピッカー表示
   - ピッカー上部にタイトルラベル（「文字の色」または「背景の色」）表示
   - `NSEvent.addLocalMonitorForEvents` でclick-outside監視開始
2. ピッカーが開いている間に自動クローズタイマーが発火した場合:
   - `timerClose()` 呼ばれる → `colorPicker.isVisible == true` → **return（スキップ）**
3. ユーザーがピッカーを閉じる（外側クリック）:
   - click-outside検知 → `colorPicker.hide()` → `onClose?()` コールバック
   - `isPerformingClose == false` → `scheduleAutoClose()` でタイマー再開
   - 設定パネルが前面に出る（`makeKeyAndOrderFront`）
4. X ボタンで設定を強制クローズ:
   - `close()` 直接呼ばれる → `isPerformingClose = true`
   - `colorPicker.hide()` → `onClose?()` コールバック → `isPerformingClose == true` → スケジュールしない
   - `super.close()`

**重要**: `timerClose` と `close` は別セレクタ。`timerClose` のみカラーピッカー中をガード。X ボタンは `close()` を直接呼ぶので常にクローズされる。

## Edge Cases Handled

- 長い文字列 → 最大300文字で切り捨て（`…` 付加）
- 空文字列コピー → 表示しない
- 同じ内容の連続コピー → 表示しない（changeCountで自動検知）
- アプリ起動時の初回changeCount → 初期値として記録、表示しない
- wordWrap OFF → テキスト幅に合わせてパネル横幅自動拡張（画面幅上限）
- wordWrap ON → 固定幅320px、折り返し
- 設定プレビュー時のwordWrap OFF → `\n` を含まない1行テキストを使用（`lineBreakMode`は実改行文字を制御しないため）
- 付箋表示中に新コピー → 古いタイマーキャンセル、新テキスト表示、alphaValue/ignoresMouseEvents リセット
- ドラッグ中に dismiss タイマー発火 → mouseDown でキャンセル済み → 問題なし
- 設定パネルが付箋より手前に表示されない → level: .modalPanel（.floatingより上位）で解決
