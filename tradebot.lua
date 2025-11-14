local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")
local LocalPlayer = Players.LocalPlayer

local isUserAllowed = true
if not isUserAllowed then return end

local TradeFolder = ReplicatedStorage:WaitForChild("Trade")
local acceptRequest = TradeFolder:WaitForChild("AcceptRequest")
local declineRequest = TradeFolder:WaitForChild("DeclineRequest")
local declineTrade = TradeFolder:WaitForChild("DeclineTrade")
local updateTrade = TradeFolder:WaitForChild("UpdateTrade")
local acceptTrade = TradeFolder:WaitForChild("AcceptTrade")
local OfferItem = TradeFolder:WaitForChild("OfferItem")

game.ReplicatedStorage.Trade.UpdateTrade.OnClientEvent:Connect(function(whatever)
    _G.fuckass = whatever.LastOffer
end)

local function sendMessage(msg)
    if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
        pcall(function()
            TextChatService.ChatInputBarConfiguration.TargetTextChannel:SendAsync(msg)
        end)
    end
end

local function getTradeUI()
    return LocalPlayer.PlayerGui:FindFirstChild("TradeGUI")
end

local function getTraderName()
    local gui = getTradeUI()
    if not gui then return "" end
    local name = gui.Container.Trade.TheirOffer.Username.Text or ""
    return name:gsub("[%(%)]", "")
end

local function getRarityFromColor(color)
    local r, g, b = math.floor(color.R*255), math.floor(color.G*255), math.floor(color.B*255)
    if r == 220 and g == 0 and b == 5 then return "Legendary"
    elseif r == 0 and g == 200 and b == 0 then return "Rare"
    elseif r == 0 and g == 255 and b == 255 then return "Uncommon"
    elseif r == 106 and g == 106 and b == 106 then return "Common"
    else return "Unknown" end
end

local function countRaritiesWithQuantity()
    local gui = getTradeUI()
    if not gui then return {Legendary=0,Rare=0,Uncommon=0,Common=0,Unknown=0} end
    local container = gui.Container.Trade.TheirOffer.Container
    local rarityCount = {Legendary=0,Rare=0,Uncommon=0,Common=0,Unknown=0}
    for i=1,4 do
        local itemFrame = container:FindFirstChild("NewItem"..i)
        if itemFrame and itemFrame.Visible then
            local rarity = getRarityFromColor(itemFrame.ItemName.BackgroundColor3)
            local quantity = 1
            if itemFrame.Container and itemFrame.Container.Amount then
                local amtText = itemFrame.Container.Amount.Text
                if amtText ~= "" and amtText ~= "x" then quantity = tonumber(amtText:match("x(%d+)")) or 1 end
            end
            if rarityCount[rarity] then rarityCount[rarity] = rarityCount[rarity]+quantity else rarityCount.Unknown=rarityCount.Unknown+quantity end
        end
    end
    return rarityCount
end

local function countSeers()
    local inventoryFrames = {}
    for _, frame in pairs(LocalPlayer.PlayerGui:GetDescendants()) do
        if frame:IsA("Frame") and frame.Name:match("NewItem") and frame.Parent and frame.Parent.Name ~= "Template" then
            if frame:FindFirstChild("ItemName") and frame.ItemName:FindFirstChild("Label") then table.insert(inventoryFrames, frame) end
        end
    end
    local seerNameMap = {["Yellow Seer"]="YellowSeer",["Orange Seer"]="OrangeSeer",["Seer"]="TheSeer",["Purple Seer"]="PurpleSeer",["Red Seer"]="RedSeer",["Blue Seer"]="BlueSeer"}
    local seersMap = {}
    for _, itemFrame in pairs(inventoryFrames) do
        local label = itemFrame.ItemName.Label
        local displayName = label.Text
        local remoteName = seerNameMap[displayName]
        if remoteName then
            local qty = 1
            local container = itemFrame:FindFirstChild("Container")
            if container and container:FindFirstChild("Amount") then
                local amtText = container.Amount.Text
                if amtText and amtText:match("%d+") then qty = tonumber(amtText:match("%d+")) or 1 end
            end
            if seersMap[displayName] then seersMap[displayName].Qty = seersMap[displayName].Qty+qty
            else seersMap[displayName]={RemoteName=remoteName,Qty=qty} end
        end
    end
    return seersMap
