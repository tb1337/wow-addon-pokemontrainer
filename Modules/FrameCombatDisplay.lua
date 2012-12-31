-----------------------------------
-- Setting up scope, upvalues and libs
-----------------------------------

local AddonName, PT = ...;
local module = PT:NewModule("FrameCombatDisplay", "AceHook-3.0");

local L = LibStub("AceLocale-3.0"):GetLocale(AddonName);
local AceTimer = LibStub("AceTimer-3.0"); -- we don't embed it since its just used by some hooks

local _G = _G;

----------------------
-- Variables
----------------------

module.order = 1;
module.displayName = function() return (module:IsEnabled() and "|cff00ff00%s|r" or "|cffff0000%s|r"):format(L["Display: Frames"]) end
module.desc = L["True frame based combat display for Pet Battles and the next generation of Pokemon Trainer. Disable it if you want to use the tooltip based combat display."];
module.noEnableButton = true;

local BattleFrames = {}; -- if a battle frame is loaded, it adds itself into this table (simply for iterating over battle frames)

local Proxy;

-- xml values
local FRAME_PLAYER = "PTPlayer";
local FRAME_ENEMY  = "PTEnemy";

local FRAME_BUTTON_WIDTH = 22;
local FRAME_LINE_HEIGHT = 22;
local SPACE_PETS = 5;
local SPACE_ABILITIES = 2;
local SPACE_HORIZONTAL = 3;

local FONT_LEVEL_DEFAULT = 13;
local FONT_LEVEL_ADJUST = 8;

-------------------------
-- Module Handling
-------------------------

function module:OnInitialize()
	self.db = PT.db:RegisterNamespace("FrameCombatDisplay", {
		profile = {
			PTPlayer_icon = "TOPLEFT",
			PTPlayer_x = 200,
			PTPlayer_y = 200,
			PTEnemy_icon = "TOPRIGHT",
			PTEnemy_x = ((_G.GetScreenWidth() * _G.UIParent:GetScale()) - 298),
			PTEnemy_y = 200,
			scale = 1,
			resize = true,
			animate_active = true,
			animate_active_r = 0.99,
			animate_active_g = 0.82,
			animate_active_b = 0,
			bg = false,
			bg_r = 0.30,
			bg_g = 0.30,
			bg_b = 0.30,
			bg_a = 0.48,
			breeds = 3,
			reorganize_use = true,
			reorganize_ani = true,
			nactivealpha_use = false,
			nactivealpha = 0.5,
			cd_text = true,
			cd_text_r = 1,
			cd_text_g = 1,
			cd_text_b = 1,
			cd_text_a = 1,
			cd_highlight = true,
			cd_highlight_r = 1,
			cd_highlight_g = 0,
			cd_highlight_b = 0,
			cd_highlight_a = 0.3,
			ability_zoom = false,
		},
	});

	if( PT.db.profile.activeBattleDisplay ~= 1 ) then
		self:SetEnabledState(false);
	end
	
	-- This is a small "positioning" window which is shown when repositioning the battle frames
	LibStub("AceConfig-3.0"):RegisterOptionsTable(AddonName.."_"..self:GetName(), self.GetPositionOptions);
	LibStub("AceConfigDialog-3.0"):SetDefaultSize(AddonName.."_"..self:GetName(), 400, 230);
end

function module:OnEnable()	
	-- For now, our proxy frames collects events and handles them
	-- Read more at the Proxy declaration
	Proxy:RegisterEvent("PET_BATTLE_OPENING_START");
	Proxy:RegisterEvent("PET_BATTLE_OVER");
	Proxy:RegisterEvent("PET_BATTLE_CLOSE");
	Proxy:RegisterEvent("PET_BATTLE_TURN_STARTED");
	Proxy:RegisterEvent("PET_BATTLE_PET_ROUND_PLAYBACK_COMPLETE");
	Proxy:RegisterEvent("PET_BATTLE_PET_CHANGED");
	Proxy:RegisterEvent("PET_BATTLE_HEALTH_CHANGED");
	Proxy:RegisterEvent("PET_BATTLE_MAX_HEALTH_CHANGED");
	Proxy:RegisterEvent("PET_BATTLE_AURA_APPLIED");
	Proxy:RegisterEvent("PET_BATTLE_AURA_CHANGED");
	Proxy:RegisterEvent("PET_BATTLE_AURA_CANCELED");
	
	-- ability buttons handle cooldown highlightning events by themselves
	for _,frame in ipairs(BattleFrames) do
		for pet = PT.PET_INDEX, #frame.petFrames do
			for ab = 1, PT.MAX_PET_ABILITY do
				-- for every ability button
				_G[frame.petFrames[pet]:GetName()]["Ability"..ab]:RegisterEvent("PET_BATTLE_PET_ROUND_PLAYBACK_COMPLETE");
			end
		end
		
		-- reanchor when module loads
		self.BattleFrame_Reanchor(frame, true);
	end
	
	-- setup hooks
	self:SecureHookScript(_G.PetBattleFrame.BottomFrame.PetSelectionFrame, "OnShow", "Hook_PetSelection_Show");
	self:SecureHookScript(_G.PetBattleFrame.BottomFrame.PetSelectionFrame, "OnHide", "Hook_PetSelection_Hide");
	for pet = PT.PET_INDEX, PT.MAX_COMBAT_PETS do
		self:SecureHookScript(_G.PetBattleFrame.BottomFrame.PetSelectionFrame["Pet"..pet], "OnEnter", "Hook_PetSelection_Pet_Enter");
		self:SecureHookScript(_G.PetBattleFrame.BottomFrame.PetSelectionFrame["Pet"..pet], "OnLeave", "Hook_PetSelection_Pet_Leave");
		self:SecureHookScript(_G.PetBattleFrame.BottomFrame.PetSelectionFrame["Pet"..pet], "OnClick", "Hook_PetSelection_Hide");
	end
end

function module:OnDisable()
	-- unregister events
	Proxy:UnregisterAllEvents();
	
	for _,frame in ipairs(BattleFrames) do		
		for pet = PT.PET_INDEX, #frame.petFrames do
			for ab = 1, PT.MAX_PET_ABILITY do
				-- for every ability button
				_G[frame.petFrames[pet]:GetName()]["Ability"..ab]:UnregisterEvent("PET_BATTLE_PET_ROUND_PLAYBACK_COMPLETE");
			end
		end
	end
	
	-- unhook hooks
	self:UnhookAll();
end

---------------
-- Hooks
---------------

