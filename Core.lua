local AddonName, PT = ...;
LibStub("AceEvent-3.0"):Embed(PT);

-- local L = LibStub("AceLocale-3.0"):GetLocale(AddonName);

local _G = _G;

_G.PT=PT;

-- pets nach stufe und qualität sortieren
-- Vorschläge, welches Setup das Pet schlagen könnte


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
end
PT:RegisterEvent("PLAYER_ENTERING_WORLD", "Boot");





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