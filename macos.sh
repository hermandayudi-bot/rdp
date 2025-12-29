#!/bin/bash
# ============================================
# 🚀 Auto Installer: macOS on Docker + Cloudflare Tunnel
# ============================================

set -e

echo "=== 🔧 Menjalankan sebagai root ==="
if [ "$EUID" -ne 0 ]; then
  echo "Script ini butuh akses root. Jalankan dengan: sudo bash install-macos-cloudflare.sh"
  exit 1
fi

echo
echo "=== 📦 Update & Install Docker Compose ==="
apt update -y
apt install docker-compose -y

systemctl enable docker
systemctl start docker

echo
echo "=== 📂 Membuat direktori kerja macos_docker ==="
mkdir -p /root/macos_docker
cd /root/macos_docker

echo
echo "=== 🧾 Membuat file macos.yml ==="
# Catatan: macOS memerlukan RAM minimal 4GB, disarankan 8GB+
cat > macos.yml <<'EOF'
version: "3.9"
services:
  macos:
    image: dockurr/macos
    container_name: macos
    environment:
      VERSION: "13"       # Versi macOS (Ventura). Bisa diubah ke "14" (Sonoma) atau "15" (Sequoia)
      DISK_SIZE: "64G"
      RAM_SIZE: "8G"
      CPU_CORES: "4"
    devices:
      - /dev/kvm
    cap_add:
      - NET_ADMIN
    ports:
      - "8006:8006"       # Web Viewer (NoVNC)
      - "5900:5900"       # VNC Port
    volumes:
      - /tmp/macos-storage:/storage
    restart: always
    stop_grace_period: 2m
EOF

echo
echo "=== ✅ File macos.yml berhasil dibuat ==="
cat macos.yml

echo
echo "=== 🚀 Menjalankan macOS container ==="
docker-compose -f macos.yml up -d

echo
echo "=== ☁️ Instalasi Cloudflare Tunnel ==="
if [ ! -f "/usr/local/bin/cloudflared" ]; then
  wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -O /usr/local/bin/cloudflared
  chmod +x /usr/local/bin/cloudflared
fi

echo
echo "=== 🌍 Membuat tunnel publik untuk akses Web & VNC ==="
# Membersihkan log lama jika ada
rm -f /var/log/cloudflared_web.log /var/log/cloudflared_vnc.log

nohup cloudflared tunnel --url http://localhost:8006 > /var/log/cloudflared_web.log 2>&1 &
nohup cloudflared tunnel --url tcp://localhost:5900 > /var/log/cloudflared_vnc.log 2>&1 &
sleep 10

CF_WEB=$(grep -o "https://[a-zA-Z0-9.-]*\.trycloudflare\.com" /var/log/cloudflared_web.log | head -n 1)
CF_VNC=$(grep -o "tcp://[a-zA-Z0-9.-]*\.trycloudflare\.com:[0-9]*" /var/log/cloudflared_vnc.log | head -n 1)

echo
echo "=============================================="
echo "🎉 Instalasi Selesai!"
echo
if [ -n "$CF_WEB" ]; then
  echo "🌍 Web Console (Akses via Browser):"
  echo "    ${CF_WEB}"
else
  echo "⚠️ Tidak menemukan link web Cloudflare (port 8006)"
  echo "    Cek log: tail -f /var/log/cloudflared_web.log"
fi

if [ -n "$CF_VNC" ]; then
  echo
  echo "🖥️  VNC Access (Screen Sharing) melalui Cloudflare:"
  echo "    ${CF_VNC}"
else
  echo "⚠️ Tidak menemukan link VNC Cloudflare (port 5900)"
  echo "    Cek log: tail -f /var/log/cloudflared_vnc.log"
fi

echo
echo "ℹ️  Info Penting:"
echo "  - Proses booting pertama kali akan memakan waktu untuk mendownload base image macOS."
echo "  - Cek progres download dengan perintah: docker logs -f macos"
echo
echo "Untuk melihat status container:"
echo "  docker ps"
echo
echo "Untuk menghentikan macOS:"
echo "  docker stop macos"
echo
echo "Untuk melihat link Cloudflare:"
echo "  grep 'trycloudflare' /var/log/cloudflared_*.log"
echo
echo "=== ✅ macOS di Docker siap digunakan! ==="
echo "=============================================="
