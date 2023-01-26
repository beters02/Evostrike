local Run = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local GunsRS = RS:WaitForChild("CSX-Guns-ReplicatedStorage")
local Sound = game:GetService("SoundService")

local gameSpace = workspace:WaitForChild("CSX-Game-Workspace")
local Temp = workspace:WaitForChild("CSX-Guns-Workspace"):WaitForChild("Temporary")
local Shields = gameSpace:WaitForChild("Shields")
local ClipBoxes = gameSpace:WaitForChild("ClipBoxes")

local function isHumanoid(instance)
    local model = instance:FindFirstAncestorWhichIsA("Model")
    if model and model:FindFirstChild("Humanoid") then
        return true
    end
    return false
end

local function hitRegistration(self)

    local function damageFromInstance(damage, instance)
        self.customDamageEvent:FireServer(damage, instance)
    end
    
    local camera = workspace.CurrentCamera
    local mouse = self.player:GetMouse()
    local target = Vector2.new(mouse.X, mouse.Y)
    local dec = {self.player.Character, camera, Temp, Shields, ClipBoxes}

    local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Blacklist
	params.FilterDescendantsInstances = dec
	params.CollisionGroup = "bullets"

    local function getResult()
        local unitRay = camera:ScreenPointToRay(mouse.X, mouse.Y)
        return workspace:Raycast(unitRay.Origin, unitRay.Direction * self.options.rayTravelLength, params)
    end

    task.spawn(function()
        for i = 21, 0, -1 do
            if not self.equipped then break end
            if i == 0 then break end
            local result = getResult()
            if result and isHumanoid(result.Instance) then
                damageFromInstance(self.options.baseDamage, result.Instance)
                break
            end
            task.wait(.01)
        end
    end)

end

local module = {}

function module.fire(self)
    hitRegistration(self)
    self.animations.Local.primaryAttack:Play()
end

return module