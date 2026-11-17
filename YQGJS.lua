--[[
    概念神菜单 (Concept God Menu) - 多级菜单版
    文件名: YQGJS.lua
    特性: 
      1. 灵动岛 UI + 多级折叠菜单
      2. 全距离透视、实时距离显示
      3. 彩色高亮描边、白线无视边界死锁
      4. 多档位调节 / 手动标友 / 指定锁头 / 飞行穿墙
]]

-- ================= 全局配置 =================
local CONFIG = {
    MenuName          = "概念神菜单",
    AimbotFOV         = 300,
    DesignW           = 420,
    DesignH           = 640,
    
    FlySpeeds         = {40, 80, 120, 200},
    JumpPowers        = {80, 120, 200, 300},
    WalkSpeeds        = {40, 80, 150, 250},
    
    FlySpeedIdx       = 1,
    JumpPowerIdx      = 1,
    WalkSpeedIdx      = 1,
}

local FLY_ANIMS = {
    Idle = 619542203, Walk = 619544080, Run  = 619543231, Jump = 619542888, Fall = 619541867,
}

-- ================= 服务 =================
local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS        = game:GetService("UserInputService")
local CoreGui    = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")

local LP     = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local IS_TOUCH  = UIS.TouchEnabled
local IS_MOBILE = IS_TOUCH

-- ================= 状态 =================
local State = {
    Fly=false, ESP=false, Noclip=false, JumpPower=false, Speed=false, Aimbot=false,
}
local ESPMode = 1
local AimbotTargetPlayer = nil
local ManualAllies = {}

-- ================= 敌友识别 =================
local function isAlly(player)
    if player == LP then return true end
    if ManualAllies[player.Name] then return true end
    if ESPMode == 2 then return false end
    if ESPMode == 3 then return true end
    if LP.Team and player.Team then
        return LP.Team == player.Team
    end
    return false
end

-- ================= 小工具 =================
local function corner(parent, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 8)
    c.Parent = parent
    return c
end

local function stroke(parent, color, thickness)
    local s = Instance.new("UIStroke")
    s.Color = color or Color3.fromRGB(255,255,255)
    s.Thickness = thickness or 1
    s.Transparency = 0.55
    s.Parent = parent
    return s
end

-- ================= 旧 UI 清理 =================
local old = CoreGui:FindFirstChild("ConceptGodMenu")
if old then old:Destroy() end

-- ================= ScreenGui =================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "ConceptGodMenu"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.IgnoreGuiInset = true
local okParent = pcall(function() ScreenGui.Parent = CoreGui end)
if not okParent then ScreenGui.Parent = LP:WaitForChild("PlayerGui") end

-- ================= 灵动岛主窗口 =================
local Main = Instance.new("Frame")
Main.Name = "Main"
Main.AnchorPoint = Vector2.new(0.5, 0)
Main.Position = UDim2.new(0.5, 0, 0, 5)
Main.Size = UDim2.new(0, 180, 0, 38)
Main.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
Main.BackgroundTransparency = 0.2
Main.BorderSizePixel = 0
Main.ClipsDescendants = true
Main.Parent = ScreenGui
corner(Main, 19)
stroke(Main, Color3.fromRGB(80, 80, 100), 1.5)

local Header = Instance.new("TextButton")
Header.Size = UDim2.new(1, 0, 0, 38)
Header.BackgroundTransparency = 1
Header.Text = "◈ " .. CONFIG.MenuName
Header.TextColor3 = Color3.fromRGB(255, 255, 255)
Header.Font = Enum.Font.GothamBold
Header.TextSize = 15
Header.Parent = Main

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 30, 0, 30)
CloseBtn.Position = UDim2.new(1, -34, 0, 4)
CloseBtn.BackgroundColor3 = Color3.fromRGB(190, 55, 55)
CloseBtn.BorderSizePixel = 0
CloseBtn.Text = "X"
CloseBtn.TextColor3 = Color3.fromRGB(255,255,255)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 14
CloseBtn.Parent = Main
corner(CloseBtn, 15)

local ScaleObj = Instance.new("UIScale")
ScaleObj.Parent = Main
local function updateScale()
    local vp = Camera.ViewportSize
    if vp.X <= 0 or vp.Y <= 0 then return end
    local s = math.min(vp.X / CONFIG.DesignW, vp.Y / CONFIG.DesignH)
    ScaleObj.Scale = math.clamp(s, 0.65, 1.30)
