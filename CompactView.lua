local ADDON, ns = ...

local Theme = ns.Theme
local Compact = {}
ns.Compact = Compact

local WIDTH, HEIGHT = 480, 100
local GAP = 8
local SLIDE_DIST = 60
local SLIDE_TIME = 0.18
local ICON_SIZE = 24
local MAT_SIZE = 16
local MAX_ROWS = 3
local ROW_PITCH = 17
local ROW_TOP = -14          -- y of the first row (shifted up 12px)
local LIST_W = 190
local LIST_X = WIDTH - 10 - LIST_W      -- left edge of the list
local NAME_W = LIST_W - MAT_SIZE - 5
local NAME_MAX = LIST_X - 42 - 10

local GetItemIcon = (C_Item and C_Item.GetItemIconByID) or GetItemIcon
local GetItemInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
local QUESTION_MARK = 134400
local DIM_HEX = "|cff8a919c"

function Compact:Build()
    if self.frame then return end

    -- Main window ----------------------------------------------------------
    local f = CreateFrame("Frame", "BreakItDownCompact", UIParent, "BackdropTemplate")
    f:SetSize(WIDTH, HEIGHT)
    f:SetFrameStrata("MEDIUM")
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    Theme:SkinFrame(f)
    f:Hide()
    self.frame = f

    -- Thin accent line along the top edge
    local line = f:CreateTexture(nil, "OVERLAY")
    line:SetHeight(2)
    line:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
    line:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -1)
    Theme:Register(function(r, g, b) line:SetColorTexture(r, g, b, 1) end)

    -- Item icon (24x24) ------------------------------------------------------
    local iconBtn = CreateFrame("Button", nil, f, "BackdropTemplate")
    iconBtn:SetSize(ICON_SIZE, ICON_SIZE)
    iconBtn:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -14)
    iconBtn:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    iconBtn:SetBackdropBorderColor(unpack(Theme.BORDER))
    local icon = iconBtn:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 1, -1)
    icon:SetPoint("BOTTOMRIGHT", -1, 1)
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    iconBtn:SetScript("OnEnter", function(s)
        local item = ns.queue[1]
        if not item then return end
        GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
        GameTooltip:SetBagItem(item.bag, item.slot)
        GameTooltip:Show()
    end)
    iconBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    self.icon, self.iconBtn = icon, iconBtn

    -- Item name ------------------------------------------------------------
    local name = f:CreateFontString(nil, "OVERLAY")
    Theme:Font(name, 15)
    name:SetPoint("LEFT", iconBtn, "RIGHT", 8, 0)
    name:SetWidth(NAME_MAX)
    name:SetJustifyH("LEFT")
    name:SetWordWrap(false)
    self.name = name

    -- "Breaks into" rows: [16x16 icon]  Name  ~chance% --------------------------
    self.rows = {}
    for i = 1, MAX_ROWS do
        local y = ROW_TOP - (i - 1) * ROW_PITCH

        local m = CreateFrame("Button", nil, f, "BackdropTemplate")
        m:SetSize(MAT_SIZE, MAT_SIZE)
        m:SetPoint("TOPLEFT", f, "TOPLEFT", LIST_X, y)
        m:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
        m:SetBackdropBorderColor(unpack(Theme.BORDER))
        local tex = m:CreateTexture(nil, "ARTWORK")
        tex:SetPoint("TOPLEFT", 1, -1)
        tex:SetPoint("BOTTOMRIGHT", -1, 1)
        tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        m.tex = tex
        m:SetScript("OnEnter", function(s)
            local e = s.entry
            if not e then return end
            GameTooltip:SetOwner(s, "ANCHOR_LEFT")
            if e.itemID then
                GameTooltip:SetHyperlink("item:" .. e.itemID)
            else
                GameTooltip:SetText(e.name or "?")
            end
            GameTooltip:Show()
        end)
        m:SetScript("OnLeave", function() GameTooltip:Hide() end)

        local nm = f:CreateFontString(nil, "OVERLAY")
        Theme:Font(nm, 11)
        nm:SetPoint("LEFT", m, "RIGHT", 5, 0)
        nm:SetWidth(NAME_W)
        nm:SetJustifyH("LEFT")
        nm:SetWordWrap(false)
        nm:SetTextColor(unpack(Theme.TEXT))
        m.nameText = nm


        m:Hide(); nm:Hide()
        self.rows[i] = m
    end

    -- Buttons --------------------------------------------------------------
    local de = Theme:CreateButton(f, "Disenchant", 100, 24, true)
    de:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 10, 10)
    de:RegisterForClicks(GetCVarBool("ActionButtonUseKeyDown") and "AnyDown" or "AnyUp")
    de:SetAttribute("type", "macro")
    self.de = de

    local skip = Theme:CreateButton(f, "Skip", 56, 24, false)
    skip:SetPoint("LEFT", de, "RIGHT", 8, 0)
    skip:SetScript("OnClick", function() ns:Skip() end)
    self.skip = skip

    local history = Theme:CreateButton(f, "History", 64, 24, false)
    history:SetPoint("LEFT", skip, "RIGHT", 8, 0)
    history:SetScript("OnClick", function() ns.HistoryView:Toggle() end)
    self.history = history

    -- Close button (top right) --------------------------------------------
    local close = CreateFrame("Button", nil, f)
    close:SetSize(18, 18)
    close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -7)
    local x = close:CreateFontString(nil, "OVERLAY")
    Theme:Font(x, 14)
    x:SetPoint("CENTER")
    x:SetText("x")
    x:SetTextColor(unpack(Theme.DIM))
    close:SetScript("OnEnter", function()
        local r, g, b = Theme:GetAccent()
        x:SetTextColor(r, g, b)
    end)
    close:SetScript("OnLeave", function() x:SetTextColor(unpack(Theme.DIM)) end)
    close:SetScript("OnClick", function() Compact:Close() end)

    -- Queue counter --------------------------------------------------------
    local count = f:CreateFontString(nil, "OVERLAY")
    Theme:Font(count, 11)
    count:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 10)
    count:SetJustifyH("RIGHT")
    self.count = count
    Theme:Register(function(r, g, b)
        self.accentHex = string.format("|cff%02x%02x%02x", r * 255, g * 255, b * 255)
    end)

    f:SetScript("OnShow", function()
        Theme:Refresh()
        Compact:Update()
        Compact:StartSlide()
    end)
    f:SetScript("OnHide", function(s)
        s:SetScript("OnUpdate", nil)
        s:SetAlpha(1)
        Compact.progress = 0
        if ns.HistoryView then ns.HistoryView:Hide() end
    end)
