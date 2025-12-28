#!/bin/bash
# ============================================
# 🚀 Updated Auto Installer: Windows 11 on Docker + Cloudflare
# ============================================
set -e

echo === 🔧 Menjalankan sebagai root ===
if [ $EUID -ne 0 ]; then
  echo Script ini butuh akses root. Jalankan dengan: sudo bash install.sh
  exit 1
fi

echo === 📦 Update & Install Docker Compose ===
apt update -y
apt install docker-compose -y
systemctl enable docker
systemctl start docker

echo === 📂 Membuat direktori kerja dockercom ===
mkdir -p /root/dockercom
cd /root/dockercom

echo === 🧾 Membuat file windows.yml dengan DISK_SIZE 128G ===
cat > windows.yml << EOF
version: '3.9'
services:
  windows:
    image: dockurr/windows
    container_name: windows
    environment:
      VERSION: "11"
      DISK_SIZE: "128G"    # <--- Change this value to your preferred size (e.g., 256G, 512G)
      USERNAME: "MASTER"
      PASSWORD: "admin@123"
      RAM_SIZE: "7G"
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

echo === 🚀 Menjalankan Windows 11 container ===
# Use --force-recreate to ensure disk changes apply if container exists
docker-compose -f windows.yml up -d --force-recreate

echo === ☁️ Instalasi Cloudflare Tunnel ===
if [ ! -f /usr/local/bin/cloudflared ]; then
  wget -q github.com -O /usr/local/bin/cloudflared
  chmod +x /usr/local/bin/cloudflared
fi

echo === 🌍 Membuat tunnel publik ===
# Kill old tunnel processes if they exist
pkill cloudflared || true
nohup cloudflared tunnel --url http://localhost:8006 > /var/log/cloudflared_web.log 2>&1 &
nohup cloudflared tunnel --url tcp://localhost:3389 > /var/log/cloudflared_rdp.log 2>&1 &

sleep 10
CF_WEB=$(grep -o 'https://[a-zA-Z0-9.-]*\.trycloudflare\.com' /var/log/cloudflared_web.log | head -n 1)
CF_RDP=$(grep -o 'tcp://[a-zA-Z0-9.-]*\.trycloudflare\.com:[0-9]*' /var/log/cloudflared_rdp.log | head -n 1)

echo ==============================================
echo 🎉 Instalasi Selesai dengan Penyimpanan 128G!
echo 🌍 Web Console: ${CF_WEB:-"Check /var/log/cloudflared_web.log"}
echo 🖥️ RDP Tunnel: ${CF_RDP:-"Check /var/log/cloudflared_rdp.log"}
echo 🔑 Username: MASTER | 🔒 Password: admin@123
echo ==============================================
