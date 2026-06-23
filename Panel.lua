-- VoidRecruit.Panel -- companion hub docked to the Guild & Communities frame.
-- A tabbed shell: each view module registers itself with AddView(); the button row
-- switches between them. Movable (remembers position), right-click to re-dock.
local ADDON, ns = ...
local Panel = {}
ns.Panel = Panel

local GAP = 6
local panel, content
local views = {}     -- ordered: { key, label, builder, frame, refresh, btn }
local active

-- View modules call this at load time; buttons + frames are built lazily.
function Panel.AddView(key, label, builder)
    views[#views + 1] = { key = key, label = label, builder = builder }
end

local function showView(entry)
    for _, v in ipairs(views) do if v.frame then v.frame:Hide() end end
    if not entry.frame then
        entry.frame, entry.refresh = entry.builder(content)
    end
    entry.frame:Show()
    if entry.refresh then entry.refresh() end
    active = entry
    for _, v in ipairs(views) do if v.btn then v.btn:SetEnabled(v ~= entry) end end
end

function Panel.ShowView(key)
    for _, v in ipairs(views) do if v.key == key then showView(v); return end end
end

function Panel.Refresh()
    if active and active.refresh then active.refresh() end
end

function Panel.ActiveKey() return active and active.key end

local function build()
    if panel then return panel end
    panel = CreateFrame("Frame", "VoidRecruitPanel", CommunitiesFrame, "BackdropTemplate")
    panel:SetSize(300, 470)
    panel:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    panel:SetBackdropColor(0.05, 0.05, 0.08, 0.96)

    panel:SetMovable(true); panel:EnableMouse(true); panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", function(s) s:StartMoving() end)
    panel:SetScript("OnDragStop", function(s)
        s:StopMovingOrSizing()
        local point, _, rel, x, y = s:GetPoint(1)
        ns.db = ns.db or {}; ns.db.panelPos = { point = point, relPoint = rel, x = x, y = y, moved = true }
    end)
    panel:SetScript("OnMouseUp", function(s, b)
        if b == "RightButton" then ns.db = ns.db or {}; ns.db.panelPos = nil; Panel.Dock() end
    end)

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 12, -10); title:SetText("|cffa335eeVoidRecruit|r")

    -- tab buttons from registered views
    local prev
    for _, v in ipairs(views) do
        local btn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        btn:SetSize(86, 22); btn:SetText(v.label)
        if prev then btn:SetPoint("LEFT", prev, "RIGHT", 4, 0) else btn:SetPoint("TOPLEFT", 10, -34) end
        btn:SetScript("OnClick", function() showView(v) end)
        v.btn = btn; prev = btn
    end

    content = CreateFrame("Frame", nil, panel)
    content:SetPoint("TOPLEFT", 8, -62); content:SetPoint("BOTTOMRIGHT", -8, 8)
    panel.content = content
    panel:Hide()
    return panel
end

function Panel.Dock()
    if not panel then return end
    panel:ClearAllPoints()
    panel:SetFrameStrata(CommunitiesFrame:GetFrameStrata())
    panel:SetFrameLevel((CommunitiesFrame:GetFrameLevel() or 1) + 1)
    local pos = ns.db and ns.db.panelPos
    if pos and pos.moved then
        panel:SetPoint(pos.point or "TOPLEFT", UIParent, pos.relPoint or "TOPLEFT", pos.x or 0, pos.y or 0)
        return
    end
    local right = CommunitiesFrame:GetRight()
    if right and (right + panel:GetWidth() + GAP) > GetScreenWidth() then
        panel:SetPoint("TOPRIGHT", CommunitiesFrame, "TOPLEFT", -GAP, 0)
    else
        panel:SetPoint("TOPLEFT", CommunitiesFrame, "TOPRIGHT", GAP, 0)
    end
end

function Panel.Attach()
    if not CommunitiesFrame then return end
    build()
    if not CommunitiesFrame._voidRecruitHook then
        CommunitiesFrame:HookScript("OnShow", function()
            Panel.Dock(); panel:Show()
            if not active and views[1] then showView(views[1]) else Panel.Refresh() end
        end)
        CommunitiesFrame:HookScript("OnHide", function() panel:Hide() end)
        CommunitiesFrame._voidRecruitHook = true
        -- keep the Vet view live when the target changes
        local ev = CreateFrame("Frame"); ev:RegisterEvent("PLAYER_TARGET_CHANGED")
        ev:SetScript("OnEvent", function() if Panel.ActiveKey() == "vet" then Panel.Refresh() end end)
    end
    if CommunitiesFrame:IsShown() then
        Panel.Dock(); panel:Show()
        if not active and views[1] then showView(views[1]) end
    end
end
