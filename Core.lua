-- VoidRecruit Core -- bootstrap + the Blizzard_Communities (guild box) load hook.
local ADDON, ns = ...
VoidRecruit = ns
ns.version = "0.1.0"

-- VoidLib logger (embedded); degrade safely if somehow absent.
ns.Log = (VoidLib and VoidLib.Logger and VoidLib.Logger.New({ svKey = "VoidRecruitLog", label = "VoidRecruit" }))
    or setmetatable({}, { __index = function() return function() end end })

-- Shared identity helper: build the VoidScout bundle slug for a player.
ns.region = ({ "us", "kr", "eu", "tw", "cn" })[GetCurrentRegion()] or "us"
local function normSlug(s) return (s or ""):lower():gsub("[^%w]", "") end
function ns.Slug(name, realm)
    if not name or name == "" then return nil end
    realm = (realm and realm ~= "") and realm or GetNormalizedRealmName() or GetRealmName() or ""
    return normSlug(name) .. "-" .. normSlug(realm) .. "-" .. ns.region
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == ADDON then
            VoidRecruitDB = VoidRecruitDB or {}
            ns.db = VoidRecruitDB
        elseif arg1 == "Blizzard_Communities" then
            -- The guild box is Load-on-Demand: it doesn't exist until opened. Attach now.
            if ns.Panel and ns.Panel.Attach then ns.Panel.Attach() end
        end
    elseif event == "PLAYER_LOGIN" then
        if ns.Perms then ns.Perms:Refresh() end
        -- If the guild box was already loaded before us, attach immediately.
        if C_AddOns.IsAddOnLoaded("Blizzard_Communities") and ns.Panel and ns.Panel.Attach then
            ns.Panel.Attach()
        end
    end
end)

-- /voidrecruit -- confirms the addon is loaded and points to where the panel lives.
-- (The UI is the docked panel; this is just a convenience/verification command.)
SLASH_VOIDRECRUIT1 = "/voidrecruit"
SLASH_VOIDRECRUIT2 = "/vrec"
SlashCmdList["VOIDRECRUIT"] = function()
    print("|cffa335eeVoidRecruit|r v" .. ns.version .. " loaded. Open Guild & Communities (press J) -- the panel docks beside it.")
    if C_AddOns.IsAddOnLoaded("Blizzard_Communities") and ns.Panel and ns.Panel.Attach then ns.Panel.Attach() end
end
