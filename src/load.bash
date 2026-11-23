#!/usr/bin/bash
set -euo pipefail

# Move to the project root and load the configured tool versions.
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."
source ./src/versions.bash

# Download the loader and locate the matching NVIDIA driver source.
./src/download.bash
LOADER_DIR="$PWD/nvidia-linux-vbios-vix-loader-${NVBIOS_LOADER_VERSION}"
DRIVER_VERSION="$(nvidia-smi --query-gpu=driver_version --format=csv,noheader | head -n 1)"
DRIVER_SOURCE="/usr/src/nvidia-${DRIVER_VERSION}"
PAYLOAD="${1:-$PWD/zotac-3090-blower-nvflash-fan-2000-loader.bin}"
PAYLOAD="$(realpath "$PAYLOAD")"

# Prepare and enroll the 3090 payload, then build and enable its boot entry.
# Setup checks existing enrollment and stops if other enrolled GPUs need decisions.
PAYLOAD_SHA256="$(sha256sum "$PAYLOAD" | cut -d ' ' -f 1)"
sudo "$LOADER_DIR/nvbios" system setup --progress \
	--repository "$LOADER_DIR" \
	--kernel "$(uname -r)" --userspace pacman \
	--device 0000:07:00.0 "$PAYLOAD" "$PAYLOAD_SHA256" \
	--driver-source "$DRIVER_SOURCE"

# Show readiness; runtime application can be checked after reboot.
sudo /usr/local/bin/nvbios system status

# Reboot manually after reviewing the loader status.
echo "Loader configured. Reboot to use the new boot entry."
echo "After reboot, run: sudo /usr/local/bin/nvbios system status"
