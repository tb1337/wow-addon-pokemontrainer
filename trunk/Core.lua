-----------------------------------
-- Setting up scope, upvalues and libs
-----------------------------------

local AddonName = ...;
local PT = LibStub("AceAddon-3.0"):NewAddon(select(2, ...), AddonName, "AceEvent-3.0");

local L = LibStub("AceLocale-3.0"):GetLocale(AddonName);
local AceTimer = LibStub("AceTimer-3.0"); -- no need for embedding it
local LibBreed = LibStub("LibPetBreedInfo-1.0");

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

PT.PAD_INDEX = _G.PET_BATTLE_PAD_INDEX;
PT.PET_INDEX = 1;

PT.WEATHER= _G.LE_BATTLE_PET_WEATHER;	-- 0
PT.PLAYER = _G.LE_BATTLE_PET_ALLY;		-- 1
PT.ENEMY  = _G.LE_BATTLE_PET_ENEMY;		-- 2

PT.MAX_COMBAT_PETS = 3;
PT.MAX_PET_ABILITY = 3;

PT.BONUS_SPEED_FASTER = 2;
PT.BONUS_SPEED_EQUAL  = 1;
PT.BONUS_SPEED_SLOWER = 0;

PT.alpha = false; -- is this an alpha package?
--@alpha@
PT.alpha = true;
--@end-alpha@

--@do-not-package@
PT.developer = true;
--@end-do-not-package@

------------------
-- Boot
------------------

function PT:OnInitialize()
	self.db = LibStub("AceDB-3.0"):New("PokemonTrainerDB", { profile = { activeBattleDisplay = 1, version = "", alpha = false } }, "Default");
	
	-- We require the PetJournal for many API functions
	--if( not _G.IsAddOnLoaded("Blizzard_PetJournal") ) then
	--	_G.LoadAddOn("Blizzard_PetJournal");
	--end
end

function PT:OnEnable()
	LibStub("AceConfig-3.0"):RegisterOptionsTable(AddonName, PT.OpenOptions);
	LibStub("AceConfigDialog-3.0"):AddToBlizOptions(AddonName);
	
	_G.SlashCmdList["PT"] = function() _G.InterfaceOptionsFrame_OpenToCategory(AddonName); end
	_G["SLASH_PT1"] = "/pt";
	
	--self:RegisterEvent("PET_BATTLE_CLOSE", "PetBattleStop");
	
	-- version check and reminder that the user may want to check the options
	local msg;
	local version = tostring(_G.GetAddOnMetadata(AddonName, "Version"));
	if( self.db.profile.version ~= version ) then
		if( self.db.profile.version == "" ) then
			msg = "|cff00aaff"..AddonName.."|r: "..L["First run, you may wanna check /pt for options."];
		else
			msg = "|cff00aaff"..AddonName.."|r: "..L["Recently updated to version"].." "..version;
		end
		self.db.profile.alpha = true;
	end
	if( self.db.profile.alpha and PT.alpha and not PT.developer ) then
		self.db.profile.alpha = false;
		msg = "|cff00aaff"..AddonName.."|r: Running Alpha Package without being a developer, it could be unstable or erroneous. Feedback is appreciated. Please install at least a Beta Package if you do not want that at all.";
	end
	if( msg ) then
		self.db.profile.version = version;
		AceTimer.ScheduleTimer(self, function() print(msg) end, 15);
	end
end

-------------------------
-- Event Callbacks
-------------------------



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

-- COLORTABLE (comparision our level against enemy level)
-- Our table differs from the blizzard pet level zone coloring (WorldMapFrame.lua)
-- The reason is that we must play safe, that means Blizzards color table is weird while displaying pet battles.
-- If the enemys level would be 2 higher than yours, it said the enemy has normal difficulty while you have hard difficulty.
-- In my opinion, that is not right. My concept: normal<->normal, hard<->easy, easy<->hard, trivial<->very hard, very hard<->trivial
--					we								|		blizzard
-------------------------------------------------------------
--	> 9												|		trivial (grey)
--  > 4			trivial (grey)		|		
--	> 3												|		easy (green)
--	> 2			easy (green)			|		
--	> 1												|		normal (yellow)
--	==			normal (yellow)		|		
--	< 1												|		hard (orange)
--	< 2			hard (orange)			|		
--	< 3												|		very hard (red)
--	< 4			very hard (red)		|		
-------------------------------------------------------------
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
	
	if( (pet2 - pet1) <= -4 ) then
		pet2 = pet2 - 4; -- leaps over the big range of green difficulties and colors it trivial
	end
	
	local color;
	if( pet1 < pet2 ) then
		color = _G.GetRelativeDifficultyColor(pet1, pet2 + 1);
	elseif( pet1 > pet2 ) then
		color = _G.GetRelativeDifficultyColor(pet1 + 1, pet2);
	else
		color = _G.QuestDifficultyColors["difficult"];
	end
	
	return color.r, color.g, color.b;
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
	
	-- Curse comment #105
	-- overrides the state when a pet is currently sleeping, repairing etc. and cannot use abilities
	-- so we disable that way of handling CDs
	--  available = not(cdleft and cdleft > 0);
	--  cdleft = available and 0 or cdleft;
	
	-- back to the roots
	available = available == true;
	
	if( cdleft and cdleft > 0 ) then
		available = false;
	else
		cdleft = 0;
	end
	
	return available, cdleft;
