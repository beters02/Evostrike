local P = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Sound = game:GetService("SoundService")
local Run = game:GetService("RunService")
local GameSpace = workspace:WaitForChild("CSX-Game-Workspace")
local MovementSettings = require(RS:WaitForChild("CSX-Movement-ReplicatedStorage"):WaitForChild("Scripts"):WaitForChild("Options"):WaitForChild("Movement"))
local WeaponService = require(RS:WaitForChild("CSX-Libraries-ReplicatedStorage"):WaitForChild("WeaponService"))
local GunsRS = RS:WaitForChild("CSX-Guns-ReplicatedStorage")

local GunSounds = GunsRS:WaitForChild("Assets"):WaitForChild("Sounds")
local HitSounds = {LocalHeadshot = GunSounds:WaitForChild("LocalHeadshot"), LocalBodyshot = GunSounds:WaitForChild("LocalBodyshot")}

local player = P.LocalPlayer
local camera = workspace.CurrentCamera

local curshots = 0
local curVec2 = Vector2.zero
local lastClickTick = tick()
local lastShovVec2 = Vector2.zero
local curShovVec2 = Vector2.zero

local Temp = GameSpace:WaitForChild("Temporary")
local Shields = GameSpace:WaitForChild("Shields")
local Spawns = GameSpace:WaitForChild("Spawns")
local ClipBoxes = GameSpace:WaitForChild("Map"):WaitForChild("ClipBoxes")
local NoBulletCollision = GameSpace.Map:FindFirstChild("NoBulletCollision")

local playSoundServer = GunsRS:WaitForChild("Events"):WaitForChild("Remote"):WaitForChild("playSoundServer")

local function calculateAccuracy(self, target)
	
	local options = self.options
	local accuracy = options.baseAccuracy
	local currentBullet = self.currentBullet
	local accuracyModifier = (currentBullet * options.sprayAccuracy) / 10
	local movementFolder = self.player.Character:FindFirstChild("CSX-Movement-StarterChar")
	local movementScript = if movementFolder then movementFolder:FindFirstChild("SourceMovement") else false
	local crouching = if movementScript then movementScript:GetAttribute("crouching") else false
	local jumping = if movementScript then movementScript:GetAttribute("jumping") else false
	local vel = self.player.Character.HumanoidRootPart.Velocity.magnitude
	
	if options.scope then -- scope check
		if self.aiming then accuracy += options.scopeAccuracy else accuracy += options.unscopeAccuracy end
	end
	
	if currentBullet == 1 and options.firstBulletAccuracy then
		accuracy = 0
	end

	if jumping then -- movement check
		accuracy += options.jumpingAccuracy
	elseif vel >= MovementSettings.runInaccSpeed then
		accuracy += options.runningAccuracy
	elseif vel >= MovementSettings.walkInaccSpeed then
		accuracy += options.runningAccuracy
	elseif crouching then
		accuracy *= .2
	else
		accuracy *= accuracyModifier
	end

	local accuracy = Vector2.new(math.random(-accuracy, accuracy), math.random(-accuracy, accuracy)) -- apply inaccuracy
	target += accuracy
	
	return target
end

local function muzzleFlash(self)
	task.spawn(function()
		local flash = self.clientModel.GunComponents.WeaponHandle.FirePoint.MuzzleFlash --play muzzle flash client
		flash.Transparency = NumberSequence.new(0,0)
		flash.Enabled = true
		local newtick = tick() + .05
		repeat Run.RenderStepped:Wait(1/60) until tick() >= newtick
		flash.Enabled = false
	end)
end

local function playEmitter(emitter, length)
	emitter.Enabled = true
	task.delay(length, function()
		emitter.Enabled = false
	end)
end

local function playEmitterSmart(result)
	task.spawn(function()
		local hitChar = result.Instance:FindFirstAncestorWhichIsA("Model")
		if hitChar and hitChar:FindFirstChild("Humanoid") then
			if hitChar.Humanoid.Health <= 0 then return end
			if string.match(result.Instance.Name, "Head") then
				playEmitter(hitChar.Head.Spark, .15)
				playEmitter(hitChar.Head.headshotEmitter, .25)
			else
				playEmitter(hitChar.UpperTorso.Blood, .25)
			end
		end
	end)
end

local playHitSoundFunctions = {
	head = function()
		for i, v in pairs(HitSounds.LocalHeadshot:GetChildren()) do
			Sound:PlayLocalSound(v)
		end
	end,
	body = function()
		for i, v in pairs(HitSounds.LocalBodyshot:GetChildren()) do
			Sound:PlayLocalSound(v)
		end
	end
}

local function playHitSound(result)
	task.spawn(function()
		local instance = result.Instance
		local parent = instance:FindFirstAncestorWhichIsA("Model")
		if parent and parent:FindFirstChild("Humanoid") then
			if parent.Humanoid.Health <= 0 then return end
			if string.match(instance.Name, "Head") then
				playHitSoundFunctions.head()
			else
				playHitSoundFunctions.body()
			end
		end
	end)
end

