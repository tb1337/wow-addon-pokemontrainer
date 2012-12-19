-----------------------------------
-- Setting up scope, upvalues and libs
-----------------------------------

local AddonName = ...;
local PT = LibStub("AceAddon-3.0"):NewAddon(select(2, ...), AddonName, "AceEvent-3.0", "AceTimer-3.0");

local L = LibStub("AceLocale-3.0"):GetLocale(AddonName);

local _G = _G;

_G.PT = PT;

-------------------------------
-- Registering with iLib
-------------------------------

LibStub("iLib"):Register(AddonName);

----------------------
-- Variables
----------------------

PT.PlayerInfo = {};
PT.EnemyInfo  = {};

PT.PLAYER = _G.LE_BATTLE_PET_ALLY;
PT.ENEMY  = _G.LE_BATTLE_PET_ENEMY;

PT.MAX_COMBAT_PETS = 3;
PT.MAX_PET_ABILITY = 3;

PT.BONUS_SPEED_FASTER = 2;
PT.BONUS_SPEED_EQUAL  = 1;
PT.BONUS_SPEED_SLOWER = 0;

local pets_scanned = false; -- Currently not sure if we ever need this. true when initially scanned the pets, false if not. resetted in PT:PetBattleStop

------------------
-- Boot
------------------

function PT:OnInitialize()
	self.db = LibStub("AceDB-3.0"):New("PokemonTrainerDB", { profile = { activeBattleDisplay = 1 } }, "Default");
	
	-- We require the PetJournal for many API functions
	if( not _G.IsAddOnLoaded("Blizzard_PetJournal") ) then
		_G.LoadAddOn("Blizzard_PetJournal");
	end
end

function PT:OnEnable()
	LibStub("AceConfig-3.0"):RegisterOptionsTable(AddonName, PT.OpenOptions);
	LibStub("AceConfigDialog-3.0"):AddToBlizOptions(AddonName);
	
	_G.SlashCmdList["PT"] = function() _G.InterfaceOptionsFrame_OpenToCategory(AddonName); end
	_G["SLASH_PT1"] = "/pt";
	
	-- for the skill frames
	--self:RegisterEvent("PET_BATTLE_OPENING_START", "ScanPets");
	--self:RegisterEvent("PET_BATTLE_CLOSE", "PetBattleStop");
	--self:RegisterEvent("PET_BATTLE_PET_CHANGED", "PetBattleChanged");
	--self:RegisterEvent("PET_BATTLE_PET_ROUND_PLAYBACK_COMPLETE", "PetBattleRoundUp");
	self:RegisterEvent("PET_BATTLE_OVER", "PetBattleStop");
end

-------------------------
-- Event Callbacks
-------------------------

function PT:PetBattleStop()
	pets_scanned = false;
end

---------------------------
-- Compare Functions
---------------------------

-- RETURN
-- float number which acts as a percentage
function PT:GetTypeBonus(petType, enemyType, noStrongWeak)
	if( not petType or not enemyType or noStrongWeak ) then
		return 1; -- in this case 0 bonuses
	end
	
	assert(type(petType) == "number");
	assert(type(enemyType) == "number");
	
	return _G.C_PetBattles.GetAttackModifier(petType, enemyType) or 1;
end

-- RETURN
-- Texture Path
function PT:GetTypeBonusIcon(petType, enemyType, noStrongWeak)
	local modifier = petType; -- if the second arg is nil, this method treats petType as the modifier to prevent double calling :GetTypeBonus
	
	if( enemyType ) then
		modifier = self:GetTypeBonus(petType, enemyType, noStrongWeak);
	end
	
	assert(type(modifier) == "number");
	
	if( modifier > 1 ) then
		return "Interface\\PetBattles\\BattleBar-AbilityBadge-Strong";
	elseif( modifier < 1 ) then
		return "Interface\\PetBattles\\BattleBar-AbilityBadge-Weak";
	else
		return "Interface\\PetBattles\\BattleBar-AbilityBadge-Neutral";
	end
end

-- RETURN
-- Texture path
function PT:GetTypeIcon(petType)
	assert(type(petType) == "number");
	return _G.GetPetTypeTexture(petType);
end

