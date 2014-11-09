local AddonName, PT = ...;
local Trainer = PT:NewClass("Trainer", PT.BaseClass);
PT.TrainerClass = Trainer;

local Const, Battle, Util = PT:GetComponent("Const", "Battle", "Util");

-------------------------------------------------------------
-- Trainer related functions
-------------------------------------------------------------

function Trainer:IsPlayer()
	return self.side == Const.PLAYER;
end

function Trainer:IsEnemy()
	return self.side == Const.ENEMY;
end

function Trainer:GetSide()
	return self.side;
end

function Trainer:GetNumPets()
	return self.numPets;
end

function Trainer:GetActivePet()
	return self:GetPet(self.activePet);
end

function Trainer:GetStates()
	return self.states;
end

-------------------------------------------------------------
-- Event related functions
-------------------------------------------------------------

PT:RegisterEvent("BattleInitPetData", nil, true);

function Trainer:BattleBeginStart()
	self.numPets = _G.C_PetBattles.GetNumPets(self:GetSide());
	self.activePet = _G.C_PetBattles.GetActivePet(self:GetSide());
	
	self.states = self.states or {}; -- setup "global" states, this data will be inherited by pet states
	
	PT:FireEvent("BattleInitPetData", self:GetSide(), self:GetNumPets());
end

function Trainer:BattleClose()
	self.numPets = nil;
	self.activePet = nil;
end

function Trainer:BattlePetAuraChange(side, pet)
	-- don't handle event when this isn't a global aura change for this trainer
	if( self:GetSide() ~= side or pet ~= Const.PAD_INDEX ) then return end
	
	Util:FillAuraStates(side, pet, self.states);
	
	-- fill in weather state manually
	if( Battle:HasWeather() ) then
		self.states[ Battle:GetWeatherState() ] = 1;
	end
end

-------------------------------------------------------------
-- Class related functions
-------------------------------------------------------------

function Trainer:initialize(className, side)
	self.side = side;
	
	-- also init super class
	self.class.super.initialize(self, className);
end

function Trainer:SetPet(slot, petClass)
	self["Pet"..slot] = petClass;
end

function Trainer:GetPet(slot)
	return self["Pet"..slot];
end