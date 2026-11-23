#!/usr/bin/bash
set -e

NVBIOS_VERSION=0.1.46
NVFLASH_VERSION=5.867

# download nvbios editor
if [[ ! -d "./nvidia-vbios-vix-editor-${NVBIOS_VERSION}" ]]; then
	curl -LJO "https://github.com/Panchovix/nvidia-vbios-vix-editor/releases/download/v${NVBIOS_VERSION}/nvidia-vbios-vix-editor-${NVBIOS_VERSION}-linux-x86_64.tar.gz"
	tar -xzf "./nvidia-vbios-vix-editor-${NVBIOS_VERSION}-linux-x86_64.tar.gz"
	rm "./nvidia-vbios-vix-editor-${NVBIOS_VERSION}-linux-x86_64.tar.gz"
fi

# download nvflash
if [[ ! -d "./nvflash" ]]; then
	curl -LJO "https://us8-dl.techpowerup.com/files/ijA4sRs02bghkI_DA4C94g/1795441984/nvflash_${NVFLASH_VERSION}_linux.zip"
	unzip "./nvflash_${NVFLASH_VERSION}_linux.zip" -d "./nvflash"
	rm "./nvflash_${NVFLASH_VERSION}_linux.zip"
	chmod +x "./nvflash/x64/nvflash"
fi

sudo "nvflash/x64/nvflash" --list
