#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
ISO_NAME="linuxmint-22.3-cinnamon-64bit.iso"
MIRROR="https://pub.linuxmint.io/stable/22.3"
OUT="$PWD/dist"
WORK="$PWD/work"
mkdir -p "$OUT" "$WORK"
printf '\nDisk space before preparation:\n'; df -h .
sudo apt-get update -qq
sudo apt-get install -y -qq xorriso squashfs-tools curl ca-certificates coreutils file
cd "$WORK"
curl --fail --location --retry 4 --retry-delay 5 -C - -o sha256sum.txt "$MIRROR/sha256sum.txt"
curl --fail --location --retry 4 --retry-delay 5 -C - -o "$ISO_NAME" "$MIRROR/$ISO_NAME"
awk -v name="$ISO_NAME" '$2==name || $2=="*"name { print $1 "  " name; found=1 } END { if (!found) exit 1 }' sha256sum.txt | sha256sum -c -
file "$ISO_NAME"
xorriso -indev "$ISO_NAME" -ls /casper | tee casper-files.txt
xorriso -indev "$ISO_NAME" -osirrox on -extract /casper/filesystem.squashfs filesystem-original.squashfs
sudo unsquashfs -f -d rootfs filesystem-original.squashfs
# Free disk before writing the new compressed image.
rm -f filesystem-original.squashfs
sudo mkdir -p rootfs/usr/share/backgrounds/skidux rootfs/usr/share/applications rootfs/usr/local/bin rootfs/etc/xdg/autostart rootfs/etc/skel/Desktop
sudo tee rootfs/usr/share/backgrounds/skidux/skidux-neon.svg >/dev/null <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="1920" height="1080" viewBox="0 0 1920 1080">
<defs>
<linearGradient id="night" x2=".9" y2="1"><stop stop-color="#030714"/><stop offset=".55" stop-color="#102951"/><stop offset="1" stop-color="#030712"/></linearGradient>
<linearGradient id="cyan" x2="1" y2="0"><stop stop-color="#17e7f0"/><stop offset="1" stop-color="#3268ff"/></linearGradient>
<radialGradient id="halo"><stop stop-color="#1d62b8" stop-opacity=".54"/><stop offset="1" stop-color="#071027" stop-opacity="0"/></radialGradient>
</defs>
<rect width="1920" height="1080" fill="url(#night)"/>
<ellipse cx="1410" cy="425" rx="690" ry="550" fill="url(#halo)"/>
<g stroke="url(#cyan)" fill="none" opacity=".75"><path stroke-width="5" d="M-80 860 C360 470 530 1040 1030 700 S1660 720 2040 385"/><path stroke-width="3" d="M-80 920 C350 530 550 1090 1050 770 S1620 810 2040 440"/></g>
<text x="150" y="370" fill="#e9fbff" font-family="DejaVu Sans,sans-serif" font-weight="bold" font-size="148">SkidUX</text>
<text x="158" y="425" fill="#51e5f9" font-family="DejaVu Sans,sans-serif" font-size="26" letter-spacing="11">OPERATING SYSTEM</text>
<text x="158" y="475" fill="#9fbdd9" font-family="DejaVu Sans,sans-serif" font-size="23">POWERED BY LINUX MINT</text>
</svg>
SVG
for name in arctic violet cobalt; do
  case "$name" in
    arctic) from='#092a40'; to='#00becd';;
    violet) from='#230f45'; to='#a044e2';;
    cobalt) from='#061b51'; to='#187df2';;
  esac
  sudo tee "rootfs/usr/share/backgrounds/skidux/$name.svg" >/dev/null <<SVG
