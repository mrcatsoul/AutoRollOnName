--[[=====================================================================================================]
--| 3.24: + микро автороллер на друга, настраивается только на один конкретный ник любым из способов:    |
--|=> 1) командами: /rolimna ник либо /autoroll ник; очистка ника: ввести только команду без ника;       |
--|=> 2) через контекстное по нику в чате/таргету, но игрок должен быть в рейде, очистка той же кнопкой; |
--|=> 3) через Интерфейс=>Модификации;                                                                   |
--|=> i) Принцип работы: чекается желтое сообщение в чате в котором заданный ник = первое слово и        | 
--|=>   проверка на действительность ника(есть ли игрок в рейде) + наличие в сообщении слова "rolls" или | 
--|=>   "выбрасывает", по обнаружению такого сообщения будет вызов функции рола: RandomRoll(1,100)       |
--[=====================================================================================================]] 

local ADDON_NAME, ns = ...
local title1, title2, addonLoadedTime = GetAddOnMetadata(ADDON_NAME,"TitleTest"), GetAddOnMetadata(ADDON_NAME,"TitleTest2")
SLASH_AutoRoll_na_kogo_rolim_name1, SLASH_AutoRoll_na_kogo_rolim_name2 = "/rolimna", "/autoroll" 
local ALMOST_NOT_ANNOYING_REMINDER = "|cffffff22. Задать ник:|r |cFF22ddcc"..SLASH_AutoRoll_na_kogo_rolim_name2.." ник|r|cffffff22 либо|r |cFF22ddcc"..SLASH_AutoRoll_na_kogo_rolim_name1.." ник|r|cffffff22, либо через контекстное меню по нику в чате/таргету, либо через Интерфейс=>Модификации.|r" -- микро напоминание при входе, не показывается когда снят флаг "вкл аддон"
local MSG_You_have_left_the_raid_group, MSG_You_have_joined_a_raid_group = ERR_RAID_YOU_LEFT, ERR_RAID_YOU_JOINED
local settings,popupCallLastTime,nextRollTimeToPreventSpam = {},0,0

local classColors = {
  ["DEATHKNIGHT"] = "C41F3B",
  ["DRUID"] = "FF7D0A",
  ["HUNTER"] = "A9D271",
  ["MAGE"] = "40C7EB",
  ["PALADIN"] = "F58CBA",
  ["PRIEST"] = "FFFFFF",
  ["ROGUE"] = "FFF569",
  ["SHAMAN"] = "0070DE",
  ["WARLOCK"] = "8787ED",
  ["WARRIOR"] = "C79C6E",
}

local testlog = function(msg)
  print(title1.." "..msg)
end

local function hexToRGB(hex)
    hex = hex:gsub("#","")
    return tonumber("0x"..hex:sub(1,2)) / 255, tonumber("0x"..hex:sub(3,4)) / 255, tonumber("0x"..hex:sub(5,6)) / 255
end

local AR=CreateFrame('frame')
AR:RegisterEvent("CHAT_MSG_SYSTEM")
AR:RegisterEvent("CHAT_MSG_WHISPER")
AR:RegisterEvent("ADDON_LOADED")
AR:RegisterEvent("PLAYER_ENTERING_WORLD")

