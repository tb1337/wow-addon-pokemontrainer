-----------------------------------
-- Setting up scope, upvalues and libs
-----------------------------------

local AddonName, PT = ...;
local module = PT:NewModule("HealBandageButtons");

local L = LibStub("AceLocale-3.0"):GetLocale(AddonName);

local _G = _G;

----------------------
-- Variables
----------------------

module.displayName = "ALPHA Pet Healing";
module.desc = "Curseforge Ticket #11 by A2line - this module is currently under construction and only available in alpha packages";

module.petHealSpell = 125439; -- Blizzard_PetJournal.lua
module.petBandage = 86143; -- item id

-------------------------
-- Module Handling
-------------------------

function module:OnInitialize()
	self.db = PT.db:RegisterNamespace("HealBandageButtons", {
		profile = {
			enabled = false,
		},
	});

	if( not self.db.profile.enabled ) then
		self:SetEnabledState(false);
	end
end

function module:OnEnable()	
	_G.PTHealBandageFrame:Show();
end

function module:OnDisable()
	_G.PTHealBandageFrame:Hide();
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
		
	};
end