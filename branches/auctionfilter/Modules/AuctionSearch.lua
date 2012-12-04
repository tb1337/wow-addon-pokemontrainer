local PT = select(2, ...)
local LibPetJournal = LibStub("LibPetJournal-2.0")

local mod = PT:NewModule("AuctionSearch", "AceHook-3.0", "AceEvent-3.0")
local AceGUI = LibStub("AceGUI-3.0")
local Auction = LibStub("LibAuction-0.1")

_G.t = mod

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
    if (self.gui_select) then
        self.gui_select:Release()
        _G.IsUsableCheckButton:Show()
    end
end

function mod:CheckAutoDisable()
    if (IsAddOnLoaded("Auc-Advanced")) then
        return true
    end
    return false
end

function mod:RegisterHooks()
    self:SecureHook("AuctionFrameBrowse_Update");
    self:SecureHook("AuctionFrameFilter_OnClick");
    
    self.test = Auction:CreateQuery();
    function self.test:Test123(...)
        JPrint("OnReady")
        JPrint(...)
    end
    self.test:RegisterCallback("OnReady", "Test123")
    JPrint(self.test)
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

function mod:AuctionFrameFilter_OnClick(obj, button)
    if (obj.type == "class") then
        -- As the hook is called AFTER the original function, the static prop contains if it is really still selected
        if (obj.index == 11 and AuctionFrameBrowse.selectedClassIndex == 11) then -- select and not unselect
            if (not self.gui_select) then
                self.gui_select = AceGUI:Create("Dropdown")
                
                local dd = self.gui_select
                dd:SetList({
                    none = "No Filter",
                    is_useable = USABLE_ITEMS,
                    not_known = "Not Known",
                }, { -- order
                    'none',
                    'is_useable',
                    'not_known',
                });
                dd:SetText("Filter")
                dd:SetCallback("OnValueChanged", function(_, _, key)
                    mod.selected_filter = key
                    JPrint("value changed", key)
                    _G.IsUsableCheckButton:SetChecked(key == "is_useable" and 1 or 0)
                end);
                
                local point, rel, relPoint, xOf, yOf = _G.IsUsableCheckButton:GetPoint(1)
                dd.frame:SetParent(_G.AuctionFrameBrowse)
                dd.frame:SetScale(0.85)
                dd:SetPoint(point, rel, relPoint, xOf, yOf)
                dd:SetWidth(_G.IsUsableCheckButton:GetWidth() + _G.IsUsableCheckButtonText:GetWidth())
            else
                self.gui_select.frame:Show()
            end
            mod.selected_filter = _G.IsUsableCheckButton:GetChecked() == 0 and 'none' or 'is_useable'
            self.gui_select:SetValue(mod.selected_filter)
            _G.IsUsableCheckButton:Hide()
        else
            if (self.gui_select) then
                self.gui_select.frame:Hide()
            end
            _G.IsUsableCheckButton:Show()
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
