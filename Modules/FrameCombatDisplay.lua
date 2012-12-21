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
			peticon_PTPlayer = "TOPLEFT",
			peticon_PTEnemy = "TOPRIGHT",
			scale = 1,
			resize = true,
			animate_active = false,
			animate_active_r = 0.99,
			animate_active_g = 0.82,
			animate_active_b = 0,
			bg = false,
			bg_r = 0.30,
			bg_g = 0.30,
			bg_b = 0.30,
			bg_a = 0.48,
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
	-- register events
	for _,frame in ipairs(BattleFrames) do
		frame:RegisterEvent("PET_BATTLE_OPENING_START");
		frame:RegisterEvent("PET_BATTLE_OVER");
		frame:RegisterEvent("PET_BATTLE_PET_ROUND_PLAYBACK_COMPLETE");
		frame:RegisterEvent("PET_BATTLE_PET_CHANGED");
		frame:RegisterEvent("PET_BATTLE_HEALTH_CHANGED");
		frame:RegisterEvent("PET_BATTLE_MAX_HEALTH_CHANGED");
		
		for pet = 1, #frame.petFrames do
			for ab = 1, PT.MAX_PET_ABILITY do
				-- for every ability button
				_G[frame.petFrames[pet]:GetName()]["Ability"..ab]:RegisterEvent("PET_BATTLE_PET_ROUND_PLAYBACK_COMPLETE");
			end
		end
	end
	
	-- setup hooks
	self:SecureHookScript(_G.PetBattleFrame.BottomFrame.PetSelectionFrame, "OnShow", "Hook_PetSelection_Show");
	self:SecureHookScript(_G.PetBattleFrame.BottomFrame.PetSelectionFrame, "OnHide", "Hook_PetSelection_Hide");
	for pet = 1, PT.MAX_COMBAT_PETS do
		self:SecureHookScript(_G.PetBattleFrame.BottomFrame.PetSelectionFrame["Pet"..pet], "OnEnter", "Hook_PetSelection_Pet_Enter");
		self:SecureHookScript(_G.PetBattleFrame.BottomFrame.PetSelectionFrame["Pet"..pet], "OnLeave", "Hook_PetSelection_Pet_Leave");
		self:SecureHookScript(_G.PetBattleFrame.BottomFrame.PetSelectionFrame["Pet"..pet], "OnClick", "Hook_PetSelection_Hide");
	end
end

function module:OnDisable()
	-- unregister events
	for _,frame in ipairs(BattleFrames) do
		frame:UnregisterEvent("PET_BATTLE_OPENING_START");
		frame:UnregisterEvent("PET_BATTLE_OVER");
		frame:UnregisterEvent("PET_BATTLE_PET_ROUND_PLAYBACK_COMPLETE");
		frame:UnregisterEvent("PET_BATTLE_PET_CHANGED");
		frame:UnregisterEvent("PET_BATTLE_HEALTH_CHANGED");
		frame:UnregisterEvent("PET_BATTLE_MAX_HEALTH_CHANGED");
		
		for pet = 1, #frame.petFrames do
			for ab = 1, PT.MAX_PET_ABILITY do
				-- for every ability button
				_G[frame.petFrames[pet]:GetName()]["Ability"..ab]:UnregisterEvent("PET_BATTLE_PET_ROUND_PLAYBACK_COMPLETE");
			end
		end
	end
	
	-- unhook hooks
	self:UnhookAll();
	--self:Unhook(_G.PetBattleFrame.BottomFrame.PetSelectionFrame, "OnShow");
	--self:Unhook(_G.PetBattleFrame.BottomFrame.PetSelectionFrame, "OnHide");
	--for pet = 1, PT.MAX_COMBAT_PETS do
	--	self:Unhook(_G.PetBattleFrame.BottomFrame.PetSelectionFrame["Pet"..pet], "OnEnter");
	--	self:Unhook(_G.PetBattleFrame.BottomFrame.PetSelectionFrame["Pet"..pet], "OnLeave");
	--	self:Unhook(_G.PetBattleFrame.BottomFrame.PetSelectionFrame["Pet"..pet], "OnClick");
	--end
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
		
		for pet = 1, PT.PlayerInfo.numPets do
			fs = _G["PTPlayerPet"..pet].Button.Level;
			font, size, outline = fs:GetFont();
			fs:SetFont(font, FONT_LEVEL_DEFAULT + (pet == current_pet and FONT_LEVEL_ADJUST or 0), outline);
		end
	end
	
	-- Sets all enemy levels to either default size or adjusted size
	local function adjust_enemy_fonts(bigger)
		local font, size, outline;
		local fs;
		
		for pet = 1, PT.EnemyInfo.numPets do
			fs = _G["PTEnemyPet"..pet].Button.Level;
			font, size, outline = fs:GetFont();
			fs:SetFont(font, FONT_LEVEL_DEFAULT + (bigger and FONT_LEVEL_ADJUST or 0), outline);
		end
	end
	
	-- colorizes all enemy levels based on the given level (= hovered player pet level)
	local function adjust_color(level)
		local r, g, b;
		
		for pet = 1, PT.EnemyInfo.numPets do
			r, g, b = PT:GetDifficultyColor(level, PT.EnemyInfo[pet].level);
			_G["PTEnemyPet"..pet].Button.Level:SetTextColor(r, g, b, 1);
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