-- This chunk of hooks makes PT interacting with the default PetBattle UI Pet Selection Frame
do
	local pet_selected = false; -- when clicked a pet, this becomes true to prevent re-loading the default selecting highlights
	
	-- Sets all player levels to default size excepting the current pet
	local function adjust_player_fonts(current_pet)
		current_pet = pet_selected and -1 or current_pet;
		
		local font, size, outline;
		local fs;
		
		for pet = PT.PET_INDEX, PT.PlayerInfo.numPets do
			fs = _G[FRAME_PLAYER.."Pet"..pet].Button.Level;
			font, size, outline = fs:GetFont();
			fs:SetFont(font, FONT_LEVEL_DEFAULT + (pet == current_pet and FONT_LEVEL_ADJUST or 0), outline);
		end
	end
	
	-- Sets all enemy levels to either default size or adjusted size
	local function adjust_enemy_fonts(bigger)
		local font, size, outline;
		local fs;
		
		for pet = PT.PET_INDEX, PT.EnemyInfo.numPets do
			fs = _G[FRAME_ENEMY.."Pet"..pet].Button.Level;
			font, size, outline = fs:GetFont();
			fs:SetFont(font, FONT_LEVEL_DEFAULT + (bigger and FONT_LEVEL_ADJUST or 0), outline);
		end
	end
	
	-- colorizes all enemy levels based on the given level (= hovered player pet level)
	local function adjust_color(level)
		local r, g, b;
		
		for pet = PT.PET_INDEX, PT.EnemyInfo.numPets do
			r, g, b = PT:GetDifficultyColor(level, PT.EnemyInfo[pet].level);
			_G[FRAME_ENEMY.."Pet"..pet].Button.Level:SetTextColor(r, g, b, 1);
		end
	end
	
	-- called when PetSelection is shown
	function module:Hook_PetSelection_Show(frame)
		pet_selected = false;
		adjust_enemy_fonts(true);
		adjust_player_fonts(PT.PlayerInfo.activePet);
	end
	
	-- called when PetSelection is hidden
	function module:Hook_PetSelection_Hide(frame, button)
		-- we set pet_selected to true because we clicked it (which results in frame closing)
		if( button and button == "LeftButton" ) then
			pet_selected = true;
		end
		
		adjust_enemy_fonts(false);
		adjust_player_fonts(-1); -- fake pet index to get all fonts smaller :D
	end
	
	local timer;
	
	-- called when a pet is hovered on the PetSelection frame
	function module:Hook_PetSelection_Pet_Enter(frame)		
		local pet = frame.petIndex;
		adjust_color(PT.PlayerInfo[pet].level);
		adjust_player_fonts(frame.petIndex);
		
		if( timer ) then
			AceTimer.CancelTimer(module, timer);
		end
	end
	
	-- called when the timer hits null
	local function real_leave()
		local pet = PT.PlayerInfo.activePet;
		adjust_color(PT.PlayerInfo[pet].level);
		adjust_player_fonts(pet);
		timer = nil;
	end
	
	-- called when a pet is not hovered anymore on the PetSelection frame
	-- the reason for the timer is a delayed reset to defaults
	function module:Hook_PetSelection_Pet_Leave(frame)
		if( not pet_selected ) then -- if pet_selected, we do not need the timer which sets everything to default
			timer = AceTimer.ScheduleTimer(module, real_leave, 0.2);
		end
	end
end

----------------------------
-- Frame Functions
----------------------------

-- get enemy frame by frame reference
local function get_enemy(self)
	return self:GetName() == FRAME_PLAYER and _G[FRAME_ENEMY] or _G[FRAME_PLAYER];
end

-- get frame reference by side ID
local function get_frame(side)
	return side == PT.PLAYER and _G[FRAME_PLAYER] or _G[FRAME_ENEMY];
end

-- function to resize a battle frame
function module.BattleFrame_Resize(self)
	-- resizing may be disabled
	if( not module.db.profile.resize ) then
		return;
	end
	
	local frame_name = self:GetName();
	
	local pet_y;
	local y = FRAME_LINE_HEIGHT; -- header frame  
	
	local x = 1 + (self.enemy.numPets + 1) * (FRAME_BUTTON_WIDTH + SPACE_HORIZONTAL) - SPACE_HORIZONTAL;
	
	for pet = PT.PET_INDEX, PT.MAX_COMBAT_PETS do
  	if( not(pet > self.player.numPets) ) then
    	pet_y = FRAME_LINE_HEIGHT; -- type and speed icons
			
			for ab = 1, self.player[pet].numAbilities do
      	pet_y = pet_y + FRAME_LINE_HEIGHT + SPACE_ABILITIES;
			end
			
			y = y + pet_y + SPACE_PETS;
			_G[frame_name.."Pet"..pet]:SetWidth(x);
			_G[frame_name.."Pet"..pet]:SetHeight(pet_y);
		end
	end
  
	self:SetWidth(x);
	self:SetHeight(y);
end

-- returns true if on the left side of the screen, false otherwise
-- called by xml for displaying tooltips
function module.GetTooltipPosition()
	return _G.GetCursorPosition() < (_G.GetScreenWidth() * _G.UIParent:GetEffectiveScale() / 2);
end

-------------------------------
-- On Loading and Events
-------------------------------

do
	-- we keep calling frame:FadeIn and frame:FadeOut instead of frame:Show and frame:Hide
	local function FadeIn(self)
		self:SetAlpha(0);
		self:Show();
		self.animShow:Play();
	end
	
	local function FadeOut(self)
		self.animHide:Play();
	end
	
	-- called by xml
	function module.BattleFrame_OnLoad(self)
		local frame_name = self:GetName();
		self:SetID( frame_name == FRAME_PLAYER and PT.PLAYER or PT.ENEMY );
		
		-- we store the table ID's for further use
		if( self:GetID() == PT.PLAYER ) then
			self.player = PT.PlayerInfo;
			self.enemy  = PT.EnemyInfo;
		else
			self.player = PT.EnemyInfo;
			self.enemy  = PT.PlayerInfo;
		end
		
		-- add self to BattleFrames
		table.insert(BattleFrames, self);
		
		-- animations
		self.petFrames = {
			_G[frame_name.."Pet1"],
			_G[frame_name.."Pet2"],
			_G[frame_name.."Pet3"],
		};
		
		-- add our Fade functions to the frame objects
		self.FadeIn = FadeIn;
		self.FadeOut = FadeOut;
	end
end

