Automatic data update after every /reload, logout and exit (runs on your PC only, never for players)

auto_update.ps1 waits in the background and, every time the game writes the addon data (each /reload, logout and exit), runs update_data.py: it bakes the collected data
and the prices, pushes them to the Data-wow repo and rebuilds the CurseForge zip in Projects\sut-curse-release.

To start it at every Windows logon, run this once in a PowerShell window (it adds a scheduled task for your user):

schtasks /Create /F /TN "SeviathsUsefulTools data update" /SC ONLOGON /RL LIMITED /TR "powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File \"D:\wow\World of Warcraft\_retail_\Interface\AddOns\SeviathsUsefulTools\tools\auto_update.ps1\""

To start it right now without waiting for the next logon:  schtasks /Run /TN "SeviathsUsefulTools data update"
To remove it:  schtasks /Delete /F /TN "SeviathsUsefulTools data update"

The log is Projects\sut-curse-release\auto_update.log. This folder (tools) is not put in the CurseForge zip.
