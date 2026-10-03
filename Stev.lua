local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local TextChatService = game:GetService("TextChatService")
local TweenService = game:GetService("TweenService")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:FindFirstChildWhichIsA("PlayerGui")
local placeId = game.PlaceId
local jobId = game.JobId

local writefile = writefile or nil
local readfile = readfile or nil
local isfile = isfile or nil
local firetouchinterest = firetouchinterest or nil

local MachoHub = {}
local WM = {}
local Config = {
	GodMode = false,
	AntiFling = false,
	EnableWalkSpeed = false,
	WalkSpeed = 16,
	EnableJumpPower = false,
	JumpPower = 50,
	Noclip = false,
	InfiniteJump = false,
	AutoGrabGun = false,
	AutoKill = false,
	KnifeAura = false,
	AuraRadius = 10,
	EspPlayers = false,
	ShowNames = false,
	EspDroppedGun = false,
	SilentThrow = false,
	AutoShootMurderer = false,
	NotifyMurderer = false,
	NotifySheriff = false,
	NotifyGunDropped = false,
	CoinFarm = false,
	ButtonsLocked = false,
	RoundTimer = false,
}

if getgenv().MachoHub_Connections then
	for k, conn in pairs(getgenv().MachoHub_Connections) do
		if conn then
			pcall(function()
				conn:Disconnect()
			end)
		end
		getgenv().MachoHub_Connections[k] = nil
	end
end
getgenv().MachoHub_Connections = {}

for _, child in ipairs(CoreGui:GetChildren()) do
	if child.Name:match("^Macho") then
		pcall(function()
			child:Destroy()
		end)
	end
end
for _, child in ipairs(playerGui:GetChildren()) do
	if child.Name:match("^Macho") then
		pcall(function()
			child:Destroy()
		end)
	end
end
for _, player in ipairs(Players:GetPlayers()) do
	if player.Character then
		local highlight = player.Character:FindFirstChild("MachoHighlight")
		if highlight then
			highlight:Destroy()
		end
		local head = player.Character:FindFirstChild("Head")
		if head then
			local nameESP = head:FindFirstChild("NameESP")
			if nameESP then
				nameESP:Destroy()
			end
		end
	end
end
for _, descendant in ipairs(Workspace:GetDescendants()) do
	if descendant.Name == "MachoGunHighlight" or descendant.Name == "MachoGunLabel" then
		descendant:Destroy()
	end
end
if getgenv().FPDH then
	Workspace.FallenPartsDestroyHeight = getgenv().FPDH
end

local function trackConnection(conn)
	local list = getgenv().MachoHub_Connections
	for i = #list, 1, -1 do
		if not list[i] or not list[i].Connected then
			table.remove(list, i)
		end
	end
	table.insert(list, conn)
	return conn
end

MachoHub.Player = localPlayer
MachoHub.PlayerGui = playerGui
MachoHub.PlaceId = placeId
MachoHub.JobId = jobId
MachoHub.RunService = RunService
MachoHub.UserInputService = UserInputService
MachoHub.Lighting = Lighting
MachoHub.Workspace = Workspace
MachoHub.ReplicatedStorage = ReplicatedStorage
MachoHub.HttpService = HttpService
MachoHub.TextChatService = TextChatService
MachoHub.Character = nil
MachoHub.Humanoid = nil
MachoHub.RootPart = nil
MachoHub.Backpack = nil
MachoHub.Camera = nil
MachoHub.PlayerData = {}
MachoHub.Config = Config
MachoHub.MobileButtons = {}

WM.LocalPlayer = localPlayer
WM.LocalCharacter = nil
WM.LocalHumanoid = nil
WM.LocalRootPart = nil
WM.Players = {}
WM.RoleCache = {}
WM.GunDrop = nil
WM.Map = nil
WM.Lobby = nil
WM.Connections = {}
WM.Events = {
	PlayerAdded = {},
	PlayerRemoved = {},
	CharacterAdded = {},
	RoleChanged = {},
	GunDropped = {},
	MapChanged = {},
}
WM._started = false

function WM.On(eventName, callback)
	if not WM.Events[eventName] then
		WM.Events[eventName] = {}
	end
	table.insert(WM.Events[eventName], callback)
	return function()
		for i, cb in ipairs(WM.Events[eventName]) do
			if cb == callback then
				table.remove(WM.Events[eventName], i)
				break
			end
		end
	end
end

function WM._fire(eventName, ...)
	local args = table.pack(...)
	for _, cb in ipairs(WM.Events[eventName] or {}) do
		pcall(cb, table.unpack(args, 1, args.n))
	end
end

function WM._indexCharacter(player, character)
	if not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 5)
	local hrp = character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart
	WM.Players[player] = WM.Players[player] or {}
	WM.Players[player].Character = character
	WM.Players[player].Humanoid = humanoid
	WM.Players[player].HRP = hrp
	WM.Players[player].IsAlive = humanoid and humanoid.Health > 0 or false
	if player == localPlayer then
		WM.LocalCharacter = character
		WM.LocalHumanoid = humanoid
		WM.LocalRootPart = hrp
		MachoHub.Character = character
		MachoHub.Humanoid = humanoid
		MachoHub.RootPart = hrp
		MachoHub.Backpack = localPlayer:FindFirstChild("Backpack")
	end
	if humanoid then
		table.insert(WM.Connections, humanoid.HealthChanged:Connect(function(health)
			if WM.Players[player] then
				WM.Players[player].IsAlive = health > 0
			end
		end))
		table.insert(WM.Connections, humanoid.Died:Connect(function()
			if WM.Players[player] then
				WM.Players[player].IsAlive = false
			end
		end))
	end
	WM._fire("CharacterAdded", player, character)
end

function WM._updateRole(player, role)
	if not player then
		return
	end
	WM.RoleCache[player.Name] = role
	if WM.Players[player] then
		WM.Players[player].Role = role
	end
	WM._fire("RoleChanged", player, role)
end

function WM.findMap()
	for _, child in ipairs(Workspace:GetChildren()) do
		if child:FindFirstChild("CoinContainer") and child:FindFirstChild("Spawns") then
			return child
		end
	end
	return nil
end

function WM.findLobby()
	for _, child in ipairs(Workspace:GetChildren()) do
		if child:FindFirstChild("Lobby") then
			return child.Lobby
		end
		if child.Name:lower() == "lobby" then
			return child
		end
	end
	return nil
end

function WM.findMurderer()
	for _, player in ipairs(Players:GetPlayers()) do
		if player:FindFirstChild("Backpack") and player.Backpack:FindFirstChild("Knife") then
			return player
		end
	end
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character and player.Character:FindFirstChild("Knife") then
			return player
		end
	end
	for name, role in pairs(WM.RoleCache) do
		if role == "Murderer" then
			local p = Players:FindFirstChild(name)
			if p then
				return p
			end
		end
	end
	return nil
end

function WM.findSheriff()
	for _, player in ipairs(Players:GetPlayers()) do
		if player:FindFirstChild("Backpack") and player.Backpack:FindFirstChild("Gun") then
			return player
		end
	end
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character and player.Character:FindFirstChild("Gun") then
			return player
		end
	end
	for name, role in pairs(WM.RoleCache) do
		if role == "Sheriff" then
			local p = Players:FindFirstChild(name)
			if p then
				return p
			end
		end
	end
	return nil
end

function WM.findSheriffExceptMe()
	local sheriff = WM.findSheriff()
	if sheriff and sheriff ~= localPlayer then
		return sheriff
	end
	return nil
end

function WM.start()
	if WM._started then
		return
	end
	WM._started = true
	task.spawn(function()
		while true do
			local map = WM.findMap()
			if map ~= WM.Map then
				WM.Map = map
				WM._fire("MapChanged", map)
			end
			WM.Lobby = WM.findLobby()
			task.wait(2)
		end
	end)
	table.insert(WM.Connections, Workspace.DescendantAdded:Connect(function(descendant)
		if descendant.Name == "GunDrop" and descendant:IsA("BasePart") then
			WM.GunDrop = descendant
			task.delay(0.3, function()
				WM._fire("GunDropped", descendant)
			end)
		end
	end))
	if localPlayer.Character then
		WM._indexCharacter(localPlayer, localPlayer.Character)
	end
	table.insert(WM.Connections, localPlayer.CharacterAdded:Connect(function(character)
		WM._indexCharacter(localPlayer, character)
	end))
	localPlayer.CharacterRemoving:Connect(function()
		WM.LocalCharacter = nil
		WM.LocalHumanoid = nil
		WM.LocalRootPart = nil
		MachoHub.Character = nil
		MachoHub.Humanoid = nil
		MachoHub.RootPart = nil
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			WM._indexCharacter(player, player.Character)
		end
		player.CharacterAdded:Connect(function(character)
			WM._indexCharacter(player, character)
		end)
	end
	table.insert(WM.Connections, Players.PlayerAdded:Connect(function(player)
		WM._fire("PlayerAdded", player)
		player.CharacterAdded:Connect(function(character)
			WM._indexCharacter(player, character)
		end)
		if player.Character then
			WM._indexCharacter(player, player.Character)
		end
	end))
	table.insert(WM.Connections, Players.PlayerRemoving:Connect(function(player)
		WM.Players[player] = nil
		WM.RoleCache[player.Name] = nil
		WM._fire("PlayerRemoved", player)
	end))
	task.spawn(function()
		local remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
		if not remotes then
			return
		end
		local gameplay = remotes:FindFirstChild("Gameplay") or remotes:FindFirstChild("Gameplay", true)
		if gameplay then
			local playerDataChanged = gameplay:FindFirstChild("PlayerDataChanged")
			if playerDataChanged and playerDataChanged:IsA("RemoteEvent") then
				playerDataChanged.OnClientEvent:Connect(function(playerData)
					if type(playerData) ~= "table" then
						return
					end
					MachoHub.PlayerData = playerData
					for name, data in pairs(playerData) do
						local p = Players:FindFirstChild(name)
						local role = data.Role or data.role
						if p and role then
							WM._updateRole(p, role)
						end
					end
				end)
			end
		end
		local getPlayerData = ReplicatedStorage:FindFirstChild("GetPlayerData", true)
		if getPlayerData and typeof(getPlayerData.InvokeServer) == "function" then
			pcall(function()
				local ok, playerData = pcall(function()
					return getPlayerData:InvokeServer()
				end)
				if ok and type(playerData) == "table" then
					MachoHub.PlayerData = playerData
					for name, data in pairs(playerData) do
						local p = Players:FindFirstChild(name)
						local role = data.Role or data.role
						if p and role then
							WM._updateRole(p, role)
						end
					end
				end
			end)
		end
	end)
	task.spawn(function()
		while true do
			local murderer = WM.findMurderer()
			if murderer then
				WM._updateRole(murderer, "Murderer")
			end
			local sheriff = WM.findSheriff()
			if sheriff then
				WM._updateRole(sheriff, "Sheriff")
			end
			task.wait(3)
		end
	end)
end

MachoHub.WM = WM

local function flingPlayer(target)
	if not target or not target.Character then
		return
	end
	local character = localPlayer.Character
	if not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid") or character:FindFirstChild("Humanoid")
	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart
	if not humanoid or not humanoidRootPart then
		return
	end
	local targetCharacter = target.Character
	local targetHumanoid = targetCharacter and targetCharacter:FindFirstChildOfClass("Humanoid")
	local targetHRP = targetHumanoid and (targetCharacter:FindFirstChild("HumanoidRootPart") or targetCharacter.PrimaryPart or targetHumanoid.RootPart)
	local targetHead = targetCharacter and targetCharacter:FindFirstChild("Head")
	local accessory = targetCharacter and targetCharacter:FindFirstChildOfClass("Accessory")
	local handle = accessory and accessory:FindFirstChild("Handle")
	if humanoidRootPart.Velocity.Magnitude < 50 then
		getgenv().OldPos = humanoidRootPart.CFrame
	end
	local currentCamera = workspace.CurrentCamera
	if targetHead then
		currentCamera.CameraSubject = targetHead
	elseif handle then
		currentCamera.CameraSubject = handle
	elseif targetHumanoid and targetHRP then
		currentCamera.CameraSubject = targetHumanoid
	end
	if not (targetCharacter and targetCharacter:FindFirstChildWhichIsA("BasePart")) then
		return
	end
	local function applyFling(targetPart, offset, angle)
		humanoidRootPart.CFrame = CFrame.new(targetPart.Position) * offset * angle
		pcall(function()
			if character and character.PrimaryPart then
				character:SetPrimaryPartCFrame(CFrame.new(targetPart.Position) * offset * angle)
			end
		end)
		humanoidRootPart.Velocity = Vector3.new(90000000, 900000000, 90000000)
		humanoidRootPart.RotVelocity = Vector3.new(900000000, 900000000, 900000000)
	end
	local function flingLoop(targetPart)
		local start = tick()
		local rot = 0
		while true do
			if humanoidRootPart and targetHumanoid then
				if targetPart.Velocity.Magnitude < 50 then
					rot = rot + 100
					local move = targetHumanoid.MoveDirection * targetPart.Velocity.Magnitude / 1.25
					applyFling(targetPart, CFrame.new(0, 1.5, 0) + move, CFrame.Angles(math.rad(rot), 0, 0))
					task.wait()
					move = targetHumanoid.MoveDirection * targetPart.Velocity.Magnitude / 1.25
					applyFling(targetPart, CFrame.new(0, -1.5, 0) + move, CFrame.Angles(math.rad(rot), 0, 0))
					task.wait()
					move = targetHumanoid.MoveDirection * targetPart.Velocity.Magnitude / 1.25
					applyFling(targetPart, CFrame.new(2.25, 1.5, -2.25) + move, CFrame.Angles(math.rad(rot), 0, 0))
					task.wait()
					move = targetHumanoid.MoveDirection * targetPart.Velocity.Magnitude / 1.25
					applyFling(targetPart, CFrame.new(-2.25, -1.5, 2.25) + move, CFrame.Angles(math.rad(rot), 0, 0))
					task.wait()
				else
					applyFling(targetPart, CFrame.new(0, 1.5, targetHumanoid.WalkSpeed), CFrame.Angles(math.pi / 2, 0, 0))
					task.wait()
					applyFling(targetPart, CFrame.new(0, -1.5, -targetHumanoid.WalkSpeed), CFrame.Angles(0, 0, 0))
					task.wait()
					applyFling(targetPart, CFrame.new(0, 1.5, targetHumanoid.WalkSpeed), CFrame.Angles(math.pi / 2, 0, 0))
					task.wait()
					local mag = targetHRP and targetHRP.Velocity.Magnitude / 1.25 or 0
					applyFling(targetPart, CFrame.new(0, 1.5, mag), CFrame.Angles(math.pi / 2, 0, 0))
					task.wait()
					mag = targetHRP and targetHRP.Velocity.Magnitude / 1.25 or 0
					applyFling(targetPart, CFrame.new(0, -1.5, -mag), CFrame.Angles(0, 0, 0))
					task.wait()
				end
				if targetPart.Velocity.Magnitude > 500
					or targetPart.Parent ~= target.Character
					or target.Parent ~= Players
					or target.Character ~= targetCharacter
					or (targetHumanoid and targetHumanoid.Sit)
					or (humanoid and humanoid.Health <= 0)
					or tick() > start + 2 then
					break
				end
			else
				break
			end
		end
	end
	if not getgenv().FPDH then
		getgenv().FPDH = workspace.FallenPartsDestroyHeight
	end
	workspace.FallenPartsDestroyHeight = 0 / 0
	local bodyVelocity = Instance.new("BodyVelocity")
	bodyVelocity.Name = "EpixVel"
	bodyVelocity.Parent = humanoidRootPart
	bodyVelocity.Velocity = Vector3.new(900000000, 900000000, 900000000)
	bodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, false)
	if targetHRP and targetHead then
		if (targetHRP.CFrame.p - targetHead.CFrame.p).Magnitude > 5 then
			flingLoop(targetHead)
		else
			flingLoop(targetHRP)
		end
	elseif targetHRP and not targetHead then
		flingLoop(targetHRP)
	elseif not targetHRP and targetHead then
		flingLoop(targetHead)
	elseif not targetHRP and not targetHead and accessory and handle then
		flingLoop(handle)
	end
	if bodyVelocity and bodyVelocity.Parent then
		bodyVelocity:Destroy()
	end
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, true)
	workspace.CurrentCamera.CameraSubject = humanoid
	while true do
		if getgenv().OldPos then
			humanoidRootPart.CFrame = getgenv().OldPos * CFrame.new(0, 0.5, 0)
			pcall(function()
				if character and character.PrimaryPart then
					character:SetPrimaryPartCFrame(getgenv().OldPos * CFrame.new(0, 0.5, 0))
				end
			end)
		end
		humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		for _, child in ipairs(character:GetChildren()) do
			if child:IsA("BasePart") then
				child.Velocity = Vector3.zero
				child.RotVelocity = Vector3.zero
			end
		end
		task.wait()
		if not getgenv().OldPos or (humanoidRootPart.Position - getgenv().OldPos.p).Magnitude < 25 then
			break
		end
	end
	if getgenv().FPDH then
		workspace.FallenPartsDestroyHeight = getgenv().FPDH
	end
end

MachoHub.GetPlayerByName = function(name)
	if not name then
		return nil
	end
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Name:lower() == name:lower() then
			return player
		end
	end
	return nil
end

MachoHub.FindMurderer = function()
	return WM.findMurderer()
end

MachoHub.FindSheriff = function()
	return WM.findSheriff()
end

MachoHub.FindSheriffThatsNotMe = function()
	return WM.findSheriffExceptMe()
end

local function getMap()
	return WM.Map or WM.findMap()
end

local function getLobby()
	return WM.Lobby or WM.findLobby()
end

local antiFlingConn = nil
MachoHub.ToggleAntiFling = function(enabled)
	Config.AntiFling = enabled
	if antiFlingConn then
		antiFlingConn:Disconnect()
		antiFlingConn = nil
	end
	if enabled then
		antiFlingConn = trackConnection(RunService.Stepped:Connect(function()
			if not MachoHub.Character then
				return
			end
			for _, player in ipairs(Players:GetPlayers()) do
				if player ~= localPlayer and player.Character then
					for _, child in ipairs(player.Character:GetChildren()) do
						if child:IsA("BasePart") and child.CanCollide then
							child.CanCollide = false
							if child.Name == "HumanoidRootPart" then
								child.Velocity = Vector3.zero
								child.RotVelocity = Vector3.zero
							end
						end
					end
				end
			end
		end))
	end
end

MachoHub.Rejoin = function()
	pcall(function()
		TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, localPlayer)
	end)
end

