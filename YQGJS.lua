--[[
    概念神菜单 (Concept God Menu) - 终极版 2.2 【美化版】
    文件名: YQGJS.lua
    特性：多档位调节、手动标友、飞行穿墙、指定锁头

    ★ 美化说明：本版只重构 UI 视觉层（配色 / 字体 / 圆角 / 渐变 / 分组 / 动效）
      所有功能逻辑、档位参数、回调绑定一概未动。
]]

-- ================= 全局配置（原样·未动） =================
local CONFIG = {
    MenuName          = "概念神菜单",
    AimbotFOV         = 300,
    DesignW           = 420,
    DesignH           = 640,

    -- 档位数组
    FlySpeeds         = {40, 80, 120, 200},      -- 慢，中，快，超快
    JumpPowers        = {80, 120, 200, 300},     -- 正常，加强，超高，飞天
    WalkSpeeds        = {40, 80, 150, 250},      -- 快跑，疾跑，瞬移，光速

    -- 默认档位索引
    FlySpeedIdx       = 1,
    JumpPowerIdx      = 1,
    WalkSpeedIdx      = 1,
}

-- 飞行动作包 ID (R15)
local FLY_ANIMS = {
    Idle = 619542203, Walk = 619544080, Run  = 619543231, Jump = 619542888, Fall = 619541867,
}

-- ================= 服务（新增 TweenService·纯视觉用） =================
local Players       = game:GetService("Players")
local RunService    = game:GetService("RunService")
local UIS           = game:GetService("UserInputService")
local CoreGui       = game:GetService("CoreGui")
local TweenService  = game:GetService("TweenService")

local LP     = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local IS_TOUCH  = UIS.TouchEnabled
local IS_MOBILE = IS_TOUCH

-- ================= 视觉主题（新增·纯视觉） =================
local THEME = {
    Bg        = Color3.fromRGB(13, 15, 22),    -- 窗口底色
    BgLight   = Color3.fromRGB(19, 21, 31),   -- 渐变亮端
    Card      = Color3.fromRGB(24, 27, 38),   -- 按钮卡片
    CardHover = Color3.fromRGB(31, 35, 49),   -- 悬停
    CardOn    = Color3.fromRGB(22, 32, 46),   -- 开启态卡片
    Accent    = Color3.fromRGB(86, 204, 242), -- 青色主色
    Accent2   = Color3.fromRGB(167, 139, 250),-- 紫色辅色
    Off       = Color3.fromRGB(43, 47, 62),   -- 关闭胶囊
    Text      = Color3.fromRGB(240, 243, 250),
    SubText   = Color3.fromRGB(142, 150, 170),
    Stroke    = Color3.fromRGB(52, 57, 76),
    Danger    = Color3.fromRGB(228, 76, 96),
    Ally      = Color3.fromRGB(94, 214, 154),
    Enemy     = Color3.fromRGB(248, 113, 124),
    PillTextOn= Color3.fromRGB(8, 14, 22),
}

local WIN_W, WIN_H = 320, 560
local HDR_H   = IS_MOBILE and 52 or 48
local BTN_H   = IS_MOBILE and 50 or 44
local NAME_SZ = IS_MOBILE and 16 or 14
local PILL_SZ = IS_MOBILE and 13 or 12

-- ================= 状态（原样·未动） =================
local State = {
    Fly=false, ESP=false, Noclip=false, JumpPower=false, Speed=false, Aimbot=false,
}
local ESPMode = 1 -- 1: 队伍识别, 2: 全部敌人, 3: 全部友军
local AimbotTargetPlayer = nil
local ManualAllies = {} -- 手动标记的队友名单

-- ================= 敌友识别（原样·未动） =================
local function isAlly(player)
    if player == LP then return true end
    -- 优先判断手动标记
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

local function stroke(parent, color, thickness, transparency)
    local s = Instance.new("UIStroke")
    s.Color = color or Color3.fromRGB(255,255,255)
    s.Thickness = thickness or 1
    s.Transparency = transparency or 0.5
    s.Parent = parent
    return s
end

local function grad(parent, c1, c2, rotation)
    local g = Instance.new("UIGradient")
    g.Color = ColorSequence.new(c1, c2)
    g.Rotation = rotation or 90
    g.Parent = parent
    return g
