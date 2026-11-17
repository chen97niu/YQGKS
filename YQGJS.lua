-- =============================================
-- 概念神菜单 - 完整修改版
-- 锁头线已改为：一端连接灵动岛中心，另一端连接每个透视玩家头部
-- =============================================

-- ====================== 基础配置 ======================
local Config = {
    FOV = 150,
    DesignResolution = Vector2.new(1920, 1080),

    FlySpeed = {15, 30, 50, 80},
    WalkSpeed = {16, 25, 40, 60},
    JumpPower = {50, 100, 200, 350},

    AnimationIdle = "rbxassetid://180426354",
    AnimationWalk = "rbxassetid://180426366",
    AnimationRun = "rbxassetid://180426384",
    AnimationJump = "rbxassetid://180426400",
    AnimationFall = "rbxassetid://180426417",

    ManualAllyList = {},
    ESPMode = "AllEnemies", -- "SameTeam", "AllEnemies", "AllFriends"
    ManualAimTarget = nil,
}

-- ====================== 服务获取 ======================
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local Camera = workspace.CurrentCamera

local LP = Players.LocalPlayer
local IsMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- ====================== 状态变量 ======================
local State = {
    Fly = false,
    ESP = false,
    Noclip = false,
    Speed = false,
    Jump = false,
    Aimbot = false,
    AimbotManual = false,
}

local Connections = {}
local ESPObjects = {}
local ESPLabels = {}
local ESPLines = {}
local LinesConn = nil
local OldHumanoid = nil
local OriginalSpeed = 16
local OriginalJump = 50

-- ====================== 旧菜单清理 ======================
local function DestroyOldMenu()
    local CoreGui = game.CoreGui
    if CoreGui:FindFirstChild("概念神菜单") then
        CoreGui["概念神菜单"]:Destroy()
    end
    local PlayerGui = LP.PlayerGui
    if PlayerGui:FindFirstChild("概念神菜单") then
        PlayerGui["概念神菜单"]:Destroy()
    end
end
DestroyOldMenu()

-- ====================== 工具函数 ======================
local function GetScale()
    local vp = Camera.ViewportSize
    return math.min(vp.X / Config.DesignResolution.X, vp.Y / Config.DesignResolution.Y)
end

local function Notify(text, duration)
    duration = duration or 2
    local Gui = Instance.new("ScreenGui")
    Gui.Name = "CG_Notify"
    Gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    Gui.ResetOnSpawn = false

    local Frame = Instance.new("Frame")
    Frame.Size = UDim2.new(0, 280, 0, 50)
    Frame.Position = UDim2.new(0.5, -140, 0, 60)
    Frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    Frame.BorderSizePixel = 0
    Frame.CornerRadius = UDim.new(0, 12)
    Frame.Parent = Gui

    local TextLabel = Instance.new("TextLabel")
    TextLabel.Size = UDim2.new(1, 0, 1, 0)
    TextLabel.BackgroundTransparency = 1
    TextLabel.Text = text
    TextLabel.TextColor3 = Color3.new(1, 1, 1)
    TextLabel.TextSize = 14
    TextLabel.Font = Enum.Font.GothamBold
    TextLabel.TextWrapped = true
    TextLabel.Parent = Frame

    Gui.Parent = game.CoreGui

    task.delay(duration, function()
        Gui:Destroy()
    end)
end

local function isAlly(player)
    if table.find(Config.ManualAllyList, player) then
        return true
    end

    if Config.ESPMode == "SameTeam" then
        return player.Team == LP.Team
    elseif Config.ESPMode == "AllFriends" then
        return true
    else
        return false
    end
end

-- ====================== UI 系统 ======================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "概念神菜单"
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.ResetOnSpawn = false

local Success, CoreGuiResult = pcall(function()
    ScreenGui.Parent = game.CoreGui
end)
if not Success then
    ScreenGui.Parent = LP.PlayerGui
end

-- 灵动岛主窗口
local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Size = UDim2.new(0, 320, 0, 40)
Main.Position = UDim2.new(0.5, -160, 0, 10)
Main.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
Main.BorderSizePixel = 0
Main.CornerRadius = UDim.new(0, 20)
Main.ClipsDescendants = true
Main.Parent = ScreenGui

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Color3.fromRGB(60, 60, 60)
MainStroke.Thickness = 1
MainStroke.Parent = Main

