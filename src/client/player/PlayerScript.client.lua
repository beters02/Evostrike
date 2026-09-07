-- [[ CONFIGURATION ]]
local HIGHLIGHT_OUTLINE_COLOR = Color3.fromRGB(255, 0, 0)
local HIGHLIGHT_OUTLINE_TRANSPARENCY = 0.3
local HIGHLIGHT_FILL_COLOR = Color3.fromRGB(255, 73, 73)
local HIGHLIGHT_FILL_TRANSPARENCY = 0.4
local DEFAULT_IMPULSE_NORMAL = Vector3.new(math.random(1,10),math.random(1,10),math.random(1,10)).Unit

game.StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Framework = require(ReplicatedStorage.Framework)
local EvoPlayerEvents = Framework.Module.EvoPlayer.Events
local SelfDiedEvent = EvoPlayerEvents:WaitForChild("PlayerDiedBindable")
local PlayerDiedEvent = EvoPlayerEvents:WaitForChild("PlayerDiedRemote")
local BotAddedEvent = Framework.Service.BotService.Remotes.BotAdded
local StoredDamageInfo = require(Framework.Module.EvoPlayer.StoredDamageInformation)
local PlayerAttributes = require(Framework.Module.PlayerAttributes)

local plr = Players.LocalPlayer
local currentStoredDamageInfo = false

local MainMenuModule = require(plr.PlayerScripts:WaitForChild("MainMenu"))
--MainMenuModule:Initialize()

local storedPlayers = {}

local Ragdolls = {
    Stored = {},
    config = {
        ImpulseRandomValues = Vector2.new(130, 200),
        MaxFrictionTorque = 0.3,
        ElbowFrictionTorque = 1,
        KneeFrictionTorque = 1,
        RagdollDecayLength = 6,
    }
}

-- | Main |
function main()
    
    for _, v in pairs(Players:GetPlayers()) do
        playerAdded(v)
    end

    Players.PlayerAdded:Connect(playerAdded)
    Players.PlayerRemoving:Connect(playerRemoving)
    BotAddedEvent.OnClientEvent:Connect(function(botChar, bot)
        Ragdolls.initBot(bot)
    end)

    EvoPlayerEvents.PlayerReceivedDamageRemote.OnClientEvent:Connect(receivedDamage)
    EvoPlayerEvents.PlayerGaveDamageBind.Event:Connect(gaveDamage)
    EvoPlayerEvents.GetPlayerDamageInteractionsBind.OnInvoke = getPlayerDamageInteractions
end

function playerAdded(player)
    if storedPlayers[player.Name] then
        return
    end
    storedPlayers[player.Name] = player
    Ragdolls.initPlayer(player)
    player.CharacterAdded:Connect(characterAdded)
end

function playerRemoving(player)
    Ragdolls.removePlayer(player)
    storedPlayers[player.Name] = nil
end

function characterAdded(char)
    local deadHighlight = Instance.new("Highlight")
    deadHighlight.Enabled = true
    deadHighlight.Parent = char
    deadHighlight.Name = "EnemyHighlight"
    deadHighlight.FillColor = HIGHLIGHT_FILL_COLOR
    deadHighlight.FillTransparency = HIGHLIGHT_FILL_TRANSPARENCY
    deadHighlight.OutlineColor = HIGHLIGHT_OUTLINE_COLOR
    deadHighlight.OutlineTransparency = HIGHLIGHT_OUTLINE_TRANSPARENCY
    deadHighlight.DepthMode = Enum.HighlightDepthMode.Occluded

    if Players:GetPlayerFromCharacter(char) == plr then
        if currentStoredDamageInfo then
            currentStoredDamageInfo:Destroy()
        end
        currentStoredDamageInfo = StoredDamageInfo.new(plr)
    end
end

function receivedDamage(damagerName, damage)
    local damager = Players[damagerName]
    currentStoredDamageInfo:PlayerReceivedDamage(damager, damage)
end

function gaveDamage(damagedName, damage)
    local damaged = Players[damagedName]
    currentStoredDamageInfo:PlayerGaveDamage(damaged, damage)
end

function getPlayerDamageInteractions(player)
    return currentStoredDamageInfo:GetPlayerInteractions(player)
end

-- | Ragdolls |