end

--@do-not-package@
do	
	local effects = {_G.C_PetBattles.GetAllEffectNames()};
	
	local env = {};
	for i, effect in ipairs(effects) do
		env[effect] = function(abilityID, turnIndex, event)
			return _G.C_PetBattles.GetAbilityEffectInfo(abilityID, turnIndex, event, effects[i]) or 0;
		end;
	end
	
	local states = {};
	for stateName, stateID in pairs(_G.C_PetBattles.GetAllStates()) do
		stateName = stateName:sub(6, 0);
		states[stateName] = stateID;
		states[stateID] = stateName;
	end
	
	local EVENT_On_Apply, EVENT_On_Damage_Taken, EVENT_On_Damage_Dealt, EVENT_On_Heal_Taken, EVENT_On_Heal_Dealt, EVENT_On_Aura_Removed,
		EVENT_On_Round_Start, EVENT_On_Round_End, EVENT_On_Turn, EVENT_On_Ability, EVENT_On_Swap_In, EVENT_On_Swap_Out =
		_G.PET_BATTLE_EVENT_ON_APPLY, _G.PET_BATTLE_EVENT_ON_DAMAGE_TAKEN, _G.PET_BATTLE_EVENT_ON_DAMAGE_DEALT, _G.PET_BATTLE_EVENT_ON_HEAL_TALEN,
		_G.PET_BATTLE_EVENT_ON_HEAL_DEALT, _G.PET_BATTLE_EVENT_ON_AURA_REMOVED, _G.PET_BATTLE_EVENT_ON_ROUND_START, _G.PET_BATTLE_EVENT_ON_ROUND_END,
		_G.PET_BATTLE_EVENT_ON_TURN, _G.PET_BATTLE_EVENT_ON_ABILITY, _G.PET_BATTLE_EVENT_ON_SWAP_IN, _G.PET_BATTLE_EVENT_ON_SWAP_OUT;
	
	PT.effects, PT.events, PT.states, PT.env = effects, events, states, env;
	
	local glow = {};
	local function g(i,v) if not glow[i] then glow[i]=v elseif glow[i] and not v then else glow[i]=v end end
	
	function PT:GetStateBonuses(player, enemy)		
		local Data = PT:GetModule("_Data");
		local playerPet, enemyPet = player[player.activePet], enemy[enemy.activePet];
		
		glow[1], glow[2], glow[3] = false, false, false;
		
		-- We have a buff which leads us in dealing more damage
		-- So we check if an ability does damage and if yes, let it glow
		if( _G.C_PetBattles.GetStateValue(player.side, player.activePet, states.Mod_DamageDealtPercent) > 0 ) then
			for ab = 1, playerPet.numAbilities do
				g(ab, env.points(playerPet["ab"..ab], 1, EVENT_On_Damage_Taken) > 0);
			end
			return unpack(glow); -- we do not need the other checks anymore
		end
		
		-- Our enemy has a debuff which leads us in dealing more damage
		-- SO we check if an ability does damage and if yes, let it glow
		if( _G.C_PetBattles.GetStateValue(enemy.side, enemy.activePet, states.Mod_DamageTakenPercent) > 0 ) then
			for ab = 1, player.numAbilities do
				g(ab, env.points(playerPet["ab"..ab], 1, EVENT_On_Damage_Taken) > 0);
			end
			return unpack(glow); -- we do not need the other checks anymore
		end
		
		-- Looping through all current aura states and check if there are abilities that need one of that states
		local state;
		for _,aurastate in ipairs(Data:GetAuraStates(player)) do
			for ab = 1, playerPet.numAbilities do				
				-- check if ability needs a specific aura state to get more damage
				state = env.requiredtargetstate(playerPet["ab"..ab], 1, EVENT_On_Damage_Dealt);
				g(ab, state > 0 and aurastate == state);
			end
		end
		
		return unpack(glow);
	end