local function get_enemy(self)
	return self:GetName() == FRAME_PLAYER and _G[FRAME_ENEMY] or _G[FRAME_PLAYER];
end

local function get_frame(side)
	return side == PT.PLAYER and _G[FRAME_PLAYER] or _G[FRAME_ENEMY];
end

local function BattleFrame_Resize(self)
	-- resizing may be disabled
	if( not module.db.profile.resize ) then
		return;
	end
	
	local frame_name = self:GetName();
	
	local pet_y;
	local y = FRAME_LINE_HEIGHT; -- header frame  
	
	local x = 1 + (self.enemy.numPets + 1) * (FRAME_BUTTON_WIDTH + SPACE_HORIZONTAL) - SPACE_HORIZONTAL;
	
	for pet = 1, PT.MAX_COMBAT_PETS do
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
-- EVENTUALLY convert this to a core function since Possible may need it too
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

-- called by xml
function module.BattleFrame_OnEvent(self, event, ...)
	if( event == "PET_BATTLE_OPENING_START" ) then
		PT:ScanPets();
		BattleFrame_Resize(self);
		module.BattleFrame_Initialize(self);
		module.BattleFrame_UpdateBattleButtons(self);
		module.BattleFrame_UpdateActivePetHighlight(self);
		BattleFrame_Pets_Reorganize_Init(self, false);
		self:FadeIn();
	elseif( event == "PET_BATTLE_OVER" ) then
		self:FadeOut();
	elseif( event == "PET_BATTLE_PET_ROUND_PLAYBACK_COMPLETE" ) then
		PT:RoundUpPets();
		module.BattleFrame_UpdateBattleButtons(self);
		--PT.BattleFrame_UpdateActivePetHighlight(self);
	elseif( event == "PET_BATTLE_PET_CHANGED" ) then
		PT:RoundUpPets();
		module.BattleFrame_UpdateActivePetHighlight(self);
		
		if( select(1, ...) == self:GetID() ) then
			if( self.firstRound ) then
				self.firstRound = nil;
			else
				BattleFrame_Pets_Reorganize_Init(self);
			end
		end
	elseif( event == "PET_BATTLE_HEALTH_CHANGED" or event == "PET_BATTLE_MAX_HEALTH_CHANGED" ) then
		local side, pet = ...;
		if( side == self:GetID() and pet == self.player.activePet ) then
			PT:RoundUpPets();
			module.BattleFrame_UpdateHealthState(self);
		end
	else
		--@do-not-package@
		-- this should never happen. god, please.
		print("Uncatched event on frame: "..self:GetName(), event, ...);
		--@end-do-not-package@
	end
end

--------------------------
-- Frame Visibility
--------------------------

local function call_tfunc(key, func)
	local result, err = loadstring("_G."..key..":"..func.."()");
	return type(result) == "function" and pcall(result) or nil;
end

local function BattleFrame_SetColumnVisibility(f, column, func)
	-- we just need the frame name here
	f = f:GetName();
	
	call_tfunc(f.."Header.Enemy"..column, func);
	
	for pet = 1, 3 do
		call_tfunc(f.."Pet"..pet..".Speed"..column, func);
		call_tfunc(f.."Pet"..pet..".SpeedBG"..column, func);
		call_tfunc(f.."Pet"..pet..".Ability1.Bonus"..column, func);
		call_tfunc(f.."Pet"..pet..".Ability2.Bonus"..column, func);
		call_tfunc(f.."Pet"..pet..".Ability3.Bonus"..column, func);
	end
end

local function BattleFrame_SetRowVisibility(self, pet, ab, func)
	local f = self:GetName();
	
	for i = 1, self.enemy.numPets do
		call_tfunc(f.."Pet"..pet..".Ability"..ab, func);
	end
end

----------------------------------
-- Battle Frame: Initialize
----------------------------------

