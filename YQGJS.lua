--[[
    概念神菜单 (Concept God Menu) - 终极修复版
    文件名: YQGJS.lua
    特性: 
      1. 摇杆自由飞行（视角指哪飞哪）
      2. 透视阵营自由切换（队伍/全红/全绿）
      3. 锁头防覆盖（BindToRenderStep）
      4. 穿墙强制推送（防止被服务器弹回）
]]

-- ================= 配置 =================
local CONFIG = {
    MenuName          = "概念神菜单",
    JumpPowerValue    = 120,
    WalkSpeedValue    = 80,
    FlySpeed          = 60,
    AimbotFOV         = 300,
    DesignW           = 420,
    DesignH           = 640,
}

-- 飞行动作包 ID (R15)
local FLY_ANIMS = {
    Idle = 619542203, Walk = 619544080, Run  = 619543231, Jump = 619542888, Fall = 619541867,
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
local ESPMode = 1 -- 1: 队伍识别, 2: 全部敌人, 3: 全部友军

-- ================= 敌友识别逻辑 =================
local function isAlly(player)
    if player == LP then return true end
    if ESPMode == 2 then return false end -- 全部敌人
    if ESPMode == 3 then return true end  -- 全部友军
    -- 队伍模式
    if LP.Team and player.Team then
        return LP.Team == player.Team
    end
    return false -- 没队伍的默认当敌人
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

-- ================= 主窗口 =================
local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Size = UDim2.new(0, 300, 0, 480)
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
    ScaleObj.Scale = math.clamp(s, 0.65, 1.30)
end
Camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
updateScale()

-- ================= 顶栏 =================
local Header = Instance.new("Frame")
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
    FoldBtn.Size = UDim2.new(0, 40, 0, 40); FoldBtn.Position = UDim2.new(1, -92, 0, 2)
    CloseBtn.Size = UDim2.new(0, 40, 0, 40); CloseBtn.Position = UDim2.new(1, -46, 0, 2)
    Header.Size = UDim2.new(1, 0, 0, 48)
end

-- ================= 拖动 =================
do
    local dragging, dragStart, startPos = false, nil, nil
    Header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true; dragStart = input.Position; startPos = Main.Position
        end
    end)
    UIS.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local d = input.Position - dragStart
            Main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
    UIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end)
end

-- ================= 功能列表 =================
local List = Instance.new("Frame")
List.Size = UDim2.new(1, 0, 1, -52)
List.Position = UDim2.new(0, 0, 0, 50)
List.BackgroundTransparency = 1
List.Parent = Main

local ListLayout = Instance.new("UIListLayout")
ListLayout.Padding = UDim.new(0, 8)
ListLayout.SortOrder = Enum.SortOrder.LayoutOrder
ListLayout.Parent = List

local ListPad = Instance.new("UIPadding")
ListPad.PaddingTop = UDim.new(0, 4); ListPad.PaddingLeft = UDim.new(0, 6); ListPad.PaddingRight = UDim.new(0, 6)
ListPad.Parent = List

local folded = false
FoldBtn.MouseButton1Click:Connect(function()
    folded = not folded
    List.Visible = not folded
    Main.Size = folded and UDim2.new(0, 300, 0, IS_MOBILE and 48 or 44) or UDim2.new(0, 300, 0, 480)
    FoldBtn.Text = folded and "+" or "-"
end)

-- ================= 按钮组件 =================
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

-- 特殊：循环切换按钮（用于阵营模式）
local function CreateCycleBtn(text, options, initialIdx, callback)
    local Btn = Instance.new("TextButton")
    Btn.Size = UDim2.new(1, 0, 0, BTN_H)
    Btn.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
    Btn.BackgroundTransparency = 0.25
    Btn.BorderSizePixel = 0
    Btn.TextColor3 = Color3.fromRGB(235,235,235)
    Btn.TextStrokeTransparency = 0.6
    Btn.Font = Enum.Font.GothamSemibold
    Btn.TextSize = IS_MOBILE and 17 or 15
    Btn.Parent = List
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
end

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
            -- 根据相机的视线方向飞行
            dir += camCF.LookVector * (-mv.Z)
            dir += camCF.RightVector * (mv.X)
        end

        -- 桌面端空格辅助上升
        if UIS:IsKeyDown(Enum.KeyCode.Space) then dir += Vector3.new(0,1,0) end
        if UIS:IsKeyDown(Enum.KeyCode.LeftShift) then dir -= Vector3.new(0,1,0) end

        if dir.Magnitude > 1e-4 then
            Fly.lv.VectorVelocity = dir.Unit * CONFIG.FlySpeed
        else
            Fly.lv.VectorVelocity = Vector3.zero
        end

        local lookFlat = Vector3.new(camCF.LookVector.X, 0, camCF.LookVector.Z)
        if lookFlat.Magnitude > 1e-4 then lookFlat = lookFlat.Unit end
        local yaw = math.atan2(-lookFlat.X, -lookFlat.Z)
        Fly.ao.CFrame = CFrame.new(Vector3.zero) * CFrame.Angles(0, yaw, 0)

        -- 动画匹配
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

