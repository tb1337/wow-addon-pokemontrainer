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
module.desc = "no text"; --L[""];

local owned_pets = {};

-------------------------
-- Module Handling
-------------------------

function module:OnInitialize()
	self.db = PT.db:RegisterNamespace("AuctionSearch", {
		profile = {
			enabled = true,
			knowncolor = {0, 1, 0, 0.2},
			unknowncolor = {1, 0, 0, 0.2},
		},
	});

	if( not self.db.profile.enabled ) then
		self:SetEnabledState(false);
	end
end

function module:OnEnable()	
	-- this AucAdvanced check needs to be reviewed since this module can now be disabled manually
	
	if( _G.IsAddOnLoaded("Blizzard_AuctionUI") ) then
		self:RegisterHooks()
	else
		self:RegisterEvent("ADDON_LOADED", function(event, addonName)
			if (addonName == "Blizzard_AuctionUI") then
				module:RegisterHooks()
				module:UnregisterEvent("ADDON_LOADED")
			end
		end);
	end
	
	LibPetJournal:RegisterCallback("PetListUpdated", module.UpdateOwnedPets, module);
end

function module:OnDisable()
	self:UnregisterEvent("ADDON_LOADED");
	self:UnhookAll();
	
	--LibPetJournal:UnregisterCallback("PetListUpdated"); -- see :UpdateOwnedPets
end

function module:RegisterHooks()
    self:SecureHook("AuctionFrameBrowse_Update");
end

---------------------------
-- Update Owned Pets
---------------------------

function module:UpdateOwnedPets()
	-- since I didn't figure out a way to unregister the callback again, we check if the module is loaded
	if( not self.db.profile.enabled ) then
		return;
	end
	
	for i, speciesID in LibPetJournal:IterateSpeciesIDs() do
		owned_pets[speciesID] = _G.C_PetJournal.GetNumCollectedInfo(speciesID) > 0;
	end
end

------------------------------
-- Hook into Auction UI
------------------------------

function module:AuctionFrameBrowse_Update()
	local offset = FauxScrollFrame_GetOffset(BrowseScrollFrame);
	local bg;
	
	for i=1, NUM_BROWSE_TO_DISPLAY do
		if( not _G["BrowseButton"..i].bg ) then
			bg = _G["BrowseButton"..i]:CreateTexture(nil, "BACKGROUND");
			--bg:SetAllPoints(_G["BrowseButton"..i]);
			bg:SetPoint("TOP", _G["BrowseButton"..i], "TOP", 0, 0);
			bg:SetPoint("BOTTOM", _G["BrowseButton"..i], "CENTER", 0, -12);
			bg:SetPoint("LEFT", _G["BrowseButton"..i], "LEFT", 0, 0);
			bg:SetPoint("RIGHT", _G["BrowseButton"..i], "RIGHT", 0, 0);
			bg:Hide();
			_G["BrowseButton"..i].bg = bg;
		end
		
		bg = _G["BrowseButton"..i].bg;
		
		local speciesID = self:ParseBattlePetLink(GetAuctionItemLink("list", offset + i))
		if (speciesID ~= nil) then
			if ( owned_pets[speciesID] ) then
				--_G["BrowseButton"..i.."ItemIconTexture"]:SetVertexColor(unpack(self.db.profile.knowncolor));
				bg:SetTexture(unpack(self.db.profile.knowncolor));
				bg:Show();
			else
				--_G["BrowseButton"..i.."ItemIconTexture"]:SetVertexColor(unpack(self.db.profile.unknowncolor));
				bg:SetTexture(unpack(self.db.profile.unknowncolor));
				bg:Show();
			end
		else
			bg:Hide();
		end
	end
end

-- "|cff1eff00|Hbattlepet:200:4:2:292:34:53:0000000000000000|h[Fr\195\188hlingshase]|h|r"
function module:ParseBattlePetLink(link)
    if (link == nil) then
        return nil
    end
    --return string.match(link, "|Hbattlepet:(%d+):(%d+):(%d+):(%d+):(%d+):(%d+):%d+|h")
    local speciesID, level, quality, health, power, speed = string.match(link, "|Hbattlepet:(%d+):(%d+):(%d+):(%d+):(%d+):(%d+):%d+|h")
    return tonumber(speciesID), tonumber(level), tonumber(quality), tonumber(health), tonumber(power), tonumber(speed)
end

----------------------
-- Option Table
----------------------

function module:GetOptions()
	return {
		color = {
			type = "color",
			name = "Known Color",
			hasAlpha = false,
			get = function()
				return unpack(self.db.profile.knowncolor);
			end,
			set = function(_, ...)
				self.db.profile.knowncolor = {...};
			end
		}
	};
end