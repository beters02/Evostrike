local Page = require(script.Parent)
local options = setmetatable({}, Page)
options.__index = options

local g = script:WaitForChild("general")
local k =  script:WaitForChild("keybinds")

local function _compile(self, mainMenu)
	local general = g
	local keybinds = k
	for _, child in pairs({general, keybinds}) do
		for index, moduleElement in pairs(require(child)) do
			self[index] = moduleElement
		end
	end
end



--

function options.new(mainMenu, frame)
	local self = setmetatable(Page.new(mainMenu, frame), options)
	
	-- compile options page module functions
	_compile(self, mainMenu)

	self.connections = {}
	self.pageconnections = {}
	self.player = game.Players.LocalPlayer
	self.crosshairModule = self:_getPlayerCrosshairModule()
	self.crosshairFrame = self.Frame.General.Crosshair
	self.viewmodelFrame = self.Frame.General.Viewmodel
	self.keybindsFrame = self.Frame.Keybinds
	
	self:_updateCrosshairFrame()
	self:_updateViewmodelFrame()
	self:_updateKeybindsFrame()
	return self
end

function options:init()
	
end

--

function options:Open()
	self._Open()
	self:ConnectMain()
	self:SetCurrentOptionsPageOpen("general") -- open with general page
	--self:OpenAnimations()
end

function options:Close()
	self._Close()
	self:DisconnectMain()
	self:DisconnectPageConnections()
end

function options:SetCurrentOptionsPageOpen(page: string)
	if page == "general" then
		self._currentOptionsPage = "general"
		self:DisconnectPageConnections()
		self.Frame.Keybinds.Visible = false
		self.Frame.General.Visible = true
		self:_connectCrosshairFrame()
		self:_connectViewmodelFrame()
	elseif page == "keybinds" then
		self._currentOptionsPage = "keybinds"
		self:DisconnectPageConnections()
		self.Frame.General.Visible = false
		self.Frame.Keybinds.Visible = true
		self:_connectKeybindsFrame()
	end
end

--

function options:ConnectMain()
	self.connections = {

		self.Frame.GeneralButton.Button.MouseButton1Click:Connect(function()
			if self._currentOptionsPage == "general" then return end
			self:SetCurrentOptionsPageOpen("general")
		end),

		self.Frame.KeybindsButton.Button.MouseButton1Click:Connect(function()
			if self._currentOptionsPage == "keybinds" then return end
			self:SetCurrentOptionsPageOpen("keybinds")
		end)
	}
end

function options:DisconnectMain()
	for i, v in pairs(self.connections) do
		v:Disconnect()
	end
	self.connections = {}
end

function options:DisconnectPageConnections()
	for i, v in pairs(self.pageconnections) do
		v:Disconnect()
	end
	self.pageconnections = {}
end

return options