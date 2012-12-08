-----------------------------------
-- Setting up scope, upvalues and libs
-----------------------------------

local AddonName = ...;
local PT = LibStub("AceAddon-3.0"):NewAddon(select(2, ...), AddonName, "AceEvent-3.0", "AceTimer-3.0")

local L = LibStub("AceLocale-3.0"):GetLocale(AddonName);
local LibPetJournal = LibStub("LibPetJournal-2.0");

local _G = _G;

-------------------------------
-- Registering with iLib
-------------------------------

LibStub("iLib"):Register(AddonName, nil, PT);

----------------------
-- Constants
----------------------

local COLOR_RED = "|cffff0000%s|r";
local COLOR_GOLD = "|cfffed100%s|r";

----------------------
-- Variables
----------------------

PT.OwnedPets = {}

---------------------
-- Utility
---------------------

local function GetDifficultyColor(levelDiff)
  local color
  if ( levelDiff >= 5 ) then
    color = _G.QuestDifficultyColors["impossible"];
  elseif ( levelDiff >= 3 ) then
    color = _G.QuestDifficultyColors["verydifficult"];
  elseif ( levelDiff >= -2 ) then
    color = _G.QuestDifficultyColors["difficult"];
  elseif ( -levelDiff <= 3 ) then
    color = _G.QuestDifficultyColors["standard"];
  else
    color = _G.QuestDifficultyColors["trivial"];
  end
  return color.r, color.g, color.b;
end

local function level_color(level, compare_level)
    local r,g,b = GetDifficultyColor(compare_level - level)
    return ("|cff%02x%02x%02x%s|r"):format(r*255,g*255,b*255,level)
end

local function type_icon(petType, size, offx, offy)
	if not size then size = 14 end
	if not offx then offx = 0 end
	if not offy then offy = 0 end
	return "|T".._G.GetPetTypeTexture(petType)..":"..size..":"..size..":"..offx..":"..offy..":128:256:62:102:128:169|t";
end

local function damage_icon(modifier, size)
	if not size then size = 14 end
	
	if( modifier > 1 ) then
		return "|TInterface\\PetBattles\\BattleBar-AbilityBadge-Strong:"..size..":"..size.."|t";
	elseif( modifier < 1 ) then
		return "|TInterface\\PetBattles\\BattleBar-AbilityBadge-Weak:"..size..":"..size.."|t";
	else
		return "|TInterface\\PetBattles\\BattleBar-AbilityBadge-Neutral:"..size..":"..size.."|t";
	end
end

local function quality_color(owner, index, name)
	local r, g, b, hex = _G.GetItemQualityColor(_G.C_PetBattles.GetBreedQuality(owner, index) - 1);
	return ("|c"..hex.."%s|r"):format(name);
end

local function format_cooldown(name, id, avail, cdleft)
	if( id and not avail) then
        if (cdleft ~= nil and cdleft > 0) then -- the ability can be unuseable without cooldown, under unknown circumstates the cdleft may be nil (may be was the missing table wipe)
            return (COLOR_RED):format(name.." ("..cdleft..")");
        else
            return (COLOR_RED):format(name);
        end
	end
	
	return (COLOR_GOLD):format(name);
end

local function UpdateOwnedPets()
	_G.wipe(PT.OwnedPets);

	local numPets, numOwned = _G.C_PetJournal.GetNumPets(false);
	local _, rarity, petID, name;

    --[[
    for i, petID in LibPetJournal:IteratePetIDs() do
		_, _, _, _, rarity = _G.C_PetJournal.GetPetStats(petID);
	
		if( not PT.OwnedPets[petID] or PT.OwnedPets[petID] < rarity ) then
			PT.OwnedPets[petID] = rarity;
		end
	end]]
    for i, speciesID in LibPetJournal:IterateSpeciesIDs() do
        PT.OwnedPets[speciesID] = true
    end
end

function PT:Compare(petType, enemyType)
	if( not petType or not enemyType ) then
		return 1;
	end
	return _G.C_PetBattles.GetAttackModifier(petType, enemyType);
end

function PT:CompareByAbilityID(abilityID, enemyType)
	local _, name, icon, _, _, _, petType, noStrongWeakHints = _G.C_PetBattles.GetAbilityInfoByID(abilityID);
	if( noStrongWeakHints ) then
		return 1, name, icon;
	else
		return self:Compare(petType, enemyType), name, icon;
	end
end

------------------
-- Boot
------------------

