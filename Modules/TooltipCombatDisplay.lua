-----------------------------------
-- Setting up scope, upvalues and libs
-----------------------------------

local AddonName, PT = ...;
local module = PT:NewModule("TooltipCombatDisplay", "AceEvent-3.0");

local L = LibStub("AceLocale-3.0"):GetLocale(AddonName);

local _G = _G;

----------------------
-- Variables
----------------------

module.order = 2;
module.displayName = function() return (module:IsEnabled() and "|cff00ff00%s|r" or "|cffff0000%s|r"):format(L["Display: Tooltip"]) end
module.desc = L["LibQTip based combat display for Pet Battles. Disable it if you want to use the frame based combat display."];
module.noEnableButton = true;

-------------------------
-- Module Handling
-------------------------

function module:OnInitialize()
	self.db = PT.db:RegisterNamespace("TooltipCombatDisplay", {
		profile = {
			
		},
	});

	if( PT.db.profile.activeBattleDisplay ~= 2 ) then
		self:SetEnabledState(false);
	end
end

function module:OnEnable()
	-- for the skill frames
	self:RegisterEvent("PET_BATTLE_OPENING_START", "PetBattleStart");
	self:RegisterEvent("PET_BATTLE_OVER", "PetBattleStop");
	self:RegisterEvent("PET_BATTLE_CLOSE", "PetBattleStop");
	self:RegisterEvent("PET_BATTLE_PET_CHANGED", "PetBattleChanged");
	self:RegisterEvent("PET_BATTLE_PET_ROUND_PLAYBACK_COMPLETE", "PetBattleChanged");
	
end

function module:OnDisable()
	self:UnregisterEvent("PET_BATTLE_OPENING_START");
	self:UnregisterEvent("PET_BATTLE_OVER");
	self:UnregisterEvent("PET_BATTLE_CLOSE");
	self:UnregisterEvent("PET_BATTLE_PET_CHANGED");
	self:UnregisterEvent("PET_BATTLE_PET_ROUND_PLAYBACK_COMPLETE");
	
	self:PetBattleStop();
end

-------------------------
-- Helper Functions
-------------------------

local function type_icon(petType, size, offx, offy)
	if not size then size = 14 end
	if not offx then offx = 0 end
	if not offy then offy = 0 end
	return "|T".._G.GetPetTypeTexture(petType)..":"..size..":"..size..":"..offx..":"..offy..":128:256:62:102:128:169|t";
end
local function level_color(level, compare_level)
    local r,g,b = GetDifficultyColor(compare_level - level)
    return ("|cff%02x%02x%02x%s|r"):format(r*255,g*255,b*255,level)
end
local function quality_color(owner, index, name)
	local r, g, b, hex = _G.GetItemQualityColor(_G.C_PetBattles.GetBreedQuality(owner, index) - 1);
	return ("|c"..hex.."%s|r"):format(name);
end
local function format_cooldown(name, id, avail, cdleft)
	if( id and not avail) then
        if (cdleft ~= nil and cdleft > 0) then -- the ability can be unuseable without cooldown, under unknown circumstates the cdleft may be nil (may be was the missing table wipe)
            return (COLOR_RED):format(name.." ("..cdleft..")");
        else
            return (COLOR_RED):format(name);
        end
	end
	
	return (COLOR_GOLD):format(name);
end

-------------------------
-- Tooltip Display
-------------------------

local function UpdatePlayerSkills(tip)
	-- temporary fix: getting the tooltip, as iLib doesn't pass it as expected
    module:UpdateTooltip(PT:GetTooltip("PlayerSkills"), PT.PLAYER, PT.PlayerInfo, PT.EnemyInfo)
end

local function UpdateEnemySkills(tip)
    module:UpdateTooltip(PT:GetTooltip("EnemySkills"), PT.ENEMY, PT.EnemyInfo, PT.PlayerInfo)
end

function module:PetBattleStart()
    PT:ScanPets()
	
	local tip = PT:GetTooltip("PlayerSkills", UpdatePlayerSkills);
	tip:SetPoint("TOPLEFT", _G.UIParent, "TOPLEFT", 0, 400 --[[-self.db.BattlePositionY]]);
	tip:SetFrameStrata("BACKGROUND");
	tip:SetScale(1 --[[self.db.BattleFrameScale]]);
	tip:Show();
    
	tip = PT:GetTooltip("EnemySkills", UpdateEnemySkills);
	tip:SetPoint("TOPRIGHT", _G.UIParent, "TOPRIGHT", 0, 400--[[-self.db.BattlePositionY]]);
	tip:SetFrameStrata("BACKGROUND");
	tip:SetScale(1 --[[self.db.BattleFrameScale]]);
	tip:Show();
