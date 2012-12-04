local LibAuction = LibStub:NewLibrary("LibAuction-0.1", 0.1)
if not LibAuction then return end

local Lib, Embed = LibAuction, {}

LibStub:GetLibrary("AceHook-3.0"):Embed(Lib)
LibStub:GetLibrary("AceEvent-3.0"):Embed(Lib)

local CallbackHandler = LibStub:GetLibrary("CallbackHandler-1.0")


local QueryBase = {
    params = {},
    page = 1,
}
QueryBase.callbacks = CallbackHandler:New(QueryBase)

function QueryBase:execute(callback)
    if (callback ~= nil) then
        QueryBase.RegisterCallback(self, "OnReady", callback)
    end
    _G.QueryAuctionItems(unpack(self.params))
    Lib.currentQuery = self
end

function QueryBase:OnReady(event)
    QueryBase.callbacks:Fire("OnReady", event)
end



--[[function Lib:Embed(target)
    for k, v in pairs(Embed) do
        target[v] = v
    end
end]]

function Lib:Init()
    if (self.initied == nil) then
        self.initied = true
        self:RegisterEvent("AUCTION_ITEM_LIST_UPDATE")
        self:SecureHook("QueryAuctionItems")
        --[[if (IsAddOnLoaded("Blizzard_AuctionUI")) then
            --
        else
            self:RegisterEvent("ADDON_LOADED", function(event, addonName)
                if (addonName == "Blizzard_AuctionUI") then
                    --
                    mod:UnregisterEvent("ADDON_LOADED")
                end
            end);
        end]]
    end
end

function Lib:QueryAuctionItems()
    Lib.currentQuery = nil
end

function Lib:AUCTION_ITEM_LIST_UPDATE(...)
    if (self.currentQuery ~= nil) then
        self.currentQuery:OnReady(...)
        self.currentQuery = nil
    end
end

function Lib:CreateQuery(...)
    assert(self.initied ~= nil, "Libary have to be initied atleast once.")
    local object = {}
    setmetatable(object, {__index = QueryBase})
    object.params = ... or {}
    return object
end
