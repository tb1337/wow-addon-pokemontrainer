-----------------------------------
-- Setting up scope, upvalues and libs
-----------------------------------

local AddonName, PT = ...;
local module = PT:NewModule("HealBandageButtons", "AceEvent-3.0");

local L = LibStub("AceLocale-3.0"):GetLocale(AddonName);

local _G = _G;

----------------------
-- Variables
----------------------

module.displayName = L["Heal Pet Buttons"];
module.desc = L["When pet tracking is enabled, this module displays two buttons on a separate and draggable frame. One for healing your battle pets with the spellcast, another for healing with pet bandages. Clicking these buttons is allowed when not in combat."];

module.petHealSpell = 125439; -- Blizzard_PetJournal.lua
module.petBandage = 86143; -- item id

-------------------------
-- Module Handling
-------------------------

function module:OnInitialize()
	self.db = PT.db:RegisterNamespace("HealBandageButtons", {
		profile = {
			enabled = false,
			mousebutton = "type1",
			modifier = "alt-",
		},
	});

	if( not self.db.profile.enabled ) then
		self:SetEnabledState(false);
	end
	
	_G.PTHealBandageFrameHealButton:SetAttribute(self.db.profile.modifier..self.db.profile.mousebutton, "spell");
	_G.PTHealBandageFrameBandageButton:SetAttribute(self.db.profile.modifier..self.db.profile.mousebutton, "item");
end

function module:OnEnable()	
	self:RegisterEvent("MINIMAP_UPDATE_TRACKING", "CheckMinimapTracking");
	self:RegisterEvent("PLAYER_REGEN_DISABLED", "CombatEvent", true);
	self:RegisterEvent("PLAYER_REGEN_ENABLED", "CombatEvent", false);
	
	self:CheckMinimapTracking();
end

function module:OnDisable()
	self:UnregisterEvent("MINIMAP_UPDATE_TRACKING");
	self:UnregisterEvent("PLAYER_ENTER_COMBAT");
	self:UnregisterEvent("PLAYER_LEAVE_COMBAT");
	
	_G.PTHealBandageFrame:Hide();
end

------------------------
-- Event Handlers
------------------------

function module:CombatEvent(in_combat)
	if( in_combat ) then
		self.prevdisplayed = _G.PTHealBandageFrame:IsVisible();
		_G.PTHealBandageFrame:Hide();
	else
		if( self.prevdisplayed ) then
			_G.PTHealBandageFrame:Show();
		end
	end	
end

function module:CheckMinimapTracking()
	local name, icon, active;
	
	for i = 1, _G.GetNumTrackingTypes() do
		name, icon, active = _G.GetTrackingInfo(i);
		
		if( icon == "Interface\\Icons\\tracking_wildpet" ) then			
			break;
		end
	end
	
	if( active ) then
		_G.PTHealBandageFrame:Show();
	else
		_G.PTHealBandageFrame:Hide();
	end
end

-----------------------------
-- Both Button related
-----------------------------

function module.Button_UpdateCooldown(self)
	local start, duration, enable;
	
	if( self:GetID() == 1 ) then
		start, duration, enable = _G.GetSpellCooldown(module.petHealSpell);
	else
		start, duration, enable = _G.GetItemCooldown(module.petBandage);		
	end
	
	_G.CooldownFrame_SetTimer(self.cooldown, start, duration, enable);
end

function module.Button_UpdateUsability(self)
	if( _G.C_PetBattles.IsInBattle() ) then
		self:SetButtonState("NORMAL", true);
		self.icon:SetDesaturated(true);
	else
		self:SetButtonState("NORMAL", false);
		self.icon:SetDesaturated(false);
	end
		
	if( self:GetID() == 1 ) then		
		if( self:IsEventRegistered("SPELLS_CHANGED") ) then
			self:UnregisterEvent("SPELLS_CHANGED");
		end
	else
		local count = _G.GetItemCount(module.petBandage);
		_G[self:GetName().."Count"]:SetText(count);
		
		if( count > 0 ) then
			self.icon:SetVertexColor(1, 1, 1, 1);
		else
			self.icon:SetVertexColor(0.3, 0.3, 0.3, 1);
		end
	end
end

----------------------
-- Option Table
----------------------

function module:GetOptions()
	return {
		mousebutton = {
			type = "select",
			name = L["Mouse button"],
			desc = L["Select the mouse button on which clicks will execute actions. UI reload required."],
			order = 1,
			get = function()
				return self.db.profile.mousebutton;
			end,
			set = function(_, value)
				self.db.profile.mousebutton = value;
			end,
			values = {
				["type1"] = L["Left"],
				["type2"] = L["Right"],
				["type*"] = _G.ALL,
			},
		},
		modifier = {
			type = "select",
			name = L["Modifier"],
			desc = L["Choose whether you need to push a modifier key or not, when clicking an action button. UI reload required."],
			order = 2,
			get = function()
				return self.db.profile.modifier;
			end,
			set = function(_, value)
				self.db.profile.modifier = value;
			end,
			values = {
				[""] = _G.NONE,
				["shift-"] = L["Shift"],
				["alt-"]   = L["Alt"],
				["ctrl-"]  = L["Ctrl"],
			},
		},
	};
end