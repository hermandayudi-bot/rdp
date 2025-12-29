#!/bin/bash
# =========================================================
# ⚠️ EXPERIMENTAL: Qubes OS on Docker (QEMU Emulation)
# =========================================================

set -e

# 1. Setup Directory
mkdir -p /root/qubes-docker
cd /root/qubes-docker

# 2. Download Qubes OS ISO (Latest 4.2.x)
# Note: This is a large (~6GB) download.
if [ ! -f "qubes.iso" ]; then
    echo "📥 Downloading Qubes OS ISO..."
    wget -O qubes.iso mirrors.edge.kernel.org
fi

# 3. Create Docker Compose file
# Requirements: Qubes needs at least 16GB RAM and 4+ cores to function well.
cat > qubes.yml <<EOF
version: "3.9"
services:
  qubes:
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
    # Custom command to boot the ISO and enable necessary CPU features for Xen
    command: >
      -drive file=/tmp/qubes.iso,media=cdrom,readonly=on
      -cpu host,vmx=on,svm=on 
      -m 16G 
      -enable-kvm
    restart: always
EOF

# 4. Launch
docker-compose -f qubes.yml up -d

echo "========================================================="
echo "🚀 Qubes OS is starting (Emulated via QEMU)"
echo "🌐 Access via Browser: http://localhost:8006"
echo "⚠️  WARNING: Qubes OS does not support nested virtualization well."
echo "   Internal VMs (AppVMs) will likely NOT start."
echo "========================================================="

