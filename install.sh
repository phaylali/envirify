#!/usr/bin/env bash
# Envirify — builds a release and installs it for the current user.
set -euo pipefail
cd "$(dirname "$0")"

echo "==> Building release…"
flutter build linux --release

BUNDLE="build/linux/x64/release/bundle"
APP_DIR="$HOME/.local/opt/envirify"
BIN_DIR="$HOME/.local/bin"
DESKTOP_DIR="$HOME/.local/share/applications"
ICON_DIR="$HOME/.local/share/icons/hicolor/256x256/apps"

echo "==> Installing to $APP_DIR"
mkdir -p "$APP_DIR" "$BIN_DIR" "$DESKTOP_DIR" "$ICON_DIR"
rm -rf "$APP_DIR/lib" "$APP_DIR/data" "$APP_DIR/envirify"
cp -r "$BUNDLE/." "$APP_DIR/"

cat > "$BIN_DIR/envirify" <<EOF
#!/usr/bin/env sh
exec "$APP_DIR/envirify" "\$@"
EOF
chmod 755 "$BIN_DIR/envirify"

install -Dm644 packaging/envirify.desktop "$DESKTOP_DIR/envirify.desktop"
install -Dm644 assets/icon-256.png "$ICON_DIR/envirify.png"

command -v update-desktop-database >/dev/null && update-desktop-database "$DESKTOP_DIR" || true
command -v gtk-update-icon-cache >/dev/null && gtk-update-icon-cache -q -t "$HOME/.local/share/icons/hicolor" || true

echo "==> Done. Launch with 'envirify' or from your app launcher."
