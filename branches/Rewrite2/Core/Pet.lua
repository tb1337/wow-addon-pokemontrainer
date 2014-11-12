local AddonName, PT = ...;
local Pet = PT:NewClass("Pet", PT.BaseClass);
PT.PetClass = Pet;

local Const, Battle, Util = PT:GetComponent("Const", "Battle", "Util");

-------------------------------------------------------------
-- Pet related functions
-------------------------------------------------------------

function Pet:GetSpecies()
	return self.species;
end

function Pet:GetName()
	return self.name;
end

function Pet:GetIcon()
	return self.icon;
end

function Pet:GetType()
	return self.type;
end

function Pet:GetTypePassive()
	return Const:GetTypePassive(self:GetType());
end

function Pet:GetModel()
	return self.model;
end

function Pet:GetLevel()
	if( self.level ) then
		return self.level;
	end
	return _G.C_PetBattles.GetLevel( self:GetSide(), self:GetSlot() );
end

function Pet:GetName()
	if( self.name ) then
		return self.name;
	end
	return _G.C_PetBattles.GetName( self:GetSide(), self:GetSlot() );
end

function Pet:GetPower()
	return _G.C_PetBattles.GetPower( self:GetSide(), self:GetSlot() );
end

function Pet:GetSpeed()
	return _G.C_PetBattles.GetSpeed( self:GetSide(), self:GetSlot() );
end

function Pet:GetQuality()
	if( self.quality ) then
		return self.quality;
	end
	-- returns pet breed quality - 1, because the API returns item color quality + 1
	return _G.C_PetBattles.GetBreedQuality( self:GetSide(), self:GetSlot() ) - 1;
end

function Pet:GetHealth()
	return _G.C_PetBattles.GetHealth( self:GetSide(), self:GetSlot() );
end

function Pet:GetMaxHealth()
	return _G.C_PetBattles.GetMaxHealth( self:GetSide(), self:GetSlot() );
end

function Pet:GetBaseMaxHealth()
	return self.maxHealth;
end

function Pet:IsDead()
	return self:GetHealth() < 1;
end

-------------------------------------------------------------
-- Ability related functions
-------------------------------------------------------------

do
	-- little helper func
	local function calculate_num_ability(side, pet)
		local num = 0;
		
		for i = Const.ABILITY_MIN, Const.ABILITY_MAX do
			if( _G.C_PetBattles.GetAbilityInfo(side, pet, i) ) then
				num = num + 1;
			end
		end
		
		return num;
	end
	
	function Pet:GetNumAbility()
		-- no ability number set, at first we need to fetch it ourselves
		if( not self.numAbility ) then
			local level = self:GetLevel();
			
			-- player abilities are calculated by pet level, its very static
			if( self:IsPlayer() or Battle:IsPVP() ) then
				return level >= 4 and 3 or level > 1 and 2 or 1;
			else
			-- npc abilities must be queries with our helper func
				return calculate_num_ability( self:GetSide(), self:GetSlot() );
			end
		end
		
		return self.numAbility;
	end
end

function Pet:GetAbilityStealth()
	return self.abilityStealth == true;
end

function Pet:GetStealthedAbility(slot)
	-- must return nil unless we have stealthed abilitys
	if( not self:GetAbilityStealth() ) then
		return;
	end
	
	return self.abilityTable[slot], self.abilityLevels[slot];
end

-------------------------------------------------------------
-- Event related functions
-------------------------------------------------------------

PT:RegisterEvent("BattleInitAbilityData", nil, true);

