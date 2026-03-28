-- CoiledTom Hub | Target Attach System
-- Wind UI v2 | By CoiledTom

-- ═══════════════════════════════════
--  LOAD WindUI v2
-- ═══════════════════════════════════
local WindUI = loadstring(game:HttpGet(
    "https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"
))()

-- ═══════════════════════════════════
--  SERVICES
-- ═══════════════════════════════════
local Players          = game:GetService("Players")
local TweenService     = game:GetService("TweenService")
local RunService       = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

-- ═══════════════════════════════════
--  VARIÁVEIS GLOBAIS
-- ═══════════════════════════════════
TargetPlayer      = nil
AttachEnabled     = false
AutoAttackEnabled = false
DistanceValue     = 5
SpeedValue        = 0.15
OrbitSpeedValue   = 1.5
SelectedPosition  = "Behind"

local orbitAngle    = 0
local currentTween  = nil
local attachLoop    = nil
local orbitLoop     = nil
local autoAtkLoop   = nil

-- ═══════════════════════════════════
--  TABELA DE POSIÇÕES
-- ═══════════════════════════════════
local Positions = {
    Behind  = { offset = Vector3.new(0, 0,  1),  angle = 0           },
    Front   = { offset = Vector3.new(0, 0, -1),  angle = math.pi     },
    Above   = { offset = Vector3.new(0, 1,  0),  angle = 0           },
    Below   = { offset = Vector3.new(0,-1,  0),  angle = 0           },
    Left    = { offset = Vector3.new(-1, 0, 0),  angle = math.pi/2   },
    Right   = { offset = Vector3.new( 1, 0, 0),  angle = -math.pi/2  },
    TopDown = { offset = Vector3.new(0, 1,  0),  angle = math.pi/2   },
    Orbit   = { offset = Vector3.new(0, 0,  1),  angle = 0           },
}

-- ═══════════════════════════════════
--  FUNÇÕES
-- ═══════════════════════════════════
local function getTarget()
    if TargetPlayer and TargetPlayer.Character then
        return TargetPlayer.Character:FindFirstChild("HumanoidRootPart")
    end
    return nil
end

local function getOffsetPosition(targetHRP, distance)
    if SelectedPosition == "Orbit" then
        local x = math.cos(orbitAngle) * distance
        local z = math.sin(orbitAngle) * distance
        return CFrame.new(targetHRP.Position + Vector3.new(x, 0, z))
            * CFrame.Angles(0, -(orbitAngle + math.pi / 2), 0)
    end

    local pos = Positions[SelectedPosition]
    if not pos then return nil end

    local scaledOffset = pos.offset * distance
    local worldOffset  = targetHRP.CFrame:VectorToWorldSpace(scaledOffset)
    return CFrame.new(targetHRP.Position + worldOffset)
        * CFrame.Angles(0, pos.angle, 0)
end