end

-- ================= 旧 UI 清理（原样·未动） =================
local old = CoreGui:FindFirstChild("ConceptGodMenu")
if old then old:Destroy() end

-- ================= ScreenGui（原样·未动） =================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "ConceptGodMenu"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.IgnoreGuiInset = true

local okParent = pcall(function() ScreenGui.Parent = CoreGui end)
if not okParent then ScreenGui.Parent = LP:WaitForChild("PlayerGui") end

-- ================= 主窗口（美化：实体卡片窗口） =================
local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Size = UDim2.new(0, WIN_W, 0, WIN_H)
Main.Position = UDim2.new(0, 20, 0, 60)
Main.BackgroundColor3 = THEME.Bg
Main.BorderSizePixel = 0
Main.Active = true
Main.ClipsDescendants = true
Main.Parent = ScreenGui
corner(Main, 14)
stroke(Main, THEME.Stroke, 1, 0.35)
grad(Main, THEME.BgLight, THEME.Bg, 100)

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

-- ================= 顶栏（美化：Logo + 渐变分隔线） =================
local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, HDR_H)
Header.BackgroundTransparency = 1
Header.BorderSizePixel = 0
Header.Parent = Main

-- Logo 徽章
local Logo = Instance.new("Frame")
Logo.Size = UDim2.new(0, 28, 0, 28)
Logo.Position = UDim2.new(0, 12, 0.5, 0)
Logo.AnchorPoint = Vector2.new(0, 0.5)
Logo.BackgroundColor3 = Color3.White
Logo.BorderSizePixel = 0
Logo.Parent = Header
corner(Logo, 8)
grad(Logo, THEME.Accent, THEME.Accent2, 45)

local LogoText = Instance.new("TextLabel")
LogoText.Size = UDim2.new(1, 0, 1, 0)
LogoText.BackgroundTransparency = 1
LogoText.Text = "神"
LogoText.TextColor3 = Color3.fromRGB(255, 255, 255)
LogoText.Font = Enum.Font.GothamBold
LogoText.TextSize = 14
LogoText.Parent = Logo

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -110, 1, 0)
Title.Position = UDim2.new(0, 48, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = CONFIG.MenuName
Title.TextColor3 = THEME.Text
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Font = Enum.Font.GothamBold
Title.TextSize = 18
Title.Parent = Header

local FoldBtn = Instance.new("TextButton")
FoldBtn.Size = UDim2.new(0, 30, 0, 30)
FoldBtn.Position = UDim2.new(1, -72, 0.5, 0)
FoldBtn.AnchorPoint = Vector2.new(0, 0.5)
FoldBtn.BackgroundColor3 = THEME.Card
FoldBtn.BackgroundTransparency = 0.35
FoldBtn.BorderSizePixel = 0
FoldBtn.Text = "-"
FoldBtn.TextColor3 = THEME.SubText
FoldBtn.Font = Enum.Font.GothamBold
FoldBtn.TextSize = 16
FoldBtn.AutoButtonColor = false
FoldBtn.Parent = Header
corner(FoldBtn, 15)
stroke(FoldBtn, THEME.Stroke, 1, 0.4)

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 30, 0, 30)
CloseBtn.Position = UDim2.new(1, -36, 0.5, 0)
CloseBtn.AnchorPoint = Vector2.new(0, 0.5)
CloseBtn.BackgroundColor3 = THEME.Danger
CloseBtn.BackgroundTransparency = 0.55
CloseBtn.BorderSizePixel = 0
CloseBtn.Text = "X"
CloseBtn.TextColor3 = Color3.fromRGB(255, 220, 224)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 14
CloseBtn.AutoButtonColor = false
CloseBtn.Parent = Header
corner(CloseBtn, 15)
stroke(CloseBtn, THEME.Danger, 1, 0.35)

-- 顶栏底部渐变分隔线
local SepLine = Instance.new("Frame")
SepLine.AnchorPoint = Vector2.new(0.5, 1)
SepLine.Position = UDim2.new(0.5, 0, 1, 0)
SepLine.Size = UDim2.new(1, -32, 0, 2)
SepLine.BackgroundColor3 = Color3.White
SepLine.BorderSizePixel = 0
SepLine.Parent = Header
local SepGrad = Instance.new("UIGradient")
SepGrad.Color = ColorSequence.new(THEME.Accent, THEME.Accent2)
SepGrad.Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 0.92),
    NumberSequenceKeypoint.new(0.2, 0.15),
    NumberSequenceKeypoint.new(0.8, 0.15),
    NumberSequenceKeypoint.new(1, 0.92),
})
SepGrad.Parent = SepLine

