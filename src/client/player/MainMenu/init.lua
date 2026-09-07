--[[
    Init MainMenu Module when player joins the game
    Get MainMenuType and Distribute to all pages on initialization
]]

--[[ CONFIG ]]
local DISABLE_CHAT_RETRIES = 5
local MENU_OPEN_WITH_HOMEPAGE = true
local TOPBAR_BUTTON_ACTIVE_COLOR = Color3.fromRGB(57, 120, 125)
local TOPBAR_BUTTON_DEFAULT_COLOR = Color3.fromRGB(235, 241, 255)
local TOPBAR_BUTTON_OPEN_FADEIN_LENGTH = .8
local TOPBAR_BAR_OPEN_LENGTH = .8
local TOPBAR_BUTTON_CLOSE_FADEOUT_LENGTH = .6
local TOPBAR_BAR_CLOSE_LENGTH = .7
local TOPBAR_BUTTON_HOVER_FADEIN_LENGTH = 1
local TOPBAR_BUTTON_HOVER_FADEOUT_LENGTH = 1
--

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Framework = require(ReplicatedStorage:WaitForChild("Framework"))
local GameService = require(Framework.Service.GameService)
local States = require(Framework.Module.States)
local UIState = States:Get("UI")
local StarterGui = game:GetService("StarterGui")

-- Button Sound Names (Stored in Gui.Sounds)
local Enum_ButtonSoundNames = {
    Purchase1 = "purchaseSound1",
    Error1 = "errorSound1",
    Hover1 = "hoverSound",
    ItemDisplay1 = "itemDisplaySound",
    ItemReceive1 = "itemReceivedSound",
    Select1 = "selectSound",
    WheelTick1 = "wheelTick",
    WoodImpact1 = "woodImpact"
}
Enum_ButtonSoundNames.Open = Enum_ButtonSoundNames.Select1
Enum_ButtonSoundNames.ItemDisplay = Enum_ButtonSoundNames.ItemDisplay1

-- Main Menu Module
local MainMenu = {
    Connections = {},
    BaseConnections = {}, -- Dont disconnect these
    TopBarConnections = {},
    Pages = {},
    ButtonSounds = {},
    Tweens = {},
    Var = {},
    CurrentOpenPage = false,
    Gui = false,
    CurrentMenuType = false,
    Popup = require(script:WaitForChild("Popup"))
}

-- Initialize Pages, Sounds and GamemodeService
function MainMenu:Initialize(gui)
    print("initting penis")
    self.Gui = gui
    self.IsTopBarOpen = false
    --self.CurrentMenuType = GamemodeService:GetMenuType()
    self.CurrentMenuType = GameService:GetMenuType()
    self.HUD = require(game.Players.LocalPlayer.PlayerScripts:WaitForChild("HUD"))
    self.DisabledHUDs = {}

    initPages(self)
    initButtonSounds(self)
    initTopBar(self)

    self.BaseConnections.MenuTypeChanged = GameService:MenuTypeChanged(menuTypeChanged)
    self.CurrentOpenPage = getPage("Home")

    self.CurrentTopBarSelectedButton = "HomeButtonFrame"

    self.BlurLightingEffect = Lighting:FindFirstChild("MainMenuBlur")
    if not self.BlurLightingEffect then
        self.BlurLightingEffect = Instance.new("BlurEffect", Lighting)
        self.BlurLightingEffect.Enabled = false
        self.BlurLightingEffect.Size = 54
        self.BlurLightingEffect.Name = "MainMenuBlur"
    end

    if self.CurrentMenuType == "Lobby" then
        self:Open()
    end
end

-- Open the Menu, Re-opens last open page
function MainMenu:Open()
    self.Gui.Enabled = true

    if self.CurrentOpenPage then
        self.CurrentOpenPage:Open()
    end

    UIState:removeOpenUI("MainMenu")
	UIState:addOpenUI("MainMenu", self.Gui, true)
    task.spawn(function()
        disableHud(self)
        disableChat()
    end)

    self.BlurLightingEffect.Enabled = true
end

-- Close the Menu, Closes current page and sets to last open
function MainMenu:Close()
    self:ClosePage()
    
    if MENU_OPEN_WITH_HOMEPAGE then
        self.CurrentOpenPage = self.Pages.Home
    end

    self.Gui.Enabled = false
    UIState:removeOpenUI("MainMenu")
    task.spawn(function()
        enableHud(self)
        enableChat()
    end)

    self.BlurLightingEffect.Enabled = false
end

