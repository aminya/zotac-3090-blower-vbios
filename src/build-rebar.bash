#!/usr/bin/env bash
set -euo pipefail

# Build a separate, opt-in image; never change a managed image or GRUB state.
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
base_image=${1:?usage: build-rebar.bash FALLBACK-INITRAMFS FALLBACK-CFG NEW-OUTPUT-DIR [RESIZE-CHECKOUT]}
base_cfg=${2:?missing fallback GRUB configuration}
output=${3:?missing new output directory}
resize_dir=${4:-$HOME/GitHub/geforce-bar1-resize-rebar-work}
expected=da12bcbb3bc4811264695ce1e0dd24aea340cb3a6ba27f03a44d76bec051d737
resize_script=$resize_dir/scripts/geforce-bar1-resize
[[ -f $base_image && -f $base_cfg && -f $resize_script ]] || { echo 'Missing input file' >&2; exit 1; }
[[ $(sha256sum "$resize_script" | cut -d ' ' -f 1) == "$expected" ]] || { echo 'Unexpected resize script hash' >&2; exit 1; }
[[ ! -e $output ]] || { echo "Output already exists: $output" >&2; exit 1; }
base_image=$(realpath "$base_image")
base_cfg=$(realpath "$base_cfg")
mkdir -m 700 -- "$output"
output=$(realpath "$output")
temp=$(mktemp -d)
trap 'rm -rf -- "$temp"' EXIT
mkdir -p "$temp/hooks/install" "$temp/source/scripts" "$temp/source/systemd" "$temp/source/config" "$temp/base" "$temp/new"
cp -- "$resize_script" "$temp/source/scripts/geforce-bar1-resize"
cp -- "$script_dir/rebar/geforce-bar1-resize-initrd.service" "$temp/source/systemd/"
cp -- "$script_dir/rebar/zotac-3090-initrd.conf" "$temp/source/config/zotac-3090-initrd.conf.example"
cp -- "$script_dir/rebar/mkinitcpio-hook" "$temp/hooks/install/geforce-bar1-resize"
GBR_SOURCE_DIR="$temp/source" mkinitcpio --nopost -D /usr/lib/initcpio -D "$temp/hooks" \
  -A geforce-bar1-resize -g "$temp/new.img"
(cd "$temp/base" && lsinitcpio -x "$base_image" >/dev/null)
(cd "$temp/new" && lsinitcpio -x "$temp/new.img" >/dev/null)
for file in etc/geforce-bar1-resize.conf usr/local/sbin/geforce-bar1-resize \
  usr/lib/systemd/system/geforce-bar1-resize-initrd.service \
  usr/lib/systemd/system/sysinit.target.wants/geforce-bar1-resize-initrd.service; do
  [[ ! -e $temp/base/$file && ! -L $temp/base/$file ]] || { echo "Fallback already contains $file" >&2; exit 1; }
done
(cd "$temp/new" && find . \( -type f -o -type l \) -print0 | while IFS= read -r -d '' file; do
  if [[ ! -e $temp/base/$file && ! -L $temp/base/$file ]]; then printf '%s\0' "$file"; fi
done | cpio --null -o -H newc --quiet | zstd -q -o "$temp/overlay.zst")
cat "$base_image" "$temp/overlay.zst" > "$output/initramfs.img"
mkdir "$temp/verify"
(cd "$temp/verify" && zstd -dq < "$temp/overlay.zst" | cpio -id --quiet)
cmp "$temp/verify/usr/local/sbin/geforce-bar1-resize" "$resize_script"
cmp "$temp/verify/etc/geforce-bar1-resize.conf" "$script_dir/rebar/zotac-3090-initrd.conf"
cmp "$temp/verify/usr/lib/systemd/system/geforce-bar1-resize-initrd.service" "$script_dir/rebar/geforce-bar1-resize-initrd.service"
[[ $(readlink "$temp/verify/usr/lib/systemd/system/sysinit.target.wants/geforce-bar1-resize-initrd.service") == ../geforce-bar1-resize-initrd.service ]]
[[ $(grep -c '^[[:space:]]*menuentry ' "$base_cfg") == 1 && $(grep -c '^[[:space:]]*linux ' "$base_cfg") == 1 && $(grep -c '^[[:space:]]*initrd ' "$base_cfg") == 1 ]] || { echo 'Unsupported fallback entry structure' >&2; exit 1; }
awk '
  /^[[:space:]]*menuentry / { print "menuentry '\''CachyOS NVIDIA ReBAR test (experimental)'\'' --class cachyos --class gnu-linux --class gnu --class os --id rebar-3090-test {"; next }
  /^[[:space:]]*savedefault[[:space:]]*$/ { next }
  /^[[:space:]]*linux / { print $0 " geforce_bar1_initrd=1"; next }
  /^[[:space:]]*initrd / { print "    initrd /boot/nvidia-vbios-rebar-test/initramfs.img"; next }
  { print }
' "$base_cfg" > "$output/rebar-test.cfg"
grub-script-check "$output/rebar-test.cfg"
sha256sum "$base_image" "$output/initramfs.img" > "$output/SHA256SUMS"
cp -- "$base_cfg" "$output/fallback.cfg"
printf 'Built %s\nFallback entry copied to %s\n' "$output/initramfs.img" "$output/fallback.cfg"
echo 'This builds only: it does not install a GRUB entry or change the default.'
