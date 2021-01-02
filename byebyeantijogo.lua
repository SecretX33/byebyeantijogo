local BBAJ = CreateFrame("frame")

-- Configurations
local showAddonMessageForBuffRemoval = true     -- default is true
-- End of Configurations

-- Don't touch anything below
local ajDebug = false      -- BBAJ debug messages
local antijogo_buffs_general = {
   [24732] = true,  -- Bat Costume
   [61716] = true,  -- Rabbit Costume
   [24740] = true,  -- Wisp Costume
   [19753] = true,  -- Divine Intervention
}
local antijogo_buffs_for_physical = {
   [1022]  = true,  -- Hand of Protection (Rank 1)
   [5599]  = true,  -- Hand of Protection (Rank 2)
   [10278] = true,  -- Hand of Protection (Rank 3)
   [66009] = true,  -- Hand of Protection (Rank 3), yes idk why where are two HoP with the same rank
}

local dpsPhysicalClasses = {"HUNTER", "DEATHKNIGHT", "PALADIN_Protection", "PALADIN_Retribution", "WARRIOR", "DRUID_Feral", "ROGUE", "SHAMAN_Enhancement"}
local dpsSpellClasses    = {"DRUID_Balance","SHAMAN_Elemental","PRIEST_Shadow","MAGE","WARLOCK"}
local healerClasses      = {"PALADIN_Holy","DRUID_Restoration","SHAMAN_Restoration","PRIEST_Discipline","PRIEST_Holy"}

local playerClass
local playerSpec
local playerClassAndSpec

local BBAJ_ADDON_PREFIX = "|cffed15d0ByeByeAntiJogo:|r "
local messageLastSent   = 0
local groupTalentsLib
local addonVersion

-- Upvalues
local CancelUnitBuff, GetSpellInfo, GetSpellLink, format = CancelUnitBuff, GetSpellInfo, GetSpellLink, string.format

BBAJ:SetScript("OnEvent", function(self, event, ...)
   self[event](self, ...)
end)

-- Utility functions
local function send(msg)
   if(msg~=nil) then print(BBAJ_ADDON_PREFIX .. msg) end
end

local function sendNoPrefix(msg)
   if(msg~=nil) then print(msg) end
end

-- [string utils]
local function upperFirst(str)
   if str==nil then return "" end
   assert(type(str) == "string", "bad argument #1: 'str' needs to be a string; instead what came was " .. tostring(type(str)))
   return (str:gsub("^%l", string.upper))
end

local function upperFirstOnly(str)
   if str==nil then return "" end
   assert(type(str) == "string", "bad argument #1: 'str' needs to be a string; instead what came was " .. tostring(type(str)))
   return upperFirst(str:lower())
end

-- Remove spaces on start and end of string
local function trim(s)
   if s==nil then return "" end
   assert(type(s) == "string", "bad argument #1: 's' needs to be a string; instead what came was " .. tostring(type(s)))
   return string.match(s,'^()%s*$') and '' or string.match(s,'^%s*(.*%S)')
end

local function removeWords(myString, howMany)
   if (myString~=nil and howMany~=nil) then
      assert(type(myString) == "string", "bad argument #1: 'myString' needs to be a string; instead what came was " .. tostring(type(myString)))
      assert(type(howMany) == "number", "bad argument #2: 'howMany' needs to be a number; instead what came was " .. tostring(type(howMany)))
      assert(math.floor(howMany) == howMany, "bad argument #2: 'howMany' needs to be an integer")

      for i=1, howMany do
         myString = string.gsub(myString,"^(%s*%a+)","",1)
      end
      return trim(myString)
   end
   return ""
end
-- end of [string utils]

local function doesElementContainsAnyValueFromTable(table, element)
   assert(table~=nil, "bad argument #1: 'table' cannot be nil")
   assert(type(table) == "table", "bad argument #1: 'table' needs to be a table; instead what came was " .. tostring(type(table)))
   assert(element~=nil, "bad argument #2: 'element' cannot be nil")

   -- If any value from the table is contained inside the element then return true, aka the table have a value that match fits inside the element
   for _, value in pairs(table) do
      if string.match(element, value) then
         return true
      end
   end
   return false
end

