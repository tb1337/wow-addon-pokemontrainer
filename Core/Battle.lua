local AddonName, PT = ...;
local Battle = PT:NewComponent("Battle");

local Const = PT:GetComponent("Const");

-------------------------------------------------------------
-- Battle state functions
-------------------------------------------------------------

function Battle:IsActive()
	return self.inBattle;
end

function Battle:GetRound()
	return self.currentRound;
end

function Battle:IsWild()
	return _G.C_PetBattles.IsWildBattle();
end

function Battle:IsPVP()
	return not self:IsWild() and not _G.C_PetBattles.IsPlayerNPC(Const.ENEMY);
end

function Battle:IsTrainer()
	return not self:IsWild() and not self:IsPVP();
end

-------------------------------------------------------------
-- Battle trainer data functions
-------------------------------------------------------------

-- there are frame display errors going to be happen if only one trainer has loaded data.
-- we need to track if both trainers data is ready and then fire the pet event in Trainer.lua

function Battle:TrainerLoad()
	if( self.bothTrainersLoaded ) then
		self.bothTrainersLoaded = self.bothTrainersLoaded + 1;
	else
		self.bothTrainersLoaded = 1;
	end
end

function Battle:TrainersLoaded()
	return self.bothTrainersLoaded and self.bothTrainersLoaded >= 2 or false;
end

-------------------------------------------------------------
-- Weather state functions
-------------------------------------------------------------

function Battle:HasWeather()
	return type(self.weatherAura) ~= "nil";
end

function Battle:GetWeatherAura()
	return self.weatherAura;
end

function Battle:GetWeatherState()
	return self.weatherState;
end

-------------------------------------------------------------
-- Aura Handler
-------------------------------------------------------------

PT:RegisterEvent("BattleWeatherChange", nil, true);
PT:RegisterEvent("BattlePetAuraChange", nil, true);
PT:RegisterEvent("BattlePetAuraDataReady", nil, true);

function Battle:BattleAuraChangeHandler(trainer, pet)
	if( Const:IsWeather(trainer, pet) ) then
		-- we got a weather change
		local auraID = _G.C_PetBattles.GetAuraInfo(trainer, pet, 1);
		local stateID;
		
		if( auraID ) then
			stateID = Const:GetWeatherState(auraID);
			
			self.weatherAura = auraID;
			self.weatherState = stateID;
		else
			self.weatherAura = nil;
			self.weatherState = nil;
		end
		
		PT:FireEvent("BattleWeatherChange", auraID, stateID);
	else
		-- we only got a buff/debuff change
		PT:FireEvent("BattlePetAuraChange", trainer, pet);
		PT:FireEvent("BattlePetAuraDataReady");
	end
end

-------------------------------------------------------------
-- Events
-------------------------------------------------------------

function Battle:BattleBeginStart()
	self.inBattle = true;
	self.currentRound = 1;
end

function Battle:BattleOver()
	self.inBattle = false;
end

function Battle:BattleClose()
	self.weatherAura = nil;
	self.weatherState = nil;
	self.currentRound = nil;
	self.bothTrainersLoaded = nil;
end

function Battle:BattleRoundPlayback(num)
	self.currentRound = num + 1;
end

-------------------------------------------------------------
-- Trainer getter func
-------------------------------------------------------------

function Battle:GetTrainer(side)
	return PT["Trainer"..side];
end