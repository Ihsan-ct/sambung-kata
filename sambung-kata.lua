-- =========================================================
-- ULTRA SMART AUTO KATA (ANTI LUAOBFUSCATOR V1 BUILD)
-- =========================================================

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
    maxLength = 12,
    
    ultraForceSuffix = true,
    forcedSuffixes = {"if","x"}
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
    local lowerPrefix = string.lower(prefix)

    for i = 1, #kataModule do
        local word = kataModule[i]
        if string.sub(word, 1, #lowerPrefix) == lowerPrefix then
            if not isUsed(word) then
                local len = string.len(word)
                if len >= config.minLength and len <= config.maxLength then
                    table.insert(results, word)
                end
            end
        end
    end

    local function pickUltraForcedWord(words)

    if not config.ultraForceSuffix then
        return words[1]
    end

    local forcedList = {}

    for _, word in ipairs(words) do
        for _, suffix in ipairs(config.forcedSuffixes) do
            if string.sub(word, -string.len(suffix)) == suffix then
                table.insert(forcedList, word)
                break
            end
        end
    end

    if #forcedList > 0 then
        -- tetap prioritaskan yang paling panjang
        table.sort(forcedList, function(a,b)
            return string.len(a) > string.len(b)
        end)

        return forcedList[1]
    end

    -- fallback kalau tidak ada suffix target
    return words[1]
end

    table.sort(results, function(a,b)
        return string.len(a) > string.len(b)
    end)

    return results
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

local selectedWord = pickUltraForcedWord(words)

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
    Name = "Sambung-kata",
    LoadingTitle = "Loading Gui...",
    LoadingSubtitle = "automate by naka",
    ConfigurationSaving = {Enabled = false}
})

local MainTab = Window:CreateTab("Main")

MainTab:CreateToggle({
    Name = "Auto type",
    CurrentValue = false,
    Callback = function(Value)
        autoEnabled = Value
        if Value then
            startUltraAI()
        end
    end
})

MainTab:CreateSlider({
    Name = "Aggression/tingkat",
    Range = {0,100},
    Increment = 5,
    CurrentValue = config.aggression,
    Callback = function(Value)
        config.aggression = Value
    end
})
MainTab:CreateSlider({
    Name = "Min Delay (ms)",
    Range = {10, 500},
    Increment = 5,
    CurrentValue = config.minDelay,
    Callback = function(Value)
        config.minDelay = Value
    end
})

MainTab:CreateSlider({
    Name = "Max Delay (ms)",
    Range = {100, 1000},
    Increment = 5,
    CurrentValue = config.maxDelay,
    Callback = function(Value)
        config.maxDelay = Value
    end
})
MainTab:CreateSlider({
    Name = "Min Word Length",
    Range = {1, 2},
    Increment = 1,
    CurrentValue = config.minLength,
    Callback = function(Value)
        config.minLength = Value
    end
})

MainTab:CreateSlider({
    Name = "Max Word Length",
    Range = {5, 20},
    Increment = 1,
    CurrentValue = config.maxLength,
    Callback = function(Value)
        config.maxLength = Value
    end
})

usedWordsDropdown = MainTab:CreateDropdown({
    Name = "Used Words",
    Options = usedWordsList,
    CurrentOption = "",
    Callback = function() end
})
-- ==============================
-- PARAGRAPH OBJECTS
-- ==============================
local opponentParagraph = MainTab:CreateParagraph({
    Title = "Status Opponent",
    Content = "Menunggu..."
})

local startLetterParagraph = MainTab:CreateParagraph({
    Title = "Kata Start",
    Content = "-"
})

-- ==============================
-- SAFE UPDATE FUNCTIONS
-- ==============================

local function updateOpponentStatus()

    local content = ""

    if matchActive == true then

        if isMyTurn == true then
            content = "Giliran Anda"
        else

            if opponentStreamWord ~= nil and opponentStreamWord ~= "" then
                content = "Opponent mengetik: " .. tostring(opponentStreamWord)
            else
                content = "Giliran Opponent"
            end

        end

    else
        content = "Match tidak aktif"
    end

    local data = {}
    data.Title = "Status Opponent"
    data.Content = tostring(content)

    opponentParagraph.Set(opponentParagraph, data)
end


local function updateStartLetter()

    local content = ""

    if serverLetter ~= nil and serverLetter ~= "" then
        content = "Kata Start: " .. tostring(serverLetter)
    else
        content = "Kata Start: -"
    end

    local data = {}
    data.Title = "Kata Start"
    data.Content = tostring(content)

    startLetterParagraph.Set(startLetterParagraph, data)
end

-- ==============================
-- TAB ABOUT (SAFE BUILD)
-- ==============================
local AboutTab = Window:CreateTab("About")

local about1 = {}
about1.Title = "Informasi Script"
about1.Content = "Auto Kata\nVersi: 2.0\nby sazaraaax\nFitur: Auto play dengan wordlist Indonesia\n\nthanks to danzzy1we for the indonesian dictionary"
AboutTab:CreateParagraph(about1)

local about2 = {}
about2.Title = "Informasi Update"
about2.Content = "> stable on all device pc or android\n > Fixing gui not showing"
AboutTab:CreateParagraph(about2)

local about3 = {}
about3.Title = "Cara Penggunaan"
about3.Content = "1. Aktifkan toggle Auto\n2. Atur delay dan agresivitas\n3. Mulai permainan\n4. Script akan otomatis menjawab"
AboutTab:CreateParagraph(about3)

local about4 = {}
about4.Title = "Catatan"
about4.Content = "Pastikan koneksi stabil\nJika ada error, coba reload"
AboutTab:CreateParagraph(about4)

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

print("ANTI LUAOBFUSCATOR BUILD LOADED SUCCESSFULLY")
