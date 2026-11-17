--[[
    概念神菜单 (Concept God Menu) v1.5 - 多级菜单版
    文件名: YQGJS.lua
    本版更新:
      新增: 背包功能页(玩家列表→查看物品→拿取/一键拿取, 自动刷新, 目标退出保护)
      已有: 环境页强制白天 / 辅助页弹飞 / 手机飞行(左摇杆+右屏转向升降) / 锁头/ESP/穿墙/移速/跳跃
      修复: 前向声明 / ESP标签键值 / UICorner tween / ESP连接泄漏
]]

-- ================= 全局配置 =================
local CONFIG = {
    MenuName     = "概念神菜单",
    AimbotFOV    = 300,
    DesignW      = 420,
    DesignH      = 640,

    EXPANDED_W   = 300,
    EXPANDED_H   = 536,

    FlySpeeds    = {40, 80, 120, 200},
    JumpPowers   = {80, 120, 200, 300},
    WalkSpeeds   = {40, 80, 150, 250},
    FlingVel     = {250, 500, 1000},

    FlySpeedIdx  = 1,
    JumpPowerIdx = 1,
    WalkSpeedIdx = 1,
    FlingVelIdx  = 1,

    FlyCamDist   = 15,

    DayClockTime  = 14,
    DayBrightness = 3,
}

local THEME = {
    Bg        = Color3.fromRGB(12, 12, 16),
    Card      = Color3.fromRGB(30, 30, 38),
    CardPress = Color3.fromRGB(44, 44, 55),
    Accent    = Color3.fromRGB(0, 255, 170),
    On        = Color3.fromRGB(0, 200, 140),
    SwitchOff = Color3.fromRGB(58, 58, 70),
    Text      = Color3.fromRGB(240, 240, 245),
    TextDim   = Color3.fromRGB(155, 155, 170),
    Danger    = Color3.fromRGB(235, 70, 70),
    Stroke    = Color3.fromRGB(70, 70, 90),
    Red       = Color3.fromRGB(255, 50, 50),
    Green     = Color3.fromRGB(50, 255, 50),
}

local FLY_ANIMS = {
    Idle = 619542203, Walk = 619544080, Run = 619543231,
    Jump = 619542888, Fall = 619541867,
}

-- ================= 服务 =================
local Players      = game:GetService("Players")
local RunService   = game:GetService("RunService")
local UIS          = game:GetService("UserInputService")
local CoreGui      = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local Lighting     = game:GetService("Lighting")

local LP     = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local IS_TOUCH  = UIS.TouchEnabled
local IS_MOBILE = IS_TOUCH

-- ================= 状态 =================
local State = {
    Fly = false, ESP = false, Noclip = false,
    JumpPower = false, Speed = false, Aimbot = false,
    Fling = false, Daytime = false,
}
local ESPMode            = 1
local AimbotTargetPlayer = nil
local ManualAllies       = {}
local selectedBpPlayer   = nil   -- 背包页当前选中的玩家

-- 前向声明（UI 先引用、后段赋值，闭包调用时取值）
local ToggleFly, ToggleESP, RefreshESP, ToggleNoclip
local ToggleSpeed, ToggleJump, ToggleAimbot, ToggleFling, ToggleDaytime
local RefreshTargetList
local TargetSelectorGui, TSScale

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

local function stroke(parent, color, thickness, transparency)
    local s = Instance.new("UIStroke")
    s.Color = color or THEME.Stroke
    s.Thickness = thickness or 1
    s.Transparency = transparency or 0.55
    s.Parent = parent
    return s
end

local function attachPress(btn, base, pressed)
    btn.MouseButton1Down:Connect(function() btn.BackgroundColor3 = pressed end)
    btn.MouseButton1Up:Connect(function() btn.BackgroundColor3 = base end)
    btn.MouseLeave:Connect(function() btn.BackgroundColor3 = base end)
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
Main.Size = UDim2.new(0, 180, 0, 40)
Main.BackgroundColor3 = THEME.Bg
Main.BackgroundTransparency = 0.12
Main.BorderSizePixel = 0
Main.ClipsDescendants = true
Main.ZIndex = 5
Main.Parent = ScreenGui
local mainCorner = corner(Main, 20)
stroke(Main, THEME.Stroke, 1.5, 0.45)

local mainGrad = Instance.new("UIGradient")
mainGrad.Color = ColorSequence.new(Color3.fromRGB(24, 24, 30), Color3.fromRGB(10, 10, 14))
mainGrad.Rotation = 90
mainGrad.Parent = Main

local StatusDot = Instance.new("Frame")
StatusDot.Size = UDim2.new(0, 8, 0, 8)
StatusDot.Position = UDim2.new(0, 16, 0.5, -4)
StatusDot.BackgroundColor3 = THEME.Accent
StatusDot.BorderSizePixel = 0
StatusDot.Parent = Main
corner(StatusDot, 4)

task.spawn(function()
    while ScreenGui.Parent do
        local t = TweenService:Create(StatusDot,
            TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
            {BackgroundTransparency = 0.75})
        t:Play() t.Completed:Wait()
        if not ScreenGui.Parent then break end
        local t2 = TweenService:Create(StatusDot,
            TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
            {BackgroundTransparency = 0})
        t2:Play() t2.Completed:Wait()
    end
end)

local Header = Instance.new("TextButton")
Header.Size = UDim2.new(1, 0, 0, 40)
Header.BackgroundTransparency = 1
Header.Text = "◈ " .. CONFIG.MenuName
Header.TextColor3 = THEME.Text
Header.Font = Enum.Font.GothamBold
Header.TextSize = 15
Header.TextXAlignment = Enum.TextXAlignment.Left
local headerPad = Instance.new("UIPadding", Header)
headerPad.PaddingLeft = UDim.new(0, 30)
Header.Parent = Main

local HeaderLine = Instance.new("Frame")
HeaderLine.Size = UDim2.new(1, -20, 0, 1)
HeaderLine.Position = UDim2.new(0, 10, 0, 40)
HeaderLine.BackgroundColor3 = THEME.Stroke
HeaderLine.BackgroundTransparency = 0.5
HeaderLine.BorderSizePixel = 0
HeaderLine.Parent = Main

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 28, 0, 28)
CloseBtn.Position = UDim2.new(1, -33, 0, 6)
CloseBtn.BackgroundColor3 = THEME.Danger
CloseBtn.BackgroundTransparency = 0.15
CloseBtn.BorderSizePixel = 0
CloseBtn.Text = "✕"
CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 12
CloseBtn.ZIndex = 6
CloseBtn.Parent = Main
corner(CloseBtn, 14)

local ScaleObj = Instance.new("UIScale")
ScaleObj.Parent = Main

local function updateScale()
    local vp = Camera.ViewportSize
    if vp.X <= 0 or vp.Y <= 0 then return end
    local s = math.min(vp.X / CONFIG.DesignW, vp.Y / CONFIG.DesignH)
    ScaleObj.Scale = math.clamp(s, 0.65, 1.30)
    if TSScale then
        TSScale.Scale = math.clamp(s * 1.05, 0.80, 1.10)
    end
