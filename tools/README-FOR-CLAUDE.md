# README for Claude (recovery notes for SeviathsUsefulTools)

If the user's PC was lost or reinstalled and this file is all you have: read it fully, then ask the user for what is missing. It describes the
project, where everything lives, how data flows, and the rules the user set. Last written 2026-11-01.

## What this is
**SeviathsUsefulTools** is a World of Warcraft retail (Midnight, interface 120007/120100/120105) addon by the user (GitHub names
`PetalsOfIron` for the repos, git user `santamadaraneilande-ctrl`). It merges farm spots/prices, the Codex encyclopedia, Dungeons & Raids
tools, Guild Helper, a Guild Directory, a talent advisor, nearby-player collecting, and ships collected game data inside the addon.
WoW Lua is **5.1**: no `goto`, no `//`, no bit operators. A Lua 5.3 checker (fengari) cannot catch 5.1 or game-specific errors.

## Repositories (all on GitHub)
- Addon: `PetalsOfIron/WOWSeviathsUsefultools-Retail` (branch `main`). The working copy on the user's PC is the addon folder
  `D:\wow\World of Warcraft\_retail_\Interface\AddOns\SeviathsUsefulTools`.
- Collected data: `PetalsOfIron/Data-wow` (public). Holds the `collected/` folder and this README.
- **The addon folder must never contain `.git`, `.github` or `.gitignore`** (CurseForge rejected a zip that had them). The git folder is kept
  outside: `C:\Users\SaphiresSilver\Projects\sut-retail-gitdir`. Use
  `git --git-dir=C:\Users\SaphiresSilver\Projects\sut-retail-gitdir --work-tree="<addon folder>" ...`. Ignore patterns go in
  `sut-retail-gitdir\info\exclude` (`*.bak`, `*.tmp`). To rebuild on a new PC: `git clone --bare <addon repo> sut-retail-gitdir`, then
  `git --git-dir=... --work-tree=<addon folder> checkout -f main`.
- Data repo clone used by the scripts: `C:\Users\SaphiresSilver\Projects\Data-wow`.

## The user's rules (follow them)
- Push after every task (user: "push all the time"). Run the syntax check first and require `problems 0`
  (`node %TEMP%\lchk\chk3.js "<addon dir>"`; fengari must be installed there). Commit messages end with
  `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`. Change the `.toc` version only when the user gives a version number.
- Never claim something was tested in game; say so each time. Do not invent data; verify facts. Keep replies short; the user sends terse
  messages and gets frustrated by misunderstandings, so change only what was asked and ask one short question when unsure.
- CurseForge changelogs: plain paragraphs, only what changed since the last one (1.8 was the last one given).
- The user does not want to create a Blizzard API client. Do not bring it up again unless asked.
- Never put guild notes in the shipped data (the data repo is public).

## How data flows
1. Players collect data in the game (nameplates, inspects, kills, loot, quests, auction scans, vendors, towns, guild rosters ...).
2. The game writes `WTF\Account\<id>\SavedVariables\SeviathsUsefulTools.lua` on `/reload`, logout and exit only (an addon cannot force it).
3. `tools/update_data.py` (run by the watcher after every save) does, in order: `bake_collected.py` (saved data -> `collected/*.lua`,
   split into ~2.5 MB parts, merged with earlier bakes so nothing is lost), `bake_gold.py` (auction prices per realm group ->
   `collected/gold.*.lua`; keeps older prices, drops troll prices over 1,000,000 g or 8x other realms), `.toc` file list sync, an offline
   load check (`tools/load_test.js`), push to Data-wow, push of the addon repo, and the CurseForge zip.
4. The zip is built from a copy of the addon folder without `.git*`, `tools` and `*.bak`, in `C:\Users\SaphiresSilver\Projects\sut-curse-release`,
   and copied to `C:\Users\SaphiresSilver\Downloads\curse` (only the zip, replaced each time). The user uploads that one zip by hand to CurseForge.
5. Players get the data with the addon. The game cannot download anything, so there is no live sync; other players' data does not come back.

## The automation on the user's PC
- `tools/auto_update.ps1` watches the saved-data file and runs `update_data.py` at the lowest CPU priority; one instance only.
- Started at Windows startup by `...\Start Menu\Programs\Startup\SeviathsUsefulTools data update.vbs`
  (a scheduled task was denied: "Access is denied"; the desktop `.bat` files are alternatives).
- Log: `Projects\sut-curse-release\auto_update.log`. Stop it by killing the powershell running `auto_update.ps1`.
- If it is not running, run `python tools/update_data.py` by hand after the game saved.

