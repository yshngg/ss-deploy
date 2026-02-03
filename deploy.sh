#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# Enable debug tracing and error line tracking
trap 'echo "❌ Error on line ${LINENO}, exit code $?" >&2' ERR

# Default configuration values
PORT="${SS_PORT:-8388}"
METHOD="${SS_METHOD:-chacha20-ietf-poly1305}"
ADDRESS="${SS_LISTEN_ADDR:-0.0.0.0}"
PLUGIN="${SS_PLUGIN:-}"
PLUGIN_OPTS="${SS_PLUGIN_OPTS:-}"
VERSION="${SS_VERSION:-latest}"
CONFIG_DIR="/etc/shadowsocks-rust"
CONFIG_FILE="${CONFIG_DIR}/config.json"
BIN_DIR="/usr/local/bin"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"

# Fix "command not found" error on certain Linux distributions (e.g., Red Hat)
# https://superuser.com/a/709522
# https://man7.org/linux/man-pages/man5/sudoers.5.html
export PATH="$PATH:/usr/local/bin"

# Help message
usage() {
  cat <<EOF
Usage: $0 [options]

Options:
  -p PORT         Shadowsocks port (default: $PORT)
  -m METHOD       Encryption method (default: $METHOD)
  -a ADDRESS      Listen address (default: $ADDRESS)
  -P PLUGIN       Plugin name (default: $PLUGIN)
  -o PLUGIN_OPTS  Plugin options (default: $PLUGIN_OPTS)
  -h              Show this help message
EOF
    exit 0
}

# Parse CLI options
while getopts "p:m:a:P:o:h" opt; do
    case $opt in
        p) PORT="$OPTARG" ;;
        m) METHOD="$OPTARG" ;;
        a) ADDRESS="$OPTARG" ;;
        P) PLUGIN="$OPTARG" ;;
        o) PLUGIN_OPTS="$OPTARG" ;;
        h) usage ;;
        *) usage ;;
    esac
done

echo "🚀 Starting Shadowsocks-Rust deployment..."

# 1. Setting up HTTP Server
echo "📡 Setting up HTTP Server for checking network connectivity..."
curl --output "$SCRIPT_DIR/http.service" https://raw.githubusercontent.com/yshngg/ss-deploy/main/http.service
sudo install -m 644 "$SCRIPT_DIR/http.service" /etc/systemd/system/http.service
sudo systemctl daemon-reload
sudo systemctl enable --now http.service
# Show status but don't fail if inactive
sudo systemctl --no-pager --full status http.service || true

# 2. Download and install shadowsocks-rust
# Detect architecture (amd64 / arm64 only)
ARCH="$(uname -m)"
case "$ARCH" in
    x86_64) TARGET="x86_64-unknown-linux-gnu" ;;
    aarch64) TARGET="aarch64-unknown-linux-gnu" ;;
    *)
        echo "❌ Unsupported architecture: $ARCH"
        exit 1
    ;;
esac

# Get latest version if VERSION=latest
if [[ "$VERSION" == "latest" ]]; then
    VERSION="$(curl -fsSL https://api.github.com/repos/shadowsocks/shadowsocks-rust/releases/latest \
    | grep -Po '"tag_name": "\K.*?(?=")')"
    echo "⬇️ Latest version detected: $VERSION"
fi

# Download and install
echo "📦 Downloading Shadowsocks-Rust $VERSION ($TARGET)..."
URL="https://github.com/shadowsocks/shadowsocks-rust/releases/download/${VERSION}/shadowsocks-${VERSION}.${TARGET}.tar.xz"
TMP_DIR="$(mktemp -d)"
cleanup() { rm -rf "$TMP_DIR"; }
trap 'cleanup' EXIT
curl -L "$URL" -o "$TMP_DIR/shadowsocks-rust.tar.xz"

tar -xJf "$TMP_DIR/shadowsocks-rust.tar.xz" -C "$TMP_DIR"
if [[ ! -x "$TMP_DIR/ssserver" || ! -x "$TMP_DIR/ssservice" ]]; then
    echo "❌ Expected binaries not found in $TMP_DIR/" >&2
    exit 1
fi
sudo install -m 755 "$TMP_DIR/ssserver" "$TMP_DIR/ssservice" "$BIN_DIR/"
echo "✅ Installed ssserver and ssservice to $BIN_DIR"

# 3. Create config
# Generate secure password using ssservice
PASSWORD="$(ssservice genkey -m "$METHOD")"
echo "🔑 Generated password with ssservice."

echo "📁 Creating config..."
sudo mkdir -p "$CONFIG_DIR"
cat <<EOF | sudo tee "$CONFIG_FILE" >/dev/null
{
  "server": "${ADDRESS}",
  "server_port": ${PORT},
  "password": "${PASSWORD}",
  "method": "${METHOD}",
  "timeout": 300,
  "plugin": "${PLUGIN}",
  "plugin_opts": "${PLUGIN_OPTS}"
}
EOF

# 4. Run ssserver
curl --output "$SCRIPT_DIR/ssserver.service" https://raw.githubusercontent.com/yshngg/ss-deploy/main/ssserver.service
sudo install -m 644 "$SCRIPT_DIR/ssserver.service" /etc/systemd/system/ssserver.service
sudo systemctl daemon-reload
sudo systemctl enable --now ssserver.service
sudo systemctl status ssserver.service
# Optional: show brief status without paging, do not fail the script if inactive
sudo systemctl --no-pager --full status ssserver.service || true

# 5. Final output
# Generate ss:// link
ENCODED_CREDENTIALS=$(echo -n "${METHOD}:${PASSWORD}" | base64 -w 0)
if ! PUBLIC_IP="$(curl -fsSL --max-time 5 ifconfig.me)"; then
  echo "⚠️ Unable to determine public IP from ifconfig.me, falling back to ${ADDRESS}." >&2
  PUBLIC_IP="${ADDRESS}"
fi
SS_URI="ss://${ENCODED_CREDENTIALS}@${PUBLIC_IP}:${PORT}"

if [[ -n "$PLUGIN" ]]; then
    PLUGIN_ENCODED=$(echo -n "/?plugin=${PLUGIN}${PLUGIN_OPTS:+%3B${PLUGIN_OPTS//;/\\%3B}}" | tr -d '\n')
    SS_URI="${SS_URI}${PLUGIN_ENCODED}"
fi

# Output
echo
echo "✅ Shadowsocks-Rust deployed successfully!"
echo "-----------------------------------------"
echo "🔌 Listen:       ${ADDRESS}:${PORT}"
echo "🔒 Method:       ${METHOD}"
echo "🔑 Password:     ${PASSWORD}"
[[ -n "$PLUGIN" ]] && echo "🔌 Plugin:       ${PLUGIN}" && echo "⚙️ Plugin opts:  ${PLUGIN_OPTS}"
echo "📄 Config file:  ${CONFIG_FILE}"
echo "🔗 SS URI:       ${SS_URI}"

# 6. Optional QR code
if command -v qrencode &>/dev/null; then
    echo
    echo "📱 QR Code (scan in Shadowsocks client):"
    echo "$SS_URI" | qrencode -t ANSIUTF8
else
    echo "⚠️ 'qrencode' not found. Install it to show QR code (e.g., 'sudo apt install qrencode')."
fi