if IS_MOBILE then
    FoldBtn.Size = UDim2.new(0, 36, 0, 36)
    CloseBtn.Size = UDim2.new(0, 36, 0, 36)
    FoldBtn.Position = UDim2.new(1, -84, 0.5, 0)
    CloseBtn.Position = UDim2.new(1, -42, 0.5, 0)
end

-- ================= 拖动（原样·未动） =================
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

-- ================= 功能列表（美化：滚动框视觉） =================
local List = Instance.new("ScrollingFrame")
List.Size = UDim2.new(1, 0, 1, -(HDR_H + 4))
List.Position = UDim2.new(0, 0, 0, HDR_H + 2)
List.BackgroundTransparency = 1
List.BorderSizePixel = 0
List.ScrollBarThickness = 3
List.ScrollBarImageColor3 = THEME.Accent
List.ScrollBarImageTransparency = 0.4
List.CanvasSize = UDim2.new(0, 0, 0, 0)
List.AutomaticCanvasSize = Enum.AutomaticSize.Y
List.Parent = Main

local ListLayout = Instance.new("UIListLayout")
ListLayout.Padding = UDim.new(0, 8)
ListLayout.SortOrder = Enum.SortOrder.LayoutOrder
ListLayout.Parent = List

local ListPad = Instance.new("UIPadding")
ListPad.PaddingTop = UDim.new(0, 8); ListPad.PaddingLeft = UDim.new(0, 8); ListPad.PaddingRight = UDim.new(0, 8)
ListPad.Parent = List

local folded = false
FoldBtn.MouseButton1Click:Connect(function()
    folded = not folded
    local target = folded and UDim2.new(0, WIN_W, 0, HDR_H) or UDim2.new(0, WIN_W, 0, WIN_H)
    if folded then
        local tw = TweenService:Create(Main, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Size = target})
        tw.Completed:Connect(function() if folded then List.Visible = false end end)
        tw:Play()
    else
        List.Visible = true
        TweenService:Create(Main, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Size = target}):Play()
    end
    FoldBtn.Text = folded and "+" or "-"
end)

-- ================= 按钮组件（美化：卡片+状态胶囊，接口不变） =================
local Toggles = {}

-- 分区小标题（纯视觉）
local function CreateSection(title)
    local Sec = Instance.new("Frame")
    Sec.Size = UDim2.new(1, 0, 0, 22)
    Sec.BackgroundTransparency = 1
    Sec.Parent = List

    local Bar = Instance.new("Frame")
    Bar.Size = UDim2.new(0, 3, 0, 11)
    Bar.Position = UDim2.new(0, 4, 0.5, 0)
    Bar.AnchorPoint = Vector2.new(0, 0.5)
    Bar.BackgroundColor3 = Color3.White
    Bar.BorderSizePixel = 0
    Bar.Parent = Sec
    corner(Bar, 2)
    grad(Bar, THEME.Accent, THEME.Accent2, 90)

    local Lbl = Instance.new("TextLabel")
    Lbl.Size = UDim2.new(1, -20, 1, 0)
    Lbl.Position = UDim2.new(0, 14, 0, 0)
    Lbl.BackgroundTransparency = 1
    Lbl.Text = title
    Lbl.TextColor3 = THEME.SubText
    Lbl.TextXAlignment = Enum.TextXAlignment.Left
    Lbl.Font = Enum.Font.GothamBold
    Lbl.TextSize = IS_MOBILE and 12 or 11
    Lbl.Parent = Sec
end

