﻿-- ====== SERVICES & VARIABLES ======
local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace  = game:GetService("Workspace")
local Input      = game:GetService("UserInputService")

local localPlayer = Players.LocalPlayer
local camera      = Workspace.CurrentCamera
local characters  = Workspace:WaitForChild("characters")

-- ESP parts & connections
local skeletonParts = { head=true, torso=true, right_arm_vis=true,
                        left_arm_vis=true, right_leg_vis=true, left_leg_vis=true }
local connections = {
    {"head","torso"}, {"torso","right_arm_vis"}, {"torso","left_arm_vis"},
    {"torso","right_leg_vis"}, {"torso","left_leg_vis"},
}
local skeletonDrawings = {}

-- Feature toggles & settings
local espEnabled      = true
local aimbotEnabled   = false
local AIMBOT_FOV       = 40   -- default radius
local SMOOTHING_FACTOR = 0    -- 0 = snap, 1 = smooth

-- FOV circle
local FOV_CIRCLE = Drawing.new("Circle")
FOV_CIRCLE.Radius       = AIMBOT_FOV
FOV_CIRCLE.Thickness    = 1.5
FOV_CIRCLE.Transparency = 1
FOV_CIRCLE.Color        = Color3.new(1,1,0)
FOV_CIRCLE.Filled       = false
FOV_CIRCLE.Visible      = false

-- ===== ESP =====
local function createLine()
    local line = Drawing.new("Line")
    line.Color = Color3.new(1,1,1)
    line.Thickness = 2
    line.Transparency = 1
    line.Visible = true
    return line
end

local function createESP(char)
    if char.Name == localPlayer.Name or skeletonDrawings[char.Name] then return end
    skeletonDrawings[char.Name] = {}
    for _ = 1, #connections do
        table.insert(skeletonDrawings[char.Name], createLine())
    end
end

local function removeESP(name)
    local draws = skeletonDrawings[name]
    if draws then
        for _, l in ipairs(draws) do l:Remove() end
        skeletonDrawings[name] = nil
    end
end

RunService.RenderStepped:Connect(function()
    if not espEnabled then
        for _, draws in pairs(skeletonDrawings) do
            for _, l in ipairs(draws) do l.Visible = false end
        end
        return
    end

    for _, char in ipairs(characters:GetChildren()) do
        if char.Name ~= localPlayer.Name then
            local plr = Players:GetPlayerFromCharacter(char)
            if not plr or plr.Team ~= localPlayer.Team then
                if not skeletonDrawings[char.Name] then
                    createESP(char)
                end

                local pos = {}
                for partName in pairs(skeletonParts) do
                    local p = char:FindFirstChild(partName)
                    if p and p:IsA("BasePart") then
                        local sp, on = camera:WorldToViewportPoint(p.Position)
                        if on then
                            pos[partName] = Vector2.new(sp.X, sp.Y)
                        end
                    end
                end

                for i, conn in ipairs(connections) do
                    local p1 = pos[conn[1]]
                    local p2 = pos[conn[2]]
                    local line = skeletonDrawings[char.Name][i]
                    if p1 and p2 then
                        line.From, line.To, line.Visible = p1, p2, true
                    else
                        line.Visible = false
                    end
                end
            end
        end
    end
end)

characters.ChildAdded:Connect(function(c) task.wait(.1); createESP(c) end)
characters.ChildRemoved:Connect(function(c) removeESP(c.Name) end)
localPlayer.AncestryChanged:Connect(function(_, p)
    if not p then
        for name in pairs(skeletonDrawings) do removeESP(name) end
    end
end)

-- ===== AIMBOT =====
local function getClosest()
    local best, dist = nil, AIMBOT_FOV + 1
    for _, char in ipairs(characters:GetChildren()) do
        if char.Name ~= localPlayer.Name then
            local plr = Players:GetPlayerFromCharacter(char)
            if not plr or plr.Team ~= localPlayer.Team then
                local head = char:FindFirstChild("head")
                if head and head:IsA("BasePart") then
                    local sp, on = camera:WorldToViewportPoint(head.Position)
                    if on then
                        local mpos = Input:GetMouseLocation()
                        local d = (Vector2.new(sp.X, sp.Y) - mpos).Magnitude
                        if d < dist then
                            dist, best = d, head
                        end
                    end
                end
            end
        end
    end
    return best
end

local function aimAt(target)
    if not target then return end
    local sp, on = camera:WorldToViewportPoint(target.Position)
    if not on then return end
    local mpos = Input:GetMouseLocation()
    local delta = Vector2.new(sp.X, sp.Y) - mpos
    local move = delta * (1 - SMOOTHING_FACTOR)  -- 0 snap, 1 smooth
    mousemoverel(move.X, move.Y)
end

RunService.RenderStepped:Connect(function()
    FOV_CIRCLE.Position = Input:GetMouseLocation()
    FOV_CIRCLE.Visible  = aimbotEnabled
    if aimbotEnabled and Input:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
        local tgt = getClosest()
        if tgt then aimAt(tgt) end
    end
end)

-- ===== GUI =====
local gui = Instance.new("ScreenGui", game:GetService("CoreGui"))
gui.Name = "PhantomGUI"
gui.ResetOnSpawn = false

