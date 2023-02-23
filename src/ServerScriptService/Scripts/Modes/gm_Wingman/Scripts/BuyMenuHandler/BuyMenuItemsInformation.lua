local module = {
	
	Weapons = {
		["AK"] = {
			Price = 2900,
			InventorySlot = "Primary"
		},
		["M4"] = {
			Price = 2900,
			InventorySlot = "Primary"
		},
		["Glock"] = {
			Price = 200,
			InventorySlot = "Secondary"
		},
		["USP"] = {
			Price = 400,
			InventorySlot = "Secondary"
		}
	},
	
	Abilities = {
		["Dash"] = {
			Price = 200,
			MaxAmount = 2,
			InventorySlot = "Movement"
		},
		["LongFlash"] = {
			Price = 200,
			MaxAmount = 2,
			InventorySlot = "Utility"
		},
		["Smoke"] = {
			Price = 400,
			MaxAmount = 2,
			InventorySlot = "Utility"
		}
	}
	
}

return module