end

function module:PetBattleChanged()
	PT:RoundUpPets()
	
	PT:CheckTooltips("EnemySkills", "PlayerSkills");
end

function module:PetBattleStop()
	PT:GetTooltip("EnemySkills"):Release();
	PT:GetTooltip("PlayerSkills"):Release();
end


function module:UpdateTooltip(tip, side, displayPets, comparePets)
	tip:Clear();
    
    local isme = side == PT.PLAYER
    local versus = isme and PT.ENEMY or PT.PLAYER
    
	tip:SetColumnLayout(2 + #comparePets, "LEFT", "LEFT", "CENTER", "CENTER", "CENTER");
	
	local line = tip:AddLine("", "");
	for i, pet in ipairs(comparePets) do
		tip:SetCell(line, 2 + i, "|T"..pet.icon..":22:22|t");
		if (i == _G.C_PetBattles.GetActivePet(versus)) then
            if (isme) then
                tip:SetColumnColor(2 + i, 1, 0, 0, 0.5);
            else
                tip:SetColumnColor(2 + i, 0, 1, 0, 0.5);
            end
		else
			tip:SetColumnColor(2 + i, 0, 0, 0, 0);
		end
	end
	
	for i, pet in ipairs(displayPets) do
		if (i ~= 1) then
			tip:AddSeparator();
		end
		
		line = tip:AddLine(type_icon(pet.type, 22), quality_color(side, i, pet.name));
		
        local mySpeed = _G.C_PetBattles.GetSpeed(side, i)
		for j, enemy in ipairs(comparePets) do
            local frame = get_speed_indicator_frame(side, i, j)
            local vsSpeed = _G.C_PetBattles.GetSpeed(versus, j);
            if (mySpeed > vsSpeed) then
                if (has_flight_bonus_active(side, i)) then
                    frame.icon:SetVertexColor(0.1,0.9,0.1, 1)
                else
                    frame.icon:SetVertexColor(1,1,1, 1)
                end
            elseif (mySpeed == vsSpeed) then
                frame.icon:SetVertexColor(0.3,0.3,0.3, 1);
            else
                frame.icon:SetVertexColor(0.7,0.1,0.1, 1);
            end
            
            tip:SetCell(line, 2 + j, frame, cellAppendProvider); -- Sets frame-parent to cell
            frame:SetPoint("CENTER");
            
			--[[local modifier = self:Compare(pet.type, enemy.type);
			tip:SetCell(line, 2 + j, damage_icon(modifier, 22));]]
		end

		if (i == _G.C_PetBattles.GetActivePet(side)) then
            if (isme) then
                tip:SetLineColor(line, 0, 1, 0, 0.5);
            else
                tip:SetLineColor(line, 1, 0, 0, 0.5);
            end
		end
		
		for j = 1, pet.numAbilities do
			local ability = pet["ab"..j]
			local id, name, icon, maxCD, desc, turns, petType, noStrongWeakHints = _G.C_PetBattles.GetAbilityInfoByID(ability);
			local avail, cdleft, _ = PT:GetAbilityCooldown(side, i, j);
			
			line = tip:AddLine("|T"..icon..":22:22|t", "  "..format_cooldown(name, id, avail, cdleft));
			
			for k, pet in ipairs(comparePets) do
				local modifier = self:Compare(petType, pet.type);
				tip:SetCell(line, 2 + k, damage_icon(modifier, 22));
			end
			
			tip:SetLineScript(line, "OnEnter", function (anchor)
                    _G.PetBattleAbilityTooltip_SetAuraID(side, i, ability);
                    if (isme) then
                        _G.PetBattleAbilityTooltip_Show("TOPLEFT", anchor, "TOPRIGHT", 10, 2);
                    else
                        _G.PetBattleAbilityTooltip_Show("TOPRIGHT", anchor, "TOPLEFT", -10, 2);
                    end
                end);
			tip:SetLineScript(line, "OnLeave", function ()
                    _G.PetBattlePrimaryAbilityTooltip:Hide();
                end);
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