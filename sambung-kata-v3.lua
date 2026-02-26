if game:IsLoaded() == false then
    game.Loaded:Wait()
end

-- =========================
-- SAFE RAYFIELD LOAD
-- =========================
-- =========================
-- LOAD RAYFIELD (OBF SAFE)
-- =========================

local httpget = game.HttpGet
local loadstr = loadstring

local RayfieldSource = httpget(game, "https://sirius.menu/rayfield")
if RayfieldSource == nil then
    warn("Gagal ambil Rayfield source")
    return
end

local RayfieldFunction = loadstr(RayfieldSource)
if RayfieldFunction == nil then
    warn("Gagal compile Rayfield")
    return
end

local Rayfield = RayfieldFunction()
if Rayfield == nil then
    warn("Rayfield return nil")
    return
end
print("Rayfield type:", typeof(Rayfield))
-- =========================
-- SERVICES (NO COLON RAW)
-- =========================
local GetService = game.GetService
local ReplicatedStorage = GetService(game, "ReplicatedStorage")
local Players = GetService(game, "Players")
local LocalPlayer = Players.LocalPlayer

-- =========================
-- LOAD WORDLIST (NO INLINE)
-- =========================
local kataModule = {}

local function downloadWordlist()
    local response = httpget(game, "https://raw.githubusercontent.com/danzzy1we/roblox-script-dump/refs/heads/main/WordListDump/Dump_IndonesianWords.lua")
    if not response then
        return false
    end

    local content = string.match(response, "return%s*(.+)")
    if not content then
        return false
    end

    content = string.gsub(content, "^%s*{", "")
    content = string.gsub(content, "}%s*$", "")

    for word in string.gmatch(content, '"([^"]+)"') do
        local w = string.lower(word)
        if string.len(w) > 1 then
            table.insert(kataModule, w)
        end
    end

    return true
end

local wordOk = downloadWordlist()
if not wordOk or #kataModule == 0 then
    warn("Wordlist gagal dimuat!")
    return
end

