local AddonName, PT = ...;
LibStub("AceEvent-3.0"):Embed(PT);

-- local L = LibStub("AceLocale-3.0"):GetLocale(AddonName);

local _G = _G;

_G.PT=PT;

-- pets nach stufe und qualität sortieren
-- Vorschläge, welches Setup das Pet schlagen könnte

LibStub("iLib"):Register(AddonName, nil, PT);

----------------------
-- Variables
----------------------

PT.maxActive = 3;

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

function PT:ComparyByAbilityID(abilityID, enemyType)
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

local abilityIDs, abilityLevels = {}, {};
local enemyAbilitys = {};

_G.E = enemyAbilitys;

function PT:PetBattleStart()
	local species, id, name, icon, maxCD, desc;
	local petName, petIcon, petType, creatureID;
	
	for i = 1, 3 do
		species = _G.C_PetBattles.GetPetSpeciesID(_G.LE_BATTLE_PET_ENEMY, i);
		_G.C_PetJournal.GetPetAbilityList(species, abilityIDs, abilityLevels);
		petName, petIcon, petType, creatureID = _G.C_PetJournal.GetPetInfoBySpeciesID(species);
		
		enemyAbilitys[i] = {
			name = petName,
			icon = petIcon,
			type = petType,
		};
		
		for j, ability in pairs(abilityIDs) do
			id, name, icon, maxCD, desc = _G.C_PetBattles.GetAbilityInfoByID(ability);
			
			table.insert(enemyAbilitys[i], {abilityLevels[j], _G.C_PetBattles.GetAbilityInfoByID(ability)});
		end
	end

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
	tip:SetColumnLayout(2, "LEFT", "LEFT");
	
	_G.wipe(abilityIDs);
	_G.wipe(abilityLevels);
	
	local id, name, icon, maxCD, desc;
	
	for i = 1, 3 do
		local species = _G.C_PetBattles.GetPetSpeciesID(_G.LE_BATTLE_PET_ENEMY, i);
		
		_G.C_PetJournal.GetPetAbilityList(species, abilityIDs, abilityLevels);
		
		for _, ability in pairs(abilityIDs) do
			id, name, icon, maxCD, desc = C_PetBattles.GetAbilityInfoByID(ability);
			
			tip:AddLine(
				"|T"..icon..":24:24|t",
				name
			);
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
			modifier, name = PT:ComparyByAbilityID(ability1, enemyType);
			self:AddDoubleLine(
				"|cffffffff- "..name.."|r",
				damage_icon(modifier, 14)
			);
			
			-- Ability2 Check
			modifier, name = PT:ComparyByAbilityID(ability2, enemyType);
			self:AddDoubleLine(
				"|cffffffff- "..name.."|r",
				damage_icon(modifier, 14)
			);
			
			-- Ability3 Check
			modifier, name = PT:ComparyByAbilityID(ability3, enemyType);
			self:AddDoubleLine(
				"|cffffffff- "..name.."|r",
				damage_icon(modifier, 14)
			);
			
		end
	end -- end for
end
GameTooltip:HookScript("OnTooltipSetUnit", GameTooltip_hook);