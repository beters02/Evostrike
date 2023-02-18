-- SERVICES & DEPENDENCIES --
--
local P = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Run = game:GetService("RunService")
local Teams = game:GetService("Teams")
local GameRS = RS:WaitForChild("CSX-Game-ReplicatedStorage")
local Gamespace = workspace:WaitForChild("CSX-Game-Workspace")
local Temp = GameRS:WaitForChild("Temp")
local Timer = require(GameRS:WaitForChild("Scripts"):WaitForChild("Modules"):WaitForChild("Timer"))
local Settings = require(script:WaitForChild("Settings"))
local GamemodeEvents = script:WaitForChild("Events")
local WingmanGamemodeData = GameRS:WaitForChild("Temp"):WaitForChild("WingmanGamemodeData")

-- SCRIPT VAR --
--

local globals = {state = "dead", timerTime = 0, players = {}, connections = {death = {}, bomb = {plant = {}, defuse = {}}}, switches = {roundEnd = false}}
local gamemodeVars = {state = "dead", timer = nil, round = 1, teams = {attack = {}, defend = {}}}
local mapVars = {spawns = {attack = {}, defend = {}}}
local events = {BombPlant = GamemodeEvents:WaitForChild("BombPlantEvent"), BombDefuse = GamemodeEvents:WaitForChild("BombDefuseEvent")}

local playerData = {}
local defaultPlayerDataTable = {
	Team = "",
	Money = 800,
	Kills = 0,
	Deaths = 0
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
			end
			newInst.Name = tostring(i)
			newInst.Value = v
		end
	else
		replicatePlayerData(player)
	end
	return playerFolder
end

function replicatePlayerData(player)
	for i, v in pairs(playerData[player.Name]) do
		Temp.WingmanPlayerData[player.Name][i].Value = v
	end
end

-- GAMEMODE FUNCTIONS --
--

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
					-- round over, killer's team wins
				end
			end))
		end
	end)()
end

local function registerRoundBombPlant()
	globals.connections.bomb.plant = events.BombPlant.OnServerEvent:Once(function()
		gamemodeVars.timer = Timer:new(Settings.roundTimeAfterPlant)
		gamemodeVars.timer:start()
		local timerChangedConnection = gamemodeVars.timer.timeChanged:Connect(function() -- global timer change
			globals.timerTime = gamemodeVars.timer.currentTime
		end)
		local timerStoppedConnection = gamemodeVars.timer.stopped:Once(function() -- bomb explode functionality
			timerChangedConnection:Disconnect()
			if globals.connections.bomb.defuse ~= nil then
				globals.connections.bomb.defuse:Disconnect()
			end
		end)
		globals.connections.bomb.defuse = events.BombDefuse.OnServerEvent:Once(function() -- bomb defuse functionality
			timerStoppedConnection:Disconnect()
			timerChangedConnection:Disconnect()
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
	gamemodeVars.timer = Timer:new(Settings.roundTime)
	gamemodeVars.timer:start()
end

local function pregame()
	local ended = false
	globals.state = "Pregame"
	-- init players
	local function initPlayer(player)
		table.insert(globals.players, player)
		playerData[player.Name] = defaultPlayerDataTable
		for i, v in pairs({script.GUIS.HUDAddon, script.GUIS.GamemodeHUD}) do
			v:Clone().Parent = player.PlayerGui
		end
		player:LoadCharacter()
	end
	for i, player in pairs(P:GetPlayers()) do
		initPlayer(player)
	end
	if #globals.players < Settings.requiredPlayerCount then
		P.PlayerAdded:Connect(function(player)
			initPlayer(player)
			if #globals.players >= Settings.requiredPlayerCount then
				ended = true
			end
		end)
	else
		ended = true
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
	local teamAssignPlayers = shuffle(globals.players)
	gamemodeVars.teams.attack[1] = teamAssignPlayers[1]
	playerData[teamAssignPlayers[1].Name].Team = "attack"
	gamemodeVars.teams.attack[2] = teamAssignPlayers[2]
	playerData[teamAssignPlayers[2].Name].Team = "attack"
	gamemodeVars.teams.defend[1] = teamAssignPlayers[3]
	playerData[teamAssignPlayers[3].Name].Team = "defend"
	gamemodeVars.teams.defend[2] = teamAssignPlayers[4]
	playerData[teamAssignPlayers[4].Name].Team = "defend"
	local AttackTeam = Instance.new("Team")
	AttackTeam.TeamColor.Color = Color3.new(1, 0, 0.117647)
	AttackTeam.Parent = Teams
	for i, plr in pairs(gamemodeVars.teams.attack) do
		plr.Team = AttackTeam
	end
	local DefendTeam = Instance.new("Team")
	DefendTeam.TeamColor.Color = Color3.new(0.333333, 0.666667, 1)
	DefendTeam.Parent = Teams
	for i, plr in pairs(gamemodeVars.teams.defend) do
		plr.Team = DefendTeam
	end
	round()
end

-- INITIALIZE GAMEMODE SETTINGS --
--

P.CharacterAutoLoads = false

Run.Heartbeat:Connect(update)

-- GAMEMODE LINEAR SCRIPT START --
--

pregame()
start()