function PT:OnEnable()
	self.db = LibStub("AceDB-3.0"):New("PokemonTrainerDB", self:CreateDB(), "Default").profile;
	
	-- for the skill frames
	self:RegisterEvent("PET_BATTLE_OPENING_START", "PetBattleStart");
	self:RegisterEvent("PET_BATTLE_OVER", "PetBattleStop");
	self:RegisterEvent("PET_BATTLE_CLOSE", "PetBattleStop");
	self:RegisterEvent("PET_BATTLE_PET_CHANGED", "PetBattleChanged");
	self:RegisterEvent("PET_BATTLE_PET_ROUND_PLAYBACK_COMPLETE", "PetBattleChanged");
	
	-- for the hooked tooltips
	LibPetJournal:RegisterCallback("PetListUpdated", UpdateOwnedPets);
	self:RegisterEvent("UPDATE_MOUSEOVER_UNIT", "PetTooltip");
end

---------------------------------------------------------
-- BATTLE FRAME
---------------------------------------------------------


local cellAppendProvider, cellPrototype, baseCellPrototype = LibStub("LibQTip-1.0"):CreateCellProvider()
function cellPrototype:InitializeCell()
    --[[self.fontString = self:CreateFontString()
    self.fontString:SetAllPoints(self)
    self.fontString:SetFontObject(GameTooltipText)
    self.r, self.g, self.b = 1, 1, 1]]
end
function cellPrototype:SetupCell(tooltip, value, justification, font, r, g, b)
    if (type(value) == "table") then
        value:SetParent(self)
        value:SetPoint("TOPLEFT", self)
        return value:GetWidth(), value:GetHeight()
    else
        return baseCellPrototype.SetupCell(self, tooltip, value, justification, font, r, g, b)
    end
end
cellPrototype.ReleaseCell = InitializeCell;

--[[local ]]speed_indicators = {}
local function get_speed_indicator_frame(player, pet, enemy)
    local idx = (player * 100) + (pet * 10) + enemy
    if (speed_indicators[idx] == nil) then
        local frame = CreateFrame("Frame")
        frame:SetWidth(22);
        frame:SetHeight(22);
        
        frame.underlay = frame:CreateTexture(nil, "ARTWORK", "MainPet-LevelBubble")
        frame.underlay:SetWidth(22);
        frame.underlay:SetHeight(22);
        frame.underlay:SetVertexColor(0.5, 0.5, 0.5, 1);
        frame.underlay:SetPoint("CENTER")
        
        frame.icon = frame:CreateTexture(nil, "OVERLAY");
        frame.icon:SetWidth(14);
        frame.icon:SetHeight(14);
        frame.icon:SetTexture("Interface\\PetBattles\\PetBattle-StatIcons");
        frame.icon:SetTexCoord(0, 0.5, 0.5, 1);
        frame.icon:SetPoint("CENTER")
        
        speed_indicators[idx] = frame;
    end
    return speed_indicators[idx];
end
local function has_flight_bonus_active(side, pet)
    --[[return _G.C_PetBattles.GetPetType(side, i) == 3 and -- Is Flight-Pet
                _G.C_PetBattles.GetHealth(side, i) > (_G.C_PetBattles.GetMaxHealth(side, i) * 0.5) and -- Has Flight-Buff
                (mySpeed / 1.5) < hisSpeed;]]
    for i = 1, _G.C_PetBattles.GetNumAuras(side, pet) do
        if (_G.C_PetBattles.GetAuraInfo(side, pet, i) == 239) then -- http://www.wowhead.com/petability=239
            return true
        end
    end
    return false
end

local function scan_pets(player, intoTable)
    local t = intoTable or {}
	local num = _G.C_PetBattles.GetNumPets(player)
	
	for i = 1, num do
		local species = _G.C_PetBattles.GetPetSpeciesID(player, i);
		local speciesName, petIcon, petType = _G.C_PetJournal.GetPetInfoBySpeciesID(species);
		local level = _G.C_PetBattles.GetLevel(player, i);
        local petName = _G.C_PetBattles.GetName(player, i) -- gets the custom name, and also works for boss pets
        
		t[i] = {
			name = petName,
			icon = petIcon,
			type = petType,
			--level = level
		};
		
		for j = 1, (level >= 4 and 3 or level >= 2 and 2 or 1) do
			t[i][j] = _G.C_PetBattles.GetAbilityInfo(player, i, j);
		end
	end
    return t
end

function PT:ScanDummyPets(player)
    t = {}
	for i = 1, 3 do
		t[i] = {
			name = "Pet Dummy "..i,
			icon = "Interface\\RAIDFRAME\\ReadyCheck-NotReady",
			type = 1,
            [1] = 812,
            [2] = 812,
            [3] = 812,
		};
	end
    return t
end

local playerAbilities, enemyAbilities = {}, {};