end

-- Which side of the icon the window opens on: away from the nearest screen edge.
function Compact:ComputeDir()
    local b = ns.Icon and ns.Icon.frame
    if not b or not b:GetLeft() then return 1 end
    local ratio = b:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local left, right = b:GetLeft() * ratio, b:GetRight() * ratio
    local rightSpace, leftSpace = UIParent:GetWidth() - right, left
    local need = WIDTH + GAP
    if rightSpace >= need then return 1 end
    if leftSpace >= need then return -1 end
    return (rightSpace >= leftSpace) and 1 or -1
end

-- Anchors the window to the icon. off = extra horizontal offset used by the slide.
function Compact:Place(off)
    local f, b = self.frame, ns.Icon and ns.Icon.frame
    if not (f and b) then return end
    f:ClearAllPoints()
    if (self.slideDir or 1) == 1 then
        f:SetPoint("LEFT", b, "RIGHT", GAP + off, 0)
    else
        f:SetPoint("RIGHT", b, "LEFT", -GAP + off, 0)
    end
end

-- Slides the window out from the icon (target 1) or back into it (target 0).
function Compact:Animate(target)
    local f = self.frame
    self.target = target
    f:SetScript("OnUpdate", function(s, dt)
        local p = self.progress or 0
        if self.target == 1 then
            p = math.min(p + dt / SLIDE_TIME, 1)
        else
            p = math.max(p - dt / SLIDE_TIME, 0)
        end
        self.progress = p
        local e = 1 - (1 - p) * (1 - p)
        self:Place(-self.slideDir * SLIDE_DIST * (1 - e))
        s:SetAlpha(e)
        if p == self.target then
            s:SetScript("OnUpdate", nil)
            if p == 0 then s:Hide() end
        end
    end)
