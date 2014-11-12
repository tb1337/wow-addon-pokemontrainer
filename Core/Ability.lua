local AddonName, PT = ...;
local Ability = PT:NewClass("Ability", PT.BaseClass);
PT.AbilityClass = Ability;

local Const, Battle = PT:GetComponent("Const", "Battle");

-------------------------------------------------------------
-- Ability related functions
-------------------------------------------------------------

function Ability:GetName()
	return self.name;
end

function Ability:GetIcon()
	return self.icon;
end

function Ability:GetMaxCooldown()
	return self.maxCD;
end

function Ability:GetNumTurns()
	return self.numTurns;
end

function Ability:GetType()
	return self.type;
end

function Ability:HasStrongWeakHints()
	return self.noHints == false; -- toggle actual value
end

-------------------------------------------------------------
-- Event related functions
-------------------------------------------------------------

function Ability:BattleInitAbilityData(side, pet, numAbility, stealth)
	-- do not load wrong side or pet or too much ability data
	if( (side ~= self:GetPet():GetSide() ) or
			( pet ~= self:GetPet():GetSlot() ) or
			(not stealth and numAbility < self:GetSlot() )
	) then return end
	
	-- do not load wrong side or wrong pet
	if(	side ~= self:GetSide() or pet ~= self:GetPet():GetSlot() ) then return end
	
	-- do not load too much ability info and, if needed, hide unnecessary frames
	if( not stealth and numAbility < self:GetSlot() ) then
		self:GetFrame():Hide();
		return;
	else
		self:GetFrame():Show();
	end
	
	local id, name, icon, maxCooldown, _, numTurns, petType, noHints;
	local slot = self:GetSlot();
	
	-- do we have ability stealth?
	if( stealth ) then
		local stealthID, stealthLevel = self:GetStealthedAbility();
		id, name, icon, maxCooldown, _, numTurns, petType, noHints = _G.C_PetBattles.GetAbilityInfoByID(stealthID, stealthLevel);
		
		-- the pet level is too low for this ability
		if( self:GetPet():GetLevel() < stealthLevel ) then
			self.locked = true;
		end
	else
		id, name, icon, maxCooldown, _, numTurns, petType, noHints = _G.C_PetBattles.GetAbilityInfo(side, pet, slot);
		
		-- apparently the pet level is too low for this ability
		if( not id ) then
			self.locked = true;
		end
	end
	
	self.id = id;
	self.name = name;
	self.icon = icon;
	self.maxCD = maxCooldown;
	self.numTurns = numTurns;
	self.type = petType;
	self.noHints = noHints;
	
	-- our ability has finally loaded data!
	self._loaded = true;
	self:UpdateAll();
end

function Ability:BattleClose()
	-- this data shall not persist between battles
	self.id = nil;
	self.name = nil;
	self.icon = nil;
	self.maxCD = nil;
	self.numTurns = nil;
	self.type = nil;
	self.noHints = nil;
	
	self.locked = nil;
	
	self._loaded = nil;
end

-------------------------------------------------------------
-- Class related functions
-------------------------------------------------------------

function Ability:initialize(className, pet, slot)
	self.pet = pet;
	self.slot = slot;
	
	-- also init super class
	self.class.super.initialize(self, className);
end

function Ability:GetTrainer()
	return self.pet.trainer;
end

function Ability:GetPet()
	return self.pet;
end

function Ability:GetSlot()
	return self.slot;
end

-- shortcuts
function Ability:GetSide()
	return self:GetTrainer():GetSide();
end

function Ability:GetStealthedAbility()
	return self:GetPet():GetStealthedAbility(self:GetSlot());
end