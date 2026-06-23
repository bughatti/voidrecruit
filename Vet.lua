-- VoidRecruit.Vet -- vetting card + recruiting actions for your current target.
-- Data from RaiderIO (M+/key/raid, ~everyone) + VoidScout bundle (ilvl + logged-only util/kick).
-- Actions: vote (you + co-officer), Track, Trial, two-tier Blacklist, alt->main link, timezone,
-- and copy-able RIO/WCL/Armory links. Follows alt->main link so an alt shows the main's data.
local ADDON, ns = ...

local function bundleLookup(slug)
    local b = _G.VoidScoutBundle
    if not (slug and b and b.players) then return nil end
    return b.players[slug]
end
local function titleCase(s)
    return (tostring(s or ""):gsub("(%a)([%w]*)", function(a, z) return a:upper() .. z:lower() end))
end
local function rioData(name, realm)
    local rio = _G.RaiderIO
    if not (rio and rio.GetProfile) then return nil end
    local ok, profile = pcall(rio.GetProfile, name, realm)
    if not ok or not profile then return nil end
    local out, mk = {}, profile.mythicKeystoneProfile
    if mk then
        out.score = mk.currentScore or mk.previousScore
        if mk.sortedDungeons then
            local best
            for _, d in ipairs(mk.sortedDungeons) do
                if (d.chests or 0) > 0 and (d.level or 0) > 0 and (not best or d.level > best.level) then
                    best = { level = d.level, dungeon = (d.dungeon and (d.dungeon.shortName or d.dungeon.name)) or "?" }
                end
            end
            out.bestKey = best
        end
    end
    local rp = profile.raidProfile
    if rp and rp.summary then out.raid = rp.summary end
    return out
end

-- current targeted player, realm resolved (nil if no valid target)
local function curTarget()
    if not (UnitExists("target") and UnitIsPlayer("target")) then return nil end
    local n, r = UnitName("target")
    if not r or r == "" then r = GetRealmName() end
    return n, r
end