----------------------------------------------------
-- + эвенты, костяк работы аддона иммено здесь в этих нескольких строчках кода, всё остальное, по большей части, - визуал часть типа опций-настроек и кнопок
----------------------------------------------------
local function func_CFInfoFrameOnEvent(self, event, ...)
  if (event == "CHAT_MSG_SYSTEM") then
    if settings["enableAddon"] and settings["na_kogo_rolim_name"]~="" and (arg1:find("rolls") or arg1:find("выбрасывает")) then
      local name = arg1:match("^(.-) ")
      if nextRollTimeToPreventSpam <= GetTime() and name:lower()==settings["na_kogo_rolim_name"]:lower() and name:lower()~=UnitName("player"):lower() then
        RandomRoll(1,100)
        nextRollTimeToPreventSpam=GetTime()+2 -- чтобы предотвратить возможный бесконечный спам рола в случае если 2 чела зачем-то настроят друг на друга О_о
        if UnitInRaid('player') and UnitInRaid(name) then
          SendChatMessage(""..title2.." => ["..name.."]","raid")
        elseif UnitInParty('player') and UnitInParty(name) then
          SendChatMessage(""..title2.." => ["..name.."]","party")
        end
      end
    elseif settings["enableDisableAddonAfterLeaveJoinRaid"] and settings["enableAddon"] and (arg1 == ERR_RAID_YOU_LEFT or arg1 == ERR_RAID_YOU_JOINED) then
      settings["enableAddon"]=false
      self:saveNameAndSendUserNotify()
      self:refreshSettingsUI()
      RaidNotice_AddMessage(RaidWarningFrame, "|cffffffffАвторолл выключен (опция \"Выключить после лива или присоединения к рейду\")|r", ChatTypeInfo["RAID_WARNING"])
      PlaySoundFile([[Sound\Interface\RaidBossWarning.wav]])
    end
  elseif (event == "ADDON_LOADED" and arg1 == ADDON_NAME) then
    self:UnregisterEvent("ADDON_LOADED")
    settings = AutoRollOnName_settings
    if settings == nil then 
      settings = {}
      AutoRollOnName_settings = settings
      settings["enableAddon"] = true
      settings["na_kogo_rolim_name"] = ""
      settings["enableDisableAddonAfterLeaveJoinRaid"] = true
    end
    self:createSettingsUI()
  elseif (event == "PLAYER_ENTERING_WORLD") then
    self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    addonLoadedTime=GetTime()
  end
end

AR:SetScript("OnEvent", func_CFInfoFrameOnEvent)
AR:SetScript("OnUpdate", function(self)
  if addonLoadedTime and (addonLoadedTime + 5) <= GetTime() then -- чтобы сообщение при входе немножко меньше смешивалось с остальными
    if settings["enableAddon"] then 
      self:saveNameAndSendUserNotify(name,nil,1)
    end
    self:SetScript("OnUpdate",nil)
  end
end)

---------------------------------------------------------------------------
-- + уведомление себе в чат и пм цели авторола когда включено
---------------------------------------------------------------------------
function AR:saveNameAndSendUserNotify(name,pmNotify,remind)
  if addonLoadedTime then addonLoadedTime=nil end
  if name and name:lower()==UnitName("player"):lower() then
    testlog("|cffff3322Лол что? Хочешь ролить на себя дважды?|r")
    return
  end
  if name then
    settings["na_kogo_rolim_name"] = name
    self:refreshSettingsUI()
  end
  if not settings["enableAddon"] then
    if settings["na_kogo_rolim_name"] == "" then
      testlog("|cff989898Выключен|r" .. (remind and ALMOST_NOT_ANNOYING_REMINDER or ""))
    else
      testlog("|cff989898Выключен, снят флаг в настройках|r" .. (remind and ALMOST_NOT_ANNOYING_REMINDER or ""))
    end
    return
  end
  if settings["na_kogo_rolim_name"] ~= "" then 
    local classColor = classColors[select(2,UnitClass(settings["na_kogo_rolim_name"]))] or "989898"
    local msg = "|ccc22dd33Включен|r|cffffff22, седня ролим на: [|r|cff"..classColor..""..settings["na_kogo_rolim_name"].."|r|cffffff22]|r" .. (remind and ALMOST_NOT_ANNOYING_REMINDER or "")
    testlog(msg)
  else
    testlog("|cff989898Ник не указан|r" .. (remind and ALMOST_NOT_ANNOYING_REMINDER or ""))
  end
  -- пм цели, фан
  if UnitInRaid(settings["na_kogo_rolim_name"]) or UnitInParty(settings["na_kogo_rolim_name"]) then
    if settings["enableAddon"] and pmNotify and UnitIsConnected(settings["na_kogo_rolim_name"]) then 
      SendChatMessage(""..title2.." {rt3} На ваш ник настроен авторолл, срабатывает автоматически после вашего рола в чат","whisper",nil,settings["na_kogo_rolim_name"]) 
    end
  elseif settings["na_kogo_rolim_name"] ~= "" then
    testlog("|cffff3322Мужика с ником [|r|cff989898"..settings["na_kogo_rolim_name"].."|r|cffff3322] нет в рейде|r")
  end
