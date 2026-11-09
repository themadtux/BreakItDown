local ADDON, ns = ...

-- Records every disenchant: which item went in, and what came out.
-- Stored in BreakItDownDB.history (newest first, capped at MAX_ENTRIES).
--
-- How it works:
--   cast starts   -> remember which bag item is being disenchanted (the locked one)
--   cast succeeds -> wait for the loot
--   loot window   -> read what is in it (falls back to the "You receive loot" chat lines)
--   loot closed   -> save the entry

local History = {}
ns.History = History

local MAX_ENTRIES = 200
local LOOT_TIMEOUT = 20
local DE_SPELL_ID = 13262

local patterns

local function SpellNameOf(id)
    if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
    if GetSpellInfo then return (GetSpellInfo(id)) end
end

local function IsDisenchant(spellID)
    if not spellID then return false end
    if spellID == DE_SPELL_ID then return true end
    local n = SpellNameOf(spellID)
    return n ~= nil and n == ns:GetSpellName()
end

-- Turns a localised format string like "You receive loot: %s." into a Lua pattern
local function Pattern(fmt)
    if type(fmt) ~= "string" then return nil end
    fmt = fmt:gsub("([%^%$%(%)%.%[%]%*%+%-%?])", "%%%1")
    fmt = fmt:gsub("%%s", "(.+)")
    fmt = fmt:gsub("%%d", "(%%d+)")
    return "^" .. fmt .. "$"
end

local function BuildPatterns()
    patterns = {}
    local function add(global, hasQty)
        local p = Pattern(global)
        if p then patterns[#patterns + 1] = { p, hasQty } end
    end
    add(_G.LOOT_ITEM_SELF_MULTIPLE, true)
    add(_G.LOOT_ITEM_PUSHED_SELF_MULTIPLE, true)
    add(_G.LOOT_ITEM_SELF, false)
    add(_G.LOOT_ITEM_PUSHED_SELF, false)
end

local function Snapshot(it)
    if not it then return { name = "Unknown item" } end
    return { link = it.link, name = it.name, quality = it.quality, ilvl = it.ilvl, itemID = it.itemID }
end

local function AddLoot(p, link, qty)
    for _, l in ipairs(p.loot) do
        if l.link == link then
            l.qty = l.qty + qty
            return
        end
    end
    p.loot[#p.loot + 1] = { link = link, qty = qty }
end

function History:BeginCast(castGUID)
    if self.pending and self.pending.success then self:Finalize() end

    -- The item being disenchanted is locked in the bag while the cast runs
    local target
    for _, it in ipairs(ns.Scanner:Scan()) do
        if it.locked then
            target = it
            break
        end
    end
    target = target or ns.queue[1]

    self.pending = {
        t = time(),
        castGUID = castGUID,
        item = Snapshot(target),
        loot = {},
        success = false,
    }
end

function History:Finalize()
    local p = self.pending
    if not p then return end
    self.pending = nil
    local list = ns.db.history
    table.insert(list, 1, { t = p.t, item = p.item, loot = p.loot })
    while #list > MAX_ENTRIES do table.remove(list) end
    if ns.HistoryView then ns.HistoryView:Refresh() end
end

function History:Clear()
    wipe(ns.db.history)
    if ns.HistoryView then ns.HistoryView:Refresh() end
end

function History:CaptureLootWindow()
    local p = self.pending
    if not p or p.source == "chat" or p.windowDone then return end
    if not (GetNumLootItems and GetLootSlotLink) then return end

    local itemType = (Enum and Enum.LootSlotType and Enum.LootSlotType.Item) or 1
    local got = false
    for i = 1, GetNumLootItems() do
        local slotType = GetLootSlotType and GetLootSlotType(i)
        if slotType == nil or slotType == itemType then
            local link = GetLootSlotLink(i)
            if link then
                local qty = 1
                if GetLootSlotInfo then
                    local _, _, q = GetLootSlotInfo(i)
                    if type(q) == "number" and q > 0 then qty = q end
                end
                AddLoot(p, link, qty)
                got = true
            end
        end
    end
    if got then
        p.windowDone = true
        p.source = "window"
    end
end

function History:CaptureChat(msg)
    local p = self.pending
    if not p or not p.success or p.source == "window" or not msg then return end
    for _, pat in ipairs(patterns) do
        local a, b = msg:match(pat[1])
        if a then
            AddLoot(p, a, pat[2] and tonumber(b) or 1)
            p.source = "chat"
            return
        end
    end
end

local function OnEvent(_, event, a, b, c)
    if event == "UNIT_SPELLCAST_START" then
        if a == "player" and IsDisenchant(c) then History:BeginCast(b) end

    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        if a ~= "player" or not IsDisenchant(c) then return end
        local p = History.pending
        if p and p.success then return end
        if p and p.castGUID and b and p.castGUID ~= b then return end
        if not p then
            History:BeginCast(b)   -- cast with no START event (instant); best guess at the item
            p = History.pending
        end
        p.success = true
        C_Timer.After(LOOT_TIMEOUT, function()
            if History.pending == p then History:Finalize() end
        end)

    elseif event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_FAILED" then
        if a ~= "player" or not IsDisenchant(c) then return end
        local p = History.pending
        if p and not p.success and (not p.castGUID or not b or p.castGUID == b) then
            History.pending = nil
        end

    elseif event == "LOOT_OPENED" then
        History:CaptureLootWindow()

    elseif event == "LOOT_CLOSED" then
        if History.pending and History.pending.success then History:Finalize() end

    elseif event == "CHAT_MSG_LOOT" then
        History:CaptureChat(a)
    end
end

function History:Init()
    ns.db.history = ns.db.history or {}
    BuildPatterns()
    local f = CreateFrame("Frame")
    for _, e in ipairs({
        "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_SUCCEEDED",
        "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_FAILED",
        "LOOT_OPENED", "LOOT_CLOSED", "CHAT_MSG_LOOT",
    }) do
        f:RegisterEvent(e)
    end
    f:SetScript("OnEvent", OnEvent)
    self.frame = f
end
