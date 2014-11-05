local AddonName, PT = ...;
if( not PT.DEBUG ) then return end -- only load in debug mode

-------------------------------------------------------------
-- Copy&Paste Snippets
--
-- max ability IDs:				/script PT.Dev:ScanMaxAbility()
-- scan all abilitys:			/script PT.Dev:ScanAbility()
-- scan weather mods:			/script PT.Dev:ScanWeatherMods()
-- scan ability mods:			/script PT.Dev:ScanAbilityMods()
--
--
--
--
-------------------------------------------------------------

local MAXIMUM_ABILITY_ID = 2000;

-- Developer component
local Dev = PT:NewComponent("Dev");
local Const = PT:GetComponent("Const");

-- stores all ability data
Dev.Ability = {};

Dev.events = {"APPLY", "DAMAGE_TAKEN", "DAMAGE_DEALT", "HEAL_TAKEN",
							"HEAL_DEALT", "AURA_REMOVED", "ROUND_START", "ROUND_END",
							"TURN", "ABILITY", "SWAP_IN", "SWAP_OUT"};

-- our print function
local print = function(...) print("|cffff0000[PT_Dev]|r", ...) end
local deli = function() print("-----------------------------------------------------------") end

-------------------------------------------------------------
-- Maximum Ability Scanner
-------------------------------------------------------------

function Dev:ScanMaxAbility(num)
	num = num or 5000;
	local result = num;
	
	-- loop backwards
	for i = num, 1, -1 do
		local id = _G.C_PetBattles.GetAbilityInfoByID(i);
		
		result = i;
		if( id ) then
			break;
		end
	end
	
	deli();
	print("Max Ability ID:", result);
	deli();
end

-------------------------------------------------------------
-- Ability Scanner
-------------------------------------------------------------

function Dev:ScanAbility()
	local IDs = {};
	self:_BuildTable(IDs);
	
	wipe(self.Ability);
	
	for _, i in ipairs(IDs) do
		local info = {};
		self:_ScanAbility(info, i);
		table.insert(self.Ability, info);
	end
end

function Dev:_BuildTable(t)
	-- exclude ability IDs from scanning
	local banned = {
			7, 70, 71, 72, 73, 74, 78, 79, 80, 81, 82, 83, 84, 85, 86, 87, 88, 97, 125,
			131, 132, 133, 134, 149, 150, 157, 220, 234, 235, 285, 286, 287, 288, 292, 295, 549, 562,
			684, 714, 722, 725, 728, 733, 853, 925, 955, 967
	};
	
	for i = 1, MAXIMUM_ABILITY_ID do
		local id, name, _, _, desc = _G.C_PetBattles.GetAbilityInfoByID(i);
		
		if( not id ) then
			-- do nothing, no valid ability found
		elseif( tContains(banned, id) ) then
			-- check for banned ability
			--print("|cffff00ffBanned Ability|r", id, "-", name);
		elseif( desc == "" ) then
			-- we pretend that abilitys without description are GM abilitys.
			-- you should simply ban them.
			--print("|cffffff00GM Ability?|r", id, "-", name);
		else
			-- supposed to be valid
			table.insert(t, id);
		end
	end
end

-- /script PT.Dev:ScanAbility()
function Dev:_ScanAbility(t, i)
	-- no ability validity check here cuz this is previously done
	local id, name, icon, maxCD, desc, numTurns, petType, noHints = _G.C_PetBattles.GetAbilityInfoByID(i);
	
	t.id = id;
	t.name = name;
	t.icon = icon;
	t.maxCD = maxCD;
	t.desc = desc;
	t.numTurns = numTurns;
	t.type = petType;
	t.noHints = noHints;
	t.isAura = false;
	
	-- numTurns or maxXD is usually 0 when it comes to an aura, but not always
	if( t.numTurns == 0 ) then
		t.isAura = true;
	end
	
	-- ability state modifications are set by auras
	-- if we catch such a state, this ability id must be an aura!
	for stateID, stateName in pairs(Const.STATES) do
		local result = _G.C_PetBattles.GetAbilityStateModification(id, stateID);
		
		if( result and result > 0 ) then
			t.isAura = true;
			t.stateMods = t.stateMods or {};
			
			t.stateMods[stateName] = {
				state = stateID,
				value = result
			};
		end
	end
	
	-- scan for ability procs
	for n, v in ipairs(Dev.events) do
		local eventNum = n - 1;
		local eventName = "EVENT_"..v;
		
		-- check for procs
		local proc = _G.C_PetBattles.GetAbilityProcTurnIndex(id, eventNum);
		if( proc ) then
			t.procTurns = t.procTurns or {};
			t.procTurns[eventName] = t.procTurns[eventName] or {};
			t.procTurns[eventName] = eventNum;
		end
		
		-- check for effects
		for effectNum, effectName in ipairs(Const.EFFECTS) do
			if( proc ) then
				for turn = 1, proc do
					local result = _G.C_PetBattles.GetAbilityEffectInfo(id, turn, eventNum, effectName);
					
					if( result ) then
						t.effects = t.effects or {};
						t.effects[turn] = t.effects[turn] or {};
						t.effects[turn][eventName] = t.effects[turn][eventName] or {};
						t.effects[turn][eventName][effectName]  = result;
					end
				end
			end
			
			if( numTurns < 2 ) then
				local result = _G.C_PetBattles.GetAbilityEffectInfo(id, 1, eventNum, effectName);
				
				if( result ) then
					t.effects = t.effects or {};
					t.effects[1] = t.effects[1] or {};
					t.effects[1][eventName] = t.effects[1][eventName] or {};
					t.effects[1][eventName][effectName]  = result;
				end
			else
				for turn = 1, numTurns do
					local result = _G.C_PetBattles.GetAbilityEffectInfo(id, turn, eventNum, effectName);
					
					if( result ) then
						t.effects = t.effects or {};
						t.effects[turn] = t.effects[turn] or {};
						t.effects[turn][eventName] = t.effects[turn][eventName] or {};
						t.effects[turn][eventName][effectName]  = result;
					end
				end
			end
		end
	end
	
end