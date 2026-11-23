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
PROFILE_DIR="$PWD/gpu-profile"

# Prepare a profile for the 3090; stop if the driver or payload is unsupported.
sudo "$LOADER_DIR/nvbios" system prepare \
	--device 0000:07:00.0 "$PAYLOAD" \
	--driver-source "$DRIVER_SOURCE" \
	--userspace pacman --output "$PROFILE_DIR"

# Install and enroll the loader, then build and enable its separate boot entry.
sudo "$LOADER_DIR/nvbios" system install --repository "$LOADER_DIR"
sudo /usr/local/bin/nvbios system enroll --profile "$PROFILE_DIR/profile.json"
sudo /usr/local/bin/nvbios system reconcile --kernel "$(uname -r)"
sudo /usr/local/bin/nvbios system enable --kernel "$(uname -r)"
sudo /usr/local/bin/nvbios system status

# Reboot manually after reviewing the loader status.
echo "Loader configured. Reboot to use the new boot entry."
