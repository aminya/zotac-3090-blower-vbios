#!/usr/bin/env bash
set -euo pipefail

output=${1:?usage: sudo bash src/install-rebar.bash BUILD-DIRECTORY}
[[ $EUID == 0 ]] || {
	echo 'Run as root' >&2
	exit 1
}
[[ -f $output/initramfs.img && -f $output/rebar.cfg && -f $output/fallback.cfg && -f $output/SHA256SUMS ]] || {
	echo 'Build files missing; rebuild the ReBAR image first' >&2
	exit 1
}
grub-script-check "$output/rebar.cfg"
fallback=$(awk '$1 == "initrd" {print $2}' "$output/fallback.cfg")
destination=$(awk '$1 == "initrd" {print $2}' "$output/rebar.cfg")
entry_id=$(sed -n "s/.* --id \([^ ]*\) {.*/\1/p" "$output/rebar.cfg")
[[ $fallback =~ ^/boot/nvidia-vbios/(vbios-[A-Za-z0-9._+-]+)/initramfs\.img$ && -f $fallback ]] || {
	echo 'Unsupported or missing fallback image' >&2
	exit 1
}
generation=${BASH_REMATCH[1]}
[[ $destination =~ ^/boot/(nvidia-vbios-rebar-[A-Za-z0-9._+-]+)/initramfs\.img$ ]] || {
	echo 'Unsupported ReBAR image path or entry ID' >&2
	exit 1
}
boot_dir=/boot/${BASH_REMATCH[1]}
[[ $entry_id =~ ^[A-Za-z0-9._-]+$ ]] || {
	echo 'Invalid entry ID' >&2
	exit 1
}
if [[ ! -f /boot/grub/nvidia-vbios-entries/$generation.cfg ]] || ! cmp -s "$output/fallback.cfg" "/boot/grub/nvidia-vbios-entries/$generation.cfg"; then
	echo 'Managed fallback entry changed since build' >&2
	exit 1
fi
expected=$(awk 'NR == 1 {print $1}' "$output/SHA256SUMS")
[[ $(sha256sum "$fallback" | cut -d ' ' -f 1) == "$expected" ]] || {
	echo 'Fallback image changed since build' >&2
	exit 1
}
expected=$(awk 'NR == 2 {print $1}' "$output/SHA256SUMS")
[[ $(sha256sum "$output/initramfs.img" | cut -d ' ' -f 1) == "$expected" ]] || {
	echo 'ReBAR image changed since build' >&2
	exit 1
}
[[ ! -e $boot_dir && ! -L $boot_dir ]] || {
	echo "Boot directory already exists: $boot_dir; preserve it and review manually" >&2
	exit 1
}
custom=/boot/grub/custom.cfg
[[ ! -L $custom ]] || {
	echo 'custom.cfg is a symlink; review manually' >&2
	exit 1
}
if [[ -e $custom ]]; then
	grub-script-check "$custom"
	if grep -Fq -- "--id $entry_id " "$custom"; then
		echo "GRUB entry already exists: $entry_id" >&2
		exit 1
	fi
fi
temp=$(mktemp /boot/grub/.rebar-custom-XXXXXX)
trap 'rm -f -- "$temp"' EXIT
if [[ -f $custom ]]; then cat "$custom" >"$temp"; fi
printf '\n' >>"$temp"
cat "$output/rebar.cfg" >>"$temp"
grub-script-check "$temp"
if [[ -f $custom ]]; then
	backup=$(mktemp /boot/grub/custom.cfg.rebar-backup-XXXXXX)
	cp -p -- "$custom" "$backup"
	echo "Previous GRUB custom entries backed up to $backup"
fi
install -d -m 700 "$boot_dir"
install -m 600 "$output/initramfs.img" "$destination"
chmod 600 "$temp"
mv -f -- "$temp" "$custom"
sha256sum "$destination" "$custom"
echo "Installed GRUB entry $entry_id. The saved default was not changed."
