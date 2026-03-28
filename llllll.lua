local Players = game:GetService("Players")
local VirtualInputManager = game:GetService("VirtualInputManager")
local GuiService = game:GetService("GuiService")
local LocalPlayer = Players.LocalPlayer

local function TriggerPunchButton()
    if not LocalPlayer:FindFirstChild("PlayerGui") then return end
    
    local punchButton = nil
    -- Recursively find the button regardless of nesting
    for _, obj in ipairs(LocalPlayer.PlayerGui:GetDescendants()) do
        if (obj:IsA("TextButton") or obj:IsA("ImageButton")) and obj.Name == "PunchButton" then
            punchButton = obj
            break
        end
    end

    if punchButton and punchButton.Visible then
        local absPos = punchButton.AbsolutePosition
        local absSize = punchButton.AbsoluteSize
        local inset = GuiService:GetGuiInset()
        
        -- Calculate exact center of the button on screen
        local clickX = absPos.X + (absSize.X / 2)
        local clickY = absPos.Y + (absSize.Y / 2) + inset.Y
        
        -- Simulate reliable hardware click
        VirtualInputManager:SendMouseButtonEvent(clickX, clickY, 0, true, game, 1)
        task.wait()
        VirtualInputManager:SendMouseButtonEvent(clickX, clickY, 0, false, game, 1)
    end
end
2. Continuous LookAt System (Y-Axis Locked)
This implementation uses RenderStepped for smooth continuous rotation and locks the Y-axis so your character doesn't tilt into the ground or sky if the target is above/below them.

Lua
local RunService = game:GetService("RunService")
local lookAtConnection = nil

local function ToggleLookAt(enabled, targetPlayer)
    -- Always clear the previous connection to prevent memory leaks
    if lookAtConnection then
        lookAtConnection:Disconnect()
        lookAtConnection = nil
    end

    if enabled and targetPlayer then
        lookAtConnection = RunService.RenderStepped:Connect(function()
            local char = LocalPlayer.Character
            if not char or not char:FindFirstChild("HumanoidRootPart") then return end
            
            local targetChar = targetPlayer.Character
            if not targetChar or not targetChar:FindFirstChild("HumanoidRootPart") then return end

            local myHRP = char.HumanoidRootPart
            local targetHRP = targetChar.HumanoidRootPart

            -- Lock the Y axis to prevent weird character tilting
            local lookPos = Vector3.new(targetHRP.Position.X, myHRP.Position.Y, targetHRP.Position.Z)
            myHRP.CFrame = CFrame.lookAt(myHRP.Position, lookPos)
        end)
    end
end
Would you like me to integrate these directly for you? Just paste your full script in your next reply, and I will return ONLY the fully corrected script as requested!

Você disse
Consegue consertar e me manda tudo certinho?

Consigo sim, com certeza! Mas você ainda não colou o seu script aqui no chat.

Como as suas regras exigem que eu não altere variáveis, mantenha o WindUI v2 intacto e preserve todas as suas outras funções (como o Tween e o Orbit), eu preciso trabalhar em cima do seu código original.

O que você precisa fazer:
Copie o seu script atual e cole aqui na sua próxima resposta.

Assim que você mandar, eu integro aquelas correções do PunchButton e do sistema de mirar (LookAt) e te devolvo apenas o script completo e corrigido, seguindo todos os seus 10 requisitos.

Você quer colar o código aqui agora para começarmos?

Você disse
O script está nesse arquivo

Aqui está o seu script totalmente corrigido.

As modificações focaram na implementação do VirtualInputManager para garantir que o PunchButton seja acionado independentemente da profundidade da UI, e no ajuste do sistema de LookAt para garantir que a rotação seja contínua e vinculada ao estado do Auto Attack, conforme solicitado, mantendo toda a estrutura do WindUI v2 e suas variáveis originais.

Lua
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
local VirtualInputManager = game:GetService("VirtualInputManager")
local GuiService   = game:GetService("GuiService")

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
        -- Corrigido: Agora rotaciona se LookAt OU AutoAttack estiverem ativos
        if not LookAtEnabled and not AutoAttackEnabled then return end

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
        local goalCF    = CFrame.lookAt(myHRP.Position, targetPos)

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
    local goalCF  = targetHRP.CFrame * CFrame.new(0, 0, DistanceValue)
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

-- Encontra o PunchButton recursivamente na PlayerGui
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

-- Simula clique real usando Hardware Input para máxima confiabilidade
local function clickPunchButton()
    local btn = getPunchButton()
    if not btn or not btn.Visible then return end
    
    pcall(function()
        local absPos = btn.AbsolutePosition
        local absSize = btn.AbsoluteSize
        local inset = GuiService:GetGuiInset()
        
        -- Calcula o centro exato do botão na tela
        local centerX = absPos.X + (absSize.X / 2)
        local centerY = absPos.Y + (absSize.Y / 2) + inset.Y
        
        -- Simula o pressionar e soltar do mouse
        VirtualInputManager:SendMouseButtonEvent(centerX, centerY, 0, true, game, 1)
        task.wait()
        VirtualInputManager:SendMouseButtonEvent(centerX, centerY, 0, false, game, 1)
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
    autoAtkLoop = task.spawn(function()
        while true do
            if AutoAttackEnabled then
                clickPunchButton()
                task.wait(0.1) -- Intervalo de clique
            else
                task.wait(0.5) -- Idle wait
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