local function wallbangRaycast(unitRay, dec, damage)
	
	local hasHit = false
	local wallsHit = false

	local cast = function()
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Blacklist
		params.FilterDescendantsInstances = dec
		params.CollisionGroup = "bullets"
		local result = workspace:Raycast(unitRay.Origin, unitRay.Direction * 500, params)
		if not result then hasHit = false return end
		local instance = result.Instance
		local model = instance:FindFirstAncestorWhichIsA("Model")
		local bangable = instance:GetAttribute("Bangable") or (model and model:GetAttribute("Bangable"))
		if bangable then
			--gunShootEvent:FireServer(weaponInformation, damage, result.Instance, result.Position, result.Normal, result.Distance, result.Material)
			table.insert(wallsHit, {result.Instance, bangable})
			table.insert(dec, result.Instance)
			if result.Instance.Parent.Name ~= "BulletClipBoxes" then
				WeaponService.CreateBulletHole(result)
			end
		end
	end

	repeat cast() until not hasHit

	local valid = false
	local wallsScript = require(RS["CSX-Guns-ReplicatedStorage"].Settings.frameworkSettings).walls
	
	if wallsHit then
		for i, v in pairs(wallsHit) do
			local index = table.find(wallsScript, v[2]) 
			damage = (index and (damage - damage * wallsScript[index])) or damage * .7
		end
	end

	return damage, dec
end

local function bulletRaycast(unitRay, dec)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Blacklist
	params.FilterDescendantsInstances = dec
	params.CollisionGroup = "bullets"
	local result = workspace:Raycast(unitRay.Origin, unitRay.Direction * 500, params)
	return result
end

local function calculateVectorVec2(self, x, y)
	local newx = (x * self.xMultiplier) + curVec2.X 
	local newy = (y * self.yMultiplier) + curVec2.Y 
	curVec2 = Vector2.new(newx, newy)
	return Vector2.new(newx, newy)
end

local function getRecoilPatternTable(self)
	curshots = (tick() - lastClickTick >= self.options.recoilReset and 1 or curshots + 1)
	lastClickTick = tick()
	local sprayPatternTable = self.options.sprayPattern[curshots]
	self.currentBullet = curshots
	return sprayPatternTable
end

local function calculateRecoilVector(self, sprayPatternTable)
	local oldX = sprayPatternTable[2]
	local oldY = sprayPatternTable[3]
	local x = oldX
	local y = oldY
	local mos = self.player:GetMouse()
	local fromPos = Vector2.new(mos.X, mos.Y)
	if self.currentBullet == 1 then curVec2 = Vector2.zero end -- reset vector addition if spray has been reset
	if self.options.firstBulletAccuracy and curshots == 1 then
		x = 0
		y = 0
	end
	local oldVec2 = calculateVectorVec2(self, x, y)
	local newVec2 = Vector2.new(-oldVec2.X + fromPos.X, -oldVec2.Y + fromPos.Y)
	return newVec2, Vector2.new(oldX, oldY)
end

local function shoveRecoilCamera(self, sprayPatternTable, x, y)
	task.spawn(function()
		local shovX = if self.currentBullet ~= 1 and lastShovVec2.X ~= 0 and x == 0 then lastShovVec2.X else x * .09
		local shovY = if self.currentBullet ~= 1 and lastShovVec2.Y ~= 0 and y == 0 then lastShovVec2.Y else y * .09
		lastShovVec2 = Vector2.new(shovX, shovY)
		self.fireCameraShove = lastShovVec2
		self.fireCameraSwitch = true
	end)
end

local module = function(self)
	
	local mos = self.player:GetMouse()
	local target = calculateAccuracy(self, Vector2.new(mos.X, mos.Y))
	local dec = {self.player.Character, self.camera, Temp, Shields, Spawns, ClipBoxes}
	if NoBulletCollision then table.insert(dec, NoBulletCollision) end

	task.spawn(function() -- animations & sounds
		self.animations.Local.Fire:Play()
		local fireSound = self.soundsFolder.Fire
		Sound:PlayLocalSound(fireSound)
		playSoundServer:FireServer(fireSound, player.Character.Head)
	end)

	task.spawn(function() -- recoil & bullet registration
		local recPatTab = getRecoilPatternTable(self)
		local target, addition = calculateRecoilVector(self, recPatTab)
		target = calculateAccuracy(self, target)
		shoveRecoilCamera(self, recPatTab, addition.X, addition.Y)
		local unitRay = camera:ScreenPointToRay(target.X, target.Y)
		local damage
		damage, dec = wallbangRaycast(unitRay, dec, self.options.baseDamage) -- get preset damage from wallbang raycast
		local mainResult = bulletRaycast(unitRay, dec)
		if mainResult then
			WeaponService.CreateBullet(self.clientModel.GunComponents.WeaponHandle.FirePoint.WorldPosition, mainResult.Position)
			self.fireEvent:FireServer(mainResult.Instance, mainResult.Position, mainResult.Normal, mainResult.Material)
			if mainResult.Instance.Parent and mainResult.Instance.Parent:FindFirstChild("Humanoid") then return end
			WeaponService.CreateBulletHole(mainResult)
			playHitSound(mainResult)
			playEmitterSmart(mainResult)
		end
	end)

end

return module