-- called by EH when a battle starts
function module.BattleFrame_Initialize(self)	
	local enemy = get_enemy(self);
	local color;
	
	local frame_name = self:GetName();
	
	for pet = 1, PT.MAX_COMBAT_PETS do
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
			BattleFrame_SetColumnVisibility(enemy, pet, "Show");
			
			-- setup ability buttons
			module.BattleFrame_SetupAbilityButtons(self, pet);
			
			-- display pet frame
			_G[frame_name.."Pet"..pet]:Show();
		else
			-- hide pet ability frame
			_G[frame_name.."Pet"..pet]:Hide();
			
			-- hide pet column on enemy frame
			BattleFrame_SetColumnVisibility(enemy, pet, "Hide");
		end
	end
	
	-- set health state
	module.BattleFrame_UpdateHealthState(self);
end

---------------------------------------------
-- Battle Frame: Setup Ability Buttons
---------------------------------------------

function module.BattleFrame_SetupAbilityButtons(self, pet)
	local abID, abName, abIcon;

	for ab = 1, PT.MAX_PET_ABILITY do
		if( ab <= self.player[pet].numAbilities ) then
			abID, abName, abIcon = _G.C_PetBattles.GetAbilityInfoByID( self.player[pet]["ab"..ab] );
			
			-- set ability icon
			_G[self:GetName().."Pet"..pet]["Ability"..ab]:SetNormalTexture(abIcon);
			
			-- show ability row on self
			BattleFrame_SetRowVisibility(self, pet, ab, "Show");
			
			-- setup vulnerability bonus buttons
			module.BattleFrame_SetupVulnerabilityButtons(self, pet, ab);
		else
			-- hide ability row on self
			BattleFrame_SetRowVisibility(self, pet, ab, "Hide");
		end
	end
end

function module.BattleFrame_SetupVulnerabilityButtons(self, pet, ab)
	local abID, abName, abIcon, abMaxCD, abDesc, abNumTurns, abType, noStrongWeak = _G.C_PetBattles.GetAbilityInfoByID( self.player[pet]["ab"..ab] );
	
	for enemPet = 1, self.enemy.numPets do
		_G[self:GetName().."Pet"..pet]["Ability"..ab]["Bonus"..enemPet]:SetTexture( PT:GetTypeBonusIcon(abType, self.enemy[enemPet].type, noStrongWeak) );
	end
end

function module.BattleFrame_UpdateBattleButtons(self)
	local speed, flying;
	local available, cdleft;
	
	local frame_name = self:GetName();
	
	for pet = 1, self.player.numPets do
		-- iterate through enemy pets and (re-)calculate speed bonuses
		for enemPet = 1, self.enemy.numPets do
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
	
	for pet = 1, self.player.numPets do
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

---------------------------------------------------------
-- Highlighting, Reorganizing, Animation Functions
---------------------------------------------------------

function module.BattleFrame_UpdateActivePetHighlight(self)
	local r, g, b;
	
	local frame_name = self:GetName();
	
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

function BattleFrame_Pets_Reorganize_Exec(self, animate) -- self is PT master frame
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
			--f["animShow"..(f:GetID() == self.player.activePet and "" or "_h")]:Play();
			f.animShow:Play();
		else
			module.BattleFrame_Pet_ShowFinished(f.animShow); -- dummy
		end
	end
end

-- little sort function which sorts the pet frames, dead pets are displayed last
local function pets_sort_dead_last(pet1, pet2)
	local dead1 = pet1:GetParent().player[pet1:GetID()].dead;
	local dead2 = pet2:GetParent().player[pet2:GetID()].dead;
	
	if( dead1 and not dead2 ) then
		return false;
	elseif( dead2 and not dead1 ) then
		return true;
	else
		return pet1:GetID() > pet2:GetID(); -- fall back to pet ID (1, 2, 3)
	end
end

function BattleFrame_Pets_Reorganize_Init(self, animate) -- self is PT master frame
	animate = (type(animate) == "nil" or animate == true) and true or false; -- nil/true = animate, false = do not animate
	
	-- may be disabled in configuration
	if( not module.db.profile.reorganize_use ) then
		return;
	else
		-- animation can be toggled in configuration
		if( animate and not module.db.profile.reorganize_ani ) then
			animate = false;
		end
	end
	
	local active = self.player.activePet;
	local rem = 0;
	
	for i,f in ipairs(self.petFrames) do
		if( animate ) then
			--f["animHide"..(f:GetID() == active and "" or "_h")]:Play();
			f.animHide:Play();
		end
		
		if( f:GetID() == active ) then
			rem = i;
		end
	end
	
	local frame = table.remove(self.petFrames, rem);
	table.sort(self.petFrames, pets_sort_dead_last); -- simply sort the other two pets for dead
	table.insert(self.petFrames, 1, frame);
	
	if( not animate ) then
		BattleFrame_Pets_Reorganize_Exec(self, animate);
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
		BattleFrame_Pets_Reorganize_Exec(master);
	end
