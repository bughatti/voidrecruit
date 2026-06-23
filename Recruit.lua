-- VoidRecruit.Recruit -- compose a recruitment message and broadcast it to chat channels
-- (a recruitment AD, not /who spam -- it brings quality applicants TO you). Borrows Guild
-- Recruiter's good bits: {guild} token, channel posting, and a send throttle so we never flood.
local ADDON, ns = ...
local lastSend = 0

local function expand(msg)
    local g = (IsInGuild() and GetGuildInfo("player")) or "our guild"
    return (msg:gsub("{guild}", g):gsub("{me}", UnitName("player") or ""))
end

local function channelList()
    local list = {}
    if IsInGuild() then list[#list + 1] = { kind = "GUILD", id = 0, label = "Guild" } end
    local raw = { GetChannelList() }
    for i = 1, #raw, 3 do
        local id, nm = raw[i], raw[i + 1]
        if type(id) == "number" and nm then list[#list + 1] = { kind = "CHANNEL", id = id, label = nm } end
    end
    return list
end

ns.Panel.AddView("recruit", "Recruit", function(parent)
    local f = CreateFrame("Frame", nil, parent); f:SetAllPoints()

    local box = CreateFrame("EditBox", nil, f, "BackdropTemplate")
    box:SetMultiLine(true); box:SetAutoFocus(false); box:SetMaxLetters(255); box:SetFontObject(ChatFontNormal)
    box:SetPoint("TOPLEFT", 2, -2); box:SetPoint("TOPRIGHT", -2, -2); box:SetHeight(60)
    box:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    box:SetBackdropColor(0, 0, 0, 0.5); box:SetTextInsets(6, 6, 6, 6)
    box:SetText((VoidRecruitDB and VoidRecruitDB.message) or "LF quality players for {guild}'s Mythic core -- whisper me if interested.")
    box:SetScript("OnTextChanged", function(self) VoidRecruitDB = VoidRecruitDB or {}; VoidRecruitDB.message = self:GetText() end)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    local hint = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 2, -3)
    hint:SetText("Tokens: {guild} {me}. Posts once per channel, throttled.")

    local lbl = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lbl:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -6); lbl:SetText("Post to:")

    local checks = {}
    do
        local list = channelList()
        for i, ch in ipairs(list) do
            local cb = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
            cb:SetSize(20, 20); cb:SetPoint("TOPLEFT", 4, -112 - (i - 1) * 20)
            local t = cb:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            t:SetPoint("LEFT", cb, "RIGHT", 2, 0); t:SetText(ch.label)
            cb.ch = ch
            checks[#checks + 1] = cb
        end
    end

    local function doSend(text, targets)
        if GetTime() - lastSend < 15 then
            print("|cffa335eeVoidRecruit|r hold on -- wait a few seconds between broadcasts."); return
        end
        lastSend = GetTime()
        local msg = expand(text)
        for i, ch in ipairs(targets) do
            C_Timer.After((i - 1) * 0.6, function()
                if ch.kind == "GUILD" then SendChatMessage(msg, "GUILD")
                else SendChatMessage(msg, "CHANNEL", nil, ch.id) end
            end)
        end
        print(("|cffa335eeVoidRecruit|r posted to %d channel(s)."):format(#targets))
    end

    local send = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    send:SetSize(120, 22); send:SetPoint("BOTTOMLEFT", 4, 4); send:SetText("Broadcast")
    send:SetScript("OnClick", function()
        local text = box:GetText()
        if not text or text:gsub("%s", "") == "" then print("|cffa335eeVoidRecruit|r write a message first."); return end
        local targets = {}
        for _, cb in ipairs(checks) do if cb:GetChecked() then targets[#targets + 1] = cb.ch end end
        if #targets == 0 then print("|cffa335eeVoidRecruit|r pick at least one channel."); return end
        doSend(text, targets)
    end)

    local wis = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    wis:SetSize(140, 22); wis:SetPoint("BOTTOMRIGHT", -4, 4); wis:SetText("Whisper target")
    wis:SetScript("OnClick", function()
        if not (UnitExists("target") and UnitIsPlayer("target")) then print("|cffa335eeVoidRecruit|r no player targeted."); return end
        local text = box:GetText()
        if not text or text:gsub("%s", "") == "" then print("|cffa335eeVoidRecruit|r write a message first."); return end
        local full = GetUnitName("target", true)
        SendChatMessage(expand(text), "WHISPER", nil, full)
        local n, r = UnitName("target"); ns.Contacts.Touch(n, r, "messaged")
        print("|cffa335eeVoidRecruit|r whispered " .. (full or "target") .. " (logged to Contacts).")
    end)

    return f, function() end
end)
