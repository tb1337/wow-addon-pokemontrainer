-----------------------------------
-- Setting up scope, upvalues and libs
-----------------------------------

local AddonName, PT = ...;
LibStub("AceEvent-3.0"):Embed(PT);

local L = LibStub("AceLocale-3.0"):GetLocale(AddonName);

local _G = _G;

-------------------------------
-- Registering with iLib
-------------------------------

LibStub("iLib"):Register(AddonName, nil, PT);

----------------------
-- Variables
----------------------

local COLOR_GOLD = "|cfffed100%s|r";

local OwnedPets = {};

------------------
-- Boot
------------------

function PT:Boot()
	-- for the skill frames
	self:RegisterEvent("PET_BATTLE_OPENING_DONE", "PetBattleStart");
	self:RegisterEvent("PET_BATTLE_OVER", "PetBattleStop");
	self:RegisterEvent("PET_BATTLE_CLOSE", "PetBattleStop");
	self:RegisterEvent("PET_BATTLE_PET_CHANGED", "PetBattleChanged");
	
	-- for the hooked tooltips
	self:RegisterEvent("PET_JOURNAL_LIST_UPDATE", "UpdateOwnedPets");
	self:RegisterEvent("UPDATE_MOUSEOVER_UNIT", "PetTooltip");
end
PT:RegisterEvent("PLAYER_ENTERING_WORLD", "Boot");

---------------------
-- Utility
---------------------

function type_icon(petType, size, offx, offy)
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

local function quality_color(index, name)
	local r, g, b, hex = _G.GetItemQualityColor(_G.C_PetBattles.GetBreedQuality(2, index) - 1);
	return ("|c"..hex.."%s|r"):format(name);
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

---------------------------------------------------------
-- BATTLE FRAME
---------------------------------------------------------

local enemyAbilitys = {};
local petAbilitys = {};

local function scan_pets(player, t, tID, tLvl)
	local num = _G.C_PetBattles.GetNumPets(player);
	
	local species, petName, petIcon, petType, level, abilityID;
	
	for i = 1, num do
		species = _G.C_PetBattles.GetPetSpeciesID(player, i);
		petName, petIcon, petType = _G.C_PetJournal.GetPetInfoBySpeciesID(species);
		level = _G.C_PetBattles.GetLevel(player, i);
		
		t[i] = {
			name = petName,
			icon = petIcon,
			type = petType,
			--level = level
		};
		
		for j = 1, (level >= 4 and 3 or level >= 2 and 2 or 1) do
			abilityID = _G.C_PetBattles.GetAbilityInfo(player, i, j);
			table.insert(t[i], abilityID);
		end
	end
end

function PT:PetBattleStart()
	-- We require the PetJournal for many API functions
	if( not _G.IsAddOnLoaded("Blizzard_PetJournal") ) then
		_G.LoadAddOn("Blizzard_PetJournal");
	end
	
	scan_pets(_G.LE_BATTLE_PET_ALLY, petAbilitys, skillIDs, skillLevels);
	scan_pets(_G.LE_BATTLE_PET_ENEMY, enemyAbilitys, enemyIDs, enemyLevels);

	local tip = self:GetTooltip("EnemySkills", "UpdateEnemySkills");
	tip:SetPoint("TOPRIGHT", _G.UIParent, "RIGHT", 0, 300);
	tip:SetFrameStrata("BACKGROUND");
	tip:SetScale(1);
	tip:Show();
	
	tip = self:GetTooltip("PlayerSkills", "UpdatePlayerSkills");
	tip:SetPoint("TOPLEFT", _G.UIParent, "LEFT", 0, 300);
	tip:SetFrameStrata("BACKGROUND");
	tip:SetScale(1);
	tip:Show();
	
	_G.WatchFrame:Hide();
end

function PT:PetBattleStop()
	self:GetTooltip("EnemySkills"):Release();
	self:GetTooltip("PlayerSkills"):Release();
	_G.WatchFrame:Show();
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