end
Camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
updateScale()

-- ================= 菜单基础容器 =================
local List = Instance.new("ScrollingFrame")
List.Size = UDim2.new(1, 0, 0, 480)
List.Position = UDim2.new(0, 0, 0, 42)
List.BackgroundTransparency = 1
List.BorderSizePixel = 0
List.ScrollBarThickness = 4
List.CanvasSize = UDim2.new(0, 0, 0, 0)
List.AutomaticCanvasSize = Enum.AutomaticSize.Y
List.Visible = false
List.Parent = Main

-- 灵动岛折叠展开逻辑
local expanded = false
Header.MouseButton1Click:Connect(function()
    expanded = not expanded
    List.Visible = expanded
    TweenService:Create(Main, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
        Size = expanded and UDim2.new(0, 300, 0, 520) or UDim2.new(0, 180, 0, 38)
    }):Play()
    TweenService:Create(Main, TweenInfo.new(0.3), {
        CornerRadius = UDim.new(0, expanded and 10 or 19)
    }):Play()
end)

-- ================= 分页 (Pages) 系统 =================
local Pages = {}
local function ShowPage(pageName)
    for name, frame in pairs(Pages) do
        frame.Visible = (name == pageName)
    end
    List.CanvasPosition = Vector2.new(0, 0) -- 切换页面时重置滚动条
end

-- 创建页面容器
local function CreatePage(pageName)
    local p = Instance.new("Frame")
    p.Name = pageName .. "Page"
    p.Size = UDim2.new(1, -12, 0, 0)
    p.Position = UDim2.new(0, 6, 0, 4)
    p.AutomaticSize = Enum.AutomaticSize.Y
    p.BackgroundTransparency = 1
    p.Visible = false
    p.Parent = List
    
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 8)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = p
    
    Pages[pageName] = p
    return p
end

local HomePage   = CreatePage("Home")
local FlyPage    = CreatePage("Fly")
local EspPage    = CreatePage("Esp")
local MovePage   = CreatePage("Move")
local CombatPage = CreatePage("Combat")

-- ================= 按钮组件 =================
local BTN_H = IS_MOBILE and 48 or 40
local Toggles = {}

-- 创建跳转按钮（分类）
local function CreateNavBtn(parent, text, targetPage)
    local Btn = Instance.new("TextButton")
    Btn.Size = UDim2.new(1, 0, 0, BTN_H)
    Btn.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    Btn.BackgroundTransparency = 0.25
    Btn.BorderSizePixel = 0
    Btn.Text = text .. "  >"
    Btn.TextColor3 = Color3.fromRGB(235,235,235)
    Btn.TextStrokeTransparency = 0.6
    Btn.Font = Enum.Font.GothamSemibold
    Btn.TextSize = IS_MOBILE and 17 or 15
    Btn.TextXAlignment = Enum.TextXAlignment.Left
    Btn.Parent = parent
    local pad = Instance.new("UIPadding", Btn)
    pad.PaddingLeft = UDim.new(0, 12)
    corner(Btn, 8)
    stroke(Btn, Color3.fromRGB(80,80,100), 1)
    
    Btn.MouseButton1Click:Connect(function() ShowPage(targetPage) end)
    return Btn
end

-- 创建返回按钮
local function CreateBackBtn(parent)
    local Btn = Instance.new("TextButton")
    Btn.Size = UDim2.new(1, 0, 0, 34)
    Btn.BackgroundColor3 = Color3.fromRGB(60, 60, 75)
    Btn.BackgroundTransparency = 0.3
    Btn.BorderSizePixel = 0
    Btn.Text = "< 返回主菜单"
    Btn.TextColor3 = Color3.fromRGB(235,235,235)
    Btn.Font = Enum.Font.GothamSemibold
    Btn.TextSize = 14
    Btn.Parent = parent
    corner(Btn, 6)
    stroke(Btn, Color3.fromRGB(100,100,120), 1)
    
    Btn.MouseButton1Click:Connect(function() ShowPage("Home") end)
    return Btn
end