-- Previously, both Player and Enemy frames were listening for events. That resulted in scanning pets twice, rounding up twice,
-- annoying checks which frame is currently handling an event, etc.pp.
-- That's why I choosed to create a Proxy frame which listens to all necessary events and makes the battle frames doing something.

Proxy = _G.CreateFrame("Frame");
Proxy:Hide();

function Proxy.OnEvent(self, event, ...)
	-- a pet battle recently started - completely set up the frames
	if( event == "PET_BATTLE_OPENING_START" ) then
		PT:ScanPets();
		for _,frame in ipairs(BattleFrames) do
			frame:FadeIn();
			PT:ScanPetAuras(frame.player);
			module.BattleFrame_UpdateAbilityHighlights(frame);
		end
	-- battle is over (beginning camera zoom)
	elseif( event == "PET_BATTLE_OVER" ) then
		_G[FRAME_PLAYER]:FadeOut();
		_G[FRAME_ENEMY]:FadeOut();
	-- battle is over or got interrupted (by lfg warp etc.), we must hide the frames if no _OVER event was fired
	elseif( event == "PET_BATTLE_CLOSE" ) then
		for _,frame in ipairs(BattleFrames) do
			if( frame:IsVisible() and not frame.animHide:IsPlaying() ) then
				frame:Hide();
			end
		end
	-- fires before a new round begins
	elseif( event == "PET_BATTLE_PET_ROUND_PLAYBACK_COMPLETE" ) then
		PT:RoundUpPets();
		module.BattleFrame_UpdateSpeedButtons(_G[FRAME_PLAYER]);
		module.BattleFrame_UpdateSpeedButtons(_G[FRAME_ENEMY]);
		--PT.BattleFrame_UpdateActivePetHighlight(self);
	-- fires when either player or enemy changed their active pet
	elseif( event == "PET_BATTLE_PET_CHANGED" ) then
		local side = ...;
		local frame = get_frame(side);
		
		module.hideall_glowing(frame);
		
		PT:RoundUpPets(side);
		PT:ScanPetAuras(frame.player);
		
		module.BattleFrame_UpdateActivePetHighlight(frame);
		
		if( frame.firstRound or not module.db.profile.reorganize_use ) then
			frame.firstRound = nil;
			module.BattleFrame_UpdateAbilityHighlights(frame);
			module.BattleFrame_UpdateAbilityHighlights(get_enemy(frame)); -- enemy needs update, too!
		else
			-- update ability highlight is called by Reorganize_Show_Finished too, after reorganizing is done.
			module.BattleFrame_Pets_Reorganize_Init(frame);
		end
	-- fired whenever a pet got damaged, healed or buffed itself more HP
	elseif( event == "PET_BATTLE_HEALTH_CHANGED" or event == "PET_BATTLE_MAX_HEALTH_CHANGED" ) then
		local side, pet = ...;
		local frame = get_frame(side);
		
		if( pet == frame.player.activePet ) then
			PT:RoundUpPets(side);
			module.BattleFrame_UpdateHealthState(frame);
		end
	-- check aura events ONLY if the data module is loaded
	elseif( event == "PET_BATTLE_AURA_APPLIED" or event == "PET_BATTLE_AURA_CHANGED" or event == "PET_BATTLE_AURA_CANCELED" ) then
		local side, pet = ...;
		local frame = get_frame(side);
		
		if( side == PT.WEATHER ) then
			PT:ScanPetAuras(frame.player);
			PT:ScanPetAuras(get_enemy(frame).player);
			module.BattleFrame_UpdateAbilityHighlights(frame);
			module.BattleFrame_UpdateAbilityHighlights(get_enemy(frame));
		elseif( pet == frame.player.activePet or pet == PT.PAD_INDEX ) then
			PT:ScanPetAuras(frame.player);
			module.BattleFrame_UpdateAbilityHighlights(frame);
			module.BattleFrame_UpdateAbilityHighlights(get_enemy(frame)); -- enemy needs update, too!
		end
	--@do-not-package@
	else
		print("Uncatched event:", event, ...);
		--@end-do-not-package@
	end
end
Proxy:SetScript("OnEvent", Proxy.OnEvent);

--------------------------
-- Frame Visibility
--------------------------

local function BattleFrame_SetColumnVisibility(f, column, visible)
	-- we just need the frame name here
	f = f:GetName();
	
	if( visible ) then
		_G[f.."Header"]["Enemy"..column]:Show();
		for pet = PT.PET_INDEX, PT.MAX_COMBAT_PETS do
			_G[f.."Pet"..pet]["Speed"..column]:Show();
			_G[f.."Pet"..pet]["SpeedBG"..column]:Show();
			_G[f.."Pet"..pet]["Ability1"]["Bonus"..column]:Show();
			_G[f.."Pet"..pet]["Ability2"]["Bonus"..column]:Show();
			_G[f.."Pet"..pet]["Ability3"]["Bonus"..column]:Show();
		end
	else
		_G[f.."Header"]["Enemy"..column]:Hide();
		for pet = PT.PET_INDEX, PT.MAX_COMBAT_PETS do
			_G[f.."Pet"..pet]["Speed"..column]:Hide();
			_G[f.."Pet"..pet]["SpeedBG"..column]:Hide();
			_G[f.."Pet"..pet]["Ability1"]["Bonus"..column]:Hide();
			_G[f.."Pet"..pet]["Ability2"]["Bonus"..column]:Hide();
			_G[f.."Pet"..pet]["Ability3"]["Bonus"..column]:Hide();
		end
	end
end

local function BattleFrame_SetRowVisibility(self, pet, ab, visible)
	local f = self:GetName();
	
	if( visible ) then
		_G[f.."Pet"..pet]["Ability"..ab]:Show();
	else
		_G[f.."Pet"..pet]["Ability"..ab]:Hide();
	end
end

----------------------------------
-- Battle Frame: Initialize
----------------------------------

