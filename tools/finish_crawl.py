"""Waits for the hunter pet bake, then continues the monster crawl (it resumes where it stopped), then bakes everything again. Run: python tools/finish_crawl.py"""
import os
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
ADDON = os.path.dirname(HERE)


def running(word):
    r = subprocess.run(["powershell", "-NoProfile", "-Command", "Get-CimInstance Win32_Process -Filter \"Name='python.exe'\" | Select-Object -ExpandProperty CommandLine"],
                       capture_output=True, text=True)
    return word in (r.stdout or "")


while running("bake_hunter_pets_forever"):
    time.sleep(20)
for cmd in (["tools/crawl_classic_npcs.py"], ["tools/make_crawl_seed.py"], ["tools/bake_collected.py", "tools/classic_seed.lua", "tools/crawl/crawl_seed.lua"],
            ["tools/bake_questgivers.py"]):
    subprocess.run([sys.executable, "-u"] + cmd, cwd=ADDON)
print("FINISHED", flush=True)
