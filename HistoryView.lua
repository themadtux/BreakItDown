local ADDON, ns = ...

local Theme = ns.Theme
local HV = {}
ns.HistoryView = HV

local WIDTH = 480
local ROWS, ROW_H = 6, 38
local HEADER_H, FOOTER_H = 30, 22
local HEIGHT = HEADER_H + ROWS * ROW_H + FOOTER_H + 6
local DIM = "|cff8a919c"

local GetItemInfoInstant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant

local function IconOf(link)
    if not link or not GetItemInfoInstant then return nil end
    return (select(5, GetItemInfoInstant(link)))
end

function HV:Build()
    if self.frame then return end

    local f = CreateFrame("Frame", "BreakItDownHistory", UIParent, "BackdropTemplate")
    f:SetSize(WIDTH, HEIGHT)
    f:SetFrameStrata("MEDIUM")
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:EnableMouseWheel(true)
    Theme:SkinFrame(f)
    f:Hide()
    self.frame = f
    self.offset = 0

    local line = f:CreateTexture(nil, "OVERLAY")
    line:SetHeight(2)
    line:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
    line:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -1)
    Theme:Register(function(r, g, b) line:SetColorTexture(r, g, b, 1) end)

    local title = f:CreateFontString(nil, "OVERLAY")
    Theme:Font(title, 14)
    title:SetPoint("TOPLEFT", 10, -9)
    title:SetText("History")
    title:SetTextColor(unpack(Theme.TEXT))

    local count = f:CreateFontString(nil, "OVERLAY")
    Theme:Font(count, 11)
    count:SetPoint("LEFT", title, "RIGHT", 8, -1)
    self.count = count

    -- Clear (needs a second click to confirm)
    local clear = Theme:CreateButton(f, "Clear", 50, 20, false)
    clear:SetPoint("TOPRIGHT", f, "TOPRIGHT", -30, -5)
    clear:SetScript("OnClick", function(s)
        if HV.confirm then
            HV.confirm = false
            s.text:SetText("Clear")
            ns.History:Clear()
        else
            HV.confirm = true
            s.text:SetText("Sure?")
            C_Timer.After(3, function()
                if HV.confirm then
                    HV.confirm = false
                    s.text:SetText("Clear")
                end
            end)
        end
    end)

    -- Close
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
    close:SetScript("OnClick", function() HV:Hide() end)

    local function OnWheel(_, delta) HV:Scroll(-delta) end
    f:SetScript("OnMouseWheel", OnWheel)

    -- Rows ---------------------------------------------------------------------
    self.rows = {}
    for i = 1, ROWS do
        local row = CreateFrame("Button", nil, f)
        row:SetSize(WIDTH - 12, ROW_H)
        row:SetPoint("TOPLEFT", f, "TOPLEFT", 6, -HEADER_H - (i - 1) * ROW_H)
        row:EnableMouseWheel(true)
        row:SetScript("OnMouseWheel", OnWheel)

        local hl = row:CreateTexture(nil, "BACKGROUND")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 1, 1, 0.04)
        hl:Hide()
        row.hl = hl

        local sep = row:CreateTexture(nil, "ARTWORK")
        sep:SetPoint("BOTTOMLEFT")
        sep:SetPoint("BOTTOMRIGHT")
        sep:SetHeight(1)
        sep:SetColorTexture(unpack(Theme.BORDER))

        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetSize(24, 24)
        icon:SetPoint("LEFT", row, "LEFT", 4, 0)
        icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        row.icon = icon

        local l1 = row:CreateFontString(nil, "OVERLAY")
        Theme:Font(l1, 12)
        l1:SetPoint("TOPLEFT", row, "TOPLEFT", 36, -5)
        l1:SetWidth(310)
        l1:SetJustifyH("LEFT")
        l1:SetWordWrap(false)
        row.line1 = l1

        local tm = row:CreateFontString(nil, "OVERLAY")
        Theme:Font(tm, 10)
        tm:SetPoint("TOPRIGHT", row, "TOPRIGHT", -6, -6)
        tm:SetTextColor(unpack(Theme.DIM))
        row.time = tm

        local l2 = row:CreateFontString(nil, "OVERLAY")
        Theme:Font(l2, 11)
        l2:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 36, 5)
        l2:SetWidth(WIDTH - 12 - 42)
        l2:SetJustifyH("LEFT")
        l2:SetWordWrap(false)
        l2:SetTextColor(unpack(Theme.TEXT))
        row.line2 = l2

        row:SetScript("OnEnter", function(s)
            s.hl:Show()
            if s.link then
                GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
                GameTooltip:SetHyperlink(s.link)
                GameTooltip:Show()
            end
        end)
        row:SetScript("OnLeave", function(s)
            s.hl:Hide()
            GameTooltip:Hide()
        end)

        row:Hide()
        self.rows[i] = row
    end

    local empty = f:CreateFontString(nil, "OVERLAY")
    Theme:Font(empty, 12)
    empty:SetPoint("CENTER", f, "CENTER", 0, 0)
    empty:SetTextColor(unpack(Theme.DIM))
    empty:SetText("Nothing disenchanted yet.")
    self.empty = empty

    local footer = f:CreateFontString(nil, "OVERLAY")
    Theme:Font(footer, 10)
    footer:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 10, 8)
    self.footer = footer

    f:SetScript("OnShow", function() HV:Refresh() end)
