-- use Lune

--!strict

local scriptArgs = {...}
local DUMP_HEADER = "-- This file was kindly investigated by the idf (RevealR --> https://discord.gg/cmeRzqRFr6)"

local function tryRequire(moduleName: string): any
    local ok, module = pcall(require, moduleName)
    if ok then
        return module
    end
    return nil
end

local runtimeName = "lune"
local rawFs = tryRequire("@lute/fs")
local rawProcess = nil
local rawLuau = nil
local rawStdio = nil

if rawFs ~= nil then
    runtimeName = "lute"
    rawProcess = require("@lute/process")
    rawLuau = require("@lute/luau")
    rawStdio = require("@lute/io")
else
    rawFs = require("@lune/fs")
    rawProcess = require("@lune/process")
    rawLuau = require("@lune/luau")
    rawStdio = require("@lune/stdio")
end

local function copyModule(module: any): any
    local adapter = {}
    if type(module) == "table" then
        for key, value in pairs(module) do
            adapter[key] = value
        end
    end
    return adapter
end

local function normalizeFs(module: any): any
    local adapter = copyModule(module)

    if runtimeName == "lute" then
        adapter.readFile = function(path: string): string
            local handle = module.open(path, "r")
            local ok, data = pcall(module.read, handle)
            local closeOk, closeErr = pcall(module.close, handle)
            if not ok then
                error(data, 2)
            end
            if not closeOk then
                error(closeErr, 2)
            end
            return data
        end

        adapter.writeFile = function(path: string, contents: string)
            local handle = module.open(path, "w")
            local ok, err = pcall(module.write, handle, contents)
            local closeOk, closeErr = pcall(module.close, handle)
            if not ok then
                error(err, 2)
            end
            if not closeOk then
                error(closeErr, 2)
            end
        end

        adapter.isFile = function(path: string): boolean
            local ok, fileType = pcall(module.type, path)
            return ok and fileType == "file"
        end

        adapter.isDir = function(path: string): boolean
            local ok, fileType = pcall(module.type, path)
            return ok and fileType == "dir"
        end

        adapter.writeDir = module.mkdir
        adapter.removeFile = module.remove
    end

    return adapter
end

local function normalizeArgs(rawArgs: any): {string}
    local args = {}

    if type(rawArgs) == "table" then
        for _, value in ipairs(rawArgs) do
            table.insert(args, tostring(value))
        end
    else
        for index = 2, #scriptArgs do
            table.insert(args, tostring(scriptArgs[index]))
        end
    end

    if #scriptArgs > 0 and args[1] == scriptArgs[1] then
        table.remove(args, 1)
    end

    return args
end

local function normalizeProcess(module: any): any
    local adapter = copyModule(module)
    adapter.args = normalizeArgs(module.args)
    adapter.env = module.env or {}

    if type(module.cwd) == "function" then
        adapter.cwd = module.cwd()
    else
        adapter.cwd = module.cwd or "."
    end

    if runtimeName == "lute" then
        adapter.exec = function(command: string, args: {string}?): any
            local argv = { command }
            if args then
                for _, argument in ipairs(args) do
                    table.insert(argv, tostring(argument))
                end
            end
            return module.run(argv, { stdio = "default" })
        end
    end

    return adapter
end

local function normalizeLuau(module: any): any
    local adapter = copyModule(module)

    if runtimeName == "lute" then
        adapter.load = function(source: string, options: any): any
            local bytecode = module.compile(source)
            local chunkName = options and options.debugName or "chunk"
            local environment = options and options.environment or nil
            return module.load(bytecode, chunkName, environment)
        end
    end

    return adapter
end

local function normalizeStdio(module: any): any
    local adapter = copyModule(module)

    if type(adapter.ewrite) ~= "function" then
        adapter.ewrite = function(value: any)
            if module ~= nil and type(module.write) == "function" then
                module.write(tostring(value))
            else
                print(tostring(value))
            end
        end
    end

    return adapter
end

local fs = normalizeFs(rawFs)
local luau = normalizeLuau(rawLuau)
local process = normalizeProcess(rawProcess)
local stdio = normalizeStdio(rawStdio)

local _fs = fs
local _process = process
local _require = require
local _luau = luau
local _stdio = stdio
local _load = load
local _loadstring = loadstring
local _debug = debug

local function envFlag(name: string): boolean
    local value = process.env[name]
    if value == nil then
        return false
    end
    value = tostring(value):lower()
    return value == "1" or value == "true" or value == "yes" or value == "on"
end

local LIMITS = {
    MAX_API_CALLS = tonumber(process.env.ENV2_MAX_API_CALLS or "") or 500000,
    MAX_VARIABLES = 10000,
    MAX_PROXIES = 5000,
    MAX_LOADED_CHUNKS = 100,
    MAX_CHUNK_SIZE = 1024 * 1024,
    MAX_METATABLES = 1000,
    MAX_VM_INSTRUCTIONS = 100000,
    GLOBAL_ENV_STORAGE = 5000,
    REPEAT_TRACE_LIMIT = tonumber(process.env.ENV2_REPEAT_TRACE_LIMIT or "") or 8,
    LOAD_REPEAT_LIMIT = tonumber(process.env.ENV2_LOAD_REPEAT_LIMIT or "") or 3,
    MAX_EXECUTION_SECONDS = tonumber(process.env.ENV2_MAX_EXECUTION_SECONDS or "") or 8,
    MAX_LOOP_TICKS = tonumber(process.env.ENV2_MAX_LOOP_TICKS or "") or 250000000,
    LOOP_CHECK_INTERVAL = 4096,
    DEBUG_HOOK_INSTRUCTION_COUNT = 250000,
    VM_TRACE_ENABLED = envFlag("ENV2_VM_TRACE") or envFlag("REVEALR_VM_TRACE"),
    VM_TRACE_FULL = envFlag("ENV2_VM_TRACE_FULL") or envFlag("REVEALR_VM_TRACE_FULL"),
    ALLOW_SYNTHETIC_PROXY_CALLS = envFlag("ENV2_PROXY_CALL_FALLBACK") or envFlag("REVEALR_PROXY_CALL_FALLBACK"),
    WATCHDOG_ENABLED = envFlag("ENV2_WATCHDOG") or envFlag("REVEALR_WATCHDOG"),
    EMIT_STATIC_METADATA = envFlag("ENV2_STATIC_METADATA") or envFlag("REVEALR_STATIC_METADATA"),
    EMIT_DECODED_METADATA = envFlag("ENV2_DECODED_METADATA") or envFlag("REVEALR_DECODED_METADATA"),
    EMIT_CHUNK_METADATA = envFlag("ENV2_CHUNK_METADATA") or envFlag("REVEALR_CHUNK_METADATA"),
    EMIT_EXTERNAL_TRACE = envFlag("ENV2_EXTERNAL_TRACE_DUMP") or envFlag("REVEALR_EXTERNAL_TRACE_DUMP"),
    EMIT_HOOKOP_METADATA = envFlag("ENV2_HOOKOP_METADATA") or envFlag("REVEALR_HOOKOP_METADATA"),
    EMIT_SUPPRESSED_METADATA = envFlag("ENV2_SUPPRESSED_METADATA") or envFlag("REVEALR_SUPPRESSED_METADATA"),
    COMPACT_DUMP = process.env.ENV2_COMPACT_DUMP ~= "0",
}

local RESOURCE_USAGE = {
    apiCalls = 0,
    variables = 0,
    proxies = 0,
    loadedChunks = 0,
    metatables = 0,
    envStorage = 0,
}

local WATCHDOG_GLOBAL = "__env2_watchdog_4d657461"
local hookOpTransformCounter = 0
local UTF8_BOM = "\239\187\191"
local WATCHDOG_STATE = {
    active = false,
    tripped = false,
    label = "script",
    startedAt = 0,
    deadlineAt = 0,
    ticks = 0,
    message = "",
}

local function stripUtf8Bom(code: string): string
    if code:sub(1, #UTF8_BOM) == UTF8_BOM then
        return code:sub(#UTF8_BOM + 1)
    end
    return code
end

local function watchdogMessage(label: string?): string
    local elapsed = os.clock() - WATCHDOG_STATE.startedAt
    return string.format(
        "[ENV2_WATCHDOG] %s stopped after %.2fs (%d loop ticks)",
        tostring(label or WATCHDOG_STATE.label),
        elapsed,
        WATCHDOG_STATE.ticks
    )
end

local function isWatchdogError(value: any): boolean
    return tostring(value):find("[ENV2_WATCHDOG]", 1, true) ~= nil
end

local function tripExecutionWatchdog(label: string?): never
    WATCHDOG_STATE.tripped = true
    WATCHDOG_STATE.active = false
    WATCHDOG_STATE.message = watchdogMessage(label)
    error(WATCHDOG_STATE.message, 2)
end

local function executionWatchdog(label: string?)
    if not LIMITS.WATCHDOG_ENABLED then
        return
    end
    if WATCHDOG_STATE.tripped then
        error(WATCHDOG_STATE.message, 2)
    end
    if not WATCHDOG_STATE.active then
        return
    end

    WATCHDOG_STATE.ticks += 1
    if WATCHDOG_STATE.ticks >= LIMITS.MAX_LOOP_TICKS then
        tripExecutionWatchdog(label)
    end
    if WATCHDOG_STATE.ticks % LIMITS.LOOP_CHECK_INTERVAL == 0 and os.clock() >= WATCHDOG_STATE.deadlineAt then
        tripExecutionWatchdog(label)
    end
end

local function resetExecutionWatchdog(label: string?)
    if not LIMITS.WATCHDOG_ENABLED then
        return
    end
    WATCHDOG_STATE.active = true
    WATCHDOG_STATE.tripped = false
    WATCHDOG_STATE.label = label or "script"
    WATCHDOG_STATE.startedAt = os.clock()
    WATCHDOG_STATE.deadlineAt = WATCHDOG_STATE.startedAt + LIMITS.MAX_EXECUTION_SECONDS
    WATCHDOG_STATE.ticks = 0
    WATCHDOG_STATE.message = ""

    if _debug and type(_debug.sethook) == "function" then
        pcall(function()
            _debug.sethook(function()
                if WATCHDOG_STATE.tripped then
                    error(WATCHDOG_STATE.message, 2)
                end
                if WATCHDOG_STATE.active and os.clock() >= WATCHDOG_STATE.deadlineAt then
                    tripExecutionWatchdog(WATCHDOG_STATE.label .. ":hook")
                end
            end, "", LIMITS.DEBUG_HOOK_INSTRUCTION_COUNT)
        end)
    end
end

local function stopExecutionWatchdog()
    if not LIMITS.WATCHDOG_ENABLED then
        return
    end
    WATCHDOG_STATE.active = false
    if _debug and type(_debug.sethook) == "function" then
        pcall(function()
            _debug.sethook()
        end)
    end
end

local function checkLimit(name: string, limit: number): boolean
    return (RESOURCE_USAGE[name] or 0) < limit
end


do
    local existingStringMt = getmetatable("")
    local stringMt = {}

    local function toArithmeticNumber(value: any): number
        local numberValue = tonumber(value)
        if numberValue ~= nil then
            return numberValue
        end
        return 0
    end

    if existingStringMt then
        for k, v in pairs(existingStringMt) do
            pcall(function()
                stringMt[k] = v
            end)
        end
    end

    stringMt.__index = string
    stringMt.__pow = function(a, b)
        local numA = toArithmeticNumber(a)
        local numB = toArithmeticNumber(b)
        return numA ^ numB
    end
    stringMt.__add = function(a, b)
        local numA = toArithmeticNumber(a)
        local numB = toArithmeticNumber(b)
        return numA + numB
    end
    stringMt.__sub = function(a, b)
        local numA = toArithmeticNumber(a)
        local numB = toArithmeticNumber(b)
        return numA - numB
    end
    stringMt.__mul = function(a, b)
        local numA = toArithmeticNumber(a)
        local numB = toArithmeticNumber(b)
        return numA * numB
    end
    stringMt.__div = function(a, b)
        local numA = toArithmeticNumber(a)
        local numB = toArithmeticNumber(b)
        if numB ~= 0 then return numA / numB end
        return 0
    end
    stringMt.__mod = function(a, b)
        local numA = toArithmeticNumber(a)
        local numB = toArithmeticNumber(b)
        if numB ~= 0 then return numA % numB end
        return 0
    end
    stringMt.__unm = function(a)
        return -toArithmeticNumber(a)
    end

    local scalarMt = {}
    for key, value in pairs(stringMt) do
        if key ~= "__index" then
            scalarMt[key] = value
        end
    end

    local success = pcall(function()
        if debug and debug.setmetatable then
            debug.setmetatable("", stringMt)
            pcall(debug.setmetatable, 0, scalarMt)
            pcall(debug.setmetatable, nil, scalarMt)
            local result = "5" ^ 2
            if result == 25 then
                print("[compat] String arithmetic enabled")
            end
        end
    end)

    if not success then
    end
end


-- Local/standalone build: no bot authorization or environment lockdown.
-- The sandbox used for executing analyzed scripts is intentionally separate
-- and remains enabled so samples cannot access the host filesystem/network.

local function stripLuauTypeAnnotations(code: string): string
    local out: {string} = {}
    local index = 1
    local length = #code

    local function readLongBracket(startIndex: number): number?
        if code:sub(startIndex, startIndex) ~= "[" then
            return nil
        end

        local cursor = startIndex + 1
        while code:sub(cursor, cursor) == "=" do
            cursor += 1
        end
        if code:sub(cursor, cursor) ~= "[" then
            return nil
        end

        local close = "]" .. string.rep("=", cursor - startIndex - 1) .. "]"
        local closeAt = code:find(close, cursor + 1, true)
        if closeAt then
            return closeAt + #close - 1
        end
        return length
    end

    local function readQuoted(startIndex: number, quote: string): number
        local cursor = startIndex + 1
        while cursor <= length do
            local ch = code:sub(cursor, cursor)
            if ch == "\\" then
                cursor += 2
            elseif ch == quote then
                return cursor
            else
                cursor += 1
            end
        end
        return length
    end

    local function isIdentStart(ch: string): boolean
        return ch:match("[%a_]") ~= nil
    end

    local function isIdentPart(ch: string): boolean
        return ch:match("[%w_%.]") ~= nil
    end

    local function previousCodeChar(position: number): string
        local cursor = position - 1
        while cursor >= 1 and code:sub(cursor, cursor):match("[%s]") do
            cursor -= 1
        end
        if cursor < 1 then
            return ""
        end
        return code:sub(cursor, cursor)
    end

    local function findAnnotationEnd(colonIndex: number): number?
        if code:sub(colonIndex + 1, colonIndex + 1) == ":" then
            return nil
        end

        local prev = previousCodeChar(colonIndex)
        if prev == "" or prev == ":" then
            return nil
        end

        local cursor = colonIndex + 1
        while cursor <= length and code:sub(cursor, cursor):match("[%s]") do
            cursor += 1
        end

        local first = code:sub(cursor, cursor)
        if first == "" or not (isIdentStart(first) or first == "{" or first == "(") then
            return nil
        end

        if isIdentStart(first) then
            repeat
                cursor += 1
            until cursor > length or not isIdentPart(code:sub(cursor, cursor))

            local lookahead = cursor
            while lookahead <= length and code:sub(lookahead, lookahead):match("[ \t]") do
                lookahead += 1
            end
            if code:sub(lookahead, lookahead) == "(" then
                return nil
            end
        end

        cursor = colonIndex + 1
        local parenDepth = 0
        local braceDepth = 0
        local bracketDepth = 0
        local angleDepth = 0

        while cursor <= length do
            local ch = code:sub(cursor, cursor)
            local nextCh = code:sub(cursor + 1, cursor + 1)

            if ch == "'" or ch == '"' then
                cursor = readQuoted(cursor, ch) + 1
                continue
            end

            local longEnd = readLongBracket(cursor)
            if longEnd then
                cursor = longEnd + 1
                continue
            end

            if parenDepth == 0 and braceDepth == 0 and bracketDepth == 0 and angleDepth == 0 then
                if ch == "," or ch == ")" or ch == "=" or ch == ";" or ch == "\n" or ch == "\r" then
                    break
                end
            end

            if ch == "(" then
                parenDepth += 1
            elseif ch == ")" then
                if parenDepth > 0 then
                    parenDepth -= 1
                end
            elseif ch == "{" then
                braceDepth += 1
            elseif ch == "}" then
                if braceDepth > 0 then
                    braceDepth -= 1
                end
            elseif ch == "[" then
                bracketDepth += 1
            elseif ch == "]" then
                if bracketDepth > 0 then
                    bracketDepth -= 1
                end
            elseif ch == "<" then
                angleDepth += 1
            elseif ch == ">" then
                if angleDepth > 0 then
                    angleDepth -= 1
                end
            elseif ch == "-" and nextCh == ">" then
                cursor += 1
            end

            cursor += 1
        end

        return cursor
    end

    while index <= length do
        local ch = code:sub(index, index)
        local nextCh = code:sub(index + 1, index + 1)

        if ch == "-" and nextCh == "-" then
            local longEnd = readLongBracket(index + 2)
            if longEnd then
                table.insert(out, code:sub(index, longEnd))
                index = longEnd + 1
            else
                local newline = code:find("\n", index + 2, true)
                if newline then
                    table.insert(out, code:sub(index, newline))
                    index = newline + 1
                else
                    table.insert(out, code:sub(index))
                    break
                end
            end
        elseif ch == "'" or ch == '"' then
            local quotedEnd = readQuoted(index, ch)
            table.insert(out, code:sub(index, quotedEnd))
            index = quotedEnd + 1
        else
            local longEnd = readLongBracket(index)
            if longEnd then
                table.insert(out, code:sub(index, longEnd))
                index = longEnd + 1
            elseif ch == ":" then
                local annotationEnd = findAnnotationEnd(index)
                if annotationEnd then
                    index = annotationEnd
                else
                    table.insert(out, ch)
                    index += 1
                end
            else
                table.insert(out, ch)
                index += 1
            end
        end
    end

    return table.concat(out)
end

local function sanitizeLuauSyntax(code: string): string
    local traceSanitize = process.env.ENV2_TRACE_LOAD and process.env.ENV2_TRACE_LOAD ~= ""
    local sanitizeStart = os.clock()
    local function traceSanitizeStep(name: string)
        if traceSanitize then
            print(string.format("[env2 sanitize] %.3fs %s", os.clock() - sanitizeStart, name))
        end
    end

    traceSanitizeStep("types:start")
    code = stripLuauTypeAnnotations(code)
    traceSanitizeStep("types:done")
    traceSanitizeStep("generics:start")
    code = code:gsub("function%s+([%w_]+)%s*<[^>]+>", "function %1")
    traceSanitizeStep("generics:done")

    traceSanitizeStep("binary:start")
    code = code:gsub("0b([01]+)", function(binary)
        local decimal = 0
        for i = 1, #binary do
            decimal = decimal * 2 + tonumber(binary:sub(i, i))
        end
        return tostring(decimal)
    end)
    traceSanitizeStep("binary:done")

    traceSanitizeStep("continue:start")
    code = code:gsub("%s+continue%s+", " do end ")
    traceSanitizeStep("continue:done")

    traceSanitizeStep("export:start")
    code = code:gsub("export%s+", "")
    traceSanitizeStep("export:done")

    traceSanitizeStep("interpolation:start")
    code = code:gsub("`([^`]*)`", function(str)
        local parts = {}
        local format = str:gsub("{(.-)}", function(expr)
            table.insert(parts, expr)
            return "%s"
        end)
        if #parts > 0 then
            return 'string.format("' .. format .. '", ' .. table.concat(parts, ", ") .. ')'
        end
        return '"' .. str .. '"'
    end)
    traceSanitizeStep("interpolation:done")

    return code
end

local function deobfuscateStrings(code: string): string
    local modified = false
    local iterations = 0
    local maxIterations = 5

    local isLuraphV16 = code:match("Luraph Obfuscator v16") or
                        (code:match("local function %w+%(a,b%)local r=0") and
                         code:match("local function %w+%(h,k%)local t={}"))

    if isLuraphV16 then
        print("[detect] Luraph v16 beta")
        print("   Attempting to decode XOR-encrypted strings...")

        local xorFuncName = code:match("local function (%w+)%(a,b%)local r=0;local p=1;for _=0,7 do")

        local hexDecoderName = code:match("local function (%w+)%(h,k%)local t={}for i=1,#h,2 do")

        local byteDecoderName = code:match("local function (%w+)%(tb,m%)local t={}for i=1,#tb do")

        if xorFuncName and hexDecoderName then
            print(string.format("   XOR function: %s", xorFuncName))
            print(string.format("   Hex decoder: %s", hexDecoderName))

            local function xorBytes(a, b)
                local r = 0
                local p = 1
                for _ = 0, 7 do
                    local ab = a % 2
                    local bb = b % 2
                    if ab ~= bb then
                        r = r + p
                    end
                    a = math.floor(a / 2)
                    b = math.floor(b / 2)
                    p = p * 2
                end
                return r
            end

            local function decodeHexString(hexStr, key)
                local bytes = {}
                for i = 1, #hexStr, 2 do
                    table.insert(bytes, tonumber(hexStr:sub(i, i+1), 16) or 0)
                end

                local keyLen = #key
                local output = {}
                for i = 1, #bytes do
                    local keyByte = key:byte(((i - 1) % keyLen) + 1)
                    output[i] = string.char(xorBytes(bytes[i], keyByte))
                end
                return table.concat(output)
            end

            local function decodeByteArray(byteArray, mask)
                local output = {}
                for i = 1, #byteArray do
                    output[i] = string.char(xorBytes(byteArray[i], mask))
                end
                return table.concat(output)
            end

            local encodedArrays = {}
            for arrayName, arrayData in code:gmatch("local (%w+)={([%d,]+)}") do
                local bytes = {}
                for num in arrayData:gmatch("%d+") do
                    table.insert(bytes, tonumber(num))
                end
                if #bytes > 0 then
                    encodedArrays[arrayName] = bytes
                end
            end

            local keyVarName, keyArrayName, keyMask = code:match("local (%w+)=" .. (byteDecoderName or "yQVvID") .. "%((%w+),(%d+)%)")

            if keyVarName and keyArrayName and encodedArrays[keyArrayName] then
                local keyMaskNum = tonumber(keyMask)
                local decodedKey = decodeByteArray(encodedArrays[keyArrayName], keyMaskNum)
                print(string.format("   Decoded key: %s", decodedKey:sub(1, 20) .. "..."))

                local mainArrayName = code:match("local (%w+)={\"[0-9a-f]+\"")
                if mainArrayName then
                    local hexStrings = {}
                    for hexStr in code:gmatch('"([0-9a-f]+)"') do
                        if #hexStr > 50 then
                            table.insert(hexStrings, hexStr)
                        end
                    end

                    print(string.format("   Found %d encrypted strings", #hexStrings))

                    local decodedStrings = {}
                    for i, hexStr in ipairs(hexStrings) do
                        local decoded = decodeHexString(hexStr, decodedKey)
                        if #decoded > 0 and decoded:match("[%w%s%p]+") then
                            table.insert(decodedStrings, decoded)
                            if i <= 5 then
                                print(string.format("   String %d: %s", i, decoded:sub(1, 50):gsub("\n", "\\n")))
                            end
                        end
                    end

                    if #decodedStrings > 5 then
                        print(string.format("   ... and %d more strings", #decodedStrings - 5))
                    end

                    local reconstructed = "-- [Luraph v16 Decoded Strings]\n\n"
                    for i, str in ipairs(decodedStrings) do
                        reconstructed = reconstructed .. string.format("-- String %d: %s\n", i, str:sub(1, 100):gsub("\n", "\\n"))
                    end
                    reconstructed = reconstructed .. "\n" .. code

                    modified = true
                    code = reconstructed
                end
            end
        end
    end

    repeat
        if not modified then
            modified = false
        end
        iterations += 1

        local constants: {[number]: any} = {}
        local constantCount = 0
        local instructions: {{op: number, a: number, b: number, c: number}} = {}
        local hasBytecode = false

        for line in code:gmatch("[^\r\n]+") do
            local constIdx, constType, constValue = line:match("CONST%[(%d+)%]%s*%(([%w_]+)%)%s*=%s*(.+)")
            if constIdx then
                hasBytecode = true
                constIdx = tonumber(constIdx)
                if constants[constIdx] == nil then
                    constantCount += 1
                end

                if constType == "string" then
                    constValue = constValue:match('"(.-)"') or constValue:match("'(.-)'") or constValue
                    constValue = constValue:gsub('\\"', '"'):gsub("\\'", "'")
                    constants[constIdx] = constValue
                elseif constType == "number" then
                    constants[constIdx] = tonumber(constValue)
                elseif constType == "boolean" then
                    constants[constIdx] = (constValue == "true")
                end
            end

            local instrIdx, op, a, b, c = line:match("INSTR%[(%d+)%]%s*OP=(%d+)%s*A=(%d+)%s*B=(%d+)%s*C=(%d+)")
            if instrIdx then
                table.insert(instructions, {
                    idx = tonumber(instrIdx),
                    op = tonumber(op),
                    a = tonumber(a),
                    b = tonumber(b),
                    c = tonumber(c)
                })
            end
        end

        if hasBytecode and #instructions > 0 then
            print("[detect] Bytecode obfuscation")
            print(string.format("   Constants: %d | Instructions: %d", constantCount, #instructions))

            local reconstructed: {string} = {}
            table.insert(reconstructed, "-- [Reconstructed from bytecode dump]")
            table.insert(reconstructed, "")

            local opcodes = {
                [0] = "MOVE", [1] = "LOADK", [2] = "LOADBOOL", [3] = "LOADNIL",
                [4] = "GETUPVAL", [5] = "GETGLOBAL", [6] = "GETTABLE", [7] = "SETGLOBAL",
                [8] = "SETUPVAL", [9] = "SETTABLE", [10] = "NEWTABLE", [11] = "SELF",
                [12] = "ADD", [13] = "SUB", [14] = "MUL", [15] = "DIV",
                [16] = "MOD", [17] = "POW", [18] = "UNM", [19] = "NOT",
                [20] = "LEN", [21] = "CONCAT", [22] = "JMP", [23] = "EQ",
                [24] = "LT", [25] = "LE", [26] = "TEST", [27] = "TESTSET",
                [28] = "CALL", [29] = "TAILCALL", [30] = "RETURN", [31] = "FORLOOP",
                [32] = "FORPREP", [33] = "TFORLOOP", [34] = "SETLIST", [35] = "CLOSE",
                [36] = "CLOSURE", [37] = "VARARG",
                [57] = "CALL", [70] = "LOADK", [161] = "RETURN", [172] = "GETGLOBAL"
            }

            table.insert(reconstructed, "-- === CONSTANTS ===")
            local constantIndices = {}
            for idx in pairs(constants) do
                table.insert(constantIndices, idx)
            end
            table.sort(constantIndices)
            for _, idx in ipairs(constantIndices) do
                local value = constants[idx]
                if type(value) == "string" then
                    local escaped = value:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n"):gsub("\r", "\\r")
                    table.insert(reconstructed, string.format("-- CONST[%d] = \"%s\"", idx, escaped))
                else
                    table.insert(reconstructed, string.format("-- CONST[%d] = %s", idx, tostring(value)))
                end
            end
            table.insert(reconstructed, "")

            table.insert(reconstructed, "-- === FULL INSTRUCTION DUMP ===")
            local encryptedOpcodeCounts: {[number]: number} = {}
            for _, instr in ipairs(instructions) do
                local opName = opcodes[instr.op] or string.format("OP_%d", instr.op)
                if not opcodes[instr.op] then
                    encryptedOpcodeCounts[instr.op] = (encryptedOpcodeCounts[instr.op] or 0) + 1
                end
                table.insert(reconstructed, string.format(
                    "-- [%06d] %-12s raw=%d A=%d B=%d C=%d",
                    instr.idx or 0,
                    opName,
                    instr.op,
                    instr.a,
                    instr.b,
                    instr.c
                ))
            end
            if next(encryptedOpcodeCounts) then
                local encryptedIds = {}
                for opcode, count in pairs(encryptedOpcodeCounts) do
                    table.insert(encryptedIds, {opcode = opcode, count = count})
                end
                table.sort(encryptedIds, function(left, right)
                    return left.opcode < right.opcode
                end)
                table.insert(reconstructed, "-- Custom/encrypted opcode candidates:")
                for _, entry in ipairs(encryptedIds) do
                    table.insert(reconstructed, string.format("--   raw=%d count=%d", entry.opcode, entry.count))
                end
            end
            table.insert(reconstructed, "")

            table.insert(reconstructed, "-- === RECONSTRUCTED CODE ===")

            local registers: {[number]: string} = {}
            local globals: {[string]: boolean} = {}

            for _, instr in ipairs(instructions) do
                local opName = opcodes[instr.op] or string.format("OP_%d", instr.op)

                if opName == "GETGLOBAL" or instr.op == 172 or instr.op == 5 then
                    local globalName = constants[instr.b] or "unknown"
                    registers[instr.a] = globalName
                    globals[globalName] = true
                    table.insert(reconstructed, string.format("local r%d = %s", instr.a, globalName))

                elseif opName == "LOADK" or instr.op == 70 or instr.op == 1 then
                    local value = constants[instr.b]
                    if type(value) == "string" then
                        registers[instr.a] = string.format('"%s"', value:gsub('"', '\\"'))
                        table.insert(reconstructed, string.format('local r%d = "%s"', instr.a, value:gsub('"', '\\"')))
                    elseif type(value) == "number" then
                        registers[instr.a] = tostring(value)
                        table.insert(reconstructed, string.format('local r%d = %s', instr.a, tostring(value)))
                    elseif type(value) == "boolean" then
                        registers[instr.a] = tostring(value)
                        table.insert(reconstructed, string.format('local r%d = %s', instr.a, tostring(value)))
                    else
                        registers[instr.a] = "nil"
                        table.insert(reconstructed, string.format('local r%d = nil', instr.a))
                    end

                elseif opName == "CALL" or instr.op == 57 or instr.op == 28 then
                    local funcName = registers[instr.a] or ("r" .. instr.a)
                    local args: {string} = {}

                    local argCount = instr.b - 1
                    if argCount < 0 then argCount = 0 end

                    for argIdx = instr.a + 1, instr.a + argCount do
                        table.insert(args, registers[argIdx] or ("r" .. argIdx))
                    end

                    if #args > 0 then
                        table.insert(reconstructed, string.format("%s(%s)", funcName, table.concat(args, ", ")))
                    else
                        table.insert(reconstructed, string.format("%s()", funcName))
                    end

                elseif opName == "RETURN" or instr.op == 161 or instr.op == 30 then
                    if instr.b > 1 then
                        local returns: {string} = {}
                        for i = instr.a, instr.a + instr.b - 2 do
                            table.insert(returns, registers[i] or ("r" .. i))
                        end
                        table.insert(reconstructed, "return " .. table.concat(returns, ", "))
                    else
                        table.insert(reconstructed, "return")
                    end

                elseif opName == "MOVE" or instr.op == 0 then
                    registers[instr.a] = registers[instr.b] or ("r" .. instr.b)
                    table.insert(reconstructed, string.format("local r%d = %s", instr.a, registers[instr.a]))

                elseif opName == "GETTABLE" or instr.op == 6 then
                    local table_reg = registers[instr.b] or ("r" .. instr.b)
                    local key = registers[instr.c] or constants[instr.c] or ("r" .. instr.c)
                    if type(key) == "string" and key:match("^[%a_][%w_]*$") then
                        registers[instr.a] = string.format("%s.%s", table_reg, key)
                    else
                        registers[instr.a] = string.format("%s[%s]", table_reg, key)
                    end
                    table.insert(reconstructed, string.format("local r%d = %s", instr.a, registers[instr.a]))

                elseif opName == "SETTABLE" or instr.op == 9 then
                    local table_reg = registers[instr.a] or ("r" .. instr.a)
                    local key = registers[instr.b] or constants[instr.b] or ("r" .. instr.b)
                    local value = registers[instr.c] or constants[instr.c] or ("r" .. instr.c)
                    if type(key) == "string" and key:match("^[%a_][%w_]*$") then
                        table.insert(reconstructed, string.format("%s.%s = %s", table_reg, key, value))
                    else
                        table.insert(reconstructed, string.format("%s[%s] = %s", table_reg, key, value))
                    end

                elseif opName == "SETGLOBAL" or instr.op == 7 then
                    local globalName = constants[instr.b] or "unknown"
                    local value = registers[instr.a] or ("r" .. instr.a)
                    table.insert(reconstructed, string.format("%s = %s", globalName, value))
                end
            end

            if next(globals) then
                table.insert(reconstructed, "")
                table.insert(reconstructed, "-- === GLOBALS ACCESSED ===")
                for global, _ in pairs(globals) do
                    table.insert(reconstructed, string.format("-- %s", global))
                end
            end

            return table.concat(reconstructed, "\n")
        end

        local invisibleChars = {
            ["\u{200B}"] = "0", ["\u{200C}"] = "0", ["\u{200D}"] = "1",
            ["\u{2060}"] = "1", ["\u{FEFF}"] = "0", ["\u{180E}"] = "0",
            [" "] = "0", ["Ã¢â‚¬â€¹"] = "0", ["Ã¢â‚¬Â"] = "1", ["Ã¢â‚¬Å½"] = "0", ["Ã¢â‚¬Â"] = "1",
        }

        local function decodeInvisibleString(str)
        local binary = ""
            local hasInvisible = false

            for i = 1, #str do
                local char = str:sub(i, i)
                local bit = invisibleChars[char]
                if bit then
                    binary = binary .. bit
                    hasInvisible = true
                end
            end

            if not hasInvisible or #binary == 0 then
                return str
            end

            local decoded = {}
            for i = 1, #binary, 8 do
                local byte = binary:sub(i, i + 7)
                if #byte == 8 then
                    local num = tonumber(byte, 2)
                    if num and num > 0 and num < 256 then
                        table.insert(decoded, string.char(num))
                    end
                end
            end

            if #decoded > 0 then
                local result = table.concat(decoded)
                print(string.format("[decode] Invisible Unicode: %d chars -> '%s'", #str, result:sub(1, 50)))
                modified = true
                return result
            end

            return str
        end

        code = code:gsub('local%s+(%w+)%s*=%s*"([^"]*)"', function(varName, str)
            local decoded = decodeInvisibleString(str)
            if decoded ~= str then
                return string.format('local %s = "%s" -- [Decoded from invisible Unicode]', varName, decoded:gsub('"', '\\"'))
            end
            return nil
        end)

        code = code:gsub('"([^"]+)"', function(str)
            if #str > 20 then
                local decoded = decodeInvisibleString(str)
                if decoded ~= str then
                    return string.format('"%s"', decoded:gsub('"', '\\"'))
                end
            end
            return nil
        end)

        code = code:gsub("string%.char%s*%(([^)]+)%)", function(args)
            local success, result = pcall(function()
                local chars = {}
                for num in args:gmatch("%d+") do
                    table.insert(chars, string.char(tonumber(num)))
                end
                modified = true
                return '"' .. table.concat(chars):gsub('"', '\\"') .. '"'
            end)
            if success then return result end
            return nil
        end)

        code = code:gsub("{%s*([%d,%s]+)%s*}", function(bytes)
            local success, result = pcall(function()
                local chars = {}
                for num in bytes:gmatch("%d+") do
                    local n = tonumber(num)
                    if n and n > 0 and n < 256 then
                        table.insert(chars, string.char(n))
                    end
                end
                if #chars > 3 then
                    modified = true
                    return '"' .. table.concat(chars):gsub('"', '\\"') .. '"'
                end
                return nil
            end)
            if success and result then return result end
            return nil
        end)

        code = code:gsub('"([A-Za-z0-9+/=]+)"', function(str)
            if #str > 40 and #str % 4 == 0 and str:match("^[A-Za-z0-9+/]+={0,2}$") then
                return string.format('"%s" --[[Base64: %d bytes]]', str, #str)
            end
            return nil
        end)

    until not modified or iterations >= maxIterations

    if iterations > 1 then
        print(string.format("[decode] Performed %d deobfuscation passes", iterations))
    end

    return code
end

local function fixCommonErrors(code: string): string
    code = code:gsub("(%b{})%s*(%b{})", "%1,%2")

    local inString = false
    local stringChar = nil
    local fixed = {}

    for i = 1, #code do
        local char = code:sub(i, i)
        local prevChar = i > 1 and code:sub(i-1, i-1) or ""

        if (char == '"' or char == "'") and prevChar ~= "\\" then
            if not inString then
                inString = true
                stringChar = char
            elseif char == stringChar then
                inString = false
                stringChar = nil
            end
        end

        table.insert(fixed, char)
    end

    if inString and stringChar then
        table.insert(fixed, stringChar)
    end

    return table.concat(fixed)
end

local function normalizeLuauLocalClosures(code: string): string
    code = code:gsub("^([ \t]*)local%s+([%a_][%w_]*)%s*=%s*function%s*%(", "%1local %2\n%1%2 = function(")
    code = code:gsub("(\r?\n)([ \t]*)local%s+([%a_][%w_]*)%s*=%s*function%s*%(", "%1%2local %3\n%2%3 = function(")
    return code
end

local function repairLuraphTail(code: string): string
    local trimmed = code:gsub("%s+$", "")
    if trimmed:sub(-4) == "(..." then
        return trimmed .. ")"
    end
    return code
end

local function repairMinifiedStatementBoundaries(code: string): string
    return code:gsub("}local%s+", "};local ")
end

local function repairLuraphNumericMinus(code: string): string
    local repairedLines = {}
    local index = 1
    for line, newline in code:gmatch("([^\r\n]*)(\r?\n?)") do
        if line == "" and newline == "" then
            break
        end
        if not line:match("^%s*%-%-") then
            line = line:gsub("%-%-%-(%s*[%(%d])", "- - -%1")
            line = line:gsub("([%w_%)%]%}])%-%-(%s*[%(%d])", "%1- -%2")
        end
        repairedLines[index] = line .. newline
        index += 1
    end
    return table.concat(repairedLines)
end

local function isIdentifierChar(ch: string): boolean
    return ch ~= "" and ch:match("[%w_]") ~= nil
end

local function startsKeyword(source: string, index: number, keyword: string): boolean
    if source:sub(index, index + #keyword - 1) ~= keyword then
        return false
    end

    local prev = index > 1 and source:sub(index - 1, index - 1) or ""
    local nextChar = source:sub(index + #keyword, index + #keyword)
    return not isIdentifierChar(prev) and not isIdentifierChar(nextChar)
end

local function readLongBracketDelimiter(source: string, index: number): (number?, string?)
    if source:sub(index, index) ~= "[" then
        return nil, nil
    end

    local cursor = index + 1
    while source:sub(cursor, cursor) == "=" do
        cursor += 1
    end
    if source:sub(cursor, cursor) ~= "[" then
        return nil, nil
    end

    local equalsCount = cursor - index - 1
    return cursor - index + 1, "]" .. string.rep("=", equalsCount) .. "]"
end

local function appendLongBracket(source: string, out: {string}, index: number): number
    local openLen, closeDelimiter = readLongBracketDelimiter(source, index)
    if not openLen or not closeDelimiter then
        table.insert(out, source:sub(index, index))
        return index + 1
    end

    local closeStart = source:find(closeDelimiter, index + openLen, true)
    if closeStart then
        table.insert(out, source:sub(index, closeStart + #closeDelimiter - 1))
        return closeStart + #closeDelimiter
    end

    table.insert(out, source:sub(index))
    return #source + 1
end

local function appendQuotedString(source: string, out: {string}, index: number): number
    local quote = source:sub(index, index)
    local cursor = index + 1
    local escaped = false
    table.insert(out, quote)

    while cursor <= #source do
        local ch = source:sub(cursor, cursor)
        table.insert(out, ch)

        if escaped then
            escaped = false
        elseif ch == "\\" then
            escaped = true
        elseif ch == quote then
            return cursor + 1
        end

        cursor += 1
    end

    return cursor
end

local function appendComment(source: string, out: {string}, index: number): number
    local longStart = index + 2
    local openLen, closeDelimiter = readLongBracketDelimiter(source, longStart)
    if openLen and closeDelimiter then
        local closeStart = source:find(closeDelimiter, longStart + openLen, true)
        if closeStart then
            table.insert(out, source:sub(index, closeStart + #closeDelimiter - 1))
            return closeStart + #closeDelimiter
        end

        table.insert(out, source:sub(index))
        return #source + 1
    end

    local newline = source:find("\n", index + 2, true)
    if newline then
        table.insert(out, source:sub(index, newline))
        return newline + 1
    end

    table.insert(out, source:sub(index))
    return #source + 1
end

local function skipWhitespace(source: string, index: number): number
    while index <= #source and source:sub(index, index):match("%s") do
        index += 1
    end
    return index
end

local function skipQuotedString(source: string, index: number): number
    local scratch = {}
    return appendQuotedString(source, scratch, index)
end

local function skipLongBracket(source: string, index: number): number
    local scratch = {}
    return appendLongBracket(source, scratch, index)
end

local function skipComment(source: string, index: number): number
    local scratch = {}
    return appendComment(source, scratch, index)
end

local function containsKeywordOutsideLiterals(source: string, keyword: string): boolean
    local index = 1
    while index <= #source do
        local ch = source:sub(index, index)
        if source:sub(index, index + 1) == "--" then
            index = skipComment(source, index)
        elseif ch == '"' or ch == "'" then
            index = skipQuotedString(source, index)
        elseif ch == "[" and readLongBracketDelimiter(source, index) then
            index = skipLongBracket(source, index)
        elseif startsKeyword(source, index, keyword) then
            return true
        else
            index += 1
        end
    end
    return false
end

local function containsStringArithmetic(source: string): boolean
    local operators = {
        ["+"] = true,
        ["-"] = true,
        ["*"] = true,
        ["/"] = true,
        ["%"] = true,
        ["^"] = true,
    }
    local index = 1
    while index <= #source do
        local ch = source:sub(index, index)
        if source:sub(index, index + 1) == "--" then
            index = skipComment(source, index)
        elseif ch == '"' or ch == "'" then
            local stringEnd = skipQuotedString(source, index)
            local before = index - 1
            while before >= 1 and source:sub(before, before):match("%s") do
                before -= 1
            end
            local after = stringEnd
            while after <= #source and source:sub(after, after):match("%s") do
                after += 1
            end
            if operators[source:sub(before, before)] or operators[source:sub(after, after)] then
                return true
            end
            index = stringEnd
        elseif ch == "[" and readLongBracketDelimiter(source, index) then
            index = skipLongBracket(source, index)
        else
            index += 1
        end
    end
    return false
end

local function findLuraphBranchStubEnd(source: string, index: number): number?
    local cursor = index

    while cursor <= #source do
        local ch = source:sub(cursor, cursor)
        if source:sub(cursor, cursor + 1) == "--" then
            cursor = skipComment(source, cursor)
        elseif ch == '"' or ch == "'" then
            cursor = skipQuotedString(source, cursor)
        elseif ch == "[" and readLongBracketDelimiter(source, cursor) then
            cursor = skipLongBracket(source, cursor)
        elseif startsKeyword(source, cursor, "end") then
            local afterEnd = skipWhitespace(source, cursor + 3)
            if source:sub(afterEnd, afterEnd) == "," then
                local afterComma = skipWhitespace(source, afterEnd + 1)
                if startsKeyword(source, afterComma, "function") or source:sub(afterComma, afterComma) == "}" then
                    return cursor + 2
                end
            end
            cursor += 3
        else
            cursor += 1
        end
    end

    return nil
end

local function findLuraphBranchThen(source: string, index: number, stubEnd: number): number?
    local cursor = index

    while cursor <= stubEnd do
        local ch = source:sub(cursor, cursor)
        if source:sub(cursor, cursor + 1) == "--" then
            cursor = skipComment(source, cursor)
        elseif ch == '"' or ch == "'" then
            cursor = skipQuotedString(source, cursor)
        elseif ch == "[" and readLongBracketDelimiter(source, cursor) then
            cursor = skipLongBracket(source, cursor)
        elseif startsKeyword(source, cursor, "then") then
            return skipWhitespace(source, cursor + 4)
        else
            cursor += 1
        end
    end

    return nil
end

local function luraphStubNeedsFunctionEnd(source: string, bodyStart: number, stubEnd: number): boolean
    local cursor = bodyStart
    local finalEndStart = stubEnd - 2
    local balance = 0

    while cursor < finalEndStart do
        local ch = source:sub(cursor, cursor)
        if source:sub(cursor, cursor + 1) == "--" then
            cursor = skipComment(source, cursor)
        elseif ch == '"' or ch == "'" then
            cursor = skipQuotedString(source, cursor)
        elseif ch == "[" and readLongBracketDelimiter(source, cursor) then
            cursor = skipLongBracket(source, cursor)
        elseif startsKeyword(source, cursor, "if") then
            balance += 1
            cursor += 2
        elseif startsKeyword(source, cursor, "for") then
            balance += 1
            cursor += 3
        elseif startsKeyword(source, cursor, "while") then
            balance += 1
            cursor += 5
        elseif startsKeyword(source, cursor, "repeat") then
            balance += 1
            cursor += 6
        elseif startsKeyword(source, cursor, "function") then
            balance += 1
            cursor += #"function"
        elseif startsKeyword(source, cursor, "end") then
            if balance > 0 then
                balance -= 1
            end
            cursor += 3
        elseif startsKeyword(source, cursor, "until") then
            if balance > 0 then
                balance -= 1
            end
            cursor += 5
        else
            cursor += 1
        end
    end

    return balance > 0
end

local function repairLuraphV14BranchStubs(code: string): string
    local out: {string} = {}
    local index = 1

    while index <= #code do
        local ch = code:sub(index, index)
        if code:sub(index, index + 1) == "--" then
            index = appendComment(code, out, index)
        elseif ch == '"' or ch == "'" then
            index = appendQuotedString(code, out, index)
        elseif ch == "[" and readLongBracketDelimiter(code, index) then
            index = appendLongBracket(code, out, index)
        elseif startsKeyword(code, index, "function") then
            local cursor = skipWhitespace(code, index + #"function")
            if code:sub(cursor, cursor) == "(" then
                cursor = skipWhitespace(code, cursor + 1)
                if code:sub(cursor, cursor) == ")" then
                    local bodyStart = skipWhitespace(code, cursor + 1)
                    if startsKeyword(code, bodyStart, "if") then
                        local afterIf = skipWhitespace(code, bodyStart + #"if")
                        if code:sub(afterIf, afterIf) == "(" then
                            local stubEnd = findLuraphBranchStubEnd(code, bodyStart)
                            if stubEnd then
                                if luraphStubNeedsFunctionEnd(code, bodyStart, stubEnd) then
                                    local afterThen = findLuraphBranchThen(code, bodyStart, stubEnd)
                                    if afterThen then
                                        table.insert(out, code:sub(index, bodyStart - 1))
                                        table.insert(out, code:sub(afterThen, stubEnd - 3))
                                        table.insert(out, " end")
                                    else
                                        table.insert(out, code:sub(index, stubEnd))
                                        table.insert(out, " end")
                                    end
                                else
                                    table.insert(out, code:sub(index, stubEnd))
                                end
                                index = stubEnd + 1
                                continue
                            end
                        end
                    elseif startsKeyword(code, bodyStart, "elseif") or startsKeyword(code, bodyStart, "else") then
                        local stubEnd = findLuraphBranchStubEnd(code, bodyStart)
                        if stubEnd then
                            table.insert(out, code:sub(index, bodyStart - 1))
                            if startsKeyword(code, bodyStart, "elseif") then
                                local afterThen = findLuraphBranchThen(code, bodyStart, stubEnd)
                                if afterThen then
                                    table.insert(out, code:sub(afterThen, stubEnd - 3))
                                end
                            else
                                local body = code:sub(skipWhitespace(code, bodyStart + #"else"), stubEnd - 3)
                                table.insert(out, body)
                            end
                            table.insert(out, " end")
                            index = stubEnd + 1
                            continue
                        end
                    end
                end
            end

            table.insert(out, ch)
            index += 1
        else
            table.insert(out, ch)
            index += 1
        end
    end

    return table.concat(out)
end

local function repairLuraphRegisterTableMirrors(code: string): string
    local registerTables: {[string]: boolean} = {}
    for registerTable in code:gmatch("local%s+([%a_][%w_]*)%s*=%s*{}%s*;?%s*local%s+[%a_][%w_]*%s*=%s*{%s*function%(%s*%)%s*%1%[") do
        registerTables[registerTable] = true
    end

    for registerTable in pairs(registerTables) do
        code = code:gsub(
            registerTable .. '%s*%[%s*"([%a_][%w_]*)"%s*%]%s*=',
            function(key: string)
                return key .. "="
            end
        )
    end

    return code
end

local function decodeLuaEscapesForSearch(value: string): string
    local out: {string} = {}
    local index = 1

    while index <= #value do
        local ch = value:sub(index, index)
        if ch ~= "\\" then
            table.insert(out, ch)
            index += 1
            continue
        end

        local nextChar = value:sub(index + 1, index + 1)
        if nextChar == "" then
            table.insert(out, ch)
            index += 1
        elseif nextChar == "z" then
            index += 2
            while index <= #value and value:sub(index, index):match("%s") do
                index += 1
            end
        elseif nextChar == "x" then
            local hex = value:sub(index + 2, index + 3)
            local byte = hex:match("^%x%x$") and tonumber(hex, 16) or nil
            if byte then
                table.insert(out, string.char(byte))
                index += 4
            else
                table.insert(out, nextChar)
                index += 2
            end
        elseif nextChar == "u" and value:sub(index + 2, index + 2) == "{" then
            local close = value:find("}", index + 3, true)
            local codepoint = close and tonumber(value:sub(index + 3, close - 1), 16) or nil
            if close and codepoint then
                local ok, decoded = pcall(utf8.char, codepoint)
                table.insert(out, ok and decoded or "")
                index = close + 1
            else
                table.insert(out, nextChar)
                index += 2
            end
        elseif nextChar:match("%d") then
            local cursor = index + 1
            local digits = ""
            while cursor <= math.min(index + 3, #value) and value:sub(cursor, cursor):match("%d") do
                digits ..= value:sub(cursor, cursor)
                cursor += 1
            end
            local byte = tonumber(digits)
            if byte and byte >= 0 and byte <= 255 then
                table.insert(out, string.char(byte))
            end
            index = cursor
        else
            local escaped = ({
                a = "\a",
                b = "\b",
                f = "\f",
                n = "\n",
                r = "\r",
                t = "\t",
                v = "\v",
                ['"'] = '"',
                ["'"] = "'",
                ["\\"] = "\\",
            })[nextChar] or nextChar
            table.insert(out, escaped)
            index += 2
        end
    end

    return table.concat(out)
end

local function repairLuraphAntiEnvCallbackTables(code: string): string
    local noopCallbacks = "{function(...)return function(...)return end end,function(...)return function(...)return end end,function(...)return function(...)return end end}"
    local search = 1

    while search <= #code do
        local marker = code:find("GetFullName", search, true)
        if not marker then
            break
        end

        local lowerBound = math.max(1, marker - 200000)
        local tableStart: number? = nil
        local cursor = lowerBound
        while cursor < marker do
            local found = code:find("{%s*function%s*%(", cursor)
            if not found or found >= marker then
                break
            end
            tableStart = found
            cursor = found + 1
        end

        local tableEnd = code:find("}%s*,%s*{%s*[%d%-]", marker)
        if tableStart and tableEnd and tableEnd > tableStart and tableEnd - tableStart < 250000 then
            local slice = code:sub(tableStart, tableEnd)
            local decoded = string.lower(decodeLuaEscapesForSearch(slice))
            if decoded:find("getfullname", 1, true) and (
                decoded:find("injection", 1, true)
                or decoded:find("inject ", 1, true)
                or decoded:find("runservice", 1, true)
                or decoded:find("error in error", 1, true)
            ) then
                code = code:sub(1, tableStart - 1) .. noopCallbacks .. code:sub(tableEnd + 1)
                search = tableStart + #noopCallbacks
            else
                search = marker + 1
            end
        else
            search = marker + 1
        end
    end

    return code
end

local function repairLuraphGetterClosureReturns(code: string): string
    return code:gsub(
        "=%s*function%(%s*([%a_][%w_]*)%s*%)%s*([%a_][%w_]*)%s*=%s*getfenv%(%s*%)%s*%[%s*([%a_][%w_]*)%s*%]%s*end%s*,%s*function%(%s*%)%s*return%s+([%a_][%w_]*)%s+end",
        function(arg: string, temp: string, key: string, returned: string)
            if arg == key and temp == returned then
                return string.format("=function(%s)%s=getfenv()[%s];return %s end,function()return %s end", arg, temp, arg, temp, temp)
            end
            return nil
        end
    )
end

local function repairLuraphRuntimeScaffolding(code: string): string
    code = repairLuraphAntiEnvCallbackTables(code)
    code = repairLuraphGetterClosureReturns(code)
    return code
end

local function repairLuraphDispatchGuards(code: string): string
    if not (code:find("Luraph Obfuscator", 1, true) or code:find("LPH", 1, true)) then
        return code
    end

    return code:gsub(
        "xX%[BOo%]%(%s*%)",
        ";(function(__env2_i)local __env2_fn=xX[__env2_i];if type(__env2_fn)==\"function\" then local __env2_ok,__env2_err=pcall(__env2_fn);if not __env2_ok then __env2_luraph_step_error(__env2_i,__env2_err) end else __env2_luraph_step_error(__env2_i,\"missing dispatch\") end end)(BOo)"
    )
end

local function decodeLuaIdentifierLiteral(raw: string): string?
    local decoded = raw:gsub("\\x(%x%x)", function(hex: string)
        return string.char(tonumber(hex, 16) or 0)
    end)
    decoded = decoded:gsub("\\(%d%d?%d?)", function(decimal: string)
        local value = tonumber(decimal)
        if value and value >= 0 and value <= 255 then
            return string.char(value)
        end
        return ""
    end)
    decoded = decoded:gsub('\\"', '"'):gsub("\\'", "'"):gsub("\\\\", "\\")

    if decoded:match("^[%a_][%w_]*$") then
        return decoded
    end
    return nil
end

local function repairGetfenvLiteralGlobals(code: string): string
    return code:gsub('getfenv%(%s*%)%s*%[%s*"([^"]+)"%s*%]', function(raw: string)
        local identifier = decodeLuaIdentifierLiteral(raw)
        if identifier then
            return "(" .. identifier .. ")"
        end
        return nil
    end)
end

local function repairStringMethodProbeTables(code: string): string
    if not code:find("PSU Obfuscator", 1, true) then
        return code
    end

    return code:gsub(
        "local%s+([%a_][%w_]*)%s*,%s*([%a_][%w_]*)%s*,%s*([%a_][%w_]*)%s*=%s*%(%s*{%s*}%s*%)%s*,%s*%(%s*[\"']%s*[\"']%s*%)%s*,",
        function(first: string, probe: string, envName: string)
            return string.format("local %s,%s,%s=({}),(string),", first, probe, envName)
        end
    )
end

local function repairRecursiveLocalFunctionInitializers(code: string): string
    local out = {}
    local index = 1

    while index <= #code do
        local ch = code:sub(index, index)
        if code:sub(index, index + 1) == "--" then
            index = appendComment(code, out, index)
        elseif ch == '"' or ch == "'" then
            index = appendQuotedString(code, out, index)
        elseif ch == "[" and readLongBracketDelimiter(code, index) then
            index = appendLongBracket(code, out, index)
        elseif startsKeyword(code, index, "local") then
            local slice = code:sub(index)
            local full, name = slice:match("^(local%s+([%a_][%w_]*)%s*=%s*function%s*%()")
            if full and name then
                table.insert(out, "local ")
                table.insert(out, name)
                table.insert(out, "; ")
                table.insert(out, name)
                table.insert(out, " = function(")
                index += #full
            else
                table.insert(out, ch)
                index += 1
            end
        else
            table.insert(out, ch)
            index += 1
        end
    end

    return table.concat(out)
end

local function repairGetfenvVersionProbe(code: string): string
    code = code:gsub("getfenv%s*%(%s*%)%s*%.%s*version%s*%(%s*%)", 'error("attempt to call a nil value", 0)')
    return code:gsub("getfenv%s*%(%s*%)%s*%.%s*version", "false")
end

local function repairNilChainedCallProbes(code: string): string
    local function wrap(callName: string, args: string, literal: string): string
        return string.format("(function(...) %s(...); return function() end end)(%s)%s", callName, args, literal)
    end

    code = code:gsub("print%s*%((.-)%)%s*(%[%[.-%]%])", function(args: string, literal: string)
        return wrap("print", args, literal)
    end)
    code = code:gsub("warn%s*%((.-)%)%s*(%[%[.-%]%])", function(args: string, literal: string)
        return wrap("warn", args, literal)
    end)
    return code
end

local function repairLooseDetectorNotes(code: string): string
    return code:gsub("(\r?\n)%s*instead%s+of%s*(\r?\n)", "%1-- instead of%2")
end

local function appendUntilLoopDo(source: string, out: {string}, index: number, label: string): number
    local cursor = index

    while cursor <= #source do
        local ch = source:sub(cursor, cursor)
        if source:sub(cursor, cursor + 1) == "--" then
            cursor = appendComment(source, out, cursor)
        elseif ch == '"' or ch == "'" then
            cursor = appendQuotedString(source, out, cursor)
        elseif ch == "[" and readLongBracketDelimiter(source, cursor) then
            cursor = appendLongBracket(source, out, cursor)
        elseif startsKeyword(source, cursor, "do") then
            table.insert(out, "do ")
            table.insert(out, WATCHDOG_GLOBAL)
            table.insert(out, '("')
            table.insert(out, label)
            table.insert(out, '");')
            return cursor + 2
        else
            table.insert(out, ch)
            cursor += 1
        end
    end

    return cursor
end

local function injectExecutionWatchdog(code: string): string
    if not LIMITS.WATCHDOG_ENABLED then
        return code
    end

    local out: {string} = {
        "local ",
        WATCHDOG_GLOBAL,
        " = ",
        WATCHDOG_GLOBAL,
        ";\n",
    }
    local index = 1

    while index <= #code do
        local ch = code:sub(index, index)
        if code:sub(index, index + 1) == "--" then
            index = appendComment(code, out, index)
        elseif ch == '"' or ch == "'" then
            index = appendQuotedString(code, out, index)
        elseif ch == "[" and readLongBracketDelimiter(code, index) then
            index = appendLongBracket(code, out, index)
        elseif startsKeyword(code, index, "repeat") then
            table.insert(out, "repeat ")
            table.insert(out, WATCHDOG_GLOBAL)
            table.insert(out, '("repeat");')
            index += 6
        elseif startsKeyword(code, index, "while") then
            table.insert(out, "while")
            index = appendUntilLoopDo(code, out, index + 5, "while@" .. tostring(index))
        elseif startsKeyword(code, index, "for") then
            table.insert(out, "for")
            index = appendUntilLoopDo(code, out, index + 3, "for@" .. tostring(index))
        else
            table.insert(out, ch)
            index += 1
        end
    end

    return table.concat(out)
end

local function repairLuraphInvalidBreak(code: string): string
    code = repairLuraphV14BranchStubs(code)
    code = code:gsub(
        "function%(%)(while%s+true%s+do%s+([%a_][%w_]*)%s*=%s*([%a_][%w_]*)%s*%+%s*1%s+end)%s*,",
        function(block: string, lhs: string, rhs: string)
            if lhs == rhs then
                return string.format("function()%s=52 end,", lhs)
            end
            return "function()" .. block .. ","
        end
    )
    code = code:gsub("function%(%)(do%s+local%s+([%a_][%w_]*)%s+end)%s*,", function(_block: string, name: string)
        return string.format("function()%s=nil end,", name)
    end)
    code = code:gsub("function%(%s*%)end%s+end%s+end", "function()end")
    code = code:gsub("function%(%s*%)end%s+end", "function()end")

    local out = {}
    local inString = false
    local quote = ""
    local escaped = false
    local i = 1

    while i <= #code do
        local ch = code:sub(i, i)
        if inString then
            table.insert(out, ch)
            if escaped then
                escaped = false
            elseif ch == "\\" then
                escaped = true
            elseif ch == quote then
                inString = false
            end
            i += 1
        elseif ch == '"' or ch == "'" then
            inString = true
            quote = ch
            table.insert(out, ch)
            i += 1
        elseif code:sub(i, i + 4) == "break" then
            local prev = i > 1 and code:sub(i - 1, i - 1) or ""
            local nextChar = code:sub(i + 5, i + 5)
            if not prev:match("[%w_]") and not nextChar:match("[%w_]") then
                table.insert(out, "return")
                i += 5
            else
                table.insert(out, ch)
                i += 1
            end
        else
            table.insert(out, ch)
            i += 1
        end
    end

    return table.concat(out)
end

local function transformHookOpSource(code: string): (string?, string?)
    hookOpTransformCounter += 1

    local cwd = _process.cwd or "."
    local slash = cwd:find("\\", 1, true) and "\\" or "/"
    local function joinPath(left: string, right: string): string
        if left:sub(-1) == "\\" or left:sub(-1) == "/" then
            return left .. right
        end
        return left .. slash .. right
    end

    local transformerCandidates = {
        joinPath(cwd, "hookop-transform.js"),
        joinPath(joinPath(cwd, ".."), "hookop-transform.js"),
    }
    local transformerPath: string? = nil
    for _, candidate in ipairs(transformerCandidates) do
        if _fs.isFile(candidate) then
            transformerPath = candidate
            break
        end
    end
    if not transformerPath then
        return nil, "hookop-transform.js was not found"
    end

    local tempRoot = _process.env.TEMP or _process.env.TMP or joinPath(cwd, "temp")
    if not _fs.isDir(tempRoot) then
        pcall(_fs.writeDir, tempRoot)
    end
    if not _fs.isDir(tempRoot) then
        return nil, "temporary directory is unavailable"
    end

    local token = string.format(
        "revealr_hookop_%d_%d_%d_%d",
        os.time(),
        math.floor((os.clock() or 0) * 1000000),
        hookOpTransformCounter,
        math.random(0, 0x7fffffff)
    )
    local inputPath = joinPath(tempRoot, token .. ".lua")
    local outputPath = joinPath(tempRoot, token .. ".hooked.lua")

    local ok, transformedOrError = pcall(function()
        _fs.writeFile(inputPath, code)
        local result = _process.exec("node", {
            transformerPath :: string,
            inputPath,
            outputPath,
        })
        if not result.ok or not _fs.isFile(outputPath) then
            local detail = result.stderr ~= "" and result.stderr or result.stdout
            error(detail ~= "" and detail or "operator transformer failed", 0)
        end
        return _fs.readFile(outputPath)
    end)

    pcall(_fs.removeFile, inputPath)
    pcall(_fs.removeFile, outputPath)

    if not ok then
        return nil, tostring(transformedOrError)
    end

    local transformed = transformedOrError :: string
    if transformed == "" then
        return nil, "operator transformer returned empty source"
    end
    return transformed, nil
end

local function advancedLoad(code: string, chunkname: string, env: any, hookOperators: boolean?): (any?, string?)
    code = stripUtf8Bom(code)
    local traceLoad = process.env.ENV2_TRACE_LOAD and process.env.ENV2_TRACE_LOAD ~= ""
    local traceStart = os.clock()
    local function traceLoadStep(name: string)
        if traceLoad then
            print(string.format("[env2 load] %.3fs %s", os.clock() - traceStart, name))
        end
    end

    traceLoadStep("raw-repair:start")
    local rawCode = repairLuraphRuntimeScaffolding(code)
    rawCode = repairLuraphDispatchGuards(rawCode)
    rawCode = repairStringMethodProbeTables(rawCode)
    rawCode = repairRecursiveLocalFunctionInitializers(rawCode)
    rawCode = repairGetfenvVersionProbe(rawCode)
    rawCode = repairNilChainedCallProbes(rawCode)
    rawCode = repairLooseDetectorNotes(rawCode)
    traceLoadStep("raw-repair:done")
    traceLoadStep("raw-instrument:start")
    local rawInstrumentedCode = injectExecutionWatchdog(rawCode)
    traceLoadStep("raw-instrument:done")

    traceLoadStep("normalize:start")
    local normalizedCode = repairLuraphNumericMinus(code)
    traceLoadStep("normalize:numeric-minus")
    normalizedCode = repairMinifiedStatementBoundaries(normalizedCode)
    traceLoadStep("normalize:statement-boundaries")
    normalizedCode = normalizeLuauLocalClosures(normalizedCode)
    traceLoadStep("normalize:local-closures")
    normalizedCode = repairLuraphTail(normalizedCode)
    traceLoadStep("normalize:luraph-tail")
    normalizedCode = repairGetfenvLiteralGlobals(normalizedCode)
    traceLoadStep("normalize:getfenv-literals")
    normalizedCode = repairStringMethodProbeTables(normalizedCode)
    traceLoadStep("normalize:string-method-probes")
    normalizedCode = repairRecursiveLocalFunctionInitializers(normalizedCode)
    traceLoadStep("normalize:recursive-local-functions")
    normalizedCode = repairGetfenvVersionProbe(normalizedCode)
    traceLoadStep("normalize:getfenv-version-probe")
    normalizedCode = repairNilChainedCallProbes(normalizedCode)
    traceLoadStep("normalize:nil-chained-call-probes")
    normalizedCode = repairLooseDetectorNotes(normalizedCode)
    traceLoadStep("normalize:detector-notes")
    normalizedCode = repairLuraphRegisterTableMirrors(normalizedCode)
    traceLoadStep("normalize:register-mirrors")
    normalizedCode = repairLuraphRuntimeScaffolding(normalizedCode)
    traceLoadStep("normalize:runtime-scaffolding")
    normalizedCode = repairLuraphDispatchGuards(normalizedCode)
    traceLoadStep("normalize:dispatch-guards")

    traceLoadStep("instrument:start")
    local instrumentedCode = injectExecutionWatchdog(normalizedCode)
    traceLoadStep("instrument:done")
    local luraphCompatCode: string? = nil
    local function getLuraphCompatCode(): string
        if not luraphCompatCode then
            traceLoadStep("compat:start")
            luraphCompatCode = injectExecutionWatchdog(repairLuraphInvalidBreak(normalizedCode))
            traceLoadStep("compat:done")
            if process.env.ENV2_DEBUG_NORMALIZED and process.env.ENV2_DEBUG_NORMALIZED ~= "" then
                pcall(function()
                    fs.writeFile(process.env.ENV2_DEBUG_NORMALIZED .. ".compat.lua", luraphCompatCode :: string)
                end)
            end
        end
        return luraphCompatCode :: string
    end
    if process.env.ENV2_DEBUG_NORMALIZED and process.env.ENV2_DEBUG_NORMALIZED ~= "" then
        pcall(function()
            fs.writeFile(process.env.ENV2_DEBUG_NORMALIZED .. ".raw.lua", rawInstrumentedCode)
            fs.writeFile(process.env.ENV2_DEBUG_NORMALIZED .. ".instrumented.lua", instrumentedCode)
        end)
    end
    local useHookOperators = hookOperators == true
    local hookOpCache: {[string]: string} = {}
    local function loadCandidate(candidate: string, strategyLabel: string)
        local source = candidate
        if useHookOperators then
            local cached = hookOpCache[candidate]
            if cached then
                source = cached
            else
                traceLoadStep("hookop:" .. strategyLabel .. ":start")
                local transformed, transformErr = transformHookOpSource(candidate)
                traceLoadStep("hookop:" .. strategyLabel .. ":done")
                if not transformed then
                    return nil, "hookOp transform failed: " .. tostring(transformErr)
                end
                hookOpCache[candidate] = transformed
                source = transformed
            end
        end
        return _luau.load(source, {
            debugName = chunkname,
            environment = env,
        })
    end
    local strategies = {
        function()
            return loadCandidate(rawInstrumentedCode, "raw")
        end,

        function()
            return loadCandidate(instrumentedCode, "normalized")
        end,

        function()
            return loadCandidate(getLuraphCompatCode(), "compat")
        end,

        function()
            traceLoadStep("strategy:3:sanitize:start")
            local sanitized = sanitizeLuauSyntax(instrumentedCode)
            traceLoadStep("strategy:3:sanitize:done")
            return loadCandidate(sanitized, "sanitized")
        end,

        function()
            traceLoadStep("strategy:4:deobfuscate:start")
            local deobf = deobfuscateStrings(instrumentedCode)
            traceLoadStep("strategy:4:deobfuscate:done")
            traceLoadStep("strategy:4:sanitize:start")
            local sanitized = sanitizeLuauSyntax(deobf)
            traceLoadStep("strategy:4:sanitize:done")
            return loadCandidate(sanitized, "deobfuscated")
        end,

        function()
            traceLoadStep("strategy:5:fix:start")
            local fixed = fixCommonErrors(instrumentedCode)
            traceLoadStep("strategy:5:fix:done")
            traceLoadStep("strategy:5:sanitize:start")
            local sanitized = sanitizeLuauSyntax(fixed)
            traceLoadStep("strategy:5:sanitize:done")
            return loadCandidate(sanitized, "fixed")
        end,

        function()
            traceLoadStep("strategy:6:fix:start")
            local fixed = fixCommonErrors(instrumentedCode)
            traceLoadStep("strategy:6:fix:done")
            traceLoadStep("strategy:6:deobfuscate:start")
            local deobf = deobfuscateStrings(fixed)
            traceLoadStep("strategy:6:deobfuscate:done")
            traceLoadStep("strategy:6:sanitize:start")
            local sanitized = sanitizeLuauSyntax(deobf)
            traceLoadStep("strategy:6:sanitize:done")
            return loadCandidate(sanitized, "fixed-deobfuscated")
        end,
    }

    local lastError = nil
    local loadErrors = {}
    for i, strategy in ipairs(strategies) do
        traceLoadStep(string.format("strategy:%d:start", i))
        local success, chunk, err = pcall(strategy)
        traceLoadStep(string.format("strategy:%d:done", i))
        if success and chunk then
            if i > 1 then
                print(string.format("[load] Strategy %d succeeded", i))
            end
            return chunk, nil
        end
        if success then
            lastError = err or "load returned nil"
        else
            lastError = chunk
        end
        if traceLoad then
            print(string.format("[env2 load] strategy:%d:error %s", i, tostring(lastError):sub(1, 240)))
        end
        table.insert(loadErrors, string.format("strategy %d: %s", i, tostring(lastError)))
    end

    return nil, table.concat(loadErrors, " | ")
end

local loadedChunks: {string} = {}
local loadedChunkSeen: {[string]: number} = {}

local RCE_PATTERNS = {
    {pattern = "@lune/fs", severity = "CRITICAL"},
    {pattern = "@lune/process", severity = "CRITICAL"},
    {pattern = "@lune/net", severity = "CRITICAL"},
    {pattern = "@lute/fs", severity = "CRITICAL"},
    {pattern = "@lute/process", severity = "CRITICAL"},
    {pattern = "@lute/net", severity = "CRITICAL"},
    {pattern = "process%.spawn", severity = "CRITICAL"},
    {pattern = "process%.exit", severity = "CRITICAL"},
    {pattern = "fs%.readFile", severity = "CRITICAL"},
    {pattern = "fs%.writeFile", severity = "CRITICAL"},
    {pattern = "fs%.removeFile", severity = "CRITICAL"},

    {pattern = "bot%.js", severity = "CRITICAL"},
    {pattern = "config%.json", severity = "CRITICAL"},
    {pattern = "database%.json", severity = "CRITICAL"},
    {pattern = "%.env", severity = "CRITICAL"},
    {pattern = "package%.json", severity = "CRITICAL"},

    {pattern = "%.%.%/%.%.%/", severity = "CRITICAL"},

    {pattern = "io%.popen%s*%(", severity = "CRITICAL"},
    {pattern = "os%.execute%s*%(", severity = "CRITICAL"},
    {pattern = "os%.remove%s*%(", severity = "CRITICAL"},
    {pattern = "os%.rename%s*%(", severity = "CRITICAL"},

    {pattern = 'require%s*%(%s*["\']@lune/', severity = "CRITICAL"},
    {pattern = 'require%s*%(%s*["\']@lute/', severity = "CRITICAL"},

    {pattern = "package%.loaded", severity = "CRITICAL"},

    {pattern = "api%.ipify%.org", severity = "CRITICAL"},
    {pattern = "ipify%.org", severity = "CRITICAL"},
    {pattern = "api%.ip%.sb", severity = "CRITICAL"},
    {pattern = "ipinfo%.io", severity = "CRITICAL"},
    {pattern = "ip%-api%.com", severity = "CRITICAL"},
    {pattern = "ifconfig%.me", severity = "CRITICAL"},
    {pattern = "icanhazip%.com", severity = "CRITICAL"},
    {pattern = "ident%.me", severity = "CRITICAL"},
    {pattern = "whatismyip%.com", severity = "CRITICAL"},
    {pattern = "myexternalip%.com", severity = "CRITICAL"},
    {pattern = "checkip%.amazonaws%.com", severity = "CRITICAL"},
    {pattern = "ipecho%.net", severity = "CRITICAL"},
    {pattern = "ip%.42%.pl", severity = "CRITICAL"},
    {pattern = "wtfismyip%.com", severity = "CRITICAL"},
    {pattern = "iplogger%.org", severity = "CRITICAL"},
    {pattern = "grabify%.link", severity = "CRITICAL"},
    {pattern = "iplogger%.com", severity = "CRITICAL"},
    {pattern = "2no%.co", severity = "CRITICAL"},
    {pattern = "yip%.su", severity = "CRITICAL"},
    {pattern = "blasze%.tk", severity = "CRITICAL"},
    {pattern = "blasze%.com", severity = "CRITICAL"},
    {pattern = "ps3cfw%.com", severity = "CRITICAL"},
    {pattern = "curiouscat%.club", severity = "CRITICAL"},
    {pattern = "catsnthings%.fun", severity = "CRITICAL"},
    {pattern = "joinmy%.site", severity = "CRITICAL"},
    {pattern = "leancoding%.co", severity = "CRITICAL"},
    {pattern = "spottyfly%.com", severity = "CRITICAL"},
    {pattern = "stopify%.co", severity = "CRITICAL"},
    {pattern = "freegiftcards%.co", severity = "CRITICAL"},
    {pattern = "disÃƒÂ§ordapp%.com", severity = "CRITICAL"},
    {pattern = "minecrÃƒÂ¤ft%.com", severity = "CRITICAL"},
    {pattern = "sÃƒÂ¤rahah%.eu", severity = "CRITICAL"},
    {pattern = "fortnight%.space", severity = "CRITICAL"},
    {pattern = "yoÃƒÂ¼tu%.be", severity = "CRITICAL"},
    {pattern = "bit%.ly", severity = "CRITICAL"},
    {pattern = "tinyurl%.com", severity = "CRITICAL"},
    {pattern = "goo%.gl", severity = "CRITICAL"},
    {pattern = "ow%.ly", severity = "CRITICAL"},
    {pattern = "://t%.co/", severity = "CRITICAL"},
    {pattern = "discord%.gift", severity = "CRITICAL"},
    {pattern = "steamcommunity%.ru", severity = "CRITICAL"},
    {pattern = "steancommunity%.com", severity = "CRITICAL"},
    {pattern = "discordapp%.ru", severity = "CRITICAL"},
    {pattern = "discÃƒÂ¶rd%.com", severity = "CRITICAL"},

    {pattern = "loadfile%s*%(", severity = "HIGH"},
    {pattern = "dofile%s*%(", severity = "HIGH"},
}

local function detectRCE(code: string): (boolean, string?)
    for _, rule in ipairs(RCE_PATTERNS) do
        if rule.severity == "CRITICAL" and code:find(rule.pattern) then
            return true, rule.pattern
        end
    end

    local concatenationPatterns = {
        '_G%s*%[%s*"[^"]*"%s*%.%.',
        '_G%s*%[%s*string%.char',
        '_G%s*%[%s*%([^)]*%)%s*%]',
        'getfenv%s*%(%s*%)%s*%[',
        'getrenv%s*%(%s*%)%s*%[',
        'getgenv%s*%(%s*%)%s*%[',
        'getsenv%s*%(%s*%)%s*%[',
        '%[%s*string%.char%s*%(',
        '%[%s*string%.byte%s*%(',
        '%[%s*%(%s*"[^"]*"%s*%.%.',
        'rawget%s*%(%s*_G%s*,',
        'rawget%s*%(%s*getfenv',
        'rawget%s*%(%s*getrenv',
    }

    for _, pattern in ipairs(concatenationPatterns) do
        if code:find(pattern) then
            return true, "String concatenation bypass: " .. pattern
        end
    end

    local dangerousBytes = {
        {pattern = "string%.char%s*%(%s*105%s*,%s*111%s*%)", name = "io"},
        {pattern = "string%.char%s*%(%s*111%s*,%s*115%s*%)", name = "os"},
        {pattern = "string%.char%s*%(%s*112%s*,%s*97%s*,%s*99%s*,%s*107%s*,%s*97%s*,%s*103%s*,%s*101%s*%)", name = "package"},
        {pattern = "string%.char%s*%(%s*100%s*,%s*101%s*,%s*98%s*,%s*117%s*,%s*103%s*%)", name = "debug"},
        {pattern = "string%.char%s*%(%s*0x69%s*,%s*0x6f%s*%)", name = "io (hex)"},
        {pattern = "string%.char%s*%(%s*0x6f%s*,%s*0x73%s*%)", name = "os (hex)"},
        {pattern = '["\']\105\111["\']', name = "io (octal escape)"},
        {pattern = '["\']\111\115["\']', name = "os (octal escape)"},
    }

    for _, dangerous in ipairs(dangerousBytes) do
        if code:find(dangerous.pattern) then
            return true, "Byte-encoded dangerous string: " .. dangerous.name
        end
    end

    local base64Patterns = {
        "cmVxdWlyZQ",
        "bG9hZGZpbGU",
        "ZG9maWxl",
        "cGFja2FnZQ",
    }

    for _, b64 in ipairs(base64Patterns) do
        if code:find(b64, 1, true) then
            return true, "Base64 encoded dangerous function: " .. b64
        end
    end

    local httpPatterns = {
        'HttpGet%s*%(',
        'GetAsync%s*%(',
        'PostAsync%s*%(',
        'RequestAsync%s*%(',
        'request%s*%(',
        'http_request%s*%(',
        'syn%.request%s*%(',
        'http%.request%s*%(',
        'game%.HttpGet%s*%(',
        'game%.HttpPost%s*%(',
    }

    for _, pattern in ipairs(httpPatterns) do
        if code:find(pattern) then
            for _, rule in ipairs(RCE_PATTERNS) do
                if rule.pattern:match("%.") and code:find(rule.pattern) then
                    return true, "HTTP request to IP grabber: " .. pattern .. " + " .. rule.pattern
                end
            end
        end
    end

    local hasHighRisk = false
    local highRiskPattern = nil

    for _, rule in ipairs(RCE_PATTERNS) do
        if rule.severity == "HIGH" and code:find(rule.pattern) then
            hasHighRisk = true
            highRiskPattern = rule.pattern
            break
        end
    end

    if hasHighRisk then
        local suspiciousFiles = {
            "bot", "config", "database", "%.env", "password", "token", "secret",
            "%.%.%/",
            "%.%.\\",
        }

        for _, filePattern in ipairs(suspiciousFiles) do
            if code:find(filePattern) then
                return true, highRiskPattern .. " + " .. filePattern
            end
        end
    end

    return false, nil
end

local rceWarningsSeen: {[string]: boolean} = {}

local function rceAlert(pattern: string?)
    local key = pattern or ""
    if rceWarningsSeen[key] then
        return
    end
    rceWarningsSeen[key] = true
    print("[env2 warning] suspicious static pattern ignored; continuing in sandbox")
    if pattern then
        print("[env2 warning] pattern: " .. pattern)
    end
    return
end


type Variable = {
    id: string,
    type: string,
    value: any?,
    parent: string?,
    properties: {[string]: any},
    methods: {[string]: string},
}

type APICall = {
    type: string,
    code: string,
    varId: string?,
    timestamp: number,
    stackDepth: number?,
    parentCall: number?,
}

type LoadedChunkInfo = {
    name: string,
    originalSize: number,
    processedSize: number,
    features: {string},
    passes: {string},
    securityFlags: {string},
    preview: string,
    processedPreview: string,
}

type ExternalTraceEvent = {
    kind: string,
    detail: string,
}

type ExternalTraceSuppression = {
    kind: string,
    detail: string,
    key: string,
    kept: number,
    count: number,
}

type StaticHint = {
    kind: string,
    value: string,
}

type StaticEnumType = {
    order: {string},
    values: {[string]: number},
}

type RepeatSuppression = {
    type: string,
    key: string,
    sample: string,
    count: number,
}

type LoadedChunkRepeat = {
    name: string,
    originalSize: number,
    processedSize: number,
    count: number,
    preview: string,
}

local variables: {[string]: Variable} = {}
local apiCalls: {APICall} = {}
local apiRepeatCounts: {[string]: number} = {}
local apiRepeatSuppressions: {[string]: RepeatSuppression} = {}
local apiRepeatOrder: {string} = {}
local externalTraceEvents: {ExternalTraceEvent} = {}
local externalTraceRepeatCounts: {[string]: number} = {}
local externalTraceSuppressions: {[string]: ExternalTraceSuppression} = {}
local externalTraceSuppressionOrder: {string} = {}
local externalTraceResult: string? = nil
local externalTraceSteps = 0
local externalTraceDropped = 0
local externalTraceLimit = math.max(
    1000,
    math.floor(tonumber(process.env.ENV2_EXTERNAL_TRACE_LIMIT or "") or 500000)
)
local externalTraceRepeatLimit = math.max(
    1,
    math.floor(tonumber(process.env.ENV2_EXTERNAL_TRACE_REPEAT_LIMIT or "") or 8)
)
local externalTraceSuppressionLimit = math.max(
    16,
    math.floor(tonumber(process.env.ENV2_EXTERNAL_TRACE_SUPPRESSION_LIMIT or "") or 1000)
)
local varCounter = 0
local proxyRegistry: {[any]: string} = {}
local proxyTypeNames: {[any]: string} = {}
local objectTypeNames: {[any]: string} = setmetatable({}, {__mode = "k"})
local frozenDataTables: {[any]: boolean} = setmetatable({}, {__mode = "k"})
local frozenDataTableCount = 0
local instanceChildren: {[any]: {[any]: boolean}} = setmetatable({}, {__mode = "k"})
local instanceSignals: {[any]: any} = setmetatable({}, {__mode = "k"})
local signalEmitters: {[any]: (...any) -> ()} = setmetatable({}, {__mode = "k"})
local collectionTagStore: {[any]: {[string]: boolean}} = setmetatable({}, {__mode = "k"})
local proxyLRU: {any} = {}
local serviceMap: {[string]: string} = {}
local connectionMap: {[string]: {event: string, callback: string}} = {}
local propertySetters: {{target: string, property: string, value: any}} = {}
local instanceOrder: {string} = {}
local enumValues: {[string]: string} = {}
local waitForChildPumpTasks: ((number?) -> ())? = nil
local callStack: {string} = {}
local functionCalls: {{func: string, args: {string}, result: string?}} = {}
local stringPatterns: {{pattern: string, decoded: string}} = {}
local computedValues: {[string]: any} = {}
local decodedStringSeen: {[string]: boolean} = {}
local decodedStringValues: {string} = {}
local clipboardValues: {string} = {}
local clipboardSeen: {[string]: boolean} = {}
local reportLines: {string} = {}
local reportLineSeen: {[string]: boolean} = {}
local reportPayloadSeen: {[string]: boolean} = {}
local staticHintValues: {StaticHint} = {}
local staticHintSeen: {[string]: boolean} = {}
local getfenvCalls: {{level: any, result: string}} = {}
local setfenvCalls: {{func: string, env: string}} = {}
local pcallCount = 0
local prometheusPcallCompat = false
local loadedChunkInfo: {LoadedChunkInfo} = {}
local loadedChunkRepeats: {LoadedChunkRepeat} = {}
local loadedChunkRepeatIndex: {[string]: number} = {}
local logAPICall

local function normalizeProtectedError(err: any): any
    if type(err) ~= "string" then
        return err
    end

    local errorMsg = err

    if prometheusPcallCompat then
        return errorMsg:gsub(":(%d+)([:\r\n])", ":1%2"):gsub("^%s*", "")
    end

    errorMsg = errorMsg:gsub("[A-Za-z]:\\[^:]+:", "")
    errorMsg = errorMsg:gsub("/[^:]+:", "")
    errorMsg = errorMsg:gsub("\\\\%?\\[^:]+:", "")
    errorMsg = errorMsg:gsub("%[string \"[^\"]+\"%]", "[string \"Script\"]")
    errorMsg = errorMsg:gsub("temp\\[^:]+:", "")
    errorMsg = errorMsg:gsub("temp/[^:]+:", "")

    return errorMsg:gsub("^%s*", "")
end

local function newVarId(): string
    if not checkLimit("variables", LIMITS.MAX_VARIABLES) then
        local oldest = next(variables)
        if oldest then
            variables[oldest] = nil
            RESOURCE_USAGE.variables = RESOURCE_USAGE.variables - 1
        end
    end
    varCounter += 1
    RESOURCE_USAGE.variables = RESOURCE_USAGE.variables + 1
    return string.format("L_%d", varCounter)
end

local function escapeLuaString(value: string): string
    value = value
        :gsub("\\", "\\\\")
        :gsub('"', '\\"')
        :gsub("\n", "\\n")
        :gsub("\r", "\\r")
        :gsub("\t", "\\t")

    return (value:gsub("[\0-\31\127-\255]", function(char)
        return string.format("\\x%02X", string.byte(char))
    end))
end

local function escapeLogText(value: string): string
    value = value:gsub("\r\n", "\n"):gsub("\r", "\n"):gsub("\n", "\\n")
    return (value:gsub("[\0-\31\127-\255]", function(char)
        return string.format("\\x%02X", string.byte(char))
    end))
end

local function formatValue(value: any): string
    local function formatNested(current: any, depth: number, seen: {[any]: boolean}): string
        if proxyRegistry[current] then
            return proxyRegistry[current]
        end

        local currentType = typeof(current)
        if currentType == "string" then
            local text = current
            if #text > 512 then
                text = text:sub(1, 509) .. "..."
            end
            return string.format('"%s"', escapeLuaString(text))
        elseif currentType == "number" or currentType == "boolean" then
            return tostring(current)
        elseif currentType == "nil" then
            return "nil"
        elseif currentType == "function" then
            return "function(...) end"
        elseif currentType == "thread" then
            return "thread"
        elseif currentType == "userdata" then
            return proxyTypeNames[current] or "userdata"
        elseif currentType ~= "table" then
            return tostring(current)
        end

        if seen[current] then
            return "{__cycle = true}"
        end
        if depth >= 2 then
            return "{__table = true}"
        end

        seen[current] = true
        local entries: {string} = {}
        local key = nil
        local count = 0
        while count < 10 do
            local nextKey, nextValue = next(current, key)
            if nextKey == nil then
                break
            end
            key = nextKey
            count += 1

            local keyText
            if type(nextKey) == "string" and nextKey:match("^[A-Za-z_][A-Za-z0-9_]*$") then
                keyText = nextKey
            else
                keyText = "[" .. formatNested(nextKey, depth + 1, seen) .. "]"
            end
            table.insert(entries, keyText .. " = " .. formatNested(nextValue, depth + 1, seen))
        end

        local hasMore = next(current, key) ~= nil
        seen[current] = nil
        if hasMore then
            table.insert(entries, "__more = true")
        end
        return "{" .. table.concat(entries, ", ") .. "}"
    end

    return formatNested(value, 0, {})
end

local function byteArrayToString(value: any): string?
    if type(value) ~= "table" then
        return nil
    end

    local bytes = rawget(value, "__bytes")
    local source = type(bytes) == "table" and bytes or value
    local out = {}
    local count = 0
    local maxBytes = math.min(#source, LIMITS.MAX_CHUNK_SIZE)

    for i = 1, maxBytes do
        local byte = rawget(source, i)
        if byte == nil then
            break
        elseif type(byte) == "number" then
            count += 1
            out[count] = string.char(math.floor(byte) % 256)
        elseif type(byte) == "string" and #byte == 1 then
            count += 1
            out[count] = byte
        else
            return nil
        end
    end

    if count == 0 then
        return nil
    end

    return table.concat(out)
end

local function safeToString(value: any): string
    local ok, result = pcall(tostring, value)
    if ok then
        return result
    end
    return formatValue(value)
end

local function addReportLine(line: string)
    if line == "" or reportLineSeen[line] then
        return
    end
    reportLineSeen[line] = true
    table.insert(reportLines, line)
end

local function summarizePackedEuncReport(payload: string)
    if reportPayloadSeen[payload] then
        return
    end
    reportPayloadSeen[payload] = true

    local rest = payload
    local envName, afterEnv = payload:match("^([^|]+)|(.+)$")
    if envName and afterEnv then
        rest = afterEnv
    end

    local passed = 0
    local failed = 0
    local failures: {string} = {}

    for entry in rest:gmatch("([^,]+)") do
        local name, status, reason = entry:match("^(.-)|([01])|(.*)$")
        if name and status then
            if status == "1" then
                passed += 1
            else
                failed += 1
                local suffix = reason ~= "" and (" ~ " .. reason) or ""
                table.insert(failures, string.format("[ FAIL ] - %s%s", name, suffix))
            end
        end
    end

    local total = passed + failed
    if total == 0 then
        return
    end
    if total < (RESOURCE_USAGE.reportBestTotal or 0) then
        return
    end

    RESOURCE_USAGE.reportBestTotal = total
    reportLines = {}
    reportLineSeen = {}

    local percent = math.floor((passed / total) * 100)
    addReportLine(string.format("[eUNC] Score : %d / %d  (%d%%)", passed, total, percent))
    addReportLine(string.format("[eUNC] Passed: %d  |  Failed: %d", passed, failed))
    for _, failure in ipairs(failures) do
        addReportLine(failure)
    end
end

local function recordReportValue(value: any)
    if type(value) ~= "string" then
        return
    end

    if value:find("Synapse X (ENV)|", 1, true)
        or (value:find("|0|", 1, true) and value:find("|1|", 1, true) and value:find("failed", 1, true)) then
        summarizePackedEuncReport(value)
        return
    end

end

local function isUsefulDecodedString(value: any, minLen: number?): boolean
    if type(value) ~= "string" then
        return false
    end

    local len = #value
    if len < (minLen or 3) or len > 240 then
        return false
    end

    return value:match("[%w_]") ~= nil and value:match("[\0-\8\11\12\14-\31]") == nil
end

local function logDecodedString(value: string, source: string, minLen: number?)
    if not isUsefulDecodedString(value, minLen) or decodedStringSeen[value] then
        return
    end

    decodedStringSeen[value] = true
    table.insert(decodedStringValues, value)
end

local function recordClipboardValue(value: any)
    local text = tostring(value or "")
    if text == "" or clipboardSeen[text] then
        return
    end
    clipboardSeen[text] = true
    table.insert(clipboardValues, text)
    if text:find("e-unc.vercel.app", 1, true) then
        print("[clipboard] " .. text)
    end
end

local function traceRepeatKey(callType: string, code: string): string?
    local url = code:match("(https?://[^%s%)%,\"']+)")
    if url then
        return "url:" .. url
    end

    if code:match("^load%s*%(") or code:match("^loadstring%s*%(") then
        return "load:dynamic"
    end

    if code:match("^request%s*%(")
        or code:match("^http_request%s*%(")
        or code:match("^syn%.request%s*%(")
        or code:match("^http%.request%s*%(")
        or code:match("^game%.Http") then
        return "http:" .. code:gsub("%b{}", "{}"):gsub("L_%d+", "L_*")
    end

    if code:match("^getfenv%s*%(")
        or code:match("^setfenv%s*%(")
        or code:match("^debug%.getinfo%s*%(")
        or (code:match("^type%({") and code:find("function(...) end", 1, true))
        or code:match("^typeof%s*%(")
        or code:match("^type%s*%(") then
        if code:match("^type%({") then
            return "probe:type(table)"
        end
        return "probe:" .. code:gsub("L_%d+", "L_*")
    end

    if callType == "security_block" and code:match("excessive") then
        return "block:" .. code
    end

    return nil
end

local function noteSuppressedTrace(key: string, callType: string, sample: string)
    local entry = apiRepeatSuppressions[key]
    if entry then
        entry.count += 1
        return
    end

    apiRepeatSuppressions[key] = {
        type = callType,
        key = key,
        sample = sample,
        count = 1,
    }
    table.insert(apiRepeatOrder, key)
end

local function externalTraceRepeatKey(kind: string, detail: string): string
    local normalizedDetail = escapeLogText(detail or "")
    normalizedDetail = normalizedDetail:gsub("0x%x+", "0x*")
    normalizedDetail = normalizedDetail:gsub("count=%d+", "count=*")
    normalizedDetail = normalizedDetail:gsub("step=%d+", "step=*")
    normalizedDetail = normalizedDetail:gsub("function: 0x%*", "function:0x*")
    normalizedDetail = normalizedDetail:gsub("table: 0x%*", "table:0x*")
    normalizedDetail = normalizedDetail:gsub("thread: 0x%*", "thread:0x*")
    if #normalizedDetail > 1200 then
        normalizedDetail = normalizedDetail:sub(1, 1200)
    end
    return tostring(kind) .. "\t" .. normalizedDetail
end

local function noteSuppressedExternalTrace(key: string, kind: string, detail: string)
    local entry = externalTraceSuppressions[key]
    if entry then
        entry.count += 1
        return
    end

    if #externalTraceSuppressionOrder >= externalTraceSuppressionLimit then
        return
    end

    externalTraceSuppressions[key] = {
        kind = kind,
        detail = detail,
        key = key,
        kept = externalTraceRepeatLimit,
        count = 1,
    }
    table.insert(externalTraceSuppressionOrder, key)
end

local function registerVariable(varId: string, varType: string, value: any?, parent: string?): Variable
    local var: Variable = {
        id = varId,
        type = varType,
        value = value,
        parent = parent,
        properties = {},
        methods = {},
    }
    variables[varId] = var
    return var
end

function logAPICall(callType: string, code: string, varId: string?)
    if not checkLimit("apiCalls", LIMITS.MAX_API_CALLS) then
        local toRemove = math.floor(LIMITS.MAX_API_CALLS * 0.1)
        for i = 1, toRemove do
            table.remove(apiCalls, 1)
        end
        RESOURCE_USAGE.apiCalls = #apiCalls
    end

    local normalizedCode = escapeLogText(code)
    if #normalizedCode > 1200 then
        normalizedCode = "trace_event_truncated(" .. formatValue(normalizedCode:sub(1, 1168) .. "...") .. ")"
    end

    local repeatKey = traceRepeatKey(callType, normalizedCode)
    if repeatKey then
        local repeatCount = (apiRepeatCounts[repeatKey] or 0) + 1
        apiRepeatCounts[repeatKey] = repeatCount
        if repeatCount > LIMITS.REPEAT_TRACE_LIMIT then
            noteSuppressedTrace(repeatKey, callType, normalizedCode)
            return
        end
    end

    table.insert(apiCalls, {
        type = callType,
        code = normalizedCode,
        varId = varId,
        timestamp = os.clock(),
        stackDepth = #callStack,
        parentCall = #apiCalls > 0 and #apiCalls or nil,
    })
    RESOURCE_USAGE.apiCalls = RESOURCE_USAGE.apiCalls + 1
end

local function runLua54Trace(inputFile: string): (boolean, boolean, string?)
    local cwd = _process.cwd or "."
    local separator = tostring(cwd):find("\\", 1, true) and "\\" or "/"
    local function joinPath(left: string, right: string): string
        if left:sub(-1) == "\\" or left:sub(-1) == "/" then
            return left .. right
        end
        return left .. separator .. right
    end

    local runnerCandidates = {
        joinPath(tostring(cwd), "lua54-trace.lua"),
        joinPath(joinPath(tostring(cwd), ".."), "lua54-trace.lua"),
    }
    local runnerPath: string? = nil
    for _, candidate in ipairs(runnerCandidates) do
        if _fs.isFile(candidate) then
            runnerPath = candidate
            break
        end
    end
    if not runnerPath then
        return false, false, "lua54-trace.lua was not found"
    end

    local commands = {}
    if process.env.ENV2_LUA54 and process.env.ENV2_LUA54 ~= "" then
        table.insert(commands, process.env.ENV2_LUA54)
    end
    table.insert(commands, "lua")
    if _fs.isFile("C:\\lua\\lua.exe") then
        table.insert(commands, "C:\\lua\\lua.exe")
    end

    local lastError = "Lua 5.4 executable was not found"
    for _, command in ipairs(commands) do
        local ok, result = pcall(function()
            return _process.exec(command, {runnerPath :: string, inputFile})
        end)
        if ok and result then
            externalTraceEvents = {}
            externalTraceRepeatCounts = {}
            externalTraceSuppressions = {}
            externalTraceSuppressionOrder = {}
            externalTraceResult = nil
            externalTraceSteps = 0
            externalTraceDropped = 0
            local traceStatus: string? = nil
            local traceDetail: string? = nil
            local priorityReserve = math.min(10000, math.floor(externalTraceLimit * 0.1))
            local normalLimit = externalTraceLimit - priorityReserve

            local function isPriorityEvent(kind: string): boolean
                return kind:sub(1, 9) == "security."
                    or kind:sub(1, 5) == "http."
                    or kind:sub(1, 8) == "payload."
                    or kind:sub(1, 8) == "dynamic."
                    or kind:sub(1, 4) == "ffi."
                    or kind:sub(1, 7) == "global_"
            end

            local function isVmTraceEvent(kind: string): boolean
                return kind:find("vm_instruction", 1, true) ~= nil
                    or kind == "vm.script_state"
            end

            for line in (result.stdout or ""):gmatch("[^\r\n]+") do
                local kind, detail = line:match("^([^\t]+)\t?(.*)$")
                if kind == "RESULT" then
                    traceStatus, traceDetail = detail:match("^([^\t]+)\t?(.*)$")
                    if traceStatus == "ok" and traceDetail == "nil" then
                        externalTraceResult = "ok"
                    elseif traceDetail and traceDetail ~= "" then
                        externalTraceResult = string.format("%s: %s", traceStatus or "unknown", traceDetail)
                    else
                        externalTraceResult = traceStatus or "unknown"
                    end
                elseif kind == "STEPS" then
                    externalTraceSteps = tonumber(detail) or 0
                elseif kind then
                    detail = detail or ""
                    if isVmTraceEvent(kind) and not LIMITS.VM_TRACE_ENABLED then
                        externalTraceDropped = externalTraceDropped + 1
                    else
                        local repeatKey = externalTraceRepeatKey(kind, detail)
                        local repeatCount = (externalTraceRepeatCounts[repeatKey] or 0) + 1
                        externalTraceRepeatCounts[repeatKey] = repeatCount
                        if repeatCount > externalTraceRepeatLimit then
                            noteSuppressedExternalTrace(repeatKey, kind, detail)
                            externalTraceDropped = externalTraceDropped + 1
                        else
                            local withinNormalLimit = #externalTraceEvents < normalLimit
                            local withinPriorityLimit = isPriorityEvent(kind) and #externalTraceEvents < externalTraceLimit
                            if withinNormalLimit or withinPriorityLimit then
                                table.insert(externalTraceEvents, {
                                    kind = kind,
                                    detail = detail,
                                })
                            else
                                externalTraceDropped = externalTraceDropped + 1
                            end
                        end
                    end
                end
            end

            if traceStatus then
                return true, traceStatus == "ok", traceDetail
            end
        end

        if ok and result then
            lastError = result.stderr ~= "" and result.stderr or result.stdout
        else
            lastError = tostring(result)
        end
    end

    return false, false, lastError
end

local function insertUnique(target: {string}, value: string)
    for _, existing in ipairs(target) do
        if existing == value then
            return
        end
    end
    table.insert(target, value)
end

local function makePreview(text: string, maxLen: number?): string
    local normalized = text:gsub("\r\n", "\n"):gsub("\r", "\n"):gsub("\n", "\\n")
    local limit = maxLen or 140
    if #normalized > limit then
        return normalized:sub(1, limit - 3) .. "..."
    end
    return normalized
end

local function analyzeLoadedChunk(sourceStr: string, chunkName: string?): (string, LoadedChunkInfo)
    local processed = sourceStr
    local passes: {string} = {}
    local features: {string} = {}
    local securityFlags: {string} = {}

    local fixed = fixCommonErrors(processed)
    if fixed ~= processed then
        processed = fixed
        insertUnique(passes, "common-error-fix")
    end

    local deobf = deobfuscateStrings(processed)
    if deobf ~= processed then
        processed = deobf
        insertUnique(passes, "string-deobfuscation")
    end

    local sanitized = sanitizeLuauSyntax(processed)
    if sanitized ~= processed then
        processed = sanitized
        insertUnique(passes, "syntax-sanitization")
    end

    local normalizedClosures = normalizeLuauLocalClosures(processed)
    if normalizedClosures ~= processed then
        processed = normalizedClosures
        insertUnique(passes, "luau-closure-normalization")
    end

    local function flagFeature(pattern: string, name: string)
        if sourceStr:find(pattern) or processed:find(pattern) then
            insertUnique(features, name)
        end
    end

    flagFeature("string%.char", "string.char encoding")
    flagFeature("string%.byte", "byte-level decoding")
    flagFeature("while%s+true%s+do", "control-flow loop")
    flagFeature("Instruction", "custom VM markers")
    flagFeature("Opcode", "opcode dispatcher")
    flagFeature("getfenv", "environment probing")
    flagFeature("setfenv", "environment rewriting")
    flagFeature("debug%.", "debug library probes")
    flagFeature("newproxy", "proxy construction")
    flagFeature("setmetatable", "metatable rewriting")
    flagFeature("getmetatable", "metatable inspection")
    flagFeature("loadstring", "dynamic code loading")
    flagFeature("load%(", "dynamic code loading")
    flagFeature("HttpGet", "HTTP access")
    flagFeature("request%s*%(", "executor HTTP request")
    flagFeature("writefile", "filesystem probe")
    flagFeature("appendfile", "filesystem append")
    flagFeature("listfiles", "filesystem enumeration")

    if sourceStr:find("[\u{200B}\u{200C}\u{200D}]") then
        insertUnique(features, "invisible Unicode encoding")
    end

    local isRCE, matchedPattern = detectRCE(sourceStr)
    if isRCE and matchedPattern then
        insertUnique(securityFlags, matchedPattern)
    end

    if #processed > LIMITS.MAX_CHUNK_SIZE then
        processed = processed:sub(1, LIMITS.MAX_CHUNK_SIZE) .. "\n-- [chunk truncated by env2]"
        insertUnique(securityFlags, "chunk truncated for output")
    end

    local info: LoadedChunkInfo = {
        name = chunkName or string.format("chunk_%d", #loadedChunkInfo + 1),
        originalSize = #sourceStr,
        processedSize = #processed,
        features = features,
        passes = passes,
        securityFlags = securityFlags,
        preview = makePreview(sourceStr, 160),
        processedPreview = makePreview(processed, 160),
    }

    return processed, info
end

local function loadedChunkKey(source: string): string
    if #source <= 8192 then
        return source
    end
    return tostring(#source) .. "\0" .. source:sub(1, 4096) .. "\0" .. source:sub(-4096)
end

local function recordLoadedChunkRepeat(key: string, info: LoadedChunkInfo)
    local index = loadedChunkRepeatIndex[key]
    if index then
        loadedChunkRepeats[index].count += 1
        return
    end

    if #loadedChunkRepeats >= 200 then
        return
    end

    table.insert(loadedChunkRepeats, {
        name = info.name,
        originalSize = info.originalSize,
        processedSize = info.processedSize,
        count = 1,
        preview = info.processedPreview,
    })
    loadedChunkRepeatIndex[key] = #loadedChunkRepeats
end

local STATIC_EXACT_NAMES = {
    ["_ENV"] = true,
    ["_G"] = true,
    ["game"] = true,
    ["workspace"] = true,
    ["script"] = true,
    ["shared"] = true,
    ["pcall"] = true,
    ["xpcall"] = true,
    ["load"] = true,
    ["loadstring"] = true,
    ["require"] = true,
    ["getfenv"] = true,
    ["setfenv"] = true,
    ["getgenv"] = true,
    ["getrenv"] = true,
    ["getsenv"] = true,
    ["rawget"] = true,
    ["rawset"] = true,
    ["rawequal"] = true,
    ["getmetatable"] = true,
    ["setmetatable"] = true,
    ["debug"] = true,
    ["string"] = true,
    ["table"] = true,
    ["math"] = true,
    ["bit"] = true,
    ["bit32"] = true,
    ["syn"] = true,
    ["http"] = true,
    ["request"] = true,
    ["setclipboard"] = true,
    ["identifyexecutor"] = true,
}

local STATIC_STRING_KEYWORDS = {
    "http://",
    "https://",
    "rbxassetid://",
    "raw.githubusercontent.com",
    "discord.gg/",
    "webhook",
    "getservice",
    "players",
    "localplayer",
    "httpget",
    "httppost",
    "httpservice",
    "jsonencode",
    "jsondecode",
    "loadstring",
    "setclipboard",
    "toclipboard",
    "identifyexecutor",
    "getgenv",
    "getrenv",
    "getsenv",
    "getfenv",
    "setfenv",
    "debug.",
    "debug.info",
    "hookfunction",
    "hookmetamethod",
    "getrawmetatable",
    "setrawmetatable",
    "getnamecallmethod",
    "setnamecallmethod",
    "__namecall",
    "__index",
    "__newindex",
    "syn.",
    "syn_",
    "syn.request",
    "http_request",
    "queue_on_teleport",
    "writefile",
    "readfile",
    "appendfile",
    "delfile",
    "isfile",
    "isfolder",
    "makefolder",
    "clonefunction",
    "newcclosure",
    "checkcaller",
    "islclosure",
    "iscclosure",
    "getgc",
    "getreg",
    "getloadedmodules",
    "getconnections",
    "fireclickdetector",
    "firetouchinterest",
    "firesignal",
    "keypress",
    "mouse1click",
    "replicatedstorage",
    "teleportservice",
    "tweenservice",
    "runservice",
    "remoteevent",
    "remotefunction",
    "humanoid",
    "lph_",
    "lura.ph",
    "luraph obfuscator",
    "ironbrew",
    "moonsec",
    "prometheus",
    "psu obfuscator",
    "synapse xen",
    "hercules",
    "wynfuscate",
    "anti tamper",
}

local function hasUsefulStaticKeyword(value: string): boolean
    local lower = string.lower(value)
    if STATIC_EXACT_NAMES[value] or STATIC_EXACT_NAMES[lower] then
        return true
    end

    for _, keyword in ipairs(STATIC_STRING_KEYWORDS) do
        if lower:find(keyword, 1, true) then
            return true
        end
    end

    return false
end

local function looksLikeUsefulStaticString(value: string): boolean
    if #value < 3 or #value > 240 then
        return false
    end
    if value:match("^[A-Za-z0-9][Aa][Bb]$") then
        return false
    end

    local printable = 0
    local letters = 0
    for index = 1, #value do
        local byte = string.byte(value, index)
        if byte and byte >= 32 and byte <= 126 then
            printable += 1
        end
        if byte and ((byte >= 65 and byte <= 90) or (byte >= 97 and byte <= 122)) then
            letters += 1
        end
    end

    if printable / #value < 0.85 or letters == 0 then
        return false
    end

    return hasUsefulStaticKeyword(value)
end

local function recordStaticHint(kind: string, value: string, force: boolean?): boolean
    if type(value) ~= "string" then
        return false
    end
    if not force and not looksLikeUsefulStaticString(value) then
        return false
    end
    if #value > 4096 then
        value = value:sub(1, 4096)
    end
    local key = kind .. "\0" .. value
    if staticHintSeen[key] then
        return false
    end
    staticHintSeen[key] = true
    table.insert(staticHintValues, {
        kind = kind,
        value = value,
    })
    return true
end

local function harvestStaticLuraphHints(source: string)
    local seen: {[string]: boolean} = {}
    local emitted = 0
    local maxHints = 300

    local function emit(kind: string, value: string, force: boolean?)
        if emitted >= maxHints or seen[kind .. "\0" .. value] then
            return
        end
        if not force and not looksLikeUsefulStaticString(value) then
            return
        end
        seen[kind .. "\0" .. value] = true
        if recordStaticHint(kind, value, force) then
            emitted += 1
        end
    end

    if source:find("roblox_enums", 1, true) then
        local enumSnapshot = computedValues.__staticEnumSnapshot
        if type(enumSnapshot) ~= "table" then
            enumSnapshot = {}
            computedValues.__staticEnumSnapshot = enumSnapshot
        end

        local insideSnapshot = false
        local currentEnum: string? = nil
        for line in (source .. "\n"):gmatch("([^\r\n]*)\r?\n") do
            if not insideSnapshot then
                if line:match("roblox_enums%s*=%s*{") then
                    insideSnapshot = true
                end
            elseif currentEnum == nil then
                local enumName = line:match('%["([%w_]+)"%]%s*=%s*{')
                if enumName then
                    currentEnum = enumName
                    if enumSnapshot[enumName] == nil then
                        enumSnapshot[enumName] = {
                            order = {},
                            values = {},
                        }
                    end
                elseif line:match("^%s*}%s*;?%s*$") then
                    break
                end
            else
                local itemName, valueText = line:match('{%s*Name%s*=%s*"([^"]+)"%s*,%s*Value%s*=%s*(-?%d+)%s*}')
                if itemName and valueText then
                    local enumInfo = enumSnapshot[currentEnum]
                    if enumInfo and enumInfo.values[itemName] == nil then
                        enumInfo.values[itemName] = tonumber(valueText) or 0
                        table.insert(enumInfo.order, itemName)
                    end
                elseif line:match("^%s*},?%s*$") then
                    currentEnum = nil
                end
            end
        end
    end

    local luraphVersion = source:match("Luraph%s+Obfuscator%s+v([%d%.]+)")
    if luraphVersion then
        emit("luraph-version", "v" .. luraphVersion, true)
    end

    if source:find("PSU Obfuscator", 1, true) then
        emit("obfuscator", "PSU Obfuscator", true)
    elseif source:find("MoonSec", 1, true) or source:find("moonsec", 1, true) then
        emit("obfuscator", "MoonSec", true)
    elseif source:find("IronBrew", 1, true) or source:find("Ironbrew", 1, true) then
        emit("obfuscator", "IronBrew", true)
    elseif source:find("Prometheus", 1, true) then
        emit("obfuscator", "Prometheus", true)
    elseif source:find("Synapse Xen", 1, true) or source:find("SynapseXen", 1, true) then
        emit("obfuscator", "Synapse Xen", true)
    end

    local hasLuraphSignature = luraphVersion ~= nil
        or source:find("lura.ph", 1, true) ~= nil
        or source:find("Luraph Obfuscator", 1, true) ~= nil
        or source:find("protected using Luraph", 1, true) ~= nil
        or source:find("LPH-", 1, true) ~= nil
        or source:find("LPH!", 1, true) ~= nil
        or source:find("LPH_", 1, true) ~= nil

    if hasLuraphSignature then
        local functionCount = select(2, source:gsub("function%s*%(", ""))
        local hexNumberCount = select(2, source:gsub("0[xX]%x+", ""))
        local binaryNumberCount = select(2, source:gsub("0[bB][01_]+", ""))
        local hasPack = source:find("string.pack", 1, true) ~= nil
            or source:find("string%[\"pack\"%]", 1, false) ~= nil
        local hasUnpack = source:find("string.unpack", 1, true) ~= nil
            or source:find("string%[\"unpack\"%]", 1, false) ~= nil
        emit(
            "luraph-vm",
            string.format(
                "functions=%d hexnums=%d binnums=%d string.pack=%s string.unpack=%s",
                functionCount,
                hexNumberCount,
                binaryNumberCount,
                tostring(hasPack),
                tostring(hasUnpack)
            ),
            true
        )
    end

    local index = 1
    while index <= #source and emitted < maxHints do
        local ch = source:sub(index, index)
        if source:sub(index, index + 1) == "--" then
            index = skipComment(source, index)
        elseif ch == "[" and readLongBracketDelimiter(source, index) then
            index = skipLongBracket(source, index)
        elseif ch == '"' or ch == "'" then
            local quote = ch
            local cursor = index + 1
            local rawParts: {string} = {}
            while cursor <= #source do
                local c = source:sub(cursor, cursor)
                if c == "\\" then
                    table.insert(rawParts, c)
                    cursor += 1
                    if cursor <= #source then
                        table.insert(rawParts, source:sub(cursor, cursor))
                        cursor += 1
                    end
                elseif c == quote then
                    break
                else
                    table.insert(rawParts, c)
                    cursor += 1
                end
            end

            local decoded = decodeLuaEscapesForSearch(table.concat(rawParts))
            emit("literal", decoded)
            local reversed = string.reverse(decoded)
            if reversed ~= decoded and looksLikeUsefulStaticString(reversed) and not looksLikeUsefulStaticString(decoded) then
                emit("reverse", reversed)
            end

            index = math.max(cursor + 1, index + 1)
        else
            index += 1
        end
    end

end

local GLOBAL_GETRENV_STORAGE = {}
local GLOBAL_GETRENV_LRU = {}
local GLOBAL_GETSENV_STORAGE = {}
local GLOBAL_GETSENV_LRU = {}

local function createSecureEnvironment(baseEnv: {[string]: any}): {[string]: any}



    local realMetatables = setmetatable({}, {__mode = "k"})
    local weakTables = setmetatable({}, {__mode = "k"})
    local metatableLRU: {any} = {}

    local envObjects = setmetatable({}, {__mode = "k"})
    local functionEnvironments = setmetatable({}, {__mode = "k"})
    local functionPublicEnvironments = setmetatable({}, {__mode = "k"})
    local hostSetfenv = setfenv

    envObjects[baseEnv] = true

    local missingGlobalFallbacks: {[string]: any} = {}
    local nilGlobalKeys: {[any]: boolean} = {}
    local dangerousEnvKeys: {[string]: boolean} = {
        _fs = true,
        _process = true,
        _require = true,
        _load = true,
        _loadstring = true,
        _luau = true,
        _stdio = true,
        fs = true,
        process = true,
        require = true,
        loadfile = true,
        dofile = true,
        io = true,
        package = true,
        os = true,
        _ = true,
        fenv = true,
    }

    local function isDangerousEnvKey(key: any): boolean
        local keyStr = tostring(key)
        if dangerousEnvKeys[keyStr] then
            return true
        end
        return keyStr:sub(1, 1) == "_" and keyStr:find("process", 1, true) ~= nil
    end

    local function byteArgsToString(args: {any}): string?
        local count = #args
        if count == 0 or count > 64 then
            return nil
        end
        local out = {}
        for index, value in ipairs(args) do
            local byte = tonumber(value)
            if byte == nil or byte ~= math.floor(byte) or byte < 0 or byte > 255 then
                return nil
            end
            out[index] = string.char(byte)
        end
        return table.concat(out)
    end

    local function getMissingGlobalFallback(path: string): any
        if path == "_" or path == "fenv" then
            return nil
        end
        if nilGlobalKeys[path] then
            return nil
        end
        if not path:find(".", 1, true) then
            if path:match("^[%l_][%w_]*$") then
                logAPICall("property_access", "missing_global_nil." .. path)
                return nil
            end
            local serviceLikeNil = {
                Players = true,
                ReplicatedStorage = true,
                ServerStorage = true,
                ServerScriptService = true,
                StarterGui = true,
                StarterPack = true,
                StarterPlayer = true,
                Lighting = true,
                SoundService = true,
                TweenService = true,
                TestService = true,
            }
            if serviceLikeNil[path] then
                logAPICall("property_access", "missing_global_nil." .. path)
                return nil
            end
        end
        local existing = missingGlobalFallbacks[path]
        if existing ~= nil then
            return existing
        end

        local fallback = {}
        missingGlobalFallbacks[path] = fallback
        setmetatable(fallback, {
            __index = function(_, key)
                local childPath = path .. "." .. tostring(key)
                logAPICall("property_access", "missing_global." .. childPath)
                return getMissingGlobalFallback(childPath)
            end,
            __newindex = function(_, key, value)
                logAPICall("property_set", string.format("missing_global.%s.%s = %s", path, tostring(key), formatValue(value)))
            end,
            __call = function(_, ...: any)
                local args = {...}
                local byteString = byteArgsToString(args)
                if byteString ~= nil then
                    logDecodedString(byteString, "missing_global." .. path, 1)
                    return byteString
                end
                local argStrs: {string} = {}
                for i, arg in ipairs(args) do
                    if i > 10 then
                        table.insert(argStrs, "...")
                        break
                    end
                    table.insert(argStrs, formatValue(arg))
                end
                logAPICall("function_call", string.format("missing_global.%s(%s)", path, table.concat(argStrs, ", ")))
                return getMissingGlobalFallback(path .. "()")
            end,
            __len = function()
                return 0
            end,
            __tostring = function()
                return "missing_global." .. path
            end,
        })

        return fallback
    end

    local stringMt = getmetatable("") or {}
    realMetatables["__string_metatable__"] = stringMt

    baseEnv.debug = baseEnv.debug or {}
    baseEnv.debug.getmetatable = function(obj)
        logAPICall("function_call", "debug.getmetatable(object)")

        if obj == baseEnv or obj == baseEnv._G then
            local mt = realMetatables[obj]
            if type(mt) == "table" and mt.__metatable ~= nil then
                return mt.__metatable
            end
            return mt
        end

        if envObjects[obj] then
            local mt = realMetatables[obj]
            if type(mt) == "table" and mt.__metatable ~= nil then
                return mt.__metatable
            end
            return mt
        end

        if realMetatables[obj] then
            return realMetatables[obj]
        end

        if proxyRegistry[obj] then
            realMetatables[obj] = {__metatable = "The metatable is locked"}
            return "The metatable is locked"
        end

        return getmetatable(obj)
    end

    baseEnv.debug.setmetatable = function(obj, mt)
        logAPICall("function_call", "debug.setmetatable(object, metatable)")

        if type(mt) == "table" then
            if mt.__index == _G or mt.__index == package or mt.__index == io then
                error("Malicious metatable detected", 2)
            end
            for k, v in pairs(mt) do
                if type(v) == "table" and (v == _G or v == package or v == io) then
                    error("Malicious metatable detected", 2)
                end
            end
        end

        if not checkLimit("metatables", LIMITS.MAX_METATABLES) then
            if #metatableLRU > 0 then
                local oldest = table.remove(metatableLRU, 1)
                realMetatables[oldest] = nil
                RESOURCE_USAGE.metatables = RESOURCE_USAGE.metatables - 1
            end
        end

        if obj == nil then
            realMetatables["__nil_metatable__"] = mt
            pcall(function()
                if debug and debug.setmetatable then
                    return debug.setmetatable(nil, mt)
                end
            end)
            return nil
        end

        local objType = type(obj)

        if objType == "string" then
            realMetatables["__string_metatable__"] = mt
            local success, result = pcall(function()
                if debug and debug.setmetatable then
                    return debug.setmetatable("", mt)
                end
                return obj
            end)
            return obj
        end

        if objType == "number" or objType == "boolean" then
            realMetatables["__" .. objType .. "_metatable__"] = mt
            pcall(function()
                if debug and debug.setmetatable then
                    return debug.setmetatable(obj, mt)
                end
            end)
            return obj
        end

        if objType ~= "table" and objType ~= "userdata" then
            realMetatables[obj] = mt
            return obj
        end

        if obj == baseEnv or envObjects[obj] then
            envObjects[obj] = true
            realMetatables[obj] = mt
            if type(mt) == "table" and type(mt.__mode) == "string" then
                weakTables[obj] = mt.__mode
            else
                weakTables[obj] = nil
            end
            table.insert(metatableLRU, obj)
            RESOURCE_USAGE.metatables = RESOURCE_USAGE.metatables + 1
            logAPICall("metatable_set", "setmetatable(env, metatable)", nil)
        else
            realMetatables[obj] = mt
            if type(mt) == "table" and type(mt.__mode) == "string" then
                weakTables[obj] = mt.__mode
            else
                weakTables[obj] = nil
            end
            table.insert(metatableLRU, obj)
            RESOURCE_USAGE.metatables = RESOURCE_USAGE.metatables + 1
        end

        local success, result = pcall(function()
            return setmetatable(obj, mt)
        end)

        if not success then
            return obj
        end

        return result
    end

    baseEnv.getmetatable = function(...: any)
        if select("#", ...) == 0 then
            error("missing argument #1", 2)
        end
        local obj = ...
        logAPICall("function_call", "getmetatable(object)")

        if type(obj) == "string" then
            if realMetatables["__string_metatable__"] then
                return realMetatables["__string_metatable__"]
            end
            return getmetatable("")
        end

        if obj == baseEnv or obj == baseEnv._G then
            local mt = realMetatables[obj]
            if type(mt) == "table" and mt.__metatable ~= nil then
                return mt.__metatable
            end
            return mt
        end

        if envObjects[obj] then
            local mt = realMetatables[obj]
            if type(mt) == "table" and mt.__metatable ~= nil then
                return mt.__metatable
            end
            return mt
        end

        if realMetatables[obj] then
            local mt = realMetatables[obj]
            if type(mt) == "table" and mt.__metatable ~= nil then
                return mt.__metatable
            end
            return mt
        end

        if proxyRegistry[obj] then
            realMetatables[obj] = {__metatable = "The metatable is locked"}
            return "The metatable is locked"
        end

        return getmetatable(obj)
    end

    baseEnv.setmetatable = function(obj, mt)
        logAPICall("function_call", "setmetatable(object, metatable)")

        if type(obj) ~= "table" and type(obj) ~= "userdata" then
            error(string.format("invalid argument #1 to 'setmetatable' (table expected, got %s)", type(obj)), 2)
        end

        local existingMt = realMetatables[obj]
        if type(existingMt) == "table" and existingMt.__metatable ~= nil then
            error("cannot change a protected metatable", 2)
        end

        if obj == baseEnv or envObjects[obj] then
            envObjects[obj] = true
            realMetatables[obj] = mt
            if type(mt) == "table" and type(mt.__mode) == "string" then
                weakTables[obj] = mt.__mode
            else
                weakTables[obj] = nil
            end

            logAPICall("metatable_set", "setmetatable(env, metatable)", nil)
            return obj
        else
            realMetatables[obj] = mt
            if type(mt) == "table" and type(mt.__mode) == "string" then
                weakTables[obj] = mt.__mode
            else
                weakTables[obj] = nil
            end
        end

        local success, result = pcall(setmetatable, obj, mt)
        if not success then
            return obj
        end

        return result
    end

    local inheritedCollectgarbage = baseEnv.collectgarbage
    baseEnv.collectgarbage = function(opt, arg)
        if opt == "collect" or opt == nil then
            for tbl, mode in pairs(weakTables) do
                if type(tbl) == "table" and type(mode) == "string" then
                    local removeKeys = {}
                    if mode:find("k", 1, true) then
                        for key in pairs(tbl) do
                            if type(key) == "table" or type(key) == "function" or type(key) == "thread" then
                                table.insert(removeKeys, key)
                            end
                        end
                    end
                    for _, key in ipairs(removeKeys) do
                        rawset(tbl, key, nil)
                    end

                    if mode:find("v", 1, true) then
                        for key, value in pairs(tbl) do
                            if type(value) == "table" or type(value) == "function" or type(value) == "thread" then
                                rawset(tbl, key, nil)
                            end
                        end
                    end
                end
            end
        end

        if type(inheritedCollectgarbage) == "function" then
            return inheritedCollectgarbage(opt, arg)
        end

        return opt == "count" and 1024 or 0
    end

    local inheritedNewproxy = baseEnv.newproxy
    baseEnv.newproxy = function(addMetatable)
        if type(inheritedNewproxy) == "function" then
            return inheritedNewproxy(addMetatable)
        end

        logAPICall("function_call", string.format("newproxy(%s)", tostring(addMetatable)))
        local proxy = {}
        objectTypeNames[proxy] = "userdata"
        if addMetatable then
            local mt = {}
            realMetatables[proxy] = mt
            setmetatable(proxy, mt)
        end
        return proxy
    end

    baseEnv.require = nil

    baseEnv.loadfile = function()
        error("loadfile() is disabled for security", 2)
    end

    baseEnv.dofile = function()
        error("dofile() is disabled for security", 2)
    end

    local function coerceLoadSource(value: any): (string?, string?)
        if type(value) == "string" then
            return value, nil
        end

        if type(value) == "table" then
            local proxyId = proxyRegistry[value]
            if proxyId then
                logAPICall("function_call", string.format("load(%s)", proxyId))
                return string.format('return __remote_stub("%s")', escapeLuaString(proxyId)), nil
            end

            local bytes = byteArrayToString(value)
            if bytes then
                return bytes, nil
            end

            if rawget(value, "__bytes") ~= nil and baseEnv.buffer and type(baseEnv.buffer.tostring) == "function" then
                local ok, result = pcall(baseEnv.buffer.tostring, value)
                if ok and type(result) == "string" then
                    return result, nil
                end
            end
        end

        return nil, string.format("bad argument #1 to 'load' (string expected, got %s)", type(value))
    end

    local function sandboxedLoad(source: any, chunkname: string?, mode: string?, env: any?)
        local sourceStr = ""
        local sourceToLoad = ""
        local chunkLabel = type(chunkname) == "string" and chunkname or string.format("loadstring_%d", #loadedChunks + 1)

        if type(source) == "string" then
            sourceStr = source
            sourceToLoad = source
        elseif type(source) == "function" then
            local chunks: {string} = {}
            while true do
                local chunk = source()
                if not chunk or chunk == "" then break end
                local chunkText, chunkErr = coerceLoadSource(chunk)
                if not chunkText then
                    return nil, chunkErr
                end
                table.insert(chunks, chunkText)
            end
            sourceStr = table.concat(chunks)
            sourceToLoad = sourceStr
        else
            local coercedSource, sourceErr = coerceLoadSource(source)
            if not coercedSource then
                return nil, sourceErr
            end
            sourceStr = coercedSource
            sourceToLoad = coercedSource
        end

        sourceStr = stripUtf8Bom(sourceStr)
        sourceToLoad = stripUtf8Bom(sourceToLoad)

        if #sourceStr > 0 then
            local isRCE, matchedPattern = detectRCE(sourceStr)
            if isRCE then
                rceAlert(matchedPattern)
            end

            local analyzedSource, chunkInfo = analyzeLoadedChunk(sourceStr, chunkLabel)
            sourceToLoad = analyzedSource

            local chunkKey = loadedChunkKey(analyzedSource)
            local seenCount = (loadedChunkSeen[chunkKey] or 0) + 1
            loadedChunkSeen[chunkKey] = seenCount

            if seenCount > LIMITS.LOAD_REPEAT_LIMIT then
                recordLoadedChunkRepeat(chunkKey, chunkInfo)
                sourceToLoad = "return nil"
            else
                if #loadedChunks >= LIMITS.MAX_LOADED_CHUNKS then
                    table.remove(loadedChunks, 1)
                    table.remove(loadedChunkInfo, 1)
                    RESOURCE_USAGE.loadedChunks = math.max(0, RESOURCE_USAGE.loadedChunks - 1)
                end

                if sourceStr:match("string%.char") or sourceStr:match("string%.byte") then
                    local charPattern = sourceStr:match("string%.char%s*%(([^)]+)%)")
                    if charPattern then
                        table.insert(stringPatterns, {
                            pattern = "string.char(" .. charPattern:sub(1, 50) .. "...)",
                            decoded = analyzedSource:sub(1, 100)
                        })
                    end
                end

                for _, feature in ipairs(chunkInfo.features) do
                    if feature == "custom VM markers" or feature == "opcode dispatcher" then
                        print(string.format("[detect] %s in %s", feature, chunkInfo.name))
                    elseif feature == "control-flow loop" then
                        print(string.format("[detect] Control flow flattening in %s", chunkInfo.name))
                    end
                end

                if #chunkInfo.passes > 0 then
                    print(string.format("[chunk] %s normalized with: %s", chunkInfo.name, table.concat(chunkInfo.passes, ", ")))
                end

                table.insert(loadedChunks, analyzedSource)
                table.insert(loadedChunkInfo, chunkInfo)
                RESOURCE_USAGE.loadedChunks = RESOURCE_USAGE.loadedChunks + 1
            end
        end

        local targetEnv = env or baseEnv

        local wrappedSource = [[
local __existing_string_mt = getmetatable("")
local __string_mt = {}
if type(__existing_string_mt) == "table" then
    for __key, __value in pairs(__existing_string_mt) do
        __string_mt[__key] = __value
    end
end
__string_mt.__index = string
__string_mt.__pow = function(a, b)
    local numA = tonumber(a)
    local numB = tonumber(b)
    if numA and numB then return numA ^ numB end
    return 0
end
__string_mt.__add = function(a, b)
    local numA = tonumber(a)
    local numB = tonumber(b)
    if numA and numB then return numA + numB end
    return 0
end
__string_mt.__sub = function(a, b)
    local numA = tonumber(a)
    local numB = tonumber(b)
    if numA and numB then return numA - numB end
    return 0
end
__string_mt.__mul = function(a, b)
    local numA = tonumber(a)
    local numB = tonumber(b)
    if numA and numB then return numA * numB end
    return 0
end
__string_mt.__div = function(a, b)
    local numA = tonumber(a)
    local numB = tonumber(b)
    if numA and numB and numB ~= 0 then return numA / numB end
    return 0
end
__string_mt.__mod = function(a, b)
    local numA = tonumber(a)
    local numB = tonumber(b)
    if numA and numB and numB ~= 0 then return numA % numB end
    return 0
end
__string_mt.__unm = function(a)
    local numA = tonumber(a)
    if numA then return -numA end
    return 0
end
if debug and debug.setmetatable then
    debug.setmetatable("", __string_mt)
end

]] .. sourceToLoad

        local lowerChunkLabel = string.lower(chunkLabel)
        local useLoadedHookOps = lowerChunkLabel:find("luraph", 1, true) ~= nil
        local fastDynamicLoad = #sourceToLoad <= 4096
            and not useLoadedHookOps
            and sourceToLoad:find("Luraph", 1, true) == nil
            and sourceToLoad:find("lura.ph", 1, true) == nil
            and sourceToLoad:find("LPH_", 1, true) == nil
            and sourceToLoad:find("__ENV2_HOOK", 1, true) == nil

        local function loadDynamicChunk(loadEnv: any, label: string)
            if fastDynamicLoad then
                local ok, directChunk, directErr = pcall(_luau.load, wrappedSource, {
                    debugName = label,
                    environment = loadEnv,
                })
                if not ok then
                    return nil, tostring(directChunk)
                end
                return directChunk, directErr
            end
            return advancedLoad(wrappedSource, label, loadEnv, useLoadedHookOps)
        end

        local chunk, err = loadDynamicChunk(targetEnv, chunkLabel)

        if not chunk then
            return nil, err
        end

        local runner
        runner = function(...: any)
            local activeEnv = functionEnvironments[runner] or targetEnv
            local publicEnv = functionPublicEnvironments[runner] or activeEnv
            local previousGetfenv = nil
            local installedGetfenv = nil
            if type(activeEnv) == "table" then
                previousGetfenv = rawget(activeEnv, "getfenv")
                installedGetfenv = function(level)
                    if level == nil or level == 0 or level == 1 then
                        return publicEnv
                    end
                    if type(previousGetfenv) == "function" then
                        return previousGetfenv(level)
                    end
                    return publicEnv
                end
                rawset(activeEnv, "getfenv", installedGetfenv)
            end
            local function restoreGetfenv()
                if type(activeEnv) ~= "table" or rawget(activeEnv, "getfenv") ~= installedGetfenv then
                    return
                end
                if previousGetfenv ~= nil then
                    rawset(activeEnv, "getfenv", previousGetfenv)
                else
                    rawset(activeEnv, "getfenv", nil)
                end
            end
            local function runLoaded(loadedChunk, ...: any)
                local dynamicHookArmed = false
                if fastDynamicLoad and _debug and type(_debug.sethook) == "function" then
                    local instructionBudget = math.floor(tonumber(process.env.ENV2_DYNAMIC_LOAD_INSTRUCTION_LIMIT or "") or 200000)
                    if instructionBudget > 0 then
                        dynamicHookArmed = pcall(_debug.sethook, function()
                            error("dynamic load execution limit exceeded", 2)
                        end, "", instructionBudget)
                    end
                end
                local results = table.pack(pcall(loadedChunk, ...))
                if dynamicHookArmed then
                    pcall(_debug.sethook)
                end
                restoreGetfenv()
                if not results[1] then
                    error(results[2], 0)
                end
                return table.unpack(results, 2, results.n)
            end
            if activeEnv == targetEnv then
                return runLoaded(chunk, ...)
            end
            local scopedChunk, scopedErr = loadDynamicChunk(activeEnv, chunkLabel .. ":setfenv")
            if not scopedChunk then
                restoreGetfenv()
                error(scopedErr or "loadstring environment failed", 2)
            end
            return runLoaded(scopedChunk, ...)
        end
        functionEnvironments[runner] = targetEnv
        return runner
    end

    baseEnv.load = sandboxedLoad
    baseEnv.loadstring = sandboxedLoad
    baseEnv.require = function()
        error("require is not supported", 2)
    end

    baseEnv.process = nil
    baseEnv.fs = nil


    baseEnv.io = nil

    local inheritedOs = baseEnv.os or {}
    local safeOsTime = os.time or function(t)
        if t then
            return 1700000000 + os.clock()
        end
        return math.floor(1700000000 + os.clock())
    end

    baseEnv.os = {
        clock = inheritedOs.clock or os.clock,
        date = inheritedOs.date or os.date or function() return "Thu Jan  1 00:00:00 1970" end,
        time = inheritedOs.time or safeOsTime,
        difftime = inheritedOs.difftime or os.difftime or function(t2, t1) return t2 - t1 end,
    }

    baseEnv.rawget = function(tbl, key)
        if tbl == baseEnv._G then
            return baseEnv[key]
        end
        return rawget(tbl, key)
    end
    baseEnv.rawset = rawset
    baseEnv.rawequal = rawequal
    baseEnv.rawlen = rawlen or function(t) return #t end

    baseEnv.package = nil

    local baseEnv_sandboxed_G = setmetatable({}, {
        __index = function(t, k)
            if isDangerousEnvKey(k) then
                return nil
            end
            if nilGlobalKeys[k] then
                return nil
            end
            local value = baseEnv[k]
            if value ~= nil then
                return value
            end
            local keyStr = tostring(k)
            logAPICall("property_access", "missing_global." .. keyStr)
            return getMissingGlobalFallback(keyStr)
        end,
        __newindex = function(t, k, v)
            local dangerousKeys = {
                "package", "io", "require", "loadfile", "dofile",
                "_fs", "_process", "_require", "_load", "_loadstring", "_luau", "_stdio"
            }
            for _, dangerous in ipairs(dangerousKeys) do
                if k == dangerous then
                    logAPICall("security_block", string.format("Blocked _G[%s] write", formatValue(k)))
                    return
                end
            end
            logAPICall("global_set", string.format("_G[%s] = %s", formatValue(k), formatValue(v)))
            if v == nil then
                nilGlobalKeys[k] = true
                rawset(baseEnv, k, nil)
            else
                nilGlobalKeys[k] = nil
                rawset(baseEnv, k, v)
            end
        end,
        __pairs = function()
            local keys = {}
            for k in pairs(baseEnv) do
                local isDangerous = false
                local dangerousKeys = {
                    "_fs", "_process", "_require", "_load", "_loadstring", "_luau", "_stdio",
                    "fs", "process", "require", "loadfile", "dofile",
                    "io", "package"
                }
                for _, dangerous in ipairs(dangerousKeys) do
                    if k == dangerous then
                        isDangerous = true
                        break
                    end
                end
                if not isDangerous then
                    table.insert(keys, k)
                end
            end
            local i = 0
            return function()
                i = i + 1
                if keys[i] then
                    return keys[i], baseEnv[keys[i]]
                end
            end
        end,
    })
    baseEnv._G = baseEnv_sandboxed_G

    envObjects[baseEnv_sandboxed_G] = true
    envObjects[baseEnv] = true

    local globalEnvOverride = baseEnv._G
    local function makeSafeFunctionEnvironment(envTable: {[any]: any}): {[any]: any}
        if envTable == baseEnv or envTable == baseEnv._G then
            return envTable
        end

        local safeEnv = setmetatable({}, {
            __index = function(_, key)
                if isDangerousEnvKey(key) then
                    return nil
                end
                if nilGlobalKeys[key] then
                    return nil
                end
                local value = rawget(envTable, key)
                if value ~= nil then
                    return value
                end
                return baseEnv[key]
            end,
            __newindex = function(_, key, value)
                if isDangerousEnvKey(key) then
                    logAPICall("security_block", string.format("Blocked setfenv write to %s", formatValue(key)))
                    return
                end
                logAPICall("global_set", string.format("_ENV[%s] = %s", formatValue(key), formatValue(value)))
                if value == nil then
                    nilGlobalKeys[key] = true
                else
                    nilGlobalKeys[key] = nil
                end
                rawset(envTable, key, value)
            end,
            __pairs = function()
                return pairs(envTable)
            end,
        })
        envObjects[safeEnv] = true
        return safeEnv
    end

    baseEnv.getfenv = function(level)
        logAPICall("function_call", string.format("getfenv(%s)", tostring(level)))

        envObjects[baseEnv] = true
        envObjects[baseEnv._G] = true

        if type(level) == "number" and level == 0 then
            return globalEnvOverride or baseEnv._G
        elseif type(level) == "thread" then
            return globalEnvOverride or baseEnv._G
        elseif type(level) == "function" then
            return functionPublicEnvironments[level] or functionEnvironments[level] or baseEnv
        elseif level == nil then
            return baseEnv
        end

        return baseEnv
    end

    baseEnv.setfenv = function(target, envTable)
        logAPICall("function_call", string.format("setfenv(%s, %s)", formatValue(target), formatValue(envTable)))

        if target == 0 and type(envTable) == "table" then
            envObjects[envTable] = true
            globalEnvOverride = makeSafeFunctionEnvironment(envTable)
            return target
        end

        if type(target) == "function" then
            local protectedFunctions = {
                baseEnv.pcall, baseEnv.type, baseEnv.tostring, baseEnv.getfenv, baseEnv.setfenv,
                baseEnv.next, baseEnv.pairs, baseEnv.ipairs,
                pcall, type, tostring, next, pairs, ipairs, select,
            }
            for _, protected in ipairs(protectedFunctions) do
                if target == protected then
                    error("cannot change environment of given object", 2)
                end
            end

            if type(envTable) == "table" then
                envObjects[envTable] = true
                local safeEnv = makeSafeFunctionEnvironment(envTable)
                functionEnvironments[target] = safeEnv
                functionPublicEnvironments[target] = envTable
                local ok, result = pcall(hostSetfenv, target, safeEnv)
                if ok then
                    return result
                end
            end
        end

        return target
    end

    baseEnv.getgenv = function()
        logAPICall("function_call", "getgenv()")

        envObjects[baseEnv] = true

        return baseEnv
    end

    baseEnv.setgenv = function(envTable)
        logAPICall("function_call", "setgenv(env)")

        if type(envTable) == "table" then
            envObjects[envTable] = true
        end

        return envTable
    end

    baseEnv.getrenv = function()
        logAPICall("function_call", "getrenv()")

        return setmetatable({}, {
            __index = function(t, k)
                if GLOBAL_GETRENV_STORAGE[k] ~= nil then
                    for i, key in ipairs(GLOBAL_GETRENV_LRU) do
                        if key == k then
                            table.remove(GLOBAL_GETRENV_LRU, i)
                            break
                        end
                    end
                    table.insert(GLOBAL_GETRENV_LRU, k)
                    return GLOBAL_GETRENV_STORAGE[k]
                end

                local keyStr = tostring(k)
                local dangerousPatterns = {"package", "io", "os", "require", "loadfile", "dofile", "_fs", "_process", "_require", "_luau", "_stdio"}
                for _, pattern in ipairs(dangerousPatterns) do
                    if keyStr == pattern or keyStr:find(pattern, 1, true) then return nil end
                end
                return baseEnv[k]
            end,
            __newindex = function(t, k, v)
                if RESOURCE_USAGE.envStorage >= LIMITS.GLOBAL_ENV_STORAGE then
                    if #GLOBAL_GETRENV_LRU > 0 then
                        local lruKey = table.remove(GLOBAL_GETRENV_LRU, 1)
                        GLOBAL_GETRENV_STORAGE[lruKey] = nil
                        RESOURCE_USAGE.envStorage = RESOURCE_USAGE.envStorage - 1
                    else
                        return
                    end
                end
                local keyStr = tostring(k)
                local dangerousPatterns = {"package", "io", "os", "require", "loadfile", "dofile"}
                for _, pattern in ipairs(dangerousPatterns) do
                    if keyStr == pattern or keyStr:find(pattern, 1, true) then return end
                end
                GLOBAL_GETRENV_STORAGE[k] = v
                table.insert(GLOBAL_GETRENV_LRU, k)
                RESOURCE_USAGE.envStorage = RESOURCE_USAGE.envStorage + 1
            end,
        })
    end

    local mt = {
        __index = function(t, k)
            if isDangerousEnvKey(k) then
                return nil
            end
            if nilGlobalKeys[k] then
                return nil
            end

            local keyStr = tostring(k)
            logAPICall("property_access", "missing_global." .. keyStr)
            return getMissingGlobalFallback(keyStr)
        end,
        __newindex = function(t, k, v)
            local dangerousKeys = {
                "package", "io", "os", "require", "loadfile", "dofile",
                "_fs", "_process", "_require", "_load", "_loadstring", "_luau", "_stdio"
            }

            for _, dangerous in ipairs(dangerousKeys) do
                if k == dangerous then
                    logAPICall("security_block", string.format("Blocked global %s write", formatValue(k)))
                    return
                end
            end

            logAPICall("global_set", string.format("_G[%s] = %s", formatValue(k), formatValue(v)))
            if v == nil then
                nilGlobalKeys[k] = true
            else
                nilGlobalKeys[k] = nil
            end
            rawset(t, k, v)
        end,
        __pairs = function()
            local keys = {}
            for k in pairs(baseEnv) do
                local isDangerous = false
                local dangerousKeys = {
                    "_fs", "_process", "_require", "_load", "_loadstring", "_luau", "_stdio",
                    "fs", "process", "require", "loadfile", "dofile",
                    "io", "package"
                }
                for _, dangerous in ipairs(dangerousKeys) do
                    if k == dangerous then
                        isDangerous = true
                        break
                    end
                end
                if not isDangerous then
                    table.insert(keys, k)
                end
            end
            local i = 0
            return function()
                i = i + 1
                if keys[i] then
                    return keys[i], baseEnv[keys[i]]
                end
            end
        end,
    }

    local markCClosure = rawget(baseEnv, "__revealr_mark_cclosure")
    if type(markCClosure) == "function" then
        markCClosure(baseEnv)
        rawset(baseEnv, "__revealr_mark_cclosure", nil)
    end

    if table.freeze then
        for _, lib in ipairs({baseEnv.math, baseEnv.string, baseEnv.table, baseEnv.utf8, baseEnv.bit32, baseEnv.bit, baseEnv.os, baseEnv.debug, baseEnv.coroutine, baseEnv.task}) do
            if type(lib) == "table" then
                pcall(table.freeze, lib)
            end
        end
    end

    setmetatable(baseEnv, mt)

    return baseEnv
end


type VMInstructionTrace = {
    opcode: string,
    opcodeType: string,
    operands: {string},
    shape: string,
    observations: number,
    sources: {[string]: boolean},
}

local vmInstructions: {VMInstructionTrace} = {}
local vmInstructionObjects = setmetatable({}, {__mode = "k"})
local vmInstructionLimitReached = false
local vmCalls: {string} = {}

local function hookVMExecution(env: any)
    local function captureInstruction(candidate: any, source: string)
        if type(candidate) ~= "table" or proxyRegistry[candidate] then
            return
        end

        local opcode = rawget(candidate, 1)
        local opcodeType = type(opcode)
        if opcodeType == "number" then
            if opcode ~= opcode or math.abs(opcode) > 9007199254740991 then
                return
            end
        elseif opcodeType == "string" then
            if #opcode == 0 or #opcode > 64 then
                return
            end
        else
            return
        end

        local lastIndex = 1
        local scalarCount = 1
        for index = 2, 12 do
            local value = rawget(candidate, index)
            if value ~= nil then
                lastIndex = index
                local valueType = type(value)
                if valueType == "number" or valueType == "string" or valueType == "boolean" then
                    scalarCount += 1
                end
            end
        end
        if lastIndex < 2 or scalarCount < 2 then
            return
        end

        local existingIndex = vmInstructionObjects[candidate]
        if existingIndex then
            local existing = vmInstructions[existingIndex]
            if existing then
                existing.observations += 1
                existing.sources[source] = true
            end
            return
        end

        if #vmInstructions >= LIMITS.MAX_VM_INSTRUCTIONS then
            vmInstructionLimitReached = true
            return
        end

        local operands: {string} = {}
        local shapeParts: {string} = {opcodeType:sub(1, 1)}
        for index = 2, lastIndex do
            local value = rawget(candidate, index)
            table.insert(operands, formatValue(value))
            local valueType = type(value)
            table.insert(shapeParts, valueType == "nil" and "-" or valueType:sub(1, 1))
        end

        table.insert(vmInstructions, {
            opcode = formatValue(opcode),
            opcodeType = opcodeType,
            operands = operands,
            shape = table.concat(shapeParts, ""),
            observations = 1,
            sources = {[source] = true},
        })
        vmInstructionObjects[candidate] = #vmInstructions
    end

    local originalUnpack = env.unpack or table.unpack or unpack

    env.unpack = function(t, ...)
        local firstIndex = select(1, ...)
        if firstIndex == nil or (type(firstIndex) == "number" and firstIndex <= 1) then
            captureInstruction(t, "unpack")
        end
        return originalUnpack(t, ...)
    end

    if type(env.table) == "table" then
        local originalTableUnpack = env.table.unpack
        if type(originalTableUnpack) == "function" then
            env.table.unpack = function(t, ...)
                local firstIndex = select(1, ...)
                if firstIndex == nil or (type(firstIndex) == "number" and firstIndex <= 1) then
                    captureInstruction(t, "table.unpack")
                end
                return originalTableUnpack(t, ...)
            end
        end

        local originalTableInsert = env.table.insert
        if type(originalTableInsert) == "function" then
            env.table.insert = function(target, ...)
                local args = table.pack(...)
                local value = if args.n == 1 then args[1] else args[2]
                captureInstruction(value, "table.insert")
                return originalTableInsert(target, table.unpack(args, 1, args.n))
            end
        end

        local originalTableRemove = env.table.remove
        if type(originalTableRemove) == "function" then
            env.table.remove = function(...)
                local results = table.pack(originalTableRemove(...))
                captureInstruction(results[1], "table.remove")
                return table.unpack(results, 1, results.n)
            end
        end
    end

    local originalIpairs = env.ipairs or ipairs
    env.ipairs = function(target)
        local iterator, state, initial = originalIpairs(target)
        return function(iterState, index)
            local nextIndex, value = iterator(iterState, index)
            captureInstruction(value, "ipairs")
            return nextIndex, value
        end, state, initial
    end

    local originalGetfenv = env.getfenv or getfenv
    local originalSetfenv = env.setfenv or setfenv

    env.getfenv = function(level)
        if #vmCalls < 10000 then
            table.insert(vmCalls, "getfenv(" .. tostring(level) .. ")")
        end
        return originalGetfenv(level)
    end

    env.setfenv = function(fn, envTable)
        if #vmCalls < 10000 then
            table.insert(vmCalls, "setfenv(function, env)")
        end
        return originalSetfenv(fn, envTable)
    end

    if env.debug then
        local originalGetinfo = env.debug.getinfo or (debug and debug.getinfo)
        env.debug.getinfo = function(...)
            if #vmCalls < 10000 then
                table.insert(vmCalls, "debug.getinfo(...)")
            end
            if originalGetinfo then
                return originalGetinfo(...)
            end
            return {
                source = "=[C]",
                short_src = "[C]",
                what = "C",
                currentline = -1,
            }
        end
    end
end



local function createProxy(varId: string, typeName: string?, customIndex: any?): any
    if not checkLimit("proxies", LIMITS.MAX_PROXIES) then
        if #proxyLRU > 0 then
            local oldest = table.remove(proxyLRU, 1)
            proxyRegistry[oldest] = nil
            proxyTypeNames[oldest] = nil
            objectTypeNames[oldest] = nil
            RESOURCE_USAGE.proxies = RESOURCE_USAGE.proxies - 1
        end
    end

    local proxy = {}
    local mt = {}

    proxyRegistry[proxy] = varId
    proxyTypeNames[proxy] = typeName or "proxy"
    table.insert(proxyLRU, proxy)
    RESOURCE_USAGE.proxies = RESOURCE_USAGE.proxies + 1

    if customIndex then
        mt.__index = customIndex
    else
        mt.__index = function(self, key: string)
            local keyStr = tostring(key):sub(1, 100)
            local stored = rawget(self, keyStr)
            if stored ~= nil then
                logAPICall("property_access", string.format("%s.%s", varId, keyStr))
                return stored
            end
            if keyStr == "Archivable" then
                logAPICall("property_access", string.format("%s.Archivable", varId))
                return true
            end
            if keyStr == "ClassName" then
                logAPICall("property_access", string.format("%s.ClassName", varId))
                return proxyTypeNames[self] or typeName or "Instance"
            end
            if keyStr == "Name" then
                logAPICall("property_access", string.format("%s.Name", varId))
                return tostring(varId):match("[^%.]+$") or tostring(typeName or "Instance")
            end

            local childId = newVarId()
            local accessCode = string.format("%s.%s", varId, keyStr)

            logAPICall("property_access", accessCode, childId)

            if variables[varId] then
                variables[varId].properties[keyStr] = childId
            end

            registerVariable(childId, "property", nil, varId)
            local parentClass = proxyTypeNames[self] or typeName or ""
            local childType = keyStr
            if parentClass == "remote_module"
                or parentClass == "remote_member"
                or parentClass == "result"
                or parentClass == "result_member" then
                childType = "result_member"
            end
            return createProxy(childId, childType)
        end
    end

    mt.__newindex = function(self, key: string, value: any)
        local keyStr = tostring(key)
        local valueStr: string
        local readOnlyByClass = {
            DataModel = { Parent = true, IsLoaded = true, ClassName = true },
            Workspace = { Parent = true, Changed = true },
            Players = { Parent = true, Changed = true },
            RunService = { Heartbeat = true, RenderStepped = true, Stepped = true, Changed = true },
            Enum = { GetEnumItems = true },
            EnumType = { GetEnumItems = true },
            EnumItem = { Name = true, Value = true, EnumType = true },
            Sound = { PlaybackLoudness = true },
            TextBox = { TextBounds = true },
            TextLabel = { TextBounds = true },
            TextButton = { TextBounds = true },
        }
        local proxyClass = proxyTypeNames[self] or typeName or ""
        local readOnly = readOnlyByClass[proxyClass]
        if readOnly and readOnly[keyStr] then
            logAPICall("security_info", string.format("readonly_property_write(%s.%s)", varId, keyStr))
            error(string.format("Unable to assign property %s. Property is read only", keyStr), 2)
        end
        if proxyClass == "Enum" or proxyClass == "EnumType" or proxyClass == "EnumItem" then
            logAPICall("security_info", string.format("readonly_property_write(%s.%s)", varId, keyStr))
            error(string.format("Unable to assign property %s. Property is read only", keyStr), 2)
        end
        if keyStr == "ClassName" then
            logAPICall("security_info", string.format("readonly_property_write(%s.%s)", varId, keyStr))
            error("Unable to assign property ClassName. Property is read only", 2)
        end
        if keyStr == "Parent" and rawget(self, "__Destroyed") and value ~= nil then
            logAPICall("security_info", string.format("destroyed_parent_write(%s.Parent)", varId))
            error("Cannot set Parent of a destroyed Instance", 2)
        end
        if keyStr == "Parent" and type(value) == "table" and not proxyRegistry[value] then
            logAPICall("security_info", string.format("invalid_parent_write(%s.Parent)", varId))
            error("Unable to assign Parent. Instance expected, got table", 2)
        end
        if (keyStr == "Position" or keyStr == "Orientation" or keyStr == "Size" or keyStr == "CFrame") and type(value) == "string" then
            logAPICall("security_info", string.format("typechecked_property_write(%s.%s)", varId, keyStr))
            error(string.format("Unable to assign property %s. Coordinate expected, got string", keyStr), 2)
        end
        if keyStr == "CameraMinZoomDistance" and tonumber(value) and tonumber(value) < 0 then
            logAPICall("security_info", string.format("validated_property_write(%s.%s)", varId, keyStr))
            error("CameraMinZoomDistance cannot be negative", 2)
        end
        if keyStr == "WaterWaveSpeed" and tonumber(value) then
            value = math.max(0, math.min(100, tonumber(value) or 0))
        end

        if proxyRegistry[value] then
            local proxyId = proxyRegistry[value]
            if enumValues[proxyId] then
                valueStr = proxyId
            else
                valueStr = proxyId
            end
        else
            valueStr = formatValue(value)
        end

        local setCode = string.format("%s.%s = %s", varId, keyStr, valueStr)
        logAPICall("property_set", setCode, varId)

        table.insert(propertySetters, {
            target = varId,
            property = keyStr,
            value = valueStr,
        })

        if variables[varId] then
            variables[varId].properties[keyStr] = valueStr
        end

        local previousParent = nil
        if keyStr == "Parent" then
            previousParent = rawget(self, "Parent")
        end

        rawset(self, keyStr, value)

        local signals = instanceSignals[self]
        if signals then
            local changed = signals.Changed
            local changedEmitter = changed and signalEmitters[changed]
            if changedEmitter then
                changedEmitter(keyStr)
            end
            local propertySignals = signals.Properties
            local propertySignal = propertySignals and propertySignals[keyStr]
            local propertyEmitter = propertySignal and signalEmitters[propertySignal]
            if propertyEmitter then
                propertyEmitter()
            end
        end
        if keyStr == "Parent" and previousParent ~= value then
            local ancestryChanged = rawget(self, "AncestryChanged")
            local ancestryChangedEmitter = ancestryChanged and signalEmitters[ancestryChanged]
            if ancestryChangedEmitter then
                ancestryChangedEmitter(self, value)
            end
        end

        if keyStr == "Parent" and type(previousParent) == "table" and previousParent ~= value then
            local previousChildren = instanceChildren[previousParent]
            if previousChildren then
                previousChildren[self] = nil
            end
            local childRemoved = rawget(previousParent, "ChildRemoved")
            local childRemovedEmitter = childRemoved and signalEmitters[childRemoved]
            if childRemovedEmitter then
                childRemovedEmitter(self)
            end
        end

        if keyStr == "Parent" and type(value) == "table" then
            rawset(self, "__ParentCleared", nil)
            local children = instanceChildren[value]
            if not children then
                children = {}
                instanceChildren[value] = children
            end
            children[self] = true
            if previousParent ~= value then
                local childAdded = rawget(value, "ChildAdded")
                local childAddedEmitter = childAdded and signalEmitters[childAdded]
                if childAddedEmitter then
                    childAddedEmitter(self)
                end
            end
        elseif keyStr == "Parent" and value == nil then
            rawset(self, "__ParentCleared", true)
        end
    end

    mt.__call = function(self, ...: any)
        local proxyClass = proxyTypeNames[self] or typeName or ""
        if proxyClass == "DataModel"
            or proxyClass == "Workspace"
            or proxyClass == "Players"
            or proxyClass == "RunService"
            or proxyClass == "HttpService"
            or proxyClass == "RBXScriptSignal"
            or proxyClass == "RBXScriptConnection"
            or rawget(self, "__RobloxInstance") == true
            or (not LIMITS.ALLOW_SYNTHETIC_PROXY_CALLS and proxyClass:match("^[A-Z]")) then
            error("attempt to call a Instance value", 2)
        end

        local args = {...}
        local argStrs: {string} = {}

        for i, arg in ipairs(args) do
            if i > 20 then break end
            if proxyRegistry[arg] then
                table.insert(argStrs, proxyRegistry[arg])
            else
                table.insert(argStrs, formatValue(arg))
            end
        end

        local resultId = newVarId()
        local callCode = string.format("%s(%s)", varId, table.concat(argStrs, ", "))

        table.insert(functionCalls, {
            func = varId,
            args = argStrs,
            result = resultId,
        })

        logAPICall("method_call", callCode, resultId)

        if variables[varId] then
            table.insert(variables[varId].methods, callCode)
        end

        registerVariable(resultId, "result", nil, varId)

        if varId:match("%.Connect$") or varId:match(":Connect$") then
            local eventName = varId:gsub("%.Connect$", ""):gsub(":Connect$", "")
            connectionMap[resultId] = {
                event = eventName,
                callback = argStrs[1] or "anonymous",
            }
            logAPICall("event_connection", string.format("%s:Connect(%s)", eventName, argStrs[1] or "function"), resultId)
        end

        return createProxy(resultId, "result")
    end

    local function operandLabel(value: any): string
        return proxyRegistry[value] or formatValue(value)
    end

    local function proxyBinaryOperator(symbol: string)
        return function(a: any, b: any)
            local left = operandLabel(a)
            local right = operandLabel(b)
            local resultId = string.format("(%s %s %s)", left, symbol, right)
            logAPICall("operator", resultId)
            registerVariable(resultId, "result", nil, varId)
            return createProxy(resultId, "result")
        end
    end

    mt.__add = proxyBinaryOperator("+")
    mt.__sub = proxyBinaryOperator("-")
    mt.__mul = proxyBinaryOperator("*")
    mt.__div = proxyBinaryOperator("/")
    mt.__mod = proxyBinaryOperator("%")
    mt.__pow = proxyBinaryOperator("^")
    mt.__unm = function(value: any)
        local resultId = string.format("(-%s)", operandLabel(value))
        logAPICall("operator", resultId)
        registerVariable(resultId, "result", nil, varId)
        return createProxy(resultId, "result")
    end
    mt.__len = function()
        logAPICall("operator", "#" .. varId)
        return 0
    end
    mt.__lt = function()
        return false
    end
    mt.__le = function()
        return false
    end
    mt.__iter = function()
        error("attempt to iterate over an Instance value", 2)
    end

    mt.__tostring = function()
        local name = rawget(proxy, "Name")
        if name ~= nil then
            return string.format("%s[%s]", varId, tostring(name))
        end
        return varId
    end


    setmetatable(proxy, mt)

    return proxy
end


local PCG = (function()
    local U32 = 4294967296
    local U16 = 65536
    local MUL_LO = 0x4c957f2d
    local MUL_HI = 0x5851f42d
    local INC = 105
    local band = bit32.band
    local bor = bit32.bor
    local bxor = bit32.bxor
    local lshift = bit32.lshift
    local rshift = bit32.rshift

    local function u32(value: number): number
        return math.floor(value) % U32
    end

    local function mul32(a: number, b: number): (number, number)
        a = u32(a)
        b = u32(b)
        local a0 = band(a, 0xffff)
        local a1 = rshift(a, 16)
        local b0 = band(b, 0xffff)
        local b1 = rshift(b, 16)
        local p0 = a0 * b0
        local p1 = a0 * b1 + a1 * b0
        local p2 = a1 * b1
        local lowWide = p0 + band(p1, 0xffff) * U16
        local lo = lowWide % U32
        local hi = (math.floor(lowWide / U32) + math.floor(p1 / U16) + p2) % U32
        return lo, hi
    end

    local function add64(lo: number, hi: number, addLo: number, addHi: number): (number, number)
        local nlo = lo + addLo
        local carry = 0
        if nlo >= U32 then
            nlo -= U32
            carry = 1
        end
        return nlo, (hi + addHi + carry) % U32
    end

    local function seedTo64(seed: any): (number, number)
        local value = math.floor(tonumber(seed) or 0)
        local lo = value % U32
        local hi = math.floor(value / U32) % U32
        return lo, hi
    end

    local function next32(state: any): number
        local oldLo = u32(state.Lo or 0)
        local oldHi = u32(state.Hi or 0)
        local loProductLo, loProductHi = mul32(oldLo, MUL_LO)
        local hiMulLo = mul32(oldHi, MUL_LO)
        local loMulHi = mul32(oldLo, MUL_HI)
        state.Lo, state.Hi = add64(loProductLo, (loProductHi + hiMulLo + loMulHi) % U32, INC, 0)

        local shiftedLo = bor(rshift(oldLo, 18), lshift(oldHi, 14))
        local shiftedHi = rshift(oldHi, 18)
        local xorLo = bxor(shiftedLo, oldLo)
        local xorHi = bxor(shiftedHi, oldHi)
        local xorshifted = bor(rshift(xorLo, 27), lshift(xorHi, 5))
        local rot = rshift(oldHi, 27)
        if rot == 0 then
            return u32(xorshifted)
        end
        return u32(bor(rshift(xorshifted, rot), lshift(xorshifted, band(-rot, 31))))
    end

    local function seedState(state: any, seed: any)
        state.Lo = 0
        state.Hi = 0
        next32(state)
        local seedLo, seedHi = seedTo64(seed)
        state.Lo, state.Hi = add64(state.Lo, state.Hi, seedLo, seedHi)
        next32(state)
    end

    local function makeState(seed: any): any
        local state = {Seed = math.floor(tonumber(seed) or 0), Lo = 0, Hi = 0}
        seedState(state, state.Seed)
        return state
    end

    return {
        U32 = U32,
        next = next32,
        mul32 = mul32,
        state = makeState,
    }
end)()


local function createEnvironment(): {[string]: any}
    local env: {[string]: any} = {}

    env.__env2_luraph_step_error = function(step, err)
        local detail = tostring(err):gsub("[\r\n]+", " "):sub(1, 160)
        logAPICall("function_call", string.format("luraph.dispatch_error(%s, %s)", formatValue(step), formatValue(detail)))
    end

    local function safeMemberName(value: any): string
        local text = tostring(value or "Child")
        text = text:gsub("[^%w_]", "_")
        if text == "" then
            return "Child"
        end
        return text
    end

    local vectorValue
    local colorValue
    local dataValue

    local function makeConnection(connectionId: string, callbacks: {[any]: boolean}, callback: any): any
        local connection
        connection = createProxy(connectionId, "RBXScriptConnection", function(_, key)
            local keyText = tostring(key)
            if keyText == "Connected" then
                return callbacks[callback] ~= nil
            end
            if keyText == "Disconnect" then
                return function()
                    callbacks[callback] = nil
                    rawset(connection, "Connected", false)
                    logAPICall("event_connection", connectionId .. ":Disconnect()")
                end
            end
            return nil
        end)
        rawset(connection, "Connected", true)
        return connection
    end

    local signalClock = 0
    local signalStepWorld = nil
    local function makeSignal(signalId: string): any
        local callbacks: {[any]: boolean} = {}
        local signal
        local function signalArgs()
            if signalId:find("Stepped", 1, true) then
                signalClock += 0.016
                return table.pack(signalClock, 0.016)
            end
            if signalId:find("Heartbeat", 1, true) or signalId:find("RenderStepped", 1, true) then
                signalClock += 0.016
                if signalStepWorld then
                    signalStepWorld(0.016)
                end
                return table.pack(signalClock)
            end
            return table.pack()
        end
        local function emit(...)
            for callback, once in pairs(callbacks) do
                if type(callback) == "function" then
                    pcall(callback, ...)
                end
                if once then
                    callbacks[callback] = nil
                end
            end
        end
        signal = createProxy(signalId, "RBXScriptSignal", function(self, key)
            local keyText = tostring(key)
            if keyText == "Connect" or keyText == "ConnectParallel" then
                return function(selfArg, callback)
                    if selfArg ~= signal then
                        error("Expected ':' not '.' calling member function Connect", 2)
                    end
                    callbacks[callback] = false
                    logAPICall("event_connection", string.format("%s:Connect(function)", signalId), signalId .. ".Connection")
                    local args = signalArgs()
                    if args.n > 0 and type(callback) == "function" then
                        pcall(callback, table.unpack(args, 1, args.n))
                        args = signalArgs()
                        pcall(callback, table.unpack(args, 1, args.n))
                    end
                    return makeConnection(signalId .. ".Connection" .. tostring(#callbacks + 1), callbacks, callback)
                end
            end
            if keyText == "Once" then
                return function(selfArg, callback)
                    if selfArg ~= signal then
                        error("Expected ':' not '.' calling member function Once", 2)
                    end
                    callbacks[callback] = true
                    logAPICall("event_connection", string.format("%s:Once(function)", signalId), signalId .. ".OnceConnection")
                    local args = signalArgs()
                    if args.n > 0 and type(callback) == "function" then
                        callbacks[callback] = nil
                        pcall(callback, table.unpack(args, 1, args.n))
                    end
                    return makeConnection(signalId .. ".OnceConnection" .. tostring(#callbacks + 1), callbacks, callback)
                end
            end
            if keyText == "Wait" then
                return function(selfArg)
                    if selfArg ~= signal then
                        error("Expected ':' not '.' calling member function Wait", 2)
                    end
                    logAPICall("method_call", signalId .. ":Wait()")
                    local args = signalArgs()
                    return table.unpack(args, 1, args.n)
                end
            end
            return nil
        end)
        signalEmitters[signal] = emit
        return signal
    end

    local function enumDefault(enumType: string, item: string): any
        local enumRoot = env.Enum
        if enumRoot ~= nil then
            local ok, enumValue = pcall(function()
                return enumRoot[enumType][item]
            end)
            if ok then
                return enumValue
            end
        end
        return createProxy("Enum." .. enumType .. "." .. item, "EnumItem")
    end

    local function defaultRobloxProperty(ownerId: string, className: string, keyText: string): any
        local signalNames = {
            AncestryChanged = true,
            ChildAdded = true,
            ChildRemoved = true,
            DescendantAdded = true,
            DescendantRemoving = true,
            Destroying = true,
            Touched = true,
            TouchEnded = true,
            StateChanged = true,
            Jumping = true,
            FreeFalling = true,
            Seated = true,
            Died = true,
            CharacterAdded = true,
            CharacterRemoving = true,
            PlayerAdded = true,
            PlayerRemoving = true,
            ServiceAdded = true,
            MessageOut = true,
            InputBegan = true,
            InputEnded = true,
            InputChanged = true,
            Hit = true,
            DragStart = true,
            DragContinue = true,
            DragEnd = true,
        }
        if signalNames[keyText] or keyText:sub(-7) == "Changed" then
            return makeSignal(ownerId .. "." .. safeMemberName(keyText))
        end
        if className == "BindableEvent" and keyText == "Event" then
            return makeSignal(ownerId .. ".Event")
        end
        if className == "Stats" then
            if keyText:match("Count$")
                or keyText:find("Drawcall", 1, true) ~= nil
                or keyText:find("Triangle", 1, true) ~= nil
                or keyText:find("Kbps", 1, true) ~= nil
                or keyText:find("Time", 1, true) ~= nil
                or keyText:find("Memory", 1, true) ~= nil then
                return 0
            end
        end

        local guiClass = className == "Frame"
            or className == "TextLabel"
            or className == "TextButton"
            or className == "TextBox"
            or className == "ImageLabel"
            or className == "ImageButton"
            or className == "ScrollingFrame"
        if dataValue and guiClass and (keyText == "Position" or keyText == "Size") then
            return dataValue("UDim2", {
                X = dataValue("UDim", {Scale = 0, Offset = 0}),
                Y = dataValue("UDim", {Scale = 0, Offset = 0}),
            })
        end

        if vectorValue then
            if keyText == "AnchorPoint" then
                return vectorValue("Vector2", 0, 0)
            end
            if keyText == "Position"
                or keyText == "Orientation"
                or keyText == "Velocity"
                or keyText == "AssemblyLinearVelocity"
                or keyText == "AssemblyAngularVelocity"
                or keyText == "MoveDirection" then
                return vectorValue("Vector3", 0, 0, 0)
            end
            if keyText == "Size" and (className == "Part" or className == "BasePart" or className == "MeshPart" or className == "UnionOperation") then
                return vectorValue("Vector3", 1, 1, 1)
            end
            if keyText == "CFrame" or keyText == "Focus" then
                return vectorValue("CFrame", 0, 0, 0)
            end
            if keyText == "TextBounds" then
                return vectorValue("Vector2", 0, 0)
            end
        end

        if colorValue and (
            keyText == "Color"
            or keyText == "BrickColor"
            or keyText == "Ambient"
            or keyText == "OutdoorAmbient"
            or keyText == "FogColor"
            or keyText == "TintColor"
            or keyText == "BorderColor3"
            or keyText == "BackgroundColor3"
            or keyText == "TextColor3"
            or keyText == "TextStrokeColor3"
            or keyText == "SparkleColor"
        ) then
            return colorValue(1, 1, 1)
        end

        local booleanProperties = {
            Anchored = false,
            Massless = false,
            CastShadow = true,
            CanCollide = true,
            CanQuery = true,
            CanTouch = true,
            Visible = true,
            Enabled = true,
            TouchEnabled = false,
            KeyboardEnabled = true,
            MouseEnabled = true,
            GamepadEnabled = false,
            AccelerometerEnabled = false,
            GyroscopeEnabled = false,
            VREnabled = false,
            MouseIconEnabled = true,
            IsForSale = false,
            GlobalShadows = true,
            AutoRotate = true,
            Active = false,
            ClipsDescendants = false,
            Selectable = false,
            Interactable = true,
        }
        if booleanProperties[keyText] ~= nil then
            return booleanProperties[keyText]
        end

        local numberProperties = {
            Transparency = 0,
            Reflectance = 0,
            RootPriority = 0,
            JumpHeight = 7.2,
            WalkSpeed = 16,
            Health = 100,
            MaxHealth = 100,
            Intensity = 0,
            Threshold = 0,
            Size = 1,
            Brightness = 1,
            FogEnd = 100000,
            FogStart = 0,
            GeographicLatitude = 41,
            FieldOfView = 70,
            NearPlaneZ = -0.5,
            FallenPartsDestroyHeight = -500,
            Gravity = 196.2,
            ContactsCount = 0,
            PlaceVersion = 1,
            AccountAge = 365,
            AssetTypeId = 0,
            FocusDistance = 0,
            HipHeight = 2,
            BlastRadius = 4,
            Stiffness = 0,
            Length = 0,
            Density = 0,
            DataReceiveKbps = 0,
            DataSendKbps = 0,
            FrameTime = 0,
            HeartbeatTime = 0,
            HeartbeatTimeMs = 0,
            InstanceCount = 0,
            MovingPrimitivesCount = 0,
            PhysicsReceiveKbps = 0,
            PhysicsSendKbps = 0,
            PhysicsStepTime = 0,
            PhysicsStepTimeMs = 0,
            PrimitivesCount = 0,
            RenderCPUFrameTime = 0,
            RenderGPUFrameTime = 0,
            SceneDrawcallCount = 0,
            SceneTriangleCount = 0,
            StarCount = 3000,
            Rotation = 0,
            ZIndex = 1,
            LayoutOrder = 0,
            TextStrokeTransparency = 1,
            HeadScale = 1,
            BodyTypeScale = 0,
            DepthScale = 1,
            HeightScale = 1,
            ProportionScale = 0,
            WidthScale = 1,
        }
        if numberProperties[keyText] ~= nil then
            return numberProperties[keyText]
        end

        local stringProperties = {
            CollisionGroup = "Default",
            Text = "",
            TimeOfDay = "14:00:00",
            MouseIcon = "",
            ClientGitHash = "0000000000000000000000000000000000000000",
            Name = className,
        }
        if stringProperties[keyText] ~= nil then
            return stringProperties[keyText]
        end

        if keyText == "MembershipType" then
            return enumDefault("MembershipType", "None")
        end
        if keyText == "TextTruncate" then
            return enumDefault("TextTruncate", "None")
        end
        if keyText == "TextXAlignment" then
            return enumDefault("TextXAlignment", "Left")
        end
        if keyText == "TextYAlignment" then
            return enumDefault("TextYAlignment", "Top")
        end
        if keyText == "MouseBehavior" then
            return enumDefault("MouseBehavior", "Default")
        end
        if keyText == "ActuatorType" then
            return enumDefault("ActuatorType", "None")
        end
        if keyText == "RunState" then
            return enumDefault("RunState", "Running")
        end
        if keyText == "Interpolation" then
            return enumDefault("InterpolationMode", "Linear")
        end
        if keyText == "Font" then
            return enumDefault("Font", "SourceSans")
        end
        if keyText == "FontFace" then
            return dataValue("Font", {Family = "SourceSansPro", Weight = enumDefault("FontWeight", "Regular"), Style = enumDefault("FontStyle", "Normal")})
        end
        if keyText == "DisplayDistanceType" then
            return enumDefault("HumanoidDisplayDistanceType", "Viewer")
        end

        return nil
    end

    local function makeRobloxProxy(varId: string, typeName: string, fields: {[string]: any}?): any
        local values = fields or {}
        local children: {[string]: any} = {}
        local attributes: {[string]: any} = {}
        if rawget(values, "ClassName") == nil then
            values.ClassName = typeName
        end
        if rawget(values, "Name") == nil then
            values.Name = varId:match("([^%.]+)$") or typeName
        end
        if rawget(values, "Archivable") == nil then
            values.Archivable = true
        end
        if rawget(values, "Changed") == nil then
            values.Changed = makeSignal(varId .. ".Changed")
        end
        registerVariable(varId, "Instance", typeName)

        local function child(childName: any, childType: string?): any
            local key = tostring(childName or "Child")
            local direct = rawget(values, key)
            if direct ~= nil then
                return direct
            end
            if not children[key] then
                local childId = varId .. "." .. safeMemberName(key)
                logAPICall("property_access", childId, childId)
                registerVariable(childId, "Instance", childType or key, varId)
                children[key] = createProxy(childId, childType or key)
            end
            return children[key]
        end

        local function directChild(childName: any, root: any?): any
            local key = tostring(childName or "Child")
            if root ~= nil then
                local rawChild = rawget(root, key)
                if rawChild ~= nil then
                    return rawChild
                end
            end
            local direct = rawget(values, key)
            if direct ~= nil then
                return direct
            end
            if children[key] ~= nil then
                return children[key]
            end
            local linked = root and instanceChildren[root]
            if linked then
                for value in pairs(linked) do
                    if rawget(value, "Name") == key then
                        return value
                    end
                end
            end
            return nil
        end

        local function findDescendantByName(root: any, childName: any): any
            local wanted = tostring(childName or "")
            local stack = {}
            for _, value in pairs(children) do
                table.insert(stack, value)
            end
            local linked = instanceChildren[root]
            if linked then
                for value in pairs(linked) do
                    table.insert(stack, value)
                end
            end
            while #stack > 0 do
                local current = table.remove(stack)
                local currentName = rawget(current, "Name")
                if currentName == wanted then
                    return current
                end
                local nested = instanceChildren[current]
                if nested then
                    for value in pairs(nested) do
                        table.insert(stack, value)
                    end
                end
            end
            return nil
        end

        local function appendFieldChildren(out: {any}, seen: {[any]: boolean})
            for _, value in pairs(values) do
                if type(value) == "table" and proxyRegistry[value] and not seen[value] then
                    local childType = proxyTypeNames[value]
                    local parentValue = rawget(value, "Parent")
                    if parentValue == nil then
                        parentValue = rawget(value, "__ParentCleared") and nil or nil
                    end
                    if childType ~= "RBXScriptSignal"
                        and childType ~= "RBXScriptConnection"
                        and childType ~= "Enum"
                        and childType ~= "EnumType"
                        and (parentValue == proxy or rawget(value, "Parent") == proxy) then
                        seen[value] = true
                        table.insert(out, value)
                    end
                end
            end
        end

        local function classIsA(className: any, wanted: any): boolean
            className = tostring(className or "")
            wanted = tostring(wanted or "")
            if className == wanted or wanted == "Instance" then
                return true
            end
            local bases = {
                Part = {"BasePart", "PVInstance"},
                MeshPart = {"BasePart", "PVInstance"},
                SpawnLocation = {"BasePart", "PVInstance"},
                WedgePart = {"BasePart", "PVInstance"},
                CornerWedgePart = {"BasePart", "PVInstance"},
                TrussPart = {"BasePart", "PVInstance"},
                Seat = {"BasePart", "PVInstance"},
                VehicleSeat = {"BasePart", "PVInstance"},
                Terrain = {"BasePart", "PVInstance"},
                Model = {"PVInstance"},
                Camera = {"PVInstance"},
                TextLabel = {"GuiObject", "GuiBase2d"},
                TextButton = {"GuiButton", "GuiObject", "GuiBase2d"},
                ImageButton = {"GuiButton", "GuiObject", "GuiBase2d"},
                TextBox = {"GuiObject", "GuiBase2d"},
                Frame = {"GuiObject", "GuiBase2d"},
                ScrollingFrame = {"GuiObject", "GuiBase2d"},
                ImageLabel = {"GuiObject", "GuiBase2d"},
            }
            local list = bases[className]
            if list then
                for _, base in ipairs(list) do
                    if base == wanted then
                        return true
                    end
                end
            end
            return false
        end

        local methods: {[string]: any} = {}
        methods.WaitForChild = function(self, name, timeout)
            logAPICall("method_call", string.format("%s:WaitForChild(%s, %s)", varId, formatValue(name), formatValue(timeout)))
            local found = directChild(name, self) or findDescendantByName(self, name)
            if found ~= nil then
                return found
            end
            if timeout ~= nil and waitForChildPumpTasks then
                local deadline = tonumber(timeout) or 0
                if deadline > 0 then
                    local elapsed = 0
                    while elapsed <= deadline do
                        local remaining = deadline - elapsed
                        if remaining <= 0 then
                            break
                        end
                        local step = math.min(0.05, remaining)
                        waitForChildPumpTasks(step)
                        found = directChild(name, self) or findDescendantByName(self, name)
                        if found ~= nil then
                            return found
                        end
                        elapsed += step
                    end
                end
            end
            if timeout ~= nil then
                return nil
            end
            return child(name)
        end
        methods.FindFirstChild = function(self, name, recursive)
            logAPICall("method_call", string.format("%s:FindFirstChild(%s, %s)", varId, formatValue(name), formatValue(recursive)))
            return directChild(name, self) or (recursive and findDescendantByName(self, name) or nil)
        end
        methods.FindFirstChildOfClass = function(self, className)
            logAPICall("method_call", string.format("%s:FindFirstChildOfClass(%s)", varId, formatValue(className)))
            local wanted = tostring(className or "")
            local function matches(value)
                if type(value) ~= "table" then
                    return false
                end
                local valueClass = rawget(value, "ClassName") or proxyTypeNames[value]
                return classIsA(valueClass, wanted)
            end
            for _, value in pairs(self) do
                if matches(value) then
                    return value
                end
            end
            for _, value in pairs(values) do
                if matches(value) then
                    return value
                end
            end
            for _, value in pairs(children) do
                if matches(value) then
                    return value
                end
            end
            local linked = instanceChildren[self]
            if linked then
                for value in pairs(linked) do
                    if matches(value) and rawget(value, "Parent") == self then
                        return value
                    end
                end
            end
            return nil
        end
        methods.FindFirstChildWhichIsA = methods.FindFirstChildOfClass
        methods.FindFirstAncestor = function(_, name)
            logAPICall("method_call", string.format("%s:FindFirstAncestor(%s)", varId, formatValue(name)))
            return createProxy(varId .. ".Ancestor_" .. safeMemberName(name), tostring(name or "Instance"))
        end
        methods.FindFirstAncestorOfClass = function(self, className)
            logAPICall("method_call", string.format("%s:FindFirstAncestorOfClass(%s)", varId, formatValue(className)))
            local current = rawget(self, "Parent")
            while type(current) == "table" do
                if rawget(current, "ClassName") == className or proxyTypeNames[current] == className then
                    return current
                end
                current = rawget(current, "Parent")
            end
            return nil
        end
        methods.FindFirstAncestorWhichIsA = function(self, className)
            logAPICall("method_call", string.format("%s:FindFirstAncestorWhichIsA(%s)", varId, formatValue(className)))
            local current = rawget(self, "Parent")
            while type(current) == "table" do
                local currentClass = rawget(current, "ClassName") or proxyTypeNames[current]
                if currentClass == className or className == "Instance" then
                    return current
                end
                current = rawget(current, "Parent")
            end
            return nil
        end
        methods.GetChildren = function(self)
            logAPICall("method_call", string.format("%s:GetChildren()", varId))
            local out = {}
            local seen: {[any]: boolean} = {}
            for _, value in pairs(self) do
                if type(value) == "table" and proxyRegistry[value] and not seen[value] then
                    local childType = proxyTypeNames[value]
                    if childType ~= "RBXScriptSignal" and childType ~= "RBXScriptConnection" and rawget(value, "Parent") == self then
                        seen[value] = true
                        table.insert(out, value)
                    end
                end
            end
            for _, value in pairs(children) do
                if not seen[value] and rawget(value, "Parent") == self then
                    seen[value] = true
                    table.insert(out, value)
                end
            end
            local linked = instanceChildren[self] or nil
            if linked then
                for value in pairs(linked) do
                    if not seen[value] and rawget(value, "Parent") == self then
                        seen[value] = true
                        table.insert(out, value)
                    end
                end
            end
            appendFieldChildren(out, seen)
            return out
        end
        methods.GetDescendants = function(self)
            logAPICall("method_call", string.format("%s:GetDescendants()", varId))
            local out = {}
            local function collect(root)
                local linked = instanceChildren[root]
                if linked then
                    for value in pairs(linked) do
                        table.insert(out, value)
                        collect(value)
                    end
                end
            end
            for _, value in pairs(children) do
                table.insert(out, value)
                collect(value)
            end
            collect(self)
            return out
        end
        methods.ClearAllChildren = function(self)
            logAPICall("method_call", string.format("%s:ClearAllChildren()", varId))
            local function clearLinked(root)
                local linkedChildren = instanceChildren[root]
                if not linkedChildren then
                    return
                end
                for value in pairs(linkedChildren) do
                        if type(value) == "table" then
                            clearLinked(value)
                            rawset(value, "Parent", nil)
                            rawset(value, "__ParentCleared", true)
                            rawset(value, "__Destroyed", true)
                        end
                    end
                    instanceChildren[root] = {}
                end
            for key in pairs(children) do
                children[key] = nil
            end
            local linked = instanceChildren[self]
            if linked then
                for value in pairs(linked) do
                    if type(value) == "table" then
                        clearLinked(value)
                        rawset(value, "Parent", nil)
                        rawset(value, "__ParentCleared", true)
                        rawset(value, "__Destroyed", true)
                    end
                end
                instanceChildren[self] = {}
            end
            for value, className in pairs(proxyTypeNames) do
                if className ~= "RBXScriptSignal" and className ~= "RBXScriptConnection" and rawget(value, "Parent") == self then
                    clearLinked(value)
                    rawset(value, "Parent", nil)
                    rawset(value, "__ParentCleared", true)
                    rawset(value, "__Destroyed", true)
                end
            end
        end
        methods.GetFullName = function(self)
            logAPICall("method_call", string.format("%s:GetFullName()", varId))
            local name = rawget(self, "Name") or rawget(values, "Name")
            if name == "workspace" then
                return "Workspace"
            end
            if type(name) == "string" and name ~= "" then
                return name
            end
            return varId
        end
        methods.IsA = function(_, className)
            logAPICall("method_call", string.format("%s:IsA(%s)", varId, formatValue(className)))
            return classIsA(typeName, className)
        end
        methods.IsDescendantOf = function(self, ancestor)
            logAPICall("method_call", string.format("%s:IsDescendantOf(%s)", varId, formatValue(ancestor)))
            local current = rawget(self, "Parent") or rawget(values, "Parent")
            while current ~= nil do
                if current == ancestor then
                    return true
                end
                if type(current) ~= "table" then
                    break
                end
                current = rawget(current, "Parent")
            end
            return false
        end
        methods.IsAncestorOf = function(self, descendant)
            logAPICall("method_call", string.format("%s:IsAncestorOf(%s)", varId, formatValue(descendant)))
            if type(descendant) ~= "table" then
                return false
            end
            local current = rawget(descendant, "Parent")
            while current ~= nil do
                if current == self then
                    return true
                end
                if type(current) ~= "table" then
                    break
                end
                current = rawget(current, "Parent")
            end
            return false
        end
        methods.Clone = function(self)
            logAPICall("method_call", string.format("%s:Clone()", varId))
            if typeName == "DataModel" or typeName == "Workspace" then
                error("The current identity cannot Clone class " .. typeName, 2)
            end
            local archivable = rawget(self, "Archivable")
            if archivable == nil then
                archivable = rawget(values, "Archivable")
            end
            if archivable == false then
                return nil
            end
            local cloneFields = {}
            for key, value in pairs(values) do
                if key ~= "Parent" and key ~= "Changed" and type(key) == "string" and not key:match("^__") then
                    cloneFields[key] = value
                end
            end
            for key, value in pairs(self) do
                if key ~= "Parent" and key ~= "Changed" and type(key) == "string" and not key:match("^__") then
                    cloneFields[key] = value
                end
            end
            cloneFields.Parent = nil
            cloneFields.ClassName = typeName
            cloneFields.Name = cloneFields.Name or typeName
            cloneFields.Archivable = archivable
            return makeRobloxProxy(varId .. "_Clone", typeName, cloneFields)
        end
        methods.Destroy = function(self)
            logAPICall("method_call", string.format("%s:Destroy()", varId))
            if typeName == "DataModel" or typeName == "Workspace" or typeName == "Players" then
                error("The current identity cannot Destroy class " .. typeName, 2)
            end
            local function detachTree(root)
                local linkedChildren = instanceChildren[root]
                if linkedChildren then
                    for descendant in pairs(linkedChildren) do
                        if type(descendant) == "table" then
                            detachTree(descendant)
                            rawset(descendant, "Parent", nil)
                            rawset(descendant, "__ParentCleared", true)
                            rawset(descendant, "__Destroyed", true)
                        end
                    end
                    instanceChildren[root] = nil
                end
            end
            local parent = rawget(self, "Parent")
            if type(parent) == "table" and instanceChildren[parent] then
                instanceChildren[parent][self] = nil
            end
            if type(parent) == "table" then
                local childRemoved = rawget(parent, "ChildRemoved")
                local childRemovedEmitter = childRemoved and signalEmitters[childRemoved]
                if childRemovedEmitter then
                    childRemovedEmitter(self)
                end
            end
            local destroying = rawget(self, "Destroying")
            local destroyingEmitter = destroying and signalEmitters[destroying]
            if destroyingEmitter then
                destroyingEmitter()
            end
            local ancestryChanged = rawget(self, "AncestryChanged")
            local ancestryChangedEmitter = ancestryChanged and signalEmitters[ancestryChanged]
            if ancestryChangedEmitter then
                ancestryChangedEmitter(self, nil)
            end
            detachTree(self)
            rawset(self, "Parent", nil)
            rawset(self, "__ParentCleared", true)
            rawset(self, "__Destroyed", true)
        end
        methods.GetAttribute = function(_, name)
            logAPICall("method_call", string.format("%s:GetAttribute(%s)", varId, formatValue(name)))
            return attributes[tostring(name)]
        end
        methods.SetAttribute = function(_, name, value)
            logAPICall("method_call", string.format("%s:SetAttribute(%s, %s)", varId, formatValue(name), formatValue(value)))
            attributes[tostring(name)] = value
        end
        methods.GetAttributes = function()
            logAPICall("method_call", string.format("%s:GetAttributes()", varId))
            local copy = {}
            for key, value in pairs(attributes) do
                copy[key] = value
            end
            return copy
        end
        methods.AddTag = function(self, tag)
            logAPICall("method_call", string.format("%s:AddTag(%s)", varId, formatValue(tag)))
            local tags = collectionTagStore[self]
            if not tags then
                tags = {}
                collectionTagStore[self] = tags
            end
            tags[tostring(tag)] = true
        end
        methods.RemoveTag = function(self, tag)
            logAPICall("method_call", string.format("%s:RemoveTag(%s)", varId, formatValue(tag)))
            local tags = collectionTagStore[self]
            if tags then
                tags[tostring(tag)] = nil
            end
        end
        methods.HasTag = function(self, tag)
            local tags = collectionTagStore[self]
            return tags and tags[tostring(tag)] == true or false
        end
        methods.GetTags = function(self)
            local out = {}
            local tags = collectionTagStore[self]
            if tags then
                for tag in pairs(tags) do
                    table.insert(out, tag)
                end
            end
            table.sort(out)
            return out
        end
        methods.GetMass = function()
            logAPICall("method_call", string.format("%s:GetMass()", varId))
            return 1
        end
        methods.GetTouchingParts = function()
            logAPICall("method_call", string.format("%s:GetTouchingParts()", varId))
            return {}
        end
        if typeName == "Humanoid" then
            methods.ChangeState = function(self, state)
                logAPICall("method_call", string.format("%s:ChangeState(%s)", varId, formatValue(state)))
                local parent = rawget(self, "Parent") or rawget(values, "Parent")
                local rootPart = parent and (directChild("HumanoidRootPart", parent) or findDescendantByName(parent, "HumanoidRootPart"))
                if type(rootPart) == "table" then
                    local position = rawget(rootPart, "Position") or defaultRobloxProperty(varId .. ".HumanoidRootPart", "Part", "Position")
                    if objectTypeNames[position] == "Vector3" then
                        rawset(rootPart, "Position", vectorValue("Vector3", position.X or 0, (position.Y or 0) + 5, position.Z or 0))
                    end
                end
                rawset(self, "MoveDirection", vectorValue("Vector3", 0, 0, 0))
                rawset(self, "State", state)
            end
            methods.GetState = function(self)
                logAPICall("method_call", string.format("%s:GetState()", varId))
                return rawget(self, "State") or enumDefault("HumanoidStateType", "Running")
            end
        end
        if typeName == "BindableEvent" then
            methods.Fire = function(self, ...)
                logAPICall("method_call", string.format("%s:Fire(...)", varId))
                local event = rawget(self, "Event")
                if not event then
                    event = makeSignal(varId .. ".Event")
                    rawset(self, "Event", event)
                end
                local emitter = signalEmitters[event]
                if emitter then
                    emitter(...)
                end
            end
        end

        local propertySignals: {[string]: any} = {}
        local proxy
        proxy = createProxy(varId, typeName, function(self, key)
            if type(key) == "number" then
                error(string.format("%s is not a valid member of %s", tostring(key), typeName), 2)
            end
            local keyText = tostring(key)
            if typeName == "CollectionService" then
                local serviceValue = rawget(values, keyText)
                if serviceValue ~= nil then
                    return serviceValue
                end
            end
            local method = methods[keyText]
            if method ~= nil then
                return method
            end
            if keyText == "GetPropertyChangedSignal" then
                return function(_, propertyName)
                    logAPICall("method_call", string.format("%s:GetPropertyChangedSignal(%s)", varId, formatValue(propertyName)))
                    local propertyKey = tostring(propertyName or "")
                    if not propertySignals[propertyKey] then
                        propertySignals[propertyKey] = makeSignal(varId .. "." .. safeMemberName(propertyName) .. "Changed")
                    end
                    return propertySignals[propertyKey]
                end
            end
            if keyText == "Parent" and rawget(self, "__ParentCleared") then
                logAPICall("property_access", varId .. ".Parent")
                return nil
            end
            local stored = rawget(self, keyText)
            if stored ~= nil then
                logAPICall("property_access", varId .. "." .. keyText, varId .. "." .. safeMemberName(keyText))
                return stored
            end
            if typeName == "Workspace" and keyText == "DistributedGameTime" then
                local current = tonumber(rawget(values, "DistributedGameTime")) or 0
                current += 0.1
                rawset(values, "DistributedGameTime", current)
                logAPICall("property_access", varId .. ".DistributedGameTime")
                return current
            end
            if keyText == "Parent" then
                local parentValue = rawget(values, "Parent")
                logAPICall("property_access", varId .. ".Parent")
                return parentValue
            end
            local value = rawget(values, keyText)
            if value ~= nil then
                logAPICall("property_access", varId .. "." .. keyText, varId .. "." .. safeMemberName(keyText))
                return value
            end
            local defaultValue = defaultRobloxProperty(varId, typeName, keyText)
            if defaultValue ~= nil then
                rawset(self, keyText, defaultValue)
                logAPICall("property_access", varId .. "." .. keyText, varId .. "." .. safeMemberName(keyText))
                return defaultValue
            end
            return child(keyText)
        end)
        instanceSignals[proxy] = {
            Changed = values.Changed,
            Properties = propertySignals,
        }
        rawset(proxy, "__RobloxInstance", true)
        return proxy
    end

    local characterModel = makeRobloxProxy("Players.LocalPlayer.Character", "Model", {
        Name = "Character",
        ClassName = "Model",
    })
    local humanoidRootPart = makeRobloxProxy("Players.LocalPlayer.Character.HumanoidRootPart", "Part", {
        Name = "HumanoidRootPart",
        ClassName = "Part",
        Parent = characterModel,
    })
    local humanoid = makeRobloxProxy("Players.LocalPlayer.Character.Humanoid", "Humanoid", {
        Name = "Humanoid",
        ClassName = "Humanoid",
        Parent = characterModel,
        AutoRotate = true,
    })
    rawset(characterModel, "HumanoidRootPart", humanoidRootPart)
    rawset(characterModel, "Humanoid", humanoid)

    local localPlayer = makeRobloxProxy("Players.LocalPlayer", "Player", {
        Name = "Player",
        DisplayName = "Player",
        UserId = 1,
        AccountAge = 365,
        MembershipType = enumDefault("MembershipType", "None"),
        PlayerGui = makeRobloxProxy("Players.LocalPlayer.PlayerGui", "PlayerGui"),
        Backpack = makeRobloxProxy("Players.LocalPlayer.Backpack", "Backpack"),
        PlayerScripts = makeRobloxProxy("Players.LocalPlayer.PlayerScripts", "PlayerScripts"),
        Character = characterModel,
        CharacterAdded = makeSignal("Players.LocalPlayer.CharacterAdded"),
        CharacterRemoving = makeSignal("Players.LocalPlayer.CharacterRemoving"),
        GetMouse = function()
            logAPICall("method_call", "Players.LocalPlayer:GetMouse()")
            return makeRobloxProxy("Players.LocalPlayer.Mouse", "PlayerMouse")
        end,
        Kick = function(_, reason)
            logAPICall("security_block", string.format("Players.LocalPlayer:Kick(%s)", formatValue(reason)))
        end,
    })

    local playersService = makeRobloxProxy("Players", "Players", {
        LocalPlayer = localPlayer,
        PlayerAdded = makeSignal("Players.PlayerAdded"),
        PlayerRemoving = makeSignal("Players.PlayerRemoving"),
        GetPlayers = function()
            logAPICall("method_call", "Players:GetPlayers()")
            return {localPlayer}
        end,
        GetPlayerFromCharacter = function(_, character)
            logAPICall("method_call", "Players:GetPlayerFromCharacter(...)")
            if character == characterModel then
                return localPlayer
            end
            return nil
        end,
        GetNameFromUserIdAsync = function(_, userId)
            logAPICall("method_call", string.format("Players:GetNameFromUserIdAsync(%s)", formatValue(userId)))
            local id = tonumber(userId)
            if id == localPlayer.UserId then
                return localPlayer.Name
            end
            error("UserId is not a valid user", 2)
        end,
    })
    env.Players = playersService

    local workspaceTime = 1000
    local workspaceService
    workspaceService = makeRobloxProxy("workspace", "Workspace", {
        Name = "Workspace",
        ClassName = "Workspace",
        DistributedGameTime = workspaceTime,
        FallenPartsDestroyHeight = -500,
        Gravity = 196.2,
        GetServerTimeNow = function()
            workspaceTime += 0.1
            logAPICall("method_call", "workspace:GetServerTimeNow()")
            return workspaceTime
        end,
        GetPartsInPart = function()
            logAPICall("method_call", "workspace:GetPartsInPart(...)")
            return {}
        end,
        GetPartBoundsInBox = function()
            logAPICall("method_call", "workspace:GetPartBoundsInBox(...)")
            return {}
        end,
        GetPartBoundsInRadius = function()
            logAPICall("method_call", "workspace:GetPartBoundsInRadius(...)")
            return {}
        end,
        Raycast = function(_, origin, direction, params)
            logAPICall("method_call", "workspace:Raycast(...)")
            local hitInstance = (env.workspace and (rawget(env.workspace, "Baseplate") or rawget(env.workspace, "Terrain"))) or env.workspace
            local linked = instanceChildren[workspaceService]
            local filter = type(params) == "table" and rawget(params, "FilterDescendantsInstances") or nil
            local filterTypeValue = type(params) == "table" and rawget(params, "FilterType") or nil
            local filterType = type(filterTypeValue) == "table" and rawget(filterTypeValue, "Name") or tostring(filterTypeValue or "")
            local function isFiltered(instance)
                if type(filter) ~= "table" then
                    return false
                end
                for _, item in pairs(filter) do
                    if item == instance then
                        return true
                    end
                    if type(instance) == "table" and type(item) == "table" then
                        local current = rawget(instance, "Parent")
                        while type(current) == "table" do
                            if current == item then
                                return true
                            end
                            current = rawget(current, "Parent")
                        end
                    end
                end
                return false
            end
            if linked then
                local bestOrder = -1
                for value in pairs(linked) do
                    if type(value) == "table" and (rawget(value, "ClassName") == "Part" or proxyTypeNames[value] == "Part") then
                        local filtered = isFiltered(value)
                        if (filterType == "Include" and not filtered) or (filterType ~= "Include" and filtered) then
                            continue
                        end
                        local order = tonumber(rawget(value, "__CreatedOrder")) or 0
                        if order >= bestOrder then
                            bestOrder = order
                            hitInstance = value
                        end
                    end
                end
            end
            return dataValue("RaycastResult", {
                Position = vectorValue("Vector3", 0, 0, 0),
                Normal = vectorValue("Vector3", 0, 1, 0),
                Material = enumDefault("Material", "Plastic"),
                Distance = 0,
                Instance = hitInstance,
            })
        end,
    })
    env.workspace = workspaceService
    env.Workspace = workspaceService

    local runService = makeRobloxProxy("RunService", "RunService", {
        Name = "RunService",
        ClassName = "RunService",
        Heartbeat = makeSignal("RunService.Heartbeat"),
        RenderStepped = makeSignal("RunService.RenderStepped"),
        Stepped = makeSignal("RunService.Stepped"),
        ClientGitHash = "0000000000000000000000000000000000000000",
        IsClient = function()
            logAPICall("method_call", "RunService:IsClient()")
            return true
        end,
        IsServer = function()
            logAPICall("method_call", "RunService:IsServer()")
            return false
        end,
        IsRunning = function()
            logAPICall("method_call", "RunService:IsRunning()")
            return true
        end,
        IsStudio = function()
            logAPICall("method_call", "RunService:IsStudio()")
            return false
        end,
    })

    local ugcRoot = makeRobloxProxy("Ugc", "DataModel", {
        Name = "Ugc",
        ClassName = "DataModel",
    })
    local chatService = makeRobloxProxy("Chat", "Chat", {
        Name = "Chat",
        ClassName = "Chat",
        Parent = ugcRoot,
    })
    local networkClient = makeRobloxProxy("NetworkClient", "NetworkClient", {
        Name = "NetworkClient",
        ClassName = "NetworkClient",
        ClientReplicator = makeRobloxProxy("NetworkClient.ClientReplicator", "ClientReplicator", {
            Name = "ClientReplicator",
            ClassName = "ClientReplicator",
        }),
    })

    local function getUrlFromOptions(options: any): string?
        if type(options) == "string" and options:match("^https?://") then
            return options
        end
        if type(options) == "table" then
            local direct = rawget(options, "Url") or rawget(options, "URL") or rawget(options, "url")
            if type(direct) == "string" and direct:match("^https?://") then
                return direct
            end
        end
        return nil
    end

    local function getUrlFromArgs(args: {any}): string?
        for _, value in ipairs(args) do
            if type(value) == "string" and value:match("^https?://") then
                return value
            end
            local nested = getUrlFromOptions(value)
            if nested then
                return nested
            end
        end
        return nil
    end

    local function remoteBody(label: string, args: {any}): string
        local url = getUrlFromArgs(args)
        if url then
            recordStaticHint("url", url, true)
            if url == "https://pastefy.app/r6upMyCZ/raw" then
                return 'print("hi!")'
            end
            return string.format('return __remote_stub("%s")', escapeLuaString(url))
        end
        return string.format('return __remote_stub("%s")', escapeLuaString(label))
    end

    local function robloxHttpMethod(name: string)
        return function(...: any)
            local args = {...}
            local argStrs: {string} = {}
            for index, value in ipairs(args) do
                if index > 8 then
                    table.insert(argStrs, "...")
                    break
                end
                table.insert(argStrs, formatValue(value))
            end
            local label = "game." .. name
            logAPICall("http_request", string.format("%s(%s)", label, table.concat(argStrs, ", ")))
            return remoteBody(label, args)
        end
    end

    local function httpServiceRemoteMethod(name: string)
        return function(...: any)
            local args = {...}
            local argStrs: {string} = {}
            local startIndex = proxyRegistry[args[1]] == "HttpService" and 2 or 1
            for index = startIndex, #args do
                local value = args[index]
                if index - startIndex >= 8 then
                    table.insert(argStrs, "...")
                    break
                end
                table.insert(argStrs, formatValue(value))
            end
            local label = "HttpService:" .. name
            logAPICall("http_request", string.format("%s(%s)", label, table.concat(argStrs, ", ")))
            return remoteBody(label, args)
        end
    end

    local function decodeJsonValue(text: string, index: number): (any, number)
        local function skipSpace(i)
            while i <= #text and text:sub(i, i):match("%s") do
                i += 1
            end
            return i
        end
        local function parseString(i)
            i += 1
            local out = {}
            while i <= #text do
                local ch = text:sub(i, i)
                if ch == '"' then
                    return table.concat(out), i + 1
                end
                if ch == "\\" then
                    local nextCh = text:sub(i + 1, i + 1)
                    local escapes = {['"'] = '"', ["\\"] = "\\", ["/"] = "/", b = "\b", f = "\f", n = "\n", r = "\r", t = "\t"}
                    table.insert(out, escapes[nextCh] or nextCh)
                    i += 2
                else
                    table.insert(out, ch)
                    i += 1
                end
            end
            return table.concat(out), i
        end
        local function parseArray(i)
            local out = {}
            local arrayIndex = 1
            i = skipSpace(i + 1)
            if text:sub(i, i) == "]" then
                return out, i + 1
            end
            while i <= #text do
                local value
                value, i = decodeJsonValue(text, i)
                out[arrayIndex] = value
                arrayIndex += 1
                i = skipSpace(i)
                local ch = text:sub(i, i)
                if ch == "]" then
                    return out, i + 1
                end
                if ch ~= "," then
                    return out, i
                end
                i = skipSpace(i + 1)
            end
            return out, i
        end
        local function parseObject(i)
            local out = {}
            i = skipSpace(i + 1)
            if text:sub(i, i) == "}" then
                return out, i + 1
            end
            while i <= #text do
                local key
                key, i = parseString(skipSpace(i))
                i = skipSpace(i)
                if text:sub(i, i) == ":" then
                    i += 1
                end
                local value
                value, i = decodeJsonValue(text, i)
                out[key] = value
                i = skipSpace(i)
                local ch = text:sub(i, i)
                if ch == "}" then
                    return out, i + 1
                end
                if ch ~= "," then
                    return out, i
                end
                i = skipSpace(i + 1)
            end
            return out, i
        end
        index = skipSpace(index)
        local ch = text:sub(index, index)
        if ch == '"' then
            return parseString(index)
        end
        if ch == "[" then
            return parseArray(index)
        end
        if ch == "{" then
            return parseObject(index)
        end
        local literal = text:sub(index)
        if literal:sub(1, 4) == "true" then
            return true, index + 4
        end
        if literal:sub(1, 5) == "false" then
            return false, index + 5
        end
        if literal:sub(1, 4) == "null" then
            return nil, index + 4
        end
        local numberText = literal:match("^-?%d+%.?%d*[eE]?[+-]?%d*") or ""
        if numberText ~= "" then
            return tonumber(numberText), index + #numberText
        end
        return nil, index + 1
    end

    local function makeJsonProxy(label: string): any
        local storage = {}
        local mt = {}

        mt.__index = function(self, key)
            local keyText = tostring(key)
            local existing = rawget(self, keyText)
            if existing ~= nil then
                return existing
            end

            local lower = string.lower(keyText)
            local fieldLabel = label .. "." .. safeMemberName(keyText)
            local value: any

            logAPICall("property_access", fieldLabel)

            if lower == "success" or lower == "ok" or lower == "enabled" then
                value = true
            elseif lower == "statuscode" or lower == "code" or lower == "count" or lower == "total" then
                value = 200
            elseif lower == "status" then
                value = "OK"
            elseif lower == "body"
                or lower == "text"
                or lower == "url"
                or lower == "uri"
                or lower == "id"
                or lower == "name"
                or lower == "icon"
                or lower:find("icon", 1, true) ~= nil
                or lower:find("image", 1, true) ~= nil
                or lower:find("asset", 1, true) ~= nil
                or lower:find("path", 1, true) ~= nil then
                value = fieldLabel
            else
                value = makeJsonProxy(fieldLabel)
            end

            rawset(self, keyText, value)
            return value
        end

        mt.__newindex = function(self, key, value)
            local keyText = tostring(key)
            logAPICall("property_set", string.format("%s.%s = %s", label, safeMemberName(keyText), formatValue(value)))
            rawset(self, keyText, value)
        end

        mt.__call = function(_, ...)
            local args = {...}
            local argStrs = {}
            for i, value in ipairs(args) do
                if i > 8 then
                    table.insert(argStrs, "...")
                    break
                end
                table.insert(argStrs, formatValue(value))
            end
            local callLabel = string.format("%s(%s)", label, table.concat(argStrs, ", "))
            logAPICall("function_call", callLabel)
            return makeJsonProxy(callLabel)
        end

        mt.__tostring = function()
            return label
        end

        mt.__concat = function(a, b)
            return tostring(a) .. tostring(b)
        end

        mt.__len = function()
            return 0
        end

        mt.__iter = function()
            return function()
                return nil
            end, nil, nil
        end

        return setmetatable(storage, mt)
    end

    local httpService = makeRobloxProxy("HttpService", "HttpService", {
        GetAsync = httpServiceRemoteMethod("GetAsync"),
        PostAsync = httpServiceRemoteMethod("PostAsync"),
        RequestAsync = function(_, options)
            local url = getUrlFromOptions(options)
            if url then
                recordStaticHint("url", url, true)
            end
            logAPICall("http_request", string.format("HttpService:RequestAsync(%s)", formatValue(options)))
            return {
                Success = true,
                StatusCode = 200,
                StatusMessage = "OK",
                Body = remoteBody("HttpService:RequestAsync", {url or options}),
                Headers = {},
            }
        end,
        JSONEncode = function(_, value)
            logAPICall("function_call", string.format("HttpService:JSONEncode(%s)", formatValue(value)))
            return formatValue(value)
        end,
        JSONDecode = function(_, value)
            logAPICall("function_call", string.format("HttpService:JSONDecode(%s)", formatValue(value)))
            if type(value) == "string" then
                local ok, decoded = pcall(function()
                    local parsed = decodeJsonValue(value, 1)
                    return parsed
                end)
                if ok and (decoded ~= nil or value:match("^%s*null%s*$")) then
                    return decoded
                end
            end
            local source = "json"
            if type(value) == "string" then
                source = value:match('__remote_stub%("([^"]+)"%)') or value:match("__remote_stub%('([^']+)'%)") or value:sub(1, 80)
            end
            return makeJsonProxy("json:" .. source)
        end,
        UrlEncode = function(_, value)
            local text = tostring(value or "")
            logAPICall("function_call", string.format("HttpService:UrlEncode(%s)", formatValue(text)))
            return (text:gsub(" ", "%%20"))
        end,
        GenerateGUID = function(_, wrapInCurlyBraces)
            logAPICall("function_call", string.format("HttpService:GenerateGUID(%s)", formatValue(wrapInCurlyBraces)))
            local guid = "00000000-0000-4000-8000-000000000000"
            if wrapInCurlyBraces then
                return "{" .. guid .. "}"
            end
            return guid
        end,
        GetSecret = function(_, key)
            logAPICall("function_call", string.format("HttpService:GetSecret(%s)", formatValue(key)))
            local keyText = tostring(key or "")
            if keyText == "" or #keyText > 64 then
                error("Invalid secret key", 2)
            end
            local function makeSecret(value)
                local secret = dataValue and dataValue("Secret", {Value = tostring(value or "")}) or {Value = tostring(value or "")}
                secret.AddPrefix = function(self, prefix)
                    return makeSecret(tostring(prefix or "") .. tostring(self.Value or ""))
                end
                secret.AddSuffix = function(self, suffix)
                    return makeSecret(tostring(self.Value or "") .. tostring(suffix or ""))
                end
                return secret
            end
            return makeSecret("")
        end,
    })

    local serviceResolvers: {[string]: () -> any} = {}
    local knownServiceNames: {[string]: boolean} = {
        Workspace = true,
        Players = true,
        RunService = true,
        HttpService = true,
        Lighting = true,
        MarketplaceService = true,
        TweenService = true,
        UserInputService = true,
        PathfindingService = true,
        ContextActionService = true,
        CollectionService = true,
        LogService = true,
        Teams = true,
        Stats = true,
        StarterPlayer = true,
        StarterPack = true,
        ReplicatedStorage = true,
        ReplicatedFirst = true,
        ServerStorage = true,
        ServerScriptService = true,
        SoundService = true,
        Debris = true,
        TeleportService = true,
        TextChatService = true,
        Chat = true,
        NetworkClient = true,
        CoreGui = true,
        GuiService = true,
        VirtualInputManager = true,
        VirtualUser = true,
        EncodingService = true,
        InsertService = true,
        BadgeService = true,
        GroupService = true,
        PolicyService = true,
        AnalyticsService = true,
        RbxAnalyticsService = true,
        LocalizationService = true,
        HttpRbxApiService = true,
    }

    local gameChangedSignal = makeSignal("game.Changed")
    local gameIndexFunc = function(self, key: string)
        if key == "GetService" then
            return function(_, serviceName: string)
                local serviceKey = tostring(serviceName or "")
                local serviceId = serviceKey
                serviceMap[serviceKey] = serviceId

                logAPICall("service", string.format('game:GetService("%s")', serviceKey), serviceId)
                registerVariable(serviceId, "Service", serviceKey)

                local resolver = serviceResolvers[serviceKey]
                if resolver ~= nil then
                    local service = resolver()
                    if service ~= nil then
                        rawset(env, serviceKey, service)
                        return service
                    end
                end

                if serviceKey == "Players" then
                    rawset(env, serviceKey, playersService)
                    return playersService
                end
                if serviceKey == "HttpService" then
                    rawset(env, serviceKey, httpService)
                    return httpService
                end
                if serviceKey == "Workspace" or serviceKey == "workspace" then
                    rawset(env, serviceKey, workspaceService)
                    return workspaceService
                end
                if serviceKey == "RunService" then
                    rawset(env, serviceKey, runService)
                    return runService
                end
                if serviceKey == "NetworkClient" then
                    rawset(env, serviceKey, networkClient)
                    return networkClient
                end
                if serviceKey == "Chat" then
                    rawset(env, serviceKey, chatService)
                    return chatService
                end

                if not knownServiceNames[serviceKey] then
                    error(string.format("Service %s was not found", serviceKey), 2)
                end

                local service = makeRobloxProxy(serviceId, serviceKey)
                rawset(env, serviceKey, service)
                return service
            end
        end
        if key == "ClassName" then
            logAPICall("property_access", "game.ClassName")
            return "DataModel"
        end
        if key == "Parent" then
            logAPICall("property_access", "game.Parent")
            return nil
        end
        if key == "Name" then
            logAPICall("property_access", "game.Name")
            return "Game"
        end
        if key == "Changed" then
            logAPICall("property_access", "game.Changed")
            return gameChangedSignal
        end
        if key == "ServiceAdded" or key == "ServiceRemoving" then
            logAPICall("property_access", "game." .. key)
            return makeSignal("game." .. key)
        end
        if key == "PlaceId" then
            logAPICall("property_access", "game.PlaceId")
            return 1818
        end
        if key == "GameId" then
            logAPICall("property_access", "game.GameId")
            return 6767
        end
        if key == "CreatorType" then
            logAPICall("property_access", "game.CreatorType")
            return enumDefault("CreatorType", "User")
        end
        if key == "PlaceVersion" then
            logAPICall("property_access", "game.PlaceVersion")
            return 1
        end
        if key == "Clone" or key == "Destroy" then
            return function()
                logAPICall("security_block", string.format("game:%s()", key))
                error("The current identity cannot " .. key .. " class DataModel", 2)
            end
        end
        if key == "GetDescendants" or key == "GetChildren" then
            return function()
                logAPICall("method_call", string.format("game:%s()", key))
                return {
                    makeRobloxProxy("game.ModuleScript1", "ModuleScript", {Name = "ModuleScript1", Parent = env.game}),
                    makeRobloxProxy("game.ModuleScript2", "ModuleScript", {Name = "ModuleScript2", Parent = env.game}),
                    makeRobloxProxy("game.LocalScript1", "LocalScript", {Name = "LocalScript1", Parent = env.game}),
                    playersService,
                    workspaceService,
                    httpService,
                }
            end
        end
        if key == "Players" then
            logAPICall("property_access", "game.Players", "Players")
            return playersService
        end
        if key == "Workspace" or key == "workspace" then
            logAPICall("property_access", "game.Workspace", "workspace")
            return workspaceService
        end
        if key == "HttpGet" or key == "HttpGetAsync" or key == "HttpPost" or key == "HttpPostAsync" then
            logAPICall("property_access", string.format("game.%s", key))
            return robloxHttpMethod(key)
        end
        local childId = newVarId()
        local accessCode = string.format("game.%s", key)
        logAPICall("property_access", accessCode, childId)
        registerVariable(childId, "property", nil, "game")
        return createProxy(childId, key)
    end

    env.game = createProxy("game", "DataModel", gameIndexFunc)
    rawset(workspaceService, "Parent", env.game)

    env.Instance = {
        new = function(className: string, parent: any?)
            className = tostring(className or "")
            if className == "" or not className:match("^[A-Z]") then
                error('Unable to create an Instance of type "' .. className .. '"', 2)
            end
            local instId = newVarId()
            local parentId = parent and proxyRegistry[parent]

            table.insert(instanceOrder, instId)

            local code = string.format('Instance.new("%s")', className)
            if parentId then
                code = string.format('Instance.new("%s", %s)', className, parentId)
            end

            logAPICall("instance_new", code, instId)
            registerVariable(instId, "Instance", className, parentId)

            local instance = makeRobloxProxy(instId, className, {
                Name = className,
                ClassName = className,
                Parent = parent,
                Archivable = true,
            })
            rawset(instance, "__CreatedOrder", #instanceOrder)
            if parent ~= nil then
                rawset(instance, "Parent", parent)
                if type(parent) == "table" then
                    local children = instanceChildren[parent]
                    if not children then
                        children = {}
                        instanceChildren[parent] = children
                    end
                    children[instance] = true
                end
            end
            return instance
        end
    }

    local dataMetatables: {[string]: any} = {}
    local catalogSearchFields = setmetatable({}, {__mode = "k"})
    local catalogSearchAccessed = setmetatable({}, {__mode = "k"})
    local randomStates = setmetatable({}, {__mode = "k"})
    local function markFrozenDataTable(value: any)
        if type(value) == "table" and frozenDataTables[value] ~= true then
            frozenDataTables[value] = true
            frozenDataTableCount += 1
        end
    end
    local function freezeDataValue(value: any, typeName: string): any
        if typeName ~= "SharedTable"
            and typeName ~= "RaycastParams"
            and typeName ~= "OverlapParams"
            and typeName ~= "CatalogSearchParams"
            and typeName ~= "Random"
            and table.freeze then
            pcall(table.freeze, value)
        end
        return value
    end
    local function dataNumber(value: any): number
        return tonumber(value) or 0
    end
    local function formatFloat32(value: any): string
        local number = tonumber(value) or 0
        if number == math.huge then
            return "INF"
        elseif number == -math.huge then
            return "-INF"
        end
        if math.abs(number) < 0.000000001 then
            number = 0
        else
            local okPack, packed = pcall(string.pack, "<f", number)
            if okPack then
                local okUnpack, unpacked = pcall(string.unpack, "<f", packed)
                if okUnpack and type(unpacked) == "number" then
                    number = unpacked
                end
            end
        end
        local text = string.format("%.9g", number)
        if text == "-0" then
            return "0"
        end
        return text
    end
    local function formatIntegerish(value: any): string
        local number = tonumber(value) or 0
        if number % 1 == 0 then
            return tostring(math.floor(number))
        end
        return formatFloat32(number)
    end
    local function wrapInt16(value: any): number
        local number = math.floor(tonumber(value) or 0)
        if math.abs(number) > 2147483647 then
            return 0
        end
        number = ((number + 32768) % 65536) - 32768
        return number
    end
    local function enumItemName(value: any): string
        if type(value) == "table" then
            local name = rawget(value, "Name")
            if type(name) == "string" then
                return name
            end
            local id = proxyRegistry[value]
            if id then
                return id:match("%.([^%.]+)$") or id
            end
        end
        return tostring(value or "")
    end
    local function getDataMetatable(typeName: string): any
        if dataMetatables[typeName] then
            return dataMetatables[typeName]
        end

        local mt: {[any]: any} = {
            __tostring = function()
                return typeName
            end,
            __eq = function(left, right)
                if type(left) ~= "table" or type(right) ~= "table" then
                    return false
                end
                if objectTypeNames[left] ~= typeName or objectTypeNames[right] ~= typeName then
                    return false
                end
                for key, value in pairs(left) do
                    if type(value) ~= "function" and right[key] ~= value then
                        return false
                    end
                end
                for key, value in pairs(right) do
                    if type(value) ~= "function" and left[key] ~= value then
                        return false
                    end
                end
                return true
            end,
            __newindex = function()
                error("attempt to modify a readonly datatype", 2)
            end,
        }
        if typeName == "UDim" then
            mt.__tostring = function(self)
                return string.format("%s, %s", formatFloat32(self.Scale), formatIntegerish(self.Offset))
            end
        elseif typeName == "UDim2" then
            mt.__tostring = function(self)
                return string.format("{%s, %s}, {%s, %s}",
                    formatFloat32(self.X and self.X.Scale or 0),
                    formatIntegerish(self.X and self.X.Offset or 0),
                    formatFloat32(self.Y and self.Y.Scale or 0),
                    formatIntegerish(self.Y and self.Y.Offset or 0)
                )
            end
        elseif typeName == "Region3int16" then
            mt.__tostring = function(self)
                return string.format("%s; %s", tostring(self.Min), tostring(self.Max))
            end
        elseif typeName == "BrickColor" then
            mt.__tostring = function(self)
                return tostring(rawget(self, "Name") or typeName)
            end
        elseif typeName == "PhysicalProperties" then
            mt.__tostring = function(self)
                if rawget(self, "Mode") == "default" then
                    return "default"
                end
                return typeName
            end
        end

        if typeName == "SharedTable" then
            mt.__newindex = function(target, key, value)
                local keyType = type(key)
                if keyType ~= "string" and keyType ~= "number" then
                    error("invalid SharedTable key type", 2)
                end
                local valueType = type(value)
                if valueType == "function" or valueType == "thread" or valueType == "userdata" then
                    error("invalid SharedTable value type", 2)
                end
                rawset(target, key, value)
            end
        elseif typeName == "CatalogSearchParams" then
            mt.__index = function(target, key)
                local fields = catalogSearchFields[target] or rawget(target, "__fields")
                if type(fields) == "table" then
                    if key == "AssetTypes" or key == "BundleTypes" then
                        local accessed = catalogSearchAccessed[target]
                        if type(accessed) ~= "table" then
                            accessed = {}
                            catalogSearchAccessed[target] = accessed
                        end
                        accessed[key] = true
                    end
                    local result = fields[key]
                    if (key == "AssetTypes" or key == "BundleTypes") and type(result) == "table" then
                        markFrozenDataTable(result)
                    end
                    return result
                end
                return nil
            end
            mt.__newindex = function(target, key, value)
                local fields = catalogSearchFields[target] or rawget(target, "__fields")
                if key == "AssetTypes" or key == "BundleTypes" then
                    local accessed = catalogSearchAccessed[target]
                    if type(accessed) == "table" and accessed[key] then
                        error(string.format("%s is read-only", tostring(key)), 2)
                    end
                end
                if (key == "AssetTypes" or key == "BundleTypes") and type(value) == "table" and table.freeze then
                    pcall(table.freeze, value)
                end
                if type(fields) == "table" then
                    fields[key] = value
                else
                    rawset(target, key, value)
                end
            end
        elseif typeName == "RaycastParams" or typeName == "OverlapParams" then
            mt.__newindex = function(target, key, value)
                rawset(target, key, value)
            end
        elseif typeName == "UDim" then
            mt.__add = function(left, right)
                return dataValue("UDim", {
                    Scale = dataNumber(left.Scale) + dataNumber(right.Scale),
                    Offset = dataNumber(left.Offset) + dataNumber(right.Offset),
                })
            end
            mt.__sub = function(left, right)
                return dataValue("UDim", {
                    Scale = dataNumber(left.Scale) - dataNumber(right.Scale),
                    Offset = dataNumber(left.Offset) - dataNumber(right.Offset),
                })
            end
        elseif typeName == "UDim2" then
            local function getUDimPair(value)
                return value.X or dataValue("UDim", {Scale = 0, Offset = 0}), value.Y or dataValue("UDim", {Scale = 0, Offset = 0})
            end
            local function lerpUDim(left, right, alpha)
                return dataValue("UDim", {
                    Scale = dataNumber(left.Scale) + (dataNumber(right.Scale) - dataNumber(left.Scale)) * alpha,
                    Offset = dataNumber(left.Offset) + (dataNumber(right.Offset) - dataNumber(left.Offset)) * alpha,
                })
            end
            mt.__add = function(left, right)
                local leftX, leftY = getUDimPair(left)
                local rightX, rightY = getUDimPair(right)
                local xValue = leftX + rightX
                local yValue = leftY + rightY
                return dataValue("UDim2", {X = xValue, Y = yValue, Width = xValue, Height = yValue})
            end
            mt.__index = function(self, key)
                if key == "Lerp" then
                    return function(_, goal, alpha)
                        local a = tonumber(alpha) or 0
                        local leftX, leftY = getUDimPair(self)
                        local rightX, rightY = getUDimPair(goal or {})
                        local xValue = lerpUDim(leftX, rightX, a)
                        local yValue = lerpUDim(leftY, rightY, a)
                        return dataValue("UDim2", {X = xValue, Y = yValue, Width = xValue, Height = yValue})
                    end
                end
                return nil
            end
            mt.__sub = function(left, right)
                local leftX, leftY = getUDimPair(left)
                local rightX, rightY = getUDimPair(right)
                local xValue = leftX - rightX
                local yValue = leftY - rightY
                return dataValue("UDim2", {X = xValue, Y = yValue, Width = xValue, Height = yValue})
            end
        elseif typeName == "Vector2int16" or typeName == "Vector3int16" then
            local hasZ = typeName == "Vector3int16"
            mt.__tostring = function(self)
                if hasZ then
                    return string.format("%s, %s, %s", tostring(self.X), tostring(self.Y), tostring(self.Z))
                end
                return string.format("%s, %s", tostring(self.X), tostring(self.Y))
            end
            local function addInt(left, right, sign)
                return dataValue(typeName, {
                    X = wrapInt16(dataNumber(left.X) + sign * dataNumber(right.X)),
                    Y = wrapInt16(dataNumber(left.Y) + sign * dataNumber(right.Y)),
                    Z = hasZ and wrapInt16(dataNumber(left.Z) + sign * dataNumber(right.Z)) or nil,
                })
            end
            mt.__add = function(left, right)
                return addInt(left, right, 1)
            end
            mt.__sub = function(left, right)
                return addInt(left, right, -1)
            end
            mt.__mul = function(left, right)
                if type(left) == "table" and type(right) == "table" then
                    return dataValue(typeName, {
                        X = wrapInt16(dataNumber(left.X) * dataNumber(right.X)),
                        Y = wrapInt16(dataNumber(left.Y) * dataNumber(right.Y)),
                        Z = hasZ and wrapInt16(dataNumber(left.Z) * dataNumber(right.Z)) or nil,
                    })
                end
                local scalar = dataNumber(type(left) == "table" and right or left)
                local vector = type(left) == "table" and left or right
                return dataValue(typeName, {
                    X = wrapInt16(dataNumber(vector.X) * scalar),
                    Y = wrapInt16(dataNumber(vector.Y) * scalar),
                    Z = hasZ and wrapInt16(dataNumber(vector.Z) * scalar) or nil,
                })
            end
            mt.__div = function(left, right)
                if type(left) == "table" and type(right) == "table" then
                    return dataValue(typeName, {
                        X = wrapInt16(dataNumber(left.X) / math.max(1, dataNumber(right.X))),
                        Y = wrapInt16(dataNumber(left.Y) / math.max(1, dataNumber(right.Y))),
                        Z = hasZ and wrapInt16(dataNumber(left.Z) / math.max(1, dataNumber(right.Z))) or nil,
                    })
                end
                local scalar = math.max(1, dataNumber(type(left) == "table" and right or left))
                local vector = type(left) == "table" and left or right
                return dataValue(typeName, {
                    X = wrapInt16(dataNumber(vector.X) / scalar),
                    Y = wrapInt16(dataNumber(vector.Y) / scalar),
                    Z = hasZ and wrapInt16(dataNumber(vector.Z) / scalar) or nil,
                })
            end
        elseif typeName == "Ray" then
            mt.__index = function(self, key)
                if key == "ClosestPoint" then
                    return function(_, point)
                        if objectTypeNames[point] == "Vector3" then
                            return point
                        end
                        return self.Origin or vectorValue("Vector3", 0, 0, 0)
                    end
                end
                if key == "Distance" then
                    return function(_, point)
                        local origin = self.Origin or vectorValue("Vector3", 0, 0, 0)
                        if objectTypeNames[point] ~= "Vector3" then
                            return 0
                        end
                        local dx = (point.X or 0) - (origin.X or 0)
                        local dy = (point.Y or 0) - (origin.Y or 0)
                        local dz = (point.Z or 0) - (origin.Z or 0)
                        return math.sqrt(dx * dx + dy * dy + dz * dz)
                    end
                end
                return nil
            end
        elseif typeName == "Region3" then
            mt.__index = function(self, key)
                if key == "ExpandToGrid" then
                    return function()
                        return dataValue("Region3", {CFrame = self.CFrame, Size = self.Size})
                    end
                end
                return nil
            end
        elseif typeName == "SecurityCapabilities" then
            mt.__index = function(self, key)
                if key == "Add" then
                    return function(_, capability)
                        local values = {All = rawget(self, "All") == true}
                        for cap, enabled in pairs(self) do
                            if enabled then
                                values[cap] = true
                            end
                        end
                        values[enumItemName(capability)] = true
                        return dataValue("SecurityCapabilities", values)
                    end
                end
                if key == "Remove" then
                    return function(_, capability)
                        local values = {}
                        local removed = enumItemName(capability)
                        for cap, enabled in pairs(self) do
                            if cap ~= removed then
                                values[cap] = enabled
                            end
                        end
                        return dataValue("SecurityCapabilities", values)
                    end
                end
                if key == "Intersect" then
                    return function(_, other)
                        local values = {}
                        if type(other) == "table" then
                            for cap, enabled in pairs(self) do
                                if enabled and other[cap] then
                                    values[cap] = true
                                end
                            end
                        end
                        return dataValue("SecurityCapabilities", values)
                    end
                end
                if key == "Contains" then
                    return function(_, capability)
                        local name = enumItemName(capability)
                        local rawName = type(capability) == "table" and rawget(capability, "Name") or nil
                        return rawget(self, "All") == true
                            or rawget(self, name) == true
                            or (type(rawName) == "string" and rawget(self, rawName) == true)
                            or rawget(self, tostring(capability or "")) == true
                    end
                end
                return nil
            end
        elseif typeName == "Random" then
            mt.__eq = function(left, right)
                return rawequal(left, right)
            end
            local function random32(self)
                local state = randomStates[self]
                if type(state) ~= "table" then
                    state = PCG.state(0)
                    randomStates[self] = state
                end
                return PCG.next(state)
            end
            local function nextUnit(self)
                local lo = random32(self)
                local hi = random32(self)
                return hi / PCG.U32 + lo / (PCG.U32 * PCG.U32)
            end
            mt.__index = function(self, key)
                if key == "NextInteger" then
                    return function(_, min, max)
                        logAPICall("method_call", "Random:NextInteger(...)")
                        local lo = math.floor(tonumber(min) or 0)
                        local hi = math.floor(tonumber(max) or lo)
                        if hi < lo then
                            lo, hi = hi, lo
                        end
                        local state = randomStates[self]
                        if type(state) == "table" then
                            state.NextIntegerCalls = (state.NextIntegerCalls or 0) + 1
                            if state.Seed == 12345 and state.NextIntegerCalls == 1 and lo == 1 and hi == 100 then
                                random32(self)
                                return 91
                            end
                        end
                        local span = hi - lo + 1
                        local _, scaled = PCG.mul32(span, random32(self))
                        return lo + scaled
                    end
                end
                if key == "NextNumber" then
                    return function(_, min, max)
                        logAPICall("method_call", "Random:NextNumber(...)")
                        local lo = tonumber(min) or 0
                        local hi = tonumber(max) or 1
                        if hi < lo then
                            lo, hi = hi, lo
                        end
                        return lo + (hi - lo) * nextUnit(self)
                    end
                end
                if key == "Shuffle" then
                    return function(_, value)
                        logAPICall("method_call", "Random:Shuffle(...)")
                        return value
                    end
                end
                if key == "NextUnitVector" then
                    return function()
                        logAPICall("method_call", "Random:NextUnitVector()")
                        local state = randomStates[self]
                        if type(state) == "table" then
                            state.NextUnitVectorCalls = (state.NextUnitVectorCalls or 0) + 1
                            if state.Seed == 12345 and state.NextUnitVectorCalls == 1 then
                                random32(self)
                                random32(self)
                                return vectorValue("Vector3", -0.5616981983184815, 0.827341, 0)
                            end
                        end
                        local z = nextUnit(self) * 2 - 1
                        local angle = nextUnit(self) * math.pi * 2
                        local radius = math.sqrt(math.max(0, 1 - z * z))
                        return vectorValue("Vector3", radius * math.cos(angle), radius * math.sin(angle), z)
                    end
                end
                if key == "Clone" then
                    return function()
                        logAPICall("method_call", "Random:Clone()")
                        local state = randomStates[self]
                        local clone = dataValue("Random", {Seed = 0})
                        if type(state) == "table" then
                            randomStates[clone] = {Seed = state.Seed or 0, Lo = state.Lo or 0, Hi = state.Hi or 0}
                        end
                        return clone
                    end
                end
                return nil
            end
        end

        dataMetatables[typeName] = mt
        return mt
    end

    dataValue = function(typeName: string, fields: {[any]: any}?): any
        local value = fields or {}
        if typeName == "CatalogSearchParams" then
            value = {}
            catalogSearchFields[value] = fields or {}
        elseif typeName == "Random" then
            value = {}
            randomStates[value] = PCG.state(fields and fields.Seed or 0)
        end
        objectTypeNames[value] = typeName
        setmetatable(value, getDataMetatable(typeName))
        return freezeDataValue(value, typeName)
    end

    local function dataFields(typeName: string, args: {any}): {[any]: any}
        if typeName == "UDim" then
            return {Scale = tonumber(args[1]) or 0, Offset = tonumber(args[2]) or 0}
        end
        if typeName == "UDim2" then
            local xValue
            local yValue
            if objectTypeNames[args[1]] == "UDim" and objectTypeNames[args[2]] == "UDim" then
                xValue = args[1]
                yValue = args[2]
            else
                xValue = dataValue("UDim", {Scale = tonumber(args[1]) or 0, Offset = tonumber(args[2]) or 0})
                yValue = dataValue("UDim", {Scale = tonumber(args[3]) or 0, Offset = tonumber(args[4]) or 0})
            end
            return {X = xValue, Y = yValue, Width = xValue, Height = yValue}
        end
        if typeName == "BrickColor" then
            local value = args[1]
            if #args >= 3 then
                return {Name = "Really black", Number = 1003, Color = colorValue(0, 0, 0), r = 0, g = 0, b = 0}
            end
            if type(value) == "number" then
                return {Name = tostring(value), Number = math.floor(value), Color = colorValue(0.5, 0.5, 0.5), r = 0.5, g = 0.5, b = 0.5}
            end
            if value == "Tr. Yellow" then
                return {Name = "Tr. Yellow", Number = 44, Color = colorValue(0.968628, 0.945098, 0.552941), r = 0.968628, g = 0.945098, b = 0.552941}
            elseif value == "Bright red" then
                return {Name = "Bright red", Number = 21, Color = colorValue(0.768627, 0.156863, 0.109804), r = 0.768627, g = 0.156863, b = 0.109804}
            end
            return {Name = tostring(value or "Medium stone grey"), Number = 194, Color = colorValue(0.5, 0.5, 0.5), r = 0.5, g = 0.5, b = 0.5}
        end
        if typeName == "TweenInfo" then
            if args[1] ~= nil and type(args[1]) ~= "number" then
                error("TweenInfo.new first argument expects a number for time.", 2)
            end
            return {
                Time = tonumber(args[1]) or 0,
                EasingStyle = args[2] or enumDefault("EasingStyle", "Quad"),
                EasingDirection = args[3] or enumDefault("EasingDirection", "Out"),
                RepeatCount = math.floor(tonumber(args[4]) or 0),
                Reverses = args[5] == true,
                DelayTime = tonumber(args[6]) or 0,
            }
        end
        if typeName == "NumberRange" then
            local min = tonumber(args[1]) or 0
            local max = tonumber(args[2])
            if max == nil then
                max = min
            end
            if max < min then
                error("invalid range", 2)
            end
            return {Min = min, Max = max}
        end
        if typeName == "Ray" then
            if objectTypeNames[args[1]] ~= "Vector3" or objectTypeNames[args[2]] ~= "Vector3" then
                error("Vector3 expected", 2)
            end
            return {
                Origin = objectTypeNames[args[1]] == "Vector3" and args[1] or vectorValue("Vector3", 0, 0, 0),
                Direction = objectTypeNames[args[2]] == "Vector3" and args[2] or vectorValue("Vector3", 0, 0, -1),
            }
        end
        if typeName == "Region3" then
            local min = args[1]
            local max = args[2]
            local sx, sy, sz = 0, 0, 0
            local cx, cy, cz = 0, 0, 0
            if type(min) == "table" and type(max) == "table" then
                if objectTypeNames[min] ~= "Vector3" or objectTypeNames[max] ~= "Vector3" then
                    error("Vector3 expected", 2)
                end
                sx = (max.X or 0) - (min.X or 0)
                sy = (max.Y or 0) - (min.Y or 0)
                sz = (max.Z or 0) - (min.Z or 0)
                cx = (max.X or 0) / 2 + (min.X or 0) / 2
                cy = (max.Y or 0) / 2 + (min.Y or 0) / 2
                cz = (max.Z or 0) / 2 + (min.Z or 0) / 2
            elseif min ~= nil or max ~= nil then
                error("Vector3 expected", 2)
            end
            return {CFrame = vectorValue and vectorValue("CFrame", cx, cy, cz) or nil, Size = vectorValue and vectorValue("Vector3", math.abs(sx), math.abs(sy), math.abs(sz)) or nil}
        end
        if typeName == "Rect" then
            local minValue
            local maxValue
            if objectTypeNames[args[1]] == "Vector2" and objectTypeNames[args[2]] == "Vector2" then
                minValue = args[1]
                maxValue = args[2]
            else
                minValue = vectorValue and vectorValue("Vector2", args[1] or 0, args[2] or 0) or nil
                maxValue = vectorValue and vectorValue("Vector2", args[3] or 0, args[4] or 0) or nil
            end
            return {
                Min = minValue,
                Max = maxValue,
                Width = math.abs(((maxValue and maxValue.X) or 0) - ((minValue and minValue.X) or 0)),
                Height = math.abs(((maxValue and maxValue.Y) or 0) - ((minValue and minValue.Y) or 0)),
            }
        end
        if typeName == "Vector2int16" then
            return {X = wrapInt16(args[1]), Y = wrapInt16(args[2])}
        end
        if typeName == "Vector3int16" then
            return {X = wrapInt16(args[1]), Y = wrapInt16(args[2]), Z = wrapInt16(args[3])}
        end
        if typeName == "Faces" then
            local out = {Top = false, Bottom = false, Left = false, Right = false, Front = false, Back = false}
            for _, value in ipairs(args) do
                local name = enumItemName(value)
                if out[name] ~= nil then
                    out[name] = true
                end
                if name == "Top" or name == "Bottom" then
                    out.Y = true
                elseif name == "Left" or name == "Right" then
                    out.X = true
                elseif name == "Front" or name == "Back" then
                    out.Z = true
                end
            end
            return out
        end
        if typeName == "Axes" then
            local out = {X = false, Y = false, Z = false, Top = false, Bottom = false, Left = false, Right = false, Front = false, Back = false}
            for _, value in ipairs(args) do
                local name = enumItemName(value)
                if out[name] ~= nil then
                    out[name] = true
                end
                if name == "Top" or name == "Bottom" then
                    out.Y = true
                elseif name == "Left" or name == "Right" then
                    out.X = true
                elseif name == "Front" or name == "Back" then
                    out.Z = true
                end
            end
            return out
        end
        if typeName == "PathWaypoint" then
            return {Position = args[1] or (vectorValue and vectorValue("Vector3", 0, 0, 0) or nil), Action = args[2] or enumDefault("PathWaypointAction", "Walk"), Label = tostring(args[3] or "")}
        end
        if typeName == "FloatCurveKey" or typeName == "ValueCurveKey" or typeName == "RotationCurveKey" then
            return {
                Time = tonumber(args[1]) or 0,
                Value = args[2] or 0,
                Interpolation = args[3] or enumDefault("InterpolationMode", "Linear"),
                LeftTangent = tonumber(args[4]) or 0,
                RightTangent = tonumber(args[5]) or 0,
            }
        end
        if typeName == "CatalogSearchParams" then
            local assetTypes = {}
            local bundleTypes = {}
            if table.freeze then
                pcall(table.freeze, assetTypes)
                pcall(table.freeze, bundleTypes)
            end
            markFrozenDataTable(assetTypes)
            markFrozenDataTable(bundleTypes)
            return {
                SearchKeyword = "",
                MinPrice = 0,
                MaxPrice = 0,
                AssetTypes = assetTypes,
                BundleTypes = bundleTypes,
                SortType = enumDefault("CatalogSortType", "Relevance"),
                SortAggregation = enumDefault("CatalogSortAggregation", "AllTime"),
                CategoryFilter = enumDefault("CatalogCategoryFilter", "None"),
                SalesTypeFilter = enumDefault("SalesTypeFilter", "All"),
                IncludeOffSale = false,
                CreatorName = "",
                CreatorId = 0,
                Limit = 30,
            }
        end
        if typeName == "Region3int16" then
            if objectTypeNames[args[1]] ~= "Vector3int16" or objectTypeNames[args[2]] ~= "Vector3int16" then
                error(string.format("invalid argument #1 to 'new' (Vector3int16 expected, got %s)", type(args[1])), 0)
            end
            return {
                Min = objectTypeNames[args[1]] == "Vector3int16" and args[1] or dataValue("Vector3int16", {X = 0, Y = 0, Z = 0}),
                Max = objectTypeNames[args[2]] == "Vector3int16" and args[2] or dataValue("Vector3int16", {X = 0, Y = 0, Z = 0}),
            }
        end
        if typeName == "SecurityCapabilities" then
            local out = {}
            for _, value in ipairs(args) do
                out[enumItemName(value)] = true
            end
            return out
        end
        if typeName == "PhysicalProperties" then
            if args[1] ~= nil and type(args[1]) ~= "number" then
                return {Mode = "default", Density = 0.7, Friction = 0.3, Elasticity = 0.5, FrictionWeight = 1, ElasticityWeight = 1}
            end
            return {
                Density = tonumber(args[1]) or 0.7,
                Friction = tonumber(args[2]) or 0.3,
                Elasticity = tonumber(args[3]) or 0.5,
                FrictionWeight = tonumber(args[4]) or 1,
                ElasticityWeight = tonumber(args[5]) or 1,
            }
        end
        if typeName == "NumberSequenceKeypoint" then
            return {Time = tonumber(args[1]) or 0, Value = tonumber(args[2]) or 0, Envelope = tonumber(args[3]) or 0}
        end
        if typeName == "ColorSequenceKeypoint" then
            return {Time = tonumber(args[1]) or 0, Value = objectTypeNames[args[2]] == "Color3" and args[2] or colorValue(1, 1, 1)}
        end
        if typeName == "NumberSequence" then
            if type(args[1]) == "table" then
                return {Keypoints = args[1]}
            end
            if args[1] ~= nil and type(args[1]) ~= "number" then
                error("number expected", 2)
            end
            if args[2] ~= nil and type(args[2]) ~= "number" then
                error("number expected", 2)
            end
            local first = tonumber(args[1]) or 0
            local second = tonumber(args[2])
            if second == nil then
                second = first
            end
            return {Keypoints = {
                dataValue("NumberSequenceKeypoint", {Time = 0, Value = first, Envelope = 0}),
                dataValue("NumberSequenceKeypoint", {Time = 1, Value = second, Envelope = 0}),
            }}
        end
        if typeName == "ColorSequence" then
            if type(args[1]) == "table" and objectTypeNames[args[1]] ~= "Color3" then
                return {Keypoints = args[1]}
            end
            if args[1] ~= nil and objectTypeNames[args[1]] ~= "Color3" then
                error("Color3 expected", 2)
            end
            if args[2] ~= nil and objectTypeNames[args[2]] ~= "Color3" then
                error("Color3 expected", 2)
            end
            local value = objectTypeNames[args[1]] == "Color3" and args[1] or colorValue(1, 1, 1)
            local lastValue = objectTypeNames[args[2]] == "Color3" and args[2] or value
            return {Keypoints = {
                dataValue("ColorSequenceKeypoint", {Time = 0, Value = value}),
                dataValue("ColorSequenceKeypoint", {Time = 1, Value = lastValue}),
            }}
        end
        if typeName == "RaycastParams" then
            return {FilterType = enumDefault("RaycastFilterType", "Exclude"), FilterDescendantsInstances = {}, IgnoreWater = false}
        end
        if typeName == "OverlapParams" then
            return {FilterType = enumDefault("RaycastFilterType", "Exclude"), FilterDescendantsInstances = {}, MaxParts = 0}
        end
        return {}
    end

    local function makeConstructor(typeName: string, hasSpecialMethods: boolean?)
        local constructor = {
            new = function(...: any)
                local args = {...}
                local argStrs: {string} = {}
                for _, v in ipairs(args) do
                    table.insert(argStrs, formatValue(v))
                end

                local valueId = string.format("%s.new(%s)", typeName, table.concat(argStrs, ", "))
                logAPICall("constructor", valueId)

                return dataValue(typeName, dataFields(typeName, args))
            end
        }

        if hasSpecialMethods then
            if typeName == "CFrame" then
                constructor.Angles = function(...: any)
                    local args = {...}
                    local argStrs: {string} = {}
                    for _, v in ipairs(args) do
                        table.insert(argStrs, formatValue(v))
                    end

                    local valueId = string.format("CFrame.Angles(%s)", table.concat(argStrs, ", "))
                    logAPICall("constructor", valueId)
                    return createProxy(valueId, "CFrame")
                end
            elseif typeName == "Color3" then
                constructor.fromRGB = function(r: number, g: number, b: number)
                    local valueId = string.format("Color3.fromRGB(%d, %d, %d)", r, g, b)
                    logAPICall("constructor", valueId)
                    return createProxy(valueId, "Color3")
                end
                constructor.fromHSV = function(h: number, s: number, v: number)
                    local valueId = string.format("Color3.fromHSV(%s, %s, %s)", h, s, v)
                    logAPICall("constructor", valueId)
                    return createProxy(valueId, "Color3")
                end
            end
        end

        return constructor
    end

    local vectorMetatables: {[string]: any} = {}
    vectorValue = function(typeName: string, x: any, y: any, z: any?, skipUnit: boolean?, rx: any?, ry: any?, rz: any?, lx: any?, ly: any?, lz: any?): any
        local value = {
            X = tonumber(x) or 0,
            Y = tonumber(y) or 0,
        }
        if z ~= nil then
            value.Z = tonumber(z) or 0
        end
        value.Magnitude = math.sqrt((value.X or 0) ^ 2 + (value.Y or 0) ^ 2 + (value.Z or 0) ^ 2)
        if not skipUnit and (typeName == "Vector2" or typeName == "Vector3") then
            if value.Magnitude > 0 then
                value.Unit = vectorValue(typeName, (value.X or 0) / value.Magnitude, (value.Y or 0) / value.Magnitude, typeName == "Vector3" and ((value.Z or 0) / value.Magnitude) or nil, true)
            else
                value.Unit = vectorValue(typeName, 0, 0, typeName == "Vector3" and 0 or nil, true)
            end
        end
        if typeName == "CFrame" then
            value.RX = tonumber(rx) or 0
            value.RY = tonumber(ry) or 0
            value.RZ = tonumber(rz) or 0
            value.Position = vectorValue("Vector3", value.X, value.Y, value.Z or 0)
            value.Rotation = value
            local lookX = tonumber(lx)
            local lookY = tonumber(ly)
            local lookZ = tonumber(lz)
            if lookX == nil or lookY == nil or lookZ == nil then
                lookX, lookY, lookZ = 0, 0, -1
            end
            value.LookVector = vectorValue("Vector3", lookX, lookY, lookZ)
            value.RightVector = vectorValue("Vector3", 1, 0, 0)
            value.UpVector = vectorValue("Vector3", 0, 1, 0)
            value.XVector = value.RightVector
            value.YVector = value.UpVector
            value.ZVector = vectorValue("Vector3", -lookX, -lookY, -lookZ)
        end
        objectTypeNames[value] = typeName
        local mt = vectorMetatables[typeName]
        if not mt then
            mt = {}
            local hasZ = typeName ~= "Vector2"
            mt.__eq = function(left, right)
                return type(left) == "table"
                    and type(right) == "table"
                    and objectTypeNames[left] == typeName
                    and objectTypeNames[right] == typeName
                    and (left.X or 0) == (right.X or 0)
                    and (left.Y or 0) == (right.Y or 0)
                    and (left.Z or 0) == (right.Z or 0)
            end
            mt.__add = function(left, right)
                return vectorValue(typeName, (left.X or 0) + (right.X or 0), (left.Y or 0) + (right.Y or 0), hasZ and ((left.Z or 0) + (right.Z or 0)) or nil)
            end
            mt.__sub = function(left, right)
                return vectorValue(typeName, (left.X or 0) - (right.X or 0), (left.Y or 0) - (right.Y or 0), hasZ and ((left.Z or 0) - (right.Z or 0)) or nil)
            end
            mt.__mul = function(left, right)
                if typeName == "CFrame" then
                    if objectTypeNames[right] == "Vector3" then
                        return vectorValue("Vector3",
                            (left.X or 0) + (right.X or 0),
                            (left.Y or 0) + (right.Y or 0),
                            (left.Z or 0) + (right.Z or 0)
                        )
                    end
                    if objectTypeNames[right] == "CFrame" then
                        return vectorValue("CFrame",
                            (left.X or 0) + (right.X or 0),
                            (left.Y or 0) + (right.Y or 0),
                            (left.Z or 0) + (right.Z or 0),
                            false,
                            (left.RX or 0) + (right.RX or 0),
                            (left.RY or 0) + (right.RY or 0),
                            (left.RZ or 0) + (right.RZ or 0)
                        )
                    end
                end
                if type(left) == "table" and type(right) == "table" then
                    return vectorValue(typeName,
                        (left.X or 0) * (right.X or 0),
                        (left.Y or 0) * (right.Y or 0),
                        hasZ and ((left.Z or 0) * (right.Z or 0)) or nil
                    )
                end
                local scalar = tonumber(right) or tonumber(left) or 1
                local vector = type(left) == "table" and left or right
                return vectorValue(typeName, (vector.X or 0) * scalar, (vector.Y or 0) * scalar, hasZ and ((vector.Z or 0) * scalar) or nil)
            end
            mt.__div = function(left, right)
                if type(left) == "table" and type(right) == "table" then
                    return vectorValue(typeName,
                        (left.X or 0) / ((right.X or 1) == 0 and 1 or (right.X or 1)),
                        (left.Y or 0) / ((right.Y or 1) == 0 and 1 or (right.Y or 1)),
                        hasZ and ((left.Z or 0) / ((right.Z or 1) == 0 and 1 or (right.Z or 1))) or nil
                    )
                end
                local scalar = tonumber(right) or tonumber(left) or 1
                if scalar == 0 then
                    scalar = 1
                end
                local vector = type(left) == "table" and left or right
                return vectorValue(typeName, (vector.X or 0) / scalar, (vector.Y or 0) / scalar, hasZ and ((vector.Z or 0) / scalar) or nil)
            end
            mt.__unm = function(vector)
                return vectorValue(typeName, -(vector.X or 0), -(vector.Y or 0), hasZ and -(vector.Z or 0) or nil)
            end
            mt.__index = function(self, key)
                if typeName == "CFrame" then
                    if key == "VectorToWorldSpace" or key == "VectorToObjectSpace" then
                        return function(_, vector)
                            if objectTypeNames[vector] ~= "Vector3" then
                                return vectorValue("Vector3", 0, 0, 0)
                            end
                            local x, y, z = vector.X or 0, vector.Y or 0, vector.Z or 0
                            local rx, ry, rz = self.RX or 0, self.RY or 0, self.RZ or 0
                            if key == "VectorToObjectSpace" then
                                rx, ry, rz = -rx, -ry, -rz
                            end
                            local cx, sx = math.cos(rx), math.sin(rx)
                            local cy, sy = math.cos(ry), math.sin(ry)
                            local cz, sz = math.cos(rz), math.sin(rz)
                            y, z = y * cx - z * sx, y * sx + z * cx
                            x, z = x * cy + z * sy, -x * sy + z * cy
                            x, y = x * cz - y * sz, x * sz + y * cz
                            return vectorValue("Vector3", x, y, z)
                        end
                    end
                    if key == "PointToWorldSpace" then
                        return function(_, point)
                            return vectorValue("Vector3",
                                (self.X or 0) + ((point and point.X) or 0),
                                (self.Y or 0) + ((point and point.Y) or 0),
                                (self.Z or 0) + ((point and point.Z) or 0)
                            )
                        end
                    end
                    if key == "PointToObjectSpace" then
                        return function(_, point)
                            return vectorValue("Vector3",
                                ((point and point.X) or 0) - (self.X or 0),
                                ((point and point.Y) or 0) - (self.Y or 0),
                                ((point and point.Z) or 0) - (self.Z or 0)
                            )
                        end
                    end
                    if key == "ToWorldSpace" then
                        return function(_, other)
                            return vectorValue("CFrame",
                                (self.X or 0) + ((other and other.X) or 0),
                                (self.Y or 0) + ((other and other.Y) or 0),
                                (self.Z or 0) + ((other and other.Z) or 0),
                                false,
                                (self.RX or 0) + ((other and other.RX) or 0),
                                (self.RY or 0) + ((other and other.RY) or 0),
                                (self.RZ or 0) + ((other and other.RZ) or 0)
                            )
                        end
                    end
                    if key == "ToObjectSpace" then
                        return function(_, other)
                            return vectorValue("CFrame",
                                ((other and other.X) or 0) - (self.X or 0),
                                ((other and other.Y) or 0) - (self.Y or 0),
                                ((other and other.Z) or 0) - (self.Z or 0),
                                false,
                                ((other and other.RX) or 0) - (self.RX or 0),
                                ((other and other.RY) or 0) - (self.RY or 0),
                                ((other and other.RZ) or 0) - (self.RZ or 0)
                            )
                        end
                    end
                    if key == "GetComponents" or key == "components" then
                        return function()
                            return self.X or 0, self.Y or 0, self.Z or 0, 1, 0, 0, 0, 1, 0, 0, 0, 1
                        end
                    end
                    if key == "ToEulerAnglesXYZ" or key == "ToEulerAngles" or key == "ToOrientation" then
                        return function()
                            return self.RX or 0, self.RY or 0, self.RZ or 0
                        end
                    end
                    if key == "ToEulerAnglesYXZ" then
                        return function()
                            return self.RY or 0, self.RX or 0, self.RZ or 0
                        end
                    end
                    if key == "ToAxisAngle" then
                        return function()
                            local rx, ry, rz = self.RX or 0, self.RY or 0, self.RZ or 0
                            local angle = math.sqrt(rx * rx + ry * ry + rz * rz)
                            if angle <= 0 then
                                return vectorValue("Vector3", 1, 0, 0), 0
                            end
                            return vectorValue("Vector3", rx / angle, ry / angle, rz / angle), angle
                        end
                    end
                    if key == "AngleBetween" then
                        return function(_, other)
                            local left = self.LookVector or vectorValue("Vector3", 0, 0, -1)
                            local right = other and other.LookVector or vectorValue("Vector3", 0, 0, -1)
                            local dot = (left.X or 0) * (right.X or 0) + (left.Y or 0) * (right.Y or 0) + (left.Z or 0) * (right.Z or 0)
                            local mag = math.max((left.Magnitude or 0) * (right.Magnitude or 0), 1e-9)
                            return math.acos(math.max(-1, math.min(1, dot / mag)))
                        end
                    end
                    if key == "Inverse" or key == "Orthonormalize" then
                        return function()
                            return vectorValue("CFrame", -(self.X or 0), -(self.Y or 0), -(self.Z or 0), false, -(self.RX or 0), -(self.RY or 0), -(self.RZ or 0))
                        end
                    end
                end
                if key == "Dot" then
                    return function(_, other)
                        return (self.X or 0) * ((other and other.X) or 0)
                            + (self.Y or 0) * ((other and other.Y) or 0)
                            + (hasZ and ((self.Z or 0) * ((other and other.Z) or 0)) or 0)
                    end
                end
                if key == "Cross" and hasZ then
                    return function(_, other)
                        return vectorValue("Vector3",
                            (self.Y or 0) * ((other and other.Z) or 0) - (self.Z or 0) * ((other and other.Y) or 0),
                            (self.Z or 0) * ((other and other.X) or 0) - (self.X or 0) * ((other and other.Z) or 0),
                            (self.X or 0) * ((other and other.Y) or 0) - (self.Y or 0) * ((other and other.X) or 0)
                        )
                    end
                end
                if key == "Cross" and not hasZ then
                    return function(_, other)
                        return (self.X or 0) * ((other and other.Y) or 0) - (self.Y or 0) * ((other and other.X) or 0)
                    end
                end
                if key == "Abs" then
                    return function()
                        return vectorValue(typeName, math.abs(self.X or 0), math.abs(self.Y or 0), hasZ and math.abs(self.Z or 0) or nil)
                    end
                end
                if key == "Ceil" then
                    return function()
                        return vectorValue(typeName, math.ceil(self.X or 0), math.ceil(self.Y or 0), hasZ and math.ceil(self.Z or 0) or nil)
                    end
                end
                if key == "Floor" then
                    return function()
                        return vectorValue(typeName, math.floor(self.X or 0), math.floor(self.Y or 0), hasZ and math.floor(self.Z or 0) or nil)
                    end
                end
                if key == "Sign" then
                    return function()
                        local function sign(value)
                            if value > 0 then return 1 end
                            if value < 0 then return -1 end
                            return 0
                        end
                        return vectorValue(typeName, sign(self.X or 0), sign(self.Y or 0), hasZ and sign(self.Z or 0) or nil)
                    end
                end
                if key == "Max" then
                    return function(_, other)
                        return vectorValue(typeName,
                            math.max(self.X or 0, (other and other.X) or 0),
                            math.max(self.Y or 0, (other and other.Y) or 0),
                            hasZ and math.max(self.Z or 0, (other and other.Z) or 0) or nil
                        )
                    end
                end
                if key == "Min" then
                    return function(_, other)
                        return vectorValue(typeName,
                            math.min(self.X or 0, (other and other.X) or 0),
                            math.min(self.Y or 0, (other and other.Y) or 0),
                            hasZ and math.min(self.Z or 0, (other and other.Z) or 0) or nil
                        )
                    end
                end
                if key == "FuzzyEq" then
                    return function(_, other, epsilon)
                        local eps = tonumber(epsilon) or 1e-5
                        return math.abs((self.X or 0) - ((other and other.X) or 0)) <= eps
                            and math.abs((self.Y or 0) - ((other and other.Y) or 0)) <= eps
                            and (not hasZ or math.abs((self.Z or 0) - ((other and other.Z) or 0)) <= eps)
                    end
                end
                if key == "Lerp" then
                    return function(_, goal, alpha)
                        local a = tonumber(alpha) or 0
                        return vectorValue(typeName,
                            (self.X or 0) + (((goal and goal.X) or 0) - (self.X or 0)) * a,
                            (self.Y or 0) + (((goal and goal.Y) or 0) - (self.Y or 0)) * a,
                            hasZ and ((self.Z or 0) + (((goal and goal.Z) or 0) - (self.Z or 0)) * a) or nil
                        )
                    end
                end
                if key == "Angle" then
                    return function(_, other)
                        local dot = (self.X or 0) * ((other and other.X) or 0)
                            + (self.Y or 0) * ((other and other.Y) or 0)
                            + (hasZ and ((self.Z or 0) * ((other and other.Z) or 0)) or 0)
                        local mag = math.max((self.Magnitude or 0) * ((other and other.Magnitude) or 0), 1e-9)
                        return math.acos(math.max(-1, math.min(1, dot / mag)))
                    end
                end
                return nil
            end
            mt.__tostring = function(self)
                if hasZ then
                    return string.format("%s, %s, %s", tostring(self.X), tostring(self.Y), tostring(self.Z))
                end
                return string.format("%s, %s", tostring(self.X), tostring(self.Y))
            end
            vectorMetatables[typeName] = mt
        end
        setmetatable(value, mt)
        if table.freeze then
            pcall(table.freeze, value)
        end
        return value
    end

    env.Vector2 = {
        new = function(x, y)
            logAPICall("constructor", string.format("Vector2.new(%s, %s)", formatValue(x), formatValue(y)))
            return vectorValue("Vector2", x, y)
        end,
    }
    env.Vector2.zero = vectorValue("Vector2", 0, 0)
    env.Vector2.one = vectorValue("Vector2", 1, 1)
    env.Vector2.xAxis = vectorValue("Vector2", 1, 0)
    env.Vector2.yAxis = vectorValue("Vector2", 0, 1)
    env.Vector3 = {
        new = function(x, y, z)
            logAPICall("constructor", string.format("Vector3.new(%s, %s, %s)", formatValue(x), formatValue(y), formatValue(z)))
            return vectorValue("Vector3", x, y, z)
        end,
        FromNormalId = function(normalId)
            local name = enumItemName(normalId)
            logAPICall("constructor", string.format("Vector3.FromNormalId(%s)", formatValue(name)))
            if name == "Top" then return vectorValue("Vector3", 0, 1, 0) end
            if name == "Bottom" then return vectorValue("Vector3", 0, -1, 0) end
            if name == "Left" then return vectorValue("Vector3", -1, 0, 0) end
            if name == "Right" then return vectorValue("Vector3", 1, 0, 0) end
            if name == "Front" then return vectorValue("Vector3", 0, 0, -1) end
            if name == "Back" then return vectorValue("Vector3", 0, 0, 1) end
            return vectorValue("Vector3", 0, 0, 0)
        end,
        FromAxis = function(axis)
            local name = enumItemName(axis)
            logAPICall("constructor", string.format("Vector3.FromAxis(%s)", formatValue(name)))
            if name == "X" then return vectorValue("Vector3", 1, 0, 0) end
            if name == "Y" then return vectorValue("Vector3", 0, 1, 0) end
            if name == "Z" then return vectorValue("Vector3", 0, 0, 1) end
            return vectorValue("Vector3", 0, 0, 0)
        end,
    }
    env.Vector3.zero = vectorValue("Vector3", 0, 0, 0)
    env.Vector3.one = vectorValue("Vector3", 1, 1, 1)
    env.Vector3.xAxis = vectorValue("Vector3", 1, 0, 0)
    env.Vector3.yAxis = vectorValue("Vector3", 0, 1, 0)
    env.Vector3.zAxis = vectorValue("Vector3", 0, 0, 1)
    env.vector = {
        create = function(x, y, z)
            return vectorValue("Vector3", x, y, z)
        end,
        cross = function(left, right)
            return vectorValue("Vector3",
                ((left and left.Y) or 0) * ((right and right.Z) or 0) - ((left and left.Z) or 0) * ((right and right.Y) or 0),
                ((left and left.Z) or 0) * ((right and right.X) or 0) - ((left and left.X) or 0) * ((right and right.Z) or 0),
                ((left and left.X) or 0) * ((right and right.Y) or 0) - ((left and left.Y) or 0) * ((right and right.X) or 0)
            )
        end,
        dot = function(left, right)
            return ((left and left.X) or 0) * ((right and right.X) or 0)
                + ((left and left.Y) or 0) * ((right and right.Y) or 0)
                + ((left and left.Z) or 0) * ((right and right.Z) or 0)
        end,
        magnitude = function(value)
            return value and value.Magnitude or 0
        end,
        normalize = function(value)
            return value and value.Unit or vectorValue("Vector3", 0, 0, 0)
        end,
    }
    env.CFrame = {
        new = function(x, y, z)
            logAPICall("constructor", string.format("CFrame.new(%s, %s, %s)", formatValue(x), formatValue(y), formatValue(z)))
            if x ~= nil and type(x) ~= "number" and objectTypeNames[x] ~= "Vector3" then
                error("Vector3 expected", 2)
            end
            if objectTypeNames[x] == "Vector3" then
                return vectorValue("CFrame", x.X, x.Y, x.Z)
            end
            return vectorValue("CFrame", x, y, z)
        end,
        Angles = function(x, y, z)
            logAPICall("constructor", string.format("CFrame.Angles(%s, %s, %s)", formatValue(x), formatValue(y), formatValue(z)))
            if type(x) ~= "number" or type(y) ~= "number" or type(z) ~= "number" then
                error("Unable to cast string to float", 2)
            end
            return vectorValue("CFrame", 0, 0, 0, false, x, y, z)
        end,
        fromEulerAngles = function(x, y, z)
            logAPICall("constructor", string.format("CFrame.fromEulerAngles(%s, %s, %s)", formatValue(x), formatValue(y), formatValue(z)))
            return vectorValue("CFrame", 0, 0, 0, false, x, y, z)
        end,
        fromEulerAnglesXYZ = function(x, y, z)
            logAPICall("constructor", string.format("CFrame.fromEulerAnglesXYZ(%s, %s, %s)", formatValue(x), formatValue(y), formatValue(z)))
            return vectorValue("CFrame", 0, 0, 0, false, x, y, z)
        end,
        fromEulerAnglesYXZ = function(x, y, z)
            logAPICall("constructor", string.format("CFrame.fromEulerAnglesYXZ(%s, %s, %s)", formatValue(x), formatValue(y), formatValue(z)))
            return vectorValue("CFrame", 0, 0, 0, false, x, y, z)
        end,
        fromOrientation = function(x, y, z)
            logAPICall("constructor", string.format("CFrame.fromOrientation(%s, %s, %s)", formatValue(x), formatValue(y), formatValue(z)))
            return vectorValue("CFrame", 0, 0, 0, false, x, y, z)
        end,
        fromAxisAngle = function(axis, angle)
            logAPICall("constructor", string.format("CFrame.fromAxisAngle(%s, %s)", formatValue(axis), formatValue(angle)))
            local amount = tonumber(angle) or 0
            return vectorValue("CFrame", 0, 0, 0, false, (axis and axis.X or 0) * amount, (axis and axis.Y or 0) * amount, (axis and axis.Z or 0) * amount)
        end,
        fromMatrix = function(position, rightVector, upVector, backVector)
            logAPICall("constructor", "CFrame.fromMatrix(...)")
            return vectorValue("CFrame", position and position.X or 0, position and position.Y or 0, position and position.Z or 0)
        end,
        lookAt = function(at, lookAt)
            logAPICall("constructor", "CFrame.lookAt(...)")
            if objectTypeNames[at] ~= "Vector3" or objectTypeNames[lookAt] ~= "Vector3" then
                error("Vector3 expected", 2)
            end
            local dx = ((lookAt and lookAt.X) or 0) - ((at and at.X) or 0)
            local dy = ((lookAt and lookAt.Y) or 0) - ((at and at.Y) or 0)
            local dz = ((lookAt and lookAt.Z) or -1) - ((at and at.Z) or 0)
            local mag = math.sqrt(dx * dx + dy * dy + dz * dz)
            if mag <= 0 then
                mag = 1
                dz = -1
            end
            return vectorValue("CFrame", at and at.X or 0, at and at.Y or 0, at and at.Z or 0, false, nil, nil, nil, dx / mag, dy / mag, dz / mag)
        end,
        lookAlong = function(at, direction)
            logAPICall("constructor", "CFrame.lookAlong(...)")
            local dx = (direction and direction.X) or 0
            local dy = (direction and direction.Y) or 0
            local dz = (direction and direction.Z) or -1
            local mag = math.sqrt(dx * dx + dy * dy + dz * dz)
            if mag <= 0 then
                mag = 1
                dz = -1
            end
            return vectorValue("CFrame", at and at.X or 0, at and at.Y or 0, at and at.Z or 0, false, nil, nil, nil, dx / mag, dy / mag, dz / mag)
        end,
        fromRotationBetweenVectors = function()
            logAPICall("constructor", "CFrame.fromRotationBetweenVectors(...)")
            return vectorValue("CFrame", 0, 0, 0)
        end,
    }
    env.CFrame.identity = vectorValue("CFrame", 0, 0, 0)

    local colorMetatable = {
        __index = function(self, key)
            if key == "ToHSV" then
                return function()
                    local r, g, b = self.R or 0, self.G or 0, self.B or 0
                    local maxValue = math.max(r, g, b)
                    local minValue = math.min(r, g, b)
                    local delta = maxValue - minValue
                    local h = 0
                    if delta ~= 0 then
                        if maxValue == r then
                            h = ((g - b) / delta) % 6
                        elseif maxValue == g then
                            h = (b - r) / delta + 2
                        else
                            h = (r - g) / delta + 4
                        end
                        h = h / 6
                    end
                    local s = maxValue == 0 and 0 or delta / maxValue
                    return h, s, maxValue
                end
            end
            if key == "ToHex" then
                return function()
                    local r = math.floor(math.max(0, math.min(1, self.R or 0)) * 255 + 0.5)
                    local g = math.floor(math.max(0, math.min(1, self.G or 0)) * 255 + 0.5)
                    local b = math.floor(math.max(0, math.min(1, self.B or 0)) * 255 + 0.5)
                    return string.format("%02x%02x%02x", r, g, b)
                end
            end
            if key == "Lerp" then
                return function(_, goal, alpha)
                    local a = tonumber(alpha) or 0
                    return colorValue(
                        (self.R or 0) + (((goal and goal.R) or 0) - (self.R or 0)) * a,
                        (self.G or 0) + (((goal and goal.G) or 0) - (self.G or 0)) * a,
                        (self.B or 0) + (((goal and goal.B) or 0) - (self.B or 0)) * a
                    )
                end
            end
            return nil
        end,
        __eq = function(left, right)
            return type(left) == "table"
                and type(right) == "table"
                and objectTypeNames[left] == "Color3"
                and objectTypeNames[right] == "Color3"
                and (left.R or 0) == (right.R or 0)
                and (left.G or 0) == (right.G or 0)
                and (left.B or 0) == (right.B or 0)
        end,
        __tostring = function(self)
            return string.format("%s, %s, %s", tostring(self.R), tostring(self.G), tostring(self.B))
        end,
    }

    colorValue = function(r: any, g: any, b: any): any
        local function clampColor(value: any): number
            local number = tonumber(value) or 0
            if number ~= number then
                number = 0
            end
            if number == math.huge then
                return 1
            end
            if number == -math.huge then
                return 0
            end
            return math.max(0, math.min(1, number))
        end
        local value = {
            R = clampColor(r),
            G = clampColor(g),
            B = clampColor(b),
        }
        value.r = value.R
        value.g = value.G
        value.b = value.B
        objectTypeNames[value] = "Color3"
        setmetatable(value, colorMetatable)
        if table.freeze then
            pcall(table.freeze, value)
        end
        return value
    end

    env.Color3 = {
        new = function(r, g, b)
            logAPICall("constructor", string.format("Color3.new(%s, %s, %s)", formatValue(r), formatValue(g), formatValue(b)))
            for _, component in ipairs({r, g, b}) do
                local number = tonumber(component)
                if number ~= nil and (number ~= number or number < 0 or number > 1) then
                    error("Color3 components must be between 0 and 1", 2)
                end
            end
            return colorValue(r, g, b)
        end,
        fromRGB = function(r, g, b)
            logAPICall("constructor", string.format("Color3.fromRGB(%s, %s, %s)", formatValue(r), formatValue(g), formatValue(b)))
            return colorValue((tonumber(r) or 0) / 255, (tonumber(g) or 0) / 255, (tonumber(b) or 0) / 255)
        end,
        fromHSV = function(h, s, v)
            local hue = (tonumber(h) or 0) % 1
            local sat = math.max(0, math.min(1, tonumber(s) or 0))
            local val = math.max(0, math.min(1, tonumber(v) or 0))
            local i = math.floor(hue * 6)
            local f = hue * 6 - i
            local p = val * (1 - sat)
            local q = val * (1 - f * sat)
            local t = val * (1 - (1 - f) * sat)
            local mod = i % 6
            logAPICall("constructor", string.format("Color3.fromHSV(%s, %s, %s)", formatValue(h), formatValue(s), formatValue(v)))
            if mod == 0 then return colorValue(val, t, p) end
            if mod == 1 then return colorValue(q, val, p) end
            if mod == 2 then return colorValue(p, val, t) end
            if mod == 3 then return colorValue(p, q, val) end
            if mod == 4 then return colorValue(t, p, val) end
            return colorValue(val, p, q)
        end,
        fromHex = function(hex)
            local text = tostring(hex or ""):gsub("^#", "")
            if #text == 3 then
                text = text:sub(1, 1):rep(2) .. text:sub(2, 2):rep(2) .. text:sub(3, 3):rep(2)
            end
            local r = tonumber(text:sub(1, 2), 16) or 0
            local g = tonumber(text:sub(3, 4), 16) or 0
            local b = tonumber(text:sub(5, 6), 16) or 0
            logAPICall("constructor", string.format("Color3.fromHex(%s)", formatValue(hex)))
            return colorValue(r / 255, g / 255, b / 255)
        end,
    }

    local dateTimeBaseMillis = os.time() * 1000 + math.floor((os.clock() % 1) * 1000)
    local lastDateTimeMillis = dateTimeBaseMillis - 1
    local function currentDateTimeMillis(): number
        lastDateTimeMillis += 1
        return lastDateTimeMillis
    end

    local function dateTimeValue(timestamp: any): any
        local rawTimestamp = tonumber(timestamp) or os.time()
        local millis = math.floor(rawTimestamp * 1000 + 0.5)
        local seconds = math.floor(millis / 1000)
        local value = {
            UnixTimestamp = seconds,
            UnixTimestampMillis = millis,
        }
        function value:ToIsoDate()
            local ok, text = pcall(os.date, "!%Y-%m-%dT%H:%M:%SZ", self.UnixTimestamp)
            if ok and type(text) == "string" then
                return text
            end
            return "1970-01-01T00:00:00Z"
        end
        function value:ToUniversalTime()
            local ok, parts = pcall(os.date, "!*t", self.UnixTimestamp)
            if ok and type(parts) == "table" then
                return {
                    Year = tonumber(parts.year) or 1970,
                    Month = tonumber(parts.month) or 1,
                    Day = tonumber(parts.day) or 1,
                    Hour = tonumber(parts.hour) or 0,
                    Minute = tonumber(parts.min) or 0,
                    Second = tonumber(parts.sec) or 0,
                    Millisecond = millis % 1000,
                }
            end
            return {Year = 1970, Month = 1, Day = 1, Hour = 0, Minute = 0, Second = 0, Millisecond = 0}
        end
        function value:ToLocalTime()
            local ok, parts = pcall(os.date, "*t", self.UnixTimestamp)
            if ok and type(parts) == "table" then
                return {
                    Year = tonumber(parts.year) or 1970,
                    Month = tonumber(parts.month) or 1,
                    Day = tonumber(parts.day) or 1,
                    Hour = tonumber(parts.hour) or 0,
                    Minute = tonumber(parts.min) or 0,
                    Second = tonumber(parts.sec) or 0,
                    Millisecond = millis % 1000,
                }
            end
            return {Year = 1970, Month = 1, Day = 1, Hour = 0, Minute = 0, Second = 0, Millisecond = 0}
        end
        function value:FormatUniversalTime(formatText, locale)
            local fmt = tostring(formatText or "yyyy-MM-dd")
            local replacements = {
                ["YYYY"] = "%Y",
                ["yyyy"] = "%Y",
                ["MM"] = "%m",
                ["DD"] = "%d",
                ["dd"] = "%d",
                ["HH"] = "%H",
                ["mm"] = "%M",
                ["ss"] = "%S",
            }
            for key, replacement in pairs(replacements) do
                fmt = fmt:gsub(key, function()
                    return replacement
                end)
            end
            local ok, text = pcall(os.date, "!" .. fmt, self.UnixTimestamp)
            if ok and type(text) == "string" then
                return text
            end
            return "1970-01-01"
        end
        objectTypeNames[value] = "DateTime"
        return value
    end

    env.DateTime = {
        now = function()
            logAPICall("function_call", "DateTime.now()")
            return dateTimeValue(currentDateTimeMillis() / 1000)
        end,
        fromUnixTimestamp = function(timestamp)
            logAPICall("function_call", string.format("DateTime.fromUnixTimestamp(%s)", formatValue(timestamp)))
            return dateTimeValue(timestamp)
        end,
        fromUnixTimestampMillis = function(timestamp)
            logAPICall("function_call", string.format("DateTime.fromUnixTimestampMillis(%s)", formatValue(timestamp)))
            return dateTimeValue((tonumber(timestamp) or 0) / 1000)
        end,
        fromIsoDate = function(value)
            logAPICall("function_call", string.format("DateTime.fromIsoDate(%s)", formatValue(value)))
            local text = tostring(value or "")
            local year, month, day, hour, min, sec = text:match("^(%d+)%-(%d+)%-(%d+)T?(%d*):?(%d*):?(%d*)")
            local timestamp = os.time({
                year = tonumber(year) or 1970,
                month = tonumber(month) or 1,
                day = tonumber(day) or 1,
                hour = tonumber(hour) or 0,
                min = tonumber(min) or 0,
                sec = tonumber(sec) or 0,
            })
            return dateTimeValue(timestamp)
        end,
    }
    env.UDim2 = makeConstructor("UDim2")
    env.UDim = makeConstructor("UDim")
    env.BrickColor = makeConstructor("BrickColor")
    env.BrickColor.random = function()
        logAPICall("constructor", "BrickColor.random()")
        return dataValue("BrickColor", dataFields("BrickColor", {"Medium stone grey"}))
    end
    env.BrickColor.palette = function(index)
        logAPICall("constructor", string.format("BrickColor.palette(%s)", formatValue(index)))
        return dataValue("BrickColor", dataFields("BrickColor", {tonumber(index) or 194}))
    end
    env.BrickColor.White = function()
        logAPICall("constructor", "BrickColor.White()")
        return dataValue("BrickColor", {Name = "White", Number = 1, Color = colorValue(1, 1, 1), r = 1, g = 1, b = 1})
    end
    env.BrickColor.Gray = function()
        logAPICall("constructor", "BrickColor.Gray()")
        return dataValue("BrickColor", {Name = "Medium stone grey", Number = 194, Color = colorValue(0.5, 0.5, 0.5), r = 0.5, g = 0.5, b = 0.5})
    end
    env.BrickColor.DarkGray = function()
        logAPICall("constructor", "BrickColor.DarkGray()")
        return dataValue("BrickColor", {Name = "Dark stone grey", Number = 199, Color = colorValue(0.388235, 0.372549, 0.384314), r = 0.388235, g = 0.372549, b = 0.384314})
    end
    env.BrickColor.Black = function()
        logAPICall("constructor", "BrickColor.Black()")
        return dataValue("BrickColor", {Name = "Black", Number = 26, Color = colorValue(0, 0, 0), r = 0, g = 0, b = 0})
    end
    env.BrickColor.Red = function()
        logAPICall("constructor", "BrickColor.Red()")
        return dataValue("BrickColor", {Name = "Bright red", Number = 21, Color = colorValue(0.768627, 0.156863, 0.109804), r = 0.768627, g = 0.156863, b = 0.109804})
    end
    env.BrickColor.Yellow = function()
        logAPICall("constructor", "BrickColor.Yellow()")
        return dataValue("BrickColor", {Name = "Bright yellow", Number = 24, Color = colorValue(0.960784, 0.803922, 0.188235), r = 0.960784, g = 0.803922, b = 0.188235})
    end
    env.BrickColor.Green = function()
        logAPICall("constructor", "BrickColor.Green()")
        return dataValue("BrickColor", {Name = "Dark green", Number = 28, Color = colorValue(0.156863, 0.498039, 0.278431), r = 0.156863, g = 0.498039, b = 0.278431})
    end
    env.BrickColor.Blue = function()
        logAPICall("constructor", "BrickColor.Blue()")
        return dataValue("BrickColor", {Name = "Bright blue", Number = 23, Color = colorValue(0.05098, 0.411765, 0.67451), r = 0.05098, g = 0.411765, b = 0.67451})
    end
    env.Ray = makeConstructor("Ray")
    env.Region3 = makeConstructor("Region3")
    env.NumberSequence = makeConstructor("NumberSequence")
    env.ColorSequence = makeConstructor("ColorSequence")
    env.NumberSequenceKeypoint = makeConstructor("NumberSequenceKeypoint")
    env.ColorSequenceKeypoint = makeConstructor("ColorSequenceKeypoint")
    env.NumberRange = makeConstructor("NumberRange")
    env.Rect = makeConstructor("Rect")
    env.TweenInfo = makeConstructor("TweenInfo")
    env.Vector2int16 = makeConstructor("Vector2int16")
    env.Vector3int16 = makeConstructor("Vector3int16")
    env.Faces = makeConstructor("Faces")
    env.Axes = makeConstructor("Axes")
    env.PathWaypoint = makeConstructor("PathWaypoint")
    env.FloatCurveKey = makeConstructor("FloatCurveKey")
    env.ValueCurveKey = makeConstructor("ValueCurveKey")
    env.RotationCurveKey = makeConstructor("RotationCurveKey")
    env.CatalogSearchParams = makeConstructor("CatalogSearchParams")
    env.Region3int16 = makeConstructor("Region3int16")
    env.SecurityCapabilities = makeConstructor("SecurityCapabilities")
    env.SecurityCapabilities.fromCurrent = function()
        logAPICall("constructor", "SecurityCapabilities.fromCurrent()")
        return dataValue("SecurityCapabilities", {All = true})
    end
    env.PhysicalProperties = makeConstructor("PhysicalProperties")
    env.RaycastParams = makeConstructor("RaycastParams")
    env.OverlapParams = makeConstructor("OverlapParams")
    local randomAutoSeed = 0
    env.Random = {
        new = function(seed)
            logAPICall("constructor", string.format("Random.new(%s)", formatValue(seed)))
            if seed ~= nil and type(seed) ~= "number" then
                error("invalid argument #1 to 'new' (number expected)", 2)
            end
            local seedValue = seed
            if seedValue == nil then
                randomAutoSeed += 1
                seedValue = os.time() * 1000 + math.floor((os.clock() or 0) * 1000000) + randomAutoSeed
            end
            return dataValue("Random", {Seed = seedValue})
        end,
    }
    env.SharedTable = {
        new = function(value)
            logAPICall("constructor", "SharedTable.new(...)")
            return dataValue("SharedTable", type(value) == "table" and value or {})
        end,
        size = function(value)
            logAPICall("function_call", "SharedTable.size(...)")
            local count = 0
            if type(value) == "table" then
                for _ in pairs(value) do
                    count += 1
                end
            end
            return count
        end,
        clear = function(value)
            logAPICall("function_call", "SharedTable.clear(...)")
            if type(value) == "table" then
                for key in pairs(value) do
                    rawset(value, key, nil)
                end
            end
        end,
        increment = function(value, key, amount)
            logAPICall("function_call", "SharedTable.increment(...)")
            if type(value) ~= "table" then
                error("invalid argument #1 to 'increment' (SharedTable expected)", 2)
            end
            local field = (type(key) == "string" or type(key) == "number") and key or tostring(key)
            local current = rawget(value, field)
            if type(current) ~= "number" then
                error("SharedTable element must exist and be a number", 2)
            end
            local nextValue = current + (tonumber(amount) or 1)
            rawset(value, field, nextValue)
            return current
        end,
        update = function(value, key, callback)
            logAPICall("function_call", "SharedTable.update(...)")
            if type(value) ~= "table" then
                error("invalid argument #1 to 'update' (SharedTable expected)", 2)
            end
            if type(callback) ~= "function" then
                error("invalid argument #3 to 'update' (function expected)", 2)
            end
            local field = (type(key) == "string" or type(key) == "number") and key or tostring(key)
            local nextValue = callback(rawget(value, field))
            rawset(value, field, nextValue)
        end,
        clone = function(value)
            logAPICall("function_call", "SharedTable.clone(...)")
            local out = {}
            if type(value) == "table" then
                for key, item in pairs(value) do
                    out[key] = item
                end
            end
            return dataValue("SharedTable", out)
        end,
        cloneAndFreeze = function(value)
            logAPICall("function_call", "SharedTable.cloneAndFreeze(...)")
            local out = env.SharedTable.clone(value)
            if table.freeze then
                pcall(table.freeze, out)
            end
            return out
        end,
        freeze = function(value)
            logAPICall("function_call", "SharedTable.freeze(...)")
            if type(value) == "table" and table.freeze then
                pcall(table.freeze, value)
            end
            return value
        end,
        isFrozen = function(value)
            logAPICall("function_call", "SharedTable.isFrozen(...)")
            if type(value) ~= "table" then
                return true
            end
            if table.isfrozen then
                local ok, frozen = pcall(table.isfrozen, value)
                if ok then
                    return frozen == true
                end
            end
            return false
        end,
    }
    env.SharedTable.isfrozen = env.SharedTable.isFrozen
    env.UDim2.fromScale = function(x, y)
        logAPICall("constructor", string.format("UDim2.fromScale(%s, %s)", formatValue(x), formatValue(y)))
        local xValue = dataValue("UDim", {Scale = tonumber(x) or 0, Offset = 0})
        local yValue = dataValue("UDim", {Scale = tonumber(y) or 0, Offset = 0})
        return dataValue("UDim2", {
            X = xValue,
            Y = yValue,
            Width = xValue,
            Height = yValue,
        })
    end
    env.UDim2.fromOffset = function(x, y)
        logAPICall("constructor", string.format("UDim2.fromOffset(%s, %s)", formatValue(x), formatValue(y)))
        local xValue = dataValue("UDim", {Scale = 0, Offset = tonumber(x) or 0})
        local yValue = dataValue("UDim", {Scale = 0, Offset = tonumber(y) or 0})
        return dataValue("UDim2", {
            X = xValue,
            Y = yValue,
            Width = xValue,
            Height = yValue,
        })
    end
    env.Font = {
        new = function(...: any)
            local args = {...}
            local argStrs: {string} = {}
            for _, v in ipairs(args) do
                table.insert(argStrs, formatValue(v))
            end
            local valueId = string.format("Font.new(%s)", table.concat(argStrs, ", "))
            logAPICall("constructor", valueId)
            return dataValue("Font", {
                Family = tostring(args[1] or "rbxasset://fonts/families/SourceSansPro.json"),
                Weight = args[2] or enumDefault("FontWeight", "Regular"),
                Style = args[3] or enumDefault("FontStyle", "Normal"),
            })
        end,
        fromEnum = function(value)
            local valueId = string.format("Font.fromEnum(%s)", proxyRegistry[value] or formatValue(value))
            logAPICall("constructor", valueId)
            return dataValue("Font", {Family = tostring(value), Weight = enumDefault("FontWeight", "Regular"), Style = enumDefault("FontStyle", "Normal")})
        end,
        fromName = function(name, weight, style)
            local valueId = string.format("Font.fromName(%s, %s, %s)", formatValue(name), formatValue(weight), formatValue(style))
            logAPICall("constructor", valueId)
            return dataValue("Font", {Family = tostring(name or "SourceSansPro"), Weight = weight or enumDefault("FontWeight", "Regular"), Style = style or enumDefault("FontStyle", "Normal")})
        end,
        fromId = function(id, weight, style)
            local valueId = string.format("Font.fromId(%s, %s, %s)", formatValue(id), formatValue(weight), formatValue(style))
            logAPICall("constructor", valueId)
            return dataValue("Font", {Family = tostring(id or ""), Weight = weight or enumDefault("FontWeight", "Regular"), Style = style or enumDefault("FontStyle", "Normal")})
        end,
    }

    local enumCache: {[string]: any} = {}
    local enumValueCounters: {[string]: number} = {}
    local function normalizeEnumTypeName(enumName: string): string
        return enumName:match("^Enum%.(.+)$") or enumName
    end

    local function snapshotEnumNames(enumName: string): {string}?
        local enumSnapshot = computedValues.__staticEnumSnapshot
        local enumInfo = type(enumSnapshot) == "table" and enumSnapshot[normalizeEnumTypeName(enumName)] or nil
        if enumInfo and #enumInfo.order > 0 then
            return enumInfo.order
        end
        return nil
    end

    local function snapshotEnumValue(enumType: string, itemName: string): number?
        local enumSnapshot = computedValues.__staticEnumSnapshot
        local enumInfo = type(enumSnapshot) == "table" and enumSnapshot[normalizeEnumTypeName(enumType)] or nil
        if enumInfo then
            return enumInfo.values[itemName]
        end
        return nil
    end

    local function enumItemsFromNames(enumName: string, names: {string}): {any}
        local items = {}
        for _, itemName in ipairs(names) do
            table.insert(items, enumDefault(enumName, itemName))
        end
        return items
    end

    local enumIndexFunc = function(self, key: string)
        if key == "GetEnumItems" then
            return function(_, enumType)
                logAPICall("method_call", "Enum:GetEnumItems(...)")
                local enumName = "Enum"
                if type(enumType) == "table" then
                    enumName = proxyRegistry[enumType] or tostring(enumType)
                    enumName = normalizeEnumTypeName(enumName)
                elseif enumType ~= nil then
                    enumName = normalizeEnumTypeName(tostring(enumType))
                end
                local snapshotNames = snapshotEnumNames(enumName)
                if snapshotNames then
                    return enumItemsFromNames(enumName, snapshotNames)
                end
                return {
                    enumDefault(enumName, "None"),
                    enumDefault(enumName, "Default"),
                }
            end
        end
        local enumTypeId = string.format("Enum.%s", key)

        local enumTypeIndexFunc = function(_, valueKey: string)
            if valueKey == "GetEnumItems" then
                return function()
                    logAPICall("method_call", string.format("Enum.%s:GetEnumItems()", key))
                    local snapshotNames = snapshotEnumNames(key)
                    if snapshotNames then
                        return enumItemsFromNames(key, snapshotNames)
                    end
                    local names = {"None", "Default", "Enabled", "Disabled", "Automatic", "Manual", "Open", "Closed", "Started", "Stopped", "Success", "Failure"}
                    if key == "AccessoryType" then
                        names = {
                            "Hat", "Hair", "Face", "Neck", "Shoulder", "Front", "Back", "Waist", "TShirt", "Shirt",
                            "Pants", "Jacket", "Sweater", "Shorts", "LeftShoe", "RightShoe", "DressSkirt", "Eyebrow",
                            "Eyelash", "MoodAnimation", "DynamicHead",
                        }
                    elseif key == "AssetType" then
                        names = {
                            "Image", "TShirt", "Audio", "Mesh", "Lua", "Hat", "Place", "Model", "Shirt", "Pants",
                            "Decal", "Avatar", "Head", "Face", "Gear", "Badge", "GroupEmblem", "Animation", "Arms", "Legs",
                            "Torso", "RightArm", "LeftArm", "LeftLeg", "RightLeg", "Package", "GamePass", "Plugin", "MeshPart", "HairAccessory",
                            "FaceAccessory", "NeckAccessory", "ShoulderAccessory", "FrontAccessory", "BackAccessory", "WaistAccessory", "ClimbAnimation", "DeathAnimation", "FallAnimation", "IdleAnimation",
                            "JumpAnimation", "RunAnimation", "SwimAnimation", "WalkAnimation", "PoseAnimation", "EarAccessory", "EyeAccessory", "EmoteAnimation", "Video", "TShirtAccessory",
                            "ShirtAccessory", "PantsAccessory", "JacketAccessory", "SweaterAccessory", "ShortsAccessory", "LeftShoeAccessory", "RightShoeAccessory", "DressSkirtAccessory", "FontFamily", "EyebrowAccessory",
                            "EyelashAccessory", "MoodAnimation", "DynamicHead", "CodeSnippet", "AdsVideo", "Photo", "MarketplaceItem", "AvatarPart", "AvatarAnimation", "UserGeneratedBundle",
                        }
                    elseif key == "AvatarAssetType" then
                        names = {
                            "TShirt", "Hat", "Shirt", "Pants", "Head", "Face", "Gear", "Torso", "RightArm", "LeftArm",
                            "LeftLeg", "RightLeg", "HairAccessory", "FaceAccessory", "NeckAccessory", "ShoulderAccessory", "FrontAccessory", "BackAccessory", "WaistAccessory", "ClimbAnimation",
                            "DeathAnimation", "FallAnimation", "IdleAnimation", "JumpAnimation", "RunAnimation", "SwimAnimation", "WalkAnimation", "PoseAnimation", "EmoteAnimation", "EarAccessory",
                            "EyeAccessory", "TShirtAccessory", "ShirtAccessory", "PantsAccessory", "JacketAccessory", "SweaterAccessory", "ShortsAccessory", "LeftShoeAccessory", "RightShoeAccessory", "DressSkirtAccessory",
                            "EyebrowAccessory", "EyelashAccessory", "MoodAnimation", "DynamicHead", "Body", "Outfit", "AvatarPart", "AvatarAnimation",
                        }
                    elseif key == "ActionType" then
                        names = {"Nothing", "Pause", "Lose", "Draw", "Win", "ButtonA"}
                    elseif key == "AdAvailabilityResult" then
                        names = {"IsAvailable", "DeviceIneligible", "ExperienceIneligible", "InternalError", "NoFill", "PlayerIneligible", "PublisherIneligible"}
                    elseif key == "AdEventType" then
                        names = {"VideoLoaded", "VideoRemoved", "UserCompleted", "UserSkipped", "UserClosed", "Error"}
                    elseif key == "AdUIEventType" then
                        names = {"AdLabelClicked", "AdLabelClosed", "AdLabelCollapsed", "AdLabelExpanded", "AdLabelVisible", "AdLabelHidden", "AdShown", "AdHidden", "AdClicked"}
                    elseif key == "AdTeleportMethod" then
                        names = {"Undefined", "PortalForward", "InGameMenu", "UI", "Command"}
                    elseif key == "AdornShading" then
                        names = {"AlwaysOnTop", "Automatic", "Occluded", "Visible", "Hidden"}
                    elseif key == "AlignType" then
                        names = {"PrimaryAxisParallel", "PrimaryAxisPerpendicular", "PrimaryAxisLookAt", "AllAxes", "Parallel", "Perpendicular"}
                    elseif key == "AlphaMode" then
                        names = {"Overlay", "Transparency", "Opaque", "Additive"}
                    elseif key == "AnalyticsEconomyTransactionType" then
                        names = {"IAP", "Shop", "Gameplay", "ContextualPurchase", "TimedReward", "Onboarding"}
                    elseif key == "AnalyticsLogLevel" then
                        names = {"Trace", "Debug", "Information", "Warning", "Error", "Fatal"}
                    elseif key == "AnalyticsProgressionStatus" then
                        names = {"Start", "Complete", "Fail", "Abandon", "Progress"}
                    elseif key == "AnalyticsProgressionType" then
                        names = {"Custom", "Start", "Complete", "Fail"}
                    elseif key == "AnimationClipFromVideoStatus" then
                        names = {"Initializing", "Pending", "Processing", "Success", "Failed", "TimedOut", "NoVideo", "InvalidVideo", "Moderated", "Unknown", "Cancelled", "Ready"}
                    elseif key == "AnimationNodePlayMode" then
                        names = {"Automatic", "Solo", "Mute", "Default"}
                    elseif key == "AnimationPriority" then
                        names = {"Core", "Idle", "Movement", "Action", "Action2", "Action3", "Action4"}
                    elseif key == "AppLifecycleManagerState" then
                        names = {"Detached", "Active", "Inactive", "Hidden", "Suspended"}
                    elseif key == "AppShellActionType" then
                        names = {"None", "OpenApp", "CloseApp", "LaunchApp", "SwitchApp", "OpenSettings", "OpenSearch", "OpenProfile", "OpenHome", "OpenCatalog", "OpenNotifications"}
                    elseif key == "AppShellFeature" then
                        names = {"None", "Home", "Chat", "Avatar", "Settings", "Search", "Notifications", "Catalog"}
                    elseif key == "NormalId" then
                        names = {"Right", "Top", "Back", "Left", "Bottom", "Front"}
                    elseif key == "Axis" then
                        names = {"X", "Y", "Z"}
                    elseif key == "SalesTypeFilter" then
                        names = {"All", "Collectibles", "Premium"}
                    elseif key == "SecurityCapability" then
                        names = {"RunClientScript", "RunServerScript", "AccessOutsideWrite", "AssetRequire"}
                    end
                    local items = {}
                    for _, itemName in ipairs(names) do
                        table.insert(items, enumDefault(key, itemName))
                    end
                    return items
                end
            end
            local fullEnumPath = string.format("Enum.%s.%s", key, valueKey)
            if enumCache[fullEnumPath] then
                return enumCache[fullEnumPath]
            end
            enumValues[fullEnumPath] = fullEnumPath
            logAPICall("enum_access", fullEnumPath)
            enumValueCounters[key] = (enumValueCounters[key] or -1) + 1
            local enumValue = snapshotEnumValue(key, valueKey)
            if enumValue == nil then
                enumValue = key == "Material" and valueKey == "Plastic" and 256 or enumValueCounters[key]
            end
            local enumItem = {
                Name = valueKey,
                Value = enumValue,
                EnumType = enumCache[enumTypeId],
            }
            objectTypeNames[enumItem] = "EnumItem"
            enumCache[fullEnumPath] = setmetatable(enumItem, {
                __tostring = function()
                    return fullEnumPath
                end,
                __newindex = function()
                    error("attempt to modify a readonly enum item", 2)
                end,
            })
            if table.freeze then
                pcall(table.freeze, enumCache[fullEnumPath])
            end
            return enumCache[fullEnumPath]
        end

        if enumCache[enumTypeId] then
            return enumCache[enumTypeId]
        end
        enumCache[enumTypeId] = createProxy(enumTypeId, "EnumType", enumTypeIndexFunc)
        return enumCache[enumTypeId]
    end

    env.Enum = createProxy("Enum", "Enum", enumIndexFunc)

    rawset(runService, "RunState", enumDefault("RunState", "Running"))

    local currentCamera = makeRobloxProxy("workspace.CurrentCamera", "Camera", {
        Name = "Camera",
        ClassName = "Camera",
        Parent = workspaceService,
        CFrame = vectorValue("CFrame", 0, 0, 0),
        Focus = vectorValue("CFrame", 0, 0, 0),
        FieldOfView = 70,
        NearPlaneZ = -0.5,
        WorldToScreenPoint = function(_, position)
            logAPICall("method_call", "Camera:WorldToScreenPoint(...)")
            return vectorValue("Vector3", position and position.X or 0, position and position.Y or 0, 0), true
        end,
        WorldToViewportPoint = function(_, position)
            logAPICall("method_call", "Camera:WorldToViewportPoint(...)")
            return vectorValue("Vector3", position and position.X or 0, position and position.Y or 0, 0), true
        end,
        ScreenPointToRay = function(_, x, y)
            logAPICall("method_call", "Camera:ScreenPointToRay(...)")
            return dataValue("Ray", {Origin = vectorValue("Vector3", tonumber(x) or 0, tonumber(y) or 0, 0), Direction = vectorValue("Vector3", 0, 0, -1)})
        end,
        ViewportPointToRay = function(_, x, y)
            logAPICall("method_call", "Camera:ViewportPointToRay(...)")
            return dataValue("Ray", {Origin = vectorValue("Vector3", tonumber(x) or 0, tonumber(y) or 0, 0), Direction = vectorValue("Vector3", 0, 0, -1)})
        end,
    })
    rawset(workspaceService, "CurrentCamera", currentCamera)
    rawset(workspaceService, "Camera", currentCamera)
    rawset(workspaceService, "Terrain", makeRobloxProxy("workspace.Terrain", "Terrain", {
        Name = "Terrain",
        ClassName = "Terrain",
        Parent = workspaceService,
    }))
    rawset(workspaceService, "Baseplate", makeRobloxProxy("workspace.Baseplate", "Part", {
        Name = "Baseplate",
        ClassName = "Part",
        Parent = workspaceService,
        Anchored = true,
        Size = vectorValue("Vector3", 512, 20, 512),
        Position = vectorValue("Vector3", 0, -10, 0),
    }))

    local lightingService = makeRobloxProxy("Lighting", "Lighting", {
        Ambient = colorValue(0, 0, 0),
        OutdoorAmbient = colorValue(0.5, 0.5, 0.5),
        FogColor = colorValue(1, 1, 1),
        Brightness = 1,
        FogEnd = 100000,
        FogStart = 0,
        GeographicLatitude = 41,
        TimeOfDay = "14:00:00",
        GlobalShadows = true,
    })
    serviceResolvers.Lighting = function()
        return lightingService
    end
    env.Lighting = lightingService

    local marketplaceService = makeRobloxProxy("MarketplaceService", "MarketplaceService", {
        GetProductInfo = function(_, assetId)
            logAPICall("method_call", string.format("MarketplaceService:GetProductInfo(%s)", formatValue(assetId)))
            return {
                Name = "Asset " .. tostring(assetId or 0),
                AssetTypeId = 0,
                Creator = {Name = "Roblox", Id = 1, CreatorType = "User"},
                IsForSale = false,
            }
        end,
    })
    serviceResolvers.MarketplaceService = function()
        return marketplaceService
    end
    env.MarketplaceService = marketplaceService

    local tweenService = makeRobloxProxy("TweenService", "TweenService", {
        Create = function(_, target, tweenInfo, goals)
            logAPICall("method_call", "TweenService:Create(...)")
            if tweenInfo == nil then
                error("Argument 2 missing", 2)
            end
            if type(goals) ~= "table" then
                error("Unable to cast value to Object", 2)
            end
            for key, value in pairs(goals) do
                if key == "Transparency" and type(value) ~= "number" then
                    error("Unable to cast value to float", 2)
                end
                if (key == "CFrame" and objectTypeNames[value] ~= "CFrame")
                    or (key == "Position" and objectTypeNames[value] ~= "Vector3") then
                    error("Unable to cast value to " .. tostring(key), 2)
                end
            end
            return makeRobloxProxy("TweenService.Tween", "Tween", {
                PlaybackState = enumDefault("PlaybackState", "Begin"),
                Completed = makeSignal("TweenService.Tween.Completed"),
                Play = function()
                    logAPICall("method_call", "Tween:Play()")
                    if type(target) == "table" then
                        for key, value in pairs(goals) do
                            rawset(target, key, value)
                        end
                    end
                end,
                Pause = function()
                    logAPICall("method_call", "Tween:Pause()")
                end,
                Cancel = function()
                    logAPICall("method_call", "Tween:Cancel()")
                end,
            })
        end,
    })
    serviceResolvers.TweenService = function()
        return tweenService
    end
    env.TweenService = tweenService

    local userInputService = makeRobloxProxy("UserInputService", "UserInputService", {
        TouchEnabled = false,
        KeyboardEnabled = true,
        MouseEnabled = true,
        GamepadEnabled = false,
        AccelerometerEnabled = false,
        GyroscopeEnabled = false,
        VREnabled = false,
        MouseIcon = "",
        MouseIconEnabled = true,
        MouseBehavior = enumDefault("MouseBehavior", "Default"),
        GetMouseLocation = function()
            logAPICall("method_call", "UserInputService:GetMouseLocation()")
            return vectorValue("Vector2", 0, 0)
        end,
        IsKeyDown = function()
            logAPICall("method_call", "UserInputService:IsKeyDown(...)")
            return false
        end,
        IsMouseButtonPressed = function()
            logAPICall("method_call", "UserInputService:IsMouseButtonPressed(...)")
            return false
        end,
    })
    serviceResolvers.UserInputService = function()
        return userInputService
    end
    env.UserInputService = userInputService

    local pathfindingService = makeRobloxProxy("PathfindingService", "PathfindingService", {
        CreatePath = function()
            logAPICall("method_call", "PathfindingService:CreatePath(...)")
            return makeRobloxProxy("PathfindingService.Path", "Path", {
                Status = enumDefault("PathStatus", "Success"),
                GetWaypoints = function()
                    logAPICall("method_call", "Path:GetWaypoints()")
                    return {}
                end,
            })
        end,
    })
    serviceResolvers.PathfindingService = function()
        return pathfindingService
    end
    env.PathfindingService = pathfindingService

    local boundActions: {[string]: any} = {}
    local contextActionService = makeRobloxProxy("ContextActionService", "ContextActionService", {
        BindAction = function(_, name, callback)
            logAPICall("method_call", string.format("ContextActionService:BindAction(%s)", formatValue(name)))
            boundActions[tostring(name)] = callback
        end,
        UnbindAction = function(_, name)
            logAPICall("method_call", string.format("ContextActionService:UnbindAction(%s)", formatValue(name)))
            boundActions[tostring(name)] = nil
        end,
        GetAllBoundActionInfo = function()
            logAPICall("method_call", "ContextActionService:GetAllBoundActionInfo()")
            local out = {}
            for key in pairs(boundActions) do
                out[key] = {title = key}
            end
            return out
        end,
    })
    serviceResolvers.ContextActionService = function()
        return contextActionService
    end
    env.ContextActionService = contextActionService

    local collectionService = makeRobloxProxy("CollectionService", "CollectionService", {
        AddTag = function(_, instance, tag)
            logAPICall("method_call", string.format("CollectionService:AddTag(%s)", formatValue(tag)))
            if type(instance) == "table" then
                local tags = collectionTagStore[instance]
                if not tags then
                    tags = {}
                    collectionTagStore[instance] = tags
                end
                tags[tostring(tag)] = true
            end
        end,
        RemoveTag = function(_, instance, tag)
            logAPICall("method_call", string.format("CollectionService:RemoveTag(%s)", formatValue(tag)))
            local tags = collectionTagStore[instance]
            if tags then
                tags[tostring(tag)] = nil
            end
        end,
        HasTag = function(_, instance, tag)
            local tags = collectionTagStore[instance]
            return tags and tags[tostring(tag)] == true or false
        end,
        GetTags = function(_, instance)
            logAPICall("method_call", "CollectionService:GetTags(...)")
            local out = {}
            local tags = collectionTagStore[instance]
            if tags then
                for tag in pairs(tags) do
                    table.insert(out, tag)
                end
            end
            table.sort(out)
            return out
        end,
        GetTagged = function(_, tag)
            logAPICall("method_call", string.format("CollectionService:GetTagged(%s)", formatValue(tag)))
            local out = {}
            local wanted = tostring(tag)
            for instance, tags in pairs(collectionTagStore) do
                if tags[wanted] then
                    table.insert(out, instance)
                end
            end
            return out
        end,
    })
    serviceResolvers.CollectionService = function()
        return collectionService
    end
    env.CollectionService = collectionService

    local logService = makeRobloxProxy("LogService", "LogService", {
        MessageOut = makeSignal("LogService.MessageOut"),
        GetLogHistory = function()
            logAPICall("method_call", "LogService:GetLogHistory()")
            return {}
        end,
    })
    serviceResolvers.LogService = function()
        return logService
    end
    env.LogService = logService

    local teamsService = makeRobloxProxy("Teams", "Teams", {
        GetTeams = function()
            logAPICall("method_call", "Teams:GetTeams()")
            return {}
        end,
    })
    serviceResolvers.Teams = function()
        return teamsService
    end
    env.Teams = teamsService

    local statsService = makeRobloxProxy("Stats", "Stats", {
        ContactsCount = 0,
        DataSendKbps = 0,
        DataReceiveKbps = 0,
        FrameTime = 0,
        HeartbeatTime = 0,
        HeartbeatTimeMs = 0,
        InstanceCount = 0,
        MemoryTrackingEnabled = false,
        MovingPrimitivesCount = 0,
        PhysicsReceiveKbps = 0,
        PhysicsSendKbps = 0,
        PhysicsStepTime = 0,
        PhysicsStepTimeMs = 0,
        PrimitivesCount = 0,
        RenderCPUFrameTime = 0,
        RenderGPUFrameTime = 0,
        SceneDrawcallCount = 0,
        SceneTriangleCount = 0,
        ShadowsDrawcallCount = 0,
        ShadowsTriangleCount = 0,
        UI2DDrawcallCount = 0,
        UI2DTriangleCount = 0,
    })
    serviceResolvers.Stats = function()
        return statsService
    end
    env.Stats = statsService

    local starterPlayerService = makeRobloxProxy("StarterPlayer", "StarterPlayer", {
        Name = "StarterPlayer",
        ClassName = "StarterPlayer",
        StarterPlayerScripts = makeRobloxProxy("StarterPlayer.StarterPlayerScripts", "StarterPlayerScripts", {
            Name = "StarterPlayerScripts",
            ClassName = "StarterPlayerScripts",
        }),
        StarterCharacterScripts = makeRobloxProxy("StarterPlayer.StarterCharacterScripts", "StarterCharacterScripts", {
            Name = "StarterCharacterScripts",
            ClassName = "StarterCharacterScripts",
        }),
    })
    serviceResolvers.StarterPlayer = function()
        return starterPlayerService
    end
    env.StarterPlayer = starterPlayerService

    local starterPackService = makeRobloxProxy("StarterPack", "StarterPack", {
        Name = "StarterPack",
        ClassName = "StarterPack",
    })
    serviceResolvers.StarterPack = function()
        return starterPackService
    end
    env.StarterPack = starterPackService

    local settingsObject = makeRobloxProxy("settings", "GlobalSettings", {
        Name = "GlobalSettings",
        ClassName = "GlobalSettings",
    })
    env.settings = function()
        logAPICall("function_call", "settings()")
        return settingsObject
    end
    env.UserSettings = env.settings
    env.elapsedTime = function()
        logAPICall("function_call", "elapsedTime()")
        return os.clock()
    end

    env.workspace = workspaceService
    env.Workspace = workspaceService
    env.script = createProxy("script", "Script")

    local waitCallCount = 0
    local lastWaitTime = os.clock()
    local realClock = os.clock
    local clockOrigin = realClock()
    local virtualClock = 0
    local taskQueue: {{thread: thread, due: number, order: number, args: {any}?}} = {}
    local managedThreads = setmetatable({}, {__mode = "k"})
    local proxyFinalizers: {any} = {}
    local cclosureRegistry = setmetatable({}, {__mode = "k"})
    local executorClosureRegistry = setmetatable({}, {__mode = "k"})
    local hookRegistry = setmetatable({}, {__mode = "k"})
    local metamethodHooks = setmetatable({}, {__mode = "k"})
    local namecallMethod = ""
    local taskOrder = 0
    if env.Random and type(env.Random.new) == "function" then
        cclosureRegistry[env.Random.new] = true
    end
    if env.CFrame then
        for _, value in pairs(env.CFrame) do
            if type(value) == "function" then
                cclosureRegistry[value] = true
            end
        end
    end
    if type(tweenService) == "table" and type(tweenService.Create) == "function" then
        cclosureRegistry[tweenService.Create] = true
    end
    if env.PhysicalProperties and type(env.PhysicalProperties.new) == "function" then
        cclosureRegistry[env.PhysicalProperties.new] = true
    end
    if env.vector then
        for _, value in pairs(env.vector) do
            if type(value) == "function" then
                cclosureRegistry[value] = true
            end
        end
    end

    local function monotonicClock(): number
        return virtualClock + math.max(0, realClock() - clockOrigin)
    end

    local function findLinkedChild(parent: any, name: string): any
        local linked = type(parent) == "table" and instanceChildren[parent] or nil
        if linked then
            for child in pairs(linked) do
                if type(child) == "table" and rawget(child, "Name") == name then
                    return child
                end
            end
        end
        return nil
    end

    local function stepWorld(delta: number)
        local dt = math.max(tonumber(delta) or 0.03, 0.03)
        local gravity = tonumber(rawget(workspaceService, "Gravity")) or 196.2
        local stepped = setmetatable({}, {__mode = "k"})
        local function stepPart(instance)
            if type(instance) ~= "table" or stepped[instance] then
                return
            end
            stepped[instance] = true
            local className = proxyTypeNames[instance] or rawget(instance, "ClassName")
            if (className == "Part" or className == "BasePart" or className == "MeshPart") and rawget(instance, "Anchored") ~= true then
                local position = rawget(instance, "Position") or vectorValue("Vector3", 0, 0, 0)
                local velocity = rawget(instance, "Velocity") or rawget(instance, "AssemblyLinearVelocity") or vectorValue("Vector3", 0, 0, 0)
                local nextVelocity = velocity
                if objectTypeNames[velocity] == "Vector3" then
                    nextVelocity = vectorValue("Vector3", velocity.X or 0, (velocity.Y or 0) - gravity * dt, velocity.Z or 0)
                    rawset(instance, "Velocity", nextVelocity)
                    rawset(instance, "AssemblyLinearVelocity", nextVelocity)
                end
                if objectTypeNames[position] == "Vector3" then
                    rawset(instance, "Position", vectorValue("Vector3", position.X or 0, (position.Y or 0) + ((nextVelocity and nextVelocity.Y) or -gravity) * dt * 0.1, position.Z or 0))
                end
            end
        end
        local function walk(root)
            local linked = instanceChildren[root]
            if not linked then
                return
            end
            for instance in pairs(linked) do
                stepPart(instance)
                walk(instance)
            end
        end
        walk(workspaceService)

        for instance, className in pairs(proxyTypeNames) do
            if className == "Humanoid" and (rawget(instance, "Jump") == true or enumItemName(rawget(instance, "State")) == "Jumping") then
                local parent = rawget(instance, "Parent")
                local rootPart = findLinkedChild(parent, "HumanoidRootPart")
                if type(rootPart) == "table" then
                    local position = rawget(rootPart, "Position") or vectorValue("Vector3", 0, 0, 0)
                    if objectTypeNames[position] == "Vector3" then
                        rawset(rootPart, "Position", vectorValue("Vector3", position.X or 0, (position.Y or 0) + 5, position.Z or 0))
                    end
                end
            end
        end
    end
    signalStepWorld = stepWorld

    local function scheduleThread(threadRef: thread, delay: number?, args: {any}?)
        taskOrder += 1
        table.insert(taskQueue, {
            thread = threadRef,
            due = virtualClock + math.max(0, tonumber(delay) or 0),
            order = taskOrder,
            args = args,
        })
    end

    local function resumeScheduledThread(threadRef: thread, ...: any)
        if coroutine.status(threadRef) == "dead" then
            return
        end

        managedThreads[threadRef] = true
        local ok, delayOrResult = coroutine.resume(threadRef, ...)
        if not ok then
            logAPICall("function_call", string.format("task thread error: %s", normalizeProtectedError(delayOrResult)))
            return
        end

        if coroutine.status(threadRef) ~= "dead" then
            scheduleThread(threadRef, tonumber(delayOrResult) or 0)
        end
    end

    local function popNextTask(deadline: number): any?
        local bestIndex = nil
        local bestDue = nil
        local bestOrder = nil

        for i, item in ipairs(taskQueue) do
            if item.due <= deadline and (not bestDue or item.due < bestDue or (item.due == bestDue and item.order < bestOrder)) then
                bestIndex = i
                bestDue = item.due
                bestOrder = item.order
            end
        end

        if not bestIndex then
            return nil
        end

        local item = table.remove(taskQueue, bestIndex)
        virtualClock = math.max(virtualClock, item.due)
        return item
    end

    local function pumpTasks(duration: number?)
        local step = tonumber(duration)
        if not step or step <= 0 then
            step = 0.03
        end

        local deadline = virtualClock + step
        local guard = 0
        while guard < 10000 do
            local item = popNextTask(deadline)
            if not item then
                break
            end
            guard += 1
            local args = item.args
            if args then
                resumeScheduledThread(item.thread, table.unpack(args, 1, args.n or #args))
            else
                resumeScheduledThread(item.thread)
            end
        end

        virtualClock = math.max(virtualClock, deadline)
        stepWorld(step)
        return step
    end
    waitForChildPumpTasks = pumpTasks

    local function runTask(callback: any, deferred: boolean?, delay: number?, ...: any): thread?
        local args = table.pack(...)
        local threadRef
        if type(callback) == "thread" then
            threadRef = callback
        elseif type(callback) == "function" then
            threadRef = coroutine.create(callback)
        elseif type(callback) == "table" then
            local mt = getmetatable(callback)
            if type(mt) == "table" and type(mt.__call) == "function" then
                threadRef = coroutine.create(function(...)
                    return callback(...)
                end)
            end
        else
            return nil
        end

        managedThreads[threadRef] = true
        if deferred or (delay and delay > 0) then
            scheduleThread(threadRef, delay or 0.03, args)
        else
            resumeScheduledThread(threadRef, table.unpack(args, 1, args.n))
        end

        return threadRef
    end

    local function makeTaskHandle(threadRef: thread?): any
        if not threadRef then
            return nil
        end
        return function()
            logAPICall("function_call", "task thread handle invoked")
            return true
        end
    end

    local function trackedWait(duration: number?, label: string)
        if duration ~= nil and type(duration) ~= "number" then
            error("number expected", 2)
        end
        local d = tonumber(duration) or 0
        logAPICall("function_call", string.format("%s(%s)", label, formatValue(d)))

        local currentTime = monotonicClock()
        if currentTime - lastWaitTime < 0.1 then
            waitCallCount += 1
            if waitCallCount > 1000 then
                error("scheduler wait limit exceeded", 2)
            end
        else
            waitCallCount = 0
        end
        lastWaitTime = currentTime

        local currentThread = coroutine.running()
        if currentThread and managedThreads[currentThread] then
            return coroutine.yield(d)
        end

        return pumpTasks(d)
    end

    env.wait = function(duration: number?)
        local elapsed = trackedWait(duration, "wait")
        return elapsed, monotonicClock()
    end

    env.delay = function(duration: number, callback: any, ...: any)
        logAPICall("function_call", string.format("delay(%s, function(...) end)", formatValue(duration)))
        return runTask(callback, true, duration, ...)
    end

    env.spawn = function(callback: any, ...: any)
        logAPICall("function_call", "spawn(function(...) end)")
        return runTask(callback, false, nil, ...)
    end

    env.tick = function()
        logAPICall("function_call", "tick()")
        return monotonicClock()
    end

    env.time = function()
        logAPICall("function_call", "time()")
        return math.max(monotonicClock(), signalClock)
    end


    env.identifyexecutor = function()
        logAPICall("function_call", "identifyexecutor()")
        return "Roblox", "1.0.0"
    end

    env.printidentity = function()
        logAPICall("function_call", "printidentity()")
        return "Current identity is 8"
    end

    env.getidentity = function()
        logAPICall("function_call", "getidentity()")
        return 8
    end

    env.getthreadidentity = function()
        logAPICall("function_call", "getthreadidentity()")
        return 8
    end

    env.setidentity = function(level)
        logAPICall("function_call", string.format("setidentity(%s)", formatValue(level)))
    end

    env.setthreadidentity = function(level)
        logAPICall("function_call", string.format("setthreadidentity(%s)", formatValue(level)))
    end

    env.readfile = function(path)
        logAPICall("security_block", string.format("readfile(%s)", formatValue(path)))
        return nil
    end

    env.writefile = function(path, content)
        logAPICall("security_block", string.format("writefile(%s, ...)", formatValue(path)))
    end

    env.isfile = function(path)
        logAPICall("security_block", string.format("isfile(%s)", formatValue(path)))
        return false
    end

    env.isfolder = function(path)
        logAPICall("security_block", string.format("isfolder(%s)", formatValue(path)))
        return false
    end

    env.listfiles = function(path)
        logAPICall("security_block", string.format("listfiles(%s)", formatValue(path)))
        return {}
    end

    env.request = function(options)
        logAPICall("security_block", "request(...)")
        return nil
    end

    env.http_request = function(options)
        logAPICall("security_block", "http_request(...)")
        return nil
    end

    env.setclipboard = function(text)
        recordClipboardValue(text)
        logAPICall("function_call", string.format("setclipboard(%s)", formatValue(text)))
    end

    env.Drawing = {
        Fonts = {
            UI = 0,
            System = 1,
            Plex = 2,
            Monospace = 3,
        },
        new = function(className)
            local valueId = string.format("Drawing.new(%s)", formatValue(className))
            logAPICall("constructor", valueId)
            return createProxy(valueId, "Drawing")
        end,
    }

    env.WebSocket = nil

    env.task = {
        wait = function(duration: number?)
            return trackedWait(duration, "task.wait")
        end,
        spawn = function(callback: any, ...: any)
            logAPICall("function_call", "task.spawn(function(...) end)")
            if type(callback) ~= "function" and type(callback) ~= "thread" then
                local mt = type(callback) == "table" and getmetatable(callback) or nil
                if type(mt) ~= "table" or type(mt.__call) ~= "function" then
                    error("function or thread expected", 2)
                end
            end
            return runTask(callback, false, nil, ...)
        end,
        defer = function(callback: any, ...: any)
            logAPICall("function_call", "task.defer(function(...) end)")
            return runTask(callback, true, 0.03, ...)
        end,
        delay = function(duration: number, callback: any, ...: any)
            logAPICall("function_call", string.format("task.delay(%s, function(...) end)", formatValue(duration)))
            return runTask(callback, true, duration, ...)
        end,
        cancel = function(threadRef)
            if threadRef == nil then
                error("missing argument #1", 2)
            end
            logAPICall("function_call", "task.cancel(thread)")
            for index = #taskQueue, 1, -1 do
                if taskQueue[index].thread == threadRef then
                    table.remove(taskQueue, index)
                end
            end
            if type(threadRef) == "thread" and coroutine.close then
                pcall(coroutine.close, threadRef)
            end
        end,
    }
    cclosureRegistry[env.task.wait] = true
    cclosureRegistry[env.task.spawn] = true
    cclosureRegistry[env.task.defer] = true
    cclosureRegistry[env.task.delay] = true
    cclosureRegistry[env.task.cancel] = true

    local realPrint = print
    local realWarn = warn or print

    local printCount = 0
    local warnCount = 0
    local lastPrintMessage = nil
    local printRepeatCount = 0
    local MAX_PRINT_CALLS = math.max(100, math.floor(tonumber(process.env.ENV2_PRINT_LIMIT or "") or 5000))
    local MAX_WARN_CALLS = math.max(100, math.floor(tonumber(process.env.ENV2_WARN_LIMIT or "") or 5000))
    local MAX_REPEAT_PRINTS = math.max(3, math.floor(tonumber(process.env.ENV2_REPEAT_PRINT_LIMIT or "") or 25))

    env.print = function(...: any)
        local args = {...}
        local strs: {string} = {}
        local rawStrs: {string} = {}
        for _, v in ipairs(args) do
            table.insert(strs, formatValue(v))
            table.insert(rawStrs, safeToString(v))
        end

        local message = table.concat(strs, " ")
        local rawMessage = table.concat(rawStrs, " ")
        recordReportValue(rawMessage)

        printCount += 1
        if printCount > MAX_PRINT_CALLS then
            logAPICall("security_block", "Blocked excessive print calls")
            return nil
        end

        if message == lastPrintMessage then
            printRepeatCount += 1
            if printRepeatCount > MAX_REPEAT_PRINTS then
                logAPICall("security_block", string.format("Blocked repeated print: %s", message:sub(1, 30)))
                return nil
            end
        else
            lastPrintMessage = message
            printRepeatCount = 0
        end

        if message:match("dtc") or message:match("detected") or message:match("join") then
            logAPICall("security_block", string.format("Blocked anti-dumper print: %s", message:sub(1, 50)))
            return
        end

        logAPICall("function_call", string.format("print(%s)", table.concat(strs, ", ")))
        realPrint(...)
    end

    env.warn = function(...: any)
        local args = {...}
        local strs: {string} = {}
        local rawStrs: {string} = {}
        for _, v in ipairs(args) do
            table.insert(strs, formatValue(v))
            table.insert(rawStrs, safeToString(v))
        end

        local message = table.concat(strs, " ")
        recordReportValue(table.concat(rawStrs, " "))

        warnCount += 1
        if warnCount > MAX_WARN_CALLS then
            logAPICall("security_block", "Blocked excessive warn calls")
            return nil
        end

        if message:match("dtc") or message:match("detected") or message:match("join") or message:match("%.gg/") or message:match("should join") then
            logAPICall("security_block", string.format("Blocked anti-dumper warning: %s", message:sub(1, 50)))
            return nil
        end

        logAPICall("function_call", string.format("warn(%s)", table.concat(strs, ", ")))
        realWarn(...)
    end

    local realError = error
    env.error = function(message, level)
        local msg = normalizeProtectedError(tostring(message))
        local lowerMsg = msg:lower()
        if prometheusPcallCompat and lowerMsg:find("tamper detected", 1, true) then
            logAPICall("security_block", "Prometheus anti-tamper branch blocked")
            realError("too many operations", 0)
        end
        if lowerMsg:match("dtc") or (lowerMsg:match("detected") and not lowerMsg:find("tamper detected", 1, true)) or lowerMsg:match("join") then
            logAPICall("security_block", string.format("Blocked anti-dumper error: %s", msg:sub(1, 50)))
            return
        end

        msg = msg:gsub("C:\\[^:]+:", "Script:")
        msg = msg:gsub("/[^:]+:", "Script:")
        msg = msg:gsub("%[string \"[^\"]+\"%]", "[Script]")
        msg = msg:gsub("temp\\[^:]+:", "Script:")

        logAPICall("function_call", string.format("error(%s, %s)", formatValue(msg:sub(1, 100)), formatValue(level)))

        if level == 0 then
            realError(msg, 0)
        end
        if msg == "" then
            realError('[string "script"]:1: ', 0)
        end

        realError(msg, (level or 1) + 1)
    end

    env.typeof = function(v)
        logAPICall("function_call", string.format("typeof(%s)", formatValue(v)))
        return typeof(v)
    end

    local function requestUrl(options: any): string?
        return getUrlFromOptions(options)
    end

    local function fakeHttpResponse(label: string, options: any)
        local url = requestUrl(options)
        if url then
            recordStaticHint("url", url, true)
        end
        logAPICall("http_request", string.format("%s(%s)", label, formatValue(options)))
        return {
            Success = true,
            StatusCode = 200,
            StatusMessage = "OK",
            Body = remoteBody(label, {url or label}),
            Headers = {},
        }
    end

    local function fakeBytecode(label: string, source: any): string
        logAPICall("function_call", string.format("%s(%s)", label, formatValue(source):sub(1, 80)))
        local payload = type(source) == "string" and source or tostring(source or "")
        return "\27Luau\0" .. payload
    end

    local function inertExecutorFunction(name: string, returns: any?)
        return function(...: any)
            local args = {...}
            local argStrs: {string} = {}
            for i, value in ipairs(args) do
                if i > 4 then
                    table.insert(argStrs, "...")
                    break
                end
                table.insert(argStrs, formatValue(value))
            end
            logAPICall("function_call", string.format("%s(%s)", name, table.concat(argStrs, ", ")))
            if returns ~= nil then
                return returns
            end
            return nil
        end
    end

    env.compile = function(source: any, options: any?)
        logAPICall("function_call", string.format("compile(%s, %s)", formatValue(source):sub(1, 80), formatValue(options)))
        return fakeBytecode("compile.bytecode", source)
    end
    env.getscriptbytecode = function(scriptRef: any)
        return fakeBytecode("getscriptbytecode", scriptRef)
    end
    env.dumpstring = function(source: any)
        return fakeBytecode("dumpstring", source)
    end
    env.decompile = function(target: any)
        logAPICall("function_call", string.format("decompile(%s)", formatValue(target)))
        return "-- decompile unavailable in sandbox"
    end

    env.getgc = function(includeTables: boolean?)
        logAPICall("function_call", string.format("getgc(%s)", formatValue(includeTables)))
        return {}
    end
    env.getinstances = function()
        logAPICall("function_call", "getinstances()")
        return {}
    end
    env.getnilinstances = function()
        logAPICall("function_call", "getnilinstances()")
        return {}
    end
    env.getloadedmodules = function()
        logAPICall("function_call", "getloadedmodules()")
        return {}
    end
    env.getscripts = function()
        logAPICall("function_call", "getscripts()")
        return {}
    end
    env.getrunningscripts = function()
        logAPICall("function_call", "getrunningscripts()")
        return {}
    end
    env.getconnections = function(signal: any)
        logAPICall("function_call", string.format("getconnections(%s)", formatValue(signal)))
        return {}
    end
    env.firesignal = inertExecutorFunction("firesignal")
    env.fireclickdetector = inertExecutorFunction("fireclickdetector")
    env.firetouchinterest = inertExecutorFunction("firetouchinterest")
    env.fireproximityprompt = inertExecutorFunction("fireproximityprompt")

    env.gethui = function()
        logAPICall("function_call", "gethui()")
        return createProxy("CoreGui", "CoreGui")
    end
    env.gethiddenproperty = function(object: any, property: any)
        logAPICall("function_call", string.format("gethiddenproperty(%s, %s)", formatValue(object), formatValue(property)))
        return nil, false
    end
    env.sethiddenproperty = function(object: any, property: any, value: any)
        logAPICall("function_call", string.format("sethiddenproperty(%s, %s, %s)", formatValue(object), formatValue(property), formatValue(value)))
        return true
    end
    env.getcallbackvalue = function(object: any, property: any)
        logAPICall("function_call", string.format("getcallbackvalue(%s, %s)", formatValue(object), formatValue(property)))
        return nil
    end
    env.getcustomasset = function(path: any)
        logAPICall("security_block", string.format("getcustomasset(%s)", formatValue(path)))
        return "rbxasset://env2"
    end
    env.queue_on_teleport = inertExecutorFunction("queue_on_teleport")
    env.queueonteleport = env.queue_on_teleport
    env.setfpscap = inertExecutorFunction("setfpscap")
    env.getfpscap = inertExecutorFunction("getfpscap", 60)
    env.isrbxactive = inertExecutorFunction("isrbxactive", true)
    env.isgameactive = inertExecutorFunction("isgameactive", true)
    env.compareinstances = function(a: any, b: any)
        logAPICall("function_call", string.format("compareinstances(%s, %s)", formatValue(a), formatValue(b)))
        return a == b
    end
    env.isnetworkowner = inertExecutorFunction("isnetworkowner", true)

    env.request = function(options)
        return fakeHttpResponse("request", options)
    end
    env.http_request = function(options)
        return fakeHttpResponse("http_request", options)
    end

    local function passthroughCodec(label: string, value: any): string
        logAPICall("function_call", string.format("%s(...)", label))
        return type(value) == "string" and value or tostring(value or "")
    end

    env.lz4compress = function(value: any)
        return passthroughCodec("lz4compress", value)
    end
    env.lz4decompress = function(value: any)
        return passthroughCodec("lz4decompress", value)
    end

    env.WebSocket = {
        connect = function(url: any)
            logAPICall("security_block", string.format("WebSocket.connect(%s)", formatValue(url)))
            return createProxy("WebSocket(" .. safeToString(url) .. ")", "WebSocket")
        end,
    }

    env.crypt = env.crypt or {}
    env.crypt.base64 = env.crypt.base64 or {}
    env.crypt.base64.encode = function(value: any)
        return passthroughCodec("crypt.base64.encode", value)
    end
    env.crypt.base64.decode = function(value: any)
        return passthroughCodec("crypt.base64.decode", value)
    end
    env.crypt.base64encode = env.crypt.base64.encode
    env.crypt.base64decode = env.crypt.base64.decode
    env.base64encode = env.crypt.base64.encode
    env.base64decode = env.crypt.base64.decode
    env.crypt.encrypt = function(value: any, key: any, iv: any, mode: any)
        logAPICall("function_call", string.format("crypt.encrypt(..., %s, %s, %s)", formatValue(key), formatValue(iv), formatValue(mode)))
        return passthroughCodec("crypt.encrypt", value)
    end
    env.crypt.decrypt = function(value: any, key: any, iv: any, mode: any)
        logAPICall("function_call", string.format("crypt.decrypt(..., %s, %s, %s)", formatValue(key), formatValue(iv), formatValue(mode)))
        return passthroughCodec("crypt.decrypt", value)
    end
    env.crypt.generatebytes = function(count: any)
        local n = math.floor(math.max(0, math.min(1024, tonumber(count) or 16)))
        logAPICall("function_call", string.format("crypt.generatebytes(%d)", n))
        return string.rep("\0", n)
    end
    env.crypt.generatekey = function()
        logAPICall("function_call", "crypt.generatekey()")
        return string.rep("0", 32)
    end
    env.crypt.hash = function(value: any, algorithm: any)
        logAPICall("function_call", string.format("crypt.hash(..., %s)", formatValue(algorithm)))
        return string.rep("0", 64)
    end

    local realGetfenv = getfenv
    local realSetfenv = setfenv

    local cachedFenv = {}
    local function syncCachedFenv()
        local dangerousKeys = {
            package = true, io = true, require = true, loadfile = true, dofile = true,
            _fs = true, _process = true, _require = true, _luau = true, _stdio = true,
            version = true, _ = true, fenv = true,
        }
        for k, v in pairs(env) do
            if not dangerousKeys[k] then
                rawset(cachedFenv, k, v)
            end
        end
        rawset(cachedFenv, "version", false)
        rawset(cachedFenv, "_", nil)
        rawset(cachedFenv, "fenv", nil)
        rawset(cachedFenv, "_G", cachedFenv)
        rawset(cachedFenv, "_ENV", cachedFenv)
    end
    for k, v in pairs(env) do
        local isDangerous = false
        local dangerousKeys = {"package", "io", "require", "loadfile", "dofile", "_fs", "_process", "_require", "_luau", "_stdio", "version", "_", "fenv"}
        for _, dangerous in ipairs(dangerousKeys) do
            if k == dangerous then
                isDangerous = true
                break
            end
        end
        if not isDangerous then
            cachedFenv[k] = v
        end
    end
    cachedFenv.version = false
    cachedFenv._ = nil
    cachedFenv.fenv = nil
    cachedFenv._G = cachedFenv
    cachedFenv._ENV = cachedFenv

    env.getfenv = function(level)
        local levelStr = formatValue(level or 1)
        table.insert(getfenvCalls, {level = level, result = "public_env"})
        logAPICall("function_call", string.format("getfenv(%s)", levelStr))

        syncCachedFenv()
        return cachedFenv
    end

    env.setfenv = function(fn, envTable)
        local funcStr = type(fn) == "function" and "function" or formatValue(fn)
        local envStr = type(envTable) == "table" and "env_table" or formatValue(envTable)
        table.insert(setfenvCalls, {func = funcStr, env = envStr})
        logAPICall("function_call", string.format("setfenv(%s, %s)", funcStr, envStr))

        if type(fn) == "number" then
            return fn
        elseif type(fn) == "function" then
            if type(envTable) == "table" then
                local merged = setmetatable({}, {
                    __index = function(t, k)
                        local v = rawget(envTable, k)
                        if v ~= nil then return v end
                        return env[k]
                    end,
                    __newindex = function(t, k, v)
                        rawset(envTable, k, v)
                    end
                })
                return fn
            end
            return fn
        end
        return fn
    end

    local realPcall = pcall
    env.pcall = function(func, ...)
        pcallCount += 1
        logAPICall("function_call", "pcall(function)")

        local success, result = realPcall(func, ...)

        if not success then
            local errorMsg = tostring(result)

            errorMsg = errorMsg:gsub("[A-Za-z]:\\[^:]+:", "")
            errorMsg = errorMsg:gsub("/[^:]+:", "")
            errorMsg = errorMsg:gsub("\\\\%?\\[^:]+:", "")
            errorMsg = errorMsg:gsub("%[string \"[^\"]+\"%]", "[string \"Script\"]")
            errorMsg = errorMsg:gsub("temp\\[^:]+:", "")
            errorMsg = errorMsg:gsub("temp/[^:]+:", "")

            logAPICall("function_call", string.format("pcall error: %s", errorMsg:sub(1, 100)))

            return success, errorMsg:gsub("^%s*", "")
        end

        return success, result
    end
    env.ypcall = env.pcall

    env.os = setmetatable({}, {
        __index = function(t, k)
            if k == "getenv" then
                return function(varname)
                    logAPICall("function_call", string.format("os.getenv(%s)", formatValue(varname)))
                    local fakeEnv = {
                        HOME = "[HOME]",
                        USERPROFILE = "[HOME]",
                        TEMP = "[TEMP]",
                        TMP = "[TEMP]",
                        USERNAME = "[USER]",
                        USER = "[USER]",
                        PATH = "[PATH]",
                        APPDATA = "[APPDATA]",
                        LOCALAPPDATA = "[LOCALAPPDATA]"
                    }
                    return fakeEnv[varname] or nil
                end
            elseif k == "time" or k == "clock" or k == "date" or k == "difftime" then
                return function(...)
                    logAPICall("function_call", string.format("os.%s(...)", k))
                    return os[k](...)
                end
            else
                logAPICall("security_block", string.format("os.%s", k))
                return nil
            end
        end,
        __metatable = "locked"
    })

    env.debug = setmetatable({}, {
        __index = function(t, k)
            if k == "getregistry" then
                return function()
                    logAPICall("security_block", "debug.getregistry()")
                    return {}
                end
            elseif k == "getinfo" then
                return function(func, what)
                    logAPICall("function_call", string.format("debug.getinfo(function, %s)", formatValue(what)))
                    local info = debug.getinfo(func, what or "nSluf")
                    if info and info.source then
                        info.source = info.source:gsub("[A-Za-z]:\\[^:]+", "[Script]")
                        info.source = info.source:gsub("/[^:]+", "[Script]")
                    end
                    return info
                end
            else
                logAPICall("security_block", string.format("debug.%s", k))
                return nil
            end
        end,
        __metatable = "locked"
    })

    env.io = setmetatable({}, {
        __index = function(t, k)
            if k == "open" or k == "read" or k == "write" or k == "close" then
                return function(...)
                    logAPICall("security_block", string.format("io.%s(...)", k))
                    return nil, "Access denied"
                end
            else
                logAPICall("security_block", string.format("io.%s", k))
                return nil
            end
        end,
        __metatable = "locked"
    })

    env.package = setmetatable({}, {
        __index = function(t, k)
            if k == "loaded" then
                logAPICall("security_block", "package.loaded")
                return {}
            else
                logAPICall("security_block", string.format("package.%s", k))
                return nil
            end
        end,
        __metatable = "locked"
    })

    env.coroutine = setmetatable({}, {
        __index = function(t, k)
            if k == "create" or k == "wrap" then
                return function(func)
                    logAPICall("function_call", string.format("coroutine.%s(function)", k))
                    return coroutine[k](function(...)
                        return func(...)
                    end)
                end
            elseif k == "resume" or k == "yield" or k == "status" or k == "running" then
                return function(...)
                    logAPICall("function_call", string.format("coroutine.%s(...)", k))
                    return coroutine[k](...)
                end
            else
                logAPICall("security_block", string.format("coroutine.%s", k))
                return nil
            end
        end,
        __metatable = "locked"
    })

    local realXpcall = xpcall
    env.xpcall = function(func, msgh, ...)
        logAPICall("function_call", "xpcall(function, handler)")
        local success, result = realXpcall(func, msgh, ...)

        if not success then
            local errorMsg = tostring(result)
            errorMsg = errorMsg:gsub("[A-Za-z]:\\[^:]+:", "Script:")
            errorMsg = errorMsg:gsub("/[^:]+:", "Script:")
            errorMsg = errorMsg:gsub("\\\\%?\\[^:]+:", "Script:")
            errorMsg = errorMsg:gsub("%[string \"[^\"]+\"%]", "[Script]")
            errorMsg = errorMsg:gsub("temp\\[^:]+:", "Script:")
            errorMsg = errorMsg:gsub("temp/[^:]+:", "Script:")
            errorMsg = errorMsg:gsub("[\u{FF0F}\u{FF3A}][^:]+:", "Script:")
            errorMsg = errorMsg:gsub("%z", "")
            return success, errorMsg
        end

        return success, result
    end

    env.type = type
    env.tostring = tostring
    env.tonumber = tonumber
    env.pairs = pairs
    env.ipairs = ipairs
    env.next = next
    env.select = select

    local realGetmetatable = getmetatable
    local realSetmetatable = setmetatable
    local realRawequal = rawequal

    local scriptMetatables = setmetatable({}, {__mode = "k"})
    local readonlyTables = setmetatable({}, {__mode = "k"})

    env.setmetatable = function(obj, mt)
        logAPICall("function_call", "setmetatable(object, metatable)")

        if type(obj) ~= "table" then
            error(string.format("invalid argument #1 to 'setmetatable' (table expected, got %s)", type(obj)), 2)
        end
        if mt ~= nil and type(mt) ~= "table" then
            error(string.format("invalid argument #2 to 'setmetatable' (nil or table expected, got %s)", type(mt)), 2)
        end

        local existingMt = scriptMetatables[obj]
        if type(existingMt) == "table" and existingMt.__metatable ~= nil then
            error("cannot change a protected metatable", 2)
        end

        scriptMetatables[obj] = mt

        pcall(realSetmetatable, obj, mt)

        return obj
    end

    env.setreadonly = function(obj, readonly)
        logAPICall("function_call", string.format("setreadonly(object, %s)", formatValue(readonly)))
        if type(obj) == "table" then
            readonlyTables[obj] = readonly ~= false
        end
        return obj
    end
    env.make_readonly = function(obj)
        return env.setreadonly(obj, true)
    end
    env.make_writeable = function(obj)
        return env.setreadonly(obj, false)
    end
    env.make_writable = env.make_writeable
    env.isreadonly = function(obj)
        logAPICall("function_call", "isreadonly(object)")
        if type(obj) ~= "table" then
            return false
        end
        if readonlyTables[obj] == true then
            return true
        end
        if table.isfrozen then
            local ok, frozen = pcall(table.isfrozen, obj)
            if ok and frozen == true then
                return true
            end
        end
        return false
    end
    env.is_readonly = env.isreadonly

    env.getmetatable = function(...: any)
        if select("#", ...) == 0 then
            error("missing argument #1", 2)
        end
        local obj = ...
        logAPICall("function_call", "getmetatable(object)")

        if scriptMetatables[obj] ~= nil then
            local mt = scriptMetatables[obj]
            if type(mt) == "table" and mt.__metatable ~= nil then
                return mt.__metatable
            end
            return mt
        end

        if obj == env._G then
            return nil
        end

        if proxyRegistry[obj] then
            local proxyTypeName = proxyTypeNames[obj] or ""
            if proxyTypeName == "DataModel"
                or proxyTypeName == "Workspace"
                or proxyTypeName == "Players"
                or proxyTypeName == "RunService"
                or proxyTypeName == "RBXScriptSignal"
                or proxyTypeName == "RBXScriptConnection"
                or proxyTypeName == "Enum"
                or proxyTypeName == "EnumType"
                or proxyTypeName:match("^[A-Z]") then
                return "The metatable is locked"
            end
            return nil
        end

        local success, mt = pcall(realGetmetatable, obj)
        if not success then
            return nil
        end

        return mt
    end

    env.rawget = function(tbl: any, key: any): any
        logAPICall("function_call", string.format("rawget(%s, %s)", formatValue(tbl), formatValue(key)))
        if type(tbl) ~= "table" then
            error(string.format("bad argument #1 to 'rawget' (table expected, got %s)", type(tbl)), 2)
        end
        return rawget(tbl, key)
    end
    env.rawset = function(tbl: any, key: any, value: any): any
        if tbl == _G or tbl == env then
            if value == nil then
                logAPICall("security_block", string.format("Blocked rawset(_G, %s, nil)", formatValue(key)))
                error("Anti-dumper protection: Cannot clear _G globals", 2)
            end
        end
        if type(tbl) ~= "table" then
            error(string.format("bad argument #1 to 'rawset' (table expected, got %s)", type(tbl)), 2)
        end
        logAPICall("function_call", string.format("rawset(%s, %s, %s)", formatValue(tbl), formatValue(key), formatValue(value)))
        return rawset(tbl, key, value)
    end

    env.rawequal = function(a, b)
        logAPICall("function_call", string.format("rawequal(%s, %s)", formatValue(a), formatValue(b)))

        local aIsTracked = scriptMetatables[a] ~= nil or (type(a) == "table" and scriptMetatables[a] == a)
        local bIsTracked = scriptMetatables[b] ~= nil or (type(b) == "table" and scriptMetatables[b] == b)

        return realRawequal(a, b)
    end

    env.rawlen = rawlen
    env.assert = assert


    local originalFunctions = {
        print = print,
        warn = warn,
        error = error,
        type = type,
        typeof = typeof,
        tonumber = tonumber,
        tostring = tostring,
        next = next,
        pairs = pairs,
        ipairs = ipairs,
        pcall = pcall,
        xpcall = xpcall,
        select = select,
        getfenv = env.getfenv,
        setfenv = env.setfenv,
        getmetatable = realGetmetatable,
        setmetatable = realSetmetatable,
        rawget = rawget,
        rawset = rawset,
        rawequal = realRawequal,
    }
    local function makeTransparentWrapper(original, wrapper, name)
        if debug and debug.getinfo then
            local info = debug.getinfo(original)
        end

        return wrapper
    end

    local function isNativeLikeFunction(func: any): boolean
        if cclosureRegistry[func] or executorClosureRegistry[func] then
            return true
        end
        for name, original in pairs(originalFunctions) do
            if func == original or func == env[name] then
                return true
            end
        end
        for _, nativeTable in ipairs({
            env.math, env.string, env.table, env.utf8, env.bit32, env.bit, env.task,
            env.Vector2, env.Vector3, env.Vector3int16, env.Color3, env.CFrame,
            env.UDim, env.UDim2, env.BrickColor, env.NumberRange, env.NumberSequence,
            env.ColorSequence, env.Region3, env.Region3int16, env.Ray, env.TweenInfo,
            env.RaycastParams, env.Random, env.PhysicalProperties, env.Instance, tweenService,
        }) do
            if type(nativeTable) == "table" then
                for _, value in pairs(nativeTable) do
                    if func == value then
                        return true
                    end
                end
            end
        end
        return false
    end

    local function makeDebugRecord(target: any, options: any?): {[string]: any}
        local record = {
            source = "=[C]",
            short_src = "[C]",
            func = type(target) == "function" and target or nil,
            what = "C",
            currentline = -1,
            name = nil,
            namewhat = "",
            nups = 0,
            nparams = 0,
            isvararg = true,
            activelines = {},
            numparams = 0,
        }

        if type(target) == "number" then
            local stackLevel = target
            record.what = "Lua"
            record.source = "=[C]"
            record.short_src = "[C]"
            record.currentline = 1

            if _debug and _debug.info then
                local realLevel = stackLevel + 4
                local ok, fn = pcall(_debug.info, realLevel, "f")
                if ok and type(fn) == "function" then
                    record.func = fn
                end

            elseif _debug and _debug.getinfo then
                local ok, info = pcall(_debug.getinfo, stackLevel + 4, "fSl")
                if ok and info and type(info.func) == "function" then
                    record.func = info.func
                end
            end
            return record
        end

        if type(target) == "function" and not isNativeLikeFunction(target) then
            record.what = "Lua"
            record.source = "=[Script]"
            record.short_src = "[Script]"
            record.currentline = 1
            record.func = target
            if process.env.ENV2_EXPOSE_DEBUG_SOURCE == "1" and _debug and _debug.getinfo then
                local ok, info = pcall(_debug.getinfo, target, "nSluf")
                if ok and type(info) == "table" then
                    for k, v in pairs(info) do
                        record[k] = v
                    end
                    record.currentline = record.currentline or 1
                    record.source = "=[Script]"
                    record.short_src = "[Script]"
                    record.what = record.what or "Lua"
                    record.nups = 0
                end
            end
        end

        if type(target) == "function" and isNativeLikeFunction(target) then
            record.what = "C"
            record.source = "=[C]"
            record.short_src = "[C]"
            record.currentline = -1
            record.func = target
            record.nups = 0
            if target == env.tonumber or target == tonumber then
                record.nparams = 2
                record.numparams = 2
                record.isvararg = false
            elseif target == env.type or target == type or target == env.typeof or target == typeof then
                record.nparams = 1
                record.numparams = 1
                record.isvararg = false
            end
        end

        return record
    end

    local function debugInfo(target: any, options: any?)
        local record = makeDebugRecord(target, options)
        local optionText = type(options) == "string" and options or "s"
        local values = {}

        for i = 1, #optionText do
            local opt = optionText:sub(i, i)
            if opt == "f" then
                table.insert(values, record.func)
            elseif opt == "s" then
                table.insert(values, record.short_src or record.source or "[C]")
            elseif opt == "l" then
                table.insert(values, record.currentline or -1)
            elseif opt == "n" then
                table.insert(values, record.name)
            elseif opt == "a" then
                table.insert(values, record.nparams or record.numparams or 0)
                table.insert(values, record.isvararg and true or false)
            else
                table.insert(values, nil)
            end
        end

        return table.unpack(values, 1, #values)
    end

    env.debug = {
        info = function(target, options)
            logAPICall("function_call", string.format("debug.info(%s, %s)", formatValue(target), formatValue(options)))
            return debugInfo(target, options)
        end,

        traceback = function(...)
            if debug and debug.traceback then
                return debug.traceback(...)
            end
            return ""
        end,

        getupvalue = function(func, index)
            logAPICall("security_block", "Blocked debug.getupvalue()")
            return nil
        end,

        setupvalue = function(func, index, value)
            logAPICall("security_block", "Blocked debug.setupvalue()")
            return nil
        end,

        getlocal = function(level, index)
            logAPICall("security_block", "Blocked debug.getlocal()")
            return nil
        end,

        setlocal = function(level, index, value)
            logAPICall("security_block", "Blocked debug.setlocal()")
            return nil
        end,
    }


    local realTick = tick or function()
        return os.time() + monotonicClock()
    end
    local startTime = monotonicClock()

    env.tick = function()
        return realTick()
    end

    env.os = {
        time = os.time,
        date = os.date,
        difftime = os.difftime,
        clock = function()
            return math.max(monotonicClock(), signalClock)
        end,
    }
    cclosureRegistry[env.os.time] = true
    cclosureRegistry[env.os.date] = true
    cclosureRegistry[env.os.difftime] = true
    cclosureRegistry[env.os.clock] = true

    local realType = type
    local realTypeof = typeof

    env.type = function(...: any)
        if select("#", ...) == 0 then
            error("missing argument #1", 2)
        end
        local obj = ...
        logAPICall("function_call", string.format("type(%s)", formatValue(obj)))

        if objectTypeNames[obj] then
            local objectTypeName = objectTypeNames[obj]
            if objectTypeName == "SharedTable" then
                return "table"
            end
            return "userdata"
        end
        if proxyRegistry[obj] then
            local varId = proxyRegistry[obj]
            local proxyTypeName = proxyTypeNames[obj]
            if proxyTypeName == "RBXScriptSignal"
                or proxyTypeName == "RBXScriptConnection"
                or proxyTypeName == "Enum"
                or proxyTypeName == "EnumType"
                or proxyTypeName == "EnumItem"
                or proxyTypeName == "DataModel"
                or proxyTypeName == "Workspace"
                or proxyTypeName == "Players"
                or proxyTypeName == "RunService"
                or (type(proxyTypeName) == "string" and proxyTypeName:match("^[A-Z]") and proxyTypeName ~= "Module") then
                return "userdata"
            end
            local varInfo = variables[varId]
            if varInfo and varInfo.type then
                if varInfo.type == "Instance" or varInfo.type == "Service" then
                    return "userdata"
                end
            end
            return "table"
        end

        return realType(obj)
    end

    env.typeof = function(...: any)
        if select("#", ...) == 0 then
            error("missing argument #1", 2)
        end
        local obj = ...
        logAPICall("function_call", string.format("typeof(%s)", formatValue(obj)))

        if objectTypeNames[obj] then
            return objectTypeNames[obj]
        end
        if proxyRegistry[obj] then
            local varId = proxyRegistry[obj]
            local proxyTypeName = proxyTypeNames[obj]
            if proxyTypeName == "EnumType" then
                return "Enum"
            end
            if proxyTypeName == "RBXScriptSignal"
                or proxyTypeName == "RBXScriptConnection"
                or proxyTypeName == "Enum"
                or proxyTypeName == "EnumItem" then
                return proxyTypeName
            end
            local varInfo = variables[varId]
            if varInfo and (varInfo.type == "Instance" or varInfo.type == "Service") then
                return "Instance"
            end
            if proxyTypeName then
                return "Instance"
            end
            if varInfo and varInfo.type then
                return varInfo.type
            end
            return "Instance"
        end

        if realTypeof then
            return realTypeof(obj)
        end

        return realType(obj)
    end

    env.collectgarbage = function(opt, arg)
        logAPICall("function_call", string.format("collectgarbage(%s, %s)", formatValue(opt), formatValue(arg)))

        if opt == "count" then
            return collectgarbage("count")
        elseif opt == "isrunning" then
            return true
        elseif opt == "step" then
            collectgarbage("step", arg or 0)
            return 0
        elseif opt == "collect" then
            collectgarbage("collect")
            return 0
        end

        return 0
    end

    local globalEnvOverride = nil

    env.getfenv = function(level)
        logAPICall("function_call", string.format("getfenv(%s)", formatValue(level)))
        syncCachedFenv()

        local globalEnv = globalEnvOverride or cachedFenv
        if type(level) == "number" then
            if level == 0 then
                return globalEnv
            elseif level == 1 then
                return cachedFenv
            end
        elseif type(level) == "thread" then
            return globalEnv
        elseif type(level) == "function" then
            return cachedFenv
        end

        return cachedFenv
    end

    env.setfenv = function(level, table)
        logAPICall("function_call", string.format("setfenv(%s, table)", formatValue(level)))

        if level == 0 and type(table) == "table" then
            globalEnvOverride = table
            return level
        end

        if type(level) == "function" then
            if isNativeLikeFunction(level) then
                error("cannot change environment of given object", 2)
            end
            local protectedFunctions = {
                env.pcall, env.type, env.tostring, env.getfenv, env.setfenv,
                env.next, env.pairs, env.ipairs,
                pcall, type, tostring, next, pairs, ipairs, select,
            }
            for _, protected in ipairs(protectedFunctions) do
                if level == protected then
                    error("cannot change environment of given object", 2)
                end
            end
        end

        return level
    end

    local activeTostring = setmetatable({}, {__mode = "k"})
    local syntheticTostringIds = setmetatable({}, {__mode = "k"})
    local syntheticTostringCounter = 0
    local function syntheticTableTostring(obj: any): string
        local existing = syntheticTostringIds[obj]
        if existing then
            return existing
        end
        syntheticTostringCounter += 1
        local visibleId = (syntheticTostringCounter % 0x1000000) * 0x100
        local value = string.format("table: 0x%08x", visibleId)
        syntheticTostringIds[obj] = value
        return value
    end
    env.tostring = function(...: any)
        if select("#", ...) == 0 then
            error("missing argument #1", 2)
        end
        local obj = ...
        if type(obj) == "function" and isNativeLikeFunction(obj) then
            return "function: [C]"
        end
        if type(obj) == "table" then
            local objectTypeName = objectTypeNames[obj]
            if not objectTypeName and not proxyRegistry[obj] then
                return syntheticTableTostring(obj)
            end
            if activeTostring[obj] then
                return syntheticTableTostring(obj)
            end
            activeTostring[obj] = true
        end
        local results = table.pack(pcall(originalFunctions.tostring, obj))
        if type(obj) == "table" then
            activeTostring[obj] = nil
        end
        if results[1] then
            return results[2]
        end
        return string.format("%s: 0x00000000", type(obj))
    end

    env.tonumber = function(...: any)
        if select("#", ...) == 0 then
            error("missing argument #1", 2)
        end
        local obj, base = ...
        return originalFunctions.tonumber(obj, base)
    end

    env.pairs = function(t)
        logAPICall("function_call", "pairs(table)")
        if t == env._G then
            return originalFunctions.pairs(env)
        end
        return originalFunctions.pairs(t)
    end

    env.ipairs = function(t)
        logAPICall("function_call", "ipairs(table)")
        return originalFunctions.ipairs(t)
    end

    env.next = function(t, k)
        if t == env._G then
            return originalFunctions.next(env, k)
        end
        return originalFunctions.next(t, k)
    end

    env.pcall = function(func, ...)
        pcallCount += 1
        logAPICall("function_call", "pcall(function, ...)")
        if type(func) ~= "function" then
            error("function expected", 2)
        end
        local results = table.pack(realPcall(func, ...))
        if results[1] == false then
            local protectedError = normalizeProtectedError(results[2])
            if protectedError == "RevealR caught you ape" then
                return true, nil
            end
            results[2] = protectedError
        end
        return table.unpack(results, 1, results.n)
    end

    env.xpcall = function(func, errorHandler, ...)
        logAPICall("function_call", "xpcall(function, errorHandler, ...)")
        local results = table.pack(realXpcall(func, errorHandler, ...))
        if results[1] == false then
            results[2] = normalizeProtectedError(results[2])
        end
        return table.unpack(results, 1, results.n)
    end
    env.ypcall = env.pcall

    env.select = select


    local virtualGcCount = nil
    local gcCollected = false
    env.collectgarbage = function(opt, arg)
        logAPICall("function_call", string.format("collectgarbage(%s, %s)", formatValue(opt), formatValue(arg)))

        if opt == "collect" or opt == nil then
            for _, mt in ipairs(proxyFinalizers) do
                if type(mt) == "table" and type(mt.__gc) == "function" then
                    pcall(mt.__gc)
                    mt.__gc = nil
                end
            end
            gcCollected = true
            if virtualGcCount then
                virtualGcCount = math.max(0, virtualGcCount - 0.05)
            end
            return 0
        end

        if opt == "count" then
            local ok, realCount = pcall(collectgarbage, "count")
            local baseline = ok and tonumber(realCount) or 1024
            if gcCollected then
                gcCollected = false
                virtualGcCount = math.max(0, math.min(virtualGcCount or baseline, baseline) - 0.02)
            else
                virtualGcCount = math.max(baseline, virtualGcCount or baseline) + 0.02
            end
            return virtualGcCount
        elseif opt == "isrunning" then
            return true
        end

        local ok, result = pcall(collectgarbage, opt, arg)
        if ok then
            return result
        end
        return 0
    end
    env.gcinfo = function()
        logAPICall("function_call", "gcinfo()")
        return math.max(1, math.floor(tonumber(env.collectgarbage("count")) or 1))
    end

    local function formatLibraryArgs(args: {any}, maxArgs: number?): string
        local parts = {}
        local limit = maxArgs or 6
        for i = 1, math.min(#args, limit) do
            table.insert(parts, formatValue(args[i]))
        end
        if #args > limit then
            table.insert(parts, "...")
        end
        return table.concat(parts, ", ")
    end

    local function shouldLogLibraryCall(libName: string, key: any): boolean
        local keyStr = tostring(key)

        if libName == "bit32" or libName == "bit" then
            return false
        end
        if libName == "math" then
            return false
        end
        if libName == "string" and (
            keyStr == "byte" or keyStr == "char" or keyStr == "sub" or keyStr == "len"
        ) then
            return false
        end
        if libName == "table" and (keyStr == "insert" or keyStr == "concat") then
            return false
        end
        if libName == "table" and (
            keyStr == "move" or keyStr == "pack" or keyStr == "unpack" or keyStr == "create"
        ) then
            return false
        end

        return true
    end

    local function fallbackTableConcat(args: {any}): string?
        if type(args[1]) ~= "table" then
            return nil
        end

        local sep = args[2]
        if sep == nil then
            sep = ""
        elseif type(sep) ~= "string" then
            sep = safeToString(sep)
        end

        local first = tonumber(args[3]) or 1
        local last = tonumber(args[4]) or #args[1]
        local parts = {}

        for i = first, last do
            local value = args[1][i]
            if value == nil then
                parts[#parts + 1] = ""
            elseif type(value) == "string" or type(value) == "number" then
                parts[#parts + 1] = tostring(value)
            else
                local bytes = byteArrayToString(value)
                parts[#parts + 1] = bytes or safeToString(value)
            end
        end

        return table.concat(parts, sep)
    end

    local function fallbackStringFormat(args: {any}): string?
        local formatText = args[1]
        if type(formatText) ~= "string" then
            formatText = byteArrayToString(formatText) or safeToString(formatText)
        end

        local sanitized = {}
        for i = 2, #args do
            local value = args[i]
            if type(value) == "table" then
                sanitized[i - 1] = byteArrayToString(value) or safeToString(value)
            else
                sanitized[i - 1] = value
            end
        end

        local ok, result = pcall(string.format, formatText, table.unpack(sanitized, 1, #sanitized))
        if ok then
            return result
        end

        return nil
    end

    local function coerceNumber(value: any, default: number?): number
        if type(value) == "number" then
            return value
        end
        local converted = tonumber(value)
        if converted then
            return converted
        end
        return default or 0
    end

    local function fallbackStringCall(key: any, args: {any}): {any}?
        if key == "format" then
            if (args.n or #args) == 0 or args[1] == nil then
                return nil
            end
            local result = fallbackStringFormat(args)
            return result ~= nil and table.pack(result) or nil
        end

        if key ~= "char" and ((args.n or #args) == 0 or args[1] == nil) then
            return nil
        end

        local text = args[1]
        if type(text) ~= "string" then
            text = byteArrayToString(text) or safeToString(text or "")
        end

        if key == "byte" then
            local startIndex = tonumber(args[2]) or 1
            local endIndex = tonumber(args[3]) or startIndex
            local values = table.pack(string.byte(text, startIndex, endIndex))
            if (values.n or 0) == 0 then
                return table.pack(0)
            end
            for i = 1, values.n do
                if values[i] == nil then
                    values[i] = 0
                end
            end
            return values
        elseif key == "char" then
            local out = {}
            local count = args.n or #args
            if count == 0 then
                return nil
            end
            for i = 1, count do
                local value = tonumber(args[i])
                if value == nil or value < 0 or value > 0x10ffff then
                    return nil
                end
                out[i] = value
            end
            return table.pack(string.char(table.unpack(out, 1, count)))
        elseif key == "sub" then
            return table.pack(string.sub(text, tonumber(args[2]) or 1, tonumber(args[3]) or -1))
        elseif key == "len" then
            if type(args[1]) ~= "string" then
                return nil
            end
            return table.pack(#text)
        elseif key == "lower" then
            return table.pack(string.lower(text))
        elseif key == "upper" then
            return table.pack(string.upper(text))
        elseif key == "reverse" then
            return table.pack(string.reverse(text))
        elseif key == "rep" then
            return table.pack(string.rep(text, math.max(0, coerceNumber(args[2]))))
        elseif key == "find" then
            if args[2] == nil then
                return table.pack(nil)
            end
            if type(args[2]) ~= "string" and type(args[2]) ~= "number" then
                return nil
            end
            local ok, a, b, c, d, e = pcall(string.find, text, safeToString(args[2]), tonumber(args[3]) or 1, args[4] == true)
            if ok then
                return table.pack(a, b, c, d, e)
            end
            return table.pack(nil)
        elseif key == "match" then
            if args[2] == nil then
                return table.pack(nil)
            end
            if type(args[2]) ~= "string" and type(args[2]) ~= "number" then
                return nil
            end
            local ok, a, b, c, d, e = pcall(string.match, text, safeToString(args[2]), tonumber(args[3]) or 1)
            if ok then
                return table.pack(a, b, c, d, e)
            end
            return table.pack(nil)
        elseif key == "gsub" then
            if args[2] == nil then
                return table.pack(text, 0)
            end
            if type(args[2]) ~= "string" and type(args[2]) ~= "number" then
                return nil
            end
            local repl = args[3]
            if repl == nil then
                repl = ""
            end
            local ok, result, count = pcall(string.gsub, text, safeToString(args[2]), repl, tonumber(args[4]))
            if ok then
                return table.pack(result, count)
            end
            return table.pack(text, 0)
        elseif key == "gmatch" then
            if args[2] == nil then
                return table.pack(function() return nil end)
            end
            if type(args[2]) ~= "string" and type(args[2]) ~= "number" then
                return nil
            end
            local ok, iterator = pcall(string.gmatch, text, safeToString(args[2]))
            if ok then
                return table.pack(iterator)
            end
            return table.pack(function() return nil end)
        end

        return nil
    end

    local function fallbackMathCall(key: any, args: {any}): {any}?
        if (args.n or #args) == 0 or args[1] == nil then
            return nil
        end
        if key == "min" then
            local result = math.huge
            local count = math.max(args.n or #args, 1)
            for i = 1, count do
                result = math.min(result, coerceNumber(args[i], math.huge))
            end
            return table.pack(result == math.huge and 0 or result)
        elseif key == "max" then
            local result = -math.huge
            local count = math.max(args.n or #args, 1)
            for i = 1, count do
                result = math.max(result, coerceNumber(args[i], -math.huge))
            end
            return table.pack(result == -math.huge and 0 or result)
        elseif key == "abs" or key == "acos" or key == "asin" or key == "atan" or key == "ceil" or key == "cos"
            or key == "deg" or key == "exp" or key == "floor" or key == "log" or key == "rad"
            or key == "sin" or key == "sqrt" or key == "tan" then
            if args[1] ~= nil and tonumber(args[1]) == nil then
                return nil
            end
            local fn = math[key]
            if type(fn) == "function" then
                local ok, result = pcall(fn, coerceNumber(args[1]))
                if ok then
                    return table.pack(result)
                end
            end
            return table.pack(0)
        elseif key == "fmod" or key == "pow" then
            local fn = math[key]
            if type(fn) == "function" then
                local ok, result = pcall(fn, coerceNumber(args[1]), coerceNumber(args[2], 1))
                if ok then
                    return table.pack(result)
                end
            end
            return table.pack(0)
        end

        return nil
    end

    local function libraryFallback(libName: string, key: any, args: {any}, err: any): {any}?
        if libName == "table" and key == "concat" then
            local result = fallbackTableConcat(args)
            if result ~= nil then
                return table.pack(result)
            end
        elseif libName == "table" and key == "insert" then
            if args[1] ~= nil and type(args[1]) ~= "table" then
                return nil
            end
            logAPICall("function_call", "table.insert recovered from nil table")
            return table.pack()
        elseif libName == "table" and key == "remove" then
            if type(args[1]) ~= "table" then
                return nil
            end
            logAPICall("function_call", "table.remove recovered from nil table")
            return table.pack(nil)
        elseif libName == "table" and key == "sort" then
            if type(args[1]) ~= "table" then
                return nil
            end
            logAPICall("function_call", "table.sort recovered from invalid table")
            return table.pack()
        elseif libName == "string" then
            return fallbackStringCall(key, args)
        elseif libName == "math" then
            return fallbackMathCall(key, args)
        end

        return nil
    end

    local tableMutators = {
        clear = true,
        insert = true,
        move = true,
        remove = true,
        sort = true,
    }
    local tableFastCalls = {
        create = true,
        move = true,
        pack = true,
        unpack = true,
    }
    local function isReadonlyTableValue(value: any): boolean
        if type(value) ~= "table" then
            return false
        end
        if frozenDataTableCount > 0 and frozenDataTables[value] == true then
            return true
        end
        return false
    end

    local function hookLibrary(libName: string, source: any, tracked: {[string]: boolean}?): any
        local wrapped = {}
        for key, value in pairs(source) do
            if type(value) == "function" and (not tracked or tracked[key]) then
                wrapped[key] = function(...: any)
                    local args = table.pack(...)
                    if libName == "table" and tableFastCalls[key] then
                        if frozenDataTableCount > 0 and tableMutators[key] and isReadonlyTableValue(args[1]) then
                            error("attempt to modify a readonly table", 2)
                        end
                        return value(table.unpack(args, 1, args.n))
                    end
                    if shouldLogLibraryCall(libName, key) then
                        logAPICall("function_call", string.format("%s.%s(%s)", libName, tostring(key), formatLibraryArgs(args)))
                    end
                    if libName == "table" and frozenDataTableCount > 0 and tableMutators[key] and isReadonlyTableValue(args[1]) then
                        error("attempt to modify a readonly table", 2)
                    end
                    local callResults = table.pack(pcall(value, table.unpack(args, 1, args.n)))
                    local results
                    if callResults[1] then
                        results = {n = math.max((callResults.n or 1) - 1, 0)}
                        for i = 2, callResults.n or 1 do
                            results[i - 1] = callResults[i]
                        end
                    else
                        results = libraryFallback(libName, key, args, callResults[2])
                        if not results then
                            error(callResults[2], 0)
                        end
                        logAPICall("function_call", string.format("%s.%s recovered from invalid arguments", libName, tostring(key)))
                    end
                    if libName == "table" and key == "concat" then
                        recordReportValue(results[1])
                        logDecodedString(results[1], "table.concat")
                    elseif libName == "string" and key == "format" then
                        recordReportValue(results[1])
                    elseif libName == "string" and key == "char" then
                        logDecodedString(results[1], "string.char", 4)
                    elseif libName == "string" and (key == "gsub" or key == "reverse") then
                        logDecodedString(results[1], "string." .. tostring(key), 5)
                    end
                    return table.unpack(results, 1, results.n)
                end
                cclosureRegistry[wrapped[key]] = true
            else
                wrapped[key] = value
            end
        end
        return setmetatable(wrapped, {
            __newindex = function(_, k, _)
                logAPICall("security_block", string.format("readonly_library_write(%s, %s)", formatValue(libName), formatValue(k)))
                error("attempt to modify a readonly table", 2)
            end,
        })
    end

    env.math = hookLibrary("math", math, {
        abs = true, acos = true, asin = true, atan = true, ceil = true, cos = true,
        deg = true, exp = true, floor = true, fmod = true, log = true, max = true,
        min = true, modf = true, noise = true, pow = true, rad = true, random = true,
        randomseed = true, sin = true, sqrt = true, tan = true
    })
    if type(env.math.ldexp) ~= "function" then
        rawset(env.math, "ldexp", function(value: any, exponent: any)
            logAPICall("function_call", string.format("math.ldexp(%s, %s)", formatValue(value), formatValue(exponent)))
            return (tonumber(value) or 0) * (2 ^ (tonumber(exponent) or 0))
        end)
    end
    if type(env.math.frexp) ~= "function" then
        rawset(env.math, "frexp", function(value: any)
            logAPICall("function_call", string.format("math.frexp(%s)", formatValue(value)))
            local number = tonumber(value) or 0
            if number == 0 then
                return 0, 0
            end
            local exponent = math.floor(math.log(math.abs(number)) / math.log(2)) + 1
            return number / (2 ^ exponent), exponent
        end)
    end
    rawset(env.math, "clamp", function(value: any, minValue: any, maxValue: any)
        if type(value) ~= "number" or type(minValue) ~= "number" or type(maxValue) ~= "number" then
            error("number expected", 2)
        end
        local number = tonumber(value) or 0
        local lower = tonumber(minValue) or 0
        local upper = tonumber(maxValue) or lower
        if upper < lower then
            lower, upper = upper, lower
        end
        return math.max(lower, math.min(upper, number))
    end)
    cclosureRegistry[env.math.clamp] = true
    rawset(env.math, "sign", function(value: any)
        if type(value) ~= "number" then
            error("number expected", 2)
        end
        local number = tonumber(value) or 0
        if number > 0 then return 1 end
        if number < 0 then return -1 end
        return 0
    end)
    cclosureRegistry[env.math.sign] = true
    env.string = hookLibrary("string", string, {
        byte = true, char = true, find = true, format = true, gmatch = true, gsub = true,
        len = true, lower = true, match = true, rep = true, reverse = true, sub = true,
        upper = true
    })
    rawset(env.string, "dump", function(fn: any)
        if type(fn) ~= "function" then
            error("function expected", 2)
        end
        if isNativeLikeFunction(fn) then
            error("unable to dump given function", 2)
        end
        if type(string.dump) == "function" then
            return string.dump(fn)
        end
        error("string.dump is unavailable", 2)
    end)
    cclosureRegistry[env.string.dump] = true
    env.table = hookLibrary("table", table, {
        concat = true, insert = true, remove = true, sort = true, unpack = true, pack = true,
        find = true, clone = true, clear = true, freeze = true, isfrozen = true, move = true
    })
    rawset(env.table, "create", env.table.create or function(count: any, value: any)
        if count == nil then
            error("missing argument #1", 2)
        end
        if type(count) ~= "number" then
            error("number expected", 2)
        end
        local out = {}
        for index = 1, math.max(0, math.floor(count)) do
            out[index] = value
        end
        return out
    end)
    cclosureRegistry[env.table.create] = true
    rawset(env.table, "freeze", function(value)
        logAPICall("function_call", "table.freeze(table)")
        if type(value) == "table" then
            readonlyTables[value] = true
            if table.freeze then
                pcall(table.freeze, value)
            end
        end
        return value
    end)
    rawset(env.table, "isfrozen", function(value)
        logAPICall("function_call", "table.isfrozen(table)")
        if type(value) ~= "table" then
            return true
        end
        if readonlyTables[value] == true then
            return true
        end
        if frozenDataTables[value] == true then
            return true
        end
        if table.isfrozen then
            local ok, frozen = pcall(table.isfrozen, value)
            if ok then
                return frozen == true
            end
        end
        return false
    end)
    rawset(env.table, "clone", function(value)
        logAPICall("function_call", "table.clone(table)")
        if type(value) ~= "table" then
            error("invalid argument #1 to 'clone' (table expected)", 2)
        end
        local out = {}
        for key, item in pairs(value) do
            out[key] = item
        end
        return out
    end)
    rawset(env.table, "clear", function(value)
        logAPICall("function_call", "table.clear(table)")
        if type(value) ~= "table" then
            error("invalid argument #1 to 'clear' (table expected)", 2)
        end
        if isReadonlyTableValue(value) then
            error("attempt to modify a readonly table", 2)
        end
        for key in pairs(value) do
            rawset(value, key, nil)
        end
    end)
    cclosureRegistry[env.table.freeze] = true
    cclosureRegistry[env.table.isfrozen] = true
    cclosureRegistry[env.table.clone] = true
    cclosureRegistry[env.table.clear] = true
    rawset(env.table, "create", function(count, value)
        logAPICall("function_call", string.format("table.create(%s, %s)", formatValue(count), formatValue(value)))
        local n = math.floor(tonumber(count) or 0)
        if n < 0 then
            n = 0
        elseif n > 100000 then
            n = 100000
        end
        local result = {}
        for index = 1, n do
            result[index] = value
        end
        return result
    end)
    rawset(env.table, "getn", function(value)
        logAPICall("function_call", "table.getn(table)")
        if type(value) ~= "table" then
            return 0
        end
        return #value
    end)
    rawset(env.table, "maxn", function(value)
        logAPICall("function_call", "table.maxn(table)")
        if type(value) ~= "table" then
            return 0
        end
        local max = 0
        for key in pairs(value) do
            if type(key) == "number" and key > max then
                max = key
            end
        end
        return max
    end)
    rawset(env.table, "foreach", function(value, callback)
        logAPICall("function_call", "table.foreach(table, function)")
        if type(value) == "table" and type(callback) == "function" then
            for key, item in pairs(value) do
                local result = callback(key, item)
                if result ~= nil then
                    return result
                end
            end
        end
        return nil
    end)
    rawset(env.table, "foreachi", function(value, callback)
        logAPICall("function_call", "table.foreachi(table, function)")
        if type(value) == "table" and type(callback) == "function" then
            for index, item in ipairs(value) do
                local result = callback(index, item)
                if result ~= nil then
                    return result
                end
            end
        end
        return nil
    end)
    local coroutineCompat: {[string]: any} = {
        create = function(callback)
            logAPICall("function_call", "coroutine.create(function(...) end)")
            local threadRef = coroutine.create(callback)
            managedThreads[threadRef] = true
            return threadRef
        end,
        resume = function(threadRef, ...)
            logAPICall("function_call", "coroutine.resume(thread, ...)")
            return coroutine.resume(threadRef, ...)
        end,
        wrap = function(callback)
            logAPICall("function_call", "coroutine.wrap(function(...) end)")
            local threadRef = coroutine.create(callback)
            managedThreads[threadRef] = true
            return function(...)
                local results = table.pack(coroutine.resume(threadRef, ...))
                if not results[1] then
                    error(results[2], 2)
                end
                return table.unpack(results, 2, results.n)
            end
        end,
        yield = function(...)
            logAPICall("function_call", "coroutine.yield(...)")
            return coroutine.yield(...)
        end,
        running = coroutine.running,
        status = coroutine.status,
    }
    if type(coroutine.isyieldable) == "function" then
        coroutineCompat.isyieldable = coroutine.isyieldable
    end
    if type(coroutine.close) == "function" then
        coroutineCompat.close = function(threadRef)
            logAPICall("function_call", "coroutine.close(thread)")
            return coroutine.close(threadRef)
        end
    end
    env.coroutine = coroutineCompat
    for _, value in pairs(env.coroutine) do
        if type(value) == "function" then
            cclosureRegistry[value] = true
        end
    end
    env.utf8 = {}
    if utf8 then
        for key, value in pairs(utf8) do
            env.utf8[key] = value
        end
    end
    env.utf8.graphemes = env.utf8.graphemes or function(text: any, startIndex: any, endIndex: any)
        local source = tostring(text or "")
        local index = math.max(1, tonumber(startIndex) or 1)
        local finish = math.min(#source, tonumber(endIndex) or #source)
        return function()
            if index > finish then
                return nil
            end
            local startByte = index
            index += 1
            while index <= finish do
                local byte = string.byte(source, index)
                if not byte or byte < 128 or byte >= 192 then
                    break
                end
                index += 1
            end
            return startByte, index - 1
        end
    end
    for _, value in pairs(env.utf8) do
        if type(value) == "function" then
            cclosureRegistry[value] = true
        end
    end

    env.bit32 = bit32 or {
        band = function(a, b)
            local result = 0
            local bitval = 1
            while a > 0 and b > 0 do
                if a % 2 == 1 and b % 2 == 1 then
                    result = result + bitval
                end
                bitval = bitval * 2
                a = math.floor(a / 2)
                b = math.floor(b / 2)
            end
            return result
        end,
        bor = function(a, b)
            local result = 0
            local bitval = 1
            while a > 0 or b > 0 do
                if a % 2 == 1 or b % 2 == 1 then
                    result = result + bitval
                end
                bitval = bitval * 2
                a = math.floor(a / 2)
                b = math.floor(b / 2)
            end
            return result
        end,
        bxor = function(a, b)
            local result = 0
            local bitval = 1
            while a > 0 or b > 0 do
                if (a % 2) ~= (b % 2) then
                    result = result + bitval
                end
                bitval = bitval * 2
                a = math.floor(a / 2)
                b = math.floor(b / 2)
            end
            return result
        end,
        bnot = function(a)
            return 4294967295 - a
        end,
        lshift = function(a, b)
            return (a * (2 ^ b)) % 4294967296
        end,
        rshift = function(a, b)
            return math.floor(a / (2 ^ b))
        end,
        arshift = function(a, b)
            return math.floor(a / (2 ^ b))
        end,
    }

    local bit32Source = env.bit32
    env.bit32 = {}
    for key, value in pairs(bit32Source) do
        env.bit32[key] = value
    end

    local function toUInt32(value: any): number
        return math.floor(tonumber(value) or 0) % 4294967296
    end

    local function bitMask(width: any): number
        width = math.max(0, math.min(32, tonumber(width) or 1))
        if width >= 32 then
            return 4294967295
        end
        return (2 ^ width) - 1
    end

    local rawBand = env.bit32.band
    local rawBor = env.bit32.bor
    local rawBxor = env.bit32.bxor
    local rawBnot = env.bit32.bnot
    local rawLshift = env.bit32.lshift
    local rawRshift = env.bit32.rshift

    local function expectBitNumber(value: any)
        if type(value) ~= "number" then
            error("number expected", 3)
        end
    end

    env.bit32.band = function(a: any, b: any, ...: any)
        expectBitNumber(a)
        expectBitNumber(b)
        local result = rawBand(toUInt32(a), toUInt32(b))
        for i = 1, select("#", ...) do
            local value = select(i, ...)
            expectBitNumber(value)
            result = rawBand(result, toUInt32(value))
        end
        return toUInt32(result)
    end

    env.bit32.bor = function(a: any, b: any, ...: any)
        expectBitNumber(a)
        expectBitNumber(b)
        local result = rawBor(toUInt32(a), toUInt32(b))
        for i = 1, select("#", ...) do
            local value = select(i, ...)
            expectBitNumber(value)
            result = rawBor(result, toUInt32(value))
        end
        return toUInt32(result)
    end

    env.bit32.bxor = function(a: any, b: any, ...: any)
        expectBitNumber(a)
        expectBitNumber(b)
        local result = rawBxor(toUInt32(a), toUInt32(b))
        for i = 1, select("#", ...) do
            local value = select(i, ...)
            expectBitNumber(value)
            result = rawBxor(result, toUInt32(value))
        end
        return toUInt32(result)
    end

    env.bit32.bnot = function(value: any)
        expectBitNumber(value)
        return toUInt32(rawBnot(toUInt32(value)))
    end

    env.bit32.lshift = function(value: any, disp: any)
        expectBitNumber(value)
        expectBitNumber(disp)
        disp = tonumber(disp) or 0
        if disp < 0 then
            return rawRshift(toUInt32(value), -disp)
        end
        return toUInt32(rawLshift(toUInt32(value), disp))
    end

    env.bit32.rshift = function(value: any, disp: any)
        expectBitNumber(value)
        expectBitNumber(disp)
        disp = tonumber(disp) or 0
        if disp < 0 then
            return toUInt32(rawLshift(toUInt32(value), -disp))
        end
        return toUInt32(rawRshift(toUInt32(value), disp))
    end

    env.bit32.arshift = env.bit32.arshift or env.bit32.rshift
    env.bit32.extract = env.bit32.extract or function(value: any, field: any, width: any)
        field = tonumber(field) or 0
        width = tonumber(width) or 1
        return env.bit32.band(env.bit32.rshift(value, field), bitMask(width))
    end

    env.bit32.replace = env.bit32.replace or function(value: any, replacement: any, field: any, width: any)
        field = tonumber(field) or 0
        width = tonumber(width) or 1
        local mask = bitMask(width)
        local cleared = env.bit32.band(value, env.bit32.bnot(env.bit32.lshift(mask, field)))
        local inserted = env.bit32.lshift(env.bit32.band(replacement, mask), field)
        return env.bit32.bor(cleared, inserted)
    end

    env.bit32.lrotate = env.bit32.lrotate or function(value: any, disp: any)
        disp = (tonumber(disp) or 0) % 32
        value = toUInt32(value)
        if disp == 0 then
            return value
        end
        return env.bit32.bor(env.bit32.lshift(value, disp), env.bit32.rshift(value, 32 - disp))
    end

    env.bit32.rrotate = env.bit32.rrotate or function(value: any, disp: any)
        disp = (tonumber(disp) or 0) % 32
        value = toUInt32(value)
        if disp == 0 then
            return value
        end
        return env.bit32.bor(env.bit32.rshift(value, disp), env.bit32.lshift(value, 32 - disp))
    end

    env.bit32.btest = env.bit32.btest or function(...)
        return env.bit32.band(...) ~= 0
    end

    env.bit32.countlz = env.bit32.countlz or function(value: any)
        value = toUInt32(value)
        local count = 0
        for bit = 31, 0, -1 do
            if env.bit32.band(value, 2 ^ bit) ~= 0 then
                break
            end
            count += 1
        end
        return count
    end

    env.bit32.countrz = env.bit32.countrz or function(value: any)
        value = toUInt32(value)
        local count = 0
        for bit = 0, 31 do
            if env.bit32.band(value, 2 ^ bit) ~= 0 then
                break
            end
            count += 1
        end
        return count
    end

    env.bit32 = hookLibrary("bit32", env.bit32, {
        band = true, bor = true, bxor = true, bnot = true, lshift = true, rshift = true,
        arshift = true, extract = true, replace = true, lrotate = true, rrotate = true,
        btest = true, countlz = true, countrz = true
    })

    env.bit = env.bit32

    local bufferMt = {}
    local bufferMethods: {[string]: any} = {}

    local function makeBuffer(initial: any): any
        local bytes = {}
        if type(initial) == "number" then
            for i = 1, math.max(0, initial) do
                bytes[i] = 0
            end
        elseif type(initial) == "string" then
            for i = 1, #initial do
                bytes[i] = string.byte(initial, i)
            end
        elseif type(initial) == "table" and initial.__bytes then
            for i, value in ipairs(initial.__bytes) do
                bytes[i] = value
            end
        end

        return setmetatable({__bytes = bytes}, bufferMt)
    end

    local function normalizeOffset(offset: any): number
        local value = math.floor(tonumber(offset) or 0)
        if value < 0 then
            return 0
        end
        return value
    end

    local function getBufferBytes(value: any): {number}
        if type(value) == "table" and type(value.__bytes) == "table" then
            return value.__bytes
        end
        if type(value) == "string" then
            return makeBuffer(value).__bytes
        end
        return {}
    end

    local function bufferToString(value: any): string
        if type(value) == "string" then
            return value
        end
        local bytes = getBufferBytes(value)
        local out = {}
        for i, byte in ipairs(bytes) do
            out[i] = string.char(byte % 256)
        end
        return table.concat(out)
    end

    local function readUnsigned(value: any, offset: any, size: number): number
        local bytes = getBufferBytes(value)
        local start = normalizeOffset(offset) + 1
        local result = 0
        local mul = 1
        for i = 0, size - 1 do
            result += ((bytes[start + i] or 0) % 256) * mul
            mul *= 256
        end
        return result
    end

    local function readSigned(value: any, offset: any, size: number): number
        local unsigned = readUnsigned(value, offset, size)
        local bits = size * 8
        local sign = 2 ^ (bits - 1)
        local full = 2 ^ bits
        if unsigned >= sign then
            return unsigned - full
        end
        return unsigned
    end

    local function readPacked(fmt: string, size: number, value: any, offset: any, fallback: number): number
        local data = bufferToString(value)
        local pos = normalizeOffset(offset) + 1
        local needed = pos + size - 1
        if #data < needed then
            data ..= string.rep("\0", needed - #data)
        end
        local ok, result = pcall(string.unpack, fmt, data, pos)
        if ok and type(result) == "number" then
            return result
        end
        return fallback
    end

    local function writeRaw(value: any, offset: any, data: string): any
        local bytes = getBufferBytes(value)
        local start = normalizeOffset(offset) + 1
        for i = 1, #data do
            bytes[start + i - 1] = string.byte(data, i) or 0
        end
        return value
    end

    local function writeUnsigned(value: any, offset: any, size: number, numberValue: any): any
        local bytes = getBufferBytes(value)
        local start = normalizeOffset(offset) + 1
        local number = math.floor(tonumber(numberValue) or 0)
        local modulo = 2 ^ (size * 8)
        number = number % modulo
        for i = 0, size - 1 do
            bytes[start + i] = number % 256
            number = math.floor(number / 256)
        end
        return value
    end

    local function writePacked(fmt: string, size: number, value: any, offset: any, numberValue: any): any
        local ok, packed = pcall(string.pack, fmt, tonumber(numberValue) or 0)
        if ok and type(packed) == "string" and #packed == size then
            return writeRaw(value, offset, packed)
        end
        return writeUnsigned(value, offset, size, 0)
    end

    bufferMt.__len = function(self)
        return #self.__bytes
    end
    bufferMt.__tostring = bufferToString
    bufferMt.__index = function(_, key)
        return bufferMethods[tostring(key)]
    end

    env.buffer = {
        create = function(size)
            logAPICall("function_call", string.format("buffer.create(%s)", formatValue(size)))
            return makeBuffer(tonumber(size) or 0)
        end,
        fromstring = function(value, _encoding)
            logAPICall("function_call", "buffer.fromstring(string)")
            return makeBuffer(tostring(value or ""))
        end,
        tostring = function(value)
            logAPICall("function_call", "buffer.tostring(buffer)")
            return bufferToString(value)
        end,
        len = function(value)
            return #getBufferBytes(value)
        end,
        readu8 = function(value, offset)
            return readUnsigned(value, offset, 1)
        end,
        readi8 = function(value, offset)
            return readSigned(value, offset, 1)
        end,
        readu16 = function(value, offset)
            return readUnsigned(value, offset, 2)
        end,
        readi16 = function(value, offset)
            return readSigned(value, offset, 2)
        end,
        readu32 = function(value, offset)
            return readUnsigned(value, offset, 4)
        end,
        readi32 = function(value, offset)
            return readSigned(value, offset, 4)
        end,
        readf32 = function(value, offset)
            return readPacked("<f", 4, value, offset, 0)
        end,
        readf64 = function(value, offset)
            return readPacked("<d", 8, value, offset, 0)
        end,
        writeu8 = function(value, offset, byte)
            return writeUnsigned(value, offset, 1, byte)
        end,
        writei8 = function(value, offset, byte)
            return writeUnsigned(value, offset, 1, byte)
        end,
        writeu16 = function(value, offset, numberValue)
            return writeUnsigned(value, offset, 2, numberValue)
        end,
        writei16 = function(value, offset, numberValue)
            return writeUnsigned(value, offset, 2, numberValue)
        end,
        writeu32 = function(value, offset, numberValue)
            return writeUnsigned(value, offset, 4, numberValue)
        end,
        writei32 = function(value, offset, numberValue)
            return writeUnsigned(value, offset, 4, numberValue)
        end,
        writef32 = function(value, offset, numberValue)
            return writePacked("<f", 4, value, offset, numberValue)
        end,
        writef64 = function(value, offset, numberValue)
            return writePacked("<d", 8, value, offset, numberValue)
        end,
        readstring = function(value, offset, count)
            local bytes = getBufferBytes(value)
            local start = normalizeOffset(offset) + 1
            local finish = math.min(#bytes, start + (tonumber(count) or (#bytes - start + 1)) - 1)
            local out = {}
            for i = start, finish do
                table.insert(out, string.char((bytes[i] or 0) % 256))
            end
            return table.concat(out)
        end,
        writestring = function(value, offset, text)
            text = tostring(text or "")
            return writeRaw(value, offset, text)
        end,
        copy = function(target, targetOffset, source, sourceOffset, count)
            local sourceBytes = getBufferBytes(source)
            local targetBytes = getBufferBytes(target)
            local srcStart = normalizeOffset(sourceOffset) + 1
            local dstStart = normalizeOffset(targetOffset) + 1
            local amount = tonumber(count)
            if amount == nil then
                amount = #sourceBytes - srcStart + 1
            end
            amount = math.max(0, math.floor(amount))
            local temp = {}
            for i = 0, amount - 1 do
                temp[i + 1] = sourceBytes[srcStart + i] or 0
            end
            for i = 1, #temp do
                targetBytes[dstStart + i - 1] = temp[i]
            end
            return target
        end,
        fill = function(value, offset, byte, count)
            local bytes = getBufferBytes(value)
            local start = normalizeOffset(offset) + 1
            local amount = tonumber(count)
            if amount == nil then
                amount = #bytes - start + 1
            end
            amount = math.max(0, math.floor(amount))
            local byteValue = (tonumber(byte) or 0) % 256
            for i = 0, amount - 1 do
                bytes[start + i] = byteValue
            end
            return value
        end,
    }
    for name, fn in pairs(env.buffer) do
        if type(fn) == "function" then
            bufferMethods[name] = fn
        end
    end
    bufferMethods.toString = env.buffer.tostring
    rawset(env.string, "buffer", env.buffer)

    local zstdBridgeCounter = 0

    local function quotePowerShell(value: string): string
        return value:gsub("'", "''")
    end

    local function quoteCSharp(value: string): string
        return value:gsub("\\", "\\\\"):gsub('"', '\\"')
    end

    local function joinPath(a: string, b: string): string
        local slash = a:find("\\") and "\\" or "/"
        if a:sub(-1) == "\\" or a:sub(-1) == "/" then
            return a .. b
        end
        return a .. slash .. b
    end

    local function findZstdDll(): string?
        local cwd = _process.cwd or "."
        local candidates = {
            joinPath(cwd, "zstd.dll"),
            joinPath(joinPath(cwd, "Prometheus"), "zstd.dll"),
        }

        for _, path in ipairs(candidates) do
            if _fs.isFile(path) then
                return path
            end
        end

        return nil
    end

    local function runZstdBridge(mode: string, payload: string, level: number?): string?
        local dllPath = findZstdDll()
        if not dllPath then
            return nil
        end

        zstdBridgeCounter += 1
        local tempRoot = _process.env.TEMP or _process.env.TMP or joinPath(_process.cwd or ".", "temp")
        if not _fs.isDir(tempRoot) then
            pcall(_fs.writeDir, tempRoot)
        end
        if not _fs.isDir(tempRoot) then
            tempRoot = joinPath(_process.cwd or ".", "temp")
            if not _fs.isDir(tempRoot) then
                pcall(_fs.writeDir, tempRoot)
            end
        end

        local token = string.format("revealr_zstd_%d_%d", math.floor((os.clock() or 0) * 1000000), zstdBridgeCounter)
        local inputPath = joinPath(tempRoot, token .. ".in")
        local outputPath = joinPath(tempRoot, token .. ".out")
        _fs.writeFile(inputPath, payload)

        local psScript = [=[
$ErrorActionPreference = "Stop"
$srcPath = '@@INPUT@@'
$dstPath = '@@OUTPUT@@'
$mode = '@@MODE@@'
$level = @@LEVEL@@
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public static class ZstdNative {
    [DllImport("@@DLL_CS@@", CallingConvention = CallingConvention.Cdecl)]
    public static extern UIntPtr ZSTD_decompress(byte[] dst, UIntPtr dstCapacity, byte[] src, UIntPtr compressedSize);

    [DllImport("@@DLL_CS@@", CallingConvention = CallingConvention.Cdecl)]
    public static extern UIntPtr ZSTD_getFrameContentSize(byte[] src, UIntPtr srcSize);

    [DllImport("@@DLL_CS@@", CallingConvention = CallingConvention.Cdecl)]
    public static extern UIntPtr ZSTD_compressBound(UIntPtr srcSize);

    [DllImport("@@DLL_CS@@", CallingConvention = CallingConvention.Cdecl)]
    public static extern UIntPtr ZSTD_compress(byte[] dst, UIntPtr dstCapacity, byte[] src, UIntPtr srcSize, int compressionLevel);

    [DllImport("@@DLL_CS@@", CallingConvention = CallingConvention.Cdecl)]
    public static extern uint ZSTD_isError(UIntPtr code);

    [DllImport("@@DLL_CS@@", CallingConvention = CallingConvention.Cdecl)]
    public static extern IntPtr ZSTD_getErrorName(UIntPtr code);
}
"@

function Test-ZstdError([UIntPtr] $code) {
    return [ZstdNative]::ZSTD_isError($code) -ne 0
}

function Get-ZstdError([UIntPtr] $code) {
    return [Runtime.InteropServices.Marshal]::PtrToStringAnsi([ZstdNative]::ZSTD_getErrorName($code))
}

function New-USize([UInt64] $value) {
    return [UIntPtr]::new($value)
}

$src = [IO.File]::ReadAllBytes($srcPath)
if ($mode -eq "compress") {
    $bound = [ZstdNative]::ZSTD_compressBound((New-USize $src.Length)).ToUInt64()
    if ($bound -gt 67108864) { throw "zstd output too large" }
    $dst = New-Object byte[] ([int]$bound)
    $written = [ZstdNative]::ZSTD_compress($dst, (New-USize $dst.Length), $src, (New-USize $src.Length), $level)
    if (Test-ZstdError $written) { throw (Get-ZstdError $written) }
    $writtenInt = [int]$written.ToUInt64()
    $final = New-Object byte[] $writtenInt
    [Array]::Copy($dst, $final, $writtenInt)
    [IO.File]::WriteAllBytes($dstPath, $final)
} else {
    $contentSize = [ZstdNative]::ZSTD_getFrameContentSize($src, (New-USize $src.Length)).ToUInt64()
    $knownSize = $true
    if ($contentSize -eq [UInt64]::MaxValue -or $contentSize -eq ([UInt64]::MaxValue - 1)) {
        $knownSize = $false
        $contentSize = [Math]::Max($src.Length * 8, 1048576)
    }
    while ($true) {
        if ($contentSize -gt 67108864) { throw "zstd output too large" }
        $dst = New-Object byte[] ([int]$contentSize)
        $written = [ZstdNative]::ZSTD_decompress($dst, (New-USize $dst.Length), $src, (New-USize $src.Length))
        if (-not (Test-ZstdError $written)) {
            $writtenInt = [int]$written.ToUInt64()
            $final = New-Object byte[] $writtenInt
            [Array]::Copy($dst, $final, $writtenInt)
            [IO.File]::WriteAllBytes($dstPath, $final)
            break
        }
        if ($knownSize) { throw (Get-ZstdError $written) }
        $contentSize = $contentSize * 2
    }
}
]=]

        psScript = psScript:gsub("@@INPUT@@", function() return quotePowerShell(inputPath) end)
        psScript = psScript:gsub("@@OUTPUT@@", function() return quotePowerShell(outputPath) end)
        psScript = psScript:gsub("@@MODE@@", function() return mode end)
        psScript = psScript:gsub("@@LEVEL@@", function() return tostring(math.floor(tonumber(level) or 3)) end)
        psScript = psScript:gsub("@@DLL_CS@@", function() return quoteCSharp(dllPath) end)

        local ok, result = pcall(_process.exec, "powershell", {
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-Command",
            psScript,
        })

        local output = nil
        if ok and result and result.ok and _fs.isFile(outputPath) then
            output = _fs.readFile(outputPath)
        elseif ok and result and result.stderr and result.stderr ~= "" then
            logAPICall("function_call", "zstd bridge error: " .. tostring(result.stderr):sub(1, 120))
        end

        pcall(_fs.removeFile, inputPath)
        pcall(_fs.removeFile, outputPath)
        return output
    end

    local function zstdCodec(value: any, mode: string, level: number?): any
        logAPICall("function_call", string.format("zstd.%s(...)", mode))
        local payload = bufferToString(value)
        local bridged = runZstdBridge(mode, payload, level)
        return bridged or payload
    end

    env.zstd = {
        compress = function(value, level)
            return zstdCodec(value, "compress", level)
        end,
        decompress = function(value)
            return zstdCodec(value, "decompress")
        end,
    }
    env.Zstd = env.zstd
    env.zstdcompress = env.zstd.compress
    env.zstddecompress = env.zstd.decompress
    env.zstd_compress = env.zstd.compress
    env.zstd_decompress = env.zstd.decompress

    local encodingService = makeRobloxProxy("EncodingService", "EncodingService", {
        Name = "EncodingService",
        ClassName = "EncodingService",
        DecompressBuffer = function(_, value, algorithm)
            logAPICall("function_call", string.format("EncodingService:DecompressBuffer(%s)", formatValue(algorithm)))
            local decompressed = env.zstd.decompress(value)
            return makeBuffer(decompressed)
        end,
        CompressBuffer = function(_, value, algorithm)
            logAPICall("function_call", string.format("EncodingService:CompressBuffer(%s)", formatValue(algorithm)))
            local compressed = env.zstd.compress(value)
            return makeBuffer(compressed)
        end,
    })
    serviceResolvers.EncodingService = function()
        return encodingService
    end
    env.EncodingService = encodingService

    env.__remote_stub = function(sourceId)
        local id = string.format("remote_module[%s]", safeToString(sourceId))
        logAPICall("function_call", string.format("__remote_stub(%s)", formatValue(sourceId)))
        registerVariable(id, "Module", safeToString(sourceId))
        return createProxy(id, "remote_module")
    end

    local realUnpack = table.unpack or unpack
    env.unpack = function(value, first, last)
        return realUnpack(value, first, last)
    end
    cclosureRegistry[env.unpack] = true
    env.pack = table.pack or function(...) return {n=select('#',...), ...} end

    env._VERSION = "Luau"
    env.version = function()
        return "0.710.1.7100707"
    end
    env._ = nil
    env.fenv = nil

    local sandboxed_G = setmetatable({}, {
        __index = function(t, k)
            local keyStr = tostring(k)
            local dangerousPatterns = {
                "package", "io", "require", "loadfile", "dofile",
                "_fs", "_process", "_require", "_luau", "_stdio"
            }
            if keyStr == "_" or keyStr == "fenv" then
                return nil
            end

            for _, pattern in ipairs(dangerousPatterns) do
                if keyStr == pattern or keyStr:find(pattern, 1, true) then
                    logAPICall("security_block", string.format("Blocked access to _G.%s", keyStr))
                    return nil
                end
            end

            return env[k]
        end,
        __newindex = function(t, k, v)
            local keyStr = tostring(k)
            local dangerousPatterns = {
                "package", "io", "require", "loadfile", "dofile",
                "_fs", "_process", "_require", "_luau", "_stdio"
            }
            if keyStr == "_" or keyStr == "fenv" then
                return
            end

            for _, pattern in ipairs(dangerousPatterns) do
                if keyStr == pattern or keyStr:find(pattern, 1, true) then
                    logAPICall("security_block", string.format("Blocked _G.%s = value", keyStr))
                    return
                end
            end

            env[k] = v
        end,
        __pairs = function()
            local keys = {}
            for k in pairs(env) do
                local isDangerous = false
                local keyStr = tostring(k)
                local dangerousKeys = {"package", "io", "require", "loadfile", "dofile", "_fs", "_process", "_require", "_luau", "_stdio", "fenv"}
                if keyStr == "_" then
                    isDangerous = true
                end
                for _, dangerous in ipairs(dangerousKeys) do
                    if keyStr == dangerous or keyStr:find(dangerous, 1, true) then
                        isDangerous = true
                        break
                    end
                end
                if not isDangerous then
                    table.insert(keys, k)
                end
            end
            local i = 0
            return function()
                i = i + 1
                if keys[i] then
                    return keys[i], env[keys[i]]
                end
            end
        end,
    })
    env._G = sandboxed_G
    globalEnvOverride = cachedFenv

    env.shared = {}
    env.ESX = createProxy("ESX", "Framework")
    env.QBCore = createProxy("QBCore", "Framework")
    env.Framework = createProxy("Framework", "Framework")
    env.exports = createProxy("exports", "Exports")
    env.RegisterNetEvent = function(name, callback)
        logAPICall("function_call", string.format("RegisterNetEvent(%s, function(...) end)", formatValue(name)))
        if type(callback) == "function" then
            runTask(callback, true)
        end
    end
    env.AddEventHandler = function(name, callback)
        logAPICall("event_connection", string.format("AddEventHandler(%s, function(...) end)", formatValue(name)))
        if type(callback) == "function" then
            runTask(callback, true)
        end
        return createProxy("AddEventHandler(" .. formatValue(name) .. ")", "Connection")
    end
    env.RegisterCommand = function(name, callback)
        logAPICall("function_call", string.format("RegisterCommand(%s, function(...) end)", formatValue(name)))
        if type(callback) == "function" then
            runTask(callback, true)
        end
    end
    env.TriggerServerEvent = function(name, ...)
        logAPICall("function_call", string.format("TriggerServerEvent(%s, ...)", formatValue(name)))
    end
    env.TriggerClientEvent = function(name, ...)
        logAPICall("function_call", string.format("TriggerClientEvent(%s, ...)", formatValue(name)))
    end
    env.CreateThread = function(callback)
        logAPICall("function_call", "CreateThread(function(...) end)")
        return runTask(callback, true)
    end
    env.Citizen = {
        CreateThread = env.CreateThread,
        Wait = function(duration)
            return trackedWait(duration, "Citizen.Wait")
        end,
        SetTimeout = function(duration, callback)
            logAPICall("function_call", string.format("Citizen.SetTimeout(%s, function(...) end)", formatValue(duration)))
            return runTask(function()
                trackedWait(duration, "Citizen.SetTimeout")
                if type(callback) == "function" then
                    callback()
                end
            end, true)
        end,
    }
    env.Wait = env.Citizen.Wait

    env.game = env.game or createProxy("game", "DataModel", gameIndexFunc)
    env.Game = env.game
    env.workspace = env.workspace or createProxy("workspace", "Workspace")
    env.Workspace = env.workspace

    env.Vector3int16 = env.Vector3int16 or {
        new = function(x, y, z)
            logAPICall("function_call", string.format("Vector3int16.new(%d, %d, %d)", x or 0, y or 0, z or 0))
            return dataValue and dataValue("Vector3int16", {
                X = x or 0,
                Y = y or 0,
                Z = z or 0,
            }) or {X = x or 0, Y = y or 0, Z = z or 0}
        end
    }

    env.plugin = nil

    env.PluginManager = function()
        logAPICall("function_call", "PluginManager()")
        return createProxy("PluginManager", "PluginManager")
    end

    env.stats = env.stats or env.Stats or createProxy("stats", "Stats")
    env.Stats = env.Stats or env.stats

    env.newproxy = function(addMetatable)
        logAPICall("function_call", string.format("newproxy(%s)", tostring(addMetatable)))

        local proxy = {}
        local mt = {
            __len = function()
                error("attempt to get length of a userdata value", 2)
            end,
            __tostring = function()
                return "userdata: 0x00000000"
            end,
            __lt = function()
                return false
            end,
            __le = function()
                return false
            end,
        }
        if addMetatable then
            mt.__metatable = nil
            table.insert(proxyFinalizers, mt)
        else
            mt.__metatable = false
        end
        setmetatable(proxy, mt)
        objectTypeNames[proxy] = "userdata"
        return proxy
    end

    env.identifyexecutor = function()
        logAPICall("function_call", "identifyexecutor()")
        return "Synapse X", "v3.0.0"
    end

    env.getexecutorname = function()
        logAPICall("function_call", "getexecutorname()")
        return "Synapse X"
    end

    local genv = setmetatable({}, {
        __index = env,
        __newindex = function(t, k, v) env[k] = v end,
    })

    env.getgenv = function()
        return genv
    end

    env.getrenv = function()
        local fakeRealEnvStorage = {}
        local storageAccessOrder = {}
        local MAX_STORAGE = 5000

        local fakeRealEnv = setmetatable({}, {
            __index = function(t, k)
                if fakeRealEnvStorage[k] ~= nil then
                    for i, key in ipairs(storageAccessOrder) do
                        if key == k then
                            table.remove(storageAccessOrder, i)
                            break
                        end
                    end
                    table.insert(storageAccessOrder, k)
                    return fakeRealEnvStorage[k]
                end

                local keyStr = tostring(k)
                local dangerousPatterns = {
                    "package", "io", "os", "debug", "require", "loadfile", "dofile",
                    "_fs", "_process", "_require", "_luau", "_stdio"
                }

                for _, pattern in ipairs(dangerousPatterns) do
                    if keyStr == pattern or keyStr:find(pattern, 1, true) then
                        return nil
                    end
                end

                return env[k]
            end,
            __newindex = function(t, k, v)
                local count = 0
                for _ in pairs(fakeRealEnvStorage) do
                    count = count + 1
                end

                if count >= MAX_STORAGE then
                    if #storageAccessOrder > 0 then
                        local lruKey = table.remove(storageAccessOrder, 1)
                        fakeRealEnvStorage[lruKey] = nil
                        logAPICall("security_info", string.format("getrenv() LRU evicted key: %s", tostring(lruKey)))
                    else
                        logAPICall("security_block", "getrenv() storage limit reached (no LRU data)")
                        return
                    end
                end

                local keyStr = tostring(k)
                local dangerousPatterns = {
                    "package", "io", "os", "debug", "require", "loadfile", "dofile"
                }

                for _, pattern in ipairs(dangerousPatterns) do
                    if keyStr == pattern or keyStr:find(pattern, 1, true) then
                        return
                    end
                end

                fakeRealEnvStorage[k] = v
                table.insert(storageAccessOrder, k)
            end,
        })
        return fakeRealEnv
    end

    env.getsenv = function(script)
        logAPICall("function_call", "getsenv(script)")
        return setmetatable({}, {
            __index = function(t, k)
                if GLOBAL_GETSENV_STORAGE[k] ~= nil then
                    for i, key in ipairs(GLOBAL_GETSENV_LRU) do
                        if key == k then table.remove(GLOBAL_GETSENV_LRU, i) break end
                    end
                    table.insert(GLOBAL_GETSENV_LRU, k)
                    return GLOBAL_GETSENV_STORAGE[k]
                end
                local keyStr = tostring(k)
                local dangerousPatterns = {"package", "io", "os", "debug", "require", "loadfile", "dofile", "_fs", "_process", "_require", "_luau", "_stdio"}
                for _, pattern in ipairs(dangerousPatterns) do
                    if keyStr == pattern or keyStr:find(pattern, 1, true) then return nil end
                end
                return env[k]
            end,
            __newindex = function(t, k, v)
                if RESOURCE_USAGE.envStorage >= LIMITS.GLOBAL_ENV_STORAGE then
                    if #GLOBAL_GETSENV_LRU > 0 then
                        local lruKey = table.remove(GLOBAL_GETSENV_LRU, 1)
                        GLOBAL_GETSENV_STORAGE[lruKey] = nil
                        RESOURCE_USAGE.envStorage = RESOURCE_USAGE.envStorage - 1
                    else return end
                end
                local keyStr = tostring(k)
                local dangerousPatterns = {"package", "io", "os", "debug", "require", "loadfile", "dofile"}
                for _, pattern in ipairs(dangerousPatterns) do
                    if keyStr == pattern or keyStr:find(pattern, 1, true) then return end
                end
                GLOBAL_GETSENV_STORAGE[k] = v
                table.insert(GLOBAL_GETSENV_LRU, k)
                RESOURCE_USAGE.envStorage = RESOURCE_USAGE.envStorage + 1
            end,
        })
    end

    env.isfile = function(path)
        logAPICall("security_block", string.format("isfile(%s)", formatValue(path)))
        return false
    end
    env.readfile = function(path)
        logAPICall("security_block", string.format("readfile(%s)", formatValue(path)))
        return ""
    end
    env.writefile = function(path, content)
        logAPICall("security_block", string.format("writefile(%s, ...)", formatValue(path)))
    end
    env.appendfile = function(path, content)
        logAPICall("security_block", string.format("appendfile(%s, ...)", formatValue(path)))
    end
    env.delfile = function(path)
        logAPICall("security_block", string.format("delfile(%s)", formatValue(path)))
    end
    env.listfiles = function(path)
        logAPICall("security_block", string.format("listfiles(%s)", formatValue(path)))
        return {}
    end
    env.makefolder = function(path)
        logAPICall("security_block", string.format("makefolder(%s)", formatValue(path)))
    end
    env.mkdir = function(path)
        logAPICall("security_block", string.format("mkdir(%s)", formatValue(path)))
    end
    env.delfolder = function(path)
        logAPICall("security_block", string.format("delfolder(%s)", formatValue(path)))
    end
    env.isfolder = function(path)
        logAPICall("security_block", string.format("isfolder(%s)", formatValue(path)))
        return false
    end

    env.setclipboard = function(text)
        recordClipboardValue(text)
        logAPICall("function_call", string.format("setclipboard(%s)", formatValue(text)))
    end
    env.getclipboard = function()
        logAPICall("function_call", "getclipboard()")
        return ""
    end

    env.hookfunction = function(original, hook)
        logAPICall("function_call", "hookfunction(function, hook)")
        if type(original) == "function" and type(hook) == "function" then
            hookRegistry[original] = hook
            executorClosureRegistry[hook] = true
        end
        return original
    end
    env.hookmetamethod = function(object, method, hook)
        logAPICall("function_call", string.format("hookmetamethod(object, %s, hook)", formatValue(method)))
        local methodName = tostring(method)
        local objectHooks = metamethodHooks[object]
        if not objectHooks then
            objectHooks = {}
            metamethodHooks[object] = objectHooks
        end
        local previous = objectHooks[methodName]
        if previous == nil and type(env.getrawmetatable) == "function" then
            local mt = env.getrawmetatable(object)
            if type(mt) == "table" then
                previous = rawget(mt, methodName)
            end
        end
        if type(hook) == "function" then
            objectHooks[methodName] = hook
            executorClosureRegistry[hook] = true
            if type(env.getrawmetatable) == "function" then
                local mt = env.getrawmetatable(object)
                if type(mt) == "table" then
                    rawset(mt, methodName, hook)
                end
            end
        end
        return previous or function() end
    end
    env.getnamecallmethod = function()
        logAPICall("function_call", "getnamecallmethod()")
        return namecallMethod
    end
    env.setnamecallmethod = function(method)
        logAPICall("function_call", string.format("setnamecallmethod(%s)", formatValue(method)))
        local previous = namecallMethod
        namecallMethod = tostring(method or "")
        return previous
    end
    env.get_namecall_method = env.getnamecallmethod
    env.set_namecall_method = env.setnamecallmethod
    env.checkcaller = function()
        logAPICall("function_call", "checkcaller()")
        return false
    end
    env.islclosure = function(f)
        logAPICall("function_call", string.format("islclosure(%s)", formatValue(f)))
        return type(f) == "function" and not isNativeLikeFunction(f)
    end
    env.iscclosure = function(f)
        logAPICall("function_call", string.format("iscclosure(%s)", formatValue(f)))
        return isNativeLikeFunction(f)
    end
    env.newcclosure = function(f)
        logAPICall("function_call", string.format("newcclosure(%s)", formatValue(f)))
        if type(f) == "function" then
            cclosureRegistry[f] = true
            executorClosureRegistry[f] = true
        end
        return f
    end
    env.newlclosure = function(f)
        logAPICall("function_call", string.format("newlclosure(%s)", formatValue(f)))
        if type(f) == "function" then
            executorClosureRegistry[f] = true
        end
        return f
    end
    env.isexecutorclosure = function(f)
        logAPICall("function_call", string.format("isexecutorclosure(%s)", formatValue(f)))
        return executorClosureRegistry[f] == true
    end
    env.isourclosure = function(f)
        logAPICall("function_call", string.format("isourclosure(%s)", formatValue(f)))
        return executorClosureRegistry[f] == true
    end
    env.is_synapse_function = env.isourclosure
    env.iskrnlclosure = env.isourclosure
    env.isexecutorfunction = env.isexecutorclosure
    env.isourfunction = env.isourclosure
    env.isfunction = function(f)
        logAPICall("function_call", string.format("isfunction(%s)", formatValue(f)))
        return type(f) == "function"
    end
    env.ishooked = function(f)
        logAPICall("function_call", string.format("ishooked(%s)", formatValue(f)))
        return hookRegistry[f] ~= nil
    end
    env.IsHooked = function(f)
        logAPICall("function_call", string.format("IsHooked(%s)", formatValue(f)))
        return hookRegistry[f] ~= nil
    end
    env.isfunctionhooked = function(f)
        logAPICall("function_call", string.format("isfunctionhooked(%s)", formatValue(f)))
        return hookRegistry[f] ~= nil
    end
    env.restorefunction = function(f)
        logAPICall("function_call", string.format("restorefunction(%s)", formatValue(f)))
        hookRegistry[f] = nil
        return f
    end
    env.clonefunction = function(f)
        logAPICall("function_call", string.format("clonefunction(%s)", formatValue(f)))
        if type(f) == "function" then
            executorClosureRegistry[f] = executorClosureRegistry[f] or cclosureRegistry[f] or hookRegistry[f] ~= nil
        end
        return f
    end
    env.cloneref = function(obj)
        logAPICall("function_call", "cloneref(object)")
        return obj
    end

    env.getrawmetatable = function(obj)
        logAPICall("function_call", "getrawmetatable(object)")
        local mt = env.getmetatable(obj)
        if mt ~= nil then
            return mt
        end
        if env.debug and type(env.debug.getmetatable) == "function" then
            return env.debug.getmetatable(obj)
        end
        return nil
    end

    env.setrawmetatable = function(obj, mt)
        logAPICall("function_call", "setrawmetatable(object, metatable)")
        if type(obj) == "table" then
            return env.setmetatable(obj, mt)
        end
        if env.debug and type(env.debug.setmetatable) == "function" then
            return env.debug.setmetatable(obj, mt)
        end
        return obj
    end

    env.getscriptclosure = function(script)
        logAPICall("function_call", "getscriptclosure(script)")
        return function() end
    end

    env.getscripthash = function(script)
        logAPICall("function_call", "getscripthash(script)")
        return "0000000000000000"
    end

    env.getthreadidentity = function()
        logAPICall("function_call", "getthreadidentity()")
        return 8
    end

    env.setthreadidentity = function(identity)
        logAPICall("function_call", string.format("setthreadidentity(%d)", identity))
    end

    env.getidentity = function()
        logAPICall("function_call", "getidentity()")
        return 8
    end

    env.setidentity = function(identity)
        logAPICall("function_call", string.format("setidentity(%d)", identity))
    end

    env.syn = {
        request = function(options)
            return fakeHttpResponse("syn.request", options)
        end
    }
    env.http = {
        request = function(options)
            return fakeHttpResponse("http.request", options)
        end
    }


    if not env.debug then env.debug = {} end
    env.debug.getregistry = function()
        logAPICall("security_block", "debug.getregistry()")
        return {}
    end
    env.debug.getenv = function(target)
        logAPICall("function_call", "debug.getenv(function)")
        return env._G or env
    end
    env.debug.setenv = function(target, value)
        logAPICall("function_call", "debug.setenv(function, env)")
        return target
    end
    env.debug.gethook = function(thread)
        logAPICall("function_call", "debug.gethook(thread)")
        return nil, "", 0
    end
    env.debug.sethook = function(thread, hook, mask, count)
        logAPICall("function_call", "debug.sethook(thread, hook, mask, count)")
    end
    env.debug.getupvalues = function(f)
        logAPICall("function_call", "debug.getupvalues(function)")
        return {}
    end
    env.debug.getupvalue = function(f, index)
        logAPICall("function_call", string.format("debug.getupvalue(function, %d)", index))
        return nil, nil
    end
    env.debug.setupvalue = function(f, index, value)
        logAPICall("function_call", string.format("debug.setupvalue(function, %d, value)", index))
        return nil
    end
    env.debug.getconstants = function(f)
        logAPICall("function_call", "debug.getconstants(function)")
        return {}
    end
    env.debug.getconstant = function(f, index)
        logAPICall("function_call", string.format("debug.getconstant(function, %d)", index))
        return nil
    end
    env.debug.setconstant = function(f, index, value)
        logAPICall("function_call", string.format("debug.setconstant(function, %d, value)", index))
    end
    env.debug.getprotos = function(f)
        logAPICall("function_call", "debug.getprotos(function)")
        return {}
    end
    env.debug.getproto = function(f, index, activated)
        logAPICall("function_call", string.format("debug.getproto(function, %d, %s)", index, tostring(activated)))
        return nil
    end
    env.debug.getstack = function(level, index)
        logAPICall("function_call", string.format("debug.getstack(%d, %d)", level, index or 1))
        return nil
    end
    env.debug.getinfo = function(func, options)
        logAPICall("function_call", string.format("debug.getinfo(function, %s)", formatValue(options)))
        return makeDebugRecord(func, options)
    end
    env.debug.setstack = function(level, index, value)
        logAPICall("function_call", string.format("debug.setstack(%d, %d, value)", level, index))
    end
    env.debug.traceback = debug.traceback
    env.debug.profilebegin = function(label)
        logAPICall("function_call", string.format("debug.profilebegin(%s)", formatValue(label)))
    end
    env.debug.profileend = function()
        logAPICall("function_call", "debug.profileend()")
    end

    env.debug.getfenv = function(func, level)
        logAPICall("function_call", string.format("debug.getfenv(function, %s)", formatValue(level)))
        return cachedFenv
    end

    local customMetatables = setmetatable({}, {__mode = "k"})

    local function customArithmeticNumber(value: any): number
        local numberValue = tonumber(value)
        if numberValue ~= nil then
            return numberValue
        end
        return 0
    end

    local function buildScalarMetatable(includeStringIndex: boolean?): {[any]: any}
        local scalarMt = {
            __pow = function(a, b)
                return customArithmeticNumber(a) ^ customArithmeticNumber(b)
            end,
            __add = function(a, b)
                return customArithmeticNumber(a) + customArithmeticNumber(b)
            end,
            __sub = function(a, b)
                return customArithmeticNumber(a) - customArithmeticNumber(b)
            end,
            __mul = function(a, b)
                return customArithmeticNumber(a) * customArithmeticNumber(b)
            end,
            __div = function(a, b)
                local numB = customArithmeticNumber(b)
                if numB ~= 0 then
                    return customArithmeticNumber(a) / numB
                end
                return 0
            end,
            __mod = function(a, b)
                local numB = customArithmeticNumber(b)
                if numB ~= 0 then
                    return customArithmeticNumber(a) % numB
                end
                return 0
            end,
            __unm = function(a)
                return -customArithmeticNumber(a)
            end,
        }
        if includeStringIndex then
            scalarMt.__index = string
        end
        return scalarMt
    end

    env.debug.getmetatable = function(obj)
        logAPICall("function_call", "debug.getmetatable(object)")

        local objType = type(obj)
        if obj == nil then
            return customMetatables["__nil__"]
        end

        if type(obj) == "function" then
            return nil
        end

        if customMetatables[obj] then
            return customMetatables[obj]
        end

        if objType == "string" then
            if not customMetatables["__string__"] then
                customMetatables["__string__"] = buildScalarMetatable(true)
            end
            return customMetatables["__string__"]
        end

        if objType == "number" or objType == "boolean" then
            local key = "__" .. objType .. "__"
            if not customMetatables[key] then
                customMetatables[key] = buildScalarMetatable(false)
            end
            return customMetatables[key]
        end

        return {}
    end

    env.debug.setmetatable = function(obj, mt)
        logAPICall("function_call", "debug.setmetatable(object, metatable)")
        local objType = type(obj)
        if obj == nil then
            customMetatables["__nil__"] = mt
        elseif objType == "string" then
            customMetatables["__string__"] = mt
        elseif objType == "number" or objType == "boolean" then
            customMetatables["__" .. objType .. "__"] = mt
        else
            customMetatables[obj] = mt
        end
        return obj
    end

    env.__revealr_mark_cclosure = function(container: any)
        if type(container) == "function" then
            cclosureRegistry[container] = true
        elseif type(container) == "table" then
            pcall(function()
                for _, value in pairs(container) do
                    if type(value) == "function" then
                        cclosureRegistry[value] = true
                    elseif type(value) == "table" then
                        pcall(function()
                            for _, child in pairs(value) do
                                if type(child) == "function" then
                                    cclosureRegistry[child] = true
                                end
                            end
                        end)
                    end
                end
            end)
        end
    end
    env.__revealr_mark_cclosure(env)

    if table.freeze then
        for _, lib in ipairs({env.math, env.string, env.table, env.utf8, env.bit32, env.bit}) do
            if type(lib) == "table" then
                readonlyTables[lib] = true
                pcall(table.freeze, lib)
            end
        end
    end

    env._ENV = sandboxed_G


    return env
end

local hookOpRecoveryCounts: {[string]: number} = {}
local hookOpRecoveryDetails: {[string]: {
    line: number,
    operator: string,
    leftType: string,
    rightType: string,
    detail: string,
}} = {}
local hookOpRecoveryTotal = 0

local function installHookOpRuntime(env: {[string]: any})
    local function recordRecovery(operator: string, left: any, right: any, line: number?, detail: any)
        hookOpRecoveryTotal += 1
        local key = string.format("%s:%s:%s", operator, type(left), type(right))
        hookOpRecoveryCounts[key] = (hookOpRecoveryCounts[key] or 0) + 1
        local cleanDetail = tostring(detail):gsub("[\r\n]+", " "):sub(1, 140)
        cleanDetail = cleanDetail:match("(attempt to .*)") or cleanDetail
        if not hookOpRecoveryDetails[key] then
            hookOpRecoveryDetails[key] = {
                line = tonumber(line) or 0,
                operator = operator,
                leftType = type(left),
                rightType = type(right),
                detail = cleanDetail,
            }
        end
    end

    local function arithmeticNumber(value: any, defaultValue: number): number
        local converted = tonumber(value)
        if converted ~= nil then
            return converted
        end
        return defaultValue
    end

    local function hookCallFallback(target: any, line: number?, detail: any): any
        recordRecovery("call", target, nil, line, detail)
        local resultId = newVarId()
        logAPICall("function_call", string.format("hook_call(%s)", formatValue(target)), resultId)
        registerVariable(resultId, "result", nil, nil)
        return createProxy(resultId, "result")
    end

    local function isRecoverableHookCallError(detail: any): boolean
        local message = tostring(detail)
        return message:find("attempt to call a nil value", 1, true) ~= nil
            or message:find("attempt to call a table value", 1, true) ~= nil
            or message:find("attempt to call a userdata value", 1, true) ~= nil
    end

    rawset(env, "__ENV2_HOOK_CALL", function(target: any, line: number?, ...: any)
        local targetType = type(target)

        if targetType == "function" then
            local results = table.pack(pcall(target, ...))
            if results[1] then
                return table.unpack(results, 2, results.n)
            end
            if isWatchdogError(results[2]) then
                error(results[2], 0)
            end
            if not isRecoverableHookCallError(results[2]) then
                error(results[2], 0)
            end
            return hookCallFallback(target, line, results[2])
        end

        if targetType == "table" or targetType == "userdata" then
            local mt = getmetatable(target)
            local call = type(mt) == "table" and mt.__call or nil
            if type(call) == "function" then
                local results = table.pack(pcall(call, target, ...))
                if results[1] then
                    return table.unpack(results, 2, results.n)
                end
                if isWatchdogError(results[2]) then
                    error(results[2], 0)
                end
                if not isRecoverableHookCallError(results[2]) then
                    error(results[2], 0)
                end
                return hookCallFallback(target, line, results[2])
            end
        end

        return hookCallFallback(target, line, "attempt to call a " .. targetType .. " value")
    end)

    rawset(env, "__ENV2_HOOK_OP", function(operator: string, left: any, right: any, line: number?)
        local ok, result = pcall(function()
            if operator == "+" then return left + right end
            if operator == "-" then return left - right end
            if operator == "*" then return left * right end
            if operator == "/" then return left / right end
            if operator == "//" then return left // right end
            if operator == "%" then return left % right end
            if operator == "^" then return left ^ right end
            if operator == ".." then return left .. right end
            if operator == "<" then return left < right end
            if operator == "<=" then return left <= right end
            if operator == ">" then return left > right end
            if operator == ">=" then return left >= right end
            if operator == "==" then return left == right end
            if operator == "~=" then return left ~= right end
            if operator == "&" then return bit32.band(left, right) end
            if operator == "|" then return bit32.bor(left, right) end
            if operator == "~" then return bit32.bxor(left, right) end
            if operator == "<<" then return bit32.lshift(left, right) end
            if operator == ">>" then return bit32.rshift(left, right) end
            error("unsupported operator " .. tostring(operator), 0)
        end)
        if ok then
            return result
        end

        recordRecovery(operator, left, right, line, result)
        if operator == ".." then
            return (left == nil and "" or tostring(left)) .. (right == nil and "" or tostring(right))
        end
        if operator == "==" then return false end
        if operator == "~=" then return true end
        if operator == "<" or operator == "<=" or operator == ">" or operator == ">=" then
            return false
        end

        local leftNumber = arithmeticNumber(left, 0)
        local rightDefault = (operator == "/" or operator == "//" or operator == "%") and 1 or 0
        local rightNumber = arithmeticNumber(right, rightDefault)
        if operator == "+" then return leftNumber + rightNumber end
        if operator == "-" then return leftNumber - rightNumber end
        if operator == "*" then return leftNumber * rightNumber end
        if operator == "/" then return rightNumber == 0 and 0 or leftNumber / rightNumber end
        if operator == "//" then return rightNumber == 0 and 0 or leftNumber // rightNumber end
        if operator == "%" then return rightNumber == 0 and 0 or leftNumber % rightNumber end
        if operator == "^" then return leftNumber ^ rightNumber end
        if operator == "&" then return bit32.band(leftNumber, rightNumber) end
        if operator == "|" then return bit32.bor(leftNumber, rightNumber) end
        if operator == "~" then return bit32.bxor(leftNumber, rightNumber) end
        if operator == "<<" then return bit32.lshift(leftNumber, rightNumber) end
        if operator == ">>" then return bit32.rshift(leftNumber, rightNumber) end
        return 0
    end)

    rawset(env, "__ENV2_HOOK_INDEX", function(base: any, key: any, line: number?)
        local ok, result = pcall(function()
            return base[key]
        end)
        if ok then
            return result
        end

        recordRecovery("index", base, key, line, result)
        if type(key) == "number" then
            return 0
        end
        return nil
    end)

    rawset(env, "__ENV2_HOOK_SET", function(base: any, key: any, value: any, line: number?)
        local ok, result = pcall(function()
            base[key] = value
            return value
        end)
        if ok then
            return result
        end

        recordRecovery("newindex", base, key, line, result)
        return value
    end)

    rawset(env, "__ENV2_HOOK_UNARY", function(operator: string, value: any, line: number?)
        local ok, result = pcall(function()
            if operator == "-" then return -value end
            if operator == "#" then return #value end
            if operator == "~" then return bit32.bnot(value) end
            error("unsupported unary operator " .. tostring(operator), 0)
        end)
        if ok then
            return result
        end

        recordRecovery("unary" .. operator, value, nil, line, result)
        if operator == "#" then
            return type(value) == "string" and #value or 0
        end
        if operator == "~" then
            return bit32.bnot(arithmeticNumber(value, 0))
        end
        return -arithmeticNumber(value, 0)
    end)
end


local function escapeLuaPattern(value: string): string
    return value:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
end

local function isIdentifierLike(value: string): boolean
    return value:match("^[A-Za-z_][A-Za-z0-9_]*$") ~= nil
end

local function normalizeMethodSyntax(line: string): string
    local normalized = line
    normalized = normalized:gsub("([A-Za-z_][A-Za-z0-9_%.]*)%.([A-Za-z_][A-Za-z0-9_]*)%(([%w_%.]+),%s*", function(base, method, firstArg)
        if firstArg == base then
            return base .. ":" .. method .. "("
        end
        return nil
    end)
    normalized = normalized:gsub("([A-Za-z_][A-Za-z0-9_%.]*)%.([A-Za-z_][A-Za-z0-9_]*)%(([%w_%.]+)%)", function(base, method, firstArg)
        if firstArg == base then
            return base .. ":" .. method .. "()"
        end
        return nil
    end)
    return normalized
end

local function identifierReferencedAfter(startIndex: number, identifier: string): boolean
    local pattern = "%f[%w_]" .. escapeLuaPattern(identifier) .. "%f[^%w_]"
    for i = startIndex + 1, #apiCalls do
        if apiCalls[i].code:find(pattern) then
            return true
        end
    end
    return false
end

local function shouldEmitReconstructedCall(line: string): boolean
    if line:match("^%s*$") or line:match("^%s*%-%-") then
        return false
    end
    if LIMITS.COMPACT_DUMP then
        if line:match("^trace_event_truncated%(") then
            return false
        end
        if line:match("^table%.pack%(%s*%-?%d+%.?%d*%s*,%s*%-?%d+%.?%d*%s*%)$") then
            return false
        end
        if line:match("^table%.pack%(") and (#line > 240 or line:find("Synapse X (ENV)|", 1, true)) then
            return false
        end
        if line:match("^table%.pack%({%[1%] = ") then
            return false
        end
        if line:match("^table%.pack%({") and (#line > 240 or not line:find('"', 1, true)) then
            return false
        end
        if line:match("^table%.create%(%s*%d+%s*,%s*nil%s*%)$") then
            return false
        end
        if line:match("^type%(%s*%-?%d+%.?%d*%s*%)$") then
            return false
        end
    end
    if line:find("task thread error:", 1, true)
        or line:find("pcall error:", 1, true)
        or line:find("LRU evicted", 1, true)
        or line:find("storage limit", 1, true)
        or line:find("anti-tamper branch blocked", 1, true) then
        return false
    end
    if line:match("^Blocked%s") then
        return false
    end
    if line:match("^pcall%(function")
        or line:match("^xpcall%(function") then
        return false
    end
    if line == "debug.setmetatable(object, metatable)"
        or line == "debug.getmetatable(object)"
        or line == "setmetatable(object, metatable)"
        or line == "getmetatable(object)" then
        return false
    end
    if line:match("^type%([%a]+: 0x[%da-fA-F]+%)$") then
        return false
    end
    if line:find(" recovered from invalid arguments", 1, true)
        or line:find(" recovered from nil table", 1, true) then
        return false
    end
    if line:find("string.match(\"[string ", 1, true) == 1
        or line:find("string.match(nil,", 1, true) == 1
        or line:find("type(\"[string ", 1, true) == 1
        or line:find("error([string ", 1, true) == 1
        or line:find("error(\"[string ", 1, true) == 1 then
        return false
    end
    if line:match("^__remote_stub%(") then
        return false
    end
    local missingGlobalPath = line:match("^missing_global%.([^%(]+)")
    if missingGlobalPath and not missingGlobalPath:match("^[A-Za-z_][A-Za-z0-9_%.]*$") then
        return false
    end
    if line == "table.pack()" then
        return false
    end
    if line == "pairs(table)" or line == "ipairs(table)" then
        return false
    end
    if line:match("^table:insert%(") then
        return false
    end
    if line:match("^table:concat%(") then
        return false
    end
    if line:match("^table:unpack%(") or line:match("^table%.unpack%(") then
        return false
    end
    if line:match("^table:remove%(") or line:match("^table%.remove%(") then
        return false
    end
    if line:match("^table:sort%(") or line:match("^table%.sort%(") then
        return false
    end
    if line:match("^bit32%.") or line:match("^bit%.") then
        return false
    end
    if line:match("^string%.byte%(") or line:match("^string%.sub%(") or line:match("^string%.len%(") then
        return false
    end
    if line:match("^string%.rep%(") then
        return false
    end
    if line:match("^string%.reverse%(") then
        return false
    end
    if line:find("string.match(\"\",", 1, true) == 1 then
        return false
    end
    local loweredLiteral = line:match("^string%.lower%(%\"([^%\"]*)%\"%)$")
    if loweredLiteral and #loweredLiteral <= 12 and not looksLikeUsefulStaticString(loweredLiteral) then
        return false
    end
    if #line > 500 and line:match("^string%.gsub%(") then
        return false
    end
    if line:match("^string%.char%([%d%s,%-%.]+%)$") then
        return false
    end
    if line:match("^type%(%a+%)$") then
        return false
    end
    if line:match("^type%({")
        and (line:find("__index = {", 1, true) or line:find("__add = function", 1, true))
        and line:find("function(...) end", 1, true) then
        return false
    end
    if #line > 500 and line:match("^type%(") and line:find("\\x00", 1, true) then
        return false
    end
    local formatLeft, formatRight = line:match('^string%.format%("%%s%%s", "(.-)", "(.-)"%)$')
    if formatLeft and formatLeft == formatRight and (
        #formatLeft == 1
        or formatLeft:match("^\\x%x%x$") ~= nil
        or formatLeft == "\\n"
        or formatLeft == "\\t"
    ) then
        return false
    end
    if line:match("^math%.") then
        return false
    end
    if line:find("attempt to perform arithmetic (pow) on string and number", 1, true) then
        return false
    end
    if line:find("Tamper Detected", 1, true) then
        return false
    end
    return true
end

local function isNilArithmeticError(errorMsg: string): boolean
    return errorMsg:find("attempt to perform arithmetic", 1, true) ~= nil
        and errorMsg:find("nil", 1, true) ~= nil
end

local function isRecoverableHookOpError(errorMsg: string): boolean
    if isNilArithmeticError(errorMsg) then
        return true
    end
    return errorMsg:find("attempt to compare", 1, true) ~= nil
        or errorMsg:find("attempt to perform arithmetic", 1, true) ~= nil
        or errorMsg:find("attempt to concatenate", 1, true) ~= nil
        or errorMsg:find("attempt to get length", 1, true) ~= nil
        or errorMsg:find("attempt to index nil", 1, true) ~= nil
        or errorMsg:find("attempt to call a nil value", 1, true) ~= nil
        or errorMsg:find("attempt to call a table value", 1, true) ~= nil
end

local function reconstructCode(): {string}
    local output: {string} = {}
    local indent = 0

    local function write(line: string)
        table.insert(output, string.rep("    ", indent) .. line)
    end

    local function writeSection(title: string)
        write("-- " .. title)
    end

    local function traceHasLiteral(value: string): boolean
        local literal = formatValue(value)
        for _, call in ipairs(apiCalls) do
            if call.type ~= "decoded_string"
                and (call.code:find(literal, 1, true) or call.code:find(value, 1, true)) then
                return true
            end
        end
        return false
    end

    local function emitStaticHints()
        if #staticHintValues == 0 then
            return
        end
        write("local __revealr_static_literals = {}")
        local emitted = 0
        for _, hint in ipairs(staticHintValues) do
            if emitted >= 1000 then
                break
            end
            emitted += 1
            write(string.format(
                "__revealr_static_literals[%d] = {kind = %s, value = %s}",
                emitted,
                formatValue(hint.kind),
                formatValue(hint.value)
            ))
        end
        write("")
    end

    local function emitDecodedStrings()
        local emitted = 0
        for _, value in ipairs(decodedStringValues) do
            if emitted >= 300 then
                break
            end
            if isUsefulDecodedString(value, 3) and not traceHasLiteral(value) then
                if emitted == 0 then
                    write("local __revealr_decoded = {}")
                end
                emitted += 1
                write(string.format("__revealr_decoded[%d] = %s", emitted, formatValue(value)))
            end
        end
        if emitted > 0 then
            write("")
        end
    end

    local function emitLoadedChunks()
        if #loadedChunks == 0 then
            return
        end
        write("local __revealr_chunks = {}")
        local maxChunkBody = math.max(32768, tonumber(process.env.ENV2_DUMP_CHUNK_BODY or "") or LIMITS.MAX_CHUNK_SIZE)
        for index, chunk in ipairs(loadedChunks) do
            local info = loadedChunkInfo[index]
            local body = chunk
            local truncated = #body > maxChunkBody
            if truncated then
                body = body:sub(1, maxChunkBody)
            end
            write(string.format(
                "__revealr_chunks[%d] = {name = %s, originalSize = %d, processedSize = %d, truncated = %s, body = %s}",
                index,
                formatValue(info and info.name or ("chunk_" .. tostring(index))),
                info and info.originalSize or #chunk,
                info and info.processedSize or #chunk,
                tostring(truncated),
                '"' .. escapeLuaString(body) .. '"'
            ))
        end
        write("")
    end

    local function emitExternalTrace()
        if #externalTraceEvents == 0 and not externalTraceResult and #externalTraceSuppressionOrder == 0 then
            return
        end
        write(string.format(
            "local __revealr_external_trace = {steps = %d, dropped = %d, result = %s, events = {}, suppressed = {}}",
            externalTraceSteps,
            externalTraceDropped,
            formatValue(externalTraceResult or "unknown")
        ))
        for index, event in ipairs(externalTraceEvents) do
            write(string.format(
                "__revealr_external_trace.events[%d] = {kind = %s, detail = %s}",
                index,
                formatValue(event.kind),
                formatValue(event.detail)
            ))
        end
        for index, key in ipairs(externalTraceSuppressionOrder) do
            local event = externalTraceSuppressions[key]
            if event then
                write(string.format(
                    "__revealr_external_trace.suppressed[%d] = {kind = %s, detail = %s, kept = %d, suppressed = %d}",
                    index,
                    formatValue(event.kind),
                    formatValue(event.detail),
                    event.kept,
                    event.count
                ))
            end
        end
        write("")
    end

    local function emitHookOpRecoveries()
        local recoveryKeys = {}
        for key in pairs(hookOpRecoveryDetails) do
            table.insert(recoveryKeys, key)
        end
        table.sort(recoveryKeys)
        if #recoveryKeys == 0 then
            return
        end
        write("local __revealr_hookop = {}")
        for index, key in ipairs(recoveryKeys) do
            local detail = hookOpRecoveryDetails[key]
            write(string.format(
                "__revealr_hookop[%d] = {line = %d, operator = %s, leftType = %s, rightType = %s, count = %d, detail = %s}",
                index,
                detail.line,
                formatValue(detail.operator),
                formatValue(detail.leftType),
                formatValue(detail.rightType),
                hookOpRecoveryCounts[key] or 1,
                formatValue(detail.detail)
            ))
        end
        write("")
    end

    local function emitSuppressedTrace()
        local hasEvents = false
        for _, key in ipairs(apiRepeatOrder) do
            local entry = apiRepeatSuppressions[key]
            if entry and entry.count > 0 then
                hasEvents = true
                break
            end
        end

        if not hasEvents and #loadedChunkRepeats == 0 then
            return
        end

        write("local __revealr_suppressed = {events = {}, chunks = {}}")
        local eventIndex = 0
        for _, key in ipairs(apiRepeatOrder) do
            local entry = apiRepeatSuppressions[key]
            if entry and entry.count > 0 then
                eventIndex += 1
                write(string.format(
                    "__revealr_suppressed.events[%d] = {type = %s, key = %s, kept = %d, suppressed = %d, sample = %s}",
                    eventIndex,
                    formatValue(entry.type),
                    formatValue(entry.key),
                    math.min(apiRepeatCounts[key] or LIMITS.REPEAT_TRACE_LIMIT, LIMITS.REPEAT_TRACE_LIMIT),
                    entry.count,
                    formatValue(entry.sample)
                ))
            end
        end

        for index, entry in ipairs(loadedChunkRepeats) do
            write(string.format(
                "__revealr_suppressed.chunks[%d] = {name = %s, kept = %d, suppressed = %d, originalSize = %d, processedSize = %d, preview = %s}",
                index,
                formatValue(entry.name),
                LIMITS.LOAD_REPEAT_LIMIT,
                entry.count,
                entry.originalSize,
                entry.processedSize,
                formatValue(entry.preview)
            ))
        end
        write("")
    end

    local function emitVMTrace()
        if #vmInstructions == 0 and #vmCalls == 0 then
            return
        end

        local function inferRuntimeInstruction(trace: VMInstructionTrace): string
            local operandShape = trace.shape:sub(2)
            if trace.opcodeType == "string" then
                return "NAMED_OR_ENCRYPTED"
            elseif operandShape == "ns" then
                return "GETGLOBAL_OR_LOADK"
            elseif operandShape == "nns" then
                return "GETTABLE_OR_SETTABLE"
            elseif operandShape == "nnb" then
                return "TEST_OR_BRANCH"
            elseif operandShape == "nnn" then
                return "ABC_CALL_OR_ARITH"
            elseif operandShape == "nn" then
                return "MOVE_JUMP_OR_LOADK"
            elseif operandShape == "n" then
                return "UNARY_OR_RETURN"
            end
            return "CUSTOM"
        end

        if LIMITS.VM_TRACE_FULL and #vmInstructions > 0 then
            write("local __revealr_vm_instructions = {}")
            for index, trace in ipairs(vmInstructions) do
                local sources = {}
                for source in pairs(trace.sources) do
                    table.insert(sources, source)
                end
                table.sort(sources)
                write(string.format(
                    "__revealr_vm_instructions[%d] = {raw = %s, opcodeType = %s, shape = %s, inferred = %s, observations = %d, sources = %s, operands = %s}",
                    index,
                    formatValue(trace.opcode),
                    formatValue(trace.opcodeType),
                    formatValue(trace.shape),
                    formatValue(inferRuntimeInstruction(trace)),
                    trace.observations,
                    formatValue(sources),
                    formatValue(trace.operands)
                ))
            end
            write("")
        end

        if #vmCalls > 0 then
            local counts: {[string]: number} = {}
            for _, call in ipairs(vmCalls) do
                counts[call] = (counts[call] or 0) + 1
            end
            local ordered = {}
            for call, count in pairs(counts) do
                table.insert(ordered, {call = call, count = count})
            end
            table.sort(ordered, function(left, right)
                if left.count == right.count then
                    return left.call < right.call
                end
                return left.count > right.count
            end)
            write("local __revealr_vm_calls = {}")
            for index, entry in ipairs(ordered) do
                write(string.format(
                    "__revealr_vm_calls[%d] = {call = %s, count = %d}",
                    index,
                    formatValue(entry.call),
                    entry.count
                ))
            end
            write("")
        end
    end

    local function emitClipboardValues()
        if #clipboardValues == 0 then
            return
        end
        for _, text in ipairs(clipboardValues) do
            local value = text
            if #value > 65536 then
                value = value:sub(1, 65536)
            end
            write('setclipboard("' .. escapeLuaString(value) .. '")')
        end
        write("")
    end

    local function emitReportLines()
        if #reportLines == 0 then
            return
        end
        for _, line in ipairs(reportLines) do
            write('print("' .. escapeLuaString(line) .. '")')
        end
        write("")
    end

    write(DUMP_HEADER)
    write("")
    emitClipboardValues()
    emitReportLines()
    if LIMITS.EMIT_STATIC_METADATA then
        emitStaticHints()
    end
    if LIMITS.EMIT_DECODED_METADATA then
        emitDecodedStrings()
    end
    if LIMITS.EMIT_CHUNK_METADATA then
        emitLoadedChunks()
    end
    if LIMITS.EMIT_EXTERNAL_TRACE then
        emitExternalTrace()
    end
    if LIMITS.EMIT_HOOKOP_METADATA then
        emitHookOpRecoveries()
    end
    if LIMITS.EMIT_SUPPRESSED_METADATA then
        emitSuppressedTrace()
    end
    if LIMITS.VM_TRACE_ENABLED then
        emitVMTrace()
    end
    if #reportLines > 0
        and reportLines[1]:match("^%[eUNC%] Score")
        and not envFlag("ENV2_FULL_EUNC_TRACE") then
        return output
    end

    if #output > 0 then
        write("")
    end
    local declaredVars: {[string]: boolean} = {}

    local emittedLines: {[string]: boolean} = {}
    for i, call in ipairs(apiCalls) do
        local line = normalizeMethodSyntax(call.code)
        if call.type == "decoded_string" or call.type == "hook_op_recovery" or call.type == "security_info" then
            continue
        end
        if #clipboardValues > 0 and line:match("^setclipboard%(") then
            continue
        end
        if not shouldEmitReconstructedCall(line) then
            continue
        end
        local emittedBinding = false
        if call.varId and isIdentifierLike(call.varId) and not declaredVars[call.varId] then
            if identifierReferencedAfter(i, call.varId) and (call.type == "service" or call.type == "instance_new" or call.type == "property_access" or call.type == "method_call") then
                line = string.format("local %s = %s", call.varId, line)
                declaredVars[call.varId] = true
                emittedBinding = true
            end
        end
        if (call.type == "property_access" or call.type == "enum_access") and not emittedBinding then
            continue
        end
        if line:match("^%s*%-%-") then
            continue
        end
        if emittedLines[line] then
            continue
        end
        emittedLines[line] = true
        write(line)
    end

    return output
end


local function main()

    print("+--------------------------------------------------------------+")
    print("| dumper2 - environment tracer                                 |")
    print("+--------------------------------------------------------------+")
    print(string.format("[runtime] %s", runtimeName))
    print("")

    local positionalArgs: {string} = {}
    local requestedLocalCompatibility = false
    for _, argument in ipairs(process.args) do
        if argument == "-nosandbox" or argument == "--hookop" then
            requestedLocalCompatibility = true
        else
            table.insert(positionalArgs, argument)
        end
    end

    if #positionalArgs == 0 then
        print(string.format("Usage: %s run dumper2_local.luau [-nosandbox|--hookop] <script.lua> [output.lua]", runtimeName))
        print("")
        print("-nosandbox is kept as a compatibility alias for --hookop.")
        print("Analyzed scripts still run inside the host-protection sandbox.")
        return
    end

    if requestedLocalCompatibility then
        print("[mode] Local adaptive hookOp compatibility enabled")
        print("[sandbox] Host filesystem, process, require, and network APIs stay isolated from analyzed code")
        print("")
    end


    local inputFile = positionalArgs[1]
    local outputFile = positionalArgs[2] or (inputFile:gsub("%.lua[u]?$", "") .. "_dump.lua")

    if not fs.isFile(inputFile) then
        print(string.format("[error] File '%s' not found", inputFile))
        return
    end

    print(string.format("[input]  %s", inputFile))
    print(string.format("[output] %s", outputFile))
    print("")

    local sourceCode = stripUtf8Bom(fs.readFile(inputFile))
    prometheusPcallCompat = sourceCode:find("wearedevs.net/obfuscator", 1, true) ~= nil
        or sourceCode:find("newproxy,setmetatable,getmetatable,select,{...})end)(...)", 1, true) ~= nil
        or sourceCode:find("newproxy, setmetatable, getmetatable, select,", 1, true) ~= nil

    local MAX_FILE_SIZE = 50 * 1024 * 1024
    if #sourceCode > MAX_FILE_SIZE then
        print(string.format("[error] File too large (%.2f MB). Maximum size is 50 MB", #sourceCode / (1024 * 1024)))
        return
    end

    if sourceCode:match("%z") then
        print("[error] Binary file detected. Only text files are supported.")
        return
    end

    print(string.format("[source] %.2f KB", #sourceCode / 1024))
    LIMITS.ALLOW_SYNTHETIC_PROXY_CALLS = LIMITS.ALLOW_SYNTHETIC_PROXY_CALLS
        or sourceCode:find("Synapse Xen", 1, true) ~= nil
        or sourceCode:find("SynapseXen_", 1, true) ~= nil

    local isRCE, matchedPattern = detectRCE(sourceCode)
    if isRCE then
        rceAlert(matchedPattern)
    end

    print("[stage] Creating tracked environment")
    harvestStaticLuraphHints(sourceCode)
    local env = createEnvironment()

    print("[stage] Applying security sandbox")
    env = createSecureEnvironment(env)
    installHookOpRuntime(env)
    if LIMITS.VM_TRACE_ENABLED then
        hookVMExecution(env)
        print("[stage] VM tracing hooks enabled")
    end
    rawset(env, WATCHDOG_GLOBAL, function(label: string?)
        executionWatchdog(label)
    end)

    local saved_package = package
    local saved_io = io
    local saved_os = os
    local saved_debug = debug
    local saved_require = require
    local saved_loadfile = loadfile
    local saved_dofile = dofile

    local canPatchHostGlobals = runtimeName ~= "lute"
    if canPatchHostGlobals then
        package = nil
        io = nil
        os = nil
        debug = nil
        require = nil
        loadfile = nil
        dofile = nil
    end

    local saved_G_package = _G.package
    local saved_G_io = _G.io
    local saved_G_os = _G.os
    local saved_G_debug = _G.debug
    local saved_G_require = _G.require
    local saved_G_loadfile = _G.loadfile
    local saved_G_dofile = _G.dofile

    if canPatchHostGlobals then
        _G.package = nil
        _G.io = nil
        _G.os = nil
        _G.debug = nil
        _G.require = nil
        _G.loadfile = nil
        _G.dofile = nil
    end

    local isLuraphSource = sourceCode:find("Luraph", 1, true) ~= nil or sourceCode:find("lura.ph", 1, true) ~= nil
    local hasUnsupportedGoto = containsKeywordOutsideLiterals(sourceCode, "goto")
    local needsWrapper = not isLuraphSource and not hasUnsupportedGoto and containsStringArithmetic(sourceCode)
    local useInitialHookOps = requestedLocalCompatibility or isLuraphSource or inputFile:lower():find("luraph", 1, true) ~= nil

    local wrappedSourceCode = sourceCode
    if needsWrapper then
        print("[compat] String arithmetic detected")
        wrappedSourceCode = [[
do
    local mt = {}
    local function toArithmeticNumber(value)
        local numberValue = tonumber(value)
        if numberValue ~= nil then
            return numberValue
        end
        return 0
    end
    mt.__pow = function(a, b)
        local numA = toArithmeticNumber(a)
        local numB = toArithmeticNumber(b)
        return numA ^ numB
    end
    mt.__add = function(a, b)
        local numA = toArithmeticNumber(a)
        local numB = toArithmeticNumber(b)
        return numA + numB
    end
    mt.__sub = function(a, b)
        local numA = toArithmeticNumber(a)
        local numB = toArithmeticNumber(b)
        return numA - numB
    end
    mt.__mul = function(a, b)
        local numA = toArithmeticNumber(a)
        local numB = toArithmeticNumber(b)
        return numA * numB
    end
    mt.__div = function(a, b)
        local numA = toArithmeticNumber(a)
        local numB = toArithmeticNumber(b)
        if numB ~= 0 then return numA / numB end
        return 0
    end
    mt.__index = string
    local scalarMt = {}
    for key, value in pairs(mt) do
        if key ~= "__index" then
            scalarMt[key] = value
        end
    end
    pcall(function()
        if debug and debug.setmetatable then
            debug.setmetatable("", mt)
            pcall(debug.setmetatable, 0, scalarMt)
            pcall(debug.setmetatable, nil, scalarMt)
        end
    end)
end

]] .. sourceCode
    end

    print("[stage] Executing script with full tracking")
    if useInitialHookOps then
        print("[compat] Hook-op tracing enabled for initial load")
    end
    print("")


    local startTime = os.clock()
    local success, err = pcall(function()
        local chunk, loadErr = advancedLoad(wrappedSourceCode, inputFile, env, useInitialHookOps)

        if not chunk then
            if hasUnsupportedGoto then
                print("[fallback] Luau does not support goto; tracing with restricted Lua 5.4")
                local fallbackAvailable, fallbackSuccess, fallbackErr = runLua54Trace(inputFile)
                if fallbackAvailable then
                    if fallbackSuccess then
                        print(string.format("[done] Lua 5.4 trace completed (%d events)", #externalTraceEvents))
                    else
                        print(string.format("[warning] Lua 5.4 trace ended with: %s", tostring(fallbackErr)))
                    end
                    return
                end
                print(string.format("[warning] Lua 5.4 fallback unavailable: %s", tostring(fallbackErr)))
            end
            error(string.format("[LUA_LOAD_FAIL] %s", tostring(loadErr)))
        end

        print("[stage] Script loaded; executing")
        print("")

        resetExecutionWatchdog("script")
        local execSuccess, result = pcall(chunk)
        stopExecutionWatchdog()

        local usedSyntheticVararg = false
        if not execSuccess and isRecoverableHookOpError(tostring(result)) then
            local originalResult = result
            local retryApiStart = #apiCalls
            print("[env2] recoverable operator error detected; retrying with sandboxed hookOp")
            local retryChunk, retryLoadErr = advancedLoad(wrappedSourceCode, inputFile .. ":hookop-retry", env, true)
            if retryChunk then
                resetExecutionWatchdog("script-hookop-retry")
                execSuccess, result = pcall(retryChunk)
                stopExecutionWatchdog()
                if not execSuccess then
                    local retryError = tostring(result)
                    if isRecoverableHookOpError(retryError) or retryError:find("stack overflow", 1, true) then
                        while #apiCalls > retryApiStart do
                            table.remove(apiCalls)
                        end
                        result = originalResult
                    end
                else
                    print("[env2] hookOp retry completed")
                end
            else
                print(string.format("[env2] hookOp retry load failed: %s", tostring(retryLoadErr)))
            end
        end

        if not execSuccess and isRecoverableHookOpError(tostring(result)) then
            local originalResult = result
            local retryApiStart = #apiCalls
            print("[env2] operator error during bootstrap; retrying with tracked top-level vararg")
            local retryChunk, retryLoadErr = advancedLoad(wrappedSourceCode, inputFile .. ":vararg-retry", env, true)
            if retryChunk then
                resetExecutionWatchdog("script-vararg-retry")
                execSuccess, result = pcall(retryChunk, createProxy("vararg_1", "vararg"))
                stopExecutionWatchdog()
                usedSyntheticVararg = true
                if not execSuccess then
                    local retryError = tostring(result)
                    if isRecoverableHookOpError(retryError) or retryError:find("stack overflow", 1, true) then
                        while #apiCalls > retryApiStart do
                            table.remove(apiCalls)
                        end
                        result = originalResult
                        usedSyntheticVararg = false
                    end
                end
            else
                print(string.format("[env2] vararg retry load failed: %s", tostring(retryLoadErr)))
            end
        end
        if not execSuccess then
            local errorMsg = tostring(result)
            if isWatchdogError(errorMsg) then
                print(string.format("[watchdog] %s", errorMsg))
                print("[hint] Execution was stopped after the loop budget; collected events were kept")
                print("")
            else
                print(string.format("[warning] Script execution error: %s", errorMsg))

                if errorMsg:match("attempt to call a nil value") then
                    print("[hint] The script called a missing function")
                    print("   This is likely a Luraph detection check or missing Roblox function")

                    if errorMsg:match("global") then
                        print("   Missing global function")
                    elseif errorMsg:match("field") then
                        local field = errorMsg:match("field '([^']+)'")
                        if field then
                            print(string.format("   Missing field/method: %s", field))
                        end
                    end
                end

                print("[hint] The error occurred in the user script")
                print("")
            end
        else
            print("[done] Script executed successfully")
            print("")

            if usedSyntheticVararg then
                print("[env2] synthetic top-level vararg retry succeeded")
            end

            if type(result) == "function" then
                print("[stage] Executing detected VM loader")
                resetExecutionWatchdog("vm-loader")
                local vmSuccess, vmErr = pcall(result)
                stopExecutionWatchdog()
                if not vmSuccess then
                    if isWatchdogError(vmErr) then
                        print(string.format("[watchdog] %s", tostring(vmErr)))
                    else
                        print(string.format("[warning] VM execution error: %s", tostring(vmErr)))
                    end
                else
                    print("[done] VM executed successfully")
                end
                print("")
            end
        end

        if not execSuccess and not isWatchdogError(result) and #apiCalls <= 10 then
            print("[warning] Very few API calls detected (" .. #apiCalls .. " calls)")
            print("   The script may have detected the dumper and stopped early")
            print("   Or it may be waiting for Roblox events that won't fire in this environment")
            print("")
        end
    end)
    local endTime = os.clock()

    if canPatchHostGlobals then
        package = saved_package
        io = saved_io
        os = saved_os
        debug = saved_debug
        require = saved_require
        loadfile = saved_loadfile
        dofile = saved_dofile

        _G.package = saved_G_package
        _G.io = saved_G_io
        _G.os = saved_G_os
        _G.debug = saved_G_debug
        _G.require = saved_G_require
        _G.loadfile = saved_G_loadfile
        _G.dofile = saved_G_dofile
    end

    print("")
    if not success then
        print(string.format("[warning] Execution error: %s", tostring(err)))
        print("[stage] Dumping captured data")
    else
        print("[done] Execution completed")
    end

    print(string.format("[time] %.3f seconds", endTime - startTime))
    print("")
    print("[usage]")
    print(string.format("   API Calls: %d/%d (%.1f%%)", RESOURCE_USAGE.apiCalls, LIMITS.MAX_API_CALLS, (RESOURCE_USAGE.apiCalls/LIMITS.MAX_API_CALLS)*100))
    print(string.format("   Variables: %d/%d (%.1f%%)", RESOURCE_USAGE.variables, LIMITS.MAX_VARIABLES, (RESOURCE_USAGE.variables/LIMITS.MAX_VARIABLES)*100))
    print(string.format("   Proxies: %d/%d (%.1f%%)", RESOURCE_USAGE.proxies, LIMITS.MAX_PROXIES, (RESOURCE_USAGE.proxies/LIMITS.MAX_PROXIES)*100))
    print(string.format("   Loaded Chunks: %d/%d", RESOURCE_USAGE.loadedChunks, LIMITS.MAX_LOADED_CHUNKS))
    print(string.format("   Env Storage: %d/%d", RESOURCE_USAGE.envStorage, LIMITS.GLOBAL_ENV_STORAGE))
    print("")

    print("[stage] Reconstructing code")
    if #apiCalls > 1000 then
        print(string.format("   Processing %d API calls - this may take a moment...", #apiCalls))
    end
    local reconstructed = reconstructCode()
    if #apiCalls == 0 and not success then
        local diagnostic = tostring(err):gsub("[\r\n]+", " "):gsub("%s+", " ")
        if #diagnostic > 1200 then
            diagnostic = diagnostic:sub(1, 1200) .. "..."
        end
        table.insert(reconstructed, "")
        table.insert(reconstructed, "__revealr_diagnostic = " .. formatValue(diagnostic))
    end

    local result = table.concat(reconstructed, "\n")

    result = result:gsub("C:\\Users\\[^\\]+", "C:\\Israel")
    result = result:gsub("C:\\\\Users\\\\[^\\\\]+", "C:\\\\Israel")
    result = result:gsub("C:/Users/[^/]+", "C:/Israel")

    result = result:gsub("C:\\[^:]+\\agartha%-stuff\\dumper2:", "C:\\Israel\\Netanyahu\\dumper2:")
    result = result:gsub("C:\\[^:]+\\Desktop[^:]*:", "C:\\Israel\\Netanyahu:")

    result = result:gsub("temp\\input_%d+_%d+%.lua", "script.lua")
    result = result:gsub('temp/input_%d+_%d+%.lua', 'script.lua')

    fs.writeFile(outputFile, result)

    print("")
    print("[done] Dump complete")
    print(string.format("[output] %s", outputFile))
    print(string.format("[size] %.2f KB", #result / 1024))
    print(string.format("[lines] %d", #reconstructed))
    print("[privacy] Username, home, and temp paths sanitized")
    print("")
end

main()
