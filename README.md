# ss-deploy

**ss-deploy** is a simple one-click deployment script for [shadowsocks-rust](https://github.com/shadowsocks/shadowsocks-rust) using Docker.  
It supports major Linux distributions including Ubuntu, Debian, CentOS, and more.

## Features

- 🔐 Secure random password generation
- 🐳 Automatic Docker installation if missing
- ⚙️ Customizable via environment variables or CLI arguments
- 🔌 Plugin support (e.g., `v2ray-plugin`, `simple-obfs`)
- 🔁 Auto-restarting Docker container
- 📄 Generates Shadowsocks config file
- 🔗 Outputs `ss://` URI and optional QR code for client import

## Usage

Download and run the script in one line:

```bash
curl -fsSL https://raw.githubusercontent.com/yshngg/ss-deploy/main/deploy-ss.sh | sudo bash
```

## Custom Options

You can also pass custom options via CLI or environment variables:

```bash
SS_PORT=443 SS_METHOD=chacha20-ietf-poly1305 \
SS_PLUGIN=v2ray-plugin SS_PLUGIN_OPTS="server;tls" \
bash deploy-ss.sh
```

OR:

```bash
bash deploy-ss.sh -p 443 -m chacha20-ietf-poly1305 -P v2ray-plugin -o "server;tls"
```

## Requirements

- Linux (Ubuntu, Debian, CentOS, etc.)
- `curl`, `openssl`, `docker` (auto-installed if missing)
- qrencode (optional, for displaying QR codes)
