# ClipNotice Windows版 — 設計文書
Generated: 2026-05-11 by tobisako
Branch: master (win/ ディレクトリ)

---

## Problem

コピー操作のたびに「正しくコピーできたか？」という認知負荷がある。
確認のためにペーストするか、クリップボードマネージャーのホットキーを押す必要がある。

ClipNotice Windows版はこれを解消する: コピーした瞬間に内容が画面左上に表示される。3秒後に自動消去される。

macOS版と同一のコアコンセプトをWindows/WinFormsで実現した移植実装。

---

## Differentiation

| カテゴリ | 例 | ClipNotice Windowsとの違い |
|---------|-----|--------------------------|
| クリップボードマネージャー | Ditto, CopyQ | 履歴蓄積＋ホットキー呼び出し。能動操作が必要。 |
| システム通知 | Windows通知センター | 後から確認できるが、コピー直後に受動で見えない。 |
| **ClipNotice** | — | コピー即時表示 → 3秒後消去。受動型アンビエント通知。履歴不要。 |

---

## Core Features (Phase 1 実装済み)

- クリップボード変化を検知（500msポーリング）
- 画面左上に付箋UI表示（コピーした文字列、最大300文字）
- 3秒後自動消去
- クリックで即時消去
- 右クリックメニュー → 設定ダイアログ / Quit
- 設定ダイアログ: フォントサイズ（8〜48pt）・文字色・背景色・改行ON/OFF
- 設定はWindowsレジストリに永続保存（`HKCU\Software\ClipNotice`）

---

## Architecture

```
Program.cs  (エントリポイント)
└── Application.Run(ClipboardMonitor)   ← ApplicationContext サブクラス

ClipboardMonitor : ApplicationContext
├── Settings.Load()                      ← 起動時にレジストリから設定読込
├── StickyForm _sticky                   ← 付箋ウィンドウ（1インスタンス使い回し）
└── Timer 500ms
    └── Poll()
        ├── Clipboard.ContainsText() → false → スキップ
        ├── Clipboard.GetText() == _lastText → スキップ
        └── 変化あり → _sticky.ShowText(text)

StickyForm : Form
├── FormBorderStyle = None               ← タイトルバーなし
├── ShowInTaskbar = false                ← タスクバー非表示
├── TopMost = true                       ← 最前面
├── Opacity = 0.95                       ← 半透明
├── Label _label (DockStyle.Fill)
├── ContextMenuStrip
│   ├── "設定..." → new SettingsForm().ShowDialog()
│   └── "Quit ClipNotice" → Application.Exit()
└── ShowText(string text)
    ├── 300文字超え → 切り捨て＋"…"
    ├── Graphics.MeasureString() でウィンドウサイズを動的計算
    │   ├── WordWrap=true  → 幅 320px 固定
    │   └── WordWrap=false → テキスト幅に追従（画面幅を超えない）
    ├── 位置: Screen.PrimaryScreen.WorkingArea の左上＋20pxマージン
    ├── Timer 3000ms → Hide()
    └── Show() + BringToFront()

SettingsForm : Form (FixedDialog, 340x230)
├── TrackBar: FontSize (8〜48pt) → Settings.FontSize に即時反映
├── Button: 文字色 → ColorDialog → Settings.TextColor
├── Button: 背景色 → ColorDialog → Settings.BgColor
└── CheckBox: 改行する → Settings.WordWrap

Settings (static class)
├── デフォルト: FontSize=13pt / TextColor=Black / BgColor=LightYellow / WordWrap=true
├── Load() → HKCU\Software\ClipNotice から REG_DWORD で読込
└── Save() → プロパティ変更のたびに自動保存 (setter で呼出)
```

### データフロー

```
[Windows Clipboard]
       │
       │ 500ms poll (System.Windows.Forms.Timer)
       ▼
 ClipboardMonitor.Poll()
       │ テキスト変化検知
       ▼
 StickyForm.ShowText(text)
       │
       ├─ Settings 読込 (FontSize / TextColor / BgColor / WordWrap)
       ├─ Graphics.MeasureString() でサイズ算出
       ├─ 位置計算 (WorkingArea 左上)
       │
       ▼
 StickyForm.Show() / BringToFront()
       │
       │ 3秒後 or クリック
       ▼
 StickyForm.Hide()
```

---

## Tech Stack

| 要素 | 選択 | 理由 |
|------|------|------|
| 言語 | C# 13 (.NET 9) | WinForms公式サポート、型安全、null許容有効 |
| UI | Windows Forms (WinForms) | Win32ネイティブ、TopMost/ShowInTaskbar制御が容易 |
| クリップボード検知 | `System.Windows.Forms.Clipboard` + 500msポーリング | 追加パーミッション不要、シンプル |
| 設定永続化 | `Microsoft.Win32.Registry` (HKCU) | Windowsネイティブ、インストーラー不要 |
| ターゲット | net9.0-windows / win-x64 | WinForms利用に必要なTFM |
| 出力形式 | PublishSingleFile=true / SelfContained=false | .NET 9ランタイム別途必要だが単一EXEで配布 |