function PT:UpdateEnemySkills(tip)
	tip:Clear();
	tip:SetColumnLayout(2 + #petAbilitys, "LEFT", "LEFT", "CENTER", "CENTER", "CENTER");
	
	local line = tip:AddLine("", "");
	for _, pet in ipairs(petAbilitys) do
		tip:SetCell(line, 2+_, "|T"..pet.icon..":22:22|t");
		if( _ == _G.C_PetBattles.GetActivePet(_G.LE_BATTLE_PET_ALLY) ) then
			tip:SetColumnColor(2+_, 0, 1, 0, 0.5);
		else
			tip:SetColumnColor(2+_, 0, 0, 0, 0);
		end
	end
	
	local id, name, icon, maxCD, desc, turns, petType, noStrongWeakHints;
	local modifier;
	
	for i, enemy in ipairs(enemyAbilitys) do
		if( i ~= 1 ) then
			tip:AddSeparator();
		end
		
		line = tip:AddLine(
			type_icon(enemy.type, 22),
			--(COLOR_GOLD):format(enemy.name)
			quality_color(i, enemy.name)
		);
		for _, pet in ipairs(petAbilitys) do
			modifier = self:Compare(enemy.type, pet.type);
			tip:SetCell(line, 2+_, damage_icon(modifier, 22));
		end

		if( i == _G.C_PetBattles.GetActivePet(_G.LE_BATTLE_PET_ENEMY) ) then
			tip:SetLineColor(line, 1, 0, 0, 0.5);
		end
		
		for j, ability in ipairs(enemy) do
			id, name, icon, maxCD, desc, turns, petType, noStrongWeakHints = _G.C_PetBattles.GetAbilityInfoByID(ability);
			
			line = tip:AddLine("|T"..icon..":22:22|t", "  "..(COLOR_GOLD):format(name));
			for _, pet in ipairs(petAbilitys) do
				modifier = self:Compare(petType, pet.type);
				tip:SetCell(line, 2+_, damage_icon(modifier, 22));
			end
			
			tip:SetLineScript(line, "OnEnter", enemySkill_OnEnter, {i, ability});
			tip:SetLineScript(line, "OnLeave", enemySkill_OnLeave);
		end
	end
end

local function playerSkill_OnEnter(anchor, info)
	_G.PetBattleAbilityTooltip_SetAuraID(_G.LE_BATTLE_PET_ALLY, info[1], info[2]);
	_G.PetBattleAbilityTooltip_Show("TOPLEFT", anchor, "TOPRIGHT", 10, 2);
end
local function playerSkill_OnLeave()
	_G.PetBattlePrimaryAbilityTooltip:Hide();
end

function PT:UpdatePlayerSkills(tip)
	tip:Clear();
	tip:SetColumnLayout(2 + #enemyAbilitys, "LEFT", "LEFT", "CENTER", "CENTER", "CENTER");
	
	local line = tip:AddLine("", "");
	for _, enemy in ipairs(enemyAbilitys) do
		tip:SetCell(line, 2+_, "|T"..enemy.icon..":22:22|t");
		if( _ == _G.C_PetBattles.GetActivePet(_G.LE_BATTLE_PET_ENEMY) ) then
			tip:SetColumnColor(2+_, 1, 0, 0, 0.5);
		else
			tip:SetColumnColor(2+_, 0, 0, 0, 0);
		end
	end
	
	local id, name, icon, maxCD, desc, turns, petType, noStrongWeakHints;
	local modifier;
	
	for i, pet in ipairs(petAbilitys) do
		if( i ~= 1 ) then
			tip:AddSeparator();
		end
		
		line = tip:AddLine(
			type_icon(pet.type, 22),
			--(COLOR_GOLD):format(pet.name)
			quality_color(i, pet.name)
		);
		for _, enemy in ipairs(enemyAbilitys) do
			modifier = self:Compare(pet.type, enemy.type);
			tip:SetCell(line, 2+_, damage_icon(modifier, 22));
		end

		if( i == _G.C_PetBattles.GetActivePet(_G.LE_BATTLE_PET_ALLY) ) then
			tip:SetLineColor(line, 0, 1, 0, 0.5);
		end
		
		for j, ability in ipairs(pet) do
			id, name, icon, maxCD, desc, turns, petType, noStrongWeakHints = _G.C_PetBattles.GetAbilityInfoByID(ability);
			
			line = tip:AddLine("|T"..icon..":22:22|t", "  "..(COLOR_GOLD):format(name));
			for _, enemy in ipairs(enemyAbilitys) do
				modifier = self:Compare(petType, enemy.type);
				tip:SetCell(line, 2+_, damage_icon(modifier, 22));
			end
			
			tip:SetLineScript(line, "OnEnter", playerSkill_OnEnter, {i, ability});
			tip:SetLineScript(line, "OnLeave", playerSkill_OnLeave);
		end
	end
end

---------------------------------------------------------
-- GAME TOOLTIP
---------------------------------------------------------
	
function PT:UpdateOwnedPets()
	_G.wipe(OwnedPets);
	
	local numPets, numOwned = _G.C_PetJournal.GetNumPets(false);
	local _, rarity, petID, name;
	
	for i = 1, numOwned do
		petID, _, _, _, _, _, _, name = _G.C_PetJournal.GetPetInfoByIndex(i, false);
		
		if( not petID ) then
			return;
		end
		_, _, _, _, rarity = _G.C_PetJournal.GetPetStats(petID);
		
		if( not OwnedPets[name] or OwnedPets[name] < rarity ) then
			OwnedPets[name] = rarity;
		end
	end	
end

function PT:PetTooltip()
	local name, unit = _G.GameTooltip:GetUnit();
	if( not _G.UnitIsWildBattlePet(unit) ) then
		return;
	end
	
	-- We require the PetJournal for many API functions
	if( not _G.IsAddOnLoaded("Blizzard_PetJournal") ) then
		_G.LoadAddOn("Blizzard_PetJournal");
	end
	
	if( not _G["PetCaught"] ) then
		if( OwnedPets[name] ) then
			local c = _G.ITEM_QUALITY_COLORS[OwnedPets[name] -1];
			_G.GameTooltip:AddLine("|TInterface\\RAIDFRAME\\ReadyCheck-Ready:14:14|t "..L["Already caught"], c.r, c.g, c.b);
		else
			_G.GameTooltip:AddLine("|TInterface\\RAIDFRAME\\ReadyCheck-NotReady:14:14|t "..L["Not caught"], 1, 0, 0);
		end
	end
	
	local enemyType = _G.UnitBattlePetType(unit);
	local modifier, _, petID, ability1, ability2, ability3, locked, customName, lvl, petName, petType;
	
	for i = 1, 3 do
		petID, ability1, ability2, ability3, locked = _G.C_PetJournal.GetPetLoadOutInfo(i);
		
		if( not locked and petID > 0 ) then
			_G.GameTooltip:AddLine(" ");
			
			_, customName, lvl, _, _, _, petName, _, petType, _ = _G.C_PetJournal.GetPetInfoByPetID(petID);
			petName = customName and customName.." (|cffffffff"..petName.."|r)" or petName;
			
			-- Type Check
			modifier = PT:Compare(petType, enemyType);
			_G.GameTooltip:AddDoubleLine(
				type_icon(petType, 14).." "..petName.." ("..lvl..")",
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
	
	_G.GameTooltip:Show();
end