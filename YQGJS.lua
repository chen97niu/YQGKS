--[[
    概念神菜单 (Concept God Menu) - 最终完美版
    文件名: YQGJS.lua
    特性: 
      1. 摇杆自由飞行（视角指哪飞哪，右侧滑屏仅转视角）
      2. R15 飞行动作自动切换
      3. 透视自动识别敌友（红敌 / 绿友）
      4. 锁头功能（自动吸附敌方头部，不锁队友）
]]

-- ================= 配置 =================
local CONFIG = {
    MenuName          = "概念神菜单",
    JumpPowerValue    = 120,
    WalkSpeedValue    = 80,
    FlySpeed          = 60,
    AimbotFOV         = 300, -- 锁头视野范围（屏幕像素）
    DesignW           = 420,
    DesignH           = 640,
}

-- 飞行动作包 ID (R15)
local FLY_ANIMS = {
    Idle = 619542203, -- 浮空待机
    Walk = 619544080, -- 浮空走路
    Run  = 619543231, -- 浮空奔跑
    Jump = 619542888, -- 浮空跳跃(上升)
    Fall = 619541867, -- 浮空下落(下降)
}

-- ================= 服务 =================
local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS        = game:GetService("UserInputService")
local CoreGui    = game:GetService("CoreGui")

local LP     = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local IS_TOUCH  = UIS.TouchEnabled
local IS_MOBILE = IS_TOUCH

-- ================= 状态 =================
local State = {
    Fly=false, ESP=false, Noclip=false, JumpPower=false, Speed=false, Aimbot=false,
}

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

-- ================= 敌友识别逻辑 =================
local function isAlly(player)
    if player == LP then return true end
    -- 如果双方都有队伍，且队伍相同，视为队友
    if LP.Team and player.Team then
        return LP.Team == player.Team
    end
    -- 没队伍的默认全当敌人处理
    return false
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
if not okParent then
    ScreenGui.Parent = LP:WaitForChild("PlayerGui")
end

-- ================= 主窗口（透明背景） =================
local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Size = UDim2.new(0, 300, 0, 450) -- 加高一点放锁头按钮
Main.Position = UDim2.new(0, 20, 0, 90)
Main.BackgroundTransparency = 1
Main.BorderSizePixel = 0
Main.Active = true
Main.Parent = ScreenGui

local ScaleObj = Instance.new("UIScale")
ScaleObj.Parent = Main

local function updateScale()
    local vp = Camera.ViewportSize
    if vp.X <= 0 or vp.Y <= 0 then return end
    local s = math.min(vp.X / CONFIG.DesignW, vp.Y / CONFIG.DesignH)
    s = math.clamp(s, 0.65, 1.30)
    ScaleObj.Scale = s
end
Camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
updateScale()

-- ================= 顶栏 =================
local Header = Instance.new("Frame")
Header.Name = "Header"
Header.Size = UDim2.new(1, 0, 0, 44)
Header.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
Header.BackgroundTransparency = 0.35
Header.BorderSizePixel = 0
Header.Parent = Main
corner(Header, 10)
stroke(Header, Color3.fromRGB(90, 90, 110), 1)

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -100, 1, 0)
Title.Position = UDim2.new(0, 12, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = CONFIG.MenuName
Title.TextColor3 = Color3.fromRGB(255,255,255)
Title.TextStrokeTransparency = 0.4
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Font = Enum.Font.GothamBold
Title.TextSize = 20
Title.Parent = Header

local FoldBtn = Instance.new("TextButton")
FoldBtn.Size = UDim2.new(0, 32, 0, 32)
FoldBtn.Position = UDim2.new(1, -76, 0, 6)
FoldBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
FoldBtn.BackgroundTransparency = 0.2
FoldBtn.BorderSizePixel = 0
FoldBtn.Text = "-"
FoldBtn.TextColor3 = Color3.fromRGB(255,255,255)
FoldBtn.Font = Enum.Font.GothamBold
FoldBtn.TextSize = 18
FoldBtn.Parent = Header
corner(FoldBtn, 8)

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 32, 0, 32)
CloseBtn.Position = UDim2.new(1, -38, 0, 6)
CloseBtn.BackgroundColor3 = Color3.fromRGB(190, 55, 55)
CloseBtn.BorderSizePixel = 0
CloseBtn.Text = "X"
CloseBtn.TextColor3 = Color3.fromRGB(255,255,255)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 16
CloseBtn.Parent = Header
corner(CloseBtn, 8)