function Ragdolls.initPlayer(player)
    print('initting ' .. player.Name)
    if not Ragdolls.Stored[player.Name] then
        local ragdollData = {Player = player, Connections = {}, CharacterAlive = false}
        ragdollData.Connections.CharacterAdded = player.CharacterAdded:Connect(function(char)
            print('Character Added ' .. player.Name)
            Ragdolls.characterAdded(player, char)
        end)
        Ragdolls.Stored[player.Name] = ragdollData
    end

    if player.Character and not Ragdolls.Stored[player.Name].CharacterAlive then
        Ragdolls.characterAdded(player, player.Character)
    end
end

function Ragdolls.initBot(bot)
    if not Ragdolls.Stored[bot.Name] then
        local ragdollData = {Player = bot, Connections = {}, CharacterAlive = false}
        Ragdolls.Stored[bot.Name] = ragdollData
    end

    Ragdolls.botCharacterAdded(bot)
end

function Ragdolls.getPlayer(player)
    return Ragdolls.Stored[player.Name]
end

function Ragdolls.removePlayer(player)
    if Ragdolls.Stored[player.Name] then
        for _, v in pairs(Ragdolls.Stored[player.Name].Connections) do
            v:Disconnect()
        end
        for _, v in pairs(CollectionService:GetTagged("Ragdolls_DestroyOnRemove_" .. player.Name)) do
            v:Destroy()
        end
        Ragdolls.Stored[player.Name] = nil
    end
end

function Ragdolls.characterAdded(player, char)
    Ragdolls.initCharacterSpawn(char)

    local clone = Ragdolls.createRagdoll(char)
    local ragdollData = Ragdolls.getPlayer(player)

    if player == game.Players.LocalPlayer then
        ragdollData.Connections.Died = SelfDiedEvent.Event:Once(function()
            Ragdolls.characterDied(player, char, clone)
        end)
    else
        ragdollData.Connections.Died = PlayerDiedEvent.OnClientEvent:Connect(function(diedPlr)
            if diedPlr == player then
                Ragdolls.characterDied(player, char, clone)
                ragdollData.Connections.Died:Disconnect()
            end
        end)
    end

    ragdollData.CharacterAlive = true
    Ragdolls.Stored[player.Name] = ragdollData
end

function Ragdolls.botCharacterAdded(bot)
    Ragdolls.initCharacterSpawn(bot.Character)

    local clone = Ragdolls.createRagdoll(bot.Character)
    local ragdollData = Ragdolls.getPlayer(bot)

    ragdollData.Connections.Died = PlayerDiedEvent.OnClientEvent:Connect(function(diedChar)
        if diedChar == bot.Character then
            Ragdolls.characterDied(bot, bot.Character, clone)
            ragdollData.Connections.Died:Disconnect()
        end
    end)
end

function Ragdolls.characterDied(player, character, ragdollClone)
    Ragdolls.ragdollCharacter(character, ragdollClone)
    Ragdolls.Stored[player.Name].CharacterAlive = false
    pcall(function()
        character.EnemyHighlight.Parent = ragdollClone
    end)
end

function Ragdolls.initCharacterSpawn(char)
    for _, v in pairs(char:GetDescendants()) do
        if v.Name == "HumanoidRootPart" then
            v.Anchored = false
            v.CollisionGroup = "Players"
            continue
        elseif v:IsA("Texture") then
            v.Transparency = 0
            continue
        elseif not v:IsA("Part") and not v:IsA("MeshPart") and not v:IsA("BasePart") then
            continue
        end

        v.Transparency = 0
        v.Anchored = false
        v.CollisionGroup = "Players"
        if v.Name == "LeftFoot" or v.Name == "RightFoot" then
            v.CollisionGroup = "PlayerFeet"
        end
    end
end

function Ragdolls.initCharacterDead(char)
    for _, v in pairs(char:GetDescendants()) do
        if v.Name == "HumanoidRootPart" then
            v.Anchored = true
            v.CollisionGroup = "DeadCharacters"
            v.CanCollide = true
            continue
        elseif v:IsA("Texture") then
            v.Transparency = 1
            continue
        elseif not v:IsA("Part") and not v:IsA("MeshPart") and not v:IsA("BasePart") then
            continue
        end

        v.Transparency = 1
        v.Anchored = true
        v.CollisionGroup = "DeadCharacters"
        v.CanCollide = true
    end
end