## Critical technical rules and gotchas
- **WoW loads a saved-data file as one chunk with at most ~262,143 distinct names and numbers ("constant table overflow").** It already
  broke the user's data once. Therefore: shipped data is never copied into the saved tables; big tables ship as one text string per record
  (`Dp(...)` in `collected/*.lua`, decoded on read by `SeviathsDecode`, walked with `SeviathsAllPairs`); the player's big saved tables are
  written as ~200 KB text pieces at logout (`SavedPack.lua`, `SavedPackLogout.lua`, unpacked again at ADDON_LOADED in `Core.lua` and
  `Modules/Codex/Core.lua`). Per-function limits apply to generated files too (batches of ~40,000 constants, `;(function() ... end)()`;
  every generated line starts with `;` because Lua 5.1 refuses `end\n(function` as ambiguous syntax).
- Saved-data backups: `C:\Users\SaphiresSilver\Projects\sut-savedvars-backup\`.
- Memory: about 200 MB for the addon (`/sfp mem`, `/sfp mem detail`). The Codex builds the item pages only when its window opens and stops
  loading when it closes. Price histories are flat lists. Collecting a known player again waits a day.
- Writing patch scripts: in a bash heredoc `\n` inside Python strings can turn into real newlines. For anything with escapes use the Write
  tool to create the script, or build strings with `chr(10)` / `chr(92)`.
- Shipped price lists are long texts per realm group (`"id,price;..."`), decoded only for the player's realm (`SFP:ShippedPrice`), then the
  region commodity list, then the closest list. The list of connected realms is `Data/ConnectedRealms.lua` (US and EU, from the
  warcraft.wiki.gg Connected Realms page, matched against three groups the game reported).
- Fast auction scan: the game allows one request per account every ~15 minutes; the timer under the scan bar shows it. After it the section
  scan follows. `/sfp fastscan`, `/sfp sections` are for testing.

## How to run things (commands)
All commands run from the addon folder `D:\wow\World of Warcraft\_retail_\Interface\AddOns\SeviathsUsefulTools`.
- Everything in one go (bake, check, push both repos, build the zip): `python tools/update_data.py`
  (`--no-zip` skips the zip). Needs Python 3 (`C:\Python315\python.exe` was used), git logged in to GitHub, and for the load check
  `node` with the `fengari` package in `%TEMP%\lchk\node_modules` (`npm install fengari` there; without it the check is skipped).
- Only the data: `python tools/bake_collected.py` (optionally extra older saved files as arguments), prices: `python tools/bake_gold.py`.
- Syntax check of the addon: `node %TEMP%\lchk\chk3.js "<addon dir>"` (the checker parses every `.lua` with fengari; recreate it if gone).
- Optional, need the user's Blizzard API client (he declined): `bake_connected_realms.py`, `bake_prices_api.py`, `bake_players.py`.
- In the game: `/sfp mem` (memory), `/sfp mem detail`, `/sfp fastscan`, `/sfp sections`, `/sfp near`, `/sfp stats`, `/sfp rio`, `/codex`.

## Rebuilding the whole process on a new PC (data saves for CurseForge)
1. Install WoW, Python 3, git, Node.js. Log in to GitHub as `santamadaraneilande-ctrl` (the owner of the `PetalsOfIron` repos has push rights).
2. Get the addon: clone the addon repo, make the addon folder `...\_retail_\Interface\AddOns\SeviathsUsefulTools` from its files, but keep the
   git folder outside it (see Repositories). Clone `Data-wow` to `C:\Users\<user>\Projects\Data-wow`.
3. `update_data.py` creates `Projects\sut-curse-release` and `Downloads\curse` and fills them with the zip.
4. Set `GITDIR`, `DATA_REPO`, the Python path in `tools/auto_update.ps1` and the WoW path in the scripts if the paths differ
   (they are constants at the top of `update_data.py` and `auto_update.ps1`).
5. Start the watcher: put a `.vbs` with `CreateObject("WScript.Shell").Run "powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File ""<path>\tools\auto_update.ps1""", 0, False`
   into `shell:startup` (a scheduled task needs admin). Log in to the game and `/reload`; about 40 seconds later `update_data.py` runs.
6. The collected data survives a PC loss only through the `collected/` folder in the repos: restore it by cloning them. The saved file in `WTF`
   is not in git; the user's older backups are in `Projects\sut-savedvars-backup` (lost with the PC unless copied elsewhere).
7. Upload `Downloads\curse\SeviathsUsefulTools-<version>.zip` to the CurseForge project by hand.

## Open items (at the time of writing)
- The curio scan: the user should press "Scan my account's curios" in the Delve planner and send the report (nothing learned yet).
- US/KR/TW prices and connected realms for KR/TW/Oceanic/Brazil are not shipped.
- Nothing from this session's later changes was tested in game beyond the user's screenshots.
