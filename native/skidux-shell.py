#!/usr/bin/env python3
"""SkidUX native X11 desktop shell. Openbox and system services provide the backend."""
import datetime
import os
import pathlib
import shutil
import signal
import subprocess
import sys
import threading
import time

import gi
gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")
from gi.repository import Gtk, Gdk, GLib

BASE = "/usr/share/skidux/brand"
ICON = BASE + "/skidux-logo.png"
WALLPAPER = "/usr/share/backgrounds/skidux/skidux-brand.png"
CSS = """
* { font-family: 'Inter', 'Noto Sans', 'DejaVu Sans', sans-serif; }
window { background-color: rgba(5, 14, 29, 0.96); color: #eaf9ff; }
.skid-glass { background-color: rgba(8, 23, 44, 0.92);
              border: 1px solid rgba(68, 216, 236, 0.34);
              border-radius: 18px; }
.skid-bar { background-color: rgba(5, 16, 32, 0.94); border-radius: 17px;
            border: 1px solid rgba(92, 210, 234, 0.30); }
.skid-title { font-weight: 800; font-size: 25px; color: #effeff; }
.skid-subtitle { color: #90adc6; font-size: 12px; }
.skid-label { color: #e9fbff; font-weight: 700; }
.skid-muted { color: #92aabd; }
button { border: 1px solid rgba(82, 167, 200, 0.27);
         border-radius: 12px; padding: 11px 13px; color:#eaf9ff;
         background-color:rgba(21,49,77,0.88); }
button:hover { background-color:rgba(33,98,126,0.96);
               border-color:rgba(58,227,250,0.88); }
entry { border-radius:12px; padding:11px 14px; background:#0c1e34;
        color:#efffff; border:1px solid rgba(64,192,212,0.42); }
scrollbar, scale { background:transparent; }
separator { background:rgba(97,189,219,0.23); }
"""
provider=Gtk.CssProvider()
provider.load_from_data(CSS.encode())
screen=Gdk.Screen.get_default()
if screen:
    Gtk.StyleContext.add_provider_for_screen(screen,provider,Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)
Gtk.Settings.get_default().set_property("gtk-application-prefer-dark-theme",True)

def spawn(*args):
    try:
        return subprocess.Popen(list(args),start_new_session=True,stdout=subprocess.DEVNULL,
                                stderr=subprocess.DEVNULL)
    except (FileNotFoundError,PermissionError):
        return None

def command_output(*args,timeout=3):
    try:
        return subprocess.check_output(list(args),stderr=subprocess.DEVNULL,
                                       timeout=timeout,text=True).strip()
    except (subprocess.SubprocessError,OSError):
        return ""

def button(text,callback,tip=None):
    b=Gtk.Button(label=text)
    b.connect("clicked",lambda *_:callback())
    if tip:b.set_tooltip_text(tip)
    return b

def text_label(text,style=None):
    x=Gtk.Label(label=text)
    x.set_xalign(0)
    if style:x.get_style_context().add_class(style)
    return x

def vertical(space=9):
    return Gtk.Box(orientation=Gtk.Orientation.VERTICAL,spacing=space)

def horizontal(space=8):
    return Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL,spacing=space)

def set_icon(window):
    if os.path.isfile(ICON):
        try:window.set_icon_from_file(ICON)
        except GLib.Error:pass

def screen_rect():
    display=Gdk.Display.get_default()
    mon=display.get_primary_monitor()
    if mon is None:mon=display.get_monitor(0)
    return mon.get_geometry()

def shell_window(width,height,hint=Gdk.WindowTypeHint.DOCK):
    w=Gtk.Window(type=Gtk.WindowType.TOPLEVEL)
    w.set_title("SkidUX")
    w.set_decorated(False)
    w.set_default_size(width,height)
    w.set_resizable(False)
    w.set_keep_above(True)
    w.set_skip_taskbar_hint(True)
    w.set_skip_pager_hint(True)
    w.set_type_hint(hint)
    visual=w.get_screen().get_rgba_visual()
    if visual and w.get_screen().is_composited():w.set_visual(visual)
    set_icon(w)
    return w

APP_LIST=[
    ("Explorer","explorer","▣"),
    ("Browser","browser","◎"),
    ("Skid Store","store","▦"),
    ("Skid AI","ai","✦"),
    ("Settings","settings","⚙"),
    ("Skid Terminal","terminal","⌘"),
    ("Text Editor","editor","▤"),
    ("Updates","updates","↻"),
    ("Performance","performance","◈"),
    ("Install SkidUX","install","↓")
]

def app_launch(action):
    if action in ("explorer","browser","store","ai","settings","terminal"):
        spawn("/usr/local/bin/skidux-app",action)
    elif action=="editor":
        for exe in ("xed","mousepad","gedit"):
            if shutil.which(exe):spawn(exe);break
    elif action=="updates":
        for exe in ("mintupdate","update-manager"):
            if shutil.which(exe):spawn(exe);break
    elif action=="performance":
        if shutil.which("xterm"):spawn("xterm","-fa","DejaVu Sans Mono","-fs","12","-e","sh","-c","skidux-performance; read x")
    elif action=="install":
        for exe in ("ubiquity","live-installer"):
            if shutil.which(exe):spawn(exe);break

