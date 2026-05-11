# ClipNotice Windows版 — 設計文書
Generated: 2026-05-11 by tobisako
Last updated: 2026-05-11 (Mac 設計書 大幅変更に追従: ドラッグ移動・dismiss 秒数設定・メニュー寿命2秒延長・カスタム32色ピッカー＋hex入力・設定パネル auto-close・Z-order 保証)
Branch: master (win/ ディレクトリ)

---

## Problem

コピー操作のたびに「正しくコピーできたか？」という認知負荷がある。
確認のためにペーストするか、クリップボードマネージャーのホットキーを押す必要がある。

ClipNotice Windows版はこれを解消する: コピーした瞬間に内容が画面左上に表示される。設定した秒数で自動消去される。

macOS版と機能完全同等を目指したWindows/WinForms移植実装。

---

## Differentiation

| カテゴリ | 例 | ClipNotice Windowsとの違い |
|---------|-----|--------------------------|
| クリップボードマネージャー | Ditto, CopyQ | 履歴蓄積＋ホットキー呼び出し。能動操作が必要。 |
| システム通知 | Windows通知センター | 後から確認できるが、コピー直後に受動で見えない。 |
| **ClipNotice** | — | コピー即時表示 → 設定秒数後消去。受動型アンビエント通知。履歴不要。 |

---

## Core Features (Implemented)

- クリップボード変化を検知（500msポーリング）
- 画面左上に付箋UI表示（コピーした文字列、最大300文字）
- 表示時間後自動消去（デフォルト3秒、0.5〜5秒で設定可能）
- クリックで即時消去
- ドラッグで付箋を移動（位置は次回表示に引き継ぐ）
- 右クリックメニュー → 設定 / Quit
- 付箋消滅後もメニューは2秒間維持（メニュー操作中は付箋が先に消える）
- タスクトレイ常駐（NotifyIcon）→ 設定 / Quit
- 設定: フォントサイズ・文字色・背景色・改行ON/OFF・付箋表示時間・設定パネル自動クローズ秒数
- カスタムカラーピッカー: 32色グリッド + #RRGGBB hex入力
- 設定パネル自動クローズ: 操作のたびにタイマーリセット（2/4/6/8/10秒、デフォルト8秒）
- 設定はWindowsレジストリに永続保存（`HKCU\Software\ClipNotice`）

---

## Architecture

