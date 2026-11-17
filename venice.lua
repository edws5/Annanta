--=== Venice/ntS :: Consumiveis (v14) ===--
if _G.__VEGG then pcall(function() _G.__VEGG:Destroy() end) end
_G.__VEGG = nil

local CONFIG = {
    TITLE = "Venice/ntS",
    ICON = "112737554168952",
    FILE = "venice.png",
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
    exp     = { on = false, qty = 1,  wait = 15 * 60, nextAt = 0, gen = 0, item = nil },
}

local SKIP = { "punch", "soco", "stomp", "ground slam", "ground", "slam", "kick", "chute",
    "weight", "peso", "situp", "abdominal", "pushup", "flexao", "pullup", "barra",
    "handstand", "parada", "dumbbell", "halter", "fist", "punho" }

local function skip(n)
    n = string.lower(n)
    for _, k in ipairs(SKIP) do if n:find(k) then return true end end
    return false
end

local function log(msg)
    LogLines[#LogLines + 1] = tostring(msg)
    while #LogLines > 24 do table.remove(LogLines, 1) end
    if LogBox then pcall(function() LogBox.Text = table.concat(LogLines, "\n") end) end
    print("[ntS] " .. tostring(msg))
end

local function folder() return LP:FindFirstChild("consumablesFolder") end

local function itemsNamed(name)
    local out = {}
    local f = folder()
    if not f then return out end
    for _, o in ipairs(f:GetChildren()) do
        if o.Name == name then out[#out + 1] = o end
    end
    return out
end

local function countNamed(name) return #itemsNamed(name) end

local function uniqueItems()
    local seen, out = {}, {}
    local f = folder()
    if not f then return out end
    for _, o in ipairs(f:GetChildren()) do
        if not seen[o.Name] and not skip(o.Name) then
            seen[o.Name] = true
            out[#out + 1] = o.Name
        end
    end
    table.sort(out)
    return out
end

local function isExp3(l)
    local base = l:find("assustador") or l:find("spooky") or l:find("xp")
    if not base then return false end
    return (l:find("iii") or l:match("%s3$") or l:find("nivel 3")) ~= nil
end

local function findByKey(kind)
    for _, n in ipairs(uniqueItems()) do
        local l = string.lower(n)
        if kind == "protein" and (l:find("protein") or l:find("ovo")) then return n end
        if kind == "exp" and isExp3(l) then return n end
    end
    return nil
end

local function iconFor(name)
    local obj = itemsNamed(name)[1]
    if not obj then return nil end
    local ok, id = pcall(function()
        for _, k in ipairs({ "TextureId", "Texture", "Icon", "ImageId", "AssetId" }) do
            local a = obj:GetAttribute(k)
            if type(a) == "string" and a ~= "" then return a end
            local ch = obj:FindFirstChild(k)
            if ch and (ch:IsA("StringValue") or ch:IsA("NumberValue")) then return tostring(ch.Value) end
        end
        return nil
    end)
    if ok and id then
        local n = tostring(id):match("(%d+)")
        if n then return "rbxthumb://type=Asset&id=" .. n .. "&w=150&h=150" end
    end
    return nil
end

local function resolveIcon()
    if CONFIG.ICON and CONFIG.ICON ~= "" then
        local n = tostring(CONFIG.ICON):match("(%d+)")
        if n then return "rbxthumb://type=Asset&id=" .. n .. "&w=150&h=150" end
        return CONFIG.ICON
    end
    if CONFIG.FILE and isfile and getcustomasset then
        local ok, exists = pcall(isfile, CONFIG.FILE)
        if ok and exists then
            local ok2, p = pcall(getcustomasset, CONFIG.FILE)
            if ok2 and p then return p end
        end
    end
    return nil
end

--================ BUFF EXP (+100%) ================
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

local function readExpBuff()
    local pg = LP:FindFirstChild("PlayerGui")
    if not pg then return nil end
    local fallback
    for _, o in ipairs(pg:GetDescendants()) do
        if o:IsA("TextLabel") and o.Visible then
            local t = string.lower(o.Text or "")
            if t:find("exp", 1, true) then
                local v = parseTime(o.Text) or siblingsTime(o)
                if v then
                    if t:find("100", 1, true) then return v end
                    if not fallback then fallback = v end
                end
            end
        end
    end
    return fallback
end

local function fmt(sec)
    sec = math.max(0, math.floor(sec or 0))
    return ("%02d:%02d"):format(math.floor(sec / 60), sec % 60)
end

--================ DISPARO ================
local function fireItem(name, qty)
    if not Event then return false, "evento ausente" end
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
        while A.on and A.gen == g do
            if kind == "exp" then
                local rem = readExpBuff()
                if rem and rem > 3 then
                    log(("exp: buff +100% ativo, aguardando %s"):format(fmt(rem)))
                    local alvo = os.clock() + rem
                    A.nextAt = alvo
                    while A.on and A.gen == g and os.clock() < alvo - 3 do
                        task.wait(5)
                        local r2 = readExpBuff()
                        if r2 then alvo = os.clock() + r2; A.nextAt = alvo end
                    end
                end
                if not A.on or A.gen ~= g then break end
            end

            local name = findByKey(kind) or A.item
            if name then
                A.item = name
                local ok, msg = fireItem(name, A.qty)
                log(("%s: %s (%s)"):format(kind, name, msg))
            else
                log(kind .. ": item nao encontrado")
            end

            A.nextAt = os.clock() + A.wait
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
    log("Auto " .. kind .. " desligado")
end

--================ GUI ================
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
    f.Size = UDim2.fromOffset(280, 520)
    f.AnchorPoint = Vector2.new(0.5, 0.5)
    f.Position = UDim2.fromScale(0.5, 0.5)
    f.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
    f.BorderSizePixel = 0
    f.Active, f.Draggable = true, true
    f.Parent = gui
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 8); c.Parent = f

    local t = Instance.new("TextLabel")
    t.Size = UDim2.new(1, -40, 0, 26)
    t.Position = UDim2.fromOffset(8, 6)
    t.BackgroundTransparency = 1
    t.Font = Enum.Font.GothamBold
    t.TextSize = 13
    t.TextXAlignment = Enum.TextXAlignment.Left
    t.TextColor3 = Color3.fromRGB(240, 240, 240)
    t.Text = CONFIG.TITLE
    t.Parent = f

    local hide = Instance.new("TextButton")
    hide.Size = UDim2.fromOffset(24, 22)
    hide.Position = UDim2.new(1, -32, 0, 8)
    hide.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
    hide.BorderSizePixel = 0
    hide.Font = Enum.Font.GothamBold
    hide.TextSize = 13
    hide.TextColor3 = Color3.fromRGB(240, 240, 240)
    hide.Text = "-"
    hide.Parent = f
    local hc = Instance.new("UICorner"); hc.CornerRadius = UDim.new(0, 5); hc.Parent = hide

    local scroll = Instance.new("ScrollingFrame")
    scroll.Size = UDim2.new(1, -16, 0, 110)
    scroll.Position = UDim2.fromOffset(8, 34)
    scroll.BackgroundColor3 = Color3.fromRGB(26, 26, 31)
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 4
    scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    scroll.Parent = f
    local sc = Instance.new("UICorner"); sc.CornerRadius = UDim.new(0, 6); sc.Parent = scroll
    local lay = Instance.new("UIListLayout"); lay.Padding = UDim.new(0, 4); lay.Parent = scroll

    local selected
    local function paint()
        for _, o in ipairs(scroll:GetChildren()) do
            if o:IsA("TextButton") then
                o.BackgroundColor3 = (o:GetAttribute("nm") == selected)
                    and Color3.fromRGB(50, 110, 70) or Color3.fromRGB(40, 40, 46)
            end
        end
    end

    local function refresh()
        for _, ch in ipairs(scroll:GetChildren()) do
            if ch:IsA("TextButton") then ch:Destroy() end
        end
        local names = uniqueItems()
        selected = names[1]
        for i, nm in ipairs(names) do
            local b = Instance.new("TextButton")
            b.Size = UDim2.new(1, -8, 0, 32)
            b.BackgroundColor3 = Color3.fromRGB(40, 40, 46)
            b.BorderSizePixel = 0
            b.Text = ""
            b.LayoutOrder = i
            b:SetAttribute("nm", nm)
            b.Parent = scroll
            local bc = Instance.new("UICorner"); bc.CornerRadius = UDim.new(0, 4); bc.Parent = b
            local ico = Instance.new("ImageLabel")
            ico.Size = UDim2.fromOffset(26, 26)
            ico.Position = UDim2.fromOffset(3, 3)
            ico.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
            ico.BorderSizePixel = 0
            ico.ScaleType = Enum.ScaleType.Fit
            ico.Parent = b
            local ic = Instance.new("UICorner"); ic.CornerRadius = UDim.new(0, 4); ic.Parent = ico
            local url = iconFor(nm)
            if url then ico.Image = url end
            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.new(1, -38, 1, 0)
            lbl.Position = UDim2.fromOffset(34, 0)
            lbl.BackgroundTransparency = 1
            lbl.Font = Enum.Font.Gotham
            lbl.TextSize = 11
            lbl.TextXAlignment = Enum.TextXAlignment.Left
            lbl.TextTruncate = Enum.TextTruncate.AtEnd
            lbl.TextColor3 = Color3.fromRGB(235, 235, 235)
            lbl.Text = nm .. "   x" .. countNamed(nm)
            lbl.Parent = b
            b.MouseButton1Click:Connect(function()
                selected = nm; paint(); log("Selecionado: " .. nm)
            end)
        end
        scroll.CanvasSize = UDim2.new(0, 0, 0, lay.AbsoluteContentSize.Y + 8)
        paint()
    end

    local function mkBtn(txt, x, w, y, col, cb, h)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(w, -6, 0, h or 28)
        b.Position = UDim2.new(x, 8, 0, y)
        b.BackgroundColor3 = col
        b.BorderSizePixel = 0
        b.Font = Enum.Font.GothamBold
        b.TextSize = 11
        b.TextColor3 = Color3.fromRGB(245, 245, 245)
        b.Text = txt
        b.Parent = f
        local bc = Instance.new("UICorner"); bc.CornerRadius = UDim.new(0, 6); bc.Parent = b
        b.MouseButton1Click:Connect(cb)
        return b
    end

    mkBtn("x1", 0, 0.333, 150, Color3.fromRGB(45, 95, 140), function()
        if selected then log(select(2, fireItem(selected, 1)) .. " " .. selected) end
    end)
    mkBtn("x5", 0.333, 0.333, 150, Color3.fromRGB(45, 110, 70), function()
        if selected then log(select(2, fireItem(selected, 5)) .. " " .. selected) end
    end)
    mkBtn("x10", 0.666, 0.334, 150, Color3.fromRGB(110, 70, 140), function()
        if selected then log(select(2, fireItem(selected, 10)) .. " " .. selected) end
    end)

    local pBtn
    pBtn = mkBtn("AUTO PROTEIN 10x / 20min: OFF", 0, 1, 184, Color3.fromRGB(40, 80, 55), function()
        if Auto.protein.on then
            stopAuto("protein")
            pBtn.Text = "AUTO PROTEIN 10x / 20min: OFF"
            pBtn.BackgroundColor3 = Color3.fromRGB(40, 80, 55)
        else
            Auto.protein.on = true
            autoLoop("protein")
            pBtn.Text = "AUTO PROTEIN 10x / 20min: ON"
            pBtn.BackgroundColor3 = Color3.fromRGB(45, 150, 85)
        end
    end, 26)

    local pLbl = Instance.new("TextLabel")
    pLbl.Size = UDim2.new(1, -16, 0, 15)
    pLbl.Position = UDim2.fromOffset(8, 213)
    pLbl.BackgroundTransparency = 1
    pLbl.Font = Enum.Font.Code
    pLbl.TextSize = 10
    pLbl.TextXAlignment = Enum.TextXAlignment.Left
    pLbl.TextColor3 = Color3.fromRGB(170, 200, 170)
    pLbl.Text = "pronto"
    pLbl.Parent = f

    local eBtn
    eBtn = mkBtn("AUTO SPOOKY III 1x: OFF", 0, 1, 236, Color3.fromRGB(40, 60, 90), function()
        if Auto.exp.on then
            stopAuto("exp")
            eBtn.Text = "AUTO SPOOKY III 1x: OFF"
            eBtn.BackgroundColor3 = Color3.fromRGB(40, 60, 90)
        else
            Auto.exp.on = true
            autoLoop("exp")
            eBtn.Text = "AUTO SPOOKY III 1x: ON"
            eBtn.BackgroundColor3 = Color3.fromRGB(50, 100, 170)
        end
    end, 26)

    local eLbl = Instance.new("TextLabel")
    eLbl.Size = UDim2.new(1, -16, 0, 15)
    eLbl.Position = UDim2.fromOffset(8, 265)
    eLbl.BackgroundTransparency = 1
    eLbl.Font = Enum.Font.Code
    eLbl.TextSize = 10
    eLbl.TextXAlignment = Enum.TextXAlignment.Left
    eLbl.TextColor3 = Color3.fromRGB(170, 185, 210)
    eLbl.Text = "pronto"
    eLbl.Parent = f

    mkBtn("ATUALIZAR", 0, 0.5, 286, Color3.fromRGB(55, 55, 65), function()
        refresh(); log("Lista: " .. #uniqueItems())
    end)
    mkBtn("DIAG", 0.5, 0.5, 286, Color3.fromRGB(45, 60, 110), function()
        log("evento: " .. tostring(Event))
        log("alvo exp III: " .. tostring(findByKey("exp")))
        log("buff 100%: " .. tostring(readExpBuff()))
        for _, n in ipairs(uniqueItems()) do log("  " .. n .. " x" .. countNamed(n)) end
    end)

    local out = Instance.new("TextLabel")
    out.Size = UDim2.new(1, -16, 0, 196)
    out.Position = UDim2.fromOffset(8, 320)
    out.BackgroundTransparency = 1
    out.Font = Enum.Font.Code
    out.TextSize = 9
    out.TextXAlignment = Enum.TextXAlignment.Left
    out.TextYAlignment = Enum.TextYAlignment.Top
    out.TextWrapped = true
    out.TextColor3 = Color3.fromRGB(150, 200, 150)
    out.Text = ""
    out.Parent = f
    LogBox = out

    -- botao flutuante ancorado no canto
    local tg = Instance.new("TextButton")
    tg.Size = UDim2.fromOffset(52, 52)
    tg.AnchorPoint = Vector2.new(1, 1)
    tg.Position = UDim2.new(1, -14, 1, -14)
    tg.BackgroundColor3 = Color3.fromRGB(238, 234, 216)
    tg.BorderSizePixel = 0
    tg.Font = Enum.Font.GothamBold
    tg.TextSize = 18
    tg.TextColor3 = Color3.fromRGB(25, 25, 25)
    tg.Text = "V"
    tg.Active, tg.Draggable, tg.Visible = true, true, false
    tg.Parent = gui
    local tgc = Instance.new("UICorner"); tgc.CornerRadius = UDim.new(1, 0); tgc.Parent = tg

    local url = resolveIcon()
    if url then
        local img = Instance.new("ImageLabel")
        img.Size = UDim2.fromScale(1, 1)
        img.BackgroundTransparency = 1
        img.ScaleType = Enum.ScaleType.Crop
        img.Image = url
        img.Parent = tg
        local imc = Instance.new("UICorner"); imc.CornerRadius = UDim.new(1, 0); imc.Parent = img
        tg.Text = ""
    end

    -- escala para caber na tela
    local function fit()
        local vp = Cam and Cam.ViewportSize or Vector2.new(800, 600)
        local s = math.min(1, (vp.Y - 30) / 540, (vp.X - 30) / 300)
        usr.Scale = math.max(0.55, s)
    end
    fit()
    if Cam then
        Cam:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
    end

    local function setVisible(v)
        f.Visible = v
        tg.Visible = not v
        if v then fit() end
    end
    hide.MouseButton1Click:Connect(function() setVisible(false) end)
    tg.MouseButton1Click:Connect(function() setVisible(true) end)

    task.spawn(function()
        while gui.Parent do
            pLbl.Text = Auto.protein.on
                and (Auto.protein.nextAt > 0 and ("proximo em " .. fmt(Auto.protein.nextAt - os.clock())) or "disparando...")
                or "pronto"

            if Auto.exp.on then
                local b = readExpBuff()
                if b and b > 0 then
                    eLbl.Text = "+100% EXP ativo: " .. fmt(b) .. " (uso quando zerar)"
                elseif Auto.exp.nextAt > 0 then
                    eLbl.Text = "proximo em " .. fmt(Auto.exp.nextAt - os.clock())
                else
                    eLbl.Text = "disparando..."
                end
            else
                local b = readExpBuff()
                eLbl.Text = b and ("off (buff " .. fmt(b) .. ")") or "pronto"
            end
            task.wait(1)
        end
    end)

    refresh()
    _G.__VEGG = { Destroy = function()
        Auto.protein.on = false; Auto.exp.on = false
        Auto.protein.gen = Auto.protein.gen + 1
        Auto.exp.gen = Auto.exp.gen + 1
        pcall(function() gui:Destroy() end)
        _G.__VEGG = nil
    end }
    return gui
end

build()
log("Venice/ntS v14 pronta.")
log("buff 100% lido: " .. tostring(readExpBuff()))
