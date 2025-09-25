#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# Enable debug tracing and error line tracking
trap 'echo "❌ Error on line ${LINENO}, exit code $?" >&2' ERR

# Default configuration values
PORT="${SS_PORT:-8388}"
METHOD="${SS_METHOD:-chacha20-ietf-poly1305}"
ADDRESS="${SS_LISTEN_ADDR:-0.0.0.0}"
PLUGIN="${SS_PLUGIN:-v2ray-plugin}"
PLUGIN_OPTS="${SS_PLUGIN_OPTS:-server}"
VERSION="${SS_VERSION:-latest}"
CONFIG_DIR="/etc/shadowsocks-rust"
CONFIG_FILE="${CONFIG_DIR}/config.json"
BIN_DIR="/usr/local/bin"

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

# 1. Detect architecture (amd64 / arm64 only)
ARCH="$(uname -m)"
case "$ARCH" in
  x86_64) TARGET="x86_64-unknown-linux-gnu" ;;
  aarch64) TARGET="aarch64-unknown-linux-gnu" ;;
  *)
    echo "❌ Unsupported architecture: $ARCH"
    exit 1
    ;;
esac

# 2. Get latest version if VERSION=latest
if [[ "$VERSION" == "latest" ]]; then
  VERSION="$(curl -fsSL https://api.github.com/repos/shadowsocks/shadowsocks-rust/releases/latest \
    | grep -Po '"tag_name": "\K.*?(?=")')"
  echo "⬇️ Latest version detected: $VERSION"
fi

# 3. Download and install shadowsocks-rust
echo "📦 Downloading Shadowsocks-Rust $VERSION ($TARGET)..."
URL="https://github.com/shadowsocks/shadowsocks-rust/releases/download/${VERSION}/shadowsocks-${VERSION}.${TARGET}.tar.xz"
TMP_DIR="$(mktemp -d)"
curl -L "$URL" -o "$TMP_DIR/ss-rust.tar.xz"
tar -xJf "$TMP_DIR/ss-rust.tar.xz" -C "$TMP_DIR"
sudo install -m 755 "$TMP_DIR/ssserver" "$TMP_DIR/ssservice" "$BIN_DIR/"
rm -rf "$TMP_DIR"
echo "✅ Installed ssserver and ssservice to $BIN_DIR"

# Generate secure password using ssservice
PASSWORD="$(ssservice genkey -m "$METHOD")"
echo "🔑 Generated password with ssservice."

# 4. Create config
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

# 5. Run ssserver
mv ./ssserver.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl start ss-rust.service
sudo systemctl enable ssserver.service
sudo systemctl status ss-rust.service

# 6. Generate ss:// link
ENCODED_CREDENTIALS=$(echo -n "${METHOD}:${PASSWORD}" | base64 -w 0)
SS_URI="ss://${ENCODED_CREDENTIALS}@${ADDRESS}:${PORT}"

if [[ -n "$PLUGIN" ]]; then
  PLUGIN_ENCODED=$(echo -n "?plugin=${PLUGIN}${PLUGIN_OPTS:+%3B${PLUGIN_OPTS//;/\\%3B}}" | tr -d '\n')
  SS_URI="${SS_URI}${PLUGIN_ENCODED}"
fi

# 7. Final output
echo
echo "✅ Shadowsocks-Rust deployed successfully!"
echo "-----------------------------------------"
echo "🔌 Listen:       ${ADDRESS}:${PORT}"
echo "🔒 Method:       ${METHOD}"
echo "🔑 Password:     ${PASSWORD}"
[[ -n "$PLUGIN" ]] && echo "🔌 Plugin:       ${PLUGIN}" && echo "⚙️ Plugin opts:  ${PLUGIN_OPTS}"
echo "📄 Config file:  ${CONFIG_FILE}"
echo "🔗 SS URI:       ${SS_URI}"

# 8. Optional QR code
if command -v qrencode &>/dev/null; then
  echo
  echo "📱 QR Code (scan in Shadowsocks client):"
  echo "$SS_URI" | qrencode -t ANSIUTF8
else
  echo "⚠️ 'qrencode' not found. Install it to show QR code (e.g., 'sudo apt install qrencode')."
fi