```
Program.cs  (エントリポイント)
└── Application.Run(ClipboardMonitor)   ← ApplicationContext サブクラス

ClipboardMonitor : ApplicationContext
├── Settings.Load()                      ← 起動時にレジストリから設定読込
├── StickyForm _sticky                   ← 付箋ウィンドウ（1インスタンス使い回し）
├── NotifyIcon _tray                     ← タスクトレイ常駐アイコン
│   └── ContextMenuStrip
│       ├── "設定..." → SettingsForm.ShowDialog()（Changed → WordWrap-aware preview）
│       └── "Quit ClipNotice" → ExitThread()
├── ctor で `Clipboard.GetText()` を `_lastText` に seed
└── Timer 500ms → Poll() → 変化あり → _sticky.ShowText(text)

StickyForm : Form
├── FormBorderStyle = None / ShowInTaskbar = false / TopMost = true / Opacity = 0.95
├── Label _label (DockStyle.Fill, Padding=12)
├── 状態: _savedLocation (ドラッグ後位置記憶), _menuOpen (右クリック中フラグ),
│        _dragging, _screenDragStart, _formOriginAtDragStart
│
├── ShowText(string text)
│   ├── Opacity = 0.95（前回不可視化リセット）
│   ├── 300文字超え → 切り捨て＋"…"
│   ├── TextRenderer.MeasureText() (GDI) でウィンドウサイズ動的計算
│   │   ├── WordWrap=true  → 幅 320px 固定（WordBreak）
│   │   └── WordWrap=false → テキスト幅 + 余白（画面幅上限、改行は反映）
│   ├── 位置: _savedLocation ?? Screen.WorkingArea 左上＋20px
│   └── StartDismissTimer() → Show() / BringToFront()
│
├── MouseDown / MouseMove / MouseUp（ドラッグ検出: スクリーン座標差分5px超え）
│   ├── MouseDown: _timer.Stop(), _screenDragStart = Cursor.Position
│   ├── MouseMove: 5px超 → _dragging=true、Location 追従
│   └── MouseUp:
│       ├── 移動なし → Hide() (クリック判定)
│       └── ドラッグあり → _savedLocation = Location, StartDismissTimer()
│
├── ContextMenuStrip (右クリック)
│   ├── Opened → _menuOpen=true, _timer.Stop()
│   ├── Closed → _menuOpen=false; Opacity==0 なら復帰して Hide()
│   ├── "設定..." → using SettingsForm.ShowDialog(this)
│   │              Changed → WordWrap-aware preview text を ShowText
│   └── "Quit ClipNotice" → Application.Exit()
│
└── StartDismissTimer()
    └── Settings.DismissMs 経過 →
        ├── _menuOpen==false → Hide()
        └── _menuOpen==true  → Opacity=0 + 2秒後 Hide()
                                （メニュー操作中は付箋が先に消える）

SettingsForm : Form (FixedDialog 360x360, TopMost=true)
├── public event Action? Changed         ← プレビュー再描画用
├── ColorPickerForm _picker              ← 子ピッカー（Owner=this+TopMost で z-order 保証）
├── System.Windows.Forms.Timer _autoClose
│
├── 各コントロール:
│   ├── TrackBar 文字サイズ (8〜48pt)
│   ├── Button 文字色 (MouseDown → OpenPicker(_btnTc, "文字の色", ...))
│   ├── Button 背景色 (MouseDown → OpenPicker(_btnBg, "背景の色", ...))
│   ├── CheckBox 改行する
│   ├── Label セクション見出し「表示時間」(GrayText)
│   ├── TrackBar 付箋 dismiss 秒数 (1〜10 = 0.5〜5秒、デフォルト3秒)
│   └── TrackBar 設定 auto-close 秒数 (1〜5 = 2/4/6/8/10秒、デフォルト8秒)
│
├── 各イベントハンドラ末尾で ResetAutoClose() →
│   操作のたび自動クローズタイマー延長
│
├── OpenPicker(anchor, title, current, onChange)
│   ├── _picker.Visible なら Hide() のみ（トグル閉じ）
│   ├── _autoClose.Stop() （ピッカー表示中はガード）
│   └── _picker.ShowPicker(this, current, title) → BringToFront()
│
├── _autoClose.Tick:
│   ├── _picker.Visible → return（ガード）
│   └── 否 → Close()
│
└── OnFormClosing:
    ├── _isPerformingClose = true
    ├── _picker.Hide() → onClose は scheduleAutoClose しない
    └── _autoClose.Stop()

ColorPickerForm : Form, IMessageFilter (新規, FormBorderStyle.None, TopMost=true)
├── Mac の ColorPickerPopover.swift mirror
├── 32色 4×8 グリッド (Mac と同色配列、24x24px)
├── 上部タイトルラベル ("文字の色" / "背景の色")
├── 下部 hex 入力 TextBox + "適用" Button (Enter 適用)
├── ShowWithoutActivation=true（フォーカス奪取しない）
│
├── ShowPicker(Form anchor, Color current, string title)
│   ├── 位置: anchor.Right + 8 (画面右端越えなら左側へフォールバック)
│   ├── Owner = anchor → z-order 自動維持
│   └── Show() → InstallFilter()（Application.AddMessageFilter）
│
├── PreFilterMessage(WM_LBUTTONDOWN/WM_RBUTTONDOWN/WM_NC*BUTTONDOWN)
│   └── Cursor.Position が Form 領域外 → Hide()
│
├── Hide() override
│   └── RemoveFilter() → base.Hide() → OnClose?.Invoke()
│
└── 色選択:
    ├── swatch Click → onChange(c) + hex フィールド更新
    └── 適用 Button / Enter → hex パース → onChange(c)

Settings (static class)
├── デフォルト: FontSize=13pt / TextColor=Black / BgColor=LightYellow / WordWrap=true
│              DismissMs=3000 / SettingsAutoCloseSecs=8
├── SettingsAutoCloseSecs setter: {2,4,6,8,10} 以外は 8 にクランプ
├── Load() → HKCU\Software\ClipNotice から読込
└── Save() → setter で自動呼出
```

