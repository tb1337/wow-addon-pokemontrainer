--@do-not-package@
-- If Curse packages this file by accident, the contents are cut though

local AddonName, PT = ...;
local _G = _G;

-- Please note that I don't take care for overhead in this script as it is only for developing purposes
-- This file isn't packaged to public Curse packages and only available at the repo

--[[ My personal copy & paste snippets. :D
	/script PT:GetModule("_Dev"):Clear()
	/script PT:GetModule("_Dev"):GetAll()
	
	/script PT:GetModule("_Dev"):Dump()
	/script PT:GetModule("_Dev"):CreateAuraStates(true)
	/script PT:GetModule("_Dev"):CompileAbilityTables(true)
--]]

local module = PT:NewModule("_Dev");
function module:OnInitialize() -- fires when the saved var is loaded
	-- SavedVariable, see TOC
	_G.PTDevDB = _G.PTDevDB or {};
	_G.PTDevDB.data = _G.PTDevDB.data or {};
	_G.PTDevDB.aurastates = _G.PTDevDB.aurastates or {};
	_G.PTDevDB.abilitymods = _G.PTDevDB.abilitymods or {};
end

function module:Clear()
	self.dumped = false;
	
	_G.PTDevDB = {
		data = {},
		aurastates = {},
		abilitymods = {},
	};
end

function module:GetAll() -- Just a shortcut
	self:Clear();
	self:CreateAuraStates(true); -- do not delete dumped data
	self:CompileAbilityTables(); -- delete dumped data
end

-------------------
-- Variables
-------------------

module.dumped = false; -- set by :Dump

local MAX_INVALID_ABILITY_ID = 2000;

local MOD_WEATHER = 1;
local MOD_STATUS = 2;
local MOD_WEATHER2 = 3;
local MOD_RAMPING = 4;

-- state familys which in fact can boost ability power
local statefamilys = {
	--"Add", 			-- not clear if it increases our damage, need to check
	"Mechanic_Is",-- status codes, f.e. Stunned, Blinded
	"Mod_Damage",	-- direct damage increase values
	--"Mod_Pet",		-- pet type id of abilities which deal more damage, all available here
	"Weather",		-- weather states
};

local wantedeffects = {
	"requiredtargetstate",
	"pointsincreaseperuse",
};

-- Both LookupState functions are for developing purposes - I can check states during battles
-- or simply retrieve state names of state IDs
function PT.LookupState(state)
	for stateName, stateID in pairs(PT.states) do
		if( stateID == state ) then
			return stateName;
		end
	end
	return "none";
end

function PT.LookupStates()
	print("=======================================");
	print("States: Player");
	for k in pairs(PT.PlayerInfo.aurastates) do
		print("  "..PT.LookupState(k));
	end
	print("States: Enemy");
	for k in pairs(PT.EnemyInfo.aurastates) do
		print("  "..PT.LookupState(k));
	end
end

--------------------------------
-- Compile Ability Tables
--------------------------------

function module:CompileAbilityTables(nodel)
	self:Dump();
	local t = {};
	
	for i,a in ipairs(_G.PTDevDB.data) do
		local e = a.events;
		-- check if not aura but real ability and whether or not it does damage
		if( not a.isAura and e and e.On_Damage_Taken ) then
			local info = {};
			
			for _,effectName in ipairs(wantedeffects) do
				-- whenever we dealt damage
				if( e.On_Damage_Dealt and e.On_Damage_Dealt[effectName] and e.On_Damage_Dealt[effectName] > 0 ) then
					local value = e.On_Damage_Dealt[effectName];
					local stateName = PT.LookupState(value);
					local match = stateName:match("%w+");
					
					if( match == "Weather" ) then
						info[MOD_WEATHER2] = value;
					elseif( match == "Mechanic" ) then
						info[MOD_STATUS] = value;
					end
				end
				
				-- whenever the enemy took damage
				if( e.On_Damage_Taken and e.On_Damage_Taken[effectName] and e.On_Damage_Taken[effectName] > 0 ) then
					local value = e.On_Damage_Taken[effectName];
					
					if( effectName == "pointsincreaseperuse" ) then
						local pointsmax = e.On_Damage_Taken["pointsmax"];
						pointsmax = pointsmax and pointsmax > 0 and pointsmax or (value * 5);
						info[MOD_RAMPING] = math.ceil(pointsmax / value);
					end
				end
			end
			
			-- mechanical attacks gain bonus from lightning storm
			if( a.type == 10 ) then -- mechanical pet type
				info[MOD_WEATHER] = PT.states.Weather_LightningStorm;
			-- aquatic attacks gain bonus from rain
			elseif( a.type == 9 ) then
				info[MOD_WEATHER] = PT.states.Weather_Rain;
			-- magic attacks gain bonus from moonlight
			elseif( a.type == 6 ) then
				info[MOD_WEATHER] = PT.states.Weather_Moonlight;
			end
			
			-- if only MOD_WEATHER is set, the table value becomes a number
			if( info[MOD_WEATHER] and not info[MOD_STATUS] and not info[MOD_WEATHER2] and not info[MOD_RAMPING] ) then
				t[a.id] = info[MOD_WEATHER];
			elseif( info[MOD_WEATHER] or info[MOD_STATUS] or info[MOD_WEATHER2] or info[MOD_RAMPING] ) then
				t[a.id] = info;
			end
		end
	end
	
	_G.PTDevDB.abilitymods = t;
	if( not nodel ) then
		_G.PTDevDB.data = nil;
		self.dumped = false;
	end
