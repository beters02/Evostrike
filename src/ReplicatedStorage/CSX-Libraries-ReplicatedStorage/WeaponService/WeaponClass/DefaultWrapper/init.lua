-- SERVICES & DEPENDENCIES --
--

local RS = game:GetService("ReplicatedStorage")
local GunsRS = RS:WaitForChild("CSX-Guns-ReplicatedStorage")
local SS = game:GetService("SoundService")

local Libraries = RS["CSX-Libraries-ReplicatedStorage"]
local WeaponService = require(Libraries:WaitForChild("WeaponService"))
local transparency = require(Libraries.Functions.transparency)
local equipBarTween = require(Libraries.Functions.equipWeaponBarTween)
local movementOptions = require(RS["CSX-Movement-ReplicatedStorage"].Scripts.Options.Movement) 

-- VARIABLES --
--

local ConnectM6D = GunsRS:WaitForChild("Events"):WaitForChild("Remote"):WaitForChild("ConnectM6D")

-- FUNCTIONS --
--

local function fireCameraScriptEvent(player, name, args)
	local char = player.Character
	if char then
		char:WaitForChild("CSX-Guns-StarterChar"):WaitForChild("Heartbeat"):WaitForChild("cameraScript"):WaitForChild(name):Fire(args)
	end
end

local function stopCurrentAnimTracks(vm)
	task.spawn(function()
		for i, v in pairs(vm.AnimationController:GetPlayingAnimationTracks()) do
			v:Stop()
		end
	end)
end

local function connectAnimationTrackSoundEvent(animationTrack, sounds)
	return animationTrack:GetMarkerReachedSignal("PlaySound"):Connect(function(SoundName)
		local sound = sounds[SoundName]
		SS:PlayLocalSound(sound)
	end)
end

local function stopPlayerServerAnimations(player)
	local char = player.Character
	if char then
		local hum = char:FindFirstChild("Humanoid")
		if hum then
			for i, v in pairs(hum.Animator:GetPlayingAnimationTracks()) do
				v:Stop()
			end
		end
	end
end

local module = {}

-- WEAPON ACTION FUNCTIONS --
--

function module.equip(self)
	
	local vm = self.camera.viewModel
	vm:WaitForChild("Equipped"):ClearAllChildren() -- clear existing models
	
	self.equipping = true
	task.delay(self.options.pulloutRate, function() -- equipping cooldown
		self.equipping = false
		self.player.Character:SetAttribute("equipping", false)
	end)

	if self.clientModel then self.clientModel:Destroy() end -- create client model
	self.clientModel = self.serverModel:Clone() 
	
	task.spawn(function() -- weapon transparency
		transparency(vm, 1)
		transparency(self.serverModel, 1)
		transparency(self.serverModel.GunComponents.WeaponHandle, 1)
		transparency(self.clientModel, 1)
		self.clientModel.Parent = vm:WaitForChild("Equipped")
		task.wait(.1)
		task.wait(.1)
		local gunComp = self.clientModel:FindFirstChild("GunComponents")
		if gunComp then transparency(self.clientModel, 0, {["WeaponHandle"] = gunComp}) end
		transparency(vm, 0, {["HumanoidRootPart"] = vm.HumanoidRootPart, ["CameraBone"] = vm.CameraBone})
	end)
	
	self.currentMovementSpeedReduction = movementOptions.walkSpeed * (.01 * self.options.weight) --set player walkspeed
	movementOptions.walkSpeed -= self.currentMovementSpeedReduction
	
	self.player.Character["CSX-Guns-StarterChar"].Heartbeat.cameraScript.Equip:Fire() -- animations --
	stopCurrentAnimTracks(vm)
	fireCameraScriptEvent(self.player, "Equip", {})
	
	self.animations.Local.Hold:Play()
	self.animations.Local.Pullout:Play()
	self.animations.server.Hold:Play()
	self.animations.server.Pullout:Play()
	
	SS:PlayLocalSound(GunsRS.Assets.Sounds.Weapons.Equip) -- play default equip sound 
	local soundConnection = connectAnimationTrackSoundEvent(self.animations.Local.Pullout, self.sounds) -- animation sounds

	ConnectM6D:FireServer(self.tool) -- --assign motors Server
	vm.RightArm.RightGrip.Part1 = self.clientModel.GunComponents.WeaponHandle --assign motors Client
	
	local weaponFrame = self.player.PlayerGui:WaitForChild("HUD"):WaitForChild("NewHUDCanvas"):WaitForChild("WeaponFrame") --enable gui
	weaponFrame.EquippedWeapon.Value = self.tool
	weaponFrame.Visible = true
	self.icons.equipped.Visible = true
	self.icons.unequipped.Visible = false
	
	repeat task.wait() until not self.equipping
	if soundConnection.Connected then soundConnection:Disconnect() end
	
end

function module.unequip(self)
	movementOptions.walkSpeed = movementOptions.defaultWalkSpeed --walk speed
	local vm = self.camera.viewModel
	vm.Equipped:ClearAllChildren() --destroy vm model
	
	self.player.Character["CSX-Guns-StarterChar"].Heartbeat.cameraScript.Unequip:Fire()
	stopCurrentAnimTracks(self.camera.viewModel)
	stopPlayerServerAnimations(self.player)

	local weaponFrame = self.player.PlayerGui.HUD.NewHUDCanvas.WeaponFrame --disable gui
	weaponFrame.EquippedWeapon.Value = nil
	weaponFrame.Visible = false
	self.icons.equipped.Visible = false
	self.icons.unequipped.Visible = true
end

return module