-- called by xml whenever a battle frame is shown
function module.BattleFrame_Initialize(self)	
	local enemy = get_enemy(self);
	local color;
	
	local frame_name = self:GetName();
	local breed, show1, show2;
	
	for pet = PT.PET_INDEX, PT.MAX_COMBAT_PETS do
		if( pet <= self.player.numPets ) then
			-- setting up pet icons
			_G[frame_name.."Pet"..pet].Button.Icon:SetTexture(self.player[pet].icon);
			_G[frame_name.."Pet"..pet].Type:SetTexture(PT:GetTypeIcon(self.player[pet].type));
			_G[enemy:GetName().."Header"]["Enemy"..pet].Icon:SetTexture(self.player[pet].icon);
			
			-- encolor pet icon borders
			color = _G.ITEM_QUALITY_COLORS[self.player[pet].quality or 0];
			_G[frame_name.."Pet"..pet].Button.Border:SetVertexColor(color.r, color.g, color.b, 1);
			_G[enemy:GetName().."Header"]["Enemy"..pet].Border:SetVertexColor(color.r, color.g, color.b, 1);
			
			-- set level strings
			_G[frame_name.."Pet"..pet].Button.Level:SetText( self.player[pet].level );
			
			-- display pet column on enemy frame
			BattleFrame_SetColumnVisibility(enemy, pet, true);
			
			-- setup ability buttons
			module.BattleFrame_SetupAbilityButtons(self, pet);
			
			-- prepare breed info
			breed = self.player[pet].breed;
			show1, show2 = false, false;
			
			if( breed and module.db.profile.breeds > 0 ) then
				-- the breeds option has to be treated as an ORed value
				if( bit.band(module.db.profile.breeds, 1) > 0 ) then
					_G[frame_name.."Pet"..pet].Button.BreedText:SetText(breed);
					show1 = true;
				end
				
				-- the breeds option has to be treated as an ORed value
				if( bit.band(module.db.profile.breeds, 2) > 0 ) then
					breed = breed:sub(1, 1); -- we don't need breed anymore, so we get the first letter for displaying icons
					show2 = true;
					
					if( breed == "P" ) then
						_G[frame_name.."Pet"..pet].Button.BreedTexture:SetTexCoord(0, 0.5, 0, 0.5);
					elseif( breed == "S" ) then
						_G[frame_name.."Pet"..pet].Button.BreedTexture:SetTexCoord(0, 0.5, 0.5, 1);
					elseif( breed == "H" ) then
						_G[frame_name.."Pet"..pet].Button.BreedTexture:SetTexCoord(0.5, 1, 0.5, 1);
					else
						-- balanced means no special stuff, so no icon
						show2 = false;
					end
				end
			end
			if( show1 ) then _G[frame_name.."Pet"..pet].Button.BreedText:Show() else _G[frame_name.."Pet"..pet].Button.BreedText:Hide() end
			if( show2 ) then _G[frame_name.."Pet"..pet].Button.BreedTexture:Show() else _G[frame_name.."Pet"..pet].Button.BreedTexture:Hide() end
			
			-- display pet frame
			_G[frame_name.."Pet"..pet]:Show();
		else
			-- hide pet ability frame
			_G[frame_name.."Pet"..pet]:Hide();
			
			-- hide pet column on enemy frame
			BattleFrame_SetColumnVisibility(enemy, pet, false);
		end
	end
	
	-- set health state
	module.BattleFrame_UpdateHealthState(self);
end

---------------------------------------------
-- Battle Frame: Setup Ability Buttons
---------------------------------------------

function module.BattleFrame_SetupAbilityButtons(self, pet)
	local abID, abName, abIcon, abMaxCD, abDesc, abNumTurns, abType, noStrongWeak;

	for ab = 1, PT.MAX_PET_ABILITY do
		if( ab <= self.player[pet].numAbilities ) then
			abID, abName, abIcon, abMaxCD, abDesc, abNumTurns, abType, noStrongWeak = _G.C_PetBattles.GetAbilityInfoByID( self.player[pet]["ab"..ab] );
			
			-- set ability icon
			_G[self:GetName().."Pet"..pet]["Ability"..ab].bg:SetTexture(abIcon);
			
			-- show ability row on self
			BattleFrame_SetRowVisibility(self, pet, ab, true);
			
			-- setup vulnerability bonus buttons
			for enemPet = PT.PET_INDEX, self.enemy.numPets do
				_G[self:GetName().."Pet"..pet]["Ability"..ab]["Bonus"..enemPet]:SetTexture( PT:GetTypeBonusIcon(abType, self.enemy[enemPet].type, noStrongWeak) );
			end
		else
			-- hide ability row on self
			BattleFrame_SetRowVisibility(self, pet, ab, false);
		end
	end
end

function module.BattleFrame_UpdateSpeedButtons(self)
	local speed, flying;
	local frame_name = self:GetName();
	
	for pet = PT.PET_INDEX, self.player.numPets do
		-- iterate through enemy pets and (re-)calculate speed bonuses
		for enemPet = PT.PET_INDEX, self.enemy.numPets do
			-- update speed buttons
			speed, flying = PT:GetSpeedBonus( self.player[pet], self.enemy[enemPet] );
			
			if( speed == PT.BONUS_SPEED_FASTER ) then -- faster
				_G[frame_name.."Pet"..pet]["Speed"..enemPet]:SetVertexColor(1, 1, 1, 1);
			elseif( speed == PT.BONUS_SPEED_EQUAL ) then -- equal
				_G[frame_name.."Pet"..pet]["Speed"..enemPet]:SetVertexColor(0.6, 0.6, 0.6, 1);
			elseif( speed == PT.BONUS_SPEED_SLOWER ) then -- slower
				if( flying ) then -- would be faster with active flying bonus
					_G[frame_name.."Pet"..pet]["Speed"..enemPet]:SetVertexColor(1, 0, 0, 1);
				else
					_G[frame_name.."Pet"..pet]["Speed"..enemPet]:SetVertexColor(0.1, 0.1, 0.1, 1);
				end
			end
		end -- end for enemPet
	end -- end for pet
end

function module.BattleFrame_UpdateHealthState(self)
	local enemy = get_enemy(self);
	
	local frame_name = self:GetName();
	local enemy_name = enemy:GetName();
	
	for pet = PT.PET_INDEX, self.player.numPets do
		if( self.player[pet].dead ) then
			_G[frame_name.."Pet"..pet].Button.Dead:Show();
			_G[frame_name.."Pet"..pet].Button.Border:Hide();
			_G[enemy_name.."Header"]["Enemy"..pet].Dead:Show();
			_G[enemy_name.."Header"]["Enemy"..pet].Border:Hide();
		else
			_G[frame_name.."Pet"..pet].Button.Dead:Hide();
			_G[frame_name.."Pet"..pet].Button.Border:Show();
			_G[enemy_name.."Header"]["Enemy"..pet].Dead:Hide();
			_G[enemy_name.."Header"]["Enemy"..pet].Border:Show();
		end
	end
end

-----------------------------------
-- Ability Highlight Glowing
-----------------------------------