MachoHub.ServerHop = function()
	local currentJobId = game.JobId
	local currentPlaceId = game.PlaceId
	local timeout = 10
	local start = tick()
	task.spawn(function()
		while true do
			local ok, result = pcall(function()
				local url = ("https://games.roblox.com/v1/games/%d/servers/Public?limit=100&sortOrder=Asc"):format(currentPlaceId)
				return HttpService:JSONDecode(game:HttpGet(url))
			end)
			if ok and result and result.data then
				local servers = {}
				for _, server in pairs(result.data) do
					if type(server) == "table" and server.playing and server.maxPlayers and server.playing < server.maxPlayers and server.id and server.id ~= currentJobId then
						table.insert(servers, server)
					end
				end
				if #servers > 0 then
					local chosen = servers[math.random(1, #servers)]
					pushNotify({ Title = "Server Hop", Content = "Hopping...", Duration = 3, Color = Colors.success })
					pcall(function()
						TeleportService:TeleportToPlaceInstance(currentPlaceId, chosen.id, localPlayer)
					end)
					return
				end
			end
			task.wait(3)
			if tick() - start > timeout then
				break
			end
		end
		pushNotify({ Title = "Server Hop", Content = "Failed. Try again.", Duration = 5, Color = Colors.danger })
		pcall(function()
			TeleportService:Teleport(currentPlaceId, localPlayer)
		end)
	end)
end

MachoHub.TeleportToMap = function()
	local character = WM.LocalCharacter
	if not character then
		return
	end
	local map = WM.Map or WM.findMap()
	if not map then
		return
	end
	local spawns = map:FindFirstChild("Spawns")
	if not spawns then
		return
	end
	local spawnList = {}
	for _, child in ipairs(spawns:GetChildren()) do
		if child:IsA("BasePart") then
			table.insert(spawnList, child)
		end
	end
	local spawn = #spawnList > 0 and spawnList[math.random(1, #spawnList)] or spawns:FindFirstChild("Spawn") or spawns:FindFirstChild("SpawnLocation")
	if spawn then
		character:PivotTo(spawn.CFrame * CFrame.new(0, 5, 0))
	end
end

MachoHub.TeleportToLobby = function()
	local character = WM.LocalCharacter
	if not character then
		return
	end
	local lobby = WM.Lobby or WM.findLobby()
	if not lobby then
		return
	end
	local spawns = lobby:FindFirstChild("Spawns")
	if not spawns then
		return
	end
	local spawnList = {}
	for _, child in ipairs(spawns:GetChildren()) do
		if child:IsA("BasePart") then
			table.insert(spawnList, child)
		end
	end
	local spawn = #spawnList > 0 and spawnList[math.random(1, #spawnList)] or spawns:FindFirstChild("SpawnLocation")
	if spawn then
		character:PivotTo(spawn.CFrame * CFrame.new(0, 5, 0))
	end
end

MachoHub.TeleportToPlayer = function(player)
	if not WM.LocalCharacter or not WM.LocalRootPart then
		return false
	end
	if not (player and player.Character and player.Character.PrimaryPart) then
		return false
	end
	return pcall(function()
		WM.LocalCharacter:SetPrimaryPartCFrame(player.Character.PrimaryPart.CFrame * CFrame.new(0, 3, 0))
	end)
end

local godModeConn = nil
MachoHub.EnableGodMode = function(enabled)
	Config.GodMode = enabled
	if godModeConn then
		godModeConn:Disconnect()
		godModeConn = nil
	end
	if not enabled then
		return
	end
	local function attachGodMode(humanoid)
		if not humanoid then
			return
		end
		local healthConn = humanoid.HealthChanged:Connect(function(health)
			if Config.GodMode and health < humanoid.MaxHealth then
				humanoid.Health = humanoid.MaxHealth
			end
		end)
		task.spawn(function()
			while Config.GodMode and humanoid.Parent do
				if humanoid.Health < humanoid.MaxHealth then
					humanoid.Health = humanoid.MaxHealth
				end
				if humanoid:GetState() == Enum.HumanoidStateType.Dead then
					humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
					humanoid.Health = humanoid.MaxHealth
				end
				task.wait(0.2)
			end
			if healthConn then
				healthConn:Disconnect()
			end
		end)
	end
	if WM.LocalHumanoid then
		attachGodMode(WM.LocalHumanoid)
	end
	godModeConn = trackConnection(localPlayer.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid", 5)
		if humanoid then
			task.wait(0.5)
			attachGodMode(humanoid)
		end
	end))
end

local walkSpeedConn = nil
MachoHub.EnableWalkSpeed = function(enabled)
	Config.EnableWalkSpeed = enabled
	if walkSpeedConn then
		walkSpeedConn:Disconnect()
		walkSpeedConn = nil
	end
	if enabled then
		walkSpeedConn = trackConnection(RunService.Heartbeat:Connect(function()
			if WM.LocalHumanoid and WM.LocalHumanoid.WalkSpeed ~= Config.WalkSpeed then
				WM.LocalHumanoid.WalkSpeed = Config.WalkSpeed
			end
		end))
	elseif WM.LocalHumanoid then
		WM.LocalHumanoid.WalkSpeed = 16
	end
end

MachoHub.SetWalkSpeed = function(value)
	Config.WalkSpeed = math.clamp(value, 16, 200)
	if Config.EnableWalkSpeed and WM.LocalHumanoid then
		WM.LocalHumanoid.WalkSpeed = Config.WalkSpeed
	end
end

local jumpPowerConn = nil
MachoHub.EnableJumpPower = function(enabled)
	Config.EnableJumpPower = enabled
	if jumpPowerConn then
		jumpPowerConn:Disconnect()
		jumpPowerConn = nil
	end
	if enabled then
		jumpPowerConn = trackConnection(RunService.Heartbeat:Connect(function()
			if WM.LocalHumanoid and WM.LocalHumanoid.JumpPower ~= Config.JumpPower then
				WM.LocalHumanoid.JumpPower = Config.JumpPower
			end
		end))
	elseif WM.LocalHumanoid then
		WM.LocalHumanoid.JumpPower = 50
	end
end

MachoHub.SetJumpPower = function(value)
	Config.JumpPower = math.clamp(value, 50, 300)
	if Config.EnableJumpPower and WM.LocalHumanoid then
		WM.LocalHumanoid.JumpPower = Config.JumpPower
	end
end

local noclipConn = nil
MachoHub.EnableNoclip = function(enabled)
	Config.Noclip = enabled
	if noclipConn then
		noclipConn:Disconnect()
		noclipConn = nil
	end
	if enabled then
		noclipConn = trackConnection(RunService.Stepped:Connect(function()
			if WM.LocalCharacter then
				for _, descendant in ipairs(WM.LocalCharacter:GetDescendants()) do
					if descendant:IsA("BasePart") then
						descendant.CanCollide = false
					end
				end
			end
		end))
	end
end

local infiniteJumpConn = nil
MachoHub.InfiniteJump = function(enabled)
	Config.InfiniteJump = enabled
	if infiniteJumpConn then
		infiniteJumpConn:Disconnect()
		infiniteJumpConn = nil
	end
	if enabled then
		infiniteJumpConn = trackConnection(UserInputService.JumpRequest:Connect(function()
			if WM.LocalHumanoid then
				WM.LocalHumanoid:ChangeState(Enum.HumanoidStateType.Jumping)
			end
		end))
	end
end

local autoGrabConn = nil
MachoHub.GrabGun = function()
	local root = WM.LocalRootPart
	if not root then
		return
	end
	local map = WM.Map or WM.findMap()
	if not map then
		return
	end
	local gunDrop = map:FindFirstChild("GunDrop")
	if gunDrop and gunDrop:IsA("BasePart") then
		pcall(function()
			firetouchinterest(gunDrop, root, 1)
			firetouchinterest(gunDrop, root, 0)
		end)
	end
end

MachoHub.ToggleAutoGrabGun = function(enabled)
	Config.AutoGrabGun = enabled
	if autoGrabConn then
		autoGrabConn:Disconnect()
		autoGrabConn = nil
	end
	if enabled then
		autoGrabConn = trackConnection(RunService.Heartbeat:Connect(MachoHub.GrabGun))
	end
end

MachoHub.KillAll = function()
	if not firetouchinterest then
		return
	end
	if not MachoHub.Backpack or not WM.LocalCharacter or not WM.LocalHumanoid then
		return
	end
	local knife = MachoHub.Backpack:FindFirstChild("Knife") or WM.LocalCharacter:FindFirstChild("Knife")
	if not knife then
		return
	end
	if knife.Parent == MachoHub.Backpack then
		pcall(function()
			WM.LocalHumanoid:EquipTool(knife)
		end)
		task.wait(0.12)
		knife = WM.LocalCharacter and WM.LocalCharacter:FindFirstChild("Knife")
	end
	if not knife or not knife:IsA("Tool") then
		return
	end
	local handle = knife:FindFirstChild("Handle")
	local stab = knife:FindFirstChild("Stab")
	if not handle or not handle:IsA("BasePart") then
		return
	end
	if not handle:IsDescendantOf(Workspace) then
		return
	end
	pcall(function()
		if knife.Parent ~= WM.LocalCharacter then
			knife.Parent = WM.LocalCharacter
		end
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= localPlayer then
			local character = player.Character
			if character then
				local humanoid = character:FindFirstChildOfClass("Humanoid")
				local hrp = character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart
				if humanoid and humanoid.Health > 0 and hrp and hrp:IsA("BasePart") and hrp:IsDescendantOf(Workspace) and handle.Parent and handle:IsDescendantOf(Workspace) then
					local success = pcall(function()
						firetouchinterest(handle, hrp, 0)
						firetouchinterest(handle, hrp, 1)
						firetouchinterest(handle, hrp, 0)
					end)
					if not success then
						if stab and typeof(stab.FireServer) == "function" then
							pcall(function()
								stab:FireServer(hrp.Position)
							end)
						end
					elseif stab and typeof(stab.FireServer) == "function" then
						pcall(function()
							stab:FireServer(hrp.Position)
						end)
					end
					task.wait(0.1)
				end
			end
		end
	end
end

local autoKillConn = nil
local lastKill = 0
MachoHub.ToggleAutoKillAll = function(enabled)
	Config.AutoKill = enabled
	if autoKillConn then
		autoKillConn:Disconnect()
		autoKillConn = nil
	end
	if enabled then
		autoKillConn = trackConnection(RunService.Heartbeat:Connect(function()
			if not Config.AutoKill then
				return
			end
			if tick() - lastKill < 0.35 then
				return
			end
			if not MachoHub.Backpack or not WM.LocalCharacter then
				return
			end
			local knife = MachoHub.Backpack:FindFirstChild("Knife") or WM.LocalCharacter:FindFirstChild("Knife")
			if knife and knife:IsA("Tool") then
				lastKill = tick()
				pcall(MachoHub.KillAll)
			end
		end))
	end
end

local killAuraConn = nil
local lastAura = 0
MachoHub.KillAura = function(enabled)
	Config.KnifeAura = enabled
	if killAuraConn then
		killAuraConn:Disconnect()
		killAuraConn = nil
	end
	if not enabled then
		return
	end
	killAuraConn = trackConnection(RunService.Heartbeat:Connect(function()
		if tick() - lastAura < 0.12 then
			return
		end
		if not firetouchinterest then
			return
		end
		local knife = WM.LocalCharacter and WM.LocalCharacter:FindFirstChild("Knife")
		if not knife or not knife:IsA("Tool") or not WM.LocalRootPart then
			return
		end
		local handle = knife:FindFirstChild("Handle")
		local stab = knife:FindFirstChild("Stab")
		if not handle or not handle:IsA("BasePart") or knife.Parent ~= WM.LocalCharacter then
			return
		end
		local radius = math.max(1, tonumber(Config.AuraRadius) or 10)
		for _, player in ipairs(Players:GetPlayers()) do
			if player ~= localPlayer then
				local character = player.Character
				if character then
					local humanoid = character:FindFirstChildOfClass("Humanoid")
					local hrp = character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart
					if humanoid and humanoid.Health > 0 and hrp and hrp:IsA("BasePart") and handle.Parent and hrp.Parent and (hrp.Position - WM.LocalRootPart.Position).Magnitude <= radius then
						lastAura = tick()
						pcall(function()
							firetouchinterest(handle, hrp, 1)
							firetouchinterest(handle, hrp, 0)
						end)
						if stab and typeof(stab.FireServer) == "function" then
							pcall(function()
								stab:FireServer(hrp.Position)
							end)
						end
						break
					end
				end
			end
		end
	end))
end

MachoHub.getPredictedPosition = function(player)
	if not player or not player.Character then
		return Vector3.zero
	end
	local hrp = player.Character:FindFirstChild("HumanoidRootPart") or player.Character.PrimaryPart
	if not hrp then
		return Vector3.zero
	end
	local velocity = hrp.AssemblyLinearVelocity or Vector3.zero
	local ping = 0
	pcall(function()
		if localPlayer.GetNetworkPing then
			ping = localPlayer:GetNetworkPing() or 0
		end
	end)
	if ping > 1 then
		ping = ping / 1000
	end
	return hrp.Position + velocity * (0.028 + ping)
end

MachoHub.ShootMurdererOnce = function()
	if not WM.LocalCharacter then
		return
	end
	local target = WM.findMurderer() or WM.findSheriffExceptMe()
	if not target or not target.Character then
		return
	end
	local targetHRP = target.Character:FindFirstChild("HumanoidRootPart")
	local localHRP = WM.LocalCharacter:FindFirstChild("HumanoidRootPart")
	if not targetHRP or not localHRP then
		return
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { WM.LocalCharacter }
	local ok, result = pcall(function()
		return workspace:Raycast(localHRP.Position, targetHRP.Position - localHRP.Position, params)
	end)
	if ok and result and result.Instance and not result.Instance:IsDescendantOf(target.Character) then
		return
	end
	if not WM.LocalCharacter:FindFirstChild("Gun") then
		local gun = MachoHub.Backpack and MachoHub.Backpack:FindFirstChild("Gun")
		if gun and WM.LocalHumanoid then
			pcall(function()
				WM.LocalHumanoid:EquipTool(gun)
			end)
		end
	end
	local gun = WM.LocalCharacter:FindFirstChild("Gun")
	if not gun then
		return
	end
	local knifeLocal = gun:FindFirstChild("KnifeLocal")
	knifeLocal = knifeLocal and knifeLocal:FindFirstChild("CreateBeam")
	local remote = knifeLocal and knifeLocal:FindFirstChild("RemoteFunction")
	if remote and typeof(remote.InvokeServer) == "function" then
		pcall(function()
			remote:InvokeServer(1, MachoHub.getPredictedPosition(target), "AH2")
		end)
	end
end

local autoShootConn = nil
MachoHub.ToggleAutoShootMurderer = function(enabled)
	Config.AutoShootMurderer = enabled
	if autoShootConn then
		autoShootConn:Disconnect()
		autoShootConn = nil
	end
	if not enabled then
		return
	end
	autoShootConn = trackConnection(RunService.Heartbeat:Connect(function()
		pcall(function()
			if Config.AutoShootMurderer and WM.findSheriff() == localPlayer then
				MachoHub.ShootMurdererOnce()
			end
		end)
	end))
end

local silentThrowThread = nil
MachoHub.ExecuteThrowAtNearest = function()
	local knife = MachoHub.Backpack:FindFirstChild("Knife") or WM.LocalCharacter and WM.LocalCharacter:FindFirstChild("Knife")
	if knife and knife.Parent == MachoHub.Backpack and WM.LocalHumanoid then
		WM.LocalHumanoid:EquipTool(knife)
		task.wait(0.1)
		knife = WM.LocalCharacter:FindFirstChild("Knife")
	end
	if not knife or not knife:FindFirstChild("Throw") or not WM.LocalRootPart then
		return
	end
	local origin = WM.LocalRootPart.Position
	local nearestDist = 1000
	local nearestHRP = nil
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= localPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
			local humanoid = player.Character:FindFirstChild("Humanoid")
			if humanoid and humanoid.Health > 0 then
				local hrp = player.Character.HumanoidRootPart
				local dist = (origin - hrp.Position).Magnitude
				if dist < nearestDist then
					nearestDist = dist
					nearestHRP = hrp
				end
			end
		end
	end
	if nearestHRP then
		local predicted = nearestHRP.Position + nearestHRP.AssemblyLinearVelocity * 0.05 * nearestDist / 100
		knife.Throw:FireServer(CFrame.new(origin, predicted), predicted)
	end
end

MachoHub.ToggleSilentThrow = function(enabled)
	Config.SilentThrow = enabled
	if silentThrowThread then
		task.cancel(silentThrowThread)
		silentThrowThread = nil
	end
	if enabled then
		silentThrowThread = task.spawn(function()
			while Config.SilentThrow do
				if WM.findMurderer() == localPlayer then
					MachoHub.ExecuteThrowAtNearest()
				end
				task.wait(0.8)
			end
		end)
	end
end

MachoHub.PlayEmote = function(emote)
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if remotes and remotes:FindFirstChild("PlayEmote") then
		remotes.PlayEmote:Fire(emote)
	else
		local playEmote = ReplicatedStorage:FindFirstChild("PlayEmote", true)
		if playEmote then
			playEmote:Fire(emote)
		end
	end
end

MachoHub.ChatRoles = function()
	local murderer = WM.findMurderer()
	local sheriff = WM.findSheriff()
	local msg = "Macho HUB >> Murderer: " .. (murderer and murderer.Name or "?") .. " | Sheriff: " .. (sheriff and sheriff.Name or "?")
	if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
		local channels = TextChatService:FindFirstChild("TextChannels")
		if channels and channels:FindFirstChild("RBXGeneral") then
			channels.RBXGeneral:SendAsync(msg)
		end
	else
		local events = ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents")
		if events and events:FindFirstChild("SayMessageRequest") then
			events.SayMessageRequest:FireServer(msg, "Normal")
		end
	end
end

do
	local timerThread = nil
	local timerGui = nil
	local function formatTime(seconds)
		if not seconds or seconds == -1 then
			return ""
		end
		return string.format("%dm %ds", math.floor(seconds / 60), seconds % 60)
	end
	MachoHub.ToggleRoundTimer = function(enabled)
		Config.RoundTimer = enabled
		if timerGui then
			timerGui:Destroy()
			timerGui = nil
		end
		if timerThread then
			pcall(task.cancel, timerThread)
			timerThread = nil
		end
		if not enabled then
			return
		end
		timerGui = Instance.new("ScreenGui")
		timerGui.Name = "MachoTimerGUI"
		timerGui.ResetOnSpawn = false
		timerGui.IgnoreGuiInset = true
		pcall(function()
			if syn and syn.protect_gui then
				syn.protect_gui(timerGui)
			end
		end)
		if not pcall(function()
			timerGui.Parent = CoreGui
		end) then
			timerGui.Parent = playerGui
		end
		local label = Instance.new("TextLabel", timerGui)
		label.Size = UDim2.fromOffset(200, 50)
		label.Position = UDim2.fromScale(0.5, 0.15)
		label.AnchorPoint = Vector2.new(0.5, 0.5)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBold
		label.TextScaled = true
		label.TextColor3 = Color3.fromHex("#E6F7FF")
		label.TextStrokeColor3 = Color3.fromHex("#000000")
		label.TextStrokeTransparency = 0
		label.Text = "Loading:"
		timerThread = task.spawn(function()
			while timerGui and timerGui.Parent do
				local ok, result = pcall(function()
					return game.ReplicatedStorage.Remotes.Extras.GetTimer:InvokeServer()
				end)
				label.Text = ok and formatTime(result) or "—"
				task.wait(0.5)
			end
		end)
	end
end

PULSE = PULSE or { fns = {} }
PULSE.add = function(fn)
	table.insert(PULSE.fns, fn)
end
PULSE.mix = function(c1, c2, t)
	return Color3.new(c1.R + (c2.R - c1.R) * t, c1.G + (c2.G - c1.G) * t, c1.B + (c2.B - c1.B) * t)
end
task.spawn(function()
	while true do
		local t = (math.sin(os.clock() * 1.7) + 1) * 0.5
		for i = #PULSE.fns, 1, -1 do
			local ok, result = pcall(PULSE.fns[i], t)
			if not ok or result == false then
				table.remove(PULSE.fns, i)
			end
		end
		task.wait(0.05)
	end
end)

FX = FX or {}
FX.SHADOW_ASSET = "rbxassetid://6014261993"
FX.mix = function(c1, c2, t)
	return Color3.new(c1.R + (c2.R - c1.R) * t, c1.G + (c2.G - c1.G) * t, c1.B + (c2.B - c1.B) * t)
end
FX.dark = function(c, factor)
	return Color3.new(c.R * factor, c.G * factor, c.B * factor)
end
FX.accent = function()
	return getgenv().MachoAccent or Color3.fromRGB(0, 255, 120)
end
FX.glow = function(parent, opts)
	opts = opts or {}
	local spread = opts.spread or 18
	local img = Instance.new("ImageLabel")
	img.Name = opts.name or "Glow"
	img.BackgroundTransparency = 1
	img.Image = FX.SHADOW_ASSET
	img.ImageColor3 = opts.color or FX.accent()
	img.ImageTransparency = opts.transparency or 0.85
	img.ScaleType = Enum.ScaleType.Slice
	img.SliceCenter = Rect.new(49, 49, 450, 450)
	img.Size = UDim2.new(1, spread * 2, 1, spread * 2)
	img.Position = UDim2.new(0, -spread, 0, -spread)
	img.ZIndex = opts.zindex or 0
	img.Active = false
	img.Parent = parent
	return img
end
FX.shadow = function(parent, opts)
	opts = opts or {}
	opts.color = opts.color or Color3.fromRGB(0, 0, 0)
	opts.transparency = opts.transparency or 0.5
	opts.spread = opts.spread or 28
	opts.name = "Shadow"
	return FX.glow(parent, opts)
end
FX.breathe = function(img, maxT, minT, speed)
	maxT = maxT or 0.92
	minT = minT or 0.78
	speed = speed or 2.4
	task.spawn(function()
		while true do
			if img and img.Parent then
				TweenService:Create(img, TweenInfo.new(speed / 2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { ImageTransparency = minT }):Play()
				task.wait(speed / 2)
				if img and img.Parent then
					TweenService:Create(img, TweenInfo.new(speed / 2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { ImageTransparency = maxT }):Play()
					task.wait(speed / 2)
				else
					break
				end
			else
				break
			end
		end
	end)
	return img
end
FX.flowGradient = function(parent, opts)
	opts = opts or {}
	local color = opts.color or FX.accent()
	local dim = FX.dark(color, opts.dim or 0.14)
	local gradient = Instance.new("UIGradient")
	gradient.Name = "FlowGradient"
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, dim),
		ColorSequenceKeypoint.new(0.3, color),
		ColorSequenceKeypoint.new(0.5, FX.mix(color, Color3.fromRGB(255, 255, 255), 0.6)),
		ColorSequenceKeypoint.new(0.7, color),
		ColorSequenceKeypoint.new(1, dim),
	})
	gradient.Rotation = opts.rotation or 0
	gradient.Parent = parent
	local speed = opts.speed or 4
	local start = os.clock()
	local conn
	conn = RunService.Heartbeat:Connect(function()
		if not gradient.Parent then
			conn:Disconnect()
			return
		end
		gradient.Offset = Vector2.new((os.clock() - start) / speed % 1 * 2 - 1, 0)
	end)
	return gradient
end

local Assets = {
	TIGER = "rbxassetid://79422104460159",
	LOGO = "https://raw.githubusercontent.com/machodev2/Vision-Hub/refs/heads/main/Vision_Logo1.png",
	GLOW = "rbxassetid://6014261993",
	SHOOT = "rbxassetid://139650104834071",
}

local Backgrounds = {
	{ url = "rbxassetid://79422104460159", file = "macho_bg_tiger.png", name = "Tiger" },
	{ url = "rbxassetid://88369503310562", file = "macho_bg_2.png", name = "Aura" },
	{ url = "rbxassetid://77514425260751", file = "macho_bg_3.png", name = "Neon" },
	{ url = "rbxassetid://112899995372259", file = "macho_bg_4.png", name = "Cosmic" },
	{ url = "rbxassetid://104775518072608", file = "macho_bg_5.png", name = "Pulse" },
	{ url = "https://files.catbox.moe/pk5a3v.jpeg", file = "macho_bg_6.jpeg", name = "Pink Anime" },
	{ url = "https://files.catbox.moe/v8y0ak.png", file = "macho_bg_7.png", name = "Red Anime" },
	{ url = "https://files.catbox.moe/sl73hb.png", file = "macho_bg_8.png", name = "Girl" },
}

local BackgroundCache = {}
local Themes = {
	{ name = "GREEN", color = Color3.fromRGB(0, 255, 120) },
	{ name = "WHITE", color = Color3.fromRGB(255, 255, 255) },
	{ name = "PURPLE", color = Color3.fromRGB(207, 159, 255) },
	{ name = "BLUE", color = Color3.fromRGB(58, 128, 245) },
	{ name = "RED", color = Color3.fromRGB(232, 52, 68) },
	{ name = "PINK", color = Color3.fromRGB(255, 105, 180) },
	{ name = "YELLOW", color = Color3.fromRGB(255, 214, 0) },
	{ name = "GREY", color = Color3.fromRGB(90, 90, 90) },
	{ name = "RAINBOW", color = Color3.fromRGB(255, 0, 0), rainbow = true },
}

local UIState = {
	flags = {},
	setters = {},
	contentPages = {},
	sidebarBtns = {},
	activeTab = "Home",
	themeName = "GREEN",
	backgroundIndex = 1,
	backgroundEnabled = true,
	bgImageRef = nil,
	bgGrad = nil,
	mobileButtonSize = 80,
	lockMobileButtons = false,
	rainbowCur = Color3.fromRGB(255, 0, 0),
}

getgenv().MachoAccent = Color3.fromRGB(0, 255, 120)

local function getAccent()
	if UIState.themeName == "RAINBOW" then
		return UIState.rainbowCur
	end
	for _, theme in ipairs(Themes) do
		if theme.name == UIState.themeName then
			return theme.color
		end
	end
	return Themes[1].color
end

local function setAccent(color)
	getgenv().MachoAccent = color
end

task.spawn(function()
	local hue = 0
	while true do
		task.wait(0.07)
		if UIState.themeName == "RAINBOW" then
			hue = (hue + 0.005) % 1
			local value = 0.88 + 0.12 * math.sin(os.clock() * 1.6)
			UIState.rainbowCur = Color3.fromHSV(hue, math.clamp(0.78 + 0.18 * math.sin(os.clock() * 0.9), 0, 1), math.clamp(value, 0, 1))
			setAccent(UIState.rainbowCur)
		end
	end
end)

setAccent(getAccent())

Colors = {
	bg = Color3.fromRGB(9, 11, 14),
	bgDark = Color3.fromRGB(5, 7, 10),
	row = Color3.fromRGB(16, 20, 24),
	rowHover = Color3.fromRGB(22, 27, 32),
	input = Color3.fromRGB(13, 17, 21),
	text = Color3.fromRGB(236, 242, 245),
	textDim = Color3.fromRGB(150, 170, 180),
	textMuted = Color3.fromRGB(100, 120, 130),
	white = Color3.fromRGB(255, 255, 255),
	divider = Color3.fromRGB(34, 42, 48),
	danger = Color3.fromRGB(232, 52, 68),
	success = Color3.fromRGB(0, 220, 120),
}

local function createUICorner(parent, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 10)
	corner.Parent = parent
	return corner
end

local function createUIStroke(parent, color, thickness)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or getAccent()
	stroke.Thickness = thickness or 1.2
	stroke.Transparency = 0.15
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = parent
	return stroke
end

local function tween(obj, props, info)
	TweenService:Create(obj, info or TweenInfo.new(0.14), props):Play()
end

local function makeDraggable(handle, target)
	local dragging = false
	local startPos = nil
	local startFramePos = nil
	local moveConn = nil
	local endConn = nil
	handle.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		dragging = true
		startPos = input.Position
		startFramePos = target.Position
		if moveConn then
			moveConn:Disconnect()
		end
		if endConn then
			endConn:Disconnect()
		end
		moveConn = UserInputService.InputChanged:Connect(function(input2)
			if not dragging then
				return
			end
			if input2.UserInputType ~= Enum.UserInputType.MouseMovement and input2.UserInputType ~= Enum.UserInputType.Touch then
				return
			end
			local delta = input2.Position - startPos
			target.Position = UDim2.new(startFramePos.X.Scale, startFramePos.X.Offset + delta.X, startFramePos.Y.Scale, startFramePos.Y.Offset + delta.Y)
		end)
		endConn = UserInputService.InputEnded:Connect(function(input2)
			if input2.UserInputType == Enum.UserInputType.MouseButton1 or input2.UserInputType == Enum.UserInputType.Touch then
				dragging = false
				if moveConn then
					moveConn:Disconnect()
					moveConn = nil
				end
				if endConn then
					endConn:Disconnect()
					endConn = nil
				end
			end
		end)
	end)
