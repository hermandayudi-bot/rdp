#!/bin/bash
# ============================================
# 🚀 Auto Installer: Tails OS on QEMU + Cloudflare Tunnel
# ============================================

set -e

echo "=== 🔧 Menjalankan sebagai root ==="
if [ "$EUID" -ne 0 ]; then
  echo "Script ini butuh akses root. Jalankan dengan: sudo bash install-tails-qemu.sh"
  exit 1
fi

echo
echo "=== 📦 Update & Install Docker Compose ==="
apt update -y
apt install docker-compose wget -y

systemctl enable docker
systemctl start docker

echo
echo "=== 📂 Membuat direktori kerja qemu ==="
mkdir -p /root/docker-qemu
cd /root/docker-qemu
mkdir -p ./qemu

echo
echo "=== 🧾 Membuat file tails.yml ==="
cat > tails.yml <<'EOF'
version: "3.9"
services:
  qemu:
    image: qemux/qemu
    container_name: qemu
    environment:
      BOOT: "tails"
      DISK_SIZE: "9999G"
      RAM_SIZE: "7G"
      CPU_CORES: "4"
    devices:
      - /dev/kvm
      - /dev/net/tun
    cap_add:
      - NET_ADMIN
    ports:
      - "8006:8006"
    volumes:
      - ./qemu:/storage
    restart: always
    stop_grace_period: 2m
EOF

echo
echo "=== ✅ File tails.yml berhasil dibuat ==="
cat tails.yml

echo
echo "=== 🚀 Menjalankan Tails OS di QEMU ==="
docker-compose -f tails.yml up -d

echo
echo "=== ☁️ Instalasi Cloudflare Tunnel ==="
if [ ! -f "/usr/local/bin/cloudflared" ]; then
  wget -q github.com -O /usr/local/bin/cloudflared
  chmod +x /usr/local/bin/cloudflared
fi

echo
echo "=== 🌍 Membuat tunnel publik untuk akses Web Console ==="
# Menghapus log lama jika ada
rm -f /var/log/cloudflared_web.log

nohup cloudflared tunnel --url http://localhost:8006 > /var/log/cloudflared_web.log 2>&1 &
sleep 10

CF_WEB=$(grep -o "https://[a-zA-Z0-9.-]*\.trycloudflare\.com" /var/log/cloudflared_web.log | head -n 1)

echo
echo "=============================================="
echo "🎉 Instalasi Tails di QEMU Selesai!"
echo
if [ -n "$CF_WEB" ]; then
  echo "🌍 Akses Tails via Browser (Web Console):"
  echo "    ${CF_WEB}"
else
  echo "⚠️ Gagal mendapatkan link Cloudflare."
  echo "    Cek log manual: tail -f /var/log/cloudflared_web.log"
fi

echo
echo "Untuk melihat status container:"
echo "  docker ps"
echo
echo "Untuk melihat log Tails/QEMU:"
echo "  docker logs -f qemu"
echo
echo "=== ✅ Tails OS siap digunakan! ==="
echo "=============================================="
