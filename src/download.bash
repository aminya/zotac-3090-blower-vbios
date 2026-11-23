#!/usr/bin/bash
set -euo pipefail

# move to the project root.
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."


source "./src/versions.bash"

if [[ -z "${NVBIOS_VERSION:-}" ]] || [[ -z "${NVFLASH_VERSION:-}" ]]; then
	echo "nvbios and nvflash versions are required"
	exit 1
fi

# Download the VBIOS editor if needed.
if [[ ! -d "./nvidia-vbios-vix-editor-${NVBIOS_VERSION}" ]]; then
	curl -LJO "https://github.com/Panchovix/nvidia-vbios-vix-editor/releases/download/v${NVBIOS_VERSION}/nvidia-vbios-vix-editor-${NVBIOS_VERSION}-linux-x86_64.tar.gz"
	tar -xzf "./nvidia-vbios-vix-editor-${NVBIOS_VERSION}-linux-x86_64.tar.gz"
	rm "./nvidia-vbios-vix-editor-${NVBIOS_VERSION}-linux-x86_64.tar.gz"
fi

# Download the VBIOS loader if needed.
if [[ ! -d "./nvidia-linux-vbios-vix-loader" ]]; then
	curl -LJ -o "./nvidia-linux-vbios-vix-loader.tar.gz" "https://github.com/Panchovix/nvidia-linux-vbios-vix-loader/archive/8a6b9e3b21a96f86684dd0131d5bec73cd9adfd4.tar.gz"
	tar -xzf "./nvidia-linux-vbios-vix-loader.tar.gz"
	rm "./nvidia-linux-vbios-vix-loader.tar.gz"
fi

# Download NVFlash if needed.
if [[ ! -d "./nvflash" ]]; then
	curl -LJO "https://us8-dl.techpowerup.com/files/ijA4sRs02bghkI_DA4C94g/1795441984/nvflash_${NVFLASH_VERSION}_linux.zip"
	unzip "./nvflash_${NVFLASH_VERSION}_linux.zip" -d "./nvflash"
	rm "./nvflash_${NVFLASH_VERSION}_linux.zip"
	chmod +x "./nvflash/x64/nvflash"
fi
