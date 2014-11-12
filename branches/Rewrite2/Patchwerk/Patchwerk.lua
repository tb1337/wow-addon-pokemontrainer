local AddonName, PT = ...;
--local Patchwerk = PT:NewComponent("Patchwerk");

local Const = PT:GetComponent("Const");
local TrainerClass, PetClass, AbilityClass = PT.TrainerClass, PT.PetClass, PT.AbilityClass;

-------------------------------------------------------------
-- Construct the combat patchwerk
-------------------------------------------------------------

local Player = TrainerClass:new("Trainer"..Const.PLAYER, Const.PLAYER);
local Enemy  = TrainerClass:new("Trainer"..Const.ENEMY, Const.ENEMY);

-- create trainer frames
--Player.Frame = _G.CreateFrame("Frame", "PTTrainer"..Const.PLAYER, _G.PetBattleFrame);
--Enemy.Frame  = _G.CreateFrame("Frame", "PTTrainer"..Const.ENEMY, _G.PetBattleFrame);

-- create pet classes
for i = Const.PET_INDEX, Const.PET_MAX do
	local playerPet = PetClass:new("Trainer"..Const.PLAYER.."Pet"..i, Player, i);
	local enemyPet  = PetClass:new("Trainer"..Const.ENEMY.. "Pet"..i, Enemy , i);
	
	Player:SetPet(i, playerPet);
 	Enemy:SetPet(i, enemyPet);
 	
 	-- create the pet frames
 	playerPet.Frame = _G.CreateFrame("Frame", "PTTrainer"..Const.PLAYER.."Pet"..i, _G.PetBattleFrame, "PokemonTrainerPetTemplate-Player");
 	playerPet.Frame._class = playerPet;
 	
 	enemyPet.Frame = _G.CreateFrame("Frame", "PTTrainer"..Const.ENEMY.."Pet"..i, _G.PetBattleFrame, "PokemonTrainerPetTemplate-Enemy");
 	enemyPet.Frame._class = enemyPet;
 	
 	-- create the abilitys
 	for j = Const.ABILITY_MIN, Const.ABILITY_ALL do
 		-- the player only has 3 abilities
 		if( j < 4 ) then
 			playerPet:SetAbility(j, AbilityClass:new("Trainer"..Const.PLAYER.."Pet"..i.."Ability"..j, playerPet, j));
 			
 			-- add the ability class to ability button and vice versa
 			playerPet.Frame.Spells["Spell"..j]._class = playerPet:GetAbility(j);
 			playerPet.Frame.Spells["Spell"..j]._class.Frame = playerPet.Frame.Spells["Spell"..j];
 		end
 		
 		-- since the enemy may have 6 (ability stealth until usage)
 		enemyPet:SetAbility(j,  AbilityClass:new("Trainer"..Const.ENEMY.. "Pet"..i.."Ability"..j, enemyPet , j));
 		
 		-- add the ability class to ability button and vice versa
 		enemyPet.Frame.Spells["Spell"..j]._class = enemyPet:GetAbility(j);
 		enemyPet.Frame.Spells["Spell"..j]._class.Frame = enemyPet.Frame.Spells["Spell"..j];
 	end
end

-------------------------------------------------------------
-- Flick enemy pet icons and their classes together
-------------------------------------------------------------
-- only works after the "big" frame creation above

for side = Const.PLAYER, Const.ENEMY do
	for pet = Const.PET_INDEX, Const.PET_MAX do
		-- save class to frame and enemy frame to class
		for i = Const.PET_INDEX, Const.PET_MAX do
			local class = PT.Component["Trainer"..(side == Const.PLAYER and Const.ENEMY or Const.PLAYER).."Pet"..i];
			local frame = _G["PTTrainer"..side.."Pet"..pet.."SpellsFrameEnemy"..i];
			
			frame._class = class;
			
			class.PetFrames = class.PetFrames or {};
			table.insert(class.PetFrames, frame);
		end
	end
end

-------------------------------------------------------------
-- Anchor the battle frames
-------------------------------------------------------------

PTTrainer1Pet1:SetPoint("TOPLEFT", 2, -200);
PTTrainer1Pet2:SetPoint("TOPLEFT", PTTrainer1Pet1, "BOTTOMLEFT", 0, 2);
PTTrainer1Pet3:SetPoint("TOPLEFT", PTTrainer1Pet2, "BOTTOMLEFT", 0, 2);

PTTrainer2Pet1:SetPoint("TOPRIGHT", -2, -200);
PTTrainer2Pet2:SetPoint("TOPRIGHT", PTTrainer2Pet1, "BOTTOMRIGHT", 0, 2);
PTTrainer2Pet3:SetPoint("TOPRIGHT", PTTrainer2Pet2, "BOTTOMRIGHT", 0, 2);