-- Automatically Closes Current Page and Opens New One
function MainMenu:OpenPage(pageName)
    local newPage = getPage(pageName)
    self:ClosePage()
    newPage:Open()
    self.CurrentOpenPage = newPage

    local fn = pageName .. "ButtonFrame"
    self.Tweens.TopBarHoverOn[self.CurrentTopBarSelectedButton]:Pause()
    self.Tweens.TopBarHoverOff[self.CurrentTopBarSelectedButton]:Play()
    self.CurrentTopBarSelectedButton = fn
    self.Tweens.TopBarHoverOff[fn]:Pause()
    self.Tweens.TopBarHoverOn[fn]:Play()
end

-- Closes the Currently Opened Page
function MainMenu:ClosePage()
    if self.CurrentOpenPage then
        self.CurrentOpenPage:Close()
    end
end

function MainMenu:GetPage(page: string)
    return self.Pages[page]
end

-- Play a Button Sound
function MainMenu:PlayButtonSound(buttonType)
    self.ButtonSounds[buttonType]:Play()
end

-- Get the CurrentMenuType
function MainMenu.MenuType()
    return MainMenu.CurrentMenuType
end

function MainMenu:OpenTopBar()
    self.IsTopBarOpen = true
    openTopBarTween(self)
    connectTopBar(self)
end

function MainMenu:CloseTopBar()
    self.IsTopBarOpen = false
    closeTopBarTween(self)
    disconnectTopBar(self)
end

--
--
--

function getPage(pageName) return MainMenu.Pages[pageName] end
function getPages() return MainMenu.Pages end

function initButtonSounds(self)
    local bsounds = self.Gui:WaitForChild("Sounds")
    for i, v in pairs(Enum_ButtonSoundNames) do
        self.ButtonSounds[i] = bsounds:FindFirstChild(v)
    end
end

function menuTypeChanged(newMenuType)
    local self = MainMenu
    if self.CurrentMenuType == newMenuType then return end
    self.CurrentMenuType = newMenuType
    for _, page in pairs(getPages()) do
        page:MenuTypeChanged(newMenuType)
    end
end

function initPages(self)
    -- Frames which names end in "Frame: are initialized as pages and moved to Pages Folder
    local pagesFolder = Instance.new("Folder", self.Gui)
    pagesFolder.Name = "Pages"
    for _, frame in pairs(self.Gui:GetChildren()) do
        if not string.match(frame.Name, "Frame") then continue end
        frame.Parent = pagesFolder
        local pageName = string.gsub(frame.Name, "Frame", "")

        -- if we can't find a module for the page, it gets the Base class.
        local module = script.Page:FindFirstChild(pageName) or script.Page
        self.Pages[pageName] = require(module).new(self, frame)
        self.Pages[pageName]:MenuTypeChanged(self.CurrentMenuType)
    end
end

function initTopBar(self)
    local tb: Frame = self.Gui.TopBar
    self.Var.topBarDefSizeY = tb.Size.Y.Scale

    local tboti = TweenInfo.new(TOPBAR_BAR_OPEN_LENGTH, Enum.EasingStyle.Cubic)
    local tbcti = TweenInfo.new(TOPBAR_BAR_CLOSE_LENGTH, Enum.EasingStyle.Cubic)
    local tbbofiti = TweenInfo.new(TOPBAR_BUTTON_OPEN_FADEIN_LENGTH, Enum.EasingStyle.Cubic)
    local tbbofoti = TweenInfo.new(TOPBAR_BUTTON_CLOSE_FADEOUT_LENGTH, Enum.EasingStyle.Cubic)
    local tbbhiti = TweenInfo.new(TOPBAR_BUTTON_HOVER_FADEIN_LENGTH, Enum.EasingStyle.Cubic)
    local tbbhoti = TweenInfo.new(TOPBAR_BUTTON_HOVER_FADEOUT_LENGTH, Enum.EasingStyle.Cubic)

    self.Tweens.TopBarOpen = {}
    self.Tweens.TopBarClose = {}
    self.Tweens.TopBarHoverOn = {}
    self.Tweens.TopBarHoverOff = {}
    self.Tweens.TopBarOpen.Bar = TweenService:Create(tb, tboti, {Size = UDim2.fromScale(1, self.Var.topBarDefSizeY)})
    self.Tweens.TopBarClose.Bar = TweenService:Create(tb, tbcti, {Size = UDim2.fromScale(1, 0)})

    for _, v in pairs(tb:GetChildren()) do
        if v.Name == "CreditsButtonFrame" then
            continue
        end
        self.Tweens.TopBarOpen[v.Name] = TweenService:Create(v:WaitForChild("TextButton"), tbbofiti, {TextTransparency = 0})
        self.Tweens.TopBarOpen[v.Name .. "_Stroke"] = TweenService:Create(v.TextButton.UIStroke, tbbofiti, {Transparency = 0})
        self.Tweens.TopBarClose[v.Name] = TweenService:Create(v.TextButton, tbbofoti, {TextTransparency = 1})
        self.Tweens.TopBarClose[v.Name .. "_Stroke"] = TweenService:Create(v.TextButton.UIStroke, tbbofoti, {Transparency = 1})
        self.Tweens.TopBarHoverOn[v.Name] = TweenService:Create(v.TextButton, tbbhiti, {TextColor3 = TOPBAR_BUTTON_ACTIVE_COLOR})
		self.Tweens.TopBarHoverOff[v.Name] = TweenService:Create(v.TextButton, tbbhoti, {TextColor3 = TOPBAR_BUTTON_DEFAULT_COLOR})
        v.TextButton.UIStroke.Transparency = 1
        v.TextButton.TextTransparency = 1
    end

    tb.Size = UDim2.fromScale(1, 0)
    tb.Visible = true
