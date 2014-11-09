local AddonName, PT = ...;
local Pet = PT.PetClass;

local Const, Battle = PT:GetComponent("Const", "Battle");

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
	local quality = _G.ITEM_QUALITY_COLORS[ self:GetQuality() ] or {r = 1, g = 1, b = 1};
	info.BorderAlive:SetVertexColor(quality.r, quality.g, quality.b);
	
	-- update level
	info.Level:SetText( self:GetLevel() );
	
	-- update model
	self:GetFrame().Model:SetDisplayInfo( self:GetModel() );
end

-------------------------------------------------------------
-- Frame related functions
-------------------------------------------------------------

function Pet:GetFrame()
	return self.Frame;
end