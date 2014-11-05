local AddonName, PT = ...;
local Base = PT:NewComponent("_Base");

local L = LibStub("AceLocale-3.0"):GetLocale(AddonName);

function Base:ComponentInit()
	-- Creating Addon Database
	PT.db = LibStub("AceDB-3.0"):New("PokemonTrainer_DB", { profile = {
		version = "",
	}}, "Default").profile;
	
	-- Registering config and attach it to the UI
	--LibStub("AceConfig-3.0"):RegisterOptionsTable(AddonName, PT.OpenOptions);
	--LibStub("AceConfigDialog-3.0"):AddToBlizOptions(AddonName);
	--_G.SlashCmdList["PT"] = function() _G.InterfaceOptionsFrame_OpenToCategory(AddonName); end
	--_G["SLASH_PT1"] = "/pt";
	
	local msg;
	local version = tostring(_G.GetAddOnMetadata(AddonName, "Version"));
	
	if( not PT.ALPHA ) then
		if( PT.db.version ~= version ) then
			if( PT.db.version == "" ) then
				msg = L["First run, you may wanna check /pt for options."];
			else
				msg = "|cff00aaff"..AddonName.."|r: "..L["Recently updated to version"].." "..version;
			end
			
			PT.db.version = version;
		end
	else
		if( not PT.DEBUG ) then
			msg = "|cff00aaff"..AddonName.."|r: "..L["Running Alpha Package without being a developer, it could be unstable or erroneous. Feedback is appreciated. Please install at least a Beta Package if you do not want that at all."];
		end
	end
	
	if( msg ) then
		LibStub("AceTimer-3.0").ScheduleTimer(PT, function() print(msg) end, 15);
	end
end

-------------------------------------------------------------
-- Addon Components
-------------------------------------------------------------

-- Both hooks only apply for the FrameCombatDisplay
-- When hiding the UI, PT's frames are hidden as well
_G.UIParent:HookScript("OnShow", function()
	if( _G.C_PetBattles.IsInBattle() ) then
		--_G.PTPlayer:Show();
		--_G.PTEnemy:Show();
	end
end);

_G.UIParent:HookScript("OnHide", function()
	if( _G.C_PetBattles.IsInBattle() ) then
		--_G.PTPlayer:Hide();
		--_G.PTEnemy:Hide();
	end
end);

-------------------------------------------------------------
-- Patch for PetJournal loading
-------------------------------------------------------------
-- Thanks to esiemiat on CurseForge
--
-- *************************************************************************************
-- **** Addresses a Blizzard issue in C_PetJournal when the UI is loading. Sometimes there is a lag
-- **** between C_PetJournal.GetPetInfoByIndex producing valid values and C_PetJournal.GetPetStats
-- **** producing valid values. This leads to the following:
-- ****      Error Message: ...e\AddOns\Blizzard_PetJournal\Blizzard_PetJournal.lua line 771:
-- ****      attempt to perform arithmetic on local 'rarity' (a nil value)
-- *************************************************************************************
local LibPetJournal = LibStub("LibPetJournal-2.0");
LibPetJournal.RegisterCallback(Base, "PostPetListUpdated", function()
	if( not _G.IsAddOnLoaded("Blizzard_PetJournal") ) then _G.LoadAddOn("Blizzard_PetJournal") end
	LibPetJournal.UnregisterCallback(Base, "PostPetListUpdated");
end)