-- Loaded last, so its logout handler runs after every other addon file's: the big tables of the saved data are cut into text pieces just
-- before the game writes them (see SavedPack.lua). The game also saves on /reload and on exit; this runs then too.
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGOUT")
f:SetScript("OnEvent", function()
    if not SeviathsPackSaved then return end
    for _, name in ipairs({ "SeviathsUsefulToolsDB", "SeviathsCodexDB" }) do
        pcall(SeviathsPackSaved, _G[name], name)
    end
end)