if IS_MOBILE then
    FoldBtn.Size  = UDim2.new(0, 40, 0, 40)
    FoldBtn.Position = UDim2.new(1, -92, 0, 2)
    CloseBtn.Size = UDim2.new(0, 40, 0, 40)
    CloseBtn.Position = UDim2.new(1, -46, 0, 2)
    Header.Size = UDim2.new(1, 0, 0, 48)
end

-- ================= 拖动 =================
do
    local dragging, dragStart, startPos = false, nil, nil
    Header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = Main.Position
        end
    end)
    UIS.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch) then
            local d = input.Position - dragStart
            Main.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + d.X,
                startPos.Y.Scale, startPos.Y.Offset + d.Y
            )
        end
    end)
    UIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

-- ================= 功能列表 =================
local List = Instance.new("Frame")
List.Name = "List"
List.Size = UDim2.new(1, 0, 1, -52)
List.Position = UDim2.new(0, 0, 0, 50)
List.BackgroundTransparency = 1
List.Parent = Main

local ListLayout = Instance.new("UIListLayout")
ListLayout.Padding = UDim.new(0, 8)
ListLayout.SortOrder = Enum.SortOrder.LayoutOrder
ListLayout.Parent = List

local ListPad = Instance.new("UIPadding")
ListPad.PaddingTop  = UDim.new(0, 4)
ListPad.PaddingLeft = UDim.new(0, 6)
ListPad.PaddingRight= UDim.new(0, 6)
ListPad.Parent = List

local folded = false
FoldBtn.MouseButton1Click:Connect(function()
    folded = not folded
    List.Visible = not folded
    Main.Size = folded and UDim2.new(0, 300, 0, IS_MOBILE and 48 or 44)
                           or UDim2.new(0, 300, 0, 450)
    FoldBtn.Text = folded and "+" or "-"
end)

-- ================= 开关按钮 =================
local BTN_H = IS_MOBILE and 48 or 40
local Toggles = {}

local function CreateToggle(text, key, callback)
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
    Btn.Parent = List
    corner(Btn, 8)
    stroke(Btn, Color3.fromRGB(80,80,100), 1)

    local on = false
    local function refresh()
        Btn.Text = text .. (on and " : 开启" or " : 关闭")
        Btn.BackgroundColor3 = on and Color3.fromRGB(55,140,90)
                                  or Color3.fromRGB(30,30,38)
    end

    Btn.MouseButton1Click:Connect(function()
        on = not on
        refresh()
        State[key] = on
        if callback then callback(on) end
    end)

    Toggles[key] = function(v)
        on = v
        refresh()
        State[key] = v
        if callback then callback(v) end
    end

    refresh()
    return Btn
end

-- ================= 读取 Roblox 自带摇杆 =================
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

-- ================= 飞行系统 (完全靠摇杆) =================
local Fly = {
    conn = nil, lv = nil, ao = nil, att = nil,
    animTracks = {}, currentAnim = "",
}
local upKey, downKey = false, false

-- 切换飞行动画
local function setFlyAnim(stateName)
    if Fly.currentAnim == stateName then return end
    Fly.currentAnim = stateName
    for name, track in pairs(Fly.animTracks) do
        if name == stateName then
            track:Play(0.2)
        else
            track:Stop(0.2)
        end
    end
end

