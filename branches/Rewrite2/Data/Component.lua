local AddonName, PT = ...;
local Data = PT:NewComponent("Data");

-------------------------------------------------------------
-- Aura States
-------------------------------------------------------------

function Data:HasAuraStates(aura)
	return self.AuraStates[aura] and true or false;
end

function Data:GetAuraStates(aura)
	return self.AuraStates[aura];
end