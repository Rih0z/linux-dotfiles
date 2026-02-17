# 日本語入力・表示設定

## 現在の構成

- **入力メソッド**: IBus + Mozc
- **切替キー**: Shift+Space
- **フォント**: Noto Sans CJK JP
- **ロケール**: ja_JP.UTF-8

## 日本語切替の使い方

- **Shift+Space**: 日本語 (Mozc) ↔ 英語 (直接入力) を切替
- CRD・ローカル両方で同じキーバインド

## トラブルシューティング

### CRD で日本語入力できない

IBus デーモンが起動しているか確認:
```bash
ps aux | grep ibus-daemon
```

起動していなければ:
```bash
ibus-daemon -drx &
```

### 文字化けする

Noto Sans CJK がインストールされているか確認:
```bash
dpkg -l fonts-noto-cjk
```

未インストールなら:
```bash
sudo apt install fonts-noto-cjk fonts-noto-cjk-extra
fc-cache -f
```

## 設定箇所

- GNOME: `org.gnome.desktop.input-sources.sources` → `[('ibus', 'mozc-jp'), ('xkb', 'jp')]`
- GNOME: `org.gnome.desktop.input-sources.xkb-options` → `['grp:shift_space_toggle']`
- IBus: `/desktop/ibus/general/hotkey/triggers` → `['<Shift>space']`
- CRD セッション: `GTK_IM_MODULE=ibus`, `QT_IM_MODULE=ibus`, `XMODIFIERS=@im=ibus`