-- RETURN
-- result:		number which is matching to one PT.BONUS_SPEED_... constants
-- better_with_flying: bool		if the pet is flying and no active speed bonus, would it be faster than pet2 if the bonus was active?
function PT:GetSpeedBonus(pet1, pet2)
	local better_with_flying = false;
	
	assert(type(pet1) == "table");
	assert(type(pet2) == "table");
	
	-- Flying pets get a speed bonus, if their HP is above 50%
	if( _G.PET_TYPE_SUFFIX[pet1.type] == "Flying" ) then
		better_with_flying = not(pet1.hpP >= 0.5) and ((pet1.speed * 1.5) >= pet2.speed) or false;
	end
	
	local result = (pet1.speed > pet2.speed) and PT.BONUS_SPEED_FASTER or (pet2.speed > pet1.speed) and PT.BONUS_SPEED_SLOWER or PT.BONUS_SPEED_EQUAL;
	
	return result, better_with_flying;
end

-- RETURN
-- r, g, b:		self-explaining
function PT:GetDifficultyColor(pet1, pet2)
	if( type(pet1) == "table" ) then
		pet1 = pet1.level;
	end
	if( type(pet2) == "table" ) then
		pet2 = pet2.level;
	end

	assert(type(pet1) == "number");
	assert(type(pet2) == "number");
	
	-- at this point, we use the zone coloring provided by LibTourist, because it's Blizz-like
	-- let Tourist do the math, we return the results :)
	-- if the enemy pet is level 15, our "fake" zone is 15-15
	local r, g, b = LibStub("LibTourist-3.0"):CalculateLevelColor(pet2, pet2, pet1);
	return r, g, b;
end

-- RETURN
-- available:	bool
-- cdleft:		number
function PT:GetAbilityCooldown(side, pet, ab)
	assert(type(side) == "number");
	assert(type(pet)  == "number");
	assert(type(ab)   == "number");

	local available, cdleft = _G.C_PetBattles.GetAbilityState(side, pet, ab);
	
	-- the API returns available = true/false and cdleft = 0/>0, but we want to make sure that this will actually happen
	available = not(cdleft and cdleft > 0);
	cdleft = available and 0 or cdleft;
	
	return available, cdleft;
end

----------------------------------
-- Scanning Pets for Combat
----------------------------------

local scan_pets, roundup_pets;
do
	-- wipes all keys/values and subtable keys/values, but not the subtables themselves
	local function wipe_pets(t)
		for k,v in pairs(t) do
			if( type(v) == 'table' ) then
				for i = 1, #v do
					v[i] = nil
				end
				v[''] = 1
				v[''] = nil
			else
				t[k] = nil
			end
		end
		t[''] = 1
		t[''] = nil
	end
	
	-- enables new table keys whose data isn't directly saved in the table
	local mt = {
		__index = function(t, k)
			if( k == "dead" ) then
				return t.hp <= 0;
			elseif( k == "hpP" ) then
				return t.hp / t.hpM;
			end
		end,
	};
	
	scan_pets = function(side, t)
		wipe_pets(t);
		
		local numPets = _G.C_PetBattles.GetNumPets(side);
		local activePet = _G.C_PetBattles.GetActivePet(side);
		
		local species, speciesName, petIcon, petType;
		local petLevel, petName, petSpeed, petQuality, petHP, petMaxHP;
		local numAbilities;
		
		t.numPets = numPets;
		t.activePet = activePet;
		
		for pet = 1, numPets do
			species = _G.C_PetBattles.GetPetSpeciesID(side, pet);
			speciesName, petIcon, petType = _G.C_PetJournal.GetPetInfoBySpeciesID(species);
			
			petLevel = _G.C_PetBattles.GetLevel(side, pet);
			petName = _G.C_PetBattles.GetName(side, pet);
			petSpeed = _G.C_PetBattles.GetSpeed(side, pet);
			petQuality = _G.C_PetBattles.GetBreedQuality(side, pet);
			
			petHP = _G.C_PetBattles.GetHealth(side, pet);
			petMaxHP = _G.C_PetBattles.GetMaxHealth(side, pet);
			
			numAbilities = petLevel >= 4 and 3 or petLevel >= 2 and 2 or 1;
			
			-- the t[pet] tables will be reused even after wipe_pets() got executed, the garbagecollector doesn't get something to eat *sob*
			if( not t[pet] or not(type(t[pet]) == "table") ) then
				t[pet] = {};
				setmetatable(t[pet], mt);
			end
			
			--t[pet].side = side;
			--t[pet].index = pet;
			t[pet].name = petName;
			t[pet].level = petLevel;
			t[pet].species = species;
			t[pet].type = petType;
			t[pet].speed = petSpeed;
			t[pet].icon = petIcon;
			t[pet].quality = petQuality - 1; -- little hack, the API returns (actual_pet_quality + 1) -.-
			t[pet].hp = petHP;
			t[pet].hpM = petMaxHP;
			t[pet].numAbilities = numAbilities;
			
			for ab = 1, numAbilities do
				t[pet]["ab"..ab] = _G.C_PetBattles.GetAbilityInfo(side, pet, ab); -- ability id
			end
		end
	end
	
	-- I decided to create a roundup function to get rid off too many scan_pets() calls
	-- For each battle round there is little updated data: speed and current hp (excepting buffs/debuffs)
	roundup_pets = function(side, t)
		local numPets = _G.C_PetBattles.GetNumPets(side);
		local activePet = _G.C_PetBattles.GetActivePet(side);
		
		local petSpeed, petHP, petMaxHP;
		
		t.numPets = numPets; -- weird, usually the number of pets shouldn't change during battles. :D
		t.activePet = activePet;
		
		for pet = 1, numPets do
			petSpeed = _G.C_PetBattles.GetSpeed(side, pet);
			petHP = _G.C_PetBattles.GetHealth(side, pet);
			
			t[pet].speed = petSpeed;
			t[pet].hp = petHP;
		end
	end
