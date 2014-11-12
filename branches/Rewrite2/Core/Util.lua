local AddonName, PT = ...;
local Util = PT:NewComponent("Util");

local Data = PT:GetComponent("Data");

-------------------------------------------------------------
-- Some utility functions
-------------------------------------------------------------

function Util:FillAuraStates(side, pet, t, noWipe)
	_G.wipe(t);
	
	local num = _G.C_PetBattles.GetNumAuras(side, pet);
	
	for i = 1, num do
		local aura = _G.C_PetBattles.GetAuraInfo(side, pet, i);
		
		if( Data:HasAuraStates(aura) ) then
			for k, v in pairs(Data:GetAuraStates(aura)) do
				t[k] = v;
			end
		end
	end
end

function Util:GetQualityColorTable(quality)
	return _G.ITEM_QUALITY_COLORS[quality] or {r = 1, g = 1, b = 1};
end