end

do
	local notifyGui = Instance.new("ScreenGui")
	notifyGui.Name = "MachoNotify"
	notifyGui.ResetOnSpawn = false
	notifyGui.IgnoreGuiInset = true
	notifyGui.DisplayOrder = 9999
	pcall(function()
		if syn and syn.protect_gui then
			syn.protect_gui(notifyGui)
		end
	end)
	if not pcall(function()
		notifyGui.Parent = CoreGui
	end) then
		notifyGui.Parent = playerGui
	end
	local container = Instance.new("Frame", notifyGui)
	container.AnchorPoint = Vector2.new(1, 0)
	container.Position = UDim2.new(1, -12, 0, 12)
	container.Size = UDim2.new(0, math.min(320, math.max(220, math.floor((workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize.X or 390) * 0.86))), 1, -24)
	container.BackgroundTransparency = 1
	local layout = Instance.new("UIListLayout", container)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.VerticalAlignment = Enum.VerticalAlignment.Top
	layout.Padding = UDim.new(0, 8)
	local function updateSize()
		local cam = workspace.CurrentCamera
		if not cam then
			return
		end
		container.Size = UDim2.new(0, math.clamp(math.floor(cam.ViewportSize.X * 0.86), 220, 320), 1, -24)
	end
	updateSize()
	if workspace.CurrentCamera then
		trackConnection(workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateSize))
	end
	trackConnection(workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(updateSize))
	pushNotify = function(opts)
		opts = opts or {}
		local card = Instance.new("Frame", container)
		card.Size = UDim2.new(1, 0, 0, 66)
		card.BackgroundColor3 = Colors.bgDark
		card.BackgroundTransparency = 0.05
		card.BorderSizePixel = 0
		card.ClipsDescendants = true
		createUICorner(card, 12)
		local accent = opts.Color or getAccent()
		createUIStroke(card, accent, 1.4).Transparency = 0.15
		local bar = Instance.new("Frame", card)
		bar.Size = UDim2.new(0, 3, 1, -12)
		bar.Position = UDim2.new(0, 6, 0, 6)
		bar.BackgroundColor3 = accent
		bar.BorderSizePixel = 0
		createUICorner(bar, 2)
		local title = Instance.new("TextLabel", card)
		title.Size = UDim2.new(1, -18, 0, 22)
		title.Position = UDim2.new(0, 16, 0, 8)
		title.BackgroundTransparency = 1
		title.Text = opts.Title or "Notification"
		title.TextColor3 = accent
		title.Font = Enum.Font.GothamBold
		title.TextSize = 14
		title.TextXAlignment = Enum.TextXAlignment.Left
		local content = Instance.new("TextLabel", card)
		content.Size = UDim2.new(1, -18, 0, 26)
		content.Position = UDim2.new(0, 16, 0, 30)
		content.BackgroundTransparency = 1
		content.Text = opts.Content or ""
		content.TextColor3 = Colors.text
		content.Font = Enum.Font.Gotham
		content.TextSize = 12
		content.TextXAlignment = Enum.TextXAlignment.Left
		content.TextWrapped = true
		local progress = Instance.new("Frame", card)
		progress.Size = UDim2.new(0, 0, 0, 2)
		progress.Position = UDim2.new(0, 0, 1, -2)
		progress.BackgroundColor3 = accent
		progress.BorderSizePixel = 0
		card.Position = UDim2.new(1, 40, 0, 0)
		tween(card, { Position = UDim2.new(0, 0, 0, 0) }, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out))
		tween(progress, { Size = UDim2.new(1, 0, 0, 2) }, TweenInfo.new(opts.Duration or 5, Enum.EasingStyle.Linear))
		task.delay(opts.Duration or 5, function()
			if not card or not card.Parent then
				return
			end
			tween(card, { BackgroundTransparency = 1, Position = UDim2.new(1, 40, 0, 0) }, TweenInfo.new(0.24))
			task.delay(0.26, function()
				pcall(function()
					card:Destroy()
				end)
			end)
		end)
	end
end

local showDialog
do
	local dialogGui = Instance.new("ScreenGui")
	dialogGui.Name = "MachoDialog"
	dialogGui.ResetOnSpawn = false
	dialogGui.IgnoreGuiInset = true
	dialogGui.DisplayOrder = 10000
	pcall(function()
		if syn and syn.protect_gui then
			syn.protect_gui(dialogGui)
		end
	end)
	if not pcall(function()
		dialogGui.Parent = CoreGui
	end) then
		dialogGui.Parent = playerGui
	end
	showDialog = function(opts)
		opts = opts or {}
		local overlay = Instance.new("Frame", dialogGui)
		overlay.Size = UDim2.new(1, 0, 1, 0)
		overlay.BackgroundColor3 = Color3.new(0, 0, 0)
		overlay.BackgroundTransparency = 0.45
		overlay.BorderSizePixel = 0
		overlay.ZIndex = 1
		overlay.Active = true
		local box = Instance.new("Frame", overlay)
		box.Size = UDim2.fromOffset(380, 200)
		box.Position = UDim2.fromScale(0.5, 0.5)
		box.AnchorPoint = Vector2.new(0.5, 0.5)
		local scale = Instance.new("UIScale", box)
		local cam = workspace.CurrentCamera
		if cam then
			local size = cam.ViewportSize
			scale.Scale = math.clamp(math.min(size.X * 0.86 / 380, size.Y * 0.72 / 200), 0.62, 1)
		end
		box.BackgroundColor3 = Colors.bg
		box.BorderSizePixel = 0
		box.ZIndex = 10
		box.Active = true
		createUICorner(box, 16)
		createUIStroke(box, getAccent(), 1.6)
		local title = Instance.new("TextLabel", box)
		title.Size = UDim2.new(1, -24, 0, 34)
		title.Position = UDim2.new(0, 12, 0, 12)
		title.BackgroundTransparency = 1
		title.ZIndex = 11
		title.Text = opts.Title or "Confirm"
		title.TextColor3 = getAccent()
		title.Font = Enum.Font.GothamBold
		title.TextSize = 18
		title.TextXAlignment = Enum.TextXAlignment.Left
		local content = Instance.new("TextLabel", box)
		content.Size = UDim2.new(1, -24, 1, -110)
		content.Position = UDim2.new(0, 12, 0, 52)
		content.BackgroundTransparency = 1
		content.ZIndex = 11
		content.Text = opts.Content or ""
		content.TextColor3 = Colors.text
		content.Font = Enum.Font.Gotham
		content.TextSize = 14
		content.TextWrapped = true
		content.TextXAlignment = Enum.TextXAlignment.Left
		content.TextYAlignment = Enum.TextYAlignment.Top
		local btnRow = Instance.new("Frame", box)
		btnRow.Size = UDim2.new(1, -24, 0, 40)
		btnRow.Position = UDim2.new(0, 12, 1, -52)
		btnRow.BackgroundTransparency = 1
		btnRow.ZIndex = 11
		local btnLayout = Instance.new("UIListLayout", btnRow)
		btnLayout.FillDirection = Enum.FillDirection.Horizontal
		btnLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
		btnLayout.VerticalAlignment = Enum.VerticalAlignment.Center
		btnLayout.Padding = UDim.new(0, 8)
		local buttons = opts.Buttons or { { Title = "OK" } }
		for _, btn in ipairs(buttons) do
			local button = Instance.new("TextButton", btnRow)
			button.Size = UDim2.new(0, 100, 0, 34)
			button.BackgroundColor3 = btn.Variant == "Secondary" and Colors.row or getAccent()
			button.BackgroundTransparency = btn.Variant == "Secondary" and 0.3 or 0
			button.BorderSizePixel = 0
			button.ZIndex = 12
			button.Text = btn.Title or "OK"
			button.TextColor3 = btn.Variant == "Secondary" and Colors.text or Colors.bgDark
			button.Font = Enum.Font.GothamBold
			button.TextSize = 13
			button.AutoButtonColor = false
			createUICorner(button, 8)
			button.MouseButton1Click:Connect(function()
				pcall(function()
					overlay:Destroy()
				end)
				if btn.Callback then
					task.spawn(btn.Callback)
				end
			end)
		end
		overlay.InputBegan:Connect(function(input)
			if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
				return
			end
			local pos = input.Position
			local absPos = box.AbsolutePosition
			local absSize = box.AbsoluteSize
			if not (pos.X >= absPos.X and pos.X <= absPos.X + absSize.X and pos.Y >= absPos.Y and pos.Y <= absPos.Y + absSize.Y) then
				pcall(function()
					overlay:Destroy()
				end)
			end
		end)
	end
end

local configReady = false
local saveConfig, loadConfig, resolveAsset, applyMobileButtons, refreshMobileBackgrounds

