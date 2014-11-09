local AddonName, PT = ...;
--local Patchwerk = PT:NewComponent("Patchwerk");

local Const = PT:GetComponent("Const");
local TrainerClass, PetClass, AbilityClass = PT.TrainerClass, PT.PetClass, PT.AbilityClass;

-------------------------------------------------------------
-- Construct the combat patchwerk
-------------------------------------------------------------

local Player = TrainerClass:new("Trainer"..Const.PLAYER, Const.PLAYER);
local Enemy  = TrainerClass:new("Trainer"..Const.ENEMY, Const.ENEMY);

for i = Const.PET_INDEX, Const.PET_MAX do
	local playerPet = PetClass:new("Trainer"..Const.PLAYER.."Pet"..i, Player, i);
	local enemyPet  = PetClass:new("Trainer"..Const.ENEMY.. "Pet"..i, Enemy , i);
	
	Player:SetPet(i, playerPet);
 	Enemy:SetPet(i, enemyPet);
 	
 	-- create the pet frames
 	playerPet.Frame = _G.CreateFrame("Frame", "PTTrainer"..Const.PLAYER.."Pet"..i, _G.UIParent, "PokemonTrainerPetTemplate");
 	playerPet.Frame._class = playerPet;
 	
 	enemyPet.Frame = _G.CreateFrame("Frame", "PTTrainer"..Const.ENEMY.."Pet"..i, _G.UIParent, "PokemonTrainerPetTemplate");
 	enemyPet.Frame._class = enemyPet;
 	
 	-- create the abilitys
 	for j = Const.ABILITY_MIN, Const.ABILITY_ALL do
 		-- the player only has 3 abilities
 		if( j < 4 ) then
 			playerPet:SetAbility(j, AbilityClass:new("Trainer"..Const.PLAYER.."Pet"..i.."Ability"..j, playerPet, j));
 		end
 		
 		-- since the enemy may have 6 (ability stealth until usage)
 		enemyPet:SetAbility(j,  AbilityClass:new("Trainer"..Const.ENEMY.. "Pet"..i.."Ability"..j, enemyPet , j));
 	end
end