end

local isTradeProcessActive = false
local tradeThread = nil

local function tradeProcess()
    local tradeInProgress=false
    local tradeDuration=60
    local cooldown=false
    local connection=nil
    local promptedForCommands=false
    local startTick=0
    local function resetTradeState()
        _G.lockedOfferPoints=nil
        tradeInProgress=false
        cooldown=true
        startTick=0
        if connection and connection.Connected then connection:Disconnect() connection=nil end
        promptedForCommands=false
    end
    while isTradeProcessActive do
        if cooldown then
            for i=1,5 do pcall(function() declineRequest:FireServer() end) wait(1) end
            cooldown=false
        end
        local gui = getTradeUI()
        local guiEnabled = gui and gui.Enabled
        if guiEnabled and not tradeInProgress then
            tradeInProgress=true
            promptedForCommands=false
            startTick=tick()
            local trader=getTraderName()
            sendMessage("Trade started with "..trader..", please select the items you would like to trade.")
        end
        if tradeInProgress then
            gui=getTradeUI()
            guiEnabled=gui and gui.Enabled
            if not guiEnabled then
                sendMessage("Trade was declined or canceled.")
                resetTradeState()
                wait(2)
                wait(0.25)
                continue
            end
            local acceptUI=gui.Container.Trade.Actions.Accept
            if acceptUI and not acceptUI.Cooldown.Visible and not acceptUI.AddItem.Visible and not promptedForCommands then
                sendMessage('Type "Done" when finished adding items, or "Chart" for a value chart.')
                promptedForCommands=true
                if connection and connection.Connected then connection:Disconnect() connection=nil end
                connection=TextChatService.MessageReceived:Connect(function(msg)
                    local text=msg.Text and msg.Text:lower() or ""
                    if text=="chart" then sendMessage("Legendary = 10, Rare = 5, Uncommon = 3, Common = 1")
                    elseif text=="done" then
                        local counts=countRaritiesWithQuantity()
                        local points=counts.Legendary*10+counts.Rare*5+counts.Uncommon*3+counts.Common*1
                        local godlys=math.floor(points/60)
                        _G.lockedOfferPoints=points
                        sendMessage(string.format("Counted offer as %d points (Godly = 60 points).",points))
                        local seersMap=countSeers()
                        for displayName,seer in pairs(seersMap) do sendMessage(string.format("%s: %d in inventory",displayName,seer.Qty)) end
                        local godlysRemaining=godlys
                        while godlysRemaining>0 do
                            local maxSeerName,maxSeerData
                            for name,data in pairs(seersMap) do
                                if data.Qty>0 and (not maxSeerData or data.Qty>maxSeerData.Qty) then maxSeerName=name maxSeerData=data end
                            end
                            if not maxSeerData then sendMessage(string.format("Not enough Seers to cover all godlys (%d remaining).",godlysRemaining)) break end
                            local toOffer=math.min(maxSeerData.Qty,godlysRemaining)
                            sendMessage(string.format("Offering %d %s(s)",toOffer,maxSeerName))
                            for i=1,toOffer do OfferItem:FireServer(maxSeerData.RemoteName,"Weapons") wait(0.1) end
                            maxSeerData.Qty=maxSeerData.Qty-toOffer
                            godlysRemaining=godlysRemaining-toOffer
                        end
                        if godlysRemaining>0 then sendMessage(string.format("Not enough Seers to cover all godlys (%d remaining).",godlysRemaining)) end
                        if connection and connection.Connected then connection:Disconnect() connection=nil end
                    end
                end)
            end
            local myOfferContainer=gui.Container.Trade.YourOffer.Container
            local offeredGodlys=0
            for i=1,4 do
                local itemFrame=myOfferContainer:FindFirstChild("NewItem"..i)
                if itemFrame and itemFrame.Visible then
                    local amtText=itemFrame.Container.Amount.Text
                    local qty=1
                    if amtText~="" and amtText~="x" then qty=tonumber(amtText:match("x(%d+)")) or 1 end
                    offeredGodlys=offeredGodlys+qty
                end
            end
            local counts=countRaritiesWithQuantity()
            local points=counts.Legendary*10+counts.Rare*5+counts.Uncommon*3+counts.Common*1
            local godlysRequired=math.floor(points/60)
            local theirAccepted=gui.Container.Trade.TheirOffer.Accepted.Visible
            local currentCounts=countRaritiesWithQuantity()
            local currentPoints=currentCounts.Legendary*10+currentCounts.Rare*5+currentCounts.Uncommon*3+currentCounts.Common*1
            if _G.lockedOfferPoints and currentPoints<_G.lockedOfferPoints then
                sendMessage("Offer changed! — declining trade.")
                pcall(function() declineTrade:FireServer() end)
                resetTradeState()
                wait(0.25)
                continue
            end
            if offeredGodlys>=godlysRequired and points>0 and theirAccepted then
                pcall(function() acceptTrade:FireServer(game.PlaceId*3,_G.fuckass) end)
                local timeout=3
                local startTime=tick()
                repeat gui=getTradeUI() wait(0.1) until not gui or not gui.Enabled or tick()-startTime>=timeout
                if not gui or not gui.Enabled then sendMessage("Trade Accepted, GG :)") else sendMessage("Error during acceptance, declining trade.") pcall(function() declineTrade:FireServer() end) end
                resetTradeState()
                wait(0.25)
                continue
            end
            if tick()-startTick>=tradeDuration then
                sendMessage("Trade has exceeded 60 seconds — canceling.")
                pcall(function() declineTrade:FireServer() end)
                resetTradeState()
                wait(2)
                continue
            end
        else
            pcall(function() acceptRequest:FireServer() end)
        end
        wait(0.25)
    end