end
Camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
updateScale()

-- ================= 菜单列表 + 页脚 =================
local List = Instance.new("ScrollingFrame")
List.Size = UDim2.new(1, -10, 0, CONFIG.EXPANDED_H - 46 - 26)
List.Position = UDim2.new(0, 0, 0, 46)
List.BackgroundTransparency = 1
List.BorderSizePixel = 0
List.ScrollBarThickness = 3
List.ScrollBarImageColor3 = THEME.Accent
List.CanvasSize = UDim2.new(0, 0, 0, 0)
List.AutomaticCanvasSize = Enum.AutomaticSize.Y
List.Visible = false
List.Parent = Main

local Footer = Instance.new("TextLabel")
Footer.Size = UDim2.new(1, -16, 0, 18)
Footer.Position = UDim2.new(0, 8, 1, -24)
Footer.BackgroundTransparency = 1
Footer.Text = "Concept God Menu · v1.5"
Footer.TextColor3 = THEME.TextDim
Footer.Font = Enum.Font.Gotham
Footer.TextSize = 11
Footer.TextXAlignment = Enum.TextXAlignment.Center
Footer.Parent = Main

-- 折叠展开
local expanded = false
Header.MouseButton1Click:Connect(function()
    expanded = not expanded
    List.Visible = expanded
    TweenService:Create(Main,
        TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
        Size = expanded and UDim2.new(0, CONFIG.EXPANDED_W, 0, CONFIG.EXPANDED_H)
                       or UDim2.new(0, 180, 0, 40)
    }):Play()
    TweenService:Create(mainCorner, TweenInfo.new(0.3), {
        CornerRadius = UDim.new(0, expanded and 12 or 20)
    }):Play()
end)

-- ================= 分页系统 =================
local Pages = {}
local function ShowPage(pageName)
    for name, frame in pairs(Pages) do
        frame.Visible = (name == pageName)
    end
    List.CanvasPosition = Vector2.new(0, 0)
    local p = Pages[pageName]
    if p then
        p.GroupTransparency = 1
        p.Position = UDim2.new(0, 6, 0, 14)
        TweenService:Create(p,
            TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            GroupTransparency = 0,
            Position = UDim2.new(0, 6, 0, 4)
        }):Play()
    end
end

local function CreatePage(pageName)
    local p = Instance.new("CanvasGroup")
    p.Name = pageName .. "Page"
    p.Size = UDim2.new(1, -12, 0, 0)
    p.Position = UDim2.new(0, 6, 0, 4)
    p.AutomaticSize = Enum.AutomaticSize.Y
    p.BackgroundTransparency = 1
    p.BorderSizePixel = 0
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
local AssistPage = CreatePage("Assist")
local EnvPage    = CreatePage("Env")
local BpPage     = CreatePage("Bp")       -- 背包：玩家列表
local BpItemPage = CreatePage("BpItems")  -- 背包：物品列表

-- ================= 按钮组件 =================
local BTN_H = IS_MOBILE and 52 or 44
local Toggles = {}

local function CreateNavBtn(parent, icon, text, targetPage)
    local Btn = Instance.new("TextButton")
    Btn.Size = UDim2.new(1, 0, 0, BTN_H)
    Btn.BackgroundColor3 = THEME.Card
    Btn.BorderSizePixel = 0
    Btn.Text = ""
    Btn.AutoButtonColor = false
    Btn.Parent = parent
    corner(Btn, 10)
    stroke(Btn, THEME.Stroke, 1, 0.6)
    attachPress(Btn, THEME.Card, THEME.CardPress)

    local ic = Instance.new("TextLabel")
    ic.Size = UDim2.new(0, 24, 1, 0)
    ic.Position = UDim2.new(0, 14, 0, 0)
    ic.BackgroundTransparency = 1
    ic.Text = icon
    ic.TextSize = IS_MOBILE and 20 or 18
    ic.Font = Enum.Font.GothamBold
    ic.TextColor3 = THEME.Accent
    ic.Parent = Btn

    local ttl = Instance.new("TextLabel")
    ttl.Size = UDim2.new(1, -80, 1, 0)
    ttl.Position = UDim2.new(0, 44, 0, 0)
    ttl.BackgroundTransparency = 1
    ttl.Text = text
    ttl.TextColor3 = THEME.Text
    ttl.Font = Enum.Font.GothamSemibold
    ttl.TextSize = IS_MOBILE and 16 or 14
    ttl.TextXAlignment = Enum.TextXAlignment.Left
    ttl.TextTruncate = Enum.TextTruncate.AtEnd
    ttl.Parent = Btn

    local arrow = Instance.new("TextLabel")
    arrow.Size = UDim2.new(0, 20, 1, 0)
    arrow.AnchorPoint = Vector2.new(1, 0.5)
    arrow.Position = UDim2.new(1, -14, 0.5, 0)
    arrow.BackgroundTransparency = 1
    arrow.Text = "›"
    arrow.TextColor3 = THEME.TextDim
    arrow.Font = Enum.Font.GothamBold
    arrow.TextSize = 18
    arrow.Parent = Btn

    Btn.MouseButton1Click:Connect(function() ShowPage(targetPage) end)
    return Btn
end

-- backPage: 返回按钮去哪页（默认回主页）
local function CreatePageHeader(parent, title, backPage)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 34)
    row.BackgroundTransparency = 1
    row.Parent = parent

    local back = Instance.new("TextButton")
    back.Size = UDim2.new(0, 92, 1, 0)
    back.BackgroundTransparency = 1
    back.Text = "‹ 返回"
    back.TextColor3 = THEME.Accent
    back.Font = Enum.Font.GothamSemibold
    back.TextSize = 15
    back.TextXAlignment = Enum.TextXAlignment.Left
    local pad = Instance.new("UIPadding", back)
    pad.PaddingLeft = UDim.new(0, 2)
    back.Parent = row
    back.MouseButton1Click:Connect(function() ShowPage(backPage or "Home") end)

    local ttl = Instance.new("TextLabel")
    ttl.Size = UDim2.new(1, -100, 1, 0)
    ttl.Position = UDim2.new(0, 100, 0, 0)
    ttl.BackgroundTransparency = 1
    ttl.Text = title
    ttl.TextColor3 = THEME.TextDim
    ttl.Font = Enum.Font.GothamBold
    ttl.TextSize = 15
    ttl.TextXAlignment = Enum.TextXAlignment.Right
    ttl.Parent = row
    return row
end