do
	local function collectMobileStates()
		local states = {}
		for id, gui in pairs(MachoHub.MobileButtons) do
			if gui and gui.Parent then
				local btn = gui:FindFirstChild("ActionBtn")
				if btn then
					states[id] = {
						enabled = true,
						xo = btn.Position.X.Offset,
						yo = btn.Position.Y.Offset,
						xs = btn.Position.X.Scale,
						ys = btn.Position.Y.Scale,
					}
				end
			end
		end
		for k, v in pairs(UIState.flags) do
			if type(k) == "string" and k:sub(1, 5) == "show_" and v == false then
				local id = k:sub(6)
				states[id] = states[id] or { enabled = false }
			end
		end
		return states
	end
	saveConfig = function()
		if not writefile or not configReady then
			return
		end
		UIState.flags.backgroundIndex = UIState.backgroundIndex
		UIState.flags.themeName = UIState.themeName
		UIState.flags.mobileButtonSize = UIState.mobileButtonSize
		UIState.flags.lockMobileButtons = UIState.lockMobileButtons
		UIState.flags.mobileButtonStates = collectMobileStates()
		pcall(function()
			writefile("MachoHUB.json", HttpService:JSONEncode(UIState.flags))
		end)
	end
	loadConfig = function()
		if not (isfile and isfile("MachoHUB.json")) then
			return
		end
		local ok, result = pcall(function()
			return HttpService:JSONDecode(readfile("MachoHUB.json"))
		end)
		if not ok or type(result) ~= "table" then
			return
		end
		for k, v in pairs(result) do
			UIState.flags[k] = v
		end
		if type(result.themeName) == "string" then
			UIState.themeName = result.themeName
			setAccent(getAccent())
		end
		if type(result.backgroundIndex) == "number" then
			UIState.backgroundIndex = result.backgroundIndex
		end
		if type(result.mobileButtonSize) == "number" then
			UIState.mobileButtonSize = result.mobileButtonSize
		end
		if type(result.lockMobileButtons) == "boolean" then
			UIState.lockMobileButtons = result.lockMobileButtons
			Config.ButtonsLocked = result.lockMobileButtons
		end
	end
	local function tryCustomAsset(path)
		for _, fn in ipairs({ getcustomasset, getsynasset, getasset }) do
			if typeof(fn) == "function" then
				local ok, result = pcall(function()
					return fn(path)
				end)
				if ok and type(result) == "string" and result ~= "" then
					return result
				end
			end
		end
		return ""
	end
	resolveAsset = function(entry)
		if not entry then
			return ""
		end
		if entry.url and (string.find(entry.url, "rbxassetid://") or string.find(entry.url, "rbxasset://")) then
			return entry.url
		end
		if isfile and isfile(entry.file) then
			local asset = tryCustomAsset(entry.file)
			if asset ~= "" then
				return asset
			end
		end
		local data = nil
		pcall(function()
			local response = game:HttpGet(entry.url)
			if response and #response > 100 then
				data = response
			end
		end)
		if not data then
			return entry.url
		end
		pcall(function()
			writefile(entry.file, data)
		end)
		task.wait(0.05)
		local asset = tryCustomAsset(entry.file)
		return asset ~= "" and asset or entry.url
	end
	for i, entry in ipairs(Backgrounds) do
		if entry.url and (string.find(entry.url, "rbxassetid://") or string.find(entry.url, "rbxasset://")) then
			BackgroundCache[i] = entry.url
		else
			task.spawn(function()
				BackgroundCache[i] = resolveAsset(entry)
			end)
		end
	end
	local buttonRegistry = {}
	local function getMobileStates()
		local states = UIState.flags.mobileButtonStates
		if type(states) == "table" then
			return states
		end
		return {}
	end
	local function persistMobile()
		if not writefile or not configReady then
			return
		end
		UIState.flags.mobileButtonStates = collectMobileStates()
		pcall(function()
			writefile("MachoHUB.json", HttpService:JSONEncode(UIState.flags))
		end)
	end
	task.spawn(function()
		while true do
			task.wait(5)
			pcall(persistMobile)
		end
	end)
	local function createMobileButton(id, settings, callback)
		if MachoHub.MobileButtons[id] then
			if MachoHub.MobileButtons[id].Parent then
				MachoHub.MobileButtons[id]:Destroy()
			end
			MachoHub.MobileButtons[id] = nil
		end
		if not settings.Enabled then
			return
		end
		local gui = Instance.new("ScreenGui")
		gui.Name = "MachoBtn_" .. id
		pcall(function()
			if syn and syn.protect_gui then
				syn.protect_gui(gui)
			end
		end)
		if not pcall(function()
			gui.Parent = CoreGui
		end) then
			gui.Parent = playerGui
		end
		gui.ResetOnSpawn = false
		gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		MachoHub.MobileButtons[id] = gui
		local size = UIState.mobileButtonSize
		local w = math.floor(84 * size / 80 + 0.5)
		local h = math.floor(36 * size / 80 + 0.5)
		local frame = Instance.new("Frame")
		frame.Name = "ActionBtn"
		frame.Size = UDim2.fromOffset(w, h)
		frame.BackgroundColor3 = Color3.fromRGB(12, 14, 15)
		frame.BackgroundTransparency = 0.35
		frame.BorderSizePixel = 0
		frame.Active = true
		frame.Parent = gui
		createUICorner(frame, 9)
		local saved = getMobileStates()[id]
		if saved and saved.xo then
			frame.Position = UDim2.new(saved.xs or 0, saved.xo, saved.ys or 0, saved.yo)
		else
			local count = 0
			for _, btn in pairs(MachoHub.MobileButtons) do
				if btn and btn.Parent then
					count = count + 1
				end
			end
			frame.Position = UDim2.new(1, -110, 0.35 + count * 0.06, 0)
		end
		local stroke = Instance.new("UIStroke", frame)
		stroke.Color = getAccent()
		stroke.Thickness = 1.4
		stroke.Transparency = 0.3
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		local bg = Instance.new("ImageLabel", frame)
		bg.Name = "ImgBg"
		bg.Size = UDim2.new(1, 0, 1, 0)
		bg.BackgroundTransparency = 1
		bg.Image = BackgroundCache[UIState.backgroundIndex] or Assets.TIGER
		bg.ImageColor3 = Color3.fromRGB(255, 255, 255)
		bg.ImageTransparency = 0.15
		bg.ScaleType = Enum.ScaleType.Crop
		bg.ZIndex = 1
		createUICorner(bg, 9)
		local overlay = Instance.new("Frame", frame)
		overlay.Name = "GradOverlay"
		overlay.Size = UDim2.new(1, 0, 1, 0)
		overlay.BackgroundColor3 = getAccent()
		overlay.BackgroundTransparency = 1
		overlay.BorderSizePixel = 0
		overlay.ZIndex = 2
		createUICorner(overlay, 9)
		PULSE.add(function()
			if not overlay.Parent then
				return false
			end
			local accent = getAccent()
			if overlay.BackgroundColor3 ~= accent then
				overlay.BackgroundColor3 = accent
			end
		end)
		local glow = FX.glow(frame, { spread = 10, transparency = 0.9, zindex = 0 })
		FX.breathe(glow, 0.9, 0.75, 2.6)
		local label = Instance.new("TextLabel", frame)
		label.Size = UDim2.new(1, -8, 1, -4)
		label.Position = UDim2.new(0, 4, 0, 2)
		label.BackgroundTransparency = 1
		label.Text = settings.Text or id
		label.TextColor3 = Color3.fromRGB(255, 255, 255)
		label.Font = Enum.Font.GothamBold
		label.TextSize = math.floor(11 * size / 80 + 0.5)
		label.TextWrapped = true
		label.TextScaled = true
		label.ZIndex = 5
		local labelStroke = Instance.new("UIStroke", label)
		labelStroke.Color = Color3.fromRGB(0, 0, 0)
		labelStroke.Thickness = 1.4
		labelStroke.Transparency = 0.35
		if settings.Type == "Image" and settings.Icon then
			local icon = Instance.new("ImageLabel", frame)
			icon.Size = UDim2.new(0.55, 0, 0.55, 0)
			icon.Position = UDim2.new(0.225, 0, 0.225, 0)
			icon.BackgroundTransparency = 1
			icon.Image = settings.Icon
			icon.ScaleType = Enum.ScaleType.Fit
			icon.ZIndex = 5
			label.Visible = false
		end
		PULSE.add(function(t)
			if not frame.Parent then
				return false
			end
			stroke.Color = PULSE.mix(getAccent(), Color3.fromRGB(255, 255, 255), 0.2 * t)
			stroke.Transparency = 0.4 - 0.2 * t
			glow.ImageTransparency = 0.95 - 0.12 * t
		end)
		local dragThreshold = 8
		local dragging = false
		local moved = false
		local startPos = nil
		local startFramePos = nil
		local moveConn = nil
		local endConn = nil
		frame.InputBegan:Connect(function(input)
			if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
				return
			end
			dragging = true
			moved = false
			startPos = input.Position
			startFramePos = frame.Position
			if moveConn then
				moveConn:Disconnect()
			end
			if endConn then
				endConn:Disconnect()
			end
			moveConn = UserInputService.InputChanged:Connect(function(input2)
				if not dragging then
					return
				end
				if input2.UserInputType ~= Enum.UserInputType.MouseMovement and input2.UserInputType ~= Enum.UserInputType.Touch then
					return
				end
				if UIState.lockMobileButtons or Config.ButtonsLocked then
					return
				end
				local delta = input2.Position - startPos
				if not moved and delta.Magnitude >= dragThreshold then
					moved = true
					tween(frame, { BackgroundTransparency = 0.05 }, TweenInfo.new(0.1))
				end
				if moved then
					frame.Position = UDim2.new(startFramePos.X.Scale, startFramePos.X.Offset + delta.X, startFramePos.Y.Scale, startFramePos.Y.Offset + delta.Y)
				end
			end)
			endConn = UserInputService.InputEnded:Connect(function(input2)
				if input2.UserInputType ~= Enum.UserInputType.MouseButton1 and input2.UserInputType ~= Enum.UserInputType.Touch then
					return
				end
				dragging = false
				if moveConn then
					moveConn:Disconnect()
					moveConn = nil
				end
				if endConn then
					endConn:Disconnect()
					endConn = nil
				end
				if moved then
					tween(frame, { BackgroundTransparency = 0.35 }, TweenInfo.new(0.15))
					pcall(persistMobile)
				else
					overlay.BackgroundColor3 = getAccent()
					tween(overlay, { BackgroundTransparency = 0.25 }, TweenInfo.new(0.08))
					tween(frame, { BackgroundTransparency = 0.05 }, TweenInfo.new(0.08))
					task.delay(0.18, function()
						if overlay and overlay.Parent then
							tween(overlay, { BackgroundTransparency = 1 }, TweenInfo.new(0.2))
						end
						if frame and frame.Parent then
							tween(frame, { BackgroundTransparency = 0.35 }, TweenInfo.new(0.2))
						end
					end)
					if callback then
						task.spawn(callback)
					end
				end
			end)
		end)
	end
	MachoHub.CreateGuiButton = function(id, settings, callback)
		buttonRegistry[id] = { settings = settings, callback = callback }
		createMobileButton(id, settings, callback)
	end
	applyMobileButtons = function()
		for id, entry in pairs(buttonRegistry) do
			if entry.settings.Enabled then
				createMobileButton(id, entry.settings, entry.callback)
			end
		end
	end
end

refreshMobileBackgrounds = function()
	for _, gui in pairs(MachoHub.MobileButtons) do
		if gui and gui.Parent then
			local btn = gui:FindFirstChild("ActionBtn")
			local img = btn and btn:FindFirstChild("ImgBg")
			if img then
				img.Image = BackgroundCache[UIState.backgroundIndex] or Assets.TIGER
			end
		end
	end
end

do
	local gunNotifyConn = nil
	local lastGun = nil
	local function onGunDropped(part)
		if not part or not part.Parent or lastGun == part then
			return
		end
		lastGun = part
		pushNotify({ Title = "Gun Dropped", Content = "A gun has been dropped in the map.", Duration = 5 })
	end
	MachoHub.ToggleNotifyGunDropped = function(enabled)
		Config.NotifyGunDropped = enabled
		if gunNotifyConn then
			gunNotifyConn:Disconnect()
			gunNotifyConn = nil
		end
		lastGun = nil
		if not enabled then
			return
		end
		gunNotifyConn = { Disconnect = WM.On("GunDropped", onGunDropped) }
	end
end

do
	local roleThread = nil
	local notifiedMurderer = false
	local notifiedSheriff = false
	local function roleLoop()
		while true do
			local ok, result = pcall(function()
				return game.ReplicatedStorage.Remotes.Extras.GetTimer:InvokeServer()
			end)
			if not ok or (type(result) == "number" and result <= 1) then
				notifiedMurderer = false
				notifiedSheriff = false
			elseif ok and type(result) == "number" and result > 1 then
				if Config.NotifyMurderer and not notifiedMurderer then
					local murderer = WM.findMurderer()
					if murderer then
						notifiedMurderer = true
						pushNotify({
							Title = "Murderer Detected!",
							Content = murderer.Name,
							Duration = 8,
							Color = Color3.fromRGB(232, 52, 68),
						})
					end
				end
				if Config.NotifySheriff and not notifiedSheriff then
					local sheriff = WM.findSheriff()
					if sheriff then
						notifiedSheriff = true
						pushNotify({
							Title = "Sheriff Detected!",
							Content = sheriff.Name,
							Duration = 8,
							Color = Color3.fromRGB(58, 128, 245),
						})
					end
				end
			end
			task.wait(1)
		end
	end
	MachoHub.UpdateRoleNotify = function()
		if roleThread then
			task.cancel(roleThread)
			roleThread = nil
		end
		if Config.NotifyMurderer or Config.NotifySheriff then
			roleThread = task.spawn(roleLoop)
		end
	end
end

local mainGui = Instance.new("ScreenGui")
mainGui.Name = "MachoMainUI"
mainGui.ResetOnSpawn = false
mainGui.IgnoreGuiInset = true
mainGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
mainGui.DisplayOrder = 100
pcall(function()
	if syn and syn.protect_gui then
		syn.protect_gui(mainGui)
	end
end)
if not pcall(function()
	mainGui.Parent = CoreGui
end) then
	mainGui.Parent = playerGui
end

local outer = Instance.new("Frame", mainGui)
outer.Name = "Outer"
outer.AnchorPoint = Vector2.new(0.5, 0.5)
outer.Size = UDim2.fromOffset(660, 480)
outer.Position = UDim2.fromScale(0.5, 0.5)
outer.BackgroundTransparency = 1
outer.BorderSizePixel = 0

local uiScale = Instance.new("UIScale", outer)
uiScale.Scale = 1

local currentScale = 1
local function computeScale()
	local cam = workspace.CurrentCamera
	if not cam then
		return 1
	end
	local size = cam.ViewportSize
	if size.X <= 0 or size.Y <= 0 then
		return 1
	end
	return math.clamp(math.min(size.X * 0.94 / 660, size.Y * 0.9 / 480), 0.45, 1)
end
local function applyScale(instant)
	currentScale = computeScale()
	if instant then
		uiScale.Scale = currentScale
	else
		tween(uiScale, { Scale = currentScale }, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
	end
end
local scaleConn = nil
local function bindScale()
	if scaleConn then
		scaleConn:Disconnect()
		scaleConn = nil
	end
	local cam = workspace.CurrentCamera
	if cam then
		scaleConn = trackConnection(cam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			applyScale(false)
		end))
	end
end
bindScale()
trackConnection(workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	bindScale()
	applyScale(false)
end))
applyScale(true)

local inner = Instance.new("Frame", outer)
inner.Name = "Inner"
inner.Size = UDim2.new(1, 0, 1, 0)
inner.BackgroundColor3 = Colors.bg
inner.BorderSizePixel = 0
inner.ClipsDescendants = true
createUICorner(inner, 18)
FX.shadow(outer, { spread = 40, transparency = 0.42, zindex = 0 })
FX.breathe(FX.glow(outer, { spread = 28, transparency = 0.88, zindex = 0 }), 0.9, 0.75, 3)
local mainStroke = createUIStroke(inner, getAccent(), 1.8)
mainStroke.Transparency = 0.05
FX.flowGradient(mainStroke, { speed = 3.5, dim = 0.15 })
PULSE.add(function(t)
	if not inner.Parent then
		return false
	end
	mainStroke.Color = getAccent()
	mainStroke.Thickness = 1.6 + 0.7 * t
	mainStroke.Transparency = 0.12 - 0.1 * t
end)

do
	local bgLayer = Instance.new("Frame", inner)
	bgLayer.Size = UDim2.new(1, 0, 1, 0)
	bgLayer.BackgroundTransparency = 1
	bgLayer.ZIndex = 0
	bgLayer.ClipsDescendants = true
	createUICorner(bgLayer, 18)
	local gradFrame = Instance.new("Frame", bgLayer)
	gradFrame.Size = UDim2.new(1, 0, 1, 0)
	gradFrame.BackgroundColor3 = Colors.bgDark
	gradFrame.BorderSizePixel = 0
	gradFrame.ZIndex = 0
	createUICorner(gradFrame, 18)
	local grad = Instance.new("UIGradient", gradFrame)
	grad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(14, 18, 24)),
		ColorSequenceKeypoint.new(0.45, Color3.fromRGB(9, 11, 14)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(5, 7, 10)),
	})
	grad.Rotation = 120
	UIState.bgGrad = gradFrame
	local bgImage = Instance.new("ImageLabel", bgLayer)
	bgImage.Name = "BackgroundImage"
	bgImage.Size = UDim2.new(1, 0, 1, 0)
	bgImage.BackgroundTransparency = 1
	bgImage.Image = ""
	bgImage.ScaleType = Enum.ScaleType.Crop
	bgImage.ZIndex = 1
	bgImage.ImageTransparency = 0.15
	bgImage.Visible = false
	createUICorner(bgImage, 18)
	UIState.bgImageRef = bgImage
end

UIState.applyBackground = function(index)
	if not UIState.bgImageRef then
		return
	end
	UIState.backgroundIndex = index or 1
	local entry = Backgrounds[UIState.backgroundIndex]
	local asset = BackgroundCache[UIState.backgroundIndex]
	if (not asset or asset == "") and entry then
		asset = resolveAsset(entry)
		BackgroundCache[UIState.backgroundIndex] = asset
	end
	if asset and asset ~= "" then
		UIState.bgImageRef.Image = asset
		UIState.bgImageRef.ImageTransparency = 0.15
		UIState.bgImageRef.Visible = true
		UIState.backgroundEnabled = true
		if UIState.bgGrad then
			UIState.bgGrad.BackgroundTransparency = 0.72
		end
		inner.BackgroundTransparency = 0.15
	else
		if UIState.bgGrad then
			UIState.bgGrad.BackgroundTransparency = 0
		end
		inner.BackgroundTransparency = 0
	end
	refreshMobileBackgrounds()
	saveConfig()
end

local showMain, hideMain, addSection, addToggle, addSlider, addButton, addKeybind, addKeybindAction, addDropdown, pages

