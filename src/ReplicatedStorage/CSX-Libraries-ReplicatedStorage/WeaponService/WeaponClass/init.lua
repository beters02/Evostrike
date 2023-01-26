-- THIS CLASS SHOULD BE USED FROM THE CLIENT ONLY


-- SERVICES & DEPENDENCIES --
--

local UIS = game:GetService("UserInputService")
local RS = game:GetService("ReplicatedStorage")
local GunsRS = RS:WaitForChild("CSX-Guns-ReplicatedStorage")
local Libraries = RS:WaitForChild("CSX-Libraries-ReplicatedStorage")

local Strings = require(Libraries:WaitForChild("Strings"))


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
	t.reloading = false
	t.aiming = false
	t.currentBullet = 1
	t.currentMovementSpeedReduction = 0
	
	t.weaponType = weaponInfoTable.weaponType
	t.wrapper = wrappers[t.weaponType] or wrappers.Default
	
	t.options = require(weaponInfoTable.optionsScript)
	t.tool = weaponInfoTable.tool
	t.serverModel = weaponInfoTable.serverModel
	t.animationsFolder = weaponInfoTable.animationsFolder
	t.serverScript = t.tool:WaitForChild("WeaponServerScript")
	t.fireEvent = t.serverScript:WaitForChild("FireEvent")
	
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
	self.connections = {input = {equip = {}, action = {}}, other = {}}
	table.insert(self.connections.input.equip, UIS.InputBegan:Connect(function(i,g) self:equipInputBegan(i,g) end))
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
	table.insert(self.connections.input.action, UIS.InputBegan:Connect(function(i,g) self:actionInputEnded(i,g) end))
end

function weapon:disconnectActionInputs()
	for i, v in pairs(self.connections.input.action) do
		v:Disconnect()
	end
	self.connections.input.action = {}
end

function weapon:equipInputBegan(input, gp)
	if gp then return end
	if input.KeyCode == Enum.KeyCode.One then
		if self.options.inventoryType == "primary" then self:toggleEquip() end
	elseif input.KeyCode == Enum.KeyCode.Two then
		if self.options.inventoryType == "secondary" then self:toggleEquip() end
	end
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
		(require(self.wrapper).fire or require(wrappers.Default).fire)(self)
	else
		
	end
end

return weapon