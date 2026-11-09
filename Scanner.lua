local ADDON, ns = ...

local Scanner = {}
ns.Scanner = Scanner

-- API wrappers so this works whichever container/item API the client exposes
local function NumSlots(bag)
    if C_Container and C_Container.GetContainerNumSlots then
        return C_Container.GetContainerNumSlots(bag)
    end
    return GetContainerNumSlots(bag)
end

local function SlotInfo(bag, slot)
    if C_Container and C_Container.GetContainerItemInfo then
        local i = C_Container.GetContainerItemInfo(bag, slot)
        if i then return i.itemID, i.hyperlink, i.quality, i.iconFileID, i.isLocked end
    elseif GetContainerItemInfo then
        local icon, _, locked, quality, _, _, link, _, _, itemID = GetContainerItemInfo(bag, slot)
        return itemID, link, quality, icon, locked
    end
end

local GetItemInfo        = (C_Item and C_Item.GetItemInfo) or GetItemInfo
local GetItemInfoInstant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
local GetItemLevel       = (C_Item and C_Item.GetDetailedItemLevelInfo) or GetDetailedItemLevelInfo

local CLASS_WEAPON, CLASS_ARMOR = 2, 4
local SUBCLASS_FISHING_POLE = 20
local SUBCLASS_COSMETIC = 5

local EXCLUDED_EQUIP = {
    INVTYPE_BODY = true,    -- shirts
    INVTYPE_TABARD = true,
    INVTYPE_BAG = true,
    INVTYPE_QUIVER = true,
}

local function IsDisenchantable(quality, classID, subClassID, equipLoc)
    if not quality or quality < 2 or quality > 4 then return false end
    if classID ~= CLASS_WEAPON and classID ~= CLASS_ARMOR then return false end
    if classID == CLASS_WEAPON and subClassID == SUBCLASS_FISHING_POLE then return false end
    if classID == CLASS_ARMOR and subClassID == SUBCLASS_COSMETIC then return false end
    if EXCLUDED_EQUIP[equipLoc] then return false end
    return true
end

function Scanner:Scan()
    local list = {}
    for bag = 0, (NUM_BAG_SLOTS or 4) do
        for slot = 1, (NumSlots(bag) or 0) do
            local itemID, link, quality, icon, locked = SlotInfo(bag, slot)
            if itemID and link then
                local _, _, _, equipLoc, instantIcon, classID, subClassID = GetItemInfoInstant(link)
                local name, _, infoQuality, infoLevel = GetItemInfo(link)
                quality = quality or infoQuality

                if IsDisenchantable(quality, classID, subClassID, equipLoc) then
                    list[#list + 1] = {
                        bag = bag,
                        slot = slot,
                        itemID = itemID,
                        link = link,
                        quality = quality,
                        icon = icon or instantIcon,
                        name = name or link:match("%[(.-)%]") or ("Item " .. itemID),
                        ilvl = (GetItemLevel and GetItemLevel(link)) or infoLevel or 0,
                        key = bag .. ":" .. slot .. ":" .. itemID,
                        locked = locked and true or false,
                    }
                end
            end
        end
    end
    return list
end
