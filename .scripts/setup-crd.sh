#!/bin/bash
# Chrome Remote Desktop セットアップスクリプト (ミラーモード)
# sudo bash ~/.scripts/setup-crd.sh で実行
#
# CRD を既存のローカルディスプレイ (:0/:1) にアタッチし、
# Mac/Windows と同じミラーリング体験を提供する。
# 既存のデスクトップセッションは破壊しない。

set -e

TARGET_USER="${TARGET_USER:-${SUDO_USER:-$(logname 2>/dev/null)}}"
if [ -z "$TARGET_USER" ] || [ "$TARGET_USER" = "root" ]; then
    echo "sudo で実行するか TARGET_USER=<user> を指定してください"; exit 1
fi
USER_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CRD_SCRIPT="/opt/google/chrome-remote-desktop/chrome-remote-desktop"

echo "=== Chrome Remote Desktop ミラーモード セットアップ ==="

# ────────────────────────────────────────────
# 1. ロケール確認 (ja_JP.UTF-8)
# ────────────────────────────────────────────
echo "[1/6] ロケール確認..."
if ! locale -a 2>/dev/null | grep -q "ja_JP.utf8"; then
    sed -i 's/^# *ja_JP.UTF-8/ja_JP.UTF-8/' /etc/locale.gen 2>/dev/null || true
    locale-gen ja_JP.UTF-8
    echo "  → ja_JP.UTF-8 を生成"
fi

cat > /etc/default/locale << 'LOCEOF'
LANG=ja_JP.UTF-8
LC_ALL=ja_JP.UTF-8
LOCEOF
echo "  → /etc/default/locale を設定"

# ────────────────────────────────────────────
# 2. 日本語フォントのインストール
# ────────────────────────────────────────────
echo "[2/6] 日本語フォントをインストール..."

if ! dpkg -l fonts-noto-cjk 2>/dev/null | grep -q "^ii"; then
    apt-get update -qq
    apt-get install -y -qq fonts-noto-cjk fonts-noto-cjk-extra
    echo "  → Noto Sans CJK をインストール"
else
    echo "  → Noto Sans CJK は既にインストール済み"
fi

su - "$TARGET_USER" -c "fc-cache -f" 2>/dev/null
echo "  → フォントキャッシュを更新"

# ────────────────────────────────────────────
# 3. CRD Python スクリプトにミラーモードパッチを適用
# ────────────────────────────────────────────
echo "[3/6] CRD ミラーモードパッチを確認..."

if grep -q "EXISTING_SESSION_ENV_VAR" "$CRD_SCRIPT"; then
    echo "  → パッチは既に適用済み"
else
    PATCH="${SCRIPT_DIR}/../patches/crd-existing-session.patch"
    cp -n "$CRD_SCRIPT" "${CRD_SCRIPT}.bak"
    if patch --dry-run "$CRD_SCRIPT" < "$PATCH" >/dev/null 2>&1; then
        patch "$CRD_SCRIPT" < "$PATCH"
        echo "  → パッチを適用 (バックアップ: ${CRD_SCRIPT}.bak)"
    else
        echo "  → 警告: パッチが適用できません (CRD のバージョン差異)。手動で確認してください"
    fi
fi

# ────────────────────────────────────────────
# 4. systemd drop-in 作成 (既存セッションモード)
# ────────────────────────────────────────────
echo "[4/6] systemd drop-in を作成..."

DROPIN_DIR="/etc/systemd/system/chrome-remote-desktop@${TARGET_USER}.service.d"
mkdir -p "$DROPIN_DIR"

cat > "${DROPIN_DIR}/existing-session.conf" << 'DROPEOF'
[Unit]
After=graphical-session.target
Wants=graphical-session.target

[Service]
Environment=CHROME_REMOTE_DESKTOP_EXISTING_SESSION=1
ExecStartPre=/bin/bash -c 'for i in $(seq 1 30); do [ -S /tmp/.X11-unix/X0 ] || [ -S /tmp/.X11-unix/X1 ] && exit 0; sleep 1; done'
DROPEOF

