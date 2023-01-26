-- THIS CLASS SHOULD BE USED FROM THE CLIENT ONLY


-- SERVICES & DEPENDENCIES --
--

local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("ReplicatedStorage")
local GunsRS = RS:WaitForChild("CSX-Guns-ReplicatedStorage")
local Libraries = RS:WaitForChild("CSX-Libraries-ReplicatedStorage")

local Strings = require(Libraries:WaitForChild("Strings"))
local FESpring = require(Libraries:WaitForChild("FESpring"))

-- VARIABLES --
--

local WeaponIconsFolder = GunsRS:WaitForChild("Assets"):WaitForChild("Images"):WaitForChild("WeaponIcons")

local wrappers = {
	Default = script:WaitForChild("DefaultWrapper"),
	Knife = script:WaitForChild("KnifeWrapper")
}
local service = script.Parent

local weapon = {}
weapon.__index = weapon

function weapon.new(weaponInfoTable, player)
	local t = {}

	t.player = player
	t.camera = workspace.CurrentCamera
	t.weaponName = weaponInfoTable.weaponName
	t.equipped = false
	t.equipping = false
	t.firing = false
	t.fireLoop = nil
	t.reloading = false
	t.aiming = false

	t.fireCameraSpring = FESpring.spring.new(Vector3.new())
	t.fireCameraSpring.s = 14
	t.fireCameraSpring.d = 0.8
	t.fireCameraSwitch = false
	t.fireCameraShove = Vector2.zero

	t.xMultiplier = 2.6
	t.yMultiplier = 2
	t.camXMultiplier = 0.9
	t.camYMultiplier = 1
	
	t.weaponType = weaponInfoTable.weaponType
	t.wrapper = wrappers[t.weaponType] or wrappers.Default
	
	t.options = require(weaponInfoTable.optionsScript)
	t.tool = weaponInfoTable.tool
	t.serverModel = weaponInfoTable.serverModel
	t.animationsFolder = weaponInfoTable.animationsFolder
	t.soundsFolder = GunsRS:WaitForChild("Assets"):WaitForChild("Sounds"):WaitForChild("Weapons"):WaitForChild(t.weaponName)
	t.serverScript = t.tool:WaitForChild("WeaponServerScript")
	t.fireEvent = t.serverScript:WaitForChild("FireEvent")

	t.fireRate = t.options.fireRate
	t.currentBullet = 1
	t.currentMovementSpeedReduction = 0
	
	setmetatable(t, weapon)
	t:init()
	return t
end

function weapon:init()
	self.animations = {Local = {}, server = {}}
	for i, v in pairs({"Hold", "Pullout", "Fire", "primaryAttack", "secondaryAttack", "Reload"}) do
		local localAnim = self.animationsFolder:FindFirstChild(v)
		if localAnim then
			self.animations.Local[v] = self.camera:WaitForChild("viewModel").AnimationController:LoadAnimation(localAnim)
		end
		local serverAnim = self.animationsFolder.Server:FindFirstChild(v)
		if serverAnim then
			self.animations.server[v] = self.player.Character:WaitForChild("Humanoid").Animator:LoadAnimation(serverAnim)
		end
	end
	self.connections = {input = {equip = {}, action = {}}, camera = {}, other = {}}
	table.insert(self.connections.input.equip, UIS.InputBegan:Connect(function(i,g) self:equipInputBegan(i,g) end))
	self.connections.camera.update = RunService.RenderStepped:Connect(function(dt) self:cameraUpdate(dt) end)
	self.icons = {}
	local weaponBarMainFrame = self.player.PlayerGui:WaitForChild("HUD"):WaitForChild("WeaponBar"):WaitForChild("MainFrame")
	for i, v in pairs({equipped = "White", unequipped = "Gray"}) do
		local icon = weaponBarMainFrame[Strings.firstToUpper(self.options.inventoryType) .. "WeaponImage"]:Clone()
		icon.Image = WeaponIconsFolder[self.weaponName .. "_" .. v].Image
		icon.Visible = v ~= "White"
		icon.Parent = weaponBarMainFrame
		icon.Name = Strings.firstToUpper(self.options.inventoryType) .. "_Icon"
		self.icons[i] = icon
	end