local function CreateToggle(text, key, callback)
    local Btn = Instance.new("TextButton")
    Btn.Size = UDim2.new(1, 0, 0, BTN_H)
    Btn.BackgroundColor3 = THEME.Card
    Btn.BorderSizePixel = 0
    Btn.Text = ""
    Btn.AutoButtonColor = false
    Btn.Parent = List
    corner(Btn, 10)
    local st = stroke(Btn, THEME.Stroke, 1)

    local NameLbl = Instance.new("TextLabel")
    NameLbl.Size = UDim2.new(1, -86, 1, 0)
    NameLbl.Position = UDim2.new(0, 14, 0, 0)
    NameLbl.BackgroundTransparency = 1
    NameLbl.Text = text
    NameLbl.TextColor3 = THEME.Text
    NameLbl.TextXAlignment = Enum.TextXAlignment.Left
    NameLbl.Font = Enum.Font.GothamMedium
    NameLbl.TextSize = NAME_SZ
    NameLbl.Parent = Btn

    local Pill = Instance.new("Frame")
    Pill.AnchorPoint = Vector2.new(1, 0.5)
    Pill.Position = UDim2.new(1, -12, 0.5, 0)
    Pill.Size = UDim2.new(0, 52, 0, 26)
    Pill.BackgroundColor3 = THEME.Off
    Pill.BorderSizePixel = 0
    Pill.Parent = Btn
    corner(Pill, 13)

    local PillText = Instance.new("TextLabel")
    PillText.Size = UDim2.new(1, 0, 1, 0)
    PillText.BackgroundTransparency = 1
    PillText.Text = "关"
    PillText.TextColor3 = THEME.SubText
    PillText.Font = Enum.Font.GothamBold
    PillText.TextSize = PILL_SZ
    PillText.Parent = Pill

    local on = false
    local function refresh()
        PillText.Text = on and "开" or "关"
        if on then
            TweenService:Create(Pill, TweenInfo.new(0.18), {BackgroundColor3 = THEME.Accent}):Play()
            TweenService:Create(PillText, TweenInfo.new(0.18), {TextColor3 = THEME.PillTextOn}):Play()
            TweenService:Create(Btn, TweenInfo.new(0.18), {BackgroundColor3 = THEME.CardOn}):Play()
            TweenService:Create(st, TweenInfo.new(0.18), {Color = THEME.Accent, Transparency = 0.15}):Play()
            TweenService:Create(NameLbl, TweenInfo.new(0.18), {TextColor3 = THEME.Text}):Play()
        else
            TweenService:Create(Pill, TweenInfo.new(0.18), {BackgroundColor3 = THEME.Off}):Play()
            TweenService:Create(PillText, TweenInfo.new(0.18), {TextColor3 = THEME.SubText}):Play()
            TweenService:Create(Btn, TweenInfo.new(0.18), {BackgroundColor3 = THEME.Card}):Play()
            TweenService:Create(st, TweenInfo.new(0.18), {Color = THEME.Stroke, Transparency = 0.5}):Play()
        end
    end

    if not IS_MOBILE then
        Btn.MouseEnter:Connect(function()
            if not on then TweenService:Create(Btn, TweenInfo.new(0.15), {BackgroundColor3 = THEME.CardHover}):Play() end
        end)
        Btn.MouseLeave:Connect(function() refresh() end)
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
    Btn.BackgroundColor3 = THEME.Card
    Btn.BorderSizePixel = 0
    Btn.Text = ""
    Btn.AutoButtonColor = false
    Btn.Parent = List
    corner(Btn, 10)
    local st = stroke(Btn, THEME.Stroke, 1)

    local NameLbl = Instance.new("TextLabel")
    NameLbl.Size = UDim2.new(1, -106, 1, 0)
    NameLbl.Position = UDim2.new(0, 14, 0, 0)
    NameLbl.BackgroundTransparency = 1
    NameLbl.Text = text
    NameLbl.TextColor3 = THEME.Text
    NameLbl.TextXAlignment = Enum.TextXAlignment.Left
    NameLbl.Font = Enum.Font.GothamMedium
    NameLbl.TextSize = NAME_SZ
    NameLbl.Parent = Btn

    local Pill = Instance.new("Frame")
    Pill.AnchorPoint = Vector2.new(1, 0.5)
    Pill.Position = UDim2.new(1, -12, 0.5, 0)
    Pill.Size = UDim2.new(0, 68, 0, 26)
    Pill.BackgroundTransparency = 0.82
    Pill.BackgroundColor3 = THEME.Accent
    Pill.BorderSizePixel = 0
    Pill.Parent = Btn
    corner(Pill, 13)
    local pst = stroke(Pill, THEME.Accent, 1, 0.35)

    local PillText = Instance.new("TextLabel")
    PillText.Size = UDim2.new(1, 0, 1, 0)
    PillText.BackgroundTransparency = 1
    PillText.Text = ""
    PillText.TextColor3 = THEME.Accent
    PillText.Font = Enum.Font.GothamBold
    PillText.TextSize = PILL_SZ
    PillText.Parent = Pill

    local idx = initialIdx
    local function refresh()
        PillText.Text = options[idx]
    end

    if not IS_MOBILE then
        Btn.MouseEnter:Connect(function()
            TweenService:Create(Btn, TweenInfo.new(0.15), {BackgroundColor3 = THEME.CardHover}):Play()
        end)
        Btn.MouseLeave:Connect(function()
            TweenService:Create(Btn, TweenInfo.new(0.15), {BackgroundColor3 = THEME.Card}):Play()
        end)
    end

    Btn.MouseButton1Click:Connect(function()
        idx = idx + 1
        if idx > #options then idx = 1 end
        refresh()
        -- 点击闪光
        TweenService:Create(Pill, TweenInfo.new(0.09), {BackgroundTransparency = 0.45}):Play()
        task.delay(0.1, function()
            if Btn.Parent then TweenService:Create(Pill, TweenInfo.new(0.25), {BackgroundTransparency = 0.82}):Play() end
        end)
        if callback then callback(idx) end
    end)
    refresh()
    return Btn
