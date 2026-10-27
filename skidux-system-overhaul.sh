#!/usr/bin/env bash
set -euo pipefail
ROOT="$1"
WORK="$2"
ORIGINAL_ISO="$3"
test -d "$ROOT/etc" || exit 3
ASSETS="$GITHUB_WORKSPACE/assets"
BRAND="$ROOT/usr/share/skidux/brand"
sudo mkdir -p "$BRAND" "$ROOT/usr/share/icons/hicolor/256x256/apps" "$ROOT/usr/share/pixmaps" "$ROOT/etc/lightdm" "$ROOT/etc/X11/xorg.conf.d" "$ROOT/etc/modules-load.d" "$ROOT/etc/default/grub.d" "$ROOT/usr/share/plymouth/themes/skidux" "$ROOT/boot/grub" "$ROOT/usr/local/bin"
test -s "$ASSETS/official-skidux-logo.jpg.b64"
base64 -d "$ASSETS/official-skidux-logo.jpg.b64" | sudo tee "$BRAND/official-logo.jpg" >/dev/null
sudo python3 - "$ROOT" "$WORK" <<'PY'
import sys,os
from PIL import Image,ImageDraw,ImageFont
root,work=sys.argv[1:]
brand=root+"/usr/share/skidux/brand"
im=Image.open(brand+"/official-logo.jpg").convert("RGB")
im.resize((256,256),Image.Resampling.LANCZOS).save(brand+"/skidux-logo.png")
im.resize((256,256),Image.Resampling.LANCZOS).save(root+"/usr/share/icons/hicolor/256x256/apps/skidux.png")
def font(size):
 path="/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
 return ImageFont.truetype(path,size) if os.path.exists(path) else ImageFont.load_default()
