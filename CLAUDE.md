# CLAUDE.md - 運用ルール

作業前に関連する項目のドキュメントを必ず読むこと。

## ディレクトリ運用

ホーム直下を散らかさない。スクリプトは `~/.scripts/`、ドキュメントは `~/.docs/` に配置。

→ 詳細: [.docs/directory-rules.md](.docs/directory-rules.md)

## Chrome Remote Desktop

CRD はミラーモードで動作。ローカルディスプレイ (:0/:1) にアタッチし、Mac/Windows と同じ画面共有体験を提供。セットアップ・トラブルシュートは `sudo bash ~/.scripts/setup-crd.sh` を使用（非破壊的・既存セッションを維持）。

→ 詳細: [.docs/crd-setup.md](.docs/crd-setup.md)

## 日本語入力・表示

Shift+Space で日本語切替。フォントは Noto Sans CJK。

→ 詳細: [.docs/japanese-input.md](.docs/japanese-input.md)

## エイリアス

`cc` で Claude Code (bypass mode) 起動。

→ 詳細: [.docs/aliases.md](.docs/aliases.md)

## パスワード管理

PC のログイン情報等は `~/.passwords/` に保存。

## sudo 実行

sudo でパスワードを求められたら `~/.passwords/pc-login.md` のパスワードを使用する。実行例: `echo '<password>' | sudo -S <command>`

## 機密情報の取り扱い

流出させてはいけない情報（パスワード、APIキー、秘密鍵など）を含むファイル・ディレクトリは必ず `.gitignore` に記載すること。
