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
local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService   = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

-- ═══════════════════════════════════
--  VARIÁVEIS GLOBAIS
-- ═══════════════════════════════════
TargetPlayer      = nil
AttachEnabled     = false
AutoAttackEnabled = false
DistanceValue     = 5
TweenSpeedValue   = 100        -- usado só no modo Tween
OrbitSpeedValue   = 1.5
SelectedPosition  = "Behind"   -- "Behind" | "OrbitTop"
MovementMode      = "Teleport" -- "Teleport" | "Tween"

local orbitAngle  = 0
local attachLoop  = nil
local autoAtkLoop = nil

-- ═══════════════════════════════════
--  HELPERS
-- ═══════════════════════════════════
local function getTarget()
    if TargetPlayer and TargetPlayer.Character then
        return TargetPlayer.Character:FindFirstChild("HumanoidRootPart")
    end
    return nil
end

-- ═══════════════════════════════════
--  LOOK AT SYSTEM
-- ═══════════════════════════════════
LookAtEnabled      = false
LookAtSpeedValue   = 10     -- 1 (lento) a 20 (instantaneo)
LookAtMaxDist      = 100    -- distancia maxima para ativar o look

local lookLoop = nil

local function startLookLoop()
    if lookLoop then lookLoop:Disconnect() end
    lookLoop = RunService.Heartbeat:Connect(function(dt)
        if not LookAtEnabled then return end

        local targetHRP = getTarget()
        if not targetHRP then return end

        local char = LocalPlayer.Character
        if not char then return end
        local myHRP = char:FindFirstChild("HumanoidRootPart")
        if not myHRP then return end

        -- Checa distancia maxima
        local dist = (myHRP.Position - targetHRP.Position).Magnitude
        if dist > LookAtMaxDist then return end

        -- Calcula o CFrame destino olhando para o alvo (so eixo Y, sem inclinar)
        local targetPos = Vector3.new(targetHRP.Position.X, myHRP.Position.Y, targetHRP.Position.Z)
        local goalCF    = CFrame.new(myHRP.Position, targetPos)

        -- Lerp suave baseado na velocidade configurada
        local alpha = math.clamp(LookAtSpeedValue * dt, 0, 1)
        myHRP.CFrame = myHRP.CFrame:Lerp(goalCF, alpha)
    end)
end

-- ═══════════════════════════════════
--  MODOS DE MOVIMENTO
-- ═══════════════════════════════════

-- BEHIND: fica atrás do alvo olhando para ele
local function getBehindCF(targetHRP)
    -- CFrame.new(0,0,D) = atrás do alvo no espaço local dele
    local goalCF  = targetHRP.CFrame * CFrame.new(0, 0, DistanceValue)
    -- Vira o player para olhar de frente para o alvo
    local lookDir = (targetHRP.Position - goalCF.Position).Unit
    return CFrame.lookAt(goalCF.Position, goalCF.Position + lookDir)
end

-- ORBITTOP: órbita em cima apontando para baixo
local function getOrbitTopCF(targetHRP, dt)
    orbitAngle = orbitAngle + OrbitSpeedValue * dt
    local x   = math.cos(orbitAngle) * DistanceValue
    local z   = math.sin(orbitAngle) * DistanceValue
    local pos = targetHRP.Position + Vector3.new(x, DistanceValue * 1.2, z)
    return CFrame.lookAt(pos, targetHRP.Position)
end

-- Move o player com teleporte direto OU Tween dependendo do modo
local function movePlayer(myHRP, goalCF)
    if MovementMode == "Teleport" then
        myHRP.CFrame = goalCF
    else
        -- Tween: SpeedValue 1-1000 → tempo de 1s até 0.001s
        local t = TweenService:Create(
            myHRP,
            TweenInfo.new(1 / TweenSpeedValue, Enum.EasingStyle.Linear),
            { CFrame = goalCF }
        )
        t:Play()
    end
end

-- ═══════════════════════════════════
--  AUTO ATTACK — clica PunchButton em loop
-- ═══════════════════════════════════

