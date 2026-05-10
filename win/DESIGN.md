# ClipNotice (Windows) — Design Document

Generated: 2026-05-11 by tobisako (mac版の DESIGN を Windows に移植)
Branch: master

## Problem

コピー操作のたびに「正しくコピーできたか？」という認知負荷がある。
確認のためにペーストするか、クリップボードマネージャーのホットキーを押す必要がある。

ClipNotice はこれを解消する: コピーした瞬間に内容が見える。自動で消える。

特に Google Remote Desktop など複数 PC 間でコピペを往復する場面で、
「どの PC にコピーが届いているか」を付箋で一目で確認できる。

## Differentiation

| カテゴリ | 例 | ClipNotice との違い |
|---------|-----|------------------|
| クリップボードマネージャー | Ditto, ClipboardFusion, ClipClip | 履歴蓄積 + ホットキー呼び出し。能動操作が必要。 |
| **ClipNotice** | — | コピー即時表示 → 3 秒後消去。受動型アンビエント通知。履歴不要。 |

## Core Feature (Phase 1 Confirmed)

- クリップボード変化を検知（0.5 秒ポーリング）
- 画面左上に付箋 UI 表示（コピーした文字列）
- 3 秒後自動消去
- クリックで即時消去
- 右クリック → 設定 / Quit メニュー

## UI Requirements

- **タスクバー**: 表示しない（`ShowInTaskbar = false`）
- **メニューバー**: なし（常駐型バックグラウンド動作）
- **付箋**: 画面左上のボーダーレス TopMost フォーム
- **起動**: ユーザー任意（`shell:startup` にショートカット配置で自動起動可）

## Architecture

```
clipnotice.exe (WinForms, .NET 9, win-x64, single-file, framework-dependent)
│
├── Program.cs
│   ├── [STAThread] static Main()        ← Clipboard API は STA 必須
│   ├── Application.EnableVisualStyles()
│   └── Application.Run(new ClipboardMonitor())
│
├── ClipboardMonitor (ApplicationContext)
│   ├── Timer 500ms → Poll()
│   ├── Clipboard.ContainsText() == false → skip
│   ├── Clipboard.GetText() が前回と同じ → skip
│   ├── 例外 (他アプリが clipboard ロック中) → catch して次の tick
│   └── 新規テキスト → StickyForm.ShowText(text)
│
├── StickyForm (Form)
│   ├── FormBorderStyle = None
│   ├── ShowInTaskbar = false
│   ├── TopMost = true
│   ├── Opacity = 0.95
│   ├── StartPosition = Manual → 左上 (Mar=20px)
│   ├── content: Label (Dock = Fill, Padding = 12)
│   ├── サイズ算出: TextRenderer.MeasureText (GDI) ← Label 描画と同じレンダラ
│   ├── auto-dismiss: WinForms.Timer 3000ms → Hide()
│   ├── 左クリック → Hide()
│   └── 右クリック → ContextMenuStrip ["設定...", "Quit ClipNotice"]
│
├── SettingsForm (Form, modal ShowDialog)
│   ├── 文字サイズ (TrackBar 8〜48pt)
│   ├── 文字の色 (ColorDialog)
│   ├── 背景の色 (ColorDialog, default LightYellow)
│   ├── 改行する (CheckBox)
│   └── public event Action? Changed
│       └── 各ウィジェット変更時に発火 → StickyForm がプレビュー表示
│
└── Settings (static, レジストリ永続化)
    ├── HKCU\Software\ClipNotice
    ├── FontSize : DWORD
    ├── TextColorArgb : DWORD
    ├── BgColorArgb : DWORD
    └── WordWrap : DWORD (0/1)
```

## Tech Stack

| 要素 | 選択 | 理由 |
|------|------|------|
| 言語 | C# 12 / .NET 9 | Windows ネイティブ、Clipboard / WinForms 直接利用 |
| UI | WinForms | ボーダレス TopMost フォームを最短コードで構築可能 |
| 検知 | `Clipboard.ContainsText()` + テキスト比較ポーリング | Win32 には NSPasteboard.changeCount 相当の公開 API がないためテキスト差分で代替 |
| 設定永続化 | `Microsoft.Win32.Registry` (HKCU) | 追加依存なし、ユーザースコープ |
| プロジェクト | `ClipNotice.csproj` (`PublishSingleFile=true`, `SelfContained=false`, `RuntimeIdentifier=win-x64`) | 単一 EXE、ランタイムは別途 .NET 9 を要求 |

