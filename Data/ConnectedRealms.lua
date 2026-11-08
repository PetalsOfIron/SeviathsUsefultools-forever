-- SeviathsUsefulTools - realms that share one auction house (US and EU; read from the Connected Realms list of warcraft.wiki.gg and checked
-- against the groups the game reported for 3 groups). Realms alone on their auction house are not listed. Can be replaced with exact data by
-- tools/bake_connected_realms.py (Blizzard API). The addon prefers the groups the game itself reported (db.realmGroups).
local _, SFP = ...
SFP.ConnectedRealms = {}
