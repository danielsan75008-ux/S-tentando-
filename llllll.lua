-- ============================================================
--   CoiledTom Hub | Target Attach System
--   Wind UI v2 | By CoiledTom
-- ============================================================

local WindUI
do
    local ok, result = pcall(function()
        return loadstring(game:HttpGet(
            "https://raw.githubusercontent.com/Footagesus/WindUI/refs/heads/main/dist/source.lua",
            true
        ))()
    end)
    if not ok then
        error("[CoiledTom Hub] Falha ao carregar Wind UI v2:\n" .. tostring(result))
    end
    WindUI = result
end

-- ============================================================
-- SERVICES
-- ============================================================
local Players       = game:GetService("Players")
local TweenService  = game:GetService("TweenService")
local RunService    = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

-- ============================================================
-- VARIÁVEIS GLOBAIS
-- ============================================================
local LocalPlayer        = Players.LocalPlayer
TargetPlayer             = nil
AttachEnabled            = false
AutoAttackEnabled        = false
DistanceValue            = 5
SpeedValue               = 0.15
OrbitSpeedValue          = 1
SelectedPosition         = "Behind"

local orbitAngle         = 0
local attachLoop         = nil
local orbitLoop          = nil
local autoAttackLoop     = nil
local currentTween       = nil

-- ============================================================
-- TABELA DE POSIÇÕES (offsets + rotação)
-- ============================================================
local Positions = {
    Behind    = { offset = Vector3.new(0, 0,  5),  angles = CFrame.Angles(0, 0,           0) },
    Front     = { offset = Vector3.new(0, 0, -5),  angles = CFrame.Angles(0, math.pi,     0) },
    Above     = { offset = Vector3.new(0, 5,  0),  angles = CFrame.Angles(0, 0,           0) },
    Below     = { offset = Vector3.new(0,-5,  0),  angles = CFrame.Angles(0, 0,           0) },
    Left      = { offset = Vector3.new(-5, 0, 0),  angles = CFrame.Angles(0, math.pi/2,   0) },
    Right     = { offset = Vector3.new( 5, 0, 0),  angles = CFrame.Angles(0, -math.pi/2,  0) },
    TopDown   = { offset = Vector3.new(0, 8,  0),  angles = CFrame.Angles(math.pi/2, 0,   0) },
    Orbit     = { offset = Vector3.new(0, 0,  0),  angles = CFrame.Angles(0, 0,           0) }, -- calculado dinamicamente
}

-- ============================================================
-- FUNÇÕES PRINCIPAIS
-- ============================================================

-- Retorna o HumanoidRootPart do alvo
local function getTarget()
    if TargetPlayer and TargetPlayer.Character then
        return TargetPlayer.Character:FindFirstChild("HumanoidRootPart")
    end
    return nil
end

-- Calcula a CFrame de destino com base na posição selecionada
local function getOffsetPosition(targetHRP, distance)
    local pos = Positions[SelectedPosition]
    if not pos then return nil end

    if SelectedPosition == "Orbit" then
        local angle = orbitAngle
        local x = math.cos(angle) * distance
        local z = math.sin(angle) * distance
        local orbitOffset = Vector3.new(x, 0, z)
        return CFrame.new(targetHRP.Position + orbitOffset) * CFrame.Angles(0, -(angle + math.pi/2), 0)
    end

    local scaledOffset = pos.offset.Unit * distance
    local targetCF     = targetHRP.CFrame
    local worldOffset  = targetCF:VectorToWorldSpace(scaledOffset)
    return CFrame.new(targetHRP.Position + worldOffset) * pos.angles
end

