-------------------------------------------------------------
-- PokemonTrainer
-------------------------------------------------------------

local AddonName, PT = ...;
_G[AddonName] = PT;

PT.Events = {};
PT.Component = {};

-------------------------------------------------------------
-- Event Handler
-------------------------------------------------------------

local EventHandler = _G.CreateFrame("Frame");
EventHandler:SetScript("OnEvent", function(_, event, ...)
	PT:FireEvent(event, ...);
end);

--PT.EventHandler = EventHandler;

-------------------------------------------------------------
-- Addon Components
-------------------------------------------------------------

function PT:NewComponent(namespace, tab)
	local t = tab or {};
	self.Component[namespace] = t;
	return t;
end

do
	local t = {};
	local wipe = _G.wipe;
	
	function PT:GetComponent(...)
		wipe(t);
		local name;
		
		for i = 1, select("#", ...) do
			name = select(i, ...);
			
			if( PT.Component[name] ) then
				table.insert(t, PT.Component[name]);
			end
		end
		
		return unpack(t);
	end
end

function PT:RegisterEvent(event, action, notBlizzard)
	if( not PT.Events[event] ) then
		if( not notBlizzard ) then
			EventHandler:RegisterEvent(event);
		end
		PT.Events[event] = action and action or event;
	end
end

function PT:FireEvent(event, ...)
	-- only handle registered events
	if( not self.Events[event] ) then return end
	local action = self.Events[event];
	
	--@do-not-package@
	local catched = false;
	--@end-do-not-package@
	
	for _, obj in pairs(PT.Component) do
		if( type(obj) == "table" and obj[action] ) then
			obj[action](obj, ...);
			--@do-not-package@
			catched = true;
			--@end-do-not-package@
		end
	end
	
	--@do-not-package@
	if( PT.DEBUG and not catched ) then
		print("PT: Uncatched event ,"..event.."' with args ", ...);
	end
	--@end-do-not-package@
end

-------------------------------------------------------------
-- Addon Base Class
-------------------------------------------------------------

local Base = PT:NewClass("BaseClass");

-- registers itself to the PT table, must be called from derived classes as supermethod
function Base:initialize(className)
	PT:NewComponent(className or self.class.name, self);
end

PT.BaseClass = Base;

-------------------------------------------------------------
-- Registering events
-------------------------------------------------------------

PT:RegisterEvent("PLAYER_ENTERING_WORLD", "ComponentInit");

-- battle begin / end
PT:RegisterEvent("PET_BATTLE_OPENING_START", "BattleBeginStart");
--PT:RegisterEvent("PET_BATTLE_OPENING_DONE", "BattleBeginDone");
PT:RegisterEvent("PET_BATTLE_OVER", "BattleOver");
PT:RegisterEvent("PET_BATTLE_CLOSE", "BattleClose");

-- battle round change
--PT:RegisterEvent("PET_BATTLE_PET_ROUND_RESULTS", "BattleRoundResult"); -- arg1: round num
PT:RegisterEvent("PET_BATTLE_PET_ROUND_PLAYBACK_COMPLETE", "BattleRoundPlayback"); -- arg1: round num
PT:RegisterEvent("PET_BATTLE_FINAL_ROUND", "BattleFinalRound"); -- arg1: either Const.USER or Const.ENEMY

-- general
PT:RegisterEvent("PET_BATTLE_ACTION_SELECTED", "BattleActionSelected");
PT:RegisterEvent("PET_BATTLE_PET_CHANGED", "BattlePetChanged"); -- arg1: trainer
--PT:RegisterEvent("CHAT_MSG_PET_BATTLE_COMBAT_LOG", "BattleCombatLog");

-- aura
PT:RegisterEvent("PET_BATTLE_AURA_APPLIED", "BattleAuraChangeHandler"); -- arg1: trainer, arg2: pet, arg3: instanceID 
PT:RegisterEvent("PET_BATTLE_AURA_CANCELED", "BattleAuraChangeHandler"); -- arg1: trainer, arg2: pet, arg3: instanceID 
PT:RegisterEvent("PET_BATTLE_AURA_CHANGED", "BattleAuraChangeHandler"); -- arg1: trainer, arg2: pet, arg3: instanceID 
PT:RegisterEvent("PET_BATTLE_PET_TYPE_CHANGED", "BattleTypeChange"); -- arg1: trainer, arg2: pet, arg3: instanceID 

-- health
PT:RegisterEvent("PET_BATTLE_HEALTH_CHANGED", "BattleHealthChanged"); -- arg1: trainer, arg2: pet, arg3: diff
PT:RegisterEvent("PET_BATTLE_MAX_HEALTH_CHANGED", "BattleMaxHealthChanged"); -- arg1: trainer, arg2: pet, arg3: diff

-------------------------------------------------------------
-- Trashy developer stuff
-------------------------------------------------------------

PT.ALPHA = false;
--@alpha@
PT.ALPHA = true;
--@end-alpha@

PT.DEBUG = false;
--@do-not-package@
_G.PT = PT;
PT.DEBUG = true;
--@do-not-package@;

-- Shortcut for PT.Component.COMPONENT_NAME
setmetatable(PT, {__index = PT.Component});