end

-- ================= 摇杆读取（原样·未动） =================
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

-- ================= 飞行系统（原样·未动） =================
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

        -- 应用选择的飞行速度档位
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

-- ================= 锁头 (Aimbot)（原样·未动） =================
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
            if head and hum and hum.Health > 0 then
                targetHead = head
            end
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

-- ================= 目标选择器 UI（美化：卡片风弹窗） =================
local TargetSelectorGui = Instance.new("Frame")
TargetSelectorGui.Name = "TargetSelector"
TargetSelectorGui.Size = UDim2.new(0, 300, 0, 400)
TargetSelectorGui.Position = UDim2.new(0.5, 0, 0.5, 0)
TargetSelectorGui.AnchorPoint = Vector2.new(0.5, 0.5)
TargetSelectorGui.BackgroundColor3 = THEME.Bg
TargetSelectorGui.BackgroundTransparency = 0.04
TargetSelectorGui.BorderSizePixel = 0
TargetSelectorGui.Visible = false
TargetSelectorGui.ZIndex = 10
TargetSelectorGui.Parent = ScreenGui
corner(TargetSelectorGui, 14)
stroke(TargetSelectorGui, THEME.Accent, 1, 0.45)
grad(TargetSelectorGui, THEME.BgLight, THEME.Bg, 100)

local TS_Title = Instance.new("TextLabel")
TS_Title.Size = UDim2.new(1, -50, 0, 44)
TS_Title.Position = UDim2.new(0, 14, 0, 0)
TS_Title.BackgroundTransparency = 1
TS_Title.Text = "目标设置 (手动标友/锁头)"
TS_Title.TextColor3 = THEME.Text
TS_Title.TextXAlignment = Enum.TextXAlignment.Left
TS_Title.Font = Enum.Font.GothamBold
TS_Title.TextSize = 15
TS_Title.ZIndex = 11
TS_Title.Parent = TargetSelectorGui

local TS_Close = Instance.new("TextButton")
TS_Close.Size = UDim2.new(0, 28, 0, 28)
TS_Close.Position = UDim2.new(1, -36, 0, 8)
TS_Close.BackgroundColor3 = THEME.Danger
TS_Close.BackgroundTransparency = 0.55
TS_Close.BorderSizePixel = 0
TS_Close.Text = "X"
TS_Close.TextColor3 = Color3.fromRGB(255, 220, 224)
TS_Close.Font = Enum.Font.GothamBold
TS_Close.TextSize = 13
TS_Close.AutoButtonColor = false
TS_Close.ZIndex = 11
TS_Close.Parent = TargetSelectorGui
corner(TS_Close, 14)
stroke(TS_Close, THEME.Danger, 1, 0.35)
TS_Close.MouseButton1Click:Connect(function() TargetSelectorGui.Visible = false end)

