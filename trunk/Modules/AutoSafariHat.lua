-----------------------------------
-- Setting up scope, upvalues and libs
-----------------------------------

local AddonName, PT = ...;
local module = PT:NewModule("AutoSafariHat", "AceEvent-3.0");

local L = LibStub("AceLocale-3.0"):GetLocale(AddonName);

local _G = _G;

----------------------
-- Variables
----------------------

module.displayName = "|TInterface\\OptionsFrame\\UI-OptionsFrame-NewFeatureIcon:0:0:0:0|t"..L["Auto Safari Hat"];
module.desc = L["Small module which will always equip your Safari Hat when engaging a battle pet. After the battle is over and the XP is gained, it will switch back to your previous weared head gear."];

local hat_exists = false;
local hat_bag;
local hat_slot;

local head_slot = 1;

local SAFARI_HAT = 92738; -- Safari Hat == 92738, my testing hat == 81578

-------------------------
-- Module Handling
-------------------------

function module:OnInitialize()
	self.db = PT.db:RegisterNamespace("AutoSafariHat", {
		profile = {
			enabled = false,
			messages = true,
			errors = false,
		},
	});

	if( not self.db.profile.enabled ) then
		self:SetEnabledState(false);
	end
end

function module:OnEnable()	
	self:RegisterEvent("BAG_UPDATE_DELAYED", "ScanForHat");
	self:RegisterEvent("PET_BATTLE_OPENING_DONE", "PetBattleStart"); -- during OPENING_START we cannot change equip
	self:RegisterEvent("PET_BATTLE_CLOSE", "PetBattleStop");
end

function module:OnDisable()
	self:UnregisterEvent("BAG_UPDATE_DELAYED");
	self:UnregisterEvent("PET_BATTLE_OPENING_DONE");
	self:UnregisterEvent("PET_BATTLE_CLOSE");
end

------------------------
-- Event Handlers
------------------------

function module:PetBattleStart()
	self.battlestop = false;
	
	local err, msg = true, nil;
	
	if( hat_exists ) then
		if( self:WearingHat() ) then
			msg = L["Hat already put on!"];
		elseif( hat_bag and hat_slot ) then
			err, msg = false, L["Hat put on successfully."];
			_G.PickupContainerItem(hat_bag, hat_slot);
			_G.PickupInventoryItem(head_slot);
		else
			msg = L["Something went totally wrong. This error should never appear."];
		end
	end
	
	if( self.db.profile.messages and msg ) then
		if( self.db.profile.errors and not err ) then
			return;
		end
		print(("|cff00aaff%s|r %s - %s"):format(AddonName, L["Safari Hat"], msg));
	end
end

function module:PetBattleStop()
	if( self.battlestop ) then -- pet battles are always closed twice. tricky you, Blizzard
		return;
	end
	self.battlestop = true;
	
	local err, msg = true, nil;
	
	if( self:WearingHat() ) then
		if( hat_bag and hat_slot ) then
			err, msg = false, L["Original hat put on succesfully."];
			_G.PickupContainerItem(hat_bag, hat_slot);
			_G.PickupInventoryItem(head_slot);
		else
			msg = L["Cannot put original hat on, it is unknown."];
		end
	end
	
	if( self.db.profile.messages and msg ) then
		if( self.db.profile.errors and not err ) then
			return;
		end
		print(("|cff00aaff%s|r %s - %s"):format(AddonName, L["Safari Hat"], msg));
	end
end

--------------------------------------
-- Scanning bags for Safari Hat
--------------------------------------

function module:WearingHat()
	return _G.GetInventoryItemID("player", head_slot) == SAFARI_HAT;
end

local function scan_slot(bag, slot)
	if( _G.GetContainerItemID(bag, slot) == SAFARI_HAT ) then
		hat_exists, hat_bag, hat_slot = true, bag, slot;
		return true;
	end
	
	return false;
end

function module:ScanForHat()
	if( self:WearingHat() ) then
		hat_exists = true;
		return;
	end
	
	for bag = 0, 4 do
		for slot = 1, _G.GetContainerNumSlots(bag) do
			if( scan_slot(bag, slot) ) then
				return;
			end
		end
	end
	
	hat_exists, hat_bag, hat_slot = false, nil, nil;
end

----------------------
-- Option Table
----------------------

do
	local function scan_hat()
		return hat_exists and "|cff00ff00"..L["Safari Hat found in your bags!"].."|r" or "|cffff0000"..L["Safari Hat not found in your bags!"].."|r";
	end
	
	function module:GetOptions()	
		return {
			scan = {
				type = "description",
				name = scan_hat,
				fontSize = "large",
				order = 1,
			},
			spacer = {
				type = "description",
				name = " ",
				order = 1.1,
			},
			messages = {
				type = "toggle",
				name = L["Display messages"],
				desc = L["Prints messages into the chat window when equip is successfully switched or errors occured."],
				get = function()
					return self.db.profile.messages;
				end,
				set = function(_, value)
					self.db.profile.messages = value;
				end,
				order = 2,
			},
			onlyerrors = {
				type = "toggle",
				name = L["Only errors"],
				desc = L["Prints only error messages."],
				get = function()
					return self.db.profile.errors;
				end,
				set = function(_, value)
					self.db.profile.errors = value;
				end,
				order = 3,
			},
		};
	end
end