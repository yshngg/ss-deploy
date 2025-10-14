# ss-deploy

**ss-deploy** is a simple one-click deployment script for [shadowsocks-rust](https://github.com/shadowsocks/shadowsocks-rust).  
It supports major Linux distributions including Ubuntu, Debian, CentOS, and more.

## 🧩 Features

- 🔐 Secure random password generation using ssservice
- 🚀 Native systemd service installation
- ⚙️ Customizable via environment variables or CLI arguments
- 🔌 Plugin support (e.g., `v2ray-plugin`, `simple-obfs`)
- 🔁 Automatic service startup on system reboot
- 📄 Generates Shadowsocks config file
- 🔗 Outputs `ss://` URI and optional QR code for client import
- ✅ Deploys a minimal HTTP server for connectivity checks

## 🚀 Quick Start

Download and run the script in one line:

```bash
curl -fsSL https://raw.githubusercontent.com/yshngg/ss-deploy/main/deploy.sh | sudo bash
```

Once completed, you can:

- Access `http://<server-ip>` to verify network access (should return `Hello World!`)
- Use the displayed ss:// URI or QR code to configure your Shadowsocks client

## ⚙️ Custom Options

You can customize settings using either **environment variables** or **CLI arguments**:

### Environment variables

```bash
SS_PORT=443 \
SS_METHOD=chacha20-ietf-poly1305 \
SS_PLUGIN=v2ray-plugin \
SS_PLUGIN_OPTS="server;tls" \
sudo bash deploy.sh
```

### CLI arguments

```bash
sudo bash deploy.sh \
  -p 443 \
  -m chacha20-ietf-poly1305 \
  -P v2ray-plugin \
  -o "server;tls"
```

### Available Options

| Option              | Description                                 | Default         |
|---------------------|---------------------------------------------|-----------------|
| `-p`, `SS_PORT`      | Port to listen                              | `8388`          |
| `-m`, `SS_METHOD`    | Encryption method                           | `chacha20-ietf-poly1305` |
| `-a`, `SS_LISTEN_ADDR` | Listen address                            | `0.0.0.0`       |
| `-P`, `SS_PLUGIN`    | Plugin name (e.g., `v2ray-plugin`)          | *(empty)*       |
| `-o`, `SS_PLUGIN_OPTS`| Plugin options (e.g., `server;tls`)        | *(empty)*       |

## ✅ Health Check

The script installs a lightweight HTTP server (using netcat) that listens on port 80.

You can verify that your server is accessible from the public internet:

```bash
curl http://<server-ip>
# should return:
# Hello World!
```

This helps diagnose network connectivity, firewall rules, and NAT/port forwarding.

## 📦 Requirements

- Linux with systemd (Ubuntu, Debian, CentOS, etc.)
- `curl` for downloading files
- `nc` ([ncat](https://nmap.org/ncat/)) for the health check server
- Open port `80` in your security group, and the port specified when running the script with the `-p` flag or the `SS_PORT` environment variable
- qrencode (optional, for displaying QR codes)