### Z-order 保証（必須仕様）

**ピッカー ＞ 設定 ＞ 付箋** — Mac の `.popUpMenu`(101) > `.modalPanel`(8) > `.floating`(3) と等価。

| ウィンドウ | クラス | TopMost | Owner |
|-----------|--------|---------|-------|
| カラーピッカー | `ColorPickerForm` | true | `SettingsForm` |
| 設定パネル | `SettingsForm` | true | `StickyForm`（StickyForm.ContextMenuStrip 経由時のみ） |
| 付箋 | `StickyForm` | true | — |

**実装方針**: WinForms には NSPanel level に相当する数値レベルがないため、`Owner` プロパティのチェーンで z-order を保証する。Owner 関係にあるフォームは常に Owner 直上に表示される。全 Form を `TopMost=true` にすることで他アプリ上に常駐。

`SettingsForm.ShowDialog(this)` を `StickyForm` から呼ぶことで modal 化（付箋クリック不能） + Owner 関係成立。`ColorPickerForm.Owner = SettingsForm` をピッカー表示時に設定 → ピッカー必ず最前面。

### Click-outside 検知

`ColorPickerForm` は `IMessageFilter.PreFilterMessage` で `WM_LBUTTONDOWN` / `WM_RBUTTONDOWN` / `WM_NCLBUTTONDOWN` / `WM_NCRBUTTONDOWN` をフックし、`Cursor.Position` がピッカー領域外なら `Hide()`。Mac の `NSEvent.addLocalMonitorForEvents` の equivalent。

`Show()` 時 `Application.AddMessageFilter(this)`、`Hide()` 時 `Application.RemoveMessageFilter(this)`。

### Drag-to-Move

- `MouseDown`: `_screenDragStart = Cursor.Position`（スクリーン座標）でドラッグ開始記録、タイマーキャンセル
- `MouseMove`: スクリーン座標差分で移動量計算、5px超で `_dragging=true` 確定、`Location` 追従
- `MouseUp`:
  - 移動なし → `Hide()`（クリック判定）
  - ドラッグあり → `_savedLocation = Location`、`StartDismissTimer()`
- `_savedLocation` があれば次回 `ShowText()` でその位置に表示

**注意**: `MouseEventArgs.Location` はコントロール相対座標（フォーム移動中は変動）。`Cursor.Position`（スクリーン絶対座標）を使うことで移動量を正確に取得。

### Context Menu Lifetime

右クリックメニュー（設定 / Quit）と付箋の消滅タイミング:

1. dismiss タイマー発火、メニューが**閉じている** → `Hide()` 通常消滅
2. dismiss タイマー発火、メニューが**開いている**:
   - `Opacity = 0`（付箋を不可視化）
   - 2秒後の追加 Timer で `Opacity` 復帰 + `Hide()`
3. ユーザーがメニューを手動で閉じた場合（`_menuOpen=false`、`Opacity==0`）:
   - `Opacity` 復帰 + `Hide()`

### Color Picker Lifetime

設定パネルの自動クローズタイマーとカラーピッカーの関係:

1. 色ボタン MouseDown → `OpenPicker()`
   - ピッカー既に表示中 → `_picker.Hide()` のみ（トグル閉じ）
   - `_autoClose.Stop()`
   - `_picker.ShowPicker(this, current, title)` → ピッカー表示
2. ピッカー表示中に `_autoClose.Tick` 発火:
   - `_picker.Visible == true` → **return（スキップ）**
3. ユーザーがピッカーを閉じる（外側クリック）:
   - `PreFilterMessage` 検知 → `Hide()` → `OnClose?.Invoke()`
   - `_isPerformingClose==false` → `Activate()` + `ResetAutoClose()`（タイマー再開）