-- 创建开关按钮
local function CreateToggle(parent, text, key, callback)
    local Btn = Instance.new("TextButton")
    Btn.Size = UDim2.new(1, 0, 0, BTN_H)
    Btn.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
    Btn.BackgroundTransparency = 0.25
    Btn.BorderSizePixel = 0
    Btn.Text = text .. " : 关闭"
    Btn.TextColor3 = Color3.fromRGB(235,235,235)
    Btn.TextStrokeTransparency = 0.6
    Btn.Font = Enum.Font.GothamSemibold
    Btn.TextSize = IS_MOBILE and 17 or 15
    Btn.Parent = parent
    corner(Btn, 8)
    stroke(Btn, Color3.fromRGB(80,80,100), 1)

    local on = false
    local function refresh()
        Btn.Text = text .. (on and " : 开启" or " : 关闭")
        Btn.BackgroundColor3 = on and Color3.fromRGB(55,140,90) or Color3.fromRGB(30,30,38)
    end

    Btn.MouseButton1Click:Connect(function()
        on = not on
        refresh()
        State[key] = on
        if callback then callback(on) end
    end)

    Toggles[key] = function(v)
        on = v; refresh(); State[key] = v
        if callback then callback(v) end
    end
    refresh()
    return Btn
end

-- 创建档位选择按钮
local function CreateCycleBtn(parent, text, options, initialIdx, callback)
    local Btn = Instance.new("TextButton")
    Btn.Size = UDim2.new(1, 0, 0, BTN_H)
    Btn.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    Btn.BackgroundTransparency = 0.25
    Btn.BorderSizePixel = 0
    Btn.TextColor3 = Color3.fromRGB(235,235,235)
    Btn.TextStrokeTransparency = 0.6
    Btn.Font = Enum.Font.GothamSemibold
    Btn.TextSize = IS_MOBILE and 17 or 15
    Btn.Parent = parent
    corner(Btn, 8)
    stroke(Btn, Color3.fromRGB(80,80,100), 1)

    local idx = initialIdx
    local function refresh()
        Btn.Text = text .. " : " .. options[idx]
    end

    Btn.MouseButton1Click:Connect(function()
        idx = idx + 1
        if idx > #options then idx = 1 end
        refresh()
        if callback then callback(idx) end
    end)
    refresh()
    return Btn
end

-- ================= 构建各个页面的 UI =================

-- 1. 主页
local homeTitle = Instance.new("TextLabel")
homeTitle.Size = UDim2.new(1, 0, 0, 20)
homeTitle.BackgroundTransparency = 1
homeTitle.Text = "选择功能分类"
homeTitle.TextColor3 = Color3.fromRGB(200, 200, 200)
homeTitle.TextXAlignment = Enum.TextXAlignment.Left
homeTitle.Font = Enum.Font.GothamBold
homeTitle.TextSize = 14
homeTitle.Parent = HomePage

CreateNavBtn(HomePage, "飞行设置", "Fly")
CreateNavBtn(HomePage, "透视设置", "Esp")
CreateNavBtn(HomePage, "移动设置 (穿墙/移速/跳跃)", "Move")
CreateNavBtn(HomePage, "战斗设置 (锁头)", "Combat")

-- 2. 飞行页
CreateBackBtn(FlyPage)
CreateToggle(FlyPage, "飞天 (Fly)", "Fly", function(on) ToggleFly(on) end)
CreateCycleBtn(FlyPage, "飞行速度", {"慢", "中", "快", "超快"}, CONFIG.FlySpeedIdx, function(idx) CONFIG.FlySpeedIdx = idx end)

-- 3. 透视页
CreateBackBtn(EspPage)
CreateToggle(EspPage, "透视 (ESP)", "ESP", ToggleESP)
CreateCycleBtn(EspPage, "透视阵营", {"仅队伍", "全敌", "全友"}, 1, function(idx)
    ESPMode = idx
    RefreshESP()
end)

