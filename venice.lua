--=== Venice/ntS :: Impulsos & Dashboard (v0.9.4 - Com Aba de Configurações) ===--
if _G.__VEGG then pcall(function() _G.__VEGG:Destroy() end) end
_G.__VEGG = nil

print("[ntS] v0.9.4 carregando...")

local START = os.clock()

local CONFIG = {
    TITLE = "VENICE",
    ICON = "112737554168952",
    FILE = "venice.png",
    EXP_NAME = "Elixir de XP Assustador III",
    WAIT_EXP = 15 * 60,
    MIN_B = 3,
    MAX_B = 1200,
}

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local LP = Players.LocalPlayer
local Cam = workspace.CurrentCamera

local LogLines = {}
local LogBox = nil
local Event = RS:FindFirstChild("rEvents") and RS.rEvents:FindFirstChild("consumeBoostEvent")

local Auto = {
    protein = { on = false, qty = 10, wait = 20 * 60, nextAt = 0, gen = 0, item = nil },
    exp     = { on = false, qty = 1,  wait = CONFIG.WAIT_EXP, nextAt = 0, gen = 0, item = nil },
}

local Tracker = { lbl = nil }

local SKIP = { "punch", "soco", "stomp", "ground slam", "ground", "slam", "kick", "chute",
    "weight", "peso", "situp", "abdominal", "pushup", "flexao", "pullup", "barra",
    "handstand", "parada", "dumbbell", "halter", "fist", "punho" }

local BOOST = { "elixir", "pocao", "potion", "boost", "impulso", "protein", "proteina", "ovo", "egg",
    "xp", "exp", "sorte", "luck", "dano", "damage", "forca", "strength", "speed", "velocidade",
    "moeda", "coin", "cash", "dinheiro", "gem", "gema", "drop", "chance", "multiplicador", "multiplier",
    "assustador", "spooky", "fortuna", "reborn", "rebirth" }

local function has(list, n)
    if type(n) ~= "string" then return false end
    n = string.lower(n)
    for _, k in ipairs(list) do
        if n:find(k, 1, true) then return true end
    end
    return false
end

local function skip(n) return has(SKIP, n) end
local function isBoost(n) return (not skip(n)) and has(BOOST, n) end