end

function HV:Scroll(delta)
    local n = #(ns.db.history or {})
    local maxOffset = math.max(0, n - ROWS)
    self.offset = math.max(0, math.min(maxOffset, (self.offset or 0) + delta))
    self:Refresh()
end

function HV:Refresh()
    if not self.frame then return end
    local hist = ns.db.history or {}
    local n = #hist
    self.offset = math.max(0, math.min(self.offset or 0, math.max(0, n - ROWS)))

    self.count:SetText(DIM .. n .. " recorded|r")
    self.empty:SetShown(n == 0)

    for i, row in ipairs(self.rows) do
        local d = hist[self.offset + i]
        if d then
            local it = d.item or {}
            row.link = it.link
            row.icon:SetTexture(IconOf(it.link))

            local name = it.link or it.name or "Unknown item"
            if it.ilvl and it.ilvl > 0 then name = name .. DIM .. "  (ilvl " .. it.ilvl .. ")|r" end
            row.line1:SetText(name)
            row.time:SetText(date("%d %b  %H:%M", d.t or 0))

            local parts = {}
            for _, l in ipairs(d.loot or {}) do
                local icon = IconOf(l.link)
                local s = (icon and ("|T" .. icon .. ":14|t ") or "") .. l.link
                if l.qty and l.qty > 1 then s = s .. " x" .. l.qty end
                parts[#parts + 1] = s
            end
            if #parts == 0 then
                row.line2:SetText(DIM .. "Received: nothing recorded|r")
            else
                row.line2:SetText(DIM .. "Received:|r " .. table.concat(parts, "   "))
            end
            row:Show()
        else
            row.link = nil
            row:Hide()
        end
    end

    if n > 0 then
        local first = self.offset + 1
        local last = math.min(self.offset + ROWS, n)
        self.footer:SetText(string.format("%d-%d of %d   (scroll for more)", first, last, n))
    else
        self.footer:SetText("")
    end
end

-- Sits under the main window, or above it if there is no room below.
function HV:Show()
    local f, c = self.frame, ns.Compact and ns.Compact.frame
    if not f then return end
    f:ClearAllPoints()
    if c then
        local bottom = c:GetBottom() or 0
        if bottom < HEIGHT + 12 then
            f:SetPoint("BOTTOM", c, "TOP", 0, 6)
        else
            f:SetPoint("TOP", c, "BOTTOM", 0, -6)
        end
    else
        f:SetPoint("CENTER")
    end
    f:Show()
end

function HV:Hide()
    if self.frame then self.frame:Hide() end
end

function HV:Toggle()
    if not self.frame then return end
    if self.frame:IsShown() then self:Hide() else self:Show() end
end
