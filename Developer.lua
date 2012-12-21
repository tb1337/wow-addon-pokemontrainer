--[[

This file contains developer stuff. The contents are cut off by the Curse Packaging System.

--]]

--@do-not-package@
local AddonName, PT = ...;

PT.dev = true;

local mt = {
	__index = function(t, k)
		if( k == "dead" ) then
			return t.hp <= 0;
		elseif( k == "hpP" ) then
			return t.hp / t.hpM;
		end
	end,
};
	
PT.PlayerInfo = {
	numPets = 3,
	activePet = 2,
	[1] = {
		ab1 = 115,
		ab2 = 611,
		ab3 = 595,
		icon = "INTERFACE\\ICONS\\INV_PET_CELESTIALDRAGON.BLP",
		level = 16,
		name = "Himmelsdrache",
		numAbilities = 3,
		quality = 6 - 1,
		species = 255,
		speed = 142,
		hp = 49,
		hpM = 100,
		type = 3, --2,
	},
	[2] = {
		ab1 = 219,
		ab2 = 223,
		ab3 = 226,
		icon = "INTERFACE\\ICONS\\INV_MISC_PET_03.BLP",
		level = 17,
		name = "Pandarenm\195\182nch",
		numAbilities = 3,
		quality = 5 - 1,
		species = 248,
		speed = 197,
		hp = 100,
		hpM = 100,
		type = 1,
	},
	[3] = {
		ab1 = 812,
		ab2 = 811,
		ab3 = 503,
		icon = "INTERFACE\\ICONS\\ACHIEVEMENT_BOSS_RAGNAROS.BLP",
		level = 16,
		name = "Mini-Ragnaros",
		numAbilities = 3,
		quality = 4 - 1,
		species = 297,
		speed = 135,
		hp = 100,
		hpM = 100,
		type = 7,
	},
};
	
PT.EnemyInfo = {
	numPets = 2,
	activePet = 1,
	[1] = {
		ab1 = 380,
		ab2 = 339,
		ab3 = 383,
		icon = "INTERFACE\\ICONS\\ABILITY_HUNTER_PET_SPIDER.BLP",
		level = 14,
		name = "Aschenspinnling",
		numAbilities = 3,
		quality = 3 - 1,
		species = 427,
		speed = 145,
		hp = 100,
		hpM = 100,
		type = 8,
	},
	[2] = {
		ab1 = 113,
		ab2 = 310,
		ab3 = 179,
		icon = "INTERFACE\\ICONS\\ABILITY_HUNTER_PET_CRAB.BLP",
		level = 14,
		name = "Lavakrebs",
		numAbilities = 3,
		quality = 2 - 1,
		species = 423,
		speed = 105,
		hp = 100,
		hpM = 100,
		type = 7,
	},
	[3] = {
		ab1 = 115,
		ab2 = 611,
		ab3 = 595,
		icon = "INTERFACE\\ICONS\\INV_PET_CELESTIALDRAGON.BLP",
		level = 16,
		name = "Himmelsdrache",
		numAbilities = 3,
		quality = 1 - 1,
		species = 255,
		speed = 156,
		hp = 100,
		hpM = 100,
		type = 2,
	},
};
	
setmetatable(PT.PlayerInfo[1], mt);
setmetatable(PT.PlayerInfo[2], mt);
setmetatable(PT.PlayerInfo[3], mt);
setmetatable(PT.EnemyInfo[1], mt);
setmetatable(PT.EnemyInfo[2], mt);
setmetatable(PT.EnemyInfo[3], mt);
--@end-do-not-package@