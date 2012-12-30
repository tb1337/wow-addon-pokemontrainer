local AddonName, PT = ...;
local _G = _G;

local module = PT:NewModule("_Dev");
function module:OnInitialize() -- fires when the saved var is loaded
	-- SavedVariable, see TOC
	_G.PTDevDB = _G.PTDevDB or {};
	_G.PTDevDB.data = _G.PTDevDB.data or {};
	_G.PTDevDB.aurastates = _G.PTDevDB.aurastates or {};
end
function module:Clear()
	self.dumped = false;
	
	_G.PTDevDB = {
		data = {},
		aurastates = {},
	};
end

-------------------
-- Variables
-------------------

module.dumped = false; -- set by :Dump

local MAX_INVALID_ABILITY_ID = 2000;

-- Please notice that I don't take care for overhead in this script as it is only for developing purposes
-- This file isn't packaged to public Curse packages and only available at the repo

--[[ My personal copy & paste snippets. :D
	/script PT:GetModule("_Dev"):Clear()
	/script PT:GetModule("_Dev"):Dump()
	/script PT:GetModule("_Dev"):CreateAuraStates()
--]]

-------------------------------------------
-- Create Table with all Aura States
-------------------------------------------

function module:CreateAuraStates()
	self:Dump();
	
	local t = {};
	
	-- state familys which in fact can boost ability power
	local statefamilys = {
		--"Add", 			-- not clear if it increases our damage, need to check
		"Mechanic_Is",-- status codes, f.e. Stunned, Blinded
		"Mod_Damage",	-- direct damage increase values
		"Mod_Pet",		-- pet type id of abilities which deal more damage, all available here
		"Weather",		-- weather states
	};
	
	-- loop all abilitys
	for i,a in ipairs(_G.PTDevDB.data) do
		-- check if aura
		if( a.isAura ) then
			-- loop all dumped states
			for stateName, data in pairs(a.states) do
				-- loop our state family list
				for _,family in ipairs(statefamilys) do
					-- check whether or not the state interests us
					if( stateName:sub(1, strlen(family)) == family ) then
						t[a.id] = t[a.id] or {};
						t[a.id][data.id] = data.value;
					end -- endif
				end -- endfor
			end -- endfor
		end --endif
	end --endfor
	
	_G.PTDevDB.aurastates = t;
end

------------------------------------------
-- Dump All Pet Battle Ability Data
------------------------------------------

function module:Dump()
	if( self.dumped ) then return end
	self.dumped = true;
	
	local t = {}; -- stores all ability info data
	
	-- stores banned ability IDs who passed all validity checks
	local banned = {86};
	
	-- loop to ability % and check if it's a valid ability
	-- invalid IDs and GM abilities are filtered
	local valid = {}; -- stores valid ability IDs
	for i = 1, MAX_INVALID_ABILITY_ID do
		local id, name, _, _, desc = _G.C_PetBattles.GetAbilityInfoByID(i);
		
		if( not id ) then
			-- invalid ability
		else
			-- GM abilities apparently have no description and weird names
			if( desc == "" ) then
				print(" GM Ability", id, name)
			elseif( tContains(banned, id) ) then
				print(" Banned Ability", id, name);
			else -- valid
				table.insert(valid, id);
			end
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
			isAura = false, -- if this ability is an aura, see end of this method
		};
		
		-- now we loop thru all possible ability "meta data", as I call it
		
		-- scan all ability events
		for eventName, event in pairs(PT.events) do
			-- check for procs
			local proc = _G.C_PetBattles.GetAbilityProcTurnIndex(ability, event);
			if( proc ) then
				info.procs[eventName] = proc;
			end
			
			-- loop thru all effects and check if there is some data available
			for _,effect in ipairs(PT.effects) do
				-- when no procs are available, simply fill data into a table
				if( not proc ) then
					local result = _G.C_PetBattles.GetAbilityEffectInfo(ability, 1, event, effect); -- proc turn = 1
					
					if( result ) then
						info.events[eventName] = info.events[eventName] or {id = event};
						info.events[eventName][effect] = result;
					end
				-- procs are available, so we need to fill a table with even more tables
				else
					-- loop thru all proc turns
					for turn = 1, proc do
						local result = _G.C_PetBattles.GetAbilityEffectInfo(ability, turn, event, effect);
						
						if( result ) then
							info.events[eventName] = info.events[eventName] or {id = event, numTurns = proc};
							info.events[eventName][turn] = info.events[eventName][turn] or {turn = turn};
							info.events[eventName][turn][effect] = result;
						end -- endif
					end --endfor
				end --endif
			end --endfor
		end --endfor
		
		-- ability state modifications are commonly known as auras
		-- we check if our ability is an aura, because auras are client-side available as ability IDs
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