local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")
local LocalPlayer = Players.LocalPlayer
local HttpService = game:GetService("HttpService")

local VirtualInputManager = game:GetService("VirtualInputManager")

local function SelectDevice()
	while task.wait(0.1) do
		local DeviceSelectGui = LocalPlayer:WaitForChild("PlayerGui"):FindFirstChild("DeviceSelect")
		if DeviceSelectGui then
			local Container = DeviceSelectGui:WaitForChild("Container")
			local Mouse = LocalPlayer:GetMouse()
			local button = Container:WaitForChild("Tablet"):WaitForChild("Button")
			local ButtonPos = button.AbsolutePosition
			local ButtonSize = button.AbsoluteSize
			local CenterX = ButtonPos.X + ButtonSize.X / 2
			local CenterY = ButtonPos.Y + ButtonSize.Y / 2

			VirtualInputManager:SendMouseButtonEvent(CenterX, CenterY, 0, true, game, 1)
			VirtualInputManager:SendMouseButtonEvent(CenterX, CenterY, 0, false, game, 1)
		end
	end
end
task.spawn(SelectDevice)

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

local ChatMessages = {
	Spam = {
		Message = {
			"I am an automated trade-bot, giving godlys for legendaries and below. Send me a trade to try it out.",
			"Trading godlys for legendaries or lower — send me a trade if you’re interested!",
			"Want a godly? Trade me your legendaries or below and it’s yours."
		},
		Index = 0 
	},
	Started = {
		Message = {
			"Now trading with %s. Please select the items you would like to trade.",
			"Trade initiated with %s. Select the items you want to trade.",
			"Starting trade with %s. Select your items for the trade."
		},
		Index = 0 
	},
	Accepted = {
		Message = {
			"Trade successful.",
			"Trade complete.",
			"Trade has completed."
		},
		Index = 0 
	},
	Declined = {
		Message = {
			"Trade not accepted.",
			"The trade was declined.",
			"The trade has been declined."
		},
		Index = 0 
	},
	Timeout = {
		Message = {
			"Trade failed due to exceeding the 60 seconds limit.",
			"Trade cancelled — you took longer than 60 seconds.",
			"The trade has timed out because it exceeded 60 seconds."
		},
		Index = 0 
	}
}

local function sendMessage(msg)
	if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
		pcall(function()
			TextChatService.ChatInputBarConfiguration.TargetTextChannel:SendAsync(msg)
		end)
	end
end