for name,w,h in [("login",1920,1080),("grub",1024,768)]:
 bg=Image.new("RGB",(w,h),(4,11,23))
 draw=ImageDraw.Draw(bg)
 for y in range(h):
  f=y/max(1,h-1)
  draw.line([(0,y),(w,y)],fill=(int(4+5*f),int(11+18*f),int(23+23*f)))
 size=int(min(w,h)*.30)
 icon=im.resize((size,size),Image.Resampling.LANCZOS)
 bg.paste(icon,((w-size)//2,int(h*.13)))
 draw.text((w//2,int(h*.17)+size+12),"SKIDUX",fill=(225,250,255),font=font(int(min(w,h)*.075)),anchor="mt")
 draw.text((w//2,int(h*.17)+size+int(min(w,h)*.11)),"OPERATING SYSTEM",fill=(72,222,235),font=font(int(min(w,h)*.025)),anchor="mt")
 path=brand+"/skidux-"+name+".png" if name=="login" else work+"/skidux-grub.png"
 bg.save(path,optimize=True)
PY
sudo cp "$BRAND/skidux-login.png" "$ROOT/usr/share/backgrounds/skidux/skidux-login.png"
sudo cp "$BRAND/skidux-login.png" "$ROOT/usr/share/backgrounds/skidux/skidux-brand.png"
# Brand Cinnamon's actual main menu applet without removing any other panel applets.
sudo python3 - "$ROOT" <<'PY'
import sys,json,pathlib
root=pathlib.Path(sys.argv[1])
path=root/"usr/share/cinnamon/applets/menu@cinnamon.org/settings-override.json"
path.parent.mkdir(parents=True,exist_ok=True)
try:
    data=json.loads(path.read_text()) if path.exists() else {}
except Exception:
    data={}
data.update({
    "menu-custom":{"default":True,"override-props":True},
    "menu-label":{"default":"SkidUX","override-props":True},
    "menu-icon":{"default":"/usr/share/icons/hicolor/256x256/apps/skidux.png",
                 "default_icon":"/usr/share/icons/hicolor/256x256/apps/skidux.png",
                 "override-props":True},
    "menu-icon-size":{"default":28,"override-props":True}
})
path.write_text(json.dumps(data,indent=2)+"\n")
PY

sudo tee "$ROOT/etc/lightdm/slick-greeter.conf" >/dev/null <<'EOF'
[Greeter]
background=/usr/share/skidux/brand/skidux-login.png
background-color=#04101f
logo=/usr/share/skidux/brand/skidux-logo.png
draw-user-backgrounds=false
draw-grid=false
show-hostname=false
theme-name=Mint-Y-Dark
icon-theme-name=Mint-Y
font-name=DejaVu Sans 11
show-clock=true
show-a11y=true
show-keyboard=true
show-power=true
enable-hidpi=auto
EOF
sudo mkdir -p "$ROOT/usr/share/doc/skidux"
sudo tee "$ROOT/usr/share/doc/skidux/BASE-SYSTEM-LICENSES.txt" >/dev/null <<'EOF'
SkidUX desktop is built on the open-source Linux Mint Cinnamon distribution.
Software packages retain their original copyright and licenses.
See /usr/share/doc/*/copyright for detailed license notices.
EOF
if test -e "$ROOT/etc/os-release"; then
 sudo sed -i -E 's/^NAME=.*/NAME="SkidUX"/; s/^PRETTY_NAME=.*/PRETTY_NAME="SkidUX 11"/' "$ROOT/etc/os-release"
fi
printf 'SkidUX 11\n' | sudo tee "$ROOT/etc/issue" >/dev/null
printf 'Welcome to SkidUX 11\n' | sudo tee "$ROOT/etc/motd" >/dev/null
printf 'skidux\n' | sudo tee "$ROOT/etc/hostname" >/dev/null
# Linux Mint's kernel already bundles modern ELAN/I2C/HID support.
# Request normal modules only, preserving all USB, Bluetooth and PS/2 input paths.
sudo tee "$ROOT/etc/modules-load.d/skidux-pointer-compat.conf" >/dev/null <<'EOF'
i2c_hid_acpi
hid_multitouch
elan_i2c
psmouse
usbhid
EOF
sudo tee "$ROOT/etc/X11/xorg.conf.d/40-skidux-pointer.conf" >/dev/null <<'EOF'
Section "InputClass"
    Identifier "SkidUX libinput touchpad"
    MatchIsTouchpad "on"
    Driver "libinput"
    Option "Tapping" "on"
    Option "DisableWhileTyping" "on"
EndSection
Section "InputClass"
    Identifier "SkidUX libinput mouse"
    MatchIsPointer "on"
    Driver "libinput"
EndSection
EOF
sudo tee "$ROOT/usr/local/bin/skidux-input-report" >/dev/null <<'EOF'
#!/bin/sh
echo 'SKIDUX INPUT DIAGNOSTICS'
cat /sys/class/dmi/id/product_name 2>/dev/null || true
cat /proc/bus/input/devices 2>/dev/null || true
lsmod | grep -Ei 'elan|i2c_hid|hid_multi|psmouse|usbhid|btusb' || true
command -v libinput >/dev/null && libinput list-devices 2>/dev/null || true
dmesg 2>/dev/null | grep -Ei 'elan|touchpad|i2c.hid|psmouse' | tail -35 || true
EOF
sudo chmod 755 "$ROOT/usr/local/bin/skidux-input-report"
sudo tee "$ROOT/usr/share/applications/skidux-input-report.desktop" >/dev/null <<'EOF'
[Desktop Entry]
Type=Application
Name=SkidUX Input Diagnostics
Comment=Check touchpad and mouse devices
Exec=sh -c 'skidux-input-report | less -R'
Terminal=true
Icon=input-mouse
Categories=Settings;HardwareSettings;
EOF
sudo mkdir -p "$ROOT/etc/sysctl.d"
sudo tee "$ROOT/etc/sysctl.d/98-skidux-performance.conf" >/dev/null <<'EOF'
# Keep kernel VM defaults; favor reusing cached filesystem information.
vm.vfs_cache_pressure=90
EOF
# Compressed RAM swap improves responsiveness on 4GB Lenovo 100w systems under memory pressure.
# Does not touch physical disks, partition tables or existing swapfiles.
sudo mkdir -p "$ROOT/etc/systemd/system/multi-user.target.wants" "$ROOT/usr/local/sbin"
sudo tee "$ROOT/usr/local/sbin/skidux-zram" >/dev/null <<'EOF'
#!/bin/sh
set -eu
[ -r /proc/meminfo ] || exit 0
command -v zramctl >/dev/null 2>&1 || exit 0
command -v modprobe >/dev/null 2>&1 || exit 0
if grep -q '/dev/zram' /proc/swaps 2>/dev/null; then exit 0; fi
modprobe zram 2>/dev/null || exit 0
[ -b /dev/zram0 ] || exit 0
kb=$(awk '/MemTotal:/{print $2}' /proc/meminfo)
[ -n "$kb" ] || exit 0
# 40% of real RAM, cap at 2GB compressed swap device.
bytes=$((kb * 1024 * 40 / 100))
[ "$bytes" -gt 2147483648 ] && bytes=2147483648
zramctl /dev/zram0 --algorithm lz4 --size "$bytes" 2>/dev/null || exit 0
mkswap -q /dev/zram0 2>/dev/null || exit 0
swapon -p 80 /dev/zram0 2>/dev/null || true
EOF
sudo chmod 755 "$ROOT/usr/local/sbin/skidux-zram"
sudo tee "$ROOT/etc/systemd/system/skidux-zram.service" >/dev/null <<'EOF'
[Unit]
Description=SkidUX lightweight compressed-memory swap
After=systemd-udev-settle.service
ConditionVirtualization=!container
[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/sbin/skidux-zram
TimeoutStartSec=8
[Install]
WantedBy=multi-user.target
EOF
sudo ln -sfn /etc/systemd/system/skidux-zram.service "$ROOT/etc/systemd/system/multi-user.target.wants/skidux-zram.service"
# Make sure a real Xorg libinput backend is present before publishing the ISO.
if ! test -f "$ROOT/usr/lib/xorg/modules/input/libinput_drv.so"; then
  echo "WARNING: Mint filesystem is missing Xorg libinput. Touchpads cannot be certified." >&2
fi

# Hide only the welcome tutorial; don't disable updates, accessibility or device services.
if test -f "$ROOT/etc/xdg/autostart/mintwelcome.desktop"; then
 sudo sed -i '/^Hidden=/d' "$ROOT/etc/xdg/autostart/mintwelcome.desktop"
 printf '\nHidden=true\n' | sudo tee -a "$ROOT/etc/xdg/autostart/mintwelcome.desktop" >/dev/null
fi
sudo tee "$ROOT/usr/local/bin/skidux-performance" >/dev/null <<'EOF'
#!/bin/sh
echo 'SKIDUX PERFORMANCE'
free -h
df -h /
ps -eo comm,rss --sort=-rss | head -18
EOF
sudo chmod 755 "$ROOT/usr/local/bin/skidux-performance"
sudo tee "$ROOT/etc/xdg/autostart/skidux-input-preferences.desktop" >/dev/null <<'EOF'
[Desktop Entry]
Type=Application
Name=SkidUX Input Preferences
Exec=/usr/local/bin/skidux-input-preferences
OnlyShowIn=X-Cinnamon;
NoDisplay=true
X-GNOME-Autostart-enabled=true
EOF
sudo tee "$ROOT/usr/local/bin/skidux-input-preferences" >/dev/null <<'EOF'
#!/bin/sh
if gsettings list-schemas | grep -qx org.cinnamon.desktop.peripherals.touchpad; then
 gsettings set org.cinnamon.desktop.peripherals.touchpad tap-to-click true 2>/dev/null || true
fi
EOF
sudo chmod 755 "$ROOT/usr/local/bin/skidux-input-preferences"
# Avoid editing Mint's live initrd (which contains vital casper drivers).
# Configure SkidUX theme for installed-system future initramfs regeneration.
if test -f "$ROOT/usr/share/plymouth/themes/mint-logo/mint-logo.plymouth"; then
 sudo cp -a "$ROOT/usr/share/plymouth/themes/mint-logo/." "$ROOT/usr/share/plymouth/themes/skidux/"
 sudo mv "$ROOT/usr/share/plymouth/themes/skidux/mint-logo.plymouth" "$ROOT/usr/share/plymouth/themes/skidux/skidux.plymouth"
 sudo sed -i -e 's/mint-logo/skidux/g' -e 's/Linux Mint/SkidUX/g' "$ROOT/usr/share/plymouth/themes/skidux/skidux.plymouth"
 sudo cp "$BRAND/skidux-logo.png" "$ROOT/usr/share/plymouth/themes/skidux/logo.png"
 sudo mkdir -p "$ROOT/etc/plymouth"
 printf '[Daemon]\nTheme=skidux\nShowDelay=0\n' | sudo tee "$ROOT/etc/plymouth/plymouthd.conf" >/dev/null
fi
sudo cp "$WORK/skidux-grub.png" "$ROOT/boot/grub/skidux-background.png"
sudo tee "$ROOT/etc/default/grub.d/98-skidux.cfg" >/dev/null <<'EOF'
GRUB_DISTRIBUTOR="SkidUX"
GRUB_TIMEOUT=5
GRUB_TIMEOUT_STYLE=menu
GRUB_BACKGROUND="/boot/grub/skidux-background.png"
EOF
mkdir -p "$WORK/skidux-boot"
for path in /boot/grub/grub.cfg /isolinux/txt.cfg /isolinux/isolinux.cfg /isolinux/menu.cfg; do
 target="$WORK/skidux-boot$path"
 mkdir -p "$(dirname "$target")"
 if xorriso -indev "$ORIGINAL_ISO" -osirrox on -extract "$path" "$target" >/dev/null 2>&1; then
  sed -i -e 's/Linux Mint/SkidUX/g' -e 's/Start Linux Mint/Start SkidUX/g' "$target"
 else
  rm -f "$target"
 fi
done
# Customize the visible firmware boot menu while retaining all original menu entries
# and kernel arguments for EFI/BIOS compatibility.
grub="$WORK/skidux-boot/boot/grub/grub.cfg"
if [ -s "$grub" ]; then
  tmp="$grub.new"
  cat > "$tmp" <<'EOF'
insmod png
insmod gfxterm
set gfxmode=auto
terminal_output gfxterm
if background_image /boot/grub/skidux-background.png; then
  set color_normal=white/black
  set menu_color_normal=white/black
  set menu_color_highlight=light-cyan/blue
fi
EOF
  cat "$grub" >> "$tmp"
  mv "$tmp" "$grub"
fi
echo 'SkidUX branded boot and hardware configuration prepared'
