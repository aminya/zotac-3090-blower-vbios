#!/usr/bin/bash
set -euo pipefail

# move to the project root.
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

source "./src/versions.bash"

# Download
./src/download.bash

# Choose the NVFlash index and preserve the existing sysfs dump.
NVFLASH_INDEX="${1:-}"
OUTPUT_FILE="${2:-zotac-3090-blower-nvflash.rom}"
if [[ -z "$NVFLASH_INDEX" ]]; then
	# List adapters using NVFlash's own indices before selecting one.
	sudo ./nvflash/x64/nvflash --list
	echo "Select the NVFlash index for the RTX 3090 at PCI 0000:07:00.0."
	read -r -p "NVFlash index: " NVFLASH_INDEX
fi
if [[ ! "$NVFLASH_INDEX" =~ ^[0-9]+$ ]]; then
	echo "Invalid NVFlash index: $NVFLASH_INDEX" >&2
	exit 1
fi
if [[ -e "$OUTPUT_FILE" || -L "$OUTPUT_FILE" ]]; then
	echo "Refusing to overwrite: $OUTPUT_FILE" >&2
	exit 1
fi

# Save the selected GPU's VBIOS and inspect whether the editor recognizes it.
sudo ./nvflash/x64/nvflash "--index=$NVFLASH_INDEX" --save "$OUTPUT_FILE"
sha256sum "$OUTPUT_FILE"
"./nvidia-vbios-vix-editor-${NVBIOS_VERSION}/nvbios" inspect "$OUTPUT_FILE"
