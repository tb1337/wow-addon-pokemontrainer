local AddonName, PT = ...;
local Const = PT:NewComponent("Const");

-------------------------------------------------------------
-- Variables
-------------------------------------------------------------

Const.PAD_INDEX = _G.PET_BATTLE_PAD_INDEX;

Const.PET_INDEX = 1;
Const.PET_MAX   = _G.NUM_BATTLE_PETS_IN_BATTLE;

Const.PET_LEVEL_MAX = 25;
Const.ABILITY_MIN   = 1;
Const.ABILITY_MAX   = _G.NUM_BATTLE_PET_ABILITIES;
Const.ABILITY_ALL   = 6;

Const.PLAYER  = _G.LE_BATTLE_PET_ALLY;
Const.ENEMY   = _G.LE_BATTLE_PET_ENEMY;
Const.WEATHER = _G.LE_BATTLE_PET_WEATHER;

-- bonus related
Const.BONUS_LOWER  = 0;
Const.BONUS_EQUAL  = 1;
Const.BONUS_BETTER = 2;

-- strong weak images
Const.BONUS_IMAGES = {
	[Const.BONUS_LOWER]  = "Interface\\PetBattles\\BattleBar-AbilityBadge-Weak",
	[Const.BONUS_EQUAL]  = "Interface\\PetBattles\\BattleBar-AbilityBadge-Neutral",
	[Const.BONUS_BETTER] = "Interface\\PetBattles\\BattleBar-AbilityBadge-Strong"
};

-- pet types
Const.PET_TYPES = _G.PET_TYPE_SUFFIX;
for i = 1, #Const.PET_TYPES do
	Const[ "PET_TYPE_"..Const.PET_TYPES[i]:upper() ] = i;
end

Const.PET_TYPE_PASSIVES = _G.PET_BATTLE_PET_TYPE_PASSIVES;

-- combat event types
do
	local events = {"APPLY", "DAMAGE_TAKEN", "DAMAGE_DEALT", "HEAL_TAKEN",
									"HEAL_DEALT", "AURA_REMOVED", "ROUND_START", "ROUND_END",
									"TURN", "ABILITY", "SWAP_IN", "SWAP_OUT"};
									
	for i, v in ipairs(events) do
		Const["EVENT_"..v] = _G["PET_BATTLE_EVENT_ON_"..v];
	end
	
	Const.EVENTS_MIN = 0;
	Const.EVENTS_MAX = #events - 1;
end

-------------------------------------------------------------
-- Functions
-------------------------------------------------------------

function Const:GetWeatherState(auraID)
	return self.WEATHER_STATES[auraID];
end

function Const:IsWeather(trainer, pet)
	return trainer == self.WEATHER and pet == self.PAD_INDEX;
end

function Const:GetTypeIcon(type)
	return "Interface\\PetBattles\\PetIcon-"..self.PET_TYPES[type];
end

function Const:GetTypePassive(type)
	return self.PET_TYPE_PASSIVES[type];
end

-------------------------------------------------------------
-- Events
-------------------------------------------------------------

function Const:ComponentInit()
	-- request state values
	for stateName, stateValue in pairs(_G.C_PetBattles.GetAllStates()) do
		Const[ stateName:upper() ] = stateValue;
		
		-- when debugging, we also need state value to name translation
		if( PT.DEBUG ) then
			Const.STATES = Const.STATES or {};
			Const.STATES[stateValue] = stateName:upper();
		end
	end
	
	-- query effect names only in debug mode
	if( PT.DEBUG ) then
		Const.EFFECTS = {_G.C_PetBattles.GetAllEffectNames()};
	end
	
	Const.WEATHER_STATES = {
		[590] = Const.STATE_WEATHER_ARCANESTORM,
		[205] = Const.STATE_WEATHER_BLIZZARD,
		[171] = Const.STATE_WEATHER_BURNTEARTH,
		[257] = Const.STATE_WEATHER_DARKNESS,
		[203] = Const.STATE_WEATHER_STATICFIELD,
		[596] = Const.STATE_WEATHER_MOONLIGHT,
		[718] = Const.STATE_WEATHER_MUD,
		[229] = Const.STATE_WEATHER_RAIN,
		[454] = Const.STATE_WEATHER_SANDSTORM,
		[403] = Const.STATE_WEATHER_SUNLIGHT,
		[63]  = Const.STATE_WEATHER_WINDY,
		[235] = Const.STATE_WEATHER_RAIN
	};
end