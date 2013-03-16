-----------------------------------
-- Setting up scope, upvalues and libs
-----------------------------------

local AddonName, PT = ...;
local module = PT:NewModule("AuctionSearch", "AceHook-3.0", "AceEvent-3.0");

local L = LibStub("AceLocale-3.0"):GetLocale(AddonName);
local LibPetJournal = LibStub("LibPetJournal-2.0");

local _G = _G;

----------------------
-- Variables
----------------------

module.displayName = L["Auction Search"];
module.desc = L["When searching for pets in the auction house, this module sets red and green background colors which indicate whether you own this pet or not."];

local owned_pets = {};
local pet_list_update = false;

-------------------------
-- Module Handling
-------------------------

function module:OnInitialize()
	self.db = PT.db:RegisterNamespace("AuctionSearch", {
		profile = {
			enabled = false,
			known_r = 0,
			known_g = 1,
			known_b = 0,
			unknown_r = 1,
			unknown_g = 0,
			unknown_b = 0,
		},
	});

	if( not self.db.profile.enabled ) then
		self:SetEnabledState(false);
	end
end

local on_event = function(event, addonName)
	if( addonName == "Blizzard_AuctionUI" ) then
		module:SecureHook("AuctionFrameBrowse_Update");
		module:SecureHook("AuctionFrame_Show");
		module:UnregisterEvent("ADDON_LOADED");
	end
end

function module:OnEnable()	
	-- this AucAdvanced check needs to be reviewed since this module can now be disabled manually
	if( _G.IsAddOnLoaded("Blizzard_AuctionUI") ) then
		self:SecureHook("AuctionFrameBrowse_Update");
		self:SecureHook("AuctionFrame_Show");
	else
		self:RegisterEvent("ADDON_LOADED", on_event);
	end
	
	pet_list_update = true;
	self:UpdateOwnedPets();
end

function module:OnDisable()
	self:UnregisterEvent("ADDON_LOADED");
	self:UnhookAll();
end

---------------------------
-- Update Owned Pets
---------------------------

function module:UpdateOwnedPets()
	-- since I didn't figure out a way to unregister the callback again, we check if the module is loaded
	if( not pet_list_update ) then return; end
	
	for i, speciesID in LibPetJournal:IterateSpeciesIDs() do
		owned_pets[speciesID] = _G.C_PetJournal.GetNumCollectedInfo(speciesID) > 0;
	end
end

function module:PetUpdate()
	pet_list_update = self.db.profile.enabled;
end

LibPetJournal:RegisterCallback("PetListUpdated", module.PetUpdate, module);

------------------------------
-- Hook into Auction UI
------------------------------

-- "|cff1eff00|Hbattlepet:200:4:2:292:34:53:0000000000000000|h[Fr\195\188hlingshase]|h|r"
-- |cff0070dd|Hbattlepet:1111:2222:3333:4444:5555:6666:0x00000000000000000|h[Aschesteinkern]|h|r
local function parse_link(link)
	if( not link ) then return; end
	--local speciesID, level, quality, health, power, speed = link:match("|Hbattlepet:(%d+):(%d+):(%d+):(%d+):(%d+):(%d+):%s+|h");
	--return tonumber(speciesID), tonumber(level), tonumber(quality), tonumber(health), tonumber(power), tonumber(speed);
	return tonumber( link:match("|Hbattlepet:(%d+):") );
end

function module:AuctionFrame_Show()
	self:UpdateOwnedPets();
end

function module:AuctionFrameBrowse_Update()
	if( not _G.AuctionFrameBrowse:IsVisible() ) then
		return;
	end
	
	-- Blizzard AuctionFrameBrowse is visible, so we display our custom backgrounds
	local bg;
	
	for i = 1, _G.NUM_BROWSE_TO_DISPLAY do
		if( not _G["PTBrowseButtonTex"..i] ) then
			bg = _G["BrowseButton"..i]:CreateTexture("PTBrowseButtonTex"..i, "BACKGROUND");
			bg:SetPoint("TOP", _G["BrowseButton"..i], "TOP", 0, 0);
			bg:SetPoint("BOTTOM", _G["BrowseButton"..i], "CENTER", 0, -12);
			bg:SetPoint("LEFT", _G["BrowseButton"..i], "LEFT", 0, 0);
			bg:SetPoint("RIGHT", _G["BrowseButton"..i], "RIGHT", 0, 0);
			bg:Hide();
		end
		
		bg = _G["PTBrowseButtonTex"..i];
		local offset = _G.FauxScrollFrame_GetOffset(_G.BrowseScrollFrame);
		local speciesID = parse_link(_G.GetAuctionItemLink("list", offset + i));
		
		if( speciesID ) then
			if ( owned_pets[speciesID] ) then
				--_G["BrowseButton"..i.."ItemIconTexture"]:SetVertexColor(unpack(self.db.profile.knowncolor));
				bg:SetTexture(self.db.profile.known_r, self.db.profile.known_g, self.db.profile.known_b, 0.2);
				bg:Show();
			else
				--_G["BrowseButton"..i.."ItemIconTexture"]:SetVertexColor(unpack(self.db.profile.unknowncolor));
				bg:SetTexture(self.db.profile.unknown_r, self.db.profile.unknown_g, self.db.profile.unknown_b, 0.2);
				bg:Show();
			end
		else
			bg:Hide();
		end
	end
	
end

----------------------
-- Option Table
----------------------

function module:GetOptions()
	return {
		known = {
			type = "color",
			name = L["Known pet color"],
			hasAlpha = false,
			order = 1,
			get = function()
				return self.db.profile.known_r, self.db.profile.known_g, self.db.profile.known_b;
			end,
			set = function(_, r, g, b)
				self.db.profile.known_r = r;
				self.db.profile.known_g = g;
				self.db.profile.known_b = b;
				self:AuctionFrameBrowse_Update();
			end,
		},
		unknown = {
			type = "color",
			name = L["Unknown pet color"],
			hasAlpha = false,
			order = 2,
			get = function()
				return self.db.profile.unknown_r, self.db.profile.unknown_g, self.db.profile.unknown_b;
			end,
			set = function(_, r, g, b)
				self.db.profile.unknown_r = r;
				self.db.profile.unknown_g = g;
				self.db.profile.unknown_b = b;
				self:AuctionFrameBrowse_Update();
			end,
		},
		spacer = { type = "description", name = " ", order = 3 },
		info = {
			type = "description",
			name = L["Please note that the Auction Search module isn't supporting third party auction addons. If such addons are actually changing the default auction UI and these changes break this module, simply disable it. Please do not open tickets if other addons break this module. Thanks."].." :-)",
			order = 4,
			fontSize = "medium",
		},
		spacer2 = { type = "description", name = " ", order = 5 },
		info2 = {
			type = "description",
			name = L["If you are author/maintainer of a common auction UI addon and want this module supporting your addon, feel free to open a ticket on Curseforge or simply send me an email at"].." |cff00aaffwow-addons@grdn.eu|r",
			order = 6,
		},
	};
end