end

function PT:ScanPets()
	scan_pets(PT.PLAYER, self.PlayerInfo);
	scan_pets(PT.ENEMY , self.EnemyInfo);
	pets_scanned = true;
end

function PT:RoundUpPets()
	roundup_pets(PT.PLAYER, self.PlayerInfo);
	roundup_pets(PT.ENEMY , self.EnemyInfo);
end

-----------------------------
-- Configuration stuff
-----------------------------

local options;
function PT:OpenOptions()
	options = {
		name = L["Pokemon Trainer Options"].."    "..(PT.dev and "|cffff0000Developer Version|r" or "|cffffffffv".._G.GetAddOnMetadata(AddonName, "Version").."|r"),
		type = "group",
		args = {
			display = {
				type = "select",
				name = L["Preferred combat display"],
				order = 1,
				get = function()
					return PT.db.profile.activeBattleDisplay;
				end,
				set = function(_, value)
					if( value == 2 ) then
						PT:GetModule("FrameCombatDisplay"):Disable();
						PT:GetModule("TooltipCombatDisplay"):Enable();
					else
						PT:GetModule("FrameCombatDisplay"):Enable();
						PT:GetModule("TooltipCombatDisplay"):Disable();
					end
					PT.db.profile.activeBattleDisplay = value;
				end,
				values = {
					[1] = L["Display: Frames"],
					[2] = L["Display: Tooltip"],
				},
				disabled = _G.C_PetBattles.IsInBattle,
			},
			spacer = { type = "description", name = " ", order = 50 },
		},
	};
	
	-- This code snippet is written by ckknight and the Chinchilla team
	-- It is great and fits our needs, so we do not re-invent the wheel
	local t;
	for key, module in PT:IterateModules() do
		t = module.GetOptions and module:GetOptions() or {};
		
		for option, args in pairs(t) do
			if( type(args.disabled) == "nil" ) then
				args.disabled = function() return not module:IsEnabled(); end
			end
		end
		
		if( not module.noEnableButton ) then
			t.enabled = {
				type = "toggle",
				name = L["Enable"],
				desc = L["Enable this module."],
				get = function()
					return module:IsEnabled();
				end,
				set = function(_, value)
					module.db.profile.enabled = not not value; -- to ensure a boolean
					
					if value then
						return module:Enable();
					else
						return module:Disable();
					end
				end,
				order = 0,
				width = "full",
			};
			t.spacer = { type = "description", name = " ", order = 0.1 }; -- spacer between the Enable toggle button and the acual options
		end
		
		options.args[key] = { type = "group", name = module.displayName, desc = module.desc, handler = module, order = module.order or -1, args = t }
	end
	
	PT.OpenOptions = nil; -- this function is needed once and gets deleted
	return options;
end