end

------------------------------------------------------------------------------------------------------------------------------------------------------------
-- + окно по центру, диалог с запросом подтверждения авторолла на игрока, а то мало ли был миссклик
------------------------------------------------------------------------------------------------------------------------------------------------------------
StaticPopupDialogs['AUTO_ROLL_CONFIRM_ENABLE_AUTO_ROLL_FOR_NAME'] = {
	text		= "|cff00bbeeВключить авторолл для [%s]?|r",
	button1		= "Да",
	button2		= "Нет",
	exclusive	= 0,
	timeout = 20,
	whileDead = 1,
  notClosableByLogout = 1,
	OnHide = function(self, data)
    self:Hide()
	end,
	OnAccept = function(self, data, data2)
    if self.data then
      settings["enableAddon"]=true
      AR:saveNameAndSendUserNotify(self.data,1)
      AR:refreshSettingsUI()
    end
    self:Hide()
	end,
  OnUpdate = function(self, elapsed)
    if self.data then
      local classColor = classColors[select(2,UnitClass(self.data))] or "989898"
      local timeLeftSec = (popupTime+21)-GetTime()
      local newText = "|cff00bbeeВключить авторолл для [|r|cff"..classColor..""..self.data.."|r|cff00bbee]?|r "..string.match(tostring(timeLeftSec), "%d+")..""
      if not (UnitInParty(self.data) or UnitInRaid(self.data)) then
        newText = newText.."\r|cffff3322Игрока нет в рейде|r"
      end
      local oldText = self.text:GetText()
      if oldText~=newText then
        self.text:SetText(newText)
        StaticPopup_Resize(self, "AUTO_ROLL_CONFIRM_ENABLE_AUTO_ROLL_FOR_NAME")
      end
    end
  end,
	OnCancel = function(self, data, data2)
    self:Hide()
	end,
}	

------------------------------------------------------------------------------------------------------------------------------------------------------------
-- + кнопка авторола в контекстном меню правой кнопкой мыши, для фреймов типа таргета/рейда/френдлиста/ников в чате итд
------------------------------------------------------------------------------------------------------------------------------------------------------------
UnitPopupButtons["TEST_AUTOROLL_ON_NAME_BUTTON"] = {
	text = ""..title1.." |cff11bbeeВключить для TESTNAMETEST?|r",
	dist = 0,
	func = function(self)
    local name = UIDROPDOWNMENU_INIT_MENU.name
    if name and name~="" then
      if not (UnitInRaid(name) or UnitInParty(name)) then
        testlog("|cffff3322Игрок не в рейде!|r")
      elseif name:lower()~=settings["na_kogo_rolim_name"]:lower() then
        --AR:saveNameAndSendUserNotify(name,1)
        local popup = StaticPopup_Show("AUTO_ROLL_CONFIRM_ENABLE_AUTO_ROLL_FOR_NAME",name)
        if popup then 
          popupTime=GetTime()
          popup.data = name 
        end
      else
        AR:saveNameAndSendUserNotify("")
      end
    end
  end
}

local function UnitPopup_ShowMenu_Hook(self)
	for i=1, UIDROPDOWNMENU_MAXBUTTONS do
		local button = _G["DropDownList"..UIDROPDOWNMENU_MENU_LEVEL.."Button"..i]
		if button.value == "TEST_AUTOROLL_ON_NAME_BUTTON" then
      button.func = UnitPopupButtons["TEST_AUTOROLL_ON_NAME_BUTTON"].func
      local name = UIDROPDOWNMENU_INIT_MENU.name
      if name and name~="" then
        if name:lower()==settings["na_kogo_rolim_name"]:lower() then
          button:SetText(""..title1.." |cff11dd55Включен для "..name.."|r |T" .. _G[button:GetName().."Check"]:GetTexture() .. ":24|t")
        elseif name:lower()==UnitName("player"):lower() then
          button:SetText(""..title1.." |cffffff55Включить для "..name.."?|r")
        elseif UnitInRaid(name) or UnitInParty(name) then
          button:SetText(""..title1.." |cffffff55Включить для "..name.."?|r")
        else
          button:SetText(""..title1.." |cffff5555Игрок не в рейде|r")
        end
      end
		end
	end