end

function weapon:connectActionInputs()
	table.insert(self.connections.input.action, UIS.InputBegan:Connect(function(i,g) self:actionInputBegan(i,g) end))
	table.insert(self.connections.input.action, UIS.InputEnded:Connect(function(i,g) self:actionInputEnded(i,g) end))
end

function weapon:disconnectActionInputs()
	for i, v in pairs(self.connections.input.action) do
		v:Disconnect()
	end
	self.connections.input.action = {}
end

function weapon:actionInputBegan(input, gp)
	if gp then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		self:fire(true)
	end
end

function weapon:actionInputEnded(input, gp)
	if gp then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		self:fire(false)
	end
end

function weapon:equipInputBegan(input, gp)
	if gp then return end
	if input.KeyCode == Enum.KeyCode.One then
		if self.options.inventoryType == "primary" then self:toggleEquip() end
	elseif input.KeyCode == Enum.KeyCode.Two then
		if self.options.inventoryType == "secondary" then self:toggleEquip() end
	end
end

local cameraUpdateRate = 1/60

function weapon:cameraUpdate(dt)
	if not self.cameraUpdateAccumulated then self.cameraUpdateAccumulated = dt end
	self.cameraUpdateAccumulated += dt
	while self.cameraUpdateAccumulated >= cameraUpdateRate do
		self.cameraUpdateAccumulated -= cameraUpdateRate
		local spring = self.fireCameraSpring
		print(self.fireCameraSwitch)
		if self.fireCameraSwitch then
			self.fireCameraSwitch = false
			task.spawn(function()
				local oldAccel = Vector2.new(self.fireCameraShove.X * self.xMultiplier * self.camXMultiplier, self.fireCameraShove.Y * self.yMultiplier * self.camYMultiplier)
				local newCamRecAccel = Vector3.new(oldAccel.Y, oldAccel.X, 0)
				--local shakeShove = Vector3.new(camShakeUp(), camShakeSide(), math.random(10, 15) * .1)
				spring:Accelerate(newCamRecAccel)
				--cameraShakeSpring:shove(shakeShove)
				task.wait(0.03)
				spring:Accelerate(-newCamRecAccel)
				--cameraShakeSpring:shove(Vector3.new(-shakeShove.X, -shakeShove.Y, 0))
			end)
		end
		self.camera.CFrame *= CFrame.Angles(spring.p.X, spring.p.Y, spring.p.Z) --* CFrame.Angles(math.rad(udpatedShakeSpring.X), math.rad(udpatedShakeSpring.Y), math.rad(udpatedShakeSpring.Z))
	end
end

-- ACTION FUNCTIONS --
--

function weapon:toggleEquip()
	self.equipped = not self.equipped
	task.spawn(function()
		self:equip(self.equipped)
	end)
end

function weapon:equip(bool)
	if bool then
		(require(self.wrapper).equip or require(wrappers.Default).equip)(self)
		self:connectActionInputs()
	else
		(require(self.wrapper).unequip or require(wrappers.Default).unequip)(self)
		self:disconnectActionInputs()
	end
end

function weapon:fire(bool)
	if bool then
		if not self.options.automatic then -- non automatic weapon fire
			(require(self.wrapper).fire or require(wrappers.Default.Shoot))(self)
			return
		end
		local nextFireTick = tick() -- automatic weapon fire
		self.fireLoop = RunService.RenderStepped:Connect(function()
			if tick() >= nextFireTick then
				(require(self.wrapper).fire or require(wrappers.Default.Shoot))(self)
				nextFireTick = tick() + self.fireRate
			end
		end)
	else
		if self.fireLoop then self.fireLoop:Disconnect() end
	end
end

return weapon