-- Encontra o PunchButton na PlayerGui
local function getPunchButton()
    local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if not playerGui then return nil end
    for _, obj in ipairs(playerGui:GetDescendants()) do
        if (obj:IsA("TextButton") or obj:IsA("ImageButton")) and obj.Name == "PunchButton" then
            return obj
        end
    end
    return nil
end

-- Simula clique real no PunchButton
local function clickPunchButton()
    local btn = getPunchButton()
    if not btn then return end
    pcall(function()
        -- Metodo 1: fire direto do sinal (mais compativel)
        local vInputObject = {
            UserInputType = Enum.UserInputType.MouseButton1,
            UserInputState = Enum.UserInputState.Begin,
            Position = Vector3.new(0,0,0),
        }
        btn:SimulateClickOrTouch()
    end)
    pcall(function()
        -- Metodo 2: fireclick via MouseButton1Click (funciona na maioria dos jogos)
        btn.MouseButton1Click:Fire()
    end)
end

-- ═══════════════════════════════════
--  LOOPS PRINCIPAIS
-- ═══════════════════════════════════
local function startAttachLoop()
    if attachLoop then attachLoop:Disconnect() end
    attachLoop = RunService.Heartbeat:Connect(function(dt)
        if not AttachEnabled then return end

        local targetHRP = getTarget()
        if not targetHRP then return end
        local char = LocalPlayer.Character
        if not char then return end
        local myHRP = char:FindFirstChild("HumanoidRootPart")
        if not myHRP then return end

        local goalCF
        if SelectedPosition == "Behind" then
            goalCF = getBehindCF(targetHRP)
        elseif SelectedPosition == "OrbitTop" then
            goalCF = getOrbitTopCF(targetHRP, dt)
        end

        if goalCF then
            movePlayer(myHRP, goalCF)
        end
    end)
end

local function startAutoAttack()
    if autoAtkLoop then autoAtkLoop:Disconnect() end
    -- Usa task.spawn com loop proprio para bater em intervalo fixo (nao por frame)
    autoAtkLoop = RunService.Heartbeat:Connect(function()
        -- so usado para manter o loop vivo; o click e feito pelo task abaixo
    end)
    task.spawn(function()
        while true do
            task.wait(0.1) -- intervalo entre cliques (100ms)
            if not AutoAttackEnabled then
                task.wait(0.1)
            else
                clickPunchButton()
            end
        end
    end)
end

startAttachLoop()
startLookLoop()
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

local TabAttach = Window:Tab({ Title = "Target Attach", Icon = "solar:crosshairs-bold" })
local TabWin    = Window:Tab({ Title = "eu consegui 😌",  Icon = "solar:star-bold"     })

