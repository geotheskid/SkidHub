#!/usr/bin/env python3
"""SkidUX desktop applications — Linux Mint/Cinnamon integration."""
import os, sys, subprocess, pathlib, shutil, urllib.request, json
import gi
gi.require_version("Gtk","3.0")
from gi.repository import Gtk,Gdk,GLib,Gio,Pango

CSS = b"""
* { font-family: 'DejaVu Sans', sans-serif; }
window, .background { background-color:rgba(6,16,32,0.96); color:#e6f7ff; }
headerbar { background:rgba(12,29,52,0.94); color:#e6f7ff; border-bottom:1px solid #235a74; }
button { background:rgba(17,42,68,0.88); border:1px solid rgba(53,151,175,0.52); border-radius:12px; color:#e9f8ff; padding:11px 14px; transition:150ms ease-out; }
button:hover { background:rgba(26,103,129,0.91); border-color:#31f3fa; }
entry, textview, scrolledwindow, treeview { background:#0b1a30; color:#d9faff; border-radius:7px; }
label { color:#e6f7ff; }
.title { font-size:30px; font-weight:700; color:#61efff; }
.subtitle { color:#98bbd6; font-size:13px; }
.card { background:rgba(12,33,57,0.84); border:1px solid rgba(52,154,179,0.42); border-radius:18px; padding:18px; }
.dock { background:rgba(5,17,32,0.89); border-radius:20px; border:1px solid rgba(43,174,206,0.55); box-shadow:0 6px 22px rgba(0,0,0,0.34); }
"""
provider=Gtk.CssProvider();provider.load_from_data(CSS)
Gtk.StyleContext.add_provider_for_screen(Gdk.Screen.get_default(),provider,Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)

def launch(*args):
    try: subprocess.Popen(args, start_new_session=True)
    except Exception as e: dialog(str(e))
def dialog(message):
    d=Gtk.MessageDialog(message_type=Gtk.MessageType.INFO, buttons=Gtk.ButtonsType.OK, text=message);d.run();d.destroy()
def btn(text,fn):
    b=Gtk.Button(label=text); b.connect('clicked',lambda *_:fn());return b
def label(text,cls=None):
    w=Gtk.Label(label=text);w.set_xalign(0)
    if cls:w.get_style_context().add_class(cls)
    return w
def vbox(spacing=12):
    return Gtk.Box(orientation=Gtk.Orientation.VERTICAL,spacing=spacing)
def hbox(spacing=8):
    return Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL,spacing=spacing)
def appwin(title,width=940,height=630):
    win=Gtk.Window(title="SkidUX  |  "+title);win.set_default_size(width,height)
    win.set_border_width(18)
    visual=win.get_screen().get_rgba_visual()
    if visual and win.get_screen().is_composited():win.set_visual(visual)
    win.connect("destroy",Gtk.main_quit);return win
def header(title,subtitle):
    row=hbox(14)
    icon="/usr/share/skidux/brand/skidux-logo.png"
    if os.path.isfile(icon):
        img=Gtk.Image.new_from_file(icon)
        img.set_pixel_size(68)
        row.pack_start(img,False,False,0)
    b=vbox(4)
    b.pack_start(label(title,"title"),False,False,0)
    b.pack_start(label(subtitle,"subtitle"),False,False,0)
    row.pack_start(b,True,True,0)
    return row
def run(win):win.show_all();Gtk.main()