do
	local header = Instance.new("Frame", inner)
	header.Size = UDim2.new(1, 0, 0, 62)
	header.BackgroundTransparency = 1
	makeDraggable(header, outer)
	local logo = Instance.new("ImageLabel", header)
	logo.Size = UDim2.new(0, 38, 0, 38)
	logo.Position = UDim2.new(0, 14, 0.5, -19)
	logo.BackgroundTransparency = 1
	logo.Image = Assets.LOGO
	logo.ScaleType = Enum.ScaleType.Fit
	local title = Instance.new("TextLabel", header)
	title.Size = UDim2.new(0, 300, 0, 30)
	title.Position = UDim2.new(0, 62, 0, 14)
	title.BackgroundTransparency = 1
	title.Text = "Macho HUB"
	title.TextColor3 = getAccent()
	title.Font = Enum.Font.GothamBlack
	title.TextSize = 22
	title.TextXAlignment = Enum.TextXAlignment.Left
	local titleGrad = Instance.new("UIGradient", title)
	titleGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(137, 247, 255)),
		ColorSequenceKeypoint.new(0.5, getAccent()),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(50, 130, 200)),
	})
	titleGrad.Rotation = 8
	PULSE.add(function(t)
		if not title.Parent then
			return false
		end
		title.TextColor3 = PULSE.mix(getAccent(), Color3.fromRGB(255, 255, 255), 0.25 * t)
	end)
	local subtitle = Instance.new("TextLabel", header)
	subtitle.Size = UDim2.new(0, 300, 0, 14)
	subtitle.Position = UDim2.new(0, 62, 0, 40)
	subtitle.BackgroundTransparency = 1
	subtitle.Text = "by machodev"
	subtitle.TextColor3 = Colors.textMuted
	subtitle.Font = Enum.Font.GothamBold
	subtitle.TextSize = 11
	subtitle.TextXAlignment = Enum.TextXAlignment.Left
	local closeBtn = Instance.new("TextButton", header)
	closeBtn.Size = UDim2.new(0, 30, 0, 30)
	closeBtn.Position = UDim2.new(1, -42, 0.5, -15)
	closeBtn.BackgroundColor3 = Colors.row
	closeBtn.BackgroundTransparency = 0.2
	closeBtn.BorderSizePixel = 0
	closeBtn.Text = "×"
	closeBtn.TextColor3 = Colors.textDim
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.TextSize = 20
	closeBtn.AutoButtonColor = false
	createUICorner(closeBtn, 8)
	createUIStroke(closeBtn, Colors.divider, 1)
	closeBtn.MouseEnter:Connect(function()
		tween(closeBtn, { BackgroundColor3 = Colors.danger, BackgroundTransparency = 0.1, TextColor3 = Colors.white })
	end)
	closeBtn.MouseLeave:Connect(function()
		tween(closeBtn, { BackgroundColor3 = Colors.row, BackgroundTransparency = 0.2, TextColor3 = Colors.textDim })
	end)
	local divider = Instance.new("Frame", header)
	divider.Size = UDim2.new(1, -24, 0, 1)
	divider.Position = UDim2.new(0, 12, 1, -1)
	divider.BackgroundColor3 = getAccent()
	divider.BackgroundTransparency = 0.5
	divider.BorderSizePixel = 0
	local divGrad = Instance.new("UIGradient", divider)
	divGrad.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.45, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	local sidebarDivider = Instance.new("Frame", inner)
	sidebarDivider.Position = UDim2.new(0, 158, 0, 66)
	sidebarDivider.Size = UDim2.new(0, 1, 1, -78)
	sidebarDivider.BackgroundColor3 = Colors.divider
	local sidebar = Instance.new("ScrollingFrame", inner)
	sidebar.Size = UDim2.new(0, 146, 1, -78)
	sidebar.Position = UDim2.new(0, 6, 0, 66)
	sidebar.BackgroundTransparency = 1
	sidebar.BorderSizePixel = 0
	sidebar.ScrollBarThickness = 3
	sidebar.ScrollBarImageColor3 = getAccent()
	sidebar.CanvasSize = UDim2.new(0, 0, 0, 0)
	sidebar.AutomaticCanvasSize = Enum.AutomaticSize.Y
	local sidebarLayout = Instance.new("UIListLayout", sidebar)
	sidebarLayout.SortOrder = Enum.SortOrder.LayoutOrder
	sidebarLayout.Padding = UDim.new(0, 4)
	local sidebarPad = Instance.new("UIPadding", sidebar)
	sidebarPad.PaddingTop = UDim.new(0, 4)
	sidebarPad.PaddingLeft = UDim.new(0, 2)
	sidebarPad.PaddingRight = UDim.new(0, 2)
	sidebarPad.PaddingBottom = UDim.new(0, 4)
	local content = Instance.new("ScrollingFrame", inner)
	content.Size = UDim2.new(1, -172, 1, -78)
	content.Position = UDim2.new(0, 166, 0, 66)
	content.BackgroundTransparency = 1
	content.BorderSizePixel = 0
	content.ScrollBarThickness = 6
	content.ScrollBarImageColor3 = getAccent()
	content.CanvasSize = UDim2.new(0, 0, 0, 0)
	content.AutomaticCanvasSize = Enum.AutomaticSize.Y
	content.ScrollingDirection = Enum.ScrollingDirection.Y
	local contentLayout = Instance.new("UIListLayout", content)
	contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
	contentLayout.Padding = UDim.new(0, 6)
	local contentPad = Instance.new("UIPadding", content)
	contentPad.PaddingTop = UDim.new(0, 6)
	contentPad.PaddingLeft = UDim.new(0, 6)
	contentPad.PaddingRight = UDim.new(0, 6)
	contentPad.PaddingBottom = UDim.new(0, 30)
	local reopenBtn = Instance.new("TextButton", mainGui)
	reopenBtn.Size = UDim2.new(0, 180, 0, 42)
	reopenBtn.Position = UDim2.new(0, 12, 0, 12)
	reopenBtn.BackgroundColor3 = Colors.bgDark
	reopenBtn.BorderSizePixel = 0
	reopenBtn.Text = "  Macho HUB"
	reopenBtn.TextColor3 = getAccent()
	reopenBtn.Font = Enum.Font.GothamBold
	reopenBtn.TextSize = 15
	reopenBtn.TextXAlignment = Enum.TextXAlignment.Left
	reopenBtn.AutoButtonColor = false
	reopenBtn.Visible = false
	createUICorner(reopenBtn, 12)
	local reopenStroke = createUIStroke(reopenBtn, getAccent(), 1.6)
	reopenStroke.Transparency = 0.1
	FX.flowGradient(reopenStroke, { speed = 3.6, dim = 0.1 })
	FX.breathe(FX.glow(reopenBtn, { spread = 16, transparency = 0.9, zindex = 0 }), 0.92, 0.8, 2.4)
	local reopenLogo = Instance.new("ImageLabel", reopenBtn)
	reopenLogo.Size = UDim2.new(0, 26, 0, 26)
	reopenLogo.Position = UDim2.new(1, -34, 0.5, -13)
	reopenLogo.BackgroundTransparency = 1
	reopenLogo.Image = Assets.LOGO
	reopenLogo.ScaleType = Enum.ScaleType.Fit
	makeDraggable(reopenBtn, reopenBtn)
	showMain = function()
		reopenBtn.Visible = false
		outer.Visible = true
		currentScale = computeScale()
		uiScale.Scale = currentScale * 0.9
		tween(uiScale, { Scale = currentScale }, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out))
	end
	hideMain = function()
		tween(uiScale, { Scale = (currentScale > 0 and currentScale or computeScale()) * 0.9 }, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In))
		task.delay(0.16, function()
			outer.Visible = false
			reopenBtn.Visible = true
		end)
	end
	closeBtn.MouseButton1Click:Connect(hideMain)
	reopenBtn.MouseButton1Click:Connect(showMain)
	addSection = function(parent, text, order)
		local row = Instance.new("Frame", parent)
		row.Size = UDim2.new(1, 0, 0, 26)
		row.BackgroundTransparency = 1
		row.LayoutOrder = order or 0
		local bar = Instance.new("Frame", row)
		bar.Size = UDim2.new(0, 3, 0, 14)
		bar.Position = UDim2.new(0, 6, 0.5, -7)
		bar.BackgroundColor3 = getAccent()
		bar.BorderSizePixel = 0
		createUICorner(bar, 2)
		local label = Instance.new("TextLabel", row)
		label.Size = UDim2.new(1, -20, 1, 0)
		label.Position = UDim2.new(0, 16, 0, 0)
		label.BackgroundTransparency = 1
		label.Text = text
		label.TextColor3 = getAccent()
		label.Font = Enum.Font.GothamBold
		label.TextSize = 12
		label.TextXAlignment = Enum.TextXAlignment.Left
	end
	addToggle = function(parent, opts)
		local flag = opts.Flag or opts.Title
		local value = opts.Value
		if value == nil then
			value = UIState.flags[flag] or false
		end
		UIState.flags[flag] = value
		local row = Instance.new("Frame", parent)
		row.Size = UDim2.new(1, 0, 0, 46)
		row.BackgroundColor3 = Colors.row
		row.BackgroundTransparency = 0.15
		row.BorderSizePixel = 0
		row.LayoutOrder = opts.Order or 0
		row.ClipsDescendants = true
		createUICorner(row, 10)
		local stroke = createUIStroke(row, Colors.divider, 1)
		stroke.Transparency = 0.5
		local title = Instance.new("TextLabel", row)
		title.Size = UDim2.new(1, -80, 0, 20)
		title.Position = UDim2.new(0, 12, 0, 6)
		title.BackgroundTransparency = 1
		title.Text = opts.Title or ""
		title.TextColor3 = Colors.text
		title.Font = Enum.Font.GothamBold
		title.TextSize = 13
		title.TextXAlignment = Enum.TextXAlignment.Left
		if opts.Desc then
			local desc = Instance.new("TextLabel", row)
			desc.Size = UDim2.new(1, -80, 0, 14)
			desc.Position = UDim2.new(0, 12, 0, 25)
			desc.BackgroundTransparency = 1
			desc.Text = opts.Desc
			desc.TextColor3 = Colors.textMuted
			desc.Font = Enum.Font.Gotham
			desc.TextSize = 11
			desc.TextXAlignment = Enum.TextXAlignment.Left
		end
		local track = Instance.new("Frame", row)
		track.Size = UDim2.new(0, 42, 0, 22)
		track.Position = UDim2.new(1, -54, 0.5, -11)
		track.BackgroundColor3 = value and FX.dark(getAccent(), 0.3) or Colors.input
		createUICorner(track, 11)
		local trackStroke = createUIStroke(track, value and getAccent() or Colors.divider, 1)
		trackStroke.Transparency = value and 0.2 or 0.6
		local trackGlow = FX.glow(track, { spread = 7, transparency = value and 0.72 or 1, zindex = 1 })
		local knob = Instance.new("Frame", track)
		knob.Size = UDim2.new(0, 16, 0, 16)
		knob.Position = value and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
		knob.BackgroundColor3 = value and getAccent() or Color3.fromRGB(120, 130, 140)
		createUICorner(knob, 8)
		PULSE.add(function(t)
			if not track.Parent then
				return false
			end
			local accent = getAccent()
			if value then
				trackStroke.Transparency = 0.3 - 0.26 * t
				trackStroke.Color = accent
				trackGlow.ImageTransparency = 0.84 - 0.2 * t
				knob.BackgroundColor3 = PULSE.mix(accent, Color3.fromRGB(255, 255, 255), 0.1 * t)
			else
				trackStroke.Transparency = 0.62 - 0.1 * t
				trackGlow.ImageTransparency = 1
			end
		end)
		local function set(val, silent)
			value = val
			UIState.flags[flag] = val
			local accent = getAccent()
			tween(knob, {
				Position = val and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8),
				BackgroundColor3 = val and accent or Color3.fromRGB(120, 130, 140),
			}, TweenInfo.new(0.26, Enum.EasingStyle.Back, Enum.EasingDirection.Out))
			tween(track, { BackgroundColor3 = val and FX.dark(accent, 0.3) or Colors.input })
			tween(trackStroke, { Transparency = val and 0.2 or 0.55, Color = val and accent or Colors.divider })
			tween(trackGlow, { ImageTransparency = val and 0.72 or 1 })
			if silent ~= false and opts.Callback then
				task.spawn(function()
					pcall(opts.Callback, val)
				end)
			end
			saveConfig()
		end
		UIState.setters[flag] = set
		local hit = Instance.new("TextButton", row)
		hit.Size = UDim2.new(0, 44, 0, 24)
		hit.Position = UDim2.new(1, -55, 0.5, -12)
		hit.BackgroundTransparency = 1
		hit.Text = ""
		hit.ZIndex = 5
		hit.MouseButton1Click:Connect(function()
			set(not value)
		end)
		local rowHit = Instance.new("TextButton", row)
		rowHit.Size = UDim2.new(1, 0, 1, 0)
		rowHit.BackgroundTransparency = 1
		rowHit.Text = ""
		rowHit.ZIndex = 0
		rowHit.MouseEnter:Connect(function()
			tween(row, { BackgroundTransparency = 0.05 })
			tween(stroke, { Transparency = 0.2, Color = getAccent() })
		end)
		rowHit.MouseLeave:Connect(function()
			tween(row, { BackgroundTransparency = 0.15 })
			tween(stroke, { Transparency = 0.5, Color = Colors.divider })
		end)
		if value and opts.Callback then
			task.defer(function()
				pcall(opts.Callback, value)
			end)
		end
	end
	addSlider = function(parent, opts)
		local flag = opts.Flag or opts.Title
		local min = opts.Value and opts.Value.Min or 0
		local max = opts.Value and opts.Value.Max or 100
		local default = opts.Value and opts.Value.Default or min
		default = UIState.flags[flag] or default
		UIState.flags[flag] = default
		local row = Instance.new("Frame", parent)
		row.Size = UDim2.new(1, 0, 0, 66)
		row.BackgroundColor3 = Colors.row
		row.BackgroundTransparency = 0.15
		row.BorderSizePixel = 0
		row.LayoutOrder = opts.Order or 0
		createUICorner(row, 10)
		createUIStroke(row, Colors.divider, 1).Transparency = 0.5
		local title = Instance.new("TextLabel", row)
		title.Size = UDim2.new(1, -80, 0, 20)
		title.Position = UDim2.new(0, 12, 0, 6)
		title.BackgroundTransparency = 1
		title.Text = opts.Title or ""
		title.TextColor3 = Colors.text
		title.Font = Enum.Font.GothamBold
		title.TextSize = 13
		title.TextXAlignment = Enum.TextXAlignment.Left
		local valueLabel = Instance.new("TextLabel", row)
		valueLabel.Size = UDim2.new(0, 60, 0, 20)
		valueLabel.Position = UDim2.new(1, -72, 0, 6)
		valueLabel.BackgroundTransparency = 1
		valueLabel.Text = tostring(math.floor(default + 0.5))
		valueLabel.TextColor3 = getAccent()
		valueLabel.Font = Enum.Font.GothamBold
		valueLabel.TextSize = 13
		valueLabel.TextXAlignment = Enum.TextXAlignment.Right
		local track = Instance.new("Frame", row)
		track.Size = UDim2.new(1, -24, 0, 8)
		track.Position = UDim2.new(0, 12, 0, 42)
		track.BackgroundColor3 = Colors.input
		track.BorderSizePixel = 0
		createUICorner(track, 4)
		local fill = Instance.new("Frame", track)
		fill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
		fill.BackgroundColor3 = getAccent()
		fill.BorderSizePixel = 0
		createUICorner(fill, 4)
		local knob = Instance.new("Frame", track)
		knob.Size = UDim2.new(0, 16, 0, 16)
		knob.Position = UDim2.new((default - min) / (max - min), -8, 0.5, -8)
		knob.BackgroundColor3 = Colors.white
		knob.BorderSizePixel = 0
		createUICorner(knob, 8)
		local knobGlow = FX.glow(knob, { spread = 8, transparency = 0.7, zindex = 0 })
		PULSE.add(function(t)
			if not knob.Parent then
				return false
			end
			knobGlow.ImageTransparency = 0.72 - 0.15 * t
			knob.BackgroundColor3 = PULSE.mix(Color3.fromRGB(255, 255, 255), getAccent(), 0.15 * t)
		end)
		local function set(val, silent)
			local n = math.clamp(val, min, max)
			UIState.flags[flag] = n
			valueLabel.Text = tostring(math.floor(n + 0.5))
			local pct = (n - min) / (max - min)
			tween(fill, { Size = UDim2.new(pct, 0, 1, 0) }, TweenInfo.new(0.08))
			tween(knob, { Position = UDim2.new(pct, -8, 0.5, -8) }, TweenInfo.new(0.08))
			if silent ~= false and opts.Callback then
				task.spawn(function()
					pcall(opts.Callback, n)
				end)
			end
			saveConfig()
		end
		UIState.setters[flag] = set
		track.InputBegan:Connect(function(input)
			if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
				return
			end
			local function update()
				set(min + (input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X * (max - min))
			end
			update()
			local conn
			conn = input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.Change then
					update()
				elseif input.UserInputState == Enum.UserInputState.End or input.UserInputState == Enum.UserInputState.Cancel then
					if conn then
						conn:Disconnect()
					end
				end
			end)
		end)
		if opts.Callback then
			task.defer(function()
				pcall(opts.Callback, default)
			end)
		end
	end
	addButton = function(parent, opts)
		local row = Instance.new("Frame", parent)
		row.Size = UDim2.new(1, 0, 0, 44)
		row.BackgroundColor3 = Colors.row
		row.BackgroundTransparency = 0.15
		row.BorderSizePixel = 0
		row.LayoutOrder = opts.Order or 0
		createUICorner(row, 10)
		local stroke = createUIStroke(row, Colors.divider, 1)
		stroke.Transparency = 0.5
		local title = Instance.new("TextLabel", row)
		local hasRight = type(opts.RightText) == "string" and opts.RightText ~= ""
		title.Size = hasRight and UDim2.new(1, -155, 1, 0) or UDim2.new(1, -20, 1, 0)
		title.Position = UDim2.new(0, 14, 0, 0)
		title.BackgroundTransparency = 1
		title.Text = opts.Title or ""
		title.TextColor3 = Colors.text
		title.Font = Enum.Font.GothamBold
		title.TextSize = 13
		title.TextXAlignment = Enum.TextXAlignment.Left
		if hasRight then
			local right = Instance.new("TextLabel", row)
			right.Size = UDim2.new(0, 125, 1, 0)
			right.Position = UDim2.new(1, -137, 0, 0)
			right.BackgroundTransparency = 1
			right.Text = opts.RightText
			right.TextColor3 = getAccent()
			right.Font = Enum.Font.GothamBold
			right.TextSize = 12
			right.TextXAlignment = Enum.TextXAlignment.Right
			right.Active = false
		end
		local hit = Instance.new("TextButton", row)
		hit.Size = UDim2.new(1, 0, 1, 0)
		hit.BackgroundTransparency = 1
		hit.Text = ""
		hit.MouseButton1Click:Connect(function()
			tween(row, { BackgroundTransparency = 0.3 }, TweenInfo.new(0.08))
			task.delay(0.12, function()
				tween(row, { BackgroundTransparency = 0.15 }, TweenInfo.new(0.15))
			end)
			if opts.Callback then
				task.spawn(function()
					pcall(opts.Callback)
				end)
			end
		end)
		hit.MouseEnter:Connect(function()
			tween(row, { BackgroundTransparency = 0.05, BackgroundColor3 = Colors.rowHover })
			tween(stroke, { Transparency = 0.2, Color = getAccent() })
		end)
		hit.MouseLeave:Connect(function()
			tween(row, { BackgroundTransparency = 0.15, BackgroundColor3 = Colors.row })
			tween(stroke, { Transparency = 0.5, Color = Colors.divider })
		end)
	end
	addKeybind = function(parent, opts)
		local flag = opts.Flag or opts.Title
		local key = opts.Value or "RightControl"
		key = UIState.flags[flag] or key
		UIState.flags[flag] = key
		local row = Instance.new("Frame", parent)
		row.Size = UDim2.new(1, 0, 0, 44)
		row.BackgroundColor3 = Colors.row
		row.BackgroundTransparency = 0.15
		row.BorderSizePixel = 0
		row.LayoutOrder = opts.Order or 0
		createUICorner(row, 10)
		createUIStroke(row, Colors.divider, 1).Transparency = 0.5
		local title = Instance.new("TextLabel", row)
		title.Size = UDim2.new(1, -110, 1, 0)
		title.Position = UDim2.new(0, 14, 0, 0)
		title.BackgroundTransparency = 1
		title.Text = opts.Title or ""
		title.TextColor3 = Colors.text
		title.Font = Enum.Font.GothamBold
		title.TextSize = 13
		title.TextXAlignment = Enum.TextXAlignment.Left
		local keyBtn = Instance.new("TextButton", row)
		keyBtn.Size = UDim2.new(0, 90, 0, 26)
		keyBtn.Position = UDim2.new(1, -102, 0.5, -13)
		keyBtn.BackgroundColor3 = Colors.input
		keyBtn.BackgroundTransparency = 0.1
		keyBtn.BorderSizePixel = 0
		keyBtn.Text = key
		keyBtn.TextColor3 = getAccent()
		keyBtn.Font = Enum.Font.GothamBold
		keyBtn.TextSize = 12
		keyBtn.AutoButtonColor = false
		createUICorner(keyBtn, 6)
		createUIStroke(keyBtn, Colors.divider, 1)
		local listening = false
		local listenConn = nil
		keyBtn.MouseButton1Click:Connect(function()
			if listening then
				listening = false
				if listenConn then
					listenConn:Disconnect()
					listenConn = nil
				end
				keyBtn.Text = UIState.flags[flag]
				return
			end
			listening = true
			keyBtn.Text = "Press..."
			listenConn = UserInputService.InputBegan:Connect(function(input)
				if not listening then
					return
				end
				if input.UserInputType ~= Enum.UserInputType.Keyboard then
					return
				end
				if input.KeyCode == Enum.KeyCode.Unknown then
					return
				end
				listening = false
				if listenConn then
					listenConn:Disconnect()
					listenConn = nil
				end
				UIState.flags[flag] = input.KeyCode.Name
				keyBtn.Text = input.KeyCode.Name
				if opts.Callback then
					pcall(opts.Callback, input.KeyCode)
				end
				saveConfig()
			end)
		end)
	end
	addKeybindAction = function(parent, opts)
		local row = Instance.new("Frame", parent)
		row.Size = UDim2.new(1, 0, 0, 44)
		row.BackgroundColor3 = Colors.row
		row.BackgroundTransparency = 0.15
		row.BorderSizePixel = 0
		row.LayoutOrder = opts.Order or 0
		createUICorner(row, 10)
		createUIStroke(row, Colors.divider, 1).Transparency = 0.5
		local title = Instance.new("TextLabel", row)
		title.Size = UDim2.new(1, -220, 1, 0)
		title.Position = UDim2.new(0, 14, 0, 0)
		title.BackgroundTransparency = 1
		title.Text = opts.Title or ""
		title.TextColor3 = Colors.text
		title.Font = Enum.Font.GothamBold
		title.TextSize = 13
		title.TextXAlignment = Enum.TextXAlignment.Left
		local keyFlag = (opts.Flag or opts.Title) .. "_Key"
		local key = opts.Key or "None"
		key = UIState.flags[keyFlag] or key
		UIState.flags[keyFlag] = key
		local keyBtn = Instance.new("TextButton", row)
		keyBtn.Size = UDim2.new(0, 80, 0, 26)
		keyBtn.Position = UDim2.new(1, -164, 0.5, -13)
		keyBtn.BackgroundColor3 = Colors.input
		keyBtn.BorderSizePixel = 0
		keyBtn.Text = key
		keyBtn.TextColor3 = getAccent()
		keyBtn.Font = Enum.Font.GothamBold
		keyBtn.TextSize = 12
		keyBtn.AutoButtonColor = false
		createUICorner(keyBtn, 6)
		createUIStroke(keyBtn, Colors.divider, 1)
		local runBtn = Instance.new("TextButton", row)
		runBtn.Size = UDim2.new(0, 70, 0, 26)
		runBtn.Position = UDim2.new(1, -80, 0.5, -13)
		runBtn.BackgroundColor3 = getAccent()
		runBtn.BorderSizePixel = 0
		runBtn.Text = "Run"
		runBtn.TextColor3 = Colors.bgDark
		runBtn.Font = Enum.Font.GothamBold
		runBtn.TextSize = 12
		runBtn.AutoButtonColor = false
		createUICorner(runBtn, 6)
		FX.breathe(FX.glow(runBtn, { spread = 8, transparency = 0.85, zindex = 0 }), 0.88, 0.75, 2.4)
		runBtn.MouseButton1Click:Connect(function()
			if opts.Callback then
				task.spawn(function()
					pcall(opts.Callback)
				end)
			end
		end)
		local listening = false
		local listenConn = nil
		keyBtn.MouseButton1Click:Connect(function()
			if listening then
				listening = false
				if listenConn then
					listenConn:Disconnect()
					listenConn = nil
				end
				keyBtn.Text = UIState.flags[keyFlag]
				return
			end
			listening = true
			keyBtn.Text = "Press..."
			listenConn = UserInputService.InputBegan:Connect(function(input)
				if not listening then
					return
				end
				if input.UserInputType ~= Enum.UserInputType.Keyboard then
					return
				end
				if input.KeyCode == Enum.KeyCode.Unknown then
					return
				end
				listening = false
				if listenConn then
					listenConn:Disconnect()
					listenConn = nil
				end
				UIState.flags[keyFlag] = input.KeyCode.Name
				keyBtn.Text = input.KeyCode.Name
				saveConfig()
			end)
		end)
		UserInputService.InputBegan:Connect(function(input, gameProcessed)
			if gameProcessed then
				return
			end
			if input.UserInputType ~= Enum.UserInputType.Keyboard then
				return
			end
			if input.KeyCode.Name == UIState.flags[keyFlag] then
				if opts.Callback then
					task.spawn(function()
						pcall(opts.Callback)
					end)
				end
			end
		end)
	end
	local clipboardBusy = false
	local function copyToClipboard(text)
		if clipboardBusy then
			return false
		end
		clipboardBusy = true
		local success = false
		for _, fn in ipairs({
			function()
				if typeof(setclipboard) == "function" then
					setclipboard(text)
					return true
				end
				return false
			end,
			function()
				if typeof(toclipboard) == "function" then
					toclipboard(text)
					return true
				end
				return false
			end,
			function()
				if typeof(set_clipboard) == "function" then
					set_clipboard(text)
					return true
				end
				return false
			end,
			function()
				if typeof(writeclipboard) == "function" then
					writeclipboard(text)
					return true
				end
				return false
			end,
		}) do
			local ok, result = pcall(fn)
			if ok and result == true then
				success = true
				break
			end
		end
		clipboardBusy = false
		return success
	end
	local function addCard(parent, opts)
		local row = Instance.new("Frame", parent)
		row.Size = UDim2.new(1, 0, 0, 130)
		row.BackgroundColor3 = Colors.row
		row.BackgroundTransparency = 0.15
		row.BorderSizePixel = 0
		row.LayoutOrder = opts.Order or 0
		createUICorner(row, 10)
		createUIStroke(row, Colors.divider, 1)
		if opts.Thumbnail then
			local thumb = Instance.new("ImageLabel", row)
			thumb.Size = UDim2.new(0, 100, 1, -20)
			thumb.Position = UDim2.new(0, 10, 0, 10)
			thumb.BackgroundTransparency = 1
			thumb.Image = opts.Thumbnail
			thumb.ScaleType = Enum.ScaleType.Fit
		end
		local title = Instance.new("TextLabel", row)
		title.Size = UDim2.new(1, -130, 0, 24)
		title.Position = UDim2.new(0, 120, 0, 12)
		title.BackgroundTransparency = 1
		title.Text = opts.Title or ""
		title.TextColor3 = getAccent()
		title.Font = Enum.Font.GothamBold
		title.TextSize = 15
		title.TextXAlignment = Enum.TextXAlignment.Left
		local desc = Instance.new("TextLabel", row)
		desc.Size = UDim2.new(1, -130, 1, -70)
		desc.Position = UDim2.new(0, 120, 0, 38)
		desc.BackgroundTransparency = 1
		desc.Text = opts.Desc or ""
		desc.TextColor3 = Colors.text
		desc.Font = Enum.Font.Gotham
		desc.TextSize = 12
		desc.TextWrapped = true
		desc.TextXAlignment = Enum.TextXAlignment.Left
		desc.TextYAlignment = Enum.TextYAlignment.Top
		if opts.Buttons then
			local btnRow = Instance.new("Frame", row)
			btnRow.Size = UDim2.new(1, -130, 0, 28)
			btnRow.Position = UDim2.new(0, 120, 1, -36)
			btnRow.BackgroundTransparency = 1
			local layout = Instance.new("UIListLayout", btnRow)
			layout.FillDirection = Enum.FillDirection.Horizontal
			layout.Padding = UDim.new(0, 8)
			for _, btn in ipairs(opts.Buttons) do
				local button = Instance.new("TextButton", btnRow)
				button.Size = UDim2.new(0, 130, 0, 26)
				button.BackgroundColor3 = getAccent()
				button.BorderSizePixel = 0
				button.Text = btn.Title or "Action"
				button.TextColor3 = Colors.bgDark
				button.Font = Enum.Font.GothamBold
				button.TextSize = 12
				button.AutoButtonColor = false
				createUICorner(button, 6)
				FX.breathe(FX.glow(button, { spread = 8, transparency = 0.8, zindex = 0 }), 0.9, 0.75, 2.6)
				button.Activated:Connect(function()
					if btn.Callback then
						task.spawn(btn.Callback)
					end
				end)
			end
		end
	end
	local dropdownGui = Instance.new("ScreenGui")
	dropdownGui.Name = "MachoDropdown"
	dropdownGui.ResetOnSpawn = false
	dropdownGui.IgnoreGuiInset = true
	dropdownGui.DisplayOrder = 9998
	pcall(function()
		if syn and syn.protect_gui then
			syn.protect_gui(dropdownGui)
		end
	end)
	if not pcall(function()
		dropdownGui.Parent = CoreGui
	end) then
		dropdownGui.Parent = playerGui
	end
	local activeDropdown = nil
	local function closeDropdown()
		if activeDropdown then
			pcall(function()
				activeDropdown:Destroy()
			end)
			activeDropdown = nil
		end
	end
	UserInputService.InputBegan:Connect(function(input)
		if activeDropdown and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
			local pos = input.Position
			local absPos = activeDropdown.AbsolutePosition
			local absSize = activeDropdown.AbsoluteSize
			if not (pos.X >= absPos.X and pos.X <= absPos.X + absSize.X and pos.Y >= absPos.Y and pos.Y <= absPos.Y + absSize.Y) then
				closeDropdown()
			end
		end
	end)
	addDropdown = function(parent, opts)
		local flag = opts.Flag or opts.Title
		local values = opts.Values or {}
		local current = opts.Value or values[1] or "Select"
		current = UIState.flags[flag] or current
		UIState.flags[flag] = current
		local row = Instance.new("Frame", parent)
		row.Size = UDim2.new(1, 0, 0, 44)
		row.BackgroundColor3 = Colors.row
		row.BackgroundTransparency = 0.15
		row.BorderSizePixel = 0
		row.LayoutOrder = opts.Order or 0
		createUICorner(row, 10)
		createUIStroke(row, Colors.divider, 1).Transparency = 0.5
		local title = Instance.new("TextLabel", row)
		title.Size = UDim2.new(0, 130, 1, 0)
		title.Position = UDim2.new(0, 14, 0, 0)
		title.BackgroundTransparency = 1
		title.Text = opts.Title or ""
		title.TextColor3 = Colors.text
		title.Font = Enum.Font.GothamBold
		title.TextSize = 13
		title.TextXAlignment = Enum.TextXAlignment.Left
		local btn = Instance.new("TextButton", row)
		btn.Size = UDim2.new(1, -160, 1, -12)
		btn.Position = UDim2.new(0, 148, 0, 6)
		btn.BackgroundColor3 = Colors.input
		btn.BorderSizePixel = 0
		btn.Text = tostring(current)
		btn.TextColor3 = getAccent()
		btn.Font = Enum.Font.GothamBold
		btn.TextSize = 12
		btn.TextTruncate = Enum.TextTruncate.AtEnd
		btn.TextXAlignment = Enum.TextXAlignment.Center
		btn.AutoButtonColor = false
		createUICorner(btn, 6)
		createUIStroke(btn, Colors.divider, 1)
		local function set(val, silent)
			UIState.flags[flag] = val
			btn.Text = tostring(val)
			if silent ~= false and opts.Callback then
				task.spawn(function()
					pcall(opts.Callback, val)
				end)
			end
			saveConfig()
		end
		UIState.setters[flag] = set
		btn.MouseButton1Click:Connect(function()
			if activeDropdown then
				closeDropdown()
				return
			end
			local list = values
			if type(opts.GetValues) == "function" then
				local ok, result = pcall(opts.GetValues)
				if ok and type(result) == "table" then
					values = result
					list = result
				end
			end
			local absPos = btn.AbsolutePosition
			local absSize = btn.AbsoluteSize
			local viewport = workspace.CurrentCamera.ViewportSize
			local height = math.clamp(math.max(#list, 1) * 28 + 8, 40, 200)
			local width = math.max(absSize.X, 180)
			local x = absPos.X + absSize.X - width
			local y = absPos.Y + absSize.Y + 6
			local altY = absPos.Y - height - 6
			if not (y + height <= viewport.Y - 8) then
				if altY >= 8 then
					y = altY
				else
					y = math.max(8, math.min(y, viewport.Y - height - 8))
				end
			end
			local menu = Instance.new("Frame", dropdownGui)
			menu.Position = UDim2.fromOffset(x, y)
			menu.Size = UDim2.fromOffset(width, height)
			menu.BackgroundColor3 = Colors.bgDark
			menu.BackgroundTransparency = 0.05
			menu.BorderSizePixel = 0
			menu.ZIndex = 50
			createUICorner(menu, 8)
			createUIStroke(menu, getAccent(), 1.2)
			activeDropdown = menu
			local scroll = Instance.new("ScrollingFrame", menu)
			scroll.Size = UDim2.new(1, -8, 1, -8)
			scroll.Position = UDim2.new(0, 4, 0, 4)
			scroll.BackgroundTransparency = 1
			scroll.BorderSizePixel = 0
			scroll.ScrollBarThickness = 3
			scroll.ScrollBarImageColor3 = getAccent()
			scroll.ScrollingDirection = Enum.ScrollingDirection.Y
			scroll.CanvasSize = UDim2.new(0, 0, 0, #list * 28)
			scroll.ZIndex = 51
			local layout = Instance.new("UIListLayout", scroll)
			layout.Padding = UDim.new(0, 2)
			layout.SortOrder = Enum.SortOrder.LayoutOrder
			if #list == 0 then
				local empty = Instance.new("TextLabel", scroll)
				empty.Size = UDim2.new(1, 0, 0, 28)
				empty.BackgroundTransparency = 1
				empty.Text = "Oyuncu bulunamadi"
				empty.TextColor3 = Colors.textMuted
				empty.Font = Enum.Font.GothamBold
				empty.TextSize = 12
				empty.ZIndex = 52
			else
				for i, val in ipairs(list) do
					local item = Instance.new("TextButton", scroll)
					item.Size = UDim2.new(1, 0, 0, 26)
					item.BackgroundColor3 = Colors.row
					item.BackgroundTransparency = 0.3
					item.BorderSizePixel = 0
					item.LayoutOrder = i
					item.Text = tostring(val)
					item.TextColor3 = Colors.text
					item.Font = Enum.Font.GothamBold
					item.TextSize = 12
					item.TextXAlignment = Enum.TextXAlignment.Left
					item.AutoButtonColor = false
					item.TextTruncate = Enum.TextTruncate.AtEnd
					item.ZIndex = 52
					createUICorner(item, 5)
					Instance.new("UIPadding", item).PaddingLeft = UDim.new(0, 8)
					item.MouseButton1Click:Connect(function()
						set(val)
						closeDropdown()
					end)
					item.MouseEnter:Connect(function()
						tween(item, { BackgroundTransparency = 0.05, BackgroundColor3 = FX.mix(Colors.row, getAccent(), 0.2) })
					end)
					item.MouseLeave:Connect(function()
						tween(item, { BackgroundTransparency = 0.3, BackgroundColor3 = Colors.row })
					end)
				end
			end
		end)
		return {
			set = set,
			refresh = function(newValues)
				if type(newValues) == "table" then
					values = newValues
				end
			end,
			button = btn,
		}
	end
	local coinFarmThread = nil
	local coinFarmNoclipWas = false
	local function getCoinContainer()
		return Workspace:FindFirstChild("CoinContainer", true)
	end
	local function getCoinPart(obj)
		if not obj then
			return nil
		end
		if obj:IsA("BasePart") then
			return obj
		end
		for _, d in ipairs(obj:GetDescendants()) do
			if d:IsA("TouchInterest") and d.Parent and d.Parent:IsA("BasePart") then
				return d.Parent
			end
		end
		for _, d in ipairs(obj:GetDescendants()) do
			if d:IsA("BasePart") and d.Name == "Coin" then
				return d
			end
		end
		return obj:FindFirstChildWhichIsA("BasePart", true)
	end
	local function getCoins()
		local container = getCoinContainer()
		return container and container:GetChildren() or {}
	end
	local function hasCoins()
		return getCoinContainer() ~= nil
	end
	local function getCoinProgress()
		local current = 0
		local max = 40
		pcall(function()
			local mainGui = localPlayer:FindFirstChild("PlayerGui") and localPlayer.PlayerGui:FindFirstChild("MainGui")
			if not mainGui then
				return
			end
			for _, d in ipairs(mainGui:GetDescendants()) do
				if d:IsA("TextLabel") then
					local a, b = tostring(d.Text or ""):gsub("<[^>]+>", ""):match("(%d+)%s*/%s*(%d+)")
					if a and b then
						current = tonumber(a) or current
						max = tonumber(b) or max
						break
					end
				end
			end
		end)
		return current, max
	end
	local function touchCoin(part)
		if not firetouchinterest then
			return false
		end
		local root = WM.LocalRootPart
		if not root or not part or not part.Parent then
			return false
		end
		return pcall(function()
			firetouchinterest(root, part, 0)
			firetouchinterest(root, part, 1)
		end)
	end
	local function moveToCoin(obj)
		local root = WM.LocalRootPart
		if not root or not obj or not obj.Parent then
			return false
		end
		local part = getCoinPart(obj)
		local pos = part and part.Position or nil
		if not part or not pos then
			return false
		end
		local dist = (pos - root.Position).Magnitude
		if dist <= 0.05 then
			touchCoin(part)
			task.wait(0.05)
			return true
		end
		local tweenObj = TweenService:Create(root, TweenInfo.new(math.clamp(dist / 25, 0.05, 8), Enum.EasingStyle.Linear), { CFrame = CFrame.new(pos) })
		tweenObj:Play()
		while tweenObj.PlaybackState == Enum.PlaybackState.Playing do
			if not Config.CoinFarm or not obj.Parent or not WM.LocalRootPart then
				pcall(function()
					tweenObj:Cancel()
				end)
				return false
			end
			task.wait()
		end
		touchCoin(part)
		task.wait(0.05)
		return true
	end
	local function stopCoinFarm()
		if coinFarmThread then
			task.cancel(coinFarmThread)
			coinFarmThread = nil
		end
		if Config.CoinFarm then
			Config.CoinFarm = false
		end
		if Config.Noclip ~= coinFarmNoclipWas then
			MachoHub.EnableNoclip(coinFarmNoclipWas)
		end
	end
	MachoHub.ToggleCoinFarm = function(enabled)
		local on = enabled == true
		Config.CoinFarm = on
		if coinFarmThread then
			task.cancel(coinFarmThread)
			coinFarmThread = nil
		end
		if not on then
			if Config.Noclip ~= coinFarmNoclipWas then
				MachoHub.EnableNoclip(coinFarmNoclipWas)
			end
			return
		end
		if not firetouchinterest then
			Config.CoinFarm = false
			pushNotify({
				Title = "Coin Farm",
				Content = "firetouchinterest is unavailable in this executor.",
				Duration = 5,
				Color = Colors.danger,
			})
			return
		end
		coinFarmNoclipWas = Config.Noclip
		MachoHub.EnableNoclip(true)
		coinFarmThread = task.spawn(function()
			while Config.CoinFarm and mainGui.Parent do
				if hasCoins() then
					local coins = getCoins()
					if #coins > 0 then
						for _, coin in ipairs(coins) do
							if Config.CoinFarm then
								if coin and coin.Parent and getCoinPart(coin) then
									moveToCoin(coin)
									task.wait(0.05)
								end
							else
								break
							end
						end
						local cur, max = getCoinProgress()
						if cur >= max and max > 0 then
							local character = WM.LocalCharacter
							local humanoid = WM.LocalHumanoid
							if character and humanoid and humanoid.Health > 0 then
								pcall(function()
									humanoid:BreakJoints()
								end)
								task.wait(0.7)
							end
						end
					else
						task.wait(0.5)
					end
				else
					task.wait(1)
				end
			end
		end)
	end
	MachoHub.StopCoinFarm = stopCoinFarm
	local function createTab(name)
		local btn = Instance.new("TextButton", sidebar)
		btn.Size = UDim2.new(1, -4, 0, 36)
		btn.BackgroundColor3 = Colors.row
		btn.BackgroundTransparency = 0.35
		btn.Text = ""
		btn.AutoButtonColor = false
		btn.BorderSizePixel = 0
		createUICorner(btn, 8)
		local stroke = createUIStroke(btn, Colors.divider, 1)
		stroke.Transparency = 0.7
		local label = Instance.new("TextLabel", btn)
		label.Size = UDim2.new(1, -20, 1, 0)
		label.Position = UDim2.new(0, 16, 0, 0)
		label.BackgroundTransparency = 1
		label.Text = name
		label.TextColor3 = Colors.textDim
		label.Font = Enum.Font.GothamBold
		label.TextSize = 13
		label.TextXAlignment = Enum.TextXAlignment.Left
		local indicator = Instance.new("Frame", btn)
		indicator.Size = UDim2.new(0, 3, 0, 0)
		indicator.AnchorPoint = Vector2.new(0, 0.5)
		indicator.Position = UDim2.new(0, 6, 0.5, 0)
		indicator.BackgroundColor3 = getAccent()
		indicator.BorderSizePixel = 0
		indicator.Visible = false
		createUICorner(indicator, 2)
		local page = Instance.new("Frame", content)
		page.Size = UDim2.new(1, 0, 0, 0)
		page.AutomaticSize = Enum.AutomaticSize.Y
		page.BackgroundTransparency = 1
		page.Visible = false
		local pageLayout = Instance.new("UIListLayout", page)
		pageLayout.SortOrder = Enum.SortOrder.LayoutOrder
		pageLayout.Padding = UDim.new(0, 6)
		UIState.contentPages[name] = page
		UIState.sidebarBtns[name] = { btn = btn, label = label, ind = indicator, stroke = stroke }
		btn.MouseButton1Click:Connect(function()
			if UIState.activeTab == name then
				return
			end
			UIState.activeTab = name
			for k, p in pairs(UIState.contentPages) do
				p.Visible = k == name
			end
			for k, s in pairs(UIState.sidebarBtns) do
				local active = k == name
				tween(s.btn, {
					BackgroundColor3 = active and FX.mix(Colors.row, getAccent(), 0.14) or Colors.row,
					BackgroundTransparency = active and 0 or 0.35,
				}, TweenInfo.new(0.22))
				tween(s.label, { TextColor3 = active and Colors.white or Colors.textDim })
				tween(s.stroke, { Transparency = active and 0.15 or 0.7, Color = active and getAccent() or Colors.divider })
				s.ind.Visible = active
				if active then
					s.ind.Size = UDim2.new(0, 3, 0, 0)
					tween(s.ind, { Size = UDim2.new(0, 3, 0, 18) }, TweenInfo.new(0.25, Enum.EasingStyle.Back))
				end
			end
			content.CanvasPosition = Vector2.new(0, 0)
		end)
		btn.MouseEnter:Connect(function()
			if UIState.activeTab ~= name then
				tween(btn, { BackgroundTransparency = 0.1 })
			end
		end)
		btn.MouseLeave:Connect(function()
			if UIState.activeTab ~= name then
				tween(btn, { BackgroundTransparency = 0.35 })
			end
		end)
		return page
	end
	pages = {
		Home = createTab("Home"),
		Movement = createTab("Movement"),
		Combat = createTab("Combat"),
		Visuals = createTab("Visuals"),
		Buttons = createTab("Buttons"),
		Teleports = createTab("Teleports"),
		Misc = createTab("Misc"),
		Background = createTab("Background"),
		Settings = createTab("Settings"),
	}
	local coinFarmBtn = Instance.new("TextButton", sidebar)
	coinFarmBtn.Name = "CoinFarmSidebarButton"
	coinFarmBtn.Size = UDim2.new(1, -4, 0, 36)
	coinFarmBtn.BackgroundColor3 = Colors.row
	coinFarmBtn.BackgroundTransparency = 0.35
	coinFarmBtn.Text = ""
	coinFarmBtn.AutoButtonColor = false
	coinFarmBtn.BorderSizePixel = 0
	createUICorner(coinFarmBtn, 8)
	local coinStroke = createUIStroke(coinFarmBtn, Colors.divider, 1)
	coinStroke.Transparency = 0.7
	local coinLabel = Instance.new("TextLabel", coinFarmBtn)
	coinLabel.Size = UDim2.new(1, -44, 1, 0)
	coinLabel.Position = UDim2.new(0, 16, 0, 0)
	coinLabel.BackgroundTransparency = 1
	coinLabel.TextColor3 = Colors.textDim
	coinLabel.Font = Enum.Font.GothamBold
	coinLabel.TextSize = 13
	coinLabel.TextXAlignment = Enum.TextXAlignment.Left
	local coinStatus = Instance.new("TextLabel", coinFarmBtn)
	coinStatus.Size = UDim2.new(0, 34, 1, 0)
	coinStatus.Position = UDim2.new(1, -40, 0, 0)
	coinStatus.BackgroundTransparency = 1
	coinStatus.Font = Enum.Font.GothamBlack
	coinStatus.TextSize = 10
	coinStatus.TextXAlignment = Enum.TextXAlignment.Right
	local coinInd = Instance.new("Frame", coinFarmBtn)
	coinInd.Size = UDim2.new(0, 3, 0, 18)
	coinInd.AnchorPoint = Vector2.new(0, 0.5)
	coinInd.Position = UDim2.new(0, 6, 0.5, 0)
	coinInd.BackgroundColor3 = getAccent()
	coinInd.BorderSizePixel = 0
	coinInd.Visible = false
	createUICorner(coinInd, 2)
	local function updateCoinFarmUI()
		local on = Config.CoinFarm == true
		coinLabel.Text = "Coin Farm"
		coinStatus.Text = on and "ON" or "OFF"
		coinStatus.TextColor3 = on and getAccent() or Colors.textMuted
		coinFarmBtn.BackgroundColor3 = on and FX.mix(Colors.row, getAccent(), 0.14) or Colors.row
		coinFarmBtn.BackgroundTransparency = on and 0 or 0.35
		coinStroke.Color = on and getAccent() or Colors.divider
		coinStroke.Transparency = on and 0.15 or 0.7
		coinInd.BackgroundColor3 = getAccent()
		coinInd.Visible = on
	end
	UIState.flags.CoinFarmToggle = UIState.flags.CoinFarmToggle or false
	UIState.setters.CoinFarmToggle = function(val)
		MachoHub.ToggleCoinFarm(val == true)
		UIState.flags.CoinFarmToggle = Config.CoinFarm == true
		updateCoinFarmUI()
	end
	coinFarmBtn.MouseButton1Click:Connect(function()
		local next = not (Config.CoinFarm == true)
		UIState.flags.CoinFarmToggle = next
		MachoHub.ToggleCoinFarm(next)
		updateCoinFarmUI()
	end)
	coinFarmBtn.MouseEnter:Connect(function()
		if Config.CoinFarm ~= true then
			tween(coinFarmBtn, { BackgroundTransparency = 0.1 })
		end
	end)
	coinFarmBtn.MouseLeave:Connect(function()
		updateCoinFarmUI()
	end)
	updateCoinFarmUI()
	UIState.contentPages.Home.Visible = true
	UIState.activeTab = "Home"
	local homeBtn = UIState.sidebarBtns.Home
	homeBtn.btn.BackgroundColor3 = FX.mix(Colors.row, getAccent(), 0.14)
	homeBtn.btn.BackgroundTransparency = 0
	homeBtn.label.TextColor3 = Colors.white
	homeBtn.stroke.Transparency = 0.15
	homeBtn.stroke.Color = getAccent()
	homeBtn.ind.Visible = true
	homeBtn.ind.Size = UDim2.new(0, 3, 0, 18)
	addCard(pages.Home, {
		Order = 1,
		Title = "Welcome to Macho HUB!",
		Desc = "Thanks for using Macho HUB. Join our Discord for support and updates.",
		Thumbnail = Assets.LOGO,
		Buttons = {
			{
				Title = "Join Discord",
				Callback = function()
					if copyToClipboard("https://discord.gg/irish") then
						pushNotify({
							Title = "Discord Link Copied",
							Content = "https://discord.gg/irish",
							Duration = 4,
							Color = Colors.success,
						})
					else
						pushNotify({
							Title = "Clipboard Unavailable",
							Content = "Executor Not Support Join: https://discord.gg/irish",
							Duration = 4,
							Color = Colors.danger,
						})
					end
				end,
			},
		},
	})
end

addSection(pages.Home, "Contact", 3)
addButton(pages.Home, {
	Order = 4,
	Title = "Report a bug on Discord",
	RightText = "discord.gg/irish",
	Callback = function()
		pushNotify({ Title = "Discord", Content = "discord.gg/irish", Duration = 3, Color = getAccent() })
	end,
})
addSection(pages.Movement, "Movement", 1)
addToggle(pages.Movement, {
	Order = 2,
	Title = "Enable WalkSpeed",
	Desc = "Allow custom WalkSpeed",
	Flag = "EnableWalkspeedToggle",
	Callback = MachoHub.EnableWalkSpeed,
})
addSlider(pages.Movement, {
	Order = 3,
	Title = "WalkSpeed",
	Flag = "WalkspeedSlider",
	Value = { Min = 16, Max = 200, Default = 16 },
	Callback = MachoHub.SetWalkSpeed,
})
addToggle(pages.Movement, {
	Order = 4,
	Title = "Enable JumpPower",
	Desc = "Allow custom JumpPower",
	Flag = "EnableJumppowerToggle",
	Callback = MachoHub.EnableJumpPower,
})
addSlider(pages.Movement, {
	Order = 5,
	Title = "Jump Power",
	Flag = "JumppowerSlider",
	Value = { Min = 50, Max = 300, Default = 50 },
	Callback = MachoHub.SetJumpPower,
})
addToggle(pages.Movement, { Order = 6, Title = "Enable Noclip", Flag = "NoclipToggle", Callback = MachoHub.EnableNoclip })
addToggle(pages.Movement, { Order = 7, Title = "Infinite Jump", Flag = "InfiniteJumpToggle", Callback = MachoHub.InfiniteJump })
addButton(pages.Movement, {
	Order = 8,
	Title = "Reset Character",
	Callback = function()
		if WM.LocalCharacter then
			WM.LocalCharacter:BreakJoints()
		end
	end,
})
addSection(pages.Combat, "General", 1)
addKeybindAction(pages.Combat, { Order = 2, Title = "Grab Gun", Key = "G", Flag = "GrabGun", Callback = MachoHub.GrabGun })
addToggle(pages.Combat, { Order = 3, Title = "Auto Grab Gun", Flag = "AutoGrabGunToggle", Callback = MachoHub.ToggleAutoGrabGun })
addToggle(pages.Combat, { Order = 4, Title = "God Mode", Flag = "GodModeToggle", Callback = MachoHub.EnableGodMode })
addToggle(pages.Combat, { Order = 5, Title = "Anti-Fling", Flag = "AntiFlingToggle", Callback = MachoHub.ToggleAntiFling })
addSection(pages.Combat, "Murderer", 6)
addKeybindAction(pages.Combat, { Order = 7, Title = "Kill All", Key = "K", Flag = "KillAll", Callback = MachoHub.KillAll })
addToggle(pages.Combat, { Order = 8, Title = "Auto Kill All", Flag = "AutoKillToggle", Callback = MachoHub.ToggleAutoKillAll })
addToggle(pages.Combat, { Order = 9, Title = "Knife Aura", Flag = "KillAuraToggle", Callback = MachoHub.KillAura })
addSlider(pages.Combat, {
	Order = 10,
	Title = "Knife Aura Radius",
	Flag = "AuraRadiusSlider",
	Value = { Min = 5, Max = 100, Default = 10 },
	Callback = function(r)
		Config.AuraRadius = r
	end,
})
addToggle(pages.Combat, {
	Order = 11,
	Title = "Auto Knife Throw",
	Flag = "ThrowKnifeFlag",
	Callback = MachoHub.ToggleSilentThrow,
})
addKeybindAction(pages.Combat, {
	Order = 12,
	Title = "Throw Knife",
	Key = "Q",
	Flag = "ThrowKnifeBtn",
	Callback = MachoHub.ExecuteThrowAtNearest,
})
addSection(pages.Combat, "Sheriff", 13)
addToggle(pages.Combat, {
	Order = 14,
	Title = "Auto Shoot Murderer",
	Flag = "AutoShootMurderer",
	Callback = MachoHub.ToggleAutoShootMurderer,
})
addKeybindAction(pages.Combat, {
	Order = 15,
	Title = "Shoot Murderer",
	Key = "E",
	Flag = "ShootMurdererBtn",
	Callback = MachoHub.ShootMurdererOnce,
})

if not CoreGui:FindFirstChild("MachoESP") then
	local folder = Instance.new("Folder")
	folder.Name = "MachoESP"
	folder.Parent = CoreGui
end

do
	local function createNameESP(adornee)
		local gui = Instance.new("BillboardGui")
		gui.Name = "NameESP"
		gui.Adornee = adornee
		gui.Size = UDim2.new(0, 200, 0, 50)
		gui.StudsOffset = Vector3.new(0, 3, 0)
		gui.AlwaysOnTop = true
		local label = Instance.new("TextLabel", gui)
		label.BackgroundTransparency = 1
		label.Size = UDim2.new(1, 0, 1, 0)
		label.TextSize = 16
		label.Font = Enum.Font.SourceSansBold
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextStrokeTransparency = 0
		label.TextStrokeColor3 = Color3.new(0, 0, 0)
		return gui
	end
	local function updateESP()
		for _, player in ipairs(Players:GetPlayers()) do
			if player ~= localPlayer and player.Character then
				local color = Color3.fromRGB(0, 255, 0)
				local role = "Innocent"
				if WM.findMurderer() == player then
					color = Color3.fromRGB(255, 0, 0)
					role = "Murderer"
				elseif WM.findSheriff() == player then
					color = Color3.fromRGB(0, 0, 255)
					role = "Sheriff"
				end
				local character = player.Character
				if Config.EspPlayers then
					if not character:FindFirstChild("MachoHighlight") then
						local hl = Instance.new("Highlight")
						hl.Name = "MachoHighlight"
						hl.FillTransparency = 0.85
						hl.OutlineTransparency = 0
						hl.Parent = character
					end
					local hl = character:FindFirstChild("MachoHighlight")
					if hl then
						hl.FillColor = color
						hl.OutlineColor = color
						hl.Enabled = true
					end
				elseif character:FindFirstChild("MachoHighlight") then
					character.MachoHighlight:Destroy()
				end
				if Config.ShowNames then
					local head = character:FindFirstChild("Head")
					if head then
						if not head:FindFirstChild("NameESP") then
							createNameESP(head).Parent = head
						end
						local nameESP = head:FindFirstChild("NameESP")
						local label = nameESP and nameESP:FindFirstChild("TextLabel")
						local localRoot = WM.LocalRootPart
						local hrp = character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart
						local dist = localRoot and hrp and math.floor((localRoot.Position - hrp.Position).Magnitude) or "?"
						if label then
							label.Text = string.format("%s\n[%s] [%s]", player.Name, role, tostring(dist))
							label.TextColor3 = color
						end
					end
				elseif character:FindFirstChild("Head") and character.Head:FindFirstChild("NameESP") then
					character.Head.NameESP:Destroy()
				end
			end
		end
	end
	local espConn = nil
	local function setESP(enabled)
		if enabled then
			if not espConn then
				espConn = trackConnection(RunService.RenderStepped:Connect(updateESP))
			end
		elseif not Config.EspPlayers and not Config.ShowNames then
			if espConn then
				espConn:Disconnect()
				espConn = nil
			end
			for _, player in ipairs(Players:GetPlayers()) do
				if player.Character then
					if player.Character:FindFirstChild("MachoHighlight") then
						player.Character.MachoHighlight:Destroy()
					end
					if player.Character:FindFirstChild("Head") and player.Character.Head:FindFirstChild("NameESP") then
						player.Character.Head.NameESP:Destroy()
					end
				end
			end
		end
	end
	local gunESPConn = nil
	local function clearGunESP()
		for _, d in ipairs(Workspace:GetDescendants()) do
			if d.Name == "GunDrop" then
				if d:FindFirstChild("MachoGunHighlight") then
					d.MachoGunHighlight:Destroy()
				end
				if d:FindFirstChild("MachoGunLabel") then
					d.MachoGunLabel:Destroy()
				end
			end
		end
	end
	local function applyGunESP(part)
		if not part or not part:IsA("BasePart") then
			return
		end
		if part:FindFirstChild("MachoGunHighlight") then
			part.MachoGunHighlight:Destroy()
		end
		if part:FindFirstChild("MachoGunLabel") then
			part.MachoGunLabel:Destroy()
		end
		local hl = Instance.new("Highlight")
		hl.Name = "MachoGunHighlight"
		hl.Adornee = part
		hl.FillColor = Color3.fromRGB(0, 255, 255)
		hl.OutlineColor = Color3.fromRGB(255, 255, 255)
		hl.FillTransparency = 0.5
		hl.OutlineTransparency = 0
		hl.Parent = part
		local gui = Instance.new("BillboardGui", part)
		gui.Name = "MachoGunLabel"
		gui.Adornee = part
		gui.Size = UDim2.new(0, 150, 0, 50)
		gui.StudsOffset = Vector3.new(0, 2, 0)
		gui.AlwaysOnTop = true
		local label = Instance.new("TextLabel", gui)
		label.BackgroundTransparency = 1
		label.Size = UDim2.new(1, 0, 1, 0)
		label.TextSize = 14
		label.Font = Enum.Font.GothamBold
		label.Text = "DROPPED GUN"
		label.TextColor3 = Color3.fromRGB(0, 255, 255)
		label.TextStrokeTransparency = 0
		label.TextStrokeColor3 = Color3.new(0, 0, 0)
	end
	MachoHub.ToggleGunESP = function(enabled)
		Config.EspDroppedGun = enabled
		if gunESPConn then
			gunESPConn:Disconnect()
			gunESPConn = nil
		end
		if enabled then
			for _, d in ipairs(Workspace:GetDescendants()) do
				if d.Name == "GunDrop" then
					applyGunESP(d)
				end
			end
			gunESPConn = trackConnection(Workspace.DescendantAdded:Connect(function(d)
				if d.Name == "GunDrop" then
					task.wait()
					applyGunESP(d)
				end
			end))
		else
			clearGunESP()
		end
	end
	addSection(pages.Visuals, "THEME COLOR", 1)
	local themeRow = Instance.new("Frame", pages.Visuals)
	themeRow.Size = UDim2.new(1, -8, 0, 42)
	themeRow.BackgroundTransparency = 1
	themeRow.LayoutOrder = 2
	local themeLayout = Instance.new("UIListLayout", themeRow)
	themeLayout.FillDirection = Enum.FillDirection.Horizontal
	themeLayout.Padding = UDim.new(0, 6)
	themeLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	local themeButtons = {}
	local function refreshThemeUI()
		for name, btn in pairs(themeButtons) do
			local active = UIState.themeName == name
			btn.BackgroundColor3 = btn:GetAttribute("BaseColor") or Color3.fromRGB(255, 255, 255)
			local stroke = btn:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Thickness = active and 2.5 or 1
				stroke.Color = active and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(60, 60, 70)
			end
			local check = btn:FindFirstChild("Check")
			if check then
				check.Visible = active
			end
		end
	end
	for _, theme in ipairs(Themes) do
		local btn = Instance.new("TextButton", themeRow)
		btn.Size = UDim2.new(0, 30, 0, 30)
		btn.BackgroundColor3 = theme.color
		btn:SetAttribute("BaseColor", theme.color)
		btn.BorderSizePixel = 0
		btn.Text = ""
		btn.AutoButtonColor = false
		createUICorner(btn, 999)
		createUIStroke(btn, Color3.fromRGB(60, 60, 70), 1).Transparency = 0.2
		if theme.rainbow then
			local grad = Instance.new("UIGradient", btn)
			grad.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
				ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 200, 70)),
				ColorSequenceKeypoint.new(0.4, Color3.fromRGB(90, 240, 140)),
				ColorSequenceKeypoint.new(0.6, Color3.fromRGB(80, 200, 255)),
				ColorSequenceKeypoint.new(0.8, Color3.fromRGB(150, 120, 255)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 110, 200)),
			})
			grad.Rotation = 30
			task.spawn(function()
				while btn and btn.Parent do
					grad.Offset = Vector2.new(os.clock() * 0.25 % 2 - 1, 0)
					grad.Rotation = 30 + math.sin(os.clock() * 0.8) * 12
					task.wait(0.03)
				end
			end)
		end
		local check = Instance.new("TextLabel", btn)
		check.Name = "Check"
		check.Size = UDim2.new(1, 0, 1, 0)
		check.BackgroundTransparency = 1
		check.Text = "✓"
		check.TextColor3 = Color3.fromRGB(0, 0, 0)
		check.Font = Enum.Font.GothamBlack
		check.TextSize = 16
		check.Visible = false
		themeButtons[theme.name] = btn
		btn.MouseButton1Click:Connect(function()
			UIState.themeName = theme.name
			if not theme.rainbow then
				setAccent(theme.color)
			end
			refreshThemeUI()
			saveConfig()
			pushNotify({ Title = "Theme", Content = theme.name, Duration = 2, Color = getAccent() })
		end)
	end
	refreshThemeUI()
	addSection(pages.Visuals, "ESP", 3)
	addToggle(pages.Visuals, {
		Order = 4,
		Title = "ESP Players",
		Flag = "EspToggle",
		Callback = function(v)
			Config.EspPlayers = v
			setESP(v or Config.ShowNames)
		end,
	})
	addToggle(pages.Visuals, {
		Order = 5,
		Title = "Show Informations",
		Flag = "ShowNamesToggle",
		Callback = function(v)
			Config.ShowNames = v
			setESP(v or Config.EspPlayers)
		end,
	})