---

## Distribution

### GitHub Actions による自動ビルド (`.github/workflows/build-windows.yml`)

| 項目 | 設定 |
|------|------|
| ランナー | `windows-latest` |
| トリガー | `v*` タグ push または `workflow_dispatch` |
| .NET バージョン | 9.0.x |
| ビルドコマンド | `dotnet publish -c Release -r win-x64 --self-contained false -p:PublishSingleFile=true` |
| 成果物 | `win/publish/clipnotice.exe` |
| アーティファクト | `clipnotice-windows` (GitHub Actions Artifact) |
| リリース添付 | タグ時に `softprops/action-gh-release` でリリースアセットに添付 |

### 配布方式の特性

```
SelfContained=false + PublishSingleFile=true
├── EXEファイル1本で配布可能
├── ランタイム依存: .NET 9 Desktop Runtime が実行マシンに必要
│   → インストールURL: https://dotnet.microsoft.com/download/dotnet/9.0
└── EXEサイズ: 小 (ランタイム非同梱)
```

**macOS版 (Homebrew Formula) との比較:**

| 項目 | macOS版 | Windows版 |
|------|---------|----------|
| 配布形式 | brew Formula (ソースビルド) | 単一EXE (GitHub Releases) |
| ランタイム | Swift標準ライブラリ同梱 | .NET 9 Runtime 別途必要 |
| 署名/公証 | 不要 (Formula経由ソースビルド) | 未対応 (SmartScreen警告が出る可能性あり) |
| 自動起動 | Login Items (手動設定) | 未実装 |

---

## Current Gaps（既知の欠陥・未実装）

### 1. システムトレイアイコンなし
- macOS版も Dockアイコンなしだが、Windows では通常トレイアイコンが存在しないアプリはユーザーが終了手段を失いやすい
- 現状の終了手段: 付箋を右クリック → "Quit ClipNotice"
- 問題点: 付箋が非表示の間はメニューにアクセスできない（次のコピーを待つ必要がある）
- 対策案: `NotifyIcon` をトレイに常駐させ、そこからも Quit / 設定を呼べるようにする

### 2. 設定ダイアログにライブプレビューなし
- フォントサイズ・色を変更しても、次にクリップボードが変化するまで付箋に反映されない
- `ShowText` を即時呼び出すプレビュー機能が未実装

### 3. 自動起動（スタートアップ）未対応
- Windows の「スタートアップ」フォルダや `HKCU\Software\Microsoft\Windows\CurrentVersion\Run` への登録が未実装
- ユーザーが手動で設定する必要がある

### 4. SmartScreen 警告の可能性
- EXE が未署名のため、初回実行時に Windows SmartScreen の警告ダイアログが表示される可能性がある
- コード署名証明書による署名または Windows Defender への申請が未対応

### 5. 複数モニター未対応
- `Screen.PrimaryScreen` のみ参照しており、マルチモニター環境では主ディスプレイ左上にしか表示されない

### 6. テキスト以外のクリップボード内容は無視
- 画像・ファイル・リッチテキストはスキップ（`Clipboard.ContainsText()` のみチェック）

---

## NOT in Scope (Phase 1)

- クリップボード履歴
- 画像・ファイルコピーの表示
- 複数モニター対応
- 自動起動設定UI
- App Store / Microsoft Store 配布
- コード署名
- 表示位置のカスタマイズ（右上・中央等）
- dismiss秒数のカスタマイズ

---

## Edge Cases handled

| ケース | 対応 |
|--------|------|
| 他アプリがクリップボードをロック中 | `try-catch` で例外を飲み込み、次のTickまでスキップ |
| 空文字列コピー | `string.IsNullOrEmpty()` チェックでスキップ |
| 同じ内容の連続コピー | `_lastText` との比較でスキップ |
| 300文字超えの長い文字列 | 300文字で切り捨て＋"…" を付与して表示 |
| 付箋が画面幅を超える長い1行テキスト | `Screen.PrimaryScreen.WorkingArea.Width - Mar*2` を上限としてクリップ |
| 付箋最小サイズ | `Math.Max(w, 80)` / `Math.Max(h, 40)` で最小80x40pxを保証 |
| SettingsForm を開いている間に付箋タイマー切れ | 独立した `Timer` インスタンスで管理しており干渉しない |
| 起動直後の初回クリップボード内容 | `_lastText = string.Empty` で初期化 → 起動前にコピーされた内容も表示される（macOS版との差異） |