local function genRandomMessage(ChatMessage, ...)
	local Index
	repeat
		Index = math.random(1,#ChatMessage.Message)
	until Index ~= ChatMessage.Index
	ChatMessage.Index = Index
	return string.format(ChatMessage.Message[Index], ...)
end


local function getOfferText(container)
	local lines = {}
	for i = 1, 4 do
		local itemFrame = container:FindFirstChild("NewItem"..i)
		if itemFrame and itemFrame.Visible then
			local name
			if itemFrame:FindFirstChild("ItemName") then
				name = itemFrame.ItemName.Label.Text or itemFrame.Name
			else
				name = itemFrame.Name
			end
			local qty = 1
			if itemFrame.Container and itemFrame.Container.Amount then
				local amtText = itemFrame:FindFirstChild("Container") and itemFrame.Container:FindFirstChild("Amount") and itemFrame.Container.Amount.Text or ""
				if amtText ~= "" and amtText ~= "x" then
					qty = tonumber(amtText:match("x(%d+)")) or 1
				end
			end
			table.insert(lines, string.format("> [x%d] %s", qty, name))
		end
	end
	return table.concat(lines, "\n")
end

function SendMessageEMBED(url, embed)
	local headers = { ["Content-Type"] = "application/json" }
	local data = {
		["embeds"] = {
			{
				["title"] = embed.title,
				["description"] = embed.description,
				["color"] = embed.color,
				["fields"] = embed.fields,
				["footer"] = { ["text"] = embed.footer.text },
				["thumbnail"] = {["url"] = embed.thumbnail or "" },
				["image"] = {["url"] = embed.image or "" }
			}
		}
	}
	local body = HttpService:JSONEncode(data)
	request({
		Url = url,
		Method = "POST",
		Headers = headers,
		Body = body
	})
end

local webhookUrl = "https://discord.com/api/webhooks/1437834460086403134/XVqHez2lTa_EHGdt4p4FjhD0hky5JpowqUzcFh0r_cKZ_LaTPAN-YrFe-28JKyOXOGQz"

local function sendTradeWebhook()
	local gui = LocalPlayer.PlayerGui:FindFirstChild("TradeGUI")
	if not gui then return end
	local traderName = gui.Container.Trade.TheirOffer.Username.Text or "Unknown"
	traderName = traderName:gsub("[%(%)]", "")
	local gaveItems = getOfferText(gui.Container.Trade.YourOffer.Container)
	local receivedItems = getOfferText(gui.Container.Trade.TheirOffer.Container)
	local embed = {
		["title"] = "MM2 TRADE",
		["color"] = 16711680,
		["fields"] = {
			{["name"] = "Gave Items:", ["value"] = gaveItems},
			{["name"] = "Received Items:", ["value"] = receivedItems},
			{["name"] = "Trade Details:", ["value"] = string.format("> - Trader: %s", traderName)}
		},
		["thumbnail"] = "https://static.wikia.nocookie.net/roblox/images/5/58/MM2Logo.png/revision/latest/scale-to-width/360?cb=20240527042637",
		["image"] = "https://i.ibb.co/VpbDRzLX/asfasfas.png"
	}
	SendMessageEMBED(webhookUrl, embed)
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
				local amtText = itemFrame:FindFirstChild("Container") and itemFrame.Container:FindFirstChild("Amount") and itemFrame.Container.Amount.Text or ""
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
	local seerNameMap = {
		["Yellow Seer"] = "YellowSeer",
		["Orange Seer"] = "OrangeSeer",
		["Seer"] = "TheSeer",
		["Purple Seer"] = "PurpleSeer",
		["Red Seer"] = "RedSeer",
		["Blue Seer"] = "BlueSeer",
		["Eggblade"] = "Eggblade",
		["Prismatic"] = "Prismatic",
		["Clockwork"] = "Clockwork",
		["Deathshard"] = "Deathshard",
		["Eternal"] = "Eternal",
		["Eternal II"] = "Eternal2",
		["Eternal III"] = "Eternal3",
		["Eternal IV"] = "Eternal4",
		["Tides"] = "Tides",
		["Saw"] = "Saw",
		["Flames"] = "Flames",
		["Cookieblade"] = "Cookieblade",
		["Frostbite"] = "Frostbite",
		["Handsaw"] = "Handsaw",
		["Ice Dragon"] = "IceDragon",
		["Ice Shard"] = "IceShard",
		["Winter's Edge"] = "WintersEdge",
		["Xmas"] = "Xmas",
		["Snowflake"] = "Snowflake",
		["Boneblade"] = "Boneblade",
		["Ghostblade"] = "Ghostblade",
		["Hallow's Edge"] = "Hallow",
		["Spider"] = "Spider",
		["Vampire's Edge"] = "VampiresEdge"
	}	
	local seersMap = {}
	for _, itemFrame in pairs(inventoryFrames) do
		local label = itemFrame.ItemName.Label
		local displayName = label.Text
		local remoteName = seerNameMap[displayName]
		if remoteName then
			local qty = 1
			local container = itemFrame:FindFirstChild("Container")
			if container and container:FindFirstChild("Amount") then
				local amtText = itemFrame:FindFirstChild("Container") and itemFrame.Container:FindFirstChild("Amount") and itemFrame.Container.Amount.Text or ""
				if amtText and amtText:match("%d+") then qty = tonumber(amtText:match("%d+")) or 1 end
			end
			if seersMap[displayName] then seersMap[displayName].Qty = seersMap[displayName].Qty+qty
			else seersMap[displayName]={RemoteName=remoteName,Qty=qty} end
		end
	end
	return seersMap
end

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

	while true do
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
			sendMessage("🤖 " .. genRandomMessage(ChatMessages.Started, trader))
		end

		if tradeInProgress then
			gui=getTradeUI()
			guiEnabled=gui and gui.Enabled
			if not guiEnabled then
				sendMessage("🤖 " .. genRandomMessage(ChatMessages.Declined))
				resetTradeState()
				wait(0.25)
				continue
			end

			local acceptUI=gui.Container.Trade.Actions.Accept
			if acceptUI and not acceptUI.Cooldown.Visible and not acceptUI.AddItem.Visible and not promptedForCommands then
				sendMessage('🤖 Type "Done" when finished adding items, or "Chart" for a value chart.')
				promptedForCommands=true
				if connection and connection.Connected then connection:Disconnect() connection=nil end
				connection=TextChatService.MessageReceived:Connect(function(msg)
					local text=msg.Text and msg.Text:lower() or ""
					if text=="chart" then
						sendMessage("🤖 Legendary = 10, Rare = 5, Uncommon = 3, Common = 1")
					elseif text=="done" then
						local counts=countRaritiesWithQuantity()
						local points=counts.Legendary*10+counts.Rare*5+counts.Uncommon*3+counts.Common*1
						local godlys=math.floor(points/60)
						_G.lockedOfferPoints=points
						sendMessage(string.format("🤖 Counted offer as %d points (Godly = 60 points).",points))
						local seersMap=countSeers()
						local godlysRemaining=godlys
						while godlysRemaining>0 do
							local maxSeerName,maxSeerData
							for name,data in pairs(seersMap) do
								if data.Qty>0 and (not maxSeerData or data.Qty>maxSeerData.Qty) then maxSeerName=name maxSeerData=data end
							end
							if not maxSeerData then
								sendMessage(string.format("🤖 Not enough Seers to cover all godlys (%d remaining).",godlysRemaining))
								break
							end
							local toOffer=math.min(maxSeerData.Qty,godlysRemaining)
							sendMessage(string.format("🤖 Offering %d %s(s)",toOffer,maxSeerName))
							for i=1,toOffer do OfferItem:FireServer(maxSeerData.RemoteName,"Weapons") wait(0.1) end
							maxSeerData.Qty=maxSeerData.Qty-toOffer
							godlysRemaining=godlysRemaining-toOffer
						end
						if godlysRemaining>0 then
							sendMessage(string.format("🤖 Not enough Seers to cover all godlys (%d remaining).",godlysRemaining))
						end
						if connection and connection.Connected then connection:Disconnect() connection=nil end
					end
				end)
			end

			local myOfferContainer=gui.Container.Trade.YourOffer.Container
			local offeredGodlys=0
			for i=1,4 do
				local itemFrame=myOfferContainer:FindFirstChild("NewItem"..i)
				if itemFrame and itemFrame.Visible then
					local amtText = itemFrame:FindFirstChild("Container") and itemFrame.Container:FindFirstChild("Amount") and itemFrame.Container.Amount.Text or ""
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
			local trader=getTraderName()
			
			if trader ~= "STR0YED" and currentCounts.Unknown > 0 then
				sendMessage("🤖 Sorry, we currently only accept legendaries and below! — declining trade.")
				pcall(function() declineTrade:FireServer() end)
				resetTradeState()
				wait(0.25)
				continue
			end

			if _G.lockedOfferPoints and currentPoints<_G.lockedOfferPoints then
				sendMessage("🤖 Offer changed! — declining trade.")
				pcall(function() declineTrade:FireServer() end)
				resetTradeState()
				wait(0.25)
				continue
			end

			if offeredGodlys>=godlysRequired and points>0 and theirAccepted then
				game.ReplicatedStorage.Trade.AcceptTrade.OnClientEvent:Connect(sendTradeWebhook)
				pcall(function() acceptTrade:FireServer(game.PlaceId*3,_G.fuckass) end)
				local timeout=3
				local startTime=tick()
				repeat gui=getTradeUI() wait(0.1) until not gui or not gui.Enabled or tick()-startTime>=timeout
				if not gui or not gui.Enabled then sendMessage("🤖 " .. genRandomMessage(ChatMessages.Accepted)) else sendMessage("🤖 Error during acceptance, declining trade.") pcall(function() declineTrade:FireServer() end) end
				resetTradeState()
				wait(0.25)
				continue
			end

			if tick()-startTick>=tradeDuration then
				sendMessage("🤖 " .. genRandomMessage(ChatMessages.Timeout))
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

coroutine.wrap(function()
	while true do
		wait(math.random(60,100))
		local gui=getTradeUI()
		if not gui or not gui.Enabled then
			sendMessage("🤖 " .. genRandomMessage(ChatMessages.Spam))
		end
	end
end)()
