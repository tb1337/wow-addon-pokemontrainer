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
-- Weather state functions
-------------------------------------------------------------

function Battle:IsWeatherActive()
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
		PT:FireEvent("BattlePetAuraChange", owner, pet);
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
end

function Battle:BattleRoundPlayback(num)
	self.currentRound = num + 1;
end