ns.Panel.AddView("vet", "Vet", function(parent)
    local f = CreateFrame("Frame", nil, parent); f:SetAllPoints()
    local refresh

    local name = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge"); name:SetPoint("TOPLEFT", 4, -4)
    local sub  = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); sub:SetPoint("TOPLEFT", 4, -24)

    -- Raid-overlap tag: the recruit's local clock at YOUR raid start, colour-coded. Click to
    -- set your raid time. Green = prime evening for them, red = their daytime / sleep.
    local raidTag = CreateFrame("Button", nil, f)
    raidTag:SetSize(150, 14); raidTag:SetPoint("TOPRIGHT", -4, -8)
    raidTag.txt = raidTag:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    raidTag.txt:SetAllPoints(); raidTag.txt:SetJustifyH("RIGHT")
    raidTag:SetScript("OnClick", function()
        if not (ns.Prompt and ns.RaidConfigStr) then return end
        ns.Prompt("Your raid start (e.g. 8pm ET):", ns.RaidConfigStr(), function(s)
            local h, tz = ns.ParseRaidTime(s); if h then ns.SetRaidConfig(h, tz) end
            if refresh then refresh() end
        end)
    end)

    local function head(y, t)
        local h = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        h:SetPoint("TOPLEFT", 4, y); h:SetText(t); h:SetTextColor(0.64, 0.21, 0.93)
    end
    local function row(y, label)
        local l = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        l:SetPoint("TOPLEFT", 10, y); l:SetText(label); l:SetTextColor(0.72, 0.72, 0.78)
        local v = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        v:SetPoint("TOPRIGHT", -6, y); v:SetJustifyH("RIGHT")
        return v
    end
    head(-46, "RaiderIO / M+")
    local vScore = row(-62, "M+ Score")
    local vKey   = row(-78, "Best Timed Key")
    local vRaid  = row(-94, "Raid Progress")
    head(-114, "VoidScout (logged only)")
    local vUtil  = row(-130, "Util Score")
    local vKick  = row(-146, "Interrupts (kick %)")

    local status = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    status:SetPoint("TOPLEFT", 6, -168); status:SetPoint("TOPRIGHT", -6, -168); status:SetJustifyH("LEFT")
    local blwarn = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    blwarn:SetPoint("TOPLEFT", 6, -184); blwarn:SetPoint("TOPRIGHT", -6, -184); blwarn:SetJustifyH("LEFT")

    local function btn(w, y, x, label, onClick)
        local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        b:SetSize(w, 20); b:SetPoint("TOPLEFT", x, y); b:SetText(label)
        b:SetScript("OnClick", function() onClick(); if refresh then refresh() end end)
        return b
    end

    -- Vote row
    local voteLbl = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    voteLbl:SetPoint("TOPLEFT", 6, -206); voteLbl:SetText("Vote:")
    btn(40, -204, 44, "Yes",  function() local n, r = curTarget(); if n then ns.Contacts.Vote(n, r, "up") end end)
    btn(40, -204, 86, "No",   function() local n, r = curTarget(); if n then ns.Contacts.Vote(n, r, "down") end end)
    btn(34, -204, 128, "?",   function() local n, r = curTarget(); if n then ns.Contacts.Vote(n, r, "maybe") end end)
    local tally = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    tally:SetPoint("TOPLEFT", 168, -208)

    -- Action rows
    btn(90, -228, 4,   "Track",     function() local n, r = curTarget(); if n then ns.Contacts.Touch(n, r, "prospect") end end)
    btn(90, -228, 98,  "Trial",     function() local n, r = curTarget(); if n then ns.Contacts.StartTrial(n, r) end end)
    btn(90, -228, 192, "Blacklist", function()
        local n, r = curTarget(); if not n then return end
        ns.Prompt("Blacklist " .. n .. " -- reason (blank = temp 30d):", "", function(reason)
            if reason and reason:gsub("%s", "") ~= "" then ns.Contacts.Blacklist(n, r, "perm", reason)
            else ns.Contacts.Blacklist(n, r, "temp") end
            if refresh then refresh() end
        end)
    end)
    btn(140, -252, 4, "Link main", function()
        local n, r = curTarget(); if not n then return end
        ns.Prompt("Main character for " .. n .. ":", "", function(m)
            if m and m ~= "" then ns.Contacts.SetMain(n, r, m, r) end; if refresh then refresh() end
        end)
    end)
    btn(140, -252, 148, "Timezone / avail", function()
        local n, r = curTarget(); if not n then return end
        local e = ns.Contacts.Get(n, r)
        ns.Prompt("Timezone / availability for " .. n .. ":", e and e.tz or "", function(tz)
            ns.Contacts.SetTZ(n, r, tz); if refresh then refresh() end
        end)
    end)

    -- Links row
    local openLbl = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    openLbl:SetPoint("TOPLEFT", 6, -278); openLbl:SetText("Open:")
    local function linkBtn(x, label, site)
        btn(70, -276, x, label, function()
            local n, r = curTarget(); if n then ns.ShowURL(ns.LinkFor(site, n, r)) end
        end)
    end
    linkBtn(44, "Raider.IO", "rio"); linkBtn(118, "Logs", "wcl"); linkBtn(192, "Armory", "armory")

    local DIM = "|cff707070-|r"
    refresh = function()
        local n, r = curTarget()
        if not n then
            name:SetText("|cff808080No target|r"); name:SetTextColor(1, 1, 1); sub:SetText("")
            for _, fs in ipairs({ vScore, vKey, vRaid, vUtil, vKick }) do fs:SetText(DIM) end
            status:SetText("Target a player -- this updates automatically."); blwarn:SetText(""); tally:SetText("")
            raidTag.txt:SetText("")
            return
        end

        -- follow alt -> main link for the *data* (actions still target the character you met)
        local contact = ns.Contacts.Get(n, r)
        local vetN, vetR, altOf = n, r, nil
        if contact and contact.main then vetN, vetR = contact.main, contact.mainRealm or r; altOf = contact.main end

        local _, classFile = UnitClass("target")
        local col = (classFile and RAID_CLASS_COLORS[classFile]) or NORMAL_FONT_COLOR
        name:SetText(n or "?"); name:SetTextColor(col.r, col.g, col.b)

        local b = _G.VoidScoutBundle and bundleLookup(ns.Slug(vetN, vetR)) or nil
        local rio = rioData(vetN, vetR)

        local parts = {}
        if b then parts[#parts + 1] = ("%s %s |cff888888ilvl %s|r"):format(b.s or "", titleCase(b.c or ""), tostring(b.i or "?")) end
        parts[#parts + 1] = "|cffaaaaaa" .. (vetR or r) .. "|r"
        if altOf then parts[#parts + 1] = "|cffffd100(alt of " .. altOf .. ")|r" end
        local rtz = ns.RealmTZ and ns.RealmTZ(vetR or r)
        if contact and contact.tz and contact.tz ~= "" then parts[#parts + 1] = "|cff66ccffTZ:" .. contact.tz .. "|r"
        elseif rtz then parts[#parts + 1] = "|cff66ccffrealm~" .. rtz .. "|r" end
        sub:SetText(table.concat(parts, "  "))

        -- raid overlap: their local clock at your raid start (manual TZ wins, else realm zone).
        -- Guarded so a not-yet-loaded RealmTZ file degrades gracefully instead of breaking the card.
        local code = (contact and contact.tz and ns.TZCode and ns.TZCode(contact.tz)) or rtz
        local ov, oc
        if ns.RaidOverlap then ov, oc = ns.RaidOverlap(code) end  -- keep both returns (and/or would truncate)
        if ov and oc then
            raidTag.txt:SetText(("|cff%sraid %s their|r"):format(oc, ov))
        else
            -- unknown recruit zone: show your configured raid time, still clickable to change
            raidTag.txt:SetText("|cff888888raid " .. (ns.RaidConfigStr and ns.RaidConfigStr() or "set") .. "|r")
        end

        local score = (rio and rio.score) or (b and b.mp)
        vScore:SetText(score and ("%d%s"):format(score, (rio and rio.score) and " |cff888888RIO|r" or "") or DIM)
        local key = (rio and rio.bestKey and ("+%d %s"):format(rio.bestKey.level, rio.bestKey.dungeon)) or (b and b.tk and b.tk[1])
        vKey:SetText(key or DIM)
        vRaid:SetText((rio and rio.raid) or (b and b.hr and (b.hr .. (b.hrr and (" " .. b.hrr) or ""))) or DIM)
        vUtil:SetText((b and b.us) and tostring(b.us) or DIM)
        vKick:SetText((b and b.e and b.e.ic) and (b.e.ic .. "%") or DIM)

        -- status line
        local rioLoaded = _G.RaiderIO and _G.RaiderIO.GetProfile
        if not rioLoaded and not _G.VoidScoutBundle then status:SetText("RaiderIO + VoidScout both not loaded.")
        elseif not rioLoaded then status:SetText("RaiderIO addon not loaded -- enable it.")
        elseif not rio and not b then status:SetText("No RaiderIO profile for this character yet.")
        elseif b and b.us then status:SetText("RIO + VoidScout-logged" .. (b.ss and (" -- " .. b.ss .. " pulls") or ""))
        else status:SetText("RaiderIO data" .. (b and "" or " (not in VoidScout bundle)")) end

        -- vote tally + trial status
        local up, down, maybe = ns.Contacts.Tally(contact)
        local t = (up + down + maybe > 0) and ("|cff40ff80%d|r / |cffff6060%d|r / |cffffd100%d?|r"):format(up, down, maybe) or ""
        if contact and contact.status == "trial" then
            local d = ns.Contacts.TrialDay(contact)
            if d then t = t .. ("   |cffa335eeTrial d%d/%d%s|r"):format(d, ns.TRIAL_DAYS, d >= ns.TRIAL_DAYS and " DUE!" or "") end
        end
        tally:SetText(t)

        -- blacklist warning
        local bl, reason = ns.Contacts.IsBlacklisted(n, r)
        if bl then
            blwarn:SetText(("|cffff2020BLACKLISTED (%s)%s|r"):format(bl, reason and (": " .. reason) or ""))
        else blwarn:SetText("") end
    end
    return f, refresh
end)
