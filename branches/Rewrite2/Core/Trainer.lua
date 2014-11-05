local AddonName, PT = ...;
local Trainer = PT:NewClass("Trainer", PT.BaseClass);
PT.TrainerClass = Trainer;

local Const, Battle = PT:GetComponent("Const", "Battle");

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

-------------------------------------------------------------
-- Event related functions
-------------------------------------------------------------

PT:RegisterEvent("BattleInitPetData", nil, true);

function Trainer:BattleBeginStart()
	self.numPets = _G.C_PetBattles.GetNumPets(self:GetSide());
	self.activePet = _G.C_PetBattles.GetActivePet(self:GetSide());
	
	PT:FireEvent("BattleInitPetData", self:GetSide(), self:GetNumPets());
end

function Trainer:BattleClose()
	self.numPets = nil;
	self.activePet = nil;
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