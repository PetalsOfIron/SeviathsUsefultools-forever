"""Waits for crawl_quest_prereqs.py, then bakes the chains, finds the places of the mounts and bakes everything again. Run: python tools/finish_crawl2.py"""
import os, subprocess, sys, time
ADDON = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
def running(word):
    r = subprocess.run(["powershell", "-NoProfile", "-Command", "Get-CimInstance Win32_Process -Filter \"Name='python.exe'\" | Select-Object -ExpandProperty CommandLine"], capture_output=True, text=True)
    return word in (r.stdout or "")
while running("crawl_quest_prereqs"):
    time.sleep(20)
for cmd in (["tools/bake_quest_prereqs.py"], ["tools/bake_mount_places.py"], ["tools/bake_questgivers.py"], ["tools/package_curseforge.py"]):
    subprocess.run([sys.executable, "-u"] + cmd, cwd=ADDON)
print("FINISHED2", flush=True)
