#!/usr/bin/env bash
set -euo pipefail

if [[ $EUID == 0 ]]; then
	echo 'Run as your normal user; the AUR helper will request sudo when needed.' >&2
	exit 1
fi

if command -v paru >/dev/null 2>&1; then
	helper=paru
elif command -v yay >/dev/null 2>&1; then
	helper=yay
else
	echo 'Install an AUR helper (paru or yay) and rerun this script.' >&2
	exit 1
fi

"$helper" -S --needed gpu-unlock-firmware gpu-unlock-dkms
echo 'Packages installed. Follow gpu-unlock documentation to configure boot-time activation and rebuild the initramfs.'