do
	local heap = {};
	local glownum = 0;
	
	PT.heap = heap;
	
	local function blast_glowing(self)
		if( not self ) then return end;
		
		local glow = self:GetParent();
		local frame = glow:GetParent();
		
		glow:Hide();
		
		table.insert(heap, glow);
		frame.glowFrame = nil;
	end
	
	local function glowing_OnHide(self)
		if( self.animOut:IsPlaying() ) then
			self.animOut:Stop();
			blast_glowing(self.animOut);
		end
	end
	
	local function get_glowing()
		local glow = table.remove(heap);
		if( not glow ) then
			glownum = glownum + 1;
			glow = _G.CreateFrame("Frame", "PTGlowFrame"..glownum, _G.UIParent, "ActionBarButtonSpellActivationAlert");
			glow.animOut:SetScript("OnFinished", blast_glowing);
			glow:SetScript("OnHide", glowing_OnHide);
		end
		return glow;
	end
	
	local function show_glowing(self)		
		if( self.glowFrame ) then
			if( self.glowFrame.animOut:IsPlaying() ) then
				self.glowFrame.animOut:Stop();
				self.glowFrame.animIn:Play();
			end
		else
			local glow = get_glowing();
			local width, height = self:GetSize();
			
			glow:SetParent(self);
			glow:ClearAllPoints();
			glow:SetSize(width * 1.4, height * 1.4);
			glow:SetPoint("TOPLEFT", self, "TOPLEFT", -width * 0.2, height * 0.2);
			glow:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", width * 0.2, -height * 0.2);
			glow.animIn:Play();
			
			self.glowFrame = glow;
		end
	end
	
	local function hide_glowing(self)
		local glow = self.glowFrame;
		
		if( glow ) then
			if( glow.animIn:IsPlaying() ) then
				glow.animIn:Stop();
			end
			if( self:IsVisible() ) then
				glow.animOut:Play();
			else
				blast_glowing(self, glow);
			end
		end
	end
	
	function module.hideall_glowing(self)
		local frame_name = self:GetName();
		local glow;
		
		for ab = 1, self.player[self.player.activePet].numAbilities do
			glow = _G[frame_name.."Pet"..self.player.activePet]["Ability"..ab].glowFrame;
			if( glow ) then
				blast_glowing(glow.animOut);
			end
		end
	end
	
	function module.BattleFrame_UpdateAbilityHighlights(self)
		local frame_name = self:GetName();
		
		if( _G.C_PetBattles.IsInBattle() ) then
			local glow1, glow2, glow3 = PT:GetStateBonuses(self.player, self.enemy);
			
			if( glow1 ) then
				show_glowing(_G[frame_name.."Pet"..self.player.activePet].Ability1);
			else
				hide_glowing(_G[frame_name.."Pet"..self.player.activePet].Ability1);
			end
			
			if( glow2 ) then
				show_glowing(_G[frame_name.."Pet"..self.player.activePet].Ability2);
			else
				hide_glowing(_G[frame_name.."Pet"..self.player.activePet].Ability2);
			end
			
			if( glow3 ) then
				show_glowing(_G[frame_name.."Pet"..self.player.activePet].Ability3);
			else
				hide_glowing(_G[frame_name.."Pet"..self.player.activePet].Ability3);
			end
		end
	end
end

---------------------------------------------------------
-- Highlighting, Reorganizing, Animation Functions
---------------------------------------------------------

function module.BattleFrame_UpdateActivePetHighlight(self)
	local frame_name = self:GetName();
	local r, g, b;
	
	for pet = 1, self.player.numPets do
		-- sets the level color in relation to the active enemy pet
		-- UPDATE NOTICE: there must be an option to reverse the coloring since it may be confusing
		r, g, b = PT:GetDifficultyColor(self.enemy[self.enemy.activePet], self.player[pet]);
		_G[frame_name.."Pet"..pet]["Button"].Level:SetTextColor(r, g, b, 1);
		
		-- set alpha
		if( module.db.profile.nactivealpha_use ) then
			if( pet == self.player.activePet ) then
				_G[frame_name.."Pet"..pet]:SetAlpha(1);
			else
				_G[frame_name.."Pet"..pet]:SetAlpha(module.db.profile.nactivealpha);
			end
		else
			_G[frame_name.."Pet"..pet]:SetAlpha(1);
		end
		
		-- set active background highlight
		if( module.db.profile.animate_active ) then
			if( pet == self.player.activePet ) then
				_G[frame_name.."Pet"..pet].activeBG.animActive:Play();
			else
				_G[frame_name.."Pet"..pet].activeBG.animActive:Stop();
			end
		else
			_G[frame_name.."Pet"..pet].activeBG.animActive:Stop();
		end
		
	end
end

function module.BattleFrame_Pets_Reorganize_Exec(self, animate) -- self is PT master frame
	animate = type(animate) == "nil" and true or false;
	animate = animate and module.db.profile.reorganize_ani and true or false;
	
	local frame_name = self:GetName();
	
	for i,f in ipairs(self.petFrames) do
		f:ClearAllPoints();
		
		if( i == 1 ) then
			f:SetPoint("TOPLEFT", frame_name.."Header", "BOTTOMLEFT", 0, -6);
		else
			f:SetPoint("TOPLEFT", self.petFrames[i - 1], "BOTTOMLEFT", 0, -SPACE_PETS);
		end
		
		if( animate ) then
			f.animShow:Play();
		else
			module.BattleFrame_Pet_ShowFinished(f.animShow); -- dummy
		end
	end
end

-- little sort function which sorts the pet frames, dead pets are displayed last
local function pets_sort(pet1, pet2)
	local master = pet1:GetParent();
	
	-- if pet frame > numPets, put it last
	local numPets = master.player.numPets;
	if( pet1:GetID() > numPets ) then
		return false;
	elseif( pet2:GetID() > numPets ) then
		return true;
	end
	
	-- check for active pet
	if( master.player.activePet == pet1:GetID() ) then
		return true;
	elseif( master.player.activePet == pet2:GetID() ) then
		return false;
	end
	
	-- check for a dead pet
	local dead1 = master.player[pet1:GetID()].dead;
	local dead2 = master.player[pet2:GetID()].dead;
	if( dead1 and not dead2 ) then
		return false;
	elseif( dead2 and not dead1 ) then
		return true;
	end
	
	-- fall back to pet ID (1, 2, 3) (no pets dead, numPets == MAX_PETS)
	return pet1:GetID() < pet2:GetID();
end