end

addToggle(pages.Visuals, { Order = 6, Title = "ESP Dropped Gun", Flag = "EspGunToggle", Callback = MachoHub.ToggleGunESP })
addToggle(pages.Visuals, { Order = 7, Title = "Round Timer", Flag = "RoundTimerToggle", Callback = MachoHub.ToggleRoundTimer })
addSection(pages.Visuals, "Notify", 8)
addToggle(pages.Visuals, {
	Order = 9,
	Title = "Notify Gun Dropped",
	Flag = "NotifyGunDroppedToggle",
	Callback = MachoHub.ToggleNotifyGunDropped,
})
addToggle(pages.Visuals, {
	Order = 10,
	Title = "Notify Murderer",
	Flag = "NotifyMurdererToggle",
	Callback = function(v)
		Config.NotifyMurderer = v
		MachoHub.UpdateRoleNotify()
	end,
})
addToggle(pages.Visuals, {
	Order = 11,
	Title = "Notify Sheriff",
	Flag = "NotifySheriffToggle",
	Callback = function(v)
		Config.NotifySheriff = v
		MachoHub.UpdateRoleNotify()
	end,
})
addSection(pages.Buttons, "Mobile Buttons", 1)
addToggle(pages.Buttons, {
	Order = 2,
	Title = "Lock Buttons",
	Desc = "Disable dragging (clicking still works)",
	Flag = "lock_buttons",
	Callback = function(v)
		Config.ButtonsLocked = v
		UIState.lockMobileButtons = v
		saveConfig()
	end,
})
addSlider(pages.Buttons, {
	Order = 3,
	Title = "Button Size",
	Flag = "MobileBtnSizeSlider",
	Value = { Min = 50, Max = 140, Default = 80 },
	Callback = function(v)
		UIState.mobileButtonSize = math.floor(v)
		applyMobileButtons()
		saveConfig()
	end,
})
addButton(pages.Buttons, {
	Order = 4,
	Title = "Reset All Button Positions",
	Callback = function()
		UIState.flags.mobileButtonStates = {}
		if writefile then
			pcall(function()
				writefile("MachoHUB.json", HttpService:JSONEncode(UIState.flags))
			end)
		end
		applyMobileButtons()
		pushNotify({ Title = "Reset", Content = "Button positions cleared", Duration = 3 })
	end,
})