echo "  → ${DROPIN_DIR}/existing-session.conf を作成"

# 古いクリーンアップサービスを無効化 (ミラーモードでは不要)
systemctl disable crd-cleanup@${TARGET_USER}.service 2>/dev/null || true
rm -f /etc/systemd/system/crd-cleanup@.service 2>/dev/null || true

# ────────────────────────────────────────────
# 5. GDM 有効化 + 自動ログイン + graphical.target
# ────────────────────────────────────────────
echo "[5/6] GDM を有効化 (起動時 GUI 自動ログイン)..."

if [ -f /etc/gdm3/daemon.conf ]; then
    # Wayland 無効化
    if grep -q "^#WaylandEnable=false" /etc/gdm3/daemon.conf; then
        sed -i 's/^#WaylandEnable=false/WaylandEnable=false/' /etc/gdm3/daemon.conf
    elif ! grep -q "^WaylandEnable=false" /etc/gdm3/daemon.conf; then
        sed -i '/^\[daemon\]/a WaylandEnable=false' /etc/gdm3/daemon.conf
    fi
    echo "  → GDM Wayland 無効化"

    # 自動ログイン設定
    if ! grep -q "^AutomaticLoginEnable" /etc/gdm3/daemon.conf; then
        sed -i '/^\[daemon\]/a AutomaticLoginEnable=true\nAutomaticLogin='"$TARGET_USER"'' /etc/gdm3/daemon.conf
        echo "  → GDM 自動ログイン有効化 (ユーザー: $TARGET_USER)"
    else
        sed -i 's/^AutomaticLoginEnable=.*/AutomaticLoginEnable=true/' /etc/gdm3/daemon.conf
        sed -i 's/^AutomaticLogin=.*/AutomaticLogin='"$TARGET_USER"'/' /etc/gdm3/daemon.conf
        echo "  → GDM 自動ログイン更新 (ユーザー: $TARGET_USER)"
    fi
fi

systemctl unmask gdm.service 2>/dev/null || true
systemctl unmask gdm3.service 2>/dev/null || true
systemctl enable gdm 2>/dev/null || true
echo "  → GDM を有効化"

systemctl set-default graphical.target
echo "  → デフォルトターゲット: graphical.target"

# ────────────────────────────────────────────
# 6. CRD サービス再起動 + ローカル設定適用
# ────────────────────────────────────────────
echo "[6/6] CRD サービスを再起動..."

systemctl unmask chrome-remote-desktop.service 2>/dev/null || true
systemctl unmask chrome-remote-desktop@${TARGET_USER}.service 2>/dev/null || true

systemctl daemon-reload
systemctl restart chrome-remote-desktop@${TARGET_USER}.service

# ローカルディスプレイに gsettings を適用
echo "  ローカルディスプレイに設定を適用..."

# ローカル DISPLAY を検出
LOCAL_DISPLAY=""
for sock in /tmp/.X11-unix/X*; do
    [ -S "$sock" ] || continue
    NUM="${sock##*/X}"
    if [ "$NUM" -lt 20 ] 2>/dev/null; then
        LOCAL_DISPLAY=":${NUM}"
        break
    fi
done

