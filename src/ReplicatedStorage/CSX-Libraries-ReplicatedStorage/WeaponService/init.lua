-- SERVICES & DEPENDENCIES --
--

local RunService = game:GetService("RunService")
local Tween = game:GetService("TweenService")
local RS = game:GetService("ReplicatedStorage")
local GunsRS = RS:WaitForChild("CSX-Guns-ReplicatedStorage")
local Assets = GunsRS:WaitForChild("Assets")
local Models = Assets:WaitForChild("Models")
local Animations = Assets:WaitForChild("Animations")
local Sounds = Assets:WaitForChild("Sounds")
local Options = GunsRS:WaitForChild("Scripts"):WaitForChild("Options")
local AddWeaponEvent = script:WaitForChild("AddWeapon")

local BulletModel = Models:WaitForChild("Bullet")

local WeaponService = {}

WeaponService.Weapons = { -- weaponNameId = {weaponClassType, isEnabled}
	AK = {false, true},
	M4 = {false, true},
	Glock = {false, true},
	USP = {false, true},
	DesertTech = {false, true},
	Knife = {"Knife", true},
	Deagle = {false, false},
	AWP = {false, false},
}

function WeaponService.VerifyWeapon(weaponName)
	local weaponTable = WeaponService.Weapons[weaponName]
	if weaponTable and weaponTable[2] then
		local t = {
			Models = Models:WaitForChild(weaponName),
			Sounds = Sounds:WaitForChild("Weapons"):WaitForChild(weaponName),
			Animations = Animations:WaitForChild(weaponName),
			Options = Options:WaitForChild("O_" .. weaponName),
			Type = weaponTable[1]
		}
		return t
	else
		print("Invalid weapon " .. weaponName .. "!")
		return false
	end
end

function WeaponService.AddWeapon(weaponName, player)
	if RunService:IsClient() then
		AddWeaponEvent:FireServer(weaponName)
		return
	end
	local weaponFolders = WeaponService.VerifyWeapon(weaponName) -- Models, Sounds, Animations, Options
	if weaponFolders then
		
		local weaponInfoTable = {}
		weaponInfoTable.optionsScript = weaponFolders.Options
		local opdep = require(weaponInfoTable.optionsScript)
		local invType = opdep.inventoryType

		local toolToDestroy = false -- clear current inventory slot
		toolToDestroy = CheckInventoryForWeaponToolInvType(player.Character, invType) or CheckInventoryForWeaponToolInvType(player.Backpack, invType)
		if toolToDestroy then
			WeaponService.RemoveWeapon(false, player, toolToDestroy)
			print('destroying old slot!')
		end
		

		local tool = Instance.new("Tool", player.Backpack)
		tool.Name = "Tool_" .. weaponName
		tool.RequiresHandle = false
		local serverModel = weaponFolders.Models.Default:Clone() -- TODO: get weapon skin
		serverModel.Parent = tool
		serverModel.Name = "Model"
		weaponInfoTable.tool = tool
		weaponInfoTable.serverModel = serverModel
		weaponInfoTable.animationsFolder = weaponFolders.Animations
		weaponInfoTable.weaponName = weaponName
		weaponInfoTable.weaponType = weaponFolders.Type
		AddWeaponEvent:FireClient(player, weaponInfoTable)
		local serverScript = script:WaitForChild("WeaponServerScript"):Clone() -- generate scripts
		serverScript.Enabled = true
		serverScript.Parent = tool
		for i, v in pairs({"Fire", "Reload", "CustomDamage", "Destroy"}) do
			Instance.new("RemoteEvent", serverScript).Name = v .. "Event"
		end
		local toolObject = Instance.new("ObjectValue", serverScript)
		toolObject.Value = tool
		toolObject.Name = "ToolObject"
		local weaponOptionsObject = Instance.new("ObjectValue", serverScript)
		weaponOptionsObject.Name = "WeaponOptionsObject"
		weaponOptionsObject.Value = weaponFolders.Options
		tool:SetAttribute("Magazine", opdep.magazineSize)
		tool:SetAttribute("TotalAmmo", opdep.totalAmmo)
		tool:SetAttribute("WeaponName", weaponName)
		tool:SetAttribute("InventoryType", invType)

		return true
	end
	print("Unable to add weapon " .. weaponName .. "!")
	return false
end

local function isWeaponTool(instance, weaponName)
	if instance:IsA("Tool") then
		local att = instance:GetAttribute("WeaponName")
		if att == weaponName then
			return true
		end
	end
end

local function CheckInventoryForWeaponTool(inventory, weaponName)
	local tool = false
	for i, v in pairs(inventory:GetChildren()) do
		if isWeaponTool(v, weaponName) then
			tool = v
			break
		end
	end
	return tool
end

function CheckInventoryForWeaponToolInvType(inventory, invType)
	local tool = false
	for i, v in pairs(inventory:GetChildren()) do
		if v:IsA("Tool") and v:GetAttribute("InventoryType") == invType then
			tool = v
			break
		end
	end
	return tool
end

function WeaponService.RemoveWeapon(weaponName, player, givenTool)
	local tool = givenTool or CheckInventoryForWeaponTool(player.Backpack, weaponName) or CheckInventoryForWeaponTool(player.Character, weaponName)
	if tool then
		tool.WeaponServerScript.DestroyEvent:FireClient(player)
		task.wait(.1)
		tool:Destroy()
	end
end

function WeaponService.CreateBulletHole(result)
	local normal = result.Normal
	local cFrame = CFrame.new(result.Position, result.Position + normal)
	local bullet_hole = Models:WaitForChild("BulletHole"):Clone()
	bullet_hole.CFrame = cFrame
	bullet_hole.Anchored = false
	bullet_hole.CanCollide = false
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = bullet_hole
	weld.Part1 = result.Instance
	weld.Parent = bullet_hole
	bullet_hole.Parent = result.Instance
	game:GetService("Debris"):AddItem(bullet_hole, 8)
end

function WeaponService.CreateBullet(startPos, endPos)
	local part = BulletModel:Clone() --create bullet part
	part.Parent = workspace:WaitForChild("CSX-Guns-Workspace").Temporary
	part.Size = Vector3.new(0.1, 0.1, 0.4)
	part.Position = startPos
	part.Transparency = 1
	part.CFrame = CFrame.lookAt(startPos, endPos)
	local tude = (startPos - endPos).magnitude --bullet speed
	local tv = tude/900
	local ti = TweenInfo.new(tv) --bullet travel animation tween
	local goal = {Position = endPos}
	--bullet size animation tween
	local sizeti = TweenInfo.new(.05) --time it takes for bullet to grow
	local sizegoal = {Size = Vector3.new(0.1, 0.1, 0.7), Transparency =  0}
	local tween = Tween:Create(part, ti, goal)
	local sizetween = Tween:Create(part, sizeti, sizegoal)
	task.wait(.015) -- wait debug so the bullet is shown starting at the tip of the weapon
	tween:Play() -- play tweens and destroy bullet
	sizetween:Play()
	tween.Completed:Wait()
	part:Destroy()
end

-- CONNECTIONS --
--

local addWeaponEventConn = false

if RunService:IsServer() and not addWeaponEventConn then
	addWeaponEventConn = script:WaitForChild("AddWeapon").OnServerEvent:Connect(function(player, weaponName)
		WeaponService.AddWeapon(weaponName, player)
	end)
end

return WeaponService