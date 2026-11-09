local ADDON, ns = ...

ns.name = ADDON
local GetMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
ns.version = (GetMeta and GetMeta(ADDON, "Version")) or "0.0.1b"

local DEFAULTS = {
    iconPoint = "CENTER",
    iconRelPoint = "CENTER",
    iconX = 0,
    iconY = -150,
    iconShown = true,
    showOnLogin = false,
}

ns.queue = {}
ns.skipped = {}   -- key -> sequence number; higher = further back in the queue
ns.skipSeq = 0

local DISENCHANT_SPELL_ID = 13262

-- Localised spell name for the /cast line; falls back to English.
function ns:GetSpellName()
    local name
    if C_Spell and C_Spell.GetSpellName then
        name = C_Spell.GetSpellName(DISENCHANT_SPELL_ID)
    elseif GetSpellInfo then
        name = GetSpellInfo(DISENCHANT_SPELL_ID)
    end
    return name or "Disenchant"
end

function ns:Print(msg)
    local r, g, b = ns.Theme:GetAccent()
    print(string.format("|cff%02x%02x%02x%s|r %s", r * 255, g * 255, b * 255, "BreakItDown", msg))
end

-- ---------------------------------------------------------------------------
-- Queue
-- ---------------------------------------------------------------------------
function ns:Rebuild()
    local list = ns.Scanner:Scan()
    table.sort(list, function(a, b)
        local sa, sb = ns.skipped[a.key] or 0, ns.skipped[b.key] or 0
        if sa ~= sb then return sa < sb end
        if a.bag ~= b.bag then return a.bag < b.bag end
        return a.slot < b.slot
    end)
    ns.queue = list
    if ns.Compact then ns.Compact:Update() end
    if ns.Icon then ns.Icon:Update() end
end

local rebuildPending = false
function ns:QueueRebuild()
    if rebuildPending then return end
    rebuildPending = true
    C_Timer.After(0.15, function()
        rebuildPending = false
        ns:Rebuild()
    end)
end

-- Sends the current item to the back of the queue.
function ns:Skip()
    local item = ns.queue[1]
    if not item then return end
    ns.skipSeq = ns.skipSeq + 1
    ns.skipped[item.key] = ns.skipSeq
    ns:Rebuild()
end

-- ---------------------------------------------------------------------------
-- Events
-- ---------------------------------------------------------------------------
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")

f:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON then
        BreakItDownDB = BreakItDownDB or {}
        for k, v in pairs(DEFAULTS) do
            if BreakItDownDB[k] == nil then BreakItDownDB[k] = v end
        end
        ns.db = BreakItDownDB
        -- v2: the icon is the main entry point now, so don't auto-open the window
        if (ns.db.dbVersion or 0) < 2 then
            ns.db.showOnLogin = false
            ns.db.dbVersion = 2
        end

    elseif event == "PLAYER_LOGIN" then
        ns.Compact:Build()
        ns.Icon:Build()
        ns.History:Init()
        ns.HistoryView:Build()
        f:RegisterEvent("BAG_UPDATE_DELAYED")
        f:RegisterEvent("GET_ITEM_INFO_RECEIVED")
        f:RegisterEvent("PLAYER_REGEN_ENABLED")
        ns:Rebuild()
        if ns.db.showOnLogin then ns.Compact:Show() end

    elseif event == "BAG_UPDATE_DELAYED" or event == "GET_ITEM_INFO_RECEIVED" then
        ns:QueueRebuild()

    elseif event == "PLAYER_REGEN_ENABLED" then
        -- secure attributes can only change out of combat
        ns.Compact:ApplySecure()
    end
end)

-- ---------------------------------------------------------------------------
-- Slash commands
-- ---------------------------------------------------------------------------
SLASH_BREAKITDOWN1 = "/bid"
SLASH_BREAKITDOWN2 = "/breakitdown"

SlashCmdList["BREAKITDOWN"] = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")
    if msg == "" or msg == "toggle" then
        ns.Compact:Toggle()
    elseif msg == "refresh" then
        ns.Theme:Refresh()
        ns:Rebuild()
        ns:Print("Refreshed.")
    elseif msg == "reset" then
        ns.db.iconPoint, ns.db.iconRelPoint = DEFAULTS.iconPoint, DEFAULTS.iconRelPoint
        ns.db.iconX, ns.db.iconY = DEFAULTS.iconX, DEFAULTS.iconY
        ns.Icon:RestorePosition()
        ns:Print("Icon position reset.")
    elseif msg == "debug" then
        local b = ns.Icon.frame
        local macro = b and b:GetAttribute("macrotext1") or "(none)"
        ns:Print("queue=" .. #ns.queue .. "  spell=" .. ns:GetSpellName() .. "  combat=" .. tostring(InCombatLockdown()))
        ns:Print("icon macro: " .. (macro:gsub("\n", " | ")))
    elseif msg == "icon" then
        ns.Icon:ToggleVisible()
    elseif msg == "version" then
        ns:Print("v" .. ns.version)
    else
        ns:Print("v" .. ns.version .. " commands: /bid (toggle), /bid refresh, /bid reset, /bid icon, /bid debug, /bid version")
    end
end
