-- SERVICES & DEPENDENCIES --
--
local P = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Run = game:GetService("RunService")
local Teams = game:GetService("Teams")
local GameRS = RS:WaitForChild("CSX-Game-ReplicatedStorage")
local GunsRS = RS:WaitForChild("CSX-Guns-ReplicatedStorage")
local Libraries = RS:WaitForChild("CSX-Libraries-ReplicatedStorage")
local Gamespace = workspace:WaitForChild("CSX-Game-Workspace")
local Temp = GameRS:WaitForChild("Temp")
local Timer = require(GameRS:WaitForChild("Scripts"):WaitForChild("Modules"):WaitForChild("Timer"))
local Settings = require(script:WaitForChild("Settings"))
local GamemodeEvents = GameRS:WaitForChild("Events"):WaitForChild("Wingman")
local WingmanGamemodeData = GameRS:WaitForChild("Temp"):WaitForChild("WingmanGamemodeData")
local Strings = require(Libraries:WaitForChild("Strings"))
local GameSounds = GameRS:WaitForChild("Assets"):WaitForChild("Sounds")
local collision = require(Libraries:WaitForChild("Functions"):WaitForChild("collision"))
local weaponClass = require(GunsRS.Scripts.Modules.Weapon)

local BarriersFolder = script:WaitForChild("Barriers")
local ObjectsFolder = script:WaitForChild("Objects")
local TeamObjectsFolder = ObjectsFolder:WaitForChild("Teams")
local BombFolder = ObjectsFolder:WaitForChild("Bomb")
local BombModel = BombFolder:WaitForChild("Bomb")
local DefaultAttackTeam = TeamObjectsFolder:WaitForChild("Attacker")
local DefaultDefendTeam = TeamObjectsFolder:WaitForChild("Defender")
local abilityUseEvent = GamemodeEvents:WaitForChild("AbilityUseEvent")
local playSoundLocal = GunsRS:WaitForChild("Events"):WaitForChild("Remote"):WaitForChild("playSoundLocal")

-- SCRIPT VAR --
--

local globals = {state = "dead", timerTime = 0, timerLabel = "", players = {}, connections = {death = {}, bomb = {plant = {}, defuse = {}}, timerChanged = nil}, switches = {roundEnd = false}}
local gamemodeVars = {state = "dead", timer = nil, round = 1, teams = {attack = {}, defend = {}}, score = {attack = 0, defend = 0}}
local mapVars = {spawns = {attack = {}, defend = {}, bomb = Gamespace:WaitForChild("Spawns"):WaitForChild("BombSpawn")}, currentBomb = nil, currentBarriers = nil}
local events = {BombPlant = GamemodeEvents:WaitForChild("BombPlantEvent"), BombDefuse = GamemodeEvents:WaitForChild("BombDefuseEvent"), BuyMenuRemote = GamemodeEvents:WaitForChild("BuyMenu"), GetMoneyAmount = GamemodeEvents:WaitForChild("GetMoneyAmount"), GetGamemodePlayerData = GamemodeEvents:WaitForChild("GetGamemodePlayerData"), SetGamemodePlayerData = GamemodeEvents:WaitForChild("SetGamemodePlayerData")}
local data = {replicated = nil}
local sounds = {BombPlanted = GameSounds:WaitForChild("bombPlanted"), BombDefused = GameSounds:WaitForChild("bombDefused")}

local playerData = {}
local defaultPlayerDataTable = {
	Team = "",
	Money = 800,
	Kills = 0,
	Deaths = 0,
	Inventory = {Primary = nil, Secondary = nil, MovementAbility = nil, UtilityAbility = nil}
}

-- SCRIPT FUNCTIONS --
--