-- 加载飞行动画
local function loadFlyAnims(hum)
    Fly.animTracks = {}
    Fly.currentAnim = ""
    local animator = hum:FindFirstChildOfClass("Animator")
    if not animator then
        animator = Instance.new("Animator")
        animator.Parent = hum
    end
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
    if Fly.conn       then Fly.conn:Disconnect();       Fly.conn = nil end
    if Fly.lv         then Fly.lv:Destroy();            Fly.lv = nil end
    if Fly.ao         then Fly.ao:Destroy();            Fly.ao = nil end
    if Fly.att        then Fly.att:Destroy();           Fly.att = nil end
    
    for _, track in pairs(Fly.animTracks) do
        track:Stop(0)
    end
    Fly.animTracks = {}
    Fly.currentAnim = ""
    upKey, downKey = false, false

    local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
    if hum then hum.PlatformStand = false end
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

    Fly.att = Instance.new("Attachment")
    Fly.att.Name = "CG_FlyAtt"
    Fly.att.Parent = hrp

    Fly.lv = Instance.new("LinearVelocity")
    Fly.lv.Name = "CG_FlyLV"
    Fly.lv.Attachment0 = Fly.att
    Fly.lv.MaxForce = 1e5
    Fly.lv.VectorVelocity = Vector3.zero
    Fly.lv.Parent = hrp

    Fly.ao = Instance.new("AlignOrientation")
    Fly.ao.Name = "CG_FlyAO"
    Fly.ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
    Fly.ao.Attachment0 = Fly.att
    Fly.ao.MaxTorque = 1e5
    Fly.ao.RigidityEnabled = true
    Fly.ao.Parent = hrp

    -- 桌面端依然保留空格升降
    if UIS.KeyboardEnabled then
        UIS.InputBegan:Connect(function(i, gp)
            if gp then return end
            if i.KeyCode == Enum.KeyCode.Space then upKey = true end
            if i.KeyCode == Enum.KeyCode.LeftShift then downKey = true end
        end)
        UIS.InputEnded:Connect(function(i)
            if i.KeyCode == Enum.KeyCode.Space then upKey = false end
            if i.KeyCode == Enum.KeyCode.LeftShift then downKey = false end
        end)
    end

    Fly.conn = RunService.RenderStepped:Connect(function()
        local c = LP.Character
        local root = c and c:FindFirstChild("HumanoidRootPart")
        if not root or not Fly.lv or not Fly.ao then return end

        local cam = workspace.CurrentCamera
        local camCF = cam.CFrame

        -- 只读取摇杆，不再拦截右侧触摸，右侧完全留给相机
        local mv = Vector3.zero
        local ctl = getControls()
        if ctl then
            local ok, v = pcall(function() return ctl:GetMoveVector() end)
            if ok and typeof(v) == "Vector3" then mv = v end
        end

        -- 计算 3D 飞行方向（基于相机视线）
        -- 当 mv.Z = -1 (前推) 时，加上相机的 LookVector，实现视角抬头就往上飞
        local dir = Vector3.zero
        if mv.Magnitude > 0.05 then
            dir += camCF.LookVector * (-mv.Z)
            dir += camCF.RightVector * (mv.X)
        end
        
        -- 键盘升降叠加
        if upKey then dir += Vector3.new(0, 1, 0) end
        if downKey then dir -= Vector3.new(0, 1, 0) end

        if dir.Magnitude > 1e-4 then
            Fly.lv.VectorVelocity = dir.Unit * CONFIG.FlySpeed
        else
            Fly.lv.VectorVelocity = Vector3.zero
        end

        -- 角色始终保持直立，朝向相机水平方向
        local lookFlat = Vector3.new(camCF.LookVector.X, 0, camCF.LookVector.Z)
        if lookFlat.Magnitude > 1e-4 then lookFlat = lookFlat.Unit end
        local yaw = math.atan2(-lookFlat.X, -lookFlat.Z)
        Fly.ao.CFrame = CFrame.new(Vector3.zero) * CFrame.Angles(0, yaw, 0)

        -- ========== 动画逻辑 ==========
        local inputMag = mv.Magnitude
        local isVertical = math.abs(dir.Y) > (Vector2.new(dir.X, dir.Z).Magnitude)

        if inputMag < 0.05 and not upKey and not downKey then
            setFlyAnim("Idle")
        elseif (isVertical and dir.Y > 0) or upKey then
            setFlyAnim("Jump")
        elseif (isVertical and dir.Y < 0) or downKey then
            setFlyAnim("Fall")
        else
            if inputMag > 0.5 then
                setFlyAnim("Run")
            else
                setFlyAnim("Walk")
            end
        end
    end)
end

-- ================= 锁头 (Aimbot) =================
local AimbotConn = nil
local function ToggleAimbot(on)
    if AimbotConn then AimbotConn:Disconnect(); AimbotConn = nil end
    if not on then return end

    AimbotConn = RunService.RenderStepped:Connect(function()
        local closestHead, shortestDist = nil, CONFIG.AimbotFOV
        local center = Camera.ViewportSize / 2

        for _, p in ipairs(Players:GetPlayers()) do
            if not isAlly(p) and p.Character then
                local head = p.Character:FindFirstChild("Head")
                local hum = p.Character:FindFirstChildOfClass("Humanoid")
                
                if head and hum and hum.Health > 0 then
                    -- 转屏幕坐标
                    local screenPos, onScreen = Camera:WorldToViewportPoint(head.Position)
                    if onScreen then
                        local dist = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
                        if dist < shortestDist then
                            shortestDist = dist
                            closestHead = head
                        end
                    end
                end
            end
        end

        -- 锁定目标，平滑插值
        if closestHead then
            local targetCF = CFrame.new(Camera.CFrame.Position, closestHead.Position)
            Camera.CFrame = Camera.CFrame:Lerp(targetCF, 0.4)
        end
    end)
end

-- ================= ESP (敌友自动识别) =================
local ESPPlayerConn = nil
local ESPObjects = {}

local function RemoveESPFromPlayer(player)
    local char = player.Character
    if not char then return end
    local highlight = char:FindFirstChild("CG_ESP_Highlight")
    if highlight then highlight:Destroy() end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if hrp then
        local billboard = hrp:FindFirstChild("CG_ESP")
        if billboard then billboard:Destroy() end
    end
