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
local RunService   = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

-- ═══════════════════════════════════
--  VARIÁVEIS GLOBAIS
-- ═══════════════════════════════════
TargetPlayer      = nil
AttachEnabled     = false
AutoAttackEnabled = false
DistanceValue     = 5
OrbitSpeedValue   = 1.5
SelectedPosition  = "Behind"  -- "Behind" | "OrbitTop"

local orbitAngle  = 0
local attachLoop  = nil
local orbitLoop   = nil
local autoAtkLoop = nil

-- ═══════════════════════════════════
--  FUNÇÕES
-- ═══════════════════════════════════
local function getTarget()
    if TargetPlayer and TargetPlayer.Character then
        return TargetPlayer.Character:FindFirstChild("HumanoidRootPart")
    end
    return nil
end

-- BEHIND: instantâneo, sempre atrás baseado na rotação atual do alvo
local function attachBehind(myHRP, targetHRP)
    -- Pega o CFrame atrás do alvo com base na direção que ele está olhando
    local behindCF = targetHRP.CFrame * CFrame.new(0, 0, DistanceValue)
    -- Rotaciona o player local para olhar para o alvo
    local lookDir = (targetHRP.Position - behindCF.Position).Unit
    myHRP.CFrame = CFrame.lookAt(behindCF.Position, behindCF.Position + lookDir)
end

-- ORBIT TOP: órbita em cima do alvo, apontando para baixo
local function attachOrbitTop(myHRP, targetHRP, dt)
    orbitAngle = orbitAngle + OrbitSpeedValue * dt
    local radius = DistanceValue
    local height = DistanceValue * 1.2
    local x = math.cos(orbitAngle) * radius
    local z = math.sin(orbitAngle) * radius
    local orbitPos = targetHRP.Position + Vector3.new(x, height, z)
    -- Apontando para baixo (olha para o alvo que está embaixo)
    myHRP.CFrame = CFrame.lookAt(orbitPos, targetHRP.Position)
end

-- ═══════════════════════════════════
--  LOOPS
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

        if SelectedPosition == "Behind" then
            attachBehind(myHRP, targetHRP)
        elseif SelectedPosition == "OrbitTop" then
            attachOrbitTop(myHRP, targetHRP, dt)
        end
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
        local names = getPlayerNames()
        pcall(function() playerDropdown:Refresh(names) end)
    end

    playerDropdown = TabAttach:Dropdown({
        Title    = "Select Target",
        Desc     = "Escolha o player alvo",
        Options  = getPlayerNames(),
        Default  = getPlayerNames()[1],
        Callback = function(selected)
            if selected ~= "(Nenhum player)" then
                TargetPlayer = Players:FindFirstChild(selected) or nil
                WindUI:Notify({ Title = "Target", Content = "Alvo: " .. tostring(selected), Duration = 2 })
            else
                TargetPlayer = nil
            end
        end,
    })

    -- Aguarda 1s e já atualiza automaticamente ao carregar
    task.defer(function()
        task.wait(1)
        pcall(refreshDropdown)
    end)

    Players.PlayerAdded:Connect(function()
        task.wait(0.5)
        pcall(refreshDropdown)
    end)
    Players.PlayerRemoving:Connect(function(p)
        if p == TargetPlayer then TargetPlayer = nil; AttachEnabled = false end
        task.wait(0.5)
        pcall(refreshDropdown)
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

    -- Apenas 2 opções conforme pedido
    local posOptions = { "Behind", "OrbitTop" }
    TabAttach:Dropdown({
        Title    = "Position Type",
        Desc     = "Behind = atrás instantâneo | OrbitTop = órbita em cima",
        Options  = posOptions,
        Default  = "Behind",
        Callback = function(selected)
            SelectedPosition = tostring(selected)
            -- Reseta ângulo ao trocar modo
            orbitAngle = 0
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
        Title = "Orbit Speed",
        Desc  = "Velocidade de rotação no modo OrbitTop",
        Step  = 1,
        Value = { Min = 1, Max = 10, Default = 3 },
        Callback = function(v)
            OrbitSpeedValue = v * 0.5
        end,
    })

    -- ── Controls ──────────────────────────────────────
    TabAttach:Section({ Title = "Controls" })

    TabAttach:Toggle({
        Title = "Toggle Attach",
        Desc  = "Ativa movimentação relativa ao alvo",
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
        Desc  = "Ataca automaticamente o alvo (tool equipada)",
        Value = false,
        Callback = function(v)
            AutoAttackEnabled = v
            WindUI:Notify({
                Title    = "Auto Attack",
                Content  = v and "Auto Attack ATIVADO!" or "Auto Attack desativado.",
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