-- Cria e executa um Tween suave para movimentação
local function createTween(character, goalCFrame)
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    if currentTween then
        currentTween:Cancel()
    end

    local tweenInfo = TweenInfo.new(SpeedValue, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
    currentTween = TweenService:Create(hrp, tweenInfo, { CFrame = goalCFrame })
    currentTween:Play()
end

-- Loop principal de attach
local function startAttachLoop()
    if attachLoop then attachLoop:Disconnect() end

    attachLoop = RunService.Heartbeat:Connect(function()
        if not AttachEnabled then return end
        if SelectedPosition == "Orbit" then return end -- Orbit tem loop próprio

        local targetHRP = getTarget()
        if not targetHRP then return end

        local localChar = LocalPlayer.Character
        if not localChar then return end

        local goalCF = getOffsetPosition(targetHRP, DistanceValue)
        if goalCF then
            createTween(localChar, goalCF)
        end
    end)
end

-- Loop de órbita
local function startOrbitLoop()
    if orbitLoop then orbitLoop:Disconnect() end

    orbitLoop = RunService.Heartbeat:Connect(function(dt)
        if not AttachEnabled then return end
        if SelectedPosition ~= "Orbit" then return end

        orbitAngle = orbitAngle + (OrbitSpeedValue * dt)

        local targetHRP = getTarget()
        if not targetHRP then return end

        local localChar = LocalPlayer.Character
        if not localChar then return end

        local goalCF = getOffsetPosition(targetHRP, DistanceValue)
        if goalCF then
            createTween(localChar, goalCF)
        end
    end)
end

-- Loop de auto-attack
local function startAutoAttack()
    if autoAttackLoop then autoAttackLoop:Disconnect() end

    autoAttackLoop = RunService.Heartbeat:Connect(function()
        if not AutoAttackEnabled then return end

        local targetHRP = getTarget()
        if not targetHRP then return end

        local localChar = LocalPlayer.Character
        if not localChar then return end

        local tool = LocalPlayer.Character:FindFirstChildOfClass("Tool")
        if tool and tool:FindFirstChild("Handle") then
            local dist = (targetHRP.Position - localChar:FindFirstChild("HumanoidRootPart").Position).Magnitude
            if dist <= (DistanceValue + 3) then
                -- Simula clique/ativação da tool
                local activateEvent = tool:FindFirstChild("Activate") or tool:FindFirstChild("RemoteEvent")
                if activateEvent then
                    pcall(function() activateEvent:FireServer() end)
                end
            end
        end
    end)
end

-- ============================================================
-- INICIALIZA LOOPS
-- ============================================================
startAttachLoop()
startOrbitLoop()
startAutoAttack()

-- ============================================================
-- WIND UI v2 — INTERFACE
-- ============================================================
local Window = WindUI:CreateWindow({
    Title       = "CoiledTom Hub",
    Icon        = "rbxassetid://10723407389",
    Author      = "by CoiledTom",
    Transparent = true,
    Theme       = "Dark",
    DisableResize = false,
    SideBarWidth = 200,
})

-- ============================================================
-- ABA: TARGET ATTACH
-- ============================================================
local TabAttach = Window:Tab({
    Name = "Target Attach",
    Icon = "crosshair",
})

-- ───────────────────────────────────────────────
-- SEÇÃO: Player Selection
-- ───────────────────────────────────────────────
TabAttach:Section({ Name = "Player Selection" })

local function getPlayerNames()
    local names = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            table.insert(names, p.Name)
        end
    end
    if #names == 0 then
        table.insert(names, "(Nenhum player)")
    end
    return names
end

local playerDropdown
playerDropdown = TabAttach:Dropdown({
    Name    = "Select Target",
    Options = getPlayerNames(),
    Default = getPlayerNames()[1] or "(Nenhum player)",
    Tooltip = "Escolha o player alvo",
    Callback = function(selected)
        local found = Players:FindFirstChild(selected)
        TargetPlayer = found or nil
    end,
})

-- Atualizar lista ao entrar/sair
Players.PlayerAdded:Connect(function()
    task.wait(0.5)
    playerDropdown:Refresh(getPlayerNames(), true)
end)

Players.PlayerRemoving:Connect(function(p)
    if p == TargetPlayer then
        TargetPlayer = nil
        AttachEnabled = false
    end
    task.wait(0.5)
    playerDropdown:Refresh(getPlayerNames(), true)
end)

-- ───────────────────────────────────────────────
-- SEÇÃO: Position Selection
-- ───────────────────────────────────────────────
TabAttach:Section({ Name = "Position Type" })

TabAttach:Dropdown({
    Name    = "Position Mode",
    Options = { "Behind", "Front", "Above", "Below", "Left", "Right", "TopDown", "Orbit" },
    Default = "Behind",
    Tooltip = "Posição relativa ao alvo",
    Callback = function(selected)
        SelectedPosition = selected
    end,
})

-- ───────────────────────────────────────────────
-- SEÇÃO: Sliders
-- ───────────────────────────────────────────────
TabAttach:Section({ Name = "Movement Settings" })

TabAttach:Slider({
    Name    = "Distance",
    Min     = 1,
    Max     = 30,
    Default = 5,
    Tooltip = "Distância até o alvo",
    Callback = function(val)
        DistanceValue = val
    end,
})

TabAttach:Slider({
    Name    = "Tween Speed",
    Min     = 1,
    Max     = 20,
    Default = 7,
    Tooltip = "Velocidade do movimento (maior = mais rápido)",
    Callback = function(val)
        -- Converte escala 1-20 para tempo de tween (menor = mais rápido)
        SpeedValue = 0.5 / val
    end,
})

TabAttach:Slider({
    Name    = "Orbit Speed",
    Min     = 1,
    Max     = 10,
    Default = 3,
    Tooltip = "Velocidade de rotação no modo Orbit",
    Callback = function(val)
        OrbitSpeedValue = val * 0.5
    end,
})

-- ───────────────────────────────────────────────
-- SEÇÃO: Toggles
-- ───────────────────────────────────────────────
TabAttach:Section({ Name = "Controls" })

TabAttach:Toggle({
    Name    = "Toggle Attach",
    Default = false,
    Tooltip = "Ativa movimentação relativa ao alvo",
    Callback = function(state)
        AttachEnabled = state
        if not state and currentTween then
            currentTween:Cancel()
        end
    end,
})

TabAttach:Toggle({
    Name    = "Auto Attack",
    Default = false,
    Tooltip = "Ataca automaticamente o alvo (requer tool equipada)",
    Callback = function(state)
        AutoAttackEnabled = state
    end,
})

-- ============================================================
-- ABA: Eu Consegui 😌
-- ============================================================
local TabWin = Window:Tab({
    Name = "eu consegui 😌",
    Icon = "party-popper",
})

TabWin:Section({ Name = "🎉 Parabéns!" })

TabWin:Paragraph({
    Title   = "Missão Cumprida 😌",
    Content = "Você configurou o Target Attach com sucesso!\nO CoiledTom Hub está funcionando corretamente.\n\nAproveite o script!",
})

TabWin:Paragraph({
    Title   = "Créditos",
    Content = "Script desenvolvido por CoiledTom.\nUI: Wind UI v2 by Footagesus.\nDistribuição via GitHub & Discord.",
})

TabWin:Button({
    Name    = "✅ Fechar aviso",
    Tooltip = "Fechar mensagem",
    Callback = function()
        WindUI:Notify({
            Title   = "CoiledTom Hub",
            Content = "Pronto! Bom jogo 😌",
            Duration = 3,
        })
    end,
})

-- ============================================================
-- FIM DO SCRIPT
-- ============================================================
print("[CoiledTom Hub] Target Attach carregado com sucesso!")
