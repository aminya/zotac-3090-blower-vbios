#!/usr/bin/bash
set -euo pipefail

# Move to the project root.
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

# Require a relocated loader payload, rather than a ROM or JSON manifest.
if [[ $# -lt 1 ]]; then
	echo 'Usage: bash src/load.bash PAYLOAD-loader.bin [KERNEL ...]' >&2
	exit 1
fi
PAYLOAD=$1
shift
kernels=("$@")
if ((${#kernels[@]} == 0)); then kernels=("$(uname -r)"); fi
for kernel in "${kernels[@]}"; do
	[[ $kernel =~ ^[A-Za-z0-9._+-]+$ && -d /usr/lib/modules/$kernel ]] || {
		echo "Kernel modules not found: $kernel" >&2
		exit 1
	}
done
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
if ! command -v jq >/dev/null 2>&1; then
	echo "jq is required to configure boot generation retention." >&2
	exit 1
fi
PAYLOAD="$(realpath "$PAYLOAD")"

# Use the installed loader for preparation as well as enrollment. This preserves
# local compatibility fixes and avoids silently using an older downloaded copy.
LOADER=/usr/local/bin/nvbios
[[ -x $LOADER ]] || {
	echo "Installed loader missing: $LOADER" >&2
	exit 1
}
DRIVER_VERSION="$(nvidia-smi --query-gpu=driver_version --format=csv,noheader | head -n 1)"
DRIVER_SOURCE="/usr/src/nvidia-${DRIVER_VERSION}"
# Prepare a fresh profile for the 3090 and the current boot configuration.
# Enrollment replaces the complete GPU profile; this setup contains one GPU.
PROFILE_PARENT="$(mktemp -d "$PWD/gpu-profile-XXXXXX")"
PROFILE_DIR="$PROFILE_PARENT/profile"
sudo "$LOADER" system prepare \
	--device 0000:07:00.0 "$PAYLOAD" \
	--driver-source "$DRIVER_SOURCE" \
	--userspace pacman --output "$PROFILE_DIR"

# Retention is global, not per kernel. Multi-kernel profiles use the maximum
# supported limit, but users should check that all desired entries survive.
retention=2
if ((${#kernels[@]} > 1)); then retention=3; fi
sudo sh -c 'jq --argjson keep "$2" '\''del(.boot.kernel_package) | .retain_boot_generations = $keep'\'' "$1" > "$1.tmp" && mv -- "$1.tmp" "$1"' sh "$PROFILE_DIR/profile.json" "$retention"

# Pause automatic rebuilds before replacing the existing READY profile.
sudo /usr/local/bin/nvbios system pre-install
sudo /usr/local/bin/nvbios system enroll --profile "$PROFILE_DIR/profile.json"

# Build and enable the new boot entry.
for kernel in "${kernels[@]}"; do
	sudo "$LOADER" system reconcile --kernel "$kernel"
done
sudo "$LOADER" system enable --kernel "${kernels[0]}"

# Show readiness; runtime application can be checked after reboot.
sudo /usr/local/bin/nvbios system status

# Reboot manually after reviewing the loader status.
echo "Loader configured. Reboot to use the new boot entry."
echo "After reboot, run: sudo /usr/local/bin/nvbios system status"
echo "Retention is global across kernels; check all desired entries and retention warnings after boot."
echo "Rebuild the separate ReBAR entry for each updated kernel before using it."
