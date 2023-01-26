-- SERVICES & DEPENDENCIES --
--

local Run = game:GetService("RunService")

-- VARIABLES --
--

local fireEvent = script:WaitForChild("FireEvent")
local tool = script:WaitForChild("ToolObject").Value
if not tool then
	repeat task.wait() until script.ToolObject.Value
	tool = script.ToolObject.Value
end
local weaponOptionsObject = script:WaitForChild("WeaponOptionsObject")
local weaponOptions = require(weaponOptionsObject.Value)

local baseDamage = weaponOptions.baseDamage
local headshotMultiplier = weaponOptions.headshotMultiplier

local CurrentAmmo = {
	Magazine = weaponOptions.magazineSize,
	Total = weaponOptions.totalAmmo,
}

local LastCurrentAmmo = {
	Magazine = 0,
	Total = 0,
}

-- FUNCTIONS --
--

local function replicateAmmo()
	if CurrentAmmo.Magazine ~= LastCurrentAmmo.Magazine or CurrentAmmo.Total ~= LastCurrentAmmo.Total then -- replicate ammos to tool attribute
		for i, curr in pairs(CurrentAmmo) do 
			LastCurrentAmmo[i] = curr
			tool:SetAttribute("Magazine", CurrentAmmo.Magazine)
			tool:SetAttribute("TotalAmmo", CurrentAmmo.Total)
		end
	end
end

local function subtractAmmo()
	if CurrentAmmo.Magazine <= 0 then
		return ""
	end
	if CurrentAmmo.Total <= 0 then
		return ""
	end
	CurrentAmmo.Magazine -= 1
	return true
end

local function isHumanoid(instance)
	local parent = instance:FindFirstAncestorWhichIsA("Model")
	if parent and parent:FindFirstChild("Humanoid") then
		return parent, parent.Humanoid
	end
	return false
end

local function calculateDamage(instance)
	local damage = baseDamage
	if string.match(instance.Name, "Head") then
		damage *= headshotMultiplier
	end
	return damage
end

local function heartbeat()
	replicateAmmo()
end

local function calculateWeaponFire(player, instance, position, normal, material)
	local ammosub = subtractAmmo()
	if type(ammosub) == "string" then -- couldn't fire, returned sound to play or something
		return false
	end
	local char, humanoid = isHumanoid(instance)
	if char then
		humanoid:TakeDamage(calculateDamage(instance))
	end
	print(instance)
end

Run.Heartbeat:Connect(heartbeat)
fireEvent.OnServerEvent:Connect(calculateWeaponFire)