## Distribution Strategy

**選択: GitHub Releases に framework-dependent な単一 EXE を添付**

理由:
- self-contained にすると 60MB 超 → framework-dependent で ~170KB に圧縮
- .NET 9 ランタイムは Microsoft 公式から無償取得可能
- コード署名なし → 初回起動時に SmartScreen 警告が出る（README に回避手順を記載）

ビルドフロー (`.github/workflows/build-windows.yml`):

```yaml
on:
  push:
    tags: ['v*']        # タグ push で自動リリース添付
  workflow_dispatch:    # 手動再ビルド可能

steps:
  - uses: actions/checkout@v4
  - uses: actions/setup-dotnet@v4
    with: { dotnet-version: '9.0.x' }
  - run: |
      dotnet publish ClipNotice.csproj `
        -c Release -r win-x64 `
        --self-contained false `
        -p:PublishSingleFile=true `
        -o publish
  - uses: actions/upload-artifact@v4
    with: { name: clipnotice-windows, path: win/publish/clipnotice.exe }
  - if: startsWith(github.ref, 'refs/tags/')
    uses: softprops/action-gh-release@v2
    with: { files: win/publish/clipnotice.exe }
```

**インストール手順 (ユーザー側):**

1. [Releases](https://github.com/tobisako/ClipNotice/releases) から `clipnotice.exe` をダウンロード
2. `Win+R` → `shell:startup` → ショートカット配置（任意）
3. 実行 — SmartScreen が出たら「詳細情報」→「実行」

## Mac 版との違い（まとめ）

| 項目 | macOS | Windows |
|------|-------|---------|
| 実行モデル | `LSBackgroundOnly = YES` の .app | `ShowInTaskbar = false` の WinForms EXE |
| クリップボード検知 | `NSPasteboard.changeCount` (整数 increment) | `Clipboard.GetText()` のテキスト比較 |
| 付箋 | `NSPanel(.nonactivatingPanel)` + `.floating` | `Form(FormBorderStyle=None, TopMost=true)` |
| スレッド要件 | メインスレッドで RunLoop | `[STAThread]` 必須（OLE Clipboard） |
| 設定永続化 | `UserDefaults` | レジストリ HKCU |
| 配布 | Homebrew Formula (ソースビルド) | GitHub Releases (EXE 添付) |
| 署名 | 不要 (ローカルビルドのため quarantine 付かない) | 未署名 → SmartScreen 警告（回避可能） |
| 自動起動 | Login Items | `shell:startup` ショートカット |

## NOT In Scope (Phase 1)

- 画像・ファイルコピーの表示
- クリップボード履歴
- グローバルホットキー
- Microsoft Store 配布
- ARM64 ビルド
- 複数モニター対応（Phase 2）
- ダークモード自動追従
- 多言語化（UI は日本語固定）

## Edge Cases Handled

- **クリップボードロック競合**: 他アプリが clipboard を握っている瞬間に GetText() が `ExternalException` を投げる → catch して次の tick で再試行
- **同じ内容の連続コピー**: `_lastText == text` で skip
- **空文字列コピー**: `string.IsNullOrEmpty` で skip
- **画像・ファイルコピー**: `ContainsText()` が false → skip（テキスト以外は無視）
- **アプリ起動直後のクリップボード**: 初回 Poll で現在の内容を 1 度表示する仕様（mac の changeCount スキップとは挙動が異なる）
- **長文**: 300 文字超は冒頭 300 文字 + `…` で truncate
- **大きいフォントでの末尾切れ**: `TextRenderer.MeasureText` (GDI) で Label 描画と同じレンダラを使い、右側に +12px 余白を取って glyph overhang を吸収

## Implementation History (Phase 1)

1. `dotnet new winforms` ベースで雛形作成
2. `Program.cs` に `[STAThread]` 付き Main を配置（top-level statements は STA を自動付与しないため必須）
3. `ClipboardMonitor.cs`: 500ms Timer + 例外スキップ
4. `StickyForm.cs`: ボーダレス TopMost + 3 秒タイマー
5. `SettingsForm.cs`: TrackBar / ColorDialog / CheckBox + `Changed` イベント
6. `Settings.cs`: HKCU レジストリ Load/Save
7. GitHub Actions ワークフローでタグ push 時に自動リリース添付
8. v0.3.0 で STA 修正 + 設定中ライブプレビュー + TextRenderer サイジングを反映
