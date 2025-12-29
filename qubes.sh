#!/bin/bash
# =========================================================
# ⚠️ EXPERIMENTAL: Qubes OS on Docker (qemus/qemu)
# =========================================================

set -e

# 1. Setup Directory
echo "=== 📂 Menyiapkan direktori kerja ==="
mkdir -p /root/qubes-docker
cd /root/qubes-docker
mkdir -p ./storage

# 2. Download Qubes OS ISO
# Catatan: File ini berukuran ~6GB. Pastikan penyimpanan cukup.
if [ ! -f "qubes.iso" ]; then
    echo "📥 Downloading Qubes OS ISO..."
    wget -O qubes.iso mirrors.edge.kernel.org
fi

# 3. Create Docker Compose file
# Qubes OS membutuhkan RAM besar (minimal 16GB) dan dukungan Nested Virtualization.
echo "=== 🧾 Membuat file qubes.yml ==="
cat > qubes.yml <<EOF
version: "3.9"
services:
  qemu:
    image: qemus/qemu
    container_name: qubes_os
    environment:
      RAM_SIZE: "16G"
      CPU_CORES: "4"
      DISK_SIZE: "128G"
    devices:
      - /dev/kvm
    cap_add:
      - NET_ADMIN
    ports:
      - "8006:8006" # Web Interface (noVNC)
    volumes:
      - ./qubes.iso:/tmp/qubes.iso
      - ./storage:/storage
    # Argumen tambahan untuk mengaktifkan VMX/SVM agar Xen bisa berjalan
    command: >
      -drive file=/tmp/qubes.iso,media=cdrom,readonly=on
      -cpu host,vmx=on,svm=on 
      -m 16G 
      -enable-kvm
    restart: always
EOF

# 4. Launch
echo "=== 🚀 Menjalankan Qubes OS di qemus/qemu ==="
docker-compose -f qubes.yml up -d

echo "========================================================="
echo "✅ PROSES SELESAI"
echo "🌐 Akses via Browser: http://localhost:8006"
echo "⚠️  PERINGATAN: Qubes OS adalah hypervisor Type-1."
echo "   Menjalankannya di dalam Docker (Nested) sangat berat"
echo "   dan fitur AppVM di dalamnya mungkin tidak akan jalan."
echo "========================================================="
