-- VoidRecruit.Util -- shared popups, external links, constants, and timezone/raid-overlap logic.
-- (Timezone code lives here rather than its own file so /reload always picks it up.)
local ADDON, ns = ...

ns.TRIAL_DAYS   = 14   -- default trial length before a decision is nudged
ns.TEMP_BL_DAYS = 30   -- temporary blacklist auto-expiry

-- 12.0's GameDialog StaticPopup exposes the edit box as `.EditBox`; older builds used `.editBox`.
local function popupEditBox(self) return self.EditBox or self.editBox end

StaticPopupDialogs["VOIDRECRUIT_PROMPT"] = {
    text = "%s", button1 = ACCEPT, button2 = CANCEL,
    hasEditBox = true, timeout = 0, whileDead = true, hideOnEscape = true,
    OnShow = function(self) local eb = popupEditBox(self); if eb then eb:SetText(ns._promptDefault or ""); eb:HighlightText() end end,
    OnAccept = function(self) local eb = popupEditBox(self); if ns._promptCb and eb then ns._promptCb(eb:GetText()) end end,
    EditBoxOnEnterPressed = function(self) if ns._promptCb then ns._promptCb(self:GetText()) end; self:GetParent():Hide() end,
    EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
}
function ns.Prompt(label, default, cb)
    ns._promptDefault, ns._promptCb = default or "", cb
    StaticPopup_Show("VOIDRECRUIT_PROMPT", label)
end

StaticPopupDialogs["VOIDRECRUIT_URL"] = {
    text = "%s", button1 = CLOSE,
    hasEditBox = true, timeout = 0, whileDead = true, hideOnEscape = true,
    OnShow = function(self) local eb = popupEditBox(self); if eb then eb:SetText(ns._url or ""); eb:HighlightText(); eb:SetFocus() end end,
    EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
}
function ns.ShowURL(url) ns._url = url; StaticPopup_Show("VOIDRECRUIT_URL", "Copy (Ctrl+C):") end

local function realmSlug(r) return (r or ""):lower():gsub("[^%w]+", "-") end
function ns.LinkFor(site, name, realm)
    local region, rs, n = ns.region or "us", realmSlug(realm), name or ""
    if site == "rio" then return ("https://raider.io/characters/%s/%s/%s"):format(region, rs, n) end
    if site == "wcl" then return ("https://www.warcraftlogs.com/character/%s/%s/%s"):format(region, rs, n) end
    if site == "armory" then return ("https://worldofwarcraft.com/en-us/character/%s/%s/%s"):format(region, rs, n) end
end

----------------------------------------------------------------------
-- Realm -> timezone (full Americas list from warcraft.wiki.gg datacenter page) + raid-overlap.
-- Codes: ET CT MT PT OCE BR (Brazil). DST ignored. Manual TZ field overrides the realm zone.
----------------------------------------------------------------------
local REALM = {}
local function add(tz, list) for _, r in ipairs(list) do if not REALM[r] then REALM[r] = tz end end end
add("ET", { "dalaran","thrall","altarofstorms","alteracmountains","anetheron","argentdawn","arthas",
    "blackdragonflight","bleedinghollow","bloodfurnace","bloodhoof","durotan","duskwood","elune","exodar",
    "gilneas","gorgonnash","grizzlyhills","guldan","lothar","magtheridon","malfurion","mannoroth","medivh",
    "nazjatar","skullcrusher","stormrage","theforgottencoast","thescryers","trollbane","warsong","ysera",
    "ysondre","zuljin","area52","arygos","burningblade","earthenring","eonar","kargath","lightningsblade",
    "llane","norgannon","onyxia","turalyon","velen","eredar","gorefiend","spinebreaker","wildhammer",
    "eldrethalas","firetree","draktharon","korialstrasz","malorne","rivendare","spirestone","stormscale","garrosh" })
add("CT", { "alexstrasza","alleria","blackhand","dentarg","galakrond","garona","ghostlands","hellscream",
    "illidan","kaelthas","khadgar","kirintor","ravencrest","sentinels","steamwheedlecartel","terokkar",
    "uldaman","whisperwind","zangarmarsh","agamaggan","archimonde","azuremyst","blackwinglair","burninglegion",
    "dethecus","detheroc","emeralddream","greymane","haomarush","jaedenar","lethon","lightninghoof","maelstrom",
    "ravenholdt","sargeras","shadowmoon","staghelm","tanaris","theunderbog","theventureco","twistingnether",
    "anvilmar","azgalor","azshara","dawnbringer","destromath","madoran","thunderlord","undermine","auchindoun",
    "bladesedge","chogall","fizzcrank","icecrown","laughingskull","malganis","malygos","thunderhorn","aegwynn",
    "anubarak","bladefist","bonechewer","chromaggus","crushridge","daggerspine","eitrigg","garithos","gurubashi",
    "hakkar","korgath","kultiras","misha","muradin","nathrezim","nordrassil","rexxar","runetotem","shuhalo",
    "smolderthorn","uther","frostmane","moonguard","tortheldrin","drakkari","quelthalas","ragnaros" })
