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
SpeedValue        = 100   -- 1 a 1000, quanto maior mais rápido
OrbitSpeedValue   = 1.5
SelectedPosition  = "Behind"

local orbitAngle  = 0
local attachLoop  = nil
local orbitLoop   = nil
local autoAtkLoop = nil

-- ═══════════════════════════════════
--  TABELA DE POSIÇÕES
-- ═══════════════════════════════════
local Positions = {
    Behind  = { offset = Vector3.new(0, 0,  1), angle = 0          },
    Front   = { offset = Vector3.new(0, 0, -1), angle = math.pi    },
    Above   = { offset = Vector3.new(0, 1,  0), angle = 0          },
    Below   = { offset = Vector3.new(0,-1,  0), angle = 0          },
    Left    = { offset = Vector3.new(-1,0,  0), angle = math.pi/2  },
    Right   = { offset = Vector3.new( 1,0,  0), angle =-math.pi/2  },
    TopDown = { offset = Vector3.new(0, 1,  0), angle = math.pi/2  },
    Orbit   = { offset = Vector3.new(0, 0,  1), angle = 0          },
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
    return CFrame.new(targetHRP.Position + worldOffset) * CFrame.Angles(0, pos.angle, 0)
end

-- Tween suave: SpeedValue 1-1000 vira tempo de 1.0s até 0.001s
local function createTween(character, goalCFrame)
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local tweenTime = 1.0 / SpeedValue  -- 1 = lento (1s), 1000 = quase instantâneo (0.001s)
    local info = TweenInfo.new(tweenTime, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
    local t = TweenService:Create(hrp, info, { CFrame = goalCFrame })
    t:Play()
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
        if not goal then return end
        -- Movimento direto: rápido e responsivo
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then
            hrp.CFrame = hrp.CFrame:Lerp(goal, math.clamp(SpeedValue / 500, 0.05, 1))
        end
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
        if not goal then return end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then
            hrp.CFrame = hrp.CFrame:Lerp(goal, math.clamp(SpeedValue / 500, 0.05, 1))
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
    local initialPlayers = getPlayerNames()
    playerDropdown = TabAttach:Dropdown({
        Title    = "Select Target",
        Desc     = "Escolha o player alvo",
        Options  = initialPlayers,
        Default  = initialPlayers[1],
        Callback = function(selected)
            if selected == "(Nenhum player)" then
                TargetPlayer = nil
            else
                TargetPlayer = Players:FindFirstChild(selected) or nil
                WindUI:Notify({ Title = "Target", Content = "Alvo: " .. tostring(selected), Duration = 2 })
            end
        end,
    })

    Players.PlayerAdded:Connect(function()
        task.wait(0.5)
        pcall(function() playerDropdown:Refresh(getPlayerNames()) end)
    end)
    Players.PlayerRemoving:Connect(function(p)
        if p == TargetPlayer then
            TargetPlayer = nil
            AttachEnabled = false
        end
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

    -- ── Position Mode ─────────────────────────────────
    TabAttach:Section({ Title = "Position Mode" })

    -- FIX: Options como tabela de strings simples, Default igual ao primeiro item
    local posOptions = {"Behind", "Front", "Above", "Below", "Left", "Right", "TopDown", "Orbit"}
    TabAttach:Dropdown({
        Title    = "Position Type",
        Desc     = "Posição relativa ao alvo",
        Options  = posOptions,
        Default  = posOptions[1],
        Callback = function(selected)
            SelectedPosition = tostring(selected)
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

    -- SpeedValue de 1 a 1000 conforme pedido
    TabAttach:Slider({
        Title = "Tween Speed",
        Desc  = "Velocidade do movimento (1 = lento | 1000 = instantâneo)",
        Step  = 1,
        Value = { Min = 1, Max = 1000, Default = 100 },
        Callback = function(v)
            SpeedValue = v
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
