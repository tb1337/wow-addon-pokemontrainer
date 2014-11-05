local AddonName, PT = ...;
if( not PT.DEBUG ) then return end -- only load in debug mode

local Dev, Const = PT:GetComponent("Dev", "Const");

Dev.WeatherMods = {};

-- our print function
local print = function(...) print("|cffff0000[PT_Dev]|r", ...) end
local deli = function() print("-----------------------------------------------------------") end

-------------------------------------------------------------
-- Maximum Ability Scanner
-------------------------------------------------------------

function Dev:ScanWeatherMods()
	-- we need the ability table
	if( not self._scanned ) then self:ScanAbility() end
	
	wipe(self.WeatherMods);
	
	-- scans for weathers, which will boost abilitys by pet type
	for _, a in ipairs(self.Ability) do
		if( a.isAura ) then
			-- does this buff boost abilitys by its pet type?
			if( a.stateMods and a.stateMods.STATE_MOD_PETTYPE_ID ) then
				local petType = a.stateMods.STATE_MOD_PETTYPE_ID.value;
				
				print("|cffffff00", a.name, "|r", "boosts type", Const.PET_TYPES[petType])
				self.WeatherMods[a.id] = petType;
			end
		end
	end
	
	-- save to database
	_G.PokemonTrainer_Developer = _G.PokemonTrainer_Developer or {};
	_G.PokemonTrainer_Developer.WeatherMods = self.WeatherMods;
end