local function CreateToggle(parent, text, key, callback)
    local Btn = Instance.new("TextButton")
    Btn.Size = UDim2.new(1, 0, 0, BTN_H)
    Btn.BackgroundColor3 = THEME.Card
    Btn.BorderSizePixel = 0
    Btn.Text = ""
    Btn.AutoButtonColor = false
    Btn.Parent = parent
    corner(Btn, 10)
    stroke(Btn, THEME.Stroke, 1, 0.6)
    attachPress(Btn, THEME.Card, THEME.CardPress)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -70, 1, 0)
    lbl.Position = UDim2.new(0, 14, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = THEME.Text
    lbl.Font = Enum.Font.GothamSemibold
    lbl.TextSize = IS_MOBILE and 16 or 14
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextTruncate = Enum.TextTruncate.AtEnd
    lbl.Parent = Btn

    local track = Instance.new("Frame")
    track.Size = UDim2.new(0, 36, 0, 20)
    track.AnchorPoint = Vector2.new(1, 0.5)
    track.Position = UDim2.new(1, -14, 0.5, 0)
    track.BackgroundColor3 = THEME.SwitchOff
    track.BorderSizePixel = 0
    track.Parent = Btn
    corner(track, 10)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 16, 0, 16)
    knob.AnchorPoint = Vector2.new(0, 0.5)
    knob.Position = UDim2.new(0, 2, 0.5, 0)
    knob.BackgroundColor3 = Color3.fromRGB(200, 200, 210)
    knob.BorderSizePixel = 0
    knob.Parent = track
    corner(knob, 8)

    local on = false
    local swTween = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    local function refresh(animate)
        local knobPos = UDim2.new(0, on and 18 or 2, 0.5, 0)
        local knobCol = on and THEME.Accent or Color3.fromRGB(200, 200, 210)
        local trackCol = on and THEME.On or THEME.SwitchOff
        if animate then
            TweenService:Create(track, swTween, {BackgroundColor3 = trackCol}):Play()
            TweenService:Create(knob, swTween, {Position = knobPos, BackgroundColor3 = knobCol}):Play()
        else
            track.BackgroundColor3 = trackCol
            knob.Position = knobPos
            knob.BackgroundColor3 = knobCol
        end
    end

    Btn.MouseButton1Click:Connect(function()
        on = not on
        refresh(true)
        State[key] = on
        if callback then callback(on) end
    end)

    Toggles[key] = function(v)
        on = v; refresh(false); State[key] = v
        if callback then callback(v) end
    end
    refresh(false)
    return Btn
end

local function CreateCycleBtn(parent, text, options, initialIdx, callback)
    local Btn = Instance.new("TextButton")
    Btn.Size = UDim2.new(1, 0, 0, BTN_H)
    Btn.BackgroundColor3 = THEME.Card
    Btn.BorderSizePixel = 0
    Btn.Text = ""
    Btn.AutoButtonColor = false
    Btn.Parent = parent
    corner(Btn, 10)
    stroke(Btn, THEME.Stroke, 1, 0.6)
    attachPress(Btn, THEME.Card, THEME.CardPress)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -110, 1, 0)
    lbl.Position = UDim2.new(0, 14, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = THEME.Text
    lbl.Font = Enum.Font.GothamSemibold
    lbl.TextSize = IS_MOBILE and 16 or 14
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextTruncate = Enum.TextTruncate.AtEnd
    lbl.Parent = Btn

    local val = Instance.new("TextLabel")
    val.Size = UDim2.new(0, 100, 1, 0)
    val.AnchorPoint = Vector2.new(1, 0.5)
    val.Position = UDim2.new(1, -14, 0.5, 0)
    val.BackgroundTransparency = 1
    val.TextColor3 = THEME.Accent
    val.Font = Enum.Font.GothamBold
    val.TextSize = IS_MOBILE and 15 or 14
    val.TextXAlignment = Enum.TextXAlignment.Right
    val.Parent = Btn

    local idx = initialIdx
    local function refresh()
        val.Text = "‹ " .. tostring(options[idx]) .. " ›"
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

-- ================= 构建页面 =================

-- 主页
local homeTitle = Instance.new("TextLabel")
homeTitle.Size = UDim2.new(1, 0, 0, 22)
homeTitle.BackgroundTransparency = 1
homeTitle.Text = "功能分类"
homeTitle.TextColor3 = THEME.TextDim
homeTitle.TextXAlignment = Enum.TextXAlignment.Left
homeTitle.Font = Enum.Font.GothamBold
homeTitle.TextSize = 13
homeTitle.Parent = HomePage

CreateNavBtn(HomePage, "✈", "飞行设置", "Fly")
CreateNavBtn(HomePage, "◎", "透视设置", "Esp")
CreateNavBtn(HomePage, "⇄", "移动 · 穿墙/移速/跳跃", "Move")
CreateNavBtn(HomePage, "✜", "战斗 · 锁头", "Combat")
CreateNavBtn(HomePage, "⚡", "辅助 · 弹飞玩家", "Assist")
CreateNavBtn(HomePage, "☀", "环境 · 强制白天", "Env")
local BackpackNavBtn = CreateNavBtn(HomePage, "▣", "背包 · 查看/拿取", "Bp")

-- 飞行页
CreatePageHeader(FlyPage, "飞行设置")
CreateToggle(FlyPage, "飞天 (Fly)", "Fly", function(on) ToggleFly(on) end)
CreateCycleBtn(FlyPage, "飞行速度", {"慢", "中", "快", "超快"},
    CONFIG.FlySpeedIdx, function(idx) CONFIG.FlySpeedIdx = idx end)

local flyHint = Instance.new("TextLabel")
flyHint.Size = UDim2.new(1, 0, 0, IS_MOBILE and 46 or 34)
flyHint.BackgroundTransparency = 1
flyHint.TextColor3 = THEME.TextDim
flyHint.Font = Enum.Font.Gotham
flyHint.TextSize = 12
flyHint.TextWrapped = true
flyHint.Text = IS_MOBILE
    and "操作：左摇杆 = 前后左右平移\n右侧屏幕拖动 = 横拖转向 / 竖拖升降，回中即悬停"
    or "操作：WASD 移动 · Space 上升 · Shift 下降"
flyHint.Parent = FlyPage

-- 透视页
CreatePageHeader(EspPage, "透视设置")
CreateToggle(EspPage, "透视 (ESP)", "ESP", function(on) ToggleESP(on) end)
CreateCycleBtn(EspPage, "透视阵营", {"仅队伍", "全敌", "全友"}, 1, function(idx)
    ESPMode = idx
    RefreshESP()
end)

-- 移动页
CreatePageHeader(MovePage, "移动设置")
CreateToggle(MovePage, "穿墙 (Noclip)", "Noclip", function(on) ToggleNoclip(on) end)
CreateToggle(MovePage, "加强移速 (Speed)", "Speed", function(on) ToggleSpeed(on) end)
CreateCycleBtn(MovePage, "移动速度", {"快跑", "疾跑", "瞬移", "光速"},
    CONFIG.WalkSpeedIdx, function(idx) CONFIG.WalkSpeedIdx = idx end)
CreateToggle(MovePage, "加强跳跃 (Jump)", "JumpPower", function(on) ToggleJump(on) end)
CreateCycleBtn(MovePage, "跳跃力度", {"正常", "加强", "超高", "飞天"},
    CONFIG.JumpPowerIdx, function(idx)
        CONFIG.JumpPowerIdx = idx
        if State.JumpPower then
            local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
            if hum then hum.JumpPower = CONFIG.JumpPowers[idx] end
        end
    end)

-- 战斗页
CreatePageHeader(CombatPage, "战斗设置")
CreateToggle(CombatPage, "锁头 (Aimbot)", "Aimbot", function(on) ToggleAimbot(on) end)

local TargetBtn = Instance.new("TextButton")
TargetBtn.Size = UDim2.new(1, 0, 0, BTN_H)
TargetBtn.BackgroundColor3 = THEME.Card
TargetBtn.BorderSizePixel = 0
TargetBtn.Text = ""
TargetBtn.AutoButtonColor = false
TargetBtn.Parent = CombatPage
corner(TargetBtn, 10)
stroke(TargetBtn, THEME.Stroke, 1, 0.6)
attachPress(TargetBtn, THEME.Card, THEME.CardPress)

local TargetLbl = Instance.new("TextLabel")
TargetLbl.Size = UDim2.new(1, -28, 1, 0)
TargetLbl.Position = UDim2.new(0, 14, 0, 0)
TargetLbl.BackgroundTransparency = 1
TargetLbl.Text = "选择锁头目标 (当前: 自动)"
TargetLbl.TextColor3 = THEME.Text
TargetLbl.Font = Enum.Font.GothamSemibold
TargetLbl.TextSize = IS_MOBILE and 16 or 14
TargetLbl.TextXAlignment = Enum.TextXAlignment.Left
TargetLbl.TextTruncate = Enum.TextTruncate.AtEnd
TargetLbl.Parent = TargetBtn

local TargetArrow = Instance.new("TextLabel")
TargetArrow.Size = UDim2.new(0, 20, 1, 0)
TargetArrow.AnchorPoint = Vector2.new(1, 0.5)
TargetArrow.Position = UDim2.new(1, -14, 0.5, 0)
TargetArrow.BackgroundTransparency = 1
TargetArrow.Text = "›"
TargetArrow.TextColor3 = THEME.TextDim
TargetArrow.Font = Enum.Font.GothamBold
TargetArrow.TextSize = 18
TargetArrow.Parent = TargetBtn

TargetBtn.MouseButton1Click:Connect(function()
    RefreshTargetList()
    TargetSelectorGui.Visible = true
end)

Toggles["TargetSelectBtn"] = function()
    if AimbotTargetPlayer then
        TargetLbl.Text = "当前目标: " .. AimbotTargetPlayer.Name
        TargetBtn.BackgroundColor3 = THEME.On
    else
        TargetLbl.Text = "选择锁头目标 (当前: 自动)"
        TargetBtn.BackgroundColor3 = THEME.Card
    end
end
Toggles["TargetSelectBtn"]()

-- 辅助页
CreatePageHeader(AssistPage, "辅助功能")
CreateToggle(AssistPage, "弹飞玩家 (触碰)", "Fling", function(on) ToggleFling(on) end)
CreateCycleBtn(AssistPage, "弹飞力度", {"普通", "强力", "离谱"},
    CONFIG.FlingVelIdx, function(idx) CONFIG.FlingVelIdx = idx end)

local flingHint = Instance.new("TextLabel")
flingHint.Size = UDim2.new(1, 0, 0, 46)
flingHint.BackgroundTransparency = 1
flingHint.TextColor3 = THEME.TextDim
flingHint.Font = Enum.Font.Gotham
flingHint.TextSize = 12
flingHint.TextWrapped = true
flingHint.Text = "开启后，你贴到的敌人会被弹飞并死亡。\n手动标友与同队玩家不受影响；透视阵营设为「全敌」时可弹所有人。"
flingHint.Parent = AssistPage

-- 环境页
CreatePageHeader(EnvPage, "环境设置")
CreateToggle(EnvPage, "强制白天", "Daytime", function(on) ToggleDaytime(on) end)

local envHint = Instance.new("TextLabel")
envHint.Size = UDim2.new(1, 0, 0, 46)
envHint.BackgroundTransparency = 1
envHint.TextColor3 = THEME.TextDim
envHint.Font = Enum.Font.Gotham
envHint.TextSize = 12
envHint.TextWrapped = true
envHint.Text = "开启后锁定为正午光照，游戏的昼夜循环会被立即拉回白天。\n效果仅自己可见；关闭后自动恢复游戏原本的时间与光照。"
envHint.Parent = EnvPage

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

-- ================= 手机飞行触控（右侧屏幕辅助区） =================
local flightTouches = {}
local flyYaw = 0
local TouchConns = {}

table.insert(TouchConns, UIS.TouchStarted:Connect(function(input, gp)
    if not IS_TOUCH or not State.Fly or gp then return end
    if input.Position.X > Camera.ViewportSize.X * 0.45 then
        flightTouches[input] = {
            startY = input.Position.Y,
            curY   = input.Position.Y,
            lastX  = input.Position.X,
        }
    end
end))

table.insert(TouchConns, UIS.TouchMoved:Connect(function(input)
    local t = flightTouches[input]
    if t then
        flyYaw = flyYaw - (input.Position.X - t.lastX) * 0.005
        t.curY = input.Position.Y
        t.lastX = input.Position.X
    end
end))

table.insert(TouchConns, UIS.TouchEnded:Connect(function(input)
    flightTouches[input] = nil
end))
table.insert(TouchConns, UIS.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch then
        flightTouches[input] = nil
    end
end))