-- ================= 锁头 (Aimbot) =================
local function ToggleAimbot(on)
    if not on then
        pcall(function() RunService:UnbindFromRenderStep("CG_Aimbot") end)
        return
    end

    -- 使用 BindToRenderStep 在相机更新之后覆盖视角
    RunService:BindToRenderStep("CG_Aimbot", Enum.RenderPriority.Camera.Value + 1, function()
        if not State.Aimbot then return end
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

        if closestHead then
            -- 强制覆盖相机的朝向来锁头
            local targetPos = closestHead.Position
            Camera.CFrame = CFrame.lookAt(Camera.CFrame.Position, targetPos)
        end
    end)
end

-- ================= ESP =================
local ESPPlayerConn = nil
local ESPObjects = {}

local function RemoveESPFromPlayer(player)
    local char = player.Character
    if not char then return end
    local h = char:FindFirstChild("CG_ESP_Highlight"); if h then h:Destroy() end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if hrp then
        local b = hrp:FindFirstChild("CG_ESP"); if b then b:Destroy() end
    end
end

local function ClearESP()
    for _, p in ipairs(Players:GetPlayers()) do RemoveESPFromPlayer(p) end
    for _, obj in ipairs(ESPObjects) do if obj and obj.Parent then obj:Destroy() end end
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

    local billboard = Instance.new("BillboardGui", hrp)
    billboard.Name = "CG_ESP"; billboard.Adornee = hrp; billboard.Size = UDim2.new(0, 100, 0, 40)
    billboard.StudsOffset = Vector3.new(0, 3, 0); billboard.AlwaysOnTop = true

    local label = Instance.new("TextLabel", billboard)
    label.Size = UDim2.new(1, 0, 1, 0); label.BackgroundTransparency = 1
    label.Text = (isEnemy and "[敌] " or "[友] ") .. player.Name
    label.TextColor3 = mainColor; label.TextStrokeTransparency = 0
    label.Font = Enum.Font.GothamBold; label.TextSize = 14

    local highlight = Instance.new("Highlight", char)
    highlight.Name = "CG_ESP_Highlight"; highlight.Adornee = char
    highlight.FillColor = mainColor; highlight.FillTransparency = 0.65; highlight.OutlineColor = outlineColor

    table.insert(ESPObjects, billboard); table.insert(ESPObjects, highlight)
end

local function RefreshESP()
    if not State.ESP then return end
    for _, p in ipairs(Players:GetPlayers()) do AddESP(p) end
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

-- ================= 穿墙 (防弹回版) =================
local NoclipConn = nil
local function ToggleNoclip(on)
    if NoclipConn then NoclipConn:Disconnect(); NoclipConn = nil end
    local char = LP.Character
    
    if not on then
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
        
        local hum = c:FindFirstChildOfClass("Humanoid")
        local hrp = c:FindFirstChild("HumanoidRootPart")
        if hum and hrp then
            hum.PlatformStand = true -- 屏蔽服务端物理回弹
            if hum.MoveDirection.Magnitude > 0.1 then
                -- 强行给前进方向施加推力，穿进墙里
                hrp.Velocity = hum.MoveDirection * 60
            else
                hrp.Velocity = Vector3.zero
            end
        end
    end)
end

-- ================= 跳跃 / 移速 =================
local origJump, origSpeed
local function ToggleJump(on)
    local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    if on then origJump = hum.JumpPower; hum.UseJumpPower = true; hum.JumpPower = CONFIG.JumpPowerValue
    else if origJump then hum.JumpPower = origJump end end
end

local function ToggleSpeed(on)
    local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    if on then origSpeed = hum.WalkSpeed; hum.WalkSpeed = CONFIG.WalkSpeedValue
    else if origSpeed then hum.WalkSpeed = origSpeed end end
end

-- ================= 绑定按钮 =================
CreateToggle("飞天 (Fly)", "Fly", function(on) ToggleFly(on) end)
CreateToggle("透视 (ESP)", "ESP", ToggleESP)
-- 插入阵营切换按钮
CreateCycleBtn("透视阵营", {"仅队伍识别", "全部视为敌人", "全部视为友军"}, 1, function(idx)
    ESPMode = idx
    RefreshESP() -- 切换后立刻刷新颜色
end)
CreateToggle("穿墙 (Noclip)", "Noclip", ToggleNoclip)
CreateToggle("加强跳跃 (Jump)", "JumpPower", ToggleJump)
CreateToggle("加强移速 (Speed)", "Speed", ToggleSpeed)
CreateToggle("锁头 (Aimbot)", "Aimbot", ToggleAimbot)

-- ================= 重生处理 =================
LP.CharacterAdded:Connect(function()
    task.wait(0.8)
    if State.JumpPower then ToggleJump(true) end
    if State.Speed then ToggleSpeed(true) end
    if State.Fly then cleanFly(); ToggleFly(true) end
    if State.Noclip then ToggleNoclip(true) end
end)

-- ================= 关闭 =================
CloseBtn.MouseButton1Click:Connect(function()
    cleanFly()
    if NoclipConn then NoclipConn:Disconnect(); end
    pcall(function() RunService:UnbindFromRenderStep("CG_Aimbot") end)
    ClearESP()
    ScreenGui:Destroy()
end)

print("[概念神菜单] 已加载终极修复版！")