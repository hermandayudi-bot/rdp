#!/bin/bash
# ============================================
# 🚀 Auto Installer: Kali Linux Desktop on Docker + Cloudflare Tunnel
# ============================================

set -e

echo "=== 🔧 Menjalankan sebagai root ==="
if [ "$EUID" -ne 0 ]; then
  echo "Script ini butuh akses root. Jalankan dengan: sudo bash install-kali-cloudflare.sh"
  exit 1
fi

echo
echo "=== 📦 Update & Install Docker Compose ==="
apt update -y
apt install docker-compose -y

systemctl enable docker
systemctl start docker

echo
echo "=== 📂 Membuat direktori kerja kalicom ==="
mkdir -p /root/kalicom
cd /root/kalicom

echo
echo "=== 🧾 Membuat file kali.yml ==="
cat > kali.yml <<'EOF'
version: "3.9"
services:
  kali:
    image: kasmweb/kali-rolling-desktop:1.15.0
    container_name: kali_linux
    environment:
      VNC_PW: "admin@123"
    ports:
      - "8006:8006"
      - "6901:6901" # Web UI (HTTPS/NoVNC)
      - "3389:3389" # RDP (Optional)
    shm_size: "2g"
    restart: always
EOF

echo
echo "=== ✅ File kali.yml berhasil dibuat ==="

echo
echo "=== 🚀 Menjalankan Kali Linux container ==="
docker-compose -f kali.yml up -d

echo
echo "=== ☁️ Instalasi Cloudflare Tunnel ==="
if [ ! -f "/usr/local/bin/cloudflared" ]; then
  wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -O /usr/local/bin/cloudflared
  chmod +x /usr/local/bin/cloudflared
fi

echo
echo "=== 🌍 Membuat tunnel publik untuk akses Web Desktop ==="
# Using --no-tls-verify because Kasm images use self-signed certs for port 6901
nohup cloudflared tunnel --url https://localhost:6901 --no-tls-verify > /var/log/cloudflared_kali.log 2>&1 &
sleep 8

CF_URL=$(grep -o "https://[a-zA-Z0-9.-]*\.trycloudflare\.com" /var/log/cloudflared_kali.log | head -n 1)

echo
echo "=============================================="
echo "🎉 Instalasi Selesai!"
echo
if [ -n "$CF_URL" ]; then
  echo "🌍 Kali Web Desktop (Browser):"
  echo "    ${CF_URL}"
else
  echo "⚠️ Tidak menemukan link Cloudflare"
  echo "    Cek log: tail -f /var/log/cloudflared_kali.log"
fi

echo
echo "🔑 Username: kasm_user"
echo "🔒 Password: admin@123"
echo
echo "Catatan:"
echo "1. Gunakan link di atas untuk membuka Kali di browser."
echo "2. Untuk menginstal tools: sudo apt update && sudo apt install kali-linux-default"
echo
echo "Untuk melihat status container:"
echo "  docker ps"
echo
echo "=== ✅ Kali Linux siap digunakan! ==="
echo "=============================================="
