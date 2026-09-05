local debugLibrary = debug
local setHook = debug.sethook
local getInfo = debug.getinfo
local getTraceback = debug.traceback
local loadFunction = load
local loadStringFunction = loadstring or load
local pcallFunction = pcall
local xpcallFunction = xpcall
local errorFunction = error
local typeFunction = type
local getMetatableFunction = getmetatable
local rawEqualFunction = rawequal
local toStringFunction = tostring
local toNumberFunction = tonumber
local ioLibrary = io
local osLibrary = os
local proxyTable = {}
proxyTable.__index = proxyTable
local configuration = {
    MAX_DEPTH = 15,
    MAX_TABLE_ITEMS = 150,
    OUTPUT_FILE = "dumped_output.lua",
    VERBOSE = true,
    TRACE_CALLBACKS = true,
    TIMEOUT_SECONDS = 50,
    MAX_REPEATED_LINES = 6,
    MIN_DEOBF_LENGTH = 150,
    MAX_OUTPUT_SIZE = 6 * 1024 * 1024,
    CONSTANT_COLLECTION = true,
    INSTRUMENT_LOGIC = true
}
local inputKey = arg and arg[3]
if inputKey then
    print("[Dumper] Auto-Input Key Detected: " .. toStringFunction(inputKey))
end
local dumperState = {
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
    ls_counter = 0
}
local inputKey = arg[3] or "NoKey"
local numericArg = toNumberFunction(arg[4]) or toNumberFunction(arg[3]) or 123456789
local proxyMarker = {}
local function isProxyTable(target)
    if typeFunction(target) ~= "table" then
        return false
    end
    local success, result = pcallFunction( function() return rawget(target, proxyMarker) == true end )
    return success and result
end
local function getProxyValue(target)
    if typeFunction(target) == "number" then
        return target
    end
    if isProxyTable(target) then
        return rawget(target, "__value") or 0
    end
    return 0
end
local loadStringFunction = loadstring or load
local printFunction = print
local warnFunction = warn or function() end
local pairsFunction = pairs
local ipairsFunction = ipairs
local typeFunction = type
local toStringFunction = tostring
local proxyList = {}
local function isProxy(target)
    if typeFunction(target) ~= "table" then
        return false
    end
    local success, result = pcallFunction( function() return rawget(target, proxyList) == true end )
    return success and result
end
local function getProxyId(target)
    if not isProxy(target) then
        return nil
    end
    return rawget(target, "__proxy_id")
end
local function processString(inputString)
    if typeFunction(inputString) ~= "string" then
        return '"'
    end
    local outputParts = {}
    local currentIndex, totalLength = 1, #inputString
    local function cleanEscapes(content)
        return content:gsub( "\\\\(.)", function(escapedChar)
            if escapedChar:match('[abfnrtv\\\\%\'%\\"%[%]0-9xu]') then
                return "" .. escapedChar
            end
            return escapedChar
        end )
    end
    local function parseExpression(rawCode)
        if not rawCode or rawCode == '"' then
            return ""
        end
        rawCode = rawCode:gsub( "0[bB]([01_]+)", function(binaryString)
            local cleanBinary = binaryString:gsub("_", "")
            local decimalValue = toNumberFunction(cleanBinary, 2)
            return decimalValue and toStringFunction(decimalValue) or "0"
        end )
        rawCode = rawCode:gsub( "0[xX]([%x_]+)", function(hexString)
            local cleanHex = hexString:gsub("_", '"')
            return "0x" .. cleanHex
        end )
        while rawCode:match("%d_+%d") do
            rawCode = rawCode:gsub("(%d)_+(%d)", "%1%2")
        end
        local operators = {{"+=", "+"}, {"-=", "-"}, {"*=", "*"}, {"/=", "/"}, {"%%=", "%%"}, {"%^=", "^"}, {"%.%.=", ".."}}
        for _, opPair in ipairsFunction(operators) do
            local operatorAssignment, operator = opPair[1], opPair[2]
            rawCode = rawCode:gsub( "([%a_][%w_]*)%s*" .. operatorAssignment, function(varName)
                return varName .. " = " .. varName .. " " .. operator .. " "
            end )
            rawCode = rawCode:gsub( "([%a_][%w_]*%.[%a_][%w_%.]+)%s*" .. operatorAssignment, function(varName)
                return varName .. " = " .. varName .. " " .. operator .. " "
            end )
            rawCode = rawCode:gsub( "([%a_][%w_]*%b[])%s*" .. operatorAssignment, function(varName)
                return varName .. " = " .. varName .. " " .. operator .. " "
            end )
        end
        rawCode = rawCode:gsub("([^%w_])continue([^%w_])", "%1_G.LuraphContinue()%2")
        rawCode = rawCode:gsub("^continue([^%w_])", "_G.LuraphContinue()%1")
        rawCode = rawCode:gsub("([^%w_])continue$", "%1_G.LuraphContinue()")
        return rawCode
    end
    local function getBracketCount(index)
        local count = 0
        while index <= totalLength and inputString:byte(index) == 61 do
            count = count + 1
            index = index + 1
        end
        return count, index
    end
    local function findClosingBracket(startIndex, bracketCount)
        local closingPattern = "]" .. string.rep("=", bracketCount) .. "]"
        local start, finish = inputString:find(closingPattern, startIndex, true)
        return finish or totalLength
    end
    local segmentStart = 1
    while currentIndex <= totalLength do
        local byteValue = inputString:byte(currentIndex)
        if byteValue == 91 then
            local bracketCount, nextIndex = getBracketCount(currentIndex + 1)
            if nextIndex <= totalLength and inputString:byte(nextIndex) == 61 then
                table.insert(outputParts, parseExpression(inputString:sub(segmentStart, currentIndex - 1)))
                local startSegment = currentIndex
                local endSegment = findClosingBracket(nextIndex + 1, bracketCount)
                table.insert(outputParts, inputString:sub(startSegment, endSegment))
                currentIndex = endSegment
                segmentStart = currentIndex + 1
            end
        elseif byteValue == 45 and currentIndex + 1 <= totalLength and inputString:byte(currentIndex + 1) == 45 then
            table.insert(outputParts, parseExpression(inputString:sub(segmentStart, currentIndex - 1)))
            local startSegment = currentIndex
            if currentIndex + 2 <= totalLength and inputString:byte(currentIndex + 2) == 91 then
                local bracketCount, nextIndex = getBracketCount(currentIndex + 3)
                if nextIndex <= totalLength and inputString:byte(nextIndex) == 61 then
                    local endSegment = findClosingBracket(nextIndex + 1, bracketCount)
                    table.insert(outputParts, inputString:sub(startSegment, endSegment))
                    currentIndex = endSegment
                    segmentStart = currentIndex + 1
                    currentIndex = currentIndex + 1
                end
            end
            local lineBreak = inputString:find("\n", currentIndex + 2, true)
            if lineBreak then
                currentIndex = lineBreak
            else
                currentIndex = totalLength
            end
            table.insert(outputParts, inputString:sub(startSegment, currentIndex))
            segmentStart = currentIndex + 1
        elseif byteValue == 34 or byteValue == 39 or byteValue == 96 then
            table.insert(outputParts, parseExpression(inputString:sub(segmentStart, currentIndex - 1)))
            local quoteType = byteValue
            local startSegment = currentIndex
            currentIndex = currentIndex + 1
            while currentIndex <= totalLength do
                local charByte = inputString:byte(currentIndex)
                if charByte == 92 then
                    currentIndex = currentIndex + 1
                elseif charByte == quoteType then
                    break
                end
                currentIndex = currentIndex + 1
            end
            local extractedContent = inputString:sub(startSegment + 1, currentIndex - 1)
            extractedContent = cleanEscapes(extractedContent)
            if quoteType == 96 then
                table.insert(outputParts, '"' .. extractedContent:gsub('"', '\\\\"') .. '"')
            else
                local quoteChar = string.char(quoteType)
                table.insert(outputParts, quoteChar .. extractedContent .. quoteChar)
            end
            segmentStart = currentIndex + 1
        end
        currentIndex = currentIndex + 1
    end
    table.insert(outputParts, parseExpression(inputString:sub(segmentStart)))
    return table.concat(outputParts)
