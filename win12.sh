#!/bin/bash
# ============================================
# 🚀 Auto Installer: Windows 12 on Docker + Cloudflare Tunnel
# ============================================

set -e

echo "=== 🔧 Menjalankan sebagai root ==="
if [ $EUID -ne 0 ]; then
  echo "Script ini butuh akses root. Jalankan dengan: sudo bash $0"
  exit 1
fi

echo
echo "=== 📦 Update & Install Docker Compose ==="
apt update -y
apt install docker-compose -y
systemctl enable docker
systemctl start docker

echo
echo "=== 📂 Membuat direktori kerja dockercom ==="
mkdir -p /root/dockercom
cd /root/dockercom

echo
echo "=== 🧾 Membuat file windows.yml ==="
cat > windows.yml << EOF
version: '3.9'
services:
  windows:
    image: dockurr/windows
    container_name: windows
    environment:
      VERSION: "12"
      USERNAME: "MASTER"
      PASSWORD: "admin@123"
      RAM_SIZE: "8G"
      CPU_CORES: "4"
    devices:
      - /dev/kvm
      - /dev/net/tun
    cap_add:
      - NET_ADMIN
    ports:
      - 8006:8006
      - 3389:3389/tcp
      - 3389:3389/udp
    volumes:
      - /tmp/windows-storage:/storage
    restart: always
    stop_grace_period: 2m
EOF

echo
echo "=== ✅ File windows.yml berhasil dibuat (Windows 12) ==="
cat windows.yml

echo
echo "=== 🚀 Menjalankan Windows 12 container ==="
docker-compose -f windows.yml up -d

echo
echo "=== ☁️ Instalasi Cloudflare Tunnel ==="
if [ ! -f /usr/local/bin/cloudflared ]; then
  wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -O /usr/local/bin/cloudflared
  chmod +x /usr/local/bin/cloudflared
fi

echo
echo "=== 🌍 Membuat tunnel publik untuk akses web & RDP ==="
# Matikan proses tunnel lama jika ada
pkill cloudflared || true

nohup cloudflared tunnel --url http://localhost:8006 > /var/log/cloudflared_web.log 2>&1 &
nohup cloudflared tunnel --url tcp://localhost:3389 > /var/log/cloudflared_rdp.log 2>&1 &

echo "Menunggu link tunnel..."
sleep 10

CF_WEB=$(grep -o 'https://[a-zA-Z0-9.-]*\.trycloudflare\.com' /var/log/cloudflared_web.log | head -n 1)
CF_RDP=$(grep -o 'tcp://[a-zA-Z0-9.-]*\.trycloudflare\.com:[0-9]*' /var/log/cloudflared_rdp.log | head -n 1)

echo
echo "=============================================="
echo "🎉 Instalasi Windows 12 Selesai!"
echo 

if [ -n "$CF_WEB" ]; then
  echo "🌍 Web Console (UI):"
  echo "$CF_WEB"
else
  echo "⚠️ Link web tidak ditemukan. Cek log: tail /var/log/cloudflared_web.log"
fi

if [ -n "$CF_RDP" ]; then
  echo
  echo "🖥️ Remote Desktop (RDP):"
  echo "$CF_RDP"
fi

echo
echo "🔑 Username: MASTER"
echo "🔒 Password: admin@123"
echo "=============================================="
