-----------------------------------
-- Setting up scope, upvalues and libs
-----------------------------------

local AddonName, PT = ...;
LibStub("AceEvent-3.0"):Embed(PT);

-- local L = LibStub("AceLocale-3.0"):GetLocale(AddonName);

local _G = _G;

_G.PT=PT;

-- pets nach stufe und qualität sortieren
-- Vorschläge, welches Setup das Pet schlagen könnte

-------------------------------
-- Registering with iLib
-------------------------------

LibStub("iLib"):Register(AddonName, nil, PT);

----------------------
-- Variables
----------------------

local COLOR_GOLD = "|cfffed100%s|r";

------------------
-- Boot
------------------

function PT:Boot()
	-- We require the PetJournal for many API functions
	if( not _G.IsAddOnLoaded("Blizzard_PetJournal") ) then
		_G.LoadAddOn("Blizzard_PetJournal");
	end
	
	self:RegisterEvent("PET_BATTLE_OPENING_DONE", "PetBattleStart");
	self:RegisterEvent("PET_BATTLE_OVER", "PetBattleStop");
	self:RegisterEvent("PET_BATTLE_CLOSE", "PetBattleStop");
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

function PT:Compare(petType, enemyType)
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

local enemyIDs, enemyLevels = {}, {};
local enemyAbilitys = {};

local skillIDs, skillLevels = {}, {};
local petAbilitys = {};

_G.E = enemyAbilitys;
_G.P = petAbilitys;

local function scan_pets(player, t, tID, tLvl)
	local num = _G.C_PetBattles.GetNumPets(player);
	local species, petName, petIcon, petType, creatureID;
	
	for i = 1, num do
		species = _G.C_PetBattles.GetPetSpeciesID(player, i);
		_G.C_PetJournal.GetPetAbilityList(species, tID, tLvl);
		petName, petIcon, petType, creatureID = _G.C_PetJournal.GetPetInfoBySpeciesID(species);
		
		t[i] = {
			name = petName,
			icon = petIcon,
			type = petType,
			level = _G.C_PetBattles.GetLevel(player, i),
		};
		
		for j, ability in pairs(tID) do
			if( t[i].level >= tLvl[j] ) then
				table.insert(t[i], tID[j]);
			end
		end
	end
end

function PT:PetBattleStart()
	scan_pets(_G.LE_BATTLE_PET_ALLY, petAbilitys, skillIDs, skillLevels);
	scan_pets(_G.LE_BATTLE_PET_ENEMY, enemyAbilitys, enemyIDs, enemyLevels);

	local tip = self:GetTooltip("EnemySkills", "UpdateEnemySkills");
	tip:SetPoint("TOPRIGHT", _G.UIParent, "RIGHT", 0, 300);
	tip:Show();
	
	_G.WatchFrame:Hide();
end

function PT:PetBattleStop()
	self:GetTooltip("EnemySkills"):Release();
	_G.WatchFrame:Show();
end

function PT:UpdateEnemySkills(tip)
	tip:Clear();
	tip:SetColumnLayout(2 + #petAbilitys, "LEFT", "LEFT", "CENTER", "CENTER", "CENTER");
	
	line = tip:AddLine("", "");
	for _, pet in ipairs(petAbilitys) do
		tip:SetCell(line, 2+_, "|T"..pet.icon..":22:22|t");
	end
	
	local line;
	local id, name, icon, maxCD, desc, turns, petType, noStrongWeakHints;
	
	local modifier;
	
	for i, enemy in ipairs(enemyAbilitys) do
		if( i ~= 1 ) then
			tip:AddSeparator();
		end
		
		line = tip:AddLine(
			type_icon(enemy.type, 22),
			(COLOR_GOLD):format(enemy.name)
		);
		for _, pet in ipairs(petAbilitys) do
			--modifier = self:Compare(pet.type, enemy.type);
			modifier = self:Compare(enemy.type, pet.type);
			tip:SetCell(line, 2+_, damage_icon(modifier, 22));
		end
		
		for j, ability in ipairs(enemy) do
			id, name, icon, maxCD, desc, turns, petType, noStrongWeakHints = _G.C_PetBattles.GetAbilityInfoByID(ability);
			
			line = tip:AddLine("|T"..icon..":22:22|t", "  "..name);
			for _, pet in ipairs(petAbilitys) do
				--modifier = self:Compare(pet.type, petType);
				modifier = self:Compare(petType, pet.type);
				tip:SetCell(line, 2+_, damage_icon(modifier, 22));
			end
		end
	end
end

---------------------------------------------------------
-- GAME TOOLTIP
---------------------------------------------------------

local function GameTooltip_hook(self)
	local name, unit = self:GetUnit();
	
	if( not _G.UnitIsWildBattlePet(unit) ) then
		return;
	end
	local enemyType = _G.UnitBattlePetType(unit);
	
	_G[self:GetName().."TextLeft2"]:SetText(_G[self:GetName().."TextLeft2"]:GetText().." "..type_icon(enemyType, 18, 0, 2));
	
	local _, petID, ability1, ability2, ability3, locked, customName, lvl, petName, petType;
	local modifier, name;
	
	for i = 1, PT.maxActive do
		petID, ability1, ability2, ability3, locked = _G.C_PetJournal.GetPetLoadOutInfo(i);
		
		if( not locked and petID > 0 ) then
			self:AddLine(" ");
			
			_, customName, lvl, _, _, _, petName, _, petType, _ = _G.C_PetJournal.GetPetInfoByPetID(petID);
			petName = customName and customName.." (|cffffffff"..petName.."|r)" or petName;
			
			-- Type Check
			modifier = PT:Compare(petType, enemyType);
			self:AddDoubleLine(
				type_icon(petType, 14).." "..petName..", L"..lvl.."",
				damage_icon(modifier, 14)
			);
			
			-- Ability1 Check
			modifier, name = PT:CompareByAbilityID(ability1, enemyType);
			self:AddDoubleLine(
				"|cffffffff- "..name.."|r",
				damage_icon(modifier, 14)
			);
			
			-- Ability2 Check
			modifier, name = PT:CompareByAbilityID(ability2, enemyType);
			self:AddDoubleLine(
				"|cffffffff- "..name.."|r",
				damage_icon(modifier, 14)
			);
			
			-- Ability3 Check
			modifier, name = PT:CompareByAbilityID(ability3, enemyType);
			self:AddDoubleLine(
				"|cffffffff- "..name.."|r",
				damage_icon(modifier, 14)
			);
			
		end
	end -- end for
end
GameTooltip:HookScript("OnTooltipSetUnit", GameTooltip_hook);