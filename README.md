# SeviathsUsefulTools (retail, Midnight)

One addon with everything Seviath made for retail:

- **Farm spots, rares and gathering zones** on the world map and minimap (from SeviathsFarmPack), Classic to Midnight.
- **Auction prices** from its own scan - and when the auction house was not scanned (or not opened yet) it uses Auctionator's or TradeSkillMaster's prices instead (prices are kept per realm and shared between your characters), **crafting profit** and **"worth grinding?"** lines on item, monster and gathering-node tooltips.
- Yellow chat messages when an **auction sells** and when you take **gold from the mailbox** or **sell to a vendor**.
- It learns monsters, drops, items, nodes and recipes as you play (menu: "Learn everything constantly").
- **Codex** encyclopedia (with Delves), **Dungeons & Raids** group tools and the **Guild Helper** as modules.

Open it with `/sfp` or the minimap button. Other commands: `/sfp craft`, `/sfp sold`, `/sfp income`, `/sfp comparelevel`, `/sfp errors`, `/codex`, `/sdr`, `/gi`.

**More tools:** `/sfp session` (farm session tracker), `/sfp next` (which rare to farm next), `/sfp alerts` (rare alerts), `/sfp route` (loop through ticked spots), `/sfp weekly` (all characters), `/sfp flip` (BoE deals), `/sfp shop` (crafting shopping list), `/sfp export` and `/sfp import` (share what the addon learned), `/sfp history` (your collections).

**Disable** SeviathsFarmPack, SeviathsCodex, SeviathsDungeonsRaids and SeviathsGuildHelper: they are inside this addon now.
The Codex, Dungeons & Raids and Guild Helper saved data carries over (same saved-variable names).

The classic (Mists of Pandaria) edition with the Questie-based quest tooltips lives in the SeviathsUsefulTools folder of the classic client; retail has its own quest tooltips and nameplate icons, so that part is left out here.

## License

Creative Commons Attribution-NonCommercial 3.0 (CC BY-NC 3.0), see `LICENSE`. Item data and spawn positions come from wowhead.com.

## Releasing (CurseForge, Wago, GitHub)

The packaging is set up, nothing is uploaded until you do these once:

1. Create the project on CurseForge and copy its numeric project id.
2. Add the line `## X-Curse-Project-ID: <id>` to `SeviathsUsefulTools.toc` (optionally `## X-Wago-ID: <id>`).
3. In the GitHub repository settings add the secret `CF_API_KEY` (your CurseForge API token) and, for Wago, `WAGO_API_TOKEN`.
4. Update the version in the `.toc` and `CHANGELOG.md`, commit, then push a tag: `git tag v2.0.1 && git push origin v2.0.1`.

The workflow in `.github/workflows/release.yml` builds the zip (rules in `.pkgmeta`) and uploads it with the changelog.

## Credits
- Housing decor data: Vamoose's Housing Decor Guide (VamooseAddons/housing-decor-guide, MIT licence), state of 2026-10-26.