local TS_Scroll = Instance.new("ScrollingFrame")
TS_Scroll.Size = UDim2.new(1, -20, 1, -56)
TS_Scroll.Position = UDim2.new(0, 10, 0, 46)
TS_Scroll.BackgroundTransparency = 1
TS_Scroll.BorderSizePixel = 0
TS_Scroll.ScrollBarThickness = 3
TS_Scroll.ScrollBarImageColor3 = THEME.Accent
TS_Scroll.ScrollBarImageTransparency = 0.4
TS_Scroll.ZIndex = 11
TS_Scroll.Parent = TargetSelectorGui

local TS_Layout = Instance.new("UIListLayout")
TS_Layout.Padding = UDim.new(0, 6)
TS_Layout.SortOrder = Enum.SortOrder.LayoutOrder
TS_Layout.Parent = TS_Scroll

local TS_Pad = Instance.new("UIPadding")
TS_Pad.PaddingTop = UDim.new(0, 2)
TS_Pad.Parent = TS_Scroll

local function RefreshTargetList()
    for _, child in ipairs(TS_Scroll:GetChildren()) do
        if child:IsA("Frame") or child:IsA("TextButton") then child:Destroy() end
    end

    local cancelBtn = Instance.new("TextButton")
    cancelBtn.Size = UDim2.new(1, -6, 0, 40)
    cancelBtn.BackgroundColor3 = THEME.Card
    cancelBtn.BackgroundTransparency = 0.6
    cancelBtn.BorderSizePixel = 0
    cancelBtn.Text = "恢复自动锁敌 (取消指定)"
    cancelBtn.TextColor3 = THEME.Text
    cancelBtn.Font = Enum.Font.GothamSemibold
    cancelBtn.TextSize = 14
    cancelBtn.AutoButtonColor = false
    cancelBtn.ZIndex = 11
    cancelBtn.Parent = TS_Scroll
    corner(cancelBtn, 10)
    stroke(cancelBtn, THEME.Accent, 1, 0.4)
    cancelBtn.MouseButton1Click:Connect(function()
        AimbotTargetPlayer = nil
        Toggles["TargetSelectBtn"]()
        TargetSelectorGui.Visible = false
    end)

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP then
            local isLockedNow = (p.Name == (AimbotTargetPlayer and AimbotTargetPlayer.Name))

            local row = Instance.new("Frame")
            row.Size = UDim2.new(1, -6, 0, 42)
            row.BackgroundColor3 = isLockedNow and THEME.CardOn or THEME.Card
            row.BorderSizePixel = 0
            row.ZIndex = 11
            row.Parent = TS_Scroll
            corner(row, 10)
            local rst = stroke(row, isLockedNow and THEME.Accent or THEME.Stroke, 1, isLockedNow and 0.2 or 0.5)

            -- 锁定按钮
            local btnLock = Instance.new("TextButton")
            btnLock.Size = UDim2.new(0.6, 0, 1, -8)
            btnLock.Position = UDim2.new(0, 8, 0, 4)
            btnLock.BackgroundTransparency = 1
            btnLock.Text = isLockedNow and ("[锁定] " .. p.Name) or p.Name
            btnLock.TextColor3 = isLockedNow and THEME.Accent or (isAlly(p) and THEME.Ally or THEME.Enemy)
            btnLock.Font = Enum.Font.GothamSemibold
            btnLock.TextSize = 13
            btnLock.TextXAlignment = Enum.TextXAlignment.Left
            btnLock.TextTruncate = Enum.TextTruncate.AtEnd
            btnLock.AutoButtonColor = false
            btnLock.ZIndex = 12
            btnLock.Parent = row
            local pad = Instance.new("UIPadding", btnLock)
            pad.PaddingLeft = UDim.new(0, 6)
            btnLock.MouseButton1Click:Connect(function()
                AimbotTargetPlayer = p
                Toggles["TargetSelectBtn"]()
                TargetSelectorGui.Visible = false
            end)

            -- 标记队友按钮
            local btnAlly = Instance.new("TextButton")
            btnAlly.Size = UDim2.new(0.35, -12, 1, -10)
            btnAlly.AnchorPoint = Vector2.new(1, 0)
            btnAlly.Position = UDim2.new(1, -8, 0, 5)
            btnAlly.BackgroundColor3 = ManualAllies[p.Name] and THEME.Ally or THEME.Off
            btnAlly.BackgroundTransparency = ManualAllies[p.Name] and 0.25 or 0.35
            btnAlly.Text = ManualAllies[p.Name] and "取消友军" or "设为友军"
            btnAlly.TextColor3 = ManualAllies[p.Name] and Color3.fromRGB(232, 255, 243) or THEME.SubText
            btnAlly.Font = Enum.Font.GothamBold
            btnAlly.TextSize = 12
            btnAlly.AutoButtonColor = false
            btnAlly.ZIndex = 12
            btnAlly.Parent = row
            corner(btnAlly, 13)
            stroke(btnAlly, ManualAllies[p.Name] and THEME.Ally or THEME.Stroke, 1, 0.35)

            btnAlly.MouseButton1Click:Connect(function()
                if ManualAllies[p.Name] then
                    ManualAllies[p.Name] = nil
                else
                    ManualAllies[p.Name] = true
                end
                RefreshTargetList()
                if State.ESP then
                    for _, plr in ipairs(Players:GetPlayers()) do
                        local c = plr.Character
                        local h = c and c:FindFirstChild("CG_ESP_Highlight")
                        if h then h:Destroy() end
                        local hrp = c and c:FindFirstChild("HumanoidRootPart")
                        if hrp then
                            local b = hrp:FindFirstChild("CG_ESP"); if b then b:Destroy() end
                        end
                    end
                    for _, plr in ipairs(Players:GetPlayers()) do AddESP(plr) end
                end
            end)
        end
    end