print("Wordlist Loaded:", #kataModule)

-- =========================
-- REMOTES (SAFE ACCESS)
-- =========================
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local MatchUI = remotes:WaitForChild("MatchUI")
local SubmitWord = remotes:WaitForChild("SubmitWord")
local BillboardUpdate = remotes:WaitForChild("BillboardUpdate")
local BillboardEnd = remotes:WaitForChild("BillboardEnd")
local TypeSound = remotes:WaitForChild("TypeSound")
local UsedWordWarn = remotes:WaitForChild("UsedWordWarn")

-- =========================
-- STATE
-- =========================
local matchActive = false
local isMyTurn = false
local serverLetter = ""

local usedWords = {}
local usedWordsList = {}
local opponentStreamWord = ""

local autoEnabled = false
local autoRunning = false

local config = {
    minDelay = 500,
    maxDelay = 750,
    aggression = 20,
    minLength = 3,
    maxLength = 12
}

-- =========================
-- LOGIC FUNCTIONS (FLAT)
-- =========================
local function isUsed(word)
    return usedWords[string.lower(word)] == true
end

local usedWordsDropdown = nil

local function addUsedWord(word)
    local w = string.lower(word)
    if usedWords[w] == nil then
        usedWords[w] = true
        table.insert(usedWordsList, word)
        if usedWordsDropdown ~= nil then
            usedWordsDropdown:Set(usedWordsList)
        end
    end
end

local function resetUsedWords()
    usedWords = {}
    usedWordsList = {}
    if usedWordsDropdown ~= nil then
        usedWordsDropdown:Set({})
    end
end

local function getSmartWords(prefix)
    local results = {}
    local fallback = {}
    local lowerPrefix = string.lower(prefix)

    for i = 1, #kataModule do
        local word = kataModule[i]

        if string.sub(word, 1, #lowerPrefix) == lowerPrefix then
            if not isUsed(word) then
                local len = string.len(word)
                local lastChar = string.sub(word, -1)

                if len >= config.minLength and len <= config.maxLength then
                    table.insert(fallback, word)

                    if (lastChar == "x" or lastChar == "q") then
                        table.insert(results, word)
                    end
                end
            end
        end
    end

    -- Jika ada kata X/Q pakai itu
    if #results > 0 then
        table.sort(results, function(a,b)
            return string.len(a) > string.len(b)
        end)
        return results
    end

    -- Jika tidak ada, pakai normal
    table.sort(fallback, function(a,b)
        return string.len(a) > string.len(b)
    end)
    return fallback
end

local function humanDelay()
    local min = config.minDelay
    local max = config.maxDelay
    if min > max then
        min = max
    end
    task.wait(math.random(min, max) / 1000)
end

-- =========================
-- AUTO ENGINE (NO SPAWN)
-- =========================
local function startUltraAI()

    if autoRunning then return end
    if not autoEnabled then return end
    if not matchActive then return end
    if not isMyTurn then return end
    if serverLetter == "" then return end

    autoRunning = true

    humanDelay()

    local words = getSmartWords(serverLetter)
    if #words == 0 then
        autoRunning = false
        return
    end

    local selectedWord = words[1]

    if config.aggression < 100 then
        local topN = math.floor(#words * (1 - config.aggression/100))
        if topN < 1 then topN = 1 end
        if topN > #words then topN = #words end
        selectedWord = words[math.random(1, topN)]
    end

    local currentWord = serverLetter
    local remain = string.sub(selectedWord, #serverLetter + 1)

    for i = 1, string.len(remain) do

        if not matchActive or not isMyTurn then
            autoRunning = false
            return
        end

        currentWord = currentWord .. string.sub(remain, i, i)

        TypeSound:FireServer()
        BillboardUpdate:FireServer(currentWord)

        humanDelay()
    end

    humanDelay()

    SubmitWord:FireServer(selectedWord)
    addUsedWord(selectedWord)

    humanDelay()
    BillboardEnd:FireServer()

    autoRunning = false
end

-- =========================
-- UI
-- =========================
local Window = Rayfield:CreateWindow({
    Name = "⚡ NAKA ULTRA AUTO KATA ⚡",
    LoadingTitle = "NAKA Engine",
    LoadingSubtitle = "Ultra Smart Automation System",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "NAKA",
        FileName = "AutoKataConfig"
    },
    Discord = {
        Enabled = false
    },
    KeySystem = false
})

Rayfield:LoadConfiguration()  -- baru load config

Rayfield:Notify({
    Title = "NAKA",
    Content = "GUI Loaded Successfully!",
    Duration = 4,
    Image = 4483362458
})

-- =========================
-- MAIN TAB (UPGRADED UI)
-- =========================

local MainTab = Window:CreateTab("⚔ MAIN CONTROL", 4483362458)

-- =========================
-- AUTO ENGINE SECTION
-- =========================

MainTab:CreateSection("🤖 AUTO ENGINE")

MainTab:CreateToggle({
    Name = "🔥 Enable Ultra Auto Type",
    CurrentValue = false,
    Callback = function(Value)
        autoEnabled = Value
        if Value then
            startUltraAI()
        end
    end
})

-- =========================
-- AI BEHAVIOR SECTION
-- =========================

MainTab:CreateSection("🧠 AI BEHAVIOR")

MainTab:CreateSlider({
    Name = "⚡ Aggression Level",
    Range = {0,100},
    Increment = 5,
    CurrentValue = config.aggression,
    Callback = function(Value)
    config.agression = Value
    end
})

MainTab:CreateSlider({
    Name = "🔤 Min Word Length",
    Range = {2, 5},
    Increment = 1,
    CurrentValue = config.minLength,
    Callback = function(Value)
        config.minLength = Value
    end
})

MainTab:CreateSlider({
    Name = "🔠 Max Word Length",
    Range = {5, 20},
    Increment = 1,
    CurrentValue = config.maxLength,
    Callback = function(Value)
        config.maxLength = Value
    end
})

-- =========================
-- HUMAN SIMULATION SECTION
-- =========================

MainTab:CreateSection("⏱ HUMAN SIMULATION")

MainTab:CreateSlider({
    Name = "⌛ Min Delay (ms)",
    Range = {50, 500},
    Increment = 10,
    CurrentValue = config.minDelay,
    Callback = function(Value)
        config.minDelay = Value
    end
})

MainTab:CreateSlider({
    Name = "⏳ Max Delay (ms)",
    Range = {100, 1000},
    Increment = 10,
    CurrentValue = config.maxDelay,
    Callback = function(Value)
        config.maxDelay = Value
    end
})-- =========================
-- MATCH INFO SECTION
-- =========================

MainTab:CreateSection("📊 MATCH INFORMATION")

usedWordsDropdown = MainTab:CreateDropdown({
    Name = "📚 Used Words History",
    Options = usedWordsList,
    CurrentOption = {},
    MultipleOptions = false,
    Callback = function() end
})

-- =========================
-- LIVE STATUS SECTION
-- =========================

MainTab:CreateSection("🎮 LIVE STATUS")

local opponentParagraph = MainTab:CreateParagraph({
    Title = "👤 Opponent Status",
    Content = "⏳ Waiting for match..."
})

local startLetterParagraph = MainTab:CreateParagraph({
    Title = "🔤 Current Start Letter",
    Content = "—"
})
-- ==============================
-- SAFE UPDATE FUNCTIONS (UPGRADED)
-- ==============================

local function updateOpponentStatus()

    local content

    if matchActive then

        if isMyTurn then
            content = "🟢 Giliran Anda"
        else
            if opponentStreamWord and opponentStreamWord ~= "" then
                content = "🟡 Lawan mengetik: " .. tostring(opponentStreamWord)
            else
                content = "🔴 Giliran Lawan"
            end
        end

    else
        content = "⚫ Match tidak aktif"
    end

    opponentParagraph:Set({
        Title = "👤 Status Opponent",
        Content = content
    })
end
-- ==============================
-- UPDATE START LETTER (UPGRADED)
-- ==============================

local function updateStartLetter()

    local content

    if serverLetter and serverLetter ~= "" then
        content = "🔤 Start Letter:  " .. tostring(serverLetter)
    else
        content = "🔤 Start Letter:  —"
    end

    startLetterParagraph:Set({
        Title = "🎯 Kata Awal",
        Content = content
    })
end
-- ==============================
-- ABOUT TAB (PREMIUM VERSION)
-- ==============================

local AboutTab = Window:CreateTab("💎 ABOUT NAKA", 4483362458)

AboutTab:CreateSection("📜 SCRIPT INFORMATION")

AboutTab:CreateParagraph({
    Title = "⚡ NAKA ULTRA AUTO KATA",
    Content =
        "Versi : 2.0\n" ..
        "Developer : NAKA\n\n" ..
        "Fitur Utama:\n" ..
        "• Auto Play AI\n" ..
        "• Smart Word Filtering\n" ..
        "• Human Delay Simulation\n" ..
        "• Aggression Control\n\n" ..
        "Dictionary credit: danzzy1we"
})

AboutTab:CreateSection("🆕 UPDATE LOG")

AboutTab:CreateParagraph({
    Title = "🔥 Latest Improvements",
    Content =
        "• Stabil di PC & Android\n" ..
        "• Fix GUI tidak muncul\n" ..
        "• Performa AI lebih cepat\n" ..
        "• Optimasi Anti Error"
})

AboutTab:CreateSection("📖 HOW TO USE")

AboutTab:CreateParagraph({
    Title = "🎮 Cara Menggunakan",
    Content =
        "1️⃣ Aktifkan 'Enable Ultra Auto Type'\n" ..
        "2️⃣ Atur Aggression & Delay\n" ..
        "3️⃣ Masuk ke Match\n" ..
        "4️⃣ AI akan otomatis bermain"
})

AboutTab:CreateSection("⚠ IMPORTANT NOTES")

AboutTab:CreateParagraph({
    Title = "🛑 Catatan Penting",
    Content =
        "• Pastikan koneksi stabil\n" ..
        "• Jangan spam toggle\n" ..
        "• Jika error, reload script\n" ..
        "• Gunakan dengan bijak"
})
-- =========================
-- REMOTE EVENTS (NO INLINE)
-- =========================
local function onMatchUI(cmd, value)

    if cmd == "ShowMatchUI" then
        matchActive = true
        isMyTurn = false
        resetUsedWords()

    elseif cmd == "HideMatchUI" then
        matchActive = false
        isMyTurn = false
        serverLetter = ""
        resetUsedWords()

    elseif cmd == "StartTurn" then
        isMyTurn = true
        if autoEnabled then
            startUltraAI()
        end

    elseif cmd == "EndTurn" then
        isMyTurn = false

    elseif cmd == "UpdateServerLetter" then
        serverLetter = value or ""
    end
end

local function onBillboard(word)
    if matchActive and not isMyTurn then
        opponentStreamWord = word or ""
    end
end

local function onUsedWarn(word)
    if word then
        addUsedWord(word)
        if autoEnabled and matchActive and isMyTurn then
            humanDelay()
            startUltraAI()
        end
    end
end

MatchUI.OnClientEvent:Connect(onMatchUI)
BillboardUpdate.OnClientEvent:Connect(onBillboard)
UsedWordWarn.OnClientEvent:Connect(onUsedWarn)

print("NAKA BUILD LOADED SUCCESSFULLY")
