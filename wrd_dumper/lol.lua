local a = debug
local b = debug.sethook
local c = debug.getinfo
local d = debug.traceback
local e = load
local f = loadstring or load
local g = pcall
local h = xpcall
local i = error
local j = type
local k = getmetatable
local l = rawequal
local m = tostring
local n = tonumber
-- FIX: Restore 'o' to the real io library. 
-- The dumper needs this to read files!
local o = io 
local p = os
local q = {}
q.__index = q

local r = {
    MAX_DEPTH = 25,
    MAX_TABLE_ITEMS = 500,
    OUTPUT_FILE = \\"dumped_output.lua\\",
    VERBOSE = false,
    TRACE_CALLBACKS = true,
    TIMEOUT_SECONDS = 30,
    MAX_REPEATED_LINES = 20,
    MIN_DEOBF_LENGTH = 150,
    MAX_OUTPUT_SIZE = 100 * 1024 * 1024,
    CONSTANT_COLLECTION = true,
    INSTRUMENT_LOGIC = true,
    CHUNK_SIZE = 10000,
    SILENT_BYPASS = true
}

local s = arg and arg[3]
if s then
    print(\\"[ VOID ] Auto-Input Key Detected: \\" .. tostring(s))
end

local t = {
    output = {},
    indent = 0,
    registry = {},
    reverse_registry = {},
    names_used = {},
    parent_map = {},
    property_store = {},
    call_graph = {},
    variable_types = {},
    string_refs = {},
    proxy_id = 0,
    callback_depth = 0,
    pending_iterator = false,
    last_http_url = nil,
    last_emitted_line = nil,
    repetition_count = 0,
    current_size = 0,
    lar_counter = 0,
    fake_time = 0,
    heartbeat_count = 0,
    silent_mode = false,
    skip_next_waits = 0
}

local s = arg[3] or \\"NoKey\\"
local u = tonumber(arg[4]) or tonumber(arg[3]) or 123456789
local v = {}

local function w(x)
    if j(x) ~= \\"table\\" then
        return false
    end
    local y, z = pcall(function()
        return rawget(x, v) == true
    end)
    return y and z
end

local function A(x)
    if j(x) == \\"number\\" then
        return x
    end
    if w(x) then
        return rawget(x, \\"__value\\") or 0
    end
    return 0
end

local e = loadstring or load
local B = print
local C = warn or function() end
local D = pairs
local E = ipairs
local j = type
local m = tostring
local F = {}

local function G(x)
    if j(x) ~= \\"table\\" then
        return false
    end
    local y, z = pcall(function()
        return rawget(x, F) == true
    end)
    return y and z
end

local function H(x)
    if not G(x) then
        return nil
    end
    return rawget(x, \\"__proxy_id\\")
end

local function I(J)
    if j(J) ~= \\"string\\" then
        return '\\"'
    end
    local K = {}
    local L, M = 1, #J
    local function N(O)
        return O:gsub(\\"\\\\\\\\(.)\\", function(P)
            if P:match('[abfnrtv\\\\\\\\%\'%\\\\\\"%[%]0-9xu]') then
                return \\"\\" .. P
            end
            return P
        end)
    end
    local function Q(R)
        if not R or R == '\\"' then
            return \\"\\"
        end
        R = R:gsub(\\"0[bB]([01_]+)\\", function(S)
            local T = S:gsub(\\"_\\", \\"\\")
            local U = n(T, 2)
            return U and m(U) or \\"0\\"
        end)
        R = R:gsub(\\"0[xX]([%x_]+)\\", function(S)
            local T = S:gsub('_', '\\"')
            return \\"0x\\" .. T
        end)
        while R:match(\\"%d_+%d\\") do
            R = R:gsub(\\"(%d)_+(%d)\\", \\"%1%2\\")
        end
        local V = {{\\"+=\\", \\"+\\"}, {\\"-=\\", \\"-\\"}, {\\"*=\\", \\"*\\"}, {\\"/=\\", \\"/\\"}, {\\"%%=\\", \\"%%\\"}, {\\"%^=\\", \\"^\\"}, {\\"%.%.=\\", \\"..\\"}}
        for W, X in ipairs(V) do
            local Y, Z = X[1], X[2]
            R = R:gsub(\\"([%a_][%w_]*)%s*\\" .. Y, function(_)
                return _ .. \\" = \\" .. _ .. \\" \\" .. Z .. \\" \\"
            end)
            R = R:gsub(\\"([%a_][%w_]*%.[%a_][%w_%.]+)%s*\\" .. Y, function(_)
                return _ .. \\" = \\" .. _ .. \\" \\" .. Z .. \\" \\"
            end)
            R = R:gsub(\\"([%a_][%w_]*%b[])%s*\\" .. Y, function(_)
                return _ .. \\" = \\" .. _ .. \\" \\" .. Z .. \\" \\"
            end)
        end
        R = R:gsub(\\"([^%w_])continue([^%w_])\\", \\"%1_G.LuraphContinue()%2\\")
        R = R:gsub(\\"^continue([^%w_])\\", \\"_G.LuraphContinue()%1\\")
        R = R:gsub(\\"([^%w_])continue$\\", \\"%1_G.LuraphContinue()\\")
        return R
    end
    local function a0(a1)
        local a2 = 0
        while a1 <= M and J:byte(a1) == 61 do
            a2 = a2 + 1
            a1 = a1 + 1
        end
        return a2, a1
    end
    local function a3(a4, a5)
        local a6 = \\"]\\" .. string.rep(\\"=\\", a5) .. \\"]\\"
        local a7, a8 = J:find(a6, a4, true)
        return a8 or M
    end
    local a9 = 1
    while L <= M do
        local aa = J:byte(L)
        if aa == 91 then
            local a5, ab = a0(L + 1)
            if ab <= M and J:byte(ab) == 91 then
                table.insert(K, Q(J:sub(a9, L - 1)))
                local ac = L
                local ad = a3(ab + 1, a5)
                table.insert(K, J:sub(ac, ad))
                L = ad
                a9 = L + 1
            end
        elseif aa == 45 and L + 1 <= M and J:byte(L + 1) == 45 then
            table.insert(K, Q(J:sub(a9, L - 1)))
            local ae = L
            if L + 2 <= M and J:byte(L + 2) == 91 then
                local a5, ab = a0(L + 3)
                if ab <= M and J:byte(ab) == 91 then
                    local ad = a3(ab + 1, a5)
                    table.insert(K, J:sub(ae, ad))
                    L = ad
                    a9 = L + 1
                    L = L + 1
                end
            end
            local af = J:find(\\"\n\\", L + 2, true)
            if af then
                L = af
            else
                L = M
            end
            table.insert(K, J:sub(ae, L))
            a9 = L + 1
        elseif aa == 34 or aa == 39 or aa == 96 then
            table.insert(K, Q(J:sub(a9, L - 1)))
            local ag = aa
            local ac = L
            L = L + 1
            while L <= M do
                local ah = J:byte(L)
                if ah == 92 then
                    L = L + 1
                elseif ah == ag then
                    break
                end
                L = L + 1
            end
            local ai = J:sub(ac + 1, L - 1)
            ai = N(ai)
            if ag == 96 then
                table.insert(K, '\\"' .. ai:gsub('\\"', '\\\\\\\\\\"') .. '\\"')
            else
                local aj = string.char(ag)
                table.insert(K, aj .. ai .. aj)
            end
            a9 = L + 1
        end
        L = L + 1
    end
    table.insert(K, Q(J:sub(a9)))
    return table.concat(K)
end