local function log(msg)
    LogLines[#LogLines + 1] = tostring(msg)
    while #LogLines > 24 do table.remove(LogLines, 1) end
    if LogBox then pcall(function() LogBox.Text = table.concat(LogLines, "\n") end) end
    print("[ntS] " .. tostring(msg))
end

local function folder() return LP:FindFirstChild("consumablesFolder") end

local function roots()
    local out = {}
    local f = folder(); if f then out[#out + 1] = f end
    local bp = LP:FindFirstChild("Backpack"); if bp then out[#out + 1] = bp end
    local ch = LP.Character; if ch then out[#out + 1] = ch end
    return out
end

local function itemsNamed(name)
    local out = {}
    if not name then return out end
    for _, r in ipairs(roots()) do
        for _, o in ipairs(r:GetChildren()) do
            if o.Name == name then out[#out + 1] = o end
        end
    end
    return out
end

local function countNamed(name) return #itemsNamed(name) end

local function listItems()
    local seen, out = {}, {}
    for _, r in ipairs(roots()) do
        for _, o in ipairs(r:GetChildren()) do
            if not seen[o.Name] and isBoost(o.Name) then
                seen[o.Name] = true
                out[#out + 1] = o.Name
            end
        end
    end
    local final = {}
    for _, n in ipairs(out) do
        if countNamed(n) > 0 then final[#final + 1] = n end
    end
    table.sort(final)
    return final
end

local function norm(s)
    s = string.lower(s or "")
    return (s:gsub("á","a"):gsub("â","a"):gsub("ã","a"):gsub("é","e")
             :gsub("ê","e"):gsub("í","i"):gsub("ó","o"):gsub("ô","o")
             :gsub("õ","o"):gsub("ú","u"):gsub("ç","c"))
end

local function isExpBoost(name)
    local l = norm(name)
    if CONFIG.EXP_NAME and CONFIG.EXP_NAME ~= "" and l == norm(CONFIG.EXP_NAME) then return true end

    local elixir = l:find("elixir", 1, true)
    local expo   = l:find("xp", 1, true) or l:find("exp", 1, true)
    local tipo   = l:find("assustador", 1, true) or l:find("spooky", 1, true)
    local grau3  = l:find("iii", 1, true) or l:find(" 3", 1, true)

    if not (elixir and expo and tipo and grau3) then return false end
    if l:find(" ii", 1, true) and not l:find(" iii", 1, true) then return false end
    if l:find(" i", 1, true) and not l:find(" ii", 1, true) and not l:find(" iii", 1, true) then return false end
    return true
end

local function findExpBoost()
    if CONFIG.EXP_NAME and CONFIG.EXP_NAME ~= "" and #itemsNamed(CONFIG.EXP_NAME) > 0 then
        return CONFIG.EXP_NAME
    end
    local seen, best, bestN = {}, nil, 0
    for _, r in ipairs(roots()) do
        for _, o in ipairs(r:GetChildren()) do
            if not seen[o.Name] and isExpBoost(o.Name) then
                seen[o.Name] = true
                local c = countNamed(o.Name)
                if c > bestN then best, bestN = o.Name, c end
            end
        end
    end
    return best
end

local function findProtein()
    for _, n in ipairs(listItems()) do
        local l = string.lower(n)
        if l:find("protein", 1, true) or l:find("ovo", 1, true) or l:find("proteina", 1, true) then
            return n
        end
    end
    return nil
end

local function findByKey(kind)
    if kind == "exp" then return findExpBoost() end
    if kind == "protein" then return findProtein() end
    return nil
end

local function parseTime(txt)
    if not txt then return nil end
    local h = tonumber(txt:match("(%d+)%s*[hH]"))
    local m = tonumber(txt:match("(%d+)%s*[mM]"))
    local s = tonumber(txt:match("(%d+)%s*[sS]"))
    if not (h or m or s) then return nil end
    return (h or 0) * 3600 + (m or 0) * 60 + (s or 0)
end

local function siblingsTime(lbl)
    local p1 = lbl.Parent
    local function scan(box)
        if not box then return nil end
        for _, sib in ipairs(box:GetChildren()) do
            if sib:IsA("TextLabel") then
                local v = parseTime(sib.Text)
                if v then return v end
            end
        end
        return nil
    end
    local v1 = scan(p1)
    if v1 then return v1 end
    if p1 and p1.Parent then return scan(p1.Parent) end
    return nil
end

local function lblTime(lbl)
    if not lbl then return nil end
    local ok, txt = pcall(function()
        if not lbl.Parent then return nil end
        return lbl.Text
    end)
    if not ok or not txt then return nil end
    local v = parseTime(txt) or siblingsTime(lbl)
    if v and v >= CONFIG.MIN_B and v <= CONFIG.MAX_B then return v end
    return nil
end

local function snapshot()
    local map = {}
    local pg = LP:FindFirstChild("PlayerGui")
    if not pg then return map end
    for _, o in ipairs(pg:GetDescendants()) do
        if o:IsA("TextLabel") and o.Visible then
            local v = lblTime(o)
            if v then map[o] = v end
        end
    end
    return map
end

local function findCountdown()
    local a = snapshot()
    task.wait(2)
    local b = snapshot()
    local best, bestScore = nil, 0
    for lbl, v in pairs(b) do
        local old = a[lbl]
        if old and v < old then
            local t = ""
            pcall(function() t = string.lower(lbl.Text or "") end)
            local kw = 0
            if t:find("assustador", 1, true) or t:find("spooky", 1, true) or t:find("elixir", 1, true) then
                kw = 200
            elseif t:find("xp", 1, true) or t:find("exp", 1, true) then
                kw = 100
            end
            local score = kw + (old - v)
            if score > bestScore then best, bestScore = lbl, score end
        end
    end
    return best
end

local function trackUntilEnd(A, g)
    local lbl = Tracker.lbl
    local stale = 0
    while A.on and A.gen == g do
        local v = lblTime(lbl)
        if not v then
            stale = stale + 1
            if stale >= 4 then return true end
        else
            stale = 0
            A.nextAt = os.clock() + v
            if v <= 2 then return true end
        end
        task.wait(1)
    end
    return false
end

local function fmt(sec)
    sec = math.max(0, math.floor(sec or 0))
    return ("%02d:%02d"):format(math.floor(sec / 60), sec % 60)
end

local function fmt3(sec)
    sec = math.max(0, math.floor(sec or 0))
    return ("%02d:%02d:%02d"):format(math.floor(sec / 3600), math.floor(sec % 3600 / 60), sec % 60)
end

local function statsText()
    local parts = {}
    local ls = LP:FindFirstChild("leaderstats")
    if ls then
        for _, o in ipairs(ls:GetChildren()) do
            pcall(function()
                local v = o.Value
                if type(v) == "number" or type(v) == "string" or type(v) == "boolean" then
                    parts[#parts + 1] = o.Name .. ": " .. tostring(v)
                end
            end)
        end
    end
    if #parts == 0 then
        local n = 0
        local ok, attrs = pcall(function() return LP:GetAttributes() end)
        if ok and type(attrs) == "table" then
            for k, v in pairs(attrs) do
                local t = type(v)
                if t == "number" or t == "string" or t == "boolean" then
                    n = n + 1
                    if n > 14 then break end
                    parts[#parts + 1] = tostring(k) .. ": " .. tostring(v)
                end
            end
        end
    end
    if #parts == 0 then return "Sem estatísticas expostas no momento." end
    return table.concat(parts, "\n")
end

local function fireItem(name, qty)
    if not Event then return false, "evento ausente" end
    if not name then return false, "item indefinido" end
    local list = itemsNamed(name)
    if #list == 0 then return false, "sem itens" end
    local q = math.min(qty, #list)
    local ok = pcall(function() Event:FireServer(list[1], q) end)
    if not ok then return false, "erro" end
    return true, ("enviado x%d"):format(q)
end

local function autoLoop(kind)
    local A = Auto[kind]
    A.gen = A.gen + 1
    local g = A.gen
    task.spawn(function()
        task.wait(2)
        while A.on and A.gen == g do
            if kind == "exp" then
                local found = findCountdown()
                if found then
                    Tracker.lbl = found
                    local v = lblTime(found) or 0
                    log("buff ativo detectado, aguardando " .. fmt(v))
                    A.nextAt = os.clock() + v
                    trackUntilEnd(A, g)
                    log("buff terminou, disparando")
                else
                    Tracker.lbl = nil
                end
                if not A.on or A.gen ~= g then break end
            end

            local name = findByKey(kind)
            if name then
                A.item = name
                local ok, msg = fireItem(name, A.qty)
                log(("%s: %s (%s)"):format(kind, name, msg))

                if ok and kind == "exp" then
                    task.wait(3)
                    local again = findCountdown()
                    if again then
                        Tracker.lbl = again
                        local v = lblTime(again) or A.wait
                        log("confirmado, aguardando " .. fmt(v))
                        A.nextAt = os.clock() + v
                        trackUntilEnd(A, g)
                    else
                        log("sem confirmacao visual, fallback " .. fmt(A.wait))
                        A.nextAt = os.clock() + A.wait
                    end
                else
                    A.nextAt = os.clock() + (ok and A.wait or 10)
                end
            else
                log(kind .. ": item nao encontrado (nova tentativa em 5s)")
                A.nextAt = os.clock() + 5
            end

            while A.on and A.gen == g and os.clock() < A.nextAt do
                task.wait(1)
            end
        end
        A.nextAt = 0
    end)
end

local function stopAuto(kind)
    Auto[kind].on = false
    Auto[kind].gen = Auto[kind].gen + 1
    Auto[kind].nextAt = 0
    Tracker.lbl = nil
    log("Auto " .. kind .. " desligado")
end

local function build()
    local parent = (gethui and gethui()) or game:GetService("CoreGui")
    local old = parent:FindFirstChild("VeniceEgg")
    if old then old:Destroy() end

    local gui = Instance.new("ScreenGui")
    gui.Name = "VeniceEgg"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.Parent = parent
    if not gui.Parent then gui.Parent = LP:WaitForChild("PlayerGui", 5) end

    local usr = Instance.new("UIScale")
    usr.Parent = gui

    local f = Instance.new("Frame")
    f.Size = UDim2.fromOffset(580, 390)
    f.AnchorPoint = Vector2.new(0.5, 0.5)
    f.Position = UDim2.fromScale(0.5, 0.5)
    f.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
    f.BorderSizePixel = 0
    f.Active = true
    f.Draggable = true
    f.Parent = gui

    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 8)
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(220, 40, 40)
    stroke.Thickness = 1.5
    stroke.Transparency = 0.2
    stroke.Parent = f

    local logoBg = Instance.new("Frame")
    logoBg.Size = UDim2.fromOffset(32, 32)
    logoBg.Position = UDim2.fromOffset(14, 14)
    logoBg.BackgroundColor3 = Color3.fromRGB(220, 45, 45)
    logoBg.BorderSizePixel = 0
    logoBg.Parent = f
    Instance.new("UICorner", logoBg).CornerRadius = UDim.new(0, 6)

    local logoTxt = Instance.new("TextLabel")
    logoTxt.Size = UDim2.fromScale(1, 1)
    logoTxt.BackgroundTransparency = 1
    logoTxt.Font = Enum.Font.GothamBold
    logoTxt.TextSize = 16
    logoTxt.TextColor3 = Color3.fromRGB(255, 255, 255)
    logoTxt.Text = "U"
    logoTxt.Parent = logoBg

    local t = Instance.new("TextLabel")
    t.Size = UDim2.new(0, 200, 0, 32)
    t.Position = UDim2.fromOffset(56, 14)
    t.BackgroundTransparency = 1
    t.Font = Enum.Font.GothamBold
    t.TextSize = 18
    t.TextXAlignment = Enum.TextXAlignment.Left
    t.TextColor3 = Color3.fromRGB(240, 240, 240)
    t.Text = CONFIG.TITLE
    t.Parent = f

    local hide = Instance.new("TextButton")
    hide.Size = UDim2.fromOffset(28, 28)
    hide.Position = UDim2.new(1, -70, 0, 16)
    hide.BackgroundTransparency = 1
    hide.Font = Enum.Font.GothamBold
    hide.TextSize = 18
    hide.TextColor3 = Color3.fromRGB(160, 160, 170)
    hide.Text = "-"
    hide.Parent = f

    local close = Instance.new("TextButton")
    close.Size = UDim2.fromOffset(28, 28)
    close.Position = UDim2.new(1, -38, 0, 16)
    close.BackgroundTransparency = 1
    close.Font = Enum.Font.GothamBold
    close.TextSize = 16
    close.TextColor3 = Color3.fromRGB(160, 160, 170)
    close.Text = "✕"
    close.Parent = f

    close.MouseButton1Click:Connect(function()
        gui:Destroy()
    end)

    local panels = {}
    local function showPanel(id)
        for k, p in pairs(panels) do
            p.Visible = (k == id)
        end
    end

    local sidebar = Instance.new("ScrollingFrame")
    sidebar.Size = UDim2.new(0, 56, 1, -64)
    sidebar.Position = UDim2.fromOffset(14, 56)
    sidebar.BackgroundTransparency = 1
    sidebar.BorderSizePixel = 0
    sidebar.ScrollBarThickness = 0
    sidebar.Parent = f

    local sbLayout = Instance.new("UIListLayout")
    sbLayout.Padding = UDim.new(0, 8)
    sbLayout.Parent = sidebar

    local tabIds = { "impulses", "stats", "sync", "settings" }
    local sbButtons = {}

    for i, id in ipairs(tabIds) do
        local sbBtn = Instance.new("TextButton")
        sbBtn.Size = UDim2.fromOffset(40, 40)
        sbBtn.BackgroundColor3 = i == 1 and Color3.fromRGB(30, 30, 38) or Color3.fromRGB(22, 22, 26)
        sbBtn.BorderSizePixel = 0
        sbBtn.Text = (i == 1 and "⚡") or (i == 2 and "📊") or (i == 3 and "🔄") or "⚙️"
        sbBtn.TextSize = 15
        sbBtn.TextColor3 = i == 1 and Color3.fromRGB(220, 45, 45) or Color3.fromRGB(150, 150, 160)
        sbBtn.Parent = sidebar
        Instance.new("UICorner", sbBtn).CornerRadius = UDim.new(0, 6)

        local indicator = Instance.new("Frame")
        indicator.Size = UDim2.new(0, 3, 0, 24)
        indicator.Position = UDim2.new(0, -6, 0.5, -12)
        indicator.BackgroundColor3 = Color3.fromRGB(220, 45, 45)
        indicator.BorderSizePixel = 0
        indicator.Visible = (i == 1)
        indicator.Parent = sbBtn
        Instance.new("UICorner", indicator).CornerRadius = UDim.new(0, 2)

        sbButtons[id] = { btn = sbBtn, ind = indicator }

        sbBtn.MouseButton1Click:Connect(function()
            showPanel(id)
            for k, info in pairs(sbButtons) do
                local active = (k == id)
                info.ind.Visible = active
                info.btn.BackgroundColor3 = active and Color3.fromRGB(30, 30, 38) or Color3.fromRGB(22, 22, 26)
                info.btn.TextColor3 = active and Color3.fromRGB(220, 45, 45) or Color3.fromRGB(150, 150, 160)
            end
        end)
    end

    -- ==================== ABA 1: IMPULSOS & AUTO ====================
    local pImpulses = Instance.new("Frame")
    pImpulses.Size = UDim2.new(1, -84, 1, -64)
    pImpulses.Position = UDim2.fromOffset(70, 56)
    pImpulses.BackgroundTransparency = 1
    pImpulses.Visible = true
    pImpulses.Parent = f
    panels["impulses"] = pImpulses

    local scroll = Instance.new("ScrollingFrame")
    scroll.Size = UDim2.new(0, 220, 1, -20)
    scroll.Position = UDim2.fromOffset(10, 10)
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 3
    scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    scroll.Parent = pImpulses
    
    local lay = Instance.new("UIListLayout")
    lay.Padding = UDim.new(0, 4)
    lay.Parent = scroll

    local selected = nil
    local lastSig = ""

    local function paint()
        for _, o in ipairs(scroll:GetChildren()) do
            if o:IsA("TextButton") then
                if o:GetAttribute("nm") == selected then
                    o.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
                else
                    o.BackgroundColor3 = Color3.fromRGB(28, 28, 35)
                end
            end
        end
    end

    local function contains(list, v)
        for _, x in ipairs(list) do if x == v then return true end end
        return false
    end

    local function refresh()
        for _, ch in ipairs(scroll:GetChildren()) do
            if ch:IsA("TextButton") then ch:Destroy() end
        end
        local names = listItems()
        lastSig = table.concat(names, "|")
        if selected and not contains(names, selected) then selected = nil end
        if not selected and names[1] then selected = names[1] end

        if #names == 0 then
            local e = Instance.new("TextLabel")
            e.Size = UDim2.new(1, -8, 0, 24)
            e.BackgroundTransparency = 1
            e.Font = Enum.Font.Gotham
            e.TextSize = 11
            e.TextXAlignment = Enum.TextXAlignment.Left
            e.TextColor3 = Color3.fromRGB(140, 140, 150)
            e.Text = "  Nenhum impulso"
            e.Parent = scroll
        end

        for i, nm in ipairs(names) do
            local b = Instance.new("TextButton")
            b.Size = UDim2.new(1, -4, 0, 32)
            b.BackgroundColor3 = Color3.fromRGB(28, 28, 35)
            b.BorderSizePixel = 0
            b.Text = ""
            b.LayoutOrder = i
            b:SetAttribute("nm", nm)
            b.Parent = scroll
            Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)

            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.new(1, -12, 1, 0)
            lbl.Position = UDim2.fromOffset(8, 0)
            lbl.BackgroundTransparency = 1
            lbl.Font = Enum.Font.GothamMedium
            lbl.TextSize = 11
            lbl.TextXAlignment = Enum.TextXAlignment.Left
            lbl.TextTruncate = Enum.TextTruncate.AtEnd
            lbl.TextColor3 = Color3.fromRGB(230, 230, 230)
            lbl.Text = nm .. "  (x" .. countNamed(nm) .. ")"
            lbl.Parent = b

            b.MouseButton1Click:Connect(function()
                selected = nm
                paint()
                log("Selecionado: " .. nm)
            end)
        end
        scroll.CanvasSize = UDim2.new(0, 0, 0, lay.AbsoluteContentSize.Y + 6)
        paint()
    end

    local rightCol = Instance.new("Frame")
    rightCol.Size = UDim2.new(1, -240, 1, -20)
    rightCol.Position = UDim2.fromOffset(235, 10)
    rightCol.BackgroundTransparency = 1
    rightCol.Parent = pImpulses

    local function mkToggle(txt, y, cb)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 0, 30)
        btn.Position = UDim2.fromOffset(0, y)
        btn.BackgroundColor3 = Color3.fromRGB(28, 28, 35)
        btn.BorderSizePixel = 0
        btn.Font = Enum.Font.GothamMedium
        btn.TextSize = 11
        btn.TextColor3 = Color3.fromRGB(240, 240, 240)
        btn.Text = "  " .. txt
        btn.TextXAlignment = Enum.TextXAlignment.Left
        btn.Parent = rightCol
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)

        local check = Instance.new("Frame")
        check.Size = UDim2.fromOffset(14, 14)
        check.AnchorPoint = Vector2.new(1, 0.5)
        check.Position = UDim2.new(1, -10, 0.5, 0)
        check.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
        check.BorderSizePixel = 0
        check.Parent = btn
        Instance.new("UICorner", check).CornerRadius = UDim.new(0, 3)
        local strokeChk = Instance.new("UIStroke")
        strokeChk.Color = Color3.fromRGB(220, 45, 45)
        strokeChk.Parent = check

        local active = false
        btn.MouseButton1Click:Connect(function()
            active = not active
            check.BackgroundColor3 = active and Color3.fromRGB(220, 45, 45) or Color3.fromRGB(35, 35, 45)
            cb(active)
        end)
        return btn
    end

    local pBtn = mkToggle("AUTO PROTEIN 10x", 0, function(state)
        if state then
            Auto.protein.on = true
            autoLoop("protein")
            pBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
        else
            stopAuto("protein")
            pBtn.TextColor3 = Color3.fromRGB(240, 240, 240)
        end
    end)

    local eBtn = mkToggle("AUTO ELIXIR XP III 1x", 35, function(state)
        if state then
            Auto.exp.on = true
            autoLoop("exp")
            eBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
        else
            stopAuto("exp")
            eBtn.TextColor3 = Color3.fromRGB(240, 240, 240)
        end
    end)

    local btnX1 = Instance.new("TextButton")
    btnX1.Size = UDim2.new(0.32, 0, 0, 28)
    btnX1.Position = UDim2.fromOffset(0, 70)
    btnX1.BackgroundColor3 = Color3.fromRGB(220, 45, 45)
    btnX1.BorderSizePixel = 0
    btnX1.Font = Enum.Font.GothamBold
    btnX1.TextSize = 11
    btnX1.TextColor3 = Color3.fromRGB(255, 255, 255)
    btnX1.Text = "USAR x1"
    btnX1.Parent = rightCol
    Instance.new("UICorner", btnX1).CornerRadius = UDim.new(0, 4)
    btnX1.MouseButton1Click:Connect(function()
        if selected then log("manual: " .. select(2, fireItem(selected, 1)) .. " " .. selected) end
    end)

    local btnX5 = Instance.new("TextButton")
    btnX5.Size = UDim2.new(0.32, 0, 0, 28)
    btnX5.Position = UDim2.new(0.34, 0, 0, 70)
    btnX5.BackgroundColor3 = Color3.fromRGB(45, 110, 70)
    btnX5.BorderSizePixel = 0
    btnX5.Font = Enum.Font.GothamBold
    btnX5.TextSize = 11
    btnX5.TextColor3 = Color3.fromRGB(255, 255, 255)
    btnX5.Text = "USAR x5"
    btnX5.Parent = rightCol
    Instance.new("UICorner", btnX5).CornerRadius = UDim.new(0, 4)
    btnX5.MouseButton1Click:Connect(function()
        if selected then log("manual: " .. select(2, fireItem(selected, 5)) .. " " .. selected) end
    end)

    local btnX10 = Instance.new("TextButton")
    btnX10.Size = UDim2.new(0.32, 0, 0, 28)
    btnX10.Position = UDim2.new(0.68, 0, 0, 70)
    btnX10.BackgroundColor3 = Color3.fromRGB(110, 70, 140)
    btnX10.BorderSizePixel = 0
    btnX10.Font = Enum.Font.GothamBold
    btnX10.TextSize = 11
    btnX10.TextColor3 = Color3.fromRGB(255, 255, 255)
    btnX10.Text = "USAR x10"
    btnX10.Parent = rightCol
    Instance.new("UICorner", btnX10).CornerRadius = UDim.new(0, 4)
    btnX10.MouseButton1Click:Connect(function()
        if selected then log("manual: " .. select(2, fireItem(selected, 10)) .. " " .. selected) end
    end)

    local logBoxBg = Instance.new("Frame")
    logBoxBg.Size = UDim2.new(1, 0, 0, 185)
    logBoxBg.Position = UDim2.fromOffset(0, 106)
    logBoxBg.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
    logBoxBg.BorderSizePixel = 0
    logBoxBg.Parent = rightCol
    Instance.new("UICorner", logBoxBg).CornerRadius = UDim.new(0, 4)

    local out = Instance.new("TextLabel")
    out.Size = UDim2.new(1, -12, 1, -12)
    out.Position = UDim2.fromOffset(6, 6)
    out.BackgroundTransparency = 1
    out.Font = Enum.Font.Code
    out.TextSize = 10
    out.TextXAlignment = Enum.TextXAlignment.Left
    out.TextYAlignment = Enum.TextYAlignment.Top
    out.TextWrapped = true
    out.TextColor3 = Color3.fromRGB(170, 200, 170)
    out.Text = ""
    out.Parent = logBoxBg
    LogBox = out


    -- ==================== ABA 2: ESTATÍSTICAS ====================
    local pStats = Instance.new("Frame")
    pStats.Size = UDim2.new(1, -84, 1, -64)
    pStats.Position = UDim2.fromOffset(70, 56)
    pStats.BackgroundTransparency = 1
    pStats.Visible = false
    pStats.Parent = f
    panels["stats"] = pStats

    local statsTitle = Instance.new("TextLabel")
    statsTitle.Size = UDim2.new(1, -20, 0, 24)
    statsTitle.Position = UDim2.fromOffset(10, 10)
    statsTitle.BackgroundTransparency = 1
    statsTitle.Font = Enum.Font.GothamBold
    statsTitle.TextSize = 14
    statsTitle.TextXAlignment = Enum.TextXAlignment.Left
    statsTitle.TextColor3 = Color3.fromRGB(240, 240, 240)
    statsTitle.Text = "ESTATÍSTICAS DO JOGADOR"
    statsTitle.Parent = pStats

    local statsBoxBg = Instance.new("Frame")
    statsBoxBg.Size = UDim2.new(1, -20, 1, -45)
    statsBoxBg.Position = UDim2.fromOffset(10, 38)
    statsBoxBg.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
    statsBoxBg.BorderSizePixel = 0
    statsBoxBg.Parent = pStats
    Instance.new("UICorner", statsBoxBg).CornerRadius = UDim.new(0, 4)

    local statsBox = Instance.new("TextLabel")
    statsBox.Size = UDim2.new(1, -16, 1, -16)
    statsBox.Position = UDim2.fromOffset(8, 8)
    statsBox.BackgroundTransparency = 1
    statsBox.Font = Enum.Font.Code
    statsBox.TextSize = 11
    statsBox.TextXAlignment = Enum.TextXAlignment.Left
    statsBox.TextYAlignment = Enum.TextYAlignment.Top
    statsBox.TextWrapped = true
    statsBox.TextColor3 = Color3.fromRGB(200, 210, 200)
    statsBox.Text = ""
    statsBox.Parent = statsBoxBg


    -- ==================== ABA 3: SINCRONIZADOR & STATUS ====================
    local pSync = Instance.new("Frame")
    pSync.Size = UDim2.new(1, -84, 1, -64)
    pSync.Position = UDim2.fromOffset(70, 56)
    pSync.BackgroundTransparency = 1
    pSync.Visible = false
    pSync.Parent = f
    panels["sync"] = pSync

    local syncTitle = Instance.new("TextLabel")
    syncTitle.Size = UDim2.new(1, -20, 0, 24)
    syncTitle.Position = UDim2.fromOffset(10, 10)
    syncTitle.BackgroundTransparency = 1
    syncTitle.Font = Enum.Font.GothamBold
    syncTitle.TextSize = 14
    syncTitle.TextXAlignment = Enum.TextXAlignment.Left
    syncTitle.TextColor3 = Color3.fromRGB(240, 240, 240)
    syncTitle.Text = "SINCRONIZADOR & STATUS"
    syncTitle.Parent = pSync

    local syncBoxBg = Instance.new("Frame")
    syncBoxBg.Size = UDim2.new(1, -20, 1, -45)
    syncBoxBg.Position = UDim2.fromOffset(10, 38)
    syncBoxBg.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
    syncBoxBg.BorderSizePixel = 0
    syncBoxBg.Parent = pSync
    Instance.new("UICorner", syncBoxBg).CornerRadius = UDim.new(0, 4)

    local syncInfoLbl = Instance.new("TextLabel")
    syncInfoLbl.Size = UDim2.new(1, -16, 0, 120)
    syncInfoLbl.Position = UDim2.fromOffset(8, 8)
    syncInfoLbl.BackgroundTransparency = 1
    syncInfoLbl.Font = Enum.Font.Code
    syncInfoLbl.TextSize = 11
    syncInfoLbl.TextXAlignment = Enum.TextXAlignment.Left
    syncInfoLbl.TextYAlignment = Enum.TextYAlignment.Top
    syncInfoLbl.TextWrapped = true
    syncInfoLbl.TextColor3 = Color3.fromRGB(170, 200, 220)
    syncInfoLbl.Text = "Sincronizador ativo.\nMonitorando inventário e contadores visuais..."
    syncInfoLbl.Parent = syncBoxBg

    local forceSyncBtn = Instance.new("TextButton")
    forceSyncBtn.Size = UDim2.new(1, -16, 0, 36)
    forceSyncBtn.Position = UDim2.fromOffset(8, 220)
    forceSyncBtn.BackgroundColor3 = Color3.fromRGB(220, 45, 45)
    forceSyncBtn.BorderSizePixel = 0
    forceSyncBtn.Font = Enum.Font.GothamBold
    forceSyncBtn.TextSize = 12
    forceSyncBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    forceSyncBtn.Text = "FORÇAR ATUALIZAÇÃO / SINCRONIZAR"
    forceSyncBtn.Parent = syncBoxBg
    Instance.new("UICorner", forceSyncBtn).CornerRadius = UDim.new(0, 4)
    forceSyncBtn.MouseButton1Click:Connect(function()
        refresh()
        log("Sincronização manual executada com sucesso.")
    end)


    -- ==================== ABA 4: CONFIGURAÇÕES ====================
    local pSettings = Instance.new("Frame")
    pSettings.Size = UDim2.new(1, -84, 1, -64)
    pSettings.Position = UDim2.fromOffset(70, 56)
    pSettings.BackgroundTransparency = 1
    pSettings.Visible = false
    pSettings.Parent = f
    panels["settings"] = pSettings

    local settTitle = Instance.new("TextLabel")
    settTitle.Size = UDim2.new(1, -20, 0, 24)
    settTitle.Position = UDim2.fromOffset(10, 10)
    settTitle.BackgroundTransparency = 1
    settTitle.Font = Enum.Font.GothamBold
    settTitle.TextSize = 14
    settTitle.TextXAlignment = Enum.TextXAlignment.Left
    settTitle.TextColor3 = Color3.fromRGB(240, 240, 240)
    settTitle.Text = "CONFIGURAÇÕES DO SCRIPT"
    settTitle.Parent = pSettings

    local settBoxBg = Instance.new("Frame")
    settBoxBg.Size = UDim2.new(1, -20, 1, -45)
    settBoxBg.Position = UDim2.fromOffset(10, 38)
    settBoxBg.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
    settBoxBg.BorderSizePixel = 0
    settBoxBg.Parent = pSettings
    Instance.new("UICorner", settBoxBg).CornerRadius = UDim.new(0, 4)

    -- Config 1: Velocidade Auto Protein (Delay em minutos)
    local lblProt = Instance.new("TextLabel")
    lblProt.Size = UDim2.new(1, -20, 0, 20)
    lblProt.Position = UDim2.fromOffset(10, 12)
    lblProt.BackgroundTransparency = 1
    lblProt.Font = Enum.Font.GothamMedium
    lblProt.TextSize = 11
    lblProt.TextXAlignment = Enum.TextXAlignment.Left
    lblProt.TextColor3 = Color3.fromRGB(200, 200, 210)
    lblProt.Text = "Intervalo Auto Protein (minutos):"
    lblProt.Parent = settBoxBg

    local boxProt = Instance.new("TextBox")
    boxProt.Size = UDim2.new(1, -20, 0, 30)
    boxProt.Position = UDim2.fromOffset(10, 34)
    boxProt.BackgroundColor3 = Color3.fromRGB(28, 28, 35)
    boxProt.BorderSizePixel = 0
    boxProt.Font = Enum.Font.Code
    boxProt.TextSize = 12
    boxProt.TextColor3 = Color3.fromRGB(255, 255, 255)
    boxProt.Text = tostring(Auto.protein.wait / 60)
    boxProt.Parent = settBoxBg
    Instance.new("UICorner", boxProt).CornerRadius = UDim.new(0, 4)

    boxProt.FocusLost:Connect(fnCsVerify or function(enter)
        local val = tonumber(boxProt.Text)
        if val and val > 0 then
            Auto.protein.wait = val * 60
            log("Config: Intervalo Protein alterado para " .. val .. " min")
        end
    end)

    -- Config 2: Alvo XP Personalizado
    local lblXp = Instance.new("TextLabel")
    lblXp.Size = UDim2.new(1, -20, 0, 20)
    lblXp.Position = UDim2.fromOffset(10, 75)
    lblXp.BackgroundTransparency = 1
    lblXp.Font = Enum.Font.GothamMedium
    lblXp.TextSize = 11
    lblXp.TextXAlignment = Enum.TextXAlignment.Left
    lblXp.TextColor3 = Color3.fromRGB(200, 200, 210)
    lblXp.Text = "Nome exato do Elixir de XP:"
    lblXp.Parent = settBoxBg

    local boxXp = Instance.new("TextBox")
    boxXp.Size = UDim2.new(1, -20, 0, 30)
    boxXp.Position = UDim2.fromOffset(10, 97)
    boxXp.BackgroundColor3 = Color3.fromRGB(28, 28, 35)
    boxXp.BorderSizePixel = 0
    boxXp.Font = Enum.Font.Code
    boxXp.TextSize = 12
    boxXp.TextColor3 = Color3.fromRGB(255, 255, 255)
    boxXp.Text = tostring(CONFIG.EXP_NAME)
    boxXp.Parent = settBoxBg
    Instance.new("UICorner", boxXp).CornerRadius = UDim.new(0, 4)

    boxXp.FocusLost:Connect(function(enter)
        if boxXp.Text ~= "" then
            CONFIG.EXP_NAME = boxXp.Text
            log("Config: Alvo XP alterado para: " .. CONFIG.EXP_NAME)
        end
    end)


    -- Botão Flutuante (Minimizado)
    local tg = Instance.new("TextButton")
    tg.Size = UDim2.fromOffset(48, 48)
    tg.AnchorPoint = Vector2.new(1, 1)
    tg.Position = UDim2.new(1, -14, 1, -14)
    tg.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
    tg.BorderSizePixel = 0
    tg.Font = Enum.Font.GothamBold
    tg.TextSize = 16
    tg.TextColor3 = Color3.fromRGB(220, 45, 45)
    tg.Text = "U"
    tg.Active = true
    tg.Draggable = true
    tg.Visible = false
    tg.Parent = gui
    Instance.new("UICorner", tg).CornerRadius = UDim.new(0, 8)
    local strokeTg = Instance.new("UIStroke")
    strokeTg.Color = Color3.fromRGB(220, 45, 45)
    strokeTg.Parent = tg

    local function fit()
        local vp = Cam and Cam.ViewportSize or Vector2.new(800, 600)
        local s = math.min(1, (vp.Y - 30) / 420, (vp.X - 30) / 600)
        usr.Scale = math.max(0.55, s)
    end
    fit()
    if Cam then
        Cam:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
    end

    hide.MouseButton1Click:Connect(function()
        f.Visible = false
        tg.Visible = true
    end)
    tg.MouseButton1Click:Connect(function()
        f.Visible = true
        tg.Visible = false
        fit()
    end)

    task.spawn(function()
        local tick = 0
        while gui.Parent do
            pcall(function()
                tick = tick + 1
                if tick % 2 == 0 then
                    statsBox.Text = statsText()
                    
                    local pStat = Auto.protein.on and (Auto.protein.nextAt > 0 and fmt(Auto.protein.nextAt - os.clock()) or "Disparando...") or "OFF"
                    local eStat = Auto.exp.on and (Auto.exp.nextAt > 0 and fmt(Auto.exp.nextAt - os.clock()) or "Disparando...") or "OFF"
                    syncInfoLbl.Text = string.format(
                        "Status do Sincronizador:\n- Uptime: %s\n- Auto Protein: %s\n- Auto XP: %s\n- Alvo XP: %s",
                        fmt3(os.clock() - START), pStat, eStat, tostring(findExpBoost())
                    )
                end
                if tick % 5 == 0 then
                    local sig = table.concat(listItems(), "|")
                    if sig ~= lastSig then refresh() end
                end
            end)
            task.wait(1)
        end
    end)

    refresh()
    return gui
end

local ok, err = pcall(build)
if ok then
    log("Venice/ntS v0.9.4 pronta.")
else
    print("[ntS] ERRO no build: " .. tostring(err))
end
