"""Keeps the CurseForge zip up to date by itself: every 10 seconds it looks at the addon folders; when a file has changed and nothing changed for 20 seconds
(you are done saving), it builds the zip again and copies it to C:\\Users\\SaphiresSilver\\Downloads\\curse\\forever.
Run: python tools/watch_curseforge.py   (or double-click tools/watch_curseforge.bat)"""
import os
import shutil
import socket
import subprocess
import sys
import time

# only one copy runs (a second one, for example the one started with Windows, stops at once)
_lock = socket.socket()
try:
    _lock.bind(("127.0.0.1", 47654))
except OSError:
    sys.exit(0)

HERE = os.path.dirname(os.path.abspath(__file__))
ADDONS = os.path.dirname(os.path.dirname(HERE))
DEST = os.path.join(os.path.expanduser("~"), "Downloads", "curse", "forever")
SKIP = {".git", "tools", "lod", ".claude"}


def stamp():
    """The newest change time of the addon files that go into the zip."""
    newest = 0
    for name in os.listdir(ADDONS):
        if name != "SeviathsUsefulTools" and not name.startswith("SeviathsUsefulTools_"):
            continue
        for d, dirs, files in os.walk(os.path.join(ADDONS, name)):
            dirs[:] = [x for x in dirs if not (x in SKIP)]
            for f in files:
                try:
                    newest = max(newest, os.path.getmtime(os.path.join(d, f)))
                except OSError:
                    pass
    return newest


def build():
    r = subprocess.run([sys.executable, os.path.join(HERE, "package_curseforge.py")], capture_output=True, text=True, creationflags=0x08000000, stdin=subprocess.DEVNULL)
    out = (r.stdout or "").strip().splitlines()
    zpath = out[-1].split(" ")[1] if out and out[-1].startswith("wrote ") else None
    # the path may hold spaces: take everything between "wrote " and the file count
    if out and out[-1].startswith("wrote "):
        zpath = out[-1][6:].rsplit(" ", 2)[0]
        os.makedirs(DEST, exist_ok=True)
        shutil.copy(zpath, DEST)
        print(time.strftime("%H:%M:%S"), "zip updated:", os.path.basename(zpath), flush=True)
    else:
        print("build failed:", r.stdout, r.stderr, flush=True)


last_built = 0
build()
last_built = stamp()
while True:
    time.sleep(10)
    s = stamp()
    if s > last_built and time.time() - s > 20:
        build()
        last_built = s
