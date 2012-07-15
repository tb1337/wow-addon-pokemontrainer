local AddonName, PT = ...;
LibStub("AceEvent-3.0"):Embed(PT);

-- local L = LibStub("AceLocale-3.0"):GetLocale(AddonName);

local _G = _G;

_G.PT=PT;

-- pets nach stufe und qualität sortieren


----------------------
-- Variables
----------------------

PT.maxActive = 3;
PT.activePets = 0;

------------------
-- Boot
------------------

function PT:Boot()
	-- We require the PetJournal for many API functions
	if( not _G.IsAddOnLoaded("Blizzard_PetJournal") ) then
		_G.LoadAddOn("Blizzard_PetJournal");
	end
	
	--self:UpdatePetRoster();
	--self:RegisterEvent("BATTLE_PET_CURSOR_CLEAR", "UpdatePetRoster");
end
PT:RegisterEvent("PLAYER_ENTERING_WORLD", "Boot");


function PT:UpdatePetRoster()
	self.activePets = 0;
	
	for i = 1, self.maxActive do
		local petID, _, _, _, locked = _G.C_PetJournal.GetPetLoadOutInfo(i);
		
		if( not locked and petID > 0 ) then
			self.activePets = self.activePets + 1;
		end
	end
end

---------------------
-- Utility
---------------------

function PT:GetPetTypeIcon(petType, size, offx, offy)
	if not size then size = 14 end
	if not offx then offx = 0 end
	if not offy then offy = 0 end
	return "|T".._G.GetPetTypeTexture(petType)..":"..size..":"..size..":"..offx..":"..offy..":128:256:62:102:128:169|t";
end

function PT:GetPetDamageModIcon(petType, enemyType, size)
	if not size then size = 14 end
	
	local icon;
	local modifier = _G.C_PetBattles.GetAttackModifier(petType, enemyType, size);
	
	if( modifier < 1 ) then
		icon = "|TInterface\\PetBattles\\BattleBar-AbilityBadge-Strong:"..size..":"..size.."|t";
	elseif( modifier > 1 ) then
		icon = "|TInterface\\PetBattles\\BattleBar-AbilityBadge-Weak:"..size..":"..size.."|t";
	else
		icon = "|TInterface\\PetBattles\\BattleBar-AbilityBadge-Neutral:"..size..":"..size.."|t";
	end
	
	return icon;
end

local function GameTooltip_hook(self)
	local name, unit = self:GetUnit();
	
	if( _G.UnitIsWildBattlePet(unit) ) then
		local enemyType = _G.UnitBattlePetType(unit);
		
		_G[self:GetName().."TextLeft2"]:SetText(_G[self:GetName().."TextLeft2"]:GetText().." "..PT:GetPetTypeIcon(enemyType, 18, 0, 2));
		
			for i = 1, PT.maxActive do
				local petID, _, _, _, locked = _G.C_PetJournal.GetPetLoadOutInfo(i);
				
				if( not locked and petID > 0 ) then
					local speciesID, customName, lvl, xp, maxXP, displayID, petName, petIcon, petType, creatureID = _G.C_PetJournal.GetPetInfoByPetID(petID);
					
					petName = customName and customName.." (|cffffffff"..petName.."|r)" or petName;
					
					self:AddDoubleLine(
						-- column 1
						PT:GetPetTypeIcon(petType, 18).." "..petName,
						-- column 2
						PT:GetPetDamageModIcon(enemyType, petType, 18)
					);
				end
			end

	end
end

GameTooltip:HookScript("OnTooltipSetUnit", GameTooltip_hook);