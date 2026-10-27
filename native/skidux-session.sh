#!/usr/bin/env bash
# SkidUX is an independent desktop session, not a Cinnamon panel overlay.
set -euo pipefail
export XDG_CURRENT_DESKTOP=SkidUX
export XDG_SESSION_DESKTOP=skidux
export DESKTOP_SESSION=skidux
export GTK_THEME=Adwaita:dark
export XDG_MENU_PREFIX=skidux-
export SKIDUX_SESSION=1
mkdir -p "$HOME/.config/skidux" "$HOME/.cache/skidux"
if command -v dbus-update-activation-environment >/dev/null 2>&1; then
  dbus-update-activation-environment --systemd DISPLAY XAUTHORITY XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP DESKTOP_SESSION || true
fi
if command -v picom >/dev/null 2>&1; then
  picom --config /etc/skidux/picom.conf --daemon || true
fi
if command -v feh >/dev/null 2>&1; then
  feh --bg-fill /usr/share/backgrounds/skidux/skidux-brand.png || true
fi
openbox --config-file /etc/skidux/openbox-rc.xml &
exec /usr/local/bin/skidux-shell
