--[[
    概念神菜单 (Concept God Menu) - 终极修复版 2.1
    文件名: YQGJS.lua
    修复：移速防回弹、穿墙不遁地、新增【指定锁头目标】功能
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
local AimbotTargetPlayer = nil -- 指定的锁头玩家(nil为自动锁敌)

-- ================= 敌友识别 =================
local function isAlly(player)
    if player == LP then return true end
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

-- ================= 主窗口 =================
local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Size = UDim2.new(0, 300, 0, 520) -- 稍微加高容纳新按钮
Main.Position = UDim2.new(0, 20, 0, 60)
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
    Main.Size = folded and UDim2.new(0, 300, 0, IS_MOBILE and 48 or 44) or UDim2.new(0, 300, 0, 520)
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
            dir += camCF.LookVector * (-mv.Z)
            dir += camCF.RightVector * (mv.X)
        end

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

    RunService:BindToRenderStep("CG_Aimbot", Enum.RenderPriority.Camera.Value + 1, function()
        if not State.Aimbot then return end
        local targetHead = nil

        -- 如果指定了目标且目标存活，则直接锁指定目标
        if AimbotTargetPlayer and AimbotTargetPlayer.Parent then
            local char = AimbotTargetPlayer.Character
            local head = char and char:FindFirstChild("Head")
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if head and hum and hum.Health > 0 then
                targetHead = head
            end
        else
            -- 否则走默认的“最近敌人”逻辑
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

        -- 执行锁头覆盖
        if targetHead then
            Camera.CFrame = CFrame.lookAt(Camera.CFrame.Position, targetHead.Position)
        end
    end)
end

-- ================= 锁头目标选择器 UI =================
local TargetSelectorGui = Instance.new("Frame")
TargetSelectorGui.Name = "TargetSelector"
TargetSelectorGui.Size = UDim2.new(0, 260, 0, 350)
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
TS_Title.Text = "选择锁头目标"
TS_Title.TextColor3 = Color3.fromRGB(255, 255, 255)
TS_Title.Font = Enum.Font.GothamBold
TS_Title.TextSize = 18
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
        if child:IsA("TextButton") then child:Destroy() end
    end

    -- 添加“取消指定”按钮
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
        Toggles["TargetSelectBtn"](false) -- 更新按钮文字
        TargetSelectorGui.Visible = false
    end)

    -- 遍历玩家
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP then
            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(1, -6, 0, 40)
            btn.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
            btn.Text = (p.Name == (AimbotTargetPlayer and AimbotTargetPlayer.Name)) and ("[已锁定] " .. p.Name) or p.Name
            btn.TextColor3 = isAlly(p) and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(255, 100, 100)
            btn.Font = Enum.Font.GothamSemibold
            btn.TextSize = 14
            btn.ZIndex = 11
            btn.Parent = TS_Scroll
            
            -- 让文字靠左显示
            btn.TextXAlignment = Enum.TextXAlignment.Left
            local pad = Instance.new("UIPadding", btn)
            pad.PaddingLeft = UDim.new(0, 10)
            
            corner(btn, 6)
            btn.MouseButton1Click:Connect(function()
                AimbotTargetPlayer = p
                Toggles["TargetSelectBtn"](false) -- 触发一次刷新文字
                TargetSelectorGui.Visible = false
            end)
        end
    end
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
        if State.Fly then return end
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
        hum.WalkSpeed = CONFIG.WalkSpeedValue
        SpeedConn = RunService.RenderStepped:Connect(function()
            local c = LP.Character
            local h = c and c:FindFirstChildOfClass("Humanoid")
            local root = c and c:FindFirstChild("HumanoidRootPart")
            if h and root and not State.Fly and not State.Noclip then
                h.WalkSpeed = CONFIG.WalkSpeedValue
                if h.MoveDirection.Magnitude > 0.1 then
                    local addSpeed = (CONFIG.WalkSpeedValue - 16) * 0.02
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
    if on then origJump = hum.JumpPower; hum.UseJumpPower = true; hum.JumpPower = CONFIG.JumpPowerValue
    else if origJump then hum.JumpPower = origJump end end
end

-- ================= 绑定按钮 =================
CreateToggle("飞天 (Fly)", "Fly", function(on) ToggleFly(on) end)
CreateToggle("透视 (ESP)", "ESP", ToggleESP)
CreateCycleBtn("透视阵营", {"仅队伍识别", "全部视为敌人", "全部视为友军"}, 1, function(idx)
    ESPMode = idx
    RefreshESP()
end)
CreateToggle("穿墙 (Noclip)", "Noclip", ToggleNoclip)
CreateToggle("加强跳跃 (Jump)", "JumpPower", ToggleJump)
CreateToggle("加强移速 (Speed)", "Speed", ToggleSpeed)

-- 锁头开关
CreateToggle("锁头 (Aimbot)", "Aimbot", ToggleAimbot)

-- 目标选择按钮
local TargetBtn = Instance.new("TextButton")
TargetBtn.Size = UDim2.new(1, 0, 0, BTN_H)
TargetBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
TargetBtn.BorderSizePixel = 0
TargetBtn.TextColor3 = Color3.fromRGB(235,235,235)
TargetBtn.Font = Enum.Font.GothamSemibold
TargetBtn.TextSize = IS_MOBILE and 17 or 15
TargetBtn.Parent = List
corner(TargetBtn, 8)
stroke(TargetBtn, Color3.fromRGB(80,80,100), 1)

TargetBtn.MouseButton1Click:Connect(function()
    RefreshTargetList()
    TargetSelectorGui.Visible = true
end)

-- 动态更新目标按钮的文字
Toggles["TargetSelectBtn"] = function()
    if AimbotTargetPlayer then
        TargetBtn.Text = "当前目标: " .. AimbotTargetPlayer.Name
        TargetBtn.BackgroundColor3 = Color3.fromRGB(55, 140, 90)
    else
        TargetBtn.Text = "选择锁头目标 (当前: 自动)"
        TargetBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    end
end
Toggles["TargetSelectBtn"]() -- 初始化文字

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
    if SpeedConn then SpeedConn:Disconnect(); end
    pcall(function() RunService:UnbindFromRenderStep("CG_Aimbot") end)
    ClearESP()
    ScreenGui:Destroy()
end)

print("[概念神菜单] 已加载！包含目标选择器。")