function Ragdolls.createRagdoll(char)
    local ragdollValue = char:FindFirstChild("RagdollValue")
    if ragdollValue and ragdollValue.Value then
        ragdollValue.Value:Destroy()
        ragdollValue:Destroy()
    end

    local clone = game:GetService("StarterPlayer").StarterCharacter:Clone()
    clone.Parent = ReplicatedStorage:WaitForChild("temp")
    task.wait()

    ragdollValue = Instance.new("ObjectValue")
    ragdollValue.Name = "RagdollValue"
    ragdollValue.Value = clone
    ragdollValue.Parent = char
    CollectionService:AddTag(clone, "Ragdolls_DestroyOnRemove_" .. char.Name)
    CollectionService:AddTag(ragdollValue, "Ragdolls_DestroyOnRemove_" .. char.Name)
    char:SetAttribute("HasRagdoll", true)

    -- prepare ragdoll CanCollide & constraints
    for _, v in pairs(clone:GetDescendants()) do
        if v:IsA("Motor6D") then
            if not string.match(v.Name, "Ankle") and not string.match(v.Name, "Wrist") then
                local part0 = v.Part0
                local joint_name = v.Name
                local attachment0 = v.Parent:FindFirstChild(joint_name.."Attachment") or v.Parent:FindFirstChild(joint_name.."RigAttachment")
                local attachment1 = part0:FindFirstChild(joint_name.."Attachment") or part0:FindFirstChild(joint_name.."RigAttachment")
                if attachment0 and attachment1 then
                    local socket = Instance.new("BallSocketConstraint", v.Parent)
                    socket.LimitsEnabled = true
                    socket.TwistLimitsEnabled = true
                    socket.MaxFrictionTorque = (joint_name == "Knee" and Ragdolls.config.KneeFrictionTorque) or (joint_name == "Elbow" and Ragdolls.config.ElbowFrictionTorque) or Ragdolls.config.MaxFrictionTorque
                    socket.Attachment0, socket.Attachment1 = attachment0, attachment1
                    v:Destroy()
                end
            end
        elseif v:IsA("Part") or v:IsA("MeshPart") then
            v.CanCollide = true
            v.CollisionGroup = "Ragdolls"
        end
    end

    return clone
end

function Ragdolls.ragdollCharacter(character, ragdollClone)
    pcall(function()
        character.PrimaryPart.Anchored = true
        character.Head.Anchored = true
    end)

    Ragdolls.initCharacterDead(character)

    local charHum = ragdollClone:WaitForChild("Humanoid")
    ragdollClone.PrimaryPart = ragdollClone:WaitForChild("UpperTorso")
    charHum:Destroy()
    ragdollClone.HumanoidRootPart:Destroy()

    -- replace char with ragdoll
    character.PrimaryPart.Anchored = true
    ragdollClone:SetPrimaryPartCFrame(character.PrimaryPart.CFrame)
    Ragdolls.transparency(character, 1)
    ragdollClone.Parent = character.Parent
    ragdollClone.PrimaryPart.Velocity = character.PrimaryPart.Velocity
    character:SetPrimaryPartCFrame(ragdollClone.PrimaryPart.CFrame + Vector3.new(0,2,0))
    
    -- impulse ragdoll
    Ragdolls.impulse(character, ragdollClone)
    game:GetService("Debris"):AddItem(ragdollClone, Ragdolls.config.RagdollDecayLength)
end

function getCharAttribute(character, attribute)
    local player = Players:GetPlayerFromCharacter(character) or {Name = "BOT_" .. character.Name}
    return PlayerAttributes:GetCharacterAttribute(player, attribute)
end

function Ragdolls.impulse(character, ragdollClone)

    local bulletRagdollNorm = -(getCharAttribute(character, "bulletRagdollKillDir") or DEFAULT_IMPULSE_NORMAL)
    local impulseModifier = getCharAttribute(character, "impulseModifier") or 1

    if bulletRagdollNorm then
        local bulletRagdollPart
        local bulletRagdollPartName = getCharAttribute(character, "lastHitPart") --character:GetAttribute("lastHitPart")

        if not bulletRagdollPartName then bulletRagdollPart = ragdollClone.Head else
            bulletRagdollPart = ragdollClone:FindFirstChild(bulletRagdollPartName)
            if not bulletRagdollPart then bulletRagdollPart = ragdollClone.Head end
        end

        local randomVec3 = Vector3.one * impulseModifier
        local impulseAmount = (Vector3.new(bulletRagdollNorm.X * randomVec3.X, 0, bulletRagdollNorm.Z * randomVec3.Z) * math.random(Ragdolls.config.ImpulseRandomValues.X, Ragdolls.config.ImpulseRandomValues.Y))
        bulletRagdollPart:ApplyImpulse(impulseAmount)
    end
end