local function createTween(character, goalCFrame)
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    if currentTween then currentTween:Cancel() end
    local info = TweenInfo.new(SpeedValue, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
    currentTween = TweenService:Create(hrp, info, { CFrame = goalCFrame })
    currentTween:Play()
end

local function startAttachLoop()
    if attachLoop then attachLoop:Disconnect() end
    attachLoop = RunService.Heartbeat:Connect(function()
        if not AttachEnabled or SelectedPosition == "Orbit" then return end
        local targetHRP = getTarget()
        if not targetHRP then return end
        local char = LocalPlayer.Character
        if not char then return end
        local goal = getOffsetPosition(targetHRP, DistanceValue)
        if goal then createTween(char, goal) end
    end)
end

local function startOrbitLoop()
    if orbitLoop then orbitLoop:Disconnect() end
    orbitLoop = RunService.Heartbeat:Connect(function(dt)
        if not AttachEnabled or SelectedPosition ~= "Orbit" then return end
        orbitAngle = orbitAngle + OrbitSpeedValue * dt
        local targetHRP = getTarget()
        if not targetHRP then return end
        local char = LocalPlayer.Character
        if not char then return end
        local goal = getOffsetPosition(targetHRP, DistanceValue)
        if goal then createTween(char, goal) end
    end)
end

local function startAutoAttack()
    if autoAtkLoop then autoAtkLoop:Disconnect() end
    autoAtkLoop = RunService.Heartbeat:Connect(function()
        if not AutoAttackEnabled then return end
        local targetHRP = getTarget()
        if not targetHRP then return end
        local char = LocalPlayer.Character
        if not char then return end
        local myRoot = char:FindFirstChild("HumanoidRootPart")
        if not myRoot then return end
        local dist = (targetHRP.Position - myRoot.Position).Magnitude
        if dist <= DistanceValue + 4 then
            local tool = char:FindFirstChildOfClass("Tool")
            if tool then
                local evt = tool:FindFirstChild("RemoteEvent") or tool:FindFirstChild("Activate")
                if evt then pcall(function() evt:FireServer() end) end
            end
        end
    end)
end

startAttachLoop()
startOrbitLoop()
startAutoAttack()

-- ═══════════════════════════════════
--  WINDOW
-- ═══════════════════════════════════
local Window = WindUI:CreateWindow({
    Title       = "CoiledTom Hub",
    Icon        = "solar:planet-bold",
    Author      = "by CoiledTom",
    Folder      = "CoiledTomHub",
    Size        = UDim2.fromOffset(580, 480),
    Theme       = "Dark",
    Transparent = true,
})

-- ═══════════════════════════════════
--  TABS
-- ═══════════════════════════════════
local TabAttach = Window:Tab({ Title = "Target Attach", Icon = "solar:crosshairs-bold"  })
local TabWin    = Window:Tab({ Title = "eu consegui 😌", Icon = "solar:star-bold"       })

-- ══════════════════════════════════════════════════════
--  ABA: TARGET ATTACH
-- ══════════════════════════════════════════════════════
do
    TabAttach:Section({ Title = "Player Selection" })

    local function getPlayerNames()
        local names = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                table.insert(names, p.Name)
            end
        end
        if #names == 0 then table.insert(names, "Nenhum player") end
        return names
    end

    local playerDropdown
    playerDropdown = TabAttach:Dropdown({
        Title    = "Select Target",
        Desc     = "Escolha o player alvo",
        Options  = getPlayerNames(),
        Default  = getPlayerNames()[1],
        Callback = function(selected)
            TargetPlayer = Players:FindFirstChild(selected) or nil
            WindUI:Notify({ Title = "Target", Content = "Alvo: " .. selected, Duration = 2 })
        end,
    })

    Players.PlayerAdded:Connect(function()
        task.wait(0.5)
        pcall(function() playerDropdown:Refresh(getPlayerNames()) end)
    end)
    Players.PlayerRemoving:Connect(function(p)
        if p == TargetPlayer then TargetPlayer = nil; AttachEnabled = false end
        task.wait(0.5)
        pcall(function() playerDropdown:Refresh(getPlayerNames()) end)
    end)

    TabAttach:Button({
        Title    = "Atualizar Lista",
        Icon     = "solar:refresh-bold",
        Desc     = "Recarrega os players disponíveis",
        Callback = function()
            pcall(function() playerDropdown:Refresh(getPlayerNames()) end)
            WindUI:Notify({ Title = "Players", Content = "Lista atualizada!", Duration = 2 })
        end,
    })

    TabAttach:Section({ Title = "Position Mode" })

    TabAttach:Dropdown({
        Title    = "Position Type",
        Desc     = "Posição relativa ao alvo",
        Options  = { "Behind", "Front", "Above", "Below", "Left", "Right", "TopDown", "Orbit" },
        Default  = "Behind",
        Callback = function(selected)
            SelectedPosition = selected
        end,
    })

    TabAttach:Section({ Title = "Movement Settings" })

    TabAttach:Slider({
        Title = "Distance",
        Desc  = "Distância até o alvo (studs)",
        Step  = 1,
        Value = { Min = 1, Max = 30, Default = 5 },
        Callback = function(v)
            DistanceValue = v
        end,
    })

    TabAttach:Slider({
        Title = "Tween Speed",
        Desc  = "Velocidade do movimento suave",
        Step  = 1,
        Value = { Min = 1, Max = 20, Default = 7 },
        Callback = function(v)
            SpeedValue = 0.5 / v
        end,
    })

    TabAttach:Slider({
        Title = "Orbit Speed",
        Desc  = "Velocidade de rotação no modo Orbit",
        Step  = 1,
        Value = { Min = 1, Max = 10, Default = 3 },
        Callback = function(v)
            OrbitSpeedValue = v * 0.5
        end,
    })

    TabAttach:Section({ Title = "Controls" })

    TabAttach:Toggle({
        Title = "Toggle Attach",
        Desc  = "Ativa movimentação relativa ao alvo",
        Value = false,
        Callback = function(v)
            AttachEnabled = v
            if not v and currentTween then currentTween:Cancel() end
            WindUI:Notify({
                Title   = "Attach",
                Content = v and "Attach ATIVADO!" or "Attach desativado.",
                Duration = 2,
            })
        end,
    })

    TabAttach:Toggle({
        Title = "Auto Attack",
        Desc  = "Ataca automaticamente o alvo (tool equipada)",
        Value = false,
        Callback = function(v)
            AutoAttackEnabled = v
            WindUI:Notify({
                Title   = "Auto Attack",
                Content = v and "Auto Attack ATIVADO!" or "Auto Attack desativado.",
                Duration = 2,
            })
        end,
    })
end

-- ══════════════════════════════════════════════════════
--  ABA: EU CONSEGUI 😌
-- ══════════════════════════════════════════════════════
do
    TabWin:Section({ Title = "Missão Cumprida!" })
    TabWin:Section({ Title = "O Target Attach está funcionando. Bom jogo! 😌" })
    TabWin:Section({ Title = "Créditos" })
    TabWin:Section({ Title = "Script: CoiledTom | UI: Wind UI v2 by Footagesus" })

    TabWin:Button({
        Title    = "Fechar aviso",
        Icon     = "solar:check-circle-bold",
        Desc     = "Fechar esta mensagem",
        Callback = function()
            WindUI:Notify({ Title = "CoiledTom Hub", Content = "Pronto! Bom jogo 😌", Duration = 3 })
        end,
    })
end

-- ══════════════════════════════════════════════════════
--  NOTIFICAÇÃO INICIAL
-- ══════════════════════════════════════════════════════
WindUI:Notify({
    Title    = "CoiledTom Hub",
    Content  = "Target Attach carregado com sucesso!",
    Duration = 4,
})
