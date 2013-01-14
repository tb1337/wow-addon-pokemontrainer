local AddonName = ...;
local L = LibStub("AceLocale-3.0"):NewLocale(AddonName, "enUS", true)

--@localization(locale="enUS", format="lua_additive_table", handle-unlocalized="english", escape-non-ascii=true, same-key-is-true=true)@

--@do-not-package@

-- Core
L["Pokemon Trainer Options"] = true
L["First run, you may wanna check /pt for options."] = true
L["Recently updated to version"] = true
L["Enable"] = true
L["Enable this module."] = true
L["Preferred combat display"] = true
L["Choose between the new (Frames) or the old (Tooltip) way of displaying combat data during pet battles."] = true
L["Switching the combat display doesn't work during pet battles."] = true

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
L["Display breeds"] = true
L["Perhaps, you heard of battle pet breeds before. Any pet has an assigned breed ID which defines which stats will grow larger than others while leveling up. Stats are health, power and speed. When this option is enabled, you can actually see pet breeds in during battles."] = true
L["As text"] = true
L["As image"] = true
L["Both"] = true
L["You need to re-open this window when changing breed settings."] = true
L["Reorganize pets by activity"] = true
L["If enabled, active pets are displayed first."] = true
L["Animate reorganizing"] = true
L["Reorganizing will take place with a cool animation."] = true
L["Pet highlightning"] = true
L["Highlight active pets"] = true
L["Currently active pets will have a background color, if this option is activated."] = true
L["With animation"] = true
L["In addition, the background of active pets gets animated with a smooth effect."] = true
L["Inactive pet alpha"] = true
L["Enable if you want to override the alpha of inactive pets. Set the new value on the right."] = true
L["Value"] = true
L["Pet ability cooldowns"] = true
L["Display rounds"] = true
L["Whether to show the cooldown of abilities on the buttons or not."] = true
L["Highlight"] = true
L["Highlights ability buttons with a color when they are on cooldown."] = true
L["Cut off ability icon borders"] = true
L["Removes the borders from any ability icon displayed by PT. Only for styling purposes."] = true
L["General ability settings"] = true
L["Highlight buffed abilities"] = true
L["Whenever your abilities are doing more damage based on buffs or weather, they will glow."] = true
L["...on Blizzard Bar"] = true
L["Applys ability glowing states on Blizzards Pet Action Buttons, too."] = true
L["Display ability amplifying state"] = true
L["Some abilities get stronger on each usage. If this option is enabled, you will see a red dot which gets more green the more you are using these abilities."] = true
L["Display active enemy borders"] = true
L["Draws a border around the column of currently active enemys, so it is easier to detect the active pet on your frame for comparing bonuses."] = true

-- module TooltipCombatDisplay
L["Display: Tooltip"] = true
L["LibQTip based combat display for Pet Battles and the old way of displaying things.. Disable it if you want to use the frame based combat display."] = true
L["Horizontal position"] = true
L["Vertical position"] = true

-- module WildPetTooltip
L["Battle Pet Tooltip"] = true
L["Add battle-specific informations to battle pet tooltips."] = true
L["Battle Level"] = true
L["Display battle pet level"] = true
L["...only on different levels"] = true
L["Sometimes the actual battle pet level differs from the NPC pet level."] = true
L["Consolidated battle infos"] = true
L["Display your battle pet team without their abilities and if they have at least one bonus or weakness."] = true
L["Display battle infos only on wild pets"] = true
L["If this is not set, battle infos are also displayed on NPC and player pets."] = true

-- module Auction Search
L["Auction Search"] = true
L["When searching for pets in the auction house, this module sets red and green background colors which indicate whether you own this pet or not."] = true
L["Known pet color"] = true
L["Unknown pet color"] = true
L["Please note that the Auction Search module isn't supporting third party auction addons. If such addons are actually changing the default auction UI and these changes break this module, simply disable it. Please do not open tickets if other addons break this module. Thanks."] = true
L["If you are author/maintainer of a common auction UI addon and want this module supporting your addon, feel free to open a ticket on Curseforge or simply send me an email at"] = true

-- module HealBandageButtons
L["Heal Pet Buttons"] = true
L["When pet tracking is enabled, this module displays two buttons on a separate and draggable frame. One for healing your battle pets with the spellcast, another for healing with pet bandages. Clicking these buttons is allowed when not in combat."] = true
L["Draggable"] = true
L["You may drag the frame around when this option is set."] = true
L["Shift"] = true
L["Alt"] = true
L["Ctrl"] = true
L["Modifier"] = true
L["Choose whether you need to push a modifier key or not, when clicking an action button."] = true
L["Mouse button"] = true
L["Select the mouse button on which clicks will execute actions."] = true

-- module AutoSafariHat
L["Auto Safari Hat"] = true
L["Small module which will always equip your Safari Hat when engaging a battle pet. After the battle is over and the XP is gained, it will switch back to your previous weared head gear."] = true
L["Hat already put on!"] = true
L["Hat put on successfully."] = true
L["Something went totally wrong. This error should never appear."] = true
L["Safari Hat"] = true
L["Original hat put on succesfully."] = true
L["Cannot put original hat on, it is unknown."] = true
L["Safari Hat found in your bags!"] = true
L["Safari Hat not found in your bags!"] = true
L["Display messages"] = true
L["Prints messages into the chat window when equip is successfully switched or errors occured."] = true
L["Only errors"] = true
L["Prints only error messages."] = true

--@end-do-not-package@