-- 4. 移动页
CreateBackBtn(MovePage)
CreateToggle(MovePage, "穿墙 (Noclip)", "Noclip", ToggleNoclip)
CreateToggle(MovePage, "加强移速 (Speed)", "Speed", ToggleSpeed)
CreateCycleBtn(MovePage, "移动速度", {"快跑", "疾跑", "瞬移", "光速"}, CONFIG.WalkSpeedIdx, function(idx) CONFIG.WalkSpeedIdx = idx end)
CreateToggle(MovePage, "加强跳跃 (Jump)", "JumpPower", ToggleJump)
CreateCycleBtn(MovePage, "跳跃力度", {"正常", "加强", "超高", "飞天"}, CONFIG.JumpPowerIdx, function(idx)
    CONFIG.JumpPowerIdx = idx
    if State.JumpPower then
        local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.JumpPower = CONFIG.JumpPowers[idx] end
    end
end)

-- 5. 战斗页
CreateBackBtn(CombatPage)
CreateToggle(CombatPage, "锁头 (Aimbot)", "Aimbot", ToggleAimbot)

local TargetBtn = Instance.new("TextButton")
TargetBtn.Size = UDim2.new(1, 0, 0, BTN_H)
TargetBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
TargetBtn.BorderSizePixel = 0
TargetBtn.TextColor3 = Color3.fromRGB(235,235,235)
TargetBtn.Font = Enum.Font.GothamSemibold
TargetBtn.TextSize = IS_MOBILE and 17 or 15
TargetBtn.Parent = CombatPage
corner(TargetBtn, 8)
stroke(TargetBtn, Color3.fromRGB(80,80,100), 1)

TargetBtn.MouseButton1Click:Connect(function()
    RefreshTargetList()
    TargetSelectorGui.Visible = true
end)

Toggles["TargetSelectBtn"] = function()
    if AimbotTargetPlayer then
        TargetBtn.Text = "当前目标: " .. AimbotTargetPlayer.Name
        TargetBtn.BackgroundColor3 = Color3.fromRGB(55, 140, 90)
    else
        TargetBtn.Text = "选择锁头目标 (当前: 自动)"
        TargetBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    end
end
Toggles["TargetSelectBtn"]()

-- 初始化显示主页
ShowPage("Home")


-- ================= 摇杆读取 =================
local PlayerModule, Controls
local function getControls()
    if Controls then return Controls end
    local ps = LP:FindFirstChild("PlayerScripts")
    if not ps then return nil end
    local pm = ps:FindFirstChild("PlayerModule")
    if not pm then return nil end
    local ok, mod = pcall(require, pm)
    if not ok or not mod then return nil end
    PlayerModule = mod
    local ok2, c = pcall(function() return mod:GetControls() end)
    if ok2 and c then Controls = c end
    return Controls
end

-- ================= 飞行系统 =================
local Fly = { conn = nil, lv = nil, ao = nil, att = nil, animTracks = {}, currentAnim = "" }

local function setFlyAnim(stateName)
    if Fly.currentAnim == stateName then return end
    Fly.currentAnim = stateName
    for name, track in pairs(Fly.animTracks) do
        if name == stateName then track:Play(0.2) else track:Stop(0.2) end
    end
end

local function loadFlyAnims(hum)
    Fly.animTracks = {}; Fly.currentAnim = ""
    local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
    for name, id in pairs(FLY_ANIMS) do
        local anim = Instance.new("Animation")
        anim.AnimationId = "rbxassetid://" .. id
        local track = animator:LoadAnimation(anim)
        track.Priority = Enum.AnimationPriority.Action
        track.Looped = true
        Fly.animTracks[name] = track
    end
end

local function cleanFly()
    if Fly.conn then Fly.conn:Disconnect(); Fly.conn = nil end
    if Fly.lv then Fly.lv:Destroy(); Fly.lv = nil end
    if Fly.ao then Fly.ao:Destroy(); Fly.ao = nil end
    if Fly.att then Fly.att:Destroy(); Fly.att = nil end
    for _, track in pairs(Fly.animTracks) do track:Stop(0) end
    Fly.animTracks = {}; Fly.currentAnim = ""
    local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
    if hum and not State.Noclip then hum.PlatformStand = false end
end

