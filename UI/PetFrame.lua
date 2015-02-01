local AddonName, PT = ...;
local Pet = PT.PetClass;

local Const, Battle, Util = PT:GetComponent("Const", "Battle", "Util");

local LibCrayon = LibStub("LibCrayon-3.0");

-------------------------------------------------------------
-- Pet related functions
-------------------------------------------------------------

function Pet:UpdateAll()	
	self:UpdateHealth();
	self:UpdatePower();
	self:UpdateSpeed();
	self:UpdateType();
	self:UpdatePetInfo();
	self:UpdateEnemyFrames();
	self:UpdateSpellBonusFrames();
end

function Pet:UpdateHealth()
	local text = self:GetFrame().HealthFrame.Text;
	local health, maxHealth, baseMax, isDead = self:GetHealth(), self:GetMaxHealth(), self:GetBaseMaxHealth(), self:IsDead();
	local maxDiff = maxHealth - baseMax;
	
	text:SetTextColor( LibCrayon:GetThresholdColor(health, maxHealth) );
	
	-- update text
	if( maxDiff > 0 ) then
		text:SetText( ("%d/%d |cff00ff00+%d|r"):format(health, maxHealth, maxDiff) );
	else
		text:SetText( ("%d/%d"):format(health, maxHealth) );
	end
	
	-- show or hide dead/alive border
	local info = self:GetFrame().PetInfo;
	
	if( isDead ) then
		info.BorderAlive:Hide();
		info.BorderDead:Show();
	else
		info.BorderAlive:Show();
		info.BorderDead:Hide();
	end
	
	-- update enemy frames
	self:UpdateEnemyFrames();
end

function Pet:UpdatePower()
	local text = self:GetFrame().PowerFrame.Text;
	text:SetText( self:GetPower() );
end

function Pet:UpdateSpeed()
	local text = self:GetFrame().SpeedFrame.Text;
	text:SetText( self:GetSpeed() );
end

function Pet:UpdateType()
	local frame = self:GetFrame().PetInfo.Type;
	
	frame.Icon:SetTexture( Const:GetTypeIcon(self:GetType()) );
	
	local auraID = self:GetTypePassive();
	if( auraID ) then
		local hasAura = _G.PetBattleUtil_PetHasAura(self:GetSide(), self:GetSlot(), auraID);
		
		if( hasAura ) then
			frame.Active:Show();
		else
			frame.Active:Hide();
		end
	end
end

function Pet:UpdatePetInfo()	
	local info = self:GetFrame().PetInfo;
	
	-- update pet icon
	info.Icon:SetTexture(self:GetIcon());
	
	-- update quality border
	local quality = Util:GetQualityColorTable(self:GetQuality());
	info.BorderAlive:SetVertexColor(quality.r, quality.g, quality.b);
	
	-- update level
	info.Level:SetText( self:GetLevel() );
	
	-- update model
	self:GetFrame().Model:SetDisplayInfo( self:GetModel() );
	
	-- update enemy frames
	self:UpdateEnemyFrames(quality);
end

function Pet:UpdateEnemyFrames(quality)
	quality = quality or Util:GetQualityColorTable(self:GetQuality());
	
	-- loop enemy and our frames (on enemy pet frames) and update icons, borders, etc.
	local Trainer = self:GetTrainer():GetEnemyTrainer();
	
	for i = Const.PET_INDEX, Const.PET_MAX do
		local enemyFrame = self.Frame.Spells["Enemy"..i];
		local ourFrame = Trainer["Pet"..i].Frame.Spells["Enemy"..self:GetSlot()];
		
		if( i > Trainer:GetNumPets() ) then
			enemyFrame:Hide();
		else
			enemyFrame:Show();
			
			ourFrame.Icon:SetTexture(self:GetIcon());
			ourFrame.BorderAlive:SetVertexColor(quality.r, quality.g, quality.b);
			
			if( self:IsDead() ) then
				ourFrame.BorderAlive:Hide();
				ourFrame.BorderDead:Show();
			else
				ourFrame.BorderAlive:Show();
				ourFrame.BorderDead:Hide();
			end
		end
	end
end

function Pet:UpdateSpellBonusFrames()
	local frame = self:GetFrame();
	
	
end

-------------------------------------------------------------
-- Frame related functions
-------------------------------------------------------------

function Pet:GetFrame()
	return self.Frame;
end