<svg xmlns="http://www.w3.org/2000/svg" width="1920" height="1080" viewBox="0 0 1920 1080"><defs><linearGradient id="g" x2="1" y2="1"><stop stop-color="$from"/><stop offset="1" stop-color="$to"/></linearGradient></defs><rect width="1920" height="1080" fill="url(#g)"/><text x="130" y="420" fill="#f0faff" font-family="DejaVu Sans,sans-serif" font-weight="bold" font-size="140">SkidUX</text></svg>
SVG
done
sudo tee rootfs/usr/local/bin/skidux-appearance >/dev/null <<'SCRIPT'
#!/bin/sh
# Keep Mint's functional Cinnamon desktop and make only appearance changes.
gsettings set org.cinnamon.desktop.interface gtk-theme 'Mint-Y-Dark' 2>/dev/null || true
gsettings set org.cinnamon.desktop.interface icon-theme 'Mint-Y' 2>/dev/null || true
gsettings set org.cinnamon.desktop.background picture-uri 'file:///usr/share/backgrounds/skidux/skidux-neon.svg' 2>/dev/null || true
SCRIPT
sudo chmod 755 rootfs/usr/local/bin/skidux-appearance
sudo tee rootfs/usr/local/bin/skidux-wallpapers >/dev/null <<'SCRIPT'
#!/bin/sh
choice=$(zenity --list --title='SkidUX Wallpapers' --text='Choose a wallpaper' --column=Wallpaper Neon Arctic Violet Cobalt) || exit 0
case "$choice" in
 Neon) path=skidux-neon.svg;;
 Arctic) path=arctic.svg;;
 Violet) path=violet.svg;;
 Cobalt) path=cobalt.svg;;
 *) exit 0;;
esac
gsettings set org.cinnamon.desktop.background picture-uri "file:///usr/share/backgrounds/skidux/$path"
SCRIPT
sudo chmod 755 rootfs/usr/local/bin/skidux-wallpapers
sudo tee rootfs/etc/xdg/autostart/skidux-appearance.desktop >/dev/null <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=SkidUX Appearance
Exec=/usr/local/bin/skidux-appearance
OnlyShowIn=X-Cinnamon;
NoDisplay=true
X-GNOME-Autostart-enabled=true
DESKTOP
sudo tee rootfs/usr/share/applications/skidux-store.desktop >/dev/null <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=Skid Store
Comment=Linux Mint Software Manager
Exec=mintinstall
Icon=mintinstall
Categories=System;PackageManager;
Terminal=false
DESKTOP
sudo tee rootfs/usr/share/applications/skidux-wallpapers.desktop >/dev/null <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=SkidUX Wallpapers
Comment=Choose SkidUX wallpapers
Exec=skidux-wallpapers
Icon=preferences-desktop-wallpaper
Categories=Settings;DesktopSettings;
Terminal=false
DESKTOP
sudo cp rootfs/usr/share/applications/skidux-wallpapers.desktop rootfs/etc/skel/Desktop/SkidUX-Wallpapers.desktop
sudo chmod 755 rootfs/etc/skel/Desktop/SkidUX-Wallpapers.desktop
# Deliberately preserve Mint's native installer, bootloader, casper settings, all applications and package manager.
sudo mksquashfs rootfs filesystem.squashfs -noappend -comp xz -b 1M -processors 4 -quiet
test -s filesystem.squashfs
printf '\nNew compressed root filesystem:\n'; ls -lh filesystem.squashfs
# xorriso replay retains the official EFI/BIOS boot layout and volume label.
xorriso -indev "$ISO_NAME" -outdev "$OUT/SkidUX_LinuxMint_LIVE_amd64.iso" \
  -map "$WORK/filesystem.squashfs" /casper/filesystem.squashfs \
  -boot_image any replay
test -s "$OUT/SkidUX_LinuxMint_LIVE_amd64.iso"
file "$OUT/SkidUX_LinuxMint_LIVE_amd64.iso"
xorriso -indev "$OUT/SkidUX_LinuxMint_LIVE_amd64.iso" -report_el_torito plain | tee "$OUT/BOOT-REPORT.txt"
( cd "$OUT" && sha256sum SkidUX_LinuxMint_LIVE_amd64.iso > SkidUX_LinuxMint_LIVE_amd64.iso.sha256 )
printf '\nISO COMPLETE\n'; ls -lh "$OUT"; df -h .
