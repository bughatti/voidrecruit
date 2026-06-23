-- VoidRecruit.Perms -- guild-permission gate.
--
-- Layer 1 of the permission model: guild ACTIONS mirror WoW exactly. The checks below are
-- copied straight from Blizzard_Communities/GuildRoster.lua (verified, 12.0.7). We only ever
-- READ capability and act within it; we NEVER call the protected GuildControl* setters
-- (rank/permission editing), which are GM + Blizzard-UI-scoped and pop "blocked from action"
-- even for the GM (learned on VoidBags). Lower guildRankOrder = higher authority (GM = 1).
local ADDON, ns = ...
local Perms = {}
ns.Perms = Perms

local cache = { ready = false }

local function myRankOrder()
    local guid = UnitGUID("player")
    return guid and C_GuildInfo.GetGuildRankOrder(guid) or nil
end

function Perms:Refresh()
    if not IsInGuild() then
        cache = { ready = true, inGuild = false }
        return
    end
    cache = {
        ready          = true,
        inGuild        = true,
        isLeader       = IsGuildLeader() and true or false,
        isOfficer      = (C_GuildInfo.IsGuildOfficer() or IsGuildLeader()) and true or false,
        canInvite      = CanGuildInvite() and true or false,
        canPromote     = CanGuildPromote() and true or false,
        canDemote      = CanGuildDemote() and true or false,
        canRemove      = CanGuildRemove() and true or false,
        canEditOfficer = C_GuildInfo.CanEditOfficerNote() and true or false,
        canViewOfficer = C_GuildInfo.CanViewOfficerNote() and true or false,
        canEditPublic  = CanEditPublicNote() and true or false,
        myRankOrder    = myRankOrder(),
        maxRankOrder   = GuildControlGetNumRanks(),
    }
end

-- Capability check, independent of a specific target.
function Perms:Can(action)
    if not cache.ready then self:Refresh() end
    if action == "invite"          then return cache.canInvite and cache.isOfficer end
    if action == "editOfficerNote" then return cache.canEditOfficer end
    if action == "viewOfficerNote" then return cache.canViewOfficer end
    if action == "editPublicNote"  then return cache.canEditPublic end
    if action == "manage"          then return cache.isOfficer end -- app-level: edit the pipeline
    if action == "promote"         then return cache.canPromote end
    if action == "demote"          then return cache.canDemote end
    if action == "cut"             then return cache.canRemove end
    return false
end

-- Rank action on a specific member -- mirrors GuildRoster.lua: you can only act on a member
-- of LOWER rank than yourself (you can't promote to/above yourself, or kick equal/higher rank).
function Perms:CanActOn(action, targetRankOrder)
    if not cache.ready then self:Refresh() end
    local my, max = cache.myRankOrder, cache.maxRankOrder
    if not (my and targetRankOrder) then return false end
    if action == "promote" then return cache.canPromote and targetRankOrder > my + 1 end
    if action == "demote"  then return cache.canDemote and targetRankOrder < max and targetRankOrder > my end
    if action == "cut"     then return cache.canRemove and targetRankOrder > my end
    return false
end

function Perms:IsOfficer() if not cache.ready then self:Refresh() end return cache.isOfficer end
function Perms:IsLeader()  if not cache.ready then self:Refresh() end return cache.isLeader end

-- Keep the cache fresh as ranks/roster change.
local ev = CreateFrame("Frame")
ev:RegisterEvent("GUILD_ROSTER_UPDATE")
ev:RegisterEvent("PLAYER_GUILD_UPDATE")
ev:SetScript("OnEvent", function() Perms:Refresh() end)
