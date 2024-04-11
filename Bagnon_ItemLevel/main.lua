
-- Используем аддон Bagnon для извлечения имен пространства т.д
local MODULE =  ...
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
local GetDetailedItemLevelInfo = _G.GetDetailedItemLevelInfo -- 3.3.5
local GetItemInfo = _G.GetItemInfo
local GetItemQualityColor = _G.GetItemQualityColor
local IsArtifactRelicItem = _G.IsArtifactRelicItem -- С этим *кхм кхм* массивом будем смотреть на уровень вещей

-- Кэщ для итемлвл вещей
local cache = {}

-- Сборка игрового клиента
local BUILD = tonumber((select(2, GetBuildInfo()))) 

-- Всплывающая подсказка для сканирования
local WOTLK = BUILD >= 24500 
local WOTLK_CRUCIBLE = WOTLK_ and select(4, GetAchievementInfo(12072))

-- ИДИ СВОЕЙ ДОРОГОЙ СТАЛКЕР
if WOTLK and (not WOTLK_CRUCIBLE) then
	local eventListener = CreateFrame("Frame")
	eventListener:RegisterEvent("ACHIEVEMENT_EARNED")
	eventListener:SetScript("OnEvent", function(self, event, id) 
		if (id == 12072) then
			WOTLK_CRUCIBLE = true
			self:UnregisterEvent(event)
		end
	end)
end

-- Всплывающая подсказка для сканирования
local scanner = CreateFrame("GameTooltip", "BagnonArtifactItemLevelScannerTooltip", WorldFrame, "GameTooltipTemplate")
local scannerName = scanner:GetName()

-- сканирование с помощью опен сурс кода http://www.wowinterface.com/forums/showthread.php?p=271406
local S_ITEM_LEVEL = "^" .. string_gsub(_G.ITEM_LEVEL, "%%d", "(%%d+)")
local S_CONTAINER_SLOTS = _G.CONTAINER_SLOTS
S_CONTAINER_SLOTS = string_gsub(S_CONTAINER_SLOTS, "%%d", "(%%d+)")
S_CONTAINER_SLOTS = string_gsub(S_CONTAINER_SLOTS, "%%s", "(%.+)") -- in search patterns 's' are spaces, can't be using that
S_CONTAINER_SLOTS = "^" .. S_CONTAINER_SLOTS

-- Инициализируем кнопку
local initButton = function(self)

	-- Добавляем новый слой повверх других, для отображения
	local holder = _G[self:GetName().."ExtraInfoFrame"] or CreateFrame("Frame", self:GetName().."ExtraInfoFrame", self)
	holder:SetAllPoints()

	-- Используем шрифт близзардов
	local itemLevel = holder:CreateFontString()
	itemLevel:SetDrawLayer("ARTWORK")
	itemLevel:SetPoint("TOPLEFT", 2, -2)
	itemLevel:SetFontObject(_G.NumberFont_Outline_Med or _G.NumberFontNormal) 
	itemLevel:SetFont(itemLevel:GetFont(), 14, "OUTLINE")
	itemLevel:SetShadowOffset(1, -1)
	itemLevel:SetShadowColor(0, 0, 0, .5)

	-- Магия вне хогварства запрещена!
	local upgradeIcon = self.UpgradeIcon
	if upgradeIcon then
		upgradeIcon:ClearAllPoints()
		upgradeIcon:SetPoint("BOTTOMRIGHT", 2, 0)
	end

	-- Сохраняем сцылку на кэш
	cache[self] = itemLevel

	return itemLevel
end

-- ПРОВЕРЯЕМ ЛЕЖИТ ЛИ В СУМКЕ ИГРУШЕЧНЫЙ ПЕТ
local battlePetInfo = function(itemLink)
	if (not string_find(itemLink, "battlepet")) then
		return
	end
	local data, name = string_match(itemLink, "|H(.-)|h(.-)|h")
	local  _, _, level, rarity = string_match(data, "(%w+):(%d+):(%d+):(%d+)")
	return true, level or 1, tonumber(rarity) or 0
end

