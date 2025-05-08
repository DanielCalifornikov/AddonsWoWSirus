-- Используем аддон Bagnon для извлечения имен пространства т.д
local ADDON_NAME, Addon = ...
local ItemLevel = Bagnon:NewModule("ItemLevel", Addon)

-- Настройки по умолчанию
ItemLevel.db = {
    showItemLevel = true,
    showBindType = true,
    itemLevelSize = 14,
    bindTypeSize = 12
}

-- Создаем сканер для типа привязки
local scanner = CreateFrame("GameTooltip", "ItemLevelScanner", nil, "GameTooltipTemplate")
scanner:SetOwner(WorldFrame, "ANCHOR_NONE")

-- Функция для надежного получения itemLevel
local function GetRealItemLevel(itemLink)
    if not itemLink then return nil end
    -- Способ 1: Для большинства предметов не работает без второго
    local _, _, _, _, _, _, _, _, _, _, _, itemLevel = GetItemInfo(itemLink)
    if itemLevel and itemLevel > 0 then return itemLevel end
    -- Способ 2: Для некоторых предметов (через tooltip) не работает без первого
    scanner:ClearLines()
    scanner:SetHyperlink(itemLink)
    
    for i = 2, scanner:NumLines() do
        local line = _G["ItemLevelScannerTextLeft"..i]
        if line then
            local text = line:GetText() or ""
            local found = text:match("Уровень предмета: (%d+)") or text:match("Item Level: (%d+)")
            if found then
                return tonumber(found)
            end
        end
    end
    
    return nil
end

-- Основная функция обновления кнопки
local function SafeUpdateButton(button)
    if not button or not button.GetItem then return end
    -- Создаем текстовые элементы если их нет
    if not button.ilvlText then
        button.ilvlText = button:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
        button.ilvlText:SetPoint("TOPLEFT", 2, -2)
        button.ilvlText:SetShadowOffset(1, -1)
        button.ilvlText:SetShadowColor(0, 0, 0, 0.8)
        button.ilvlText:SetFont(STANDARD_TEXT_FONT, ItemLevel.db.itemLevelSize or 14)
    end
    -- Создаем текстовое поле для типа привязки, если оно нужно
    if ItemLevel.db.showBindType and not button.bindText then
        button.bindText = button:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
        button.bindText:SetPoint("BOTTOMRIGHT", -2, 2)
        button.bindText:SetShadowOffset(1, -1)
        button.bindText:SetShadowColor(0, 0, 0, 0.8)
        button.bindText:SetFont(STANDARD_TEXT_FONT, ItemLevel.db.bindTypeSize or 12)
    end
    -- Сбрасываем текст
    button.ilvlText:SetText("")
    if button.bindText then button.bindText:SetText("") end
    
    local itemLink = button:GetItem()
    if not itemLink then return end
    -- Получаем полную информацию о предмете
    local _, _, rarity, itemLevel, _, itemType, itemSubType, _, itemEquipLoc = GetItemInfo(itemLink)
    -- Список категорий, для которых НЕ показываем илвл в сумке
    local skipItemLevelTypes = {
        ["Реагенты"] = true, 
        ["Ткань"] = true, 
        ["Кожа"] = true,
        ["Металл и камни"] = true, 
        ["Торговые товары"] = true,
        ["Квест"] = true, 
        ["Профессии"] = true, 
        ["Рыболовство"] = true,
        ["Еда и напитки"] = true, 
        ["Трава"] = true, 
        ["Расходуемые"] = true,
        ["Хлам"] = true, 
        ["Задания"] = true, 
        ["Ювелирное дело"] = true,
        ["Наложение чар"] = true, 
        ["Стихии"] = true, 
        ["Материалы"] = true,
        ["Оранжевые"] = true, 
        ["Хозяйственные товары"] = true, 
        ["Пули"] = true,
    }
    -- Отображаем уровень предмета только для разрешенных категорий
    if ItemLevel.db.showItemLevel and itemLevel and itemLevel > 0 then
        if not skipItemLevelTypes[itemType] and not skipItemLevelTypes[itemSubType] then
            local r, g, b = GetItemQualityColor(rarity or 1)
            button.ilvlText:SetTextColor(r, g, b)
            button.ilvlText:SetText(tostring(itemLevel))
        end
    end
    -- Определяем тип привязки ТОЛЬКО для экипировки
    if ItemLevel.db.showBindType and button.bindText then
        local isEquipment = itemEquipLoc and itemEquipLoc ~= "" 
                          and itemEquipLoc ~= "INVTYPE_BAG" 
                          and itemEquipLoc ~= "INVTYPE_QUIVER"
                          and itemEquipLoc ~= "INVTYPE_TABARD"
                          and itemEquipLoc ~= "INVTYPE_BODY"
        
        if isEquipment then
            scanner:ClearLines()
            scanner:SetHyperlink(itemLink)
            
            for i = 2, scanner:NumLines() do
                local line = _G["ItemLevelScannerTextLeft"..i]
                if line then
                    local text = line:GetText() or ""
                    if text:find(ITEM_BIND_ON_PICKUP or "Привязывается при получении") then
                        button.bindText:SetTextColor(1, 0.2, 0.2)
                        button.bindText:SetText("BoP")
                        break
                    elseif text:find(ITEM_BIND_ON_EQUIP or "Привязывается при надевании") then
                        button.bindText:SetTextColor(0.2, 1, 0.2)
                        button.bindText:SetText("BoE")
                        break
                    end
                end
            end
        end
    end
