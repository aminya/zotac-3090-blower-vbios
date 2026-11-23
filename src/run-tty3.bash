#!/usr/bin/bash
set -euo pipefail

# Run from a text console; stopping the display manager ends the graphical session.
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# Stop the desktop and unload each loaded NVIDIA module in dependency order.
sudo systemctl stop display-manager
for module in nvidia_drm nvidia_uvm nvidia_modeset nvidia; do
	if [[ -d "/sys/module/$module" ]]; then
		if ! sudo modprobe -r "$module"; then
			echo "Could not unload $module. Open GPU devices and sessions:" >&2
			sudo fuser -v /dev/nvidia* /dev/dri/* 2>&1 || true
			loginctl list-sessions || true
			exit 1
		fi
	fi
done

# Save the ROM once the driver has been unloaded.
"$SCRIPT_DIR/run.bash" 0

# Restart the system after reviewing the save and inspection output.
echo "Backup finished. Run 'sudo reboot' to restore the desktop and NVIDIA driver."