local function ToggleFly(on)
    cleanFly()
    if not on then return end
    local char = LP.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return end

    hum.PlatformStand = true
    loadFlyAnims(hum)

    Fly.att = Instance.new("Attachment", hrp)
    Fly.lv = Instance.new("LinearVelocity")
    Fly.lv.Attachment0 = Fly.att; Fly.lv.MaxForce = 1e5; Fly.lv.Parent = hrp
    Fly.ao = Instance.new("AlignOrientation")
    Fly.ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
    Fly.ao.Attachment0 = Fly.att; Fly.ao.MaxTorque = 1e5; Fly.ao.RigidityEnabled = true; Fly.ao.Parent = hrp

    Fly.conn = RunService.RenderStepped:Connect(function()
        local c = LP.Character
        local root = c and c:FindFirstChild("HumanoidRootPart")
        if not root or not Fly.lv or not Fly.ao then return end

        local camCF = workspace.CurrentCamera.CFrame
        local mv = Vector3.zero
        local ctl = getControls()
        if ctl then
            local ok, v = pcall(function() return ctl:GetMoveVector() end)
            if ok and typeof(v) == "Vector3" then mv = v end
        end

        local dir = Vector3.zero
        if mv.Magnitude > 0.05 then
            dir += camCF.LookVector * (-mv.Z)
            dir += camCF.RightVector * (mv.X)
        end

        if UIS:IsKeyDown(Enum.KeyCode.Space) then dir += Vector3.new(0,1,0) end
        if UIS:IsKeyDown(Enum.KeyCode.LeftShift) then dir -= Vector3.new(0,1,0) end

        local currentSpeed = CONFIG.FlySpeeds[CONFIG.FlySpeedIdx]
        if dir.Magnitude > 1e-4 then
            Fly.lv.VectorVelocity = dir.Unit * currentSpeed
        else
            Fly.lv.VectorVelocity = Vector3.zero
        end

        local lookFlat = Vector3.new(camCF.LookVector.X, 0, camCF.LookVector.Z)
        if lookFlat.Magnitude > 1e-4 then lookFlat = lookFlat.Unit end
        local yaw = math.atan2(-lookFlat.X, -lookFlat.Z)
        Fly.ao.CFrame = CFrame.new(Vector3.zero) * CFrame.Angles(0, yaw, 0)

        local inputMag = mv.Magnitude
        local isVertical = math.abs(dir.Y) > (Vector2.new(dir.X, dir.Z).Magnitude)

        if inputMag < 0.05 and not UIS:IsKeyDown(Enum.KeyCode.Space) and not UIS:IsKeyDown(Enum.KeyCode.LeftShift) then
            setFlyAnim("Idle")
        elseif (isVertical and dir.Y > 0) or UIS:IsKeyDown(Enum.KeyCode.Space) then
            setFlyAnim("Jump")
        elseif (isVertical and dir.Y < 0) or UIS:IsKeyDown(Enum.KeyCode.LeftShift) then
            setFlyAnim("Fall")
        else
            if inputMag > 0.5 then setFlyAnim("Run") else setFlyAnim("Walk") end
        end
    end)
end

-- ================= 锁头 =================
local function ToggleAimbot(on)
    if not on then
        pcall(function() RunService:UnbindFromRenderStep("CG_Aimbot") end)
        return
    end

    RunService:BindToRenderStep("CG_Aimbot", Enum.RenderPriority.Camera.Value + 1, function()
        if not State.Aimbot then return end
        local targetHead = nil

        if AimbotTargetPlayer and AimbotTargetPlayer.Parent then
            local char = AimbotTargetPlayer.Character
            local head = char and char:FindFirstChild("Head")
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if head and hum and hum.Health > 0 then targetHead = head end
        else
            local closestHead, shortestDist = nil, CONFIG.AimbotFOV
            local center = Camera.ViewportSize / 2
            for _, p in ipairs(Players:GetPlayers()) do
                if not isAlly(p) and p.Character then
                    local head = p.Character:FindFirstChild("Head")
                    local hum = p.Character:FindFirstChildOfClass("Humanoid")
                    if head and hum and hum.Health > 0 then
                        local screenPos, onScreen = Camera:WorldToViewportPoint(head.Position)
                        if onScreen then
                            local dist = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
                            if dist < shortestDist then
                                shortestDist = dist; closestHead = head
                            end
                        end
                    end
                end
            end
            targetHead = closestHead
        end

        if targetHead then
            Camera.CFrame = CFrame.lookAt(Camera.CFrame.Position, targetHead.Position)
        end
    end)
end