end

local function ClearESP()
    for _, p in ipairs(Players:GetPlayers()) do
        RemoveESPFromPlayer(p)
    end
    for _, obj in ipairs(ESPObjects) do
        if obj and obj.Parent then obj:Destroy() end
    end
    table.clear(ESPObjects)
    if ESPPlayerConn then ESPPlayerConn:Disconnect(); ESPPlayerConn = nil end
end

local function AddESP(player)
    if player == LP then return end
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    RemoveESPFromPlayer(player)

    local isEnemy = not isAlly(player)
    local mainColor = isEnemy and Color3.fromRGB(255, 50, 50) or Color3.fromRGB(50, 255, 50)
    local outlineColor = isEnemy and Color3.fromRGB(255, 100, 100) or Color3.fromRGB(100, 255, 100)

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "CG_ESP"
    billboard.Adornee = hrp
    billboard.Size = UDim2.new(0, 100, 0, 40)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.AlwaysOnTop = true
    billboard.Parent = hrp

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = (isEnemy and "[敌] " or "[友] ") .. player.Name
    label.TextColor3 = mainColor
    label.TextStrokeTransparency = 0
    label.Font = Enum.Font.GothamBold
    label.TextSize = 14
    label.Parent = billboard

    local highlight = Instance.new("Highlight")
    highlight.Name = "CG_ESP_Highlight"
    highlight.Adornee = char
    highlight.FillColor = mainColor
    highlight.FillTransparency = 0.65
    highlight.OutlineColor = outlineColor
    highlight.Parent = char

    table.insert(ESPObjects, billboard)
    table.insert(ESPObjects, highlight)
end

local function ToggleESP(on)
    ClearESP()
    if not on then return end

    for _, p in ipairs(Players:GetPlayers()) do AddESP(p) end

    ESPPlayerConn = Players.PlayerAdded:Connect(function(p)
        p.CharacterAdded:Connect(function()
            task.wait(0.5)
            if State.ESP then AddESP(p) end
        end)
    end)

    for _, p in ipairs(Players:GetPlayers()) do
        p.CharacterAdded:Connect(function()
            task.wait(0.5)
            if State.ESP then AddESP(p) end
        end)
    end
end

-- ================= 穿墙 =================
local NoclipConn = nil
local function ToggleNoclip(on)
    if NoclipConn then NoclipConn:Disconnect(); NoclipConn = nil end
    if not on then return end
    NoclipConn = RunService.Stepped:Connect(function()
        local char = LP.Character
        if not char then return end
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") and part.CanCollide then
                part.CanCollide = false
            end
        end
    end)
end

-- ================= 加强跳跃 =================
local origJump
local function ToggleJump(on)
    local char = LP.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    if on then
        origJump = hum.JumpPower
        hum.UseJumpPower = true
        hum.JumpPower = CONFIG.JumpPowerValue
    else
        if origJump then hum.JumpPower = origJump end
    end
end

-- ================= 加强移速 =================
local origSpeed
local function ToggleSpeed(on)
    local char = LP.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    if on then
        origSpeed = hum.WalkSpeed
        hum.WalkSpeed = CONFIG.WalkSpeedValue
    else
        if origSpeed then hum.WalkSpeed = origSpeed end
    end
end

-- ================= 绑定按钮 =================
CreateToggle("飞天 (Fly)", "Fly", function(on) ToggleFly(on) end)
CreateToggle("透视 (ESP)", "ESP", ToggleESP)
CreateToggle("穿墙 (Noclip)", "Noclip", ToggleNoclip)
CreateToggle("加强跳跃 (Jump)", "JumpPower", ToggleJump)
CreateToggle("加强移速 (Speed)", "Speed", ToggleSpeed)
CreateToggle("锁头 (Aimbot)", "Aimbot", ToggleAimbot) -- 新增锁头

-- ================= 重生处理 =================
LP.CharacterAdded:Connect(function()
    task.wait(0.8)
    if State.JumpPower then ToggleJump(true) end
    if State.Speed     then ToggleSpeed(true) end
    if State.Fly then
        cleanFly()
        ToggleFly(true)
    end
end)

-- ================= 关闭 =================
CloseBtn.MouseButton1Click:Connect(function()
    cleanFly()
    if NoclipConn then NoclipConn:Disconnect(); NoclipConn = nil end
    if AimbotConn then AimbotConn:Disconnect(); AimbotConn = nil end
    ClearESP()
    ScreenGui:Destroy()
end)

-- ================= 提示 =================
print("[概念神菜单] 已加载。仅限自己的私人体验使用。")