end

-- ================= ESP（原样·未动） =================
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

-- ================= 穿墙（原样·未动） =================
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
    -- 飞行时也强制关闭碰撞
    NoclipConn = RunService.Stepped:Connect(function()
        local c = LP.Character
        if not c then return end
        for _, part in ipairs(c:GetDescendants()) do
            if part:IsA("BasePart") then part.CanCollide = false end
        end
    end)
end

-- ================= 移速（原样·未动） =================
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

-- ================= 跳跃（原样·未动） =================
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

-- ================= 绑定按钮（美化：分区排版，绑定关系未动） =================
CreateSection("移动")
CreateToggle("飞天 (Fly)", "Fly", function(on) ToggleFly(on) end)
CreateCycleBtn("飞行速度", {"慢", "中", "快", "超快"}, CONFIG.FlySpeedIdx, function(idx)
    CONFIG.FlySpeedIdx = idx
end)
CreateToggle("穿墙 (Noclip)", "Noclip", ToggleNoclip)

CreateSection("跳跃与移速")
CreateToggle("加强跳跃 (Jump)", "JumpPower", ToggleJump)
CreateCycleBtn("跳跃力度", {"正常", "加强", "超高", "飞天"}, CONFIG.JumpPowerIdx, function(idx)
    CONFIG.JumpPowerIdx = idx
    if State.JumpPower then
        local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.JumpPower = CONFIG.JumpPowers[idx] end
    end
end)
CreateToggle("加强移速 (Speed)", "Speed", ToggleSpeed)
CreateCycleBtn("移动速度", {"快跑", "疾跑", "瞬移", "光速"}, CONFIG.WalkSpeedIdx, function(idx)
    CONFIG.WalkSpeedIdx = idx
end)

CreateSection("视觉")
CreateToggle("透视 (ESP)", "ESP", ToggleESP)
CreateCycleBtn("透视阵营", {"仅队伍", "全敌", "全友"}, 1, function(idx)
    ESPMode = idx
    RefreshESP()
end)

CreateSection("战斗")
CreateToggle("锁头 (Aimbot)", "Aimbot", ToggleAimbot)

-- 目标选择按钮（美化：名称+状态胶囊）
local TargetBtn = Instance.new("TextButton")
TargetBtn.Size = UDim2.new(1, 0, 0, BTN_H)
TargetBtn.BackgroundColor3 = THEME.Card
TargetBtn.BorderSizePixel = 0
TargetBtn.Text = ""
TargetBtn.AutoButtonColor = false
TargetBtn.Parent = List
corner(TargetBtn, 10)
local tbst = stroke(TargetBtn, THEME.Stroke, 1)

