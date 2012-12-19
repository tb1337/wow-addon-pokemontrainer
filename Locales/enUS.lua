local AddonName = ...;
local L = LibStub("AceLocale-3.0"):NewLocale(AddonName, "enUS", true)

--@localization(locale="enUS", format="lua_additive_table", handle-unlocalized="english", escape-non-ascii=true, same-key-is-true=true)@

--@do-not-package@

-- Core
L["Pokemon Trainer Options"] = true
L["Enable"] = true
L["Enable this module."] = true
L["Preferred combat display"] = true

-- module FrameCombatDisplay
L["Display: Frames"] = true
L["True frame based combat display for Pet Battles and the next generation of Pokemon Trainer. Disable it if you want to use the tooltip based combat display."] = true
L["More settings"] = true
L["You can now move the frames by dragging them around."] = true
L["Mirror frames"] = true
L["Frame scale"] = true
L["When moving a battle frame, the enemy frame gets mirrored to the opposite side of the screen."] = true
L["Left"] = true
L["Right"] = true
L["Player: pet icons"] = true
L["Enemy: pet icons"] = true
L["Frame-related options"] = true
L["Auto-resize"] = true
L["Battle frames are getting resized when players have less than three pets."] = true
L["Override color"] = true
L["Battle frames are usually colored black. Enable to set your own color."] = true
L["Reorganize pets by activity"] = true
L["If enabled, active pets are displayed first."] = true
L["Animate reorganizing"] = true
L["Reorganizing will take place with a cool animation."] = true
L["Active and inactive pet highlightning"] = true
L["Highlight background of active pets"] = true
L["The background of currently active pets will glow, if this option is activated."] = true
L["Inactive pet alpha"] = true
L["Enable if you want to override the alpha of inactive pets. Set the new value on the right."] = true
L["Value"] = true
L["Pet ability cooldowns"] = true
L["Display rounds"] = true
L["Whether to show the cooldown of abilities on the buttons or not."] = true
L["Highlight"] = true
L["Highlights ability buttons with a color when they are on cooldown."] = true

-- module TooltipCombatDisplay
L["Display: Tooltip"] = true
L["LibQTip based combat display for Pet Battles. Disable it if you want to use the frame based combat display."] = true

-- module WildPetTooltip
L["Battle Pet Tooltip"] = true
L["Add battle-specific informations to battle pet tooltips."] = true
L["Battle Level"] = true
L["Display battle pet level"] = true
L["Sometimes the actual battle pet level differs from the NPC pet level."] = true
L["Consolidated battle infos"] = true
L["Display your battle pet team without their abilities and if they have at least one bonus or weakness."] = true
L["Display battle infos only on wild pets"] = true
L["If this is not set, battle infos are also displayed on NPC and player pets."] = true

-- module Auction Search
L["Auction Search"] = true

--@end-do-not-package@