HOME=str(pathlib.Path.home())
class Explorer:
    def __init__(self):
        self.win=appwin("Explorer");self.cwd=HOME;root=vbox();self.win.add(root)
        root.pack_start(header("SKID EXPLORER","Files  /  Local storage"),False,False,0)
        nav=hbox();root.pack_start(nav,False,False,0)
        nav.pack_start(btn("⌂ Home",lambda:self.open(HOME)),False,False,0)
        nav.pack_start(btn("↑ Up",lambda:self.open(str(pathlib.Path(self.cwd).parent))),False,False,0)
        self.path=Gtk.Entry();self.path.set_text(HOME);self.path.connect("activate",lambda x:self.open(x.get_text()))
        nav.pack_start(self.path,True,True,0)
        nav.pack_start(btn("↻ Refresh",lambda:self.open(self.cwd)),False,False,0)
        nav.pack_start(btn("+ Folder",self.folder),False,False,0)
        nav.pack_start(btn("Delete",self.delete),False,False,0)
        self.store=Gtk.ListStore(str,str,str)
        self.view=Gtk.TreeView(model=self.store)
        for i,t in enumerate(("Name","Type","Size")):
            cell=Gtk.CellRendererText();col=Gtk.TreeViewColumn(t,cell,text=i);col.set_resizable(True);self.view.append_column(col)
        self.view.connect("row-activated",self.activated)
        pane=Gtk.ScrolledWindow();pane.add(self.view);root.pack_start(pane,True,True,0)
        self.open(HOME)
    def selected(self):
        model,it=self.view.get_selection().get_selected()
        return model[it][0] if it else None
    def open(self,path):
        try:
            path=os.path.abspath(os.path.expanduser(path))
            items=sorted(os.scandir(path),key=lambda x:(not x.is_dir(follow_symlinks=False),x.name.lower()))
            self.cwd=path;self.path.set_text(path);self.store.clear()
            for item in items:
                try:
                    directory=item.is_dir(follow_symlinks=False)
                    size="—" if directory else str(item.stat(follow_symlinks=False).st_size//1024)+" KB"
                    self.store.append([item.name,"Folder" if directory else "File",size])
                except OSError:pass
        except Exception as e: dialog("Cannot open folder: "+str(e))
    def activated(self,*args):
        n=self.selected()
        if not n:return
        p=os.path.join(self.cwd,n)
        if os.path.isdir(p):self.open(p)
        else:launch("xdg-open",p)
    def folder(self):
        d=Gtk.Dialog(title="New folder",transient_for=self.win);d.add_button("Cancel",Gtk.ResponseType.CANCEL);d.add_button("Create",Gtk.ResponseType.OK)
        e=Gtk.Entry();e.set_placeholder_text("Folder name");d.get_content_area().add(e);d.show_all()
        if d.run()==Gtk.ResponseType.OK:
            name=e.get_text().strip()
            if name and name not in (".","..") and "/" not in name:
                try:os.mkdir(os.path.join(self.cwd,name))
                except Exception as ex:dialog(str(ex))
        d.destroy();self.open(self.cwd)
    def delete(self):
        n=self.selected()
        if not n:return
        path=os.path.join(self.cwd,n)
        d=Gtk.MessageDialog(transient_for=self.win,message_type=Gtk.MessageType.QUESTION,buttons=Gtk.ButtonsType.YES_NO,text="Move '"+n+"' to Trash?")
        if d.run()==Gtk.ResponseType.YES:
            try:Gio.File.new_for_path(path).trash(None)
            except Exception as e:dialog("Trash failed: "+str(e))
        d.destroy();self.open(self.cwd)
class Browser:
    def __init__(self):
        self.win=appwin("Browser",900,460);b=vbox();self.win.add(b);b.pack_start(header("SKID BROWSER","Privacy controls and navigation powered by Firefox"),False,False,0)
        b.pack_start(label("Search the web or enter a URL"),False,False,0)
        self.q=Gtk.Entry();self.q.set_placeholder_text("Search or https://...")
        self.q.connect("activate",lambda *_:self.open());b.pack_start(self.q,False,False,0)
        row=hbox();b.pack_start(row,False,False,0)
        row.pack_start(btn("Open in Firefox",self.open),False,False,0);row.pack_start(btn("Private Window",lambda:launch("firefox","--private-window")),False,False,0)
        row.pack_start(btn("Downloads",lambda:launch("xdg-open",os.path.join(HOME,"Downloads"))),False,False,0)
        b.pack_start(label("Built on Firefox. Web content uses Firefox's security updates and browser engine."),False,False,0)
    def open(self):
        import urllib.parse
        q=self.q.get_text().strip()
        if not q:return
        url=q if q.startswith(("https://","http://")) else ("https://"+q if "." in q and " " not in q else "https://www.google.com/search?q="+urllib.parse.quote(q))
        launch("firefox",url)
class Store:
    def __init__(self):
        self.win=appwin("Store",960,550);v=vbox();self.win.add(v);v.pack_start(header("SKID STORE","Linux Mint applications • APT • Flatpak"),False,False,0)
        row=hbox();v.pack_start(row,False,False,0)
        self.q=Gtk.Entry();self.q.set_placeholder_text("Find an application");self.q.connect("activate",self.search);row.pack_start(self.q,True,True,0)
        row.pack_start(btn("Search",lambda:self.search()),False,False,0)
        row.pack_start(btn("Mint Software Manager",lambda:launch("mintinstall")),False,False,0)
        grid=Gtk.Grid(column_spacing=12,row_spacing=12);v.pack_start(grid,False,False,15)
        for idx,(name,pkg) in enumerate([("Firefox","firefox"),("VLC","vlc"),("GIMP","gimp"),("LibreOffice","libreoffice"),("Blender","blender"),("Inkscape","inkscape"),("OBS Studio","obs-studio"),("Steam","steam-installer")]):
            grid.attach(btn(name,lambda p=pkg:self.details(p)),idx%4,idx//4,1,1)
        v.pack_start(label("Package availability depends on configured Mint repositories and Flatpak sources."),False,False,0)
    def details(self,pkg):
        # The native package manager owns privilege elevation and actual installation.
        launch("mintinstall")
    def search(self,*_):
        import urllib.parse
        q=self.q.get_text().strip()
        if q:launch("mintinstall")
class AI:
    def __init__(self):
        self.win=appwin("AI",930,650);v=vbox();self.win.add(v);v.pack_start(header("SKID AI","Local model chat  /  Requires Ollama on 127.0.0.1:11434"),False,False,0)
        r=hbox();v.pack_start(r,False,False,0)
        r.pack_start(label("Model:"),False,False,0);self.model=Gtk.Entry();self.model.set_text("llama3.2");r.pack_start(self.model,True,True,0)
        self.buffer=Gtk.TextBuffer();tv=Gtk.TextView(buffer=self.buffer);tv.set_editable(False);tv.set_wrap_mode(Gtk.WrapMode.WORD)
        sc=Gtk.ScrolledWindow();sc.add(tv);v.pack_start(sc,True,True,0)
        r=hbox();v.pack_start(r,False,False,0);self.input=Gtk.Entry();self.input.set_placeholder_text("Ask Skid AI...")
        self.input.connect("activate",lambda *_:self.send());r.pack_start(self.input,True,True,0);r.pack_start(btn("Send",self.send),False,False,0)
        self.write("Skid AI\nConnect an Ollama model to enable chat. No AI model is secretly bundled or simulated.\n\n")
    def write(self,s):self.buffer.insert(self.buffer.get_end_iter(),s)
    def send(self):
        question=self.input.get_text().strip()
        if not question:return
        self.input.set_text("");self.write("You: "+question+"\nSkid AI: ")
        import threading
        def fetch():
            try:
                payload=json.dumps({"model":self.model.get_text().strip(),"prompt":question,"stream":False}).encode()
                request=urllib.request.Request("http://127.0.0.1:11434/api/generate",data=payload,headers={"Content-Type":"application/json"})
                with urllib.request.urlopen(request,timeout=45) as r:reply=json.load(r).get("response","(empty response)")
            except Exception as e:reply="Local model unavailable. Install/run Ollama and download a model first. ("+str(e)+")"
            GLib.idle_add(self.write,reply+"\n\n")
        threading.Thread(target=fetch,daemon=True).start()
class Settings:
    def __init__(self):
        self.win=appwin("Settings",800,540);v=vbox();self.win.add(v);v.pack_start(header("SKID SETTINGS","Personalize your SkidUX workspace"),False,False,0)
        v.pack_start(label("Wallpaper"),False,False,0);grid=Gtk.Grid(row_spacing=12,column_spacing=12);v.pack_start(grid,False,False,0)
        names=["skidux-brand.png","skidux-neon.svg","arctic.svg","violet.svg","cobalt.svg"]
        for i,n in enumerate(names):
            grid.attach(btn(n.replace("skidux-","").replace(".jpg","").replace(".svg","").title(),lambda x=n:self.wallpaper(x)),i%4,i//4,1,1)
        v.pack_start(btn("Display Settings",lambda:launch("cinnamon-settings","display")),False,False,0)
        v.pack_start(btn("Network Settings",lambda:launch("cinnamon-settings","network")),False,False,0)
        v.pack_start(btn("Touchpad & Mouse",lambda:launch("cinnamon-settings","mouse")),False,False,0)
        v.pack_start(btn("Input Diagnostics",lambda:launch("x-terminal-emulator","-e","sh","-c","skidux-input-report | less -R")),False,False,0)
        v.pack_start(btn("Performance Overview",lambda:launch("x-terminal-emulator","-e","sh","-c","skidux-performance; read x")),False,False,0)
        v.pack_start(btn("Sound Settings",lambda:launch("cinnamon-settings","sound")),False,False,0)
        v.pack_start(btn("System Information",lambda:launch("cinnamon-settings","info")),False,False,0)
    def wallpaper(self,n):
        p="/usr/share/backgrounds/skidux/"+n
        if not os.path.isfile(p):return dialog("Wallpaper unavailable: "+n)
        launch("gsettings","set","org.cinnamon.desktop.background","picture-uri","file://"+p)
        launch("gsettings","set","org.cinnamon.desktop.background","picture-uri-dark","file://"+p)
class Home:
    def __init__(self):
        self.win=appwin("Home",970,640);root=vbox(18);self.win.add(root)
        root.pack_start(header("SKIDUX","Your system. Your rules.  /  Built on Linux Mint Cinnamon"),False,False,0)
        root.pack_start(label("WORKSPACE", "subtitle"),False,False,0)
        grid=Gtk.Grid(column_spacing=14,row_spacing=14);root.pack_start(grid,False,False,0)
        apps=[("Explorer","explorer"),("Browser","browser"),("Skid Store","store"),("Skid AI","ai"),("Settings","settings"),("Terminal","terminal"),("Software Updates","updates"),("Install SkidUX","install")]
        for i,(name,action) in enumerate(apps):grid.attach(btn("◈  "+name,lambda a=action:call(a)),i%4,i//4,1,1)
        root.pack_start(label("Desktop applications use native Linux Mint system services and package tools."),False,False,0)
class Dock:
    def __init__(self):
        self.win=Gtk.Window(type=Gtk.WindowType.TOPLEVEL);self.win.set_decorated(False);self.win.set_keep_above(True)
        self.win.set_skip_taskbar_hint(True);self.win.set_type_hint(Gdk.WindowTypeHint.DOCK)
        self.win.set_resizable(False)
        visual=self.win.get_screen().get_rgba_visual()
        if visual and self.win.get_screen().is_composited():self.win.set_visual(visual)
        self.win.connect("destroy",Gtk.main_quit)
        row=hbox(6);row.set_border_width(8);row.get_style_context().add_class("dock");self.win.add(row)
        for title,action in [("◈ SkidUX","home"),("▣ Explorer","explorer"),("◎ Browser","browser"),("▦ Store","store"),("✧ AI","ai"),("⚙ Settings","settings")]:
            row.pack_start(btn(title,lambda a=action:call(a)),False,False,0)
        self.win.show_all();GLib.timeout_add(650,self.place)
    def place(self):
        screen=Gdk.Screen.get_default();monitor=screen.get_primary_monitor()
        if monitor<0:monitor=0
        rect=screen.get_monitor_geometry(monitor);w,h=self.win.get_size()
        self.win.move(rect.x+(rect.width-w)//2,rect.y+rect.height-h-24)
        return True
def call(which):
    if which in ("home","explorer","browser","store","ai","settings"):launch("skidux-app",which)
    elif which=="terminal":launch("gnome-terminal")
    elif which=="updates":launch("mintupdate")
    elif which=="install":launch("ubiquity")
def main():
    which=sys.argv[1] if len(sys.argv)>1 else "home"
    if which=="dock":Dock();Gtk.main();return
    item={"home":Home,"explorer":Explorer,"browser":Browser,"store":Store,"ai":AI,"settings":Settings}.get(which,Home)()
    run(item.win)
if __name__=="__main__":main()