end

hooksecurefunc("UnitPopup_ShowMenu", UnitPopup_ShowMenu_Hook)

table.insert(UnitPopupMenus["RAID_PLAYER"], 	#UnitPopupMenus["RAID_PLAYER"] - 1, 	"TEST_AUTOROLL_ON_NAME_BUTTON")
table.insert(UnitPopupMenus["FRIEND"], 	#UnitPopupMenus["FRIEND"] - 1,		"TEST_AUTOROLL_ON_NAME_BUTTON")
table.insert(UnitPopupMenus["PARTY"], 	#UnitPopupMenus["PARTY"] - 1, 		"TEST_AUTOROLL_ON_NAME_BUTTON")
table.insert(UnitPopupMenus["RAID"], 	#UnitPopupMenus["RAID"] - 1, 		"TEST_AUTOROLL_ON_NAME_BUTTON")

--------------------------------------------------
-- функция создания чекбокса для настроек
--------------------------------------------------
function AR:createCheckbox(offsetY,settingName,checkboxText,tooltipText) -- offsetY отступ от settingsTitleText
  local cb=CreateFrame("CheckButton",nil,self.settingsFrame,"UICheckButtonTemplate")
  cb:SetPoint("TOPLEFT", self.settingsTitleText, "BOTTOMLEFT", 0, offsetY)
  local t = cb:CreateFontString(nil, "ARTWORK")
  t:SetFont(GameFontNormal:GetFont(), 12, 'OUTLINE')
  t:SetPoint("LEFT", cb, "RIGHT", 5, 0)
  t:SetText(checkboxText)
  cb:SetScript("OnClick", function(self)
    if self:GetChecked() then
      settings[settingName] = true
    else
      settings[settingName] = false
    end
    if settingName == "enableAddon" then
      AR:saveNameAndSendUserNotify(nil,1)
    end
  end)
  cb:SetScript("OnShow", function(self)
    self:SetChecked(settings[settingName])
  end)
  if tooltipText then
    cb:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText(tooltipText, nil, nil, nil, nil, true)
      GameTooltip:Show()
    end)
    cb:SetScript("OnLeave", function(self)
      GameTooltip:Hide()
    end)
  end
end

function AR:createSettingsUI()
  ------------------------------------------------------------------------------------------
  -- + вкладка настроек в близ интерфейсе (Интерфейс=>Модификации)
  ------------------------------------------------------------------------------------------
  local settingsFrame = CreateFrame("Frame", nil, InterfaceOptionsFramePanelContainer)
  settingsFrame.name = GetAddOnMetadata(ADDON_NAME, "Title") 
  settingsFrame:Hide()
  self.settingsFrame = settingsFrame

  local settingsTitleText = settingsFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  settingsTitleText:SetPoint("TOPLEFT", 16, -16)
  settingsTitleText:SetText("|cFF22ddcc"..(GetAddOnMetadata(ADDON_NAME,"Author")).."|r's "..ADDON_NAME..": settings")
  self.settingsTitleText = settingsTitleText
  
  -- + чекбокс вкл/выкл аддон
  self:createCheckbox(-10,"enableAddon","Включить аддон") 

  ------------------------------------------------------------------------------------------
  -- + поле для ввода ника в настройках
  ------------------------------------------------------------------------------------------
  do
    local editbox = CreateFrame("EditBox", nil, settingsFrame, "InputBoxTemplate") -- поле ввода ника
    editbox:SetPoint("TOPLEFT", settingsTitleText, "BOTTOMLEFT", 8, -45)
    editbox:SetAutoFocus(false)
    editbox:SetHeight(20)
    editbox:SetWidth(150)
    --editbox:SetFont("GameFontNormal", 12)
    editbox:SetText(settings["na_kogo_rolim_name"] or "")
    editbox:SetTextColor(0.5, 0.5, 0.5)

    local label = editbox:CreateFontString(nil, "ARTWORK", "GameFontNormal") -- текст справа от поля
    label:SetPoint("LEFT", editbox, "RIGHT", 10, 0)
    label:SetJustifyH("LEFT")
    label:SetJustifyV("BOTTOM")
    local defaultText = "На каво седня ролим?"
    label:SetText(defaultText)
    editbox.label=label

    local function updateTextColor(self)
      local name = self:GetText()
      if name == "" then
        self.label:SetText(defaultText .. "\n" .. "|ccc777777=> Ни на кого, пустая строка|r")
      elseif UnitInRaid(name) or UnitInParty(name) then
        local classColor = classColors[select(2,UnitClass(name))] or "989898"
        local r,g,b = hexToRGB(classColor)
        self.label:SetText(defaultText .. "\n" .. "|ccc33dd33=> На [|r|cff"..classColor..""..name.."|r|ccc00ff00], мужик в рейде, всё ок|r")
        self:SetTextColor(r,g,b)
      else
        self:SetTextColor(0.5, 0.5, 0.5)
        self.label:SetText(defaultText .. "\n" .. "|cffff3322=> Мужик с ником [|r|cff989898"..name.."|r|cffff3322] не в рейде|r")
      end
    end

    editbox:SetScript('OnEnterPressed', function(self)
      self:ClearFocus()
      local text = self:GetText():gsub(" ","")
      if settings["na_kogo_rolim_name"]:lower() ~= text:lower() then
        AR:saveNameAndSendUserNotify(text,1)
      end
      if text:lower()==UnitName("player"):lower() then
        text=settings["na_kogo_rolim_name"] or ""
      end
      self:SetText(text)
      updateTextColor(self)
    end)

    editbox:SetScript('OnEscapePressed', function(self)
      self:ClearFocus()
      self:SetText(settings["na_kogo_rolim_name"] or "")
      updateTextColor(self)
    end)

    editbox:SetScript('OnEditFocusGained', function(self)
      self:SetText(settings["na_kogo_rolim_name"] or "")
      self:SetTextColor(1, 1, 1)
      self:HighlightText(self)
    end)

    editbox:SetScript('OnShow', function(self)
      self:SetText(settings["na_kogo_rolim_name"] or "")
      updateTextColor(self)
    end)
  end

  -- + чекбокс авто выключения
  self:createCheckbox(-70,"enableDisableAddonAfterLeaveJoinRaid","Выключить после лива или присоединения к рейду") 

  InterfaceOptions_AddCategory(settingsFrame)
end

------------------------------------------------------------------------------------------------------------------------------------------------------------
-- + костыльный (или нет?) метод обновления визуальной составляющей опций если они открыты и в этот момент настройки изменены не через фреймы(чекбоксы/поля ввода итд в Интерфейс=>Модификации) а иным способом
------------------------------------------------------------------------------------------------------------------------------------------------------------
function AR:refreshSettingsUI()
  if self.settingsFrame:IsVisible() then
    self.settingsFrame:Hide()
    self.settingsFrame:Show()
  end
end

----------------------------------------------------
-- + слэш команды
----------------------------------------------------
SlashCmdList["AutoRoll_na_kogo_rolim_name"] = function(name) 
  if name and name~="" then
    name = name:gsub(" ","")
    if settings["na_kogo_rolim_name"]:lower() ~= name:lower() then
      --AR:saveNameAndSendUserNotify(name,1)
      local popup = StaticPopup_Show("AUTO_ROLL_CONFIRM_ENABLE_AUTO_ROLL_FOR_NAME",name)
      if popup then 
        popupTime=GetTime()
        popup.data = name 
      end
    end
  else
    AR:saveNameAndSendUserNotify("")
  end
end
