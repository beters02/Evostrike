-- SERVICES & DEPENDENCIES --
--

local Run = game:GetService("RunService")

-- VARIABLES --
--

local fireEvent = script:WaitForChild("FireEvent")
local reloadEvent = script:WaitForChild("ReloadEvent")
local customDamageEvent = script:WaitForChild("CustomDamageEvent")
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

local function setRagdollProperties(instance, norm)
	local hitChar = instance:FindFirstAncestorWhichIsA("Model")
	if hitChar and hitChar:FindFirstChild("Humanoid") then
		hitChar:SetAttribute("bulletRagdollNormal", Vector3.new(-norm.X, -norm.Y + -1, -norm.Z))
		hitChar:SetAttribute("lastHitPart", instance.Name)
	end
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

local function calculateReloadAmmo()
	local DefMagSize = weaponOptions.magazineSize
	local need = DefMagSize - CurrentAmmo.Magazine
	if need <= CurrentAmmo.Total then
		CurrentAmmo.Magazine = DefMagSize
		CurrentAmmo.Total -= need
	elseif need > CurrentAmmo.Total then
		CurrentAmmo.Magazine += CurrentAmmo.Total
		CurrentAmmo.Total = 0
	end
	print(CurrentAmmo.Magazine)
	print(CurrentAmmo.Total)
end

local function calculateCustomDamage(player, damage, instance)
	local char, humanoid = isHumanoid(instance)
	if char then
		humanoid:TakeDamage(calculateDamage(instance))
	end
end

Run.Heartbeat:Connect(heartbeat)
fireEvent.OnServerEvent:Connect(function(player, instance, position, normal, material)
	task.spawn(function()
		calculateWeaponFire(player, instance, position, normal, material)
	end)
	task.spawn(function()
		setRagdollProperties(instance, normal)
	end)
end)
reloadEvent.OnServerEvent:Connect(calculateReloadAmmo)
customDamageEvent.OnServerEvent:Connect(calculateCustomDamage)