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

-- Faz o player local olhar para o alvo (mantém posição, só muda rotação)
local function lookAtTarget(myHRP, targetHRP)
    local pos    = myHRP.Position
    local lookAt = Vector3.new(targetHRP.Position.X, pos.Y, targetHRP.Position.Z)
    myHRP.CFrame = CFrame.lookAt(pos, lookAt)
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
--  AUTO ATTACK — procura botões/vars de ataque
-- ═══════════════════════════════════
-- Nomes comuns de RemoteEvents, Functions e botões de ataque
local ATTACK_KEYWORDS = {
    "attack", "Attack", "ATTACK",
    "hit", "Hit", "HIT",
    "swing", "Swing",
    "damage", "Damage",
    "strike", "Strike",
    "punch", "Punch",
    "slash", "Slash",
    "atk", "Atk", "ATK",
    "combat", "Combat",
    "fight", "Fight",
}

local function findAttackEvent(char)
    -- 1. Procura na tool equipada
    local tool = char:FindFirstChildOfClass("Tool")
    if tool then
        for _, obj in ipairs(tool:GetDescendants()) do
            if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") or obj:IsA("BindableEvent") then
                for _, kw in ipairs(ATTACK_KEYWORDS) do
                    if string.find(obj.Name, kw) then
                        return obj, "remote"
                    end
                end
            end
            -- Procura por ClickDetector ou ProximityPrompt dentro da tool
            if obj:IsA("ClickDetector") then
                return obj, "click"
            end
        end
    end

    -- 2. Procura no personagem
    for _, obj in ipairs(char:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") or obj:IsA("BindableEvent") then
            for _, kw in ipairs(ATTACK_KEYWORDS) do
                if string.find(obj.Name, kw) then
                    return obj, "remote"
                end
            end
        end
    end

    -- 3. Procura no workspace (scripts de jogo que ficam fora do char)
    for _, obj in ipairs(workspace:GetDescendants()) do
        if (obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction")) then
            for _, kw in ipairs(ATTACK_KEYWORDS) do
                if string.find(obj.Name, kw) then
                    return obj, "remote"
                end
            end
        end
    end

    return nil, nil
end

local function fireAttack(char)
    local evt, kind = findAttackEvent(char)
    if not evt then return end
    pcall(function()
        if kind == "remote" then
            if evt:IsA("RemoteEvent") then
                evt:FireServer()
            elseif evt:IsA("RemoteFunction") then
                evt:InvokeServer()
            elseif evt:IsA("BindableEvent") then
                evt:Fire()
            end
        elseif kind == "click" then
            -- Simula click
            local tool = char:FindFirstChildOfClass("Tool")
            if tool then
                tool:Activate()
            end
        end
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
    autoAtkLoop = RunService.Heartbeat:Connect(function()
        if not AutoAttackEnabled then return end
        local targetHRP = getTarget()
        if not targetHRP then return end
        local char = LocalPlayer.Character
        if not char then return end
        local myRoot = char:FindFirstChild("HumanoidRootPart")
        if not myRoot then return end
        local dist = (targetHRP.Position - myRoot.Position).Magnitude
        if dist <= DistanceValue + 6 then
            fireAttack(char)
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
        Desc  = "Procura e dispara eventos de ataque automaticamente",
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