if [ -n "$LOCAL_DISPLAY" ]; then
    # Xauthority を検出
    UID_NUM=$(id -u "$TARGET_USER" 2>/dev/null || echo 1000)
    XAUTH="/run/user/${UID_NUM}/gdm/Xauthority"
    [ -f "$XAUTH" ] || XAUTH="${USER_HOME}/.Xauthority"

    su - "$TARGET_USER" -c "
      export DISPLAY=${LOCAL_DISPLAY}
      export XAUTHORITY=${XAUTH}
      export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/${UID_NUM}/bus

      # 日本語フォント
      gsettings set org.gnome.desktop.interface font-name 'Noto Sans CJK JP 11' 2>/dev/null || true
      gsettings set org.gnome.desktop.interface document-font-name 'Noto Sans CJK JP 11' 2>/dev/null || true
      gsettings set org.gnome.desktop.interface monospace-font-name 'Noto Sans Mono CJK JP 10' 2>/dev/null || true
      gsettings set org.gnome.desktop.wm.preferences titlebar-font 'Noto Sans CJK JP Bold 11' 2>/dev/null || true

      # 日本語入力: Shift+Space で切替
      gsettings set org.gnome.desktop.input-sources sources \"[('ibus', 'mozc-jp'), ('xkb', 'jp')]\" 2>/dev/null || true
      gsettings set org.gnome.desktop.input-sources xkb-options \"['grp:shift_space_toggle']\" 2>/dev/null || true

      # スクリーンロック・スクリーンセーバーを無効化
      gsettings set org.gnome.desktop.screensaver lock-enabled false 2>/dev/null || true
      gsettings set org.gnome.desktop.screensaver idle-activation-enabled false 2>/dev/null || true
      gsettings set org.gnome.desktop.session idle-delay 0 2>/dev/null || true
      gsettings set org.gnome.settings-daemon.plugins.power idle-dim false 2>/dev/null || true
      gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'nothing' 2>/dev/null || true

      # Mac風操作
      gsettings set org.gnome.desktop.peripherals.mouse natural-scroll true 2>/dev/null || true
      gsettings set org.gnome.desktop.peripherals.touchpad natural-scroll true 2>/dev/null || true
      gsettings set org.gnome.desktop.peripherals.touchpad tap-to-click true 2>/dev/null || true
      gsettings set org.gnome.desktop.wm.preferences button-layout 'close,minimize,maximize:' 2>/dev/null || true
      gsettings set org.gnome.mutter dynamic-workspaces true 2>/dev/null || true
    " 2>/dev/null || true
    echo "  → ローカルディスプレイ (${LOCAL_DISPLAY}) に設定を適用"
else
    echo "  → 警告: ローカルディスプレイが見つかりません"
fi

# 起動確認 (最大30秒待機)
echo "  起動を確認中..."
CRD_OK=false
for i in $(seq 1 10); do
    sleep 3
    if pgrep -u "$TARGET_USER" -f "chrome-remote-desktop-host" >/dev/null 2>&1; then
        CRD_OK=true
        break
    fi
    echo "  待機中... ($((i*3))秒)"
done

if [ "$CRD_OK" = true ]; then
    echo ""
    echo "=== セットアップ完了 (ミラーモード) ==="
    echo ""
    echo "  [CRD 状態]"
    echo "    ✓ CRD ホスト: 起動済み"
    echo "    ✓ ミラーモード: ローカルディスプレイ ${LOCAL_DISPLAY:-??} にアタッチ"
    echo ""
else
    echo ""
    echo "=== 警告: CRD の起動に問題がある可能性 ==="
    echo ""
    echo "  CRD サービス状態:"
    systemctl is-active chrome-remote-desktop@${TARGET_USER}.service 2>/dev/null || true
    echo ""
    echo "  CRD ログ (最新10行):"
    journalctl -u chrome-remote-desktop@${TARGET_USER}.service --no-pager -n 10 2>/dev/null || true
    echo ""
fi

echo "  [ミラーモードの動作]"
echo "    ✓ CRD がローカルディスプレイ (${LOCAL_DISPLAY:-:0/:1}) にアタッチ"
echo "    ✓ Mac/Windows と同じミラーリング体験"
echo "    ✓ ローカル画面と CRD が同じデスクトップを共有"
echo ""
echo "  [日本語環境]"
echo "    ✓ ロケール: ja_JP.UTF-8"
echo "    ✓ Noto Sans CJK フォント"
echo "    ✓ IBus + Mozc (Shift+Space で切替)"
echo ""
echo "  [起動時の動作]"
echo "    ✓ graphical.target (GUI 起動)"
echo "    ✓ GDM 自動ログイン ($TARGET_USER)"
echo "    ✓ CRD がローカルセッションにミラー接続"
echo ""