end

function connectTopBar(self)
    for _, frame: Frame in pairs(self.Gui.TopBar:GetChildren()) do
        if frame.Name == "CreditsButtonFrame" then
            continue
        end
        self.TopBarConnections[frame.Name .. "Began"] = frame.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement then
                if self.CurrentTopBarSelectedButton == frame.Name then
                    return
                end
                hoverOnTopBarTween(self, frame)
			end
        end)
        self.TopBarConnections[frame.Name .. "Ended"] = frame.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement then
                if self.CurrentTopBarSelectedButton == frame.Name then
                    return
                end
                hoverOffTopBarTween(self, frame)
			end
        end)
        self.TopBarConnections[frame.Name .. "Activated"] = frame.TextButton.MouseButton1Click:Connect(function()
            self:PlayButtonSound("Select1")
            self:OpenPage(string.gsub(frame.Name, "ButtonFrame", ""))
        end)
    end
end

function disconnectTopBar(self)
    for _, v in pairs(self.TopBarConnections) do
        v:Disconnect()
    end
end

function openTopBarTween(self)
    self.Tweens.TopBarOpen.Bar:Play()
    self.Tweens.TopBarOpen.Bar.Completed:Once(function()
        if not self.IsTopBarOpen then
            return
        end
        for i, v in pairs(self.Tweens.TopBarOpen) do
            if i == "Bar" then
                continue
            end
            v:Play()
        end
    end)
end

function closeTopBarTween(self)
    local last
    for i, v in pairs(self.Tweens.TopBarClose) do
        if i == "Bar" then
            continue
        end
        v:Play()
        last = v
    end
    for _, frame in pairs(self.Gui.TopBar:GetChildren()) do
        if frame.Name == "CreditsButtonFrame" then
            continue
        end
        hoverOffTopBarTween(self, frame)
    end
    last.Completed:Once(function()
        if not self.IsTopBarOpen then
            self.Tweens.TopBarClose.Bar:Play()
        end
    end)
end

function hoverOnTopBarTween(self, frame)
    local offTween = self.Tweens.TopBarHoverOff[frame.Name]
    local onTween = self.Tweens.TopBarHoverOn[frame.Name]
    if offTween.PlaybackState == Enum.PlaybackState.Playing then
        offTween:Pause()
    end
    onTween:Play()
end

function hoverOffTopBarTween(self, frame)
    local offTween = self.Tweens.TopBarHoverOff[frame.Name]
    local onTween = self.Tweens.TopBarHoverOn[frame.Name]
    if onTween.PlaybackState == Enum.PlaybackState.Playing then
        onTween:Pause()
    end
    offTween:Play()
end

function disableChat()
    local retries = 0
	local success,message
	repeat
		success,message = pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, false)
		end)
		if not success then
			retries += 1
			task.wait(1)
		end
	until success == true or retries == DISABLE_CHAT_RETRIES
	if not success then
		error(message)
	end
end

function enableChat()
    local retries = 0
	local success,message
	repeat
		success,message = pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, true)
		end)
		if not success then
			retries += 1
			task.wait(1)
		end
	until success == true or retries == DISABLE_CHAT_RETRIES
	if not success then
		error(message)
	end
end

function enableHud(self)
    local hud = self.HUD

    if hud.gui then
        hud:Enable()
    end

    for i, v in pairs(self.DisabledHUDs) do
        v.Enabled = true
    end
    self.DisabledHUDs = {}
end

function disableHud(self)
    local hud = self.HUD

    if hud.gui then
        hud:Disable()
    end
    
    for _, v in pairs(game.Players.LocalPlayer.PlayerGui:GetChildren()) do
        if v.Enabled and v.Name ~= "MainMenuGui" then
            v.Enabled = false
            table.insert(self.DisabledHUDs, v)
        end
    end
end

return MainMenu