end
--@end-do-not-package@


----------------------------------
-- Scanning Pets for Combat
----------------------------------

local scan_pets, scan_dummys, roundup_pets;
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
		
		t.side = side;
		t.numPets = numPets;
		t.activePet = activePet;
		t.scanned = true;
		
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
			--t[pet].pet = pet;
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
			t[pet].breed = LibBreed:GetBreedName( LibBreed:GetBreedByPetBattleSlot(side, pet) or 0 );
			
			for ab = 1, numAbilities do
				t[pet]["ab"..ab] = _G.C_PetBattles.GetAbilityInfo(side, pet, ab); -- ability id
			end
		end
	end
	
	local random = math.random;
	scan_dummys = function(side, t)
		-- if there is scanned data, we can return :)
		if( t.scanned ) then return; end
		
		local numPets = 3;
		local activePet = random(1, numPets);
		
		t.side = side;
		t.numPets = numPets;
		t.activePet = activePet;
		t.scanned = true;
		
		local abID; -- for random ability creation
		
		for pet = 1, numPets do
			-- the t[pet] tables will be reused even after wipe_pets() got executed, the garbagecollector doesn't get something to eat *sob*
			if( not t[pet] or not(type(t[pet]) == "table") ) then
				t[pet] = {};
				setmetatable(t[pet], mt);
			end
			
			--t[pet].side = side;
			--t[pet].pet = pet;
			t[pet].name = "Dummy "..pet;
			t[pet].level = random(1, 25);
			t[pet].species = species;
			t[pet].type = random(1, 10);
			t[pet].speed = t[pet].level * random(7, 15);
			t[pet].icon = "INTERFACE\\ICONS\\INV_CRATE_02";
			t[pet].quality = pet + ((side - 1) * 3) - 1;
			t[pet].hp = random(0, 10);
			t[pet].hpM = 10;
			t[pet].numAbilities = random(1, 3);
			t[pet].breed = LibBreed:GetBreedName( random(1, 10) );
			
			for ab = 1, t[pet].numAbilities do
				while( not abID ) do
					abID = _G.C_PetBattles.GetAbilityInfoByID(random(200, 800));
				end
				t[pet]["ab"..ab] = abID;
				abID = nil;
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
	scan_pets(PT.ENEMY , self.EnemyInfo );
end

function PT:ScanDummyPets()
	scan_dummys(PT.PLAYER, self.PlayerInfo);
	scan_dummys(PT.ENEMY , self.EnemyInfo );
end

function PT:RoundUpPets()
	roundup_pets(PT.PLAYER, self.PlayerInfo);
	roundup_pets(PT.ENEMY , self.EnemyInfo );
end

-----------------------------
-- Configuration stuff
-----------------------------

local options;
function PT:OpenOptions()
	options = {
		name = L["Pokemon Trainer Options"]..(PT.alpha and " |cffff0000Alpha Package|r" or ""),
		type = "group",
		args = {
			display = {
				type = "select",
				name = L["Preferred combat display"],
				desc = L["Choose between the new (Frames) or the old (Tooltip) way of displaying combat data during pet battles."],
				order = 1,
				style = "radio",
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
				hidden = _G.C_PetBattles.IsInBattle,
			},
			combatnotice = {
				type = "description",
				name = "|cffff0000"..L["Switching the combat display doesn't work during pet battles."].."|r",
				order = 1.1,
				hidden = function() return not _G.C_PetBattles.IsInBattle() end,
			},
			spacer = { type = "description", name = " ", order = 50 },
		},
	};
	
	-- Parts of this code snippet have been written by ckknight and the Chinchilla team
	-- They are great and fit our needs, so we do not re-invent the wheel over and over again.
	local t;
	for key, module in PT:IterateModules() do
		if( key:sub(1, 1) ~= "_" ) then -- no data modules
			t = module.GetOptions and module:GetOptions() or {};
			
			for option, args in pairs(t) do
				if( type(args.disabled) == "nil" ) then
					args.disabled = function() return not module:IsEnabled(); end
				end
			end
			
			t.descr = { type = "description", name = module.desc, order = 0.1 };
			t._spacer1 = { type = "description", name = " ", order = 0.2 };
			
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
					order = 0.3,
					width = "full",
				};
				t._spacer2 = { type = "description", name = " ", order = 0.4 }; -- spacer between the Enable toggle button and the acual options
			end
			
			options.args[key] = { type = "group", name = module.displayName, desc = module.desc, handler = module, order = module.order or -1, args = t }
		end
	end
	
	PT.OpenOptions = nil; -- this function is needed once and gets deleted
	return options;
end