4. X ボタンで設定を強制クローズ:
   - `OnFormClosing` 呼出 → `_isPerformingClose = true`
   - `_picker.Hide()` → `OnClose` で `_isPerformingClose==true` → 何もしない
   - `_autoClose.Stop()`

---

## Tech Stack

| 要素 | 選択 | 理由 |
|------|------|------|
| 言語 | C# 13 (.NET 9) | WinForms公式サポート、型安全、null許容有効 |
| UI | Windows Forms (WinForms) | Win32ネイティブ、TopMost/Owner制御が容易 |
| クリップボード検知 | `System.Windows.Forms.Clipboard` + 500msポーリング | 追加パーミッション不要 |
| Click-outside | `IMessageFilter` + `Cursor.Position` | NSEvent.addLocalMonitorForEvents 相当 |
| Z-order | `Form.Owner` chain + `TopMost=true` | NSPanel level 相当を idiom で実現 |
| 設定永続化 | `Microsoft.Win32.Registry` (HKCU) | Windowsネイティブ、インストーラー不要 |
| ターゲット | net9.0-windows / win-x64 | WinForms 必須TFM |
| 出力形式 | PublishSingleFile=true / SelfContained=true | .NET 9ランタイム不要の単一EXE |

---

## Settings Persistence

すべて `HKCU\Software\ClipNotice` レジストリキーに保存:

| キー | 型 | デフォルト |
|------|-----|---------|
| `FontSize` | REG_DWORD | 13 |
| `TextColorArgb` | REG_DWORD | 0 (Black) |
| `BgColorArgb` | REG_DWORD | LightYellow |
| `WordWrap` | REG_DWORD | 1 (true) |
| `DismissMs` | REG_DWORD | 3000 |
| `SettingsAutoCloseSecs` | REG_DWORD | 8 |

---

## Distribution

### GitHub Actions による自動ビルド (`.github/workflows/build-windows.yml`)

| 項目 | 設定 |
|------|------|
| ランナー | `windows-latest` (≒ `windows-2025`、2026-05-12 以降は `windows-2025-vs2026` にリダイレクト) |
| トリガー | `v*` タグ push または `workflow_dispatch` |
| .NET バージョン | 9.0.x |
| ビルドコマンド | `dotnet publish -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true` |
| 成果物 | `clipnotice.exe` (約 50MB、ランタイム同梱) |
| アーティファクト | `clipnotice-windows` (GitHub Actions Artifact) |
| リリース添付 | タグ時に `softprops/action-gh-release` でリリースアセットに添付 |

### macOS版 (Homebrew Formula) との比較

| 項目 | macOS版 | Windows版 |
|------|---------|----------|
| 配布形式 | brew Formula (ソースビルド) | 単一EXE (GitHub Releases) |
| ランタイム | Swift標準ライブラリ同梱 | .NET 9 Runtime 同梱（self-contained） |
| 署名/公証 | 不要 (Formula経由ソースビルド) | 未対応 (SmartScreen警告が出る可能性あり) |
| 自動起動 | Login Items (手動設定) | 未実装 |

---

## Current Gaps（既知の欠陥・未実装）

### 1. 自動起動（スタートアップ）未対応
- `HKCU\Software\Microsoft\Windows\CurrentVersion\Run` への登録未実装
- `Win+R` → `shell:startup` でショートカット手動配置が必要

### 2. SmartScreen 警告
- EXE 未署名のため初回実行時に SmartScreen 警告
- 「詳細情報」→「実行」で回避可能
- コード署名証明書 / Microsoft Store 申請 未対応

### 3. 複数モニター未対応
- `Screen.PrimaryScreen` のみ参照、マルチモニター環境では主ディスプレイのみ

### 4. テキスト以外無視
- 画像・ファイル・リッチテキストはスキップ（`Clipboard.ContainsText()` のみ）

### 5. カスタムトレイアイコンなし
- `SystemIcons.Application` 流用、ClipNotice 固有アイコン未作成

---

## NOT in Scope (Phase 1)