end

-- Called when the window is shown: pick a side, then slide out.
function Compact:StartSlide()
    self.slideDir = self:ComputeDir()
    self.progress = 0
    self:Place(-self.slideDir * SLIDE_DIST)
    self.frame:SetAlpha(0)
    self:Animate(1)
end

-- Slides back into the icon, then hides.
function Compact:Close()
    local f = self.frame
    if not (f and f:IsShown()) then return end
    if ns.HistoryView then ns.HistoryView:Hide() end
    self:Animate(0)
end

-- The Disenchant button is a secure button; its macro can only change out of
-- combat, so a change made during combat is deferred (see PLAYER_REGEN_ENABLED).
function Compact:ApplySecure()
    if not self.de then return end
    if InCombatLockdown() then
        self.needSecure = true
        return
    end
    self.needSecure = false
    if ns.Icon then ns.Icon:ApplySecure() end
    local item = ns.queue[1]
    if item then
        self.de:SetAttribute("macrotext",
            "/cast " .. ns:GetSpellName() .. "\n/use " .. item.bag .. " " .. item.slot)
    else
        self.de:SetAttribute("macrotext", "")
    end
end

function Compact:UpdateRows(entries)
    for i, m in ipairs(self.rows) do
        local e = entries and entries[i]
        if e then
            m.tex:SetTexture((e.itemID and GetItemIcon and GetItemIcon(e.itemID)) or QUESTION_MARK)
            m.entry = e

            -- Full item name from the client; falls back to the short label
            -- until the item is cached (a refresh follows when it arrives).
            local full = e.itemID and GetItemInfo(e.itemID)
            if e.itemID and not full and C_Item and C_Item.RequestLoadItemDataByID then
                C_Item.RequestLoadItemDataByID(e.itemID)
            end
            m.nameText:SetText(full or e.name or "?")

            m:Show(); m.nameText:Show()
        else
            m.entry = nil
            m:Hide(); m.nameText:Hide()
        end
    end
end

function Compact:Update()
    if not self.frame then return end

    local item = ns.queue[1]
    local total = #ns.queue

    if item then
        local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[item.quality]
        self.icon:SetTexture(item.icon)
        self.name:SetText(item.name)
        if c then self.name:SetTextColor(c.r, c.g, c.b) else self.name:SetTextColor(1, 1, 1) end
        self:UpdateRows(ns.Data:GetBreakdown(item))

        self.de:SetAlpha(1)
        self.skip:SetAlpha(total > 1 and 1 or 0.4)
    else
        self.icon:SetTexture(nil)
        self.name:SetText("Nothing to disenchant")
        self.name:SetTextColor(unpack(Theme.DIM))
        self:UpdateRows(nil)
        self.de:SetAlpha(0.4)
        self.skip:SetAlpha(0.4)
    end

    self.count:SetText(DIM_HEX .. "In queue:|r " .. (self.accentHex or "") .. total .. "|r")
    self:ApplySecure()
end

function Compact:Show()
    if self.frame then self.frame:Show() end
end

function Compact:Toggle()
    local f = self.frame
    if not f then return end
    if not f:IsShown() then
        f:Show()
    elseif self.target == 0 then
        self:Animate(1)      -- was closing: slide back out
    else
        self:Close()
    end
end