function PT:PetBattleStart()
	-- We require the PetJournal for many API functions
	if( not _G.IsAddOnLoaded("Blizzard_PetJournal") ) then
		_G.LoadAddOn("Blizzard_PetJournal");
	end
	
    -- pre-cache the skills in lokal tables to pass the data to UpdateTooltip
    scan_pets(_G.LE_BATTLE_PET_ALLY, --[[into]] playerAbilities)
    scan_pets(_G.LE_BATTLE_PET_ENEMY, --[[into]] enemyAbilities)
    
	local tip = self:GetTooltip("EnemySkills", "UpdateEnemySkills");
	tip:SetPoint("TOPRIGHT", _G.UIParent, "TOPRIGHT", 0, -self.db.BattlePositionY);
	tip:SetFrameStrata("BACKGROUND");
	tip:SetScale(self.db.BattleFrameScale);
	tip:Show();
	
	tip = self:GetTooltip("PlayerSkills", "UpdatePlayerSkills");
	tip:SetPoint("TOPLEFT", _G.UIParent, "TOPLEFT", 0, -self.db.BattlePositionY);
	tip:SetFrameStrata("BACKGROUND");
	tip:SetScale(self.db.BattleFrameScale);
	tip:Show();
end

function PT:PetBattleStop()
    _G.wipe(playerAbilities); -- remove table content for clean start on next battle. the table address remains the same
    _G.wipe(enemyAbilities);
	self:GetTooltip("EnemySkills"):Release();
	self:GetTooltip("PlayerSkills"):Release();
end

function PT:UpdatePlayerSkills(tip)
    self:UpdateTooltip(tip, _G.LE_BATTLE_PET_ALLY, playerAbilities, enemyAbilities)
end

function PT:UpdateEnemySkills(tip)
    self:UpdateTooltip(tip, _G.LE_BATTLE_PET_ENEMY, enemyAbilities, playerAbilities)
end

function PT:PetBattleChanged()
	self:CheckTooltips("EnemySkills", "PlayerSkills");
end

local function enemySkill_OnEnter(anchor, info)
	_G.PetBattleAbilityTooltip_SetAuraID(_G.LE_BATTLE_PET_ENEMY, info[1], info[2]);
	_G.PetBattleAbilityTooltip_Show("TOPRIGHT", anchor, "TOPLEFT", -10, 2);
end
local function enemySkill_OnLeave()
	_G.PetBattlePrimaryAbilityTooltip:Hide();
end



