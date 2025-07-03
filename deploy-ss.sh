#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# Enable debug tracing and error line tracking
trap 'echo "❌ Error on line ${LINENO}, exit code $?" >&2' ERR

# Default configuration values
PORT="${SS_PORT:-8388}"
METHOD="${SS_METHOD:-aes-256-gcm}"
ADDRESS="${SS_LISTEN_ADDR:-0.0.0.0}"
PLUGIN="${SS_PLUGIN:-}"
PLUGIN_OPTS="${SS_PLUGIN_OPTS:-}"
IMAGE="${SS_IMAGE:-ghcr.io/shadowsocks/ssserver-rust:latest}"
CONFIG_DIR="/etc/shadowsocks-rust"
CONFIG_FILE="${CONFIG_DIR}/config.json"

# Help message
usage() {
  cat <<EOF
Usage: $0 [options]

Options:
  -p PORT         Shadowsocks port (default: $PORT)
  -m METHOD       Encryption method (default: $METHOD)
  -a ADDRESS      Listen address (default: $ADDRESS)
  -P PLUGIN       Plugin name (e.g., v2ray-plugin)
  -o PLUGIN_OPTS  Plugin options (e.g., "server;tls")
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

# 1. Install Docker if not installed
if ! command -v docker &>/dev/null; then
  echo "🛠 Docker not found. Installing..."
  if [ -f /etc/redhat-release ]; then
    sudo yum install -y yum-utils device-mapper-persistent-data lvm2
    sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    sudo yum install -y docker-ce docker-ce-cli containerd.io
  elif [ -f /etc/debian_version ]; then
    sudo apt-get update
    sudo apt-get install -y ca-certificates curl gnupg lsb-release
    curl -fsSL https://download.docker.com/linux/$(. /etc/os-release && echo "$ID")/gpg | \
      sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] \
      https://download.docker.com/linux/$(. /etc/os-release && echo "$ID") \
      $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io
  else
    echo "❌ Unsupported Linux distribution."
    exit 1
  fi
  sudo systemctl enable docker
  sudo systemctl start docker
  echo "✅ Docker installed."
else
  echo "✔ Docker is already installed."
fi

# 2. Generate secure random password
PASSWORD="$(openssl rand -base64 16)"
echo "🔑 Generated secure password."

# 3. Create config directory and file
echo "📁 Creating config..."
sudo mkdir -p "$CONFIG_DIR"
cat <<EOF | sudo tee "$CONFIG_FILE" >/dev/null
{
  "server": "0.0.0.0",
  "server_port": ${PORT},
  "password": "${PASSWORD}",
  "method": "${METHOD}",
  "timeout": 300,
  "plugin": "${PLUGIN}",
  "plugin_opts": "${PLUGIN_OPTS}"
}
EOF

# 4. Run Docker container
echo "🐳 Starting Shadowsocks container..."
sudo docker pull "$IMAGE"
sudo docker rm -f ss-rust &>/dev/null || true
sudo docker run -d \
  --name ss-rust \
  --restart unless-stopped \
  -p "${ADDRESS}:${PORT}:${PORT}/tcp" \
  -p "${ADDRESS}:${PORT}:${PORT}/udp" \
  -v "${CONFIG_FILE}:/etc/shadowsocks-rust/config.json:ro" \
  "$IMAGE"

# 5. Generate ss:// link
ENCODED_CREDENTIALS=$(echo -n "${METHOD}:${PASSWORD}" | base64 -w 0)
SS_URI="ss://${ENCODED_CREDENTIALS}@${ADDRESS}:${PORT}"

if [[ -n "$PLUGIN" ]]; then
  PLUGIN_ENCODED=$(echo -n "?plugin=${PLUGIN}${PLUGIN_OPTS:+%3B${PLUGIN_OPTS//;/\\%3B}}" | tr -d '\n')
  SS_URI="${SS_URI}${PLUGIN_ENCODED}"
fi

# 6. Display final info
echo
echo "✅ Shadowsocks-Rust deployed successfully!"
echo "-----------------------------------------"
echo "🔌 Listen:       ${ADDRESS}:${PORT}"
echo "🔒 Method:       ${METHOD}"
echo "🔑 Password:     ${PASSWORD}"
[[ -n "$PLUGIN" ]] && echo "🔌 Plugin:       ${PLUGIN}" && echo "⚙️ Plugin opts:  ${PLUGIN_OPTS}"
echo "📄 Config file:  ${CONFIG_FILE}"
echo "🔗 SS URI:       ${SS_URI}"

# 7. Optional QR code
if command -v qrencode &>/dev/null; then
  echo
  echo "📱 QR Code (scan in Shadowsocks client):"
  echo "$SS_URI" | qrencode -t ANSIUTF8
else
  echo "⚠️ 'qrencode' not found. Install it to show QR code (e.g., 'sudo apt install qrencode')."
fi