end

-- Функция очистки кэша
local function ClearItemLevelCache()
    for button, _ in pairs(ItemLevel.buttonCache or {}) do
        if button.ilvlText then button.ilvlText:SetText("") end
        if button.bindText then button.bindText:SetText("") end
    end
    ItemLevel.buttonCache = {}
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[Bagnon ItemLevel]|r Кэш очищен!")
end

-- Инициализация аддона с защитой от ошибок
ItemLevel.OnEnable = function(self)
    -- Загрузка настроек
    if not BagnonDB then BagnonDB = {} end
    if not BagnonDB.ItemLevel then
        BagnonDB.ItemLevel = CopyTable(self.db)
    else
        for k, v in pairs(self.db) do
            if BagnonDB.ItemLevel[k] == nil then
                BagnonDB.ItemLevel[k] = v
            end
        end
    end
    self.db = BagnonDB.ItemLevel

    -- Создание панели настроек с защитой
    local success, err = pcall(function()
        local panel = CreateFrame("Frame", "BagnonItemLevelOptions", UIParent)
        panel.name = "Bagnon ItemLevel"
        
        -- Заголовок
        local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", 16, -16)
        title:SetText(panel.name)

        -- Чекбокс уровня предметов
        local showIlvlCB = CreateFrame("CheckButton", nil, panel, "OptionsCheckButtonTemplate")
        showIlvlCB:SetPoint("TOPLEFT", 16, -50)
        showIlvlCB:SetChecked(self.db.showItemLevel)
        showIlvlCB:SetScript("OnClick", function(self) 
            ItemLevel.db.showItemLevel = self:GetChecked() 
        end)
        
        local showIlvlLabel = showIlvlCB:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        showIlvlLabel:SetPoint("LEFT", showIlvlCB, "RIGHT", 5, 0)
        showIlvlLabel:SetText("Показывать уровень предметов")

        -- Чекбокс типа привязки
        local showBindCB = CreateFrame("CheckButton", nil, panel, "OptionsCheckButtonTemplate")
        showBindCB:SetPoint("TOPLEFT", 16, -80)
        showBindCB:SetChecked(self.db.showBindType)
        showBindCB:SetScript("OnClick", function(self)
            ItemLevel.db.showBindType = self:GetChecked()
        end)
        
        local showBindLabel = showBindCB:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        showBindLabel:SetPoint("LEFT", showBindCB, "RIGHT", 5, 0)
        showBindLabel:SetText("Показывать тип привязки")

        -- Кнопка очистки кэша
        local clearBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        clearBtn:SetPoint("TOPLEFT", 16, -120)
        clearBtn:SetSize(180, 25)
        clearBtn:SetText("Очистить кэш")
        clearBtn:SetScript("OnClick", ClearItemLevelCache)

        InterfaceOptions_AddCategory(panel)
        return panel
    end)

    if not success then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[Bagnon ItemLevel]|r Ошибка создания настроек: "..(tostring(err) or "unknown error"))
    end

    -- Хук для обновления кнопок
    if Bagnon and Bagnon.ItemSlot then
        hooksecurefunc(Bagnon.ItemSlot, "Update", SafeUpdateButton)
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[Bagnon ItemLevel]|r Bagnon не найден!")
    end

    -- Обновление при загрузке
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_LOGIN")
    eventFrame:SetScript("OnEvent", function()
        C_Timer.After(1, function()
            if Bagnon and Bagnon.frames then
                for _, frame in pairs(Bagnon.frames) do
                    if frame and frame.items then
                        for _, button in pairs(frame.items) do
                            SafeUpdateButton(button)
                        end
                    end
                end
            end
        end)
    end)

    -- Команда очистки кэша
    SLASH_BAGNONITEMLEVELCLEAR1 = "/bilclear"
    SlashCmdList["BAGNONITEMLEVELCLEAR"] = ClearItemLevelCache
end