function Ragdolls.transparency(character, t)
    for _, v in pairs(character:GetDescendants()) do
        if v.Name ~= "HumanoidRootPart" and (v:IsA("Part") or v:IsA("MeshPart") or v:IsA("Texture")) then
            v.Transparency = t
        end
    end
end

-- | TorsoToMouse |

-- | Abilities |

local AbilityService = Framework.Service.AbilityService
local Ability = require(AbilityService:WaitForChild("Ability"))
local FastCast = require(Framework.Module.lib.c_fastcast)
local Conns = require(Framework.Module.lib.fc_rbxsignals)

local player = Players.LocalPlayer

local PlayerData = {}
local GrenadeAbilityModules = {}
local StoredAbilityClasses = {}
local AbilityRequiredModules = {}
for _, module in pairs(AbilityService.Ability:GetChildren()) do
    local _name = string.lower(module.Name)
    AbilityRequiredModules[_name] = require(module)
    if AbilityRequiredModules[_name].Options and AbilityRequiredModules[_name].Options.isGrenade then
        GrenadeAbilityModules[_name] = module
    end
end

local function InitPlayer(iplayer)
    if not PlayerData[iplayer.Name] then
        PlayerData[iplayer.Name] = {
            Conn = iplayer.CharacterAdded:Connect(function()
                InitCharacter(iplayer)
            end)
        }
        if iplayer.Character then
            InitCharacter(iplayer)
        end
    end
end

local function RemovePlayer(iplayer)
    if PlayerData[iplayer.Name] then
        Conns.DisconnectAllIn(PlayerData[iplayer.Name])
    end
    PlayerData[iplayer.Name] = nil
    RemoveCharacter(iplayer)
end

function InitCaster(_Ability, module)
    local caster = FastCast.new()
    caster.SimulateBeforePhysics = true
    local castBeh = FastCast.newBehavior()

    castBeh.Acceleration = Vector3.new(0, -workspace.Gravity * _Ability.Options.gravityModifier, 0)
    castBeh.AutoIgnoreContainer = false
    castBeh.CosmeticBulletContainer = workspace.Temp
    castBeh.CosmeticBulletTemplate = module:WaitForChild("Assets").Models.Grenade
    caster.RayHit:Connect(function(...)
        _Ability:RayHitCore(...)
    end)
    caster.LengthChanged:Connect(function(...)
        _Ability:LengthChanged(...)
    end)
    caster.CastTerminating:Connect(function(...)
        _Ability.CastTerminating(...)
    end)

    _Ability.Caster = caster
    _Ability.CastBehavior = castBeh
end

function InitCharacter(cplayer)
    RemoveCharacter(cplayer)
    StoredAbilityClasses[cplayer.Name] = {}
    for name, v in pairs(GrenadeAbilityModules) do
        StoredAbilityClasses[cplayer.Name][string.lower(name)] = Ability.new(cplayer, v, true)
        InitCaster(StoredAbilityClasses[cplayer.Name][string.lower(name)], v)
    end
end

function RemoveCharacter(cplayer)
    if StoredAbilityClasses[cplayer.Name] then
        StoredAbilityClasses[cplayer.Name] = nil
    end
end

Framework.Module.EvoPlayer.Events.PlayerDiedBindable.Event:Connect(function()
    RemoveCharacter(player.Character or player)
end)

Framework.Module.EvoPlayer.Events.PlayerDiedRemote.OnClientEvent:Connect(function(died)
    if died == player then return end
    local char = died:FindFirstChild("Character") or died
    RemoveCharacter(char)
end)

AbilityService.Events.RemoteFunction.OnClientInvoke = function(action, ...)
    if action == "LongFlashCanSee" then
        local part = ...
        return AbilityRequiredModules.longflash.CanSee(part)
    end
end

AbilityService.Events.RemoteEvent.OnClientEvent:Connect(function(action, ...)
    if action == "GrenadeFire" then
        local args = table.pack(...)
        local ability, owner = args[1], args[2]
        table.remove(args, 1)
        table.remove(args, 1)
        local success, result = pcall(function()
            StoredAbilityClasses[owner.Name][string.lower(ability)]:FireGrenade(table.unpack(args))
        end)
        if not success then
            warn("Did not replicate Grenade Fire. " .. tostring(result))
        end
    end
end)

InitPlayer(player)
for _, plr in pairs(Players:GetPlayers()) do
    InitPlayer(plr)
end
Players.PlayerAdded:Connect(InitPlayer)
Players.PlayerRemoving:Connect(RemovePlayer)

-- | Script Start |
main()