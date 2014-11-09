local AddonName, PT = ...;
if( not PT.DEBUG ) then return end -- only load in debug mode

local Dev, Const = PT:GetComponent("Dev", "Const");

Dev.AbilityMods = {};
Dev.AuraStates = {};

-- our print function
local print = function(...) print("|cffff0000[PT_Dev]|r", ...) end
local deli = function() print("-----------------------------------------------------------") end

-------------------------------------------------------------
-- Ability Mod Scanner
-------------------------------------------------------------

function Dev:ScanAbilityMods()
	-- we need the ability table
	if( not self._scanned ) then self:ScanAbility() end
	
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
					self.AbilityMods[a.id] = targetState;
				end
			end
		end
	end
	
	-- save to database
	_G.PokemonTrainer_Developer = _G.PokemonTrainer_Developer or {};
	_G.PokemonTrainer_Developer.AbilityMods = self.AbilityMods;
end

-------------------------------------------------------------
-- Aura State Scanner
-------------------------------------------------------------

function Dev:ScanAuraStates()
	-- we need the ability table
	if( not self._scanned ) then self:ScanAbility() end
	
	wipe(self.AuraStates);
	
	-- scans for abilities which do more damage on a specific state
	for _, a in ipairs(self.Ability) do
		-- has this ability state modifications?
		if( type(a.stateMods) == "table" ) then
			self.AuraStates[a.id] = self.AuraStates[a.id] or {};
			
			for k, t in pairs(a.stateMods) do
				self.AuraStates[a.id][t.state] = t.value;
			end
		end
	end
	
	-- save to database
	_G.PokemonTrainer_Developer = _G.PokemonTrainer_Developer or {};
	_G.PokemonTrainer_Developer.AuraStates = self.AuraStates;
end