local function updatePlayerSpec()
   -- the function GetUnitTalentSpec from GroupTalentsLib can return a number if the player has not yet seen that class/build, so another "just in case" code, but I'm not sure what if this number means the talent tree number (like 1 for balance, 3 for restoration) or just the spec slot (player has just two slots), I guess I'll have to shoot in the dark here. ;)
   -- I just discovered that this function can also return nil if called when player is logging in (probably because the inspect function doesn't work while logging in)
   local spec = groupTalentsLib:GetUnitTalentSpec(UnitName("player"))
   if spec=="Feral Combat" then spec = "Feral" end  -- We will treat 'Feral Combat' as 'Feral'

   if spec~=nil then
      playerSpec = spec
      BBAJ.dbc.spec = spec
   end
end

local function getPlayerSpec()
   if playerSpec==nil then
      updatePlayerSpec()
   end
   return playerSpec or BBAJ.dbc.spec
end

local function updatePlayerClassAndSpec()
   updatePlayerSpec()
   if playerSpec~=nil then
      playerClassAndSpec = playerClass .. "_" .. playerSpec  -- E.G. PALADIN_Retribution
   end
end

local function updatePlayerClassAndSpecIfNeeded()
   if playerSpec==nil or playerClassAndSpec==nil then updatePlayerClassAndSpec() end
end

local function isPlayerDPSPhysical()
   updatePlayerClassAndSpecIfNeeded()
   if playerClassAndSpec==nil then send("playerClassAndSpec came nil inside function to check if player is dps physical, report this.");return false; end

   local isPhysical = doesElementContainsAnyValueFromTable(dpsPhysicalClasses, playerClassAndSpec)
   --if wrDebug then send("player class is dps physical? " .. tostring(isPhysical)) end
   return isPhysical
end

local function isPlayerDPSSpell()
   updatePlayerClassAndSpecIfNeeded()
   if playerClassAndSpec==nil then send("playerClassAndSpec came nil inside function to check if player is dps spell, report this.");return false; end

   local isSpell = doesElementContainsAnyValueFromTable(dpsSpellClasses, playerClassAndSpec)
   --if wrDebug then send("player class is dps spell? " .. tostring(isSpell)) end
   return isSpell
end

local function isPlayerHealer()
   updatePlayerClassAndSpecIfNeeded()
   if playerClassAndSpec==nil then send("playerClassAndSpec came nil inside function to check if player is healer, report this.");return false; end

   local isHealer = doesElementContainsAnyValueFromTable(healerClasses, playerClassAndSpec)
   --if wrDebug then send("player class is healer? " .. tostring(isHealer)) end
   return isHealer
end

-- Not using these functions yet
--[[local function getSpellName(spellID)
   if spellID==nil then return "" end

   local spellName = GetSpellInfo(spellID)
   if spellName~=nil then return spellName else return "" end
end

local function doesUnitHaveThisBuff(unit, buff)
   if(unit==nil or buff==nil) then return false end

   return UnitBuff(unit,buff)~=nil
end

local function getICCDifficultyIndexAsString(index)
   if index==nil then send("'index' parameter came nil inside function to get instance as name, report this."); return ""; end

   if index==1 then return "10-man normal"
   elseif index==2 then return "25-man normal"
   elseif index==3 then return "10-man heroic"
   elseif index==4 then return "25-man heroic"
   else send("Report this, unexpected value came as parameter inside function that convert difficultyIndex to the string equivalent, the value passed is \'" .. tostring(index) .. "\'.")
   end
end

local function getBuffExpirationTime(unit, buff)
   if(unit==nil or buff==nil) then return 0 end

   -- /run print(select(7,UnitBuff("player",GetSpellInfo(48518)))-GetTime())
   -- 11.402

   -- "API select" pull all the remaining returns from a given function or API starting from that index, the first valid number is 1
   -- [API_UnitBuff] index 7 is the absolute time (client time) when the buff will expire, in seconds

   local now = GetTime()
   local expirationAbsTime = select(7, UnitBuff(unit, buff))

   if expirationAbsTime~=nil then return math.max(0,(expirationAbsTime - now)) end
   return 0
end

local function getDebuffDurationTime(spellID)
   if spellID==nil then send("spellID came nil inside function to get debuff duration, report this"); return 0; end
   if not is_int(spellID) then send("spellID came, but it's not an integer inside function to get debuff duration, report this, its type is " .. tostring(type(spellID))); return 0; end

   for key, value in pairs(mind_control_spells_duration) do
      if key == spellID then
         if value == -1 then
            return 9999
         else
            return value
         end
      end
   end
   return 12  -- Default value for mind control duration, should cover most mind controls
end]]--

local function tableHasThisEntryAndItsTrue(table, entry)
   assert(table~=nil, "bad argument #1: 'table' cannot be nil")
   assert(type(table) == "table", "bad argument #1: 'table' needs to be a table; instead what came was " .. tostring(type(table)))
   assert(entry~=nil, "bad argument #2: 'entry' cannot be nil")

   for key, value in pairs(table) do
      if entry == key and value then
         return true
      end
   end
   return false
end

local function cancelAllBuffsFromPlayerInTableThatAreTrue(buffTable)
   assert(buffTable~=nil, "bad argument #1: 'buffTable' cannot be nil")
   assert(type(buffTable) == "table", "bad argument #1: 'buffTable' needs to be a table; instead what came was " .. tostring(type(buffTable)))

   for buffID, isTrue in pairs(buffTable) do
      if isTrue then CancelUnitBuff("player", GetSpellInfo(buffID)) end
   end
end

local function sendAddonMessageForBuffRemoved(srcName, spellID)
   if showAddonMessageForBuffRemoval and (GetTime() > (messageLastSent + 1)) then
      if srcName==nil or srcName=="" then srcName = "Alguém" end
      local spell = GetSpellLink(spellID) or ""
      send(format("Removido %s que o %s castou em você.",spell,srcName))
      messageLastSent = GetTime()
   end
end

-- Logic functions are under here
local function onAntiJogoCast(srcName, spellID)
   if srcName==nil or srcName=="" then srcName = "Alguém" end
   assert(type(spellID) == "number", "bad argument #2: 'spellID' needs to be a number; instead what came was " .. tostring(type(spellID)))
   assert(math.floor(spellID) == spellID, "bad argument #2: 'spellID' needs to be an integer")
   updatePlayerClassAndSpecIfNeeded()

   local sendMessage = false
   if(tableHasThisEntryAndItsTrue(antijogo_buffs_general, spellID)) then
      if ajDebug then send(GetSpellLink(spellID) .. " is classified as general antijogo.") end
      cancelAllBuffsFromPlayerInTableThatAreTrue(antijogo_buffs_general)
      sendMessage = true
   elseif tableHasThisEntryAndItsTrue(antijogo_buffs_for_physical, spellID) and isPlayerDPSPhysical() then
      if ajDebug then send(GetSpellLink(spellID) .. " is classified as physical antijogo.") end
      cancelAllBuffsFromPlayerInTableThatAreTrue(antijogo_buffs_for_physical)
      sendMessage = true
   elseif ajDebug and spellID == 20217 then
      CancelUnitBuff("player", GetSpellInfo(20217))
      sendMessage = true
   end
   if sendMessage then sendAddonMessageForBuffRemoved(srcName, spellID) end
end

function BBAJ:COMBAT_LOG_EVENT_UNFILTERED(_, event, _, srcName, _, _, destName, _, spellID, ...)
   if spellID == nil then return end  -- If spell doesn't have an ID, it's not relevant since all antijogo spells have one
   if destName ~= UnitName("player") then return end -- Antijogo buff was not cast on player

   if (event == "SPELL_CAST_SUCCESS" or event == "SPELL_AURA_APPLIED") then
      -- If spell from this table gets cast on player
      if tableHasThisEntryAndItsTrue(antijogo_buffs_general, spellID) or tableHasThisEntryAndItsTrue(antijogo_buffs_for_physical, spellID) then
         onAntiJogoCast(srcName, spellID)

      -- A test case with a Paladin casting 10 minute Kings on player to simulate a Mind Control
      elseif ajDebug and spellID == 20217 then
         onAntiJogoCast(srcName, spellID)
      end
   end
end

local function regForAllEvents()
   if(BBAJ ==nil) then send("frame is nil inside function that register for all events function, report this"); return; end
   if ajDebug then send("addon is now listening to all combatlog events.") end

   BBAJ:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
   BBAJ:RegisterEvent("PLAYER_REGEN_ENABLED")
   BBAJ:RegisterEvent("PLAYER_REGEN_DISABLED")
   BBAJ:RegisterEvent("PLAYER_TALENT_UPDATE")
end

local function unregFromAllEvents()
   if(BBAJ ==nil) then send("frame is nil inside function that unregister all events function, report this"); return; end
   if ajDebug then send("addon is no longer listening to combatlog events.") end

   BBAJ:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
   BBAJ:UnregisterEvent("PLAYER_REGEN_ENABLED")
   BBAJ:UnregisterEvent("PLAYER_REGEN_DISABLED")
   BBAJ:UnregisterEvent("PLAYER_TALENT_UPDATE")
end

-- Checks if addon should be enabled, and enable it if isn't enabled, and disable if it should not be enabled
local function checkIfAddonShouldBeEnabled()
   if(BBAJ==nil) then send("frame came nil inside function that check if this addon should be enabled, report this"); return; end

   local shouldIt = BBAJ.db.enabled
   if shouldIt then
      regForAllEvents()
   else
      unregFromAllEvents()
   end
   return shouldIt
end

-- Called when player leaves combat
-- Used to zero all variables so the addon logic knows that, when player enters combat again, it's a new fight against a new enemy
function BBAJ:PLAYER_REGEN_ENABLED()
   updatePlayerClassAndSpecIfNeeded()
   messageLastSent = 0
end

-- Called when player enters combat
-- Used here to double check if we have what spec player is, and if not then we call getPlayerSpec to get what spec player is beforehand, yet another "just in case" code that if lady casts dominate mind addon maybe won't have time to query what class player is before the control affects the player
function BBAJ:PLAYER_REGEN_DISABLED()
   updatePlayerClassAndSpecIfNeeded()
end

function BBAJ:PLAYER_TALENT_UPDATE()
   updatePlayerClassAndSpec()
   if ajDebug then send("updated talents, now you are using " .. (playerSpec or "Unknown")) end
end

function BBAJ:PLAYER_ENTERING_WORLD()
   updatePlayerClassAndSpecIfNeeded()
   checkIfAddonShouldBeEnabled()
end

-- Slash commands functions
-- toggle, on, off
local function slashToggleAddon(state)
   if state == "on" or (not BBAJ.db.enabled and state==nil) then
      BBAJ.db.enabled = true
      checkIfAddonShouldBeEnabled()
      send("|cff00ff00on|r")
   elseif state == "off" or (BBAJ.db.enabled and state==nil) then
      BBAJ.db.enabled = false
      checkIfAddonShouldBeEnabled()
      send("|cffff0000off|r")
   end
end

-- status, state
local function slashStatus()
   if not BBAJ.db.enabled then
      send("|cffffe83bstatus:|r addon is |cffff0000off|r because it was set as OFF by the command \'/aj toggle\'.")
   else
      send("|cffffe83bstatus:|r addon is |cff00ff00on|r.")
   end
end

-- version, ver
local function slashVersion()
   if(addonVersion==nil) then send("Addon is not loaded yet, try later."); return; end
   send("version " .. addonVersion)
end

-- spec
local function slashSpec()
   if(playerClass==nil) then send("Addon is not loaded yet, try later."); return; end
   updatePlayerClassAndSpec()
   local spec = getPlayerSpec()
   local class = playerClass

   if class=="DEATHKNIGHT" then class = "Death Knight"
   else class = upperFirstOnly(playerClass) end
   if spec==nil then spec = "Desconhecida"
   else spec = upperFirstOnly(spec) end

   send(format("Sua classe é %s e a sua spec é %s.",class,spec))
end

-- debug
local function slashDebug()
   if not ajDebug then
      ajDebug = true
      BBAJ.db.debug = true
   else
      ajDebug = false
      BBAJ.db.debug = false
   end
   send("debug mode turned " .. (ajDebug and "|cff00ff00on|r" or "|cffff0000off|r"))
   checkIfAddonShouldBeEnabled()
end

local function slashCommand(typed)
   local cmd = string.match(typed,"^(%w+)") -- Gets the first word the user has typed
   if cmd~=nil then cmd = cmd:lower() end           -- And makes it lower case
   local extra = removeWords(typed,1)

   if(cmd==nil or cmd=="" or cmd=="toggle") then slashToggleAddon()
   elseif(cmd=="on" or cmd=="enable") then slashToggleAddon("on")
   elseif(cmd=="off" or cmd=="disable") then slashToggleAddon("off")
   elseif(cmd=="status" or cmd=="state" or cmd=="reason") then slashStatus()
   elseif(cmd=="version" or cmd=="ver") then slashVersion()
   elseif(cmd=="spec") then slashSpec()
   elseif(cmd=="debug") then slashDebug()
   end
end
-- End of slash commands function

function BBAJ:ADDON_LOADED(addon)
   if addon ~= "ByeByeAntiJogo" then return end

   BBAJDB = BBAJDB or { enabled = true }
   BBAJDBC = BBAJDBC or { }
   self.db = BBAJDB
   self.dbc = BBAJDBC

   playerClass = select(2,UnitClass("player"))  -- Get player class

   addonVersion = GetAddOnMetadata("ByeByeAntiJogo", "Version")
   groupTalentsLib = LibStub("LibGroupTalents-1.0")   -- Importing LibGroupTalents so I can use it later by using groupTalentsLib variable
   -- Loading variables
   ajDebug = self.db.debug or ajDebug
   SLASH_BYEBYEANTIJOGO1 = "/aj"
   SLASH_BYEBYEANTIJOGO2 = "/bbaj"
   SLASH_BYEBYEANTIJOGO3 = "/byebyeantijogo"
   SlashCmdList.BYEBYEANTIJOGO = function(cmd) slashCommand(cmd) end
   if ajDebug then send("remember that debug mode is |cff00ff00ON|r.") end

   self:RegisterEvent("PLAYER_ENTERING_WORLD")
   self:UnregisterEvent("ADDON_LOADED")
end

BBAJ:RegisterEvent("ADDON_LOADED")