-- ================= 飞行系统 =================
local Fly = { conn = nil, lv = nil, ao = nil, att = nil, animTracks = {}, currentAnim = "", prevCamType = nil }

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
    if Fly.prevCamType then
        Camera.CameraType = Fly.prevCamType
        Fly.prevCamType = nil
    end
    table.clear(flightTouches)
    local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
    if hum and not State.Noclip then hum.PlatformStand = false end
end

function ToggleFly(on)
    cleanFly()
    if not on then return end
    local char = LP.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return end

    hum.PlatformStand = true
    loadFlyAnims(hum)

    if IS_TOUCH then
        Fly.prevCamType = Camera.CameraType
        Camera.CameraType = Enum.CameraType.Scriptable
        local look = Camera.CFrame.LookVector
        flyYaw = math.atan2(-look.X, -look.Z)
    end

    Fly.att = Instance.new("Attachment", hrp)
    Fly.lv = Instance.new("LinearVelocity")
    Fly.lv.Attachment0 = Fly.att; Fly.lv.MaxForce = 1e5; Fly.lv.Parent = hrp
    Fly.ao = Instance.new("AlignOrientation")
    Fly.ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
    Fly.ao.Attachment0 = Fly.att; Fly.ao.MaxTorque = 1e5
    Fly.ao.RigidityEnabled = true; Fly.ao.Parent = hrp

    Fly.conn = RunService.RenderStepped:Connect(function()
        local c = LP.Character
        local root = c and c:FindFirstChild("HumanoidRootPart")
        if not root or not Fly.lv or not Fly.ao then return end

        local mv = Vector3.zero
        local ctl = getControls()
        if ctl then
            local ok, v = pcall(function() return ctl:GetMoveVector() end)
            if ok and typeof(v) == "Vector3" then mv = v end
        end

        local speed = CONFIG.FlySpeeds[CONFIG.FlySpeedIdx]
        local vel, charYaw

        if IS_TOUCH then
            local yawCF = CFrame.Angles(0, flyYaw, 0)
            local hDir = yawCF.LookVector * (-mv.Z) + yawCF.RightVector * mv.X

            local climb = 0
            for _, t in pairs(flightTouches) do
                local ci = math.clamp((t.startY - t.curY) / 140, -1, 1)
                if math.abs(ci) > math.abs(climb) then climb = ci end
            end

            local h = Vector3.new(hDir.X, 0, hDir.Z)
            h = h.Magnitude > 1e-4 and h.Unit or Vector3.zero
            vel = h * speed + Vector3.new(0, climb * speed * 0.8, 0)
            charYaw = flyYaw

            if not State.Aimbot then
                local look = (yawCF * CFrame.Angles(math.rad(-15), 0, 0)).LookVector
                local focus = root.Position + Vector3.new(0, 2, 0)
                Camera.CFrame = CFrame.lookAt(focus - look * CONFIG.FlyCamDist, focus)
            end
        else
            local camCF = Camera.CFrame
            local dir = camCF.LookVector * (-mv.Z) + camCF.RightVector * mv.X
            if UIS:IsKeyDown(Enum.KeyCode.Space) then dir += Vector3.new(0, 1, 0) end
            if UIS:IsKeyDown(Enum.KeyCode.LeftShift) then dir -= Vector3.new(0, 1, 0) end
            vel = dir.Magnitude > 1e-4 and dir.Unit * speed or Vector3.zero

            local lookFlat = Vector3.new(camCF.LookVector.X, 0, camCF.LookVector.Z)
            charYaw = lookFlat.Magnitude > 1e-4
                and math.atan2(-lookFlat.X, -lookFlat.Z) or 0
        end

        Fly.lv.VectorVelocity = vel
        Fly.ao.CFrame = CFrame.Angles(0, charYaw, 0)

        local inputMag = mv.Magnitude
        local horiz = Vector2.new(vel.X, vel.Z).Magnitude
        local vertDom = math.abs(vel.Y) > horiz
        if inputMag < 0.05 and not vertDom then
            setFlyAnim("Idle")
        elseif vertDom and vel.Y > 0 then
            setFlyAnim("Jump")
        elseif vertDom and vel.Y < 0 then
            setFlyAnim("Fall")
        elseif inputMag > 0.5 then
            setFlyAnim("Run")
        else
            setFlyAnim("Walk")
        end
    end)
