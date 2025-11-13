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

game.ReplicatedStorage.Trade.UpdateTrade.OnClientEvent:Connect(function(v)
    _G.fuckass = v.LastOffer
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
    local r,g,b=math.floor(color.R*255),math.floor(color.G*255),math.floor(color.B*255)
    if r==220 and g==0 and b==5 then return"Legendary"
    elseif r==0 and g==200 and b==0 then return"Rare"
    elseif r==0 and g==255 and b==255 then return"Uncommon"
    elseif r==106 and g==106 and b==106 then return"Common"
    else return"Unknown"end
end

local function countRaritiesWithQuantity()
    local gui=getTradeUI()
    if not gui then return{}end
    local c=gui.Container.Trade.TheirOffer.Container
    local r={Legendary=0,Rare=0,Uncommon=0,Common=0,Unknown=0}
    for i=1,4 do
        local f=c:FindFirstChild("NewItem"..i)
        if f and f.Visible then
            local rarity=getRarityFromColor(f.ItemName.BackgroundColor3)
            local q=1
            if f.Container and f.Container.Amount then
                local t=f.Container.Amount.Text
                if t~=""and t~="x"then q=tonumber(t:match("x(%d+)"))or 1 end
            end
            r[rarity]+=q
        end
    end
    return r
end

local isTradeProcessActive=false
local tradeThread=nil

local function tradeProcess()
    local tradeInProgress=false
    local tradeDuration=60
    local cooldown=false
    local connection=nil
    local promptedForCommands=false
    local startTick=0
    while isTradeProcessActive do
        if cooldown then
            for i=1,5 do pcall(function()declineRequest:FireServer()end)wait(1)end
            cooldown=false
        end
        local gui=getTradeUI()
        local guiEnabled=gui and gui.Enabled
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
                tradeInProgress=false
                cooldown=true
                if connection and connection.Connected then connection:Disconnect()connection=nil end
                wait(2)
                continue
            end
            local acceptUI=gui.Container.Trade.Actions.Accept
            if acceptUI and not acceptUI.Cooldown.Visible and not acceptUI.AddItem.Visible and not promptedForCommands then
                sendMessage('Type "Done" when finished adding items, or "Chart" for a value chart.')
                promptedForCommands=true
                connection=TextChatService.MessageReceived:Connect(function(msg)
                    local text=msg.Text and msg.Text:lower()or""
                    if text=="chart"then
                        sendMessage("Legendary = 10, Rare = 5, Uncommon = 3, Common = 1")
                    elseif text=="done"then
                        local counts=countRaritiesWithQuantity()
                        local points=counts.Legendary*10+counts.Rare*5+counts.Uncommon*3+counts.Common*1
                        local godlys=math.floor(points/60)
                        sendMessage(string.format("Offer counted as %d points, 60 points = 1 godly.",points,godlys))
                        local inventory={}
                        for _,f in pairs(LocalPlayer.PlayerGui:GetDescendants())do
                            if f:IsA("Frame")and f.Name:match("NewItem")then
                                if f:FindFirstChild("ItemName")and f.ItemName:FindFirstChild("Label")then
                                    table.insert(inventory,f)
                                end
                            end
                        end
                        local seerNameMap={["Yellow Seer"]="YellowSeer",["Orange Seer"]="OrangeSeer",["Purple Seer"]="PurpleSeer",["Red Seer"]="RedSeer"}
                        local seersMap={}
                        for _,itemFrame in pairs(inventory)do
                            local label=itemFrame:FindFirstChild("ItemName")and itemFrame.ItemName:FindFirstChild("Label")
                            if label then
                                local displayName=label.Text
                                local remoteName=seerNameMap[displayName]
                                if remoteName then
                                    local qty=1
                                    if itemFrame:FindFirstChild("Container")and itemFrame.Container:FindFirstChild("Amount")then
                                        local amt=itemFrame.Container.Amount.Text
                                        if amt~=""and amt~="x"then qty=tonumber(amt:match("x(%d+)"))or 1 end
                                    end
                                    if seersMap[displayName]then seersMap[displayName].Qty+=qty
                                    else seersMap[displayName]={RemoteName=remoteName,Qty=qty}end
                                end
                            end
                        end
                        local godlysRemaining=godlys
                        for displayName,seer in pairs(seersMap)do
                            if godlysRemaining<=0 then break end
                            local toOffer=math.min(seer.Qty,godlysRemaining)
                            sendMessage(string.format("Offering %d %s(s)",toOffer,displayName))
                            for i=1,toOffer do
                                OfferItem:FireServer(seer.RemoteName,"Weapons")
                                wait(0.1)
                            end
                            godlysRemaining-=toOffer
                        end
                        if godlysRemaining>0 then sendMessage("Not enough Seers to cover all godlys.")end
                        if connection and connection.Connected then connection:Disconnect()connection=nil end
                    end
                end)
            end
            local myOffer=gui.Container.Trade.YourOffer.Container
            local offeredGodlys=0
            for i=1,4 do
                local f=myOffer:FindFirstChild("NewItem"..i)
                if f and f.Visible then
                    local t=f.Container.Amount.Text
                    local q=1
                    if t~=""and t~="x"then q=tonumber(t:match("x(%d+)"))or 1 end
                    offeredGodlys+=q
                end
            end
            local counts=countRaritiesWithQuantity()
            local points=counts.Legendary*10+counts.Rare*5+counts.Uncommon*3+counts.Common*1
            local godlysRequired=math.floor(points/60)
            local theirAccepted=gui.Container.Trade.TheirOffer.Accepted.Visible
            if offeredGodlys>=godlysRequired and points>0 and theirAccepted then
                pcall(function()acceptTrade:FireServer(game.PlaceId*3,_G.fuckass)end)
                local timeout=3
                local t0=tick()
                repeat gui=getTradeUI()wait(0.1)until not gui or not gui.Enabled or tick()-t0>=timeout
                if not gui or not gui.Enabled then sendMessage("Trade Accepted, GG :)")
                else sendMessage("Error, Declining Trade!")declineTrade:FireServer()end
                tradeInProgress=false
                cooldown=true
                if connection and connection.Connected then connection:Disconnect()connection=nil end
            end
            if tick()-startTick>=tradeDuration then
                sendMessage("The trade has exceeded 60 seconds.")
                pcall(function()declineTrade:FireServer()end)
                tradeInProgress=false
                cooldown=true
                if connection and connection.Connected then connection:Disconnect()connection=nil end
                wait(2)
            end
        else
            pcall(function()acceptRequest:FireServer()end)
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
        if not tradeThread or coroutine.status(tradeThread)=="dead"then
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
