# linux-dotfiles

Linux (Debian/GNOME) の設定とセットアップスクリプト。別のマシンでも同じ環境を簡単に再現するためのリポジトリ。

## セットアップ

```bash
git clone https://github.com/Rih0z/linux-dotfiles.git ~/dotfiles
sudo bash ~/dotfiles/.scripts/setup-crd.sh
```

`TARGET_USER=<user>` を付けると対象ユーザーを指定できる（既定は `sudo` を実行したユーザー）。

## 内容

| パス | 説明 |
|------|------|
| `.scripts/setup-crd.sh` | Chrome Remote Desktop をローカル画面にミラー接続させる (非破壊的)。日本語ロケール/フォント、GDM 自動ログインも設定 |
| `patches/crd-existing-session.patch` | CRD 本体への「既存セッション」パッチ (スクリプトが自動適用) |
| `.docs/` | CRD・日本語入力・エイリアス等のドキュメント |
| `CLAUDE.md` | Claude Code 用の運用ルール |

## 注意 (セキュリティ)

- 実画面を共有するため、CRD の PIN を知る人は実デスクトップを操作できる。強い PIN を使うこと。
- スクリプトは画面ロック・スクリーンセーバーを無効化し、GDM 自動ログインを有効にする。物理アクセスが懸念される環境では該当部分を外すこと。
- パスワード・トークン類は `.passwords/` に置き、このリポジトリには含めない (`.gitignore` 済み)。
- パッチは CRD 本体 (`/opt/google/chrome-remote-desktop/`) を root で書き換える。内容は `patches/` で確認できる。
