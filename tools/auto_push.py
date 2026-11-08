"""Pushes the collected data to GitHub by itself after every reload or logout of the game.
The game writes the saved variables (WTF/Account/*/SavedVariables/SeviathsUsefulTools.lua) at /reload and at logout. When that file has changed and
stays unchanged for 15 seconds, this program bakes it into the addon (tools/bake_collected.py and bake_gold.py), makes a commit and pushes it to
PetalsOfIron/SeviathsUsefultools-forever, and builds the CurseForge zip again. Run: python tools/auto_push.py   (it keeps running; stop it with Ctrl+C)
"""
import glob
import os
import subprocess
import sys
import socket
import time

# only one copy runs: a second one (for example the one started with Windows while one is already running) stops at once
_lock = socket.socket()
try:
    _lock.bind(("127.0.0.1", 47653))
except OSError:
    sys.exit(0)

HERE = os.path.dirname(os.path.abspath(__file__))
ADDON = os.path.dirname(HERE)
FOREVER = os.path.abspath(os.path.join(ADDON, "..", "..", ".."))
GITDIR = os.path.join(os.path.expanduser("~"), "Projects", "sut-forever-gitdir")
SAVED = os.path.join(FOREVER, "WTF", "Account", "*", "SavedVariables", "SeviathsUsefulTools.lua")


def newest():
    t = 0
    for f in glob.glob(SAVED):
        try:
            t = max(t, os.path.getmtime(f))
        except OSError:
            pass
    return t


def run(*cmd):
    r = subprocess.run(list(cmd), cwd=ADDON, capture_output=True, text=True)
    return r.returncode, (r.stdout + r.stderr).strip()


def git(*a):
    return run("git", "--git-dir=" + GITDIR, "--work-tree=.", *a)


last = newest()
print("watching", SAVED, flush=True)
while True:
    time.sleep(10)
    t = newest()
    if t > last and time.time() - t > 15:
        last = t
        print(time.strftime("%H:%M:%S"), "saved data changed: baking", flush=True)
        run(sys.executable, os.path.join(HERE, "bake_collected.py"), os.path.join(HERE, "classic_seed.lua"), os.path.join(HERE, "crawl", "crawl_seed.lua"))
        run(sys.executable, os.path.join(HERE, "bake_gold.py"))
        run(sys.executable, os.path.join(HERE, "package_curseforge.py"))
        try:   # and the zip into the curse folder, where it is taken from
            import shutil
            dest = os.path.join(os.path.expanduser("~"), "Downloads", "curse", "forever")
            os.makedirs(dest, exist_ok=True)
            shutil.copy(os.path.join(FOREVER, "curseforge", "SeviathsUsefulTools-1.0-forever.zip"), dest)
        except Exception as e:
            print("zip copy failed", e, flush=True)
        git("add", "-A")
        code, out = git("commit", "-qm", "Collected data after a reload or logout (automatic)\n\nCo-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>")
        if code == 0:
            code, out = git("push")
            print(time.strftime("%H:%M:%S"), "pushed" if code == 0 else "push failed: " + out[-200:], flush=True)
        else:
            print(time.strftime("%H:%M:%S"), "nothing new to commit", flush=True)
