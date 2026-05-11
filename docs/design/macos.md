# ClipNotice — macOS Design Document

Generated: 2026-05-10 by tobisako (/office-hours Builder Mode)
Last updated: 2026-05-11

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
- **起動**: ログイン時自動起動（Login Items）

## Architecture

```
AppDelegate
├── ClipboardMonitor
│   ├── Timer 0.5s → NSPasteboard.general.changeCount
│   ├── changeCount変化なし → スキップ
│   └── 変化あり → NSPasteboard.string(forType: .string) → StickyNotePanel.show(text)
│
└── StickyNotePanel (NSPanel, NSMenuDelegate)
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
    ├── mouseDown → dismissWorkItem.cancel(), dragStartLocation = NSEvent.mouseLocation
    ├── mouseUp
    │   ├── 移動量 < 5px → close()  (クリック判定)
    │   └── 移動量 ≥ 5px → customOrigin = frame.origin, scheduleDismiss()  (ドラッグ)
    │
    ├── NSMenuDelegate
    │   ├── menuWillOpen → menuIsOpen = true
    │   └── menuDidClose → menuIsOpen = false
    │                       alphaValue == 0 なら dismissWorkItem.cancel(), close()
    │
    ├── rightClick → NSMenu ["設定...", "Quit ClipNotice"]
    │
    └── SettingsPanel (singleton, level: .modalPanel)
        ├── fontSize: 8–48pt slider
        ├── textColor: 色ボタン → ColorPickerPopover (カスタム32色 + hex入力)
        ├── backgroundColor: 色ボタン → ColorPickerPopover
        ├── wordWrap: checkbox
        ├── dismissDelay: 0.5–5秒 スライダー (0.5秒刻み)
        ├── settingsAutoCloseSecs: 2/4/6/8/10秒 スライダー (デフォルト8秒)
        ├── live preview on change
        │
        ├── open()
        │   └── makeKeyAndOrderFront → loadFromSettings → scheduleAutoClose
        │
        ├── timerClose() ← scheduleAutoClose が登録するセレクタ
        │   ├── colorPicker.isShown == true → return (カラーピッカー中はスキップ)
        │   └── colorPicker.isShown == false → close()
        │
        ├── close() ← X ボタン / プログラム的クローズ
        │   ├── colorPicker.close() (アンカー表示中に閉じる必要あり)
        │   └── super.close()
        │
        └── ColorPickerPopover (NSPopover, child window of SettingsPanel)
            ├── 設定ウィンドウの右隣に表示 (preferredEdge: .maxX, anchor: contentView)
            ├── popoverWillShow → timerClose キャンセル (タイマー一時停止)
            ├── popoverDidShow → addChildWindow(.above) で設定パネルより前面を保証
            ├── popoverWillClose → removeChildWindow
            └── popoverDidClose → scheduleAutoClose (タイマー再開)
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
- `mouseDown`: `dragStartLocation = NSEvent.mouseLocation`（スクリーン座標）でドラッグ開始記録、タイマーキャンセル
- `mouseUp`: スクリーン座標で移動量を計算
  - < 5px → クリック判定 → close()
  - ≥ 5px → ドラッグ判定 → `customOrigin = frame.origin` 保存、scheduleDismiss()
- `customOrigin` があれば次回 `show()` でその位置に表示

**注意**: `locationInWindow` はウィンドウ相対座標のため、isMovableByWindowBackground と組み合わせると常にほぼ0になり誤判定する。`NSEvent.mouseLocation`（スクリーン絶対座標）を使う。

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

## Color Picker Lifetime

設定パネルの自動クローズタイマーとカラーピッカーの関係:

1. 色ボタンをクリック → `openTextColorPicker()` / `openBgColorPicker()`
   - `timerClose` セレクタのペンディングリクエストをキャンセル
   - `colorPicker.show()` でピッカー表示
2. `popoverWillShow` → `timerClose` 追加キャンセル（タイマー完全停止）
3. `popoverDidShow` → `addChildWindow(pickerWindow, ordered: .above)` で設定パネルより前面を保証
   （`window.level` 設定は NSPopover 内部ウィンドウでは AppKit に上書きされるため無効）
4. ピッカーが開いている間に自動クローズタイマーが発火した場合:
   - `timerClose()` 呼ばれる → `colorPicker.isShown == true` → **return（スキップ）**
5. ユーザーがピッカーを閉じる（外側クリック / Escape）:
   - `popoverDidClose` → `scheduleAutoClose()` でタイマー再開
   - 設定パネルが前面に出る（`makeKeyAndOrderFront`）
6. X ボタンで設定を強制クローズ:
   - `close()` 直接呼ばれる → `isShown` チェックなし → ピッカー→設定 両方クローズ

**重要**: `timerClose` と `close` は別セレクタ。`timerClose` のみカラーピッカー中をガード。X ボタンは `close()` を直接呼ぶので常にクローズされる。

## Edge Cases Handled

- 長い文字列 → 最大300文字で切り捨て（`…` 付加）
- 空文字列コピー → 表示しない
- 同じ内容の連続コピー → 表示しない（changeCountで自動検知）
- アプリ起動時の初回changeCount → 初期値として記録、表示しない
- wordWrap OFF → テキスト幅に合わせてパネル横幅自動拡張（画面幅上限）
- wordWrap ON → 固定幅320px、折り返し
- 付箋表示中に新コピー → 古いタイマーキャンセル、新テキスト表示、alphaValue/ignoresMouseEvents リセット
- ドラッグ中に dismiss タイマー発火 → mouseDown でキャンセル済み → 問題なし
- 設定パネルが付箋より手前に表示されない → level: .modalPanel（.floatingより上位）で解決