function module.BattleFrame_Pets_Reorganize_Init(self, animate) -- self is PT master frame
	animate = (type(animate) == "nil" or animate == true) and true or false; -- nil/true = animate, false = do not animate
	
	-- animation can be toggled in configuration
	if( animate and not module.db.profile.reorganize_ani ) then
		animate = false;
	end
		
	if( animate ) then
		for i,f in ipairs(self.petFrames) do
			f.animHide:Play();
		end
	end
	
	table.sort(self.petFrames, pets_sort);
	
	if( not animate ) then
		module.BattleFrame_Pets_Reorganize_Exec(self, animate);
	end
end

-- called by xml
function module.BattleFrame_Pet_HideFinished(self) -- self is animation frame
	local parent = self:GetParent(); -- pet frame
	local master = parent:GetParent(); -- master frame
	
	master.animDone = master.animDone + 1;
	parent:SetAlpha(0);
	
	-- if all frames are hidden, the reorganizing shall begin
	if( master.animDone == master.player.numPets ) then
		master.animDone = 0;
		module.BattleFrame_Pets_Reorganize_Exec(master);
	end
end

-- called by xml
function module.BattleFrame_Pet_ShowFinished(self) -- self is animation frame
	local parent = self:GetParent(); -- pet frame
	local alpha = module.db.profile.nactivealpha_use and module.db.profile.nactivealpha or 1;
	parent:SetAlpha( parent:GetID() == parent:GetParent().player.activePet and 1 or alpha );
	
	-- the reorganization process is finished now, so we can update ability highlights
	-- parent of parent is master
	parent = parent:GetParent();
	module.BattleFrame_UpdateAbilityHighlights(parent);
	module.BattleFrame_UpdateAbilityHighlights(get_enemy(parent)); -- enemy needs update, too!
end

-- called by xml
function module.BattleFrame_Pet_WhilePlaying(self) -- self is animation frame
	local parent = self:GetParent();
	if( module.db.profile.nactivealpha_use and parent:GetID() ~= parent:GetParent().player.activePet ) then
		if( module.db.profile.nactivealpha <= parent:GetAlpha() ) then
			self:Stop();
		end
	end
end

-------------------------------------------------------
-- Misc option setting apply functions and stuff
-------------------------------------------------------

-- also used by drag&drop
local mirrors = {
	TOPLEFT = "TOPRIGHT",
	TOPRIGHT = "TOPLEFT",
	LEFT = "RIGHT",
	RIGHT = "LEFT",
	BOTTOMLEFT = "BOTTOMRIGHT",
	BOTTOMRIGHT = "BOTTOMLEFT",
	CENTER = "CENTER",
	TOP = "TOP",
	BOTTOM = "BOTTOM",
};

-- called by xml and configuration window
function module.BattleFrame_Options_Apply(self)
	local frame_name = self:GetName();
	
	local icon;
	local value = module.db.profile[frame_name.."_icon"];
	
	for pet = 1, PT.MAX_COMBAT_PETS do
		-- adjust pet icon anchors
		icon = _G[frame_name.."Pet"..pet].Button;
		icon:ClearAllPoints();
		icon:SetPoint(mirrors[value], icon:GetParent(), value, (value == "TOPLEFT" and -6 or 4), 0);
		
		-- reanchor the breed textures and breed strings
		icon.BreedText:ClearAllPoints();
		icon.BreedTexture:ClearAllPoints();
		
		if( value == "TOPLEFT" ) then
			icon.BreedText:SetPoint("BOTTOMRIGHT", 1, 2);
			icon.BreedTexture:SetPoint("BOTTOMLEFT", -4, -2);
		else
			icon.BreedText:SetPoint("BOTTOMLEFT", 0, 2);
			icon.BreedTexture:SetPoint("BOTTOMRIGHT", 4, -2);
		end
				
		-- adjust active highlight colors
		_G[frame_name.."Pet"..pet].activeBG:SetTexture(
			module.db.profile.animate_active_r,
			module.db.profile.animate_active_g,
			module.db.profile.animate_active_b,
			0.2 -- the alpha is not adjustable
		);
		
		-- cut off ability icon borders, or not
		if( module.db.profile.ability_zoom ) then
			for ab = 1, PT.MAX_PET_ABILITY do
				_G[frame_name.."Pet"..pet]["Ability"..ab].bg:SetTexCoord(0.078125, 0.921875, 0.078125, 0.921875);
			end
		else
			for ab = 1, PT.MAX_PET_ABILITY do
				_G[frame_name.."Pet"..pet]["Ability"..ab].bg:SetTexCoord(0, 1, 0, 1);
			end
		end
	end
	
	-- adjust frame background colors
	if( module.db.profile.bg ) then
		self.bg:SetTexture(module.db.profile.bg_r, module.db.profile.bg_g, module.db.profile.bg_b, module.db.profile.bg_a);
	else
		self.bg:SetTexture(0, 0, 0, 0.4);
	end
	
	-- adjust frame scale
	self:SetScale(module.db.profile.scale);
end

-----------------------------------
-- Drag&Drop and Positioning
-----------------------------------

-- Well, this Drag&Drop code is coded a little bit nooby, but it is really worth it.
-- I'm currently too lazy to code my own position frame etc., so I used a dirty self-implementation of AceGUI instead.
-- Blame me at wow-addons@grdn.eu or by PM :)

-- enemy frame mirrors the positions of the dragged frame
local mirror = true;
local function do_mirror(self, elapsed)
	-- throttle onUpdate calls
	self.dragElapsed = self.dragElapsed + elapsed;
	if( self.dragElapsed < 0.0417 ) then -- 24 times a second, should be almost fluent
		return;
	end		
	self.dragElapsed = 0;
	
	local point, relativeTo, relativePoint, x, y = self:GetPoint();
	
	-- re-position the enemy frame
	local enemy = get_enemy(self);
	
	-- we need to correct x since there is always an inaccuracy of appros 2 pixels
	x = x - 2;
	
	enemy:ClearAllPoints();
	enemy:SetPoint(mirrors[point], relativeTo, mirrors[point], -x, y);
end

-- called by xml
function module.BattleFrame_StartDrag(self) -- self is master frame
	self:StartMoving();
	
	if( mirror ) then
		self:SetScript("OnUpdate", do_mirror);
	end
end

-- after dragging stopped, we reanchor both frames to TOPLEFT points instead of LEFT, CENTER, etc.
-- also called from :OnEnable()
function module.BattleFrame_Reanchor(self, from_config)
	local left, top;
	local frame_name = self:GetName();
	
	if( from_config ) then
		left, top = module.db.profile[frame_name.."_x"], module.db.profile[frame_name.."_y"];
	else
		left, top = self:GetLeft(), self:GetTop();
		
		-- we must adjust top by both UI and frame scale
		top = ((_G.GetScreenHeight() * _G.UIParent:GetScale() / module.db.profile.scale) - top);
		
		module.db.profile[frame_name.."_x"] = left;
		module.db.profile[frame_name.."_y"] = top;
	end
	
	self:ClearAllPoints();
	self:SetPoint("TOPLEFT", _G.UIParent, "TOPLEFT", left, -top);
