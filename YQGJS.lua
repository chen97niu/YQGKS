--[[
    概念神菜单 (Concept God Menu) - 透明背景 / 手机适配版
    文件名: YQGJS.lua
    特性: 已升级新版物理引擎 (LinearVelocity + AlignOrientation)，加强 ESP 对象回收
    手机飞行：左侧 = Roblox 自带摇杆(前后左右)，右侧滑动 = 升降
]]

-- ================= 配置 =================
local CONFIG = {
    MenuName          = "概念神菜单",
    JumpPowerValue    = 120,
    WalkSpeedValue    = 80,
    FlySpeed          = 60,
    -- 右侧滑动多少像素达到满速升降（越小越灵敏）
    FlyVertSensitivity = 200,
    DesignW           = 420,
    DesignH           = 640,
}

-- ================= 服务 =================
local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS        = game:GetService("UserInputService")
local CoreGui    = game:GetService("CoreGui")

local LP     = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local IS_TOUCH  = UIS.TouchEnabled
local IS_MOBILE = IS_TOUCH   -- 仅用于 UI 大小适配

-- ================= 状态 =================
local State = {
    Fly=false, ESP=false, Noclip=false, JumpPower=false, Speed=false,
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
Main.Size = UDim2.new(0, 300, 0, 400)
Main.Position = UDim2.new(0, 20, 0, 90)   -- 放左上，右侧留给滑动升降
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
                           or UDim2.new(0, 300, 0, 400)
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

-- ================= 飞行（新版物理约束） =================
local Fly = {
    conn = nil, lv = nil, ao = nil, att = nil,
    inputBegan = nil, inputEnded = nil,
}
local upKey, downKey = false, false

-- 右侧滑动升降
local RightTouch, RightStartY, VertInput = nil, 0, 0
local tStart, tMove, tEnd, tCancel = nil, nil, nil, nil

local function resetVert()
    RightTouch = nil
    RightStartY = 0
    VertInput = 0
end

local function teardownMobileFlightInput()
    if tStart  then tStart:Disconnect();  tStart  = nil end
    if tMove   then tMove:Disconnect();   tMove   = nil end
    if tEnd    then tEnd:Disconnect();    tEnd    = nil end
    if tCancel then tCancel:Disconnect(); tCancel = nil end
    resetVert()
end

local function setupMobileFlightInput()
    if not IS_TOUCH then return end
    teardownMobileFlightInput()

    tStart = UIS.TouchStarted:Connect(function(input, gp)
        if gp then return end
        if not State.Fly then return end
        local vp = Camera.ViewportSize
        if input.Position.X >= vp.X * 0.5 and RightTouch == nil then
            RightTouch = input
            RightStartY = input.Position.Y
            VertInput = 0
        end
    end)
    tMove = UIS.TouchMoved:Connect(function(input)
        if RightTouch and input == RightTouch and State.Fly then
            local dy = input.Position.Y - RightStartY
            -- 向上滑(dy<0) 上升；向下滑(dy>0) 下降
            VertInput = math.clamp(-dy / CONFIG.FlyVertSensitivity, -1, 1)
        end
    end)
    tEnd = UIS.TouchEnded:Connect(function(input)
        if RightTouch and input == RightTouch then
            resetVert()
        end
    end)
    tCancel = UIS.TouchEnded:Connect(function() resetVert() end) -- 兜底
end

local function cleanFly()
    if Fly.conn       then Fly.conn:Disconnect();       Fly.conn = nil end
    if Fly.inputBegan then Fly.inputBegan:Disconnect(); Fly.inputBegan = nil end
    if Fly.inputEnded then Fly.inputEnded:Disconnect(); Fly.inputEnded = nil end
    if Fly.lv         then Fly.lv:Destroy();            Fly.lv = nil end
    if Fly.ao         then Fly.ao:Destroy();            Fly.ao = nil end
    if Fly.att        then Fly.att:Destroy();           Fly.att = nil end
    teardownMobileFlightInput()
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
    if not hrp then return end

    if hum then hum.PlatformStand = true end

    -- 新版物理移动器：基于 Attachment
    Fly.att = Instance.new("Attachment")
    Fly.att.Name = "CG_FlyAtt"
    Fly.att.Parent = hrp

    -- 线性速度 (代替 BodyVelocity)
    Fly.lv = Instance.new("LinearVelocity")
    Fly.lv.Name = "CG_FlyLV"
    Fly.lv.Attachment0 = Fly.att
    Fly.lv.MaxForce = 1e5
    Fly.lv.VectorVelocity = Vector3.zero
    Fly.lv.Parent = hrp

    -- 对齐朝向 (代替 BodyGyro)
    Fly.ao = Instance.new("AlignOrientation")
    Fly.ao.Name = "CG_FlyAO"
    Fly.ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
    Fly.ao.Attachment0 = Fly.att
    Fly.ao.MaxTorque = 1e5
    Fly.ao.RigidityEnabled = true -- 刚性对齐，避免镜头转动时角色甩尾
    Fly.ao.Parent = hrp

    -- 桌面：Space 升 / Shift 降
    if UIS.KeyboardEnabled then
        Fly.inputBegan = UIS.InputBegan:Connect(function(i, gp)
            if gp then return end
            if i.KeyCode == Enum.KeyCode.Space then upKey = true end
            if i.KeyCode == Enum.KeyCode.LeftShift then downKey = true end
        end)
        Fly.inputEnded = UIS.InputEnded:Connect(function(i)
            if i.KeyCode == Enum.KeyCode.Space then upKey = false end
            if i.KeyCode == Enum.KeyCode.LeftShift then downKey = false end
        end)
    end

    -- 手机：右侧滑动升降
    if IS_TOUCH then setupMobileFlightInput() end

    -- 每帧控制
    Fly.conn = RunService.RenderStepped:Connect(function()
        local c = LP.Character
        local root = c and c:FindFirstChild("HumanoidRootPart")
        if not root or not Fly.lv or not Fly.ao then return end

        local cam = workspace.CurrentCamera
        local camCF = cam.CFrame

        local lookFlat = Vector3.new(camCF.LookVector.X, 0, camCF.LookVector.Z)
        if lookFlat.Magnitude > 1e-4 then lookFlat = lookFlat.Unit end
        local rightFlat = Vector3.new(camCF.RightVector.X, 0, camCF.RightVector.Z)
        if rightFlat.Magnitude > 1e-4 then rightFlat = rightFlat.Unit end

        -- 1) 水平：读 Roblox 自带摇杆（手机）或键盘 WASD（桌面）
        local mv = Vector3.zero
        local ctl = getControls()
        if ctl then
            local ok, v = pcall(function() return ctl:GetMoveVector() end)
            if ok and typeof(v) == "Vector3" then mv = v end
        end

        local dir = Vector3.zero
        dir += lookFlat  * (-mv.Z)     -- 前推 -> 前进；后推 -> 后退
        dir += rightFlat * ( mv.X)     -- 左 -> 左；右 -> 右

        -- 2) 垂直：右侧滑动 + 桌面 Space/Shift 叠加
        local vy = VertInput
        if upKey   then vy += 1 end
        if downKey then vy -= 1 end
        vy = math.clamp(vy, -1, 1)
        dir += Vector3.new(0, vy, 0)

        -- 3) 应用速度
        if dir.Magnitude > 1e-4 then
            Fly.lv.VectorVelocity = dir.Unit * CONFIG.FlySpeed
        else
            Fly.lv.VectorVelocity = Vector3.zero
        end

        -- 4) 角色保持直立、朝相机水平方向（不会俯仰翻滚）
        local yaw = math.atan2(-lookFlat.X, -lookFlat.Z)
        Fly.ao.CFrame = CFrame.new(Vector3.zero) * CFrame.Angles(0, yaw, 0)
    end)
end

-- ================= ESP（加强回收机制） =================
local ESPPlayerConn = nil
local ESPObjects = {}

-- 彻底清理某个玩家角色上的 ESP 残留
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

    -- 每次添加前，先确保清理掉旧对象，防止重复叠加
    RemoveESPFromPlayer(player)

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
    label.Text = player.Name
    label.TextColor3 = Color3.fromRGB(255,90,90)
    label.TextStrokeTransparency = 0
    label.Font = Enum.Font.GothamBold
    label.TextSize = 14
    label.Parent = billboard

    local highlight = Instance.new("Highlight")
    highlight.Name = "CG_ESP_Highlight"
    highlight.Adornee = char
    highlight.FillColor = Color3.fromRGB(255,0,0)
    highlight.FillTransparency = 0.65
    highlight.OutlineColor = Color3.fromRGB(255,90,90)
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
    ClearESP()
    ScreenGui:Destroy()
end)

-- ================= 提示 =================
print("[概念神菜单] 已加载。仅限自己的私人体验使用。")
if IS_TOUCH then
    print("[概念神菜单] 手机飞行操作：左摇杆 = 前后左右；右侧滑屏 = 上升/下降")
end