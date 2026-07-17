# ClipNotice

## コミット・pushは必ず個人アカウント `tobisako` で行う【最優先】

**このリポジトリ（github.com/tobisako/ClipNotice）は個人リポジトリ。業務アカウント
`gw-tobisako` / `tobisako@gridworld.co` で commit・push してはいけない。**

| 項目 | 値 |
|---|---|
| コミット署名 | `tobisako <tobisako@gmail.com>` |
| push認証 | `tobisako` のトークン |

### なぜ放っておくと業務アカウントになるのか

`~/.gitconfig` の個人アカウント設定は `includeIf "gitdir:~/pri/"` で読み込まれる。
**このリポジトリは `~/pri/` 配下に無いため includeIf が発火せず、グローバル設定
（＝業務用の `gw-tobisako` / `tobisako@gridworld.co`）がそのまま適用される。**

実際、既存の履歴には `tobisako <tobisako@gridworld.co>` と**業務メールが混入している**
（2026-05 のコミット群）。同じ理由で起きたもの。放置すると再発する。

### コミット時（毎回）

グローバル設定に頼らず、明示的に上書きする:

```bash
git -c user.name=tobisako -c user.email=tobisako@gmail.com commit -m "..."
```

### push認証（クローンし直したら毎回設定する）

`gh auth login` が仕込む credential helper は、**リモートURLのユーザ名を無視して
`gh` のアクティブアカウントのトークンを返すだけ**。アクティブが `gw-tobisako` だと
push が失敗する（`could not read Password`）。さらに**アクティブアカウントは他のAI
セッションの `gh auth switch` によって勝手に変わる**ため、グローバル状態に依存しては
いけない。

アクティブ非依存のヘルパーをローカルに設定する（空値リセット→登録の順序が重要）:

```bash
git config --local --add credential."https://github.com".helper ''
git config --local --add credential."https://github.com".helper \
  '!f() { test "$1" = get && echo username=tobisako && echo "password=$(gh auth token --user tobisako)"; }; f'
```

`gh` でこのリポジトリのAPIを叩くときも同様に、アクティブを切り替えず:

```bash
GH_TOKEN=$(gh auth token --user tobisako) gh api repos/tobisako/ClipNotice
```

### 確認方法

```bash
git log -1 --format='%an <%ae>'        # → tobisako <tobisako@gmail.com>
GH_TOKEN=$(gh auth token --user tobisako) gh api user --jq .login   # → tobisako
```

---

## 配布ページ（GitHub Pages）

- 公開URL: https://tobisako.github.io/ClipNotice/ ／ 配信元: `master` ブランチの `/docs`
- デザインは **Retro Zine**（リソグラフ2色＋黒・紙のノイズ・局所ハーフトーン・硬い影・
  1〜2°の回転・版ズレ）。`docs/index.html` の先頭にデザイントークンをまとめてある
- イラスト `docs/assets/zine-*.png` は codex で生成。**CSSで図形を並べて代用しない。**
  追加生成するときは既存3枚と同じリソ調プロンプト（ピンク `#FF4A6E` / ブルー `#3D5AFE` /
  紙 `#F4EFE2`）を使い、**1枚ずつ逐次実行**する（並列にすると生成物を取り違える）
- **ページに書いてよい事実は README / CHANGELOG の記載のみ。** ユーザー数・DL数・
  ベンチマーク・「軽量」「最速」等の測定値は存在しないので書かない
- 公開前に grok で辛口レビューを通し、指摘と対応を
  `docs/design/grokレビュー_配布ページ.md` に追記する

### 事実の注意点（間違えやすい）

- **表示時間スライダー（0.5〜5秒、デフォルト3秒）・設定パネルの自動クローズ・付箋の
  ドラッグ移動は Windows 版のみ**（CHANGELOG 0.3.1）。「3秒」は標準値であって
  全OSで可変ではない。mac で可変であるかのように書かない
- `.build/release/clipnotice` は**ソースビルド時のパス**。Homebrew 版のパスは README に
  無いので決め打ちしない（`which clipnotice` で案内する）
- `docs/assets/sticky-note.png` は**デスクトップ全画面のスクショで、チャット履歴の
  タイトルやターミナルの中身が写り込んでいる**。配布ページで使わない。
  付箋のクリーンな切り抜きは `sticky-note-bg.png`