-- ================= ESP 全距离透视 + 连线系统 =================
local ESPPlayerConn = nil
local ESPObjects = {}
local ESPLines = {}
local ESPLabels = {}

local function ClearESP()
    for _, obj in ipairs(ESPObjects) do if obj and obj.Parent then obj:Destroy() end end
    table.clear(ESPObjects)
    for _, line in ipairs(ESPLines) do if line and line.Parent then line:Destroy() end end
    table.clear(ESPLines)
    for _, label in ipairs(ESPLabels) do if label and label.Parent then label:Destroy() end end
    table.clear(ESPLabels)
    if ESPPlayerConn then ESPPlayerConn:Disconnect(); ESPPlayerConn = nil end
end

local LinesConn = nil
local function StartLinesRenderer()
    if LinesConn then LinesConn:Disconnect(); LinesConn = nil end
    
    LinesConn = RunService.RenderStepped:Connect(function()
        if not State.ESP then return end
        local vp = Camera.ViewportSize
        local startPos = Vector2.new(vp.X / 2, 45)
        local rainbowColor = Color3.fromHSV((tick() * 0.3) % 1, 1, 1)

        for player, lineFrame in pairs(ESPLines) do
            if player.Character and LP.Character then
                local targetPart = player.Character:FindFirstChild("Head") or player.Character:FindFirstChild("HumanoidRootPart")
                local myPos = LP.Character:FindFirstChild("HumanoidRootPart")
                
                if targetPart and myPos then
                    local screenPos = Camera:WorldToViewportPoint(targetPart.Position)
                    
                    local dist = math.floor((myPos.Position - targetPart.Position).Magnitude)
                    local label = ESPLabels[player]
                    if label then
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
                end
            else
                lineFrame.Visible = false
            end
        end
    end)
end

local function AddESP(player)
    if player == LP then return end
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    if ESPLines[player] then ESPLines[player]:Destroy() end
    if ESPLabels[player] then ESPLabels[player]:Destroy() end

    local isEnemy = not isAlly(player)
    local mainColor = isEnemy and Color3.fromRGB(255, 50, 50) or Color3.fromRGB(50, 255, 50)

    local highlight = Instance.new("Highlight", char)
    highlight.Name = "CG_ESP_Highlight"; highlight.Adornee = char
    highlight.FillColor = mainColor; highlight.FillTransparency = 0.65
    highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
    table.insert(ESPObjects, highlight)

    local billboard = Instance.new("BillboardGui", hrp)
    billboard.Name = "CG_ESP"; billboard.Adornee = hrp
    billboard.Size = UDim2.new(0, 200, 0, 40)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.AlwaysOnTop = true
    billboard.MaxDistance = 100000

    local label = Instance.new("TextLabel", billboard)
    label.Size = UDim2.new(1, 0, 1, 0); label.BackgroundTransparency = 1
    label.Text = (isEnemy and "[敌] " or "[友] ") .. player.Name
    label.TextColor3 = mainColor; label.TextStrokeTransparency = 0
    label.Font = Enum.Font.GothamBold; label.TextSize = 14
    label.Parent = billboard
    table.insert(ESPLabels, label)

    local line = Instance.new("Frame")
    line.Name = "CG_ESP_Line"
    line.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    line.BorderSizePixel = 0
    line.AnchorPoint = Vector2.new(0, 0.5)
    line.ZIndex = 2
    line.Visible = false
    line.Parent = ScreenGui
    ESPLines[player] = line
end

local function RefreshESP()
    ClearESP()
    if not State.ESP then return end
    for _, p in ipairs(Players:GetPlayers()) do AddESP(p) end
    StartLinesRenderer()
end

local function ToggleESP(on)
    ClearESP()
    if not on then return end
    RefreshESP()

    ESPPlayerConn = Players.PlayerAdded:Connect(function(p)
        p.CharacterAdded:Connect(function() task.wait(0.5); if State.ESP then AddESP(p) end end)
    end)
    for _, p in ipairs(Players:GetPlayers()) do
        p.CharacterAdded:Connect(function() task.wait(0.5); if State.ESP then AddESP(p) end end)
    end
end

