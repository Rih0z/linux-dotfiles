# Chrome Remote Desktop セットアップ (ミラーモード)

## 概要

CRD をローカルディスプレイ (:0/:1) にアタッチし、Mac/Windows と同じミラーリング体験を提供する。仮想ディスプレイ (:20) は使用しない。

## セットアップスクリプト

```bash
sudo bash ~/.scripts/setup-crd.sh
```

## スクリプトが行うこと

1. ロケール確認 (`ja_JP.UTF-8` の生成・設定)
2. 日本語フォント (Noto Sans CJK) インストール
3. CRD Python スクリプトのミラーモードパッチ確認
4. systemd drop-in 作成 (`CHROME_REMOTE_DESKTOP_EXISTING_SESSION=1`)
5. GDM 有効化 + 自動ログイン + `graphical.target` 設定
6. CRD サービス再起動 + ローカルディスプレイへの gsettings 適用

**非破壊的**: 既存のデスクトップセッションやプロセスを kill しない。

## ミラーモードの仕組み

1. PC 起動 → GDM 自動ログイン → GNOME がローカルディスプレイ (:0 or :1) で起動
2. CRD サービスが起動 → 環境変数 `CHROME_REMOTE_DESKTOP_EXISTING_SESSION=1` を検出
3. CRD が既存のローカル X ディスプレイにアタッチ (仮想ディスプレイは作成しない)
4. CRD で接続 → ローカルと同じ画面が表示される (Mac/Windows と同じ体験)

## Mac/Windows との比較

| 項目 | Mac/Windows | Linux (ミラーモード) |
|------|-------------|----------------------|
| 方式 | ローカル画面をミラー | ローカル画面をミラー |
| セッション | ローカルと共有 | ローカルと共有 |
| ディスプレイ | 実画面 | 実画面 (:0/:1) |
| 永続性 | ○ | ○ |
| 自動起動 | ○ | ○ |

## 技術的な詳細

### CRD Python スクリプトへのパッチ

`/opt/google/chrome-remote-desktop/chrome-remote-desktop` に以下の変更を適用:

- `EXISTING_SESSION_ENV_VAR` 定数を追加
- `detect_existing_display()` 関数: `/tmp/.X11-unix/` からローカルディスプレイを検出
- `_init_child_env()`: ソフトウェアレンダリング強制をスキップ (ハードウェア GL を維持)
- `_launch_server()`: X サーバー起動をスキップし、既存ディスプレイにアタッチ
- `launch_desktop_session()`: セッション起動をスキップ (GNOME は既に起動済み)
- `on_process_exit()`: センチネルプロセス死亡時は再作成 (tear_down しない)

### systemd drop-in

`/etc/systemd/system/chrome-remote-desktop@<user>.service.d/existing-session.conf`:
- `Environment=CHROME_REMOTE_DESKTOP_EXISTING_SESSION=1` でミラーモードを有効化
- `ExecStartPre` で X ソケットの出現を最大30秒待機

### バックアップ

パッチ前のオリジナル: `/opt/google/chrome-remote-desktop/chrome-remote-desktop.bak`

## 検証方法

### コマンドラインでの確認

```bash
# サービス状態
systemctl is-active chrome-remote-desktop@<user>

# CRD ホストプロセスが起動しているか
pgrep -f "chrome-remote-desktop-host"

# センチネルプロセス (sleep infinity) が2つ起動しているか
ps -u "$USER" -o pid,comm,args | grep "sleep infinity"

# ログで "Existing session mode" を確認
sudo journalctl -u chrome-remote-desktop@<user> -b | grep -i "existing session"
```

### Playwright MCP での接続テスト

1. `remotedesktop.google.com/access` にアクセス
2. Google アカウントでログイン (手動)
3. debian-edu が「オンライン」と表示されていることを確認
4. クリックして PIN を入力 → 接続
5. ローカルデスクトップがそのままミラーリングされていれば成功

PIN: `~/.passwords/crd-pin.md` に保存済み

## トラブルシューティング

### CRD が「オフライン」と表示される

```bash
# ログを確認
journalctl -u chrome-remote-desktop@<user> -n 20

# サービスを再起動
sudo systemctl restart chrome-remote-desktop@<user>
```

### "no local X display found" エラー

ローカルデスクトップが起動していない。GDM が起動しているか確認:

```bash
systemctl status gdm
ls -la /tmp/.X11-unix/
```

### CRD 接続で黒画面になる場合

スクリーンロックが有効になっている可能性。スクリプトを再実行:

```bash
sudo bash ~/.scripts/setup-crd.sh
```

## 関連ファイル

- `~/.scripts/setup-crd.sh` - メインセットアップスクリプト
- `/opt/google/chrome-remote-desktop/chrome-remote-desktop` - CRD 本体 (パッチ済み)
- `/opt/google/chrome-remote-desktop/chrome-remote-desktop.bak` - パッチ前バックアップ
- `/etc/systemd/system/chrome-remote-desktop@<user>.service.d/existing-session.conf` - systemd drop-in
- `/etc/gdm3/daemon.conf` - GDM 設定 (自動ログイン・Wayland無効化)
- `/etc/default/locale` - システムロケール設定