local TargetNameLbl = Instance.new("TextLabel")
TargetNameLbl.Size = UDim2.new(1, -116, 1, 0)
TargetNameLbl.Position = UDim2.new(0, 14, 0, 0)
TargetNameLbl.BackgroundTransparency = 1
TargetNameLbl.Text = "选择锁头目标"
TargetNameLbl.TextColor3 = THEME.Text
TargetNameLbl.TextXAlignment = Enum.TextXAlignment.Left
TargetNameLbl.Font = Enum.Font.GothamMedium
TargetNameLbl.TextSize = NAME_SZ
TargetNameLbl.Parent = TargetBtn

local TargetPill = Instance.new("Frame")
TargetPill.AnchorPoint = Vector2.new(1, 0.5)
TargetPill.Position = UDim2.new(1, -12, 0.5, 0)
TargetPill.Size = UDim2.new(0, 88, 0, 26)
TargetPill.BackgroundColor3 = THEME.Off
TargetPill.BackgroundTransparency = 0.35
TargetPill.BorderSizePixel = 0
TargetPill.Parent = TargetBtn
corner(TargetPill, 13)

local TargetPillText = Instance.new("TextLabel")
TargetPillText.Size = UDim2.new(1, 0, 1, 0)
TargetPillText.BackgroundTransparency = 1
TargetPillText.Text = "自动"
TargetPillText.TextColor3 = THEME.SubText
TargetPillText.Font = Enum.Font.GothamBold
TargetPillText.TextSize = PILL_SZ
TargetPillText.TextTruncate = Enum.TextTruncate.AtEnd
TargetPillText.Parent = TargetPill

if not IS_MOBILE then
    TargetBtn.MouseEnter:Connect(function()
        TweenService:Create(TargetBtn, TweenInfo.new(0.15), {BackgroundColor3 = THEME.CardHover}):Play()
    end)
    TargetBtn.MouseLeave:Connect(function()
        local base = AimbotTargetPlayer and THEME.CardOn or THEME.Card
        TweenService:Create(TargetBtn, TweenInfo.new(0.15), {BackgroundColor3 = base}):Play()
    end)
end

TargetBtn.MouseButton1Click:Connect(function()
    RefreshTargetList()
    TargetSelectorGui.Visible = true
end)

Toggles["TargetSelectBtn"] = function()
    if AimbotTargetPlayer then
        TargetPillText.Text = AimbotTargetPlayer.Name
        TargetPillText.TextColor3 = THEME.PillTextOn
        TargetPill.BackgroundColor3 = THEME.Accent
        TargetPill.BackgroundTransparency = 0
        tbst.Color = THEME.Accent; tbst.Transparency = 0.15
        TweenService:Create(TargetBtn, TweenInfo.new(0.18), {BackgroundColor3 = THEME.CardOn}):Play()
    else
        TargetPillText.Text = "自动"
        TargetPillText.TextColor3 = THEME.SubText
        TargetPill.BackgroundColor3 = THEME.Off
        TargetPill.BackgroundTransparency = 0.35
        tbst.Color = THEME.Stroke; tbst.Transparency = 0.5
        TweenService:Create(TargetBtn, TweenInfo.new(0.18), {BackgroundColor3 = THEME.Card}):Play()
    end
end
Toggles["TargetSelectBtn"]()

-- ================= 重生处理（原样·未动） =================
LP.CharacterAdded:Connect(function()
    task.wait(0.8)
    if State.JumpPower then ToggleJump(true) end
    if State.Speed then ToggleSpeed(true) end
    if State.Fly then cleanFly(); ToggleFly(true) end
    if State.Noclip then ToggleNoclip(true) end
end)

-- ================= 关闭（原样·未动） =================
CloseBtn.MouseButton1Click:Connect(function()
    cleanFly()
    if NoclipConn then NoclipConn:Disconnect(); end
    if SpeedConn then SpeedConn:Disconnect(); end
    pcall(function() RunService:UnbindFromRenderStep("CG_Aimbot") end)
    ClearESP()
    ScreenGui:Destroy()
end)

print("[概念神菜单] 已更新！新增多档位调节与手动标友。")