function PT:UpdateTooltip(tip, side, displayAbilities, compareAbilities)
	tip:Clear();
    
    local isme = side == _G.LE_BATTLE_PET_ALLY;
    local versus = isme and _G.LE_BATTLE_PET_ENEMY or _G.LE_BATTLE_PET_ALLY
    
    -- the given cached tables are optional, without we're gonna fetch them (unused, but nice to have)
    if (type(displayAbilities) ~= "table") then
        displayAbilities = scan_pets(side)
    end
    if (type(compareAbilities) ~= "table") then
        compareAbilities = scan_pets(versus)
    end
    
	tip:SetColumnLayout(2 + #compareAbilities, "LEFT", "LEFT", "CENTER", "CENTER", "CENTER");
	
	local line = tip:AddLine("", "");
	for i, pet in ipairs(compareAbilities) do
		tip:SetCell(line, 2 + i, "|T"..pet.icon..":22:22|t");
		if (i == _G.C_PetBattles.GetActivePet(versus)) then
            if (isme) then
                tip:SetColumnColor(2 + i, 1, 0, 0, 0.5);
            else
                tip:SetColumnColor(2 + i, 0, 1, 0, 0.5);
            end
		else
			tip:SetColumnColor(2 + i, 0, 0, 0, 0);
		end
	end
	
	for i, pet in ipairs(displayAbilities) do
		if (i ~= 1) then
			tip:AddSeparator();
		end
		
		line = tip:AddLine(type_icon(pet.type, 22), quality_color(side, i, pet.name));
		
        local mySpeed = _G.C_PetBattles.GetSpeed(side, i)
		for j, enemy in ipairs(compareAbilities) do
            local frame = get_speed_indicator_frame(side, i, j)
            local vsSpeed = _G.C_PetBattles.GetSpeed(versus, j);
            if (mySpeed > vsSpeed) then
                if (has_flight_bonus_active(side, i)) then
                    frame.icon:SetVertexColor(0.1,0.9,0.1, 1)
                else
                    frame.icon:SetVertexColor(1,1,1, 1)
                end
            elseif (mySpeed == vsSpeed) then
                frame.icon:SetVertexColor(0.3,0.3,0.3, 1);
            else
                frame.icon:SetVertexColor(0.7,0.1,0.1, 1);
            end
            
            tip:SetCell(line, 2 + j, frame, cellAppendProvider); -- Sets frame-parent to cell
            frame:SetPoint("CENTER");
            
			--[[local modifier = self:Compare(pet.type, enemy.type);
			tip:SetCell(line, 2 + j, damage_icon(modifier, 22));]]
		end

		if (i == _G.C_PetBattles.GetActivePet(side)) then
            if (isme) then
                tip:SetLineColor(line, 0, 1, 0, 0.5);
            else
                tip:SetLineColor(line, 1, 0, 0, 0.5);
            end
		end
		
		for j, ability in ipairs(pet) do
			local id, name, icon, maxCD, desc, turns, petType, noStrongWeakHints = _G.C_PetBattles.GetAbilityInfoByID(ability);
			local avail, cdleft, _ = _G.C_PetBattles.GetAbilityState(side, i, j);
			
			line = tip:AddLine("|T"..icon..":22:22|t", "  "..format_cooldown(name, id, avail, cdleft));
			
			for k, pet in ipairs(compareAbilities) do
				local modifier = self:Compare(petType, pet.type);
				tip:SetCell(line, 2 + k, damage_icon(modifier, 22));
			end
			
			tip:SetLineScript(line, "OnEnter", function (anchor)
                    _G.PetBattleAbilityTooltip_SetAuraID(side, i, ability);
                    if (isme) then
                        _G.PetBattleAbilityTooltip_Show("TOPLEFT", anchor, "TOPRIGHT", 10, 2);
                    else
                        _G.PetBattleAbilityTooltip_Show("TOPRIGHT", anchor, "TOPLEFT", -10, 2);
                    end
                end);
			tip:SetLineScript(line, "OnLeave", function ()
                    _G.PetBattlePrimaryAbilityTooltip:Hide();
                end);
		end
	end
end

---------------------------------------------------------
-- GAME TOOLTIP
---------------------------------------------------------

function PT:PetTooltip()
	local name, unit = _G.GameTooltip:GetUnit();
	if( not unit or not _G.UnitIsWildBattlePet(unit) ) then
		return;
	end
	
	-- We require the PetJournal for many API functions
	if( not _G.IsAddOnLoaded("Blizzard_PetJournal") ) then
		_G.LoadAddOn("Blizzard_PetJournal");
	end
	
	--if( not _G["PetCaught"] and self.db.TooltipShowCaught ) then
	--	if( OwnedPets[name] ) then
	--		local c = _G.ITEM_QUALITY_COLORS[OwnedPets[name] -1];
	--		_G.GameTooltip:AddLine("|TInterface\\RAIDFRAME\\ReadyCheck-Ready:14:14|t "..L["Already caught"], c.r, c.g, c.b);
	--	else
	--		_G.GameTooltip:AddLine("|TInterface\\RAIDFRAME\\ReadyCheck-NotReady:14:14|t "..L["Not caught"], 1, 0, 0);
	--	end
	--end
	
	if( self.db.TooltipShowProsCons ) then
		local enemyType, enemyLevel = _G.UnitBattlePetType(unit), _G.UnitBattlePetLevel(unit)
		local modifier, _, petID, ability1, ability2, ability3, locked, customName, lvl, petName, petType;
		
		for i = 1, 3 do
			petID, ability1, ability2, ability3, locked = _G.C_PetJournal.GetPetLoadOutInfo(i);
			if( not locked and petID ~= nil ) then
				_G.GameTooltip:AddLine(" ");
				
				_, customName, lvl, _, _, _, _, petName, _, petType, _ = _G.C_PetJournal.GetPetInfoByPetID(petID);
				petName = customName and customName.." (|cffffffff"..petName.."|r)" or petName;
				
				-- Type Check
				modifier = PT:Compare(petType, enemyType);
				_G.GameTooltip:AddDoubleLine(
					type_icon(petType, 14).." "..petName.." ("..level_color(lvl, enemyLevel)..")",
					damage_icon(modifier, 14)
				);
				
				-- Ability1 Check
				modifier, name = PT:CompareByAbilityID(ability1, enemyType);
				_G.GameTooltip:AddDoubleLine(
					"|cffffffff- "..name.."|r",
					damage_icon(modifier, 14)
				);
				
				-- Ability2 Check
				modifier, name = PT:CompareByAbilityID(ability2, enemyType);
				_G.GameTooltip:AddDoubleLine(
					"|cffffffff- "..name.."|r",
					damage_icon(modifier, 14)
				);
				
				-- Ability3 Check
				modifier, name = PT:CompareByAbilityID(ability3, enemyType);
				_G.GameTooltip:AddDoubleLine(
					"|cffffffff- "..name.."|r",
					damage_icon(modifier, 14)
				);
			end
		end
	end
	
	_G.GameTooltip:Show();
end