end

-------------------------------------------
-- Create Table with all Aura States
-------------------------------------------

function module:CreateAuraStates(nodel)
	self:Dump();
	local t = {};

	-- loop all abilitys
	for i,a in ipairs(_G.PTDevDB.data) do
		-- check if aura
		if( a.isAura ) then
			local info = {};
			
			-- loop all dumped states
			for stateName, data in pairs(a.states) do
				-- loop our state family list
				for _,family in ipairs(statefamilys) do
					-- check whether or not the state interests us
					if( stateName:sub(1, strlen(family)) == family ) then
						table.insert(info, data.id);
					end -- endif
				end -- endfor
			end -- endfor
			
			if( #info > 0 ) then
				if( #info == 1 ) then
					t[a.id] = info[1];
				else
					t[a.id] = info;
				end
			end
		end --endif
	end --endfor
	
	_G.PTDevDB.aurastates = t;
	if( not nodel ) then
		_G.PTDevDB.data = nil;
		self.dumped = false;
	end
end

------------------------------------------
-- Dump All Pet Battle Ability Data
------------------------------------------

function module:Dump()
	if( self.dumped ) then return end
	self.dumped = true;
	
	local t = {}; -- stores all ability info data
	
	-- stores banned ability IDs which passed all my validity checks
	local banned = {86, 292, 295, 562, 684, 714, 722, 725, 728, 733};
	
	-- loop to ability % and check if it's a valid ability
	-- invalid IDs and GM abilities are filtered
	local valid = {}; -- stores valid ability IDs
	for i = 1, MAX_INVALID_ABILITY_ID do
		local id, name, _, _, desc = _G.C_PetBattles.GetAbilityInfoByID(i);
		
		if( not id ) then
			-- invalid ability
		elseif( desc == "" ) then
			--print(" GM Ability", id, name)
		elseif( tContains(banned, id) ) then
			print(" Banned Ability", id, name);
		-- supposed to be valid
		else
			table.insert(valid, id);
		end
	end
	print("Highest ability ID: "..valid[#valid] );
	
	for _,abilityID in ipairs(valid) do
		-- need no ability validity check here cuz this is previously done
		local ability, name, icon, maxCD, desc, numTurns, ptype, noHints = _G.C_PetBattles.GetAbilityInfoByID(abilityID)
		
		-- store all ability info
		local info = {
			id = ability,
			name = name,
			maxCD = maxCD,
			numTurns = numTurns,
			type = ptype,
			noHints = noHints,
			desc = desc,
			events = {}, -- stores eventual events
			states = {}, -- stores eventual states
			procs  = {}, -- stores eventual procs
			isAura = false, -- whether or not this ability is an aura, see end of this method
		};
		
		-- initial aura check
		if( info.numTurns == 0 ) then
			info.isAura = true;
		end
		
		-- now we loop thru all possible ability "meta data", as I call it
		
		-- scan all ability events
		for eventName, event in pairs(PT.events) do
			-- check for procs
			local proc = _G.C_PetBattles.GetAbilityProcTurnIndex(ability, event);
			if( proc ) then
				info.procs[eventName] = {proc = proc};
			end
			
			-- loop thru all effects and check if there is some data available
			for _,effect in ipairs(PT.effects) do
				if( proc ) then
					for turn = 1, proc do
						local result = _G.C_PetBattles.GetAbilityEffectInfo(ability, turn, event, effect);
						
						if( result ) then
							info.procs[eventName] = info.procs[eventName] or {id = event};
							info.procs[eventName][turn] = info.procs[eventName][turn] or {turn = turn};
							info.procs[eventName][turn][effect] = result;
						end
					end
				end
			
				-- when no procs are available, simply fill data into a table
				if( numTurns < 2 ) then
					local result = _G.C_PetBattles.GetAbilityEffectInfo(ability, 1, event, effect);
					
					if( result ) then
						info.events[eventName] = info.events[eventName] or {id = event};
						info.events[eventName][effect] = result;
					end
				-- procs are available, so we need to fill a table with even more tables
				else
					-- loop thru all proc turns
					for turn = 1, numTurns do
						local result = _G.C_PetBattles.GetAbilityEffectInfo(ability, turn, event, effect);
						
						if( result ) then
							info.events[eventName] = info.events[eventName] or {id = event};
							info.events[eventName][turn] = info.events[eventName][turn] or {turn = turn};
							info.events[eventName][turn][effect] = result;
						end -- endif
					end --endfor
				end --endif
			end --endfor
		end --endfor
		
		-- ability state modifications are commonly known as auras
		-- we check if our ability is an aura, because auras are ability IDs as well
		for stateName, stateID in pairs(PT.states) do
			local result = _G.C_PetBattles.GetAbilityStateModification(ability, stateID);
			
			if( result and result > 0 ) then
				info.isAura = true; -- if there is a valid result, it must be an aura
				info.states[stateName] = {
					id = stateID,
					value = result;
				};
			end
		end
		
		table.insert(t, info);
	end
	
	_G.PTDevDB.data = t;
end

--@end-do-not-package@