-- ================= 目标选择器 UI (保持独立弹窗) =================
local TargetSelectorGui = Instance.new("Frame")
TargetSelectorGui.Name = "TargetSelector"
TargetSelectorGui.Size = UDim2.new(0, 280, 0, 380)
TargetSelectorGui.Position = UDim2.new(0.5, 0, 0.5, 0)
TargetSelectorGui.AnchorPoint = Vector2.new(0.5, 0.5)
TargetSelectorGui.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
TargetSelectorGui.BackgroundTransparency = 0.1
TargetSelectorGui.BorderSizePixel = 0
TargetSelectorGui.Visible = false
TargetSelectorGui.ZIndex = 10
TargetSelectorGui.Parent = ScreenGui
corner(TargetSelectorGui, 10)
stroke(TargetSelectorGui, Color3.fromRGB(100, 100, 120), 2)

local TS_Title = Instance.new("TextLabel")
TS_Title.Size = UDim2.new(1, 0, 0, 40)
TS_Title.BackgroundTransparency = 1
TS_Title.Text = "目标设置 (手动标友/锁头)"
TS_Title.TextColor3 = Color3.fromRGB(255, 255, 255)
TS_Title.Font = Enum.Font.GothamBold
TS_Title.TextSize = 16
TS_Title.ZIndex = 11
TS_Title.Parent = TargetSelectorGui

local TS_Close = Instance.new("TextButton")
TS_Close.Size = UDim2.new(0, 30, 0, 30)
TS_Close.Position = UDim2.new(1, -35, 0, 5)
TS_Close.BackgroundColor3 = Color3.fromRGB(190, 55, 55)
TS_Close.BorderSizePixel = 0
TS_Close.Text = "X"
TS_Close.TextColor3 = Color3.fromRGB(255, 255, 255)
TS_Close.Font = Enum.Font.GothamBold
TS_Close.TextSize = 14
TS_Close.ZIndex = 11
TS_Close.Parent = TargetSelectorGui
corner(TS_Close, 6)
TS_Close.MouseButton1Click:Connect(function() TargetSelectorGui.Visible = false end)

local TS_Scroll = Instance.new("ScrollingFrame")
TS_Scroll.Size = UDim2.new(1, -20, 1, -50)
TS_Scroll.Position = UDim2.new(0, 10, 0, 40)
TS_Scroll.BackgroundTransparency = 1
TS_Scroll.BorderSizePixel = 0
TS_Scroll.ScrollBarThickness = 4
TS_Scroll.ZIndex = 11
TS_Scroll.Parent = TargetSelectorGui

local TS_Layout = Instance.new("UIListLayout")
TS_Layout.Padding = UDim.new(0, 6)
TS_Layout.SortOrder = Enum.SortOrder.LayoutOrder
TS_Layout.Parent = TS_Scroll

local function RefreshTargetList()
    for _, child in ipairs(TS_Scroll:GetChildren()) do
        if child:IsA("Frame") or child:IsA("TextButton") then child:Destroy() end
    end

    local cancelBtn = Instance.new("TextButton")
    cancelBtn.Size = UDim2.new(1, -6, 0, 40)
    cancelBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
    cancelBtn.Text = "恢复自动锁敌 (取消指定)"
    cancelBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    cancelBtn.Font = Enum.Font.GothamSemibold
    cancelBtn.TextSize = 14
    cancelBtn.ZIndex = 11
    cancelBtn.Parent = TS_Scroll
    corner(cancelBtn, 6)
    cancelBtn.MouseButton1Click:Connect(function()
        AimbotTargetPlayer = nil
        Toggles["TargetSelectBtn"]()
        TargetSelectorGui.Visible = false
    end)

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP then
            local row = Instance.new("Frame")
            row.Size = UDim2.new(1, -6, 0, 40)
            row.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
            row.ZIndex = 11
            row.Parent = TS_Scroll
            corner(row, 6)

            local btnLock = Instance.new("TextButton")
            btnLock.Size = UDim2.new(0.65, 0, 1, 0)
            btnLock.BackgroundTransparency = 1
            btnLock.Text = (p.Name == (AimbotTargetPlayer and AimbotTargetPlayer.Name)) and ("[锁定] " .. p.Name) or p.Name
            btnLock.TextColor3 = isAlly(p) and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(255, 100, 100)
            btnLock.Font = Enum.Font.GothamSemibold
            btnLock.TextSize = 14
            btnLock.TextXAlignment = Enum.TextXAlignment.Left
            btnLock.ZIndex = 12
            btnLock.Parent = row
            local pad = Instance.new("UIPadding", btnLock)
            pad.PaddingLeft = UDim.new(0, 10)
            btnLock.MouseButton1Click:Connect(function()
                AimbotTargetPlayer = p
                Toggles["TargetSelectBtn"]()
                TargetSelectorGui.Visible = false
            end)

            local btnAlly = Instance.new("TextButton")
            btnAlly.Size = UDim2.new(0.35, 0, 1, 0)
            btnAlly.Position = UDim2.new(0.65, 0, 0, 0)
            btnAlly.BackgroundColor3 = ManualAllies[p.Name] and Color3.fromRGB(55, 140, 90) or Color3.fromRGB(80, 80, 90)
            btnAlly.Text = ManualAllies[p.Name] and "取消友军" or "设为友军"
            btnAlly.TextColor3 = Color3.fromRGB(255, 255, 255)
            btnAlly.Font = Enum.Font.GothamBold
            btnAlly.TextSize = 12
            btnAlly.ZIndex = 12
            btnAlly.Parent = row
            corner(btnAlly, 6)
            
            btnAlly.MouseButton1Click:Connect(function()
                if ManualAllies[p.Name] then ManualAllies[p.Name] = nil else ManualAllies[p.Name] = true end
                RefreshTargetList()
                RefreshESP()
            end)
        end
    end
