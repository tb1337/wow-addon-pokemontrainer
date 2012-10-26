-----------------------------
-- Get the addon table
-----------------------------

local AddonName, PT = ...;

local L = LibStub("AceLocale-3.0"):GetLocale(AddonName);

local _G = _G; -- I always use _G.FUNC when I call a Global. Upvalueing done here.
local format = string.format;

-----------------------------------------
-- Variables, functions and colors
-----------------------------------------

local cfg; -- this stores our configuration GUI

---------------------------
-- The options table
---------------------------

function PT:CreateDB()
	PT.CreateDB = nil;
	
	return { profile = {
		TooltipShowCaught = true,
		TooltipShowProsCons = true,
		BattlePositionY = 300,
		BattleFrameScale = 1,
	}};
end

---------------------------------
-- The configuration table
---------------------------------

local dummyBattleStarted = false;

function PT:CancelDummyBattle()
	self:PetBattleStop();
	dummyBattleStarted = false;
end

local function initializeDummyBattleFrames(info, value)
	PT.db[info[#info]] = value;
	
	PT:ScanDummyPets(_G.LE_BATTLE_PET_ALLY, PT.petAbilitys);
	PT:ScanDummyPets(_G.LE_BATTLE_PET_ENEMY, PT.enemyAbilitys);
	
	if( dummyBattleStarted ) then
		PT:PetBattleStop();
		dummyBattleStarted = false;
	end
	
	PT:PetBattleStart();
	dummyBattleStarted = true;
	
	PT.dummyTimer = PT:ScheduleTimer("CancelDummyBattle", 5);
end

cfg = {
		type = "group",
		name = AddonName,
		order = 1,
		get = function(info)
			return PT.db[info[#info]];
		end,
		set = function(info, value)
			PT.db[info[#info]] = value;
		end,
		args = {
			GroupTooltip = {
				type = "group",
				name = "Tooltip Options",
				order = 1,
				inline = true,
				args = {
					TooltipShowCaught = {
						type = "toggle",
						name = "Display whether the pet is already caught or not",
						width = "full",
						order = 1,
					},
					TooltipShowProsCons = {
						type = "toggle",
						name = "Display the pros and cons of your setup against the wild pet",
						width = "full",
						order = 5,
					},
				},
			},
			GroupBattle = {
				type = "group",
				name = "Battle Options",
				order = 2,
				inline = true,
				args = {
					BattlePositionY = {
						type = "range",
						name = "Frame Position",
						width = "full",
						order = 1,
						min = 1,
						max = 800,
						step = 1,
						bigStep = 5,
						set = initializeDummyBattleFrames,
					},
					BattleFrameScale = {
						type = "range",
						name = "Frame Scale",
						order = 5,
						min = 0.5,
						max = 1.5,
						step = 0.1,
						set = initializeDummyBattleFrames,
					},
				},
			},
		},
};

function PT:OpenOptions()
	_G.InterfaceOptionsFrame_OpenToCategory(AddonName);
end

LibStub("AceConfig-3.0"):RegisterOptionsTable(AddonName, cfg);
LibStub("AceConfigDialog-3.0"):AddToBlizOptions(AddonName);
_G.SlashCmdList["PT"] = PT.OpenOptions;
_G["SLASH_PT1"] = "/pt";