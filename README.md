# ss-deploy

**ss-deploy** is a simple one-click deployment script for [shadowsocks-rust](https://github.com/shadowsocks/shadowsocks-rust) using Docker.  
It supports major Linux distributions including Ubuntu, Debian, CentOS, and more.

## 🧩 Features

- 🔐 Secure random password generation
- 🐳 Automatic Docker installation if missing
- ⚙️ Customizable via environment variables or CLI arguments
- 🔌 Plugin support (e.g., `v2ray-plugin`, `simple-obfs`)
- 🔁 Docker container auto-restarts on reboot
- 📄 Generates Shadowsocks config file
- 🔗 Outputs `ss://` URI and optional QR code for client import
- ✅ Deploys a minimal Nginx server on port 80 for health checks

## 🚀 Quick Start

Download and run the script in one line:

```bash
curl -fsSL https://raw.githubusercontent.com/yshngg/ss-deploy/main/deploy-ss.sh | sudo bash
```

Once completed, you can:

- Access `http://<server-ip>` to verify network access (should return `Hello, world!`)
- Use the displayed ss:// URI or QR code to configure your Shadowsocks client

## ⚙️ Custom Options

You can customize settings using either **environment variables** or **CLI arguments**:

### Environment variables

```bash
SS_PORT=443 \
SS_METHOD=chacha20-ietf-poly1305 \
SS_PLUGIN=v2ray-plugin \
SS_PLUGIN_OPTS="server;tls" \
sudo bash deploy-ss.sh
```

### CLI arguments

```bash
sudo bash deploy-ss.sh \
  -p 443 \
  -m chacha20-ietf-poly1305 \
  -P v2ray-plugin \
  -o "server;tls"
```

### Available Options

| Option              | Description                                 | Default         |
|---------------------|---------------------------------------------|-----------------|
| `-p`, `SS_PORT`      | Port to listen                              | `8388`          |
| `-m`, `SS_METHOD`    | Encryption method                           | `aes-256-gcm`   |
| `-a`, `SS_LISTEN_ADDR` | Listen address                            | `0.0.0.0`       |
| `-P`, `SS_PLUGIN`    | Plugin name (e.g., `v2ray-plugin`)          | *(empty)*       |
| `-o`, `SS_PLUGIN_OPTS`| Plugin options (e.g., `server;tls`)        | *(empty)*       |

## ✅ Health Check (Nginx)

After running the script, a lightweight Nginx server will be deployed and listen on port 80.

You can verify that your server is accessible from the public internet:

```bash
curl http://<server-ip>
# should return:
# Hello, world!
```

This is useful for basic firewall/NAT/port forwarding diagnosis.

## 📦 Requirements

- Linux (Ubuntu, Debian, CentOS, etc.)
- `curl`, `openssl`, `docker` (auto-installed if missing)
- qrencode (optional, for displaying QR codes)