do
	local mobileDefs = {
		{
			flag = "show_shoot_button",
			id = "Shoot",
			settings = { Type = "Image", Icon = Assets.SHOOT, Text = "Shoot" },
			cb = MachoHub.ShootMurdererOnce,
			order = 5,
			title = "Show Shoot Button",
		},
		{
			flag = "show_fmurderer_button",
			id = "FlingMurderer",
			settings = { Type = "Text", Text = "Fling Murderer" },
			cb = function()
				local p = WM.findMurderer()
				if p and p.Character then
					flingPlayer(p)
				end
			end,
			order = 6,
			title = "Fling Murderer Button",
		},
		{
			flag = "show_fsheriff_button",
			id = "FlingSheriff",
			settings = { Type = "Text", Text = "Fling Sheriff" },
			cb = function()
				local p = WM.findSheriff()
				if p and p.Character then
					flingPlayer(p)
				end
			end,
			order = 7,
			title = "Fling Sheriff Button",
		},
		{
			flag = "show_kill_button",
			id = "Kill",
			settings = { Type = "Text", Text = "Kill All" },
			cb = MachoHub.KillAll,
			order = 9,
			title = "Show Kill Button",
		},
		{
			flag = "show_throw_knife_button",
			id = "ThrowKnife",
			settings = { Type = "Text", Text = "Throw Knife" },
			cb = MachoHub.ExecuteThrowAtNearest,
			order = 10,
			title = "Show Throw Knife Button",
		},
		{
			flag = "show_grab_gun_button",
			id = "GrabGun",
			settings = { Type = "Text", Text = "Grab Gun" },
			cb = MachoHub.GrabGun,
			order = 11,
			title = "Show Grab Gun Button",
		},
		{
			flag = "show_teleport_button",
			id = "Teleport",
			settings = { Type = "Text", Text = "TP Map" },
			cb = MachoHub.TeleportToMap,
			order = 12,
			title = "Show Teleport Map Button",
		},
		{
			flag = "show_teleport_lobby_button",
			id = "TeleportLobby",
			settings = { Type = "Text", Text = "TP Lobby" },
			cb = MachoHub.TeleportToLobby,
			order = 13,
			title = "Show Teleport Lobby Button",
		},
	}
	for _, def in ipairs(mobileDefs) do
		addToggle(pages.Buttons, {
			Order = def.order,
			Title = def.title,
			Flag = def.flag,
			Callback = function(v)
				MachoHub.CreateGuiButton(def.id, {
					Enabled = v,
					Type = def.settings.Type,
					Icon = def.settings.Icon,
					Text = def.settings.Text,
				}, def.cb)
			end,
		})
	end