add("MT", { "deathwing","executus","kalecgos","shatteredhalls","kelthuzad","azjolnerub","bloodscalp",
    "boulderfist","cairne","dunemaul","khazmodan","maiev","perenolde","stonemaul","blackwaterraiders","hydraxis","terenas" })
add("PT", { "aeriepeak","andorhal","baelgun","coilfang","dalvengyr","darkiron","demonsoul","doomhammer",
    "gnomeregan","moonrunner","scilla","shatteredhand","ursin","zuluhed","blackrock","farstriders","frostwolf",
    "kiljaeden","kilrogg","proudmoore","silverhand","thoriumbrotherhood","tichondrius","vashj","veknilash",
    "winterhoof","antonidas","bronzebeard","cenarius","cenarioncircle","draenor","dragonblight","draka",
    "echoisles","fenris","hyjal","lightbringer","shandris","sistersofelune","suramar","uldum","wyrmrestaccord",
    "akama","arathor","boreantundra","darrowmere","dragonmaw","drakthul","drenden","feathermoon","moknathal",
    "mugthol","nerzhul","scarletcrusade","shadowsong","silvermoon","skywall","windrunner" })
add("OCE", { "amanthul","barthilas","caelestrasz","dathremar","dreadmaul","frostmourne","khazgoroth",
    "nagrand","thaurissan","gundrak","jubeithos","saurfang" })
add("BR", { "goldrinn","nemesis","azralon","tolbarad","gallywix" })

local function normRealm(r) return (r or ""):lower():gsub("[^%w]", "") end
function ns.RealmTZ(realm) return REALM[normRealm(realm)] end

ns.TZ_OFF = { ET = 0, CT = -1, MT = -2, PT = -3, BR = 2, OCE = 15 } -- hours relative to US Eastern

function ns.TZCode(s)
    if not s or s == "" then return nil end
    s = s:upper()
    if s:find("OCE") or s:find("AES") or s:find("AED") or s:find("SYDNEY") or s:find("BRISB") or s:find("MELB") or s:find("AUS") then return "OCE" end
    if s:find("BRT") or s:find("BRAZIL") or s:find("BRASIL") then return "BR" end
    if s:find("PST") or s:find("PDT") or s:find("PACIF") then return "PT" end
    if s:find("MST") or s:find("MDT") or s:find("MOUNT") then return "MT" end
    if s:find("CST") or s:find("CDT") or s:find("CENTR") then return "CT" end
    if s:find("EST") or s:find("EDT") or s:find("EAST") then return "ET" end
    if s:find("PT") then return "PT" end
    if s:find("MT") then return "MT" end
    if s:find("CT") then return "CT" end
    if s:find("ET") then return "ET" end
    return nil
end

local function fmt12(h)
    local ap = (h < 12) and "am" or "pm"
    local h12 = h % 12; if h12 == 0 then h12 = 12 end
    return h12 .. ap
end

function ns.RaidConfig()
    VoidRecruitDB = VoidRecruitDB or {}
    return VoidRecruitDB.raidHour or 20, VoidRecruitDB.raidTZ or "ET"
end
function ns.SetRaidConfig(h, tz) VoidRecruitDB = VoidRecruitDB or {}; VoidRecruitDB.raidHour, VoidRecruitDB.raidTZ = h, tz end
function ns.RaidConfigStr() local h, tz = ns.RaidConfig(); return fmt12(h) .. " " .. tz end

function ns.ParseRaidTime(s)
    s = (s or ""):upper()
    local h = tonumber(s:match("(%d+)")); if not h then return nil end
    if s:find("PM") and h < 12 then h = h + 12 end
    if s:find("AM") and h == 12 then h = 0 end
    return h % 24, ns.TZCode(s) or "ET"
end

function ns.RaidOverlap(recruitCode)
    local off = recruitCode and ns.TZ_OFF[recruitCode]; if not off then return nil end
    local rh, rtz = ns.RaidConfig()
    local hour, day = rh + (off - (ns.TZ_OFF[rtz] or 0)), 0
    while hour >= 24 do hour, day = hour - 24, day + 1 end
    while hour < 0 do hour, day = hour + 24, day - 1 end
    local color = (hour >= 16 and hour <= 22) and "40ff80"
        or (((hour >= 14 and hour < 16) or hour == 23) and "ffd700")
        or "ff6060"
    local tail = (day > 0 and (" +" .. day .. "d")) or (day < 0 and (" " .. day .. "d")) or ""
    return fmt12(hour) .. tail, color
end