end
local function safeLoad(code, chunkName)
    local loadedFunc, errorMessage = loadStringFunction(code, chunkName)
    if loadedFunc then
        return loadedFunc
    end
    printFunction("\n[CRITICAL ERROR] Failed to load script!")
    printFunction("[LUA_LOAD_FAIL] " .. toStringFunction(errorMessage))
    local errorLine = toNumberFunction(errorMessage:match(":(%d+):"))
    local errorNear = errorMessage:match("near '([^']+)'")
    if errorNear then
        local foundIndex = code:find(errorNear, 1, true)
        if foundIndex then
            local startCtx = math.max(1, foundIndex - 50)
            local endCtx = math.min(#code, foundIndex + 50)
            printFunction("Context around error:")
            printFunction("..." .. code:sub(startCtx, endCtx) .. "...")
        end
    end
    local debugFile = ioLibrary.open("DEBUG_FAILED_TRANSPILE.lua", "w")
    if debugFile then
        debugFile:write(code)
        debugFile:close()
        printFunction("[*] Saved to 'DEBUG_FAILED_TRANSPILE.lua' for inspection")
    end
    return nil, errorMessage
end
local function emitOutput(data, isInline)
    if dumperState.limit_reached then
        return
    end
    if data == nil then
        return
    end
    local indentPrefix = isInline and "" or string.rep("    ", dumperState.indent)
    local lineString = indentPrefix .. toStringFunction(data)
    local lineSize = #lineString + 1
    if dumperState.current_size + lineSize > configuration.MAX_OUTPUT_SIZE then
        dumperState.limit_reached = true
        local warningMessage = "-- [CRITICAL] Dump stopped: File size exceeded 6MB limit."
        table.insert(dumperState.output, warningMessage)
        dumperState.current_size = dumperState.current_size + #warningMessage
        errorFunction("DUMP_LIMIT_EXCEEDED")
    end
    if lineString == dumperState.last_emitted_line then
        dumperState.repetition_count = dumperState.repetition_count + 1
        if dumperState.repetition_count <= configuration.MAX_REPEATED_LINES then
            table.insert(dumperState.output, lineString)
            dumperState.current_size = dumperState.current_size + lineSize
        elseif dumperState.repetition_count == configuration.MAX_REPEATED_LINES + 1 then
            local suppressMessage = indentPrefix .. "-- [Repeated lines suppressed...]"
            table.insert(dumperState.output, suppressMessage)
            dumperState.current_size = dumperState.current_size + #suppressMessage
        end
    else
        dumperState.last_emitted_line = lineString
        dumperState.repetition_count = 0
        table.insert(dumperState.output, lineString)
        dumperState.current_size = dumperState.current_size + lineSize
    end
    if configuration.VERBOSE and dumperState.repetition_count <= 1 then
        printFunction(lineString)
    end
end
local function emitComment(data)
    emitOutput("-- " .. toStringFunction(data or ""))
end
local function addEmptyLine()
    dumperState.last_emitted_line = nil
    table.insert(dumperState.output, "")
end
local function getFullOutput()
    return table.concat(dumperState.output, "\n")
end
local function saveToFile(filePath)
    local fileHandle = ioLibrary.open(filePath or configuration.OUTPUT_FILE, "w")
    if fileHandle then
        fileHandle:write(getFullOutput())
        fileHandle:close()
        return true
    end
    return false
end
local function formatValue(value)
    if value == nil then
        return "nil"
    end
    if typeFunction(value) == "string" then
        return value
    end
    if typeFunction(value) == "number" or typeFunction(value) == "boolean" then
        return toStringFunction(value)
    end
    if typeFunction(value) == "table" then
        if dumperState.registry[value] then
            return dumperState.registry[value]
        end
        if isProxy(value) then
            local proxyId = getProxyId(value)
            return proxyId and "proxy_" .. proxyId or "proxy"
        end
    end
    local success, result = pcallFunction(toStringFunction, value)
    return success and result or "unknown"
end
local function formatStringLiteral(value)
    local rawValue = formatValue(value)
    local escapedValue = rawValue:gsub("\\\\", "\\\\\\\\"):gsub('"', '\\\\"'):gsub("\n", "\n"):gsub("\\r", "\\\\r"):gsub("\\t", "\\\\t")
    return '"' .. escapedValue .. '"'
end
local serviceNames = {
    Players = "Players",
    Workspace = "Workspace",
    ReplicatedStorage = "ReplicatedStorage",
    ServerStorage = "ServerStorage",
    ServerScriptService = "ServerScriptService",
    StarterGui = "StarterGui",
    StarterPack = "StarterPack",
    StarterPlayer = "StarterPlayer",
    Lighting = "Lighting",
    SoundService = "SoundService",
    Chat = "Chat",
    RunService = "RunService",
    UserInputService = "UserInputService",
    TweenService = "TweenService",
    HttpService = "HttpService",
    MarketplaceService = "MarketplaceService",
    TeleportService = "TeleportService",
    PathfindingService = "PathfindingService",
    CollectionService = "CollectionService",
    PhysicsService = "PhysicsService",
    ProximityPromptService = "ProximityPromptService",
    ContextActionService = "ContextActionService",
    GuiService = "GuiService",
    HapticService = "HapticService",
    VRService = "VRService",
    CoreGui = "CoreGui",
    Teams = "Teams",
    InsertService = "InsertService",
    DataStoreService = "DataStoreService",
    MessagingService = "MessagingService",
    TextService = "TextService",
    TextChatService = "TextChatService",
    ContentProvider = "ContentProvider",
    Debris = "Debris"
}
local serviceShortcuts = {
    Players = "Players",
    UserInputService = "UIS",
    RunService = "RunService",
    ReplicatedStorage = "ReplicatedStorage",
    TweenService = "TweenService",
    Workspace = "Workspace",
    Lighting = "Lighting",
    StarterGui = "StarterGui",
    CoreGui = "CoreGui",
    HttpService = "HttpService",
    MarketplaceService = "MarketplaceService",
    DataStoreService = "DataStoreService",
    TeleportService = "TeleportService",
    SoundService = "SoundService",
    Chat = "Chat",
    Teams = "Teams",
    ProximityPromptService = "ProximityPromptService",
    ContextActionService = "ContextActionService",
    CollectionService = "CollectionService",
    PathfindingService = "PathfindingService",
    Debris = "Debris"
}
local uiNamingConvention = {
    {pattern = "window", prefix = "Window", counter = "window"},
    {pattern = "tab", prefix = "Tab", counter = "tab"},
    {pattern = "section", prefix = "Section", counter = "section"},
    {pattern = "button", prefix = "Button", counter = "button"},
    {pattern = "toggle", prefix = "Toggle", counter = "toggle"},
    {pattern = "slider", prefix = "Slider", counter = "slider"},
    {pattern = "dropdown", prefix = "Dropdown", counter = "dropdown"},
    {pattern = "textbox", prefix = "Textbox", counter = "textbox"},
    {pattern = "input", prefix = "Input", counter = "input"},
    {pattern = "label", prefix = "Label", counter = "label"},
    {pattern = "keybind", prefix = "Keybind", counter = "keybind"},
    {pattern = "colorpicker", prefix = "ColorPicker", counter = "colorpicker"},
    {pattern = "paragraph", prefix = "Paragraph", counter = "paragraph"},
    {pattern = "notification", prefix = "Notification", counter = "notification"},
    {pattern = "divider", prefix = "Divider", counter = "divider"},
    {pattern = "bind", prefix = "Bind", counter = "bind"},
    {pattern = "picker", prefix = "Picker", counter = "picker"}
}
local uiCounters = {}
local function getUiCounter(name)
    uiCounters[name] = (uiCounters[name] or 0) + 1
    return uiCounters[name]
end
local function resolveVariableName(obj, originalName, hintString)
    if not obj then
        obj = "var"
    end
    local formattedName = formatValue(obj)
    if serviceShortcuts[formattedName] then
        return serviceShortcuts[formattedName]
    end
    if hintString then
        local lowerHint = hintString:lower()
        for _, patternEntry in ipairsFunction(uiNamingConvention) do
            if lowerHint:find(patternEntry.pattern) then
                local counter = getUiCounter(patternEntry.counter)
                return counter == 1 and patternEntry.prefix or patternEntry.prefix .. counter
            end
        end
    end
    if formattedName == "LocalPlayer" then
        return "LocalPlayer"
    end
    if formattedName == "Character" then
        return "Character"
    end
    if formattedName == "Humanoid" then
        return "Humanoid"
    end
    if formattedName == "HumanoidRootPart" then
        return "HumanoidRootPart"
    end
    if formattedName == "Camera" then
        return "Camera"
    end
    if formattedName:match("^Enum%.") then
        return formattedName
    end
    local sanitizedName = formattedName:gsub("[^%w_]", '"'):gsub("^%d+", '"')
    if sanitizedName == '"' or sanitizedName == "Object" or sanitizedName == "Value" or sanitizedName == "result" then
        sanitizedName = "var"
    end
    return sanitizedName
end
local function registerVariable(obj, objName, varType, hintString)
    local existing = dumperState.registry[obj]
    if existing and existing:match("^ls%d+$") then
        return existing
    end
    dumperState.ls_counter = (dumperState.ls_counter or 0) + 1
    local newName = "ls" .. dumperState.ls_counter
    dumperState.names_used[newName] = true
    dumperState.registry[obj] = newName
    dumperState.reverse_registry[newName] = obj
    dumperState.variable_types[newName] = varType or typeFunction(obj)
    return newName
end
local function serializeValue(obj, depth, visited, allowInline)
    depth = depth or 0
    visited = visited or {}
    if depth > configuration.MAX_DEPTH then
        return "{ --[[max depth]] }"
    end
    local valueType = typeFunction(obj)
    if isProxyTable(obj) then
        local proxyValue = rawget(obj, "__value")
        return toStringFunction(proxyValue or 0)
    end
    if valueType == "table" and dumperState.registry[obj] then
        return dumperState.registry[obj]
    end
    if valueType == "nil" then
        return "nil"
    elseif valueType == "string" then
        if #obj > 100 and obj:match("^[A-Za-z0-9+/=]+$") then
            table.insert(dumperState.string_refs, {value = obj:sub(1, 50) .. "...", hint = "base64", full_length = #obj})
        elseif obj:match("https?://") then
            table.insert(dumperState.string_refs, {value = obj, hint = "URL"})
        elseif obj:match("rbxasset://") or obj:match("rbxassetid://") then
            table.insert(dumperState.string_refs, {value = obj, hint = "Asset"})
        end
        return formatStringLiteral(obj)
    elseif valueType == "number" then
        if obj ~= obj then
            return "0/0"
        end
        if obj == math.huge then
            return "math.huge"
        end
        if obj == -math.huge then
            return "-math.huge"
        end
        if obj == math.floor(obj) then
            return toStringFunction(math.floor(obj))
        end
        return string.format("%.6g", obj)
    elseif valueType == "boolean" then
        return toStringFunction(obj)
    elseif valueType == "function" then
        if dumperState.registry[obj] then
            return dumperState.registry[obj]
        end
        return "function() end"
    elseif valueType == "table" then
        if isProxy(obj) then
            return dumperState.registry[obj] or "proxy"
        end
        if visited[obj] then
            return "{ --[[circular]] }"
        end
        visited[obj] = true
        local count = 0
        for k, v in pairsFunction(obj) do
            if k ~= proxyList and k ~= "__proxy_id" then
                count = count + 1
            end
        end
        if count == 0 then
            return "{}"
        end
        local isSequence = true
        local maxIdx = 0
        for k, v in pairsFunction(obj) do
            if k ~= proxyList and k ~= "__proxy_id" then
                if typeFunction(k) ~= "number" or k < 1 or k ~= math.floor(k) then
                    isSequence = false
                    break
                else
                    maxIdx = math.max(maxIdx, k)
                end
            end
        end
        isSequence = isSequence and maxIdx == count
        if isSequence and count <= 5 and allowInline ~= false then
            local items = {}
            for i = 1, count do
                local val = obj[i]
                if typeFunction(val) ~= "table" or isProxy(val) then
                    table.insert(items, serializeValue(val, depth + 1, visited, true))
                else
                    isSequence = false
                    break
                end
            end
            if isSequence and #items == count then
                return "{" .. table.concat(items, ", ") .. "}"
            end
        end
        local output = {}
        local itemCount = 0
        local indent = string.rep("    ", dumperState.indent + depth + 1)
        local baseIndent = string.rep("    ", dumperState.indent + depth)
        for k, v in pairsFunction(obj) do
            if k ~= proxyList and k ~= "__proxy_id" then
                itemCount = itemCount + 1
                if itemCount > configuration.MAX_TABLE_ITEMS then
                    table.insert(output, indent .. "-- ..." .. count - itemCount + 1 .. " more")
                    break
                end
                local keyStr
                if isSequence then
                    keyStr = nil
                elseif typeFunction(k) == "string" and k:match("^[%a_][%w_]*$") then
                    keyStr = k
                else
                    keyStr = "[" .. serializeValue(k, depth + 1, visited) .. "]"
                end
                local valStr = serializeValue(v, depth + 1, visited)
                if keyStr then
                    table.insert(output, indent .. keyStr .. " = " .. valStr)
                else
                    table.insert(output, indent .. valStr)
                end
            end
        end
        if #output == 0 then
            return "{}"
        end
        return "{\n" .. table.concat(output, ",\n") .. "\n" .. baseIndent .. "}"
    elseif valueType == "userdata" then
        if dumperState.registry[obj] then
            return dumperState.registry[obj]
        end
        local success, result = pcallFunction(toStringFunction, obj)
        return success and result or "userdata"
    elseif valueType == "thread" then
        return "coroutine.create(function() end)"
    else
        local success, result = pcallFunction(toStringFunction, obj)
        return success and result or "nil"
    end
end
local proxyStore = {}
setmetatable(proxyStore, {__mode = "k"})
local function createProxy()
    local proxy = {}
    proxyStore[proxy] = true
    local meta = {}
    setmetatable(proxy, meta)
    return proxy, meta
end
local function isProxy(obj)
    return proxyStore[obj] == true
end
local createProxyObject
local createProxyMethod
local function createProxyInstance(bm)
    local proxy, meta = createProxy()
    rawset(proxy, proxyMarker, true)
    rawset(proxy, "__value", bm)
    dumperState.registry[proxy] = toStringFunction(bm)
    meta.__tostring = function() return toStringFunction(bm) end
    meta.__index = function(tbl, key)
        if key == proxyList or key == "__proxy_id" or key == proxyMarker or key == "__value" then
            return rawget(tbl, key)
        end
        return createProxyInstance(0)
    end
    meta.__newindex = function() end
    meta.__call = function() return bm end
    local function op(symbol)
        return function(a, b)
            local valA = typeFunction(a) == "table" and rawget(a, "__value") or a or 0
            local valB = typeFunction(b) == "table" and rawget(b, "__value") or b or 0
            local res
            if symbol == "+" then res = valA + valB
            elseif symbol == "-" then res = valA - valB
            elseif symbol == "*" then res = valA * valB
            elseif symbol == "/" then res = valB ~= 0 and valA / valB or 0
            elseif symbol == "%" then res = valB ~= 0 and valA % valB or 0
            elseif symbol == "^" then res = valA ^ valB
            else res = 0 end
            return createProxyInstance(res)
        end
    end
    meta.__add = op("+")
    meta.__sub = op("-")
    meta.__mul = op("*")
    meta.__div = op("/")
    meta.__mod = op("%")
    meta.__pow = op("^")
    meta.__unm = function(a) return createProxyInstance(-(rawget(a, "__value") or 0)) end
    meta.__eq = function(a, b)
        local valA = typeFunction(a) == "table" and rawget(a, "__value") or a
        local valB = typeFunction(b) == "table" and rawget(b, "__value") or b
        return valA == valB
    end
    meta.__lt = function(a, b)
        local valA = typeFunction(a) == "table" and rawget(a, "__value") or a
        local valB = typeFunction(b) == "table" and rawget(b, "__value") or b
        return valA < valB
    end
    meta.__le = function(a, b)
        local valA = typeFunction(a) == "table" and rawget(a, "__value") or a
        local valB = typeFunction(b) == "table" and rawget(b, "__value") or b
        return valA <= valB
    end
    meta.__len = function() return 0 end
    return proxy
end
local function executeFunction(func, args)
    if typeFunction(func) ~= "function" then
        return {}
    end
    local outputCount = #dumperState.output
    local previousIteratorState = dumperState.pending_iterator
    dumperState.pending_iterator = false
    xpcallFunction( function() func(table.unpack(args or {})) end, function() end )
    while dumperState.pending_iterator do
        dumperState.indent = dumperState.indent - 1
        emitOutput("end")
        dumperState.pending_iterator = false
    end
    dumperState.pending_iterator = previousIteratorState
    local capturedLines = {}
    for i = outputCount + 1, #dumperState.output do
        table.insert(capturedLines, dumperState.output[i])
    end
    for i = #dumperState.output, outputCount + 1, -1 do
        table.remove(dumperState.output, i)
    end
    return capturedLines
end
createProxyMethod = function(methodName, parentProxy)
    local proxy, meta = createProxy()
    local parentName = dumperState.registry[parentProxy] or "object"
    local methodSignature = formatValue(methodName)
    dumperState.registry[proxy] = parentName .. "." .. methodSignature
    meta.__call = function(self, firstArg, ...)
        local args
        if firstArg == proxy or firstArg == parentProxy or isProxy(firstArg) then
            args = {...}
        else
            args = {firstArg, ...}
        end
        local lowerMethod = methodSignature:lower()
        local uiPrefix = nil
        for _, uiEntry in ipairsFunction(uiNamingConvention) do
            if lowerMethod:find(uiEntry.pattern) then
                uiPrefix = uiEntry.prefix
                break
            end
        end
        local callbackFunc, callbackKey, callbackIndex = nil, nil, nil
        for i, val in ipairsFunction(args) do
            if typeFunction(val) == "function" then
                callbackFunc = val
                break
            elseif typeFunction(val) == "table" and not isProxy(val) then
                for k, v in pairsFunction(val) do
                    local keyStr = toStringFunction(k):lower()
                    if keyStr == "callback" and typeFunction(v) == "function" then
                        callbackFunc = v
                        callbackKey = k
                        callbackIndex = i
                        break
                    end
                end
            end
        end
        local defaultParam, dummyArgs = "value", {}
        if callbackFunc then
            if lowerMethod:match("toggle") then
                defaultParam = "enabled"
                dummyArgs = {true}
            elseif lowerMethod:match("slider") then
                defaultParam = "value"
                dummyArgs = {50}
            elseif lowerMethod:match("dropdown") then
                defaultParam = "selected"
                dummyArgs = {"Option"}
            elseif lowerMethod:match("textbox") or lowerMethod:match("input") then
                defaultParam = "text"
                dummyArgs = {inputKey or "input"}
            elseif lowerMethod:match("keybind") or lowerMethod:match("bind") then
                defaultParam = "key"
                dummyArgs = {createProxyObject("Enum.KeyCode.E", false)}
            elseif lowerMethod:match("color") then
                defaultParam = "color"
                dummyArgs = {Color3.fromRGB(255, 255, 255)}
            elseif lowerMethod:match("button") then
                defaultParam = "\\"
                dummyArgs = {}
            end
        end
        local callbackLines = {}
        if callbackFunc then
            callbackLines = executeFunction(callbackFunc, dummyArgs)
        end
        local newProxy = createProxyObject(uiPrefix or methodSignature, false, parentProxy)
        local varName = registerVariable(newProxy, uiPrefix or methodSignature, nil, methodSignature)
        local argStrings = {}
        for i, val in ipairsFunction(args) do
            if typeFunction(val) == "table" and not isProxy(val) and i == callbackIndex then
                local tableParts = {}
                for k, v in pairsFunction(val) do
                    local keyStr
                    if typeFunction(k) == "string" and k:match("^[%a_][%w_]*$") then
                        keyStr = k
                    else
                        keyStr = "[" .. serializeValue(k) .. "]"
                    end
                    if k == callbackKey and #callbackLines > 0 then
                        local funcSignature = defaultParam ~= '"' and "function(" .. "bI" .. ")" or "function()"
                        local indent = string.rep("    ", dumperState.indent + 2)
                        local funcBody = {}
                        for _, line in ipairsFunction(callbackLines) do
                            table.insert(funcBody, indent .. (line:match("^%s*(.*)$") or line))
                        end
                        local baseIndent = string.rep("    ", dumperState.indent + 1)
                        table.insert(tableParts, keyStr .. " = " .. funcSignature .. "\n" .. table.concat(funcBody, "\n") .. "\n" .. baseIndent .. "end")
                    elseif k == callbackKey then
                        local funcDef = defaultParam ~= "\\" and "function(" .. defaultParam .. ") end" or "function() end"
                        table.insert(tableParts, keyStr .. " = " .. funcDef)
                    else
                        table.insert(tableParts, keyStr .. " = " .. serializeValue(v))
                    end
                end
                table.insert(argStrings, "{\n" .. string.rep("    ", dumperState.indent + 1) .. table.concat(tableParts, ",\n" .. string.rep("    ", dumperState.indent + 1)) .. "\n" .. string.rep("    ", dumperState.indent) .. "}")
            elseif typeFunction(val) == "function" then
                if #callbackLines > 0 then
                    local funcSignature = defaultParam ~= '"' and "function(" .. defaultParam .. ")" or "function()"
                    local indent = string.rep("    ", dumperState.indent + 1)
                    local funcBody = {}
                    for _, line in ipairsFunction(callbackLines) do
                        table.insert(funcBody, indent .. (line:match("^%s*(.*)$") or line))
                    end
                    table.insert(argStrings, funcSignature .. "\n" .. table.concat(funcBody, "\n") .. "\n" .. string.rep("    ", dumperState.indent) .. "end")
                else
                    local funcDef = defaultParam ~= '"' and "function(" .. defaultParam .. ") end" or "function() end"
                    table.insert(argStrings, funcDef)
                end
            else
                table.insert(argStrings, serializeValue(val))
            end
        end
        emitOutput(string.format("local %s = %s:%s(%s)", varName, parentName, methodSignature, table.concat(argStrings, ", ")))
        return newProxy
    end
    meta.__index = function(tbl, key)
        if key == proxyList or key == "__proxy_id" then
            return rawget(tbl, key)
        end
        return createProxyMethod(key, proxy)
    end
    meta.__tostring = function() return parentName .. ":" .. methodSignature end
    return proxy
end
createProxyObject = function(objName, isGlobal, parentProxy)
    local proxy, meta = createProxy()
    local formattedName = formatValue(objName)
    dumperState.property_store[proxy] = {}
    if isGlobal then
        dumperState.registry[proxy] = formattedName
        dumperState.names_used[formattedName] = true
    elseif parentProxy then
        dumperState.parent_map[proxy] = parentProxy
        rawset(proxy, "__temp_path", (dumperState.registry[parentProxy] or "object") .. "." .. formattedName)
    end
    local serviceMethods = {}
    serviceMethods.GetService = function(self, serviceName)
        local resolvedName = formatValue(serviceName)
        local proxy = createProxyObject(resolvedName, false, proxy)
        local varName = registerVariable(proxy, resolvedName)
        local parentPath = dumperState.registry[proxy] or "game"
        emitOutput(string.format("local %s = %s:GetService(%s)", varName, parentPath, formatStringLiteral(resolvedName)))
        return proxy
    end
    serviceMethods.WaitForChild = function(self, childName, timeout)
        local resolvedName = formatValue(childName)
        local proxy = createProxyObject(resolvedName, false, proxy)
        local varName = registerVariable(proxy, resolvedName)
        local parentPath = dumperState.registry[proxy] or "object"
        if timeout then
            emitOutput(string.format("local %s = %s:WaitForChild(%s, %s)", varName, parentPath, formatStringLiteral(resolvedName), serializeValue(timeout)))
        else
            emitOutput(string.format("local %s = %s:WaitForChild(%s)", varName, parentPath, formatStringLiteral(resolvedName)))
        end
        return proxy
    end
    serviceMethods.FindFirstChild = function(self, childName, recursive)
        local resolvedName = formatValue(childName)
        local proxy = createProxyObject(resolvedName, false, proxy)
        local varName = registerVariable(proxy, resolvedName)
        local parentPath = dumperState.registry[proxy] or "object"
        if recursive then
            emitOutput(string.format("local %s = %s:FindFirstChild(%s, true)", varName, parentPath, formatStringLiteral(resolvedName)))
        else
            emitOutput(string.format("local %s = %s:FindFirstChild(%s)", varName, parentPath, formatStringLiteral(resolvedName)))
        end
        return proxy
    end
    serviceMethods.FindFirstChildOfClass = function(self, className)
        local resolvedName = formatValue(className)
        local proxy = createProxyObject(resolvedName, false, proxy)
        local varName = registerVariable(proxy, resolvedName)
        local parentPath = dumperState.registry[proxy] or "object"
        emitOutput(string.format("local %s = %s:FindFirstChildOfClass(%s)", varName, parentPath, formatStringLiteral(resolvedName)))
        return proxy
    end
    serviceMethods.FindFirstChildWhichIsA = function(self, className)
        local resolvedName = formatValue(className)
        local proxy = createProxyObject(resolvedName, false, proxy)
        local varName = registerVariable(proxy, resolvedName)
        local parentPath = dumperState.registry[proxy] or "object"
        emitOutput(string.format("local %s = %s:FindFirstChildWhichIsA(%s)", varName, parentPath, formatStringLiteral(resolvedName)))
        return proxy
    end
    serviceMethods.FindFirstAncestor = function(self, ancestorName)
        local resolvedName = formatValue(ancestorName)
        local proxy = createProxyObject(resolvedName, false, proxy)
        local varName = registerVariable(proxy, resolvedName)
        local parentPath = dumperState.registry[proxy] or "object"
        emitOutput(string.format("local %s = %s:FindFirstAncestor(%s)", varName, parentPath, formatStringLiteral(resolvedName)))
        return proxy
    end
    serviceMethods.FindFirstAncestorOfClass = function(self, className)
        local resolvedName = formatValue(className)
        local proxy = createProxyObject(resolvedName, false, proxy)
        local varName = registerVariable(proxy, resolvedName)
        local parentPath = dumperState.registry[proxy] or "object"
        emitOutput(string.format("local %s = %s:FindFirstAncestorOfClass(%s)", varName, parentPath, formatStringLiteral(resolvedName)))
        return proxy
    end
    serviceMethods.FindFirstAncestorWhichIsA = function(self, className)
        local resolvedName = formatValue(className)
        local proxy = createProxyObject(resolvedName, false, proxy)
        local varName = registerVariable(proxy, resolvedName)
        local parentPath = dumperState.registry[proxy] or "object"
        emitOutput(string.format("local %s = %s:FindFirstAncestorWhichIsA(%s)", varName, parentPath, formatStringLiteral(resolvedName)))
        return proxy
    end
    serviceMethods.GetChildren = function(self)
        local parentPath = dumperState.registry[proxy] or "object"
        emitOutput(string.format("for _, child in %s:GetChildren() do", parentPath))
        dumperState.indent = dumperState.indent + 1
        dumperState.pending_iterator = true
        return {}
    end
    serviceMethods.GetDescendants = function(self)
        local parentPath = dumperState.registry[proxy] or "object"
        emitOutput(string.format("for _, obj in %s:GetDescendants() do", parentPath))
        dumperState.indent = dumperState.indent + 1
        local descProxy = createProxyObject("obj", false)
        dumperState.registry[descProxy] = "obj"
        dumperState.property_store[descProxy] = {Name = "Ball", ClassName = "Part", Size = Vector3.new(1, 1, 1)}
        local yielded = false
        return function()
            if not yielded then
                yielded = true
                return 1, descProxy
            else
                dumperState.indent = dumperState.indent - 1
                emitOutput("end")
                return nil
            end
        end, nil, 0
    end
    serviceMethods.Clone = function(self)
        local parentPath = dumperState.registry[proxy] or "object"
        local cloneProxy = createProxyObject((formattedName or "object") .. "Clone", false)
        local varName = registerVariable(cloneProxy, (formattedName or "object") .. "Clone")
        emitOutput(string.format("local %s = %s:Clone()", varName, parentPath))
        return cloneProxy
    end
    serviceMethods.Destroy = function(self)
        local parentPath = dumperState.registry[proxy] or "object"
        emitOutput(string.format("%s:Destroy()", parentPath))
    end
    serviceMethods.ClearAllChildren = function(self)
        local parentPath = dumperState.registry[proxy] or "object"
        emitOutput(string.format("%s:ClearAllChildren()", parentPath))
    end
    serviceMethods.Connect = function(self, func)
        local signalPath = dumperState.registry[proxy] or "signal"
        local connectionProxy = createProxyObject("connection", false)
        local varName = registerVariable(connectionProxy, "conn")
        local signalName = signalPath:match("%.([^%.]+)$") or signalPath
        local args = {"..."}
        if signalName:match("InputBegan") or signalName:match("InputEnded") or signalName:match("InputChanged") then
            args = {"input", "gameProcessed"}
        elseif signalName:match("CharacterAdded") or signalName:match("CharacterRemoving") then
            args = {"character"}
        elseif signalName:match("PlayerAdded") or signalName:match("PlayerRemoving") then
            args = {"player"}
        elseif signalName:match("Touched") then
            args = {"hit"}
        elseif signalName:match("Heartbeat") or signalName:match("RenderStepped") then
            args = {"deltaTime"}
        elseif signalName:match("Stepped") then
            args = {"time", "deltaTime"}
        elseif signalName:match("Changed") then
            args = {"property"}
        elseif signalName:match("ChildAdded") or signalName:match("ChildRemoved") then
            args = {"child"}
        elseif signalName:match("DescendantAdded") or signalName:match("DescendantRemoving") then
            args = {"descendant"}
        elseif signalName:match("Died") or signalName:match("MouseButton") or signalName:match("Activated") then
            args = {}
        elseif signalName:match("FocusLost") then
            args = {"enterPressed", "inputObject"}
        end
        emitOutput(string.format("local %s = %s:Connect(function(%s)", varName, signalPath, table.concat(args, ", ")))
        dumperState.indent = dumperState.indent + 1
        if typeFunction(func) == "function" then
            xpcallFunction( function() func() end, function() end )
        end
        while dumperState.pending_iterator do
            dumperState.indent = dumperState.indent - 1
            emitOutput("end")
            dumperState.pending_iterator = false
        end
        dumperState.indent = dumperState.indent - 1
        emitOutput("end)")
        return connectionProxy
    end
    serviceMethods.Once = function(self, func)
        local signalPath = dumperState.registry[proxy] or "signal"
        local connectionProxy = createProxyObject("connection", false)
        local varName = registerVariable(connectionProxy, "conn")
        emitOutput(string.format("local %s = %s:Once(function(...)", varName, signalPath))
        dumperState.indent = dumperState.indent + 1
        if typeFunction(func) == "function" then
            xpcallFunction( function() func() end, function() end )
        end
        dumperState.indent = dumperState.indent - 1
        emitOutput("end)")
        return connectionProxy
    end
    serviceMethods.Wait = function(self)
        local signalPath = dumperState.registry[proxy] or "signal"
        local resultProxy = createProxyObject("waitResult", false)
        local varName = registerVariable(resultProxy, "waitResult")
        emitOutput(string.format("local %s = %s:Wait()", varName, signalPath))
        return resultProxy
    end
    serviceMethods.Disconnect = function(self)
        local connectionPath = dumperState.registry[proxy] or "connection"
        emitOutput(string.format("%s:Disconnect()", connectionPath))
    end
    serviceMethods.FireServer = function(self, ...)
        local remotePath = dumperState.registry[proxy] or "remote"
        local args = {...}
        local serializedArgs = {}
        for _, val in ipairsFunction(args) do
            table.insert(serializedArgs, serializeValue(val))
        end
        emitOutput(string.format("%s:FireServer(%s)", remotePath, table.concat(serializedArgs, ", ")))
        table.insert(dumperState.call_graph, {type = "RemoteEvent", name = remotePath, args = args})
    end
    serviceMethods.InvokeServer = function(self, ...)
        local remotePath = dumperState.registry[proxy] or "remote"
        local args = {...}
        local serializedArgs = {}
        for _, val in ipairsFunction(args) do
            table.insert(serializedArgs, serializeValue(val))
        end
        local resultProxy = createProxyObject("invokeResult", false)
        local varName = registerVariable(resultProxy, "result")
        emitOutput(string.format("local %s = %s:InvokeServer(%s)", varName, remotePath, table.concat(serializedArgs, ", ")))
        table.insert(dumperState.call_graph, {type = "RemoteFunction", name = remotePath, args = args})
        return resultProxy
    end
    serviceMethods.Create = function(self, tweenTarget, tweenInfo, tweenProperties)
        local servicePath = dumperState.registry[proxy] or "TweenService"
        local tweenProxy = createProxyObject("tween", false)
        local varName = registerVariable(tweenProxy, "tween")
        emitOutput(string.format("local %s = %s:Create(%s, %s, %s)", varName, servicePath, serializeValue(tweenTarget), serializeValue(tweenInfo), serializeValue(tweenProperties)))
        return tweenProxy
    end
    serviceMethods.Play = function(self)
        local tweenPath = dumperState.registry[proxy] or "tween"
        emitOutput(string.format("%s:Play()", tweenPath))
    end
    serviceMethods.Pause = function(self)
        local tweenPath = dumperState.registry[proxy] or "tween"
        emitOutput(string.format("%s:Pause()", tweenPath))
    end
    serviceMethods.Cancel = function(self)
        local tweenPath = dumperState.registry[proxy] or "tween"
        emitOutput(string.format("%s:Cancel()", tweenPath))
    end
    serviceMethods.Stop = function(self)
        local tweenPath = dumperState.registry[proxy] or "tween"
        emitOutput(string.format("%s:Stop()", tweenPath))
    end
    serviceMethods.Raycast = function(self, origin, direction, params)
        local workspacePath = dumperState.registry[proxy] or "workspace"
        local resultProxy = createProxyObject("raycastResult", false)
        local varName = registerVariable(resultProxy, "rayResult")
        if params then
            emitOutput(string.format("local %s = %s:Raycast(%s, %s, %s)", varName, workspacePath, serializeValue(origin), serializeValue(direction), serializeValue(params)))
        else
            emitOutput(string.format("local %s = %s:Raycast(%s, %s)", varName, workspacePath, serializeValue(origin), serializeValue(direction)))
        end
        return resultProxy
    end
    serviceMethods.GetMouse = function(self)
        local playerPath = dumperState.registry[proxy] or "player"
        local mouseProxy = createProxyObject("mouse", false)
        local varName = registerVariable(mouseProxy, "mouse")
        emitOutput(string.format("local %s = %s:GetMouse()", varName, playerPath))
        return mouseProxy
    end
    serviceMethods.Kick = function(self, message)
        local playerPath = dumperState.registry[proxy] or "player"
        if message then
            emitOutput(string.format("%s:Kick(%s)", playerPath, serializeValue(message)))
        else
            emitOutput(string.format("%s:Kick()", playerPath))
        end
    end
    serviceMethods.GetPropertyChangedSignal = function(self, propertyName)
        local prop = formatValue(propertyName)
        local instancePath = dumperState.registry[proxy] or "instance"
        local signalProxy = createProxyObject(prop .. "Changed", false)
        dumperState.registry[signalProxy] = instancePath .. ":GetPropertyChangedSignal(" .. formatStringLiteral(prop) .. ")"
        return signalProxy
    end
    serviceMethods.IsA = function(self, class) return true end
    serviceMethods.IsDescendantOf = function(self, parent) return true end
    serviceMethods.IsAncestorOf = function(self, child) return true end
    serviceMethods.GetAttribute = function(self, attr) return nil end
    serviceMethods.SetAttribute = function(self, attr, val)
        local instancePath = dumperState.registry[proxy] or "instance"
        emitOutput(string.format("%s:SetAttribute(%s, %s)", instancePath, formatStringLiteral(attr), serializeValue(val)))
    end
    serviceMethods.GetAttributes = function(self) return {} end
    serviceMethods.GetPlayers = function(self) return {} end
    serviceMethods.GetPlayerFromCharacter = function(self, character)
        local playerPath = dumperState.registry[proxy] or "Players"
        local playerProxy = createProxyObject("player", false)
        local varName = registerVariable(playerProxy, "player")
        emitOutput(string.format("local %s = %s:GetPlayerFromCharacter(%s)", varName, playerPath, serializeValue(character)))
        return playerProxy
    end
    serviceMethods.GetPlayerByUserId = function(self, userId)
        local playerPath = dumperState.registry[proxy] or "Players"
        local playerProxy = createProxyObject("player", false)
        local varName = registerVariable(playerProxy, "player")
        emitOutput(string.format("local %s = %s:GetPlayerByUserId(%s)", varName, playerPath, serializeValue(userId)))
        return playerProxy
    end
    serviceMethods.SetCore = function(self, action, value)
        local guiPath = dumperState.registry[proxy] or "StarterGui"
        emitOutput(string.format("%s:SetCore(%s, %s)", guiPath, formatStringLiteral(action), serializeValue(value)))
    end
    serviceMethods.GetCore = function(self, action) return nil end
    serviceMethods.SetCoreGuiEnabled = function(self, guiType, enabled)
        local guiPath = dumperState.registry[proxy] or "StarterGui"
        emitOutput(string.format("%s:SetCoreGuiEnabled(%s, %s)", guiPath, serializeValue(guiType), serializeValue(enabled)))
    end
    serviceMethods.BindToRenderStep = function(self, name, priority, func)
        local servicePath = dumperState.registry[proxy] or "RunService"
        emitOutput(string.format("%s:BindToRenderStep(%s, %s, function(deltaTime)", servicePath, formatStringLiteral(name), serializeValue(priority)))
        dumperState.indent = dumperState.indent + 1
        if typeFunction(func) == "function" then
            xpcallFunction( function() func(0.016) end, function() end )
        end
        dumperState.indent = dumperState.indent - 1
        emitOutput("end)")
    end
    serviceMethods.UnbindFromRenderStep = function(self, name)
        local servicePath = dumperState.registry[proxy] or "RunService"
        emitOutput(string.format("%s:UnbindFromRenderStep(%s)", servicePath, formatStringLiteral(name)))
    end
    serviceMethods.GetFullName = function(self) return dumperState.registry[proxy] or "Instance" end
    serviceMethods.GetDebugId = function(self) return "DEBUG_" .. (getProxyId(proxy) or "0") end
    serviceMethods.MoveTo = function(self, pos, part)
        local humPath = dumperState.registry[proxy] or "humanoid"
        if part then
            emitOutput(string.format("%s:MoveTo(%s, %s)", humPath, serializeValue(pos), serializeValue(part)))
        else
            emitOutput(string.format("%s:MoveTo(%s)", humPath, serializeValue(pos)))
        end
    end
    serviceMethods.Move = function(self, direction, relativeTo)
        local humPath = dumperState.registry[proxy] or "humanoid"
        emitOutput(string.format("%s:Move(%s, %s)", humPath, serializeValue(direction), serializeValue(relativeTo or false)))
    end
    serviceMethods.EquipTool = function(self, tool)
        local humPath = dumperState.registry[proxy] or "humanoid"
        emitOutput(string.format("%s:EquipTool(%s)", humPath, serializeValue(tool)))
    end
    serviceMethods.UnequipTools = function(self)
        local humPath = dumperState.registry[proxy] or "humanoid"
        emitOutput(string.format("%s:UnequipTools()", humPath))
    end
    serviceMethods.TakeDamage = function(self, damage)
        local humPath = dumperState.registry[proxy] or "humanoid"
        emitOutput(string.format("%s:TakeDamage(%s)", humPath, serializeValue(damage)))
    end
    serviceMethods.ChangeState = function(self, state)
        local humPath = dumperState.registry[proxy] or "humanoid"
        emitOutput(string.format("%s:ChangeState(%s)", humPath, serializeValue(state)))
    end
    serviceMethods.GetState = function(self) return createProxyObject("Enum.HumanoidStateType.Running", false) end
    serviceMethods.SetPrimaryPartCFrame = function(self, cf)
        local modelPath = dumperState.registry[proxy] or "model"
        emitOutput(string.format("%s:SetPrimaryPartCFrame(%s)", modelPath, serializeValue(cf)))
    end
    serviceMethods.GetPrimaryPartCFrame = function(self) return CFrame.new(0, 0, 0) end
    serviceMethods.PivotTo = function(self, cf)
        local modelPath = dumperState.registry[proxy] or "model"
        emitOutput(string.format("%s:PivotTo(%s)", modelPath, serializeValue(cf)))
    end
    serviceMethods.GetPivot = function(self) return CFrame.new(0, 0, 0) end
    serviceMethods.GetBoundingBox = function(self) return CFrame.new(0, 0, 0), Vector3.new(1, 1, 1) end
    serviceMethods.GetExtentsSize = function(self) return Vector3.new(1, 1, 1) end
    serviceMethods.TranslateBy = function(self, vec)
        local modelPath = dumperState.registry[proxy] or "model"
        emitOutput(string.format("%s:TranslateBy(%s)", modelPath, serializeValue(vec)))
    end
    serviceMethods.LoadAnimation = function(self, anim)
        local animPath = dumperState.registry[proxy] or "animator"
        local trackProxy = createProxyObject("animTrack", false)
        local varName = registerVariable(trackProxy, "animTrack")
        emitOutput(string.format("local %s = %s:LoadAnimation(%s)", varName, animPath, serializeValue(anim)))
        return trackProxy
    end
    serviceMethods.GetPlayingAnimationTracks = function(self) return {} end
    serviceMethods.AdjustSpeed = function(self, speed)
        local trackPath = dumperState.registry[proxy] or "animTrack"
        emitOutput(string.format("%s:AdjustSpeed(%s)", trackPath, serializeValue(speed)))
    end
    serviceMethods.AdjustWeight = function(self, weight, fade)
        local trackPath = dumperState.registry[proxy] or "animTrack"
        if fade then
            emitOutput(string.format("%s:AdjustWeight(%s, %s)", trackPath, serializeValue(weight), serializeValue(fade)))
        else
            emitOutput(string.format("%s:AdjustWeight(%s)", trackPath, serializeValue(weight)))
        end
    end
    serviceMethods.Teleport = function(self, placeId, player, spawn, customTeleportData)
        local servicePath = dumperState.registry[proxy] or "TeleportService"
        emitOutput(string.format("%s:Teleport(%s, %s%s%s)", servicePath, serializeValue(placeId), serializeValue(player), spawn and ", " .. serializeValue(spawn) or '"', customTeleportData and ", " .. serializeValue(customTeleportData) or '"'))
    end
    serviceMethods.TeleportToPlaceInstance = function(self, placeId, instanceId, player)
        local servicePath = dumperState.registry[proxy] or "TeleportService"
        emitOutput(string.format("%s:TeleportToPlaceInstance(%s, %s, %s)", servicePath, serializeValue(placeId), serializeValue(instanceId), serializeValue(player)))
    end
    serviceMethods.PlayLocalSound = function(self, sound)
        local servicePath = dumperState.registry[proxy] or "SoundService"
        emitOutput(string.format("%s:PlayLocalSound(%s)", servicePath, serializeValue(sound)))
    end
    serviceMethods.GetAsync = function(self, url) return "{}" end
    serviceMethods.PostAsync = function(self, url, data) return "{}" end
    serviceMethods.JSONEncode = function(self, data) return "{}" end
    serviceMethods.JSONDecode = function(self, json) return {} end
    serviceMethods.GenerateGUID = function(self, includeBraces) return "00000000-0000-0000-0000-000000000000" end
    serviceMethods.HttpGet = function(self, url)
        local resolvedUrl = formatValue(url)
        table.insert(dumperState.string_refs, {value = resolvedUrl, hint = "HTTP URL"})
        dumperState.last_http_url = resolvedUrl
        return resolvedUrl
    end
    serviceMethods.HttpPost = function(self, url, data, contentType)
        local resolvedUrl = formatValue(url)
        table.insert(dumperState.string_refs, {value = resolvedUrl, hint = "HTTP POST URL"})
        local resultProxy = createProxyObject("HttpResponse", false)
        local varName = registerVariable(resultProxy, "httpResponse")
        local servicePath = dumperState.registry[proxy] or "HttpService"
        emitOutput(string.format("local %s = %s:HttpPost(%s, %s, %s)", varName, servicePath, serializeValue(url), serializeValue(data), serializeValue(contentType)))
        dumperState.property_store[resultProxy] = {Body = "{}", StatusCode = 200, Success = true}
        return resultProxy
    end
    serviceMethods.AddItem = function(self, item, delayTime)
        local servicePath = dumperState.registry[proxy] or "Debris"
        emitOutput(string.format("%s:AddItem(%s, %s)", servicePath, serializeValue(item), serializeValue(delayTime or 10)))
    end
    meta.__index = function(tbl, key)
        if key == proxyList or key == "__proxy_id" then
            return rawget(tbl, key)
        end
        if key == "PlaceId" or key == "GameId" or key == "placeId" or key == "gameId" then
            return numericArg
        end
        local pathName = dumperState.registry[proxy] or formattedName or "object"
        local propertyName = formatValue(key)
        if dumperState.property_store[proxy] and dumperState.property_store[proxy][key] ~= nil then
            return dumperState.property_store[proxy][key]
        end
        if serviceMethods[propertyName] then
            local methodProxy, methodMeta = createProxy()
            dumperState.registry[methodProxy] = pathName .. "." .. propertyName
            methodMeta.__call = function(_, ...)
                local args = {...}
                if args[1] == proxy or isProxy(args[1]) and args[1] ~= methodProxy then
                    table.remove(args, 1)
                end
                return serviceMethods[propertyName](proxy, table.unpack(args))
            end
            methodMeta.__index = function(_, k)
                if k == proxyList or k == "__proxy_id" then
                    return rawget(methodProxy, k)
                end
                return createProxyObject(k, false, methodProxy)
            end
            methodMeta.__tostring = function() return pathName .. ":" .. propertyName end
            return methodProxy
        end
        if pathName == "fenv" or pathName == "getgenv" or pathName == "_G" then
            if key == "game" then return game end
            if key == "workspace" then return workspace end
            if key == "script" then return script end
            if key == "Enum" then return Enum end
            if _G[key] ~= nil then return _G[key] end
            return nil
        end
        if key == "Parent" then return dumperState.parent_map[proxy] or createProxyObject("Parent", false) end
        if key == "Name" then return formattedName or "Object" end
        if key == "ClassName" then return formattedName or "Instance" end
        if key == "LocalPlayer" then
            local lpProxy = createProxyObject("LocalPlayer", false, proxy)
            local varName = registerVariable(lpProxy, "LocalPlayer")
            emitOutput(string.format("local %s = %s.LocalPlayer", varName, pathName))
            return lpProxy
        end
        if key == "PlayerGui" then return createProxyObject("PlayerGui", false, proxy) end
        if key == "Backpack" then return createProxyObject("Backpack", false, proxy) end
        if key == "PlayerScripts" then return createProxyObject("PlayerScripts", false, proxy) end
        if key == "UserId" then return 1 end
        if key == "DisplayName" then return "Player" end
        if key == "AccountAge" then return 1000 end
        if key == "Team" then return createProxyObject("Team", false, proxy) end
        if key == "TeamColor" then return BrickColor.new("White") end
        if key == "Character" then return createProxyObject("Character", false, proxy) end
        if key == "Humanoid" then
            local humProxy = createProxyObject("Humanoid", false, proxy)
            dumperState.property_store[humProxy] = {Health = 100, MaxHealth = 100, WalkSpeed = 16, JumpPower = 50, JumpHeight = 7.2}
            return humProxy
        end
        if key == "HumanoidRootPart" or key == "PrimaryPart" or key == "RootPart" then
            local rootProxy = createProxyObject("HumanoidRootPart", false, proxy)
            dumperState.property_store[rootProxy] = {Position = Vector3.new(0, 5, 0), CFrame = CFrame.new(0, 5, 0)}
            return rootProxy
        end
        local limbNames = {"Head", "Torso", "UpperTorso", "LowerTorso", "RightArm", "LeftArm", "RightLeg", "LeftLeg", "RightHand", "LeftHand", "RightFoot", "LeftFoot"}
        for _, limb in ipairsFunction(limbNames) do
            if key == limb then return createProxyObject(key, false, proxy) end
        end
        if key == "Animator" then return createProxyObject("Animator", false, proxy) end
        if key == "CurrentCamera" or key == "Camera" then
            local camProxy = createProxyObject("Camera", false, proxy)
            dumperState.property_store[camProxy] = {CFrame = CFrame.new(0, 10, 0), FieldOfView = 70, ViewportSize = Vector2.new(1920, 1080)}
            return camProxy
        end
        if key == "CameraType" then return createProxyObject("Enum.CameraType.Custom", false) end
        if key == "CameraSubject" then return createProxyObject("Humanoid", false, proxy) end
        local constants = {Health = 100, MaxHealth = 100, WalkSpeed = 16, JumpPower = 50, JumpHeight = 7.2, HipHeight = 2, Transparency = 0, Mass = 1, Value = 0, TimePosition = 0, TimeLength = 1, Volume = 0.5, PlaybackSpeed = 1, Brightness = 1, Range = 60, Angle = 90, FieldOfView = 70, Size = 1, Thickness = 1, ZIndex = 1, LayoutOrder = 0}
        if constants[key] then return createProxyInstance(constants[key]) end
        local boolConstants = {Visible = true, Enabled = true, Anchored = false, CanCollide = true, Locked = false, Active = true, Draggable = false, Modal = false, Playing = false, Looped = false, IsPlaying = false, AutoPlay = false, Archivable = true, ClipsDescendants = false, RichText = false, TextWrapped = false, TextScaled = false, PlatformStand = false, AutoRotate = true, Sit = false}
        if boolConstants[key] ~= nil then return boolConstants[key] end
        if key == "AbsoluteSize" or key == "ViewportSize" then return Vector2.new(1920, 1080) end
        if key == "AbsolutePosition" then return Vector2.new(0, 0) end
        if key == "Position" then
            if formattedName and (formattedName:match("Part") or formattedName:match("Model") or formattedName:match("Character") or formattedName:match("Root")) then return Vector3.new(0, 5, 0) end
            return UDim2.new(0, 0, 0, 0)
        end
        if key == "Size" then
            if formattedName and formattedName:match("Part") then return Vector3.new(4, 1, 2) end
            return UDim2.new(1, 0, 1, 0)
        end
        if key == "CFrame" then return CFrame.new(0, 5, 0) end
        if key == "Velocity" or key == "AssemblyLinearVelocity" then return Vector3.new(0, 0, 0) end
        if key == "RotVelocity" or key == "AssemblyAngularVelocity" then return Vector3.new(0, 0, 0) end
        if key == "Orientation" or key == "Rotation" then return Vector3.new(0, 0, 0) end
        if key == "LookVector" then return Vector3.new(0, 0, -1) end
        if key == "RightVector" then return Vector3.new(1, 0, 0) end
        if key == "UpVector" then return Vector3.new(0, 1, 0) end
        if key == "Color" or key == "Color3" or key == "BackgroundColor3" or key == "BorderColor3" or key == "TextColor3" or key == "PlaceholderColor3" or key == "ImageColor3" then return Color3.new(1, 1, 1) end
        if key == "BrickColor" then return BrickColor.new("Medium stone grey") end
        if key == "Material" then return createProxyObject("Enum.Material.Plastic", false) end
        if key == "Hit" then return CFrame.new(0, 0, -10) end
        if key == "Origin" then return CFrame.new(0, 5, 0) end
        if key == "Target" then return createProxyObject("Target", false, proxy) end
        if key == "X" or key == "Y" then return 0 end
        if key == "UnitRay" then return Ray.new(Vector3.new(0, 5, 0), Vector3.new(0, 0, -1)) end
        if key == "ViewSizeX" then return 1920 end
        if key == "ViewSizeY" then return 1080 end
        if key == "Text" or key == "PlaceholderText" or key == "ContentText" or key == "Value" then
            if inputKey then return inputKey end
            if key == "Value" then return "input" end
            return '"'
        end
        if key == "TextBounds" then return Vector2.new(0, 0) end
        if key == "Font" then return createProxyObject("Enum.Font.SourceSans", false) end
        if key == "TextSize" then return 14 end
        if key == "Image" or key == "ImageContent" then return '"' end
        local signalNames = {"Changed", "ChildAdded", "ChildRemoved", "DescendantAdded", "DescendantRemoving", "Touched", "TouchEnded", "InputBegan", "InputEnded", "InputChanged", "MouseButton1Click", "MouseButton1Down", "MouseButton1Up", "MouseButton2Click", "MouseButton2Down", "MouseButton2Up", "MouseEnter", "MouseLeave", "MouseMoved", "MouseWheelForward", "MouseWheelBackward", "Activated", "Deactivated", "FocusLost", "FocusGained", "Focused", "Heartbeat", "RenderStepped", "Stepped", "CharacterAdded", "CharacterRemoving", "CharacterAppearanceLoaded", "PlayerAdded", "PlayerRemoving", "AncestryChanged", "AttributeChanged", "Died", "FreeFalling", "GettingUp", "Jumping", "Running", "Seated", "Swimming", "StateChanged", "HealthChanged", "MoveToFinished", "OnClientEvent", "OnServerEvent", "OnClientInvoke", "OnServerInvoke", "Completed", "DidLoop", "Stopped", "Button1Down", "Button1Up", "Button2Down", "Button2Up", "Idle", "Move", "TextChanged", "ReturnPressedFromOnScreenKeyboard", "Triggered", "TriggerEnded"}
        for _, sig in ipairsFunction(signalNames) do
            if key == sig then
                local sigProxy = createProxyObject(pathName .. "." .. key, false, proxy)
                dumperState.registry[sigProxy] = pathName .. "." .. key
                return sigProxy
            end
        end
        if pathName:match("^Enum") then
            local fullEnum = pathName .. "." .. propertyName
            local enumProxy = createProxyObject(fullEnum, false)
            dumperState.registry[enumProxy] = fullEnum
            return enumProxy
        end
        return createProxyMethod(propertyName, proxy)
    end
    meta.__newindex = function(tbl, key, val)
        if key == proxyList or key == "__proxy_id" then
            rawset(tbl, key, val)
            return
        end
        local pathName = dumperState.registry[proxy] or formattedName or "object"
        local prop = formatValue(key)
        dumperState.property_store[proxy] = dumperState.property_store[proxy] or {}
        dumperState.property_store[proxy][key] = val
        if key == "Parent" and isProxy(val) then
            dumperState.parent_map[proxy] = val
        end
        emitOutput(string.format("%s.%s = %s", pathName, prop, serializeValue(val)))
    end
    meta.__call = function(tbl, ...)
        local pathName = dumperState.registry[proxy] or formattedName or "func"
        if pathName == "fenv" or pathName == "getgenv" or pathName:match("env") then
            return proxy
        end
        local args = {...}
        local serializedArgs = {}
        for _, val in ipairsFunction(args) do
            table.insert(serializedArgs, serializeValue(val))
        end
        local resultProxy = createProxyObject("result", false)
        local varName = registerVariable(resultProxy, "result")
        emitOutput(string.format("local %s = %s(%s)", varName, pathName, table.concat(serializedArgs, ", ")))
        return resultProxy
    end
    local function operatorMeta(opSymbol)
        local function metaCall(a, b)
            local proxy, meta = createProxy()
            local strA = "0"
            if a ~= nil then strA = dumperState.registry[a] or serializeValue(a) end
            local strB = "0"
            if b ~= nil then strB = dumperState.registry[b] or serializeValue(b) end
            local expression = "(" .. strA .. " " .. opSymbol .. " " .. strB .. ")"
            dumperState.registry[proxy] = expression
            meta.__tostring = function() return expression end
            meta.__call = function() return proxy end
            meta.__index = function(_, k)
                if k == proxyList or k == "__proxy_id" then return rawget(proxy, k) end
                return createProxyObject(expression .. "." .. formatValue(k), false)
            end
            meta.__add = operatorMeta("+")
            meta.__sub = operatorMeta("-")
            meta.__mul = operatorMeta("*")
            meta.__div = operatorMeta("/")
            meta.__mod = operatorMeta("%")
            meta.__pow = operatorMeta("^")
            meta.__concat = operatorMeta("..")
            meta.__eq = function() return false end
            meta.__lt = function() return false end
            meta.__le = function() return false end
            return proxy
        end
        return metaCall
    end
    meta.__add = operatorMeta("+")
    meta.__sub = operatorMeta("-")
    meta.__mul = operatorMeta("*")
    meta.__div = operatorMeta("/")
    meta.__mod = operatorMeta("%")
    meta.__pow = operatorMeta("^")
    meta.__concat = operatorMeta("..")
    meta.__eq = function() return false end
    meta.__lt = function() return false end
    meta.__le = function() return false end
    meta.__unm = function(a)
        local proxy, meta = createProxy()
        dumperState.registry[proxy] = "(-" .. (dumperState.registry[a] or serializeValue(a)) .. ")"
        meta.__tostring = function() return dumperState.registry[proxy] end
        return proxy
    end
    meta.__len = function() return 0 end
    meta.__tostring = function() return dumperState.registry[proxy] or formattedName or "Object" end
    meta.__pairs = function() return function() return nil end, proxy, nil end
    meta.__ipairs = meta.__pairs
    return proxy
end
local function createTypeDa(typeName, methods)
    local dc = {}
    local dd = {}
    dd.__index = function(_, key)
        if key == "new" or methods and methods[key] then
            return function(...)
                local args = {...}
                local serializedArgs = {}
                for _, val in ipairsFunction(args) do
                    table.insert(serializedArgs, serializeValue(val))
                end
                local expression = typeName .. "." .. key .. "(" .. table.concat(serializedArgs, ", ") .. ")"
                local proxy, meta = createProxy()
                dumperState.registry[proxy] = expression
                meta.__tostring = function() return expression end
                meta.__index = function(_, k)
                    if k == proxyList or k == "__proxy_id" then return rawget(proxy, k) end
                    if k == "X" or k == "Y" or k == "Z" or k == "W" then return 0 end
                    if k == "Magnitude" then return 0 end
                    if k == "Unit" or k == "Position" or k == "CFrame" or k == "LookVector" or k == "RightVector" or k == "UpVector" or k == "Rotation" or k == "p" then return proxy end
                    if k == "R" or k == "G" or k == "B" then return 1 end
                    if k == "Width" or k == "Height" then return UDim.new(0, 0) end
                    if k == "Min" or k == "Max" or k == "Scale" or k == "Offset" then return 0 end
                    return 0
                end
                local function opMeta(symbol)
                    return function(a, b)
                        local proxy, meta = createProxy()
                        local expr = "(" .. (dumperState.registry[a] or serializeValue(a)) .. " " .. symbol .. " " .. (dumperState.registry[b] or serializeValue(b)) .. ")"
                        dumperState.registry[proxy] = expr
                        meta.__tostring = function() return expr end
                        meta.__index = meta.__index
                        meta.__add = opMeta("+")
                        meta.__sub = opMeta("-")
                        meta.__mul = opMeta("*")
                        meta.__div = opMeta("/")
                        return proxy
                    end
                end
                meta.__add = opMeta("+")
                meta.__sub = opMeta("-")
                meta.__mul = opMeta("*")
                meta.__div = opMeta("/")
                meta.__unm = function(a)
                    local proxy, meta = createProxy()
                    dumperState.registry[proxy] = "(-" .. (dumperState.registry[a] or serializeValue(a)) .. ")"
                    meta.__tostring = function() return dumperState.registry[proxy] end
                    return proxy
                end
                meta.__eq = function() return false end
                return proxy
            end
        end
        return nil
    end
    dd.__call = function(_, ...) return _.new(...) end
    return setmetatable(dc, dd)
end
Vector3 = createTypeDa("Vector3", {new = true, zero = true, one = true})
Vector2 = createTypeDa("Vector2", {new = true, zero = true, one = true})
UDim = createTypeDa("UDim", {new = true})
UDim2 = createTypeDa("UDim2", {new = true, fromScale = true, fromOffset = true})
CFrame = createTypeDa("CFrame", {new = true, Angles = true, lookAt = true, fromEulerAnglesXYZ = true, fromEulerAnglesYXZ = true, fromAxisAngle = true, fromMatrix = true, fromOrientation = true, identity = true})
Color3 = createTypeDa("Color3", {new = true, fromRGB = true, fromHSV = true, fromHex = true})
BrickColor = createTypeDa("BrickColor", {new = true, random = true, White = true, Black = true, Red = true, Blue = true, Green = true, Yellow = true, palette = true})
TweenInfo = createTypeDa("TweenInfo", {new = true})
Rect = createTypeDa("Rect", {new = true})
Region3 = createTypeDa("Region3", {new = true})
Region3int16 = createTypeDa("Region3int16", {new = true})
Ray = createTypeDa("Ray", {new = true})
NumberRange = createTypeDa("NumberRange", {new = true})
NumberSequence = createTypeDa("NumberSequence", {new = true})
NumberSequenceKeypoint = createTypeDa("NumberSequenceKeypoint", {new = true})
ColorSequence = createTypeDa("ColorSequence", {new = true})
ColorSequenceKeypoint = createTypeDa("ColorSequenceKeypoint", {new = true})
PhysicalProperties = createTypeDa("PhysicalProperties", {new = true})
Font = createTypeDa("Font", {new = true, fromEnum = true, fromName = true, fromId = true})
RaycastParams = createTypeDa("RaycastParams", {new = true})
OverlapParams = createTypeDa("OverlapParams", {new = true})
PathWaypoint = createTypeDa("PathWaypoint", {new = true})
Axes = createTypeDa("Axes", {new = true})
Faces = createTypeDa("Faces", {new = true})
Vector3int16 = createTypeDa("Vector3int16", {new = true})
Vector2int16 = createTypeDa("Vector2int16", {new = true})
CatalogSearchParams = createTypeDa("CatalogSearchParams", {new = true})
DateTime = createTypeDa("DateTime", {now = true, fromUnixTimestamp = true, fromUnixTimestampMillis = true, fromIsoDate = true})
Random = {new = function(seed)
        local obj = {}
        function obj:NextNumber(min, max) return (min or 0) + 0.5 * ((max or 1) - (min or 0)) end
        function obj:NextInteger(min, max) return math.floor((min or 1) + 0.5 * ((max or 100) - (min or 1))) end
        function obj:NextUnitVector() return Vector3.new(0.577, 0.577, 0.577) end
        function obj:Shuffle(tab) return tab end
        function obj:Clone() return Random.new() end
        return obj
    end}
setmetatable(Random, {__call = function(_, seed) return _.new(seed) end})
Enum = createProxyObject("Enum", true)
local enumMeta = debugLibrary.getmetatable(Enum)
enumMeta.__index = function(_, key)
    if key == proxyList or key == "__proxy_id" then return rawget(_, key) end
    local enumProxy = createProxyObject("Enum." .. formatValue(key), false)
    dumperState.registry[enumProxy] = "Enum." .. formatValue(key)
    return enumProxy
end
Instance = {new = function(className, parent)
        local name = formatValue(className)
        local proxy = createProxyObject(name, false)
        local varName = registerVariable(proxy, name)
        if parent then
            local parentPath = dumperState.registry[parent] or serializeValue(parent)
            emitOutput(string.format("local %s = Instance.new(%s, %s)", varName, formatStringLiteral(name), parentPath))
            dumperState.parent_map[proxy] = parent
        else
            emitOutput(string.format("local %s = Instance.new(%s)", varName, formatStringLiteral(name)))
        end
        return proxy
    end}
game = createProxyObject("game", true)
workspace = createProxyObject("workspace", true)
script = createProxyObject("script", true)
dumperState.property_store[script] = {Name = "DumpedScript", Parent = game, ClassName = "LocalScript"}
task = {
    wait = function(sec)
        if sec then emitOutput(string.format("task.wait(%s)", serializeValue(sec))) else emitOutput("task.wait()") end
        return sec or 0.03, osLibrary.clock()
    end,
    spawn = function(func, ...)
        local args = {...}
        emitOutput("task.spawn(function()")
        dumperState.indent = dumperState.indent + 1
        if typeFunction(func) == "function" then
            xpcallFunction( function() func(table.unpack(args)) end, function(err) emitOutput("-- [Error in spawn] " .. toStringFunction(err)) end )
        end
        while dumperState.pending_iterator do
            dumperState.indent = dumperState.indent - 1
            emitOutput("end")
            dumperState.pending_iterator = false
        end
        dumperState.indent = dumperState.indent - 1
        emitOutput("end)")
    end,
    delay = function(sec, func, ...)
        local args = {...}
        emitOutput(string.format("task.delay(%s, function()", serializeValue(sec or 0)))
        dumperState.indent = dumperState.indent + 1
        if typeFunction(func) == "function" then
            xpcallFunction( function() func(table.unpack(args)) end, function() end )
        end
        while dumperState.pending_iterator do
            dumperState.indent = dumperState.indent - 1
            emitOutput("end")
            dumperState.pending_iterator = false
        end
        dumperState.indent = dumperState.indent - 1
        emitOutput("end)")
    end,
    defer = function(func, ...)
        local args = {...}
        emitOutput("task.defer(function()")
        dumperState.indent = dumperState.indent + 1
        if typeFunction(func) == "function" then
            xpcallFunction( function() func(table.unpack(args)) end, function() end )
        end
        dumperState.indent = dumperState.indent - 1
        emitOutput("end)")
    end,
    cancel = function(thread) emitOutput("task.cancel(thread)") end,
    synchronize = function() emitOutput("task.synchronize()") end,
    desynchronize = function() emitOutput("task.desynchronize()") end
}
wait = function(sec)
    if sec then emitOutput(string.format("wait(%s)", serializeValue(sec))) else emitOutput("wait()") end
    return sec or 0.03, osLibrary.clock()
end
delay = function(sec, func)
    emitOutput(string.format("delay(%s, function()", serializeValue(sec or 0)))
    dumperState.indent = dumperState.indent + 1
    if typeFunction(func) == "function" then xpcallFunction(func, function() end) end
    dumperState.indent = dumperState.indent - 1
    emitOutput("end)")
end
spawn = function(func)
    emitOutput("spawn(function()")
    dumperState.indent = dumperState.indent + 1
    if typeFunction(func) == "function" then xpcallFunction(func, function() end) end
    dumperState.indent = dumperState.indent - 1
    emitOutput("end)")
end
tick = function() return osLibrary.time() end
time = function() return osLibrary.clock() end
elapsedTime = function() return osLibrary.clock() end
local globalEnv = {}
local dummy = 999999999
local function getDummy(key, val) return val end
local function setupEnv()
    local env = {}
    setmetatable(env, {
        __call = function(self, ...) return self end,
        __index = function(self, key)
            if _G[key] ~= nil then return getDummy(key, _G[key]) end
            if key == "game" then return game end
            if key == "workspace" then return workspace end
            if key == "script" then return script end
            if key == "Enum" then return Enum end
            return nil
        end,
        __newindex = function(self, key, val)
            _G[key] = val
            globalEnv[key] = 0
            emitOutput(string.format("_G.%s = %s", formatValue(key), serializeValue(val)))
        end
    })
    return env
end
_G.G = setupEnv()
_G.g = setupEnv()
_G.ENV = setupEnv()
_G.env = setupEnv()
_G.E = setupEnv()
_G.e = setupEnv()
_G.L = setupEnv()
_G.l = setupEnv()
_G.F = setupEnv()
_G.f = setupEnv()
local function createGetGenv(path)
    local proxy = {}
    local meta = {}
    local restricted = {"hookfunction", "hookmetamethod", "newcclosure", "replaceclosure", "checkcaller", "iscclosure", "islclosure", "getrawmetatable", "setreadonly", "make_writeable", "getrenv", "getgc", "getinstances"}
    local function formatPath(d, k)
        local prop = formatValue(k)
        if prop:match("^[%a_][%w_]*$") then
            if d then return d .. "." .. prop end
            return prop
        else
            local escaped = prop:gsub("'", "\\\\'")
            if d then return d .. "['" .. escaped .. "']" end
            return "['" .. escaped .. "']"
        end
    end
    meta.__index = function(_, key)
        for _, restrictedName in ipairsFunction(restricted) do
            if key == restrictedName then return nil end
        end
        return createGetGenv(formatPath(path, key))
    end
    meta.__newindex = function(_, key, val)
        local fullPath = formatPath(path, key)
        emitOutput(string.format("getgenv().%s = %s", fullPath, serializeValue(val)))
    end
    meta.__call = function() return proxy end
    meta.__pairs = function() return function() return nil end, nil, nil end
    return setmetatable(proxy, meta)
end
local exploitFuncs = {
    getgenv = function() return createGetGenv(nil) end,
    getrenv = function() return createProxyObject("getrenv()", false) end,
    getfenv = function(depth) return _G end,
    setfenv = function(func, env)
        if typeFunction(func) ~= "function" then return end
        local i = 1
        while true do
            local name = debugLibrary.getupvalue(func, i)
            if name == "_ENV" then debugLibrary.setupvalue(func, i, env) break
            elseif not name then break end
            i = i + 1
        end
        return func
    end,
    hookfunction = function(f, h) return f end,
    hookmetamethod = function(x, method, hook) return function() end end,
    getrawmetatable = function(x)
        if isProxy(x) then return debugLibrary.getmetatable(x) end
        return {}
    end,
    setrawmetatable = function(x, mt) return x end,
    getnamecallmethod = function() return "__namecall" end,
    setnamecallmethod = function(m) end,
    checkcaller = function() return true end,
    islclosure = function(f) return typeFunction(f) == "function" end,
    iscclosure = function(f) return false end,
    newcclosure = function(f) return f end,
    clonefunction = function(f) return f end,
    request = function(req)
        emitOutput(string.format("request(%s)", serializeValue(req)))
        table.insert(dumperState.string_refs, {value = req.Url or req.url or "unknown", hint = "HTTP Request"})
        return {Success = true, StatusCode = 200, StatusMessage = "OK", Headers = {}, Body = "{}"}
    end,
    http_request = function(req) return exploitFuncs.request(req) end,
    syn = {request = function(req) return exploitFuncs.request(req) end},
    http = {request = function(req) return exploitFuncs.request(req) end},
    HttpPost = function(url, data)
        emitOutput(string.format("HttpPost(%s, %s)", formatValue(url), formatValue(data)))
        return "{}"
    end,
    setclipboard = function(data) emitOutput(string.format("setclipboard(%s)", serializeValue(data))) end,
    getclipboard = function() return '"' end,
    identifyexecutor = function() return "Dumper", "3.0" end,
    getexecutorname = function() return "Dumper" end,
    gethui = function()
        local hui = createProxyObject("HiddenUI", false)
        registerVariable(hui, "HiddenUI")
        emitOutput(string.format("local %s = gethui()", dumperState.registry[hui]))
        return hui
    end,
    gethiddenui = function() return exploitFuncs.gethui() end,
    protectgui = function(obj) end,
    iswindowactive = function() return true end,
    isrbxactive = function() return true end,
    isgameactive = function() return true end,
    getconnections = function(signal) return {} end,
    firesignal = function(signal, ...) end,
    fireclickdetector = function(detector, dist) end,
    fireproximityprompt = function(prompt) end,
    firetouchinterest = function(a, b, c) end,
    getinstances = function() return {} end,
    getnilinstances = function() return {} end,
    getgc = function() return {} end,
    getscripts = function() return {} end,
    getrunningscripts = function() return {} end,
    getloadedmodules = function() return {} end,
    getcallingscript = function() return script end,
    readfile = function(file)
        emitOutput(string.format("readfile(%s)", formatStringLiteral(file)))
        return '"'
    end,
    writefile = function(file, content) emitOutput(string.format("writefile(%s, %s)", formatStringLiteral(file), serializeValue(content))) end,
    appendfile = function(file, content) emitOutput(string.format("appendfile(%s, %s)", formatStringLiteral(file), serializeValue(content))) end,
    loadfile = function(file) return function() return createProxyObject("loaded_file", false) end end,
    listfiles = function(folder) return {} end,
    isfile = function(file) return false end,
    isfolder = function(folder) return false end,
    makefolder = function(folder) emitOutput(string.format("makefolder(%s)", formatStringLiteral(folder))) end,
    delfolder = function(folder) emitOutput(string.format("delfolder(%s)", formatStringLiteral(folder))) end,
    delfile = function(file) emitOutput(string.format("delfile(%s)", formatStringLiteral(file))) end,
    Drawing = {
        new = function(type)
            local t = formatValue(type)
            local proxy = createProxyObject("Drawing_" .. t, false)
            registerVariable(proxy, t)
            emitOutput(string.format("local %s = Drawing.new(%s)", dumperState.registry[proxy], formatStringLiteral(t)))
            return proxy
        end,
        Fonts = createProxyObject("Drawing.Fonts", false)
    },
    crypt = {
        base64encode = function(s) return s end,
        base64decode = function(s) return s end,
        base64_encode = function(s) return s end,
        base64_decode = function(s) return s end,
        encrypt = function(s, k) return s end,
        decrypt = function(s, k) return s end,
        hash = function(s) return "hash" end,
        generatekey = function(len) return string.rep("0", len or 32) end,
        generatebytes = function(len) return string.rep("\\0", len or 16) end
    },
    base64_encode = function(s) return s end,
    base64_decode = function(s) return s end,
    base64encode = function(s) return s end,
    base64decode = function(s) return s end,
    mouse1click = function() emitOutput("mouse1click()") end,
    mouse1press = function() emitOutput("mouse1press()") end,
    mouse1release = function() emitOutput("mouse1release()") end,
    mouse2click = function() emitOutput("mouse2click()") end,
    mouse2press = function() emitOutput("mouse2press()") end,
    mouse2release = function() emitOutput("mouse2release()") end,
    mousemoverel = function(x, y) emitOutput(string.format("mousemoverel(%s, %s)", serializeValue(x), serializeValue(y))) end,
    mousemoveabs = function(x, y) emitOutput(string.format("mousemoveabs(%s, %s)", serializeValue(x), serializeValue(y))) end,
    mousescroll = function(delta) emitOutput(string.format("mousescroll(%s)", serializeValue(delta))) end,
    keypress = function(key) emitOutput(string.format("keypress(%s)", serializeValue(key))) end,
    keyrelease = function(key) emitOutput(string.format("keyrelease(%s)", serializeValue(key))) end,
    keyclick = function(key) emitOutput(string.format("keyclick(%s)", serializeValue(key))) end,
    isreadonly = function(t) return false end,
    setreadonly = function(t, val) return t end,
    make_writeable = function(t) return t end,
    make_readonly = function(t) return t end,
    getthreadidentity = function() return 7 end,
    setthreadidentity = function(id) end,
    getidentity = function() return 7 end,
    setidentity = function(id) end,
    getthreadcontext = function() return 7 end,
    setthreadcontext = function(id) end,
    getcustomasset = function(file) return "rbxasset://" .. formatValue(file) end,
    getsynasset = function(file) return "rbxasset://" .. formatValue(file) end,
    getinfo = function(func) return {source = "=", what = "Lua", name = "unknown", short_src = "dumper"} end,
    getconstants = function(func) return {} end,
    getupvalues = function(func) return {} end,
    getprotos = function(func) return {} end,
    getupvalue = function(func, i) return nil end,
    setupvalue = function(func, i, val) end,
    setconstant = function(func, i, val) end,
    getconstant = function(func, i) return nil end,
    getproto = function(func, i) return function() end end,
    setproto = function(func, i, f) end,
    getstack = function(level, i) return nil end,
    setstack = function(level, i, val) end,
    debug = {
        getinfo = getInfo or function() return {} end,
        getupvalue = debugLibrary.getupvalue or function() return nil end,
        setupvalue = debugLibrary.setupvalue or function() end,
        getmetatable = debugLibrary.getmetatable,
        setmetatable = debugLibrary.setmetatable or setmetatable,
        traceback = getTraceback or function() return '"' end,
        profilebegin = function() end,
        profileend = function() end,
        sethook = function() end
    },
    rconsoleprint = function(s) end,
    rconsoleclear = function() end,
    rconsolecreate = function() end,
    rconsoledestroy = function() end,
    rconsoleinput = function() return "" end,
    rconsoleinfo = function(s) end,
    rconsolewarn = function(s) end,
    rconsoleerr = function(s) end,
    rconsolename = function(name) end,
    printconsole = function(s) end,
    setfflag = function(flag, val) end,
    getfflag = function(flag) return "" end,
    setfpscap = function(cap) emitOutput(string.format("setfpscap(%s)", serializeValue(cap))) end,
    getfpscap = function() return 60 end,
    isnetworkowner = function(part) return true end,
    gethiddenproperty = function(instance, prop) return nil end,
    sethiddenproperty = function(instance, prop, val) emitOutput(string.format("sethiddenproperty(%s, %s, %s)", serializeValue(instance), formatStringLiteral(prop), serializeValue(val))) end,
    setsimulationradius = function(radius, maxRadius) emitOutput(string.format("setsimulationradius(%s%s)", serializeValue(radius), maxRadius and ", " .. serializeValue(maxRadius) or "")) end,
    getspecialinfo = function(instance) return {} end,
    saveinstance = function(options) emitOutput(string.format("saveinstance(%s)", serializeValue(options or {}))) end,
    decompile = function(script) return "-- decompiled" end,
    lz4compress = function(s) return s end,
    lz4decompress = function(s) return s end,
    MessageBox = function(text, caption, type) return 1 end,
    setwindowactive = function() end,
    setwindowtitle = function(title) end,
    queue_on_teleport = function(code) emitOutput(string.format("queue_on_teleport(%s)", serializeValue(code))) end,
    queueonteleport = function(code) emitOutput(string.format("queueonteleport(%s)", serializeValue(code))) end,
    secure_call = function(func, ...) return func(...) end,
    create_secure_function = function(func) return func end,
    isvalidinstance = function(instance) return instance ~= nil end,
    validcheck = function(instance) return instance ~= nil end
}
for name, func in pairsFunction(exploitFuncs) do
    _G[name] = func
end
_G.hookfunction = nil
_G.hookmetamethod = nil
_G.newcclosure = nil
local bitLibrary = {}
local function toBit(n)
    n = (n or 0) % 4294967296
    if n >= 2147483648 then n = n - 4294967296 end
    return math.floor(n)
end
bitLibrary.tobit = toBit
bitLibrary.tohex = function(n, len) return string.format("%0" .. (len or 8) .. "x", (n or 0) % 0x100000000) end
_G.bit = {
    band = function(a, b) return toBit(toBit(a) & toBit(b)) end,
    bor = function(a, b) return toBit(toBit(a) | toBit(b)) end,
    bxor = function(a, b) return toBit(toBit(a) ~ toBit(b)) end,
    lshift = function(n, bits) return toBit(toBit(n) << bits % 32) end,
    rshift = function(n, bits) return toBit(toBit(n) >> bits % 32) end
}
_G.bit32 = _G.bit
bitLibrary.arshift = function(n, bits)
    local val = toBit(n or 0)
    if val < 0 then return toBit(val >> bits or 0) + toBit(-1 << 32 - (bits or 0)) else return toBit(val >> bits or 0) end
end
bitLibrary.rol = function(n, bits)
    n = n or 0; bits = (bits or 0) % 32
    return toBit(n << bits | (n >> 32 - bits))
end
bitLibrary.ror = function(n, bits)
    n = n or 0; bits = (bits or 0) % 32
    return toBit(n >> bits | (n << 32 - bits))
end
bitLibrary.bswap = function(n)
    n = n or 0
    local a = n >> 24 & 0xFF
    local b = n >> 8 & 0xFF00
    local c = n << 8 & 0xFF0000
    local d = n << 24 & 0xFF000000
    return toBit(a | b | c | d)
end
bitLibrary.countlz = function(n)
    n = bitLibrary.tobit(n)
    if n == 0 then return 32 end
    local count = 0
    if bitLibrary.band(n, 0xFFFF0000) == 0 then count = count + 16; n = bitLibrary.lshift(n, 16) end
    if bitLibrary.band(n, 0xFF000000) == 0 then count = count + 8; n = bitLibrary.lshift(n, 8) end
    if bitLibrary.band(n, 0xF0000000) == 0 then count = count + 4; n = bitLibrary.lshift(n, 4) end
    if bitLibrary.band(n, 0xC0000000) == 0 then count = count + 2; n = bitLibrary.lshift(n, 2) end
    if bitLibrary.band(n, 0x80000000) == 0 then count = count + 1 end
    return count
end
bitLibrary.countrz = function(n)
    n = bitLibrary.tobit(n)
    if n == 0 then return 32 end
    local count = 0
    while bitLibrary.band(n, 1) == 0 do n = bitLibrary.rshift(n, 1); count = count + 1 end
    return count
end
bitLibrary.lrotate = bitLibrary.rol
bitLibrary.rrotate = bitLibrary.ror
bitLibrary.extract = function(n, pos, len) len = len or 1; return n >> pos & 1 << len - 1 end
bitLibrary.replace = function(n, val, pos, len)
    len = len or 1
    local mask = 1 << len - 1
    return n & ~(mask << pos) | (val & mask << pos)
end
bitLibrary.btest = function(a, b) return bitLibrary.band(a, b) ~= 0 end
bit32 = bitLibrary
bit = bitLibrary
_G.bit = bit
_G.bit32 = bit32
table.getn = table.getn or function(t) return #t end
table.foreach = table.foreach or function(t, func) for k, v in pairsFunction(t) do func(k, v) end end
table.foreachi = table.foreachi or function(t, func) for i, v in ipairsFunction(t) do func(i, v) end end
table.move = table.move or function(src, start, endIdx, dest, target)
    target = target or src
    for i = start, endIdx do target[dest + i - start] = src[i] end
    return target
end
string.split = string.split or function(str, sep)
    local t = {}
    for match in string.gmatch(str, "([^" .. (sep or "%s") .. "]+)") do table.insert(t, match) end
    return t
end
if not math.frexp then
    math.frexp = function(x)
        if x == 0 then return 0, 0 end
        local exp = math.floor(math.log(math.abs(x)) / math.log(2)) + 1
        local m = x / 2 ^ exp
        return m, exp
    end
end
if not math.ldexp then math.ldexp = function(m, e) return m * 2 ^ e end end
if not utf8 then
    utf8 = {}
    utf8.char = function(...)
        local args = {...}
        local chars = {}
        for _, byte in ipairsFunction(args) do table.insert(chars, string.char(byte % 256)) end
        return table.concat(chars)
    end
    utf8.len = function(s) return #s end
    utf8.codes = function(s)
        local i = 0
        return function() i = i + 1; if i <= #s then return i, string.byte(s, i) end end
    end
end
_G.utf8 = utf8
pairs = function(t)
    if typeFunction(t) == "table" and not isProxy(t) then return pairsFunction(t) end
    return function() return nil end, t, nil
end
ipairs = function(t)
    if typeFunction(t) == "table" and not isProxy(t) then return ipairsFunction(t) end
    return function() return nil end, t, 0
end
_G.pairs = pairs
_G.ipairs = ipairs
_G.math = math
_G.table = table
_G.string = string
_G.os = os
_G.coroutine = coroutine
_G.io = nil
_G.debug = exploitFuncs.debug
_G.utf8 = utf8
_G.next = next
_G.tostring = tostring
_G.tonumber = tonumber
_G.getmetatable = getmetatable
_G.setmetatable = setmetatable
_G.pcall = function(f, ...)
    local results = {pcallFunction(f, ...)}
    local success = results[1]
    if not success then
        local err = results[2]
        if typeFunction(err) == "string" and err:match("TIMEOUT_FORCED_BY_DUMPER") then errorFunction(err) end
    end
    return table.unpack(results)
end
_G.xpcall = function(f, errFunc, ...)
    local function wrapper(err)
        if typeFunction(err) == "string" and err:match("TIMEOUT_FORCED_BY_DUMPER") then return err end
        if errFunc then return errFunc(err) end
        return err
    end
    local results = {xpcallFunction(f, wrapper, ...)}
    local success = results[1]
    if not success then
        local err = results[2]
        if typeFunction(err) == "string" and err:match("TIMEOUT_FORCED_BY_DUMPER") then errorFunction(err) end
    end
    return table.unpack(results)
end
_G.error = errorFunction
if _G.originalError == nil then _G.originalError = errorFunction end
_G.assert = assert
_G.select = select
_G.type = typeFunction
_G.rawget = rawget
_G.rawset = rawset
_G.rawequal = rawEqualFunction
_G.rawlen = rawlen or function(t) return #t end
_G.unpack = table.unpack or unpack
_G.pack = table.pack or function(...) return {n = select("#", ...), ...} end
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
    if isProxy(x) then return "The metatable is locked" end
    return getMetatableFunction(x)
end
_G.getmetatable = getmetatable
type = function(x)
    if getProxyValue(x) ~= 0 then return "number" end
    if isProxy(x) then return "userdata" end
    return typeFunction(x)
end
_G.type = type
typeof = function(x)
    if getProxyValue(x) ~= 0 then return "number" end
    if isProxy(x) then
        local regName = dumperState.registry[x]
        if regName then
            if regName:match("Vector3") then return "Vector3" end
            if regName:match("CFrame") then return "CFrame" end
            if regName:match("Color3") then return "Color3" end
            if regName:match("UDim") then return "UDim2" end
            if regName:match("Enum") then return "EnumItem" end
        end
        return "Instance"
    end
    return typeFunction(x) == "table" and "table" or typeFunction(x)
end
_G.typeof = typeof
tonumber = function(x, base)
    if getProxyValue(x) ~= 0 then return 123456789 end
    return toNumberFunction(x, base)
end
_G.tonumber = tonumber
rawequal = function(a, b) return rawEqualFunction(a, b) end
_G.rawequal = rawequal
tostring = function(x)
    if isProxy(x) then
        local regName = dumperState.registry[x]
        return regName or "Instance"
    end
    return toStringFunction(x)
end
_G.tostring = tostring
dumperState.last_http_url = nil
loadstring = function(code, chunkName)
    if typeFunction(code) ~= "string" then return function() return createProxyObject("loaded", false) end end
    local url = dumperState.last_http_url or code
    dumperState.last_http_url = nil
    local libName = nil
    local lowerCode = url:lower()
    local libs = {{pattern = "rayfield", name = "Rayfield"}, {pattern = "orion", name = "OrionLib"}, {pattern = "kavo", name = "Kavo"}, {pattern = "venyx", name = "Venyx"}, {pattern = "sirius", name = "Sirius"}, {pattern = "linoria", name = "Linoria"}, {pattern = "wally", name = "Wally"}, {pattern = "dex", name = "Dex"}, {pattern = "infinite", name = "InfiniteYield"}, {pattern = "hydroxide", name = "Hydroxide"}, {pattern = "simplespy", name = "SimpleSpy"}, {pattern = "remotespy", name = "RemoteSpy"}}
    for _, lib in ipairsFunction(libs) do if lowerCode:find(lib.pattern) then libName = lib.name; break end end
    if libName then
        local proxy = createProxyObject(libName, false)
        dumperState.registry[proxy] = libName
        dumperState.names_used[libName] = true
        if url:match("^https?://") then emitOutput(string.format('local %s = loadstring(game:HttpGet("%s"))()', libName, url)) end
        return function() return proxy end
    end
    if url:match("^https?://") then
        local proxy = createProxyObject("Library", false)
        emitOutput(string.format('local luasploitsixseven = loadstring(game:HttpGet("%s"))()', url))
        return function() return proxy end
    end
    if typeFunction(code) == "string" then code = processString(code) end
    local func, err = loadFunction(code)
    if func then return func end
    local proxy = createProxyObject("LoadedChunk", false)
    return function() return proxy end
end
load = loadstring
_G.loadstring = loadstring
_G.load = loadstring
require = function(module)
    local modName = dumperState.registry[module] or serializeValue(module)
    local proxy = createProxyObject("RequiredModule", false)
    local varName = registerVariable(proxy, "module")
    emitOutput(string.format("local %s = require(%s)", varName, modName))
    return proxy
end
_G.require = require
print = function(...)
    local args = {...}
    local items = {}
    for _, val in ipairsFunction(args) do table.insert(items, serializeValue(val)) end
    emitOutput(string.format("print(%s)", table.concat(items, ", ")))
end
_G.print = print
warn = function(...)
    local args = {...}
    local items = {}
    for _, val in ipairsFunction(args) do table.insert(items, serializeValue(val)) end
    emitOutput(string.format("warn(%s)", table.concat(items, ", ")))
end
_G.warn = warn
shared = createProxyObject("shared", true)
_G.shared = shared
local globalBase = _G
local globalMeta = setmetatable({}, {
    __index = function(tbl, key)
        if configuration.VERBOSE then printFunction("[VERBOSE] Accessing field: " .. toStringFunction(key)) end
        local val = rawget(globalBase, key)
        if val == nil then val = rawget(_G, key) end
        if configuration.VERBOSE then
            if val ~= nil then
                if typeFunction(val) == "table" then printFunction("[VERBOSE] Found global table: " .. toStringFunction(key))
                elseif typeFunction(val) == "function" then printFunction("[VERBOSE] Found global function: " .. toStringFunction(key))
                else printFunction("[VERBOSE] Found global value: " .. toStringFunction(key) .. " = " .. toStringFunction(val)) end
            else
                printFunction("[VERBOSE] Missing field, providing dummy function: " .. toStringFunction(key))
                val = function() if configuration.VERBOSE then printFunction("[Missing Function] Called: " .. toStringFunction(key) .. " with 0 arguments") end return nil end
            end
        end
        return val
    end,
    __newindex = function(tbl, key, val) rawset(globalBase, key, val) end
})
_G._G = globalMeta
function proxyTable.reset()
    dumperState = {output = {}, indent = 0, registry = {}, reverse_registry = {}, names_used = {}, parent_map = {}, property_store = {}, call_graph = {}, variable_types = {}, string_refs = {}, proxy_id = 0, callback_depth = 0, pending_iterator = false, last_http_url = nil, last_emitted_line = nil, repetition_count = 0, current_size = 0, limit_reached = false, ls_counter = 0, captured_constants = {}}
    uiCounters = {}
    game = createProxyObject("game", true)
    workspace = createProxyObject("workspace", true)
    script = createProxyObject("script", true)
    Enum = createProxyObject("Enum", true)
    shared = createProxyObject("shared", true)
    dumperState.property_store[game] = {PlaceId = numericArg, GameId = numericArg, placeId = numericArg, gameId = numericArg}
    _G.game = game; _G.Game = game; _G.workspace = workspace; _G.Workspace = workspace; _G.script = script; _G.Enum = Enum; _G.shared = shared
    local meta = debugLibrary.getmetatable(Enum)
    meta.__index = function(_, key)
        if key == proxyList or key == "__proxy_id" then return rawget(_, key) end
        local enumProxy = createProxyObject("Enum." .. formatValue(key), false)
        dumperState.registry[enumProxy] = "Enum." .. formatValue(key)
        return enumProxy
    end
end
function proxyTable.get_output() return getFullOutput() end
function proxyTable.save(file) return saveToFile(file) end
function proxyTable.get_call_graph() return dumperState.call_graph end
function proxyTable.get_string_refs() return dumperState.string_refs end
function proxyTable.get_stats() return {total_lines = #dumperState.output, remote_calls = #dumperState.call_graph, suspicious_strings = #dumperState.string_refs, proxies_created = dumperState.proxy_id} end
local dumper = {callId = "LUASPLOIT_", binaryOperatorNames = {["and"] = "AND", ["or"] = "OR", [">"] = "GT", ["<"] = "LT", [">="] = "GE", ["<="] = "LE", ["=="] = "EQ", ["~="] = "NEQ", [".."] = "CAT"}}
function dumper:hook(code) return self.callId .. code end
function dumper:process_expr(expr)
    if not expr then return "nil" end
    if typeFunction(expr) == "string" then return expr end
    local tag = expr.tag or expr.kind
    if tag == "number" or tag == "string" then
        local val = tag == "string" and string.format("%q", expr.text) or (expr.value or expr.text)
        if configuration.CONSTANT_COLLECTION then return string.format("%sGET(%s)", self.callId, val) end
        return val
    end
    if tag == "local" or tag == "global" then return (expr.name or expr.token).text
    elseif tag == "boolean" or tag == "bool" then return toStringFunction(expr.value)
    elseif tag == "binary" then
        local lhs = self:process_expr(expr.lhsoperand)
        local rhs = self:process_expr(expr.rhsoperand)
        local op = expr.operator.text
        local opName = self.binaryOperatorNames[op]
        if opName then return string.format("%s%s(%s, %s)", self.callId, opName, lhs, rhs) end
        return string.format("(%s %s %s)", lhs, op, rhs)
    elseif tag == "call" then
        local func = self:process_expr(expr.func)
        local args = {}
        for i, node in ipairsFunction(expr.arguments) do args[i] = self:process_expr(node.node or node) end
        return string.format("%sCALL(%s, %s)", self.callId, func, table.concat(args, ", "))
    elseif tag == "indexname" or tag == "index" then
        local exprStr = self:process_expr(expr.expression)
        local keyStr = tag == "indexname" and string.format("%q", expr.index.text) or self:process_expr(expr.index)
        return string.format("%sCHECKINDEX(%s, %s)", self.callId, exprStr, keyStr)
    end
    return "nil"
end
function dumper:process_statement(stmt)
    if not stmt then return "" end
    local tag = stmt.tag
    if tag == "local" or tag == "assign" then
        local vars, vals = {}, {}
        for _, node in ipairsFunction(stmt.variables or {}) do table.insert(vars, self:process_expr(node.node or node)) end
        for _, node in ipairsFunction(stmt.values or {}) do table.insert(vals, self:process_expr(node.node or node)) end
        return (tag == "local" and "local " or "") .. table.concat(vars, ", ") .. " = " .. table.concat(vals, ", ")
    elseif tag == "block" then
        local stmts = {}
        for _, s in ipairsFunction(stmt.statements or {}) do table.insert(stmts, self:process_statement(s)) end
        return table.concat(stmts, "; ")
    end
    return self:process_expr(stmt) or ""
end
function proxyTable.dump_file(inputPath, outputPath)
    proxyTable.reset()
    emitComment("--[[ This File Has Been Generated By Speack | https://discord.gg/VS9TGtMt9Q ]]")
    local file = ioLibrary.open(inputPath, "rb")
    if not file then return false end
    local code = file:read("*a")
    file:close()
    printFunction("[Dumper] Sanitizing Luau and Binary Literals...")
    local sanitized = processString(code)
    local func, err = loadFunction(sanitized, "Obfuscated_Script")
    if not func then printFunction("\n[LUA_LOAD_FAIL] " .. toStringFunction(err)) return false end
    local env = setmetatable({
        LuraphContinue = function() end,
        script = script, game = game, workspace = workspace,
        LUASPLOIT_CHECKINDEX = function(tbl, key)
            local val = tbl[key]
            if typeFunction(val) == "table" and not dumperState.registry[val] then
                dumperState.ls_counter = dumperState.ls_counter + 1
                dumperState.registry[val] = "ls" .. dumperState.ls_counter
            end
            return val
        end,
        LUASPLOIT_GET = function(v) return v end,
        LS_CALL = function(f, ...)
            if configuration.VERBOSE then printFunction("[VERBOSE] LS_CALL called with function: " .. toStringFunction(f)) end
            if typeFunction(f) ~= "function" then
                if configuration.VERBOSE then printFunction("[Missing Function] Called: " .. toStringFunction(f)) end
                return nil
            end
            return f(...)
        end,
        LS_NAMECALL = function(t, method, ...)
            if configuration.VERBOSE then printFunction("[VERBOSE] LS_NAMECALL called on table: " .. toStringFunction(t) .. " method: " .. toStringFunction(method)) end
            if typeFunction(t) ~= "table" then return nil end
            if typeFunction(t[method]) ~= "function" then return nil end
            return t[method](t, ...)
        end,
        LUASPLOIT_CALL = function(f, ...) return f(...) end,
        LUASPLOIT_NAMECALL = function(t, method, ...) return t[method](t, ...) end,
        pcall = function(f, ...)
            local res = {pcallFunction(f, ...)}
            if not res[1] and toStringFunction(res[2]):match("TIMEOUT") then errorFunction(res[2], 0) end
            return table.unpack(res)
        end
    }, {__index = _G, __newindex = _G})
    if setfenv then setfenv(func, env) end
    printFunction("[Dumper] Executing Protected VM...")
    local startClock = osLibrary.clock()
    setHook(function() if osLibrary.clock() - startClock > configuration.TIMEOUT_SECONDS then errorFunction("TIMEOUT", 0) end end, "", 1000)
    local success, err = xpcallFunction(function() func() end, function(e) return toStringFunction(e) end)
    setHook()
    if not success then emitComment("Terminated: " .. err) end
    return proxyTable.save(outputPath or configuration.OUTPUT_FILE)
end
function proxyTable.dump_string(code, outputPath)
    proxyTable.reset()
    emitComment("--[[ This File Has Been Generated By Speack | https://discord.gg/VS9TGtMt9Q ]]")
    addEmptyLine()
    if code then code = processString(code) end
    local func, err = loadFunction(code)
    if not func then emitComment("Load Error: " .. (err or "unknown")) return false, err end
    xpcallFunction(function() func() end, function() end)
    if outputPath then return proxyTable.save(outputPath) end
    return true, getFullOutput()
end
if arg and arg[1] then
    local success = proxyTable.dump_file(arg[1], arg[2])
    if success then
        printFunction("Saved to: " .. (arg[2] or configuration.OUTPUT_FILE))
        local stats = proxyTable.get_stats()
        printFunction(string.format("Lines: %d | Remotes: %d | Strings: %d", stats.total_lines, stats.remote_calls, stats.suspicious_strings))
    end
else
    local file = ioLibrary.open("obfuscated.lua", "rb")
    if file then
        file:close()
        local success = proxyTable.dump_file("obfuscated.lua")
        if success then
            printFunction("Saved to: " .. configuration.OUTPUT_FILE)
            printFunction(proxyTable.get_output())
        end
    else
        printFunction("Usage: lua dumper.lua <input> [output] [key]")
    end
end
_G.LuraphContinue = function() end
return proxyTable
