local AddonName, PT = ...;
if( not PT.DEBUG ) then return end -- only load in debug mode

local Dev, Const = PT:GetComponent("Dev", "Const");

Dev.AbilityMods = {};

-- our print function
local print = function(...) print("|cffff0000[PT_Dev]|r", ...) end
local deli = function() print("-----------------------------------------------------------") end

-------------------------------------------------------------
-- Ability Mod Scanner
-------------------------------------------------------------

function Dev:ScanAbilityMods()
	self.Ability = self.Ability or _G.PokemonTrainer_Developer;
	
	-- we need the ability table
	if( not self.Ability ) then return end
	
	wipe(self.AbilityMods);
	
	-- scans for abilities which do more damage on a specific state
	for _, a in ipairs(self.Ability) do
		-- has this ability effects on turn 1?		
		if( a.effects and a.effects[1] ) then
			local turn = a.effects[1];
			
			-- has this ability effects if the enemy pet takes damage?
			if( turn.EVENT_DAMAGE_DEALT ) then
				local targetState = turn.EVENT_DAMAGE_DEALT.requiredtargetstate;
				
				if( targetState and targetState > 0 ) then
					print("|cffffff00", a.name, "|r", "bonus damage on", Const.STATES[targetState]);
				end
			end
		end
	end
end