function shuffle(x)
	local shuffled = {}
	for i, v in ipairs(x) do
		local pos = math.random(1, #shuffled+1)
		table.insert(shuffled, pos, v)
	end
	return shuffled
end

function update()
	if WingmanGamemodeData.CurrentRound.Value ~= gamemodeVars.round then
		WingmanGamemodeData.CurrentRound.Value = gamemodeVars.round
	end
	if WingmanGamemodeData.TotalRounds.Value ~= Settings.halftimeRound * 2 then
		WingmanGamemodeData.TotalRounds.Value = Settings.halftimeRound * 2
	end
	if WingmanGamemodeData.TimerValue.Value ~= globals.timerTime then
		WingmanGamemodeData.TimerValue.Value = globals.timerTime
	end
end

-- PLAYER DATA FUNCTIONS --
--

function playerDataIncrement(player, dataKey, amnt)
	playerData[player.Name][dataKey] += amnt
	local tempFolder = Temp.WingmanPlayerData:FindFirstChild(player.Name)
	if tempFolder then tempFolder[dataKey].Value = playerData[player.Name][dataKey] end
end

function downloadPlayerData(player)
	local playerFolder = Temp.WingmanPlayerData:FindFirstChild(player.Name)
	if not playerFolder then
		playerFolder = Instance.new("Folder", Temp.WingmanPlayerData)
		playerFolder.Name = player.Name
		for i, v in pairs(playerData[player.Name]) do
			local newInst
			if type(v) == "string" then
				newInst = Instance.new("StringValue")
			elseif type(v) == "number" then
				newInst = Instance.new("NumberValue")
			else continue end
			newInst.Name = tostring(i)
			newInst.Value = v
			newInst.Parent = playerFolder
		end
	else
		replicatePlayerData(player)
	end
	return playerFolder
end

function replicatePlayerData(player)
	for i, v in pairs(playerData[player.Name]) do
		if tostring(i) == "Inventory" then continue end
		Temp.WingmanPlayerData[player.Name][i].Value = v
	end
end

function getMoneyAmount(player)
	return playerData[player.Name].Money
end

function getGamemodePlayerData(player)
	return playerData[player.Name]
end

function setGamemodePlayerData(player, newData)
	playerData[player.Name] = newData
	replicatePlayerData(player)
end

function useAbility(player, abilityName)
	local abilityKey
	for i, v in pairs(playerData[player.Name].Inventory) do
		if v.AbilityName == abilityName then
			abilityKey = v
			break
		end
	end
	abilityKey.Amount -= 1
end

-- GAMEMODE DATA FUNCTIONS --
--

function incrementGamemodeData(dataKey, amnt)
	local tableKey = dataKey == "AttackScore" and "attack" or dataKey == "DefendScore" and "defend" or "CurrentRound" and "round"
	gamemodeVars[tableKey] += amnt
	WingmanGamemodeData[dataKey].Value += amnt
end

function setGamemodeData(dataKey, new)
	local tableKey = (dataKey == "AttackScore" and "attack") or (dataKey == "DefendScore" and "defend") or (dataKey == "CurrentRound" and "round")
	if tableKey then
		gamemodeVars[tableKey] = new
		WingmanGamemodeData[dataKey].Value = new
	else
		tableKey = (dataKey == "TimerValue" and "timerTime") or (dataKey == "TimerLabelValue" and "timerLabel")
		if not tableKey then return end
		globals[tableKey] = new
		WingmanGamemodeData[dataKey].Value = new
	end
end

-- GAMEMODE FUNCTIONS --
--

function checkTeamAlive(teamName)
	if gamemodeVars.teams[teamName][1].Character.Humanoid.Health <= 0 and gamemodeVars.teams[teamName][2].Character.Humanoid.Health <= 0 then return true end
	return false
end

function loadAllCharacters()
	for i, plr in pairs(globals.players) do
		if not plr.Character then plr:LoadCharacter() end
	end
end

function randomizeTeamSpawns()
	local newSpawns = {attack = {}, defend = {}}
	newSpawns.attack = shuffle(mapVars.spawns.attack)
	newSpawns.defend = shuffle(mapVars.spawns.defend)
	return newSpawns
end

function teleportPlayersToSpawn()
	loadAllCharacters()
	local spawns = randomizeTeamSpawns()
	gamemodeVars.teams.attack[1].Character.PrimaryPart.CFrame = spawns.attack[1].CFrame
	gamemodeVars.teams.attack[2].Character.PrimaryPart.CFrame = spawns.attack[2].CFrame
	gamemodeVars.teams.defend[1].Character.PrimaryPart.CFrame = spawns.defend[1].CFrame
	gamemodeVars.teams.defend[2].Character.PrimaryPart.CFrame = spawns.defend[2].CFrame
end

function setAllPlayersHealth(health)
	for i, plr in pairs(globals.players) do
		plr.Character.Humanoid.Health = health
	end
end

function startNewRoundTimer(length, label)
	setGamemodeData("TimerLabelValue", label or "")
	gamemodeVars.timer = Timer:new(length)
	gamemodeVars.timer:start()
	if globals.connections.timerChanged ~= nil then
		globals.connections.timerChanged:Disconnect()
	end
	globals.connections.timerChanged = gamemodeVars.timer.timeChanged.Event:Connect(function()
		setGamemodeData("TimerValue", gamemodeVars.timer.time)
	end)
end

local function roundOverTeamWon(team)
	incrementGamemodeData(Strings.firstToUpper(team) .. "Score", 1)
	incrementGamemodeData("CurrentRound", 1)
end

local function spawnBomb(atOrigin)
	mapVars.currentBomb = BombModel:Clone()
	collision(mapVars.currentBomb, true)
	mapVars.currentBomb.Parent = Gamespace:WaitForChild("Map")
	if not atOrigin then
		mapVars.currentBomb.PrimaryPart.CFrame = mapVars.spawns.bomb.CFrame
	end
end

local function spawnBarriers()
	mapVars.currentBarriers = BarriersFolder:Clone()
	mapVars.currentBarriers.Parent = Gamespace
end

local function destroyBarriers()
	mapVars.currentBarriers:Destroy()
	mapVars.currentBarriers = nil
end

local function registerRoundKills()
	coroutine.wrap(function()
		for i, plr in pairs(globals.players) do
			table.insert(globals.connections.death, plr.Character.Humanoid.Died:Connect(function()
				local killed = plr
				local killer = killed.Character:FindFirstChild("DamageTag") and killed.Character.DamageTag.Value
				-- for cases in which the damage tag has not been created
				if not killer then
					print("Killer for player " .. killed.Name .. " not found! Selecting random player from opposite team.")
					for _, team in pairs(Teams:GetTeams()) do
						if team ~= killed.Team then
							for _, plrInTeam in pairs(team:GetPlayers()) do
								killer = plrInTeam
							end
						end
					end
				end
				playerDataIncrement(killed, "Deaths", 1)
				playerDataIncrement(killer, "Kills", 1)
				local killerMoneyAdd = Settings.moneyPerKill
				-- for cases in which a player was killed by a knife
				-- we want to reward players for knife kills
				if killed.Character:FindFirstChild("DamageTagData") then
					local req = require(killed.Character.DamageTagData)
					if req.LastShooterWeapon == "Knife" then
						killerMoneyAdd = Settings.moneyPerKnifeKill
					end
				end
				playerDataIncrement(killer, "Money", killerMoneyAdd)
				if not checkTeamAlive(playerData[killed.Name].Team) then
					roundOverTeamWon(playerData[killer.Name].Team) -- round over, killer's team wins
				end
			end))
		end
	end)()
end

local function registerRoundBombPlant()
	globals.connections.bomb.plant = events.BombPlant.Event:Once(function()
		startNewRoundTimer(Settings.roundTimeAfterPlant)
		playSoundLocal:FireAllClients(sounds.BombPlanted, false)
		local timerStoppedConnection = gamemodeVars.timer.stopped.Event:Once(function() -- bomb explode functionality
			if globals.connections.bomb.defuse ~= nil then
				globals.connections.bomb.defuse:Disconnect()
				roundOverTeamWon("attack")
			end
		end)
		globals.connections.bomb.defuse = events.BombDefuse.Event:Once(function() -- bomb defuse functionality
			timerStoppedConnection:Disconnect()
			roundOverTeamWon("defend")
		end)
	end)
end

local function round(roundNumber) -- to start a round at round 1, call round(). otherwise, you must pass the current round number.
	if not roundNumber then roundNumber = 1 end
	gamemodeVars.round = roundNumber
	gamemodeVars.state = "Round"
	globals.state = "Game"
	teleportPlayersToSpawn()
	setAllPlayersHealth(100)
	registerRoundKills()
	registerRoundBombPlant()
	startNewRoundTimer(10, "In Buy Menu")
	spawnBarriers()
	gamemodeVars.timer.stopped:Once(function()
		destroyBarriers()
		startNewRoundTimer(Settings.roundTime, "In Game")
	end)
end

local function initPlayer(player)
	table.insert(globals.players, player)
	playerData[player.Name] = defaultPlayerDataTable
	for i, v in pairs({script.GUIS.HUDAddon, script.GUIS.GamemodeHUD, script.GUIS.BuyMenu}) do
		v:Clone().Parent = player.PlayerGui
	end
	downloadPlayerData(player)
	player:LoadCharacter()
end

local function initTeams()
	local teamAssignPlayers = shuffle(globals.players)
	local attackTeamObject = DefaultAttackTeam:Clone()
	local defendTeamObject = DefaultDefendTeam:Clone()
	for i = 1, #teamAssignPlayers do
		local teamIndex = i
		local team, teamName, teamObject = gamemodeVars.teams.attack, "attack", attackTeamObject
		if i > 2 then
			teamIndex-=2
			team, teamName, teamObject = gamemodeVars.teams.defend, "defend", defendTeamObject
		end
		playerData[teamAssignPlayers[i].Name].Team = teamName
		team[teamIndex] = teamAssignPlayers[i]
		teamAssignPlayers[i].Team = teamObject
	end
	attackTeamObject.Parent = Teams
	defendTeamObject.Parent = Teams
end

local function pregame()
	local ended = true
	local playerAddedConnection = nil
	globals.state = "Pregame"
	-- init players
	for i, player in pairs(P:GetPlayers()) do
		initPlayer(player)
	end
	if #globals.players < Settings.requiredPlayerCount then
		ended = false
		playerAddedConnection = P.PlayerAdded:Connect(function(player)
			initPlayer(player)
			if #globals.players >= Settings.requiredPlayerCount then
				ended = true
				if playerAddedConnection then playerAddedConnection:Disconnect() end
			end
		end)
	end
	-- load assets
	for i, v in pairs(Gamespace:WaitForChild("Spawns"):GetChildren()) do
		if v.Name == "DefendSpawn" then
			table.insert(mapVars.spawns.defend, v)
		elseif v.Name == "AttackSpawn" then
			table.insert(mapVars.spawns.attack, v)
		end
	end
	repeat task.wait(1) until ended
end

local function start()
	initTeams()
	round()
end

-- INITIALIZE GAMEMODE SETTINGS & CONNECT CONNECTIONS --
--

P.CharacterAutoLoads = false
Run.Heartbeat:Connect(update)
events.GetMoneyAmount.OnServerInvoke = getMoneyAmount
events.GetGamemodePlayerData.OnInvoke = getGamemodePlayerData
events.SetGamemodePlayerData.Event:Connect(setGamemodePlayerData)
abilityUseEvent.OnServerEvent:Connect(useAbility)

-- GAMEMODE LINEAR SCRIPT START --
--

pregame()
--start()

startNewRoundTimer(60, "Test")
spawnBomb(true)
registerRoundBombPlant()