end

-- called by xml
function module.BattleFrame_StopDrag(self) -- self is master frame
	self:StopMovingOrSizing();
	
	if( mirror ) then
		self:SetScript("OnUpdate", nil);
		do_mirror(self, 0);
	end
	
	local enemy = get_enemy(self);
	module.BattleFrame_Reanchor(self);
	module.BattleFrame_Reanchor(enemy);
	
	-- set to true so the UI saves and restores their positions automatically
	self:SetUserPlaced(false);
	enemy:SetUserPlaced(false);
end

-- fake AceGUI widget with custom close callback, which acts as our container
-- we also must adjust little things so the container fit our needs.
local container = LibStub("AceGUI-3.0"):Create("Frame");
container:Hide(); -- damn auto show -.-
container:EnableResize(false); -- resizing is not allowed!

-- called when closing the little window
container:SetCallback("OnClose", function(widget, event)
	local appName = widget:GetUserData("appName");
	LibStub("AceConfigDialog-3.0").OpenFrames[appName] = nil;
	widget:Hide();
	
	-- unregister dragging mouse buttons
	_G[FRAME_PLAYER]:RegisterForDrag();
	_G[FRAME_ENEMY]:RegisterForDrag();
	
	-- hiding the frames during a battle is sort of annoying
	if( not _G.C_PetBattles.IsInBattle() ) then
		_G[FRAME_PLAYER]:Hide();
		_G[FRAME_ENEMY]:Hide();
		
		-- when not in a battle, call /pt to re-open the options frame
		pcall(_G.SlashCmdList["PT"]);
	end
end);

-- called by the "edit positions" button in the config window
local function OpenPositioning()
	LibStub("AceConfigDialog-3.0"):Open("PokemonTrainer_FrameCombatDisplay", container); -- container == our custom AceGUI container
	_G.InterfaceOptionsFrame:Hide();
	
	if( not _G.C_PetBattles.IsInBattle() ) then
		PT:ScanDummyPets();
	end
	
	for _,frame in ipairs(BattleFrames) do		
		frame:Show();
		frame:RegisterForDrag("LeftButton");
	end
end

-- called by :OnInitialize
local function get_pet_icon(info)
	return module.db.profile[info.arg.."_icon"];
end

local function set_pet_icon(info, value)
	module.db.profile[info.arg.."_icon"] = value;
	module.BattleFrame_Options_Apply(_G[info.arg]);
end
	
function module:GetPositionOptions()	
	local options = {
		name = L["More settings"],
		type = "group",
		args = {
			info = {
				type = "description",
				name = L["You can now move the frames by dragging them around."],
				order = 1,
			},
			spacer1 = { type = "description", name = "", order = 1.1 },
			mirror = {
				type = "toggle",
				name = L["Mirror frames"],
				desc = L["When moving a battle frame, the enemy frame gets mirrored to the opposite side of the screen."],
				order = 2,
				get = function()
					return mirror;
				end,
				set = function(_, value)
					mirror = value;
				end,
			},
			scale = {
				type = "range",
				name = L["Frame scale"],
				min = 0.5,
				max = 2.0,
				step = 0.05,
				order = 2.1,
				get = function()
					return module.db.profile.scale;
				end,
				set = function(_, value)
					module.db.profile.scale = value;
					module.BattleFrame_Options_Apply(_G[FRAME_PLAYER]);
					module.BattleFrame_Options_Apply(_G[FRAME_ENEMY]);
					do_mirror(_G[FRAME_ENEMY], 1); -- for styling purposes, scaling smells
				end,
			},
			spacer2 = { type = "description", name = "", order = 2.2 },
			bg = {
				type = "toggle",
				name = L["Override color"],
				desc = L["Battle frames are usually colored black. Enable to set your own color."],
				order = 3,
				get = function()
					return module.db.profile.bg;
				end,
				set = function(_, value)
					module.db.profile.bg = value;
					module.BattleFrame_Options_Apply(_G[FRAME_PLAYER]);
					module.BattleFrame_Options_Apply(_G[FRAME_ENEMY]);
				end,
			},
			bg_color = {
				type = "color",
				name = _G.COLOR,
				order = 4,
				hasAlpha = true,
				get = function()
					return module.db.profile.bg_r, module.db.profile.bg_g, module.db.profile.bg_b, module.db.profile.bg_a;
				end,
				set = function(_, r, g, b, a)
					module.db.profile.bg_r = r;
					module.db.profile.bg_g = g;
					module.db.profile.bg_b = b;
					module.db.profile.bg_a = a;
					module.BattleFrame_Options_Apply(_G[FRAME_PLAYER]);
					module.BattleFrame_Options_Apply(_G[FRAME_ENEMY]);
				end,
			},
			spacer3 = { type = "description", name = "", order = 4.1 },
			peticon1 = {
				type = "select",
				name = L["Player: pet icons"],
				order = 5,
				get = get_pet_icon,
				set = set_pet_icon,
				values = {
					["TOPLEFT"] = L["Left"],
					["TOPRIGHT"] = L["Right"],
				},
				arg = FRAME_PLAYER,
			},
			peticon2 = {
				type = "select",
				name = L["Enemy: pet icons"],
				order = 6,
				get = get_pet_icon,
				set = set_pet_icon,
				values = {
					["TOPLEFT"] = L["Left"],
					["TOPRIGHT"] = L["Right"],
				},
				arg = FRAME_ENEMY,
			},
		},
	};
	
	module.GetPositionOptions = nil;
	return options;
end

----------------------
-- Option Table
----------------------