end

local ScreenGui=Instance.new("ScreenGui")
ScreenGui.Name="TradeManagerUI"
ScreenGui.Parent=LocalPlayer.PlayerGui
ScreenGui.ResetOnSpawn=false
ScreenGui.DisplayOrder=9999
ScreenGui.Enabled=true

local uiFrame=Instance.new("Frame")
uiFrame.Size=UDim2.new(0,350,0,100)
uiFrame.Position=UDim2.new(0.5,-175,0.5,-50)
uiFrame.BackgroundColor3=Color3.fromRGB(0,0,0)
uiFrame.BackgroundTransparency=0.7
uiFrame.BorderSizePixel=0
uiFrame.AnchorPoint=Vector2.new(0.5,0.5)
uiFrame.Active=true
uiFrame.Draggable=true
uiFrame.Parent=ScreenGui

local UICorner=Instance.new("UICorner")
UICorner.CornerRadius=UDim.new(0,12)
UICorner.Parent=uiFrame

local button=Instance.new("TextButton")
button.Size=UDim2.new(0,300,0,60)
button.Position=UDim2.new(0.5,-150,0.5,-30)
button.Text="TRADEBOT: OFF"
button.BackgroundColor3=Color3.fromRGB(255,0,0)
button.TextColor3=Color3.fromRGB(255,255,255)
button.TextScaled=true
button.Parent=uiFrame

local buttonCorner=Instance.new("UICorner")
buttonCorner.CornerRadius=UDim.new(0,12)
buttonCorner.Parent=button

button.MouseButton1Click:Connect(function()
    if isTradeProcessActive then
        isTradeProcessActive=false
        button.Text="TRADEBOT: OFF"
        button.BackgroundColor3=Color3.fromRGB(255,0,0)
        tradeThread=nil
    else
        isTradeProcessActive=true
        button.Text="TRADEBOT: ON"
        button.BackgroundColor3=Color3.fromRGB(0,255,0)
        if not tradeThread or coroutine.status(tradeThread)=="dead" then
            tradeThread=coroutine.create(tradeProcess)
            coroutine.resume(tradeThread)
        end
    end
end)

coroutine.wrap(function()
    while true do
        wait(60)
        if isTradeProcessActive then
            local gui=getTradeUI()
            if not gui or not gui.Enabled then
                sendMessage("Hey guys, I am an automated trade-bot, giving godlys for legendaries and below. Send me a trade to try it out :)")
            end
        end
    end
end)()
