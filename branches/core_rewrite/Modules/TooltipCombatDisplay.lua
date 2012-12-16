-----------------------------------
-- Setting up scope, upvalues and libs
-----------------------------------

local AddonName, PT = ...;
local module = PT:NewModule("TooltipCombatDisplay");

local L = LibStub("AceLocale-3.0"):GetLocale(AddonName);

local _G = _G;

----------------------
-- Variables
----------------------

module.order = 2;
module.displayName = function() return (module:IsEnabled() and "|cff00ff00%s|r" or "|cffff0000%s|r"):format(L["Display: Tooltip"]) end
module.desc = L["LibQTip based combat display for Pet Battles. Disable it if you want to use the frame based combat display."];
module.noEnableButton = true;

-------------------------
-- Module Handling
-------------------------

function module:OnInitialize()
	self.db = PT.db:RegisterNamespace("TooltipCombatDisplay", {
		profile = {
			
		},
	});

	if( PT.db.profile.activeBattleDisplay ~= 2 ) then
		self:SetEnabledState(false);
	end
end

function module:OnEnable()
	
end

function module:OnDisable()
	
end



-- Start hacking here :D



----------------------
-- Option Table
----------------------

function module:GetOptions()
	return {
		
	};
end