class Launcher:
    def __init__(self,shell):
        self.shell=shell
        rect=screen_rect()
        self.win=shell_window(min(750,rect.width-22),min(600,rect.height-90),Gdk.WindowTypeHint.UTILITY)
        self.win.connect("focus-out-event",lambda *_:self.hide())
        outer=vertical(12)
        outer.set_border_width(20)
        outer.get_style_context().add_class("skid-glass")
        self.win.add(outer)
        logo=horizontal(12)
        if os.path.isfile(ICON):
            img=Gtk.Image.new_from_file(ICON)
            img.set_pixel_size(64)
            logo.pack_start(img,False,False,0)
        title=vertical(3)
        title.pack_start(text_label("SKIDUX","skid-title"),False,False,0)
        title.pack_start(text_label("Everything you need, right here.","skid-subtitle"),False,False,0)
        logo.pack_start(title,True,True,0)
        outer.pack_start(logo,False,False,4)
        self.search=Gtk.Entry()
        self.search.set_placeholder_text("Search SkidUX apps...")
        self.search.connect("changed",lambda *_:self.rebuild())
        self.search.connect("activate",lambda *_:self.launch_first())
        outer.pack_start(self.search,False,False,0)
        sc=Gtk.ScrolledWindow()
        sc.set_policy(Gtk.PolicyType.NEVER,Gtk.PolicyType.AUTOMATIC)
        outer.pack_start(sc,True,True,0)
        self.results=vertical(5)
        self.results.set_border_width(3)
        sc.add(self.results)
        footer=horizontal()
        footer.pack_start(text_label("SKIDUX 11  •  LIVE SYSTEM","skid-subtitle"),True,True,0)
        footer.pack_start(button("Shut down",lambda:self.power("poweroff")),False,False,0)
        footer.pack_start(button("Restart",lambda:self.power("reboot")),False,False,0)
        outer.pack_start(footer,False,False,0)
        self.matches=[]
        self.rebuild()
    def power(self,mode):
        self.hide()
        dialog=Gtk.MessageDialog(transient_for=self.shell.bar,flags=0,
                                 message_type=Gtk.MessageType.QUESTION,
                                 buttons=Gtk.ButtonsType.YES_NO,
                                 text="Confirm "+("shutdown" if mode=="poweroff" else "restart")+"?")
        choice=dialog.run()
        dialog.destroy()
        if choice==Gtk.ResponseType.YES:spawn("systemctl",mode)
    def rebuild(self):
        for child in self.results.get_children():self.results.remove(child)
        q=self.search.get_text().strip().lower()
        self.matches=[item for item in APP_LIST if not q or q in item[0].lower()]
        for name,action,symbol in self.matches:
            row=button("  "+symbol+"     "+name,lambda a=action:self.launch(a))
            row.set_halign(Gtk.Align.FILL)
            self.results.pack_start(row,False,False,2)
        self.results.show_all()
    def launch_first(self):
        if self.matches:self.launch(self.matches[0][1])
    def launch(self,action):
        self.hide()
        app_launch(action)
    def show(self):
        rect=screen_rect()
        width,height=self.win.get_size()
        self.win.move(rect.x+(rect.width-width)//2,rect.y+(rect.height-height)//2)
        self.win.show_all()
        self.search.set_text("")
        self.search.grab_focus()
        self.win.present()
    def hide(self):
        self.win.hide()
    def toggle(self):
        if self.win.get_visible():self.hide()
        else:self.show()

class ControlCenter:
    def __init__(self,shell):
        self.shell=shell
        self.win=shell_window(365,470,Gdk.WindowTypeHint.UTILITY)
        self.win.connect("focus-out-event",lambda *_:self.hide())
        root=vertical(13)
        root.set_border_width(18)
        root.get_style_context().add_class("skid-glass")
        self.win.add(root)
        root.pack_start(text_label("SKID CENTER","skid-title"),False,False,0)
        root.pack_start(text_label("Connectivity & quick controls","skid-subtitle"),False,False,0)
        self.wifi=button("Wi-Fi",self.toggle_wifi)
        self.bluetooth=button("Bluetooth",self.toggle_bluetooth)
        row=horizontal(8)
        row.pack_start(self.wifi,True,True,0)
        row.pack_start(self.bluetooth,True,True,0)
        root.pack_start(row,False,False,0)
        root.pack_start(button("Network settings",lambda:self.call_action("settings")),False,False,0)
        root.pack_start(text_label("Volume","skid-label"),False,False,0)
        self.volume=Gtk.Scale.new_with_range(Gtk.Orientation.HORIZONTAL,0,100,2)
        self.volume.set_draw_value(True)
        self.volume.connect("value-changed",self.on_volume)
        root.pack_start(self.volume,False,False,0)
        root.pack_start(text_label("Brightness","skid-label"),False,False,0)
        self.brightness=Gtk.Scale.new_with_range(Gtk.Orientation.HORIZONTAL,5,100,5)
        self.brightness.set_value(70)
        self.brightness.connect("value-changed",self.on_brightness)
        root.pack_start(self.brightness,False,False,0)
        bottom=horizontal()
        bottom.pack_start(button("Settings",lambda:self.call_action("settings")),True,True,0)
        bottom.pack_start(button("Power",self.open_power),True,True,0)
        root.pack_end(bottom,False,False,0)
    def call_action(self,action):
        self.hide()
        app_launch(action)
    def open_power(self):
        self.hide()
        self.shell.launcher.show()
    def toggle_wifi(self):
        state=command_output("nmcli","radio","wifi")
        spawn("nmcli","radio","wifi","off" if state=="enabled" else "on")
        GLib.timeout_add(800,self.refresh)
    def toggle_bluetooth(self):
        state=command_output("bluetoothctl","show")
        spawn("bluetoothctl","power","off" if "Powered: yes" in state else "on")
        GLib.timeout_add(800,self.refresh)
    def on_volume(self,scale):
        if shutil.which("pactl"):
            spawn("pactl","set-sink-volume","@DEFAULT_SINK@",str(int(scale.get_value()))+"%")
    def on_brightness(self,scale):
        if shutil.which("brightnessctl"):
            spawn("brightnessctl","set",str(int(scale.get_value()))+"%")
    def refresh(self):
        wifi=command_output("nmcli","radio","wifi")
        bt=command_output("bluetoothctl","show")
        self.wifi.set_label("Wi-Fi   "+("ON" if wifi=="enabled" else "OFF"))
        self.bluetooth.set_label("Bluetooth   "+("ON" if "Powered: yes" in bt else "OFF"))
        vol=command_output("pactl","get-sink-volume","@DEFAULT_SINK@")
        import re
        m=re.search(r"(\d+)%",vol)
        if m:
            self.volume.handler_block_by_func(self.on_volume)
            self.volume.set_value(int(m.group(1)))
            self.volume.handler_unblock_by_func(self.on_volume)
        return False
    def show(self):
        rect=screen_rect()
        self.win.show_all()
        width,height=self.win.get_size()
        self.win.move(rect.x+rect.width-width-16,rect.y+56)
        self.refresh()
        self.win.present()
    def hide(self):
        self.win.hide()
    def toggle(self):
        if self.win.get_visible():self.hide()
        else:self.show()

class Shell:
    def __init__(self):
        rect=screen_rect()
        self.top=shell_window(max(300,rect.width-24),46)
        self.top.set_name("SkidUX status")
        topbox=horizontal(10)
        topbox.set_border_width(4)
        topbox.get_style_context().add_class("skid-bar")
        self.top.add(topbox)
        topbox.pack_start(button("◈   SKIDUX",self.open_menu,"Open SkidMenu"),False,False,0)
        topbox.pack_start(text_label("WORKSPACE","skid-subtitle"),False,False,10)
        spacer=Gtk.Label()
        topbox.pack_start(spacer,True,True,0)
        self.clock=button("",self.open_center)
        self.status=button("Wi-Fi  •  Sound  •  Power",self.open_center)
        topbox.pack_end(self.status,False,False,0)
        topbox.pack_end(self.clock,False,False,0)
        self.bar=shell_window(650,70)
        dockbox=horizontal(7)
        dockbox.set_border_width(8)
        dockbox.get_style_context().add_class("skid-bar")
        self.bar.add(dockbox)
        for name,action,symbol in APP_LIST[:6]:
            dockbox.pack_start(button(symbol+"\n"+name,
                                       lambda a=action:app_launch(a)),True,True,0)
        dockbox.pack_end(button("⊞\nMenu",self.open_menu),False,False,0)
        self.launcher=Launcher(self)
        self.center=ControlCenter(self)
        self.top.connect("destroy",Gtk.main_quit)
        self.bar.connect("destroy",Gtk.main_quit)
        self.top.show_all()
        self.bar.show_all()
        self.reposition()
        self.tick()
        GLib.timeout_add_seconds(1,self.tick)
        GLib.timeout_add_seconds(5,self.reposition)
        # SIGUSR1 is bound to the Super key through SkidUX Openbox configuration.
        try:GLib.unix_signal_add(GLib.PRIORITY_DEFAULT,signal.SIGUSR1,self.signal_menu)
        except (AttributeError,ValueError):pass
    def signal_menu(self):
        self.open_menu()
        return GLib.SOURCE_CONTINUE
    def reposition(self):
        rect=screen_rect()
        self.top.resize(max(300,rect.width-24),46)
        self.top.move(rect.x+12,rect.y+7)
        w,h=self.bar.get_size()
        self.bar.move(rect.x+(rect.width-w)//2,rect.y+rect.height-h-12)
        return True
    def tick(self):
        self.clock.set_label(datetime.datetime.now().strftime("%a %b %d  •  %I:%M %p"))
        return True
    def open_menu(self):
        self.center.hide()
        self.launcher.toggle()
    def open_center(self):
        self.launcher.hide()
        self.center.toggle()

if __name__=="__main__":
    Shell()
    Gtk.main()