-- 顶部窄条
local TopBar = Instance.new("Frame")
TopBar.Name = "TopBar"
TopBar.Size = UDim2.new(1, 0, 0, 40)
TopBar.Position = UDim2.new(0, 0, 0, 0)
TopBar.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
TopBar.BorderSizePixel = 0
TopBar.Parent = Main

local Title = Instance.new("TextLabel")
Title.Text = "概念神菜单"
Title.Size = UDim2.new(1, -60, 1, 0)
Title.Position = UDim2.new(0, 20, 0, 0)
Title.BackgroundTransparency = 1
Title.TextColor3 = Color3.new(1, 1, 1)
Title.TextSize = 14
Title.Font = Enum.Font.GothamBold
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = TopBar

local CloseButton = Instance.new("TextButton")
CloseButton.Text = "✕"
CloseButton.Size = UDim2.new(0, 40, 0, 40)
CloseButton.Position = UDim2.new(1, -40, 0, 0)
CloseButton.BackgroundTransparency = 1
CloseButton.TextColor3 = Color3.fromRGB(200, 200, 200)
CloseButton.TextSize = 18
CloseButton.Font = Enum.Font.GothamBold
CloseButton.Parent = TopBar

CloseButton.MouseButton1Click:Connect(function()
    CloseMenu()
end)

-- 页面容器
local PagesContainer = Instance.new("Frame")
PagesContainer.Name = "PagesContainer"
PagesContainer.Size = UDim2.new(1, 0, 1, -40)
PagesContainer.Position = UDim2.new(0, 0, 0, 40)
PagesContainer.BackgroundTransparency = 1
PagesContainer.ClipsDescendants = true
PagesContainer.Parent = Main

local function CreatePage(name)
    local Page = Instance.new("Frame")
    Page.Name = name
    Page.Size = UDim2.new(1, 0, 1, 0)
    Page.Position = UDim2.new(0, 0, 0, 0)
    Page.BackgroundTransparency = 1
    Page.Visible = false
    Page.Parent = PagesContainer

    local ScrollingFrame = Instance.new("ScrollingFrame")
    ScrollingFrame.Size = UDim2.new(1, 0, 1, 0)
    ScrollingFrame.Position = UDim2.new(0, 0, 0, 0)
    ScrollingFrame.BackgroundTransparency = 1
    ScrollingFrame.ScrollBarThickness = 4
    ScrollingFrame.Parent = Page

    local Layout = Instance.new("UIListLayout")
    Layout.Padding = UDim.new(0, 8)
    Layout.Parent = ScrollingFrame

    return Page, ScrollingFrame
end

local HomePage, HomeList = CreatePage("Home")
local FlyPage, FlyList = CreatePage("Fly")
local ESPPage, ESPList = CreatePage("ESP")
local SpeedPage, SpeedList = CreatePage("Speed")
local CombatPage, CombatList = CreatePage("Combat")

HomePage.Visible = true

-- UI组件封装
local function CreateButton(parent, text, callback)
    local Button = Instance.new("TextButton")
    Button.Size = UDim2.new(1, -16, 0, 40)
    Button.Position = UDim2.new(0, 8, 0, 0)
    Button.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    Button.BorderSizePixel = 0
    Button.CornerRadius = UDim.new(0, 8)
    Button.Text = text
    Button.TextColor3 = Color3.new(1, 1, 1)
    Button.TextSize = 14
    Button.Font = Enum.Font.Gotham
    Button.Parent = parent

    Button.MouseButton1Click:Connect(function()
        callback()
    end)

    return Button
end

