#!/usr/bin/bash
set -euo pipefail

# Locate the project and the configured editor version.
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."
source ./src/versions.bash

# Choose the original ROM and the new edited copy.
INPUT_ROM="${1:-zotac-3090-blower-nvflash.rom}"
OUTPUT_ROM="${2:-zotac-3090-blower-nvflash-1000rpm-10pct-45deg.rom}"
if [[ "$OUTPUT_ROM" != *.rom ]]; then
	echo "Output must have a .rom extension: $OUTPUT_ROM" >&2
	exit 1
fi
OUTPUT_PAYLOAD="${OUTPUT_ROM%.rom}-loader.bin"
if [[ ! -f "$INPUT_ROM" ]]; then
	echo "Input ROM not found: $INPUT_ROM" >&2
	exit 1
fi
if [[ -e "$OUTPUT_ROM" || -e "$OUTPUT_PAYLOAD" || -L "$OUTPUT_ROM" || -L "$OUTPUT_PAYLOAD" ]]; then
	echo "Output ROM or loader payload already exists; choose a new output name." >&2
	exit 1
fi

# Download the editor and save a copy with the same settings on both channels.
./src/download.bash
EDITOR="./nvidia-vbios-vix-editor-${NVBIOS_VERSION}/nvbios"
"$EDITOR" edit "$INPUT_ROM" "$OUTPUT_ROM" \
	--set fan_1_min_rpm=1000 --set fan_1_min_pct=10 \
	--set fan_1_curve_1_temp_c=45 --set fan_1_curve_1_rpm=1000 --set fan_1_curve_1_pct=10 \
	--set fan_2_min_rpm=1000 --set fan_2_min_pct=10 \
	--set fan_2_curve_1_temp_c=45 --set fan_2_curve_1_rpm=1000 --set fan_2_curve_1_pct=10

# Export the relocated Ampere payload for the in-memory loader.
"$EDITOR" normalize "$OUTPUT_ROM" "$OUTPUT_PAYLOAD" --representation ampere-relocated-v1
echo "Created $OUTPUT_ROM and $OUTPUT_PAYLOAD"
