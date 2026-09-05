print("

local fs, process, stdio, net, serde

-- Safely require Lune dependencies
pcall(function() fs = require(\"@lune/fs\") end)
pcall(function() process = require(\"@lune/process\") end)
pcall(function() stdio = require(\"@lune/stdio\") end)
pcall(function() net = require(\"@lune/net\") end)
pcall(function() serde = require(\"@lune/serde\") end)

------------------------------------------------------------------------
-- 0. CONFIGURATION & LIMITS
------------------------------------------------------------------------

local Config = {
    HookOp = true,         -- Merekam operasi CFrame, Vector, UDim2, Math
    Minifier = false,      -- Meminifikasi output (diset false secara default)
    Pretty = true,         -- Merapikan output dengan indentasi otomatis
    BypassAntiEnv = true,  -- Bypass deteksi eksekutor (syn, krnl, dll)
    ExploreFuncs = true,   -- Ekstrak fungsi di dalam event callback
    InfLoopGuard = true,   -- Perlindungan infinite loop
    Constants = false,     -- Mengubah string menjadi STR_CONST
    SpyExecOnly = false,   -- Hanya merekam aktivitas mencurigakan
    TypeAnnotations = false, -- Memberikan anotasi tipe Luau pada variabel
    Timeout = 180,         -- Batas waktu timeout saat eksekusi
    LogErrors = false      -- Mencetak error eksekusi di output
}

------------------------------------------------------------------------
-- 1. JSON ENCODER / DECODER
------------------------------------------------------------------------

local jsonEncode, jsonDecode

if serde then
    jsonEncode = function(t) 
        return serde.encode(\"json\", t) 
    end
    jsonDecode = function(s) 
        return serde.decode(\"json\", s) 
    end
else
    jsonEncode = function(t)
        local function enc(v, d)
            if d > 12 then 
                return '\"[MAX_DEPTH]\"' 
            end
            local tp = type(v)
            if tp == \"nil\" then 
                return \"null\"
            elseif tp == \"boolean\" then 
                return v and \"true\" or \"false\"
            elseif tp == \"number\" then
                if v ~= v or v == math.huge or v == -math.huge then 
                    return \"null\" 
                end
                return tostring(v)
            elseif tp == \"string\" then
                local escaped = v:gsub('\\\\', '\\\\\\\\'):gsub('\"', '\\\\\"'):gsub('\\n', '\\\\n'):gsub('\\r', '\\\\r'):gsub('\\t', '\\\\t')
                return '\"' .. escaped .. '\"'
            elseif tp == \"table\" then
                local p = {}
                local isArr = #v > 0
                if isArr then
                    for i, x in ipairs(v) do
                        p[i] = enc(x, d + 1)
                    end
                    return \"[\" .. table.concat(p, \",\") .. \"]\"
                else
                    for k, x in pairs(v) do
                        p[#p + 1] = '\"' .. tostring(k) .. '\":' .. enc(x, d + 1)
                    end
                    return \"{\" .. table.concat(p, \",\") .. \"}\"
                end
            end
            return '\"' .. tostring(v) .. '\"'
        end
        return enc(t, 0)
    end

    jsonDecode = function(s)
        if not s or s == \"\" then 
            return nil 
        end
        local pos = 1
        local function skip()
            while pos <= #s and s:sub(pos, pos):match(\"%s\") do 
                pos = pos + 1 
            end
        end
        local function peek() 
            return s:sub(pos, pos) 
        end
        local function parseValue()
            skip()
            local c = peek()
            if c == '\"' then
                pos = pos + 1
                local r = \"\"
                while pos <= #s do
                    local ch = peek()
                    if ch == '\"' then 
                        pos = pos + 1 
                        return r
                    elseif ch == '\\\\' then
                        pos = pos + 1
                        local nc = peek()
                        if nc == 'n' then 
                            r = r .. '\\n'
                        elseif nc == 'r' then 
                            r = r .. '\\r'
                        elseif nc == 't' then 
                            r = r .. '\\t'
                        else 
                            r = r .. nc 
                        end
                    else 
                        r = r .. ch 
                    end
                    pos = pos + 1
                end
                return r
            elseif c == '{' then
                pos = pos + 1
                skip()
                local obj = {}
                if peek() == '}' then 
                    pos = pos + 1 
                    return obj 
                end
                while true do
                    skip()
                    local k = parseValue()
                    skip()
                    if peek() == ':' then 
                        pos = pos + 1 
                    end
                    skip()
                    obj[k] = parseValue()
                    skip()
                    if peek() == ',' then 
                        pos = pos + 1
                    elseif peek() == '}' then 
                        pos = pos + 1 
                        break
                    else 
                        break 
                    end
                end
                return obj
            elseif c == '[' then
                pos = pos + 1
                skip()
                local arr = {}
                if peek() == ']' then 
                    pos = pos + 1 
                    return arr 
                end
                while true do
                    skip()
                    arr[#arr + 1] = parseValue()
                    skip()
                    if peek() == ',' then 
                        pos = pos + 1
                    elseif peek() == ']' then 
                        pos = pos + 1 
                        break
                    else 
                        break 
                    end
                end
                return arr
            elseif c == 't' then 
                pos = pos + 4 
                return true
            elseif c == 'f' then 
                pos = pos + 5 
                return false
            elseif c == 'n' then 
                pos = pos + 4 
                return nil
            elseif c:match(\"[%d%-]\") then
                local st = pos
                while pos <= #s and peek():match(\"[%d%.eE%+%-]\") do 
                    pos = pos + 1 
                end
                return tonumber(s:sub(st, pos - 1))
            end
            return parseValue()
        end
        return parseValue()
    end
end

------------------------------------------------------------------------
-- 2. BIT32 POLYFILL
------------------------------------------------------------------------

local Bit32Shim = {}

function Bit32Shim.bnot(a)
    return 0xFFFFFFFF - (tonumber(a) or 0)
end

function Bit32Shim.band(...)
    local r = 0xFFFFFFFF
    for _, v in ipairs({...}) do
        local a2 = r
        local b2 = tonumber(v) or 0
        local res = 0
        local bit = 1
        while a2 > 0 or b2 > 0 do
            if a2 % 2 == 1 and b2 % 2 == 1 then
                res = res + bit
            end
            a2 = math.floor(a2 / 2)
            b2 = math.floor(b2 / 2)
            bit = bit * 2
        end
        r = res
    end
    return r
end

function Bit32Shim.bor(...)
    local r = 0
    for _, v in ipairs({...}) do
        local a2 = r
        local b2 = tonumber(v) or 0
        local res = 0
        local bit = 1
        while a2 > 0 or b2 > 0 do
            if a2 % 2 == 1 or b2 % 2 == 1 then
                res = res + bit
            end
            a2 = math.floor(a2 / 2)
            b2 = math.floor(b2 / 2)
            bit = bit * 2
        end
        r = res
    end
    return r
end

function Bit32Shim.bxor(a, b)
    local a_val = tonumber(a) or 0
    local b_val = tonumber(b) or 0
    local res = 0
    local bit = 1
    while a_val > 0 or b_val > 0 do
        if a_val % 2 ~= b_val % 2 then
            res = res + bit
        end
        a_val = math.floor(a_val / 2)
        b_val = math.floor(b_val / 2)
        bit = bit * 2
    end
    return res
end

function Bit32Shim.lshift(a, b)
    local base = tonumber(a) or 0
    local shift = tonumber(b) or 0
    return math.floor(base * (2 ^ shift)) % 4294967296
end

function Bit32Shim.rshift(a, b)
    local base = tonumber(a) or 0
    local shift = tonumber(b) or 0
    return math.floor(base / (2 ^ shift)) % 4294967296
end

function Bit32Shim.arshift(a, b)
    local base = tonumber(a) or 0
    local shift = tonumber(b) or 0
    return math.floor(base / (2 ^ shift))
end

function Bit32Shim.extract(n, field, width)
    local val = tonumber(n) or 0
    local f = tonumber(field) or 0
    local w = tonumber(width) or 1
    local shifted = Bit32Shim.rshift(val, f)
    local mask = Bit32Shim.lshift(1, w) - 1
    return Bit32Shim.band(shifted, mask)
end

function Bit32Shim.replace(n, v, field, width)
    return n
end

function Bit32Shim.lrotate(x, disp)
    local shift_left = Bit32Shim.lshift(x, disp)
    local shift_right = Bit32Shim.rshift(x, 32 - disp)
    return Bit32Shim.bor(shift_left, shift_right)
end

function Bit32Shim.rrotate(x, disp)
    local shift_right = Bit32Shim.rshift(x, disp)
    local shift_left = Bit32Shim.lshift(x, 32 - disp)
    return Bit32Shim.bor(shift_right, shift_left)
end

function Bit32Shim.countlz(a) 
    return 0 
end

function Bit32Shim.countrz(a) 
    return 0 
end

------------------------------------------------------------------------
-- 3. SECURITY LAYER & LIMITS
------------------------------------------------------------------------

local Security = {
    BANNED_PATTERNS = {
        { pattern = \"os%.execute%s*%(\", label = \"os.execute\" },
        { pattern = \"io%.popen%s*%(\", label = \"io.popen\" },
        { pattern = \"dofile%s*%(\", label = \"dofile\" },
        { pattern = \"loadfile%s*%(\", label = \"loadfile\" },
    },
    MAX_SOURCE_SIZE = 50000 * 1024,
    callCount = 0,
    MAX_CALLS = 500000
}

local LIMITS = {
    MAX_CALL_DEPTH = 2000,
    MAX_OUTPUT_SIZE = 50 * 1024 * 1024,
    MAX_TABLE_DEPTH = 12,
}

local FEATURES = {
    VARIABLE_HOISTING = true,
    SMART_NUMBER_FORMAT = true,
    PARENT_IN_CONSTRUCTOR = true,
    DRAWING_LIBRARY = true,
    REPORT_ERRORS = true,
    ALWAYS_WAIT_FOR_CHILD = false,
    AST_DEAD_CODE_REVIVAL = true,
}

function Security.ScanSource(source)
    local warnings = {}
    if #source > Security.MAX_SOURCE_SIZE then
        return false, {\"Source too large (\"..#source..\" bytes), max \"..Security.MAX_SOURCE_SIZE..\" bytes\"}
    end
    for _, rule in ipairs(Security.BANNED_PATTERNS) do
        if source:lower():match(rule.pattern) then
            warnings[#warnings + 1] = \"Potentially dangerous pattern: \" .. rule.label
        end
    end
    if source:find(\"\\0\") then
        return false, {\"Null byte detected in source\"}
    end
    if source:sub(1, 1) == \"<\" then
        return false, {\"Source appears to be HTML, not Lua\"}
    end
    return true, warnings
end

function Security.CheckCallRate()
    Security.callCount = Security.callCount + 1
    if Security.callCount > Security.MAX_CALLS then
        error(\"Too many requests (Call limit exceeded)\", 0)
    end
end

function Security.GuardString(s, maxLen)
    maxLen = maxLen or 65536
    if type(s) == \"string\" and #s > maxLen then
        return s:sub(1, maxLen)..\"...[truncated]\"
    end
    return s
end

------------------------------------------------------------------------
-- 4. ERROR FILTER RULES
------------------------------------------------------------------------

local SUPPRESSED_ERROR_PATTERNS = {
    \"attempt to perform arithmetic\",
    \"assertion failed!\",
    \"attempt to modify a readonly table\",
    \"attempt to index boolean with\",
    \"attempt to call missing method\",
    \"attempt to compare\",
    \"invalid argument #\",
    \"attempt to concatenate\",
    \"/root/mainu:\",
    \"attempt to perform arithmetic %(pow%)\",
    \"attempt to perform arithmetic %(div%)\",
}

local function ShouldSuppressError(errMsg)
    if not errMsg then return true end
    local s = tostring(errMsg)
    
    if Config.LogErrors then
        if s:match(\"attempt to call a nil value\") or s:match(\"attempt to index nil with\") then
            return false
        end
    else
        if s:match(\"attempt to call a nil value\") or s:match(\"attempt to index nil with\") then
            return true
        end
    end

    for _, pat in ipairs(SUPPRESSED_ERROR_PATTERNS) do
        if s:match(pat) then 
            return true 
        end
    end
    return false
end

------------------------------------------------------------------------
-- 5. STATE & GC POOL MANAGEMENT
------------------------------------------------------------------------

local GC_POOL = {}

local function TrackGC(obj)
    GC_POOL[#GC_POOL + 1] = obj
    return obj
end

local function MakeState()
    return {
        logs = {},
        sourceLines = {},
        currentSize = 0,
        outputMaxReached = false,
        startTime = os.clock(),
        instanceVarNames = {},
        componentCounters = {},
        mockInstances = {},
        mockInstanceId = 0,
        internalSetup = false,
        declaredVars = {},
        returnValues = {},
        serviceUsage = {},
        customLibraries = {},
        libraryVarNames = {},
        drawingObjects = {},
        drawingId = 0,
        callbackStack = {},
        callbackDepth = 0,
        errorLog = {},
        seenErrors = {},
        timedOut = false,
        loopEmitCount = 0,
        loadstringCounter = 0,
        libraryCounter = 0,
        dataStores = {},
        replicatedCache = setmetatable({}, {__mode = \"v\"}),
        stringConstants = {},
        stringCounter = 0,
    }
end

local State = MakeState()

------------------------------------------------------------------------
-- TIMEOUT & SMART ACTIVITY TRACKER
------------------------------------------------------------------------

local function CheckTimeout()
    if State.timedOut then 
        error(\"TIMEOUT_YIELD\", 0) 
    end
    if os.clock() - State.startTime > Config.Timeout then
        State.timedOut = true
        error(\"TIMEOUT_YIELD\", 0)
    end
end

local function TouchActivity()
    local timeAlive = os.clock() - State.startTime
    local bufferZone = Config.Timeout * 0.5
    if timeAlive > bufferZone then
        State.startTime = math.max(State.startTime, os.clock() - bufferZone)
    end
end

------------------------------------------------------------------------
-- 6. TOKEN STACK & EMITTER
------------------------------------------------------------------------

local function CurrentBuffer()
    if State.callbackDepth > 0 then
        return State.callbackStack[State.callbackDepth]
    end
    return nil
end

local function EmitRaw(line)
    CheckTimeout()
    
    if Config.SpyExecOnly and State.callbackDepth == 0 then
        local isExec = line:match(\"request\") or line:match(\"setclipboard\") or line:match(\"getgenv\") or 
                       line:match(\"loadstring\") or line:match(\"HttpGet\") or line:match(\"^local \") or line:match(\" = \")
        if not isExec then 
            return 
        end
    end

    local buf = CurrentBuffer()
    if buf then
        buf[#buf + 1] = line
    else
        if State.currentSize + #line + 1 > LIMITS.MAX_OUTPUT_SIZE then
            if not State.outputMaxReached then
                State.outputMaxReached = true
                State.logs[#State.logs + 1] = \"-- [Korvahub] MAX OUTPUT LIMIT REACHED. Halting further logs to prevent crash.\"
            end
            return
        end
        State.logs[#State.logs + 1] = line
        State.currentSize = State.currentSize + #line + 1
    end
end

local function Emit(code)
    EmitRaw(code)
end

local function PushCallback()
    State.callbackDepth = State.callbackDepth + 1
    State.callbackStack[State.callbackDepth] = {}
    return State.callbackStack[State.callbackDepth]
end

local function PopCallback()
    local buf = State.callbackStack[State.callbackDepth]
    State.callbackStack[State.callbackDepth] = nil
    State.callbackDepth = State.callbackDepth - 1
    return buf
end

local function ReportError(context, errMsg)
    if not FEATURES.REPORT_ERRORS then 
        return 
    end
    if ShouldSuppressError(errMsg) then 
        return 
    end
    local cleanMsg = tostring(errMsg):gsub(\"/root/[^:]*:\", \"\"):gsub('%[string \"Korvahub_script\"%]:%d+:%s*', \"\"):gsub(\"%(loadstring%):%d+:%s*\", \"\")
    local key = tostring(context) .. \":\" .. cleanMsg
    if State.seenErrors[key] then 
        return 
    end
    State.seenErrors[key] = true
    local msg = '-- [ERROR] ' .. cleanMsg:gsub('\\n', ' ')
    EmitRaw(msg)
end

local function GetVarName(inst)
    if not inst then 
        return nil 
    end
    if State.instanceVarNames[inst] then
        return State.instanceVarNames[inst]
    end
    if type(inst) == \"table\" and inst.__implicitPath then
        return inst.__implicitPath
    end
    return nil
end

------------------------------------------------------------------------
-- 7. STATIC ANALYSIS
------------------------------------------------------------------------

local function ExtractSourceLines(func)
    if not FEATURES.AST_DEAD_CODE_REVIVAL then 
        return nil 
    end
    if type(func) ~= \"function\" then 
        return nil 
    end
    local info = debug.getinfo(func)
    if info and info.linedefined and info.lastlinedefined and State.sourceLines then
        local lines = {}
        for i = info.linedefined, info.lastlinedefined do
            table.insert(lines, State.sourceLines[i] or \"\")
        end
        local raw = table.concat(lines, \"\\n\")
        local body = raw:match(\"^%s*function%s*%b()%s*(.-)%s*end%s*$\")
        if not body then
            body = raw:match(\"function%s*%(.-%)%s*(.*)%s*end\")
        end
        return body or raw
    end
    return nil
end

------------------------------------------------------------------------
-- 8. SERIALIZATION ENGINE
------------------------------------------------------------------------

local SerializeValue
SerializeValue = function(val, depth)
    depth = depth or 0
    if depth > LIMITS.MAX_TABLE_DEPTH then 
        return \"{...}\" 
    end
    
    local ok, result = pcall(function()
        CheckTimeout()
        
        if type(val) == \"table\" then
            if State.instanceVarNames[val] then
                return State.instanceVarNames[val]
            end
            if val.__implicitPath then
                return val.__implicitPath
            end
            if State.libraryVarNames[val] then
                return State.libraryVarNames[val]
            end
        end
        
        local t = type(val)
        
        if t == \"nil\" then
            return \"nil\"
        elseif t == \"boolean\" then
            return tostring(val)
        elseif t == \"number\" then
            if val ~= val then 
                return \"0/0\" 
            end
            if val == math.huge then 
                return \"math.huge\" 
            end
            if val == -math.huge then 
                return \"-math.huge\" 
            end
            if FEATURES.SMART_NUMBER_FORMAT and math.floor(val) == val and math.abs(val) < 1e15 then
                return string.format(\"%d\", val)
            end
            local s = string.format(\"%.6g\", val)
            if tonumber(s) == val then 
                return s 
            end
            return tostring(val)
        elseif t == \"string\" then
            val = Security.GuardString(val, 65536)
            
            if Config.Constants and #val > 4 and not val:match(\"^https?://\") then
                if not State.stringConstants[val] then
                    State.stringCounter = State.stringCounter + 1
                    State.stringConstants[val] = State.stringCounter
                end
                return \"STR_CONST[\" .. State.stringConstants[val] .. \"]\"
            end
            
            return '\"' .. val:gsub('\\\\', '\\\\\\\\'):gsub('\"', '\\\\\"'):gsub('\\n', '\\\\n'):gsub('\\r', '\\\\r'):gsub('\\t', '\\\\t') .. '\"'
        elseif t == \"function\" then
            local rawCode = ExtractSourceLines(val)
            if rawCode and #rawCode > 5 then
                return \"function()\\n \" .. rawCode:gsub(\"\\n\", \"\\n \") .. \"\\n end\"
            end
            return \"function() end\"
        elseif t == \"table\" then
            if val.__isCallback then
                if not val.lines or #val.lines == 0 then
                    return \"function() end\"
                end
                return \"function()\\n \" .. table.concat(val.lines, \"\\n \") .. \"\\n end\"
            end
            if val.__MOCK_INSTANCE then
                return GetVarName(val) or val.__name or \"<Instance>\"
            end
            if val.__MOCK_ENUM then
                return val.__enumString or \"Enum.Unknown\"
            end
            if val.__MOCK_DRAWING then
                return val.__varName or \"Drawing\"
            end
            if val.__MOCK_LIBRARY then
                return val.__libName or \"Library\"
            end
            if val.__isVector3 then
                local function fmt(n)
                    return math.floor(n)==n and string.format(\"%d\",n) or string.format(\"%.3f\",n)
                end
                return string.format(\"Vector3.new(%s, %s, %s)\", fmt(val.X), fmt(val.Y), fmt(val.Z))
            end
            if val.__isVector2 then
                local function fmt(n)
                    return math.floor(n)==n and string.format(\"%d\",n) or string.format(\"%.3f\",n)
                end
                return string.format(\"Vector2.new(%s, %s)\", fmt(val.X), fmt(val.Y))
            end
            if val.__isColor3 then
                return string.format(\"Color3.fromRGB(%d, %d, %d)\",
                    math.floor((val.R or 0)*255+0.5),
                    math.floor((val.G or 0)*255+0.5),
                    math.floor((val.B or 0)*255+0.5))
            end
            if val.__isUDim2 then
                return string.format(\"UDim2.new(%s, %s, %s, %s)\",
                    val.X.Scale, val.X.Offset, val.Y.Scale, val.Y.Offset)
            end
            if val.__isCFrame then
                if val.__isMulCFrame then return val.__str end
                local function fmt(n)
                    return math.floor(n)==n and string.format(\"%d\",n) or string.format(\"%.3f\",n)
                end
                return string.format(\"CFrame.new(%s, %s, %s)\", fmt(val.X), fmt(val.Y), fmt(val.Z))
            end
            
            local parts, count = {}, 0
            local isArr = #val > 0
            for k, v in pairs(val) do
                if not tostring(k):match(\"^__\") then
                    count = count + 1
                    if count > 100 then
                        parts[#parts+1] = \"...\"
                        break
                    end
                    if isArr and type(k) == \"number\" then
                        parts[#parts+1] = SerializeValue(v, depth+1)
                    else
                        local ks = (type(k) == \"string\" and k:match(\"^[%a_][%w_]*$\")) and k or (\"[\"..SerializeValue(k, depth+1)..\"]\")
                        parts[#parts+1] = ks .. \" = \" .. SerializeValue(v, depth+1)
                    end
                end
            end
            if count == 0 then 
                return \"{}\" 
            end
            return \"{\\n \" .. table.concat(parts, \",\\n \") .. \"\\n}\"
        end
        return \"<\" .. t .. \">\"
    end)
    return ok and result or tostring(val)
end

local function SerializeArgs(args, count)
    local parts = {}
    for i = 1, math.min(count or #args, 15) do
        parts[i] = SerializeValue(args[i])
    end
    return table.concat(parts, \", \")
end

local function TrackOp(opStr, a, b)
    if not Config.HookOp then return end
    local sa = (type(a) == \"table\" and (GetVarName(a) or SerializeValue(a))) or SerializeValue(a)
    local sb = (type(b) == \"table\" and (GetVarName(b) or SerializeValue(b))) or SerializeValue(b)
    Emit(\"-- [MathOp] \" .. sa .. \" \" .. opStr .. \" \" .. sb)
end

------------------------------------------------------------------------
-- 9. DATA TYPES & MOCK OBJECTS (Fully Metatabled)
------------------------------------------------------------------------

local MockVector3 = {__index={}}
function MockVector3.new(x,y,z)
    local m = math.sqrt((x or 0)^2 + (y or 0)^2 + (z or 0)^2)
    local u = (m == 0) and {X=0, Y=0, Z=0} or {X=(x or 0)/m, Y=(y or 0)/m, Z=(z or 0)/m}
    u.__isVector3 = true
    return setmetatable({X=x or 0, Y=y or 0, Z=z or 0, __isVector3=true, Magnitude=m, Unit=setmetatable(u, MockVector3)}, MockVector3)
end
MockVector3.__add = function(a,b) 
    TrackOp(\"+\", a, b)
    return MockVector3.new(a.X+b.X, a.Y+b.Y, a.Z+b.Z) 
end
MockVector3.__sub = function(a,b) 
    TrackOp(\"-\", a, b)
    return MockVector3.new(a.X-b.X, a.Y-b.Y, a.Z-b.Z) 
end
MockVector3.__mul = function(a,b) 
    TrackOp(\"*\", a, b)
    return type(b)==\"number\" and MockVector3.new(a.X*b, a.Y*b, a.Z*b) or MockVector3.new(a.X*b.X, a.Y*b.Y, a.Z*b.Z) 
end
MockVector3.__div = function(a,b) 
    TrackOp(\"/\", a, b)
    return type(b)==\"number\" and MockVector3.new(a.X/b, a.Y/b, a.Z/b) or MockVector3.new(a.X/b.X, a.Y/b.Y, a.Z/b.Z) 
end
MockVector3.__unm = function(a) 
    return MockVector3.new(-a.X, -a.Y, -a.Z) 
end
MockVector3.__eq  = function(a,b) 
    TrackOp(\"==\", a, b)
    return a.X==b.X and a.Y==b.Y and a.Z==b.Z 
end
MockVector3.zero = MockVector3.new(0,0,0)
MockVector3.one = MockVector3.new(1,1,1)

local MockVector2 = {__index={}}
function MockVector2.new(x,y)
    local m = math.sqrt((x or 0)^2 + (y or 0)^2)
    local u = (m == 0) and {X=0, Y=0} or {X=(x or 0)/m, Y=(y or 0)/m}
    u.__isVector2 = true
    return setmetatable({X=x or 0, Y=y or 0, __isVector2=true, Magnitude=m, Unit=setmetatable(u, MockVector2)}, MockVector2)
end
MockVector2.__add = function(a,b) 
    TrackOp(\"+\", a, b)
    return MockVector2.new(a.X+b.X, a.Y+b.Y) 
end
MockVector2.__sub = function(a,b) 
    TrackOp(\"-\", a, b)
    return MockVector2.new(a.X-b.X, a.Y-b.Y) 
end
MockVector2.__mul = function(a,b) 
    TrackOp(\"*\", a, b)
    return type(b)==\"number\" and MockVector2.new(a.X*b, a.Y*b) or MockVector2.new(a.X*b.X, a.Y*b.Y) 
end
MockVector2.__div = function(a,b) 
    TrackOp(\"/\", a, b)
    return type(b)==\"number\" and MockVector2.new(a.X/b, a.Y/b) or MockVector2.new(a.X/b.X, a.Y/b.Y) 
end
MockVector2.zero = MockVector2.new(0,0)

local MockColor3 = {__index={}}
function MockColor3.new(r,g,b) 
    return setmetatable({R=r or 0, G=g or 0, B=b or 0, __isColor3=true}, MockColor3) 
end
function MockColor3.fromRGB(r,g,b) 
    return MockColor3.new((r or 0)/255, (g or 0)/255, (b or 0)/255) 
end
function MockColor3.fromHex(hex) 
    return MockColor3.new(1,1,1) 
end
MockColor3.__add = function(a,b) 
    TrackOp(\"+\", a, b)
    return MockColor3.new(a.R+b.R, a.G+b.G, a.B+b.B) 
end
MockColor3.__sub = function(a,b) 
    TrackOp(\"-\", a, b)
    return MockColor3.new(a.R-b.R, a.G-b.G, a.B-b.B) 
end
MockColor3.__mul = function(a,b) 
    TrackOp(\"*\", a, b)
    return type(b)==\"number\" and MockColor3.new(a.R*b, a.G*b, a.B*b) or MockColor3.new(a.R*b.R, a.G*b.G, a.B*b.B) 
end
MockColor3.__div = function(a,b) 
    TrackOp(\"/\", a, b)
    return type(b)==\"number\" and MockColor3.new(a.R/b, a.G/b, a.B/b) or MockColor3.new(a.R/b.R, a.G/b.G, a.B/b.B) 
end

local MockUDim = {__index={}}
function MockUDim.new(s,o) 
    return setmetatable({Scale=s or 0, Offset=o or 0, __isUDim=true}, MockUDim) 
end
MockUDim.__add = function(a,b) 
    TrackOp(\"+\", a, b)
    return MockUDim.new(a.Scale+b.Scale, a.Offset+b.Offset) 
end
MockUDim.__sub = function(a,b) 
    TrackOp(\"-\", a, b)
    return MockUDim.new(a.Scale-b.Scale, a.Offset-b.Offset) 
end
MockUDim.__mul = function(a,b) 
    TrackOp(\"*\", a, b)
    return MockUDim.new(a.Scale*(tonumber(b) or 1), a.Offset*(tonumber(b) or 1)) 
end

local MockUDim2 = {__index={}}
function MockUDim2.new(xs,xo,ys,yo) 
    return setmetatable({X=MockUDim.new(xs,xo), Y=MockUDim.new(ys,yo), __isUDim2=true}, MockUDim2) 
end
function MockUDim2.fromScale(x,y) 
    return MockUDim2.new(x,0,y,0) 
end
function MockUDim2.fromOffset(x,y) 
    return MockUDim2.new(0,x,0,y) 
end
MockUDim2.__add = function(a,b) 
    TrackOp(\"+\", a, b)
    return MockUDim2.new(a.X.Scale+b.X.Scale, a.X.Offset+b.X.Offset, a.Y.Scale+b.Y.Scale, a.Y.Offset+b.Y.Offset) 
end
MockUDim2.__sub = function(a,b) 
    TrackOp(\"-\", a, b)
    return MockUDim2.new(a.X.Scale-b.X.Scale, a.X.Offset-b.X.Offset, a.Y.Scale-b.Y.Scale, a.Y.Offset-b.Y.Offset) 
end
MockUDim2.__mul = function(a,b) 
    TrackOp(\"*\", a, b)
    return MockUDim2.new(a.X.Scale*(tonumber(b) or 1), a.X.Offset*(tonumber(b) or 1), a.Y.Scale*(tonumber(b) or 1), a.Y.Offset*(tonumber(b) or 1)) 
end

local MockCFrame = {__index = {}}
setmetatable(MockCFrame, {
    __index = function(t,k) return rawget(t,k) end
})
function MockCFrame.new(...)
    local a = {...}
    local x,y,z = (a[1] or 0), (a[2] or 0), (a[3] or 0)
    if type(a[1]) == \"table\" and a[1].__isVector3 then
        x, y, z = a[1].X, a[1].Y, a[1].Z
    end
    local cf = setmetatable({X=x, Y=y, Z=z, __isCFrame=true, Position=MockVector3.new(x,y,z), LookVector=MockVector3.new(0,0,-1)}, MockCFrame)
    return cf
end
MockCFrame.__index = MockCFrame
function MockCFrame.__mul(a,b)
    TrackOp(\"*\", a, b)
    if type(b)==\"table\" and b.__isVector3 then 
        return MockVector3.new(a.X+b.X, a.Y+b.Y, a.Z+b.Z) 
    end
    if type(b)==\"table\" and b.__isCFrame then 
        return MockCFrame.new(a.X+b.X, a.Y+b.Y, a.Z+b.Z) 
    end
    return MockCFrame.new(a.X, a.Y, a.Z)
end
function MockCFrame.__add(a,b)
    TrackOp(\"+\", a, b)
    local ax, ay, az = a.X or 0, a.Y or 0, a.Z or 0
    local bx, by, bz = 0, 0, 0
    if type(b)==\"table\" then 
        bx, by, bz = b.X or 0, b.Y or 0, b.Z or 0 
    end
    return MockCFrame.new(ax+bx, ay+by, az+bz)
end
function MockCFrame.__sub(a,b)
    TrackOp(\"-\", a, b)
    local ax, ay, az = a.X or 0, a.Y or 0, a.Z or 0
    local bx, by, bz = 0, 0, 0
    if type(b)==\"table\" then 
        bx, by, bz = b.X or 0, b.Y or 0, b.Z or 0 
    end
    return MockCFrame.new(ax-bx, ay-by, az-bz)
end
function MockCFrame:Inverse() 
    return MockCFrame.new(-self.X, -self.Y, -self.Z) 
end
MockCFrame.identity = MockCFrame.new(0,0,0)
MockCFrame.Angles = function(rx,ry,rz) 
    return MockCFrame.new(0,0,0) 
end

local MockEnum = setmetatable({},{
    __index = function(_,key)
        return setmetatable({},{
            __index = function(_,c)
                return {__MOCK_ENUM=true, __enumString=\"Enum.\"..key..\".\"..c, Name=c, Value=0}
            end
        })
    end
})

local function MakeEnumItem(enumName, itemName)
    return {__MOCK_ENUM=true, __enumString=\"Enum.\"..enumName..\".\"..itemName, Name=itemName, Value=0}
end

local MockTweenInfo = {}
function MockTweenInfo.new(time,style,dir,rep,rev,delay)
    return {Time=time or 1, EasingStyle=style, EasingDirection=dir, __isTweenInfo=true}
end


------------------------------------------------------------------------
-- 10. HARDCODED NATIVE API DATABASE (REPLACES APIDUMP)
------------------------------------------------------------------------
-- Ini adalah pengganti apidump.json untuk memastikan alat ini 100% standalone
-- dengan akurasi objek Roblox yang tetap tinggi.
-- Setiap Class memiliki Properties, dan Methods default.

local NATIVE_API_DB = {
    [\"Instance\"] = {
        Properties = { Name = \"string\", ClassName = \"string\", Parent = \"Instance\" },
        Methods = { \"Clone\", \"Destroy\", \"ClearAllChildren\", \"GetChildren\", \"GetDescendants\", \"FindFirstChild\", \"WaitForChild\", \"IsA\", \"GetAttribute\", \"SetAttribute\" }
    },
    [\"BasePart\"] = {
        Super = \"Instance\",
        Properties = { Anchored = \"bool\", CanCollide = \"bool\", Transparency = \"number\", Color = \"Color3\", Size = \"Vector3\", Position = \"Vector3\", CFrame = \"CFrame\", Material = \"Enum.Material\" },
        Methods = { \"GetMass\", \"GetTouchingParts\", \"ApplyImpulse\", \"ApplyAngularImpulse\" }
    },
    [\"Part\"] = { Super = \"BasePart\", Properties = { Shape = \"Enum.PartType\" } },
    [\"MeshPart\"] = { Super = \"BasePart\", Properties = { MeshId = \"string\", TextureID = \"string\" } },
    [\"Model\"] = { Super = \"Instance\", Properties = { PrimaryPart = \"Instance\" }, Methods = { \"GetBoundingBox\", \"MoveTo\", \"SetPrimaryPartCFrame\", \"PivotTo\", \"BreakJoints\" } },
    [\"Folder\"] = { Super = \"Instance\" },
    [\"Configuration\"] = { Super = \"Instance\" },
    [\"Humanoid\"] = {
        Super = \"Instance\",
        Properties = { Health = \"number\", MaxHealth = \"number\", WalkSpeed = \"number\", JumpPower = \"number\", Sit = \"bool\", PlatformStand = \"bool\", AutoRotate = \"bool\" },
        Methods = { \"MoveTo\", \"TakeDamage\", \"ChangeState\", \"LoadAnimation\", \"GetPlayingAnimationTracks\", \"EquipTool\", \"UnequipTools\" }
    },
    [\"Player\"] = {
        Super = \"Instance\",
        Properties = { UserId = \"number\", Name = \"string\", DisplayName = \"string\", Character = \"Instance\", Team = \"Instance\", TeamColor = \"Color3\" },
        Methods = { \"Kick\", \"LoadCharacter\", \"GetJoinData\", \"GetMouse\" }
    },
    [\"GuiObject\"] = {
        Super = \"Instance\",
        Properties = { Active = \"bool\", AnchorPoint = \"Vector2\", BackgroundColor3 = \"Color3\", BackgroundTransparency = \"number\", Position = \"UDim2\", Size = \"UDim2\", Visible = \"bool\", ZIndex = \"number\", Rotation = \"number\" },
        Methods = { \"TweenSize\", \"TweenPosition\", \"TweenSizeAndPosition\" }
    },
    [\"Frame\"] = { Super = \"GuiObject\" },
    [\"ScrollingFrame\"] = { Super = \"GuiObject\", Properties = { CanvasPosition = \"Vector2\", CanvasSize = \"UDim2\", ScrollBarThickness = \"number\" } },
    [\"TextLabel\"] = { Super = \"GuiObject\", Properties = { Text = \"string\", TextColor3 = \"Color3\", TextSize = \"number\", TextTransparency = \"number\", TextXAlignment = \"Enum.TextXAlignment\", TextYAlignment = \"Enum.TextYAlignment\", Font = \"Enum.Font\" } },
    [\"TextButton\"] = { Super = \"TextLabel\", Properties = { AutoButtonColor = \"bool\" } },
    [\"TextBox\"] = { Super = \"TextLabel\", Properties = { ClearTextOnFocus = \"bool\", TextEditable = \"bool\", PlaceholderText = \"string\" }, Methods = { \"CaptureFocus\", \"ReleaseFocus\" } },
    [\"ImageLabel\"] = { Super = \"GuiObject\", Properties = { Image = \"string\", ImageColor3 = \"Color3\", ImageTransparency = \"number\" } },
    [\"ImageButton\"] = { Super = \"ImageLabel\", Properties = { HoverImage = \"string\", PressedImage = \"string\" } },
    [\"ScreenGui\"] = { Super = \"Instance\", Properties = { Enabled = \"bool\", IgnoreGuiInset = \"bool\", DisplayOrder = \"number\", ResetOnSpawn = \"bool\" } },
    [\"BillboardGui\"] = { Super = \"ScreenGui\", Properties = { Adornee = \"Instance\", ExtentsOffset = \"Vector3\", StudsOffset = \"Vector3\", Size = \"UDim2\", AlwaysOnTop = \"bool\" } },
    [\"SurfaceGui\"] = { Super = \"BillboardGui\", Properties = { Face = \"Enum.NormalId\", CanvasSize = \"Vector2\" } },
    [\"UILayout\"] = { Super = \"Instance\", Properties = {} },
    [\"UIListLayout\"] = { Super = \"UILayout\", Properties = { Padding = \"UDim\", FillDirection = \"Enum.FillDirection\", HorizontalAlignment = \"Enum.HorizontalAlignment\", VerticalAlignment = \"Enum.VerticalAlignment\" } },
    [\"UIGridLayout\"] = { Super = \"UILayout\", Properties = { CellPadding = \"UDim2\", CellSize = \"UDim2\", FillDirection = \"Enum.FillDirection\" } },
    [\"UICorner\"] = { Super = \"Instance\", Properties = { CornerRadius = \"UDim\" } },
    [\"UIPadding\"] = { Super = \"Instance\", Properties = { PaddingBottom = \"UDim\", PaddingTop = \"UDim\", PaddingLeft = \"UDim\", PaddingRight = \"UDim\" } },
    [\"UIStroke\"] = { Super = \"Instance\", Properties = { Color = \"Color3\", Thickness = \"number\", ApplyStrokeMode = \"Enum.ApplyStrokeMode\" } },
    [\"Tool\"] = { Super = \"Instance\", Properties = { RequiresHandle = \"bool\", CanBeDropped = \"bool\", ManualActivationOnly = \"bool\", Grip = \"CFrame\", ToolTip = \"string\" }, Methods = { \"Activate\", \"Deactivate\" } },
    [\"DataStore\"] = { Super = \"Instance\", Methods = { \"GetAsync\", \"SetAsync\", \"UpdateAsync\", \"IncrementAsync\", \"RemoveAsync\" } },
    [\"GlobalDataStore\"] = { Super = \"DataStore\" },
    [\"OrderedDataStore\"] = { Super = \"GlobalDataStore\", Methods = { \"GetSortedAsync\" } },
    [\"Camera\"] = { Super = \"Instance\", Properties = { CFrame = \"CFrame\", Focus = \"CFrame\", FieldOfView = \"number\", CameraType = \"Enum.CameraType\", CameraSubject = \"Instance\" } },
    [\"Animation\"] = { Super = \"Instance\", Properties = { AnimationId = \"string\" } },
    [\"AnimationTrack\"] = { Super = \"Instance\", Properties = { IsPlaying = \"bool\", Length = \"number\", Looped = \"bool\", Speed = \"number\", TimePosition = \"number\", WeightCurrent = \"number\", WeightTarget = \"number\" }, Methods = { \"Play\", \"Stop\", \"AdjustSpeed\", \"AdjustWeight\", \"GetMarkerReachedSignal\" } },
    [\"Sound\"] = { Super = \"Instance\", Properties = { SoundId = \"string\", IsLoaded = \"bool\", IsPlaying = \"bool\", IsPaused = \"bool\", Looped = \"bool\", PlaybackSpeed = \"number\", TimePosition = \"number\", Volume = \"number\", RollOffMode = \"Enum.RollOffMode\" }, Methods = { \"Play\", \"Pause\", \"Resume\", \"Stop\" } },
    [\"RayValue\"] = { Super = \"Instance\", Properties = { Value = \"Ray\" } },
    [\"Color3Value\"] = { Super = \"Instance\", Properties = { Value = \"Color3\" } },
    [\"Vector3Value\"] = { Super = \"Instance\", Properties = { Value = \"Vector3\" } },
    [\"StringValue\"] = { Super = \"Instance\", Properties = { Value = \"string\" } },
    [\"BoolValue\"] = { Super = \"Instance\", Properties = { Value = \"bool\" } },
    [\"NumberValue\"] = { Super = \"Instance\", Properties = { Value = \"number\" } },
    [\"ObjectValue\"] = { Super = \"Instance\", Properties = { Value = \"Instance\" } },
    [\"Tween\"] = { Super = \"Instance\", Properties = { PlaybackState = \"Enum.PlaybackState\" }, Methods = { \"Play\", \"Pause\", \"Cancel\" } },
    [\"ProximityPrompt\"] = { Super = \"Instance\", Properties = { ActionText = \"string\", ObjectText = \"string\", KeyboardKeyCode = \"Enum.KeyCode\", HoldDuration = \"number\", RequiresLineOfSight = \"bool\", MaxActivationDistance = \"number\", Enabled = \"bool\" } },
    [\"RemoteEvent\"] = { Super = \"Instance\", Methods = { \"FireServer\", \"FireClient\", \"FireAllClients\" } },
    [\"RemoteFunction\"] = { Super = \"Instance\", Methods = { \"InvokeServer\", \"InvokeClient\" } },
    [\"BindableEvent\"] = { Super = \"Instance\", Methods = { \"Fire\" } },
    [\"BindableFunction\"] = { Super = \"Instance\", Methods = { \"Invoke\" } },
    [\"TextChannel\"] = { Super = \"Instance\", Methods = { \"SendAsync\", \"DisplaySystemMessage\" } },
}

local function GetClassDefinition(className)
    local def = NATIVE_API_DB[className]
    if not def then
        -- Coba cari dengan menghapus \"Service\" atau \"Provider\"
        local baseName = className:gsub(\"Service$\", \"\"):gsub(\"Provider$\", \"\")
        def = NATIVE_API_DB[baseName]
    end
    return def
end

local function GetInheritedProperties(className)
    local props = {}
    local currentClass = className
    while currentClass do
        local def = NATIVE_API_DB[currentClass]
        if not def then break end
        if def.Properties then
            for k, v in pairs(def.Properties) do
                props[k] = v
            end
        end
        currentClass = def.Super
    end
    return props
end

local function GetInheritedMethods(className)
    local methods = {}
    local currentClass = className
    while currentClass do
        local def = NATIVE_API_DB[currentClass]
        if not def then break end
        if def.Methods then
            for _, m in ipairs(def.Methods) do
                methods[m] = true
            end
        end
        currentClass = def.Super
    end
    return methods
end

------------------------------------------------------------------------
-- 11. CALLBACK RUNNER & SIGNALS
------------------------------------------------------------------------

local function RunInCallback(fn, args, context)
    PushCallback()
    local ok, err = pcall(function()
        fn(table.unpack(args or {}))
    end)
    if not ok and not ShouldSuppressError(err) then
        ReportError(context or \"callback\", err)
    end
    local captured = PopCallback()
    return captured
end

local function ScanAndExecuteCallbacks(tbl)
    if type(tbl) ~= \"table\" then 
        return 
    end
    for k, v in pairs(tbl) do
        if type(v) == \"function\" and (Config.ExploreFuncs or tostring(k):lower():match(\"call\") or tostring(k):lower():match(\"change\")) then
            TrackGC(v)
            local captured = RunInCallback(v, {true}, tostring(k))
            local captured2 = RunInCallback(v, {false}, tostring(k))
            
            -- Ekstraksi Argumen Tambahan untuk ExploreFuncs yang lebih canggih
            local captured3 = RunInCallback(v, {CreateMockInstance(\"Player\", \"ExplorePlayer\", true)}, tostring(k))
            local captured4 = RunInCallback(v, {\"MockString\", 999}, tostring(k))

            local filtered = {}
            for _, cap in ipairs({captured, captured2, captured3, captured4}) do
                for _, line in ipairs(cap) do
                    if not line:match(\"^%s*%-%-\") then
                        filtered[#filtered+1] = line
                    end
                end
            end

            if #filtered == 0 and FEATURES.AST_DEAD_CODE_REVIVAL then
                local rawSource = ExtractSourceLines(v)
                if rawSource then
                    for line in rawSource:gmatch(\"[^\\r\\n]+\") do
                        filtered[#filtered+1] = line
                    end
                end
            end
            tbl[k] = {__isCallback = true, lines = filtered}
        elseif Config.ExploreFuncs and type(v) == \"table\" and not v.__MOCK_INSTANCE then
            ScanAndExecuteCallbacks(v)
        end
    end
end

local function createMockSignal(name, parent)
    local sig = {
        __connections = {},
        __name = name,
        __parent = parent
    }
    
    function sig:Connect(cb)
        if type(cb) ~= \"function\" then
            return {Connected = true, Disconnect = function() end}
        end        
        TrackGC(cb)
        local conn = {
            Connected = true,
            Disconnect = function(self)
                self.Connected = false
            end
        }
        table.insert(self.__connections, {callback = cb, connection = conn})
        
        local mockArgs = {}
        if name:match(\"Heartbeat\") or name:match(\"RenderStepped\") then
            mockArgs = {0.016}
        elseif name:match(\"Stepped\") then
            mockArgs = {0, 0.016}
        elseif name:match(\"ChildAdded\") or name:match(\"ChildRemoved\") then
            mockArgs = {CreateMockInstance(\"Instance\", \"child_mock\", true)}
        elseif name == \"Touched\" or name == \"TouchEnded\" then
            mockArgs = {CreateMockInstance(\"Part\", \"hitPart\", true)}
        elseif name:match(\"PromptTriggered\") then
            local promptInst = CreateMockInstance(\"ProximityPrompt\", \"prompt\", true)
            local playerInst = CreateMockInstance(\"Player\", \"player\", true)
            mockArgs = {promptInst, playerInst}
        elseif name == \"PlayerAdded\" or name == \"PlayerRemoving\" then
            local playerInst = CreateMockInstance(\"Player\", \"playerArg\", true)
            rawset(playerInst, \"UserId\", math.random(100000000, 999999999))
            rawset(playerInst, \"Name\", \"Player_\" .. tostring(math.random(1000, 9999)))
            mockArgs = {playerInst}
        elseif name:match(\"InputBegan\") or name:match(\"InputEnded\") then
            mockArgs = {
                {
                    KeyCode = MakeEnumItem(\"KeyCode\", \"W\"),
                    UserInputType = MakeEnumItem(\"UserInputType\", \"Keyboard\"),
                    Position = MockVector3.new(100, 100, 0),
                    Delta = MockVector3.new(0, 0, 0)
                },
                false
            }
        end
        
        local captured = RunInCallback(cb, mockArgs, name .. \":Connect\")
        
        if #captured == 0 and FEATURES.AST_DEAD_CODE_REVIVAL then
            local rawSource = ExtractSourceLines(cb)
            if rawSource then
                for line in rawSource:gmatch(\"[^\\r\\n]+\") do
                    captured[#captured+1] = line
                end
            end
        end
        
        local pv = GetVarName(parent) or (parent and parent.__name) or \"instance\"
        local params = \"...\"
        if name:match(\"Stepped\") then
            params = \"time, deltaTime\"
        elseif name:match(\"RenderStepped\") or name:match(\"Heartbeat\") then
            params = \"deltaTime\"
        elseif name == \"Touched\" then
            params = \"hit\"
        elseif name == \"PlayerAdded\" then
            params = \"player\"
        elseif name:match(\"Input\") then
            params = \"input, gameProcessed\"
        end
        
        if #captured > 0 then
            Emit(pv .. \".\" .. name .. \":Connect(function(\" .. params .. \")\")
            for _, line in ipairs(captured) do
                Emit(\" \" .. line)
            end
            Emit(\"end)\")
        else
            Emit(pv .. \".\" .. name .. \":Connect(function(\" .. params .. \") end)\")
        end
        return conn
    end
    
    function sig:Wait() 
        if self.__name:match(\"Stepped\") or self.__name:match(\"Heartbeat\") or self.__name:match(\"RenderStepped\") then 
            return 0.016 
        end
        return 
    end
    
    function sig:Once(cb) 
        return self:Connect(cb) 
    end
    
    return sig
end

------------------------------------------------------------------------
-- 12. MOCK INSTANCE CREATOR (USING NATIVE DB)
------------------------------------------------------------------------

CreateMockInstance = function(className, varName, skipLog)
    Security.CheckCallRate()
    TouchActivity()
    State.mockInstanceId = State.mockInstanceId + 1
    
    if not varName or varName == \"\" then
        varName = className .. \"_\" .. State.mockInstanceId
    end

    local classDef = GetClassDefinition(className)
    local inheritedProps = GetInheritedProperties(className)
    local inheritedMethods = GetInheritedMethods(className)

    local instance = {
        __MOCK_INSTANCE = true,
        __className = className,
        __name = varName,
        __children = {},
        __parent = nil,
        __props = {},
        __signals = {},
        ClassName = className,
        Name = varName,
    }

    State.instanceVarNames[instance] = varName
    TrackGC(instance)

    local signalNames = {
        \"MouseButton1Click\", \"MouseButton1Down\", \"MouseButton1Up\",
        \"MouseEnter\", \"MouseLeave\", \"Changed\", \"ChildAdded\",
        \"ChildRemoved\", \"DescendantAdded\", \"DescendantRemoving\",
        \"Touched\", \"TouchEnded\", \"Heartbeat\", \"RenderStepped\",
        \"Stepped\", \"Completed\", \"PlayerAdded\", \"PlayerRemoving\",
        \"CharacterAdded\", \"CharacterRemoving\", \"PromptTriggered\",
        \"Activated\", \"AncestryChanged\", \"AttributeChanged\"
    }

    for _, sn in ipairs(signalNames) do
        instance.__signals[sn] = createMockSignal(sn, instance)
    end

    local methods = {}
    
    -- Assign Native Methods
    for funcName, _ in pairs(inheritedMethods) do
        methods[funcName] = function(self, ...)
            local args = {...}
            local vn = GetVarName(self) or self.__name or \"instance\"
            local paramStr = SerializeArgs(args)
            Emit(vn .. \":\" .. funcName .. \"(\" .. paramStr .. \")\")
            return CreateMockInstance(\"Instance\", \"ret_\" .. funcName, true)
        end
    end

    -- Assign Default Mandatory Methods
    local defaultMethods = {
        Clone = function(self)
            local nv = (GetVarName(self) or self.__name) .. \"_clone\"
            local typeStr = Config.TypeAnnotations and (\": \" .. className) or \"\"
            Emit(\"local \" .. nv .. typeStr .. \" = \" .. (GetVarName(self) or \"instance\") .. \":Clone()\")
            return CreateMockInstance(self.__className, nv, true)
        end,
        Destroy = function(self)
            Emit((GetVarName(self) or \"instance\") .. \":Destroy()\")
        end,
        Remove = function(self)
            Emit((GetVarName(self) or \"instance\") .. \":Remove()\")
        end,
        IsA = function(self, cn)
            if State.callbackDepth > 0 then return true end
            if self.__className == cn or cn == \"Instance\" then return true end
            local current = className
            while current do
                local def = NATIVE_API_DB[current]
                if not def then break end
                if current == cn then return true end
                current = def.Super
            end
            return false
        end,
        WaitForChild = function(self, name, timeout)
            local nv = tostring(name):gsub(\"[^%w_]\", \"_\")
            local cacheKey = (GetVarName(self) or \"Inst\") .. \"_\" .. nv
            if State.replicatedCache[cacheKey] then
                return State.replicatedCache[cacheKey]
            end
            for inst, vn in pairs(State.instanceVarNames) do
                if vn == nv and type(inst) == \"table\" and inst.__MOCK_INSTANCE then
                    return inst
                end
            end
            local ci = CreateMockInstance(\"Instance\", nv, true)
            local timeStr = timeout and (\", \" .. tostring(timeout)) or \"\"
            local typeStr = Config.TypeAnnotations and \": Instance\" or \"\"
            Emit(\"local \" .. nv .. typeStr .. \" = \" .. (GetVarName(self) or \"instance\") .. ':WaitForChild(\"' .. tostring(name) .. '\"' .. timeStr .. ')')
            State.replicatedCache[cacheKey] = ci
            return ci
        end,
        FindFirstChild = function(self, name, rec)
            local nv = tostring(name):gsub(\"[^%w_]\", \"_\")
            for inst, vn in pairs(State.instanceVarNames) do
                if vn == nv and type(inst) == \"table\" and inst.__MOCK_INSTANCE then
                    return inst
                end
            end
            local ci = CreateMockInstance(\"Instance\", nv, true)
            local typeStr = Config.TypeAnnotations and \": Instance\" or \"\"
            Emit(\"local \" .. nv .. typeStr .. \" = \" .. (GetVarName(self) or \"instance\") .. ':FindFirstChild(\"' .. tostring(name) .. '\")')
            return ci
        end,
        GetChildren = function(self)
            local r = {}
            for _, c in pairs(instance.__children) do
                r[#r + 1] = c
            end
            return r
        end,
        GetDescendants = function(self)
            local r = {}
            local function g(inst)
                for _, c in pairs(inst.__children or {}) do
                    r[#r + 1] = c
                    g(c)
                end
            end
            g(instance)
            return r
        end,
        GetPropertyChangedSignal = function(self, prop)
            local sn = prop .. \"Changed\"
            if not instance.__signals[sn] then
                instance.__signals[sn] = createMockSignal(sn, instance)
            end
            return instance.__signals[sn]
        end,
        GetFullName = function(self)
            return GetVarName(self) or self.__name or self.__className
        end
    }

    for k, v in pairs(defaultMethods) do
        if not methods[k] then
            methods[k] = v
        end
    end

    -- Setup Initial Properties based on Native DB
    local DEFAULT_PROPS = {
        Text = \"\", Value = 0, Enabled = true, Visible = true, Active = true,
        Transparency = 0, BackgroundTransparency = 0, TimePosition = 0,
        CFrame = MockCFrame.new(), Position = MockVector3.new(0,0,0),
        Size = MockVector3.new(1,1,1), Color = MockColor3.new(),
        Name = varName, ClassName = className
    }

    for propName, valueType in pairs(inheritedProps) do
        if valueType == \"string\" then DEFAULT_PROPS[propName] = \"Mock_\" .. propName
        elseif valueType == \"bool\" then DEFAULT_PROPS[propName] = true
        elseif valueType == \"number\" then DEFAULT_PROPS[propName] = 0
        elseif valueType == \"Vector3\" then DEFAULT_PROPS[propName] = MockVector3.new(0, 0, 0)
        elseif valueType == \"Vector2\" then DEFAULT_PROPS[propName] = MockVector2.new(0, 0)
        elseif valueType == \"CFrame\" then DEFAULT_PROPS[propName] = MockCFrame.new()
        elseif valueType == \"Color3\" then DEFAULT_PROPS[propName] = MockColor3.new()
        elseif valueType == \"UDim2\" then DEFAULT_PROPS[propName] = MockUDim2.new(0, 0, 0, 0)
        elseif valueType == \"UDim\" then DEFAULT_PROPS[propName] = MockUDim.new(0, 0)
        elseif valueType:match(\"^Enum%.\") then 
            local enumName = valueType:gsub(\"Enum%.\", \"\")
            DEFAULT_PROPS[propName] = MakeEnumItem(enumName, \"Default\")
        end
    end

    local mt = {
        __index = function(t, key)
            local rv = rawget(t, key)
            if rv ~= nil then 
                return rv 
            end
            if methods[key] then 
                return methods[key] 
            end
            if instance.__signals[key] then 
                return instance.__signals[key] 
            end
            local p = rawget(t, \"__props\")
            if p and p[key] ~= nil then 
                return p[key] 
            end
            if DEFAULT_PROPS[key] ~= nil then 
                return DEFAULT_PROPS[key] 
            end

            -- Jika properti dideklarasikan di Database
            if inheritedProps[key] then
                local vn = GetVarName(t) or t.__name or \"instance\"
                local proxyVar = vn .. \"_\" .. tostring(key)
                local fallbackInst = CreateMockInstance(\"Instance\", proxyVar, true)
                State.instanceVarNames[fallbackInst] = nil
                fallbackInst.__implicitPath = vn .. \".\" .. key
                return fallbackInst
            end

            -- Fallback
            local vn = GetVarName(t) or t.__name or \"instance\"
            local proxyVar = vn .. \"_\" .. tostring(key)
            local fallbackInst = CreateMockInstance(\"Instance\", proxyVar, true)
            State.instanceVarNames[fallbackInst] = nil
            local safeKey = \"\"
            if type(key) == \"string\" and key:match(\"^[%a_][%w_]*$\") then
                safeKey = \".\" .. key
            else
                safeKey = '[\"' .. tostring(key) .. '\"]'
            end
            fallbackInst.__implicitPath = vn .. safeKey
            getmetatable(fallbackInst).__call = function(self, ...)
                local args = {...}
                if args[1] == t then 
                    table.remove(args, 1) 
                end
                Emit(vn .. \":\" .. key .. \"(\" .. SerializeArgs(args) .. \")\")
                return fallbackInst
            end
            
            if not p then
                p = {}
                rawset(t, \"__props\", p)
            end
            p[key] = fallbackInst
            return fallbackInst
        end,
        
        __newindex = function(t, key, value)
            if tostring(key):sub(1, 2) == \"__\" then
                rawset(t, key, value)
                return
            end
            if key == \"Parent\" then
                rawset(t, key, value)
                rawset(t, \"__parent\", value)
                if value and type(value) == \"table\" then
                    if value.__children then
                        table.insert(value.__children, t)
                    end
                end
                if not State.internalSetup then
                    local vn = GetVarName(t) or t.__implicitPath or t.__name
                    local parentVar = GetVarName(value)
                    if value then
                        Emit(vn .. \".Parent = \" .. (parentVar or SerializeValue(value)))
                    else
                        Emit(vn .. \".Parent = nil\")
                    end
                end
            elseif key == \"Name\" then
                rawset(t, key, value)
                if not State.internalSetup then
                    local vn = GetVarName(t) or t.__implicitPath or t.__name
                    Emit(vn .. '.Name = \"' .. tostring(value) .. '\"')
                end
            else
                local p = rawget(t, \"__props\")
                if not p then
                    p = {}
                    rawset(t, \"__props\", p)
                end
                p[key] = value
                if not State.internalSetup then
                    local vn = GetVarName(t) or t.__implicitPath or t.__name
                    Emit(vn .. \".\" .. key .. \" = \" .. SerializeValue(value))
                end
            end
        end,
        
        __tostring = function(t)
            return GetVarName(t) or t.__name or t.__className
        end
    }

    if Config.HookOp then
        mt.__eq = function(a, b) 
            TrackOp(\"==\", a, b)
            return rawequal(a,b) 
        end
        mt.__lt = function(a, b) 
            TrackOp(\"<\", a, b)
            return false 
        end
        mt.__le = function(a, b) 
            TrackOp(\"<=\", a, b)
            return false 
        end
        mt.__add = function(a, b) 
            TrackOp(\"+\", a, b)
            return a 
        end
        mt.__sub = function(a, b) 
            TrackOp(\"-\", a, b)
            return a 
        end
        mt.__mul = function(a, b) 
            TrackOp(\"*\", a, b)
            return a 
        end
        mt.__div = function(a, b) 
            TrackOp(\"/\", a, b)
            return a 
        end
    end

    setmetatable(instance, mt)
    return instance
end

------------------------------------------------------------------------
-- 13. MOCK SERVICES
------------------------------------------------------------------------

local function CreateMockService(serviceName, varName)
    State.internalSetup = true
    local service = CreateMockInstance(serviceName, varName, true)

    if serviceName == \"Players\" then
        local player = CreateMockInstance(\"Player\", \"LocalPlayer\", true)
        local character = CreateMockInstance(\"Model\", \"Character\", true)
        local hrp = CreateMockInstance(\"Part\", \"HumanoidRootPart\", true)
        local humanoid = CreateMockInstance(\"Humanoid\", \"Humanoid\", true)
        
        rawset(hrp, \"CFrame\", MockCFrame.new(0, 5, 0))
        rawset(hrp, \"Position\", MockVector3.new(0, 5, 0))
        rawset(character, \"HumanoidRootPart\", hrp)
        rawset(character, \"Humanoid\", humanoid)
        rawset(player, \"Character\", character)
        rawset(player, \"UserId\", math.random(10000000, 99999999))
        rawset(player, \"Name\", \"Player_\" .. tostring(math.random(100, 999)))
        rawset(player, \"DisplayName\", rawget(player, \"Name\"))
        rawset(player, \"Team\", nil)
        rawset(player, \"Kick\", function(self, msg)
            Emit((GetVarName(self) or \"LocalPlayer\") .. ':Kick(\"' .. tostring(msg or \"\") .. '\")')
        end)
        
        rawset(service, \"LocalPlayer\", player)
        rawset(service, \"GetPlayers\", function() 
            return {player} 
        end)
        
        State.instanceVarNames[player] = \"LocalPlayer\"
        State.instanceVarNames[character] = \"Character\"
        State.instanceVarNames[hrp] = \"HumanoidRootPart\"

    elseif serviceName == \"DataStoreService\" then
        rawset(service, \"GetDataStore\", function(self, name)
            if not State.dataStores[name] then
                local ds = CreateMockInstance(\"GlobalDataStore\", \"DataStore_\" .. name, true)
                local memoryDb = {}
                rawset(ds, \"GetAsync\", function(s, k)
                    Emit(\"DataStore:GetAsync(\" .. SerializeValue(k) .. \")\")
                    return memoryDb[k]
                end)
                rawset(ds, \"SetAsync\", function(s, k, v)
                    Emit(\"DataStore:SetAsync(\" .. SerializeValue(k) .. \", \" .. SerializeValue(v) .. \")\")
                    memoryDb[k] = v
                end)
                rawset(ds, \"UpdateAsync\", function(s, k, func)
                    Emit(\"DataStore:UpdateAsync(\" .. SerializeValue(k) .. \", function(...) end)\")
                    if type(func) == \"function\" then
                        local newVal = RunInCallback(func, {memoryDb[k]}, \"DataStore Update\")
                        memoryDb[k] = newVal
                    end
                end)
                State.dataStores[name] = ds
            end
            return State.dataStores[name]
        end)

    elseif serviceName == \"MarketplaceService\" then
        rawset(service, \"UserOwnsGamePassAsync\", function()
            Emit(\"MarketplaceService:UserOwnsGamePassAsync(...)\")
            return true
        end)
        rawset(service, \"PlayerOwnsAsset\", function()
            Emit(\"MarketplaceService:PlayerOwnsAsset(...)\")
            return true
        end)
        rawset(service, \"PromptGamePassPurchase\", function(s, p, id)
            Emit(\"MarketplaceService:PromptGamePassPurchase(...)\")
        end)
        rawset(service, \"PromptPurchase\", function(s, p, id)
            Emit(\"MarketplaceService:PromptPurchase(...)\")
        end)

    elseif serviceName == \"UserInputService\" then
        rawset(service, \"IsKeyDown\", function(self, keycode)
            local ks = tostring(keycode)
            if ks:match(\"W\") or ks:match(\"A\") or ks:match(\"S\") or ks:match(\"D\") then
                return true
            end
            return false
        end)
        rawset(service, \"GetMouseLocation\", function()
            return MockVector2.new(960, 540)
        end)
        rawset(service, \"MouseEnabled\", true)
        rawset(service, \"KeyboardEnabled\", true)

    elseif serviceName == \"PathfindingService\" then
        rawset(service, \"CreatePath\", function()
            local path = CreateMockInstance(\"Path\", \"PathObj\", true)
            rawset(path, \"Status\", MakeEnumItem(\"PathStatus\", \"Success\"))
            rawset(path, \"ComputeAsync\", function(s, start, goal)
                Emit(\"PathObj:ComputeAsync(\" .. SerializeValue(start) .. \", \" .. SerializeValue(goal) .. \")\")
            end)
            rawset(path, \"GetWaypoints\", function()
                return {
                    {Position = MockVector3.new(10, 0, 10), Action = MakeEnumItem(\"PathWaypointAction\", \"Walk\")},
                    {Position = MockVector3.new(20, 0, 20), Action = MakeEnumItem(\"PathWaypointAction\", \"Jump\")},
                    {Position = MockVector3.new(30, 0, 30), Action = MakeEnumItem(\"PathWaypointAction\", \"Walk\")}
                }
            end)
            return path
        end)

    elseif serviceName == \"TextChatService\" then
        local channels = CreateMockInstance(\"Folder\", \"TextChannels\", true)
        local general = CreateMockInstance(\"TextChannel\", \"RBXGeneral\", true)
        rawset(general, \"SendAsync\", function(s, msg)
            Emit('RBXGeneral:SendAsync(' .. SerializeValue(msg) .. ')')
        end)
        rawset(channels, \"RBXGeneral\", general)
        rawset(service, \"TextChannels\", channels)
        rawset(service, \"MessageReceived\", createMockSignal(\"MessageReceived\", service))

    elseif serviceName == \"Workspace\" then
        local cam = CreateMockInstance(\"Camera\", \"CurrentCamera\", true)
        rawset(cam, \"CFrame\", MockCFrame.new(0, 10, 0))
        rawset(service, \"CurrentCamera\", cam)
        rawset(service, \"Raycast\", function(self, origin, dir, params)
            Emit(\"workspace:Raycast(\" .. SerializeValue(origin) .. \", \" .. SerializeValue(dir) .. \")\")
            if dir and dir.Y and dir.Y < -5 then
                local hit = CreateMockInstance(\"Part\", \"SimulatedFloor\", true)
                return {
                    Instance = hit,
                    Position = MockVector3.new(origin.X, 0, origin.Z),
                    Material = MakeEnumItem(\"Material\", \"Plastic\"),
                    Normal = MockVector3.new(0, 1, 0)
                }
            end
            return nil
        end)
        rawset(service, \"FindPartOnRay\", function(self, r)
            Emit(\"workspace:FindPartOnRay(...)\")
            return nil, MockVector3.new(0, 0, 0), MockVector3.new(0, 1, 0)
        end)

    elseif serviceName == \"TweenService\" then
        rawset(service, \"Create\", function(self, inst, ti, props)
            local tw = CreateMockInstance(\"Tween\", \"TweenObj\", true)
            rawset(tw, \"PlaybackState\", MakeEnumItem(\"PlaybackState\", \"Begin\"))
            rawset(tw, \"Play\", function(self2)
                Emit((GetVarName(self2) or \"TweenObj\") .. \":Play()\")
                if tw.__signals and tw.__signals[\"Completed\"] then
                    for _, conn in ipairs(tw.__signals[\"Completed\"].__connections) do
                        if conn.callback then
                            pcall(conn.callback, MakeEnumItem(\"PlaybackState\", \"Completed\"))
                        end
                    end
                end
            end)
            local typeStr = Config.TypeAnnotations and \": Tween\" or \"\"
            Emit(\"local TweenObj\" .. typeStr .. \" = TweenService:Create(\" .. (GetVarName(inst) or \"Inst\") .. \", \" .. SerializeValue(ti) .. \", \" .. SerializeValue(props) .. \")\")
            return tw
        end)

    elseif serviceName == \"HttpService\" then
        rawset(service, \"JSONEncode\", function(self, t)
            return jsonEncode(t)
        end)
        rawset(service, \"JSONDecode\", function(self, s)
            return jsonDecode(s)
        end)
        rawset(service, \"GenerateGUID\", function()
            return \"xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx\"
        end)
        rawset(service, \"GetAsync\", function(self, url)
            Emit('HttpService:GetAsync(\"' .. tostring(url) .. '\")')
            return \"{}\"
        end)
        
    elseif serviceName == \"RunService\" then
        rawset(service, \"Heartbeat\", createMockSignal(\"Heartbeat\", service))
        rawset(service, \"RenderStepped\", createMockSignal(\"RenderStepped\", service))
        rawset(service, \"Stepped\", createMockSignal(\"Stepped\", service))
    end

    State.internalSetup = false
    return service
end

------------------------------------------------------------------------
-- 14. GAME GLOBAL (DataModel Proxy)
------------------------------------------------------------------------

local MockGameGlobal = {
    __services = {},
    PlaceId = 83369512629707,
    GameId = 83369512629707,
    JobId = \"MockedJobId\"
}

function MockGameGlobal:GetService(sn)
    if sn == \"RbxAnalyticsService\" then sn = \"AnalyticsService\" end
    if not self.__services[sn] then
        self.__services[sn] = CreateMockService(sn, sn)
        if sn ~= \"Workspace\" and not Config.SpyExecOnly then
            local typeStr = Config.TypeAnnotations and (\": \" .. sn) or \"\"
            Emit('local ' .. sn .. typeStr .. ' = game:GetService(\"' .. sn .. '\")')
        end
    end
    return self.__services[sn]
end

function MockGameGlobal:HttpGet(url)
    Emit(\"-- [Korvahub] Intercepted HttpGet: \" .. tostring(url))
    local mock = { __isString = true, __value = \"\", __url = url }
    return mock
end

function MockGameGlobal:IsLoaded()
    Emit(\"game:IsLoaded()\")
    return true
end

setmetatable(MockGameGlobal, {
    __index = function(t, k)
        if k == \"GetService\" then
            return function(self, sn) return MockGameGlobal:GetService(sn) end
        end
        if k == \"HttpGet\" then
            return function(self, url) return MockGameGlobal:HttpGet(url) end
        end
        if k == \"IsLoaded\" then
            return function(self) return MockGameGlobal:IsLoaded() end
        end
        local maps = {
            Workspace = \"Workspace\",
            workspace = \"Workspace\",
            Players = \"Players\",
            Lighting = \"Lighting\",
            ReplicatedStorage = \"ReplicatedStorage\",
            CoreGui = \"CoreGui\",
            RunService = \"RunService\",
            TweenService = \"TweenService\"
        }
        if maps[k] then
            return MockGameGlobal:GetService(maps[k])
        end
        return rawget(t, k)
    end,
    __newindex = function(t, k, v)
        rawset(t, k, v)
    end
})

------------------------------------------------------------------------
-- 15. MOCK UI LIBRARIES
------------------------------------------------------------------------

local function CreateMockLibrary(libName, parentVarName)
    if State.customLibraries[libName] then
        return State.customLibraries[libName]
    end
    
    local lib = setmetatable({},{
        __index = function(t, method)
            local function handleWindow(s, ...)
                local args = {...}
                ScanAndExecuteCallbacks(args)
                State.libraryCounter = State.libraryCounter + 1
                local wv = \"Window_\" .. State.libraryCounter
                if args[1] and type(args[1]) == \"table\" and args[1].Name then
                    wv = \"Window_\" .. tostring(args[1].Name):gsub(\"[^%w_]\", \"\")
                end
                local optsStr = #args > 0 and SerializeValue(args[1]) or \"\"
                Emit(\"local \" .. wv .. \" = \" .. (parentVarName or libName) .. \":\" .. method .. \"(\" .. optsStr .. \")\")
                local win = CreateMockLibrary(wv .. \"_Obj\", wv)
                State.libraryVarNames[win] = wv
                rawset(win, \"Notify\", function(s, o)
                    Emit(wv .. \":Notify(\" .. SerializeValue(o) .. \")\")
                end)
                rawset(win, \"Destroy\", function(s)
                    Emit(wv .. \":Destroy()\")
                end)
                rawset(win, \"SetTheme\", function(s, o)
                    Emit(wv .. \":SetTheme(\" .. SerializeValue(o) .. \")\")
                end)
                return win
            end
            
            if method == \"CreateWindow\" or method == \"MakeWindow\" or method == \"Init\" or method == \"Window\" then
                return handleWindow
            end
            
            if method == \"RefreshTheme\" or method == \"SetTheme\" or method == \"ConfigurationSaving\" then
                return function(s, ...)
                    Emit((parentVarName or libName) .. \":\" .. method .. \"(\" .. SerializeArgs({...}) .. \")\")
                    return t
                end
            end
            
            return function(s, ...)
                local args = {...}
                ScanAndExecuteCallbacks(args)
                State.libraryCounter = State.libraryCounter + 1
                local retName = (parentVarName or libName) .. \"_\" .. method .. \"_\" .. State.libraryCounter
                local basePrefix = \"\"
                
                if method:match(\"Tab\") then basePrefix = \"Tab\"
                elseif method:match(\"Section\") then basePrefix = \"Section\"
                elseif method:match(\"Button\") then basePrefix = \"Button\"
                elseif method:match(\"Toggle\") then basePrefix = \"Toggle\"
                elseif method:match(\"Slider\") then basePrefix = \"Slider\"
                elseif method:match(\"Dropdown\") then basePrefix = \"Dropdown\"
                elseif method:match(\"Label\") then basePrefix = \"Label\"
                elseif method:match(\"Input\") then basePrefix = \"Input\"
                end
                
                if basePrefix ~= \"\" then
                    local extractName = \"\"
                    if args[1] and type(args[1]) == \"table\" and args[1].Name then
                        extractName = args[1].Name
                    elseif type(args[1]) == \"string\" then
                        extractName = args[1]
                    end
                    if extractName ~= \"\" then
                        retName = basePrefix .. \"_\" .. tostring(extractName):gsub(\"[^%w_]\", \"\")
                    else
                        retName = basePrefix .. \"_\" .. State.libraryCounter
                    end
                end
                
                if State.declaredVars[retName] then
                    retName = retName .. \"_\" .. State.libraryCounter
                end
                Emit(\"local \" .. retName .. \" = \" .. (parentVarName or libName) .. \":\" .. method .. \"(\" .. SerializeArgs(args) .. \")\")
                State.declaredVars[retName] = true
                local methodMock = CreateMockLibrary(retName, retName)
                State.libraryVarNames[methodMock] = retName
                return methodMock
            end
        end,
        __call = function(t, ...)
            return t
        end
    })
    
    rawset(lib, \"__MOCK_LIBRARY\", true)
    rawset(lib, \"__libName\", libName)
    State.customLibraries[libName] = lib
    return lib
end

------------------------------------------------------------------------
-- 16. GLOBAL ENVIRONMENT & EXPLOIT BYPASSES
------------------------------------------------------------------------

local function CreateEnvProxy(name, targetEnv)
    local proxy = {}
    setmetatable(proxy, {
        __index = targetEnv,
        __newindex = function(t, k, v)
            if not State.internalSetup then
                local safeKey = type(k) == \"string\" and k:match(\"^[%a_][%w_]*$\") and (\".\" .. k) or (\"[\" .. SerializeValue(k, 0) .. \"]\")
                Emit(name .. safeKey .. \" = \" .. SerializeValue(v, 0))
            end
            rawset(targetEnv, k, v)
        end
    })
    return proxy
end

local function CreateMockEnvironment()
    local env = {}
    
    env.game = MockGameGlobal
    env.Game = MockGameGlobal
    env.workspace = MockGameGlobal:GetService(\"Workspace\")
    env.Workspace = env.workspace
    env.Players = MockGameGlobal:GetService(\"Players\")
    
    local lp = rawget(env.Players, \"LocalPlayer\")
    env.LocalPlayer = lp
    env.Character = rawget(lp, \"Character\")
    env.HumanoidRootPart = rawget(env.Character, \"HumanoidRootPart\")
    
    -- Types
    env.Vector3 = MockVector3
    env.Vector2 = MockVector2
    env.Color3 = MockColor3
    env.CFrame = MockCFrame
    env.UDim2 = MockUDim2
    env.UDim = MockUDim
    env.Enum = MockEnum
    env.TweenInfo = MockTweenInfo
    
    env.Instance = {
        new = function(className, parent)
            local inst = CreateMockInstance(className, className .. \"_\" .. State.mockInstanceId, false)
            local pStr = parent and (\", \" .. (GetVarName(parent) or SerializeValue(parent))) or \"\"
            local typeStr = Config.TypeAnnotations and (\": \" .. className) or \"\"
            Emit(\"local \" .. GetVarName(inst) .. typeStr .. \" = Instance.new(\\\"\" .. className .. \"\\\"\" .. pStr .. \")\")
            if parent then
                rawset(inst, \"Parent\", parent)
            end
            return inst
        end
    }
    
    -- Lua Base Functions
    env.math = math
    env.string = string
    env.table = table
    env.os = os
    env.coroutine = coroutine
    env.bit32 = Bit32Shim
    env.bit = Bit32Shim
    
    env.print = function(...)
        Emit(\"print(\" .. SerializeArgs({...}) .. \")\")
    end
    
    env.warn = function(...)
        Emit(\"warn(\" .. SerializeArgs({...}) .. \")\")
    end
    
    env.error = error
    env.pcall = pcall
    env.xpcall = xpcall
    env.setmetatable = setmetatable
    env.getmetatable = getmetatable
    env.type = type
    
    env.typeof = function(v)
        if type(v) == \"table\" and v.__MOCK_INSTANCE then
            return \"Instance\"
        end
        return type(v)
    end
    
    env.tostring = tostring
    env.tonumber = tonumber
    env.pairs = pairs
    env.ipairs = ipairs
    env.next = next
    env.unpack = table.unpack or unpack
    
    env.require = function(m)
        Emit(\"require(\" .. tostring(m) .. \")\")
        return CreateMockLibrary(\"RequiredModule\")
    end
    
    -- Task Scheduler
    env.task = {
        wait = function(t)
            CheckTimeout()
            TouchActivity()
            Emit(\"task.wait(\" .. (t and tostring(t) or \"\") .. \")\")
            return t or 0
        end,
        spawn = function(f, ...)
            local cap = RunInCallback(f, {...}, \"task.spawn\")
            if #cap > 0 then
                Emit(\"task.spawn(function()\\n \" .. table.concat(cap, \"\\n \") .. \"\\n end)\")
            else
                Emit(\"task.spawn(function() end)\")
            end
        end,
        defer = function(f, ...)
            Emit(\"task.defer(function() ... end)\")
        end,
        delay = function(t, f, ...)
            Emit(\"task.delay(\" .. tostring(t) .. \", function() ... end)\")
        end
    }
    
    env.wait = env.task.wait
    env.spawn = env.task.spawn
    env.delay = env.task.delay
    
    -- UI Libraries
    for _, lib in ipairs({\"Rayfield\", \"Fluent\", \"OrionLib\", \"MacLib\", \"WindUI\", \"Kavo\", \"Venyx\", \"Linoria\"}) do
        env[lib] = CreateMockLibrary(lib)
    end
    
    -- Debug / Anti-Logger Bypass
    env.debug = {
        traceback = function() return \"\" end,
        getinfo = function(...)
            return {source=\"=Korvahub\", short_src=\"Korvahub\", name=\"intercepted\", currentline=1}
        end,
        getupvalue = function() return nil end,
        setupvalue = function() end,
        getregistry = function() return GC_POOL end,
        setmetatable = setmetatable,
        getmetatable = getmetatable
    }
    
    env.getgenv = function()
        if not env.__genv then env.__genv = CreateEnvProxy(\"genv\", env) end
        return env.__genv
    end
    
    env.getfenv = function()
        if not env.__fenv then env.__fenv = CreateEnvProxy(\"fenv\", env) end
        return env.__fenv
    end
    
    env._G = CreateEnvProxy(\"env\", env)
    env.getrenv = function() return env end
    env.gethui = function() return MockGameGlobal:GetService(\"CoreGui\") end
    
    -- Networking
    env.request = function(o)
        Emit(\"request(\" .. SerializeValue(o) .. \")\")
        return {Body='{\"success\":true}', StatusCode=200, Headers={}, Success=true}
    end
    env.http_request = env.request
    
    env.WebSocket = { 
        connect = function(url) 
            Emit(\"WebSocket.connect(\" .. tostring(url) .. \")\")
            return {Send=function()end, Close=function()end} 
        end 
    }
    
    -- Clipboard & File System
    env.setclipboard = function(t) 
        Emit(\"setclipboard(\" .. SerializeValue(t) .. \")\") 
    end
    
    env.writefile = function(n, d) 
        Emit('writefile(\"'..tostring(n)..'\", ...)') 
    end
    
    env.readfile = function(n) 
        Emit('readfile(\"'..tostring(n)..'\")')
        return \"\" 
    end
    
    env.isfile = function(n) return false end
    env.isfolder = function() return false end
    env.makefolder = function() end

    -- Executor Identity
    env.identifyexecutor = function() 
        return \"Korvahub\", \"V0.8.4\" 
    end
    
    -- Closures & Functions
    env.hookfunction = function(a, b) return a end
    env.hookmetamethod = function(a, b, c) return c end
    env.cloneref = function(i) return i end
    env.checkcaller = function() return true end
    env.islclosure = function() return true end
    env.newcclosure = function(f) return f end

    -- Crypt & Cache
    env.crypt = {
        base64encode = function(s) return \"YmFzZTY0\" end,
        base64decode = function(s) return \"base64\" end,
        encrypt = function() return \"enc\", \"iv\" end,
        decrypt = function() return \"dec\" end,
        hash = function() return \"hash\" end,
        custom = { encrypt = function() return \"\" end, decrypt = function() return \"\" end }
    }
    env.base64 = env.crypt
    env.cache = {
        invalidate = function() end,
        iscached = function() return false end,
        replace = function() end
    }
    env.Drawing = {
        new = function(t) return CreateMockInstance(\"Drawing\", \"Drawing_\"..t) end,
        Fonts = { UI = 0, System = 1, Plex = 2, Monospace = 3 }
    }

    env.loadstring = function(src)
        if type(src) == \"table\" and src.__url then
            return function()
                Emit('local Loaded_Module = loadstring(game:HttpGet(\"' .. src.__url .. '\"))()')
                return CreateMockLibrary(\"Loaded_Module\", \"Loaded_Module\")
            end
        end
        local fn, err = loadstring(src)
        if fn then
            setfenv(fn, env)
            return fn
        end
        return nil, err
    end
    
    -- Raw Functions
    env.rawget = rawget
    env.rawset = rawset
    env.rawequal = rawequal

    -- Exploit Bypasses (BypassAntiEnv)
    if Config.BypassAntiEnv then
        env.iscclosure = function(f) return true end
        env.isourclosure = function() return true end
        env.isexecutorclosure = function() return true end
        env.is_synapse_function = function() return true end
        env.getnamecallmethod = function() return \"FakeMethod\" end
        env.setnamecallmethod = function(m) end
        
        local orig_getmetatable = env.getmetatable
        env.getmetatable = function(t)
            local mt = orig_getmetatable(t)
            if mt and mt.__MOCK_INSTANCE then 
                return nil 
            end
            return mt
        end

        env.syn = {
            request = env.request,
            queue_on_teleport = function(c) Emit(\"syn.queue_on_teleport(\"..tostring(c)..\")\") end,
            secure_call = function(f, e, ...) return f(...) end,
            crypto = env.crypt,
            cache_replace = function() end,
            cache_invalidate = function() end,
            set_thread_identity = function(i) Emit(\"syn.set_thread_identity(\"..tostring(i)..\")\") end,
            get_thread_identity = function() return 8 end,
            is_cached = function() return false end,
            write_clipboard = env.setclipboard,
        }
        env.KRNL_LOADED = true
        env.FLUXUS_LOADED = true
        env.krnl = env.syn
        env.fluxus = env.syn
    end
    
    setmetatable(env, {
        __index = function(t, k)
            local gv = _G[k]
            if gv ~= nil then 
                return gv 
            end
            return nil
        end,
        __newindex = function(t, k, v)
            rawset(t, k, v)
        end,
    })
    
    return env
end

------------------------------------------------------------------------
-- 17. LOG PROCESSOR & FORMATTING
------------------------------------------------------------------------

local function FormatPrettyLogs(logs)
    if not Config.Pretty then 
        return logs 
    end
    local formatted = {}
    local indentLevel = 0
    for _, line in ipairs(logs) do
        local clean = line:match(\"^%s*(.-)%s*$\")
        if clean ~= \"\" then
            if clean:match(\"^end%)?\") or clean:match(\"^%}\") or clean:match(\"^elseif\") or clean:match(\"^else\") then
                indentLevel = math.max(0, indentLevel - 1)
            end
            
            formatted[#formatted + 1] = string.rep(\"    \", indentLevel) .. clean
            
            if clean:match(\"function%s*%(\") or clean:match(\"do$\") or clean:match(\"then$\") or clean:match(\"%{$\") then
                indentLevel = indentLevel + 1
            end
        end
    end
    return formatted
end

local function ProcessLogs(logs)
    local deduped = {}
    local lastBlank = false
    
    for _, line in ipairs(logs) do
        local isBlank = line:match(\"^%s*$\")
        if not (isBlank and lastBlank) then
            deduped[#deduped + 1] = line
            lastBlank = isBlank
        end
    end
    
    if #deduped > 150000 then 
        return FormatPrettyLogs(deduped) 
    end
    
    local finalLogs = {}
    local i = 1
    
    while i <= #deduped do
        local bestBlockSize = 0
        local bestReps = 0
        for blockSize = 1, 25 do
            if i + blockSize * 2 - 1 <= #deduped then
                local reps = 1
                while i + (reps * blockSize) + blockSize - 1 <= #deduped do
                    local matches = true
                    for k = 0, blockSize - 1 do
                        if deduped[i + k] ~= deduped[i + (reps * blockSize) + k] then
                            matches = false
                            break
                        end
                    end
                    if matches then reps = reps + 1 else break end
                end
                if reps > bestReps and reps > 1 then
                    bestReps = reps
                    bestBlockSize = blockSize
                end
            end
        end
        
        if bestReps >= 5 then
            local showReps = 3
            for r = 1, math.min(showReps, bestReps) do
                for k = 0, bestBlockSize - 1 do
                    finalLogs[#finalLogs + 1] = deduped[i + (r - 1) * bestBlockSize + k]
                end
            end
            if bestReps > showReps then
                finalLogs[#finalLogs + 1] = \"-- [Korvahub] Skipped \" .. (bestReps - showReps) .. \" repetitive iterations from loop...\"
            end
            i = i + bestReps * bestBlockSize
        else
            finalLogs[#finalLogs + 1] = deduped[i]
            i = i + 1
        end
    end
    
    if FEATURES.VARIABLE_HOISTING then
        local hoisted, rest = {}, {}
        for _, log in ipairs(finalLogs) do
            if log:match(\"^local %w+ = game:GetService\") or log:match(\"^local %w+ = get%w+%b()\") then
                hoisted[#hoisted + 1] = log
            elseif log:match(\"^local LocalPlayer\") then
                hoisted[#hoisted + 1] = log
            else
                rest[#rest + 1] = log
            end
        end
        local r = {}
        for _, l in ipairs(hoisted) do 
            r[#r + 1] = l 
        end
        if #hoisted > 0 and #rest > 0 then 
            r[#r + 1] = \"\" 
        end
        for _, l in ipairs(rest) do 
            r[#r + 1] = l 
        end
        finalLogs = r
    end
    
    return FormatPrettyLogs(finalLogs)
end

------------------------------------------------------------------------
-- 18. SCRIPT PROCESSOR (ENTRY POINT)
------------------------------------------------------------------------

local function ProcessScript(source)
    if not source or type(source) ~= \"string\" or #source == 0 then
        return nil, \"empty source\"
    end
    
    local safe, scanResults = Security.ScanSource(source)
    if not safe then
        return nil, \"SECURITY BLOCK: \" .. table.concat(scanResults, \"; \")
    end
    
    State = MakeState()
    Security.callCount = 0
    GC_POOL = {}
    State.sourceLines = string.split(source, \"\\n\")
    
    for _, w in ipairs(scanResults) do
        State.logs[#State.logs + 1] = \"-- [WARNING] \" .. w
    end
    
    local configLines = {\"-- Config = {\"}
    for k, v in pairs(Config) do 
        table.insert(configLines, \"--    \" .. tostring(k) .. \" = \" .. tostring(v) .. \",\") 
    end
    table.insert(configLines, \"-- }\")
    
    local header = \"-- generated using KVms V0.8 \\-- https://discord.gg/YYu4F3Rdj\\n\" .. table.concat(configLines, \"\\n\") .. \"\"
    
    local fn, err = loadstring(source, \"Korvahub_script\")
    if not fn then
        local synErr = \"-- [Korvahub] SYNTAX OR COMPILATION ERROR:\\n-- \" .. tostring(err)
        State.logs[#State.logs + 1] = synErr
        return header .. table.concat(ProcessLogs(State.logs), \"\\n\"), nil
    end
    
    local mockEnv = CreateMockEnvironment()
    setfenv(fn, mockEnv)
    
    if debug and debug.sethook and Config.InfLoopGuard then
        local instructionCount = 0
        debug.sethook(function()
            instructionCount = instructionCount + 1
            if instructionCount > 50000000 then
                error(\"KORVAHUB_INF_LOOP\", 0)
            end
            if os.clock() - State.startTime > Config.Timeout then
                error(\"TIMEOUT_YIELD\", 0)
            end
        end, \"\", 1500)
    end
    
    local ok, runErr = pcall(fn)
    
    if debug and debug.sethook then 
        debug.sethook() 
    end
    
    if not ok then
        local errStr = tostring(runErr or \"\")
        if errStr:match(\"TIMEOUT\") then
            State.logs[#State.logs + 1] = \"\\n-- [Korvahub] Script yielded/timed out after \" .. Config.Timeout .. \"s.\"
        elseif errStr:match(\"KORVAHUB_INF_LOOP\") then
            State.logs[#State.logs + 1] = \"\\n-- [Korvahub] Infinite loop detected & automatically broken (50M limit).\"
        elseif not ShouldSuppressError(errStr) then
            local cleanErr = errStr:gsub(\"/root/[^:]*:\", \"\"):gsub('%[string \"Korvahub_script\"%]:', \"Line \")
            State.logs[#State.logs + 1] = '-- [Korvahub Exec Error] ' .. cleanErr:gsub('\\n', ' ')
        end
    end
    
    local processed = ProcessLogs(State.logs)

    local finalOutputLogs = {}
    if Config.Constants and State.stringCounter > 0 then
        table.insert(finalOutputLogs, \"local STR_CONST = {\")
        local temp = {}
        for strVal, id in pairs(State.stringConstants) do
            temp[id] = strVal
        end
        for i = 1, State.stringCounter do
            if temp[i] then
                local escaped = '\"' .. temp[i]:gsub('\\\\', '\\\\\\\\'):gsub('\"', '\\\\\"'):gsub('\\n', '\\\\n'):gsub('\\r', '\\\\r'):gsub('\\t', '\\\\t') .. '\"'
                table.insert(finalOutputLogs, \"  [\" .. i .. \"] = \" .. escaped .. \",\")
            end
        end
        table.insert(finalOutputLogs, \"}\")
        table.insert(finalOutputLogs, \"\")
    end

    for _, pLog in ipairs(processed) do
        table.insert(finalOutputLogs, pLog)
    end

    if Config.Minifier then
        local minified = {}
        for _, l in ipairs(finalOutputLogs) do
            local clean = l:match(\"^%s*(.-)%s*$\")
            if clean ~= \"\" then
                if not clean:match(\"^%-%-\") or clean:match(\"^%-%- %[Korvahub\") or clean:match(\"^%-%- %[WARNING]\") then
                    minified[#minified + 1] = clean
                end
            end
        end
        finalOutputLogs = minified
    end
    
    return header .. table.concat(finalOutputLogs, \"\\n\"), nil
end

------------------------------------------------------------------------
-- 19. FILE I/O SHIM & CLI HANDLER
------------------------------------------------------------------------

local function ReadFile(path)
    if fs then
        local ok, data = pcall(function() return fs.readFile(path) end)
        if ok and data then return data end
    end
    local f = io.open(path, \"rb\")
    if not f then 
        return nil, \"Cannot open: \" .. path 
    end
    local data = f:read(\"*a\")
    f:close()
    return data
end

local function WriteFile(path, data)
    if fs then
        local ok = pcall(function() fs.writeFile(path, data) end)
        if ok then return true end
    end
    local f = io.open(path, \"wb\")
    if not f then 
        return false, \"Cannot write: \" .. path 
    end
    f:write(data)
    f:close()
    return true
end

local function ReadStdin()
    if stdio then
        local lines = {}
        local ok = pcall(function()
            while true do
                local line = stdio.readLine()
                if line == nil then break end
                lines[#lines + 1] = line
            end
        end)
        if ok and #lines > 0 then return table.concat(lines, \"\\n\") end
    end
    local data = io.read(\"*a\")
    return data and #data > 0 and data or nil
end

if not io then
    io = {
        write = function(...) print(table.concat({...})) end,
        flush = function() end,
        stderr = {write = function(_, s) print(s) end},
    }
elseif not io.stderr then
    io.stderr = {write = function(_, s) io.write(s) end}
end
if not io.flush then 
    io.flush = function() end 
end

local args = process and process.args or {}
local inputPath, outputPath

for i = 1, #args do
    local arg = args[i]
    if arg:sub(1, 2) == \"--\" then
        local key, val = arg:match(\"^%-%-([^=]+)=(.*)$\")
        if key and val then
            if val:lower() == \"true\" then 
                Config[key] = true
            elseif val:lower() == \"false\" then 
                Config[key] = false
            elseif tonumber(val) then 
                Config[key] = tonumber(val)
            else 
                Config[key] = val 
            end
        else
            local flag = arg:match(\"^%-%-(.+)$\")
            if flag and Config[flag] ~= nil then 
                Config[flag] = true 
            end
        end
    elseif not inputPath then
        inputPath = arg
    elseif not outputPath then
        outputPath = arg
    end
end

Config.Timeout = math.min(Config.Timeout or 180, 300)

if not inputPath and #args == 0 then
    local src = ReadStdin()
    if not src then
        print(\"Usage:\\n lune run main.luau <input.lua> <output.lua> [--ConfigKey=Value]\\nExample:\\n lune run main.luau in.lua out.lua --Pretty=true --HookOp=true\")
        if process then process.exit(1) end
        return
    end
    local result, err = ProcessScript(src)
    if not result then
        io.stderr:write(\"ERROR: \" .. tostring(err) .. \"\\n\")
        if process then process.exit(1) end
        return
    end
    io.write(result)
elseif inputPath then
    io.write(\"Processing: \" .. inputPath .. \" ... \")
    io.flush()
    local src, err1 = ReadFile(inputPath)
    if not src then
        print(\"ERROR: \" .. tostring(err1))
        if process then process.exit(1) end
        return
    end
    local result, err2 = ProcessScript(src)
    if not result then
        print(\"FAILED: \" .. tostring(err2))
        if process then process.exit(1) end
        return
    end
    if outputPath then
        local ok, err3 = WriteFile(outputPath, result)
        if not ok then
            print(\"WRITE ERROR: \" .. tostring(err3))
            if process then process.exit(1) end
            return
        end
        print(\"OK (\" .. #result .. \" bytes) -> Saved to \" .. outputPath)
    else
        print(\"\\n\\n\" .. result)
    end
else
    print(\"Usage:\\n lune run main.luau <input.lua> <output.lua> [--Flags]\")
end")
