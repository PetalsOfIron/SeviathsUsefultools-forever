-- Seviath's Codex — collection history
-- What your own collections say you already own is no longer shown in the Codex (it only holds shared game data: bosses, rares,
-- monsters, items, materials, towns). The data is still read by TransmogHistory.lua in the main addon; these stay as empty hooks.

local ADDON, ns = SFP_Module("Codex")

function ns:LoadHistory() end
function ns:RefreshHistory() end
function ns:HistoryEntryText() return "" end
