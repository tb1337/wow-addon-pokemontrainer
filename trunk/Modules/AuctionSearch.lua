local PT = select(2, ...)
local LibPetJournal = LibStub("LibPetJournal-2.0")

local mod = PT:NewModule("AuctionSearch", "AceHook-3.0", "AceEvent-3.0")
local AceGUI = LibStub("AceGUI-3.0")

function mod:OnEnable()
    if (not PT.db.AuctionIconDisplay or self:CheckAutoDisable()) then
        return self:Disable()
    end

    if (IsAddOnLoaded("Blizzard_AuctionUI")) then
        self:RegisterHooks()
    else
        self:RegisterEvent("ADDON_LOADED", function(event, addonName)
            if (addonName == "Blizzard_AuctionUI") then
                mod:RegisterHooks()
                mod:UnregisterEvent("ADDON_LOADED")
            end
        end);
    end
end
function mod:OnDisable()
    mod:UnregisterEvent("ADDON_LOADED")
    self:UnhookAll()
end

function mod:CheckAutoDisable()
    if (IsAddOnLoaded("Auc-Advanced")) then
        return true
    end
    return false
end

function mod:RegisterHooks()
    self:SecureHook("AuctionFrameBrowse_Update");
end

function mod:AuctionFrameBrowse_Update()
    local offset = FauxScrollFrame_GetOffset(BrowseScrollFrame);
    for i=1, NUM_BROWSE_TO_DISPLAY do
        --local name, texture, count, quality, canUse, level, levelColHeader, minBid, minIncrement, buyoutPrice, bidAmount, highBidder, owner, saleStatus, itemId, hasAllInfo =  GetAuctionItemInfo("list", offset + i);
        --if (hasAllInfo and itemId == 82800) then
        local speciesID = self:ParseBattlePetLink(GetAuctionItemLink("list", offset + i))
        if (speciesID ~= nil) then
            if (self:HasPetBySpeciesID(tonumber(speciesID))) then
            --if (self:CountPetByName(name) > 0) then
                local iconTexture = _G["BrowseButton"..i.."ItemIconTexture"];
                iconTexture:SetVertexColor(unpack(PT.db.AuctionIconKnownColor));
            end
        end
    end
end

-- "|cff1eff00|Hbattlepet:200:4:2:292:34:53:0000000000000000|h[Fr\195\188hlingshase]|h|r"
function mod:ParseBattlePetLink(link)
    if (link == nil) then
        return nil
    end
    --local speciesID, level, quality, health, power, speed = string.match(link, "|Hbattlepet:(%d+):(%d+):(%d+):(%d+):(%d+):(%d+):%d+|h")
    return string.match(link, "|Hbattlepet:(%d+):(%d+):(%d+):(%d+):(%d+):(%d+):%d+|h")
    --return speciesID, level, quality, health, power, speed
end

function mod:CountPetByName(searchName)
    local count = 0;
    for i,petid in LibPetJournal:IteratePetIDs() do 
        local speciesID, customName, level, xp, maxXp, displayID, _, name, icon,
        petType, creatureID, sourceText, description, isWild, canBattle,
        tradable, unique = C_PetJournal.GetPetInfoByPetID(petid)
        if name == searchName then
            count = count + 1
        end
    end
    return count
end
function mod:HasPetBySpeciesID(searchSpeciesID)
    for i,petid in LibPetJournal:IteratePetIDs() do 
        local speciesID = C_PetJournal.GetPetInfoByPetID(petid)
        if (speciesID == searchSpeciesID) then
            return true
        end
    end
    return false
end
