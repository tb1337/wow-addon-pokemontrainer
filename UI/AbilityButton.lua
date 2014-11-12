local AddonName, PT = ...;
local Ability = PT.AbilityClass;

local Const, Battle = PT:GetComponent("Const", "Battle");

-------------------------------------------------------------
-- Ability related functions
-------------------------------------------------------------

function Ability:UpdateAll()
	self:UpdateIcon();
end

function Ability:UpdateIcon()
	local button = self:GetFrame();
	
	button.Icon:SetTexture(self:GetIcon());
	button.Icon:SetTexCoord(0.078125, 0.921875, 0.078125, 0.921875); -- zoom out icon borders
end

-------------------------------------------------------------
-- Frame related functions
-------------------------------------------------------------

function Ability:GetFrame()
	return self.Frame;
end