end

-- ================= 锁头 =================
function ToggleAimbot(on)
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

-- ================= ESP 全距离透视 + 连线 =================
local ESPHighlights, ESPLines, ESPLabels = {}, {}, {}
local ESPConns = {}
local LinesConn = nil

local function ClearESP()
    for _, hl in pairs(ESPHighlights) do
        if hl and hl.Parent then hl:Destroy() end
    end
    table.clear(ESPHighlights)
    for _, line in pairs(ESPLines) do
        if line and line.Parent then line:Destroy() end
    end
    table.clear(ESPLines)
    for _, lbl in pairs(ESPLabels) do
        if lbl and lbl.Parent then lbl:Destroy() end
    end
    table.clear(ESPLabels)
    for _, c in ipairs(ESPConns) do c:Disconnect() end
    table.clear(ESPConns)
    if LinesConn then LinesConn:Disconnect(); LinesConn = nil end
end

local function StartLinesRenderer()
    if LinesConn then LinesConn:Disconnect(); LinesConn = nil end

    LinesConn = RunService.RenderStepped:Connect(function()
        if not State.ESP then return end
        local startPos = Main.AbsolutePosition + Main.AbsoluteSize / 2
        local rainbowColor = Color3.fromHSV((tick() * 0.3) % 1, 1, 1)

        for player, lineFrame in pairs(ESPLines) do
            if player.Character and LP.Character then
                local targetPart = player.Character:FindFirstChild("Head")
                    or player.Character:FindFirstChild("HumanoidRootPart")
                local myPos = LP.Character:FindFirstChild("HumanoidRootPart")

                if targetPart and myPos then
                    local screenPos = Camera:WorldToViewportPoint(targetPart.Position)
                    local dist = math.floor((myPos.Position - targetPart.Position).Magnitude)
                    local isEnemy = not isAlly(player)

                    local label = ESPLabels[player]
                    if label then
                        label.Text = (isEnemy and "[敌] " or "[友] ") .. player.Name .. " [" .. dist .. "m]"
                        label.TextColor3 = isEnemy and THEME.Red or THEME.Green
                    end

                    local hl = ESPHighlights[player]
                    if hl and hl.Parent then
                        hl.OutlineColor = rainbowColor
                    end

                    if screenPos.Z > 0 then
                        local endPos = Vector2.new(screenPos.X, screenPos.Y)
                        local delta = endPos - startPos
                        lineFrame.Visible = true
                        lineFrame.Position = UDim2.new(0, startPos.X, 0, startPos.Y)
                        lineFrame.Size = UDim2.new(0, delta.Magnitude, 0, 1)
                        lineFrame.Rotation = math.deg(math.atan2(delta.Y, delta.X))
                        lineFrame.BackgroundColor3 = isEnemy
                            and Color3.fromRGB(255, 40, 40) or Color3.fromRGB(40, 255, 60)
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

function AddESP(player)
    if player == LP then return end
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    if ESPHighlights[player] and ESPHighlights[player].Parent then
        ESPHighlights[player]:Destroy()
    end
    if ESPLines[player] then ESPLines[player]:Destroy() end
    if ESPLabels[player] then ESPLabels[player]:Destroy() end

    local isEnemy = not isAlly(player)
    local mainColor = isEnemy and THEME.Red or THEME.Green

    local highlight = Instance.new("Highlight", char)
    highlight.Name = "CG_ESP_Highlight"
    highlight.Adornee = char
    highlight.FillColor = mainColor
    highlight.FillTransparency = 0.65
    highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
    ESPHighlights[player] = highlight

    local billboard = Instance.new("BillboardGui", hrp)
    billboard.Name = "CG_ESP"
    billboard.Adornee = hrp
    billboard.Size = UDim2.new(0, 200, 0, 40)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.AlwaysOnTop = true
    billboard.MaxDistance = 100000

    local label = Instance.new("TextLabel", billboard)
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = (isEnemy and "[敌] " or "[友] ") .. player.Name
    label.TextColor3 = mainColor
    label.TextStrokeTransparency = 0
    label.Font = Enum.Font.GothamBold
    label.TextSize = 14
    ESPLabels[player] = label

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

function RefreshESP()
    ClearESP()
    if not State.ESP then return end
    for _, p in ipairs(Players:GetPlayers()) do AddESP(p) end
    StartLinesRenderer()
end

function ToggleESP(on)
    ClearESP()
    if not on then return end
    RefreshESP()

    table.insert(ESPConns, Players.PlayerAdded:Connect(function(p)
        table.insert(ESPConns, p.CharacterAdded:Connect(function()
            task.wait(0.5)
            if State.ESP then AddESP(p) end
        end))
        task.spawn(function()
            if not p.Character then p.CharacterAdded:Wait() end
            task.wait(0.5)
            if State.ESP then AddESP(p) end
        end)
    end))
    for _, p in ipairs(Players:GetPlayers()) do
        table.insert(ESPConns, p.CharacterAdded:Connect(function()
            task.wait(0.5)
            if State.ESP then AddESP(p) end
        end))
    end
end

Players.PlayerRemoving:Connect(function(p)
    if selectedBpPlayer == p then selectedBpPlayer = nil end
    if ESPLines[p] then ESPLines[p]:Destroy(); ESPLines[p] = nil end
    if ESPLabels[p] then ESPLabels[p]:Destroy(); ESPLabels[p] = nil end
    ESPHighlights[p] = nil
end)

-- ================= 目标选择器 UI =================
TargetSelectorGui = Instance.new("Frame")
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

TSScale = Instance.new("UIScale")
TSScale.Parent = TargetSelectorGui
updateScale()

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
TS_Close.Text = "✕"
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
TS_Scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
TS_Scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
TS_Scroll.ZIndex = 11
TS_Scroll.Parent = TargetSelectorGui

local TS_Layout = Instance.new("UIListLayout")
TS_Layout.Padding = UDim.new(0, 6)
TS_Layout.SortOrder = Enum.SortOrder.LayoutOrder
TS_Layout.Parent = TS_Scroll

function RefreshTargetList()
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
            btnLock.Text = (AimbotTargetPlayer and p.Name == AimbotTargetPlayer.Name)
                and ("[锁定] " .. p.Name) or p.Name
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
            btnAlly.BackgroundColor3 = ManualAllies[p.Name]
                and Color3.fromRGB(55, 140, 90) or Color3.fromRGB(80, 80, 90)
            btnAlly.Text = ManualAllies[p.Name] and "取消友军" or "设为友军"
            btnAlly.TextColor3 = Color3.fromRGB(255, 255, 255)
            btnAlly.Font = Enum.Font.GothamBold
            btnAlly.TextSize = 12
            btnAlly.ZIndex = 12
            btnAlly.Parent = row
            corner(btnAlly, 6)

            btnAlly.MouseButton1Click:Connect(function()
                if ManualAllies[p.Name] then
                    ManualAllies[p.Name] = nil
                else
                    ManualAllies[p.Name] = true
                end
                RefreshTargetList()
                RefreshESP()
            end)
        end
    end
end

-- ================= 穿墙 =================
local NoclipConn = nil
function ToggleNoclip(on)
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
function ToggleSpeed(on)
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
function ToggleJump(on)
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

-- ================= 辅助功能：触碰弹飞 =================
local FlingConns = {}
local flingCooldown = {}

local function playerFromHit(hit)
    if not hit or not hit.Parent then return nil end
    local p = Players:GetPlayerFromCharacter(hit.Parent)
    if p then return p, hit.Parent end
    local up = hit.Parent.Parent
    if up then
        local p2 = Players:GetPlayerFromCharacter(up)
        if p2 then return p2, up end
    end
    return nil
end

local function onFlingTouch(hit)
    if not State.Fling then return end
    local myChar = LP.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myRoot then return end

    local player, char = playerFromHit(hit)
    if not player or player == LP then return end
    if isAlly(player) then return end

    local now = os.clock()
    if flingCooldown[player] and now - flingCooldown[player] < 1.2 then return end
    flingCooldown[player] = now

    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return end

    local root = char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart
    if not root then return end

    local power = CONFIG.FlingVel[CONFIG.FlingVelIdx] or 300

    local dir = root.Position - myRoot.Position
    dir = Vector3.new(dir.X, 0, dir.Z)
    dir = dir.Magnitude > 0.05 and dir.Unit or myRoot.CFrame.LookVector

    root.AssemblyLinearVelocity = dir * power + Vector3.new(0, power * 0.6, 0)
    root.AssemblyAngularVelocity = Vector3.new(power, power, power)
    pcall(function() hum:ChangeState(Enum.HumanoidStateType.Physics) end)

    if not char:FindFirstChildOfClass("ForceField") then
        hum.Health = 0
    end
end

local function hookFling(char)
    local hrp = char:WaitForChild("HumanoidRootPart", 10)
    if not hrp or not State.Fling then return end
    table.insert(FlingConns, hrp.Touched:Connect(onFlingTouch))
end

function ToggleFling(on)
    for _, c in ipairs(FlingConns) do c:Disconnect() end
    table.clear(FlingConns)
    table.clear(flingCooldown)
    if not on then return end

    if LP.Character then hookFling(LP.Character) end
    table.insert(FlingConns, LP.CharacterAdded:Connect(function(c)
        task.wait(0.6)
        if State.Fling then hookFling(c) end
    end))
end

-- ================= 环境功能：强制白天 =================
local DayConns = {}
local dayLoopRunning = false
local origLighting = nil

local function saveLighting()
    if origLighting then return end
    origLighting = {
        ClockTime      = Lighting.ClockTime,
        Brightness     = Lighting.Brightness,
        Ambient        = Lighting.Ambient,
        OutdoorAmbient = Lighting.OutdoorAmbient,
        GlobalShadows  = Lighting.GlobalShadows,
    }
end

local function restoreLighting()
    if not origLighting then return end
    for k, v in pairs(origLighting) do
        pcall(function() Lighting[k] = v end)
    end
    origLighting = nil
end

local function forceDay()
    Lighting.ClockTime = CONFIG.DayClockTime
    Lighting.Brightness = CONFIG.DayBrightness
    Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
    Lighting.GlobalShadows = true
end

function ToggleDaytime(on)
    dayLoopRunning = false
    for _, c in ipairs(DayConns) do c:Disconnect() end
    table.clear(DayConns)

    if not on then
        restoreLighting()
        return
    end

    saveLighting()
    forceDay()

    table.insert(DayConns, Lighting:GetPropertyChangedSignal("ClockTime"):Connect(function()
        if State.Daytime and Lighting.ClockTime ~= CONFIG.DayClockTime then
            Lighting.ClockTime = CONFIG.DayClockTime
        end
    end))

    dayLoopRunning = true
    task.spawn(function()
        while dayLoopRunning and ScreenGui.Parent do
            task.wait(1)
            if State.Daytime then
                forceDay()
            end
        end
    end)
end

-- ================= 【新增】背包功能：查看 / 拿取 =================
local BpItemConns = {}

local function clearBpItemConns()
    for _, c in ipairs(BpItemConns) do c:Disconnect() end
    table.clear(BpItemConns)
end

-- 拿取 = 把对方工具克隆一份塞进自己背包（客户端操作）
local function takeTool(tool)
    if not tool or not tool.Parent then return false, "物品已消失" end
    local bp = LP:FindFirstChild("Backpack")
    if not bp then return false, "找不到背包" end
    pcall(function() tool.Archivable = true end)
    local ok = pcall(function()
        local copy = tool:Clone()
        copy.Parent = bp
    end)
    if ok then return true end
    return false, "克隆失败"
end

-- ---- 背包页 UI（玩家列表） ----
CreatePageHeader(BpPage, "背包查看")

local BpRefresh = Instance.new("TextButton")
BpRefresh.Size = UDim2.new(1, 0, 0, 38)
BpRefresh.LayoutOrder = 2
BpRefresh.BackgroundColor3 = Color3.fromRGB(60, 60, 75)
BpRefresh.BackgroundTransparency = 0.25
BpRefresh.BorderSizePixel = 0
BpRefresh.Text = "↻ 刷新玩家列表"
BpRefresh.TextColor3 = THEME.Text
BpRefresh.Font = Enum.Font.GothamSemibold
BpRefresh.TextSize = 14
BpRefresh.AutoButtonColor = false
BpRefresh.Parent = BpPage
corner(BpRefresh, 8)
attachPress(BpRefresh, Color3.fromRGB(60, 60, 75), Color3.fromRGB(44, 44, 55))

local bpHint = Instance.new("TextLabel")
bpHint.Size = UDim2.new(1, 0, 0, 58)
bpHint.LayoutOrder = 100
bpHint.BackgroundTransparency = 1
bpHint.TextColor3 = THEME.TextDim
bpHint.Font = Enum.Font.Gotham
bpHint.TextSize = 12
bpHint.TextWrapped = true
bpHint.Text = "点击玩家名字查看他的物品。能否看到对方背包由游戏决定——\n看不到背包时，至少能拿他手里装备中的工具。"
bpHint.Parent = BpPage

local function buildBpPlayerList()
    for _, c in ipairs(BpPage:GetChildren()) do
        if (c:IsA("TextButton") or c:IsA("Frame")) and c.LayoutOrder >= 10 and c.LayoutOrder < 100 then
            c:Destroy()
        end
    end

    local order = 10
    local added = false

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP then
            added = true
            local bpCount, equipped = 0, 0
            local bpReadable = (p:FindFirstChild("Backpack") ~= nil)
            if bpReadable then
                for _, t in ipairs(p.Backpack:GetChildren()) do
                    if t:IsA("Tool") then bpCount += 1 end
                end
            end
            if p.Character then
                for _, t in ipairs(p.Character:GetChildren()) do
                    if t:IsA("Tool") then equipped += 1 end
                end
            end

            local row = Instance.new("TextButton")
            row.Size = UDim2.new(1, 0, 0, BTN_H)
            row.LayoutOrder = order; order += 1
            row.BackgroundColor3 = THEME.Card
            row.BorderSizePixel = 0
            row.Text = ""
            row.AutoButtonColor = false
            row.Parent = BpPage
            corner(row, 10)
            stroke(row, THEME.Stroke, 1, 0.6)
            attachPress(row, THEME.Card, THEME.CardPress)

            local nm = Instance.new("TextLabel")
            nm.Size = UDim2.new(1, -190, 1, 0)
            nm.Position = UDim2.new(0, 14, 0, 0)
            nm.BackgroundTransparency = 1
            nm.Text = p.DisplayName .. " (@" .. p.Name .. ")"
            nm.TextColor3 = THEME.Text
            nm.Font = Enum.Font.GothamSemibold
            nm.TextSize = IS_MOBILE and 15 or 14
            nm.TextXAlignment = Enum.TextXAlignment.Left
            nm.TextTruncate = Enum.TextTruncate.AtEnd
            nm.Parent = row

            local cnt = Instance.new("TextLabel")
            cnt.Size = UDim2.new(0, 170, 1, 0)
            cnt.AnchorPoint = Vector2.new(1, 0.5)
            cnt.Position = UDim2.new(1, -14, 0.5, 0)
            cnt.BackgroundTransparency = 1
            cnt.Text = bpReadable
                and ("背包 " .. bpCount .. " · 装备 " .. equipped)
                or ("装备 " .. equipped .. " · 背包未同步")
            cnt.TextColor3 = THEME.TextDim
            cnt.Font = Enum.Font.Gotham
            cnt.TextSize = 12
            cnt.TextXAlignment = Enum.TextXAlignment.Right
            cnt.Parent = row

            row.MouseButton1Click:Connect(function()
                if not p.Parent then buildBpPlayerList() return end
                selectedBpPlayer = p
                buildBpItemList(p)
                ShowPage("BpItems")
            end)
        end
    end

    if not added then
        local empty = Instance.new("Frame")
        empty.Size = UDim2.new(1, 0, 0, 44)
        empty.LayoutOrder = 11
        empty.BackgroundColor3 = THEME.Card
        empty.BackgroundTransparency = 0.5
        empty.BorderSizePixel = 0
        empty.Parent = BpPage
        corner(empty, 8)
        local t = Instance.new("TextLabel")
        t.Size = UDim2.new(1, 0, 1, 0)
        t.BackgroundTransparency = 1
        t.Text = "服务器里没有其他玩家"
        t.TextColor3 = THEME.TextDim
        t.Font = Enum.Font.Gotham
        t.TextSize = 13
        t.Parent = empty
    end
end

-- ---- 物品页 UI ----
CreatePageHeader(BpItemPage, "物品列表", "Bp")

local BpOwnerLabel = Instance.new("TextLabel")
BpOwnerLabel.Size = UDim2.new(1, 0, 0, 20)
BpOwnerLabel.LayoutOrder = 2
BpOwnerLabel.BackgroundTransparency = 1
BpOwnerLabel.Text = "目标: -"
BpOwnerLabel.TextColor3 = THEME.TextDim
BpOwnerLabel.Font = Enum.Font.GothamBold
BpOwnerLabel.TextSize = 13
BpOwnerLabel.TextXAlignment = Enum.TextXAlignment.Left
BpOwnerLabel.TextTruncate = Enum.TextTruncate.AtEnd
BpOwnerLabel.Parent = BpItemPage

local BpTakeAll = Instance.new("TextButton")
BpTakeAll.Size = UDim2.new(1, 0, 0, 40)
BpTakeAll.LayoutOrder = 3
BpTakeAll.BackgroundColor3 = Color3.fromRGB(55, 140, 90)
BpTakeAll.BackgroundTransparency = 0.2
BpTakeAll.BorderSizePixel = 0
BpTakeAll.Text = "⇓ 一键拿取全部"
BpTakeAll.TextColor3 = Color3.fromRGB(255, 255, 255)
BpTakeAll.Font = Enum.Font.GothamBold
BpTakeAll.TextSize = 15
BpTakeAll.AutoButtonColor = false
BpTakeAll.Parent = BpItemPage
corner(BpTakeAll, 8)
attachPress(BpTakeAll, Color3.fromRGB(55, 140, 90), Color3.fromRGB(70, 170, 110))

local bpItemHint = Instance.new("TextLabel")
bpItemHint.Size = UDim2.new(1, 0, 0, 58)
bpItemHint.LayoutOrder = 100
bpItemHint.BackgroundTransparency = 1
bpItemHint.TextColor3 = THEME.TextDim
bpItemHint.Font = Enum.Font.Gotham
bpItemHint.TextSize = 12
bpItemHint.TextWrapped = true
bpItemHint.Text = "点「拿取」会把该工具复制进你的背包（一键拿取=全部复制）。\n这是本地操作：校验松的游戏里能真正使用；校验严的游戏只有你自己看得见。"
bpItemHint.Parent = BpItemPage

function buildBpItemList(pl)
    clearBpItemConns()
    for _, c in ipairs(BpItemPage:GetChildren()) do
        if (c:IsA("TextButton") or c:IsA("Frame")) and c.LayoutOrder >= 10 and c.LayoutOrder < 100 then
            c:Destroy()
        end
    end

    if not pl or not pl.Parent then
        BpOwnerLabel.Text = "目标已离开服务器"
        return
    end
    BpOwnerLabel.Text = "目标: " .. pl.DisplayName .. " (@" .. pl.Name .. ")"

    -- 收集可见工具：装备中(永远可见) + 背包(游戏同步了才能看见)
    local items = {}
    local char = pl.Character
    if char then
        for _, t in ipairs(char:GetChildren()) do
            if t:IsA("Tool") then table.insert(items, {tool = t, where = "装备中"}) end
        end
    end
    local bp = pl:FindFirstChild("Backpack")
    if bp then
        for _, t in ipairs(bp:GetChildren()) do
            if t:IsA("Tool") then table.insert(items, {tool = t, where = "背包"}) end
        end
        -- 对方背包变化时自动刷新列表
        table.insert(BpItemConns, bp.ChildAdded:Connect(function(c)
            if selectedBpPlayer == pl and c:IsA("Tool") then
                task.defer(buildBpItemList, pl)
            end
        end))
        table.insert(BpItemConns, bp.ChildRemoved:Connect(function(c)
            if selectedBpPlayer == pl and c:IsA("Tool") then
                task.defer(buildBpItemList, pl)
            end
        end))
    end

    if #items == 0 then
        local empty = Instance.new("Frame")
        empty.Size = UDim2.new(1, 0, 0, 52)
        empty.LayoutOrder = 11
        empty.BackgroundColor3 = THEME.Card
        empty.BackgroundTransparency = 0.5
        empty.BorderSizePixel = 0
        empty.Parent = BpItemPage
        corner(empty, 8)
        local t = Instance.new("TextLabel")
        t.Size = UDim2.new(1, -16, 1, 0)
        t.Position = UDim2.new(0, 8, 0, 0)
        t.BackgroundTransparency = 1
        t.Text = "没有可见物品\n(对方背包未同步给你，或背包为空)"
        t.TextColor3 = THEME.TextDim
        t.Font = Enum.Font.Gotham
        t.TextSize = 13
        t.TextWrapped = true
        t.Parent = empty
        return
    end

    local order = 10
    for _, it in ipairs(items) do
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, BTN_H)
        row.LayoutOrder = order; order += 1
        row.BackgroundColor3 = THEME.Card
        row.BorderSizePixel = 0
        row.Parent = BpItemPage
        corner(row, 10)
        stroke(row, THEME.Stroke, 1, 0.6)

        local nm = Instance.new("TextLabel")
        nm.Size = UDim2.new(1, -220, 1, 0)
        nm.Position = UDim2.new(0, 14, 0, 0)
        nm.BackgroundTransparency = 1
        nm.Text = it.tool.Name
        nm.TextColor3 = THEME.Text
        nm.Font = Enum.Font.GothamSemibold
        nm.TextSize = IS_MOBILE and 15 or 14
        nm.TextXAlignment = Enum.TextXAlignment.Left
        nm.TextTruncate = Enum.TextTruncate.AtEnd
        nm.Parent = row

        local tag = Instance.new("TextLabel")
        tag.Size = UDim2.new(0, 84, 1, 0)
        tag.AnchorPoint = Vector2.new(1, 0.5)
        tag.Position = UDim2.new(1, -102, 0.5, 0)
        tag.BackgroundTransparency = 1
        tag.Text = it.where
        tag.TextColor3 = it.where == "装备中" and THEME.Accent or THEME.TextDim
        tag.Font = Enum.Font.Gotham
        tag.TextSize = 12
        tag.TextXAlignment = Enum.TextXAlignment.Right
        tag.Parent = row

        local takeBtn = Instance.new("TextButton")
        takeBtn.Size = UDim2.new(0, 84, 0, BTN_H - 12)
        takeBtn.AnchorPoint = Vector2.new(1, 0.5)
        takeBtn.Position = UDim2.new(1, -8, 0.5, 0)
        takeBtn.BackgroundColor3 = Color3.fromRGB(55, 140, 90)
        takeBtn.BorderSizePixel = 0
        takeBtn.Text = "拿取"
        takeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        takeBtn.Font = Enum.Font.GothamBold
        takeBtn.TextSize = 14
        takeBtn.AutoButtonColor = false
        takeBtn.Parent = row
        corner(takeBtn, 8)
        attachPress(takeBtn, Color3.fromRGB(55, 140, 90), Color3.fromRGB(70, 170, 110))

        takeBtn.MouseButton1Click:Connect(function()
            local ok, msg = takeTool(it.tool)
            takeBtn.Text = ok and "✓ 已拿取" or ("✗ " .. (msg or "失败"))
            takeBtn.BackgroundColor3 = ok and THEME.On or THEME.Danger
            task.delay(1.2, function()
                if takeBtn.Parent then
                    takeBtn.Text = "拿取"
                    takeBtn.BackgroundColor3 = Color3.fromRGB(55, 140, 90)
                end
            end)
        end)
    end