local function CreateToggle(parent, text, state, callback)
    local Frame = Instance.new("Frame")
    Frame.Size = UDim2.new(1, -16, 0, 40)
    Frame.Position = UDim2.new(0, 8, 0, 0)
    Frame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    Frame.BorderSizePixel = 0
    Frame.CornerRadius = UDim.new(0, 8)
    Frame.Parent = parent

    local Label = Instance.new("TextLabel")
    Label.Text = text
    Label.Size = UDim2.new(1, -60, 1, 0)
    Label.Position = UDim2.new(0, 12, 0, 0)
    Label.BackgroundTransparency = 1
    Label.TextColor3 = Color3.new(1, 1, 1)
    Label.TextSize = 14
    Label.Font = Enum.Font.Gotham
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Parent = Frame

    local Toggle = Instance.new("TextButton")
    Toggle.Text = state and "开" or "关"
    Toggle.Size = UDim2.new(0, 40, 0, 30)
    Toggle.Position = UDim2.new(1, -50, 0.5, -15)
    Toggle.BackgroundColor3 = state and Color3.fromRGB(80, 200, 80) or Color3.fromRGB(180, 50, 50)
    Toggle.BorderSizePixel = 0
    Toggle.CornerRadius = UDim.new(0, 6)
    Toggle.TextColor3 = Color3.new(1, 1, 1)
    Toggle.TextSize = 12
    Toggle.Font = Enum.Font.GothamBold
    Toggle.Parent = Frame

    Toggle.MouseButton1Click:Connect(function()
        state = not state
        Toggle.Text = state and "开" or "关"
        Toggle.BackgroundColor3 = state and Color3.fromRGB(80, 200, 80) or Color3.fromRGB(180, 50, 50)
        callback(state)
    end)

    return Frame
end

local function CreateCycle(parent, text, values, currentIndex, callback)
    local Frame = Instance.new("Frame")
    Frame.Size = UDim2.new(1, -16, 0, 40)
    Frame.Position = UDim2.new(0, 8, 0, 0)
    Frame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    Frame.BorderSizePixel = 0
    Frame.CornerRadius = UDim.new(0, 8)
    Frame.Parent = parent

    local Label = Instance.new("TextLabel")
    Label.Text = text
    Label.Size = UDim2.new(0.6, 0, 1, 0)
    Label.Position = UDim2.new(0, 12, 0, 0)
    Label.BackgroundTransparency = 1
    Label.TextColor3 = Color3.new(1, 1, 1)
    Label.TextSize = 14
    Label.Font = Enum.Font.Gotham
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Parent = Frame

    local ValueLabel = Instance.new("TextLabel")
    ValueLabel.Text = tostring(values[currentIndex])
    ValueLabel.Size = UDim2.new(0.4, -12, 1, 0)
    ValueLabel.Position = UDim2.new(0.6, 6, 0, 0)
    ValueLabel.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    ValueLabel.BorderSizePixel = 0
    ValueLabel.CornerRadius = UDim.new(0, 6)
    ValueLabel.TextColor3 = Color3.new(1, 1, 1)
    ValueLabel.TextSize = 13
    ValueLabel.Font = Enum.Font.GothamBold
    ValueLabel.Parent = Frame

    ValueLabel.MouseButton1Click:Connect(function()
        currentIndex = currentIndex % #values + 1
        ValueLabel.Text = tostring(values[currentIndex])
        callback(values[currentIndex], currentIndex)
    end)

    return Frame
end

-- 页面切换
local function ShowPage(page)
    for i, v in pairs(PagesContainer:GetChildren()) do
        if v:IsA("Frame") then
            v.Visible = false
        end
    end
    page.Visible = true
end

CreateButton(HomeList, "飞行设置", function()
    ShowPage(FlyPage)
end)

CreateButton(HomeList, "透视设置", function()
    ShowPage(ESPPage)
end)

CreateButton(HomeList, "移动设置", function()
    ShowPage(SpeedPage)
end)

CreateButton(HomeList, "战斗设置", function()
    ShowPage(CombatPage)
end)

-- ====================== 飞天系统 ======================
local FlyVelocity = nil
local FlyAlign = nil
local FlyAnimations = {}
local FlyState = "Idle"

local function CreateFly()
    if not LP.Character then return end
    local HumanoidRootPart = LP.Character:FindFirstChild("HumanoidRootPart")
    if not HumanoidRootPart then return end

    if FlyVelocity then FlyVelocity:Destroy() end
    if FlyAlign then FlyAlign:Destroy() end

    FlyVelocity = Instance.new("LinearVelocity")
    FlyVelocity.Name = "FlyVelocity"
    FlyVelocity.MaxVelocity = Config.FlySpeed[2]
    FlyVelocity.Velocity = Vector3.new(0, 0, 0)
    FlyVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
    FlyVelocity.Enabled = true
    FlyVelocity.Parent = HumanoidRootPart

    FlyAlign = Instance.new("AlignOrientation")
    FlyAlign.Name = "FlyAlign"
    FlyAlign.CFrame = CFrame.new()
    FlyAlign.MaxTorque = 100000
    FlyAlign.Responsiveness = 20
    FlyAlign.Enabled = true
    FlyAlign.Parent = HumanoidRootPart
