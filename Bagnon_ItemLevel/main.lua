-- Используем аддон Bagnon для извлечения имен пространства т.д
local MODULE = ...
local ADDON, Addon = MODULE:match("[^_]+"), _G[MODULE:match("[^_]+")]
local ItemLevel = Bagnon:NewModule("ItemLevel", Addon)

-- Lua API
local _G = _G
local select = select
local string_find = string.find
local string_gsub = string.gsub
local string_match = string.match
local tonumber = tonumber

-- WoW API
local CreateFrame = _G.CreateFrame
local GetAchievementInfo = _G.GetAchievementInfo
local GetBuildInfo = _G.GetBuildInfo
local GetDetailedItemLevelInfo = _G.GetDetailedItemLevelInfo
local GetItemInfo = _G.GetItemInfo
local GetItemQualityColor = _G.GetItemQualityColor
local IsArtifactRelicItem = _G.IsArtifactRelicItem

-- Кэщ для итемлвл вещей
local cache = {}

-- Настройки цветов для типов привязки
local BIND_TYPE_COLORS = {
    BoP = {1, 0.2, 0.2},    -- Красный
    BoE = {0.2, 1, 0.2},    -- Зеленый
    BoU = {0.4, 0.4, 1},    -- Синий
    Soulbound = {1, 0.5, 0} -- Оранжевый
}

-- Функция определения типа привязки
local function GetBindType(itemLink)
    if not itemLink then return nil end
    
    local scanner = CreateFrame("GameTooltip", "BindTypeScanner", nil, "GameTooltipTemplate")
    scanner:SetOwner(WorldFrame, "ANCHOR_NONE")
    scanner:SetHyperlink(itemLink)
    
    for i = 2, 4 do
        local line = _G["BindTypeScannerTextLeft"..i]
        if line then
            local text = line:GetText()
            if text then
                if string_find(text, ITEM_BIND_ON_PICKUP) then
                    return "BoP"
                elseif string_find(text, ITEM_BIND_ON_EQUIP) then
                    return "BoE"
                elseif string_find(text, ITEM_BIND_ON_USE) then
                    return "BoU"
                elseif string_find(text, ITEM_SOULBOUND) then
                    return "Soulbound"
                end
            end
        end
    end
    
    return nil
end

-- Инициализация кнопки
local initButton = function(self)
    local holder = _G[self:GetName().."ExtraInfoFrame"] or CreateFrame("Frame", self:GetName().."ExtraInfoFrame", self)
    holder:SetAllPoints()

    -- Текст уровня предмета
    local itemLevel = holder:CreateFontString()
    itemLevel:SetDrawLayer("ARTWORK")
    itemLevel:SetPoint("TOPLEFT", 2, -2)
    itemLevel:SetFontObject(_G.NumberFont_Outline_Med or _G.NumberFontNormal)
    itemLevel:SetFont(itemLevel:GetFont(), 14, "OUTLINE")
    itemLevel:SetShadowOffset(1, -1)
    itemLevel:SetShadowColor(0, 0, 0, .5)

    -- Текст типа привязки
    local bindType = holder:CreateFontString()
    bindType:SetDrawLayer("ARTWORK")
    bindType:SetPoint("BOTTOMRIGHT", -2, 2)
    bindType:SetFontObject(_G.NumberFont_Outline_Med or _G.NumberFontNormal)
    bindType:SetFont(bindType:GetFont(), 12, "OUTLINE")
    bindType:SetShadowOffset(1, -1)
    bindType:SetShadowColor(0, 0, 0, .5)

    cache[self] = {
        itemLevel = itemLevel,
        bindType = bindType
    }

    return itemLevel, bindType
end

-- Основная функция обновления
local updateButton = function(self)
    local itemLink = self:GetItem()
    local cacheEntry = cache[self] or {}
    local itemLevelText = cacheEntry.itemLevel
    local bindTypeText = cacheEntry.bindType
    
    if not itemLevelText or not bindTypeText then
        itemLevelText, bindTypeText = initButton(self)
        cacheEntry = cache[self]
    end

    if itemLink then
        -- Получаем информацию о предмете
        local _, _, itemRarity, iLevel, _, itemType, itemSubType, _, itemEquipLoc = GetItemInfo(itemLink)
        local bindType = GetBindType(itemLink)
        
        -- Устанавливаем уровень предмета
        if itemRarity and itemRarity > 1 and (itemEquipLoc and _G[itemEquipLoc]) then
            local r, g, b = GetItemQualityColor(itemRarity)
            itemLevelText:SetTextColor(r, g, b)
            itemLevelText:SetText(iLevel or "")
        else
            itemLevelText:SetText("")
        end
        
        -- Устанавливаем тип привязки текстом
        if bindType and BIND_TYPE_COLORS[bindType] then
            local r, g, b = unpack(BIND_TYPE_COLORS[bindType])
            bindTypeText:SetTextColor(r, g, b)
            bindTypeText:SetText(bindType) -- Отображаем текст (BoP/BoE и т.д.)
        else
            bindTypeText:SetText("")
        end
    else
        itemLevelText:SetText("")
        bindTypeText:SetText("")
    end
end

ItemLevel.OnEnable = function(self)
    hooksecurefunc(Bagnon.ItemSlot, "Update", updateButton)
end