end

-- ================= 穿墙 =================
local NoclipConn = nil
local function ToggleNoclip(on)
    if NoclipConn then NoclipConn:Disconnect(); NoclipConn = nil end
    if not on then
        local char = LP.Character
        if char then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then part.CanCollide = true end
            end
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum and not State.Fly then hum.PlatformStand = false end
        end
        return
    end
    NoclipConn = RunService.Stepped:Connect(function()
        local c = LP.Character
        if not c then return end
        for _, part in ipairs(c:GetDescendants()) do
            if part:IsA("BasePart") then part.CanCollide = false end
        end
    end)
end

-- ================= 移速 =================
local SpeedConn = nil
local origSpeed
local function ToggleSpeed(on)
    if SpeedConn then SpeedConn:Disconnect(); SpeedConn = nil end
    local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    if on then
        origSpeed = hum.WalkSpeed
        SpeedConn = RunService.RenderStepped:Connect(function()
            local c = LP.Character
            local h = c and c:FindFirstChildOfClass("Humanoid")
            local root = c and c:FindFirstChild("HumanoidRootPart")
            if h and root and not State.Fly and not State.Noclip then
                local currentSpeed = CONFIG.WalkSpeeds[CONFIG.WalkSpeedIdx]
                h.WalkSpeed = currentSpeed
                if h.MoveDirection.Magnitude > 0.1 then
                    local addSpeed = (currentSpeed - 16) * 0.02
                    root.CFrame = root.CFrame + (h.MoveDirection * addSpeed)
                end
            end
        end)
    else
        if origSpeed then hum.WalkSpeed = origSpeed end
    end
end

-- ================= 跳跃 =================
local origJump
local function ToggleJump(on)
    local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    if on then 
        origJump = hum.JumpPower
        hum.UseJumpPower = true
        hum.JumpPower = CONFIG.JumpPowers[CONFIG.JumpPowerIdx]
    else 
        if origJump then hum.JumpPower = origJump end 
    end
end

-- ================= 重生与清理 =================
LP.CharacterAdded:Connect(function()
    task.wait(0.8)
    if State.JumpPower then ToggleJump(true) end
    if State.Speed then ToggleSpeed(true) end
    if State.Fly then cleanFly(); ToggleFly(true) end
    if State.Noclip then ToggleNoclip(true) end
    if State.ESP then RefreshESP() end
end)

CloseBtn.MouseButton1Click:Connect(function()
    cleanFly()
    if NoclipConn then NoclipConn:Disconnect(); end
    if SpeedConn then SpeedConn:Disconnect(); end
    if LinesConn then LinesConn:Disconnect(); end
    pcall(function() RunService:UnbindFromRenderStep("CG_Aimbot") end)
    ClearESP()
    ScreenGui:Destroy()
end)

print("[概念神菜单] 已更新！多级菜单已加载。")