end

local function PlayFlyAnimation(id)
    if not LP.Character then return end
    local Humanoid = LP.Character:FindFirstChildOfClass("Humanoid")
    if not Humanoid then return end

    for i, v in pairs(FlyAnimations) do
        v:Stop()
    end
    table.clear(FlyAnimations)

    local Animation = Instance.new("Animation")
    Animation.AnimationId = id
    local Animator = Humanoid:WaitForChild("Animator")
    local Track = Animator:LoadAnimation(Animation)
    Track:Play()
    table.insert(FlyAnimations, Track)
end

local FlySpeedIndex = 2
CreateToggle(FlyList, "飞天", State.Fly, function(state)
    State.Fly = state
    if state then
        CreateFly()
        PlayFlyAnimation(Config.AnimationIdle)
        Notify("飞天已开启")
    else
        if FlyVelocity then FlyVelocity:Destroy(); FlyVelocity = nil end
        if FlyAlign then FlyAlign:Destroy(); FlyAlign = nil end
        for i, v in pairs(FlyAnimations) do
            v:Stop()
        end
        table.clear(FlyAnimations)
        Notify("飞天已关闭")
    end
end)

CreateCycle(FlyList, "飞行速度", Config.FlySpeed, FlySpeedIndex, function(value)
    FlySpeedIndex = value
    if FlyVelocity then
        FlyVelocity.MaxVelocity = Config.FlySpeed[FlySpeedIndex]
    end
end)

-- ====================== ESP透视系统 ======================
local function AddESP(player)
    if player == LP then return end
    if ESPObjects[player] then return end

    local Highlight = Instance.new("Highlight")
    Highlight.Name = "CG_ESP_Highlight"
    Highlight.FillTransparency = 1
    Highlight.OutlineTransparency = 0
    Highlight.OutlineColor = Color3.fromRGB(255, 50, 50)
    Highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    Highlight.Adornee = player.Character
    Highlight.Parent = ScreenGui

    local Billboard = Instance.new("BillboardGui")
    Billboard.Name = "CG_ESP_Billboard"
    Billboard.Size = UDim2.new(0, 140, 0, 40)
    Billboard.StudsOffset = Vector3.new(0, 3, 0)
    Billboard.AlwaysOnTop = true
    Billboard.Parent = ScreenGui

    local Label = Instance.new("TextLabel")
    Label.Name = "CG_ESP_Label"
    Label.Size = UDim2.new(1, 0, 1, 0)
    Label.BackgroundTransparency = 1
    Label.Text = player.Name
    Label.TextColor3 = Color3.fromRGB(255, 50, 50)
    Label.TextSize = 14
    Label.Font = Enum.Font.GothamBold
    Label.Parent = Billboard

    local Line = Instance.new("Frame")
    Line.Name = "CG_ESP_Line"
    Line.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    Line.BorderSizePixel = 0
    Line.Visible = false
    Line.Parent = ScreenGui

    ESPObjects[player] = Highlight
    ESPLabels[player] = Billboard
    ESPLines[player] = Line

    if player.Character then
        Highlight.Adornee = player.Character
        Billboard.Adornee = player.Character.Head or player.Character.HumanoidRootPart
    end

    player.CharacterAdded:Connect(function(Character)
        Character:WaitForChild("Head")
        Highlight.Adornee = Character
        Billboard.Adornee = Character.Head
    end)
end

local function RemoveESP(player)
    if ESPObjects[player] then
        ESPObjects[player]:Destroy()
        ESPObjects[player] = nil
    end
    if ESPLabels[player] then
        ESPLabels[player]:Destroy()
        ESPLabels[player] = nil
    end
    if ESPLines[player] then
        ESPLines[player]:Destroy()
        ESPLines[player] = nil
    end
end

local function ClearESP()
    for player, _ in pairs(ESPObjects) do
        RemoveESP(player)
    end
    table.clear(ESPObjects)
    table.clear(ESPLabels)
    table.clear(ESPLines)
