-- VoidRecruit.Contacts -- the pipeline / CRM. Borrows from GRM (notes, alt/main, history),
-- Guild Recruiter (don't-recontact), and A.X.I.O.M./GRIP (two-tier blacklist with reasons).
-- Each contact: status, note, votes{officer=up/down/maybe}, blacklist(tier+reason+expiry),
-- trialStart, main link, timezone. Stored in VoidRecruitDB.contacts keyed by bundle slug.
local ADDON, ns = ...
local Contacts = {}
ns.Contacts = Contacts

local ORDER = { "prospect", "messaged", "replied", "trial", "core", "declined" }
local COLOR = {
    prospect = "ffd100", messaged = "00c7ff", replied = "40ff80",
    trial = "a335ee", core = "1eff00", declined = "888888",
}
local NEXT = {}
for i, s in ipairs(ORDER) do NEXT[s] = ORDER[(i % #ORDER) + 1] end

local function store()
    VoidRecruitDB = VoidRecruitDB or {}
    VoidRecruitDB.contacts = VoidRecruitDB.contacts or {}
    return VoidRecruitDB.contacts
end

local function refreshIfShown()
    if ns.Panel and ns.Panel.ActiveKey() == "contacts" then ns.Panel.Refresh() end
end

function Contacts.Touch(name, realm, status)
    local slug = ns.Slug(name, realm); if not slug then return end
    local c = store()
    local e = c[slug]
    if not e then e = { name = name, realm = realm, status = status or "prospect" }; c[slug] = e end
    if status then e.status = status end
    e.last = time(); e.by = UnitName("player")
    refreshIfShown()
    return e, slug
end

function Contacts.Get(name, realm) local slug = ns.Slug(name, realm); return slug and store()[slug], slug end
function Contacts.Cycle(slug) local e = store()[slug]; if e then e.status = NEXT[e.status] or ORDER[1]; e.last = time() end end
function Contacts.Remove(slug) store()[slug] = nil end
function Contacts.StatusColor(s) return COLOR[s] or "ffffff" end

-- Voting (officer name -> up/down/maybe)
function Contacts.Vote(name, realm, v)
    local e = Contacts.Touch(name, realm); if not e then return end
    e.votes = e.votes or {}; e.votes[UnitName("player")] = v; refreshIfShown()
end
function Contacts.Tally(e)
    local up, down, maybe = 0, 0, 0
    if e and e.votes then
        for _, v in pairs(e.votes) do
            if v == "up" then up = up + 1 elseif v == "down" then down = down + 1 else maybe = maybe + 1 end
        end
    end
    return up, down, maybe
end

-- Two-tier blacklist
function Contacts.Blacklist(name, realm, tier, reason)
    local e = Contacts.Touch(name, realm); if not e then return end
    e.bl, e.blReason = tier, reason
    e.blUntil = (tier == "temp") and (time() + ns.TEMP_BL_DAYS * 86400) or nil
    e.status = "declined"; refreshIfShown()
end
function Contacts.Unblacklist(slug) local e = store()[slug]; if e then e.bl, e.blReason, e.blUntil = nil, nil, nil end end
function Contacts.IsBlacklisted(name, realm)
    local e = Contacts.Get(name, realm)
    if not e or not e.bl then return nil end
    if e.bl == "temp" and e.blUntil and time() > e.blUntil then e.bl, e.blReason, e.blUntil = nil, nil, nil; return nil end
    return e.bl, e.blReason
end

-- Trials
function Contacts.StartTrial(name, realm)
    local e = Contacts.Touch(name, realm, "trial"); if e then e.trialStart = time() end; refreshIfShown()
end
function Contacts.TrialDay(e)
    if not (e and e.trialStart) then return nil end
    return math.floor((time() - e.trialStart) / 86400)
end

-- Alt -> main link, timezone, note
function Contacts.SetMain(name, realm, mainName, mainRealm)
    local e = Contacts.Touch(name, realm); if e then e.main, e.mainRealm = mainName, mainRealm end; refreshIfShown()
end
function Contacts.SetTZ(name, realm, tz) local e = Contacts.Touch(name, realm); if e then e.tz = tz end; refreshIfShown() end
function Contacts.SetNote(name, realm, note) local e = Contacts.Touch(name, realm); if e then e.note = note end; refreshIfShown() end

function Contacts.List()
    local out = {}
    for slug, e in pairs(store()) do out[#out + 1] = { slug = slug, e = e } end
    table.sort(out, function(a, b) return (a.e.last or 0) > (b.e.last or 0) end)
    return out
end

-- Any trials past their decision window? (for the reminder)
function Contacts.OverdueTrials()
    local due = {}
    for _, item in ipairs(Contacts.List()) do
        local d = Contacts.TrialDay(item.e)
        if item.e.status == "trial" and d and d >= ns.TRIAL_DAYS then due[#due + 1] = item end
    end
    return due
end

-- View
ns.Panel.AddView("contacts", "Contacts", function(parent)
    local f = CreateFrame("Frame", nil, parent); f:SetAllPoints()
    local hdr = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hdr:SetPoint("TOPLEFT", 4, -2); hdr:SetText("Left-click: cycle status   Right-click: remove")
    local empty = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    empty:SetPoint("TOPLEFT", 6, -24); empty:SetWidth(280); empty:SetJustifyH("LEFT")
    empty:SetText("No contacts yet. Vet a player and use the buttons (Track / Trial / Vote / Blacklist).")

    local rows = {}
    local refresh
    local function makeRow(i)
        local r = CreateFrame("Button", nil, f)
        r:SetSize(286, 16); r:SetPoint("TOPLEFT", 4, -22 - (i - 1) * 17)
        r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        r.txt = r:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        r.txt:SetPoint("LEFT", 0, 0); r.txt:SetJustifyH("LEFT"); r.txt:SetWidth(286)
        r:SetScript("OnClick", function(self, button)
            if button == "RightButton" then Contacts.Remove(self.slug) else Contacts.Cycle(self.slug) end
            refresh()
        end)
        return r
    end
    refresh = function()
        local list = Contacts.List()
        empty:SetShown(#list == 0)
        for _, r in ipairs(rows) do r:Hide() end
        for i = 1, math.min(#list, 16) do
            local item = list[i]; local e = item.e
            rows[i] = rows[i] or makeRow(i)
            local r = rows[i]; r.slug = item.slug
            local st = e.status or "prospect"
            local line = ("%s  |cff%s[%s]|r"):format(e.name or "?", COLOR[st] or "ffffff", st)
            local up, down = Contacts.Tally(e)
            if up + down > 0 then line = line .. ("  |cff40ff80%d|r/|cffff6060%d|r"):format(up, down) end
            if st == "trial" then local d = Contacts.TrialDay(e); if d then
                line = line .. ("  |cffa335eed%d/%d|r"):format(d, ns.TRIAL_DAYS) end end
            if e.bl then line = line .. ("  |cffff2020[BL%s]|r"):format(e.bl == "perm" and "!" or "") end
            if e.tz then line = line .. ("  |cff888888%s|r"):format(e.tz) end
            r.txt:SetText(line)
            r:Show()
        end
    end
    return f, refresh
end)
