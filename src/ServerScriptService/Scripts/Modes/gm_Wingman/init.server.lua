-- SERVICES & DEPENDENCIES --
--
local P = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Teams = game:GetService("Teams")
local GameRS = RS:WaitForChild("CSX-Game-ReplicatedStorage")
local Gamespace = workspace:WaitForChild("CSX-Game-Workspace")
local Timer = require(GameRS:WaitForChild("Scripts"):WaitForChild("Modules"):WaitForChild("Timer"))
local Settings = require(script:WaitForChild("Settings"))

-- SCRIPT VAR --
--

local globals = {state = "dead", timer = 0, players = {}, connections = {death = {}}, switches = {roundEnd = false}}
local gamemodeVars = {state = "dead", round = 1, teams = {attack = {}, defend = {}}}
local mapVars = {spawns = {attack = {}, defend = {}}}

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

-- GAMEMODE FUNCTIONS --
--

local function pregame()
	local ended = false
	globals.state = "Pregame"
	-- init players
	local function initPlayer(player)
		table.insert(globals.players, player)
		playerData[player.Name] = defaultPlayerDataTable
		script.GUIS.HUDAddon:Clone().Parent = player.PlayerGui
		player:LoadCharacter()
	end
	for i, player in pairs(P:GetPlayers()) do
		initPlayer(player)
	end
	if #globals.players < Settings.requiredPlayers then
		P.PlayerAdded:Connect(function(player)
			initPlayer(player)
			if #globals.players >= Settings.requiredPlayers then
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
			table.insert(mapVars.spawns.attack)
		end
	end
	repeat task.wait(1) until ended
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
				playerData[killed.Name].Deaths += 1
				playerData[killer.Name].Kills += 1
				local killerMoneyAdd = Settings.moneyPerKill
				-- for cases in which a player was killed by a knife
				-- we want to reward players for knife kills
				if killed.Character:FindFirstChild("DamageTagData") then
					local req = require(killed.Character.DamageTagData)
					if req.LastShooterWeapon == "Knife" then
						killerMoneyAdd = Settings.moneyPerKnifeKill
					end
				end
				playerData[killer.Name].Money += killerMoneyAdd
				if not checkTeamAlive(playerData[killed.Name].Team) then
					-- round over, killer's team wins
				end
			end))
		end
	end)()
end

local function round(roundNumber) -- to start a round at round 1, call round(). otherwise, you must pass the current round number.
	if not roundNumber then roundNumber = 1 end
	gamemodeVars.round = roundNumber
	gamemodeVars.state = "Round"
	globals.state = "Game"
	teleportPlayersToSpawn()
	setAllPlayersHealth(100)
	registerRoundKills()
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

-- GAMEMODE LINEAR SCRIPT START --
--

pregame()
start()