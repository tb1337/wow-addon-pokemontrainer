-----------------------------------
-- Setting up scope, upvalues and libs
-----------------------------------

local AddonName, PT = ...;

local L = LibStub("AceLocale-3.0"):GetLocale(AddonName);

local _G = _G;

----------------------
-- Variables
----------------------

local ALPHA_FULL = 1;
local ALPHA_HALF = 0.5;

-- xml values
local FRAME_BUTTON_WIDTH = 22;
local FRAME_LINE_HEIGHT = 22;
local SPACE_PETS = 5;
local SPACE_ABILITIES = 2;
local SPACE_HORIZONTAL = 3;

----------------------------
-- Frame Functions
----------------------------

local function get_enemy(self)
	return self:GetName() == "PTPlayer" and _G["PTEnemy"] or _G["PTPlayer"];
end

local function get_frame(side)
	return side == PT.PLAYER and _G["PTPlayer"] or _G["PTEnemy"];
end

function PT.BattleFrame_Resize(self)
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

-----------------------------
-- Animation Functions
-----------------------------

function BattleFrame_Pets_Reorganize_Exec(self, noAnimation) -- self is PT master frame
	for i,f in ipairs(self.petFrames) do
		f:ClearAllPoints();
		
		if( i == 1 ) then
			f:SetPoint("TOPLEFT", self:GetName().."Header", "BOTTOMLEFT", 0, -6);
		else
			f:SetPoint("TOPLEFT", self.petFrames[i - 1], "BOTTOMLEFT", 0, -SPACE_PETS);
		end
		
		if( not noAnimation ) then
			f["animShow"..(f.alpha <= ALPHA_HALF and "_h" or "")]:Play();
		else
			PT.BattleFrame_Pet_ShowFinished(f.animShow); -- dummy
		end
	end
end

function BattleFrame_Pets_Reorganize_Init(self, noAnimation) -- self is PT master frame
	local active = self.player.activePet;
	local rem = 0;
	
	for i,f in ipairs(self.petFrames) do
		f.alpha = f.alpha or f:GetAlpha();
		
		if( not noAnimation ) then
			f["animHide"..(f.alpha <= ALPHA_HALF and "_h" or "")]:Play();
		end
		
		if( f:GetID() == active ) then
			rem = i;
		end
	end
	
	local frame = table.remove(self.petFrames, rem);
	table.insert(self.petFrames, 1, frame);
	
	if( noAnimation ) then
		BattleFrame_Pets_Reorganize_Exec(self, noAnimation);
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
	parent:SetAlpha(parent.alpha); -- reset alpha
	parent.alpha = nil;
end

-------------------------------
-- On Loading and Events
-------------------------------

function PT.BattleFrame_OnLoad(self)
	self:SetID( self:GetName() == "PTPlayer" and PT.PLAYER or PT.ENEMY );
	
	-- animations
	self.petFrames = {
		_G[self:GetName().."Pet1"],
		_G[self:GetName().."Pet2"],
		_G[self:GetName().."Pet3"],
	};
	
	-- Register events
	--self:RegisterEvent("PET_BATTLE_OPENING_DONE");
	--self:RegisterEvent("PET_BATTLE_CLOSE");
	--self:RegisterEvent("PET_BATTLE_TURN_STARTED");
	--self:RegisterEvent("PET_BATTLE_ACTION_SELECTED");
	self:RegisterEvent("PET_BATTLE_OPENING_START");
	self:RegisterEvent("PET_BATTLE_OVER");
	self:RegisterEvent("PET_BATTLE_PET_ROUND_PLAYBACK_COMPLETE");
	self:RegisterEvent("PET_BATTLE_PET_CHANGED");
	self:RegisterEvent("PET_BATTLE_HEALTH_CHANGED");
	self:RegisterEvent("PET_BATTLE_MAX_HEALTH_CHANGED");
	
end

function PT.BattleFrame_OnEvent(self, event, ...)	
	if( event == "PET_BATTLE_OPENING_START" ) then
		PT:ScanPets();
		PT.BattleFrame_Initialize(self);
		PT.BattleFrame_UpdateBattleButtons(self);
		BattleFrame_Pets_Reorganize_Init(self, true);
		self:Show();
	elseif( event == "PET_BATTLE_OVER" ) then
		self:Hide();
	elseif( event == "PET_BATTLE_PET_ROUND_PLAYBACK_COMPLETE" ) then
		PT:RoundUpPets();
		PT.BattleFrame_UpdateBattleButtons(self);
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
	-- we store the table ID's for further use
	if( self:GetID() == PT.PLAYER ) then
		self.player = PT.PlayerInfo;
		self.enemy  = PT.EnemyInfo;
	else
		self.player = PT.EnemyInfo;
		self.enemy  = PT.PlayerInfo;
	end
	
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
		
		PT.BattleFrame_UpdateActivePetHighlight(self, pet);
	end -- end for pet
end

do
	local function setAlphaAndLevelColor(self, pet)
		local r, g, b;
		
		-- sets the level color in relation to the active enemy pet
		-- UPDATE NOTICE: there must be an option to reverse the coloring since it may be confusing
		r, g, b = PT:GetDifficultyColor(self.enemy[self.enemy.activePet], self.player[pet]);
		_G[self:GetName().."Pet"..pet.."Button"].Level:SetTextColor(r, g, b, 1);
		
		-- set alpha
		_G[self:GetName().."Pet"..pet].alpha = not(pet == self.player.activePet) and ALPHA_HALF or ALPHA_FULL;
	end
	
	function PT.BattleFrame_UpdateActivePetHighlight(self, pet)
		if( pet ) then
			setAlphaAndLevelColor(self, pet);
			return;
		end
	
		for pet = 1, self.player.numPets do
			setAlphaAndLevelColor(self, pet);
		end
	end
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