end

-- 一键拿取全部
BpTakeAll.MouseButton1Click:Connect(function()
    local pl = selectedBpPlayer
    if not pl or not pl.Parent then return end

    local snapshot = {}
    local char = pl.Character
    if char then
        for _, t in ipairs(char:GetChildren()) do
            if t:IsA("Tool") then table.insert(snapshot, t) end
        end
    end
    local bp = pl:FindFirstChild("Backpack")
    if bp then
        for _, t in ipairs(bp:GetChildren()) do
            if t:IsA("Tool") then table.insert(snapshot, t) end
        end
    end

    local okN = 0
    for _, t in ipairs(snapshot) do
        if takeTool(t) then okN += 1 end
    end

    BpTakeAll.Text = ("已拿取 %d/%d"):format(okN, #snapshot)
    task.delay(1.5, function()
        if BpTakeAll.Parent then BpTakeAll.Text = "⇓ 一键拿取全部" end
    end)
    if okN > 0 then buildBpItemList(pl) end
end)

-- 入口联动：进背包页 / 点刷新 都重建玩家列表
BackpackNavBtn.MouseButton1Click:Connect(function()
    buildBpPlayerList()
end)
BpRefresh.MouseButton1Click:Connect(function()
    buildBpPlayerList()
end)
buildBpPlayerList() -- 预构建一次

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
    if NoclipConn then NoclipConn:Disconnect() end
    if SpeedConn then SpeedConn:Disconnect() end
    if LinesConn then LinesConn:Disconnect() end
    for _, c in ipairs(TouchConns) do c:Disconnect() end
    for _, c in ipairs(FlingConns) do c:Disconnect() end

    dayLoopRunning = false
    for _, c in ipairs(DayConns) do c:Disconnect() end
    table.clear(DayConns)
    restoreLighting()

    clearBpItemConns()
    pcall(function() RunService:UnbindFromRenderStep("CG_Aimbot") end)
    ClearESP()
    ScreenGui:Destroy()
end)

print("[概念神菜单] v1.5 已加载：背包 → 查看/拿取")