- クリップボード履歴
- 画像・ファイルコピーの表示
- 複数モニター対応
- 自動起動設定UI
- App Store / Microsoft Store 配布
- コード署名

---

## Edge Cases handled

| ケース | 対応 |
|--------|------|
| 他アプリがクリップボードをロック中 | `try-catch` で例外を飲み込み、次のTickまでスキップ |
| 空文字列コピー | `string.IsNullOrEmpty()` チェックでスキップ |
| 同じ内容の連続コピー | `_lastText` との比較でスキップ |
| 300文字超えの長い文字列 | 300文字で切り捨て＋"…" を付与して表示 |
| 改行を含むテキスト | `TextRenderer.MeasureText` で改行込みサイズ計算（WordWrap オフでも `\n` 反映） |
| 付箋が画面幅を超える長い1行テキスト | `Screen.PrimaryScreen.WorkingArea.Width - Mar*2` を上限としてクリップ |
| 付箋最小サイズ | `Math.Max(w, 80)` / `Math.Max(h, 40)` で最小80x40px保証 |
| SettingsForm を開いている間に付箋タイマー切れ | 独立した `Timer` インスタンスで干渉なし |
| 起動直後の初回クリップボード内容 | ctor で `Clipboard.GetText()` を `_lastText` に seed → 起動前コピー済み内容は非表示 |
| プレビュー時 WordWrap OFF | 改行を含まない単行テキスト「プレビュー Preview  ABC abc 123 あいう」を使用 |
| ピッカー表示中の auto-close 発火 | `_picker.Visible` ガードで設定パネルは閉じない |
| ドラッグ中に dismiss タイマー発火 | MouseDown で _timer.Stop() 済み → MouseUp 後に再開 |
| 設定パネルが付箋より手前に表示されない | TopMost=true + ShowDialog(StickyForm) で確実に前面 |
| ピッカーが画面右端を越える | `anchor.Right + 8 + Width > Screen.Right` 時は左側へフォールバック |

---

## 実装履歴 (主要修正)

| 修正 | 内容 | 影響 |
|------|------|------|
| `[STAThread]` を Main に付与 | top-level statements は STA 自動付与なし → `Clipboard.GetText()` が `ThreadStateException` で常時失敗 | クリップボード非反応バグ修正 |
| `TextRenderer.MeasureText` 切替 | `Graphics.MeasureString` (GDI+) と Label 描画 (GDI) のメトリクス差で右端文字切れ | 末尾切れ解消 |
| Settings ライブプレビュー | `Changed` イベント追加、StickyForm/NotifyIcon が購読 | macOS版と体感同等 |
| `_lastText` を ctor で seed | 起動直後に既存クリップボード内容を表示してしまっていた | 起動時ノイズ解消 |
| `NotifyIcon` 追加 | 付箋消滅後の設定/Quit 入口確保 | トレイから常時アクセス可能 |
| SingleLine flag 削除 | WordWrap=OFF 時 `\n` が無視され1行表示 | 複数行クリップボードの改行表示 |
| ドラッグ移動 + 位置記憶 | `_savedLocation` 導入、Mouse* イベントで実装 | Mac 同等のドラッグ操作 |
| dismiss 秒数スライダ | 0.5〜5秒、`Settings.DismissMs` 永続化 | Mac 同等のカスタマイズ |
| メニュー寿命2秒延長 | dismiss 発火時メニュー開いてれば Opacity=0 + 2秒後 Hide | メニュー操作中の付箋消失バグ解消 |
| カスタム ColorPickerForm | `IMessageFilter` で click-outside、32色グリッド + hex 入力、トグル開閉、mouseDown起動、Owner+TopMost で z-order 保証 | Mac の ColorPickerPopover.swift と機能完全同等 |
| 設定パネル auto-close | `_autoClose` Timer、操作のたびリセット、ピッカー表示中はガード | Mac の `scheduleAutoClose` と等価 |
| 「表示時間」セクション再設計 | 付箋 / 設定 の二段スライダ、セクションヘッダ追加 | Mac と UI 同形 |
| プレビュー WordWrap aware | OFF 時は `\n` なしテキスト | Mac と挙動同形 |