end

addSection(pages.Teleports, "Players", 1)
do
	local selectedPlayer = nil
	local dropdown = addDropdown(pages.Teleports, {
		Order = 2,
		Title = "Select Player",
		Flag = "TPPlayerSelect",
		Values = {},
		GetValues = function()
			local list = {}
			for _, p in ipairs(Players:GetPlayers()) do
				if p ~= localPlayer then
					table.insert(list, p.Name)
				end
			end
			table.sort(list)
			return list
		end,
		Callback = function(name)
			selectedPlayer = MachoHub.GetPlayerByName(name)
		end,
	})
	local function refreshPlayers()
		local list = {}
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= localPlayer then
				table.insert(list, p.Name)
			end
		end
		table.sort(list)
		dropdown.refresh(list)
		if (not selectedPlayer or not selectedPlayer.Parent) and list[1] then
			selectedPlayer = MachoHub.GetPlayerByName(list[1])
		end
	end
	refreshPlayers()
	Players.PlayerAdded:Connect(refreshPlayers)
	Players.PlayerRemoving:Connect(refreshPlayers)
	task.spawn(function()
		while true do
			task.wait(4)
			refreshPlayers()
		end
	end)
	addButton(pages.Teleports, {
		Order = 3,
		Title = "Teleport to Player",
		Callback = function()
			if selectedPlayer then
				MachoHub.TeleportToPlayer(selectedPlayer)
			end
		end,
	})
end
addSection(pages.Teleports, "Roles", 4)
addButton(pages.Teleports, {
	Order = 5,
	Title = "Teleport to Murderer",
	Callback = function()
		local p = WM.findMurderer()
		if p then
			MachoHub.TeleportToPlayer(p)
		end
	end,
})
addButton(pages.Teleports, {
	Order = 6,
	Title = "Teleport to Sheriff",
	Callback = function()
		local p = WM.findSheriff()
		if p then
			MachoHub.TeleportToPlayer(p)
		end
	end,
})
addSection(pages.Teleports, "Locations", 7)
addButton(pages.Teleports, { Order = 8, Title = "Lobby", Callback = MachoHub.TeleportToLobby })
addButton(pages.Teleports, { Order = 9, Title = "Teleport to Map", Callback = MachoHub.TeleportToMap })
addSection(pages.Misc, "Fling", 1)
do
	local selectedPlayer = nil
	local dropdown = addDropdown(pages.Misc, {
		Order = 2,
		Title = "Select Player",
		Flag = "FlingPlayerSelect",
		Values = {},
		GetValues = function()
			local list = {}
			for _, p in ipairs(Players:GetPlayers()) do
				if p ~= localPlayer then
					table.insert(list, p.Name)
				end
			end
			table.sort(list)
			return list
		end,
		Callback = function(name)
			selectedPlayer = Players:FindFirstChild(name)
		end,
	})
	local function refreshPlayers()
		local list = {}
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= localPlayer then
				table.insert(list, p.Name)
			end
		end
		table.sort(list)
		dropdown.refresh(list)
	end
	refreshPlayers()
	Players.PlayerAdded:Connect(refreshPlayers)
	Players.PlayerRemoving:Connect(refreshPlayers)
	task.spawn(function()
		while true do
			task.wait(4)
			refreshPlayers()
		end
	end)
	addButton(pages.Misc, {
		Order = 3,
		Title = "Fling Player",
		Callback = function()
			if selectedPlayer and selectedPlayer.Character then
				flingPlayer(selectedPlayer)
			end
		end,
	})
end
addButton(pages.Misc, {
	Order = 4,
	Title = "Fling All Players",
	Callback = function()
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= localPlayer and p.Character then
				flingPlayer(p)
			end
		end
	end,
})
addButton(pages.Misc, {
	Order = 5,
	Title = "Fling Murderer",
	Callback = function()
		local p = WM.findMurderer()
		if p and p.Character then
			flingPlayer(p)
		end
	end,
})
addButton(pages.Misc, {
	Order = 6,
	Title = "Fling Sheriff",
	Callback = function()
		local p = WM.findSheriff()
		if p and p.Character then
			flingPlayer(p)
		end
	end,
})
addSection(pages.Misc, "Emotes", 7)
local selectedEmote = "sit"
addDropdown(pages.Misc, {
	Order = 8,
	Title = "Select Emote",
	Flag = "EmoteSelectDropdown",
	Values = { "sit", "zombie", "ninja", "zen", "floss", "dab" },
	Callback = function(v)
		selectedEmote = v
	end,
})
addButton(pages.Misc, {
	Order = 9,
	Title = "Play Emote",
	Callback = function()
		if selectedEmote then
			MachoHub.PlayEmote(selectedEmote)
		end
	end,
})
addSection(pages.Misc, "Chat", 10)
addButton(pages.Misc, { Order = 11, Title = "Expose Roles in Chat", Callback = MachoHub.ChatRoles })
addSection(pages.Background, "Menu & Button Background", 1)
local bgHint = Instance.new("TextLabel", pages.Background)
bgHint.Size = UDim2.new(1, -8, 0, 18)
bgHint.BackgroundTransparency = 1
bgHint.Text = "Tap a preview to set it as menu + button background"
bgHint.TextColor3 = Colors.textMuted
bgHint.Font = Enum.Font.GothamBold
bgHint.TextSize = 11
bgHint.TextXAlignment = Enum.TextXAlignment.Left
bgHint.LayoutOrder = 2

do
	local previews = {}
	local function refreshPreviewUI(active)
		for i, entry in ipairs(previews) do
			if entry.stroke then
				entry.stroke.Color = i == active and getAccent() or Color3.fromRGB(60, 60, 70)
				entry.stroke.Thickness = i == active and 2 or 1
			end
			if entry.badge then
				entry.badge.Visible = i == active
			end
		end
	end
	for i, entry in ipairs(Backgrounds) do
		local imgBtn = Instance.new("ImageButton", pages.Background)
		imgBtn.Size = UDim2.new(1, -8, 0, 130)
		imgBtn.BackgroundColor3 = Color3.fromRGB(12, 12, 16)
		imgBtn.BackgroundTransparency = 0.05
		imgBtn.Image = entry.url or Assets.TIGER
		imgBtn.ImageColor3 = Color3.fromRGB(255, 255, 255)
		imgBtn.ScaleType = Enum.ScaleType.Crop
		imgBtn.BorderSizePixel = 0
		imgBtn.AutoButtonColor = false
		imgBtn.LayoutOrder = 3 + i
		imgBtn.ZIndex = 5
		createUICorner(imgBtn, 12)
		local stroke = createUIStroke(imgBtn, getAccent(), 1.4)
		local footer = Instance.new("Frame", imgBtn)
		footer.Size = UDim2.new(1, 0, 0, 32)
		footer.Position = UDim2.new(0, 0, 1, -32)
		footer.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		footer.BackgroundTransparency = 0.35
		footer.BorderSizePixel = 0
		footer.ZIndex = 7
		createUICorner(footer, 12)
		local nameLabel = Instance.new("TextLabel", imgBtn)
		nameLabel.Size = UDim2.new(1, -90, 0, 22)
		nameLabel.Position = UDim2.new(0, 12, 1, -28)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = entry.name or ("Background " .. i)
		nameLabel.TextColor3 = Color3.fromRGB(240, 240, 245)
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.TextSize = 12
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.ZIndex = 8
		local badge = Instance.new("TextLabel", imgBtn)
		badge.Size = UDim2.new(0, 64, 0, 20)
		badge.Position = UDim2.new(1, -74, 1, -26)
		badge.BackgroundColor3 = getAccent()
		badge.Text = "ACTIVE"
		badge.TextColor3 = Color3.fromRGB(0, 0, 0)
		badge.TextSize = 9
		badge.Font = Enum.Font.GothamBold
		badge.ZIndex = 8
		badge.Visible = UIState.backgroundIndex == i
		createUICorner(badge, 6)
		previews[i] = { stroke = stroke, badge = badge, img = imgBtn }
		task.spawn(function()
			for attempt = 1, 25 do
				local asset = BackgroundCache[i]
				if asset and asset ~= "" then
					imgBtn.Image = asset
					break
				elseif attempt == 3 then
					local resolved = resolveAsset(entry)
					if resolved ~= "" then
						BackgroundCache[i] = resolved
						imgBtn.Image = resolved
						break
					else
						task.wait(0.12)
					end
				else
					task.wait(0.12)
				end
			end
			if imgBtn.Image == "" then
				imgBtn.Image = entry.url
			end
		end)
		imgBtn.MouseButton1Click:Connect(function()
			UIState.applyBackground(i)
			refreshPreviewUI(i)
			pushNotify({ Title = "Background", Content = entry.name, Duration = 3, Color = getAccent() })
		end)
	end
	task.defer(function()
		refreshPreviewUI(UIState.backgroundIndex or 1)
		if UIState.backgroundIndex then
			UIState.applyBackground(UIState.backgroundIndex)
		end
	end)
end

addSection(pages.Background, "Options", 15)
addToggle(pages.Background, {
	Order = 16,
	Title = "Background Enabled",
	Flag = "BgEnabledToggle",
	Value = true,
	Callback = function(v)
		UIState.backgroundEnabled = v
		if UIState.bgImageRef then
			UIState.bgImageRef.Visible = v
		end
		if v then
			UIState.applyBackground(UIState.backgroundIndex)
		else
			inner.BackgroundTransparency = 0
			if UIState.bgGrad then
				UIState.bgGrad.BackgroundTransparency = 0
			end
		end
	end,
})
addButton(pages.Background, {
	Order = 17,
	Title = "Refresh Mobile Button BG",
	Callback = function()
		refreshMobileBackgrounds()
		pushNotify({ Title = "Refreshed", Content = "Mobile buttons updated", Duration = 3 })
	end,
})
addSection(pages.Settings, "Config", 1)
addButton(pages.Settings, {
	Order = 2,
	Title = "Save Config (auto)",
	Callback = function()
		saveConfig()
		pushNotify({ Title = "Success", Content = "Saved to MachoHUB.json", Duration = 4, Color = Colors.success })
	end,
})
addButton(pages.Settings, {
	Order = 3,
	Title = "Load Config",
	Callback = function()
		loadConfig()
		for k, setter in pairs(UIState.setters) do
			if UIState.flags[k] ~= nil then
				pcall(setter, UIState.flags[k], true)
			end
		end
		pushNotify({ Title = "Success", Content = "Configuration loaded!", Duration = 4, Color = Colors.success })
	end,
})
addSection(pages.Settings, "Appearance", 4)
addKeybind(pages.Settings, { Order = 5, Title = "Hide GUI Keybind", Value = "RightControl", Flag = "HideGuiKeybind" })
addSection(pages.Settings, "Server", 6)
addButton(pages.Settings, {
	Order = 7,
	Title = "Rejoin Server",
	Callback = function()
		showDialog({
			Title = "Confirm Rejoin",
			Content = "Are you sure you want to rejoin the server?",
			Buttons = { { Title = "Cancel", Variant = "Secondary" }, { Title = "Rejoin", Callback = MachoHub.Rejoin } },
		})
	end,
})
addButton(pages.Settings, {
	Order = 8,
	Title = "Server Hop",
	Callback = function()
		showDialog({
			Title = "Confirm Server Hop",
			Content = "Are you sure you want to server hop?",
			Buttons = {
				{ Title = "Cancel", Variant = "Secondary" },
				{ Title = "Server Hop", Callback = MachoHub.ServerHop },
			},
		})
	end,
})

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if input.UserInputType ~= Enum.UserInputType.Keyboard then
		return
	end
	if input.KeyCode.Name == (UIState.flags.HideGuiKeybind or "RightControl") then
		if outer.Visible then
			hideMain()
		else
			showMain()
		end
	end
end)

WM.start()
loadConfig()
configReady = true
task.defer(function()
	for k, setter in pairs(UIState.setters) do
		if UIState.flags[k] ~= nil and type(UIState.flags[k]) == "boolean" and UIState.flags[k] then
			pcall(setter, true, true)
		end
	end
	if UIState.backgroundIndex then
		UIState.applyBackground(UIState.backgroundIndex)
	end
	refreshMobileBackgrounds()
	saveConfig()
end)

print("[Macho HUB] Loaded")
return MachoHub
