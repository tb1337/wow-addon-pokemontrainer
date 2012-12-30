--@do-not-package@

local AddonName, PT = ...;
local _G = _G;

local module = PT:NewModule("_Data");

function module:OnInitialize()
	self:SetEnabledState(false); -- will be loaded from FrameCombatDisplay
end

module.aurastates = {};

function module:OnEnable()
	PT.DATALOADED = true;

	
end

--@end-do-not-package@