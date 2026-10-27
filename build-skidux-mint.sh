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
gsettings set org.cinnamon.theme name 'SkidUX' 2>/dev/null || true
gsettings set org.cinnamon.desktop.interface gtk-theme 'Mint-Y-Dark' 2>/dev/null || true
gsettings set org.cinnamon.desktop.interface icon-theme 'Mint-Y' 2>/dev/null || true
gsettings set org.cinnamon.desktop.background picture-uri 'file:///usr/share/backgrounds/skidux/skidux-neon.svg' 2>/dev/null || true
gsettings set org.cinnamon.desktop.background picture-uri-dark 'file:///usr/share/backgrounds/skidux/skidux-neon.svg' 2>/dev/null || true
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

# Install native SkidUX desktop apps, not just a wallpaper.
sudo install -m 0755 "$GITHUB_WORKSPACE/skidux-app.py" rootfs/usr/local/bin/skidux-app
sudo mkdir -p rootfs/etc/xdg/autostart rootfs/usr/share/skidux rootfs/usr/share/themes/SkidUX/cinnamon rootfs/usr/share/icons/hicolor/scalable/apps
sudo tee rootfs/usr/share/icons/hicolor/scalable/apps/skidux.svg >/dev/null <<'SKIDICON'
<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128"><rect width="128" height="128" rx="30" fill="#08152a"/><path d="M95 30H50C22 30 17 64 48 66H78C104 68 102 102 73 102H30" fill="none" stroke="#22e9f2" stroke-width="17" stroke-linecap="round"/><path d="M90 21L109 41M27 92L46 111" stroke="#e7fcff" stroke-width="8"/></svg>
SKIDICON
for app in home explorer browser store ai settings; do
  case "$app" in
    home) title="SkidUX Home"; category="Utility";;
    explorer) title="Skid Explorer"; category="System";;
    browser) title="Skid Browser"; category="Network";;
    store) title="Skid Store"; category="System";;
    ai) title="Skid AI"; category="Utility";;
    settings) title="Skid Settings"; category="Settings";;
  esac
  sudo tee "rootfs/usr/share/applications/skidux-$app.desktop" >/dev/null <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=$title
Exec=/usr/local/bin/skidux-app $app
Icon=skidux
Categories=$category;
Terminal=false
StartupNotify=true
EOF
done
# Replace plain Mint Store launcher with the real SkidUX storefront.
sudo tee rootfs/usr/share/applications/skidux-store.desktop >/dev/null <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=Skid Store
Exec=/usr/local/bin/skidux-app store
Icon=skidux
Categories=System;PackageManager;
Terminal=false
DESKTOP
sudo tee rootfs/etc/xdg/autostart/skidux-dock.desktop >/dev/null <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=SkidUX Dock
Exec=/usr/local/bin/skidux-app dock
OnlyShowIn=X-Cinnamon;
X-GNOME-Autostart-enabled=true
Terminal=false
DESKTOP
# Do not replace Linux Mint's graphics, display manager, live account or installer.
# Mint's existing theme is copied and recolored to retain working Cinnamon widgets.
if [ -d rootfs/usr/share/themes/Mint-Y-Dark/cinnamon ]; then
  sudo cp -a rootfs/usr/share/themes/Mint-Y-Dark/cinnamon/. rootfs/usr/share/themes/SkidUX/cinnamon/
elif [ -d rootfs/usr/share/themes/Mint-Y/cinnamon ]; then
  sudo cp -a rootfs/usr/share/themes/Mint-Y/cinnamon/. rootfs/usr/share/themes/SkidUX/cinnamon/
fi
if [ -f rootfs/usr/share/themes/SkidUX/cinnamon/cinnamon.css ]; then
  sudo sed -i -e 's/#4a4a4a/#10253d/g' -e 's/#2b2b2b/#0b182d/g' -e 's/#383838/#10253d/g' rootfs/usr/share/themes/SkidUX/cinnamon/cinnamon.css
fi
sudo tee rootfs/usr/share/skidux/README.txt >/dev/null <<'TXT'
SkidUX is a customized Linux Mint Cinnamon desktop.
Skid Explorer is a local file manager with browsing, file opening, new folders and Trash.
Skid Browser delegates web rendering and private browsing to Firefox.
Skid Store integrates with Linux Mint Software Manager.
Skid AI requires separately installed Ollama and a downloaded model.
TXT

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