end

-- ====================== 锁头线核心修改 ======================
local function StartLinesRenderer()
    if LinesConn then
        LinesConn:Disconnect()
        LinesConn = nil
    end

    LinesConn = RunService.RenderStepped:Connect(function()
        if not State.ESP then return end

        -- ✅ 核心修改：锁头线起点改为灵动岛窗口中心点
        local mainAbsPos = Main.AbsolutePosition
        local mainAbsSize = Main.AbsoluteSize
        local startPos = mainAbsPos + (mainAbsSize / 2)

        local rainbowColor = Color3.fromHSV((tick() * 0.3) % 1, 1, 1)

        for player, lineFrame in pairs(ESPLines) do
            if player.Character and LP.Character then
                local targetPart = player.Character:FindFirstChild("Head")
                local myRoot = LP.Character:FindFirstChild("HumanoidRootPart")

                if targetPart and myRoot then
                    local screenPos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
                    local dist = math.floor((myRoot.Position - targetPart.Position.Magnitude))

                    local label = ESPLabels[player]
                    if label and label.Adornee then
                        local isEnemy = not isAlly(player)
                        label.Text = (isEnemy and "[敌] " or "[友] ") .. player.Name .. " [" .. dist .. "m]"
                        label.TextColor3 = isEnemy and Color3.fromRGB(255, 50, 50) or Color3.fromRGB(50, 255, 50)
                    end

                    for _, hl in pairs(ESPObjects) do
                        if hl.Adornee == player.Character then
                            hl.OutlineColor = rainbowColor
                        end
                    end

                    if screenPos.Z > 0 then
                        local endPos = Vector2.new(screenPos.X, screenPos.Y)
                        local delta = endPos - startPos
                        local length = delta.Magnitude
                        local angle = math.deg(math.atan2(delta.Y, delta.X))

                        lineFrame.Visible = true
                        lineFrame.Position = UDim2.new(0, startPos.X, 0, startPos.Y)
                        lineFrame.Size = UDim2.new(0, length, 0, 1)
                        lineFrame.Rotation = angle
                    else
                        lineFrame.Visible = false
                    end
                else
                    lineFrame.Visible = false
                end
            else
                lineFrame.Visible = false
            end
        end
    end)
end

CreateToggle(ESPPage, "ESP透视", State.ESP, function(state)
    State.ESP = state
    if state then
        for i, v in pairs(Players:GetPlayers()) do
            if v ~= LP then
                AddESP(v)
            end
        end
        StartLinesRenderer()
        Notify("ESP已开启")
    else
        ClearESP()
        if LinesConn then
            LinesConn:Disconnect()
            LinesConn = nil
        end
        Notify("ESP已关闭")
    end
end)

-- ====================== 穿墙系统 ======================
local NoclipConn = nil

local function SetNoclip(enable)
    if not LP.Character then return end
    for i, v in pairs(LP.Character:GetDescendants()) do
        if v:IsA("BasePart") then
            v.CanCollide = not enable
        end
    end
end

CreateToggle(SpeedPage, "穿墙", State.Noclip, function(state)
    State.Noclip = state
    if state then
        NoclipConn = RunService.Stepped:Connect(function()
            SetNoclip(true)
        end)
        Notify("穿墙已开启")
    else
        if NoclipConn then
            NoclipConn:Disconnect()
            NoclipConn = nil
        end
        SetNoclip(false)
        Notify("穿墙已关闭")
    end
end)

-- ====================== 移动速度系统 ======================
local SpeedIndex = 1

local function SetSpeed(value)
    if not LP.Character then return end
    local Humanoid = LP.Character:FindFirstChildOfClass("Humanoid")
    if Humanoid then
        Humanoid.WalkSpeed = value
    end
end

CreateToggle(SpeedPage, "移速增强", State.Speed, function(state)
    State.Speed = state
    if state then
        SetSpeed(Config.WalkSpeed[SpeedIndex])
        Notify("移速已开启")
    else
        SetSpeed(OriginalSpeed)
        Notify("移速已关闭")
    end
end)

CreateCycle(SpeedPage, "移速档位", Config.WalkSpeed, SpeedIndex, function(value, index)
    SpeedIndex = index
    if State.Speed then
        SetSpeed(value)
    end
end)

