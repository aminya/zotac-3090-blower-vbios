#!/usr/bin/bash
set -euo pipefail
set -v

# Move to the project root and load the configured tool versions.
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."
source ./src/versions.bash

# Require a relocated loader payload, rather than a ROM or JSON manifest.
PAYLOAD="${1:-$PWD/zotac-3090-blower-nvflash-fan-2000-loader.bin}"
if [[ "$PAYLOAD" != *-loader.bin ]]; then
	echo "Pass an Ampere -loader.bin payload, not a ROM or JSON manifest: $PAYLOAD" >&2
	if [[ "$PAYLOAD" == *.rom ]]; then
		CANDIDATE="${PAYLOAD%.rom}-loader.bin"
		if [[ -f "$CANDIDATE" ]]; then
			echo "Matching payload: $CANDIDATE" >&2
		fi
	fi
	exit 1
fi
if [[ ! -f "$PAYLOAD" || ! -s "$PAYLOAD" ]]; then
	echo "Payload is missing or empty: $PAYLOAD" >&2
	exit 1
fi
PAYLOAD="$(realpath "$PAYLOAD")"

# Download the loader and locate the matching NVIDIA driver source.
./src/download.bash
LOADER_DIR="$PWD/nvidia-linux-vbios-vix-loader-${NVBIOS_LOADER_VERSION}"
DRIVER_VERSION="$(nvidia-smi --query-gpu=driver_version --format=csv,noheader | head -n 1)"
DRIVER_SOURCE="/usr/src/nvidia-${DRIVER_VERSION}"
# Prepare a fresh profile for the 3090 and the current boot configuration.
# Enrollment replaces the complete GPU profile; this setup contains one GPU.
PROFILE_PARENT="$(mktemp -d "$PWD/gpu-profile-XXXXXX")"
PROFILE_DIR="$PROFILE_PARENT/profile"
sudo "$LOADER_DIR/nvbios" system prepare \
	--device 0000:07:00.0 "$PAYLOAD" \
	--driver-source "$DRIVER_SOURCE" \
	--userspace pacman --output "$PROFILE_DIR"

# Pause automatic rebuilds before replacing the existing READY profile.
sudo /usr/local/bin/nvbios system pre-install
sudo /usr/local/bin/nvbios system enroll --profile "$PROFILE_DIR/profile.json"

# Build and enable the new boot entry.
sudo /usr/local/bin/nvbios system reconcile --kernel "$(uname -r)"
sudo /usr/local/bin/nvbios system enable --kernel "$(uname -r)"

# Show readiness; runtime application can be checked after reboot.
sudo /usr/local/bin/nvbios system status

# Reboot manually after reviewing the loader status.
echo "Loader configured. Reboot to use the new boot entry."
echo "After reboot, run: sudo /usr/local/bin/nvbios system status"
