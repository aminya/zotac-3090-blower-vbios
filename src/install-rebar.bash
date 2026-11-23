#!/usr/bin/env bash
set -euo pipefail

output=${1:?usage: sudo bash src/install-rebar.bash BUILD-DIRECTORY}
[[ $EUID == 0 ]] || { echo 'Run as root' >&2; exit 1; }
[[ -f $output/initramfs.img && -f $output/rebar-test.cfg && -f $output/fallback.cfg ]] || { echo 'Build files missing' >&2; exit 1; }
grub-script-check "$output/rebar-test.cfg"
[[ ! -e /boot/grub/custom.cfg && ! -L /boot/grub/custom.cfg ]] || { echo '/boot/grub/custom.cfg already exists; preserve it and review manually' >&2; exit 1; }
[[ ! -e /boot/nvidia-vbios-rebar-test ]] || { echo '/boot/nvidia-vbios-rebar-test already exists; preserve it and review manually' >&2; exit 1; }
fallback=$(awk '$1 == "initrd" {print $2}' "$output/fallback.cfg")
[[ $fallback == /boot/nvidia-vbios/*/initramfs.img && -f $fallback ]] || { echo 'Unsupported or missing fallback image' >&2; exit 1; }
expected=$(awk 'NR == 1 {print $1}' "$output/SHA256SUMS")
[[ $(sha256sum "$fallback" | cut -d ' ' -f 1) == "$expected" ]] || { echo 'Fallback image changed since build' >&2; exit 1; }
expected_test=$(awk 'NR == 2 {print $1}' "$output/SHA256SUMS")
[[ $(sha256sum "$output/initramfs.img" | cut -d ' ' -f 1) == "$expected_test" ]] || { echo 'Test image changed since build' >&2; exit 1; }
install -d -m 700 /boot/nvidia-vbios-rebar-test
install -m 600 "$output/initramfs.img" /boot/nvidia-vbios-rebar-test/initramfs.img
install -m 600 "$output/rebar-test.cfg" /boot/grub/custom.cfg
sha256sum /boot/nvidia-vbios-rebar-test/initramfs.img /boot/grub/custom.cfg
echo 'Test entry installed. Existing GRUB default was not changed.'