local frame = Instance.new("Frame", gui)
frame.Size = UDim2.new(0,260,0,240)
frame.Position = UDim2.new(0.4,0,0.3,0)
frame.BackgroundColor3 = Color3.new(0.12,0.12,0.12)
frame.Active = true
frame.Draggable = false

-- Title bar
local bar = Instance.new("Frame", frame)
bar.Size = UDim2.new(1,0,0,30)
bar.Position = UDim2.new(0,0,0,0)
bar.BackgroundColor3 = Color3.new(0.18,0.18,0.18)

local title = Instance.new("TextLabel", bar)
title.Size = UDim2.new(1,0,1,0)
title.BackgroundTransparency = 1
title.Font = Enum.Font.SourceSansBold
title.TextSize = 18
title.TextColor3 = Color3.new(1,1,1)
title.Text = "Godlys Cheat"

-- Manual drag logic for the whole frame
do
    local dragging, dragStart, startPos, dragInput

    bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    bar.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            dragInput = input
        end
    end)

    Input.InputChanged:Connect(function(input)
        if dragging and input == dragInput then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)
end

-- Helper: button
local function btn(text,y,col,cb)
    local b = Instance.new("TextButton", frame)
    b.Size = UDim2.new(0,240,0,30)
    b.Position = UDim2.new(0,10,0,y)
    b.BackgroundColor3 = col
    b.Font = Enum.Font.SourceSansBold
    b.TextSize = 18
    b.TextColor3 = Color3.new(1,1,1)
    b.Text = text
    b.MouseButton1Click:Connect(cb)
    return b
end

-- Create the ESP toggle button
local espBtn = Instance.new("TextButton", frame)
espBtn.Size              = UDim2.new(0,240,0,30)
espBtn.Position          = UDim2.new(0,10,0,40)
espBtn.BackgroundColor3  = Color3.new(0.2,0.2,0.2)
espBtn.Font             = Enum.Font.SourceSansBold
espBtn.TextSize         = 18
espBtn.TextColor3       = Color3.new(1,1,1)
espBtn.Text             = "Disable ESP"
espBtn.MouseButton1Click:Connect(function()
    espEnabled = not espEnabled
    espBtn.Text = espEnabled and "Disable ESP" or "Enable ESP"
end)

local aimBtn = Instance.new("TextButton", frame)
aimBtn.Size              = UDim2.new(0,240,0,30)
aimBtn.Position          = UDim2.new(0,10,0,80)
aimBtn.BackgroundColor3  = Color3.new(0.2,0.2,0.4)
aimBtn.Font              = Enum.Font.SourceSansBold
aimBtn.TextSize          = 18
aimBtn.TextColor3        = Color3.new(1,1,1)
aimBtn.Text              = "Enable Aimbot"

aimBtn.MouseButton1Click:Connect(function()
    aimbotEnabled = not aimbotEnabled
    aimBtn.Text = aimbotEnabled and "Disable Aimbot" or "Enable Aimbot"
    FOV_CIRCLE.Visible = aimbotEnabled
end)


local closeBtn = btn("Close GUI", 120, Color3.new(0.8,0.2,0.2), function()
    espEnabled = false
    aimbotEnabled = false
    for _, ds in pairs(skeletonDrawings) do
        for _, l in ipairs(ds) do l.Visible = false end
    end
    FOV_CIRCLE.Visible = false
    gui:Destroy()
end)

-- Helper: slider
local function slider(formatTxt, y, minV, maxV, initV, color, callback)
    local lbl = Instance.new("TextLabel", frame)
    lbl.Size = UDim2.new(0,240,0,20)
    lbl.Position = UDim2.new(0,10,0,y)
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.SourceSansBold
    lbl.TextSize = 16
    lbl.TextColor3 = color
    lbl.Text = formatTxt:format(initV)

    local track = Instance.new("Frame", frame)
    track.Size = UDim2.new(0,240,0,10)
    track.Position = UDim2.new(0,10,0,y+22)
    track.BackgroundColor3 = Color3.new(0.24,0.24,0.24)

    local bar = Instance.new("Frame", track)
    bar.Size = UDim2.new((initV-minV)/(maxV-minV),1,1,0)
    bar.BackgroundColor3 = color

    local dragging = false
    local function update(input)
        local x = math.clamp(input.Position.X - track.AbsolutePosition.X, 0, track.AbsoluteSize.X)
        local pct = x / track.AbsoluteSize.X
        local val = minV + (maxV-minV)*pct
        bar.Size = UDim2.new(pct,1,1,0)
        lbl.Text = formatTxt:format(val)
        callback(val)
    end

    track.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            update(i)
        end
    end)
    track.InputChanged:Connect(function(i)
        if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
            update(i)
        end
    end)
    Input.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
end

-- FOV slider
slider("FOV: %d", 160, 10, 200, AIMBOT_FOV, Color3.new(1,1,0), function(v)
    AIMBOT_FOV = v
    FOV_CIRCLE.Radius = v
end)

-- Smoothing slider
slider("Smoothing: %.2f", 200, 0, 1, SMOOTHING_FACTOR, Color3.new(0,1,1), function(v)
    SMOOTHING_FACTOR = v
end)
