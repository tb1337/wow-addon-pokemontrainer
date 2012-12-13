-----------------------------------
-- Setting up scope, upvalues and libs
-----------------------------------

local AddonName, PT = ...;
local module = PT:NewModule("WildPetTooltip", "AceEvent-3.0");

local L = LibStub("AceLocale-3.0"):GetLocale(AddonName);

local _G = _G;

----------------------
-- Variables
----------------------

-- O RLY? no vars? kk

-------------------------
-- Module Handling
-------------------------

function module:OnEnable()
	self:RegisterEvent("UPDATE_MOUSEOVER_UNIT", "ProcessTooltip");
end

function module:OnDisable()
	self:UnregisterEvent("UPDATE_MOUSEOVER_UNIT");
end

------------------------
-- Change Tooltip
------------------------

local function add_ability(petLevel, slot, ab, enemyType)
	if( slot > (petLevel >= 4 and 3 or petLevel >= 2 and 2 or 1) ) then
		return;
	end
	
	local _, abName, abIcon, _, _, _, abType, noStrongWeak = _G.C_PetBattles.GetAbilityInfoByID(ab);
	local icon = PT:GetTypeBonusIcon(abType, enemyType, noStrongWeak);
	
	_G.GameTooltip:AddDoubleLine(
		" |T"..abIcon..":14:14|t |cffffffff"..abName.."|r",
		"|T"..icon..":14:14|t"
	);
end

function module:ProcessTooltip()
	if( not PT.db.TooltipShowProsCons ) then
		return;
	end
	
	local name, unit = _G.GameTooltip:GetUnit();
	if( not unit or not _G.UnitIsWildBattlePet(unit) ) then
		return;
	end
	
	-- We require the PetJournal for many API functions
	if( not _G.IsAddOnLoaded("Blizzard_PetJournal") ) then
		_G.LoadAddOn("Blizzard_PetJournal");
	end
	
	local enemyType, enemyLevel = _G.UnitBattlePetType(unit), _G.UnitBattlePetLevel(unit)
	
	local petID, ab1, ab2, ab3, slotLocked;
	local _, customName, petLevel, petName, petType;
	local r, g, b;
	
	for pet = 1, PT.MAX_COMBAT_PETS do
		petID, ab1, ab2, ab3, slotLocked = _G.C_PetJournal.GetPetLoadOutInfo(pet);
		
		if( not slotLocked and petID ) then
			_, customName, petLevel, _, _, _, _, petName, _, petType = _G.C_PetJournal.GetPetInfoByPetID(petID);
			petName = customName and customName.." (|cffffffff"..petName.."|r)" or petName;
			
			_G.GameTooltip:AddLine(" ");
			
			-- Pet Type
			r, g, b = PT:GetDifficultyColor(petLevel, enemyLevel);
			
			_G.GameTooltip:AddDoubleLine(
				petName.."  "..("|cff%02x%02x%02x%s|r"):format(r *255, g *255, b *255, petLevel),
				"|T"..PT:GetTypeIcon(petType)..":14:14:0:0:128:256:62:102:128:169|t"
			);
			
			add_ability(petLevel, 1, ab1, enemyType);
			add_ability(petLevel, 2, ab2, enemyType);
			add_ability(petLevel, 3, ab3, enemyType);
		end
	end
	
	_G.GameTooltip:Show();
end