-- ====================== 高跳系统 ======================
local JumpIndex = 1

local function SetJump(value)
    if not LP.Character then return end
    local Humanoid = LP.Character:FindFirstChildOfClass("Humanoid")
    if Humanoid then
        Humanoid.JumpPower = value
    end
end

CreateToggle(SpeedPage, "高跳增强", State.Jump, function(state)
    State.Jump = state
    if state then
        SetJump(Config.JumpPower[JumpIndex])
        Notify("高跳已开启")
    else
        SetJump(OriginalJump)
        Notify("高跳已关闭")
    end
end)

CreateCycle(SpeedPage, "高跳档位", Config.JumpPower, JumpIndex, function(value, index)
    JumpIndex = index
    if State.Jump then
        SetJump(value)
    end
end)

-- ====================== 锁头系统 ======================
local function GetClosestTarget()
    local closest = nil
    local closestDist = Config.FOV

    for player, _ in pairs(ESPObjects) do
        if player.Character and player.Character.Head then
            local screenPos = Camera:WorldToViewportPoint(player.Character.Head.Position)
            local dist = Vector2.new(screenPos.X, screenPos.Y).Distance(
                Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
            )

            if dist < closestDist and screenPos.Z > 0 and not isAlly(player) then
                closestDist = dist
                closest = player
            end
        end
    end

    return closest
end

CreateToggle(CombatPage, "自动锁头", State.Aimbot, function(state)
    State.Aimbot = state
    State.AimbotManual = false
    Notify(state and "自动锁头已开启" or "自动锁头已关闭")
end)

-- ====================== 角色重生恢复 ======================
LP.CharacterAdded:Connect(function(Character)
    Character:WaitForChild("Humanoid")
    Character:WaitForChild("HumanoidRootPart")

    task.wait(1)

    if State.Fly then
        CreateFly()
        PlayFlyAnimation(Config.AnimationIdle)
    end

    if State.Noclip then
        SetNoclip(true)
    end

    if State.Speed then
        SetSpeed(Config.WalkSpeed[SpeedIndex])
    end

    if State.Jump then
        SetJump(Config.JumpPower[JumpIndex])
    end
end)

-- ====================== 玩家加入/离开 ======================
Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function()
        if State.ESP then
            AddESP(player)
        end
    end)
end)

Players.PlayerRemoving:Connect(function(player)
    RemoveESP(player)
end)

-- ====================== 主循环 ======================
RunService.RenderStepped:Connect(function()
    if State.Fly and FlyVelocity then
        local MoveDirection = UserInputService:GetMoveVector()
        local CameraCFrame = Camera.CFrame.Rotation

        local WorldMove = CameraCFrame * MoveDirection
        local Up = UserInputService:IsKeyDown(Enum.KeyCode.Space) and Vector3.new(0, 1, 0) or Vector3.new(0, 0, 0)
        local Down = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) and Vector3.new(0, -1, 0) or Vector3.new(0, 0, 0)

        FlyVelocity.Velocity = (WorldMove + Up + Down) * Config.FlySpeed[FlySpeedIndex]

        if MoveDirection.Magnitude > 0 then
            if FlyState ~= "Moving" then
                PlayFlyAnimation(Config.AnimationWalk)
                FlyState = "Moving"
            end
        else
            if FlyState ~= "Idle" then
                PlayFlyAnimation(Config.AnimationIdle)
                FlyState = "Idle"
            end
        end
    end

    if State.Aimbot then
        local Target = Config.ManualAimTarget or GetClosestTarget()
        if Target and Target.Character and Target.Character.Head then
            Camera.CFrame = CFrame.new(Camera.CFrame.Position, Target.Character.Head.Position)
        end
    end
end)

-- ====================== 关闭菜单 ======================
function CloseMenu()
    if LinesConn then
        LinesConn:Disconnect()
        LinesConn = nil
    end

    ClearESP()

    if NoclipConn then
        NoclipConn:Disconnect()
        NoclipConn = nil
    end

    if FlyVelocity then FlyVelocity:Destroy() end
    if FlyAlign then FlyAlign:Destroy() end

    ScreenGui:Destroy()
    Notify("菜单已关闭")
end

Notify("概念神菜单已加载")