function Pet:BattleInitPetData(side, numPets)	
	-- do not load wrong side
	if(	side ~= self:GetSide() ) then return end
	
	-- do not load too much pet info and, if needed, hide unnecessary frames
	if( numPets < self:GetSlot() ) then
		self:UpdateEnemyFrames();
		self:GetFrame():Hide();
		return;
	else
		self:GetFrame():Show();
	end
	
	-- begin gather pet data
	self.species = _G.C_PetBattles.GetPetSpeciesID( self:GetSide(), self:GetSlot() );
	
	-- request info from the journal about our pet species
	local speciesName, speciesIcon, petType, _, _, _, _, _, _, _, _, displayID = _G.C_PetJournal.GetPetInfoBySpeciesID(self:GetSpecies());
	local actualName = self:GetName();
	
	self.name = speciesName ~= actualName and actualName or speciesName;
	self.icon = speciesIcon;
	self.type = petType;
	self.model = displayID;
	
	self.level = self:GetLevel();
	self.quality = self:GetQuality();
	self.maxHealth = self:GetMaxHealth(); -- initial health without buffs
	
	self.states = self.states or {}; -- pet related states
	
	-- setup ability data
	self.numAbility = self:GetNumAbility();
	
	-- in pvp battles, we don't know which enemy abilities are slotted, so we need to initialize more data on the enemy pet
	if( self:IsEnemy() and true ) then --Battle:IsPVP() ) then
		self.abilityStealth = true;
		
		-- no table caching since we're not making thousands of pvp duels a second
		self.abilityTable = {};
		self.abilityLevels = {};
		
		-- this table does attach an ability to its real slot when it becomes known by PT
		self.abilityBattleSlot = {
			[1] = 1,
			[2] = 2,
			[3] = 3,
			[4] = 4,
			[5] = 5,
			[6] = 6
		};
		
		_G.C_PetJournal.GetPetAbilityList(self:GetSpecies(), self.abilityTable, self.abilityLevels);
	end
	
	PT:FireEvent("BattleInitAbilityData", self:GetSide(), self:GetSlot(), self:GetNumAbility(), self:GetAbilityStealth());
	
	-- our pet class has loaded data!
	self._loaded = true;
	self:UpdateAll();
end

function Pet:BattleClose()
	-- this data shall not persist between battles
	self.species = nil;
	self.name = nil;
	self.icon = nil;
	self.type = nil;
	self.model = nil;
	self.level = nil;
	self.quality = nil;
	self.maxHealth = nil;
	
	self.numAbility = nil;
	self.abilityStealth = nil;
	self.abilityTable = nil;
	self.abilityLevels = nil;
	self.abilityBattleSlot = nil;
	
	self._loaded = nil;
end

function Pet:BattleHealthChanged(side, pet)
	-- don't handle event when this isn't the changed pet
	if( self:GetSide() ~= side or self:GetSlot() ~= pet ) then return end
	
	self:UpdateHealth();
end

function Pet:BattleMaxHealthChanged(side, pet)
	-- don't handle event when this isn't the changed pet
	if( self:GetSide() ~= side or self:GetSlot() ~= pet ) then return end
	
	self:UpdateHealth();
end

function Pet:BattlePetAuraChange(side, pet)
	-- don't handle event when this isn't the changed pet
	if( self:GetSide() ~= side or self:GetSlot() ~= pet ) then return end
	
	Util:FillAuraStates(side, pet, self.states);
end

-------------------------------------------------------------
-- Class related functions
-------------------------------------------------------------

function Pet:initialize(className, trainer, slot)
	self.trainer = trainer;
	self.slot = slot;
	
	-- also init super class
	self.class.super.initialize(self, className);
end

function Pet:SetAbility(slot, abilityClass)
	self["Ability"..slot] = abilityClass;
end

function Pet:GetAbility(slot)
	if( self:GetAbilityStealth() ) then
		return self["Ability"..self.abilityBattleSlot[slot]];
	end
	return self["Ability"..slot];
end

function Pet:HasData()
	return self._loaded;
end

function Pet:GetSlot()
	return self.slot;
end

function Pet:GetTrainer()
	return self.trainer;
end

-- shortcuts
function Pet:GetSide()
	return self:GetTrainer():GetSide();
end

function Pet:IsPlayer()
	return self:GetTrainer():IsPlayer();
end

function Pet:IsEnemy()
	return self:GetTrainer():IsEnemy();
end