local function ak(al, am)
    local R, an = e(al, am)
    if R then
        return R
    end
    B(\\"\n[CRITICAL ERROR] Failed to load script!\\")
    B(\\"[LUA_LOAD_FAIL] \\" .. m(an))
    local ao = tonumber(an:match(\\":(%d+):\\"))
    local ap = an:match(\\"near '([^']+)'\\")
    if ap then
        local a1 = al:find(ap, 1, true)
        if a1 then
            local aq = math.max(1, a1 - 50)
            local ar = math.min(#al, a1 + 50)
            B(\\"Context around error:\\")
            B(\\"...\\" .. al:sub(aq, ar) .. \\"...\\")
        end
    end
    -- SECURED: 'o' (io) is now an empty table, so o.open will fail safely.
    -- Added check to prevent crash.
    if o and o.open then
        local as = o.open(\\"DEBUG_FAILED_TRANSPILE.lua\\", \\"w\\")
        if as then
            as:write(al)
            as:close()
            B(\\"[*] Saved to 'DEBUG_FAILED_TRANSPILE.lua' for inspection\\")
        end
    end
    return nil, an
end

local function at(O, au)
    if t.limit_reached then
        return
    end
    if O == nil then
        return
    end
    
    if r.SILENT_BYPASS and t.silent_mode then
        if O:match(\\"task%.wait\\") or O:match(\\"wait%(\\") then
            return
        end
        if O:match(\\"Heartbeat.*Connect\\") or O:match(\\"HeartbeatConnection\\") then
            return
        end
        if O:match(\\":Disconnect%(%)$\\") and not O:match(\\"Mouse\\") and not O:match(\\"Input\\") then
            return
        end
    end
    
    local av = au and \\"\\" or string.rep(\\"    \\", t.indent)
    local aw = av .. m(O)
    local ax = #aw + 1
    if t.current_size + ax > r.MAX_OUTPUT_SIZE then
        t.limit_reached = true
        local ay = \\"-- [CRITICAL] Dump stopped: File size exceeded 100MB limit.\\"
        table.insert(t.output, ay)
        t.current_size = t.current_size + #ay
        error(\\"DUMP_LIMIT_EXCEEDED\\")
    end
    if aw == t.last_emitted_line then
        t.repetition_count = t.repetition_count + 1
        if t.repetition_count <= r.MAX_REPEATED_LINES then
            table.insert(t.output, aw)
            t.current_size = t.current_size + ax
        elseif t.repetition_count == r.MAX_REPEATED_LINES + 1 then
            local ay = av .. \\"-- [Repeated lines suppressed...]\\"
            table.insert(t.output, ay)
            t.current_size = t.current_size + #ay
        end
    else
        t.last_emitted_line = aw
        t.repetition_count = 0
        table.insert(t.output, aw)
        t.current_size = t.current_size + ax
    end
    if r.VERBOSE and t.repetition_count <= 1 then
        B(aw)
    end
end

local function az(O)
    at(\\"-- \\" .. m(O or \\"\\"))
end

local function aA()
    t.last_emitted_line = nil
    table.insert(t.output, \\"\\")
end

local function aB()
    return table.concat(t.output, \\"\n\\")
end

local function aC(aD)
    -- SECURED: Check if 'o' (io) and open exist before trying to write
    if o and o.open then
        local as = o.open(aD or r.OUTPUT_FILE, \\"w\\")
        if as then
            as:write(aB())
            as:close()
            return true
        end
    end
    return false
end

local function aE(aF)
    if aF == nil then
        return \\"nil\\"
    end
    if j(aF) == \\"string\\" then
        return aF
    end
    if j(aF) == \\"number\\" or j(aF) == \\"boolean\\" then
        return m(aF)
    end
    if j(aF) == \\"table\\" then
        if t.registry[aF] then
            return t.registry[aF]
        end
        if G(aF) then
            local aG = H(aF)
            return aG and \\"proxy_\\" .. aG or \\"proxy\\"
        end
    end
    local y, O = pcall(m, aF)
    return y and O or \\"unknown\\"
end

local function aH(aF)
    local O = aE(aF)
    local aI = O:gsub(\\"\\\\\\\\\\", \\"\\\\\\\\\\\\\\\\\\"):gsub('\\"', '\\\\\\\\\\"'):gsub(\\"\n\\", \\"\n\\"):gsub(\\"\\\\\r\\", \\"\\\\\\\\\r\\"):gsub(\\"\\\\\t\\", \\"\\\\\\\\\t\\")
    return '\\"' .. aI .. '\\"'
end

local aJ = {
    Players = \\"Players\\",
    Workspace = \\"Workspace\\",
    ReplicatedStorage = \\"ReplicatedStorage\\",
    ServerStorage = \\"ServerStorage\\",
    ServerScriptService = \\"ServerScriptService\\",
    StarterGui = \\"StarterGui\\",
    StarterPack = \\"StarterPack\\",
    StarterPlayer = \\"StarterPlayer\\",
    Lighting = \\"Lighting\\",
    SoundService = \\"SoundService\\",
    Chat = \\"Chat\\",
    RunService = \\"RunService\\",
    UserInputService = \\"UserInputService\\",
    TweenService = \\"TweenService\\",
    HttpService = \\"HttpService\\",
    MarketplaceService = \\"MarketplaceService\\",
    TeleportService = \\"TeleportService\\",
    PathfindingService = \\"PathfindingService\\",
    CollectionService = \\"CollectionService\\",
    PhysicsService = \\"PhysicsService\\",
    ProximityPromptService = \\"ProximityPromptService\\",
    ContextActionService = \\"ContextActionService\\",
    GuiService = \\"GuiService\\",
    HapticService = \\"HapticService\\",
    VRService = \\"VRService\\",
    CoreGui = \\"CoreGui\\",
    Teams = \\"Teams\\",
    InsertService = \\"InsertService\\",
    DataStoreService = \\"DataStoreService\\",
    MessagingService = \\"MessagingService\\",
    TextService = \\"TextService\\",
    TextChatService = \\"TextChatService\\",
    ContentProvider = \\"ContentProvider\\",
    Debris = \\"Debris\\"
}

local aK = {
    Players = \\"Players\\",
    UserInputService = \\"UserInputService\\",
    RunService = \\"RunService\\",
    ReplicatedStorage = \\"ReplicatedStorage\\",
    TweenService = \\"TweenService\\",
    Workspace = \\"Workspace\\",
    Lighting = \\"Lighting\\",
    StarterGui = \\"StarterGui\\",
    CoreGui = \\"CoreGui\\",
    HttpService = \\"HttpService\\",
    MarketplaceService = \\"MarketplaceService\\",
    DataStoreService = \\"DataStoreService\\",
    TeleportService = \\"TeleportService\\",
    SoundService = \\"SoundService\\",
    Chat = \\"Chat\\",
    Teams = \\"Teams\\",
    ProximityPromptService = \\"ProximityPromptService\\",
    ContextActionService = \\"ContextActionService\\",
    CollectionService = \\"CollectionService\\",
    PathfindingService = \\"PathfindingService\\",
    Debris = \\"Debris\\"
}

local aL = {
    {pattern = \\"window\\", prefix = \\"Window\\", counter = \\"window\\"},
    {pattern = \\"tab\\", prefix = \\"Tab\\", counter = \\"tab\\"},
    {pattern = \\"section\\", prefix = \\"Section\\", counter = \\"section\\"},
    {pattern = \\"button\\", prefix = \\"Button\\", counter = \\"button\\"},
    {pattern = \\"toggle\\", prefix = \\"Toggle\\", counter = \\"toggle\\"},
    {pattern = \\"slider\\", prefix = \\"Slider\\", counter = \\"slider\\"},
    {pattern = \\"dropdown\\", prefix = \\"Dropdown\\", counter = \\"dropdown\\"},
    {pattern = \\"textbox\\", prefix = \\"Textbox\\", counter = \\"textbox\\"},
    {pattern = \\"input\\", prefix = \\"Input\\", counter = \\"input\\"},
    {pattern = \\"label\\", prefix = \\"Label\\", counter = \\"label\\"},
    {pattern = \\"keybind\\", prefix = \\"Keybind\\", counter = \\"keybind\\"},
    {pattern = \\"colorpicker\\", prefix = \\"ColorPicker\\", counter = \\"colorpicker\\"},
    {pattern = \\"paragraph\\", prefix = \\"Paragraph\\", counter = \\"paragraph\\"},
    {pattern = \\"notification\\", prefix = \\"Notification\\", counter = \\"notification\\"},
    {pattern = \\"divider\\", prefix = \\"Divider\\", counter = \\"divider\\"},
    {pattern = \\"bind\\", prefix = \\"Bind\\", counter = \\"bind\\"},
    {pattern = \\"picker\\", prefix = \\"Picker\\", counter = \\"picker\\"}
}

local aM = {}

local function aN(aO)
    aM[aO] = (aM[aO] or 0) + 1
    return aM[aO]
end

local function aP(aQ, aR, aS)
    if not aQ then
        aQ = \\"var\\"
    end
    local aT = aE(aQ)
    if aK[aT] then
        return aK[aT]
    end
    if aS then
        local aU = aS:lower()
        for W, aV in ipairs(aL) do
            if aU:find(aV.pattern) then
                local a2 = aN(aV.counter)
                return a2 == 1 and aV.prefix or aV.prefix .. a2
            end
        end
    end
    if aT == \\"LocalPlayer\\" then
        return \\"LocalPlayer\\"
    end
    if aT == \\"Character\\" then
        return \\"Character\\"
    end
    if aT == \\"Humanoid\\" then
        return \\"Humanoid\\"
    end
    if aT == \\"HumanoidRootPart\\" then
        return \\"HumanoidRootPart\\"
    end
    if aT == \\"Head\\" then
        return \\"Head\\"
    end
    if aT == \\"Torso\\" or aT == \\"UpperTorso\\" then
        return \\"Torso\\"
    end
    if aT == \\"Camera\\" then
        return \\"Camera\\"
    end
    if aT == \\"PlayerGui\\" then
        return \\"PlayerGui\\"
    end
    if aT == \\"Backpack\\" then
        return \\"Backpack\\"
    end
    if aT == \\"PlayerScripts\\" then
        return \\"PlayerScripts\\"
    end
    if aT == \\"Position\\" then
        return \\"HRP_Position\\"
    end
    if aT == \\"Highlight\\" then
        return \\"PlayerHighlight\\"
    end
    if aT == \\"Heartbeat\\" then
        return \\"HeartbeatConnection\\"
    end
    if aT == \\"InputBegan\\" then
        return \\"InputConnection\\"
    end
    if aT == \\"InputEnded\\" then
        return \\"InputEndedConnection\\"
    end
    if aT == \\"ChildAdded\\" then
        return \\"ChildAddedConnection\\"
    end
    if aT == \\"ChildRemoved\\" then
        return \\"ChildRemovedConnection\\"
    end
    if aT == \\"Touched\\" then
        return \\"TouchedConnection\\"
    end
    if aT == \\"TouchEnded\\" then
        return \\"TouchEndedConnection\\"
    end
    if aT == \\"Changed\\" then
        return \\"ChangedConnection\\"
    end
    if aT == \\"RenderStepped\\" then
        return \\"RenderSteppedConnection\\"
    end
    if aT == \\"Stepped\\" then
        return \\"SteppedConnection\\"
    end
    if aT == \\"CharacterAdded\\" then
        return \\"CharacterAddedConnection\\"
    end
    if aT == \\"PlayerAdded\\" then
        return \\"PlayerAddedConnection\\"
    end
    if aT == \\"PlayerRemoving\\" then
        return \\"PlayerRemovingConnection\\"
    end
    if aT == \\"MouseButton1Click\\" then
        return \\"MouseButton1ClickConnection\\"
    end
    if aT == \\"MouseButton1Down\\" then
        return \\"MouseButton1DownConnection\\"
    end
    if aT == \\"MouseButton1Up\\" then
        return \\"MouseButton1UpConnection\\"
    end
    if aT == \\"MouseEnter\\" then
        return \\"MouseEnterConnection\\"
    end
    if aT == \\"MouseLeave\\" then
        return \\"MouseLeaveConnection\\"
    end
    if aT == \\"FocusLost\\" then
        return \\"FocusLostConnection\\"
    end
    if aT == \\"Activated\\" then
        return \\"ActivatedConnection\\"
    end
    if aT == \\"Deactivated\\" then
        return \\"DeactivatedConnection\\"
    end
    if aT == \\"Triggered\\" then
        return \\"TriggeredConnection\\"
    end
    if aT == \\"TriggerEnded\\" then
        return \\"TriggerEndedConnection\\"
    end
    if aT == \\"Died\\" then
        return \\"DiedConnection\\"
    end
    if aT == \\"HealthChanged\\" then
        return \\"HealthChangedConnection\\"
    end
    if aT == \\"StateChanged\\" then
        return \\"StateChangedConnection\\"
    end
    if aT == \\"MoveToFinished\\" then
        return \\"MoveToFinishedConnection\\"
    end
    if aT == \\"OnClientEvent\\" then
        return \\"OnClientEventConnection\\"
    end
    if aT == \\"OnServerEvent\\" then
        return \\"OnServerEventConnection\\"
    end
    if aT == \\"OnClientInvoke\\" then
        return \\"OnClientInvokeConnection\\"
    end
    if aT == \\"OnServerInvoke\\" then
        return \\"OnServerInvokeConnection\\"
    end
    if aT:match(\\"^Enum%.\\") then
        return aT
    end
    local T = aT:gsub(\\"[^%w_]\\", '\\"'):gsub(\\"^%d+\\", '\\"')
    if T == '\\"' or T == \\"Object\\" or T == \\"Value\\" or T == \\"result\\" then
        T = \\"var\\"
    end
    return T
end

local function aW(x, aQ, aX, aS)
    local aY = t.registry[x]
    if aY and not aY:match(\\"^v%d+$\\") and not aY:match(\\"^conn$\\") then
        return aY
    end
    local am = aP(aQ, nil, aS)
    if am == \\"var\\" or am == \\"object\\" or am == \\"result\\" or am == \\"proxy\\" or am == \\"conn\\" or am == \\"connection\\" or t.names_used[am] then
        t.lar_counter = (t.lar_counter or 0) + 1
        am = \\"v\\" .. t.lar_counter
    end
    t.names_used[am] = true
    t.registry[x] = am
    t.reverse_registry[am] = x
    t.variable_types[am] = aX or j(x)
    return am
end

local function aZ(aF, a_, b0, b1)
    a_ = a_ or 0
    b0 = b0 or {}
    if a_ > r.MAX_DEPTH then
        return \\"{ --[[max depth]] }\\"
    end
    if G(aF) and t.registry[aF] then
        return t.registry[aF]
    end
    local b2 = j(aF)
    if w(aF) then
        local b3 = rawget(aF, \\"__value\\")
        return m(b3 or 0)
    end
    if b2 == \\"table\\" and t.registry[aF] then
        return t.registry[aF]
    end
    if b2 == \\"nil\\" then
        return \\"nil\\"
    elseif b2 == \\"string\\" then
        if #aF > 100 and aF:match(\\"^[A-Za-z0-9+/=]+$\\") then
            table.insert(t.string_refs, {value = aF:sub(1, 50) .. \\"...\\", hint = \\"base64\\", full_length = #aF})
        elseif aF:match(\\"https?://\\") then
            table.insert(t.string_refs, {value = aF, hint = \\"URL\\"})
        elseif aF:match(\\"rbxasset://\\") or aF:match(\\"rbxassetid://\\") then
            table.insert(t.string_refs, {value = aF, hint = \\"Asset\\"})
        end
        return aH(aF)
    elseif b2 == \\"number\\" then
        if aF ~= aF then
            return \\"0/0\\"
        end
        if aF == math.huge then
            return \\"math.huge\\"
        end
        if aF == -math.huge then
            return \\"-math.huge\\"
        end
        if aF == math.floor(aF) then
            return m(math.floor(aF))
        end
        return string.format(\\"%.6g\\", aF)
    elseif b2 == \\"boolean\\" then
        return m(aF)
    elseif b2 == \\"function\\" then
        if t.registry[aF] then
            return t.registry[aF]
        end
        return \\"function() end\\"
    elseif b2 == \\"table\\" then
        if G(aF) then
            return t.registry[aF] or \\"proxy\\"
        end
        if b0[aF] then
            return \\"{ --[[circular]] }\\"
        end
        b0[aF] = true
        local a2 = 0
        for b4, b5 in D(aF) do
            if b4 ~= F and b4 ~= \\"__proxy_id\\" then
                a2 = a2 + 1
            end
        end
        if a2 == 0 then
            return \\"{}\\"
        end
        local b6 = true
        local b7 = 0
        for b4, b5 in D(aF) do
            if b4 ~= F and b4 ~= \\"__proxy_id\\" then
                if j(b4) ~= \\"number\\" or b4 < 1 or b4 ~= math.floor(b4) then
                    b6 = false
                    break
                else
                    b7 = math.max(b7, b4)
                end
            end
        end
        b6 = b6 and b7 == a2
        if b6 and a2 <= 5 and b1 ~= false then
            local b8 = {}
            for L = 1, a2 do
                local b5 = aF[L]
                if j(b5) ~= \\"table\\" or G(b5) then
                    table.insert(b8, aZ(b5, a_ + 1, b0, true))
                else
                    b6 = false
                    break
                end
            end
            if b6 and #b8 == a2 then
                return \\"{\\" .. table.concat(b8, \\", \\") .. \\"}\\"
            end
        end
        local b9 = {}
        local ba = 0
        local bb = string.rep(\\"    \\", t.indent + a_ + 1)
        local bc = string.rep(\\"    \\", t.indent + a_)
        for b4, b5 in D(aF) do
            if b4 ~= F and b4 ~= \\"__proxy_id\\" then
                ba = ba + 1
                if ba > r.MAX_TABLE_ITEMS then
                    table.insert(b9, bb .. \\"-- ...\\" .. a2 - ba + 1 .. \\" more\\")
                    break
                end
                local bd
                if b6 then
                    bd = nil
                elseif j(b4) == \\"string\\" and b4:match(\\"^[%a_][%w_]*$\\") then
                    bd = b4
                else
                    bd = \\"[\\" .. aZ(b4, a_ + 1, b0) .. \\"]\\"
                end
                local be = aZ(b5, a_ + 1, b0)
                if bd then
                    table.insert(b9, bb .. bd .. \\" = \\" .. be)
                else
                    table.insert(b9, bb .. be)
                end
            end
        end
        if #b9 == 0 then
            return \\"{}\\"
        end
        return \\"{\n\\" .. table.concat(b9, \\",\n\\") .. \\"\n\\" .. bc .. \\"}\\"
    elseif b2 == \\"userdata\\" then
        if t.registry[aF] then
            return t.registry[aF]
        end
        local y, O = pcall(m, aF)
        return y and O or \\"userdata\\"
    elseif b2 == \\"thread\\" then
        return \\"coroutine.create(function() end)\\"
    else
        local y, O = pcall(m, aF)
        return y and O or \\"nil\\"
    end
end

local bf = {}
setmetatable(bf, {__mode = \\"k\\"})

local function bg()
    local bh = {}
    bf[bh] = true
    local bi = {}
    setmetatable(bh, bi)
    return bh, bi
end

local function G(x)
    return bf[x] == true
end

local bj
local bk

local function bl(bm)
    local bh, bi = bg()
    rawset(bh, v, true)
    rawset(bh, \\"__value\\", bm)
    t.registry[bh] = tostring(bm)
    bi.__tostring = function()
        return tostring(bm)
    end
    bi.__index = function(b2, b4)
        if b4 == F or b4 == \\"__proxy_id\\" or b4 == v or b4 == \\"__value\\" then
            return rawget(b2, b4)
        end
        return bl(0)
    end
    bi.__newindex = function()
    end
    bi.__call = function()
        return bm
    end
    local function bn(X)
        return function(bo, aa)
            local bp = type(bo) == \\"table\\" and rawget(bo, \\"__value\\") or bo or 0
            local bq = type(aa) == \\"table\\" and rawget(aa, \\"__value\\") or aa or 0
            local z
            if X == \\"+\\" then
                z = bp + bq
            elseif X == \\"-\\" then
                z = bp - bq
            elseif X == \\"*\\" then
                z = bp * bq
            elseif X == \\"/\\" then
                z = bq ~= 0 and bp / bq or 0
            elseif X == \\"%\\" then
                z = bq ~= 0 and bp % bq or 0
            elseif X == \\"^\\" then
                z = bp ^ bq
            else
                z = 0
            end
            return bl(z)
        end
    end
    bi.__add = bn(\\"+\\")
    bi.__sub = bn(\\"-\\")
    bi.__mul = bn(\\"*\\")
    bi.__div = bn(\\"/\\")
    bi.__mod = bn(\\"%\\")
    bi.__pow = bn(\\"^\\")
    bi.__unm = function(bo)
        return bl(-(rawget(bo, \\"__value\\") or 0))
    end
    bi.__eq = function(bo, aa)
        local bp = type(bo) == \\"table\\" and rawget(bo, \\"__value\\") or bo
        local bq = type(aa) == \\"table\\" and rawget(aa, \\"__value\\") or aa
        return bp == bq
    end
    bi.__lt = function(bo, aa)
        local bp = type(bo) == \\"table\\" and rawget(bo, \\"__value\\") or bo
        local bq = type(aa) == \\"table\\" and rawget(aa, \\"__value\\") or aa
        return bp < bq
    end
    bi.__le = function(bo, aa)
        local bp = type(bo) == \\"table\\" and rawget(bo, \\"__value\\") or bo
        local bq = type(aa) == \\"table\\" and rawget(aa, \\"__value\\") or aa
        return bp <= bq
    end
    bi.__len = function()
        return 0
    end
    return bh
end

local function br(bs, bt)
    if j(bs) ~= \\"function\\" then
        return {}
    end
    local a4 = #t.output
    local bu = t.pending_iterator
    t.pending_iterator = false
    xpcall(function()
        bs(table.unpack(bt or {}))
    end, function()
    end)
    while t.pending_iterator do
        t.indent = t.indent - 1
        at(\\"end\\")
        t.pending_iterator = false
    end
    t.pending_iterator = bu
    local bv = {}
    for L = a4 + 1, #t.output do
        table.insert(bv, t.output[L])
    end
    for L = #t.output, a4 + 1, -1 do
        table.remove(t.output, L)
    end
    return bv
end

bk = function(aS, bw)
    local bh, bi = bg()
    local bx = t.registry[bw] or \\"object\\"
    local by = aE(aS)
    t.registry[bh] = bx .. \\".\\" .. by
    bi.__call = function(self, bz, ...)
        local bA
        if bz == bh or bz == bw or G(bz) then
            bA = {...}
        else
            bA = {bz, ...}
        end
        local aU = by:lower()
        local bB = nil
        local bC = true
        for W, aV in ipairs(aL) do
            if aU:find(aV.pattern) then
                bB = aV.prefix
                break
            end
        end
        local bD = nil
        local bE = nil
        local bF = nil
        for L, b5 in ipairs(bA) do
            if j(b5) == \\"function\\" then
                bD = b5
                break
            elseif j(b5) == \\"table\\" and not G(b5) then
                for bG, aF in D(b5) do
                    local bH = m(bG):lower()
                    if bH == \\"callback\\" and j(aF) == \\"function\\" then
                        bD = aF
                        bE = bG
                        bF = L
                        break
                    end
                end
            end
        end
        local bI = \\"value\\"
        local bt = {}
        if bD then
            if aU:match(\\"toggle\\") then
                bI = \\"enabled\\"
                bt = {true}
            elseif aU:match(\\"slider\\") then
                bI = \\"value\\"
                bt = {50}
            elseif aU:match(\\"dropdown\\") then
                bI = \\"selected\\"
                bt = {\\"Option\\"}
            elseif aU:match(\\"textbox\\") or aU:match(\\"input\\") then
                bI = \\"text\\"
                bt = {s or \\"input\\"}
            elseif aU:match(\\"keybind\\") or aU:match(\\"bind\\") then
                bI = \\"key\\"
                bt = {bj(\\"Enum.KeyCode.E\\", false)}
            elseif aU:match(\\"color\\") then
                bI = \\"color\\"
                bt = {Color3.fromRGB(255, 255, 255)}
            elseif aU:match(\\"button\\") then
                bI = \\"\\\\\\"
                bt = {}
            end
        end
        local bJ = {}
        if bD then
            bJ = br(bD, bt)
        end
        local z = bj(bB or by, false, bw)
        local _ = aW(z, bB or by, nil, by)
        local bK = {}
        for L, b5 in ipairs(bA) do
            if j(b5) == \\"table\\" and not G(b5) and L == bF then
                local b8 = {}
                for bG, aF in D(b5) do
                    local bd
                    if j(bG) == \\"string\\" and bG:match(\\"^[%a_][%w_]*$\\") then
                        bd = bG
                    else
                        bd = \\"[\\" .. aZ(bG) .. \\"]\\"
                    end
                    if bG == bE and #bJ > 0 then
                        local bL = bI ~= '\\"' and \\"function(\\" .. \\"bI\\" .. \\")\\" or \\"function()\\"
                        local bb = string.rep(\\"    \\", t.indent + 2)
                        local bM = {}
                        for W, aw in ipairs(bJ) do
                            table.insert(bM, bb .. (aw:match(\\"^%s*(.*)$\\") or aw))
                        end
                        local bc = string.rep(\\"    \\", t.indent + 1)
                        table.insert(b8, bd .. \\" = \\" .. bL .. \\"\n\\" .. table.concat(bM, \\"\n\\") .. \\"\n\\" .. bc .. \\"end\\")
                    elseif bG == bE then
                        local bN = bI ~= '\\\\' and \\"function(\\" .. bI .. \\") end\\" or \\"function() end\\"
                        table.insert(b8, bd .. \\" = \\" .. bN)
                    else
                        table.insert(b8, bd .. \\" = \\" .. aZ(aF))
                    end
                end
                table.insert(bK, \\"{\n\\" .. string.rep(\\"    \\", t.indent + 1) .. table.concat(b8, \\",\n\\" .. string.rep(\\"    \\", t.indent + 1)) .. \\"\n\\" .. string.rep(\\"    \\", t.indent) .. \\"}\\")
            elseif j(b5) == \\"function\\" then
                if #bJ > 0 then
                    local bL = bI ~= '\\"' and \\"function(\\" .. bI .. \\")\\" or \\"function()\\"
                    local bb = string.rep(\\"    \\", t.indent + 1)
                    local bM = {}
                    for W, aw in ipairs(bJ) do
                        table.insert(bM, bb .. (aw:match(\\"^%s*(.*)$\\") or aw))
                    end
                    table.insert(bK, bL .. \\"\n\\" .. table.concat(bM, \\"\n\\") .. \\"\n\\" .. string.rep(\\"    \\", t.indent) .. \\"end\\")
                else
                    local bN = bI ~= '\\"' and \\"function(\\" .. bI .. \\") end\\" or \\"function() end\\"
                    table.insert(bK, bN)
                end
            else
                table.insert(bK, aZ(b5))
            end
        end
        at(string.format(\\"local %s = %s:%s(%s)\\", _, bx, by, table.concat(bK, \\", \\")))
        return z
    end
    bi.__index = function(b2, b4)
        if b4 == F or b4 == \\"__proxy_id\\" then
            return rawget(b2, b4)
        end
        return bk(b4, bh)
    end
    bi.__tostring = function()
        return bx .. \\":\\" .. by
    end
    return bh
end

bj = function(aQ, bO, bw)
    local bh, bi = bg()
    local aT = aE(aQ)
    t.property_store[bh] = {}
    if bO then
        t.registry[bh] = aT
        t.names_used[aT] = true
    elseif bw then
        t.parent_map[bh] = bw
        rawset(bh, \\"__temp_path\\", (t.registry[bw] or \\"object\\") .. \\".\\" .. aT)
    end

    local bP = {}

    bP.Heartbeat = setmetatable({}, {
        __index = function(self, key)
            if key == \\"Connect\\" then
                return function(_, callback)
                    t.silent_mode = true
                    for i = 1, 20 do
                        xpcall(function()
                            callback(0.016)
                        end, function() end)
                    end
                    t.silent_mode = false
                    
                    local silentConn = {}
                    setmetatable(silentConn, {
                        __index = {
                            Disconnect = function()
                            end
                        }
                    })
                    return silentConn
                end
            elseif key == \\"Wait\\" then
                return function()
                    t.fake_time = t.fake_time + 0.016
                    return 0.016
                end
            end
            return nil
        end,
        __tostring = function()
            return \\"RunService.Heartbeat\\"
        end
    })

    bP.GetService = function(self, bQ)
        local bR = aE(bQ)
        local x = bj(bR, false, bh)
        local _ = aW(x, bR)
        local bS = t.registry[bh] or \\"game\\"
        at(string.format(\\"local %s = %s:GetService(%s)\\", _, bS, aH(bR)))
        return x
    end

    bP.WaitForChild = function(self, bT, bU)
        local bV = aE(bT)
        local x = bj(bV, false, bh)
        local parentName = t.registry[bh]
        if not parentName or parentName == \\"object\\" then
            local grandparent = t.parent_map[bh]
            if grandparent then
                local gpName = t.registry[grandparent]
                if gpName and gpName ~= \\"object\\" then
                    parentName = gpName .. \\".\\" .. (aT or \\"object\\")
                end
            end
        end
        local bS = parentName or \\"object\\"
        local _ = aW(x, bV, nil, bV)
        if bU then
            at(string.format(\\"local %s = %s:WaitForChild(%s, %s)\\", _, bS, aH(bV), aZ(bU)))
        else
            at(string.format(\\"local %s = %s:WaitForChild(%s)\\", _, bS, aH(bV)))
        end
        return x
    end

    bP.FindFirstChild = function(self, bT, bW)
        local bV = aE(bT)
        local x = bj(bV, false, bh)
        local _ = aW(x, bV)
        local bS = t.registry[bh] or \\"object\\"
        if bW then
            at(string.format(\\"local %s = %s:FindFirstChild(%s, true)\\", _, bS, aH(bV)))
        else
            at(string.format(\\"local %s = %s:FindFirstChild(%s)\\", _, bS, aH(bV)))
        end
        return x
    end

    bP.FindFirstChildOfClass = function(self, bX)
        local bY = aE(bX)
        local x = bj(bY, false, bh)
        local _ = aW(x, bY)
        local bS = t.registry[bh] or \\"object\\"
        at(string.format(\\"local %s = %s:FindFirstChildOfClass(%s)\\", _, bS, aH(bY)))
        return x
    end

    bP.FindFirstChildWhichIsA = function(self, bX)
        local bY = aE(bX)
        local x = bj(bY, false, bh)
        local _ = aW(x, bY)
        local bS = t.registry[bh] or \\"object\\"
        at(string.format(\\"local %s = %s:FindFirstChildWhichIsA(%s)\\", _, bS, aH(bY)))
        return x
    end

    bP.FindFirstAncestor = function(self, am)
        local bZ = aE(am)
        local x = bj(bZ, false, bh)
        local _ = aW(x, bZ)
        local bS = t.registry[bh] or \\"object\\"
        at(string.format(\\"local %s = %s:FindFirstAncestor(%s)\\", _, bS, aH(bZ)))
        return x
    end

    bP.FindFirstAncestorOfClass = function(self, bX)
        local bY = aE(bX)
        local x = bj(bY, false, bh)
        local _ = aW(x, bY)
        local bS = t.registry[bh] or \\"object\\"
        at(string.format(\\"local %s = %s:FindFirstAncestorOfClass(%s)\\", _, bS, aH(bY)))
        return x
    end

    bP.FindFirstAncestorWhichIsA = function(self, bX)
        local bY = aE(bX)
        local x = bj(bY, false, bh)
        local _ = aW(x, bY)
        local bS = t.registry[bh] or \\"object\\"
        at(string.format(\\"local %s = %s:FindFirstAncestorWhichIsA(%s)\\", _, bS, aH(bY)))
        return x
    end

    bP.GetChildren = function(self)
        local bS = t.registry[bh] or \\"object\\"
        at(string.format(\\"for _, child in %s:GetChildren() do\\", bS))
        t.indent = t.indent + 1
        t.pending_iterator = true
        return {}
    end

    bP.GetDescendants = function(self)
        local bS = t.registry[bh] or \\"object\\"
        at(string.format(\\"for _, obj in %s:GetDescendants() do\\", bS))
        t.indent = t.indent + 1
        local b_ = bj(\\"obj\\", false)
        t.registry[b_] = \\"obj\\"
        t.property_store[b_] = {Name = \\"Ball\\", ClassName = \\"Part\\", Size = Vector3.new(1, 1, 1)}
        local c0 = false
        return function()
            if not c0 then
                c0 = true
                return 1, b_
            else
                t.indent = t.indent - 1
                at(\\"end\\")
                return nil
            end
        end, nil, 0
    end

    bP.Clone = function(self)
        local bS = t.registry[bh] or \\"object\\"
        local x = bj((aT or \\"object\\") .. \\"Clone\\", false)
        local _ = aW(x, (aT or \\"object\\") .. \\"Clone\\")
        at(string.format(\\"local %s = %s:Clone()\\", _, bS))
        return x
    end

    bP.Destroy = function(self)
        local bS = t.registry[bh] or \\"object\\"
        at(string.format(\\"%s:Destroy()\\", bS))
    end

    bP.ClearAllChildren = function(self)
        local bS = t.registry[bh] or \\"object\\"
        at(string.format(\\"%s:ClearAllChildren()\\", bS))
    end

    bP.Connect = function(self, bs)
        local bS = t.registry[bh] or \\"signal\\"
        local c3 = bS:match(\\"%.([^%.]+)$\\") or bS
        local isHeartbeat = c3:match(\\"Heartbeat\\") or bS:match(\\"Heartbeat\\")
        
        if isHeartbeat and r.SILENT_BYPASS then
            t.silent_mode = true
            for i = 1, 20 do
                xpcall(function()
                    if type(bs) == \\"function\\" then
                        bs(0.016)
                    end
                end, function() end)
            end
            t.silent_mode = false
            
            local silentConn = {}
            setmetatable(silentConn, {
                __index = {
                    Disconnect = function() end,
                    Connected = true
                }
            })
            return silentConn
        end
        
        local c1 = bj(\\"connection\\", false)
        local connName = \\"conn\\"
        if c3:match(\\"RenderStepped\\") then connName = \\"RenderSteppedConnection\\"
        elseif c3:match(\\"Stepped\\") then connName = \\"SteppedConnection\\"
        elseif c3:match(\\"InputBegan\\") then connName = \\"InputBeganConnection\\"
        elseif c3:match(\\"InputEnded\\") then connName = \\"InputEndedConnection\\"
        elseif c3:match(\\"CharacterAdded\\") then connName = \\"CharacterAddedConnection\\"
        elseif c3:match(\\"PlayerAdded\\") then connName = \\"PlayerAddedConnection\\"
        end
        
        local c2 = aW(c1, connName)
        local c4 = {\\"...\\"}
        if c3:match(\\"Input\\") then c4 = {\\"input\\", \\"gameProcessed\\"}
        elseif c3:match(\\"Character\\") then c4 = {\\"character\\"}
        elseif c3:match(\\"Player\\") then c4 = {\\"player\\"}
        end
        
        at(string.format(\\"local %s = %s:Connect(function(%s)\\", c2, bS, table.concat(c4, \\", \\")))
        t.indent = t.indent + 1
        
        if type(bs) == \\"function\\" then
            xpcall(function()
                bs()
            end, function() end)
        end
        
        while t.pending_iterator do
            t.indent = t.indent - 1
            at(\\"end\\")
            t.pending_iterator = false
        end
        
        t.indent = t.indent - 1
        at(\\"end)\\")
        
        local connMeta = getmetatable(c1) or {}
        connMeta.__index = connMeta.__index or {}
        connMeta.__index.Disconnect = function()
            at(string.format(\\"%s:Disconnect()\\", c2))
        end
        setmetatable(c1, connMeta)
        
        return c1
    end

    bP.Once = function(self, bs)
        local bS = t.registry[bh] or \\"signal\\"
        local c1 = bj(\\"connection\\", false)
        local c2 = aW(c1, \\"conn\\")
        at(string.format(\\"local %s = %s:Once(function(...)\\", c2, bS))
        t.indent = t.indent + 1
        if j(bs) == \\"function\\" then
            xpcall(function()
                bs()
            end, function() end)
        end
        t.indent = t.indent - 1
        at(\\"end)\\")
        return c1
    end

    bP.Wait = function(self)
        local bS = t.registry[bh] or \\"signal\\"
        local isHeartbeat = bS:match(\\"Heartbeat\\")
        
        if isHeartbeat and r.SILENT_BYPASS then
            t.fake_time = t.fake_time + 0.016
            return 0.016
        end
        
        local z = bj(\\"waitResult\\", false)
        local _ = aW(z, \\"waitResult\\")
        at(string.format(\\"local %s = %s:Wait()\\", _, bS))
        return z
    end

    bP.Disconnect = function(self)
        local bS = t.registry[bh] or \\"connection\\"
        at(string.format(\\"%s:Disconnect()\\", bS))
    end

    bP.FireServer = function(self, ...)
        local bS = t.registry[bh] or \\"remote\\"
        local bA = {...}
        local c5 = {}
        for W, b5 in ipairs(bA) do
            table.insert(c5, aZ(b5))
        end
        at(string.format(\\"%s:FireServer(%s)\\", bS, table.concat(c5, \\", \\")))
        table.insert(t.call_graph, {type = \\"RemoteEvent\\", name = bS, args = bA})
    end

    bP.InvokeServer = function(self, ...)
        local bS = t.registry[bh] or \\"remote\\"
        local bA = {...}
        local c5 = {}
        for W, b5 in ipairs(bA) do
            table.insert(c5, aZ(b5))
        end
        local z = bj(\\"invokeResult\\", false)
        local _ = aW(z, \\"result\\")
        at(string.format(\\"local %s = %s:InvokeServer(%s)\\", _, bS, table.concat(c5, \\", \\")))
        table.insert(t.call_graph, {type = \\"RemoteFunction\\", name = bS, args = bA})
        return z
    end

    bP.Create = function(self, x, c6, c7)
        local bS = t.registry[bh] or \\"TweenService\\"
        local c8 = bj(\\"tween\\", false)
        local _ = aW(c8, \\"tween\\")
        at(string.format(\\"local %s = %s:Create(%s, %s, %s)\\", _, bS, aZ(x), aZ(c6), aZ(c7)))
        return c8
    end

    bP.Play = function(self)
        local bS = t.registry[bh] or \\"tween\\"
        at(string.format(\\"%s:Play()\\", bS))
    end

    bP.Pause = function(self)
        local bS = t.registry[bh] or \\"tween\\"
        at(string.format(\\"%s:Pause()\\", bS))
    end

    bP.Cancel = function(self)
        local bS = t.registry[bh] or \\"tween\\"
        at(string.format(\\"%s:Cancel()\\", bS))
    end

    bP.Stop = function(self)
        local bS = t.registry[bh] or \\"tween\\"
        at(string.format(\\"%s:Stop()\\", bS))
    end

    bP.Raycast = function(self, c9, ca, cb)
        local bS = t.registry[bh] or \\"workspace\\"
        local z = bj(\\"raycastResult\\", false)
        local _ = aW(z, \\"rayResult\\")
        if cb then
            at(string.format(\\"local %s = %s:Raycast(%s, %s, %s)\\", _, bS, aZ(c9), aZ(ca), aZ(cb)))
        else
            at(string.format(\\"local %s = %s:Raycast(%s, %s)\\", _, bS, aZ(c9), aZ(ca)))
        end
        return z
    end

    bP.GetMouse = function(self)
        local bS = t.registry[bh] or \\"player\\"
        local cc = bj(\\"mouse\\", false)
        local _ = aW(cc, \\"mouse\\")
        at(string.format(\\"local %s = %s:GetMouse()\\", _, bS))
        return cc
    end

    bP.Kick = function(self, cd)
        local bS = t.registry[bh] or \\"player\\"
        if cd then
            at(string.format(\\"%s:Kick(%s)\\", bS, aZ(cd)))
        else
            at(string.format(\\"%s:Kick()\\", bS))
        end
    end

    bP.GetPropertyChangedSignal = function(self, ce)
        local cf = aE(ce)
        local bS = t.registry[bh] or \\"instance\\"
        local cg = bj(cf .. \\"Changed\\", false)
        t.registry[cg] = bS .. \\":GetPropertyChangedSignal(\\" .. aH(cf) .. \\")\\"
        return cg
    end

    bP.IsA = function(self, bX)
        return true
    end

    bP.IsDescendantOf = function(self, ch)
        return true
    end

    bP.IsAncestorOf = function(self, ci)
        return true
    end

    bP.GetAttribute = function(self, cj)
        return nil
    end

    bP.SetAttribute = function(self, cj, bm)
        local bS = t.registry[bh] or \\"instance\\"
        at(string.format(\\"%s:SetAttribute(%s, %s)\\", bS, aH(cj), aZ(bm)))
    end

    bP.GetAttributes = function(self)
        return {}
    end

    bP.GetPlayers = function(self)
        return {}
    end

    bP.GetPlayerFromCharacter = function(self, ck)
        local bS = t.registry[bh] or \\"Players\\"
        local cl = bj(\\"player\\", false)
        local _ = aW(cl, \\"player\\")
        at(string.format(\\"local %s = %s:GetPlayerFromCharacter(%s)\\", _, bS, aZ(ck)))
        return cl
    end

    bP.GetPlayerByUserId = function(self, cm)
        local bS = t.registry[bh] or \\"Players\\"
        local cl = bj(\\"player\\", false)
        local _ = aW(cl, \\"player\\")
        at(string.format(\\"local %s = %s:GetPlayerByUserId(%s)\\", _, bS, aZ(cm)))
        return cl
    end

    bP.SetCore = function(self, am, bm)
        local bS = t.registry[bh] or \\"StarterGui\\"
        at(string.format(\\"%s:SetCore(%s, %s)\\", bS, aH(am), aZ(bm)))
    end

    bP.GetCore = function(self, am)
        return nil
    end

    bP.SetCoreGuiEnabled = function(self, cn, co)
        local bS = t.registry[bh] or \\"StarterGui\\"
        at(string.format(\\"%s:SetCoreGuiEnabled(%s, %s)\\", bS, aZ(cn), aZ(co)))
    end

    bP.BindToRenderStep = function(self, am, cp, bs)
        local bS = t.registry[bh] or \\"RunService\\"
        at(string.format(\\"%s:BindToRenderStep(%s, %s, function(deltaTime)\\", bS, aH(am), aZ(cp)))
        t.indent = t.indent + 1
        if j(bs) == \\"function\\" then
            xpcall(function()
                bs(0.016)
            end, function() end)
        end
        t.indent = t.indent - 1
        at(\\"end)\\")
    end

    bP.UnbindFromRenderStep = function(self, am)
        local bS = t.registry[bh] or \\"RunService\\"
        at(string.format(\\"%s:UnbindFromRenderStep(%s)\\", bS, aH(am)))
    end

    bP.GetFullName = function(self)
        return t.registry[bh] or \\"Instance\\"
    end

    bP.GetDebugId = function(self)
        return \\"DEBUG_\\" .. (H(bh) or \\"0\\")
    end

    bP.MoveTo = function(self, cq, cr)
        local bS = t.registry[bh] or \\"humanoid\\"
        if cr then
            at(string.format(\\"%s:MoveTo(%s, %s)\\", bS, aZ(cq), aZ(cr)))
        else
            at(string.format(\\"%s:MoveTo(%s)\\", bS, aZ(cq)))
        end
    end

    bP.Move = function(self, ca, cs)
        local bS = t.registry[bh] or \\"humanoid\\"
        at(string.format(\\"%s:Move(%s, %s)\\", bS, aZ(ca), aZ(cs or false)))
    end

    bP.EquipTool = function(self, ct)
        local bS = t.registry[bh] or \\"humanoid\\"
        at(string.format(\\"%s:EquipTool(%s)\\", bS, aZ(ct)))
    end

    bP.UnequipTools = function(self)
        local bS = t.registry[bh] or \\"humanoid\\"
        at(string.format(\\"%s:UnequipTools()\\", bS))
    end

    bP.TakeDamage = function(self, cu)
        local bS = t.registry[bh] or \\"humanoid\\"
        at(string.format(\\"%s:TakeDamage(%s)\\", bS, aZ(cu)))
    end

    bP.ChangeState = function(self, cv)
        local bS = t.registry[bh] or \\"humanoid\\"
        at(string.format(\\"%s:ChangeState(%s)\\", bS, aZ(cv)))
    end

    bP.GetState = function(self)
        return bj(\\"Enum.HumanoidStateType.Running\\", false)
    end

    bP.SetPrimaryPartCFrame = function(self, cw)
        local bS = t.registry[bh] or \\"model\\"
        at(string.format(\\"%s:SetPrimaryPartCFrame(%s)\\", bS, aZ(cw)))
    end

    bP.GetPrimaryPartCFrame = function(self)
        return CFrame.new(0, 0, 0)
    end

    bP.PivotTo = function(self, cw)
        local bS = t.registry[bh] or \\"model\\"
        at(string.format(\\"%s:PivotTo(%s)\\", bS, aZ(cw)))
    end

    bP.GetPivot = function(self)
        return CFrame.new(0, 0, 0)
    end

    bP.GetBoundingBox = function(self)
        return CFrame.new(0, 0, 0), Vector3.new(1, 1, 1)
    end

    bP.GetExtentsSize = function(self)
        return Vector3.new(1, 1, 1)
    end

    bP.TranslateBy = function(self, cx)
        local bS = t.registry[bh] or \\"model\\"
        at(string.format(\\"%s:TranslateBy(%s)\\", bS, aZ(cx)))
    end

    bP.LoadAnimation = function(self, cy)
        local bS = t.registry[bh] or \\"animator\\"
        local cz = bj(\\"animTrack\\", false)
        local _ = aW(cz, \\"animTrack\\")
        at(string.format(\\"local %s = %s:LoadAnimation(%s)\\", _, bS, aZ(cy)))
        return cz
    end

    bP.GetPlayingAnimationTracks = function(self)
        return {}
    end

    bP.AdjustSpeed = function(self, cA)
        local bS = t.registry[bh] or \\"animTrack\\"
        at(string.format(\\"%s:AdjustSpeed(%s)\\", bS, aZ(cA)))
    end

    bP.AdjustWeight = function(self, cB, cC)
        local bS = t.registry[bh] or \\"animTrack\\"
        if cC then
            at(string.format(\\"%s:AdjustWeight(%s, %s)\\", bS, aZ(cB), aZ(cC)))
        else
            at(string.format(\\"%s:AdjustWeight(%s)\\", bS, aZ(cB)))
        end
    end

    bP.Teleport = function(self, cD, cl, cE, cF)
        local bS = t.registry[bh] or \\"TeleportService\\"
        at(string.format(\\"%s:Teleport(%s, %s%s%s)\\", bS, aZ(cD), aZ(cl), cE and \\", \\" .. aZ(cE) or '\\"', cF and \\", \\" .. aZ(cF) or \\"\\"))
    end

    bP.TeleportToPlaceInstance = function(self, cD, cG, cl)
        local bS = t.registry[bh] or \\"TeleportService\\"
        at(string.format(\\"%s:TeleportToPlaceInstance(%s, %s, %s)\\", bS, aZ(cD), aZ(cG), aZ(cl)))
    end

    bP.PlayLocalSound = function(self, cH)
        local bS = t.registry[bh] or \\"SoundService\\"
        at(string.format(\\"%s:PlayLocalSound(%s)\\", bS, aZ(cH)))
    end

    bP.GetAsync = function(self, cI)
        return \\"{}\\"
    end

    bP.PostAsync = function(self, cI, cJ)
        return \\"{}\\"
    end

    bP.JSONEncode = function(self, cJ)
        return \\"{}\\"
    end

    bP.JSONDecode = function(self, O)
        return {}
    end

    bP.GenerateGUID = function(self, cK)
        return \\"00000000-0000-0000-0000-000000000000\\"
    end

    bP.HttpGet = function(self, cI)
        local cL = aE(cI)
        table.insert(t.string_refs, {value = cL, hint = \\"HTTP URL\\"})
        t.last_http_url = cL
        return cL
    end

    bP.HttpPost = function(self, cI, cJ, cM)
        local cL = aE(cI)
        table.insert(t.string_refs, {value = cL, hint = \\"HTTP POST URL\\"})
        local x = bj(\\"HttpResponse\\", false)
        local _ = aW(x, \\"httpResponse\\")
        local bS = t.registry[bh] or \\"HttpService\\"
        at(string.format(\\"local %s = %s:HttpPost(%s, %s, %s)\\", _, bS, aZ(cI), aZ(cJ), aZ(cM)))
        t.property_store[x] = {Body = \\"{}\\", StatusCode = 200, Success = true}
        return x
    end

    bP.AddItem = function(self, cN, cO)
        local bS = t.registry[bh] or \\"Debris\\"
        at(string.format(\\"%s:AddItem(%s, %s)\\", bS, aZ(cN), aZ(cO or 10)))
    end

    bi.__index = function(b2, b4)
        if b4 == F or b4 == \\"__proxy_id\\" then
            return rawget(b2, b4)
        end
        if b4 == \\"PlaceId\\" or b4 == \\"GameId\\" or b4 == \\"placeId\\" or b4 == \\"gameId\\" then
            return u
        end
        local bS = t.registry[bh] or aT or \\"object\\"
        local cP = aE(b4)
        
        if b4 == \\"Heartbeat\\" and bS:match(\\"RunService\\") then
            return bP.Heartbeat
        end
        
        if t.property_store[bh] and t.property_store[bh][b4] ~= nil then
            return t.property_store[bh][b4]
        end
        if bP[cP] then
            local cQ, cR = bg()
            t.registry[cQ] = bS .. \\".\\" .. cP
            cR.__call = function(W, ...)
                local bA = {...}
                if bA[1] == bh or G(bA[1]) and bA[1] ~= cQ then
                    table.remove(bA, 1)
                end
                return bP[cP](bh, table.unpack(bA))
            end
            cR.__index = function(W, cS)
                if cS == F or cS == \\"__proxy_id\\" then
                    return rawget(cQ, cS)
                end
                return bj(cS, false, cQ)
            end
            cR.__tostring = function()
                return bS .. \\":\\" .. cP
            end
            return cQ
        end
        if bS == \\"fenv\\" or bS == \\"getgenv\\" or bS == \\"_G\\" then
            if b4 == \\"game\\" then
                return game
            end
            if b4 == \\"workspace\\" then
                return workspace
            end
            if b4 == \\"script\\" then
                return script
            end
            if b4 == \\"Enum\\" then
                return Enum
            end
            if _G[b4] ~= nil then
                return _G[b4]
            end
            return nil
        end
        if b4 == \\"Parent\\" then
            return t.parent_map[bh] or bj(\\"Parent\\", false)
        end
        if b4 == \\"Name\\" then
            return aT or \\"Object\\"
        end
        if b4 == \\"ClassName\\" then
            return aT or \\"Instance\\"
        end
        if b4 == \\"LocalPlayer\\" then
            local cT = bj(\\"LocalPlayer\\", false, bh)
            local _ = aW(cT, \\"LocalPlayer\\")
            at(string.format(\\"local %s = %s.LocalPlayer\\", _, bS))
            return cT
        end
        if b4 == \\"PlayerGui\\" then
            return bj(\\"PlayerGui\\", false, bh)
        end
        if b4 == \\"Backpack\\" then
            return bj(\\"Backpack\\", false, bh)
        end
        if b4 == \\"PlayerScripts\\" then
            return bj(\\"PlayerScripts\\", false, bh)
        end
        if b4 == \\"UserId\\" then
            return 1
        end
        if b4 == \\"DisplayName\\" then
            return \\"Player\\"
        end
        if b4 == \\"AccountAge\\" then
            return 1000
        end
        if b4 == \\"Team\\" then
            return bj(\\"Team\\", false, bh)
        end
        if b4 == \\"TeamColor\\" then
            return BrickColor.new(\\"White\\")
        end
        if b4 == \\"Character\\" then
            local cT = bj(\\"Character\\", false, bh)
            if not t.registry[cT] then
                local _ = aW(cT, \\"Character\\")
                local bS = t.registry[bh] or \\"LocalPlayer\\"
                at(string.format(\\"local %s = %s.Character\\", _, bS))
            end
            return cT
        end
        if b4 == \\"Humanoid\\" then
            local cU = bj(\\"Humanoid\\", false, bh)
            t.property_store[cU] = {Health = 100, MaxHealth = 100, WalkSpeed = 16, JumpPower = 50, JumpHeight = 7.2}
            return cU
        end
        if b4 == \\"HumanoidRootPart\\" or b4 == \\"PrimaryPart\\" or b4 == \\"RootPart\\" then
            local cV = bj(\\"HumanoidRootPart\\", false, bh)
            t.property_store[cV] = {Position = Vector3.new(0, 5, 0), CFrame = CFrame.new(0, 5, 0)}
            return cV
        end
        local cW = {\\"Head\\", \\"Torso\\", \\"UpperTorso\\", \\"LowerTorso\\", \\"RightArm\\", \\"LeftArm\\", \\"RightLeg\\", \\"LeftLeg\\", \\"RightHand\\", \\"LeftHand\\", \\"RightFoot\\", \\"LeftFoot\\"}
        for W, cr in ipairs(cW) do
            if b4 == cr then
                return bj(b4, false, bh)
            end
        end
        if b4 == \\"Animator\\" then
            return bj(\\"Animator\\", false, bh)
        end
        if b4 == \\"CurrentCamera\\" or b4 == \\"Camera\\" then
            local cX = bj(\\"Camera\\", false, bh)
            t.property_store[cX] = {CFrame = CFrame.new(0, 10, 0), FieldOfView = 70, ViewportSize = Vector2.new(1920, 1080)}
            return cX
        end
        if b4 == \\"CameraType\\" then
            return bj(\\"Enum.CameraType.Custom\\", false)
        end
        if b4 == \\"CameraSubject\\" then
            return bj(\\"Humanoid\\", false, bh)
        end
        local cY = {Health = 100, MaxHealth = 100, WalkSpeed = 16, JumpPower = 50, JumpHeight = 7.2, HipHeight = 2, Transparency = 0, Mass = 1, Value = 0, TimePosition = 0, TimeLength = 1, Volume = 0.5, PlaybackSpeed = 1, Brightness = 1, Range = 60, Angle = 90, FieldOfView = 70, Size = 1, Thickness = 1, ZIndex = 1, LayoutOrder = 0}
        if cY[b4] then
            return bl(cY[b4])
        end
        local cZ = {Visible = true, Enabled = true, Anchored = false, CanCollide = true, Locked = false, Active = true, Draggable = false, Modal = false, Playing = false, Looped = false, IsPlaying = false, AutoPlay = false, Archivable = true, ClipsDescendants = false, RichText = false, TextWrapped = false, TextScaled = false, PlatformStand = false, AutoRotate = true, Sit = false}
        if cZ[b4] ~= nil then
            return cZ[b4]
        end
        if b4 == \\"AbsoluteSize\\" or b4 == \\"ViewportSize\\" then
            return Vector2.new(1920, 1080)
        end
        if b4 == \\"AbsolutePosition\\" then
            return Vector2.new(0, 0)
        end
        if b4 == \\"Position\\" then
            if aT and (aT:match(\\"Part\\") or aT:match(\\"Model\\") or aT:match(\\"Character\\") or aT:match(\\"Root\\")) then
                return Vector3.new(0, 5, 0)
            end
            return UDim2.new(0, 0, 0, 0)
        end
        if b4 == \\"Size\\" then
            if aT and aT:match(\\"Part\\") then
                return Vector3.new(4, 1, 2)
            end
            return UDim2.new(1, 0, 1, 0)
        end
        if b4 == \\"CFrame\\" then
            return CFrame.new(0, 5, 0)
        end
        if b4 == \\"Velocity\\" or b4 == \\"AssemblyLinearVelocity\\" then
            return Vector3.new(0, 0, 0)
        end
        if b4 == \\"RotVelocity\\" or b4 == \\"AssemblyAngularVelocity\\" then
            return Vector3.new(0, 0, 0)
        end
        if b4 == \\"Orientation\\" or b4 == \\"Rotation\\" then
            return Vector3.new(0, 0, 0)
        end
        if b4 == \\"LookVector\\" then
            return Vector3.new(0, 0, -1)
        end
        if b4 == \\"RightVector\\" then
            return Vector3.new(1, 0, 0)
        end
        if b4 == \\"UpVector\\" then
            return Vector3.new(0, 1, 0)
        end
        if b4 == \\"Color\\" or b4 == \\"Color3\\" or b4 == \\"BackgroundColor3\\" or b4 == \\"BorderColor3\\" or b4 == \\"TextColor3\\" or b4 == \\"PlaceholderColor3\\" or b4 == \\"ImageColor3\\" then
            return Color3.new(1, 1, 1)
        end
        if b4 == \\"BrickColor\\" then
            return BrickColor.new(\\"Medium stone grey\\")
        end
        if b4 == \\"Material\\" then
            return bj(\\"Enum.Material.Plastic\\", false)
        end
        if b4 == \\"Hit\\" then
            return CFrame.new(0, 0, -10)
        end
        if b4 == \\"Origin\\" then
            return CFrame.new(0, 5, 0)
        end
        if b4 == \\"Target\\" then
            return bj(\\"Target\\", false, bh)
        end
        if b4 == \\"X\\" or b4 == \\"Y\\" then
            return 0
        end
        if b4 == \\"UnitRay\\" then
            return Ray.new(Vector3.new(0, 5, 0), Vector3.new(0, 0, -1))
        end
        if b4 == \\"ViewSizeX\\" then
            return 1920
        end
        if b4 == \\"ViewSizeY\\" then
            return 1080
        end
        if b4 == \\"Text\\" or b4 == \\"PlaceholderText\\" or b4 == \\"ContentText\\" or b4 == \\"Value\\" then
            if s then
                return s
            end
            if b4 == \\"Value\\" then
                return \\"input\\"
            end
            return '\\"'
        end
        if b4 == \\"TextBounds\\" then
            return Vector2.new(0, 0)
        end
        if b4 == \\"Font\\" then
            return bj(\\"Enum.Font.SourceSans\\", false)
        end
        if b4 == \\"TextSize\\" then
            return 14
        end
        if b4 == \\"Image\\" or b4 == \\"ImageContent\\" then
            return '\\"'
        end
        local c_ = {\\"Changed\\", \\"ChildAdded\\", \\"ChildRemoved\\", \\"DescendantAdded\\", \\"DescendantRemoving\\", \\"Touched\\", \\"TouchEnded\\", \\"InputBegan\\", \\"InputEnded\\", \\"InputChanged\\", \\"MouseButton1Click\\", \\"MouseButton1Down\\", \\"MouseButton1Up\\", \\"MouseButton2Click\\", \\"MouseButton2Down\\", \\"MouseButton2Up\\", \\"MouseEnter\\", \\"MouseLeave\\", \\"MouseMoved\\", \\"MouseWheelForward\\", \\"MouseWheelBackward\\", \\"Activated\\", \\"Deactivated\\", \\"FocusLost\\", \\"FocusGained\\", \\"Focused\\", \\"Heartbeat\\", \\"RenderStepped\\", \\"Stepped\\", \\"CharacterAdded\\", \\"CharacterRemoving\\", \\"CharacterAppearanceLoaded\\", \\"PlayerAdded\\", \\"PlayerRemoving\\", \\"AncestryChanged\\", \\"AttributeChanged\\", \\"Died\\", \\"FreeFalling\\", \\"GettingUp\\", \\"Jumping\\", \\"Running\\", \\"Seated\\", \\"Swimming\\", \\"StateChanged\\", \\"HealthChanged\\", \\"MoveToFinished\\", \\"OnClientEvent\\", \\"OnServerEvent\\", \\"OnClientInvoke\\", \\"OnServerInvoke\\", \\"Completed\\", \\"DidLoop\\", \\"Stopped\\", \\"Button1Down\\", \\"Button1Up\\", \\"Button2Down\\", \\"Button2Up\\", \\"Idle\\", \\"Move\\", \\"TextChanged\\", \\"ReturnPressedFromOnScreenKeyboard\\", \\"Triggered\\", \\"TriggerEnded\\"}
        for W, d0 in ipairs(c_) do
            if b4 == d0 then
                local cg = bj(bS .. \\".\\" .. b4, false, bh)
                t.registry[cg] = bS .. \\".\\" .. b4
                return cg
            end
        end
        if bS:match(\\"^Enum\\") then
            local d1 = bS .. \\".\\" .. cP
            local d2 = bj(d1, false)
            t.registry[d2] = d1
            return d2
        end
        return bk(cP, bh)
    end

    bi.__newindex = function(b2, b4, b5)
        if b4 == F or b4 == \\"__proxy_id\\" then
            rawset(b2, b4, b5)
            return
        end
        local bS = t.registry[bh] or aT or \\"object\\"
        local cP = aE(b4)
        t.property_store[bh] = t.property_store[bh] or {}
        t.property_store[bh][b4] = b5
        if b4 == \\"Parent\\" and G(b5) then
            t.parent_map[bh] = b5
        end
        at(string.format(\\"%s.%s = %s\\", bS, cP, aZ(b5)))
    end

    bi.__call = function(b2, ...)
        local bS = t.registry[bh] or aT or \\"func\\"
        if bS == \\"fenv\\" or bS == \\"getgenv\\" or bS:match(\\"env\\") then
            return bh
        end
        local bA = {...}
        local c5 = {}
        for W, b5 in ipairs(bA) do
            table.insert(c5, aZ(b5))
        end
        local z = bj(\\"result\\", false)
        local _ = aW(z, \\"result\\")
        at(string.format(\\"local %s = %s(%s)\\", _, bS, table.concat(c5, \\", \\")))
        return z
    end

    local function d3(d4)
        local function d5(bo, aa)
            local bh, bi = bg()
            local d6 = \\"0\\"
            if bo ~= nil then
                d6 = t.registry[bo] or aZ(bo)
            end
            local d7 = \\"0\\"
            if aa ~= nil then
                d7 = t.registry[aa] or aZ(aa)
            end
            local d8 = \\"(\\" .. d6 .. \\" \\" .. d4 .. \\" \\" .. d7 .. \\")\\"
            t.registry[bh] = d8
            bi.__tostring = function()
                return d8
            end
            bi.__call = function()
                return bh
            end
            bi.__index = function(W, b4)
                if b4 == F or b4 == \\"__proxy_id\\" then
                    return rawget(bh, b4)
                end
                return bj(d8 .. \\".\\" .. aE(b4), false)
            end
            bi.__add = d3(\\"+\\")
            bi.__sub = d3(\\"-\\")
            bi.__mul = d3(\\"*\\")
            bi.__div = d3(\\"/\\")
            bi.__mod = d3(\\"%\\")
            bi.__pow = d3(\\"^\\")
            bi.__concat = d3(\\"..\\")
            bi.__eq = function()
                return false
            end
            bi.__lt = function()
                return false
            end
            bi.__le = function()
                return false
            end
            return bh
        end
        return d5
    end

    bi.__add = d3(\\"+\\")
    bi.__sub = d3(\\"-\\")
    bi.__mul = d3(\\"*\\")
    bi.__div = d3(\\"/\\")
    bi.__mod = d3(\\"%\\")
    bi.__pow = d3(\\"^\\")
    bi.__concat = d3(\\"..\\")
    bi.__eq = function()
        return false
    end
    bi.__lt = function()
        return false
    end
    bi.__le = function()
        return false
    end
    bi.__unm = function(bo)
        local z, d9 = bg()
        t.registry[z] = \\"(-\\" .. (t.registry[bo] or aZ(bo)) .. \\")\\"
        d9.__tostring = function()
            return t.registry[z]
        end
        return z
    end
    bi.__len = function()
        return 0
    end
    bi.__tostring = function()
        return t.registry[bh] or aT or \\"Object\\"
    end
    bi.__pairs = function()
        return function()
            return nil
        end, bh, nil
    end
    bi.__ipairs = bi.__pairs

    return bh
end

local function da(am, db)
    local dc = {}
    local dd = {}
    dd.__index = function(b2, b4)
        if b4 == \\"new\\" or db and db[b4] then
            return function(...)
                local bA = {...}
                local c5 = {}
                for W, b5 in ipairs(bA) do
                    table.insert(c5, aZ(b5))
                end
                local d8 = am .. \\".\\" .. b4 .. \\"(\\" .. table.concat(c5, \\", \\") .. \\")\\"
                local bh, de = bg()
                t.registry[bh] = d8
                de.__tostring = function()
                    return d8
                end
                de.__index = function(W, bG)
                    if bG == F or bG == \\"__proxy_id\\" then
                        return rawget(bh, bG)
                    end
                    if bG == \\"X\\" or bG == \\"Y\\" or bG == \\"Z\\" or bG == \\"W\\" then
                        return 0
                    end
                    if bG == \\"Magnitude\\" then
                        return 0
                    end
                    if bG == \\"Unit\\" then
                        return bh
                    end
                    if bG == \\"Position\\" then
                        return bh
                    end
                    if bG == \\"CFrame\\" then
                        return bh
                    end
                    if bG == \\"LookVector\\" or bG == \\"RightVector\\" or bG == \\"UpVector\\" then
                        return bh
                    end
                    if bG == \\"Rotation\\" then
                        return bh
                    end
                    if bG == \\"R\\" or bG == \\"G\\" or bG == \\"B\\" then
                        return 1
                    end
                    if bG == \\"Width\\" or bG == \\"Height\\" then
                        return UDim.new(0, 0)
                    end
                    if bG == \\"Min\\" or bG == \\"Max\\" then
                        return 0
                    end
                    if bG == \\"Scale\\" or bG == \\"Offset\\" then
                        return 0
                    end
                    if bG == \\"p\\" then
                        return bh
                    end
                    return 0
                end
                local function df(Z)
                    return function(bo, aa)
                        local dg, dh = bg()
                        local O = \\"(\\" .. (t.registry[bo] or aZ(bo)) .. \\" \\" .. Z .. \\" \\" .. (t.registry[aa] or aZ(aa)) .. \\")\\"
                        t.registry[dg] = O
                        dh.__tostring = function()
                            return O
                        end
                        dh.__index = de.__index
                        dh.__add = df(\\"+\\")
                        dh.__sub = df(\\"-\\")
                        dh.__mul = df(\\"*\\")
                        dh.__div = df(\\"/\\")
                        return dg
                    end
                end
                de.__add = df(\\"+\\")
                de.__sub = df(\\"-\\")
                de.__mul = df(\\"*\\")
                de.__div = df(\\"/\\")
                de.__unm = function(bo)
                    local dg, dh = bg()
                    t.registry[dg] = \\"(-\\" .. (t.registry[bo] or aZ(bo)) .. \\")\\"
                    dh.__tostring = function()
                        return t.registry[dg]
                    end
                    return dg
                end
                de.__eq = function()
                    return false
                end
                return bh
            end
        end
        return nil
    end
    dd.__call = function(b2, ...)
        return b2.new(...)
    end
    return setmetatable(dc, dd)
end

Vector3 = da(\\"Vector3\\", {new = true, zero = true, one = true})
Vector2 = da(\\"Vector2\\", {new = true, zero = true, one = true})
UDim = da(\\"UDim\\", {new = true})
UDim2 = da(\\"UDim2\\", {new = true, fromScale = true, fromOffset = true})
CFrame = da(\\"CFrame\\", {new = true, Angles = true, lookAt = true, fromEulerAnglesXYZ = true, fromEulerAnglesYXZ = true, fromAxisAngle = true, fromMatrix = true, fromOrientation = true, identity = true})
Color3 = da(\\"Color3\\", {new = true, fromRGB = true, fromHSV = true, fromHex = true})
BrickColor = da(\\"BrickColor\\", {new = true, random = true, White = true, Black = true, Red = true, Blue = true, Green = true, Yellow = true, palette = true})
TweenInfo = da(\\"TweenInfo\\", {new = true})
Rect = da(\\"Rect\\", {new = true})
Region3 = da(\\"Region3\\", {new = true})
Region3int16 = da(\\"Region3int16\\", {new = true})
Ray = da(\\"Ray\\", {new = true})
NumberRange = da(\\"NumberRange\\", {new = true})
NumberSequence = da(\\"NumberSequence\\", {new = true})
NumberSequenceKeypoint = da(\\"NumberSequenceKeypoint\\", {new = true})
ColorSequence = da(\\"ColorSequence\\", {new = true})
ColorSequenceKeypoint = da(\\"ColorSequenceKeypoint\\", {new = true})
PhysicalProperties = da(\\"PhysicalProperties\\", {new = true})
Font = da(\\"Font\\", {new = true, fromEnum = true, fromName = true, fromId = true})
RaycastParams = da(\\"RaycastParams\\", {new = true})
OverlapParams = da(\\"OverlapParams\\", {new = true})
PathWaypoint = da(\\"PathWaypoint\\", {new = true})
Axes = da(\\"Axes\\", {new = true})
Faces = da(\\"Faces\\", {new = true})
Vector3int16 = da(\\"Vector3int16\\", {new = true})
Vector2int16 = da(\\"Vector2int16\\", {new = true})
CatalogSearchParams = da(\\"CatalogSearchParams\\", {new = true})
DateTime = da(\\"DateTime\\", {now = true, fromUnixTimestamp = true, fromUnixTimestampMillis = true, fromIsoDate = true})

Random = {new = function(di)
    local x = {}
    function x:NextNumber(dj, dk)
        return (dj or 0) + 0.5 * ((dk or 1) - (dj or 0))
    end
    function x:NextInteger(dj, dk)
        return math.floor((dj or 1) + 0.5 * ((dk or 100) - (dj or 1)))
    end
    function x:NextUnitVector()
        return Vector3.new(0.577, 0.577, 0.577)
    end
    function x:Shuffle(dl)
        return dl
    end
    function x:Clone()
        return Random.new()
    end
    return x
end}

setmetatable(Random, {__call = function(b2, di)
    return b2.new(di)
end})

Enum = bj(\\"Enum\\", true)
local dm = a.getmetatable(Enum)
dm.__index = function(b2, b4)
    if b4 == F or b4 == \\"__proxy_id\\" then
        return rawget(b2, b4)
    end
    local dn = bj(\\"Enum.\\" .. aE(b4), false)
    t.registry[dn] = \\"Enum.\\" .. aE(b4)
    return dn
end

Instance = {new = function(bX, bS)
    local bY = aE(bX)
    local x = bj(bY, false)
    local _ = aW(x, bY)
    if bS then
        local dp = t.registry[bS] or aZ(bS)
        at(string.format(\\"local %s = Instance.new(%s, %s)\\", _, aH(bY), dp))
        t.parent_map[x] = bS
    else
        at(string.format(\\"local %s = Instance.new(%s)\\", _, aH(bY)))
    end
    return x
end}

game = bj(\\"game\\", true)
workspace = bj(\\"workspace\\", true)
script = bj(\\"script\\", true)
t.property_store[script] = {Name = \\"DumpedScript\\", Parent = game, ClassName = \\"LocalScript\\"}

task = {
    wait = function(dq)
        t.fake_time = t.fake_time + (dq or 0.03)
        
        if r.SILENT_BYPASS and t.silent_mode then
            return dq or 0.03, t.fake_time
        end
        
        if dq then
            at(string.format(\\"task.wait(%s)\\", aZ(dq)))
        else
            at(\\"task.wait()\\")
        end
        return dq or 0.03, t.fake_time
    end,
    spawn = function(dr, ...)
        local bA = {...}
        at(\\"task.spawn(function()\\")
        t.indent = t.indent + 1
        if j(dr) == \\"function\\" then
            xpcall(function()
                dr(table.unpack(bA))
            end, function(ds)
                at(\\"-- [Error in spawn] \\" .. tostring(ds))
            end)
        end
        while t.pending_iterator do
            t.indent = t.indent - 1
            at(\\"end\\")
            t.pending_iterator = false
        end
        t.indent = t.indent - 1
        at(\\"end)\\")
    end,
    delay = function(dq, dr, ...)
        local bA = {...}
        at(string.format(\\"task.delay(%s, function()\\", aZ(dq or 0)))
        t.indent = t.indent + 1
        if j(dr) == \\"function\\" then
            xpcall(function()
                dr(table.unpack(bA))
            end, function() end)
        end
        while t.pending_iterator do
            t.indent = t.indent - 1
            at(\\"end\\")
            t.pending_iterator = false
        end
        t.indent = t.indent - 1
        at(\\"end)\\")
    end,
    defer = function(dr, ...)
        local bA = {...}
        at(\\"task.defer(function()\\")
        t.indent = t.indent + 1
        if j(dr) == \\"function\\" then
            xpcall(function()
                dr(table.unpack(bA))
            end, function() end)
        end
        t.indent = t.indent - 1
        at(\\"end)\\")
    end,
    cancel = function(dt)
        at(\\"task.cancel(thread)\\")
    end,
    synchronize = function()
        at(\\"task.synchronize()\\")
    end,
    desynchronize = function()
        at(\\"task.desynchronize()\\")
    end
}

-- SECURED: Hardened os table with blocked execute
_G.os = {
    clock = function() 
        t.fake_time = t.fake_time + 0.001
        return t.fake_time 
    end,
    time = function(t) return p.time(t) end,
    date = function(format, time) return p.date(format, time) end,
    difftime = function(t2, t1) return p.difftime(t2, t1) end,
    -- SECURED: os.execute is now completely blocked.
    execute = function(cmd)
        at(string.format(\\"os.execute(%s) -- [BLOCKED]\\", aZ(cmd)))
        return nil, \\"exit\\", 1 -- Return failure
    end,
    remove = function(filename)
        at(string.format(\\"os.remove(%s) -- [BLOCKED]\\", aH(filename)))
        return false
    end,
    rename = function(oldname, newname)
        at(string.format(\\"os.rename(%s, %s) -- [BLOCKED]\\", aH(oldname), aH(newname)))
        return false
    end,
    exit = function(code, close)
        at(string.format(\\"os.exit(%s%s) -- [BLOCKED]\\", code or \\"nil\\", close and \\", true\\" or \\"\\"))
    end,
    tmpname = function()
        local tmpname = \\"/tmp/temp_\\" .. tostring(math.random(100000, 999999))
        at(string.format(\\"os.tmpname() -- returned %s\\", aH(tmpname)))
        return tmpname
    end,
    getenv = function(varname)
        at(string.format(\\"os.getenv(%s)\\", aH(varname)))
        local fakeEnv = {
            PATH = \\"/usr/bin:/bin\\",
            HOME = \\"/home/user\\",
            USER = \\"user\\",
            TEMP = \\"/tmp\\",
            TMP = \\"/tmp\\"
        }
        return fakeEnv[varname] or nil
    end,
    setlocale = function(locale, category)
        if category then
            at(string.format(\\"os.setlocale(%s, %s)\\", aZ(locale), aH(category)))
        else
            at(string.format(\\"os.setlocale(%s)\\", aZ(locale)))
        end
        return \\"C\\"
    end
}

wait = function(dq)
    t.fake_time = t.fake_time + (dq or 0.03)
    
    if r.SILENT_BYPASS and t.silent_mode then
        return dq or 0.03, t.fake_time
    end
    
    if dq then
        at(string.format(\\"wait(%s)\\", aZ(dq)))
    else
        at(\\"wait()\\")
    end
    return dq or 0.03, t.fake_time
end

delay = function(dq, dr)
    at(string.format(\\"delay(%s, function()\\", aZ(dq or 0)))
    t.indent = t.indent + 1
    if j(dr) == \\"function\\" then
        xpcall(dr, function() end)
    end
    t.indent = t.indent - 1
    at(\\"end)\\")
end

spawn = function(dr)
    at(\\"spawn(function())\\")
    t.indent = t.indent + 1
    if j(dr) == \\"function\\" then
        xpcall(dr, function() end)
    end
    t.indent = t.indent - 1
    at(\\"end)\\")
end

tick = function()
    t.fake_time = t.fake_time + 0.001
    return t.fake_time
end

time = function()
    return p.clock()
end

elapsedTime = function()
    return p.clock()
end

local du = {}
local dv = 999999999

local function dw(bG, dx)
    return dx
end

local function dy()
    local b2 = {}
    setmetatable(b2, {
        __call = function(self, ...)
            return self
        end,
        __index = function(self, b4)
            if _G[b4] ~= nil then
                return dw(b4, _G[b4])
            end
            if b4 == \\"game\\" then
                return game
            end
            if b4 == \\"workspace\\" then
                return workspace
            end
            if b4 == \\"script\\" then
                return script
            end
            if b4 == \\"Enum\\" then
                return Enum
            end
            return nil
        end,
        __newindex = function(self, b4, b5)
            _G[b4] = b5
            du[b4] = 0
            at(string.format(\\"_G.%s = %s\\", aE(b4), aZ(b5)))
        end
    })
    return b2
end

_G.G = dy()
_G.g = dy()
_G.ENV = dy()
_G.env = dy()
_G.E = dy()
_G.e = dy()
_G.L = dy()
_G.l = dy()
_G.F = dy()
_G.f = dy()

local function dz(dA)
    local bh = {}
    local dd = {}
    local dB = {
        \\"hookfunction\\",
        \\"hookmetamethod\\",
        \\"newcclosure\\",
        \\"replaceclosure\\",
        \\"checkcaller\\",
        \\"iscclosure\\",
        \\"islclosure\\",
        \\"getrawmetatable\\",
        \\"setreadonly\\",
        \\"make_writeable\\",
        \\"getrenv\\",
        \\"getgc\\",
        \\"getinstances\\"
    }
    local function dC(dD, bG)
        local bd = aE(bG)
        if bd:match(\\"^[%a_][%w_]*$\\") then
            if dD then
                return dD .. \\".\\" .. bd
            end
            return bd
        else
            local aI = bd:gsub(\\"'\\", \\"\\\\\\\\'\\")
            if dD then
                return dD .. \\"['\\" .. aI .. \\"']\\"
            end
            return \\"['\\" .. aI .. \\"']\\"
        end
    end
    dd.__index = function(b2, b4)
        for W, dE in ipairs(dB) do
            if b4 == dE then
                return nil
            end
        end
        local dF = dC(dA, b4)
        return dz(dF)
    end
    dd.__newindex = function(b2, b4, b5)
        local dG = dC(dA, b4)
        at(string.format(\\"getgenv().%s = %s\\", dG, aZ(b5)))
    end
    dd.__call = function(b2, ...)
        return b2
    end
    dd.__pairs = function()
        return function()
            return nil
        end, nil, nil
    end
    return setmetatable(bh, dd)
end

local function enhanced_pcall(f, ...)
    if type(f) ~= \\"function\\" then
        return false, \\"attempt to call a \\" .. type(f) .. \\" value\\"
    end
    
    local info = debug.getinfo(f, \\"S\\")
    if info and info.source then
        local result = {g(f, ...)}
        if result[1] == false then
            local err = tostring(result[2])
            if err:match(\\"attempt to call\\") and err:match(\\"nil\\") then
                return false, err
            end
        end
        return table.unpack(result)
    end
    
    return g(f, ...)
end

local exploit_funcs = {
    getgenv = function()
        return dz(nil)
    end,
    getrenv = function()
        return bj(\\"getrenv()\\", false)
    end,
    getfenv = function(dH)
        return _G
    end,
    setfenv = function(dI, dJ)
        if j(dI) ~= \\"function\\" then
            return
        end
        local L = 1
        while true do
            local am = debug.getupvalue(dI, L)
            if am == \\"_ENV\\" then
                debug.setupvalue(dI, L, dJ)
                break
            elseif not am then
                break
            end
            L = L + 1
        end
        return dI
    end,
    hookfunction = function(dK, dL)
        return dK
    end,
    hookmetamethod = function(x, dM, dN)
        return function() end
    end,
    getrawmetatable = function(x)
        if G(x) then
            return a.getmetatable(x)
        end
        return {}
    end,
    setrawmetatable = function(x, dd)
        return x
    end,
    getnamecallmethod = function()
        return \\"__namecall\\"
    end,
    setnamecallmethod = function(dM)
    end,
    checkcaller = function()
        return true
    end,
    islclosure = function(dr)
        return j(dr) == \\"function\\"
    end,
    iscclosure = function(dr)
        return false
    end,
    newcclosure = function(dr)
        return dr
    end,
    clonefunction = function(dr)
        return dr
    end,
    request = function(dO)
        at(string.format(\\"request(%s)\\", aZ(dO)))
        table.insert(t.string_refs, {value = dO.Url or dO.url or \\"unknown\\", hint = \\"HTTP Request\\"})
        return {Success = true, StatusCode = 200, StatusMessage = \\"OK\\", Headers = {}, Body = \\"{}\\"}
    end,
    http_request = function(dO)
        return exploit_funcs.request(dO)
    end,
    syn = {request = function(dO)
        return exploit_funcs.request(dO)
    end},
    http = {request = function(dO)
        return exploit_funcs.request(dO)
    end},
    HttpPost = function(cI, cJ)
        at(string.format(\\"HttpPost(%s, %s)\\", aE(cI), aE(cJ)))
        return \\"{}\\"
    end,
    setclipboard = function(cJ)
        at(string.format(\\"setclipboard(%s)\\", aZ(cJ)))
    end,
    getclipboard = function()
        return '\\"'
    end,
    identifyexecutor = function()
        return \\"Dumper\\", \\"3.0\\"
    end,
    getexecutorname = function()
        return \\"Dumper\\"
    end,
    gethui = function()
        local dP = bj(\\"HiddenUI\\", false)
        aW(dP, \\"HiddenUI\\")
        at(string.format(\\"local %s = gethui()\\", t.registry[dP]))
        return dP
    end,
    gethiddenui = function()
        return exploit_funcs.gethui()
    end,
    protectgui = function(dQ)
    end,
    iswindowactive = function()
        return true
    end,
    isrbxactive = function()
        return true
    end,
    isgameactive = function()
        return true
    end,
    getconnections = function(cg)
        return {}
    end,
    firesignal = function(cg, ...)
    end,
    fireclickdetector = function(dR, dS)
    end,
    fireproximityprompt = function(dT)
    end,
    firetouchinterest = function(dU, dV, dW)
    end,
    getinstances = function()
        return {}
    end,
    getnilinstances = function()
        return {}
    end,
    getgc = function()
        return {}
    end,
    getscripts = function()
        return {}
    end,
    getrunningscripts = function()
        return {}
    end,
    getloadedmodules = function()
        return {}
    end,
    getcallingscript = function()
        return script
    end,
    readfile = function(dA)
        at(string.format(\\"readfile(%s) -- [BLOCKED]\\", aH(dA)))
        return nil
    end,
    writefile = function(dA, ai)
        at(string.format(\\"writefile(%s, %s) -- [BLOCKED]\\", aH(dA), aZ(ai)))
    end,
    appendfile = function(dA, ai)
        at(string.format(\\"appendfile(%s, %s) -- [BLOCKED]\\", aH(dA), aZ(ai)))
    end,
    loadfile = function(dA)
        return function()
            return bj(\\"loaded_file\\", false)
        end
    end,
    listfiles = function(dX)
        return {}
    end,
    isfile = function(dA)
        return false
    end,
    isfolder = function(dA)
        return false
    end,
    makefolder = function(dA)
        at(string.format(\\"makefolder(%s) -- [BLOCKED]\\", aH(dA)))
    end,
    delfolder = function(dA)
        at(string.format(\\"delfolder(%s) -- [BLOCKED]\\", aH(dA)))
    end,
    delfile = function(dA)
        at(string.format(\\"delfile(%s) -- [BLOCKED]\\", aH(dA)))
    end,
    Drawing = {new = function(aO)
        local dY = aE(aO)
        local x = bj(\\"Drawing_\\" .. dY, false)
        local _ = aW(x, dY)
        at(string.format(\\"local %s = Drawing.new(%s)\\", _, aH(dY)))
        return x
    end, Fonts = bj(\\"Drawing.Fonts\\", false)},
    crypt = {
        base64encode = function(cJ)
            return cJ
        end,
        base64decode = function(cJ)
            return cJ
        end,
        base64_encode = function(cJ)
            return cJ
        end,
        base64_decode = function(cJ)
            return cJ
        end,
        encrypt = function(cJ, bG)
            return cJ
        end,
        decrypt = function(cJ, bG)
            return cJ
        end,
        hash = function(cJ)
            return \\"hash\\"
        end,
        generatekey = function(dZ)
            return string.rep(\\"0\\", dZ or 32)
        end,
        generatebytes = function(dZ)
            return string.rep(\\"\\\\0\\", dZ or 16)
        end
    },
    base64_encode = function(cJ)
        return cJ
    end,
    base64_decode = function(cJ)
        return cJ
    end,
    base64encode = function(cJ)
        return cJ
    end,
    base64decode = function(cJ)
        return cJ
    end,
    mouse1click = function()
        at(\\"mouse1click()\\")
    end,
    mouse1press = function()
        at(\\"mouse1press()\\")
    end,
    mouse1release = function()
        at(\\"mouse1release()\\")
    end,
    mouse2click = function()
        at(\\"mouse2click()\\")
    end,
    mouse2press = function()
        at(\\"mouse2press()\\")
    end,
    mouse2release = function()
        at(\\"mouse2release()\\")
    end,
    mousemoverel = function(d_, e0)
        at(string.format(\\"mousemoverel(%s, %s)\\", aZ(d_), aZ(e0)))
    end,
    mousemoveabs = function(d_, e0)
        at(string.format(\\"mousemoveabs(%s, %s)\\", aZ(d_), aZ(e0)))
    end,
    mousescroll = function(e1)
        at(string.format(\\"mousescroll(%s)\\", aZ(e1)))
    end,
    keypress = function(bG)
        at(string.format(\\"keypress(%s)\\", aZ(bG)))
    end,
    keyrelease = function(bG)
        at(string.format(\\"keyrelease(%s)\\", aZ(bG)))
    end,
    keyclick = function(bG)
        at(string.format(\\"keyclick(%s)\\", aZ(bG)))
    end,
    isreadonly = function(b2)
        return false
    end,
    setreadonly = function(b2, e2)
        return b2
    end,
    make_writeable = function(b2)
        return b2
    end,
    make_readonly = function(b2)
        return b2
    end,
    getthreadidentity = function()
        return 7
    end,
    setthreadidentity = function(aG)
    end,
    getidentity = function()
        return 7
    end,
    setidentity = function(aG)
    end,
    getthreadcontext = function()
        return 7
    end,
    setthreadcontext = function(aG)
    end,
    getcustomasset = function(dA)
        return \\"rbxasset://\\" .. aE(dA)
    end,
    getsynasset = function(dA)
        return \\"rbxasset://\\" .. aE(dA)
    end,
    getinfo = function(dr)
        return {source = \\"=\\", what = \\"Lua\\", name = \\"unknown\\", short_src = \\"dumper\\"}
    end,
    getconstants = function(dr)
        return {}
    end,
    getupvalues = function(dr)
        return {}
    end,
    getprotos = function(dr)
        return {}
    end,
    getupvalue = function(dr, ba)
        return nil
    end,
    setupvalue = function(dr, ba, bm)
    end,
    setconstant = function(dr, ba, bm)
    end,
    getconstant = function(dr, ba)
        return nil
    end,
    getproto = function(dr, ba)
        return function() end
    end,
    setproto = function(dr, ba, e3)
    end,
    getstack = function(dH, ba)
        return nil
    end,
    setstack = function(dH, ba, bm)
    end,
    debug = {
        getinfo = c or function()
            return {}
        end,
        getupvalue = debug.getupvalue or function()
            return nil
        end,
        setupvalue = debug.setupvalue or function()
        end,
        getmetatable = a.getmetatable,
        setmetatable = debug.setmetatable or setmetatable,
        traceback = d or function()
            return '\\"'
        end,
        profilebegin = function()
        end,
        profileend = function()
        end,
        sethook = function()
        end
    },
    rconsoleprint = function(ay)
    end,
    rconsoleclear = function()
    end,
    rconsolecreate = function()
    end,
    rconsoledestroy = function()
    end,
    rconsoleinput = function()
        return \\"\\"
    end,
    rconsoleinfo = function(ay)
    end,
    rconsolewarn = function(ay)
    end,
    rconsoleerr = function(ay)
    end,
    rconsolename = function(am)
    end,
    printconsole = function(ay)
    end,
    setfflag = function(e4, bm)
    end,
    getfflag = function(e4)
        return \\"\\"
    end,
    setfpscap = function(e5)
        at(string.format(\\"setfpscap(%s)\\", aZ(e5)))
    end,
    getfpscap = function()
        return 60
    end,
    isnetworkowner = function(cr)
        return true
    end,
    gethiddenproperty = function(x, ce)
        return nil
    end,
    sethiddenproperty = function(x, ce, bm)
        at(string.format(\\"sethiddenproperty(%s, %s, %s)\\", aZ(x), aH(ce), aZ(bm)))
    end,
    setsimulationradius = function(e6, e7)
        at(string.format(\\"setsimulationradius(%s%s)\\", aZ(e6), e7 and \\", \\" .. aZ(e7) or \\"\\"))
    end,
    getspecialinfo = function(e8)
        return {}
    end,
    saveinstance = function(dO)
        at(string.format(\\"saveinstance(%s)\\", aZ(dO or {})))
    end,
    decompile = function(script)
        return \\"-- decompiled\\"
    end,
    lz4compress = function(cJ)
        return cJ
    end,
    lz4decompress = function(cJ)
        return cJ
    end,
    MessageBox = function(e9, ea, eb)
        return 1
    end,
    setwindowactive = function()
    end,
    setwindowtitle = function(ec)
    end,
    queue_on_teleport = function(al)
        at(string.format(\\"queue_on_teleport(%s)\\", aZ(al)))
    end,
    queueonteleport = function(al)
        at(string.format(\\"queueonteleport(%s)\\", aZ(al)))
    end,
    secure_call = function(dr, ...)
        return dr(...)
    end,
    create_secure_function = function(dr)
        return dr
    end,
    isvalidinstance = function(e8)
        return e8 ~= nil
    end,
    validcheck = function(e8)
        return e8 ~= nil
    end
}

for b4, b5 in D(exploit_funcs) do
    _G[b4] = b5
end

_G.hookfunction = nil
_G.hookmetamethod = nil
_G.newcclosure = nil

local ed = {}

local function ee(d_)
    d_ = (d_ or 0) % 4294967296
    if d_ >= 2147483648 then
        d_ = d_ - 4294967296
    end
    return math.floor(d_)
end

ed.tobit = ee

ed.tohex = function(d_, U)
    return string.format(\\"%0\\" .. (U or 8) .. \\"x\\", (d_ or 0) % 0x100000000)
end

_G.bit = {
    band = function(bo, aa)
        return ee(ee(bo) & ee(aa))
    end,
    bor = function(bo, aa)
        return ee(ee(bo) | ee(aa))
    end,
    bxor = function(bo, aa)
        return ee(ee(bo) ~ ee(aa))
    end,
    lshift = function(d_, U)
        return ee(ee(d_) << U % 32)
    end,
    rshift = function(d_, U)
        return ee(ee(d_) >> U % 32)
    end
}

_G.bit32 = _G.bit

ed.arshift = function(d_, U)
    local b5 = ee(d_ or 0)
    if b5 < 0 then
        return ee(b5 >> U or 0) + ee(-1 << 32 - (U or 0))
    else
        return ee(b5 >> U or 0)
    end
end

ed.rol = function(d_, U)
    d_ = d_ or 0
    U = (U or 0) % 32
    return ee(d_ << U | (d_ >> 32 - U))
end

ed.ror = function(d_, U)
    d_ = d_ or 0
    U = (U or 0) % 32
    return ee(d_ >> U | (d_ << 32 - U))
end

ed.bswap = function(d_)
    d_ = d_ or 0
    local bo = d_ >> 24 & 0xFF
    local aa = d_ >> 8 & 0xFF00
    local ah = d_ << 8 & 0xFF0000
    local ef = d_ << 24 & 0xFF000000
    return ee(bo | aa | ah | ef)
end

ed.countlz = function(U)
    U = ed.tobit(U)
    if U == 0 then
        return 32
    end
    local a2 = 0
    if ed.band(U, 0xFFFF0000) == 0 then
        a2 = a2 + 16
        U = ed.lshift(U, 16)
    end
    if ed.band(U, 0xFF000000) == 0 then
        a2 = a2 + 8
        U = ed.lshift(U, 8)
    end
    if ed.band(U, 0xF0000000) == 0 then
        a2 = a2 + 4
        U = ed.lshift(U, 4)
    end
    if ed.band(U, 0xC0000000) == 0 then
        a2 = a2 + 2
        U = ed.lshift(U, 2)
    end
    if ed.band(U, 0x80000000) == 0 then
        a2 = a2 + 1
    end
    return a2
end

ed.countrz = function(U)
    U = ed.tobit(U)
    if U == 0 then
        return 32
    end
    local a2 = 0
    while ed.band(U, 1) == 0 do
        U = ed.rshift(U, 1)
        a2 = a2 + 1
    end
    return a2
end

ed.lrotate = ed.rol
ed.rrotate = ed.ror

ed.extract = function(U, eg, eh)
    eh = eh or 1
    return U >> eg & 1 << eh - 1
end

ed.replace = function(U, b5, eg, eh)
    eh = eh or 1
    local ei = 1 << eh - 1
    return U & ~(ei << eg) | (b5 & ei << eg)
end

ed.btest = function(bo, aa)
    return ed.band(bo, aa) ~= 0
end

bit32 = ed
bit = ed
_G.bit = bit
_G.bit32 = bit32

table.getn = table.getn or function(b2)
    return #b2
end

table.foreach = table.foreach or function(b2, as)
    for b4, b5 in pairs(b2) do
        as(b4, b5)
    end
end

table.foreachi = table.foreachi or function(b2, as)
    for L, b5 in ipairs(b2) do
        as(L, b5)
    end
end

table.move = table.move or function(ej, as, ds, b2, ek)
    ek = ek or ej
    for L = as, ds do
        ek[b2 + L - as] = ej[L]
    end
    return ek
end

string.split = string.split or function(S, el)
    local b2 = {}
    for O in string.gmatch(S, \\"([^\\" .. (el or \\"%s\\") .. \\"]+)\\") do
        table.insert(b2, O)
    end
    return b2
end

if not math.frexp then
    math.frexp = function(d_)
        if d_ == 0 then
            return 0, 0
        end
        local ds = math.floor(math.log(math.abs(d_)) / math.log(2)) + 1
        local em = d_ / 2 ^ ds
        return em, ds
    end
end

if not math.ldexp then
    math.ldexp = function(em, ds)
        return em * 2 ^ ds
    end
end

if not utf8 then
    utf8 = {}
    utf8.char = function(...)
        local bA = {...}
        local dg = {}
        for L, al in ipairs(bA) do
            table.insert(dg, string.char(al % 256))
        end
        return table.concat(dg)
    end
    utf8.len = function(S)
        return #S
    end
    utf8.codes = function(S)
        local L = 0
        return function()
            L = L + 1
            if L <= #S then
                return L, string.byte(S, L)
            end
        end
    end
end

_G.utf8 = utf8

pairs = function(b2)
    if j(b2) == \\"table\\" and not G(b2) then
        return D(b2)
    end
    return function()
        return nil
    end, b2, nil
end

ipairs = function(b2)
    if j(b2) == \\"table\\" and not G(b2) then
        return E(b2)
    end
    return function()
        return nil
    end, b2, 0
end

_G.pairs = pairs
_G.ipairs = ipairs
_G.math = math
_G.table = table
_G.string = string
_G.os = os
_G.coroutine = coroutine
-- SECURED: io library is removed completely from global scope
_G.io = nil
_G.debug = exploit_funcs.debug
_G.utf8 = utf8
_G.pairs = pairs
_G.ipairs = ipairs
_G.next = next
_G.tostring = tostring
_G.tonumber = tonumber
_G.getmetatable = getmetatable
_G.setmetatable = setmetatable

_G.pcall = function(as, ...)
    if type(as) == \\"function\\" then
        local info = debug.getinfo(as, \\"S\\")
        local result = {g(as, ...)}
        if not result[1] then
            local err = tostring(result[2])
            if err:match(\\"attempt to call\\") and err:match(\\"nil\\") then
                for i = 1, select(\\"#\\", ...) do
                    local arg = select(i, ...)
                    if G(arg) then
                        return false, err
                    end
                end
            end
        end
        return table.unpack(result)
    end
    return g(as, ...)
end

_G.xpcall = function(as, ep, ...)
    local function eq(an)
        if j(an) == \\"string\\" and an:match(\\"TIMEOUT_FORCED_BY_DUMPER\\") then
            return an
        end
        if ep then
            return ep(an)
        end
        return an
    end
    local en = {h(as, eq, ...)}
    local eo = en[1]
    if not eo then
        local an = en[2]
        if j(an) == \\"string\\" and an:match(\\"TIMEOUT_FORCED_BY_DUMPER\\") then
            i(an)
        end
    end
    return table.unpack(en)
end

_G.error = error
if _G.originalError == nil then
    _G.originalError = error
end
_G.assert = assert
_G.select = select
_G.type = type
_G.rawget = rawget
_G.rawset = rawset
_G.rawequal = rawequal
_G.rawlen = rawlen or function(b2)
    return #b2
end
_G.unpack = table.unpack or unpack
_G.pack = table.pack or function(...)
    return {n = select(\\"#\\", ...), ...}
end
_G.task = task
_G.wait = wait
_G.Wait = wait
_G.delay = delay
_G.Delay = delay
_G.spawn = spawn
_G.Spawn = spawn
_G.tick = tick
_G.time = time
_G.elapsedTime = elapsedTime
_G.game = game
_G.Game = game
_G.workspace = workspace
_G.Workspace = workspace
_G.script = script
_G.Enum = Enum
_G.Instance = Instance
_G.Random = Random
_G.Vector3 = Vector3
_G.Vector2 = Vector2
_G.CFrame = CFrame
_G.Color3 = Color3
_G.BrickColor = BrickColor
_G.UDim = UDim
_G.UDim2 = UDim2
_G.TweenInfo = TweenInfo
_G.Rect = Rect
_G.Region3 = Region3
_G.Region3int16 = Region3int16
_G.Ray = Ray
_G.NumberRange = NumberRange
_G.NumberSequence = NumberSequence
_G.NumberSequenceKeypoint = NumberSequenceKeypoint
_G.ColorSequence = ColorSequence
_G.ColorSequenceKeypoint = ColorSequenceKeypoint
_G.PhysicalProperties = PhysicalProperties
_G.Font = Font
_G.RaycastParams = RaycastParams
_G.OverlapParams = OverlapParams
_G.PathWaypoint = PathWaypoint
_G.Axes = Axes
_G.Faces = Faces
_G.Vector3int16 = Vector3int16
_G.Vector2int16 = Vector2int16
_G.CatalogSearchParams = CatalogSearchParams
_G.DateTime = DateTime

getmetatable = function(x)
    if G(x) then
        return \\"The metatable is locked\\"
    end
    return k(x)
end
_G.getmetatable = getmetatable

type = function(x)
    if w(x) then
        return \\"number\\"
    end
    if G(x) then
        return \\"userdata\\"
    end
    return j(x)
end
_G.type = type

typeof = function(x)
    if w(x) then
        return \\"number\\"
    end
    if G(x) then
        local er = t.registry[x]
        if er then
            if er:match(\\"Vector3\\") then
                return \\"Vector3\\"
            end
            if er:match(\\"CFrame\\") then
                return \\"CFrame\\"
            end
            if er:match(\\"Color3\\") then
                return \\"Color3\\"
            end
            if er:match(\\"UDim\\") then
                return \\"UDim2\\"
            end
            if er:match(\\"Enum\\") then
                return \\"EnumItem\\"
            end
        end
        return \\"Instance\\"
    end
    return j(x) == \\"table\\" and \\"table\\" or j(x)
end
_G.typeof = typeof

tonumber = function(x, es)
    if w(x) then
        return 123456789
    end
    return n(x, es)
end
_G.tonumber = tonumber

rawequal = function(bo, aa)
    return l(bo, aa)
end
_G.rawequal = rawequal

tostring = function(x)
    if G(x) then
        local et = t.registry[x]
        return et or \\"Instance\\"
    end
    return m(x)
end
_G.tostring = tostring

t.last_http_url = nil

loadstring = function(al, eu)
    if j(al) ~= \\"string\\" then
        return function()
            return bj(\\"loaded\\", false)
        end
    end
    local cI = t.last_http_url or al
    t.last_http_url = nil
    local ev = nil
    local ew = cI:lower()
    local ex = {
        {pattern = \\"rayfield\\", name = \\"Rayfield\\"},
        {pattern = \\"orion\\", name = \\"OrionLib\\"},
        {pattern = \\"kavo\\", name = \\"Kavo\\"},
        {pattern = \\"venyx\\", name = \\"Venyx\\"},
        {pattern = \\"sirius\\", name = \\"Sirius\\"},
        {pattern = \\"linoria\\", name = \\"Linoria\\"},
        {pattern = \\"wally\\", name = \\"Wally\\"},
        {pattern = \\"dex\\", name = \\"Dex\\"},
        {pattern = \\"infinite\\", name = \\"InfiniteYield\\"},
        {pattern = \\"hydroxide\\", name = \\"Hydroxide\\"},
        {pattern = \\"simplespy\\", name = \\"SimpleSpy\\"},
        {pattern = \\"remotespy\\", name = \\"RemoteSpy\\"}
    }
    for W, ey in ipairs(ex) do
        if ew:find(ey.pattern) then
            ev = ey.name
            break
        end
    end
    if ev then
        local ez = bj(ev, false)
        t.registry[ez] = ev
        t.names_used[ev] = true
        if cI:match(\\"^https?://\\") then
            at(string.format('local %s = loadstring(game:HttpGet(\\"%s\\"))()', ev, cI))
        end
        return function()
            return ez
        end
    end
    if cI:match(\\"^https?://\\") then
        local ez = bj(\\"Library\\", false)
        at(string.format('local Library = loadstring(game:HttpGet(\\"%s\\"))()', cI))
        return function()
            return ez
        end
    end
    if type(al) == \\"string\\" then
        al = I(al)
    end
    local R, an = e(al)
    if R then
        return R
    end
    local ez = bj(\\"LoadedChunk\\", false)
    return function()
        return ez
    end
end

load = loadstring
_G.loadstring = loadstring
_G.load = loadstring

require = function(eA)
    local eB = t.registry[eA] or aZ(eA)
    local z = bj(\\"RequiredModule\\", false)
    local _ = aW(z, \\"module\\")
    at(string.format(\\"local %s = require(%s)\\", _, eB))
    return z
end
_G.require = require

print = function(...)
    local bA = {...}
    local b8 = {}
    for W, b5 in ipairs(bA) do
        table.insert(b8, aZ(b5))
    end
    at(string.format(\\"print(%s)\\", table.concat(b8, \\", \\")))
end
_G.print = print

warn = function(...)
    local bA = {...}
    local b8 = {}
    for W, b5 in ipairs(bA) do
        table.insert(b8, aZ(b5))
    end
    at(string.format(\\"warn(%s)\\", table.concat(b8, \\", \\")))
end
_G.warn = warn

shared = bj(\\"shared\\", true)
_G.shared = shared

local eC = _G
local eD = setmetatable({}, {
    __index = function(b2, b4)
        local aF = rawget(eC, b4)
        if aF == nil then
            aF = rawget(_G, b4)
        end
        return aF
    end,
    __newindex = function(b2, b4, b5)
        rawset(eC, b4, b5)
    end
})
_G._G = eD

function q.reset()
    t = {
        output = {},
        indent = 0,
        registry = {},
        reverse_registry = {},
        names_used = {},
        parent_map = {},
        property_store = {},
        call_graph = {},
        variable_types = {},
        string_refs = {},
        proxy_id = 0,
        callback_depth = 0,
        pending_iterator = false,
        last_http_url = nil,
        last_emitted_line = nil,
        repetition_count = 0,
        current_size = 0,
        limit_reached = false,
        lar_counter = 0,
        captured_constants = {},
        fake_time = 0,
        heartbeat_count = 0,
        silent_mode = false,
        skip_next_waits = 0
    }
    aM = {}
    game = bj(\\"game\\", true)
    workspace = bj(\\"workspace\\", true)
    script = bj(\\"script\\", true)
    Enum = bj(\\"Enum\\", true)
    shared = bj(\\"shared\\", true)
    t.property_store[game] = {PlaceId = u, GameId = u, placeId = u, gameId = u}
    _G.game = game
    _G.Game = game
    _G.workspace = workspace
    _G.Workspace = workspace
    _G.script = script
    _G.Enum = Enum
    _G.shared = shared
    local dm = a.getmetatable(Enum)
    dm.__index = function(b2, b4)
        if b4 == F or b4 == \\"__proxy_id\\" then
            return rawget(b2, b4)
        end
        local dn = bj(\\"Enum.\\" .. aE(b4), false)
        t.registry[dn] = \\"Enum.\\" .. aE(b4)
        return dn
    end
end

function q.get_output()
    return aB()
end

function q.save(aD)
    return aC(aD)
end

function q.get_call_graph()
    return t.call_graph
end

function q.get_string_refs()
    return t.string_refs
end

function q.get_stats()
    return {
        total_lines = #t.output,
        remote_calls = #t.call_graph,
        suspicious_strings = #t.string_refs,
        proxies_created = t.proxy_id
    }
end

function q.dump_env(filePath, flags)
    local getsenv = getsenv or false
    if getsenv == false then
        az(\\"Error: getsenv is not supported by this executor\\")
        return false, \\"getsenv not supported\\"
    end
    
    if not filePath then
        az(\\"Error: FilePath parameter is required\\")
        return false, \\"FilePath required\\"
    end
    
    local ok, err = pcall(function()
        if typeof(filePath) ~= \\"Instance\\" then
            error(\\"FilePath must be a Roblox Instance\\")
        end
        filePath:GetFullName()
    end)
    
    if not ok then
        az(\\"Error: Invalid FilePath - \\" .. tostring(err))
        return false, \\"Invalid FilePath\\"
    end
    
    flags = flags or {}
    local defaultFlags = {
        [\\"only-functions\\"] = false,
        [\\"only-values\\"] = false,
        [\\"no-functions\\"] = false,
        [\\"no-tables\\"] = false,
        [\\"no-userdata\\"] = false,
        [\\"no-upvalues\\"] = false,
        [\\"no-writing\\"] = false,
        [\\"no-printing\\"] = false
    }
    
    for k, v in pairs(defaultFlags) do
        if flags[k] == nil then
            flags[k] = v
        end
    end
    
    q.reset()
    
    local env = getsenv(filePath)
    if not env then
        az(\\"Error: getsenv returned nil for \\" .. tostring(filePath.Name))
        return false, \\"getsenv returned nil\\"
    end
    
    az(\\"=== \\" .. filePath.Name .. \\" ENVIRONMENT DUMP ===\\")
    az(\\"Timestamp: \\" .. os.date(\\"%Y-%m-%d %H:%M:%S\\"))
    aA()
    
    local visited = {}
    local originalGetupvalue = a.getupvalue or (debug and debug.getupvalue)
    
    local function allowed(t)
        if flags[\\"only-functions\\"] then return t == \\"function\\" end
        if flags[\\"only-values\\"] then return t ~= \\"function\\" and t ~= \\"table\\" and t ~= \\"userdata\\" end
        if t == \\"function\\" and flags[\\"no-functions\\"] then return false end
        if t == \\"table\\" and flags[\\"no-tables\\"] then return false end
        if t == \\"userdata\\" and flags[\\"no-userdata\\"] then return false end
        return true
    end
    
    local function dump_table(tbl, prefix)
        if visited[tbl] then
            at(prefix .. \\" = <circular>\\")
            return
        end
        visited[tbl] = true
        
        local functions, values, tables, userdata, upvalues = {}, {}, {}, {}, {}
        
        for k, v in pairs(tbl) do
            local keyStr = prefix ~= \\"\\" and (prefix .. \\".\\" .. tostring(k)) or tostring(k)
            local t = typeof(v)
            
            if t == \\"table\\" then
                if allowed(t) then tables[keyStr] = v end
                if not flags[\\"no-tables\\"] and not flags[\\"only-functions\\"] and not flags[\\"only-values\\"] then
                    dump_table(v, keyStr)
                end
            elseif t == \\"function\\" then
                if allowed(t) then
                    functions[keyStr] = v
                    if not flags[\\"no-upvalues\\"] and originalGetupvalue then
                        local i = 1
                        while true do
                            local success, name, val = pcall(function()
                                return originalGetupvalue(v, i)
                            end)
                            if not success or not name then break end
                            table.insert(upvalues, string.format(\\"%s.%s = %s\\", 
                                keyStr:gsub(\\"\\\"\\", \\"\\\\\\\"\\"), 
                                tostring(name):gsub(\\"\\\"\\", \\"\\\\\\\"\\"), 
                                aZ(val)))
                            i = i + 1
                        end
                    end
                end
            elseif t == \\"userdata\\" then
                if allowed(t) then userdata[keyStr] = v end
            else
                if allowed(t) then values[keyStr] = v end
            end
        end
        
        local categories = {
            {name = \\"functions\\", data = functions},
            {name = \\"values\\", data = values},
            {name = \\"tables\\", data = tables},
            {name = \\"userdata\\", data = userdata},
            {name = \\"upvalues\\", data = upvalues}
        }
        
        for _, cat in ipairs(categories) do
            if next(cat.data) then
                at(string.format(\\"-- %s --\\", cat.name:upper()))
                if cat.name == \\"upvalues\\" then
                    for _, line in ipairs(cat.data) do at(line) end
                else
                    for k, v in pairs(cat.data) do
                        if cat.name == \\"functions\\" then
                            at(string.format(\\"%s = function %s(...) %s\\", k, k, aZ(v)))
                        elseif cat.name == \\"values\\" then
                            at(string.format(\\"%s = %s\\", k, aZ(v)))
                        else
                            at(string.format(\\"%s = %s\\", k, cat.name:sub(1, -2)))
                        end
                    end
                end
                aA()
            end
        end
    end
    
    dump_table(env, \\"\\")
    
    az(\\"=== END ENV DUMP ===\\")
    
    local result = aB()
    
    if not flags[\\"no-printing\\"] then
        B(result)
    else
        B(filePath.Name .. \\" environment dump completed\\")
    end
    
    if not flags[\\"no-writing\\"] then
        local fileName = filePath.Name .. \\"_env_dump.lua\\"
        aC(fileName)
        az(\\"Saved to: \\" .. fileName)
    end
    
    return true, result
end

local eE = {
    callId = \\"LARRY_\\",
    binaryOperatorNames = {
        [\\"and\\"] = \\"AND\\",
        [\\"or\\"] = \\"OR\\",
        [\\">\\"] = \\"GT\\",
        [\\"<\\"] = \\"LT\\",
        [\\">=\\"] = \\"GE\\",
        [\\"<=\\"] = \\"LE\\",
        [\\"==\\"] = \\"EQ\\",
        [\\"~=\\"] = \\"NEQ\\",
        [\\"..\\"] = \\"CAT\\"
    }
}

function eE:hook(al)
    return self.callId .. al
end

function eE:process_expr(eF)
    if not eF then
        return \\"nil\\"
    end
    if type(eF) == \\"string\\" then
        return eF
    end
    local eG = eF.tag or eF.kind
    if eG == \\"number\\" or eG == \\"string\\" then
        local aF = eG == \\"string\\" and string.format(\\"%q\\", eF.text) or (eF.value or eF.text)
        if r.CONSTANT_COLLECTION then
            return string.format(\\"%sGET(%s)\\", self.callId, aF)
        end
        return aF
    end
    if eG == \\"local\\" or eG == \\"global\\" then
        return (eF.name or eF.token).text
    elseif eG == \\"boolean\\" or eG == \\"bool\\" then
        return tostring(eF.value)
    elseif eG == \\"binary\\" then
        local eH = self:process_expr(eF.lhsoperand)
        local eI = self:process_expr(eF.rhsoperand)
        local X = eF.operator.text
        local eJ = self.binaryOperatorNames[X]
        if eJ then
            return string.format(\\"%s%s(%s, %s)\\", self.callId, eJ, eH, eI)
        end
        return string.format(\\"(%s %s %s)\\", eH, X, eI)
    elseif eG == \\"call\\" then
        local dr = self:process_expr(eF.func)
        local bA = {}
        for L, b5 in ipairs(eF.arguments) do
            bA[L] = self:process_expr(b5.node or b5)
        end
        return string.format(\\"%sCALL(%s, %s)\\", self.callId, dr, table.concat(bA, \\", \\"))
    elseif eG == \\"indexname\\" or eG == \\"index\\" then
        local bS = self:process_expr(eF.expression)
        local ba = eG == \\"indexname\\" and string.format(\\"%q\\", eF.index.text) or self:process_expr(eF.index)
        return string.format(\\"%sCHECKINDEX(%s, %s)\\", self.callId, bS, ba)
    end
    return \\"nil\\"
end

function eE:process_statement(eF)
    if not eF then
        return \\"\\"
    end
    local eG = eF.tag
    if eG == \\"local\\" or eG == \\"assign\\" then
        local eK, eL = {}, {}
        for W, b5 in ipairs(eF.variables or {}) do
            table.insert(eK, self:process_expr(b5.node or b5))
        end
        for W, b5 in ipairs(eF.values or {}) do
            table.insert(eL, self:process_expr(b5.node or b5))
        end
        return (eG == \\"local\\" and \\"local \\" or \\"\\") .. table.concat(eK, \\", \\") .. \\" = \\" .. table.concat(eL, \\", \\")
    elseif eG == \\"block\\" then
        local b9 = {}
        for W, eM in ipairs(eF.statements or {}) do
            table.insert(b9, self:process_statement(eM))
        end
        return table.concat(b9, \\"; \\")
    end
    return self:process_expr(eF) or \\"\\"
end

function q.dump_file(eN, eO)
    q.reset()
    az(\\"This File Was Dumped Successfully  \nlocal fenv = getfenv(0.1)\n\\")
    
    -- FIX: Use 'o' (the real io) directly. 
    -- The dumper needs this to read the file.
    if not o then
        B(\\"[CRITICAL ERROR] IO Library not found. Cannot dump file.\\")
        return false
    end

    local as = o.open(eN, \\"rb\\")
    if not as then
        B(\\"[ERROR] Could not open file: \\" .. tostring(eN))
        return false
    end
    
    local al = as:read(\\"*a\\")
    as:close()
    
    B(\\"[ VOID ] Sanitizing Luau and Binary Literals...\\")
    local eP = I(al)
    local R, eQ = e(eP, \\"Obfuscated_Script\\")
    if not R then
        B(\\"\n[LUA_LOAD_FAIL] \\" .. m(eQ))
        return false
    end
    
    local eR = setmetatable({
        LuraphContinue = function() end,
        script = script,
        game = game,
        workspace = workspace,
        LARRY_CHECKINDEX = function(x, ba)
            local aF = x[ba]
            if j(aF) == \\"table\\" and not t.registry[aF] then
                t.lar_counter = t.lar_counter + 1
                t.registry[aF] = \\"lartab\\" .. t.lar_counter
            end
            return aF
        end,
        LARRY_GET = function(b5)
            return b5
        end,
        LARRY_CALL = function(as, ...)
            return as(...)
        end,
        LARRY_NAMECALL = function(eS, em, ...)
            return eS[em](eS, ...)
        end,
        pcall = function(as, ...)
            local dg = {g(as, ...)}
            if not dg[1] and m(dg[2]):match(\\"TIMEOUT\\") then
                i(dg[2], 0)
            end
            return table.unpack(dg)
        end
    }, {__index = _G, __newindex = _G})
    
    if setfenv then
        setfenv(R, eR)
    end
    
    B(\\"[ VOID ] Executing Protected VM...\\")
    local eT = p.clock()
    b(function()
        if p.clock() - eT > r.TIMEOUT_SECONDS then
            error(\\"TIMEOUT\\", 0)
        end
    end, \\"\\", 1000)
    
    local eo, eU = h(function()
        R()
    end, function(ds)
        return tostring(ds)
    end)
    
    b()
    if not eo then
        az(\\"Terminated: \\" .. eU)
    end
    return q.save(eO or r.OUTPUT_FILE)
end
-- DO NOT ADD ANY MORE 'end' or 'else' HERE. The function is finished.

function q.dump_string(al, eO)
    q.reset()
    az(\\"ts file was generated at .gg/yymRJ9ZBFT\\")
    aA()
    if al then
        al = I(al)
    end
    local R, an = e(al)
    if not R then
        az(\\"Load Error: \\" .. (an or \\"unknown\\"))
        return false, an
    end
    xpcall(function()
        R()
    end, function() end)
    if eO then
        return q.save(eO)
    end
    return true, aB()
end

if arg and arg[1] then
    local eo = q.dump_file(arg[1], arg[2])
    if eo then
        B(\\"Saved to: \\" .. (arg[2] or r.OUTPUT_FILE))
        local eV = q.get_stats()
        B(string.format(\\"Lines: %d | Remotes: %d | Strings: %d\\", eV.total_lines, eV.remote_calls, eV.suspicious_strings))
    end
else
    -- SECURED: o.open call guarded
    if o and o.open then
        local as = o.open(\\"obfuscated.lua\\", \\"rb\\")
        if as then
            as:close()
            local eo = q.dump_file(\\"obfuscated.lua\\")
            if eo then
                B(\\"Saved to: \\" .. r.OUTPUT_FILE)
                B(q.get_output())
            end
        else
            B(\\"Usage: lua dumper.lua <input> [output] [key]\\")
        end
    else
        B(\\"Usage: lua dumper.lua <input> [output] [key]\\")
        B(\\"[INFO] IO Library is disabled. File system access blocked for security.\\")
    end
end

_G.LuraphContinue = function() end
return q
