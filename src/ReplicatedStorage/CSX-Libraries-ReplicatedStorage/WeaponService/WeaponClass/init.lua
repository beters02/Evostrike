-- THIS CLASS SHOULD BE USED FROM THE CLIENT ONLY


-- SERVICES & DEPENDENCIES --
--

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("ReplicatedStorage")
local GunsRS = RS:WaitForChild("CSX-Guns-ReplicatedStorage")
local Libraries = RS:WaitForChild("CSX-Libraries-ReplicatedStorage")
local Profile = require(RS:WaitForChild("CSX-Profile-ReplicatedStorage"):WaitForChild("Scripts"):WaitForChild("Modules"):WaitForChild("Profile"))

local Strings = require(Libraries:WaitForChild("Strings"))
local FESpring = require(Libraries:WaitForChild("FESpring"))

-- VARIABLES --
--

local equippedToolTable = nil
local cameraUpdateRate = 1/60

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
	t.vm = t.camera:WaitForChild("viewModel")
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
	t.nextFireTick = 0

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
	t.reloadEvent = t.serverScript:WaitForChild("ReloadEvent")
	t.customDamageEvent = t.serverScript:WaitForChild("CustomDamageEvent")
	t.destroyEvent = t.serverScript:WaitForChild("DestroyEvent")

	t.fireRate = t.options.fireRate
	t.currentBullet = 1
	t.currentMovementSpeedReduction = 0
	t.aimAlpha = Instance.new("NumberValue", t.tool)
	t.aimAlpha.Name = "AimAlpha"

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
	self.connections.other.destroy = self.destroyEvent.OnClientEvent:Connect(function()
		self:destroy()
		print('yes')
	end)
	local blackScreen = self.player.PlayerGui:WaitForChild("CSX-Guns-StarterGUI"):WaitForChild("ScopeGUI"):WaitForChild("BlackScreen")

	self.aimTweens = {
		FOVIn = TweenService:Create(self.aimAlpha.Value, TweenInfo.new(self.options.scopeRate, Enum.EasingStyle.Circular), {Value = 40}),
		ScopeIn = TweenService:Create(blackScreen, TweenInfo.new(self.options.scopeRate, Enum.EasingStyle.Circular), {ImageTransparency = 1}),
		ScopeOut = TweenService:Create(blackScreen, TweenInfo.new(self.options.scopeRate/2), {ImageTransparency = 0})
	}
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
	elseif input.KeyCode == Enum.KeyCode.R then
		self:reload()
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

function weapon:cameraUpdate(dt)
	if not self.cameraUpdateAccumulated then self.cameraUpdateAccumulated = dt end
	self.cameraUpdateAccumulated += dt
	while self.cameraUpdateAccumulated >= cameraUpdateRate do
		self.cameraUpdateAccumulated -= cameraUpdateRate
		local spring = self.fireCameraSpring
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

function weapon:destroy()
	task.spawn(function()
		for _, tab in pairs(self.animations) do
			for _, animation in pairs(tab) do
				animation:Stop()
			end
		end
		for _, tab in pairs(self.connections) do
			for _, v in pairs(tab) do
				if type(v) == "table" then
					for _, conn in pairs(v) do
						conn:Disconnect()
					end
				else
					v:Disconnect()
				end
			end
		end
		self:disconnectActionInputs()
		for _, icon in pairs(self.icons) do
			icon:Destroy()
		end
		self.clientModel:Destroy()
		self = nil
	end)
end

function weapon:basicSanityCheck()
	if self.reloading then return false end
	if not self.equipped then return false end
	if self.firing then return false end
	return true
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
		if equippedToolTable ~= nil then
			equippedToolTable:equip(false)
		end
		equippedToolTable = self;
		(require(self.wrapper).equip or require(wrappers.Default).equip)(self)
		self:connectActionInputs()
	else
		equippedToolTable = nil;
		(require(self.wrapper).unequip or require(wrappers.Default).unequip)(self)
		self:disconnectActionInputs()
	end
end

function weapon:fire(bool)
	if bool then
		if tick() < self.nextFireTick then task.wait(.05) if tick() < self.nextFireTick then return end end -- if player is on fireRate cooldown
		if not self.equipped then return end
		if self.reloading then return end
		if self.tool:GetAttribute("Magazine") <= 0 then
			self:reload()
			return
		end
		if not self.options.automatic then -- non automatic weapon fire
			self.nextFireTick = tick() + self.fireRate;
			(require(self.wrapper).fire or require(wrappers.Default.Shoot))(self)
			return
		end
		self.nextFireTick = tick() -- automatic weapon fire
		self.firing = true
		self.fireLoop = RunService.RenderStepped:Connect(function()
			if not self.firing then self.fireLoop:Disconnect() return end -- THIS SHIT IS SO FUCKING IMPORTANT DO NOT TOUCH IT
			if self.tool:GetAttribute("Magazine") <= 0 then
				self:reload()
				self.fireLoop:Disconnect()
				return
			end
			if tick() >= self.nextFireTick then
				(require(self.wrapper).fire or require(wrappers.Default.Shoot))(self)
				self.nextFireTick = tick() + self.fireRate
			end
		end)
	else
		self.firing = false -- YOU WILL REGRET EVER BEING BORN IF YOU REMOVE THIS PIECE OF CODE
		if self.fireLoop then self.fireLoop:Disconnect() end
	end
end

function weapon:reload()
	if not self:basicSanityCheck() then return end
	if self.tool:GetAttribute("TotalAmmo") <= 0 then return end
	(require(self.wrapper).reload or require(wrappers.Default).reload)(self)
end

local transparency = require(Libraries.Functions.transparency)

function weapon:scope()
	if not self:basicSanityCheck() then return end
	
	if not self.aiming then
		self.aiming = true
		self.aimTweens.FOVOut = TweenService:Create(self.aimAlpha.Value, TweenInfo.new(self.options.scopeRate/2), {Value = Profile.getPlayerOption(self.player, "fov")})
		self.player.PlayerGui.HUD.Enabled = false

		local fovSensCorrection = 40/require(Profile.getPlayerOption(self.player, "fov")).defaultFOV
		UIS.MouseDeltaSensitivity = UIS.MouseDeltaSensitivity * fovSensCorrection

		local vm = self.vm
		transparency(vm, 1)
		transparency(vm.Equipped[self.weaponName], 1, {["WeaponHandle"] = vm.Equipped[self.weaponName]:WaitForChild("GunComponents").WeaponHandle})

		local scopeGui = self.player.PlayerGui["CSX-Guns-StarterGui"].ScopeGui
		for i, v in pairs({"ScopeImage", "BlackScreen"}) do
			local g = scopeGui[v]
			g.ImageTransparency = 0
			g.Enabled = true
		end

		-- todo: play aim in sound
		self.aimTweens.FOVIn:Play()
		self.aimTweens.ScopeIn:Play()
	
	else
		self.aiming = false
		UIS.MouseDeltaSensitivity = 1
		self.player.PlayerGui.HUD.Enabled = true
		local vm = self.vm
		transparency(vm, 0)
		transparency(vm.Equipped[self.weaponName], 0, {["WeaponHandle"] = vm.Equipped[self.weaponName]:WaitForChild("GunComponents").WeaponHandle})
		local scopeGui = self.player.PlayerGui["CSX-Guns-StarterGui"].ScopeGui
		for i, v in pairs({"ScopeImage", "BlackScreen"}) do
			local g = scopeGui[v]
			g.ImageTransparency = 1
			g.Enabled = false
		end
		self.aimTweens.FOVOut:Play()
		self.aimTweens.ScopeOut:Play()
	end
end

return weapon