local updateButton = (GetDetailedItemLevelInfo and IsArtifactRelicItem) and function(self)
	local itemLink = self:GetItem() 
	if itemLink then

		-- Извлекаем и создаем текст на уровне вещи
		local itemLevel = cache[self] or initButton(self)

		-- Получаем информацию от близзардов(ага кнш, поверил. Ну и бридятина) на шмотку
		local _, _, itemRarity, iLevel, _, itemType, itemSubType, _, itemEquipLoc = GetItemInfo(itemLink)
		local effectiveLevel, previewLevel, origLevel = GetDetailedItemLevelInfo(itemLink)
		local isBattlePet, battlePetLevel, battlePetRarity = battlePetInfo(itemLink)

		-- Извлекаем айди шмотки для отображения
		local itemID = tonumber(string_match(itemLink, "item:(%d+)"))

		if (itemEquipLoc == "INVTYPE_BAG") then 

			scanner.owner = self
			scanner:SetOwner(self, "ANCHOR_NONE")
			scanner:SetBagItem(self:GetBag(), self:GetID())

			local scannedSlots
			local line = _G[scannerName.."TextLeft3"]
			if line then
				local msg = line:GetText()
				if msg and string_find(msg, S_CONTAINER_SLOTS) then
					local bagSlots = string_match(msg, S_CONTAINER_SLOTS)
					if bagSlots and (tonumber(bagSlots) > 0) then
						scannedSlots = bagSlots
					end
				else
					line = _G[scannerName.."TextLeft4"]
					if line then
						local msg = line:GetText()
						if msg and string_find(msg, S_CONTAINER_SLOTS) then
							local bagSlots = string_match(msg, S_CONTAINER_SLOTS)
							if bagSlots and (tonumber(bagSlots) > 0) then
								scannedSlots = bagSlots
							end
						end
					end
				end
			end

			if scannedSlots then 
				--Используя RGB смешиваем и получаем уровень шмотки в цвете
				local r, g, b = 240/255, 240/255, 240/255
				itemLevel:SetTextColor(r, g, b)
				itemLevel:SetText(scannedSlots)
			else 
				itemLevel:SetText("")
			end 

		-- Отображение уровня вещи
		elseif ((itemRarity and (itemRarity > 0)) and ((itemEquipLoc and _G[itemEquipLoc]) or (itemID and IsArtifactRelicItem(itemID)))) or (isBattlePet) then

			local scannedLevel
			if (not isBattlePet) then
				scanner.owner = self
				scanner:SetOwner(self, "ANCHOR_NONE")
				scanner:SetBagItem(self:GetBag(), self:GetID())

				local line = _G[scannerName.."TextLeft2"]
				if line then
					local msg = line:GetText()
					if msg and string_find(msg, S_ITEM_LEVEL) then
						local itemLevel = string_match(msg, S_ITEM_LEVEL)
						if itemLevel and (tonumber(itemLevel) > 0) then
							scannedLevel = itemLevel
						end
					else
						-- БИ-БУ-БИ-БИ-БУП-БУП
						line = _G[scannerName.."TextLeft3"]
						if line then
							local msg = line:GetText()
							if msg and string_find(msg, S_ITEM_LEVEL) then
								local itemLevel = string_match(msg, S_ITEM_LEVEL)
								if itemLevel and (tonumber(itemLevel) > 0) then
									scannedLevel = itemLevel
								end
							end
						end
					end
				end
			end

			local r, g, b = GetItemQualityColor(battlePetRarity or itemRarity)
			itemLevel:SetTextColor(r, g, b)
			itemLevel:SetText(scannedLevel or battlePetLevel or effectiveLevel or iLevel or "")

		else
			itemLevel:SetText("")
		end

	else
		if cache[self] then
			cache[self]:SetText("")
		end
	end	
end 
or 
IsArtifactRelicItem and function(self)
	local itemLink = self:GetItem() 
	if itemLink then

		-- Извлекаем кнопку на уровне шмотки
		local itemLevel = cache[self] or initButton(self)

		-- Получаем нечего устал писать одно и тоже
		local _, _, itemRarity, iLevel, _, _, _, _, itemEquipLoc = GetItemInfo(itemLink)
		local isBattlePet, battlePetLevel, battlePetRarity = battlePetInfo(itemLink)

		-- ну да ну да пошел я куда подальше
		local itemID = tonumber(string_match(itemLink, "item:(%d+)"))

		-- Кофе 3 в 1 для настоящих гурманов
		if ((itemRarity and (itemRarity > 1)) and ((itemEquipLoc and _G[itemEquipLoc]) or (itemID and IsArtifactRelicItem(itemID)))) or (isBattlePet) then
			local r, g, b = GetItemQualityColor(battlePetRarity or itemRarity)
			itemLevel:SetTextColor(r, g, b)
			itemLevel:SetText(battlePetLevel or iLevel or "")
		else
			itemLevel:SetText("")
		end

	else
		if cache[self] then
			cache[self]:SetText("")
		end
	end	
end 
or 
function(self)
	local itemLink = self:GetItem() 
	if itemLink then

		-- Извлекаем кнопку на уровне шмотки
		local itemLevel = cache[self] or initButton(self)

		-- Получаем нечего устал писать одно и тоже
		local _, _, itemRarity, iLevel, _, _, _, _, itemEquipLoc = GetItemInfo(itemLink)

		-- ну да ну да пошел я куда подальше
		local itemID = tonumber(string_match(itemLink, "item:(%d+)"))

		-- Салат цезарь был сделан в честь цезаря или секретный ингридиент это и есть сам цезарь?
		local isBattlePet, battlePetLevel, battlePetRarity = battlePetInfo(itemLink)

		-- Ну короче иди своей дорогой сталкер
		if ((itemRarity and (itemRarity > 1)) and ((itemEquipLoc and _G[itemEquipLoc]))) or (isBattlePet) then
			local r, g, b = GetItemQualityColor(battlePetRarity or itemRarity)
			itemLevel:SetTextColor(r, g, b)
			itemLevel:SetText(battlePetLevel or iLevel or "")
		else
			itemLevel:SetText("")
		end

	else
		if cache[self] then
			cache[self]:SetText("")
		end
	end	
end 

ItemLevel.OnEnable = function(self)
	hooksecurefunc(Bagnon.ItemSlot, "Update", updateButton)
end 
