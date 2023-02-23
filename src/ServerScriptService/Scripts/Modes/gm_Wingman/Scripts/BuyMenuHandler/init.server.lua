-- ** buy menu remote information :
--[[

possible buy menu remote actions:
 -: attemptWeaponPurchase
 -: attemptAbilityPurchase
 -: attemptAbilityDestroy

]]


--
-- SERVICES & DEPENDENCIES --
--

local RS = game:GetService("ReplicatedStorage")
local GunsRS = RS:WaitForChild("CSX-Guns-ReplicatedStorage")
local GameRS = RS:WaitForChild("CSX-Game-ReplicatedStorage")
local AbilityRS = RS:WaitForChild("CSX-Abilities-ReplicatedStorage")
local WingmanEvents = GameRS:WaitForChild("Events"):WaitForChild("Wingman")

local weaponClass = require(GunsRS:WaitForChild("Scripts"):WaitForChild("Modules"):WaitForChild("Weapon"))
local abilityClass = require(AbilityRS:WaitForChild("Scripts"):WaitForChild("Modules"):WaitForChild("Ability"))
local buyMenuItemsInfo = require(script:WaitForChild("BuyMenuItemsInformation"))
local bmii = buyMenuItemsInfo

--
-- GAME OBJECTS --
--

local buyMenuRemote = WingmanEvents:WaitForChild("BuyMenu")
local getGamemodePlayerData = WingmanEvents:WaitForChild("GetGamemodePlayerData")
local setGamemodePlayerData = WingmanEvents:WaitForChild("SetGamemodePlayerData")

--
--
--

local function buyMenuRemoteFunction(player, action, value)
	local playerData = getGamemodePlayerData:Invoke(player)
	if action == "attemptWeaponPurchase" then
		local weaponData = bmii.Weapons[value]
		if playerData.Money < weaponData.Price then
			return false, "You do not have enough money!"
		end
		playerData.Inventory[weaponData.InventorySlot] = value
		playerData.Money -= weaponData.Price
		setGamemodePlayerData:Fire(player, playerData)
		weaponClass.add(player, value, true)
	elseif action == "attemptAbilityPurchase" then
		local abilityData = bmii.Abilities[value]
		if playerData.Money < abilityData.Price then
			return false, "You do not have enough money!"
		end
		local key = abilityData.InventorySlot .. "Ability"
		if playerData.Inventory[key] == nil then
			playerData.Inventory[key] = {AbilityName = value, Amount = 0}
		elseif playerData.Inventory[key].AbilityName ~= value then
			return false, "You must destroy the ability in this slot!"
		end
		if playerData.Inventory[key].Amount >= abilityData.MaxAmount then
			return false, "You have the maximum amount!"
		end
		playerData.Inventory[key].Amount += 1
		playerData.Money -= abilityData.Price
		setGamemodePlayerData:Fire(player, playerData)
		abilityClass.add(player, value, {uses = playerData.Inventory[key].Amount})
	end
end

buyMenuRemote.OnServerInvoke = buyMenuRemoteFunction