local function is_disabled(info)
	return not module:IsEnabled() and true or not module.db.profile[info[#info].."_use"];
end

function module:GetOptions()	
	return {
		frame = {
			name = L["Frame-related options"],
			type = "group",
			inline = true,
			order = 2,
			args = {
				resize = {
					type = "toggle",
					name = L["Auto-resize"],
					desc = L["Battle frames are getting resized when players have less than three pets."],
					order = 1,
					get = function()
						return self.db.profile.resize;
					end,
					set = function(_, value)
						self.db.profile.resize = value;
					end,
				},
				drag = {
					type = "execute",
					name = L["More settings"],
					order = 2,
					func = OpenPositioning,
				},
				breeds = {
					type = "select",
					name = L["Display breeds"],
					desc = L["Perhaps, you heard of battle pet breeds before. Any pet has an assigned breed ID which defines which stats will grow larger than others while leveling up. Stats are health, power and speed. When this option is enabled, you can actually see pet breeds in during battles."],
					order = 3,
					get = function()
						return self.db.profile.breeds;
					end,
					set = function(_, value)
						self.db.profile.breeds = value;
					end,
					values = {
						[0] = _G.NONE,
						[1] = L["As text"],
						[2] = L["As image"],
						[3] = L["Both"],
					},
				},
			},
		},
		reorganize = {
			name = L["Reorganize pets by activity"],
			type = "group",
			inline = true,
			order = 3,
			args = {
				use = {
					type = "toggle",
					name = L["Enable"],
					desc = L["If enabled, active pets are displayed first."],
					order = 1,
					get = function()
						return self.db.profile.reorganize_use;
					end,
					set = function(_, value)
						self.db.profile.reorganize_use = value;
					end,
				},
				reorganize = {
					type = "toggle",
					name = L["Animate reorganizing"],
					desc = L["Reorganizing will take place with a cool animation."],
					order = 2,
					get = function()
						return self.db.profile.reorganize_ani;
					end,
					set = function(_, value)
						self.db.profile.reorganize_ani = value;
					end,
					disabled = is_disabled,
				},
			},
		},
		activepets = {
			name = L["Active and inactive pet highlightning"],
			type = "group",
			inline = true,
			order = 4,
			args = {
				active = {
					type = "toggle",
					name = L["Highlight background of active pets"],
					desc = L["The background of currently active pets will glow, if this option is activated."],
					order = 1,
					get = function()
						return self.db.profile.animate_active;
					end,
					set = function(_, value)
						self.db.profile.animate_active = value;
						-- update if currently in battle
						if( _G.C_PetBattles.IsInBattle() ) then
							module.BattleFrame_UpdateActivePetHighlight(_G[FRAME_PLAYER]);
							module.BattleFrame_UpdateActivePetHighlight(_G[FRAME_ENEMY]);
						end
					end,
				},
				active_color = {
					type = "color",
					name = _G.COLOR,
					order = 1.1,
					get = function()
						return self.db.profile.animate_active_r, self.db.profile.animate_active_g, self.db.profile.animate_active_b;
					end,
					set = function(_, r, g, b, a)
						self.db.profile.animate_active_r = r;
						self.db.profile.animate_active_g = g;
						self.db.profile.animate_active_b = b;
						module.BattleFrame_Options_Apply(_G[FRAME_PLAYER]);
						module.BattleFrame_Options_Apply(_G[FRAME_ENEMY]);
					end,
				},
				nactivealpha_use = {
					type = "toggle",
					name = L["Inactive pet alpha"],
					desc = L["Enable if you want to override the alpha of inactive pets. Set the new value on the right."],
					order = 2,
					get = function()
						return self.db.profile.nactivealpha_use;
					end,
					set = function(_, value)
						self.db.profile.nactivealpha_use = value;
						-- update if currently in battle
						if( _G.C_PetBattles.IsInBattle() ) then
							module.BattleFrame_UpdateActivePetHighlight(_G[FRAME_PLAYER]);
							module.BattleFrame_UpdateActivePetHighlight(_G[FRAME_ENEMY]);
						end
					end,
				},
				nactivealpha = {
					type = "range",
					name = L["Value"],
					min = 0.1,
					max = 0.9,
					step = 0.1,
					order = 3,
					get = function()
						return self.db.profile.nactivealpha;
					end,
					set = function(_, value)
						self.db.profile.nactivealpha = value;
						-- update if currently in battle
						if( _G.C_PetBattles.IsInBattle() ) then
							module.BattleFrame_UpdateActivePetHighlight(_G[FRAME_PLAYER]);
							module.BattleFrame_UpdateActivePetHighlight(_G[FRAME_ENEMY]);
						end
					end,
					disabled = is_disabled,
				},
			},
		},
		cooldowns = {
			name = L["Pet ability cooldowns"],
			type = "group",
			inline = true,
			order = 5,
			args = {
				text = {
					type = "toggle",
					name = L["Display rounds"],
					desc = L["Whether to show the cooldown of abilities on the buttons or not."],
					order = 1,
					get = function()
						return self.db.profile.cd_text;
					end,
					set = function(_, value)
						self.db.profile.cd_text = value;
					end,
				},
				text_color = {
					type = "color",
					name = _G.COLOR,
					order = 2,
					hasAlpha = true,
					get = function()
						return self.db.profile.cd_text_r, self.db.profile.cd_text_g, self.db.profile.cd_text_b, self.db.profile.cd_text_a;
					end,
					set = function(_, r, g, b, a)
						self.db.profile.cd_text_r = r;
						self.db.profile.cd_text_g = g;
						self.db.profile.cd_text_b = b;
						self.db.profile.cd_text_a = a;
					end,
				},
				highlight = {
					type = "toggle",
					name = L["Highlight"],
					desc = L["Highlights ability buttons with a color when they are on cooldown."],
					order = 3,
					get = function()
						return self.db.profile.cd_highlight;
					end,
					set = function(_, value)
						self.db.profile.cd_highlight = value;
					end,
				},
				highlight_color = {
					type = "color",
					name = _G.COLOR,
					order = 4,
					hasAlpha = true,
					get = function()
						return self.db.profile.cd_highlight_r, self.db.profile.cd_highlight_g, self.db.profile.cd_highlight_b, self.db.profile.cd_highlight_a;
					end,
					set = function(_, r, g, b, a)
						self.db.profile.cd_highlight_r = r;
						self.db.profile.cd_highlight_g = g;
						self.db.profile.cd_highlight_b = b;
						self.db.profile.cd_highlight_a = a;
					end,
				},
				ability_zoom = {
					type = "toggle",
					name = L["Cut off ability icon borders by zooming in"],
					desc = L["Removes the borders from any ability icon displayed by PT. Only for styling purposes."],
					order = 5,
					width = "full",
					get = function()
						return self.db.profile.ability_zoom;
					end,
					set = function(_, value)
						self.db.profile.ability_zoom = value;
						module.BattleFrame_Options_Apply(_G[FRAME_PLAYER]);
						module.BattleFrame_Options_Apply(_G[FRAME_ENEMY]);
					end,
				},
			},
		},
		
	};
end