-- ══════════════════════════════════════════════════════
--  ABA: TARGET ATTACH
-- ══════════════════════════════════════════════════════
do
    -- ── Player Selection ──────────────────────────────
    TabAttach:Section({ Title = "Player Selection" })

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

    local function refreshDropdown()
        pcall(function() playerDropdown:Refresh(getPlayerNames()) end)
    end

    playerDropdown = TabAttach:Dropdown({
        Title    = "Select Target",
        Desc     = "Escolha o player alvo",
        Values   = getPlayerNames(),
        Callback = function(selected)
            if selected ~= "(Nenhum player)" then
                TargetPlayer = Players:FindFirstChild(selected) or nil
                WindUI:Notify({ Title = "Target", Content = "Alvo: " .. tostring(selected), Duration = 2 })
            else
                TargetPlayer = nil
            end
        end,
    })

    task.defer(function()
        task.wait(1)
        pcall(refreshDropdown)
    end)

    Players.PlayerAdded:Connect(function()
        task.wait(0.5); pcall(refreshDropdown)
    end)
    Players.PlayerRemoving:Connect(function(p)
        if p == TargetPlayer then TargetPlayer = nil; AttachEnabled = false end
        task.wait(0.5); pcall(refreshDropdown)
    end)

    TabAttach:Button({
        Title    = "Atualizar Lista",
        Icon     = "solar:refresh-bold",
        Desc     = "Recarrega os players disponíveis",
        Callback = function()
            pcall(refreshDropdown)
            WindUI:Notify({ Title = "Players", Content = "Lista atualizada!", Duration = 2 })
        end,
    })

    TabAttach:Button({
        Title    = "Anti Bug",
        Icon     = "solar:bug-bold",
        Desc     = "Clique em mim se estiver bugado",
        Callback = function()
            pcall(refreshDropdown)
            WindUI:Notify({ Title = "Anti Bug", Content = "Lista corrigida!", Duration = 2 })
        end,
    })

    -- ── Position Mode ─────────────────────────────────
    TabAttach:Section({ Title = "Position Mode" })

    TabAttach:Dropdown({
        Title    = "Position Type",
        Desc     = "Behind = atrás | OrbitTop = órbita em cima",
        Values   = { "Behind", "OrbitTop" },
        Callback = function(selected)
            SelectedPosition = tostring(selected)
            orbitAngle = 0
        end,
    })

    -- ── Movement Mode ─────────────────────────────────
    TabAttach:Section({ Title = "Movement Mode" })

    TabAttach:Dropdown({
        Title    = "Move Type",
        Desc     = "Teleport = instantâneo | Tween = suave",
        Values   = { "Teleport", "Tween" },
        Callback = function(selected)
            MovementMode = tostring(selected)
            WindUI:Notify({
                Title   = "Movement Mode",
                Content = "Modo: " .. tostring(selected),
                Duration = 2,
            })
        end,
    })

    -- ── Movement Settings ─────────────────────────────
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
        Desc  = "Velocidade do Tween (só ativo no modo Tween)",
        Step  = 1,
        Value = { Min = 1, Max = 1000, Default = 100 },
        Callback = function(v)
            TweenSpeedValue = v
        end,
    })

    TabAttach:Slider({
        Title = "Orbit Speed",
        Desc  = "Velocidade de rotação no modo OrbitTop",
        Step  = 1,
        Value = { Min = 1, Max = 10, Default = 3 },
        Callback = function(v)
            OrbitSpeedValue = v * 0.5
        end,
    })

    -- ── Look At Settings ──────────────────────────────
    TabAttach:Section({ Title = "Look At Settings" })

    TabAttach:Toggle({
        Title = "Look At Target",
        Desc  = "Personagem fica olhando para o alvo continuamente",
        Value = false,
        Callback = function(v)
            LookAtEnabled = v
            WindUI:Notify({
                Title    = "Look At",
                Content  = v and "Look At ATIVADO!" or "Look At desativado.",
                Duration = 2,
            })
        end,
    })

    TabAttach:Slider({
        Title = "Look At Speed",
        Desc  = "Velocidade de rotacao para olhar o alvo",
        Step  = 1,
        Value = { Min = 1, Max = 20, Default = 10 },
        Callback = function(v)
            LookAtSpeedValue = v
        end,
    })

    TabAttach:Slider({
        Title = "Max Distance",
        Desc  = "Distancia maxima para ativar o look at (studs)",
        Step  = 5,
        Value = { Min = 5, Max = 300, Default = 100 },
        Callback = function(v)
            LookAtMaxDist = v
        end,
    })

    -- ── Controls ──────────────────────────────────────
    TabAttach:Section({ Title = "Controls" })

    TabAttach:Toggle({
        Title = "Toggle Attach",
        Desc  = "Ativa movimentacao relativa ao alvo",
        Value = false,
        Callback = function(v)
            AttachEnabled = v
            WindUI:Notify({
                Title    = "Attach",
                Content  = v and "Attach ATIVADO!" or "Attach desativado.",
                Duration = 2,
            })
        end,
    })

    TabAttach:Toggle({
        Title = "Auto Attack",
        Desc  = "Clica PunchButton em loop automaticamente",
        Value = false,
        Callback = function(v)
            AutoAttackEnabled = v
            WindUI:Notify({
                Title    = "Auto Attack",
                Content  = v and "Auto Attack ATIVADO! Clicando PunchButton..." or "Auto Attack desativado.",
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
