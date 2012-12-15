-----------------------------------
-- Setting up scope, upvalues and libs
-----------------------------------

local AddonName, PT = ...;
local module = PT:NewModule("FrameCombatDisplay");

local L = LibStub("AceLocale-3.0"):GetLocale(AddonName);

local _G = _G;

----------------------
-- Variables
----------------------

module.order = 1;
module.displayName = function() return (module:IsEnabled() and "|cff00ff00%s|r" or "|cffff0000%s|r"):format(L["Display: Frames"]) end
module.desc = L["True frame based combat display for Pet Battles and the next generation of Pokemon Trainer. Disable it if you want to use the tooltip based combat display."];
module.noEnableButton = true;

local FRAME_PLAYER = "PTPlayer";
local FRAME_ENEMY  = "PTEnemy";

-- xml values
local FRAME_BUTTON_WIDTH = 22;
local FRAME_LINE_HEIGHT = 22;
local SPACE_PETS = 5;
local SPACE_ABILITIES = 2;
local SPACE_HORIZONTAL = 3;

-------------------------
-- Module Handling
-------------------------

function module:OnInitialize()
	self.db = PT.db:RegisterNamespace("FrameCombatDisplay", {
		profile = {
			enabled = true,
			resize = true,
			bg = false,
			bg_r = 0.44,
			bg_g = 0.70,
			bg_b = 0.23,
			bg_a = 0.35,
			reorganize_use = true,
			reorganize_ani = true,
			nactivealpha_use = true,
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

	if( not self.db.profile.enabled ) then
		self:SetEnabledState(false);
	end
	
	-- This is a small "positioning" window which is shown when repositioning the battle frames
	LibStub("AceConfig-3.0"):RegisterOptionsTable(AddonName.."_"..self:GetName(), self.GetPositionOptions);
	LibStub("AceConfigDialog-3.0"):SetDefaultSize(AddonName.."_"..self:GetName(), 374, 100);
end

function module:OnEnable()
	local frame;
	
	for i = 1, 2 do -- too lazy to put stuff into a separate function
		frame = _G[i == 1 and FRAME_PLAYER or FRAME_ENEMY];
		
		frame:RegisterEvent("PET_BATTLE_OPENING_START");
		frame:RegisterEvent("PET_BATTLE_OVER");
		frame:RegisterEvent("PET_BATTLE_PET_ROUND_PLAYBACK_COMPLETE");
		frame:RegisterEvent("PET_BATTLE_PET_CHANGED");
		frame:RegisterEvent("PET_BATTLE_HEALTH_CHANGED");
		frame:RegisterEvent("PET_BATTLE_MAX_HEALTH_CHANGED");
		
		for pet = 1, #frame.petFrames do
			for ab = 1, PT.MAX_PET_ABILITY do
				-- for every ability button
				_G[frame.petFrames[pet]:GetName().."Ability"..ab]:RegisterEvent("PET_BATTLE_PET_ROUND_PLAYBACK_COMPLETE");
			end
		end
		
		-- encolor background
		if( self.db.profile.bg ) then
			frame.bg:SetTexture(self.db.profile.bg_r, self.db.profile.bg_g, self.db.profile.bg_b, self.db.profile.bg_a);
		else
			frame.bg:SetTexture(0, 0, 0, 0.4);
		end
	end
end

function module:OnDisable()
	local frame;
	
	for i = 1, 2 do -- too lazy to put stuff into a separate function
		frame = _G[i == 1 and FRAME_PLAYER or FRAME_ENEMY];
		
		frame:UnregisterEvent("PET_BATTLE_OPENING_START");
		frame:UnregisterEvent("PET_BATTLE_OVER");
		frame:UnregisterEvent("PET_BATTLE_PET_ROUND_PLAYBACK_COMPLETE");
		frame:UnregisterEvent("PET_BATTLE_PET_CHANGED");
		frame:UnregisterEvent("PET_BATTLE_HEALTH_CHANGED");
		frame:UnregisterEvent("PET_BATTLE_MAX_HEALTH_CHANGED");
		
		for pet = 1, #frame.petFrames do
			for ab = 1, PT.MAX_PET_ABILITY do
				-- for every ability button
				_G[frame.petFrames[pet]:GetName().."Ability"..ab]:UnregisterEvent("PET_BATTLE_PET_ROUND_PLAYBACK_COMPLETE");
			end
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
	
	local y = FRAME_LINE_HEIGHT; -- header frame  
	local pet_y;
   
	for pet = 1, 3 do
  	if( not(pet > self.player.numPets) ) then
    	pet_y = FRAME_LINE_HEIGHT; -- type and speed icons
         
			for ab = 1, self.player[pet].numAbilities do
      	pet_y = pet_y + FRAME_LINE_HEIGHT + SPACE_ABILITIES;
			end
         
			y = y + pet_y + SPACE_PETS;
			_G[self:GetName().."Pet"..pet]:SetHeight(pet_y);
		end
	end
   
	self:SetWidth((self.enemy.numPets + 1) * (FRAME_BUTTON_WIDTH + SPACE_HORIZONTAL) - SPACE_HORIZONTAL);
	self:SetHeight(y);
end

-- returns true if on the left side of the screen, false otherwise
-- called by xml for displaying tooltips
-- EVENTUALLY convert this to a core function since Possible may need it too
function PT.BattleFrame_GetTooltipPosition()
	return _G.GetCursorPosition() < (_G.GetScreenWidth() * _G.UIParent:GetEffectiveScale() / 2);
end

-------------------------------
-- On Loading and Events
-------------------------------

function PT.BattleFrame_OnLoad(self)
	self:SetID( self:GetName() == FRAME_PLAYER and PT.PLAYER or PT.ENEMY );
	
	-- we store the table ID's for further use
	if( self:GetID() == PT.PLAYER ) then
		self.player = PT.PlayerInfo;
		self.enemy  = PT.EnemyInfo;
	else
		self.player = PT.EnemyInfo;
		self.enemy  = PT.PlayerInfo;
	end
	
	-- animations
	self.petFrames = {
		_G[self:GetName().."Pet1"],
		_G[self:GetName().."Pet2"],
		_G[self:GetName().."Pet3"],
	};
end

function PT.BattleFrame_OnEvent(self, event, ...)	
	if( event == "PET_BATTLE_OPENING_START" ) then
		PT:ScanPets();
		BattleFrame_Resize(self);
		PT.BattleFrame_Initialize(self);
		PT.BattleFrame_UpdateBattleButtons(self);
		PT.BattleFrame_UpdateActivePetHighlight(self);
		BattleFrame_Pets_Reorganize_Init(self, false);
		self:Show();
	elseif( event == "PET_BATTLE_OVER" ) then
		self:Hide();
	elseif( event == "PET_BATTLE_PET_ROUND_PLAYBACK_COMPLETE" ) then
		PT:RoundUpPets();
		PT.BattleFrame_UpdateBattleButtons(self);
		--PT.BattleFrame_UpdateActivePetHighlight(self);
	elseif( event == "PET_BATTLE_PET_CHANGED" ) then
		PT:RoundUpPets();
		PT.BattleFrame_UpdateActivePetHighlight(self);
		
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
			PT.BattleFrame_UpdateHealthState(self);
		end
	else
		print(self:GetName(), event, ...);
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
	
	call_tfunc(f.."HeaderEnemy"..column, func);
	
	for pet = 1, 3 do
		call_tfunc(f.."Pet"..pet.."Button.Bonus"..column, func);
		call_tfunc(f.."Pet"..pet.."Button.underlay"..column, func);
		call_tfunc(f.."Pet"..pet.."Ability1.Bonus"..column, func);
		call_tfunc(f.."Pet"..pet.."Ability2.Bonus"..column, func);
		call_tfunc(f.."Pet"..pet.."Ability3.Bonus"..column, func);
	end
end

local function BattleFrame_SetRowVisibility(self, pet, ab, func)
	local f = self:GetName();
	
	for i = 1, self.enemy.numPets do
		call_tfunc(f.."Pet"..pet.."Ability"..ab, func);
	end
end

----------------------------------
-- Battle Frame: Initialize
----------------------------------

function PT.BattleFrame_Initialize(self)	
	local enemy = get_enemy(self);
	local color;
	
	for pet = 1, PT.MAX_COMBAT_PETS do
		if( pet <= self.player.numPets ) then
			-- setting up pet icons
			_G[self:GetName().."Pet"..pet.."Button"].Icon:SetTexture(self.player[pet].icon);
			_G[self:GetName().."Pet"..pet.."ButtonType"]:SetTexture(PT:GetTypeIcon(self.player[pet].type));
			_G[enemy:GetName().."HeaderEnemy"..pet].Icon:SetTexture(self.player[pet].icon);
			
			-- encolor pet icon borders
			color = _G.ITEM_QUALITY_COLORS[self.player[pet].quality or 0];
			_G[self:GetName().."Pet"..pet.."Button"].Border:SetVertexColor(color.r, color.g, color.b, 1);
			_G[enemy:GetName().."HeaderEnemy"..pet].Border:SetVertexColor(color.r, color.g, color.b, 1);
			
			-- set level strings
			_G[self:GetName().."Pet"..pet.."Button"].Level:SetText( self.player[pet].level );
			
			-- display pet column on enemy frame
			BattleFrame_SetColumnVisibility(enemy, pet, "Show");
			
			-- setup ability buttons
			PT.BattleFrame_SetupAbilityButtons(self, pet);
			
			-- display pet frame
			_G[self:GetName().."Pet"..pet]:Show();
		else
			-- hide pet ability frame
			_G[self:GetName().."Pet"..pet]:Hide();
			
			-- hide pet column on enemy frame
			BattleFrame_SetColumnVisibility(enemy, pet, "Hide");
		end
	end
	
	-- set health state
	PT.BattleFrame_UpdateHealthState(self);
end

---------------------------------------------
-- Battle Frame: Setup Ability Buttons
---------------------------------------------

function PT.BattleFrame_SetupAbilityButtons(self, pet)
	local abID, abName, abIcon;

	for ab = 1, PT.MAX_PET_ABILITY do
		if( ab <= self.player[pet].numAbilities ) then
			abID, abName, abIcon = _G.C_PetBattles.GetAbilityInfoByID( self.player[pet]["ab"..ab] );
			
			-- set ability icon
			_G[self:GetName().."Pet"..pet.."Ability"..ab]:SetNormalTexture(abIcon);
			
			-- show ability row on self
			BattleFrame_SetRowVisibility(self, pet, ab, "Show");
			
			-- setup vulnerability bonus buttons
			PT.BattleFrame_SetupVulnerabilityButtons(self, pet, ab);
		else
			-- hide ability row on self
			BattleFrame_SetRowVisibility(self, pet, ab, "Hide");
		end
	end
end

function PT.BattleFrame_SetupVulnerabilityButtons(self, pet, ab)
	local abID, abName, abIcon, abMaxCD, abDesc, abNumTurns, abType, noStrongWeak = _G.C_PetBattles.GetAbilityInfoByID( self.player[pet]["ab"..ab] );
	
	for enemPet = 1, self.enemy.numPets do
		_G[self:GetName().."Pet"..pet.."Ability"..ab]["Bonus"..enemPet]:SetTexture( PT:GetTypeBonusIcon(abType, self.enemy[enemPet].type, noStrongWeak) );
	end
end

function PT.BattleFrame_UpdateBattleButtons(self)
	local speed, flying;
	local available, cdleft;
	
	for pet = 1, self.player.numPets do
		-- iterate through enemy pets and (re-)calculate speed bonuses
		for enemPet = 1, self.enemy.numPets do
			-- update speed buttons
			speed, better_with_flying = PT:GetSpeedBonus( self.player[pet], self.enemy[enemPet] );
			
			if( speed == PT.BONUS_SPEED_FASTER ) then -- faster
				_G[self:GetName().."Pet"..pet.."Button"]["Bonus"..enemPet]:SetVertexColor(1, 1, 0, 1);
			elseif( speed == PT.BONUS_SPEED_EQUAL ) then -- equal
				_G[self:GetName().."Pet"..pet.."Button"]["Bonus"..enemPet]:SetVertexColor(0.6, 0.6, 0.6, 1);
			elseif( speed == PT.BONUS_SPEED_SLOWER ) then -- slower
				if( better_with_flying ) then -- would be faster with active flying bonus
					_G[self:GetName().."Pet"..pet.."Button"]["Bonus"..enemPet]:SetVertexColor(1, 0, 0, 1);
				else
					_G[self:GetName().."Pet"..pet.."Button"]["Bonus"..enemPet]:SetVertexColor(0.1, 0.1, 0.1, 1);
				end
			end
		end -- end for enemPet
	end -- end for pet
end

function PT.BattleFrame_UpdateHealthState(self)
	local enemy = get_enemy(self);
	
	for pet = 1, self.player.numPets do
		if( self.player[pet].dead ) then
			_G[self:GetName().."Pet"..pet.."Button"].Dead:Show();
			_G[self:GetName().."Pet"..pet.."Button"].Border:Hide();
			_G[enemy:GetName().."HeaderEnemy"..pet].Dead:Show();
			_G[enemy:GetName().."HeaderEnemy"..pet].Border:Hide();
		else
			_G[self:GetName().."Pet"..pet.."Button"].Dead:Hide();
			_G[self:GetName().."Pet"..pet.."Button"].Border:Show();
			_G[enemy:GetName().."HeaderEnemy"..pet].Dead:Hide();
			_G[enemy:GetName().."HeaderEnemy"..pet].Border:Show();
		end
	end
end

---------------------------------------------------------
-- Highlighting, Reorganizing, Animation Functions
---------------------------------------------------------

function PT.BattleFrame_UpdateActivePetHighlight(self)
	local r, g, b;
	
	for pet = 1, self.player.numPets do
		-- sets the level color in relation to the active enemy pet
		-- UPDATE NOTICE: there must be an option to reverse the coloring since it may be confusing
		r, g, b = PT:GetDifficultyColor(self.enemy[self.enemy.activePet], self.player[pet]);
		_G[self:GetName().."Pet"..pet.."Button"].Level:SetTextColor(r, g, b, 1);
		
		-- set alpha
		if( module.db.profile.nactivealpha_use ) then
			_G[self:GetName().."Pet"..pet]:SetAlpha( not(pet == self.player.activePet) and module.db.profile.nactivealpha or 1 );
		else
			_G[self:GetName().."Pet"..pet]:SetAlpha(1);
		end
	end
end

function BattleFrame_Pets_Reorganize_Exec(self, animate) -- self is PT master frame
	animate = type(animate) == "nil" and true or false;
	animate = animate and module.db.profile.reorganize_ani and true or false;
	
	for i,f in ipairs(self.petFrames) do
		f:ClearAllPoints();
		
		if( i == 1 ) then
			f:SetPoint("TOPLEFT", self:GetName().."Header", "BOTTOMLEFT", 0, -6);
		else
			f:SetPoint("TOPLEFT", self.petFrames[i - 1], "BOTTOMLEFT", 0, -SPACE_PETS);
		end
		
		if( animate ) then
			f["animShow"..(f:GetID() == self.player.activePet and "" or "_h")]:Play();
		else
			PT.BattleFrame_Pet_ShowFinished(f.animShow); -- dummy
		end
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
			f["animHide"..(f:GetID() == active and "" or "_h")]:Play();
		end
		
		if( f:GetID() == active ) then
			rem = i;
		end
	end
	
	local frame = table.remove(self.petFrames, rem);
	table.insert(self.petFrames, 1, frame);
	
	if( not animate ) then
		BattleFrame_Pets_Reorganize_Exec(self, animate);
	end
end

-- called by xml
function PT.BattleFrame_Pet_HideFinished(self) -- self is animation frame
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
function PT.BattleFrame_Pet_ShowFinished(self) -- self is animation frame
	local parent = self:GetParent(); -- pet frame
	local alpha = module.db.profile.nactivealpha_use and module.db.profile.nactivealpha or 1;
	parent:SetAlpha( parent:GetID() == parent:GetParent().player.activePet and 1 or alpha );
end

-------------------
-- Drag&Drop
-------------------

-- Well, this Drag&Drop code is coded a little bit nooby, but it really is worth it.
-- I'm currently too lazy to code my own position frame etc., so I used AceGUI instead.
-- ToDo: eventually rework the OnUpdate handler since its really expensive in CPU usage.

local OpenPositioning;
do	
	local mirror = true;
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
	
	-- enemy frame mirrors the positions of the dragged frame
	local function do_mirror(self, elapsed)
		-- throttle onUpdate calls
		self.dragElapsed = self.dragElapsed + elapsed;
		if( self.dragElapsed < 0.0417 ) then -- 24 times a second, should me almost fluent
			return;
		end		
		self.dragElapsed = 0;
		
		-- the left icon is not allowed to get out of screen
		local point, relativeTo, relativePoint, x, y = self:GetPoint();
		if( x < 36 ) then
			x = 36;
			self:ClearAllPoints();
			self:SetPoint(point, relativeTo, relativePoint, x, y);
		end
		
		-- re-position the enemy frame
		local enemy = get_enemy(self);
		x = x - 34;
		
		enemy:ClearAllPoints();
		enemy:SetPoint(mirrors[point], relativeTo, mirrors[point], -x, y);
	end
	
	-- called by xml
	function PT.BattleFrame_StartDrag(self) -- self is master frame
		self:StartMoving();
		
		if( mirror ) then
			self:SetScript("OnUpdate", do_mirror);
		end
	end
	
	-- called by xml
	function PT.BattleFrame_StopDrag(self) -- self is master frame
		self:StopMovingOrSizing();
		
		if( mirror ) then
			self:SetScript("OnUpdate", nil);
			do_mirror(self, 0);
		end
		
		self:SetUserPlaced(true);
	end
	
	-- fake AceGUI widget with custom close callback, which acts as our container
	local f = LibStub("AceGUI-3.0"):Create("Frame");
	f:Hide(); -- damn auto show -.-
	
	-- called when closing the little window
	f:SetCallback("OnClose", function(widget, event)
		local appName = widget:GetUserData("appName");
		LibStub("AceConfigDialog-3.0").OpenFrames[appName] = nil;
		f:Hide();
		
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
	OpenPositioning = function()
		LibStub("AceConfigDialog-3.0"):Open("PokemonTrainer_FrameCombatDisplay", f); -- f == our custom AceGUI container
		_G.InterfaceOptionsFrame:Hide();
		
		_G.PTPlayer:Show();
		_G.PTEnemy:Show();
		
		-- left button for dragging should be enough, I think
		_G.PTPlayer:RegisterForDrag("LeftButton");
		_G.PTEnemy:RegisterForDrag("LeftButton");
	end
	
	-- called by :OnInitialize
	function module:GetPositionOptions()
		local options = {
			name = L["Edit positions"],
			type = "group",
			args = {
				mirror = {
					type = "toggle",
					name = L["Mirror frames"],
					desc = L["When moving a battle frame, the enemy frame gets mirrored to the opposite side of the screen."],
					order = 3,
					get = function()
						return mirror;
					end,
					set = function(_, value)
						mirror = value;
					end,
				},
			},
		};
		
		module.GetPositionOptions = nil;
		return options;
	end
end

----------------------
-- Option Table
----------------------

function module:GetOptions()
	local function is_disabled(info, value)
		return not module:IsEnabled() and true or not self.db.profile[info[#info - 1].."_use"];
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
					name = L["Edit positions"],
					order = 2,
					func = OpenPositioning,
				},
				bg = {
					type = "toggle",
					name = L["Override color"],
					desc = L["Battle frames are usually colored black. Enable to set your own color."],
					order = 3,
					get = function()
						return self.db.profile.bg;
					end,
					set = function(_, value)
						self.db.profile.bg = value;
						
						-- encolor background
						if( self.db.profile.bg ) then
							_G.PTPlayer.bg:SetTexture(self.db.profile.bg_r, self.db.profile.bg_g, self.db.profile.bg_b, self.db.profile.bg_a);
							_G.PTEnemy.bg:SetTexture(self.db.profile.bg_r, self.db.profile.bg_g, self.db.profile.bg_b, self.db.profile.bg_a);
						else
							_G.PTPlayer.bg:SetTexture(0, 0, 0, 0.4);
							_G.PTEnemy.bg:SetTexture(0, 0, 0, 0.4);
						end
					end,
				},
				bg_color = {
					type = "color",
					name = _G.COLOR,
					order = 4,
					hasAlpha = true,
					get = function()
						return self.db.profile.bg_r, self.db.profile.bg_g, self.db.profile.bg_b, self.db.profile.bg_a;
					end,
					set = function(_, r, g, b, a)
						self.db.profile.bg_r = r;
						self.db.profile.bg_g = g;
						self.db.profile.bg_b = b;
						self.db.profile.bg_a = a;
						
						_G.PTPlayer.bg:SetTexture(r, g, b, a);
						_G.PTEnemy.bg:SetTexture(r, g, b, a);
					end,
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
				animate = {
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
		nactivealpha = {
			name = L["Visibility of currently not active pets"],
			type = "group",
			inline = true,
			order = 4,
			args = {
				use = {
					type = "toggle",
					name = L["Enable"],
					desc = L["Enable this if you want to change the visibility of not active pets. Set the new value on the right."],
					order = 1,
					get = function()
						return self.db.profile.nactivealpha_use;
					end,
					set = function(_, value)
						self.db.profile.nactivealpha_use = value;
					end,
				},
				value = {
					type = "range",
					name = L["Value"],
					min = 0.1,
					max = 0.9,
					step = 0.1,
					order = 2,
					get = function()
						return self.db.profile.nactivealpha;
					end,
					set = function(_, value)
						self.db.profile.nactivealpha = value;
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