#!/usr/bin/env bash
# Preserve original Mint casper initramfs and append only updated Plymouth bitmap files.
set -euo pipefail
ISO="$1"
ROOT="$2"
WORK="$3"
ORIG="$WORK/initrd-original.lz"
OUT="$WORK/skidux-initrd.lz"
DIR="$WORK/skidux-initrd-unpack"
OVER="$WORK/skidux-initrd-overlay"
BRAND="$ROOT/usr/share/skidux/brand/skidux-logo.png"
rm -rf "$DIR" "$OVER"
mkdir -p "$DIR" "$OVER"
if ! xorriso -indev "$ISO" -osirrox on -extract /casper/initrd.lz "$ORIG" >/dev/null 2>&1; then
 echo "No casper/initrd.lz in ISO; retaining stock early boot image"
 exit 0
fi
if ! unmkinitramfs "$ORIG" "$DIR" >/dev/null 2>&1; then
 echo "Cannot decode source initramfs; preserving stock early boot image"
 exit 0
fi
echo "Plymouth images in source initrd:"
find "$DIR" -type f -iname '*.png' -path '*/plymouth/*' | head -30 || true
count=0
while IFS= read -r source; do
 case "$source" in
   */plymouth/themes/mint-logo/logo.png|*/plymouth/themes/mint-logo/mint-logo.png|*/plymouth/themes/mint-logo/watermark.png)
     rel=$(printf '%s' "$source" | sed "s|^$DIR/||; s|^main/||; s|^early/||; s|^early2/||")
     test -n "$rel" || continue
     mkdir -p "$OVER/$(dirname "$rel")"
     cp "$BRAND" "$OVER/$rel"
     count=$((count+1))
     ;;
 esac
done < <(find "$DIR" -type f -iname '*.png' -path '*/plymouth/*')
if [ "$count" -eq 0 ]; then
 echo "No compatible Mint Plymouth bitmap found; preserving original initrd"
 exit 0
fi
cp "$ORIG" "$OUT"
(
 cd "$OVER"
 find . -print0 | cpio --null --quiet -o -H newc
) >> "$OUT"
echo "Patched $count Plymouth logo(s) using appended CPIO; original initrd unchanged before overlay."
test -s "$OUT"