end

-- called by xml
function module.BattleFrame_Pet_ShowFinished(self) -- self is animation frame
	local parent = self:GetParent(); -- pet frame
	local alpha = module.db.profile.nactivealpha_use and module.db.profile.nactivealpha or 1;
	parent:SetAlpha( parent:GetID() == parent:GetParent().player.activePet and 1 or alpha );
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
	local value = module.db.profile["peticon_"..frame_name];
	
	for pet = 1, PT.MAX_COMBAT_PETS do
		-- adjust pet icon anchors
		icon = _G[frame_name.."Pet"..pet].Button;
		icon:ClearAllPoints();
		icon:SetPoint(mirrors[value], icon:GetParent(), value, (value == "TOPLEFT" and -6 or 4), 0);
		
		-- adjust active highlight colors
		_G[frame_name.."Pet"..pet].activeBG:SetTexture(
			module.db.profile.animate_active_r,
			module.db.profile.animate_active_g,
			module.db.profile.animate_active_b,
			0.2 -- the alpha is not adjustable
		);
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

-- called by xml
function module.BattleFrame_StopDrag(self) -- self is master frame
	self:StopMovingOrSizing();
	
	if( mirror ) then
		self:SetScript("OnUpdate", nil);
		do_mirror(self, 0);
	end
	
	-- set to true so the UI saves and restores their positions automatically
	self:SetUserPlaced(true);
	get_enemy(self):SetUserPlaced(true);
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
	_G.PTPlayer:RegisterForDrag();
	_G.PTEnemy:RegisterForDrag();
	
	-- hiding the frames during a battle is sort of annoying
	if( not _G.C_PetBattles.IsInBattle() ) then
		_G.PTPlayer:Hide();
		_G.PTEnemy:Hide();
		
		-- when not in a battle, call /pt to re-open the options frame
		pcall(_G.SlashCmdList["PT"]);
	end
end);

-- called by the "edit positions" button in the config window
local function OpenPositioning()
	LibStub("AceConfigDialog-3.0"):Open("PokemonTrainer_FrameCombatDisplay", container); -- container == our custom AceGUI container
	_G.InterfaceOptionsFrame:Hide();
	
	_G.PTPlayer:Show();
	_G.PTEnemy:Show();
	
	-- left button for dragging should be enough, I think
	_G.PTPlayer:RegisterForDrag("LeftButton");
	_G.PTEnemy:RegisterForDrag("LeftButton");
end

-- called by :OnInitialize
function module:GetPositionOptions()
	local function get_pet_icon(info)
		return module.db.profile["peticon_"..info.arg];
	end
	
	local function set_pet_icon(info, value)
		module.db.profile["peticon_"..info.arg] = value;
		module.BattleFrame_Options_Apply(_G[info.arg]);
	end
	
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
					module.BattleFrame_Options_Apply(_G.PTPlayer);
					module.BattleFrame_Options_Apply(_G.PTEnemy);
					do_mirror(_G.PTEnemy, 1); -- for styling purposes, scaling smells
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
					module.BattleFrame_Options_Apply(_G.PTPlayer);
					module.BattleFrame_Options_Apply(_G.PTEnemy);
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
					module.BattleFrame_Options_Apply(_G.PTPlayer);
					module.BattleFrame_Options_Apply(_G.PTEnemy);
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
				arg = "PTPlayer",
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
				arg = "PTEnemy",
			},
		},
	};
	
	module.GetPositionOptions = nil;
	return options;
end

----------------------
-- Option Table
----------------------

function module:GetOptions()
	local function is_disabled(info)
		return not module:IsEnabled() and true or not module.db.profile[info[#info].."_use"];
	end
	
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
							module.BattleFrame_UpdateActivePetHighlight(_G.PTPlayer);
							module.BattleFrame_UpdateActivePetHighlight(_G.PTEnemy);
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
						module.BattleFrame_Options_Apply(_G.PTPlayer);
						module.BattleFrame_Options_Apply(_G.PTEnemy);
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
							module.BattleFrame_UpdateActivePetHighlight(_G.PTPlayer);
							module.BattleFrame_UpdateActivePetHighlight(_G.PTEnemy);
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
							module.BattleFrame_UpdateActivePetHighlight(_G.PTPlayer);
							module.BattleFrame_UpdateActivePetHighlight(_G.PTEnemy);
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
			},
		},
		
	};
end