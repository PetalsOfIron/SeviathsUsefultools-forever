// Offline load test: the shipped collected files + a real saved-data file + SavedPack.lua + CollectedImport.lua, with the WoW API stubbed.
const {lua, lauxlib, lualib, to_luastring} = require('fengari');
const fs = require('fs');
const A = process.argv[2];
const SV = process.argv[3];
const L = lauxlib.luaL_newstate(); lualib.luaL_openlibs(L);
function run(code, name) {
  const r = lauxlib.luaL_loadbuffer(L, to_luastring(code), null, to_luastring(name));
  if (r !== 0) throw new Error(name + ': ' + lua.lua_tojsstring(L, -1));
  if (lua.lua_pcall(L, 0, lua.LUA_MULTRET, 0) !== 0) throw new Error(name + ': ' + lua.lua_tojsstring(L, -1));
}
const t0 = Date.now();
run(`
local handlers = {}
function CreateFrame()
  local f = { events = {} }
  function f:RegisterEvent(e) self.events[e] = true; handlers[#handlers + 1] = { f, e } end
  function f:SetScript(n, fn) if n == "OnEvent" then self.onevent = fn end end
  function f:Show() end function f:Hide() end
  return f
end
FIRE = function(ev) for _, h in ipairs(handlers) do if h[2] == ev and h[1].onevent then h[1].onevent(h[1], ev) end end end
local timers = {}
C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }
RUN_TIMERS = function() local t = timers; timers = {}; for _, fn in ipairs(t) do fn() end end
unpack = unpack or table.unpack
GetCurrentRegion = function() return 3 end
`, 'stubs');
for (const f of fs.readdirSync(A + '/collected').filter(x => x.endsWith('.lua')).sort()) run(fs.readFileSync(A + '/collected/' + f, 'utf8'), f);
console.log('shipped files loaded', (Date.now() - t0) / 1000, 's');
run(fs.readFileSync(A + '/SavedPack.lua', 'utf8'), 'SavedPack');
const t1 = Date.now();
run(fs.readFileSync(SV, 'utf8'), 'saved');
console.log('saved file loaded', (Date.now() - t1) / 1000, 's');
const t2 = Date.now();
run(`
local function raw(t) local n = 0 for _ in pairs(t or {}) do n = n + 1 end return n end
BEFORE = { quests = raw(SeviathsCodexDB.quests), known = raw(SeviathsUsefulToolsDB.knownItems), packed = SeviathsUsefulToolsDB.__packed ~= nil }
SeviathsUnpackSaved(SeviathsUsefulToolsDB)
SeviathsUnpackSaved(SeviathsCodexDB)
SeviathsUsefulTools = { db = SeviathsUsefulToolsDB, Social = {} }
`, 'unpack');
console.log('unpacked', (Date.now() - t2) / 1000, 's');
const t3 = Date.now();
run(fs.readFileSync(A + '/CollectedImport.lua', 'utf8'), 'CollectedImport');
run('FIRE("PLAYER_LOGIN")', 'login');
console.log('login import (prune + merge)', (Date.now() - t3) / 1000, 's');
run(`
local function raw(t) local n = 0 for _ in pairs(t or {}) do n = n + 1 end return n end
local function all(t) local n = 0 for _ in SeviathsAllPairs(t) do n = n + 1 end return n end
print("before: local quests", BEFORE.quests, "known", BEFORE.known, "was packed", BEFORE.packed)
print("after:  local quests", raw(SeviathsCodexDB.quests), "known", raw(SeviathsUsefulToolsDB.knownItems))
print("whole:  quests", all(SeviathsCodexDB.quests), "known", all(SeviathsUsefulToolsDB.knownItems), "loot", all(SeviathsCodexDB.loot))
-- reading by key goes through the shipped text
local id, rec
for k in SeviathsAllPairs(SeviathsCodexDB.quests) do id = k break end
rec = SeviathsCodexDB.quests[id]
print("a quest read by key:", id, type(rec), rec and rec.t)
local kid = next(SeviathsUsefulToolsDB.knownItems) or (function() for k in SeviathsAllPairs(SeviathsUsefulToolsDB.knownItems) do return k end end)()
local item = SeviathsUsefulToolsDB.knownItems[kid]
print("an item read by key:", kid, type(item), item and item.n)
print("collected date set:", SeviathsUsefulToolsDB.collectedDate ~= nil, "players", raw(SeviathsUsefulToolsDB.seenInfo), "guilds", raw(SeviathsUsefulToolsDB.guildDir))
`, 'checks');
console.log('done, total', (Date.now() - t0) / 1000, 's');
