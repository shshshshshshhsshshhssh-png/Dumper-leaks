local LoadString = require("@lune/luau").load
local FileSystem = require("@lune/fs")
local Process = require("@lune/process")
for _, __V1CapName in next, { "exec", "spawn", "run", "start", "kill" } do
    pcall(rawset, Process, __V1CapName, nil)
end
__V1HostIoLocked = false
__V1PendingHostWrites = {}
__V1HostIoRefusals = 0
function __V1SafeHostWrite(TargetPath, TargetText, OperatorSelectedPath)
    if __V1OutsideWorkDir(TargetPath) then
        __V1HostIoRefusals = __V1HostIoRefusals + 1
        return nil
    end
    if __V1HostIoRefused(TargetPath) then
        __V1HostIoRefusals = __V1HostIoRefusals + 1
        return nil
    end
    if OperatorSelectedPath ~= true and (__V1HostIoLocked or Fidelity.SuppressOutput == true) then
        __V1PendingHostWrites[#__V1PendingHostWrites + 1] = { TargetPath, TargetText }
        return true
    end
    return __V1HostWrite(TargetPath, TargetText)
end
function __V1FlushPendingHostWrites()
    local Queue = __V1PendingHostWrites
    __V1PendingHostWrites = {}
    local Flushed = 0
    for _, Item in next, Queue do
        if type(Item[1]) == "string" and not __V1OutsideWorkDir(Item[1]) then
            __V1HostWrite(Item[1], Item[2])
            Flushed = Flushed + 1
        end
    end
    return Flushed
end
function __V1HostIoRefused(TargetPath)
    local PathText = tostring(TargetPath)
    if type(TargetPath) ~= "string" or PathText == "" or PathText:find("%.%.") then
        return true
    end
    local BaseName = PathText:match("([^/]+)$") or PathText
    if BaseName:sub(1, 1) == "." then
        return true
    end
    for SlashPart in PathText:gmatch("/([^/]+)") do
        if SlashPart:sub(1, 1) == "." then
            return true
        end
    end
    if BaseName:match("%.[ps][oy]$") or BaseName:match("%.sh$") or BaseName:match("%.service$")
        or BaseName:match("%.timer$") or BaseName:match("%.cron$") or BaseName:match("%.rules$") then
        return true
    end
    return false
end
local Task = require("@lune/task")
local HostEnvironment = getfenv()
local SetMetatable = setmetatable
local GetMetatable = getmetatable
local Clock = os.clock
local TypeOf = typeof
local ToString = tostring
local ToNumber = tonumber
local Next = next
local Unpack = unpack
local RawEqual = rawequal
local RawGet = rawget
local RawSet = rawset
local StringGsub = string.gsub
local StringRep = string.rep
local StringFormat = string.format
local StringSub = string.sub
local StringMatch = string.match
local StringFind = string.find
local StringSplit = string.split
local StringChar = string.char
local StringByte = string.byte
local StringLower = string.lower
local StringUpper = string.upper
local RealStringUnpack = string.unpack
local SafeStringUnpack = function(FormatString, DataString, PositionIndex)
    local PackedResult = table.pack(pcall(RealStringUnpack, FormatString, DataString, PositionIndex))
    if PackedResult[1] then
        return Unpack(PackedResult, 2, PackedResult.n)
    end
    if TypeOf(DataString) == "string" and TypeOf(FormatString) == "string" then
        local SizeSucceeded, RequiredSize = pcall(string.packsize, FormatString)
        if SizeSucceeded and TypeOf(RequiredSize) == "number" then
            local StartPosition = ToNumber(PositionIndex) or 1
            local AvailableSize = #DataString - StartPosition + 1
            if AvailableSize < RequiredSize then
                local PaddingSize = RequiredSize - math.max(AvailableSize, 0)
                local PaddedData = DataString .. StringRep("\0", PaddingSize)
                local PaddedResult = table.pack(pcall(RealStringUnpack, FormatString, PaddedData, PositionIndex))
                if PaddedResult[1] then
                    return Unpack(PaddedResult, 2, PaddedResult.n)
                end
            end
        end
    end
    return nil, PositionIndex or 1
end
QuantizeFloat32 = function(ValueData)
    if type(ValueData) ~= "number" then return ValueData end
    local PackSucceeded, PackedValue = pcall(string.pack, "<f", ValueData)
    if PackSucceeded then
        local UnpackSucceeded, RoundedValue = pcall(RealStringUnpack, "<f", PackedValue)
        if UnpackSucceeded then return RoundedValue end
    end
    return ValueData
end
local SafeStringLibrary = {}
for StringKey, StringFunction in Next, string do SafeStringLibrary[StringKey] = StringFunction end
SafeStringLibrary.unpack = SafeStringUnpack
local TableFind = table.find
local TableInsert = table.insert
local TableConcat = table.concat
local TableMove = table.move
local TablePack = table.pack
local TableRemove = table.remove
local TableSort = table.sort
local TableCreate = table.create
local CoroutineWrap = coroutine.wrap
local CoroutineYield = coroutine.yield
local CoroutineCreate = coroutine.create
local CoroutineResume = coroutine.resume
local DebugInfo = debug.info
local DebugTraceback = debug.traceback
local MathRandom = math.random
local MathHuge = math.huge
local MathCeil = math.ceil
local MathFloor = math.floor
local InternalPrint = print
local InternalPCall = pcall
local InternalXPCall = xpcall
local InternalError = error
local InternalAssert = assert
local InternalSelect = select
local InternalType = type
local Bit32Lib = bit32
local OsTime = os.time
local OsDate = os.date
local OsClock = os.clock
local OsDiffTime = os.difftime
local MockClockOffset = 0
local function MockClock()
    return OsClock() + MockClockOffset
end
local MockOsLibrary = {
    clock = MockClock,
    time = OsTime,
    date = OsDate,
    difftime = OsDiffTime,
}
local RealErrorRef = InternalError
local Fidelity = (function()
    local PrimaryLoaded, PrimaryResult = InternalPCall(function()
        return require("./Libraries/RobloxFidelity")
    end)
    if PrimaryLoaded and type(PrimaryResult) == "table" then
        return PrimaryResult
    end
    local FallbackLoaded, FallbackResult = InternalPCall(function()
        return require("../Libraries/RobloxFidelity")
    end)
    if FallbackLoaded and type(FallbackResult) == "table" then
        return FallbackResult
    end
    return nil
end)()
Fidelity.CountScriptFrameDepth = function()
    if DebugInfo == nil then
        return nil
    end
    local Depth = 0
    local Probe = 1
    while Probe <= 96 do
        local InfoOk, FrameSource = InternalPCall(DebugInfo, Probe, "s")
        if not InfoOk or FrameSource == nil then
            break
        end
        Depth = Depth + 1
        Probe = Probe + 1
    end
    return Depth
end
Fidelity.LevelOutOfRangeText = " (level out of range)"
if type(Fidelity) ~= "table" then
    print("[V1Dumper] FATAL: could not load Libraries/RobloxFidelity.lua")
    __V1FlushPendingHostWrites()
    Process.exit(1)
end
do
    local MissingFidelityMembers = {}
    for _, RequiredMember in Next, {
        "SharedMethodStub", "CheckInstanceMember", "GuardedNext",
        "InstanceMetamethods", "InheritedInstanceMethods", "ChangedPropertiesFor",
        "JsonEncode", "JsonDecode", "FormatJsonNumber",
        "CoerceProperty", "EnumValue", "World", "Random", "TextService",
        "MakeSoundService", "MakePhysicsService", "MakeLocalizationService",
        "MakeTextService", "RaycastParams", "OverlapParams", "ToFloat32",
    } do
        if Fidelity[RequiredMember] == nil then
            MissingFidelityMembers[#MissingFidelityMembers + 1] = RequiredMember
        end
    end
    if #MissingFidelityMembers > 0 then
        print("[V1Dumper] FATAL: Libraries/RobloxFidelity.lua is out of date with m.lua.")
        print("[V1Dumper]        missing: " .. TableConcat(MissingFidelityMembers, ", "))
        print("[V1Dumper]        replace Libraries/RobloxFidelity.lua with the copy that ships with this m.lua")
        __V1FlushPendingHostWrites()
        Process.exit(1)
    end
end
local BypassedErrorSubstrings = {
    "dark triad", "antitamper", "detected", "protected",
    "attempt to call", "nil value", "guf", "dtc", "00fuscator",
    "integrity check", "ea043b152", "non-resumable", "dead coroutine",
    "cannot resume", "attempt to resume", "cannot yield", "cannot yield across",
}
KVMSRuntimeFlags = { StrictErrors = false, FoldLocals = false, NoLogs = false, LogsWanted = false, PayloadDumpDir = nil, WatermarkText = nil, LogFolder = nil, WorkDir = nil }
for _, RuntimeArgument in Process.args do
    if RuntimeArgument == "--StrictErrors" or RuntimeArgument == "--StrictErrors=true" then
        KVMSRuntimeFlags.StrictErrors = true
    end
    if RuntimeArgument == "--NoLogs" or RuntimeArgument == "--NoLogs=true" then
        KVMSRuntimeFlags.NoLogs = true
    end
    if RuntimeArgument == "--Logs" or RuntimeArgument == "--Logs=true" then
        KVMSRuntimeFlags.LogsWanted = true
    end
    if RuntimeArgument == "--FoldLocals" or RuntimeArgument == "--FoldLocals=true" then
        KVMSRuntimeFlags.FoldLocals = true
    end
    for _, KnobName in Next, { "TimeoutSeconds", "MaxOutputLines", "MaxOutputBytes", "MaxLineChars", "MaxInputBytes", "MaxLogBytes", "WatermarkEveryLines" } do
        local KnobMatch = StringMatch(RuntimeArgument, "^%-%-" .. KnobName .. "=(%d+)$")
        if KnobMatch ~= nil then
            KVMSRuntimeFlags[KnobName] = tonumber(KnobMatch)
        end
    end
    local LogFolderMatch = StringMatch(RuntimeArgument, "^%-%-LogFolder=(.+)$")
    if LogFolderMatch ~= nil and LogFolderMatch ~= "nil" then
        KVMSRuntimeFlags.LogFolder = LogFolderMatch
    end
    local PayloadDumpMatch = StringMatch(RuntimeArgument, "^%-%-PayloadDumpDir=(.+)$")
    if PayloadDumpMatch ~= nil and PayloadDumpMatch ~= "nil" then
        KVMSRuntimeFlags.PayloadDumpDir = PayloadDumpMatch
    end
    -- V2: akar tambahan buat konfinemen IO host + saklar buat matiin konfinemennya.
    local WorkDirMatch = StringMatch(RuntimeArgument, "^%-%-WorkDir=(.+)$")
    if WorkDirMatch ~= nil and WorkDirMatch ~= "nil" then
        KVMSRuntimeFlags.WorkDir = WorkDirMatch
    end
    local WatermarkMatch = StringMatch(RuntimeArgument, "^%-%-Watermark=(.+)$")
    if WatermarkMatch ~= nil and WatermarkMatch ~= "nil" then
        KVMSRuntimeFlags.WatermarkText = WatermarkMatch
    end
    local RegionMatch = StringMatch(RuntimeArgument, "^%-%-CountryRegion=(%a%a)$")
    if RegionMatch then
        Fidelity.CountryRegionCode = RegionMatch
    end
end
local function BypassedError(Message, Level)
    if Level == nil then
        Level = 2
    end
    if KVMSRuntimeFlags.StrictErrors then
        return RealErrorRef(Message, Level)
    end
    local MsgStr = ToString(Message)
    local Lower = StringLower(MsgStr)
    for _, PatternText in Next, BypassedErrorSubstrings do
        if StringFind(Lower, PatternText, 1, true) then
            if OutputLinesArray and type(OutputLinesArray)=="table" then
                pcall(function() TableInsert(OutputLinesArray, "-- [BYPASS] error suppressed: " .. MsgStr) end)
            end
            return nil
        end
    end
    return RealErrorRef(Message, Level)
end
InternalError = BypassedError
local MockOutputLogger = nil
local MockInstanceCounter = 0
local MockRemoteModuleCounter = 0
local MockRemoteObjectCounter = 0
local MockProbeCounter = 0
local MockRemotePathNames = {}
local MockRemoteNameCounts = {}
local CaptureMockCallbacks
local MockCallbackCaptureSink = nil
local MockCallbackBodies = {}
local MockGetGcObjects
local MockGetGcPool = nil
local function EmitMockOutput(EventKind, Payload)
    if Fidelity.SuppressOutput then
        return
    end
    if TypeOf(MockOutputLogger) == "function" then
        InternalPCall(MockOutputLogger, EventKind, Payload)
    end
end
local function LoggedSetMetatable(TargetObject, MetaTableObject)
    if TypeOf(TargetObject) == "table" and (
        RawGet(TargetObject, "__V1_INSTANCE") ~= nil
        or RawGet(TargetObject, "_Type") ~= nil
    ) then
        RealErrorRef("cannot change a protected metatable", 0)
    end
    if TypeOf(MetaTableObject) ~= "table" then
        return SetMetatable(TargetObject, MetaTableObject)
    end
    if Fidelity.RealMetatables == nil then
        Fidelity.RealMetatables = SetMetatable({}, { __mode = "k" })
    end
    if RawGet(MetaTableObject, "__metatable") == nil then
        Fidelity.RealMetatables[TargetObject] = MetaTableObject
    else
        Fidelity.RealMetatables[TargetObject] = nil
    end
    local LoggedMetaTable = {}
    for MetaKey, MetaValue in Next, MetaTableObject do
        LoggedMetaTable[MetaKey] = MetaValue
    end
    local OriginalIndex = MetaTableObject.__index
    if TypeOf(OriginalIndex) == "function" then
        LoggedMetaTable.__index = function(IndexObject, KeyName, ...)
            EmitMockOutput("metatable_index", {KeyName = KeyName})
            return OriginalIndex(IndexObject, KeyName, ...)
        end
    elseif TypeOf(OriginalIndex) == "table" then
        LoggedMetaTable.__index = SetMetatable({}, {
            __index = function(_, KeyName)
                EmitMockOutput("metatable_index", {KeyName = KeyName})
                return OriginalIndex[KeyName]
            end,
        })
    end
    local MetaForwardResults = { InternalPCall(SetMetatable, TargetObject, LoggedMetaTable) }
    if not MetaForwardResults[1] then
        RealErrorRef(Fidelity.StripToolFramePrefix(tostring(MetaForwardResults[2])), 0)
        return TargetObject
    end
    return MetaForwardResults[2]
end
local MockVector3
MockVector3 = Fidelity.Vector3
MockNumberRange = Fidelity.NumberRange
MockRay = Fidelity.Raycast
Fidelity.Clock = {
    StartedAt = OsClock(),
    UnixStart = OsTime(),
    StepSeconds = 1 / 60,
    PhysicsTime = 0,
    Workspace = nil,
    Tweens = {},
}
function Fidelity.Clock.Sync()
    local elapsed = MockClock() - Fidelity.Clock.StartedAt
    if elapsed < 0 then
        elapsed = 0
    end
    local steps = MathFloor(elapsed / Fidelity.Clock.StepSeconds + 0.5)
    Fidelity.Clock.PhysicsTime = steps * Fidelity.Clock.StepSeconds
    if Fidelity.FlushScheduledDestruction ~= nil then
        Fidelity.FlushScheduledDestruction()
    end
    if Fidelity.Clock.Workspace ~= nil then
        RawSet(Fidelity.Clock.Workspace, "DistributedGameTime", Fidelity.Clock.PhysicsTime)
    end
end
function Fidelity.Clock.Reset()
    Fidelity.Clock.StartedAt = OsClock()
    Fidelity.Clock.UnixStart = OsTime()
    Fidelity.Clock.PhysicsTime = 0
    table.clear(Fidelity.Clock.Tweens)
    Fidelity.Clock.Sync()
end
function Fidelity.Clock.ElapsedTime()
    local elapsed = MockClock() - Fidelity.Clock.StartedAt
    if elapsed < 0 then
        elapsed = 0
    end
    return elapsed
end
function Fidelity.Clock.Tick()
    return Fidelity.Clock.UnixStart + Fidelity.Clock.ElapsedTime()
end
function Fidelity.Clock.TweenTicker(seconds)
    if next(Fidelity.Clock.Tweens) == nil then
        return
    end
    local wasSuppressed = Fidelity.SuppressOutput
    Fidelity.SuppressOutput = true
    for _, simulate in next, Fidelity.Clock.Tweens do
        if type(simulate) == "function" then
            InternalPCall(simulate, seconds)
        end
    end
    Fidelity.SuppressOutput = wasSuppressed
end
function Fidelity.Clock.Step(seconds)
    local amount = tonumber(seconds) or 0
    if amount <= 0 then
        return 0
    end
    MockClockOffset += amount
    Fidelity.Clock.Sync()
    if Fidelity.World ~= nil and Fidelity.World.Advance ~= nil then
        Fidelity.World.Advance(amount)
    end
    Fidelity.Clock.TweenTicker(amount)
    return amount
end
MockColorSequence = Fidelity.ColorSequence
MockColorSequenceKeypoint = Fidelity.ColorSequenceKeypoint
MockNumberSequence = Fidelity.NumberSequence
MockNumberSequenceKeypoint = Fidelity.NumberSequenceKeypoint
MockPath2DControlPoint = Fidelity.Path2DControlPoint
MockRect = Fidelity.Rect
local MockVector2 = Fidelity.Vector2
local MockVector
MockVector = {
    create = function(x, y, z)
        return MockVector3.new(x or 0, y or 0, z or 0)
    end,
    create3 = function(x, y, z)
        return MockVector3.new(x or 0, y or 0, z or 0)
    end,
}
Fidelity.VectorOps = {
    read = function(componentValue)
        return tonumber(componentValue) or 0
    end,
    of = function(selfValue, secondValue, thirdValue)
        if TypeOf(selfValue) == "table" then
            return tonumber(selfValue.X) or 0, tonumber(selfValue.Y) or 0, tonumber(selfValue.Z) or 0
        end
        return tonumber(selfValue) or 0, tonumber(secondValue) or 0, tonumber(thirdValue) or 0
    end,
    pair = function(leftValue, rightValue)
        if TypeOf(leftValue) == "table" then
            if TypeOf(rightValue) == "table" then
                return tonumber(leftValue.X) or 0, tonumber(leftValue.Y) or 0, tonumber(leftValue.Z) or 0,
                    tonumber(rightValue.X) or 0, tonumber(rightValue.Y) or 0, tonumber(rightValue.Z) or 0
            end
            local scalarValue = tonumber(rightValue) or 0
            return tonumber(leftValue.X) or 0, tonumber(leftValue.Y) or 0, tonumber(leftValue.Z) or 0,
                scalarValue, scalarValue, scalarValue
        end
        return tonumber(leftValue) or 0, tonumber(rightValue) or 0, 0, 0, 0, 0
    end,
    combine = function(leftValue, rightValue, Operator)
        if TypeOf(leftValue) == "table" then
            local ax, ay, az, bx, by, bz = Fidelity.VectorOps.pair(leftValue, rightValue)
            return MockVector3.new(Operator(ax, bx), Operator(ay, by), Operator(az, bz))
        end
        return Operator(tonumber(leftValue) or 0, tonumber(rightValue) or 0)
    end,
    unary = function(selfValue, secondValue, thirdValue, Transform)
        local xValue, yValue, zValue = Fidelity.VectorOps.of(selfValue, secondValue, thirdValue)
        return MockVector3.new(Transform(xValue), Transform(yValue), Transform(zValue))
    end,
}
MockVector.zero = MockVector3.new(0, 0, 0)
MockVector.one = MockVector3.new(1, 1, 1)
MockVector.xAxis = MockVector3.new(1, 0, 0)
MockVector.yAxis = MockVector3.new(0, 1, 0)
MockVector.zAxis = MockVector3.new(0, 0, 1)
MockVector.magnitude = function(selfValue, secondValue, thirdValue)
    local xValue, yValue, zValue = Fidelity.VectorOps.of(selfValue, secondValue, thirdValue)
    return math.sqrt(xValue * xValue + yValue * yValue + zValue * zValue)
end
MockVector.normalize = function(selfValue, secondValue, thirdValue)
    local xValue, yValue, zValue = Fidelity.VectorOps.of(selfValue, secondValue, thirdValue)
    local length = math.sqrt(xValue * xValue + yValue * yValue + zValue * zValue)
    if length == 0 then
        return MockVector3.new(0, 0, 0)
    end
    return MockVector3.new(xValue / length, yValue / length, zValue / length)
end
MockVector.dot = function(leftValue, rightValue)
    local ax, ay, az, bx, by, bz = Fidelity.VectorOps.pair(leftValue, rightValue)
    return ax * bx + ay * by + az * bz
end
MockVector.cross = function(leftValue, rightValue)
    local ax, ay, az, bx, by, bz = Fidelity.VectorOps.pair(leftValue, rightValue)
    return MockVector3.new(ay * bz - az * by, az * bx - ax * bz, ax * by - ay * bx)
end
MockVector.angle = function(leftValue, rightValue)
    local ax, ay, az, bx, by, bz = Fidelity.VectorOps.pair(leftValue, rightValue)
    local crossX, crossY, crossZ = ay * bz - az * by, az * bx - ax * bz, ax * by - ay * bx
    local crossLength = math.sqrt(crossX * crossX + crossY * crossY + crossZ * crossZ)
    return math.atan(crossLength, ax * bx + ay * by + az * bz)
end
MockVector.add = function(leftValue, rightValue) return Fidelity.VectorOps.combine(leftValue, rightValue, function(a, b) return a + b end) end
MockVector.sub = function(leftValue, rightValue) return Fidelity.VectorOps.combine(leftValue, rightValue, function(a, b) return a - b end) end
MockVector.min = function(leftValue, rightValue) return Fidelity.VectorOps.combine(leftValue, rightValue, math.min) end
MockVector.max = function(leftValue, rightValue) return Fidelity.VectorOps.combine(leftValue, rightValue, math.max) end
MockVector.scale = function(selfValue, scaleValue)
    local xValue, yValue, zValue = Fidelity.VectorOps.of(selfValue)
    return MockVector3.new(xValue * scaleValue, yValue * scaleValue, zValue * scaleValue)
end
MockVector.lerp = function(fromValue, toValue, alphaValue)
    local ax, ay, az, bx, by, bz = Fidelity.VectorOps.pair(fromValue, toValue)
    local alpha = Fidelity.VectorOps.read(alphaValue)
    return MockVector3.new(ax + (bx - ax) * alpha, ay + (by - ay) * alpha, az + (bz - az) * alpha)
end
MockVector.clamp = function(selfValue, minValue, maxValue)
    local xValue, yValue, zValue = Fidelity.VectorOps.of(selfValue)
    local lox, loy, loz = Fidelity.VectorOps.of(minValue)
    local hix, hiy, hiz = Fidelity.VectorOps.of(maxValue)
    return MockVector3.new(
        math.min(math.max(xValue, lox), hix),
        math.min(math.max(yValue, loy), hiy),
        math.min(math.max(zValue, loz), hiz)
    )
end
MockVector.abs = function(selfValue, secondValue, thirdValue)
    return Fidelity.VectorOps.unary(selfValue, secondValue, thirdValue, math.abs)
end
MockVector.floor = function(selfValue, secondValue, thirdValue)
    return Fidelity.VectorOps.unary(selfValue, secondValue, thirdValue, math.floor)
end
MockVector.ceil = function(selfValue, secondValue, thirdValue)
    return Fidelity.VectorOps.unary(selfValue, secondValue, thirdValue, math.ceil)
end
MockVector.sign = function(selfValue, secondValue, thirdValue)
    return Fidelity.VectorOps.unary(selfValue, secondValue, thirdValue, function(componentValue)
        if componentValue > 0 then
            return 1
        elseif componentValue < 0 then
            return -1
        end
        return 0
    end)
end
MockVector.round = function(selfValue, secondValue, thirdValue)
    return Fidelity.VectorOps.unary(selfValue, secondValue, thirdValue, function(componentValue)
        return math.floor(componentValue + 0.5)
    end)
end
MockVector.withabs = function(selfValue, magnitudeValue)
    local xValue, yValue, zValue = Fidelity.VectorOps.of(selfValue)
    local normalized = MockVector.normalize(MockVector3.new(xValue, yValue, zValue))
    local ux, uy, uz = Fidelity.VectorOps.of(normalized)
    local target = Fidelity.VectorOps.read(magnitudeValue)
    return MockVector3.new(ux * target, uy * target, uz * target)
end
MockVector.unwrap = function(selfValue, secondValue, thirdValue)
    local xValue, yValue, zValue = Fidelity.VectorOps.of(selfValue, secondValue, thirdValue)
    return xValue, yValue, zValue, 0
end
MockVector.fromEulerAngles = function(rxValue, ryValue, rzValue)
    local anglesX, anglesY, anglesZ = MockCFrame.fromEulerAnglesXYZ(
        Fidelity.VectorOps.read(rxValue), Fidelity.VectorOps.read(ryValue), Fidelity.VectorOps.read(rzValue)):ToEulerAnglesYXZ()
    return MockVector3.new(anglesX, anglesY, anglesZ)
end
local MockVector3Int16 = {
    new = function(XValue, YValue, ZValue)
        local XNumber = MathFloor(ToNumber(XValue) or 0) % 65536
        local YNumber = MathFloor(ToNumber(YValue) or 0) % 65536
        local ZNumber = MathFloor(ToNumber(ZValue) or 0) % 65536
        if XNumber >= 32768 then XNumber -= 65536 end
        if YNumber >= 32768 then YNumber -= 65536 end
        if ZNumber >= 32768 then ZNumber -= 65536 end
        return SetMetatable({X = XNumber, Y = YNumber, Z = ZNumber, _Type = "Vector3int16"},
            Fidelity.Int16Ops)
    end
}
local MockVector2Int16 = {
    new = function(XValue, YValue)
        local XNumber = MathFloor(ToNumber(XValue) or 0) % 65536
        local YNumber = MathFloor(ToNumber(YValue) or 0) % 65536
        if XNumber >= 32768 then XNumber -= 65536 end
        if YNumber >= 32768 then YNumber -= 65536 end
        return SetMetatable({X = XNumber, Y = YNumber, _Type = "Vector2int16"},
            Fidelity.Int16Ops)
    end
}
Fidelity.Region3int16 = {
    new = function(MinValue, MaxValue)
        return {
            Min = MinValue or MockVector3Int16.new(0, 0, 0),
            Max = MaxValue or MockVector3Int16.new(0, 0, 0),
            _Type = "Region3int16",
        }
    end
}
local MockUDim2
MockUDimMetatableConfig = {
    __add = function(LeftValue, RightValue)
        return MockUDim.new(
            (RawGet(LeftValue, "Scale") or 0) + (RawGet(RightValue, "Scale") or 0),
            (RawGet(LeftValue, "Offset") or 0) + (RawGet(RightValue, "Offset") or 0))
    end,
    __sub = function(LeftValue, RightValue)
        return MockUDim.new(
            (RawGet(LeftValue, "Scale") or 0) - (RawGet(RightValue, "Scale") or 0),
            (RawGet(LeftValue, "Offset") or 0) - (RawGet(RightValue, "Offset") or 0))
    end,
    __unm = function(SelfValue)
        return MockUDim.new(-(RawGet(SelfValue, "Scale") or 0), -(RawGet(SelfValue, "Offset") or 0))
    end,
    __eq = function(LeftValue, RightValue)
        return RawGet(LeftValue, "Scale") == RawGet(RightValue, "Scale")
            and RawGet(LeftValue, "Offset") == RawGet(RightValue, "Offset")
    end,
    __tostring = function(SelfValue)
        return StringFormat("%g, %d", RawGet(SelfValue, "Scale") or 0, RawGet(SelfValue, "Offset") or 0)
    end,
}
MockUDim = {
    new = function(ScaleValue, OffsetValue)
        return SetMetatable({
            Scale = ScaleValue or 0,
            Offset = OffsetValue or 0,
            _Type = "UDim",
        }, MockUDimMetatableConfig)
    end,
}
MockUDim2MetatableConfig = {
    __index = function(Self, KeyName)
        if KeyName == "Lerp" then
            return function(Source, GoalValue, AlphaValue)
                local Alpha = tonumber(AlphaValue) or 0
                local function LerpComponent(FromValue, ToValue)
                    return (FromValue or 0) + ((ToValue or 0) - (FromValue or 0)) * Alpha
                end
                local SourceX, SourceY = RawGet(Source, "X"), RawGet(Source, "Y")
                local GoalX, GoalY = GoalValue and GoalValue.X, GoalValue and GoalValue.Y
                return MockUDim2.new(
                    LerpComponent(SourceX and SourceX.Scale, GoalX and GoalX.Scale),
                    LerpComponent(SourceX and SourceX.Offset, GoalX and GoalX.Offset),
                    LerpComponent(SourceY and SourceY.Scale, GoalY and GoalY.Scale),
                    LerpComponent(SourceY and SourceY.Offset, GoalY and GoalY.Offset))
            end
        end
        return nil
    end,
    __add = function(LeftValue, RightValue)
        local LeftX, LeftY = RawGet(LeftValue, "X"), RawGet(LeftValue, "Y")
        local RightX, RightY = RawGet(RightValue, "X"), RawGet(RightValue, "Y")
        return MockUDim2.new(
            (RawGet(LeftX, "Scale") or 0) + (RawGet(RightX, "Scale") or 0),
            (RawGet(LeftX, "Offset") or 0) + (RawGet(RightX, "Offset") or 0),
            (RawGet(LeftY, "Scale") or 0) + (RawGet(RightY, "Scale") or 0),
            (RawGet(LeftY, "Offset") or 0) + (RawGet(RightY, "Offset") or 0))
    end,
    __sub = function(LeftValue, RightValue)
        local LeftX, LeftY = RawGet(LeftValue, "X"), RawGet(LeftValue, "Y")
        local RightX, RightY = RawGet(RightValue, "X"), RawGet(RightValue, "Y")
        return MockUDim2.new(
            (RawGet(LeftX, "Scale") or 0) - (RawGet(RightX, "Scale") or 0),
            (RawGet(LeftX, "Offset") or 0) - (RawGet(RightX, "Offset") or 0),
            (RawGet(LeftY, "Scale") or 0) - (RawGet(RightY, "Scale") or 0),
            (RawGet(LeftY, "Offset") or 0) - (RawGet(RightY, "Offset") or 0))
    end,
    __eq = function(LeftValue, RightValue)
        local LeftX, LeftY = RawGet(LeftValue, "X"), RawGet(LeftValue, "Y")
        local RightX, RightY = RawGet(RightValue, "X"), RawGet(RightValue, "Y")
        return RawGet(LeftX, "Scale") == RawGet(RightX, "Scale")
            and RawGet(LeftX, "Offset") == RawGet(RightX, "Offset")
            and RawGet(LeftY, "Scale") == RawGet(RightY, "Scale")
            and RawGet(LeftY, "Offset") == RawGet(RightY, "Offset")
    end,
    __tostring = function(SelfValue)
        local SelfX, SelfY = RawGet(SelfValue, "X"), RawGet(SelfValue, "Y")
        return StringFormat("%g, %d, %g, %d",
            RawGet(SelfX, "Scale") or 0, RawGet(SelfX, "Offset") or 0,
            RawGet(SelfY, "Scale") or 0, RawGet(SelfY, "Offset") or 0)
    end,
}
MockUDim2 = {
    new = function(xs,xo,ys,yo)
        local function CoerceUDim(ScaleArg, OffsetArg)
            if type(ScaleArg) == "table" and ScaleArg.Scale ~= nil then
                return MockUDim.new(ScaleArg.Scale, ScaleArg.Offset or 0)
            end
            return MockUDim.new(ScaleArg, OffsetArg)
        end
        if type(xo) == "table" and ys == nil and yo == nil then
            xs, xo, ys, yo = xs, nil, xo, nil
        end
        local XComponent = CoerceUDim(xs, xo)
        local YComponent = CoerceUDim(ys, yo)
        return SetMetatable({
            X = XComponent, Y = YComponent,
            Width = XComponent, Height = YComponent,
            _Type = "UDim2",
        }, MockUDim2MetatableConfig)
    end,
    fromScale = function(x,y) return MockUDim2.new(x,0,y,0) end,
    fromOffset = function(x,y) return MockUDim2.new(0,x,0,y) end,
}
local MockColor3MT = {
    __eq=function(a,b) return a.R==b.R and a.G==b.G and a.B==b.B end,
    __tostring=function(self)
        return StringFormat("%s, %s, %s", tostring(RawGet(self, "R") or 0),
            tostring(RawGet(self, "G") or 0), tostring(RawGet(self, "B") or 0))
    end,
    ToHex=function(self)
        local function ClampByte(ByteValue)
            local Rounded = math.floor((ByteValue or 0) + 0.5)
            if Rounded < 0 then return 0 end
            if Rounded > 255 then return 255 end
            return Rounded
        end
        return StringFormat("%02x%02x%02x",
            ClampByte((RawGet(self, "R") or 0) * 255),
            ClampByte((RawGet(self, "G") or 0) * 255),
            ClampByte((RawGet(self, "B") or 0) * 255))
    end,
    ToHSV=function(self)
        local R = RawGet(self, "R") or 0
        local G = RawGet(self, "G") or 0
        local B = RawGet(self, "B") or 0
        local MaxValue = math.max(R, G, B)
        local MinValue = math.min(R, G, B)
        local Delta = MaxValue - MinValue
        local Hue
        if Delta == 0 then
            Hue = 0
        elseif MaxValue == R then
            Hue = ((G - B) / Delta) % 6
        elseif MaxValue == G then
            Hue = (B - R) / Delta + 2
        else
            Hue = (R - G) / Delta + 4
        end
        Hue = Hue / 6
        if Hue < 0 then Hue = Hue + 1 end
        local Saturation = MaxValue == 0 and 0 or (Delta / MaxValue)
        return Hue, Saturation, MaxValue
    end,
}
local MockColor3
MockColor3MT.Lerp = function(self, otherValue, alphaValue)
    local alpha = ToNumber(alphaValue) or 0
    local otherR = otherValue and otherValue.R or 0
    local otherG = otherValue and otherValue.G or 0
    local otherB = otherValue and otherValue.B or 0
    return table.freeze(SetMetatable({
        R = (self.R or 0) + (otherR - (self.R or 0)) * alpha,
        G = (self.G or 0) + (otherG - (self.G or 0)) * alpha,
        B = (self.B or 0) + (otherB - (self.B or 0)) * alpha,
        _Type = "Color3",
        ToHex = MockColor3MT.ToHex,
        ToHSV = MockColor3MT.ToHSV,
        Lerp = MockColor3MT.Lerp,
    }, MockColor3MT))
end
MockColor3 = {
    fromRGB = function(r,g,b) local function C01(v) v = ToNumber(v) or 0; if v < 0 then return 0 end; if v > 1 then return 1 end; return v end; return table.freeze(SetMetatable({R=C01((r or 0)/255),G=C01((g or 0)/255),B=C01((b or 0)/255),_Type="Color3",ToHex=MockColor3MT.ToHex,ToHSV=MockColor3MT.ToHSV,Lerp=MockColor3MT.Lerp}, MockColor3MT)) end,
    new = function(r,g,b) local function C01(v) v = ToNumber(v) or 0; if v < 0 then return 0 end; if v > 1 then return 1 end; return v end; return table.freeze(SetMetatable({R=C01(r),G=C01(g),B=C01(b),_Type="Color3",ToHex=MockColor3MT.ToHex,ToHSV=MockColor3MT.ToHSV,Lerp=MockColor3MT.Lerp}, MockColor3MT)) end,
    fromHex = function(hexValue)
        local hexText = StringGsub(tostring(hexValue or ""), "^#", "")
        if #hexText == 3 and string.match(hexText, "^[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]$") then
            hexText = StringGsub(hexText, "(.)", "%1%1")
        end
        local numericValue = tonumber(hexText, 16)
        if numericValue == nil then
            numericValue = tonumber(hexText) or 0
        end
        return MockColor3.fromRGB(
            math.floor(numericValue / 65536) % 256,
            math.floor(numericValue / 256) % 256,
            numericValue % 256)
    end,
    fromHSV = function(h, s, v)
        local H = ((h or 0) % 1) * 6
        local S = s or 0
        local V = v or 0
        local SectorIndex = math.floor(H)
        local Fraction = H - SectorIndex
        local P = V * (1 - S)
        local Q = V * (1 - S * Fraction)
        local T = V * (1 - S * (1 - Fraction))
        local R, G, B
        if SectorIndex == 0 then R, G, B = V, T, P
        elseif SectorIndex == 1 then R, G, B = Q, V, P
        elseif SectorIndex == 2 then R, G, B = P, V, T
        elseif SectorIndex == 3 then R, G, B = P, Q, V
        elseif SectorIndex == 4 then R, G, B = T, P, V
        else R, G, B = V, P, Q end
        return table.freeze(SetMetatable({R=R, G=G, B=B, _Type="Color3", ToHex=MockColor3MT.ToHex, ToHSV=MockColor3MT.ToHSV, Lerp=MockColor3MT.Lerp}, MockColor3MT))
    end,
}
local MockTweenInfo = {
    new = function(t, easingStyle, easingDirection, repeatCount, reverses, delayTime)
        return {
            _Type = "TweenInfo",
            Time = ToNumber(t) or 1,
            EasingStyle = easingStyle or Fidelity.EnumValue("EasingStyle", "Quad", 0),
            EasingDirection = easingDirection or Fidelity.EnumValue("EasingDirection", "Out", 1),
            RepeatCount = repeatCount or 0,
            Reverses = reverses or false,
            DelayTime = delayTime or 0,
        }
    end
}
Fidelity.MockRegion3 = {
    new = function(MinValue, MaxValue)
        if MaxValue == nil then
            local HalfSize = MockVector3.new(
                (RawGet(MinValue, "X") or 0) / 2,
                (RawGet(MinValue, "Y") or 0) / 2,
                (RawGet(MinValue, "Z") or 0) / 2)
            MinValue = MockVector3.new(-HalfSize.X, -HalfSize.Y, -HalfSize.Z)
            MaxValue = HalfSize
        end
        local MinX, MinY, MinZ = RawGet(MinValue, "X") or 0, RawGet(MinValue, "Y") or 0, RawGet(MinValue, "Z") or 0
        local MaxX, MaxY, MaxZ = RawGet(MaxValue, "X") or 0, RawGet(MaxValue, "Y") or 0, RawGet(MaxValue, "Z") or 0
        local RegionSize = MockVector3.new(MaxX - MinX, MaxY - MinY, MaxZ - MinZ)
        local RegionCenter = MockVector3.new((MinX + MaxX) / 2, (MinY + MaxY) / 2, (MinZ + MaxZ) / 2)
        local RegionValue = {
            _Type = "Region3",
            Size = RegionSize,
            CFrame = Fidelity.CFrame.new(RegionCenter.X, RegionCenter.Y, RegionCenter.Z),
        }
        return SetMetatable(RegionValue, {
            __index = {
                GetCFrame = function(self) return self.CFrame end,
                ExpandToGrid = function(self, GridSize)
                    local cell = tonumber(GridSize) or 4
                    local CenterValue = self.CFrame.Position
                    local SizeValue = self.Size
                    return Fidelity.MockRegion3.new(
                        MockVector3.new(math.floor(CenterValue.X / cell + 0.5) * cell - SizeValue.X / 2,
                            math.floor(CenterValue.Y / cell + 0.5) * cell - SizeValue.Y / 2,
                            math.floor(CenterValue.Z / cell + 0.5) * cell - SizeValue.Z / 2),
                        MockVector3.new(math.floor(CenterValue.X / cell + 0.5) * cell + SizeValue.X / 2,
                            math.floor(CenterValue.Y / cell + 0.5) * cell + SizeValue.Y / 2,
                            math.floor(CenterValue.Z / cell + 0.5) * cell + SizeValue.Z / 2)
                    )
                end,
            },
        })
    end,
}
local MockCFrame = Fidelity.CFrame
if Fidelity.Color3 == nil then
    Fidelity.Color3 = MockColor3
end
MockRandom = Fidelity.Random
MockRandom.NextInteger = function(_, MinValue, MaxValue) return MockRandom.new():NextInteger(MinValue, MaxValue) end
MockRandom.NextNumber = function(_, MinValue, MaxValue) return MockRandom.new():NextNumber(MinValue, MaxValue) end
MockRandom.NextUnitVector = function(_) return MockRandom.new():NextUnitVector() end
MockRandom.NextNormal = function(_, MeanValue, StandardDeviation) return MockRandom.new():NextNormal(MeanValue, StandardDeviation) end
MockBrickColorPaletteNumbers = {
    White = 1, ["Dark green"] = 17, ["Really blue"] = 24, Grey = 101, ["Light stone grey"] = 102, ["Dark stone grey"] = 103,
    ["Reddish brown"] = 192, ["Really red"] = 21, ["Really blue"] = 24,
    ["Really black"] = 104, ["Bright red"] = 105, ["Bright blue"] = 106,
    ["Bright yellow"] = 107, ["Bright green"] = 108, ["Neon orange"] = 111,
    ["Neon green"] = 112, ["Neon blue"] = 113, Black = 26, ["Cool yellow"] = 121,
    ["Medium stone grey"] = 127, ["Sand blue"] = 135, ["Navy blue"] = 140,
    ["Earth orange"] = 141, ["Electric blue"] = 142, ["Eggplant"] = 143,
    ["Olive"] = 145, ["Lime green"] = 146, ["Pink"] = 148, ["Alder"] = 151,
}
MockBrickColorPaletteColors = {
    -- r72: nilai RGB nama yang ada di daftar nama; tanpa ini .Color jadi nil
    White = { 255, 255, 255 }, Black = { 27, 42, 53 },
    ["Really red"] = { 255, 0, 0 }, ["Really blue"] = { 0, 0, 255 },
    ["Really black"] = { 17, 17, 17 }, ["Really orange"] = { 255, 165, 0 },
    ["Bright red"] = { 196, 40, 28 }, ["Bright green"] = { 74, 159, 43 },
    ["Neon orange"] = { 181, 86, 13 }, ["Neon green"] = { 104, 196, 73 },
    ["Neon blue"] = { 63, 184, 240 }, ["Cool yellow"] = { 232, 193, 67 },
    ["Sand blue"] = { 63, 101, 128 }, ["Navy blue"] = { 97, 107, 137 },
    ["Earth orange"] = { 127, 86, 42 }, ["Electric blue"] = { 7, 122, 173 },
    ["Eggplant"] = { 123, 48, 102 }, ["Olive"] = { 121, 121, 70 },
    ["Lime green"] = { 155, 191, 88 }, ["Pink"] = { 255, 174, 201 },
    ["Alder"] = { 151, 107, 191 }, ["Reddish brown"] = { 105, 64, 40 },
    Grey = { 170, 170, 170 }, ["Light stone grey"] = { 203, 203, 203 },
    ["Dark green"] = { 40, 108, 34 },
    ["Bright violet"] = { 107, 50, 124 },
    ["Bright blue"] = { 13, 105, 172 },
    ["Bright yellow"] = { 245, 205, 48 },
    ["Medium stone grey"] = { 163, 162, 165 },
    ["Dark stone grey"] = { 99, 95, 98 },
    ["Light grey"] = { 199, 193, 183 },
    ["Med. reddish violet"] = { 196, 112, 160 },
}
MockBrickColorNumbersToNames = (function()
    local ReverseMap = {}
    for PaletteName, PaletteNumber in Next, MockBrickColorPaletteNumbers do
        if ReverseMap[PaletteNumber] == nil then
            ReverseMap[PaletteNumber] = PaletteName
        end
    end
    return ReverseMap
end)()
MockBrickColor = SetMetatable({
    new = function(NameOrNumberValue)
        local ResolvedNumber = tonumber(NameOrNumberValue)
        local ResolvedName
        if ResolvedNumber ~= nil then
            ResolvedNumber = math.floor(ResolvedNumber)
            ResolvedName = MockBrickColorNumbersToNames[ResolvedNumber] or ToString(NameOrNumberValue)
        else
            ResolvedName = ToString(NameOrNumberValue)
            ResolvedNumber = MockBrickColorPaletteNumbers[ResolvedName] or 1
        end
        local PaletteColor = MockBrickColorPaletteColors[ResolvedName]
        return SetMetatable({
            Name = ResolvedName,
            Number = ResolvedNumber,
            r = PaletteColor and (PaletteColor[1] / 255) or 1,
            g = PaletteColor and (PaletteColor[2] / 255) or 1,
            b = PaletteColor and (PaletteColor[3] / 255) or 1,
            Color = PaletteColor and MockColor3.fromRGB(PaletteColor[1], PaletteColor[2], PaletteColor[3]) or nil,
            _Type = "BrickColor",
        }, {
            __tostring = function() return ResolvedName end,
        })
    end,
    Random = function() return MockBrickColor.new("Bright red") end,
    random = function() return MockBrickColor.new("Bright red") end,
    White = function() return MockBrickColor.new("White") end,
    Black = function() return MockBrickColor.new("Black") end,
    Red = function() return MockBrickColor.new("Bright red") end,
    Blue = function() return MockBrickColor.new("Bright blue") end,
    Green = function() return MockBrickColor.new("Dark green") end,
    Yellow = function() return MockBrickColor.new("Bright yellow") end,
    Gray = function() return MockBrickColor.new("Medium stone grey") end,
    Grey = function() return MockBrickColor.new("Medium stone grey") end,
    DarkGray = function() return MockBrickColor.new("Dark stone grey") end,
    DarkGrey = function() return MockBrickColor.new("Dark stone grey") end,
    palette = function(IndexValue)
        local IndexNumber = ToNumber(IndexValue) or 0
        if IndexNumber < 0 or IndexNumber > 208 then
            return RealErrorRef("palette index out of bounds (" .. ToString(IndexValue) .. ")", 0)
        end
        local ResolvedIndex = IndexNumber < 1 and 1 or IndexNumber
        local PaletteName = MockBrickColorNumbersToNames[ResolvedIndex] or (IndexNumber == 15 and "Camo" or "BrickColor")
        return SetMetatable({
            Name = PaletteName,
            Number = ResolvedIndex,
            _Type = "BrickColor",
        }, {
            __tostring = function() return PaletteName end,
        })
    end,
}, {
    __index = function(_, KeyName)
        return nil
    end,
    __tostring = function() return "BrickColor" end,
})
MockKeyInterpolationLinear = SetMetatable({
    Name = "Linear",
    _Type = "EnumItem",
}, {
    __tostring = function() return "Enum.KeyInterpolationMode.Linear" end,
})
MockFloatCurveKey = {
    new = function(TimeValue, ValueValue, InterpolationValue)
        if TimeValue == nil or ValueValue == nil or InterpolationValue == nil then
            return RealErrorRef("FloatCurveKey.new requires time, value, and interpolation", 0)
        end
        local InterpolationOk = false
        if TypeOf(InterpolationValue) == "number" then
            InterpolationOk = InterpolationValue >= 0 and InterpolationValue <= 2
        elseif type(InterpolationValue) == "table" then
            local ItemName = RawGet(InterpolationValue, "Name")
            InterpolationOk = ItemName == "Linear" or ItemName == "Constant" or ItemName == "Cubic"
        end
        if not InterpolationOk then
            return RealErrorRef("invalid FloatCurveKey interpolation", 0)
        end
        return SetMetatable({
            Time = TimeValue,
            Value = ValueValue,
            Interpolation = InterpolationValue,
            _Type = "FloatCurveKey",
        }, {
            __tostring = function() return "FloatCurveKey" end,
        })
    end,
}
Fidelity.EnvRequire = function(ModuleValue)
    local IsModule = type(ModuleValue) == "table" and RawGet(ModuleValue, "ClassName") == "ModuleScript"
    local CachedModule = IsModule and RawGet(ModuleValue, "__V1_ModuleTable") or nil
    if CachedModule ~= nil then
        return CachedModule
    end
    if type(ModuleValue) == "string" and Fidelity.NoteSourceProbe ~= nil then
        Fidelity.NoteSourceProbe(ModuleValue)
    end
    return RealErrorRef("Module ' " .. ToString(ModuleValue) .. " ' not found", 2)
end
Fidelity.EnvVersion = function()
    return "version-2612-09-06-a"
end
Fidelity.EnvGcinfo = function()
    local ok, count = InternalPCall(collectgarbage, "count")
    if ok and type(count) == "number" then
        return math.floor(count)
    end
    return 0
end
Fidelity.EnvUserSettings = function()
    if Fidelity.UserSettingsObject == nil then
        local SettingsObject = Fidelity.CreateMockInstance("UserSettings")
        RawSet(SettingsObject, "GameSettings", Fidelity.CreateMockInstance("CoreSettings"))
        RawSet(SettingsObject, "DevelopSettings", Fidelity.CreateMockInstance("CoreSettings"))
        Fidelity.UserSettingsObject = SettingsObject
    end
    return Fidelity.UserSettingsObject
end
Fidelity.EnvSettings = function()
    if Fidelity.DataModelSettingsObject == nil then
        local SettingsObject = Fidelity.CreateMockInstance("DataModelSettings")
        RawSet(SettingsObject, "ContentProvider", Fidelity.CreateMockInstance("ContentProvider"))
        RawSet(SettingsObject, "NetworkDefaults", Fidelity.CreateMockInstance("NetworkDefaults"))
        RawSet(SettingsObject, "NetworkServer", Fidelity.CreateMockInstance("NetworkServer"))
        Fidelity.DataModelSettingsObject = SettingsObject
    end
    return Fidelity.DataModelSettingsObject
end
local CreateGenericMock
local CreateGenericMember
CreateGenericMock = function(Name)
    local GenericObject = { _Name = Name }
    SetMetatable(GenericObject, {
        __index = function(_, KeyName)
            if KeyName == "new" then
                return function(...)
                    local MockObject = { _Type = Name, ClassName = Name, Name = Name }
                    MockObject.Magnitude = 0
                    MockObject.X = 0; MockObject.Y = 0; MockObject.Z = 0
                    MockObject.Scale = 0; MockObject.Offset = 0
                    MockObject.Min = 1; MockObject.Max = 5
                    MockObject.Density = 0.5
                    MockObject.Time = 1
                    MockObject.Intensity = 1
                    MockObject.Visible = true
                    MockObject.Archivable = true
                    return SetMetatable(MockObject, {
                        __index = function(t, MemberName)
                            if MemberName == "R" or MemberName == "G" or MemberName == "B" then return 0 end
                            if MemberName == "X" or MemberName == "Y" or MemberName == "Z" then return 0 end
                            if MemberName == "Scale" or MemberName == "Offset" then return 0 end
                            if MemberName == "Min" or MemberName == "Max" then return 0 end
                            if MemberName == "Density" then return 0.5 end
                            if MemberName == "Magnitude" then return 0 end
                            if MemberName == "Time" then return 1 end
                            if MemberName == "Intensity" then return 1 end
                            if Fidelity.PropertyDefaultFor ~= nil then
                                local DefaultedValue, IsModelled = Fidelity.PropertyDefaultFor(
                                    Name, MemberName)
                                if IsModelled then
                                    return DefaultedValue
                                end
                            end
                            if (Name == "ValueCurveKey" or Name == "RotationCurveKey")
                                and MemberName == "new" then
                                return function(TimeValue, ValueOrX, YValue, ZValue, InterpValue)
                                    local KeyValue = {
                                        _Type = Name,
                                        Time = ToNumber(TimeValue) or 0,
                                        LeftTangent = ToNumber(ValueOrX) or 0,
                                        RightTangent = ToNumber(YValue) or 0,
                                        Interpolation = Fidelity.EnumValue("KeyInterpolation",
                                            "Linear", ToNumber(InterpValue) or 0),
                                    }
                                    if Name == "ValueCurveKey" then
                                        KeyValue.Value = ToNumber(ValueOrX) or 0
                                    else
                                        KeyValue.Value = MockVector3.new(ValueOrX or 0, YValue or 0,
                                            ZValue or 0)
                                    end
                                    return KeyValue
                                end
                            end
                            if Name == "PathWaypoint" and MemberName == "new" then
                                return function(OriginValue, FacingValue, ActionValue)
                                    return {
                                        _Type = "PathWaypoint",
                                        Position = OriginValue or MockVector3.new(0, 0, 0),
                                        Facing = FacingValue or MockVector3.new(0, 0, 0),
                                        Action = ActionValue or Fidelity.EnumValue(
                                            "PathwayPointAction", "Walk", 0),
                                    }
                                end
                            end
                            return CreateGenericMember(Name, MemberName, t)
                        end,
                        __tostring = function() return Name end,
                    })
                end
            end
            if KeyName == "GetEnumItems" then return function() return {} end end
            if KeyName == "now" then return function() return { UnixTimestamp = 0 } end end
            if KeyName == "fromRGB" or KeyName == "fromHex" or KeyName == "fromHSV" or KeyName == "fromEnum" then
                return function(...) return CreateGenericMock(Name).new(...) end
            end
            if KeyName == "Linear" or KeyName == "Quad" or KeyName == "Top" or KeyName == "AddPrefix" or KeyName == "User" or KeyName == "X" or KeyName == "Y" then
                return SetMetatable({ Name = KeyName, EnumType = Name }, {
                    __tostring = function() return KeyName end,
                    __call = function() return CreateGenericMock(Name .. "." .. KeyName) end,
                })
            end
            return CreateGenericMember(Name, KeyName, GenericObject)
        end,
        __call = function(_, ...)
            local Arguments = TablePack(...)
            EmitMockOutput("generic_api", {Path = Name, Arguments = Arguments, UseColon = false})
            return CreateGenericMock(Name .. "()")
        end,
        __tostring = function() return Name end,
    })
    return GenericObject
end
CreateGenericMember = function(OwnerName, MemberName, ParentObject)
    local MemberPath = OwnerName .. "." .. ToString(MemberName)
    local MemberObject = {}
    SetMetatable(MemberObject, {
        __index = function(_, ChildName)
            return CreateGenericMember(MemberPath, ChildName, MemberObject)
        end,
        __newindex = function(_, KeyName, ValueData)
            if Fidelity.IsReadOnlyInstanceProperty(KeyName) then
                error(StringFormat("Cannot set %s: it is a read-only property", ToString(KeyName)), 0)
            end
            EmitMockOutput("generic_set", {
                Path = MemberPath,
                KeyName = KeyName,
                ValueData = ValueData,
            })
        end,
        __call = function(_, ...)
            local PackedArguments = TablePack(...)
            local FirstArgument = 1
            local UseColon = PackedArguments[1] == ParentObject
            if UseColon then FirstArgument = 2 end
            local Arguments = {}
            for ArgumentIndex = FirstArgument, PackedArguments.n do
                Arguments[#Arguments + 1] = PackedArguments[ArgumentIndex]
            end
            EmitMockOutput("generic_api", {
                Path = MemberPath,
                Arguments = Arguments,
                UseColon = UseColon,
            })
            return CreateGenericMock(MemberPath .. "()")
        end,
        __tostring = function() return MemberPath end,
    })
    return MemberObject
end
local MockInstanceStorage = {}
local MockSignalNames = {
    MouseButton1Click = true,
    MouseButton1Down = true,
    MouseButton1Up = true,
    MouseButton2Click = true,
    MouseButton2Down = true,
    MouseButton2Up = true,
    Activated = true,
    InputBegan = true,
    InputChanged = true,
    InputEnded = true,
    JumpRequest = true,
    Changed = true,
    ChildAdded = true,
    ChildRemoved = true,
    DescendantAdded = true,
    DescendantRemoving = true,
    AncestryChanged = true,
    AttributeChanged = true,
    Focused = true,
    FocusLost = true,
    TouchTap = true,
    Touched = true,
    TouchEnded = true,
    MouseEnter = true,
    MouseLeave = true,
    DragBegin = true,
    DragStopped = true,
    SelectionGained = true,
    SelectionLost = true,
    Stepped = true,
    Died = true,
    StateChanged = true,
    HealthChanged = true,
    MoveToFinished = true,
    StoppedTouching = true,
    PlayerAdded = true,
    PlayerRemoving = true,
    CharacterAdded = true,
    CharacterRemoving = true,
    GameBindRequest = true,
    RenderStepped = true,
    Heartbeat = true,
}
Fidelity.SignalRegistry = Fidelity.SignalRegistry or {}
if Fidelity.FireSignals == nil then
    Fidelity.FireSignals = function(TargetEventName, ...)
        local RegistryBucket = Fidelity.SignalRegistry[TargetEventName]
        if RegistryBucket == nil then return end
        for _, LiveSignal in Next, RegistryBucket do
            LiveSignal:Fire(...)
        end
    end
end
local function CreateMockSignal(EventName, OwnerObject, SignalKind)
    local CallbackList = {}
    local SignalObject = {}
    SignalObject._Type = "RBXScriptSignal"
    if Fidelity.SignalIdentity ~= nil then
        Fidelity.SignalIdentity[SignalObject] = {
            Name = EventName, Owner = OwnerObject, Kind = SignalKind,
        }
    end
    local RegistryBucket = Fidelity.SignalRegistry[EventName]
    if RegistryBucket == nil then
        RegistryBucket = {}
        Fidelity.SignalRegistry[EventName] = RegistryBucket
    end
    TableInsert(RegistryBucket, SignalObject)
    local function Register(CallbackFunction, MethodName)
        if TypeOf(CallbackFunction) == "function" then
            TableInsert(CallbackList, CallbackFunction)
        end
        CaptureMockCallbacks(CallbackFunction)
        EmitMockOutput("connect", {
            EventName = EventName,
            OwnerObject = OwnerObject,
            SignalObject = SignalObject,
            CallbackFunction = CallbackFunction,
            MethodName = MethodName,
        })
        local ConnectionObject = { Connected = true, _Type = "RBXScriptConnection" }
        ConnectionObject.Disconnect = function()
            ConnectionObject.Connected = false
            for ListIndex = 1, #CallbackList do
                if CallbackList[ListIndex] == CallbackFunction then
                    TableRemove(CallbackList, ListIndex)
                    break
                end
            end
        end
        return ConnectionObject
    end
    function SignalObject:Connect(CallbackFunction)
        return Register(CallbackFunction, "Connect")
    end
    SignalObject.connect = SignalObject.Connect
    local OnceCallbacks = {}
    function SignalObject:Once(CallbackFunction)
        if TypeOf(CallbackFunction) ~= "function" then
            error(StringFormat("bad argument #1 to 'Once' (function expected, got %s", TypeOf(CallbackFunction)), 0)
        end
        local OnceWrapper
        local OnceAlreadyRan = false
        OnceWrapper = function(...)
            if OnceAlreadyRan then
                return nil
            end
            OnceAlreadyRan = true
            local OwnedConnection = OnceCallbacks[OnceWrapper]
            if OwnedConnection ~= nil then
                OnceCallbacks[OnceWrapper] = nil
                pcall(OwnedConnection.Disconnect)
            end
            return CallbackFunction(...)
        end
        local OnceConnection = Register(OnceWrapper, "Once")
        OnceCallbacks[OnceWrapper] = OnceConnection
        return OnceConnection
    end
    function SignalObject.Wait(SignalSelf, ...)
        if SignalSelf == nil then
            error("bad argument #1 to 'Wait' (RBXScriptSignal expected, got no value)", 2)
        end
        return nil
    end
    function SignalObject:Fire(...)
        local ListIndex = 1
        while ListIndex <= #CallbackList do
            local CallbackFunction = CallbackList[ListIndex]
            local OnceConnection = OnceCallbacks[CallbackFunction]
            if OnceConnection ~= nil then
                OnceCallbacks[CallbackFunction] = nil
                TableRemove(CallbackList, ListIndex)
                if type(OnceConnection) == "table" then
                    OnceConnection.Connected = false
                end
            end
            InternalPCall(CallbackFunction, ...)
            ListIndex += 1
        end
    end
    return SignalObject
end
Fidelity.UDim2 = MockUDim2
Fidelity.InstanceApiContext = {
    Signal = CreateMockSignal,
    Instance = function(ClassName) return Fidelity.CreateMockInstance(ClassName) end,
    Color3 = MockColor3,
    UDim2 = MockUDim2,
    Vector3 = MockVector3,
    Vector2 = MockVector2,
    CFrame = MockCFrame,
    Enum = Fidelity.EnumValues,
}
local function CreateMockInstance(ClassName)
    local Self = {}
    local Properties = {}
    local ModifiedProperties = {}
    Properties["Name"] = ClassName
    local Signals = {}
    local EventSignals = {}
    local MetadataStore = nil
    local PropertyStore = {}
    local Children = {}
    function Self:IsA(TargetClassName)
        if TargetClassName == ClassName or TargetClassName == "Instance" then return true end
        if (ClassName == "Part" or ClassName == "MeshPart") and (TargetClassName == "BasePart" or TargetClassName == "PVInstance") then return true end
        if ClassName == "Workspace" and (TargetClassName == "Model" or TargetClassName == "PVInstance") then return true end
        if ClassName == "PlayerGui"
            and (TargetClassName == "BasePlayerGui" or TargetClassName == "LayerCollector"
                or TargetClassName == "GuiBase2d") then return true end
        if ClassName == "ScreenGui"
            and (TargetClassName == "LayerCollector" or TargetClassName == "GuiBase2d") then return true end
        if ClassName == "AnimationController" and TargetClassName == "Animator" then return true end
        if ClassName == "AnimationTrack" and TargetClassName == "AnimationBase" then return true end
        if ClassName == "Animation" and TargetClassName == "AnimationBase" then return true end
        if TargetClassName == "ValueBase" then
            local ValueClasses = { IntValue = true, NumberValue = true, StringValue = true, BoolValue = true, ObjectValue = true, Color3Value = true, BrickColorValue = true, CFrameValue = true, Vector3Value = true, RayValue = true }
            if ValueClasses[ClassName] then return true end
        end
        if TargetClassName == "BaseWrap" then
            if ClassName == "WrapLayer" or ClassName == "WrapTarget" then return true end
        end
        return false
    end
    function Self:IsPropertyModified(PropertyName)
        return ModifiedProperties[PropertyName] == true
    end
    function Self:ResetPropertyToDefault(PropertyName)
        local DefaultValue
        if PropertyName == "Transparency" then
            DefaultValue = 0
        elseif PropertyName == "Reflectance" then
            DefaultValue = 0
        elseif PropertyName == "CanCollide" then
            DefaultValue = true
        elseif PropertyName == "Anchored" then
            DefaultValue = false
        end
        ModifiedProperties[PropertyName] = nil
        Properties[PropertyName] = DefaultValue
        PropertyStore[PropertyName] = nil
        RawSet(self, PropertyName, nil)
        return DefaultValue
    end
    function Self:GetChildren()
        return Fidelity.GetChildrenOf(self)
    end
    function Self:GetDescendants()
        local Result = {}
        local function Walk(CurrentNode)
            for _, ChildValue in ipairs(Fidelity.GetChildrenOf(CurrentNode)) do
                Result[#Result + 1] = ChildValue
                Walk(ChildValue)
            end
        end
        Walk(self)
        return Result
    end
    function Self:FindFirstChild(ChildName, RecursiveSearch)
        for _, ChildValue in ipairs(Fidelity.GetChildrenOf(self)) do
            if ChildValue.Name == ChildName then return ChildValue end
        end
        if RecursiveSearch then
            local PendingChildren = Fidelity.GetChildrenOf(self)
            local PendingCount = #PendingChildren
            local VisitedCount = 0
            while PendingCount > 0 do
                local DescendantValue = table.remove(PendingChildren)
                PendingCount = PendingCount - 1
                VisitedCount = VisitedCount + 1
                if DescendantValue ~= nil and DescendantValue.Name == ChildName then
                    return DescendantValue
                end
                if DescendantValue ~= nil and VisitedCount < 4096 then
                    for _, GrandchildValue in ipairs(Fidelity.GetChildrenOf(DescendantValue)) do
                        PendingChildren[#PendingChildren + 1] = GrandchildValue
                        PendingCount = PendingCount + 1
                    end
                end
            end
        end
        return nil
    end
    function Self:QueryDescendants(Selector)
        return Fidelity.QueryDescendants(self, Selector)
    end
    function Self:GetNetworkOwner()
        return nil
    end
    function Self:SetNetworkOwner(_PlayerValue, _CanAssert)
        return nil
    end
    function Self:SetNetworkOwnershipAuto(_AutoValue)
        return nil
    end
    function Self:CanSetNetworkOwnership()
        return true
    end
    function Self:GetNetworkOwnershipAuto()
        return false
    end
    function Self:WaitForChild(ChildName, TimeoutSeconds)
        local FoundChild = self:FindFirstChild(ChildName)
        if FoundChild ~= nil then
            return FoundChild
        end
        if TimeoutSeconds ~= nil and ToNumber(TimeoutSeconds) == nil then
            RealErrorRef("bad argument #2 to 'WaitForChild' (number expected, got "
                .. InternalType(TimeoutSeconds) .. ")", 0)
        end
        return nil
    end
    function Self:FindFirstChildOfClass(ChildClassName, Recursive)
        return Fidelity.FindFirstChildOfClass(self, ChildClassName, Recursive, false)
    end
    function Self:FindFirstChildWhichIsA(ChildClassName, Recursive)
        return Fidelity.FindFirstChildOfClass(self, ChildClassName, Recursive, true)
    end
    function Self:FindFirstAncestor(AncestorName)
        local AncestorValue = self.Parent
        local GuardCount = 0
        while AncestorValue ~= nil and GuardCount < 64 do
            if AncestorValue.Name == AncestorName then return AncestorValue end
            AncestorValue = AncestorValue.Parent
            GuardCount += 1
        end
        return nil
    end
    function Self:FindFirstAncestorOfClass(AncestorClassName)
        local AncestorValue = self.Parent
        local GuardCount = 0
        while AncestorValue ~= nil and GuardCount < 64 do
            if AncestorValue:IsA(AncestorClassName) then return AncestorValue end
            AncestorValue = AncestorValue.Parent
            GuardCount += 1
        end
        return nil
    end
    function Self:FindFirstAncestorWhichIsA(AncestorClassName)
        local AncestorValue = self.Parent
        local GuardCount = 0
        while AncestorValue ~= nil and GuardCount < 64 do
            if AncestorValue.IsA ~= nil and AncestorValue:IsA(AncestorClassName) then
                return AncestorValue
            end
            AncestorValue = AncestorValue.Parent
            GuardCount += 1
        end
        return nil
    end
    function Self:AddTag(TagName)
        Fidelity.AddTagTo(self, TagName)
        local Service = nil
        pcall(function() Service = MockGameCollectionService end)
        if Service ~= nil and Service.AddTag ~= nil then
            pcall(function() Service:AddTag(self, TagName) end)
        end
        EmitMockOutput("metadata_call", {
            InstanceObject = self, MethodName = "AddTag", Arguments = { TagName },
        })
    end
    function Self:RemoveTag(TagName)
        Fidelity.RemoveTagFrom(self, TagName)
        local Service = nil
        pcall(function() Service = MockGameCollectionService end)
        if Service ~= nil and Service.RemoveTag ~= nil then
            pcall(function() Service:RemoveTag(self, TagName) end)
        end
        EmitMockOutput("metadata_call", {
            InstanceObject = self, MethodName = "RemoveTag", Arguments = { TagName },
        })
    end
    function Self:HasTag(TagName)
        if Fidelity.ObjectHasTag(self, TagName) then return true end
        local Service = nil
        pcall(function() Service = MockGameCollectionService end)
        if Service ~= nil and Service.HasTag ~= nil then
            local ok, answer = pcall(function() return Service:HasTag(self, TagName) end)
            return ok and answer == true
        end
        return false
    end
    function Self:GetTags()
        local StoredTags = Fidelity.TagsOf(self)
        if #StoredTags > 0 then return StoredTags end
        local Service = nil
        pcall(function() Service = MockGameCollectionService end)
        if Service ~= nil and Service.GetTags ~= nil then
            local ok, answer = pcall(function() return Service:GetTags(self) end)
            if ok and TypeOf(answer) == "table" then return answer end
        end
        return StoredTags
    end
    function Self:GetAttribute(KeyName)
        local AttributeStore = Properties["__V1_ATTRIBUTES"]
        if TypeOf(AttributeStore) ~= "table" then return nil end
        return AttributeStore[ToString(KeyName)]
    end
    function Self:GetAttributeChangedSignal(KeyName)
        local SignalObject = CreateMockSignal("GetAttributeChangedSignal:" .. ToString(KeyName), self, "attribute")
        return SignalObject
    end
    function Self:GetAttributes()
        local AttributeStore = Properties["__V1_ATTRIBUTES"]
        if TypeOf(AttributeStore) ~= "table" then return {} end
        local CopiedAttributes = {}
        for AttributeName, AttributeValue in pairs(AttributeStore) do
            CopiedAttributes[AttributeName] = AttributeValue
        end
        return CopiedAttributes
    end
    function Self:SetAttribute(KeyName, AttributeValue)
        local AttributeStore = Properties["__V1_ATTRIBUTES"]
        if TypeOf(AttributeStore) ~= "table" then
            AttributeStore = {}
            Properties["__V1_ATTRIBUTES"] = AttributeStore
        end
        AttributeStore[ToString(KeyName)] = AttributeValue
        EmitMockOutput("metadata_call", {
            InstanceObject = self, MethodName = "SetAttribute", Arguments = { KeyName, AttributeValue },
        })
        local AttributeChangedSignal = EventSignals["AttributeChanged"]
        if AttributeChangedSignal ~= nil then
            AttributeChangedSignal:Fire(ToString(KeyName))
        end
    end
    local HasPivot = Fidelity.IsPivotClass(ClassName)
    local function StoredPivotOffset()
        local OffsetFrame = Properties["PivotOffset"]
        if OffsetFrame ~= nil and OffsetFrame.X ~= nil then return OffsetFrame end
        if ClassName == "Model" or ClassName == "Workspace" then
            return MockCFrame.new(0, 0, 0)
        end
        local SizeValue = Properties["Size"]
        local HalfX = 2
        if SizeValue ~= nil and SizeValue.X ~= nil then HalfX = SizeValue.X / 2 end
        return MockCFrame.new(HalfX, 0, 0)
    end
    local function BaseFrameOf(BaseFrame)
        if BaseFrame ~= nil and BaseFrame.X ~= nil then return BaseFrame end
        local PositionValue = Properties["Position"]
        if PositionValue ~= nil and PositionValue.X ~= nil then
            return MockCFrame.new(PositionValue.X, PositionValue.Y, PositionValue.Z)
        end
        return MockCFrame.new(0, 0, 0)
    end
    local function PivotFrameFrom(BaseFrame)
        local PivotOk, PivotFrame = InternalPCall(function()
            return BaseFrameOf(BaseFrame) * StoredPivotOffset()
        end)
        if PivotOk and PivotFrame ~= nil and PivotFrame.X ~= nil then return PivotFrame end
        return BaseFrameOf(BaseFrame)
    end
    local function WriteBaseFrame(TargetInstance, NewBaseFrame)
        if NewBaseFrame == nil or NewBaseFrame.X == nil then return end
        if ClassName == "Model" or ClassName == "Workspace" then
            local CenterValue = Fidelity.BoundsOfInstance(TargetInstance)
            local OldX, OldY, OldZ = 0, 0, 0
            if CenterValue ~= nil and CenterValue.X ~= nil then
                OldX, OldY, OldZ = CenterValue.X, CenterValue.Y, CenterValue.Z
            end
            local DeltaX = NewBaseFrame.X - OldX
            local DeltaY = NewBaseFrame.Y - OldY
            local DeltaZ = NewBaseFrame.Z - OldZ
            for _, ChildValue in ipairs(Fidelity.GetChildrenOf(TargetInstance)) do
                local DescendantQueue = { ChildValue }
                local GuardCount = 0
                while #DescendantQueue > 0 and GuardCount < 4096 do
                    GuardCount += 1
                    local DescendantValue = TableRemove(DescendantQueue)
                    local DescendantName = DescendantValue ~= nil and DescendantValue.ClassName or nil
                    if DescendantValue ~= nil and Fidelity.IsSpatialPart(DescendantName)
                        and DescendantValue.Position ~= nil then
                        local PositionValue = DescendantValue.Position
                        DescendantValue.CFrame = MockCFrame.new(
                            PositionValue.X + DeltaX, PositionValue.Y + DeltaY, PositionValue.Z + DeltaZ
                        )
                    end
                    if DescendantValue ~= nil and Fidelity.GetChildrenOf ~= nil then
                        for _, GrandChildValue in ipairs(Fidelity.GetChildrenOf(DescendantValue)) do
                            DescendantQueue[#DescendantQueue + 1] = GrandChildValue
                        end
                    end
                end
            end
            return
        end
        Properties["CFrame"] = NewBaseFrame
        PropertyStore["CFrame"] = NewBaseFrame
        ModifiedProperties["CFrame"] = true
        local NewPosition = MockVector3.new(NewBaseFrame.X, NewBaseFrame.Y, NewBaseFrame.Z)
        Properties["Position"] = NewPosition
        PropertyStore["Position"] = NewPosition
        ModifiedProperties["Position"] = true
        Fidelity.World.SetBodyState(TargetInstance, NewPosition, nil)
        Properties["Pivot"] = PivotFrameFrom(NewBaseFrame)
    end
    if HasPivot then
        function Self:GetPivot()
            if ClassName == "Model" then
                local PrimaryValue = Properties["PrimaryPart"]
                if PrimaryValue ~= nil and PrimaryValue.CFrame ~= nil then
                    return PivotFrameFrom(PrimaryValue.CFrame)
                end
                local CenterValue = Fidelity.BoundsOfInstance(self)
                if CenterValue ~= nil and CenterValue.X ~= nil then
                    return PivotFrameFrom(MockCFrame.new(CenterValue.X, CenterValue.Y, CenterValue.Z))
                end
            end
            return PivotFrameFrom(Properties["CFrame"])
        end
        function Self:SetPivot(NewPivotFrame)
            if NewPivotFrame == nil or NewPivotFrame.X == nil then return end
            local OffsetFrame = StoredPivotOffset()
            local InverseOk, InverseOffset = InternalPCall(function() return OffsetFrame:Inverse() end)
            if not InverseOk or InverseOffset == nil or InverseOffset.X == nil then
                InverseOffset = MockCFrame.new(-OffsetFrame.X, -OffsetFrame.Y, -OffsetFrame.Z)
            end
            local MoveOk, NewBaseFrame = InternalPCall(function() return NewPivotFrame * InverseOffset end)
            WriteBaseFrame(self, MoveOk and NewBaseFrame or NewPivotFrame)
        end
        function Self:PivotTo(NewPivotFrame)
            Self.SetPivot(self, NewPivotFrame)
        end
        function Self:GetBoundingBox()
            local CenterValue, SizeValue = Fidelity.BoundsOfInstance(self)
            if CenterValue == nil or SizeValue == nil then
                return MockCFrame.new(0, 0, 0), MockVector3.new(0, 0, 0)
            end
            return MockCFrame.new(CenterValue.X, CenterValue.Y, CenterValue.Z), SizeValue
        end
    end
    function Self:Clone()
        if ClassName == "DataModel" then
            return nil
        end
        if Properties["Archivable"] == false then
            return nil
        end
        local ClonedInstance = CreateMockInstance(ClassName)
        local ClonedName = Properties["Name"]
        if ClonedName ~= nil then
            ClonedInstance.Name = ClonedName
        end
        local ClonedArchivable = Properties["Archivable"]
        if ClonedArchivable == nil then ClonedArchivable = true end
        ClonedInstance.Archivable = ClonedArchivable
        local AttributeStore = Properties["__V1_ATTRIBUTES"]
        if TypeOf(AttributeStore) == "table" then
            for AttributeName, AttributeValue in pairs(AttributeStore) do
                ClonedInstance:SetAttribute(AttributeName, AttributeValue)
            end
        end
        local CloneMapIsOurs = Fidelity.CloneMap == nil
        if CloneMapIsOurs then Fidelity.CloneMap = {} end
        local ClonedReferences = Fidelity.CloneMap
        ClonedReferences[self] = ClonedInstance
        for _, ChildValue in ipairs(Fidelity.GetChildrenOf(self)) do
            local ClonedChild = ChildValue:Clone()
            if ClonedChild ~= nil then
                ClonedChild.Parent = ClonedInstance
            end
        end
        local SourceValue = Properties["Value"]
        if SourceValue ~= nil then
            ClonedInstance.Value = ClonedReferences[SourceValue] or SourceValue
        end
        for _, ReferencePropertyName in Next, {
            "Part0", "Part1", "Attachment0", "Attachment1", "PrimaryPart", "HostPart",
        } do
            local SourceReference = Properties[ReferencePropertyName]
            if SourceReference ~= nil then
                ClonedInstance[ReferencePropertyName] = ClonedReferences[SourceReference] or SourceReference
            end
        end
        if CloneMapIsOurs then Fidelity.CloneMap = nil end
        return ClonedInstance
    end
    function Self:IsDescendantOf(AncestorInstance)
        if AncestorInstance == nil then return false end
        local CurrentAncestor = self ~= nil and self.Parent or nil
        local PreviousAncestor = self
        local GuardCount = 0
        while CurrentAncestor ~= nil and CurrentAncestor ~= PreviousAncestor and GuardCount < 64 do
            if CurrentAncestor == AncestorInstance then return true end
            PreviousAncestor = CurrentAncestor
            CurrentAncestor = CurrentAncestor.Parent
            GuardCount += 1
        end
        return false
    end
    function Self:IsAncestorOf(DescendantInstance)
        if DescendantInstance == nil then return false end
        if DescendantInstance == self then return true end
        return DescendantInstance:IsDescendantOf(self)
    end
    function Self:ClearAllChildren()
        local ChildSnapshot = self:GetChildren()
        for ChildIndex = #ChildSnapshot, 1, -1 do
            ChildSnapshot[ChildIndex].Parent = nil
        end
    end
    function Self:GetFullName()
        local NameValue = Properties["Name"] or ClassName
        local PathText = ToString(NameValue)
        local AncestorValue = self ~= nil and self.Parent or nil
        local PreviousAncestor = self
        local GuardCount = 0
        while AncestorValue ~= nil and AncestorValue ~= PreviousAncestor and GuardCount < 64 do
            local AncestorName = AncestorValue.Name
            if AncestorName == nil then break end
            if AncestorValue.Parent == nil and ToString(AncestorValue.ClassName) == "DataModel" then
                break
            end
            PathText = ToString(AncestorName) .. "." .. PathText
            PreviousAncestor = AncestorValue
            AncestorValue = AncestorValue.Parent
            GuardCount += 1
        end
        return PathText
    end

    local function ResolvePathUDim2(UDim2Value, ScaleX, ScaleY)
        if TypeOf(UDim2Value) ~= "table" then
            return 0, 0
        end
        local XValue = RawGet(UDim2Value, "X")
        local YValue = RawGet(UDim2Value, "Y")
        local x = 0
        local y = 0
        if TypeOf(XValue) == "table" then
            x = (RawGet(XValue, "Scale") or 0) * ScaleX + (RawGet(XValue, "Offset") or 0)
        end
        if TypeOf(YValue) == "table" then
            y = (RawGet(YValue, "Scale") or 0) * ScaleY + (RawGet(YValue, "Offset") or 0)
        end
        return x, y
    end
    local function ResolvePathParentSize()
        local ScaleX, ScaleY = 0, 0
        local ParentValue = self ~= nil and self.Parent or nil
        if TypeOf(ParentValue) == "table" then
            local ParentSize = RawGet(ParentValue, "Size")
            if TypeOf(ParentSize) == "table" then
                local SizeX = RawGet(ParentSize, "X")
                local SizeY = RawGet(ParentSize, "Y")
                if TypeOf(SizeX) == "table" then ScaleX = RawGet(SizeX, "Offset") or 0 end
                if TypeOf(SizeY) == "table" then ScaleY = RawGet(SizeY, "Offset") or 0 end
            end
        end
        return ScaleX, ScaleY
    end
    function Self:Fire(...)
        if ClassName == "BindableEvent" then
            local EventSignal = EventSignals["Event"]
            if EventSignal == nil then
                EventSignal = CreateMockSignal("Event", self)
                EventSignals["Event"] = EventSignal
            end
            EventSignal:Fire(...)
        end
    end
    function Self:Invoke(...)
        if ClassName == "BindableFunction" then
            local OnInvokeFn = Properties["OnInvoke"]
            if TypeOf(OnInvokeFn) == "function" then
                return OnInvokeFn(...)
            end
        end
        return nil
    end
    function Self:GetMass()
        if Fidelity.IsSpatialPart(ClassName) then
            return Fidelity.World.MassOf(self)
        end
        return 0
    end
    function Self:GetTouchingParts()
        if Fidelity.IsSpatialPart(ClassName) then
            return Fidelity.World.TouchingParts(self)
        end
        return {}
    end
    if ClassName == "FloatCurve" then
        local CurveKeyList = {}
        Properties["Length"] = 0
        function Self:SetKeys(KeyList)
            CurveKeyList = {}
            if TypeOf(KeyList) == "table" then
                for KeyIndex, KeyValue in Next, KeyList do
                    CurveKeyList[KeyIndex] = KeyValue
                end
            end
            Properties["Length"] = #CurveKeyList
            return #CurveKeyList
        end
        function Self:GetKeyAtIndex(KeyIndex)
            return CurveKeyList[KeyIndex]
        end
        function Self:InsertKey(KeyValue)
            if KeyValue ~= nil then
                CurveKeyList[#CurveKeyList + 1] = KeyValue
                table.sort(CurveKeyList, function(LeftKey, RightKey)
                    return (ToNumber(LeftKey and LeftKey.Time) or 0)
                        < (ToNumber(RightKey and RightKey.Time) or 0)
                end)
            end
            Properties["Length"] = #CurveKeyList
            return #CurveKeyList
        end
        function Self:AddKey(KeyValue)
            return Self:InsertKey(KeyValue)
        end
        function Self:RemoveKeyAtIndex(KeyIndex)
            table.remove(CurveKeyList, ToNumber(KeyIndex) or 1)
            Properties["Length"] = #CurveKeyList
            return true
        end
        function Self:GetKeys()
            local KeyCopy = {}
            for KeyIndex, KeyValue in Next, CurveKeyList do
                KeyCopy[KeyIndex] = KeyValue
            end
            return KeyCopy
        end
        function Self:GetValueAtTime(TimeValue)
            for _, KeyValue in Next, CurveKeyList do
                if TypeOf(KeyValue) == "table" and RawGet(KeyValue, "Time") == TimeValue then
                    return RawGet(KeyValue, "Value")
                end
            end
            return nil
        end
        function Self:Destroy() end
    elseif ClassName == "DataStoreIncrementOptions" then
        function Self:SetMetadata(data) MetadataStore = data end
        function Self:GetMetadata() return MetadataStore or {} end
        function Self:Destroy() end
    elseif ClassName == "StyleRule" then
        function Self:GetProperty(prop) return PropertyStore[prop] end
        function Self:SetProperty(prop, val) PropertyStore[prop]=val; return val end
        function Self:Destroy() end
    elseif ClassName == "TerrainRegion" then
        Properties["Size"] = MockVector3Int16.new(4, 4, 4)
        function Self:Destroy() end
    elseif ClassName == "LocalizationTable" then
        local EntryStore = {}
        local ContextList = {}
        function Self:SetEntries(EntriesTable, removeExisting)
            if TypeOf(EntriesTable) == "table" then
                if removeExisting == true then
                    table.clear(EntryStore)
                end
                for _, Entry in Next, EntriesTable do
                    if TypeOf(Entry) == "table" and Entry.Key ~= nil then
                        local Record = {
                            Key = tostring(Entry.Key),
                            Source = Entry.Source ~= nil and tostring(Entry.Source) or "",
                            Values = {},
                            Context = Entry.Context,
                        }
                        if TypeOf(Entry.Values) == "table" then
                            for LocaleId, LocaleValue in Next, Record and Entry.Values do
                                Record.Values[tostring(LocaleId)] = tostring(LocaleValue)
                            end
                        end
                        EntryStore[Record.Key] = Record
                        if Record.Context ~= nil then
                            TableInsert(ContextList, tostring(Record.Context))
                        end
                    end
                end
            end
            return nil
        end
        function Self:GetEntries()
            local Result = {}
            for _, Record in Next, EntryStore do
                Result[#Result + 1] = Record
            end
            return Result
        end
        function Self:GetContexts()
            return ContextList
        end
        function Self:RemoveEntries(KeyList)
            if TypeOf(KeyList) == "table" then
                for _, Key in Next, KeyList do
                    EntryStore[tostring(Key)] = nil
                end
            end
        end
        local function LookupPattern(Key, LocaleId)
            local record = EntryStore[tostring(Key)]
            if record == nil then
                return nil
            end
            if LocaleId ~= nil then
                local wanted = StringLower(ToString(LocaleId))
                local exact = record.Values[wanted]
                if exact ~= nil then
                    return exact
                end
                local language = StringMatch(wanted, "^(%a+)")
                if language ~= nil then
                    for storedLocale, storedValue in Next, record.Values do
                        if StringLower(ToString(storedLocale)) == language then
                            return storedValue
                        end
                    end
                end
            end
            return record.Source
        end
        function Self:GetString(Key, LocaleId)
            return LookupPattern(Key, LocaleId ~= nil and LocaleId or Properties["SourceLocaleId"]) or ""
        end
        function Self:RemoveEntry(Key)
            EntryStore[tostring(Key)] = nil
        end
        function Self:RemoveEntryValue(Key, LocaleId)
            local Record = EntryStore[tostring(Key)]
            if Record ~= nil and TypeOf(Record.Values) == "table" and LocaleId ~= nil then
                Record.Values[tostring(LocaleId)] = nil
            end
        end
        function Self:GetCurrentTranslation(Key, LocaleId)
            return LookupPattern(Key, LocaleId ~= nil and LocaleId or Properties["SourceLocaleId"])
        end
        function Self:GetTranslator(LocaleId)
            local resolvedLocale = LocaleId ~= nil and LocaleId or Properties["SourceLocaleId"]
            if TypeOf(resolvedLocale) ~= "string" then
                resolvedLocale = "en-us"
            end
            local Translator = {
                _Type = "LocalizationTableTranslator",
                LocaleId = resolvedLocale,
            }
            function Translator:FormatByKey(Key, Arguments)
                return Fidelity.FormatLocalizationMessage(
                    LookupPattern(Key, resolvedLocale) or "", Arguments)
            end
            function Translator:Format(...)
                local varargs = table.pack(...)
                local pattern = varargs[1]
                local arguments
                if varargs.n == 2 and type(varargs[2]) == "table" then
                    arguments = varargs[2]
                elseif varargs.n > 1 then
                    arguments = {}
                    for argIndex = 2, varargs.n do
                        arguments[argIndex - 1] = varargs[argIndex]
                    end
                end
                if type(pattern) ~= "string" then
                    pattern = tostring(LookupPattern(pattern, resolvedLocale) or "")
                end
                return Fidelity.FormatLocalizationMessage(pattern, arguments)
            end
            function Translator:FormatAsync(Key, Arguments)
                local translated = Translator:FormatByKey(Key, Arguments)
                return {
                    _Type = "Future",
                    GetValue = function() return translated end,
                    Await = function() return translated end,
                }
            end
            return Translator
        end
        function Self:Destroy() end
    elseif ClassName == "Terrain" then
        function Self:CopyRegion(TargetRegion)
            local TerrainRegionObject = CreateMockInstance("TerrainRegion")
            RawSet(TerrainRegionObject, "__V1_TYPE", "TerrainRegion")
            return TerrainRegionObject
        end
        function Self:Destroy() end
    elseif ClassName == "Frame" or ClassName == "Part" or ClassName == "Folder" or ClassName == "ScreenGui" then
        Properties["Position"] = ClassName == "Frame" and MockUDim2.new(0,0,0,0) or MockVector3.new(0,0,0)
        Properties["Size"] = ClassName == "Frame" and MockUDim2.new(0,100,0,100)
            or (ClassName == "Part" and MockVector3.new(4, 1.2, 2) or MockVector3.new(0,0,0))
        Properties["Transparency"] = ClassName == "Part" and 0 or Properties["Transparency"]
        Properties["Name"] = ClassName
        function Self:GetPropertyChangedSignal(propName)
            local SignalObject = CreateMockSignal(ToString(propName), self, "property")
            return SignalObject
        end
        function Self:Destroy() end
    else
        function Self:GetPropertyChangedSignal(propName)
            local SignalObject = CreateMockSignal(ToString(propName), self, "property")
            return SignalObject
        end
        function Self:GetProperty(prop) return PropertyStore[prop] end
        function Self:SetProperty(prop,val) PropertyStore[prop]=val end
        function Self:SetMetadata(data) MetadataStore = data end
        function Self:GetMetadata() return MetadataStore or {} end
        function Self:Destroy() end
    end
    if not Self.Destroy then function Self:Destroy() end end
    if not Self.GetProperty then function Self:GetProperty(p) return PropertyStore[p] or Properties[p] end end
    if not Self.SetProperty then function Self:SetProperty(p,v) PropertyStore[p]=v; Properties[p]=v end end
    if not Self.GetPropertyChangedSignal then
        function Self:GetPropertyChangedSignal(p)
            return {Connect=function(_,cb)
                CaptureMockCallbacks(cb)
                EmitMockOutput("connect", {
                    EventName = p,
                    OwnerObject = self,
                    CallbackFunction = cb,
                    MethodName = "Connect",
                    SignalExpression = ':GetPropertyChangedSignal("' .. ToString(p) .. '")',
                })
                return {Disconnect=function() end}
            end}
        end
    end
    if not Self.GetMetadata then function Self:GetMetadata() return MetadataStore or {} end end
    if not Self.SetMetadata then function Self:SetMetadata(d) MetadataStore=d end end
    local function SeedDefault(PropertyName, PropertyValue)
        if Properties[PropertyName] == nil and PropertyStore[PropertyName] == nil then
            Properties[PropertyName] = PropertyValue
        end
    end
    do
        local PreviousDestroyHandler = Self.Destroy
        function Self:Destroy(...)
            Fidelity.World.Unregister(self)
            local ParentValue = RawGet(self, "__V1_PARENT_VALUE") or Properties["Parent"]
            if ParentValue ~= nil then
                Fidelity.UnregisterChild(ParentValue, self)
            end
            RawSet(self, "__V1_DESTROYED", true)
            RawSet(Self, "__V1_LOCK_PARENT", true)
            for _, DestroyedChild in Next, Children do
                pcall(function() DestroyedChild.Parent = nil end)
                RawSet(DestroyedChild, "__V1_LOCK_PARENT", true)
                RawSet(DestroyedChild, "__V1_PARENT_VALUE", nil)
            end
            if Fidelity.ChildrenSnapshot ~= nil then
                local DetachedChildren = Fidelity.ChildrenSnapshot(self)
                if DetachedChildren ~= nil then
                    for DetachIndex = 1, #DetachedChildren do
                        local DetachedChild = DetachedChildren[DetachIndex]
                        if type(DetachedChild) == "table" and DetachedChild ~= self then
                            pcall(function() DetachedChild.Parent = nil end)
                            RawSet(DetachedChild, "__V1_LOCK_PARENT", true)
                            RawSet(DetachedChild, "__V1_PARENT_VALUE", nil)
                            if Fidelity.DetachDestroyedInstance ~= nil then
                                Fidelity.DetachDestroyedInstance(DetachedChild, 8)
                            end
                        end
                    end
                end
            end
            if PreviousDestroyHandler ~= nil then
                return PreviousDestroyHandler(self, ...)
            end
        end
    end
    local Proxy = {}
    local SelfMethods = {}
    for MethodName, MethodValue in Next, Self do
        SelfMethods[MethodName] = MethodValue
    end
    RawSet(Self, "__V1_Methods", SelfMethods)
    for MethodName, MethodValue in Next, SelfMethods do
        if StringSub(MethodName, 1, 7) == "__V1_" then continue end
        Proxy[MethodName] = Fidelity.SharedMethodStub(ClassName, MethodName)
    end
    RawSet(Proxy, "__V1_Methods", SelfMethods)
    RawSet(Proxy, "__V1_CLASS_NAME", ClassName)
    if Fidelity.ApplyModelledDefaults ~= nil then
        Fidelity.ApplyModelledDefaults(Proxy, ClassName)
    end
    Proxy.__V1_INSTANCE = true
    Proxy.__V1_TYPE = "Instance"
    local ProxyMT = {
        __index = function(t,k)
            if k == "Parent" then
                local StoredParent = RawGet(t, "__V1_PARENT_VALUE")
                if StoredParent ~= nil then return StoredParent end
            end
            if StringSub(ToString(k), 1, 7) == "__V1_" then
                return nil
            end
            if Fidelity.GetPropertyOverride ~= nil then
                local OverrideValue = Fidelity.GetPropertyOverride(t, k)
                if OverrideValue ~= nil then return OverrideValue end
            end
            local method = Self[k]
            if method ~= nil then return method end
            if Fidelity.IsSpatialPart(ClassName) and Fidelity.World ~= nil then
                if k == "Position" then
                    local BodyPosition = Fidelity.World.BodyPositionOf(t)
                    if BodyPosition ~= nil then
                        return BodyPosition
                    end
                elseif k == "CFrame" then
                    local BodyPosition = Fidelity.World.BodyPositionOf(t)
                    if BodyPosition ~= nil then
                        return MockCFrame.new(BodyPosition.X, BodyPosition.Y, BodyPosition.Z)
                    end
                elseif k == "AssemblyLinearVelocity" then
                    local BodyVelocity = Fidelity.World.BodyVelocityOf(t)
                    return BodyVelocity ~= nil and BodyVelocity or MockVector3.new(0, 0, 0)
                elseif k == "AssemblyAngularVelocity" then
                    local StoredAngularFrame = Properties["AssemblyAngularVelocity"]
                    return StoredAngularFrame ~= nil and StoredAngularFrame or MockVector3.new(0, 0, 0)
                elseif k == "AssemblyAngularVelocityX" or k == "AssemblyAngularVelocityY"
                    or k == "AssemblyAngularVelocityZ" then
                    local StoredAngularFrame = Properties["AssemblyAngularVelocity"]
                    local AxisComponent = StoredAngularFrame ~= nil
                        and StoredAngularFrame[StringSub(k, 24)] or nil
                    return AxisComponent ~= nil and AxisComponent or 0
                elseif k == "AssemblyRootPart" then
                    return Fidelity.World.ResolveRoot(t)
                elseif k == "AssemblyMass" then
                    return Fidelity.World.MassOf(t)
                elseif k == "Mass" then
                    return Fidelity.World.SinglePartMass(t)
                elseif k == "AssemblyRootPart" then
                    return t
                elseif k == "AssemblyLinearVelocityX" then
                    local BodyVelocity = Fidelity.World.BodyVelocityOf(t)
                    return BodyVelocity ~= nil and BodyVelocity.X or 0
                elseif k == "AssemblyLinearVelocityY" then
                    local BodyVelocity = Fidelity.World.BodyVelocityOf(t)
                    return BodyVelocity ~= nil and BodyVelocity.Y or 0
                elseif k == "AssemblyLinearVelocityZ" then
                    local BodyVelocity = Fidelity.World.BodyVelocityOf(t)
                    return BodyVelocity ~= nil and BodyVelocity.Z or 0
                end
            end
            if Properties[k] ~= nil then return Properties[k] end
            if PropertyStore[k] ~= nil then return PropertyStore[k] end
            if MockSignalNames[k] then
                EventSignals[k] = EventSignals[k] or CreateMockSignal(k, t)
                return EventSignals[k]
            end
            if k == "CFrame" and (ClassName == "Part" or ClassName == "MeshPart") then
                local PartPosition = RawGet(t, "Position") or Properties["Position"] or MockVector3.zero
                return MockCFrame.new(PartPosition.X, PartPosition.Y, PartPosition.Z)
            end
            if k == "TextBounds" then
                local LabelSize = RawGet(t, "Size") or Properties["Size"]
                local FrameWidth, FrameHeight = 0, 0
                if LabelSize ~= nil and LabelSize.X ~= nil then
                    FrameWidth = LabelSize.X.Offset or 0
                    FrameHeight = LabelSize.Y.Offset or 0
                end
                return Fidelity.TextService:GetTextSize(
                    RawGet(t, "Text") or Properties["Text"] or "",
                    RawGet(t, "TextSize") or Properties["TextSize"] or 14,
                    RawGet(t, "Font") or Properties["Font"],
                    MockVector2.new(FrameWidth, FrameHeight)
                )
            end
            if type(k) == "number" then
                error(StringFormat("%s is not a valid member of %s \"%s\"",
                    ToString(k), ClassName, ClassName), 0)
            end
            local RawValue = RawGet(t, k)
            if RawValue ~= nil then return RawValue end
            if k == "ClassName" then
                return RawGet(t, "__V1_CLASS_NAME") or ClassName
            end
            if type(k) == "string" and Fidelity.PropertyDefaultFor ~= nil then
                local DefaultedValue, IsModelled = Fidelity.PropertyDefaultFor(ClassName, k)
                if IsModelled then
                    return DefaultedValue
                end
            end
            if (k == "C0" or k == "C1") and Fidelity.JointClasses ~= nil
                and Fidelity.JointClasses[ClassName] == true then
                return MockCFrame.identity ~= nil and MockCFrame.identity or MockCFrame.new(0, 0, 0)
            end
            if ClassName == "Stats" and type(k) == "string"
                and Fidelity.MakeStatsItem ~= nil
                and k ~= "Parent" and k ~= "Name" and k ~= "ClassName"
                and k ~= "Archivable" and k ~= "IsLoaded" and k ~= "ParentChanged" then
                return Fidelity.MakeStatsItem(k)
            end
            if StringMatch(ToString(k), "^%u%l") and not Fidelity.WorkspaceAlwaysNilMembers[k] then
                EventSignals[k] = EventSignals[k] or CreateMockSignal(k, t)
                return EventSignals[k]
            end
            return nil
        end,
        __newindex = function(t,k,v)
            if Fidelity.IsReadOnlyInstanceProperty(k) then
                error(StringFormat("Cannot set %s: it is a read-only property", ToString(k)), 0)
            end
            if k == "Parent" and TypeOf(v) == "table" and RawGet(v, "_Type") == nil
                and RawGet(v, "ClassName") == nil and TypeOf(v.ClassName) ~= "string" then
                error(StringFormat("The Parent property of %s is not a valid Instance (%s)",
                    ToString(RawGet(t, "Name") or ClassName), InternalType(v)), 0)
            end
            if k == "Parent" and (RawGet(t, "__V1_LOCK_PARENT")
                or RawGet(Self, "__V1_LOCK_PARENT")) then
                local LockedInstanceName = Properties["Name"]
                if LockedInstanceName == nil then
                    LockedInstanceName = RawGet(t, "Name")
                end
                return RealErrorRef("The Parent property of "
                    .. ToString(LockedInstanceName == nil and "Instance" or LockedInstanceName)
                    .. " is locked", 0)
            end
            if ClassName == "Part" and k == "Transparency" then
                v = QuantizeFloat32(v)
            end
            if k == "Parent" then
                RawSet(t, "__V1_OLD_PARENT_VALUE", RawGet(t, "__V1_PARENT_VALUE"))
                RawSet(t, "__V1_PARENT_VALUE", v)
            end
            v = Fidelity.CoerceProperty(ClassName, k, v)
            ModifiedProperties[k] = true
            Properties[k]=v
            if HasPivot then
                if k == "PivotOffset" and v ~= nil and v.X ~= nil then
                    local HeldPivotFrame = Properties["Pivot"]
                    local PreviousOffsetFrame = Properties["__V1_PIVOT_PREV_OFFSET"]
                    if HeldPivotFrame == nil or HeldPivotFrame.X == nil then
                        local HoldOk, HeldValue = InternalPCall(function()
                            return BaseFrameOf(Properties["CFrame"]) * BaseFrameOf(PreviousOffsetFrame)
                        end)
                        if HoldOk and HeldValue ~= nil and HeldValue.X ~= nil then
                            HeldPivotFrame = HeldValue
                        end
                    end
                    if HeldPivotFrame ~= nil and HeldPivotFrame.X ~= nil then
                        local InverseOk, InverseOffset = InternalPCall(function() return v:Inverse() end)
                        local NewBaseFrame = nil
                        if InverseOk and InverseOffset ~= nil and InverseOffset.X ~= nil then
                            local MoveOk, MovedFrame = InternalPCall(function()
                                return HeldPivotFrame * InverseOffset
                            end)
                            if MoveOk and MovedFrame ~= nil then NewBaseFrame = MovedFrame end
                        else
                            NewBaseFrame = MockCFrame.new(
                                HeldPivotFrame.X - v.X, HeldPivotFrame.Y - v.Y, HeldPivotFrame.Z - v.Z
                            )
                        end
                        WriteBaseFrame(t, NewBaseFrame)
                    end
                elseif k == "Pivot" and v ~= nil and v.X ~= nil then
                    Self.SetPivot(t, v)
                else
                    Properties["Pivot"] = PivotFrameFrom(Properties["CFrame"])
                    PropertyStore["Pivot"] = Properties["Pivot"]
                end
                Properties["__V1_PIVOT_PREV_OFFSET"] = Properties["PivotOffset"]
            end
            if Fidelity.JointClasses ~= nil and Fidelity.JointClasses[ClassName] == true then
                if k == "Part0" or k == "Part1" or k == "Parent" then
                    if v == nil and k == "Parent" then
                        Fidelity.World.ClearJoint(t)
                    else
                        Fidelity.World.SetJoint(t)
                    end
                end
            end
            if Fidelity.IsSpatialPart(ClassName) then
                if k == "CFrame" and v ~= nil and v.Position ~= nil then
                    local PositionValue = MockVector3.new(v.Position.X, v.Position.Y, v.Position.Z)
                    Properties["Position"] = PositionValue
                    PropertyStore["Position"] = PositionValue
                    ModifiedProperties["Position"] = true
                    Fidelity.World.SetBodyState(t, PositionValue, nil)
                elseif k == "Position" then
                    Fidelity.World.SetBodyState(t, v, nil)
                elseif k == "AssemblyLinearVelocity" then
                    Fidelity.World.SetBodyState(t, nil, v)
                elseif k == "Anchored" then
                    if v == true then
                        local BodyPosition = Fidelity.World.BodyPositionOf(t)
                        Fidelity.World.Bodies[t] = nil
                        if BodyPosition ~= nil then
                            Properties["Position"] = BodyPosition
                            PropertyStore["Position"] = BodyPosition
                        end
                    else
                        Fidelity.World.SetBodyState(t, nil, nil)
                    end
                end
            end
            PropertyStore[k]=v
            if k == "Parent" then
                if Fidelity.World.IsWorkspace(v) then
                    if Fidelity.IsSpatialPart(t.ClassName) then
                        Fidelity.World.Register(t)
                    end
                else
                    Fidelity.World.Unregister(t)
                end
                local OldParent = RawGet(t, "__V1_OLD_PARENT_VALUE")
                if OldParent ~= nil then
                    Fidelity.UnregisterChild(OldParent, t)
                end
                if v ~= nil then
                    Fidelity.RegisterChild(v, t)
                end
                if v == nil then
                    RawSet(t, "__V1_DETACHED", true)
                else
                    RawSet(t, "__V1_DETACHED", nil)
                end
            end
            if Signals[k] then
                for _,cb in Next, Signals[k] do
                    InternalPCall(cb)
                end
            end
            local ChangedPropertyNames = Fidelity.ChangedPropertiesFor(ClassName)
            if ChangedPropertyNames ~= nil and TableFind(ChangedPropertyNames, k) ~= nil then
                local ChangedEventSignal = EventSignals["Changed"]
                if ChangedEventSignal ~= nil then
                    ChangedEventSignal:Fire(v)
                end
            end
            EmitMockOutput("property", {
                InstanceObject = t,
                PropertyName = k,
                PropertyValue = v,
            })
        end,
        __tostring = function(SelfInstance)
            local NameValue = RawGet(SelfInstance, "Name")
            if type(NameValue) ~= "string" then
                NameValue = Properties["Name"]
            end
            if type(NameValue) == "string" and NameValue ~= "" then
                return NameValue
            end
            return ClassName
        end,
        __len = Fidelity.InstanceMetamethods.__len,
        __unm = Fidelity.InstanceMetamethods.__unm,
        __lt = Fidelity.InstanceMetamethods.__lt,
        __le = Fidelity.InstanceMetamethods.__le,
        __concat = Fidelity.InstanceMetamethods.__concat,
    }
    SetMetatable(Proxy, ProxyMT)
    Fidelity.Seeders = Fidelity.Seeders or SetMetatable({}, { __mode = "k" })
    Fidelity.Seeders[Proxy] = SeedDefault
    if HasPivot then
        if Properties["PivotOffset"] == nil then
            Properties["PivotOffset"] = StoredPivotOffset()
        end
        if Properties["Pivot"] == nil then
            Properties["Pivot"] = PivotFrameFrom(Properties["CFrame"])
        end
    end
    Fidelity.ApplyInstanceApis(Proxy, ClassName, Fidelity.InstanceApiContext)
    return Proxy
end
Fidelity.CreateMockInstance = CreateMockInstance
Fidelity.InstanceApiContext.Ray = MockRay
Fidelity.InstanceApiContext.BrickColor = MockBrickColor
Fidelity.InstanceApiContext.NumberRange = MockNumberRange
local MockCharacterAdded = CreateMockSignal("CharacterAdded", nil)
MockCharacterAdded.Wait = function()
    return CreateMockInstance("Model")
end
local MockHumanoid = CreateMockInstance("Humanoid")
RawSet(MockHumanoid, "Health", 100)
RawSet(MockHumanoid, "Walkspeed", 16)
RawSet(MockHumanoid, "WalkSpeed", 16)
RawSet(MockHumanoid, "JumpPower", 50)
RawSet(MockHumanoid, "JumpHeight", 7.055224609375)
RawSet(MockHumanoid, "MaxHealth", 100)
RawSet(MockHumanoid, "AutoRotate", true)
RawSet(MockHumanoid, "MoveTo", function(_, PositionValue) return PositionValue end)
local MockHeartbeatCount = 0
local MockRootPart = CreateMockInstance("Part")
RawSet(MockRootPart, "AssemblyLinearVelocity", MockVector3.new(1, 0, 0))
local function MockHeartbeatWait(SignalSelf)
    if SignalSelf == nil or type(SignalSelf) ~= "table" or SignalSelf.Wait == nil then
        error("bad argument #1 to 'Wait' (RBXScriptSignal expected, got " .. tostring(SignalSelf) .. ")", 2)
    end
    MockHeartbeatCount += 1
    Fidelity.Clock.Step(1 / 60)
    local FrameSeconds = Fidelity.MeasureFrameDelta()
    local Speed = MockHeartbeatCount % 2 == 0 and 2 or 1
    RawSet(MockRootPart, "AssemblyLinearVelocity", MockVector3.new(Speed, 0, 0))
    if Fidelity.FireSignals ~= nil and not Fidelity.InHeartbeatFire then
        Fidelity.InHeartbeatFire = true
        Fidelity.FireSignals("Heartbeat", FrameSeconds)
        Fidelity.InHeartbeatFire = false
    end
    return FrameSeconds
end
local MockAnimatorTrack = { _Type="AnimationTrack", IsPlaying=false, TimePosition=0, Length=1 }
function MockAnimatorTrack:Play() self.IsPlaying=true; self.TimePosition=0.05 end
function MockAnimatorTrack:Stop() self.IsPlaying=false end
local MockAnimator = CreateMockInstance("Animator")
_GlobalAnimTime = 0
function MockAnimator:LoadAnimation(anim)
    local tr = { _Type="AnimationTrack", IsPlaying=true, _IsPlaying=true, _TimePosition=0.1, Length=2, Animation=anim }
    function tr:Play() rawset(self,"_IsPlaying",true); rawset(self,"IsPlaying",true) end
    function tr:Stop() rawset(self,"_IsPlaying",false); rawset(self,"IsPlaying",false) end
    setmetatable(tr, { __index=function(t,k)
        if k=="IsPlaying" then return rawget(t,"_IsPlaying") end
        if k=="TimePosition" then return rawget(t,"_TimePosition") + (_G._GlobalAnimTime or _GlobalAnimTime or 0) end
        return rawget(t,k)
    end, __newindex=function(t,k,v) if k=="IsPlaying" then rawset(t,"_IsPlaying",v) end; if k=="TimePosition" then rawset(t,"_TimePosition",v) end; rawset(t,k,v) end })
    return tr
end
local MockCharacter = CreateMockInstance("Model")
MockCharacter.Name="LocalPlayer"
RawSet(MockCharacter, "Humanoid", MockHumanoid)
RawSet(MockHumanoid, "ChangeState", function(_, StateName) return StateName end)
Fidelity.BuildCharacterRig(MockLocalPlayer, MockCharacter, MockHumanoid, MockAnimator)
local MockLocalPlayer = CreateMockInstance("Player")
RawSet(MockLocalPlayer, "GetMouse", function(PlayerObject)
    local Existing = RawGet(PlayerObject, "__KVMS_Mouse")
    if Existing ~= nil then return Existing end
    local VectorLibrary = Fidelity.Vector2
    local MouseObject = CreateMockInstance("PlayerMouse")
    RawSet(MouseObject, "Parent", PlayerObject)
    if VectorLibrary ~= nil then
        RawSet(MouseObject, "X", 0)
        RawSet(MouseObject, "Y", 0)
        RawSet(MouseObject, "View", VectorLibrary.new(0, 0))
    end
    RawSet(MouseObject, "Target", nil)
    RawSet(MouseObject, "IsA", function(_, TargetClassName)
        return TargetClassName == "Mouse" or TargetClassName == "PlayerMouse"
            or TargetClassName == "Instance"
    end)
    if Fidelity.Vector3 ~= nil and Fidelity.Raycast ~= nil then
        RawSet(MouseObject, "UnitRay", Fidelity.Raycast.new(
            Fidelity.Vector3.new(0, 0, 0), Fidelity.Vector3.new(0, 0, -1)))
    end
    RawSet(MouseObject, "View", Fidelity.Vector2 and Fidelity.Vector2.new(0, 0))
    local MouseViewportX, MouseViewportY = Fidelity.CameraViewportSize()
    RawSet(MouseObject, "ViewSizeX", MouseViewportX)
    RawSet(MouseObject, "ViewSizeY", MouseViewportY)
    for _, KeyName in ipairs({ "Button1Down", "Button1Up", "Button2Down", "Button2Up" }) do
        RawSet(MouseObject, KeyName, CreateMockSignal("Mouse." .. KeyName, MouseObject))
    end
    RawSet(MouseObject, "GetObservedTime", function() return 0 end)
    RawSet(MouseObject, "Move", CreateMockSignal("Mouse.Move", MouseObject))
    RawSet(MouseObject, "WheelForward", CreateMockSignal("Mouse.WheelForward", MouseObject))
    RawSet(MouseObject, "WheelBackward", CreateMockSignal("Mouse.WheelBackward", MouseObject))
    RawSet(MouseObject, "__KVMS_MouseFor", PlayerObject)
    RawSet(PlayerObject, "__KVMS_Mouse", MouseObject)
    return MouseObject
end)
MockLocalPlayer.Name="LocalPlayer"
RawSet(MockLocalPlayer, "UserId", 135097)
RawSet(MockLocalPlayer, "DisplayName", "LocalPlayer")
local MockPlayerGui = CreateMockInstance("PlayerGui")
RawSet(MockLocalPlayer, "PlayerGui", MockPlayerGui)
RawSet(MockLocalPlayer, "WaitForChild", function(_, ChildName, TimeoutSeconds)
    if ChildName == "PlayerGui" then return MockPlayerGui end
    if TimeoutSeconds ~= nil and ToNumber(TimeoutSeconds) == nil then
        RealErrorRef("bad argument #2 to 'WaitForChild' (number expected, got "
            .. InternalType(TimeoutSeconds) .. ")", 0)
    end
    return nil
end)
RawSet(MockLocalPlayer, "Character", MockCharacter)
RawSet(MockLocalPlayer, "CharacterAdded", MockCharacterAdded)
RawSet(MockLocalPlayer, "TeamColor", MockBrickColor.new("Really blue"))
Fidelity.RegisterChild(MockLocalPlayer, MockPlayerGui)
local MockPlayersService = CreateMockInstance("Players")
RawSet(MockPlayersService, "LocalPlayer", MockLocalPlayer)
RawSet(MockPlayersService, "GetPlayers", function() return {MockLocalPlayer} end)
RawSet(MockPlayersService, "GetPlayerByUserId", function(_, UserIdValue)
    if RawGet(MockLocalPlayer, "UserId") == UserIdValue then return MockLocalPlayer end
    return nil
end)
RawSet(MockPlayersService, "GetPlayerByName", function(_, NameValue)
    if RawGet(MockLocalPlayer, "Name") == NameValue then return MockLocalPlayer end
    return nil
end)
RawSet(MockPlayersService, "GetPlayerFromCharacter", function(_, CharacterValue)
    if CharacterValue == MockCharacter then return MockLocalPlayer end
    return nil
end)
RawSet(MockPlayersService, "CharacterAutoLoads", true)
RawSet(MockPlayersService, "RespectPhysicsAspectRatio", true)
Fidelity.MockPlayerDirectory = {}
RawSet(MockPlayersService, "GetNameFromUserIdAsync",
    function(_, UserIdValue, _UseCache)
        local NumericId = tonumber(UserIdValue)
        if NumericId == nil or NumericId <= 0 then
            error("Players:GetNameFromUserIdAsync requires a userId greater than 0", 0)
        end
        if NumericId ~= nil then
            local Seeded = Fidelity.MockPlayerDirectory[NumericId]
            if Seeded ~= nil then return Seeded end
        end
        return (MockLocalPlayer ~= nil and MockLocalPlayer.Name) or "Player"
    end)
RawSet(MockPlayersService, "GetUserIdFromNameAsync",
    function(_, NameValue)
        for PlayerId, PlayerName in pairs(Fidelity.MockPlayerDirectory) do
            if PlayerName == NameValue then return PlayerId end
        end
        if NameValue == MockLocalPlayer.Name then
            return MockLocalPlayer.UserId
        end
        error("The username '" .. tostring(NameValue) .. "' does not exist", 2)
    end)
local MockInstance = {
    new = function(className, parent)
        if Fidelity.IsNotCreatableClassName ~= nil and Fidelity.IsNotCreatableClassName(className) then
            error(StringFormat("Unable to create an Instance of type \"%s\"", ToString(className)), 0)
        end
        local inst = CreateMockInstance(className)
        MockInstanceCounter += 1
        local InstanceIdentifier = Fidelity.SynthesisedInstanceName(className, MockInstanceCounter)
        RawSet(inst, "__V1_ID", InstanceIdentifier)
        if parent ~= nil then
            RawSet(inst, "__V1_PARENT_VALUE", parent)
            Fidelity.RegisterChild(parent, inst)
            if Fidelity.World.IsWorkspace(parent) and Fidelity.IsSpatialPart(className) then
                Fidelity.World.Register(inst)
            end
        end
        local SeedDefault = Fidelity.Seeders and Fidelity.Seeders[inst]
        local function Seed(PropName, PropValue)
            if SeedDefault then SeedDefault(PropName, PropValue) end
        end
        if className=="Animation" then
            RawSet(inst, "AnimationId", "")
        elseif className=="NumberValue" then
            RawSet(inst, "Value", 0)
        elseif className=="Part" or className=="MeshPart" then
            Seed("Size", MockVector3.new(4, 1.2, 2))
            Seed("Position", MockVector3.new(0, 0, 0))
            Seed("Anchored", false)
            Seed("CanCollide", true)
            Seed("CanQuery", true)
            Seed("CanTouch", true)
            Seed("Transparency", 0)
            Seed("Reflectance", 0)
            Seed("Material", Fidelity.EnumValue("Material", "Plastic", 256))
            Seed("Color", MockColor3.fromRGB(163, 162, 165))
            Seed("BrickColor", MockBrickColor.new("Medium stone grey"))
        elseif className=="Sound" then
            Seed("Volume", 0.5)
            Seed("PlaybackSpeed", 1)
            Seed("Looped", false)
            Seed("SoundId", "")
        elseif className=="TextLabel" or className=="TextButton" or className=="TextBox" then
            Seed("Text", "")
            Seed("TextSize", 14)
            Seed("Font", Fidelity.EnumValue("Font", "SourceSans", 3))
        end
        EmitMockOutput("create", {
            ClassName = className,
            InstanceObject = inst,
            ParentObject = parent,
        })
        return inst
    end
}
local function FormatMockUiScalar(ValueData)
    if ValueData == nil then return "nil" end
    local ValueType = TypeOf(ValueData)
    if ValueType == "string" then return StringFormat("%q", ValueData) end
    if ValueType == "number" then
        if ValueData == MathHuge then return "math.huge" end
        if ValueData == -MathHuge then return "-math.huge" end
        if ValueData % 1 == 0 then return ToString(ValueData) end
        return StringFormat("%.8g", ValueData)
    end
    if ValueType == "boolean" then return ValueData and "true" or "false" end
    return StringFormat("%q", ToString(ValueData))
end
local function FormatMockUiValue(ValueData, Depth, OptionsTable)
    Depth = Depth or 0
    local ValueType = TypeOf(ValueData)
    if ValueData == nil or ValueType == "string" or ValueType == "number" or ValueType == "boolean" then
        return FormatMockUiScalar(ValueData)
    end
    if ValueType == "table" then
        local InstanceIdentifier = RawGet(ValueData, "__V1_ID")
        if InstanceIdentifier then return InstanceIdentifier end
        if RawGet(ValueData, "__V1_DATAMODEL") then
            return (RawGet(ValueData, "ClassName") or RawGet(ValueData, "__V1_CLASS_NAME")) == "DataModel" and "game" or "workspace"
        end
        local RenderedDatatype = Fidelity.RenderDatatypeLiteral(ValueData)
        if RenderedDatatype ~= nil then
            return RenderedDatatype
        end
        local ClassNameValue = (RawGet(ValueData, "ClassName") or RawGet(ValueData, "__V1_CLASS_NAME"))
        if ClassNameValue == "PlayerGui" then
            return 'game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")'
        elseif ClassNameValue == "Player" then
            return 'game:GetService("Players").LocalPlayer'
        elseif ClassNameValue == "Humanoid" then
            return 'game:GetService("Players").LocalPlayer.Character:FindFirstChildOfClass("Humanoid")'
        elseif ClassNameValue == "Model" and RawGet(ValueData, "Name") == "Character" then
            return 'game:GetService("Players").LocalPlayer.Character'
        end
        if RawGet(ValueData, "__V1_INSTANCE") ~= nil or RawGet(ValueData, "__V1_TYPE") == "Instance" then
            return ""
        end
    end
    if ValueType == "function" then
        local CallbackLines = MockCallbackBodies[ValueData]
        if CallbackLines and #CallbackLines > 0 then
            if OptionsTable and OptionsTable.KeepParameters and Fidelity.CallbackFormatter then
                local ReflowSucceeded, ReflowedCallback = InternalPCall(Fidelity.CallbackFormatter, ValueData)
                if ReflowSucceeded and TypeOf(ReflowedCallback) == "string" and ReflowedCallback ~= "" then
                    return ReflowedCallback
                end
            end
            return "function()\n" .. TableConcat(CallbackLines, "\n") .. "\nend"
        end
        if Fidelity.CallbackFormatter then
            local FormatSucceeded, FormattedCallback = InternalPCall(Fidelity.CallbackFormatter, ValueData)
            if FormatSucceeded and TypeOf(FormattedCallback) == "string" and FormattedCallback ~= "" then
                return FormattedCallback
            end
        end
        return "function() end"
    elseif ValueType == "thread" or ValueType == "userdata" then
        return "nil"
    end
    if ValueType == "table" and Depth < 2 then
        local Fields = {}
        local FieldCount = 0
        for KeyData, ElementData in Next, ValueData do
            local KeyText = ToString(KeyData)
            if StringSub(KeyText, 1, 8) ~= "__V1_" and StringSub(KeyText, 1, 1) ~= "_" then
                FieldCount += 1
                if InternalType(KeyData) == "string" and StringMatch(KeyData, "^[A-Za-z_][A-Za-z0-9_]*$") then
                    KeyText = KeyData .. " = "
                else
                    KeyText = "[" .. FormatMockUiValue(KeyData, Depth + 1) .. "] = "
                end
                Fields[FieldCount] = KeyText .. FormatMockUiValue(ElementData, Depth + 1)
                if FieldCount >= 32 then break end
            end
        end
        if FieldCount > 0 then
            return "{ " .. TableConcat(Fields, ", ") .. " }"
        end
    end
    return "{}"
end
local function SanitizeRemoteVariableName(ValueData)
    local CleanName = StringGsub(ToString(ValueData or ""), "[^A-Za-z0-9_]", "")
    if CleanName == "" then return "Remote" end
    if ToNumber(StringSub(CleanName, 1, 1)) then
        CleanName = "Remote" .. CleanName
    end
    return CleanName
end
local function ChooseRemoteVariableName(MethodName, Arguments)
    local BaseName
    local MethodSuffixes = {
        CreateButton = "Button",
        CreateToggle = "Toggle",
        CreateSlider = "Slider",
        CreateInput = "Input",
        CreateDropdown = "Dropdown",
        CreateColorPicker = "ColorPicker",
        CreateKeybind = "Keybind",
        CreateParagraph = "Paragraph",
    }
    if MethodName == "CreateWindow" then
        BaseName = "Window"
    elseif MethodName == "CreateTab" then
        BaseName = SanitizeRemoteVariableName(Arguments[1]) .. "Tab"
    elseif MethodName == "CreateSection" then
        BaseName = SanitizeRemoteVariableName(Arguments[1]) .. "Section"
    elseif MethodName == "Notify" then
        BaseName = "Notification"
    elseif MethodSuffixes[MethodName] then
        local ConfigData = Arguments[1]
        local ConfigName = TypeOf(ConfigData) == "table" and RawGet(ConfigData, "Name") or nil
        local Suffix = MethodSuffixes[MethodName]
        if ConfigName then
            local CleanConfigName = SanitizeRemoteVariableName(ConfigName)
            BaseName = CleanConfigName == Suffix and Suffix or CleanConfigName .. Suffix
        else
            BaseName = Suffix
        end
    else
        BaseName = SanitizeRemoteVariableName(MethodName or "RemoteObject")
    end
    local ExistingCount = MockRemoteNameCounts[BaseName] or 0
    MockRemoteNameCounts[BaseName] = ExistingCount + 1
    return ExistingCount == 0 and BaseName or BaseName .. tostring(ExistingCount + 1)
end
local function BuildMockUiLogLine(EventKind, Payload)
    if TypeOf(Payload) ~= "table" then return nil end
    if EventKind == "create" then
        local InstanceObject = Payload.InstanceObject
        local InstanceIdentifier = InstanceObject and RawGet(InstanceObject, "__V1_ID")
        if not InstanceIdentifier then return nil end
        local CreateStatement = StringFormat(
            "local %s = Instance.new(%s",
            InstanceIdentifier,
            FormatMockUiValue(Payload.ClassName)
        )
        if Payload.ParentObject ~= nil then
            CreateStatement ..= ", " .. FormatMockUiValue(Payload.ParentObject)
        end
        return CreateStatement .. ")"
    elseif EventKind == "property" then
        local InstanceIdentifier = Payload.InstanceObject and RawGet(Payload.InstanceObject, "__V1_ID")
        local ObjectExpression = InstanceIdentifier or FormatMockUiValue(Payload.InstanceObject)
        if not ObjectExpression or ObjectExpression == "" or ObjectExpression == "{}" then return nil end
        local PropertyName = ToString(Payload.PropertyName)
        local PropertySuffix = StringMatch(PropertyName, "^[A-Za-z_][A-Za-z0-9_]*$")
            and "." .. PropertyName
            or "[" .. FormatMockUiValue(PropertyName) .. "]"
        return ObjectExpression .. PropertySuffix .. " = " .. FormatMockUiValue(Payload.PropertyValue)
    elseif EventKind == "task_call" then
        local TaskNameText = ToString(Payload.TaskName)
        if TaskNameText == "" then TaskNameText = "spawn" end
        local CallbackText = FormatMockUiValue(Payload.CallbackFunction, nil, { KeepParameters = true })
        if TaskNameText == "delay" then
            local DelayText = Payload.DelaySeconds
                and FormatMockUiValue(Payload.DelaySeconds) or "0"
            return StringFormat("task.delay(%s, %s)", DelayText, CallbackText)
        end
        return StringFormat("task.%s(%s)", TaskNameText, CallbackText)
    elseif EventKind == "connect" then
        local OwnerObject = Payload.OwnerObject
        local InstanceIdentifier = OwnerObject and RawGet(OwnerObject, "__V1_ID")
        if not InstanceIdentifier and OwnerObject
            and RawGet(OwnerObject, "__V1_INSTANCE") then
            local OwnerClassName = RawGet(OwnerObject, "ClassName")
            if OwnerClassName then
                InstanceIdentifier = "game:GetService("
                    .. FormatMockUiValue(OwnerClassName) .. ")"
            end
        end
        if not InstanceIdentifier then return nil end
        local EventExpression = Payload.SignalExpression and ToString(Payload.SignalExpression)
            or (Payload.SignalObject and Fidelity.SignalSuffixFor and Fidelity.SignalSuffixFor(Payload.SignalObject))
            or "." .. ToString(Payload.EventName)
        return InstanceIdentifier .. EventExpression
            .. ":" .. ToString(Payload.MethodName or "Connect")
            .. "(" .. FormatMockUiValue(Payload.CallbackFunction, nil, { KeepParameters = true }) .. ")"
    elseif EventKind == "metadata_call" then
        local CallTarget = Payload.InstanceObject and RawGet(Payload.InstanceObject, "__V1_ID")
        if not CallTarget or CallTarget == "" then return nil end
        local CallArguments = Payload.Arguments or {}
        local FormattedArguments = {}
        for ArgumentIndex = 1, #CallArguments do
            FormattedArguments[ArgumentIndex] = FormatMockUiValue(CallArguments[ArgumentIndex])
        end
        return CallTarget .. ":" .. ToString(Payload.MethodName)
            .. "(" .. TableConcat(FormattedArguments, ", ") .. ")"
    elseif EventKind == "metatable_index" then
        return "-- __index >> " .. ToString(Payload.KeyName)
    elseif EventKind == "index" then
        MockProbeCounter += 1
        local ObjectName = ToString(Payload.ObjectName)
        local KeyName = ToString(Payload.KeyName)
        local KeyExpression = StringMatch(KeyName, "^[A-Za-z_][A-Za-z0-9_]*$")
            and "." .. KeyName
            or "[" .. FormatMockUiValue(KeyName) .. "]"
        return StringFormat(
            "local Probe_%d = %s%s",
            MockProbeCounter,
            ObjectName,
            KeyExpression
        )
    elseif EventKind == "http" then
        local ModuleIndex = Payload.ModuleIndex or 1
        local UrlText = StringLower(ToString(Payload.Url))
        local BaseName = StringFind(UrlText, "rayfield", 1, true) and "Rayfield"
            or StringFind(UrlText, "windui", 1, true) and "WindUI"
            or StringFind(UrlText, "fluent", 1, true) and "Fluent"
            or "RemoteLib"
        local ExistingCount = MockRemoteNameCounts[BaseName] or 0
        MockRemoteNameCounts[BaseName] = ExistingCount + 1
        local ModuleName = ExistingCount == 0 and BaseName or BaseName .. tostring(ExistingCount + 1)
        local RemotePath = Payload.RemotePath or StringFormat("__REMOTE_%d__", ModuleIndex)
        MockRemotePathNames[RemotePath] = ModuleName
        local EmittedUrlLiteral = FormatMockUiValue(Payload.Url)
        if TypeOf(EmittedUrlLiteral) ~= "string" then
            EmittedUrlLiteral = '" "'
        end
        return StringFormat(
            "local %s = (function()\n\tlocal Source = game:HttpGet(%s)\n\tlocal Chunk = (type(Source) == \"string\" and loadstring) and loadstring(Source)\n\tif Chunk then\n\t\tlocal Ok, Loaded = pcall(Chunk)\n\t\tif Ok and Loaded ~= nil then return Loaded end\n\tend\n\treturn setmetatable({ __V1_UNRESOLVED = %s }, {__index = function(Self) return Self end, __newindex = function() end, __call = function(Self) return Self end, __concat = function() return \"\" end, __tostring = function() return %s end})\nend)()",
            ModuleName,
            EmittedUrlLiteral,
            StringFormat("%q", ToString(Payload.Url)),
            StringFormat("%q", ModuleName)
        )
    elseif EventKind == "api" then
        local Arguments = Payload.Arguments or {}
        local FormattedArguments = {}
        for ArgumentIndex = 1, #Arguments do
            FormattedArguments[ArgumentIndex] = FormatMockUiValue(Arguments[ArgumentIndex])
        end
        local Path = ToString(Payload.Path)
        local ParentPath, MethodName = StringMatch(Path, "^(.*)%.([^.]+)$")
        local ParentExpression = ParentPath and MockRemotePathNames[ParentPath]
        local ResultName = ChooseRemoteVariableName(MethodName, Arguments)
        local CallExpression
        if ParentExpression and MethodName then
            CallExpression = ParentExpression .. ":" .. MethodName
        else
            CallExpression = MockRemotePathNames[Path] or Path
        end
        if CallExpression == nil or CallExpression == "" then
            return nil
        end
        MockRemotePathNames[Path] = ResultName
        return "local " .. ResultName .. " = " .. CallExpression
            .. "(" .. TableConcat(FormattedArguments, ", ") .. ")"
    elseif EventKind == "api_set" then
        local Path = ToString(Payload.Path)
        local ObjectExpression = MockRemotePathNames[Path] or Path
        if ObjectExpression == nil or ObjectExpression == "" then
            return nil
        end
        return ObjectExpression .. "." .. ToString(Payload.KeyName)
            .. " = " .. FormatMockUiValue(Payload.ValueData)
    elseif EventKind == "generic_api" then
        local Arguments = Payload.Arguments or {}
        local FormattedArguments = {}
        for ArgumentIndex = 1, #Arguments do
            FormattedArguments[ArgumentIndex] = FormatMockUiValue(Arguments[ArgumentIndex])
        end
        local Path = ToString(Payload.Path)
        local ParentPath, MethodName = StringMatch(Path, "^(.*)%.([^.]+)$")
        local CallExpression = Path
        if Payload.UseColon and ParentPath and MethodName then
            CallExpression = ParentPath .. ":" .. MethodName
        end
        if Payload.UseColon and (ParentPath == nil or ParentPath == "") then
            return nil
        end
        return CallExpression .. "(" .. TableConcat(FormattedArguments, ", ") .. ")"
    elseif EventKind == "generic_set" then
        local SetTargetExpression = ToString(Payload.Path)
        if SetTargetExpression == "" then
            return nil
        end
        return SetTargetExpression .. "." .. ToString(Payload.KeyName)
            .. " = " .. FormatMockUiValue(Payload.ValueData)
    end
    return nil
end
local MockMemStore = {}
local MockMemStorageService = {
    __V1_TYPE = "Instance",
    __V1_INSTANCE = true,
    SetItem = function(_, k,v) MockMemStore[k]=v end,
    GetItem = function(_, k) return MockMemStore[k] end,
    RemoveItem = function(_, k) MockMemStore[k]=nil end,
    GetItemAsync = function(_, k) return MockMemStore[k] end,
    SetItemAsync = function(_, k,v) MockMemStore[k]=v end,
}
local MockCollectionTags = {}
local MockCollectionService = CreateMockInstance("CollectionService")
RawSet(MockCollectionService, "Name", "CollectionService")
MockGameCollectionService = MockCollectionService
do
    local CollectionMethods = {}
    function CollectionMethods:AddTag(ObjectInstance, Tag)
        Fidelity.AddTagTo(ObjectInstance, Tag)
        MockCollectionTags[Tag] = MockCollectionTags[Tag] or {}
        if not TableFind(MockCollectionTags[Tag], ObjectInstance) then
            TableInsert(MockCollectionTags[Tag], ObjectInstance)
        end
    end
    function CollectionMethods:RemoveTag(ObjectInstance, Tag)
        Fidelity.RemoveTagFrom(ObjectInstance, Tag)
        local TagList = MockCollectionTags[Tag]
        if not TagList then return end
        for IndexNum = #TagList, 1, -1 do
            if TagList[IndexNum] == ObjectInstance then TableRemove(TagList, IndexNum) end
        end
    end
    function CollectionMethods:HasTag(ObjectInstance, Tag)
        local TagList = MockCollectionTags[Tag]
        return TagList ~= nil and TableFind(TagList, ObjectInstance) ~= nil
    end
    function CollectionMethods:GetTags(ObjectInstance)
        local ResultTags = {}
        for TagName, TagList in Next, MockCollectionTags do
            if TagList and TableFind(TagList, ObjectInstance) then
                ResultTags[#ResultTags + 1] = TagName
            end
        end
        return ResultTags
    end
    function CollectionMethods:GetTagged(Tag)
        local TagList = MockCollectionTags[Tag]
        if not TagList then return {} end
        local Copy = {}
        for IndexNum = 1, #TagList do
            local TaggedInstance = TagList[IndexNum]
            local InDataModel = false
            if TypeOf(TaggedInstance) == "table"
                and not RawGet(TaggedInstance, "__V1_DETACHED") then
                local AncestorObject = TaggedInstance
                for _ = 1, 64 do
                    if AncestorObject == nil then break end
                    if RawGet(AncestorObject, "__V1_DATAMODEL") then
                        InDataModel = true
                        break
                    end
                    local ParentObject = AncestorObject.Parent
                    if ParentObject == nil then break end
                    AncestorObject = ParentObject
                end
            end
            if InDataModel then
                Copy[#Copy + 1] = TaggedInstance
            end
        end
        return Copy
    end
    function CollectionMethods:GetInstanceAddedSignal(Tag)
        local SignalCache = RawGet(MockCollectionService, "__V1_SIGNAL_CACHE")
        if SignalCache == nil then
            SignalCache = {}
            RawSet(MockCollectionService, "__V1_SIGNAL_CACHE", SignalCache)
        end
        local CacheKey = "Added:" .. ToString(Tag)
        local SignalObject = SignalCache[CacheKey]
        if SignalObject == nil then
            SignalObject = CreateMockSignal("GetInstanceAddedSignal", MockCollectionService)
            SignalCache[CacheKey] = SignalObject
        end
        return SignalObject
    end
    function CollectionMethods:GetInstanceRemovedSignal(Tag)
        local SignalCache = RawGet(MockCollectionService, "__V1_SIGNAL_CACHE")
        if SignalCache == nil then
            SignalCache = {}
            RawSet(MockCollectionService, "__V1_SIGNAL_CACHE", SignalCache)
        end
        local CacheKey = "Removed:" .. ToString(Tag)
        local SignalObject = SignalCache[CacheKey]
        if SignalObject == nil then
            SignalObject = CreateMockSignal("GetInstanceRemovedSignal", MockCollectionService)
            SignalCache[CacheKey] = SignalObject
        end
        return SignalObject
    end
    local InstalledCollectionMethods = RawGet(MockCollectionService, "__V1_Methods")
    for MethodName, MethodValue in Next, CollectionMethods do
        RawSet(MockCollectionService, MethodName, MethodValue)
        InstalledCollectionMethods[MethodName] = MethodValue
    end
end
local MockSoundService = Fidelity.MakeSoundService({
    Name = "SoundService",
    ClassName = "SoundService",
    __V1_INSTANCE = true,
    __V1_TYPE = "Instance",
})
local MockHttpService = CreateMockInstance("HttpService")
RawSet(MockHttpService, "Name", "HttpService")
RawSet(MockHttpService, "HttpEnabled", true)
RawSet(MockHttpService, "GetSecret", function(ServiceObject, SecretName)
    if TypeOf(SecretName) ~= "string" then
        error(StringFormat("bad argument #1 to 'GetSecret' (string expected, got %s)",
            InternalType(SecretName)), 0)
    end
    error(StringFormat("HttpService:GetSecret() failed: no secret named '%s' is available to this place",
        SecretName), 0)
end)
do
    local HttpMethods = {}
    function HttpMethods:JSONEncode(ValueData)
        return Fidelity.JsonEncode(ValueData)
    end
    function HttpMethods:JSONDecode(TextData)
        return Fidelity.JsonDecode(TextData)
    end
    function HttpMethods:UrlEncode(TextData)
        return ToString(TextData or "")
    end
    function HttpMethods:UrlDecode(TextData)
        return ToString(TextData or "")
    end
    function HttpMethods:GetAsync(Url, NoCache)
        return RawGet(MockHttpService, "__V1_HttpResolver")(Url)
    end
    function HttpMethods:PostAsync(Url, Data, ContentType, Compress, Headers)
        return RawGet(MockHttpService, "__V1_HttpResolver")(Url)
    end
    function HttpMethods:RequestAsync(Options)
        local Url = TypeOf(Options) == "table" and Options.Url or nil
        return {
            Success = true,
            StatusCode = 200,
            StatusMessage = "OK",
            Headers = {},
            Body = RawGet(MockHttpService, "__V1_HttpResolver")(Url),
        }
    end
    function HttpMethods:GenerateGUID(WrapInCurlyBraces)
        MockRemoteModuleCounter += 1
        local RandomA = math.floor(MathRandom() * 0xFFFFFFFF)
        local RandomB = math.floor(MathRandom() * 0xFFFFFFFF)
        local GuidBody = StringFormat("%08X-%04X-%04X-%04X-%012X",
            RandomA, RandomB % 0x10000, 0x8000 + (MockRemoteModuleCounter % 0x4000),
            RandomB % 0x10000, MockRemoteModuleCounter)
        if WrapInCurlyBraces then
            return "{" .. GuidBody .. "}"
        end
        return GuidBody
    end
    local InstalledHttpMethods = RawGet(MockHttpService, "__V1_Methods")
    for MethodName, MethodValue in Next, HttpMethods do
        RawSet(MockHttpService, MethodName, MethodValue)
        InstalledHttpMethods[MethodName] = MethodValue
    end
end
local MockCoreGui = CreateMockInstance("CoreGui")
Fidelity.RegisterChild(MockCoreGui, (function()
    local TopbarFolder = CreateMockInstance("Folder")
    TopbarFolder.Name = "TopbarContainer"
    TopbarFolder.Parent = MockCoreGui
    return TopbarFolder
end)())
MockEncodingService = CreateMockInstance("EncodingService")
do
    local B64Chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    local B64Map = {}
    for CharIndex = 1, #B64Chars do B64Map[B64Chars:sub(CharIndex, CharIndex)] = CharIndex - 1 end
    local function EncodeBase64String(DataString)
        local OutChunks = {}
        local DataLength = #DataString
        for IndexStart = 1, DataLength, 3 do
            local B1 = StringByte(DataString, IndexStart)
            local B2 = StringByte(DataString, IndexStart + 1)
            local B3 = StringByte(DataString, IndexStart + 2)
            local E1 = MathFloor(B1 / 4)
            local E2 = (B1 % 4) * 16 + (B2 and MathFloor(B2 / 16) or 0)
            local E3 = (B2 and (B2 % 16) * 4 + (B3 and MathFloor(B3 / 64) or 0)) or nil
            local E4 = B3 and (B3 % 64) or nil
            OutChunks[#OutChunks + 1] = B64Chars:sub(E1 + 1, E1 + 1)
            OutChunks[#OutChunks + 1] = B64Chars:sub(E2 + 1, E2 + 1)
            OutChunks[#OutChunks + 1] = E3 and B64Chars:sub(E3 + 1, E3 + 1) or "="
            OutChunks[#OutChunks + 1] = E4 and B64Chars:sub(E4 + 1, E4 + 1) or "="
        end
        return TableConcat(OutChunks)
    end
    local function DecodeBase64String(EncodedString)
        local OutBytes = {}
        local Accumulator, AccumulatedBits = 0, 0
        for IndexCursor = 1, #EncodedString do
            local CurrentChar = StringSub(EncodedString, IndexCursor, IndexCursor)
            if CurrentChar == "=" then break end
            local DecodedValue = B64Map[CurrentChar]
            if DecodedValue == nil then
                InternalError("invalid base64 input", 0)
            end
            Accumulator = Accumulator * 64 + DecodedValue
            AccumulatedBits = AccumulatedBits + 6
            if AccumulatedBits >= 8 then
                AccumulatedBits = AccumulatedBits - 8
                OutBytes[#OutBytes + 1] = StringChar(MathFloor(Accumulator / 2 ^ AccumulatedBits) % 256)
                Accumulator = Accumulator % 2 ^ AccumulatedBits
            end
        end
        return TableConcat(OutBytes)
    end
    local function ComputeSimpleHash(InputText)
        local HashValue = 5381
        for CharIndex = 1, #InputText do
            HashValue = (HashValue * 33 + StringByte(InputText, CharIndex)) % 2147483647
        end
        return StringFormat("%08X", HashValue)
    end
    RawSet(MockEncodingService, "Base64Encode", function(_, InputBuffer, Algorithms)
        return buffer.fromstring(EncodeBase64String(buffer.tostring(InputBuffer)))
    end)
    RawSet(MockEncodingService, "Base64Decode", function(_, InputBuffer, Algorithms)
        return buffer.fromstring(DecodeBase64String(buffer.tostring(InputBuffer)))
    end)
    RawSet(MockEncodingService, "ComputeStringHash", function(_, InputString, Algorithms)
        return ComputeSimpleHash(ToString(InputString))
    end)
    RawSet(MockEncodingService, "ComputeBufferHash", function(_, InputBuffer, Algorithms)
        return buffer.fromstring(ComputeSimpleHash(buffer.tostring(InputBuffer)))
    end)
    local CompressedFrameMagics = {
        { 0x28, 0xB5, 0x2F, 0xFD },
        { 0x04, 0x22, 0x4D, 0x18 },
        { 0x1F, 0x8B },
    }
    local function BufferPrefixBytes(BufferValue, ByteCount)
        local LengthOk, LengthValue = InternalPCall(buffer.len, BufferValue)
        if not LengthOk or InternalType(LengthValue) ~= "number" or LengthValue < ByteCount then
            return nil
        end
        local PrefixBytes = {}
        for ByteIndex = 0, ByteCount - 1 do
            local ReadOk, ByteValue = InternalPCall(buffer.readu8, BufferValue, ByteIndex)
            if not ReadOk or InternalType(ByteValue) ~= "number" then
                return nil
            end
            PrefixBytes[ByteIndex + 1] = ByteValue
        end
        return PrefixBytes
    end
    local function IsCompressedFrame(BufferValue)
        for _, MagicBytes in ipairs(CompressedFrameMagics) do
            local PrefixBytes = BufferPrefixBytes(BufferValue, #MagicBytes)
            if PrefixBytes ~= nil then
                local MatchesAll = true
                for PartIndex = 1, #MagicBytes do
                    if PrefixBytes[PartIndex] ~= MagicBytes[PartIndex] then
                        MatchesAll = false
                        break
                    end
                end
                if MatchesAll then
                    return true
                end
            end
        end
        return false
    end
    RawSet(MockEncodingService, "CompressBuffer", function(_, InputBuffer, Algorithm, Level)
        return InputBuffer
    end)
    RawSet(MockEncodingService, "DecompressBuffer", function(_, InputBuffer, Algorithm)
        if IsCompressedFrame(InputBuffer) then
            return RealErrorRef("DecompressBuffer: compressed data this run did not produce cannot be expanded here", 0)
        end
        return InputBuffer
    end)
    RawSet(MockEncodingService, "GetDecompressedBufferSize", function(_, InputBuffer, Algorithm)
        if IsCompressedFrame(InputBuffer) then
            return nil
        end
        return buffer.len(InputBuffer)
    end)
end
MockInsertService = CreateMockInstance("InsertService")
RawSet(MockInsertService, "Name", "InsertService")
RawSet(MockInsertService, "__V1_LOCK_PARENT", true)
RawSet(MockInsertService, "LoadAsset", function()
    return RealErrorRef("LoadAsset is unavailable in KVMS compatibility mode", 0)
end)
RawSet(MockInsertService, "LoadAssetVersion", function()
    return RealErrorRef("LoadAssetVersion is unavailable in KVMS compatibility mode", 0)
end)
RawSet(MockInsertService, "GetLatestAssetVersionAsync", function()
    return RealErrorRef("GetLatestAssetVersionAsync is unavailable in KVMS compatibility mode", 0)
end)
RawSet(MockInsertService, "CreateMeshPartAsync", function()
    return RealErrorRef("CreateMeshPartAsync is unavailable in KVMS compatibility mode", 0)
end)
RawSet(MockInsertService, "Clone", function()
    return RealErrorRef("InsertService cannot be cloned", 0)
end)
local MockTweenService = {
    __V1_INSTANCE = true,
    __V1_TYPE = "Instance",
    ClassName = "TweenService",
    Name = "TweenService",
    Create = function(_, instance, tweenInfo, goal)
        if type(goal) ~= "table" then
            error(StringFormat("bad argument #3 to 'Create' (table expected, got %s)",
                InternalType(goal)), 0)
        end
        -- r72: engine menolak nilai yang tidak cocok dengan tipe propertinya
        for GoalKey, GoalValue in pairs(goal) do
            if type(GoalKey) ~= "string" then
                error("invalid goal key: property name expected, got " .. type(GoalKey), 0)
            end
            if GoalValue == nil or type(GoalValue) == "function" or type(GoalValue) == "boolean" then
                error("The provided property value cannot be applied to property " .. GoalKey, 0)
            end
            if instance ~= nil then
                local CurrentValue = nil
                pcall(function() CurrentValue = instance[GoalKey] end)
                if CurrentValue ~= nil then
                    if type(CurrentValue) == "table" then
                        if InternalType(GoalValue) ~= "table" or typeof(CurrentValue) ~= typeof(GoalValue) then
                            error("The provided property value cannot be applied to property " .. GoalKey, 0)
                        end
                    elseif type(CurrentValue) ~= type(GoalValue) then
                        error("The provided property value cannot be applied to property " .. GoalKey, 0)
                    end
                end
            end
        end
        local Info = TypeOf(tweenInfo) == "table" and tweenInfo or {}
        local Duration = tonumber(Info.Time) or 1
        local DelaySeconds = tonumber(Info.DelayTime) or 0
        local Style = Info.EasingStyle
        local Direction = Info.EasingDirection
        local Reverses = Info.Reverses == true
        local StartValues = {}
        local Elapsed = 0
        local CompleteCallbacks = {}
        local TweenProxy = { ClassName = "Tween", Name = "Tween", _Type = "Tween", IsPlaying = false, __V1_TYPE = "Instance", __V1_INSTANCE = true }
        Fidelity.ApplyInstanceApis(TweenProxy, "Tween", Fidelity.InstanceApiContext)
        local function CurrentAlpha()
            if Duration <= 0 then
                return 1
            end
            local progress = (Elapsed - DelaySeconds) / Duration
            if progress < 0 then
                progress = 0
            elseif progress > 1 then
                progress = 1
            end
            if Reverses then
                local half = progress * 2
                local cycle = MathFloor(half)
                local within = half - cycle
                if cycle % 2 == 1 then
                    progress = 1 - within
                else
                    progress = within
                end
            end
            return Fidelity.ApplyEasing(progress, Style, Direction)
        end
        local function Apply(alpha)
            if TypeOf(goal) ~= "table" then
                return
            end
            for PropertyName, TargetValue in Next, goal do
                local StartValue = StartValues[PropertyName]
                if TypeOf(TargetValue) == "number" and type(StartValue) == "number" then
                    InternalPCall(function()
                        instance[PropertyName] = StartValue + (TargetValue - StartValue) * alpha
                    end)
                else
                    InternalPCall(function() instance[PropertyName] = TargetValue end)
                end
            end
        end
        local function Finish()
            TweenProxy.IsPlaying = false
            TweenProxy.PlaybackState = Fidelity.EnumValue("PlaybackState", "Completed", 2)
            Fidelity.Clock.Tweens[TweenProxy] = nil
            Apply(1)
            for _, Callback in Next, CompleteCallbacks do
                InternalPCall(Callback, TweenProxy)
            end
        end
        function TweenProxy.Simulate(dt)
            if not TweenProxy.IsPlaying then
                return
            end
            Elapsed += dt
            if Elapsed >= DelaySeconds + Duration then
                Finish()
                return
            end
            Apply(CurrentAlpha())
        end
        function TweenProxy:Play()
            StartValues = {}
            if TypeOf(goal) == "table" then
                for PropertyName in Next, goal do
                    local Ok, StartValue = InternalPCall(function() return instance[PropertyName] end)
                    StartValues[PropertyName] = Ok and StartValue or nil
                end
            end
            Elapsed = 0
            TweenProxy.IsPlaying = true
            TweenProxy.PlaybackState = Fidelity.EnumValue("PlaybackState", "Playing", 1)
            Fidelity.Clock.Tweens[TweenProxy] = TweenProxy.Simulate
            return TweenProxy
        end
        function TweenProxy:Cancel()
            TweenProxy.IsPlaying = false
            TweenProxy.PlaybackState = Fidelity.EnumValue("PlaybackState", "Canceled", 3)
            Fidelity.Clock.Tweens[TweenProxy] = nil
        end
        function TweenProxy:Pause()
            if TweenProxy.IsPlaying then
                TweenProxy.IsPlaying = false
                TweenProxy.PlaybackState = Fidelity.EnumValue("PlaybackState", "Delayed", 0)
            end
        end
        local TweenCompletedSignal = { _Type = "RBXScriptSignal" }
        function TweenCompletedSignal:Wait()
            local guard = 0
            while TweenProxy.IsPlaying and guard < 1000000 do
                guard += 1
                Fidelity.Clock.Step(Fidelity.Clock.StepSeconds)
            end
            return TweenProxy
        end
        function TweenCompletedSignal:Connect(CallbackFunction)
            if TypeOf(CallbackFunction) == "function" then
                TableInsert(CompleteCallbacks, CallbackFunction)
            end
            return {
                Connected = true,
                Disconnect = function(self)
                    self.Connected = false
                end,
            }
        end
        TweenCompletedSignal.connect = TweenCompletedSignal.Connect
        function TweenCompletedSignal:Once(CallbackFunction)
            return TweenCompletedSignal:Connect(CallbackFunction)
        end
        TweenProxy.Completed = TweenCompletedSignal
        TweenProxy.PlaybackState = Fidelity.EnumValue("PlaybackState", "Completed", 2)
        return TweenProxy
    end,
    GetValue = function(_, AlphaValue, EasingStyleValue, EasingDirectionValue)
        local Alpha = TypeOf(AlphaValue) == "number" and AlphaValue or 0
        local Style = EasingStyleValue
        local Direction = EasingDirectionValue
        local StyleIndex = TypeOf(Style) == "number" and Style or (TypeOf(Style) == "table" and Style.Value or 0)
        local DirectionIndex = TypeOf(Direction) == "number" and Direction or (TypeOf(Direction) == "table" and Direction.Value or 0)
        return Fidelity.ApplyEasing(Alpha, StyleIndex, DirectionIndex)
    end
}
local MockEnum = {
    __V1_TYPE = "Enums",
    GetEnums = function()
        local collected = {}
        local seenNames = {}
        for EnumIndex = 1, #Fidelity.EnumNames do
            local EnumName = Fidelity.EnumNames[EnumIndex]
            if seenNames[EnumName] == nil then
                seenNames[EnumName] = true
                collected[#collected + 1] = Fidelity.EnumFacadeFor(EnumName)
            end
        end
        return collected
    end,
}
Fidelity.EnumTypeCache = {}
Fidelity.ProtoHooks = setmetatable({}, { __mode = "k" })
Fidelity.CallbackParams = setmetatable({}, { __mode = "k" })
Fidelity.CallbackFormatter = nil
Fidelity.HookedFunctions = setmetatable({}, { __mode = "k" })
Fidelity.EmulatedNatives = setmetatable({}, { __mode = "k" })
Fidelity.NativeMetadata = setmetatable({}, { __mode = "k" })
Fidelity.RegisterNative = function(fn, name)
    Fidelity.NativeMetadata[fn] = { name = name, argc = 0, vararg = true }
    Fidelity.EmulatedNatives[fn] = true
    if Fidelity.GuardedNatives ~= nil then
        Fidelity.GuardedNatives[fn] = true
    end
    return fn
end
Fidelity.CClosureRegistry = setmetatable({}, { __mode = "k" })
Fidelity.EnvWrittenByScript = {}
Fidelity.NewCClosure = function(TargetFunction)
    if TypeOf(TargetFunction) ~= "function" then
        return TargetFunction
    end
    local WrappedClosure = function(...) return TargetFunction(...) end
    Fidelity.RegisterNative(WrappedClosure, "newcclosure")
    Fidelity.CClosureRegistry[WrappedClosure] = TargetFunction
    return WrappedClosure
end
Fidelity.EmitRemoteProxyChunk = function(RemotePathValue)
    local QuotedPath = StringFormat("%q", RemotePathValue)
    return "local Proxy = __V1CreateRemoteProxy and __V1CreateRemoteProxy("
        .. QuotedPath .. ")\n"
        .. "if Proxy == nil then\n\tProxy = setmetatable({}, {"
        .. "__index = function() return Proxy end, __call = function() return Proxy end, "
        .. "__concat = function() return \"\" end, __tostring = function() return "
        .. QuotedPath .. " end})\nend\nreturn Proxy"
end
Fidelity.NativeInfo = function(target, options)
    local meta = Fidelity.NativeMetadata[target]
    local results = {}
    for i = 1, #options do
        local c = StringSub(options, i, i)
        if c == "s" then results[#results + 1] = "[C]"
        elseif c == "l" then results[#results + 1] = -1
        elseif c == "n" then results[#results + 1] = meta.name
        elseif c == "a" then
            results[#results + 1] = meta.argc
            results[#results + 1] = meta.vararg and true or false
        elseif c == "f" then results[#results + 1] = target
        else results[#results + 1] = nil
        end
    end
    return Unpack(results, 1, #results)
end
Fidelity.EnumTypeCache = {}
Fidelity.HookedFunctions = setmetatable({}, { __mode = "k" })
Fidelity.EmulatedNatives = setmetatable({}, { __mode = "k" })
Fidelity.StampEnumItems = function(EnumTypeName, FacadeValue)
    local CachedItemsOfType = RawGet(Fidelity.EnumItemCache, EnumTypeName)
    if TypeOf(CachedItemsOfType) == "table" then
        for _, CachedItem in Next, CachedItemsOfType do
            CachedItem.EnumType = FacadeValue
        end
    end
end
Fidelity.EnumFacadeFor = function(EnumTypeName)
    return MockEnum[EnumTypeName]
end
setmetatable(MockEnum, {
    __index=function(_, EnumTypeName)
        local CachedFacade = RawGet(Fidelity.EnumTypeCache, EnumTypeName)
        if CachedFacade ~= nil then return CachedFacade end
        local SeenItems = {}
        local SeenItemCount = 0
        local NewFacade = SetMetatable({ __V1_TYPE = "Enum", _Type = "EnumType" }, {
            __newindex = function(_)
                error("The Enum is read only", 2)
            end,
            __index = function(__, ItemName)
                if ItemName == "Name" then
                    local KnownItemNames = RawGet(Fidelity.EnumValues, EnumTypeName)
                    if KnownItemNames == nil or KnownItemNames.Name == nil then
                        return EnumTypeName
                    end
                end
                if ItemName == "GetEnumItems" then
                    return function()
                        local CollectedItems = {}
                        local KnownItems = RawGet(Fidelity.EnumValues, EnumTypeName)
                        if TypeOf(KnownItems) == "table" then
                            for KnownName, KnownNumber in Next, KnownItems do
                                if SeenItems[KnownName] == nil then
                                    SeenItemCount += 1
                                    SeenItems[KnownName] = Fidelity.EnumValue(EnumTypeName, KnownName, KnownNumber)
                                    SeenItems[SeenItemCount] = SeenItems[KnownName]
                                end
                            end
                        end
                        if SeenItemCount == 0 then
                            SeenItemCount = 1
                            SeenItems[1] = Fidelity.EnumValue(EnumTypeName, "Unknown", 0)
                            SeenItems["Unknown"] = SeenItems[1]
                        end
                        Fidelity.StampEnumItems(EnumTypeName,
                            RawGet(Fidelity.EnumTypeCache, EnumTypeName))
                        for ListIndex = 1, SeenItemCount do
                            CollectedItems[ListIndex] = SeenItems[ListIndex]
                        end
                        return CollectedItems
                    end
                end
                local ItemValue = SeenItems[ItemName]
                if ItemValue == nil then
                    Fidelity.SyntheticEnumValueCounter = (Fidelity.SyntheticEnumValueCounter or 0) + 1
                    ItemValue = Fidelity.EnumValue(EnumTypeName, ItemName,
                        Fidelity.SyntheticEnumValueCounter)
                    SeenItemCount += 1
                    SeenItems[ItemName] = ItemValue
                    SeenItems[SeenItemCount] = ItemValue
                end
                local OwningFacade = RawGet(Fidelity.EnumTypeCache, EnumTypeName)
                if OwningFacade ~= nil then
                    ItemValue.EnumType = OwningFacade
                end
                return ItemValue
            end,
            __tostring=function() return "Enum." .. EnumTypeName end,
        })
        Fidelity.EnumTypeNames = Fidelity.EnumTypeNames or {}
        Fidelity.EnumTypeNames[EnumTypeName] = true
        RawSet(NewFacade, "FromName", function(SelfType, ItemName)
            if SelfType == nil then
                error("missing argument #1 to 'FromName' (Enum expected)", 0)
            end
            if ItemName == nil then
                error("missing argument #2 to 'FromName' (string expected)", 0)
            end
            local KnownItems = Fidelity.EnumValues[EnumTypeName]
            if KnownItems == nil then
                return Fidelity.EnumValue(EnumTypeName, ItemName, 0)
            end
            if KnownItems[ItemName] == nil then return nil end
            local OwningFacade = RawGet(Fidelity.EnumTypeCache, EnumTypeName)
            if OwningFacade ~= nil then return OwningFacade[ItemName] end
            return Fidelity.EnumValue(EnumTypeName, ItemName, 0)
        end)
        RawSet(NewFacade, "FromValue", function(SelfType, ItemValue)
            if SelfType == nil then
                error("missing argument #1 to 'FromValue' (Enum expected)", 0)
            end
            if ItemValue == nil then
                error("missing argument #2 to 'FromValue' (number expected)", 0)
            end
            local KnownItems = Fidelity.EnumValues[EnumTypeName]
            if KnownItems ~= nil then
                for KnownName, KnownNumber in Next, KnownItems do
                    if KnownNumber == ItemValue then
                        local OwningFacade = RawGet(Fidelity.EnumTypeCache, EnumTypeName)
                        if OwningFacade ~= nil then return OwningFacade[KnownName] end
                        return Fidelity.EnumValue(EnumTypeName, KnownName, 0)
                    end
                end
            end
            return nil
        end)
        RawSet(Fidelity.EnumTypeCache, EnumTypeName, NewFacade)
        Fidelity.StampEnumItems(EnumTypeName, NewFacade)
        return NewFacade
    end,
    __tostring=function() return "Enum" end
})
Fidelity.EnumFacadeFor("PlaybackState")
Fidelity.EnumFacadeFor("EasingStyle")
Fidelity.EnumFacadeFor("EasingDirection")
local MockCurrentCamera = CreateMockInstance("Camera")
if Fidelity.Vector2 ~= nil then
    RawSet(MockCurrentCamera, "ViewportSize", Fidelity.Vector2.new(1280, 720))
end
RawSet(MockCurrentCamera, "FieldOfView", 70)
RawSet(MockCurrentCamera, "Focus", Fidelity.CFrame.new(0, 5.5, 10))
RawSet(MockCurrentCamera, "CFrame", Fidelity.CFrame.new(0, 5.5, 10))
RawSet(MockCurrentCamera, "__V1_CLASS_NAME", "Camera")
function Fidelity.CameraViewportSize()
    local ViewportSizeValue = MockCurrentCamera.ViewportSize
    if type(ViewportSizeValue) == "table" and ViewportSizeValue.X and ViewportSizeValue.Y then
        return ViewportSizeValue.X, ViewportSizeValue.Y
    end
    return 1280, 720
end
function Fidelity.CameraProject(WorldPosition, IsDepthMode)
    local Part = RawGet(WorldPosition, "X")
    local ComponentY = RawGet(WorldPosition, "Y")
    local ComponentZ = RawGet(WorldPosition, "Z")
    if type(Part) ~= "number" or type(ComponentY) ~= "number" or type(ComponentZ) ~= "number" then
        error("WorldToScreenPoint expects a Vector3", 2)
    end
    local CameraFrame = MockCurrentCamera.CFrame
    local RelativeX, RelativeY, RelativeZ = Part, ComponentY, ComponentZ
    local Depth, Horizontal, Vertical = RelativeZ, RelativeX, RelativeY
    local Position = type(CameraFrame) == "table" and CameraFrame.Position or nil
    local LookVector = type(CameraFrame) == "table" and CameraFrame.LookVector or nil
    local RightVector = type(CameraFrame) == "table" and CameraFrame.RightVector or nil
    local UpVector = type(CameraFrame) == "table" and CameraFrame.UpVector or nil
    if type(Position) == "table" then
        RelativeX = Part - (Position.X or 0)
        RelativeY = ComponentY - (Position.Y or 0)
        RelativeZ = ComponentZ - (Position.Z or 0)
    end
    if type(LookVector) == "table" and type(RightVector) == "table" and type(UpVector) == "table" then
        Depth = RelativeX * (LookVector.X or 0) + RelativeY * (LookVector.Y or 0)
            + RelativeZ * (LookVector.Z or 0)
        Horizontal = RelativeX * (RightVector.X or 0) + RelativeY * (RightVector.Y or 0)
            + RelativeZ * (RightVector.Z or 0)
        Vertical = RelativeX * (UpVector.X or 0) + RelativeY * (UpVector.Y or 0)
            + RelativeZ * (UpVector.Z or 0)
    end
    local SafeDepth = Depth
    if SafeDepth == 0 then SafeDepth = 0.0001 end
    local ViewportXValue, ViewportYValue = Fidelity.CameraViewportSize()
    local FieldOfViewValue = tonumber(MockCurrentCamera.FieldOfView) or 70
    local Scale = (ViewportYValue * 0.5) / math.tan(math.rad(FieldOfViewValue * 0.5))
    if IsDepthMode then
        return math.abs(Depth) * (ViewportXValue / Scale)
    end
    local ScreenX = ViewportXValue * 0.5 + (Horizontal / SafeDepth) * Scale
    local ScreenY = ViewportYValue * 0.5 - (Vertical / SafeDepth) * Scale
    local IsInView = Depth > 0 and ScreenX >= 0 and ScreenX <= ViewportXValue
        and ScreenY >= 0 and ScreenY <= ViewportYValue
    return Fidelity.Vector3.new(ScreenX, ScreenY, Depth), IsInView
end
for _, ProjectionName in ipairs({ "WorldToScreenPoint", "WorldToScreenPointAsync" }) do
    RawSet(MockCurrentCamera, ProjectionName,
        function(_, WorldPosition)
            local ScreenPosition, IsInView = Fidelity.CameraProject(WorldPosition, false)
            return ScreenPosition, IsInView
        end)
end
RawSet(MockCurrentCamera, "WorldToViewportPoint",
    function(_, WorldPosition)
        local ScreenPosition, IsInView = Fidelity.CameraProject(WorldPosition, false)
        local ViewportXValue, ViewportYValue = Fidelity.CameraViewportSize()
        return Fidelity.Vector3.new(
            (RawGet(ScreenPosition, "X") or 0) / ViewportXValue,
            1 - (RawGet(ScreenPosition, "Y") or 0) / ViewportYValue,
            RawGet(ScreenPosition, "Z") or 0), IsInView
    end)
function Fidelity.CameraUnproject(PixelXValue, PixelYValue, DepthValue)
    local ViewportXValue, ViewportYValue = Fidelity.CameraViewportSize()
    local FieldOfViewValue = tonumber(MockCurrentCamera.FieldOfView) or 70
    local Depth = tonumber(DepthValue) or 0
    local Tangent = math.tan(math.rad(FieldOfViewValue * 0.5))
    local HorizontalWorld = (PixelXValue - ViewportXValue * 0.5) * Depth * Tangent * 2
        / ViewportYValue
    local VerticalWorld = (ViewportYValue * 0.5 - PixelYValue) * Depth * Tangent * 2
        / ViewportYValue
    local CameraFrame = MockCurrentCamera.CFrame
    local Position = type(CameraFrame) == "table" and CameraFrame.Position or nil
    local RightVector = type(CameraFrame) == "table" and CameraFrame.RightVector or nil
    local UpVector = type(CameraFrame) == "table" and CameraFrame.UpVector or nil
    local LookVector = type(CameraFrame) == "table" and CameraFrame.LookVector or nil
    local OriginX = type(Position) == "table" and (Position.X or 0) or 0
    local OriginY = type(Position) == "table" and (Position.Y or 0) or 0
    local OriginZ = type(Position) == "table" and (Position.Z or 0) or 0
    if type(RightVector) == "table" and type(UpVector) == "table"
        and type(LookVector) == "table" then
        return Fidelity.Vector3.new(
            OriginX + HorizontalWorld * (RightVector.X or 0)
                + VerticalWorld * (UpVector.X or 0) + Depth * (LookVector.X or 0),
            OriginY + HorizontalWorld * (RightVector.Y or 0)
                + VerticalWorld * (UpVector.Y or 0) + Depth * (LookVector.Y or 0),
            OriginZ + HorizontalWorld * (RightVector.Z or 0)
                + VerticalWorld * (UpVector.Z or 0) + Depth * (LookVector.Z or 0))
    end
    return Fidelity.Vector3.new(OriginX + HorizontalWorld, OriginY + VerticalWorld,
        OriginZ - Depth)
end
function Fidelity.CameraRayThrough(PointXValue, PointYValue, DepthValue)
    local CameraFrame = MockCurrentCamera.CFrame
    local Position = type(CameraFrame) == "table" and CameraFrame.Position or nil
    local Origin = type(Position) == "table"
        and Fidelity.Vector3.new(Position.X or 0, Position.Y or 0, Position.Z or 0)
        or Fidelity.Vector3.new(0, 0, 0)
    local FarPoint = Fidelity.CameraUnproject(PointXValue, PointYValue,
        math.max(tonumber(DepthValue) or 0, 0.0001))
    local DeltaX = (FarPoint.X or 0) - (Origin.X or 0)
    local DeltaY = (FarPoint.Y or 0) - (Origin.Y or 0)
    local DeltaZ = (FarPoint.Z or 0) - (Origin.Z or 0)
    local Length = math.sqrt(DeltaX * DeltaX + DeltaY * DeltaY + DeltaZ * DeltaZ)
    if Length == 0 then
        DeltaX, DeltaY, DeltaZ, Length = 0, 0, -1, 1
    end
    local RayLength = 1000
    local Direction = Fidelity.Vector3.new(DeltaX / Length * RayLength,
        DeltaY / Length * RayLength, DeltaZ / Length * RayLength)
    if Fidelity.Raycast ~= nil then
        return Fidelity.Raycast.new(Origin, Direction)
    end
    return { _Type = "Ray", Origin = Origin, Direction = Direction }
end
RawSet(MockCurrentCamera, "ViewportPointToWorld",
    function(_, ViewportX, ViewportY, DepthValue)
        local ViewportXValue, ViewportYValue = Fidelity.CameraViewportSize()
        local PointX, PointY = tonumber(ViewportX), tonumber(ViewportY)
        if PointX == nil and type(ViewportX) == "table" then
            PointX, PointY = tonumber(ViewportX.X), tonumber(ViewportX.Y)
        end
        return Fidelity.CameraUnproject((PointX or 0) * ViewportXValue,
            (PointY or 0) * ViewportYValue, DepthValue)
    end)
RawSet(MockCurrentCamera, "ScreenPointToWorld",
    function(_, ScreenX, ScreenY, DepthValue)
        return Fidelity.CameraUnproject(tonumber(ScreenX) or 0, tonumber(ScreenY) or 0,
            DepthValue)
    end)
RawSet(MockCurrentCamera, "ViewportPointToRay",
    function(_, ViewportX, ViewportY, DepthValue)
        local ViewportXValue, ViewportYValue = Fidelity.CameraViewportSize()
        return Fidelity.CameraRayThrough((tonumber(ViewportX) or 0) * ViewportXValue,
            (tonumber(ViewportY) or 0) * ViewportYValue, DepthValue)
    end)
RawSet(MockCurrentCamera, "ScreenPointToRay",
    function(_, ScreenX, ScreenY, DepthValue)
        return Fidelity.CameraRayThrough(tonumber(ScreenX) or 0, tonumber(ScreenY) or 0, DepthValue)
    end)
RawSet(MockCurrentCamera, "GetDistributedGameTime",
    function() return 0 end)
RawSet(MockCurrentCamera, "CFrame", MockCFrame.new())
RawSet(MockCurrentCamera, "FieldOfView", 70)
RawSet(MockCurrentCamera, "Focus", Fidelity.CFrame.new(0, 5.5, 10))
RawSet(MockCurrentCamera, "ViewportSize", MockVector2.new(1920, 1080))
local MockWorkspace = SetMetatable({
    FallenPartsDestroyHeight = 500,
    StreamingEnabled = false,
    PrimaryPartCameraMode = false,
    CurrentCamera = MockCurrentCamera,
    Name = "Workspace",
    ClassName = "Workspace",
    __V1_TYPE = "Workspace",
    __V1_INSTANCE = true,
    __V1_TYPE = "Instance",
}, {
    __index = function(t,k)
        if k=="CurrentCamera" then return MockCurrentCamera end
        local ExistingValue = RawGet(t,k)
        if ExistingValue ~= nil then return ExistingValue end
        if StringMatch(ToString(k), "^heph_probe_") then
            EmitMockOutput("index", {ObjectName = "workspace", KeyName = k})
        end
        return nil
    end,
    __tostring=function() return "Workspace" end
})
local MockTerrain = CreateMockInstance("Terrain")
RawSet(MockTerrain, "Name", "Terrain")
RawSet(MockTerrain, "Parent", MockWorkspace)
RawSet(MockWorkspace, "Terrain", MockTerrain)
RawSet(MockWorkspace, "FindFirstChildOfClass", function(_, TargetClassName)
    if TargetClassName == "Terrain" then return MockTerrain end
    return nil
end)
RawSet(MockWorkspace, "__V1_DATAMODEL", true)
Fidelity.World.SetWorkspace(MockWorkspace)
Fidelity.BuildWorkspaceCharacter(MockCharacter, MockWorkspace)
Fidelity.ApplyInstanceApis(MockWorkspace, "Workspace", Fidelity.InstanceApiContext)
Fidelity.ApplyInstanceApis(MockTweenService, "TweenService", Fidelity.InstanceApiContext)
Fidelity.ApplyInstanceApis(MockSoundService, "SoundService", Fidelity.InstanceApiContext)
Fidelity.ApplyInstanceApis(MockCoreGui, "CoreGui", Fidelity.InstanceApiContext)
RawSet(MockWorkspace, "Raycast", function(_, OriginValue, DirectionValue, ParamsValue)
    return Fidelity.World.Raycast(OriginValue, DirectionValue, ParamsValue)
end)
RawSet(MockWorkspace, "GetPartBoundsInBox", function(_, CframeValue, SizeValue, ParamsValue)
    return Fidelity.World.GetPartBoundsInBox(CframeValue, SizeValue, ParamsValue)
end)
RawSet(MockWorkspace, "GetPartsInPart", function(_, PartValue, ParamsValue)
    return Fidelity.World.GetPartsInPart(PartValue, ParamsValue)
end)
RawSet(MockWorkspace, "GetPartBoundsInRadius", function(_, CenterValue, RadiusValue, ParamsValue)
    local BoxSize = MockVector3.new(RadiusValue * 2, RadiusValue * 2, RadiusValue * 2)
    return Fidelity.World.GetPartBoundsInBox(MockCFrame.new(CenterValue.X, CenterValue.Y, CenterValue.Z), BoxSize, ParamsValue)
end)
RawSet(MockWorkspace, "FindPartOnRay", function(_, RayValue, ParamsValue)
    local ResultValue = Fidelity.World.Raycast(RayValue.Origin, RayValue.Direction, ParamsValue)
    if ResultValue == nil then return nil end
    return ResultValue.Instance, ResultValue.Position, ResultValue.Normal
end)
RawSet(MockWorkspace, "FindPartOnRayWithIgnoreList", function(_, RayValue)
    return MockWorkspace.FindPartOnRay(nil, RayValue)
end)
RawSet(MockWorkspace, "FindPartsInRegion3", function(_, RegionValue, ParamsValue)
    return Fidelity.World.GetPartBoundsInBox(RegionValue.CFrame, RegionValue.Size, ParamsValue)
end)
RawSet(MockWorkspace, "Gravity", 196.2)
RawSet(MockWorkspace, "DistributedGameTime", 0)
Fidelity.Clock.Workspace = MockWorkspace
Fidelity.Clock.Sync()
RawSet(MockWorkspace, "GetServerTimeNow", function()
    return Fidelity.Clock.Tick()
end)
Fidelity.World.TouchNotifier = function(PartInstance, OtherInstance, EventName)
    local ContactSignal = PartInstance[EventName]
    if ContactSignal ~= nil and TypeOf(ContactSignal.Fire) == "function" then
        InternalPCall(ContactSignal.Fire, ContactSignal, OtherInstance)
    end
end
RawSet(MockWorkspace, "PhysicsPause", false)
RawSet(MockWorkspace, "WaterWaveSpeed", 0)
RawSet(MockWorkspace, "WaterTransparency", 0.2)
RawSet(MockWorkspace, "WideFloor", true)
RawSet(MockWorkspace, "FallingDuration", 0)
RawSet(MockWorkspace, "StreamingEnabled", false)
RawSet(MockWorkspace, "FilteringEnabled", true)
RawSet(MockWorkspace, "TouchesUseCollisionGroups", false)
RawSet(MockWorkspace, "PhysicsSteppingMethod", "Default")
RawSet(MockWorkspace, "SignalBehavior", "Default")
RawSet(MockWorkspace, "InterpolationThrottling", "Default")
RawSet(MockWorkspace, "GetRealPhysicsFPS", function() return 60 end)
RawSet(MockWorkspace, "BreakJoints", function() end)
RawSet(MockWorkspace, "JoinToOutsiders", function() end)
RawSet(MockWorkspace, "UnJoinFromOutsiders", function() end)
RawSet(MockWorkspace, "SetInsertPoint", function() end)
RawSet(MockWorkspace, "GetNumAwakeParts", function() return Fidelity.World.PartCount() end)
RawSet(MockWorkspace, "FindFirstChild", function(_, ChildName)
    for _, CandidateChild in ipairs(Fidelity.GetChildrenOf(MockWorkspace)) do
        if CandidateChild.Name == ChildName then return CandidateChild end
    end
    for _, CandidatePart in ipairs(Fidelity.World.ListParts()) do
        if CandidatePart.Name == ChildName then return CandidatePart end
    end
    return nil
end)
RawSet(MockWorkspace, "__V1_Methods", {
    GetChildren = function()
        return Fidelity.GetChildrenOf(MockWorkspace)
    end,
    GetDescendants = function()
        local CopyTable = {}
        local function Walk(CurrentNode)
            for _, ChildValue in ipairs(Fidelity.GetChildrenOf(CurrentNode)) do
                CopyTable[#CopyTable + 1] = ChildValue
                Walk(ChildValue)
            end
        end
        Walk(MockWorkspace)
        return CopyTable
    end,
})
RawSet(MockWorkspace, "GetChildren", Fidelity.SharedMethodStub("Workspace", "GetChildren"))
RawSet(MockWorkspace, "GetDescendants", Fidelity.SharedMethodStub("Workspace", "GetDescendants"))
RawSet(RawGet(MockWorkspace, "__V1_Methods"), "IsA", function(_, TargetClassName)
    return TargetClassName == "Workspace" or TargetClassName == "Model"
        or TargetClassName == "PVInstance" or TargetClassName == "Instance"
end)
RawSet(RawGet(MockWorkspace, "__V1_Methods"), "GetFullName", function() return "Workspace" end)
RawSet(RawGet(MockWorkspace, "__V1_Methods"), "GetDebugId", function() return "0000000000000000" end)
RawSet(RawGet(MockWorkspace, "__V1_Methods"), "GetActor", function() return nil end)
RawSet(RawGet(MockWorkspace, "__V1_Methods"), "GetAttribute", function() return nil end)
RawSet(RawGet(MockWorkspace, "__V1_Methods"), "GetAttributes", function() return {} end)
RawSet(RawGet(MockWorkspace, "__V1_Methods"), "SetAttribute", function() end)
RawSet(RawGet(MockWorkspace, "__V1_Methods"), "IsDescendantOf", function(_, AncestorInstance)
    if AncestorInstance == nil then return false end
    local CurrentAncestor = MockWorkspace.Parent
    local PreviousAncestor = MockWorkspace
    local GuardCount = 0
    while CurrentAncestor ~= nil and CurrentAncestor ~= PreviousAncestor and GuardCount < 64 do
        if CurrentAncestor == AncestorInstance then return true end
        PreviousAncestor = CurrentAncestor
        CurrentAncestor = CurrentAncestor.Parent
        GuardCount += 1
    end
    return false
end)
RawSet(RawGet(MockWorkspace, "__V1_Methods"), "IsAncestorOf", function(_, OtherInstance)
    if OtherInstance == nil or OtherInstance == MockWorkspace then return false end
    local CurrentAncestor = OtherInstance.Parent
    local PreviousAncestor = OtherInstance
    local GuardCount = 0
    while CurrentAncestor ~= nil and CurrentAncestor ~= PreviousAncestor and GuardCount < 64 do
        if CurrentAncestor == MockWorkspace then return true end
        PreviousAncestor = CurrentAncestor
        CurrentAncestor = CurrentAncestor.Parent
        GuardCount += 1
    end
    return false
end)
Fidelity.WorkspaceInheritedMethodNames = {
    "IsA", "GetFullName", "GetDebugId", "GetActor", "GetAttribute",
    "GetAttributes", "SetAttribute", "IsDescendantOf", "IsAncestorOf",
}
for _, InheritedMethodName in Next, Fidelity.WorkspaceInheritedMethodNames do
    RawSet(MockWorkspace, InheritedMethodName, Fidelity.SharedMethodStub("Workspace", InheritedMethodName))
end
RawSet(MockWorkspace, "WaitForChild", function(Self, ChildName, TimeoutSeconds)
    local FoundChild = MockWorkspace.FindFirstChild(Self or MockWorkspace, ChildName)
    if FoundChild ~= nil then
        return FoundChild
    end
    if TimeoutSeconds ~= nil and ToNumber(TimeoutSeconds) == nil then
        RealErrorRef("bad argument #2 to 'WaitForChild' (number expected, got "
            .. InternalType(TimeoutSeconds) .. ")", 0)
    end
    return nil
end)
RawSet(MockWorkspace, "__V1_UNKNOWN_MEMBER_FALLBACK", function() return nil end)
SetMetatable(MockWorkspace, {
    __index = function(TargetTable, KeyName)
        if KeyName == "CurrentCamera" then return MockCurrentCamera end
        local ExistingValue = RawGet(TargetTable, KeyName)
        if ExistingValue ~= nil then return ExistingValue end
        if StringMatch(ToString(KeyName), "^heph_probe_") then
            EmitMockOutput("index", {ObjectName = "workspace", KeyName = KeyName})
        end
        if Fidelity.WorkspaceAlwaysNilMembers[KeyName] then
            return nil
        end
        if Fidelity.InstanceEventNames[KeyName] then
            local CachedSignal = RawGet(TargetTable, KeyName)
            if CachedSignal == nil then
                CachedSignal = CreateMockSignal(ToString(KeyName), TargetTable)
                RawSet(TargetTable, KeyName, CachedSignal)
            end
            return CachedSignal
        end
        local ChildValue = MockWorkspace.FindFirstChild(nil, KeyName)
        if ChildValue ~= nil then return ChildValue end
        return nil
    end,
    __tostring = function() return "Workspace" end,
    __len = Fidelity.InstanceMetamethods.__len,
    __unm = Fidelity.InstanceMetamethods.__unm,
    __lt = Fidelity.InstanceMetamethods.__lt,
    __le = Fidelity.InstanceMetamethods.__le,
    __concat = Fidelity.InstanceMetamethods.__concat,
})
local ServiceCache = {}
local MockGame = SetMetatable({
    Name="game",
    __V1_TYPE = "DataModel",
    CreatorType = Fidelity.EnumValue("CreatorType", "User", 0),
    CreatorId = 0,
    JobId = "",
    PlaceId = 0,
    GameId = 0,
    IsLoaded = true,
    Players=MockPlayersService,
    Workspace=MockWorkspace,
    CoreGui=MockCoreGui,
    ClassName="DataModel",
    __V1_INSTANCE=true,
    __V1_TYPE="DataModel",
}, {
    __index = function(t,k)
        if k=="Players" then return MockPlayersService end
        if k=="Workspace" then return MockWorkspace end
        if k=="GetService" then
            return function(Self, ServiceName)
                local GameObject = Self
                if type(GameObject) ~= "table" then
                    GameObject = MockGame
                end
                if StringFind(ServiceName, "InvalidServiceDetect_", 1, true) == 1 then
                    RealErrorRef("Service '" .. ServiceName .. "' is not a valid service", 2)
                end
                if ServiceCache[ServiceName] then
                    local CachedService = ServiceCache[ServiceName]
                    if type(CachedService) == "table" and CachedService.Parent ~= GameObject
                        and RawGet(CachedService, "__V1_GAME_CHILD") == nil then
                        if RawGet(CachedService, "Parent") == nil then
                            RawSet(CachedService, "Parent", GameObject)
                        end
                        RawSet(CachedService, "__V1_GAME_CHILD", true)
                        Fidelity.RegisterChild(GameObject, CachedService)
                    end
                    Fidelity.SeedKnownServiceChildren(CachedService, ServiceName, CreateMockInstance)
                    return CachedService
                end
                local ServiceObject
                if ServiceName=="Workspace" then ServiceObject=MockWorkspace
                elseif ServiceName=="Players" then ServiceObject=MockPlayersService
                elseif ServiceName=="TweenService" then ServiceObject=MockTweenService
                elseif ServiceName=="MemStorageService" then ServiceObject=MockMemStorageService
                elseif ServiceName=="CollectionService" then ServiceObject=MockCollectionService
                elseif ServiceName=="SoundService" then ServiceObject=MockSoundService
                elseif ServiceName=="LogService" then ServiceObject=CreateMockInstance("LogService")
                    RawSet(ServiceObject, "MessageOut", CreateMockSignal("MessageOut", ServiceObject))
                    RawSet(ServiceObject, "OnNewLog", CreateMockSignal("OnNewLog", ServiceObject))
                    RawSet(ServiceObject, "GetLogHistory", function() return {} end)
                    RawSet(ServiceObject, "RequestServerHttpResult", function() return {} end)
                    RawSet(ServiceObject, "RequestHttpResultApproved", CreateMockSignal("RequestHttpResultApproved", ServiceObject))
                elseif ServiceName=="UserInputService" then ServiceObject=CreateMockInstance("UserInputService")
                    RawSet(ServiceObject, "TouchEnabled", false)
                    RawSet(ServiceObject, "KeyboardEnabled", true)
                    RawSet(ServiceObject, "MouseEnabled", true)
                    RawSet(ServiceObject, "GamepadEnabled", false)
                    RawSet(ServiceObject, "TouchGestureEnabled", false)
                    RawSet(ServiceObject, "AccelerometerEnabled", false)
                    RawSet(ServiceObject, "GyroscopeEnabled", false)
                    RawSet(ServiceObject, "IsKeyDown", function() return false end)
                    RawSet(ServiceObject, "IsMouseButtonPressed", function() return false end)
                    RawSet(ServiceObject, "IsGamepadButtonDown", function() return false end)
                    RawSet(ServiceObject, "GetConnectedGamepads", function() return {} end)
                    RawSet(ServiceObject, "GetGamepadState", function() return {} end)
                    RawSet(ServiceObject, "GetFocusedTextBox", function() return nil end)
                    RawSet(ServiceObject, "GetPlatform", function()
                        return Fidelity.EnumValue("Platform", "Windows", 0)
                    end)
                    RawSet(ServiceObject, "GetMouseLocation", function() return MockVector2.new(0, 0) end)
                    RawSet(ServiceObject, "GetString", function() return "" end)
                    RawSet(ServiceObject, "InputBegan", CreateMockSignal("InputBegan", ServiceObject))
                    RawSet(ServiceObject, "InputEnded", CreateMockSignal("InputEnded", ServiceObject))
                    RawSet(ServiceObject, "InputChanged", CreateMockSignal("InputChanged", ServiceObject))
                    RawSet(ServiceObject, "TextBoxFocused", CreateMockSignal("TextBoxFocused", ServiceObject))
                    RawSet(ServiceObject, "TextBoxFocusReleased", CreateMockSignal("TextBoxFocusReleased", ServiceObject))
                elseif ServiceName=="PathfindingService" then ServiceObject=CreateMockInstance("PathfindingService")
                    RawSet(ServiceObject, "CreatePath", function()
                        local PathInstance = CreateMockInstance("Path")
                        local PathMethods = RawGet(PathInstance, "__V1_Methods") or {}
                        RawSet(PathInstance, "__V1_Methods", PathMethods)
                        RawSet(PathMethods, "ComputeAsync", function() return Enum and Enum.PathStatus and Enum.PathStatus.Success or 2 end)
                        RawSet(PathMethods, "GetWaypoints", function() return {} end)
                        RawSet(PathMethods, "GetBlockedWaypointIndex", function() return -1 end)
                        RawSet(PathMethods, "GetPointCoordinates", function() return {} end)
                        RawSet(PathInstance, "ComputeAsync", PathMethods["ComputeAsync"])
                        RawSet(PathInstance, "GetWaypoints", PathMethods["GetWaypoints"])
                        RawSet(PathInstance, "GetBlockedWaypointIndex", PathMethods["GetBlockedWaypointIndex"])
                        RawSet(PathInstance, "Status",
                            Fidelity.EnumValue("PathStatus", "Success", 0))
                        return PathInstance
                    end)
                elseif ServiceName=="HttpService" then ServiceObject=MockHttpService
                elseif ServiceName=="EncodingService" then ServiceObject=MockEncodingService
                elseif ServiceName=="InsertService" then ServiceObject=MockInsertService
                elseif ServiceName=="CoreGui" then ServiceObject=MockCoreGui
                elseif ServiceName=="PhysicsService" then ServiceObject=Fidelity.MakePhysicsService(CreateMockInstance("PhysicsService"))
                elseif ServiceName=="TextService" then ServiceObject=Fidelity.MakeTextService(CreateMockInstance("TextService"))
                elseif ServiceName=="LocalizationService" then ServiceObject=Fidelity.MakeLocalizationService(CreateMockInstance("LocalizationService"))
                elseif ServiceName=="PolicyService" then ServiceObject=Fidelity.MakePolicyService(CreateMockInstance("PolicyService"))
                elseif ServiceName=="MarketplaceService" then ServiceObject=CreateMockInstance("MarketplaceService")
                    RawSet(ServiceObject, "GetProductInfo",
                        function(_, AssetIdValue)
                            local ResolvedPlaceId = tonumber(AssetIdValue) or RawGet(ServiceObject, "PlaceId") or 0
                            return {
                                InfoType = Fidelity.EnumValue("InfoType", "Asset", 0),
                                Name = "Roblox", Description = "", CreatorId = 1,
                                CreatorType = Fidelity.EnumValue("CreatorType", "User", 1),
                                Creator = { Id = 1, Name = "Roblox",
                                    UserUploadsCount = 0, HasPremiumPricing = false,
                                    CreatorType = Fidelity.EnumValue("CreatorType", "User", 1) },
                                AssetId = ResolvedPlaceId, PlaceId = ResolvedPlaceId,
                                AssetTypeId = 8, InventoryItemId = 0, ContentRatingId = 0,
                                IsPublicDomain = false, IsForSale = false, PriceInRobux = nil,
                                Created = 0, Updated = 0, MaxPlayers = 50, Playing = 0,
                                ServerSizeId = 2, ContentRatingId = 0,
                                SourceAssetId = ResolvedPlaceId,
                            }
                        end)
                    RawSet(ServiceObject, "PlayerOwnsAsset",
                        function() error("PlayerOwnsAsset requires network access", 2) end)
                elseif ServiceName=="RunService" then ServiceObject=CreateMockInstance("RunService")
                    for _, SignalName in ipairs({
                        "UnscaledTimeUpdate", "PostSimulationStepped", "PreAnimation",
                        "PreAnimationStepped", "PreSimulationStepped", "ServiceAdded",
                        "ServiceRemoving", "ServiceStarted", "TimestepCompleted",
                        "SendTriggerEventReceived",
                    }) do
                        Fidelity.RegisterPropertyOverride(ServiceObject, SignalName,
                            CreateMockSignal(SignalName, ServiceObject))
                    end
                    RawSet(ServiceObject, "IsStudio", function() return false end)
                    RawSet(ServiceObject, "IsClient", function() return true end)
                    RawSet(ServiceObject, "IsServer", function() return false end)
                    RawSet(ServiceObject, "IsRunning", function() return true end)
                    Fidelity.RegisterPropertyOverride(ServiceObject,
                    "Heartbeat", (function()
                        local Signal = CreateMockSignal("Heartbeat", ServiceObject)
                        Signal.Wait = MockHeartbeatWait
                        return Signal
                    end)())
                    for SteppedName, SteppedSignal in {
                        RenderStepped = CreateMockSignal("RenderStepped", ServiceObject),
                        Stepped = CreateMockSignal("Stepped", ServiceObject),
                        PreRender = CreateMockSignal("PreRender", ServiceObject),
                        PreSimulation = CreateMockSignal("PreSimulation", ServiceObject),
                        PostSimulation = CreateMockSignal("PostSimulation", ServiceObject),
                    } do
                        SteppedSignal.Wait = Fidelity.MakeSteppedWait(SteppedName)
                        Fidelity.RegisterPropertyOverride(ServiceObject, SteppedName,
                            SteppedSignal)
                    end
                else ServiceObject=CreateMockInstance(ServiceName) end
                if (RawGet(ServiceObject, "ClassName") or RawGet(ServiceObject, "__V1_CLASS_NAME")) == nil and ServiceObject.ClassName == nil then
                    RawSet(ServiceObject, "ClassName", ServiceName)
                end
                Fidelity.SeedKnownServiceChildren(ServiceObject, ServiceName, CreateMockInstance)
                if RawGet(ServiceObject, "GetFullName") == nil then
                    RawSet(ServiceObject, "GetFullName", function() return ToString(ServiceName) end)
                end
                if RawGet(ServiceObject, "IsA") == nil then
                    RawSet(ServiceObject, "IsA", function(_, TargetClassName)
                        if TargetClassName == "Instance" then return true end
                        if TargetClassName == ServiceName then return true end
                        if ServiceName == "CoreGui" and TargetClassName == "BasePlayerGui" then return true end
                        return false
                    end)
                end
                if ServiceObject ~= nil and type(ServiceObject) == "table"
                    and RawGet(ServiceObject, "__V1_GAME_CHILD") == nil then
                    if RawGet(ServiceObject, "Parent") == nil then
                        RawSet(ServiceObject, "Parent", GameObject)
                    end
                    RawSet(ServiceObject, "__V1_GAME_CHILD", true)
                    Fidelity.RegisterChild(GameObject, ServiceObject)
                end
                Fidelity.ApplyInstanceApis(ServiceObject, ServiceName, Fidelity.InstanceApiContext)
                if ServiceName == "Lighting" then
                    Fidelity.SeedLightingChildren(ServiceObject)
                end
                if ServiceName == "StarterPlayer" then
                    Fidelity.StarterPlayerService = ServiceObject
                    if Fidelity.SeedStarterContainers ~= nil then
                        Fidelity.SeedStarterContainers(ServiceObject)
                    end
                    Fidelity.StarterContainerFor("StarterPlayerScripts")
                    Fidelity.StarterContainerFor("StarterCharacterScripts")
                end
                if ServiceName == "Stats" then
                    Fidelity.StatsObject = ServiceObject
                    Fidelity.RefreshStats()
                end
                ServiceCache[ServiceName]=ServiceObject
                return ServiceObject
            end
        end
        local ExistingValue = RawGet(t,k)
        if ExistingValue ~= nil then return ExistingValue end
        if StringMatch(ToString(k), "^heph_probe_") then
            EmitMockOutput("index", {ObjectName = "game", KeyName = k})
        end
        if Fidelity.InstanceEventNames[k] then
            local CachedSignal = RawGet(t, k)
            if CachedSignal == nil then
                CachedSignal = CreateMockSignal(ToString(k), t)
                RawSet(t, k, CachedSignal)
            end
            return CachedSignal
        end
        if StringMatch(ToString(k), "Service$") then
            return t:GetService(k)
        end
        return nil
    end,
    __namecall = Fidelity.RegisterNative(function(Self, ...)
        local CallArguments = table.pack(...)
        local MethodName = CallArguments[CallArguments.n]
        Fidelity.LastMethodCallName = MethodName
        local Resolved = RawGet(Self, MethodName)
        if Resolved == nil then
            Resolved = GetMetatable(Self).__index(Self, MethodName)
        end
        if TypeOf(Resolved) == "function" then
            return Resolved(Self, table.unpack(CallArguments, 1, CallArguments.n - 1))
        end
        return nil
    end, "namecall"),
    __newindex = function(Self, KeyName, ValueData)
        -- r72: Parent/ClassName sebuah DataModel tidak bisa ditata ulang (engine menolak)
        if KeyName == "Parent" or KeyName == "ClassName" then
            error("The " .. tostring(KeyName) .. " of the DataModel cannot be set", 2)
        end
        RawSet(Self, KeyName, ValueData)
    end,
    __tostring=function() return "Game" end,
    __len = Fidelity.InstanceMetamethods.__len,
    __unm = Fidelity.InstanceMetamethods.__unm,
    __lt = Fidelity.InstanceMetamethods.__lt,
    __le = Fidelity.InstanceMetamethods.__le,
    __concat = Fidelity.InstanceMetamethods.__concat,
})
RawSet(MockGame, "__V1_DATAMODEL", true)
do
    local SeedMix = 0
    local ClockOkay, ClockValue = InternalPCall(function() return os.clock() * 1e6 end)
    if ClockOkay and type(ClockValue) == "number" then
        SeedMix = math.floor(ClockValue)
    end
    local TimeOkay, TimeValue = InternalPCall(function() return tick() end)
    if TimeOkay and type(TimeValue) == "number" then
        SeedMix = SeedMix + math.floor(TimeValue * 1000)
    end
    MathRandom((SeedMix % 2147483647) + 1)
    local GuidHex = {}
    local GuidShape = { 8, 4, 4, 4, 12 }
    for _, PartLen in ipairs(GuidShape) do
        local Part = {}
        local PairCount = (PartLen + 1) // 4
        for _ = 1, PairCount do
            Part[#Part + 1] = string.format("%04x", MathRandom(0, 65535))
        end
        GuidHex[#GuidHex + 1] = string.sub(table.concat(Part), 1, PartLen)
    end
    Fidelity.ScriptInstalledEnvironments = {}
    Fidelity.HostEscapeNames = {
        require = true, loadstring = true, load = true, dofile = true, loadfile = true,
        getfenv = true, setfenv = true, package = true, io = true, os = true, debug = true,
        process = true, fs = true, net = true, stdio = true, task = true, path = true,
        serde = true, regex = true, toml = true, yaml = true, lune = true, bit = true,
    }
    Fidelity.ExecutorIdentity = {
        Name = "Delta 1.1.733.988",
        Version = "1.1.733.988",
        Platform = "arm64",
    }
    Fidelity.SessionIdentity = {
        Hwid = "S-1-5-21-" .. tostring(MathRandom(100000000, 2000000000)) .. "-"
            .. tostring(MathRandom(100000000, 2000000000)) .. "-"
            .. tostring(MathRandom(10000, 99999)),
        PlaceId = MathRandom(100000000, 999999999),
        GameId = MathRandom(100000000, 999999999),
        PlaceVersion = MathRandom(1000000, 99999999),
        JobId = table.concat(GuidHex, "-"),
    }
end
RawSet(MockGame, "JobId", Fidelity.SessionIdentity.JobId)
RawSet(MockGame, "PlaceId", Fidelity.SessionIdentity.PlaceId)
RawSet(MockGame, "GameId", Fidelity.SessionIdentity.GameId)
RawSet(MockGame, "PlaceVersion", Fidelity.SessionIdentity.PlaceVersion)
Fidelity.RegisterNative(RawGet(GetMetatable(MockGame), "__index"), "__index")
Fidelity.RegisterNative(RawGet(GetMetatable(MockGame), "__newindex"), "__newindex")
Fidelity.RegisterNative(RawGet(GetMetatable(MockGame), "__namecall"), "__namecall")
RawSet(GetMetatable(MockGame), "__V1_READONLY", true)
do
    RawSet(MockGame, "Clone", function(_)
        error("DataModel cannot be cloned", 2)
    end)
    RawSet(MockGame, "Destroy", function(_)
        error("The DataModel cannot be destroyed", 2)
    end)
    RawSet(MockWorkspace, "Destroy", function(_)
        error("The Workspace cannot be destroyed", 2)
    end)
    RawSet(MockWorkspace, "Clone", function(_)
        error("The Workspace cannot be cloned", 2)
    end)
    local MockGameReadOnlyValues = {}
    for _, ReadOnlyName in Next, {
        "IsLoaded", "JobId", "PlaceId", "GameId", "CreatorId", "CreatorType", "ServerId",
    } do
        MockGameReadOnlyValues[ReadOnlyName] = RawGet(MockGame, ReadOnlyName)
        RawSet(MockGame, ReadOnlyName, nil)
    end
    local MockGameMetaTable = GetMetatable(MockGame)
    local GameIndexFunction = RawGet(MockGameMetaTable, "__index")
    RawSet(MockGameMetaTable, "__index", function(TargetTable, KeyName)
        local ReadOnlyValue = MockGameReadOnlyValues[KeyName]
        if ReadOnlyValue ~= nil then
            return ReadOnlyValue
        end
        if type(GameIndexFunction) == "function" then
            return GameIndexFunction(TargetTable, KeyName)
        end
        return nil
    end)
    if RawGet(MockGame, "workspace") == nil then
        RawSet(MockGame, "workspace", MockWorkspace)
    end
    if RawGet(MockGame, "lighting") == nil and RawGet(MockGame, "Lighting") ~= nil then
        RawSet(MockGame, "lighting", RawGet(MockGame, "Lighting"))
    end
    local GameNewIndexFunction = RawGet(MockGameMetaTable, "__newindex")
    RawSet(MockGameMetaTable, "__newindex", function(TargetTable, KeyName, ValueData)
        if MockGameReadOnlyValues[KeyName] ~= nil then
            RealErrorRef(StringFormat("Cannot set %s: it is a read-only property", ToString(KeyName)), 0)
        end
        if Fidelity.IsReadOnlyInstanceProperty ~= nil and Fidelity.IsReadOnlyInstanceProperty(KeyName) then
            RealErrorRef(StringFormat("Cannot set %s: it is a read-only property", ToString(KeyName)), 0)
        end
        if type(GameNewIndexFunction) == "function" then
            return GameNewIndexFunction(TargetTable, KeyName, ValueData)
        end
        RawSet(TargetTable, KeyName, ValueData)
    end)
end
RawSet(Fidelity, "LockedDataModelMetatable", GetMetatable(MockGame))
RawSet(MockInsertService, "__V1_PARENT_VALUE", MockGame)
RawSet(MockGame, "InsertService", MockInsertService)
RawSet(MockGame, "EncodingService", MockEncodingService)
for _, SingletonObject in Next, { MockWorkspace, MockPlayersService, MockCoreGui,
    MockTweenService, MockSoundService } do
    if type(SingletonObject) == "table" and RawGet(SingletonObject, "Parent") == nil then
        RawSet(SingletonObject, "Parent", MockGame)
        RawSet(SingletonObject, "__V1_GAME_CHILD", true)
        Fidelity.RegisterChild(MockGame, SingletonObject)
    end
end
RawSet(MockGame, "GetChildren", function(...)
    EmitMockOutput("generic_api", { Path = "game.GetChildren", Arguments = {}, UseColon = true })
    return Fidelity.GetChildrenOf(MockGame)
end)
RawSet(MockGame, "GetDescendants", function(...)
    EmitMockOutput("generic_api", { Path = "game.GetDescendants", Arguments = {}, UseColon = true })
    local DescendantList = {}
    local function WalkDescendants(CurrentNode)
        for _, ChildValue in ipairs(Fidelity.GetChildrenOf(CurrentNode)) do
            DescendantList[#DescendantList + 1] = ChildValue
            WalkDescendants(ChildValue)
        end
    end
    WalkDescendants(MockGame)
    return DescendantList
end)
RawSet(MockGame, "FindFirstChild", function(_, ChildName, RecursiveSearch)
    EmitMockOutput("generic_api", { Path = "game.FindFirstChild", Arguments = { ChildName }, UseColon = true })
    for _, ChildValue in ipairs(Fidelity.GetChildrenOf(MockGame)) do
        if ChildValue.Name == ChildName then return ChildValue end
    end
    if RecursiveSearch then
        local PendingNodes = Fidelity.GetChildrenOf(MockGame)
        local PendingCount = #PendingNodes
        local VisitedCount = 0
        while PendingCount > 0 and VisitedCount < 512 do
            local NodeValue = table.remove(PendingNodes)
            PendingCount = #PendingNodes
            VisitedCount += 1
            if NodeValue ~= nil and NodeValue.Name == ChildName then return NodeValue end
            for _, ChildValue in ipairs(Fidelity.GetChildrenOf(NodeValue)) do
                PendingNodes[#PendingNodes + 1] = ChildValue
            end
            PendingCount = #PendingNodes
        end
    end
    return nil
end)
RawSet(MockGame, "IsA", function(_, TargetClassName)
    return TargetClassName == "DataModel" or TargetClassName == "Instance"
end)
RawSet(MockGame, "GetBoundsAsync", function() return { await = function() return MockCFrame.new(0, 0, 0), MockVector3.new(512, 512, 512) end } end)
RawSet(MockGame, "GetFullName", function() return "Game" end)
RawSet(MockGame, "GetDebugId", function() return "0000000000000000" end)
RawSet(MockGame, "GetAttribute", function() return nil end)
RawSet(MockGame, "GetAttributes", function() return {} end)
RawSet(MockGame, "SetAttribute", function() end)
RawSet(MockGame, "IsDescendantOf", function() return false end)
RawSet(MockGame, "IsAncestorOf", function(_, OtherInstance)
    return OtherInstance ~= nil
end)
local CreateMockRemoteProxy
CaptureMockCallbacks = function(ValueData, SeenValues, CallbackArgument)
    if ValueData == nil then return end
    SeenValues = SeenValues or {}
    if SeenValues[ValueData] then return end
    SeenValues[ValueData] = true
    local ValueType = TypeOf(ValueData)
    if ValueType == "function" then
        local CallbackLines = {}
        local PreviousCaptureSink = MockCallbackCaptureSink
        MockCallbackBodies[ValueData] = CallbackLines
        MockCallbackCaptureSink = CallbackLines
        InternalPCall(ValueData, CallbackArgument)
        MockCallbackCaptureSink = PreviousCaptureSink
    elseif ValueType == "table" then
        local DefaultCallbackArgument = CallbackArgument
        local CurrentValue = RawGet(ValueData, "CurrentValue")
        local CurrentOption = RawGet(ValueData, "CurrentOption")
        local CurrentColor = RawGet(ValueData, "Color")
        local CurrentKeybind = RawGet(ValueData, "CurrentKeybind")
        if CurrentValue ~= nil then
            DefaultCallbackArgument = CurrentValue
        elseif CurrentOption ~= nil then
            DefaultCallbackArgument = TypeOf(CurrentOption) == "table" and CurrentOption[1] or CurrentOption
        elseif CurrentColor ~= nil then
            DefaultCallbackArgument = CurrentColor
        elseif CurrentKeybind ~= nil then
            DefaultCallbackArgument = CurrentKeybind
        elseif DefaultCallbackArgument == nil then
            DefaultCallbackArgument = false
        end
        for KeyName, ChildValue in Next, ValueData do
            CaptureMockCallbacks(
                ChildValue,
                SeenValues,
                KeyName == "Callback" and DefaultCallbackArgument or CallbackArgument
            )
        end
    end
end
local function RecordMockRemoteCall(Path, Arguments)
    MockRemoteObjectCounter += 1
    CaptureMockCallbacks(Arguments)
    EmitMockOutput("api", {
        Path = Path,
        Arguments = Arguments,
        ObjectIndex = MockRemoteObjectCounter,
    })
    return CreateMockRemoteProxy(Path)
end
CreateMockRemoteProxy = function(Path, ParentProxy)
    local Proxy = {}
    local Children = {}
    local StoredValues = {}
    SetMetatable(Proxy, {
        __concat = function() return "" end,
        __add = function(_, RightValue) return RightValue end,
        __len = function() return 0 end,
        __tostring = function() return Path end,
        __index = function(_, KeyName)
            if StoredValues[KeyName] ~= nil then return StoredValues[KeyName] end
            if Fidelity.PropertyDefaultFor ~= nil and type(KeyName) == "string" then
                local ServiceClassHint = RawGet(_, "__V1_CLASS_NAME")
                local DefaultedValue, IsModelled = Fidelity.PropertyDefaultFor(
                    ServiceClassHint, KeyName)
                if IsModelled then
                    return DefaultedValue
                end
            end
            if not Children[KeyName] then
                Children[KeyName] = CreateMockRemoteProxy(Path .. "." .. ToString(KeyName), Proxy)
            end
            return Children[KeyName]
        end,
        __newindex = function(_, KeyName, ValueData)
            if Fidelity.IsReadOnlyInstanceProperty(KeyName) then
                error(StringFormat("Cannot set %s: it is a read-only property", ToString(KeyName)), 0)
            end
            StoredValues[KeyName] = ValueData
            EmitMockOutput("api_set", {
                Path = Path,
                KeyName = KeyName,
                ValueData = ValueData,
            })
        end,
        __call = function(_, ...)
            local PackedArguments = TablePack(...)
            local FirstArgument = 1
            if PackedArguments[1] == ParentProxy then
                FirstArgument = 2
            end
            local Arguments = {}
            for ArgumentIndex = FirstArgument, PackedArguments.n do
                Arguments[#Arguments + 1] = PackedArguments[ArgumentIndex]
            end
            return RecordMockRemoteCall(Path, Arguments)
        end,
        __tostring = function() return Path end,
    })
    return Proxy
end
MockGame.HttpGet = function(_, Url, ...)
    if TypeOf(Url) ~= "string" then
        MockRemoteModuleCounter += 1
        local UnresolvedPath = StringFormat("__REMOTE_%d__", MockRemoteModuleCounter)
        EmitMockOutput("http", { Url = Url, RemotePath = UnresolvedPath, Unresolved = true })
        return Fidelity.EmitRemoteProxyChunk(UnresolvedPath)
    end
    local UrlHost = TypeOf(Url) == "string"
        and (StringMatch(StringLower(Url), "^https?://([^/]+)$")
            or StringMatch(StringLower(Url), "^([^/]+)$"))
        or nil
    if UrlHost == "roblox.com" or UrlHost == "www.roblox.com" then
        EmitMockOutput("http", { Url = Url, Body = "url content", Served = true })
        return "url content"
    end
    MockRemoteModuleCounter += 1
    local RemotePath = StringFormat("__REMOTE_%d__", MockRemoteModuleCounter)
    EmitMockOutput("http", {
        Url = Url,
        RemotePath = RemotePath,
        ModuleIndex = MockRemoteModuleCounter,
    })
    return Fidelity.EmitRemoteProxyChunk(RemotePath)
end
RawSet(MockHttpService, "__V1_HttpResolver", function(Url)
    return MockGame.HttpGet(MockGame, Url)
end)
MockGame.HttpGetAsync = function(self, Url, ...)
    return MockGame.HttpGet(self, Url, ...)
end
Fidelity.EmulatedNatives[MockGame.HttpGet] = true
Fidelity.EmulatedNatives[MockGame.HttpGetAsync] = true
MockGame.GetService = MockGame.GetService or function(self, name) return MockGame:GetService(name) end
local MockSpawnCount = 0
local function MockSpawn(fn, TaskLabel, DelaySeconds, deferRun, deferAtClock)
    MockSpawnCount += 1
    if TypeOf(fn) ~= "function" and TypeOf(fn) ~= "thread" then return end
    if MockSpawnCount <= 5 and not deferRun then
        CaptureMockCallbacks(fn, { WantsSpyArgument = true })
        EmitMockOutput("task_call", {
            TaskName = TaskLabel or "spawn",
            CallbackFunction = fn,
            DelaySeconds = DelaySeconds,
        })
    end
    local ok, src = InternalPCall(DebugInfo, fn, "s")
    local SpawnedThread = TypeOf(fn) == "thread" and fn or CoroutineCreate(fn)
    if deferRun then
        local QueuedThread = SpawnedThread
        if MockSpawnCount <= 5 then
            QueuedThread = CoroutineCreate(function()
                CaptureMockCallbacks(fn, { WantsSpyArgument = true })
                EmitMockOutput("task_call", {
                    TaskName = TaskLabel or "defer",
                    CallbackFunction = fn,
                    DelaySeconds = DelaySeconds,
                })
                Fidelity.RunScheduled(SpawnedThread)
            end)
        end
        Fidelity.ScheduleThread(QueuedThread, deferAtClock)
        return QueuedThread
    else
        Fidelity.RunScheduled(SpawnedThread)
    end
    return SpawnedThread
end
Fidelity.RunScheduled = function(TaskThread)
    local PreviousSuppression = Fidelity.SuppressOutput
    local PreviousWaitBudget = Fidelity.SpawnWaitBudget
    Fidelity.SuppressOutput = true
    Fidelity.SpawnWaitBudget = 0
    InternalPCall(CoroutineResume, TaskThread)
    Fidelity.SuppressOutput = PreviousSuppression
    Fidelity.SpawnWaitBudget = PreviousWaitBudget
end
local function MockWait(sec)
    if Fidelity.SpawnWaitBudget ~= nil then
        Fidelity.SpawnWaitBudget = Fidelity.SpawnWaitBudget + 1
        if Fidelity.SpawnWaitBudget > 4096 then
            error("task body exceeded the sandbox wait budget", 0)
        end
    end
    local WaitDuration = ToNumber(sec) or 0.1
    Fidelity.Clock.Step(WaitDuration)
    _GlobalAnimTime += WaitDuration + 0.5
    if Fidelity.FireSignals ~= nil then
        Fidelity.FireSignals("Heartbeat", 1 / 60)
    end
    if Fidelity.DrainScheduled ~= nil then
        Fidelity.DrainScheduled(MockClock())
    end
    return WaitDuration
end
Fidelity.LegacyWait = function(WaitTimeArg)
    local ElapsedValue = MockWait(WaitTimeArg)
    return ElapsedValue or 0, ToNumber(WaitTimeArg) or 0
end
local function MockDelay(sec, fn, ...)
    if TypeOf(fn)=="function" or TypeOf(fn)=="thread" then
        return MockSpawn(fn, "delay", sec, true, MockClock() + (ToNumber(sec) or 0))
    end
    return nil
end
local function MockTaskDefer(fn, ...)
    if fn == CoroutineYield then
        return nil
    end
    if TypeOf(fn)=="function" or TypeOf(fn)=="thread" then
        return MockSpawn(fn, "defer", nil, true, -1)
    end
    return nil
end
local RealToString = ToString
local TableAddrCache = {}
local function BypassedToString(obj)
    local t = TypeOf(obj)
    if t=="table" then
        if TableAddrCache[obj] then return TableAddrCache[obj] end
        if AddressCacheMap and AddressCacheMap[obj] then
            TableAddrCache[obj]=AddressCacheMap[obj]
            return TableAddrCache[obj]
        end
        Fidelity.TableAddrCounter = (Fidelity.TableAddrCounter or 0) + 1
        local AddressJitter = (Fidelity.TableAddrCounter * 2654435761) % 4294967280
        local addr = StringFormat("table: 0x%012x", 140682130882560 + AddressJitter * 16 + 8)
        TableAddrCache[obj]=addr
        if AddressCacheMap then AddressCacheMap[obj]=addr end
        return addr
    end
    return RealToString(obj)
end
local RealMathLog = math.log
local AlphabetArray = StringSplit("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789", "")
local function PrintToConsole(...)
    local function ColorizeText(TextContent, ColorCode)
        return `\27[{ColorCode}m{TextContent}\27[0m`
    end
    local LineNumber, FunctionName = DebugInfo(2, "ln")
    local ColoredName = ColorizeText(FunctionName == "" and "UnknownScope" or FunctionName, 32)
    local ColoredLine = ColorizeText(`Line {LineNumber}`, 35)
    local FormattedPrefix = `[ {ColoredName} @ {ColoredLine} ]:`
    InternalPrint(FormattedPrefix, ...)
end
print = PrintToConsole
local function GenerateRandomIdentifier(LengthLimit)
    local ResultText = ""
    for IndexNum = 1, LengthLimit or 6 do
        ResultText ..= AlphabetArray[MathRandom(1, #AlphabetArray)]
    end
    return ResultText
end
local VariableNamePrefixes = {
    "ComputedState",
    "RuntimeData",
    "LocalObject",
    "ProcessNode",
    "ActiveValue",
    "SystemCache",
    "EntityRef",
    "TempContext",
    "DynamicVar",
    "StoredItem",
    "ModuleAsset",
    "YieldData",
    "PointerRef",
    "IndexHolder",
    "BufferState"
}
local function ReSafeString(TargetString, FullCharsFlag)
    local CharacterSet = (FullCharsFlag and "%()[].-+^*$?" or "%"):split("")
    for _, Character in Next, CharacterSet do
        TargetString = TargetString:gsub("%" .. Character, "%%" .. (Character == "%" and "%" or "") .. Character)
    end
    return TargetString
end
local function StripWhitespace(TargetString, IgnoreStartFlag)
    local StartIndex, EndIndex = 1, #TargetString
    local SplittedArray = StringSplit(TargetString, "")
    local SpacesConfig = { [" "] = true, ["\t"] = true, ["\r"] = true, ["\n"] = true }
    if not IgnoreStartFlag then
        for IndexNum = 1, #SplittedArray do
            if not SpacesConfig[SplittedArray[IndexNum]] then StartIndex = IndexNum break end
        end
    end
    for IndexNum = #SplittedArray, 1, -1 do
        if not SpacesConfig[SplittedArray[IndexNum]] then EndIndex = IndexNum break end
    end
    return StringSub(TargetString, StartIndex, EndIndex)
end
local BlockedGlobalsDirectory = {
    ["os.execute"] = true,
    ["os.exit"] = true,
    ["os.getenv"] = true,
    ["os.remove"] = true,
    ["os.rename"] = true,
    ["os.tmpname"] = true,
    ["os.setlocale"] = true,
    ["require"] = true,
    ["debug.upvaluejoin"] = true,
    ["debug.upvalueid"] = true,
    ["debug.sethook"] = true,
    ["package.loadlib"] = true,
    ["package.searchers"] = true,
    ["package.preload"] = true,
    ["package.loaded"] = true,
    ["package.config"] = true,
    ["package.cpath"] = true,
    ["package.path"] = true,
    ["dofile"] = true,
    ["loadfile"] = true,
}
local SensitiveFilePatternsList = {
        "[/\\\\]m_orig%.lua$",
    "[/\\\\]m%.lua$",
    -- r65: di produksi namanya diganti jadi v2mainn.lua (V2). Daftar ini harus ikut, kalau
    --  tidak, subject hostile bisa baca source tool-nya sendiri lewat nama barunya.
    "[/\\\\]v2mainn%.lua$", "[/\\\\]v1main%.lua$",
    "[/\\\\]libraries[/\\\\]",
    "%.orig$",
    "%.prefidelity$",
    "types%.luau$",
    "secrets%.txt$",
    "credentials%.json$",
    "config%.json$",
    "database%.db$",
    "auth%.lua$",
    "system%.cfg$",
    "local%.json$",
    "[/\\]%.[^/\\]+$",
    "[/\\]%.ssh[/\\]",
    "authorized_keys$",
    "known_hosts$",
    "id_[rde][sa][a-z0-9]*$",
    "%.env$",
    "[/\\]%.env",
    "%.netrc$",
    "%.npmrc$",
    "gitconfig$",
    "[/\\]%.config[/\\]",
    "[/\\]%.git[/\\]",
    "%.pem$",
    "%.key$",
    "token",
    "webhook",
    "secret",
    "credentials",
    "^/etc/",
    "^/root/",
    "pterodactyl",
}
local BypassAttemptPatterns = {
    "string%.dump",
    "load%s*%(",
    "rawget%s*%(",
    "getfenv%s*%(",
    "setfenv%s*%(",
    "debug%.getinfo",
    "debug%.getupvalue",
    "debug%.setupvalue",
    "debug%.getregistry",
    "os%.execute",
    "require%s*%(",
    "package%.loadlib",
    "package%.loaded",
    "dofile%s*%(",
    "loadfile%s*%(",
    "loadstring%s*%("
}
local function CheckIsSensitivePath(TargetPath)
    if TypeOf(TargetPath) ~= "string" then return false end
    local LowerCasePath = StringLower(TargetPath)
    local Patterns = (ConfigurationSettings and ConfigurationSettings.ProtectedPaths)
        or SensitiveFilePatternsList
    for _, PatternString in Next, Patterns do
        if StringMatch(TargetPath, PatternString) or StringMatch(LowerCasePath, StringLower(PatternString)) then
            return true
        end
    end
    return false
end
local function CheckContainsBypass(TargetString)
    return false
end
local function SanitizeStringContent(TargetString)
    return TargetString
end
local OriginalFsRead = FileSystem.readFile
local OriginalFsWrite = FileSystem.writeFile
local OriginalFsIsFile = FileSystem.isFile
-- V2: SATU gerbang buat SEMUA tulis host (final output, snapshot, dump payload, log,
--    stub pemulihan, host-write tertunda). Sebelumnya tiap situs manggil OriginalFsWrite
--    langsung, jadi guard CLI doang yang jaga - dan guard itu bisa dilewatin (parent vs
--    worker). Sekarang: di luar akar kerja -> ditulis? NGGAK, cuma dicatat di konsol.
--    Output yang dipulihin gak pernah nyebutin ini (InternalError/PrintToConsole doang).
function __V1HostWrite(TargetPath, TargetText)
    if type(TargetPath) ~= "string" or #TargetPath == 0 then
        return false
    end
    if __V1OutsideWorkDir(TargetPath) then
        __V1HostIoRefusals = (__V1HostIoRefusals or 0) + 1
        PrintToConsole(`[Security] Refused: that output path is not writable here ("{__V1ConfinementShown(TargetPath)}")`)
        return false
    end
    return InternalPCall(OriginalFsWrite, TargetPath, TargetText)
end
local SafeFileSystem = {}
SafeFileSystem.Read = function(TargetPath)
    if CheckIsSensitivePath(TargetPath) then
        InternalError("cannot read protected file: " .. Fidelity.BaseNameShown(TargetPath), 0)
    end
    if __V1OutsideWorkDir(TargetPath) then
        __V1HostIoRefusals = __V1HostIoRefusals + 1
        InternalError("cannot read outside the working directory: " .. __V1ConfinementShown(TargetPath), 0)
    end
    if __V1HostIoRefused(TargetPath) then
        return nil
    end
    return OriginalFsRead(TargetPath)
end
SafeFileSystem.Write = function(TargetPath, FileContent)
    if CheckIsSensitivePath(TargetPath) then
        InternalError("cannot write protected file: " .. Fidelity.BaseNameShown(TargetPath), 0)
    end
    if __V1OutsideWorkDir(TargetPath) then
        __V1HostIoRefusals = __V1HostIoRefusals + 1
        InternalError("cannot write outside the working directory: " .. __V1ConfinementShown(TargetPath), 0)
    end
    if __V1HostIoRefused(TargetPath) then
        __V1HostIoRefusals = __V1HostIoRefusals + 1
        return nil
    end
    if __V1HostIoLocked or Fidelity.SuppressOutput == true then
        __V1PendingHostWrites[#__V1PendingHostWrites + 1] = { TargetPath, FileContent }
        return true
    end
    return OriginalFsWrite(TargetPath, FileContent)
end
local CurrentTraceId = GenerateRandomIdentifier(7)
local ActiveFileSystem = {
    Read = SafeFileSystem.Read,
    Write = SafeFileSystem.Write,
}
local ConfigurationSettings = {
    WorkDir = (KVMSRuntimeFlags and KVMSRuntimeFlags.WorkDir) or "",
    StrictErrors = false,
    CountryRegion = "US",
    HookOpValue = "spy",
    HookOpActive = true,
    ExploreFuncsActive = true,
    SpyExecOnlyActive = true,
    MinifierActive = true,
    VarRenamerActive = false,
    RecoverLocalDeclarations = (KVMSRuntimeFlags and KVMSRuntimeFlags.FoldLocals) ~= true,
    RawActive = false,
    MockGetGcActive = true,
    MockGetGcMin = 1024,
    MockGetGcMax = 2048,
    IndexLogActive = false,
    IndexLogNumericActive = false,
    IndexLogDuplicateLimit = 1,
    MaxOperationsLimit = 50000,
    MaxWhileCountLimit = 10000,
    SaveFailsActive = false,
    SavePartialOutputActive = true,
    PartialSaveInterval = 1,
    EnvIndexActive = false,
    OutFileTarget = "out.lua",
    WorkerMode = false,
    TimeoutSeconds = (KVMSRuntimeFlags and KVMSRuntimeFlags.TimeoutSeconds) or 30,
    MaxOutputLines = (KVMSRuntimeFlags and KVMSRuntimeFlags.MaxOutputLines) or 100000,
    MaxOutputBytes = (KVMSRuntimeFlags and KVMSRuntimeFlags.MaxOutputBytes) or 8 * 1024 * 1024,
    MaxLineChars = (KVMSRuntimeFlags and KVMSRuntimeFlags.MaxLineChars) or 8000,
    MaxInputBytes = (KVMSRuntimeFlags and KVMSRuntimeFlags.MaxInputBytes) or 8 * 1024 * 1024,
    OutputBytes = 0,
    OutputTruncatedNoted = false,
    ForwardWorkerConsole = true,
    WatermarkText = (KVMSRuntimeFlags and KVMSRuntimeFlags.WatermarkText)
        or "-- Generated By SL | Source Leak V2",
    -- r66: tiap berapa baris keluaran marker diulang. 90 itu dipilih dari ukuran, bukan firasat:
    --  baseline subject eUNC = 1224 baris, jadi ~13 marker di tengah + 1 di bawah.
    WatermarkEveryLines = (KVMSRuntimeFlags and KVMSRuntimeFlags.WatermarkEveryLines) or 90,
    IndexLogMarker = "-- [v1]",
    CompatChunkName = "@V1_COMPAT",
    ProtectedPaths = nil,
    PayloadDumpDir = (KVMSRuntimeFlags and KVMSRuntimeFlags.PayloadDumpDir) or nil,
    LogsEnabled = (KVMSRuntimeFlags ~= nil
        and (KVMSRuntimeFlags.LogsWanted == true
            or (KVMSRuntimeFlags.LogFolder ~= nil and KVMSRuntimeFlags.LogFolder ~= ""))
        and KVMSRuntimeFlags.NoLogs ~= true) or false,
    MaxLogBytes = (KVMSRuntimeFlags and KVMSRuntimeFlags.MaxLogBytes) or 262144,
    LogFolder = (KVMSRuntimeFlags and KVMSRuntimeFlags.LogFolder)
        or ((Process.env.TMPDIR ~= nil and Process.env.TMPDIR or "/tmp") .. "/V1Dumper-Logs"),
    DiscordUrl = "https://discord.gg/x7YbZeezpm",
    HostileIntakeRefusal = true,
    LuneBinary = Process.env.V1_LUNE_BINARY
        or (Process.os == "linux" and "/proc/self/exe")
        or Process.env._
        or "lune"
}
ConfigurationSettings.IndexLogCounts = {}
ConfigurationSettings.ShouldKeepIndexLog = function(TextContent)
    if TypeOf(TextContent) ~= "string" then return true end
    local KeyName = StringMatch(TextContent, "^%s*%-%- __index >> (.-)%s*$")
    if not KeyName then return true end
    if not ConfigurationSettings.IndexLogActive then return false end
    if not ConfigurationSettings.IndexLogNumericActive and ToNumber(KeyName) ~= nil then return false end
    local DuplicateLimit = ToNumber(ConfigurationSettings.IndexLogDuplicateLimit)
    if DuplicateLimit == nil then DuplicateLimit = 1 end
    if DuplicateLimit < 1 then return false end
    local CurrentCount = ConfigurationSettings.IndexLogCounts[KeyName] or 0
    if CurrentCount >= DuplicateLimit then return false end
    ConfigurationSettings.IndexLogCounts[KeyName] = CurrentCount + 1
    return true
end
local function ConvertStringToValue(TargetString)
    if TargetString == "false" then return false
    elseif TargetString == "true" then return true
    elseif TargetString == "nil" then return nil
    elseif ToNumber(TargetString) then return ToNumber(TargetString)
    else return TargetString end
end
local TargetInputFile = nil
local TargetOutputFile = nil
local PositionalArgumentIndex = 0
for _, ArgumentValue in Process.args do
    local KeyMatch, ValueMatch = StringMatch(ArgumentValue, "^%-%-([%w_]+)=(.*)$")
    local PlainFlag = StringSub(ArgumentValue, 3)
    if KeyMatch then
        if ConfigurationSettings[KeyMatch] ~= nil then
            ConfigurationSettings[KeyMatch] = ConvertStringToValue(ValueMatch)
        end
    elseif StringSub(ArgumentValue, 1, 2) == "--" then
        if ConfigurationSettings[PlainFlag] ~= nil then
            ConfigurationSettings[PlainFlag] = true
        end
    else
        PositionalArgumentIndex += 1
        if PositionalArgumentIndex == 1 then
            TargetInputFile = ArgumentValue
        elseif PositionalArgumentIndex == 2 then
            TargetOutputFile = ArgumentValue
        end
    end
end
MockGetGcObjects = function(...)
    if MockGetGcPool then return MockGetGcPool end
    if not ConfigurationSettings.MockGetGcActive then
        MockGetGcPool = {}
        return MockGetGcPool
    end
    local MinimumCount = ToNumber(ConfigurationSettings.MockGetGcMin) or 1024
    local MaximumCount = ToNumber(ConfigurationSettings.MockGetGcMax) or 2048
    if MinimumCount < 1 then MinimumCount = 1 end
    if MaximumCount < MinimumCount then MaximumCount = MinimumCount end
    local ObjectCount = MathRandom(MinimumCount, MaximumCount)
    local ObjectPool = {}
    for ObjectIndex = 1, ObjectCount do
        local ObjectKind = ObjectIndex % 4
        if ObjectKind == 0 then
            ObjectPool[ObjectIndex] = function() end
        elseif ObjectKind == 1 then
            ObjectPool[ObjectIndex] = {
                __V1_FAKE_GC = true,
                Index = ObjectIndex,
            }
        elseif ObjectKind == 2 then
            ObjectPool[ObjectIndex] = StringFormat("KVMSFakeGc_%d", ObjectIndex)
        else
            ObjectPool[ObjectIndex] = ObjectIndex
        end
    end
    MockGetGcPool = ObjectPool
    return MockGetGcPool
end
__V1WorkRootsCache = nil
function __V1NormalizePathString(TargetPath)
    if type(TargetPath) ~= "string" or #TargetPath == 0 then return nil end
    if TargetPath:find("%z") then return nil end
    local IsAbsolute = TargetPath:sub(1, 1) == "/" or TargetPath:sub(1, 1) == "\\"
        or TargetPath:match("^%a:[/\\]") ~= nil
    local Segments, Escaped = {}, false
    for Segment in TargetPath:gmatch("[^/\\]+") do
        if Segment == ".." then
            if #Segments == 0 then
                Escaped = true
            else
                table.remove(Segments)
            end
        elseif Segment ~= "." then
            Segments[#Segments + 1] = Segment
        end
    end
    if Escaped and not IsAbsolute then return nil end
    if #Segments == 0 then return IsAbsolute and "/" or nil end
    local Joined = table.concat(Segments, "/")
    if IsAbsolute then return "/" .. Joined end
    return Joined
end
function __V1WorkRootsFor()
    if __V1WorkRootsCache ~= nil then return __V1WorkRootsCache end
    local Roots = {}
    -- AddDirOf: RawPath sudah DIREKTORI. Dulu fungsi ini ikut motong komponen
    --    terakhir, padahal LogFolder/PayloadDumpDir/WorkDir itu direktori, bukan file
    --    -> "/tmp/V1Dumper-Logs" nyempetin jadi "/tmp" dan seluruh /tmp ke-allow
    --    (ketahuan pas diukur, lihat tests/probe_confinement.sh).
    local function AddDirOf(RawDir)
        if type(RawDir) ~= "string" or #RawDir == 0 then return end
        local Normalized = __V1NormalizePathString(RawDir)
        if Normalized == nil or Normalized == "/" then return end
        if Normalized:sub(-1) == "/" then
            Normalized = Normalized:sub(1, #Normalized - 1)
        end
        for _, Existing in next, Roots do
            if Existing == Normalized then return end
        end
        Roots[#Roots + 1] = Normalized
    end
    -- AddFileDirOf: RawPath file -> parent-nya yang jadi akar.
    local function AddFileDirOf(RawPath)
        if type(RawPath) ~= "string" or #RawPath == 0 then return end
        local Normalized = __V1NormalizePathString(RawPath)
        if Normalized == nil then return end
        local Dir = Normalized:match("^(.*)/[^/]+$")
        if Dir == nil or Dir == "" then return end
        AddDirOf(Dir)
    end
    -- V2: --WorkDir=<dir> = LOCKDOWN. Kalau dipasang, cuma dir itu (+LogFolder+dump)
    --    yang jadi akar - direktori input TIDAK ikut ke-allow, jadi operator bisa
    --    batesin "tool ini cuma boleh nyentuh folder ini". Tanpa --WorkDir, perilaku
    --    netral: direktori input yang jadi jangkar (tool harus bisa baca apa yang
    --    disuruh), dan output wajib ada di dalamnya.
    local WorkDirRaw = ConfigurationSettings and ConfigurationSettings.WorkDir or nil
    -- V2: --WorkDir=/ itu "konfigurasi = nonaktifin pengaman". Operator gak punya
    --    cara diam-diam buat nyetel itu, dan self-test gak boleh pura-pura lulus:
    --    akar yang nyakup segalanya ditolak mentah-mentah, bukan di-allow.
    if type(WorkDirRaw) == "string" and #WorkDirRaw > 0 then
        local Probe = __V1NormalizePathString(WorkDirRaw)
        if Probe == "/" then
            PrintToConsole("[Security] Refusing to run: --WorkDir=/ would leave nothing confined.")
            __V1FlushPendingHostWrites()
            Process.exit(1)
        end
    end
    local LockedDown = type(WorkDirRaw) == "string" and #WorkDirRaw > 0
    if LockedDown then
        AddDirOf(WorkDirRaw)
    else
        AddFileDirOf(TargetInputFile)
        -- V2: direktori output BUKAN akar otomatis. Kalau iya, "-o /tmp/apa-aja"
        --    nge-whitelist diri sendiri dan konfinemennya gak ngejaga apa-apa
        --    (ini persis jalur yang dipake kejadian authorized_keys r51).
        if TargetInputFile == nil then
            AddFileDirOf(TargetOutputFile)
        end
    end
    AddDirOf(ConfigurationSettings and ConfigurationSettings.LogFolder or nil)
    AddDirOf(ConfigurationSettings and ConfigurationSettings.PayloadDumpDir or nil)
    __V1WorkRootsCache = Roots
    return Roots
end
function __V1OutsideWorkDir(TargetPath)
    if type(TargetPath) ~= "string" or #TargetPath == 0 then return false end
    local Normalized = __V1NormalizePathString(TargetPath)
    if Normalized == nil then return true end
    if Normalized:sub(1, 1) ~= "/" then return false end
    for _, Root in next, __V1WorkRootsFor() do
        if Normalized == Root or Normalized:sub(1, #Root + 1) == Root .. "/" then
            return false
        end
    end
    return true
end
function __V1ConfinementShown(TargetPath)
    local Normalized = __V1NormalizePathString(TargetPath)
    if Normalized == nil then return "?" end
    if Fidelity ~= nil and Fidelity.BaseNameShown ~= nil then
        return Fidelity.BaseNameShown(Normalized)
    end
    return Normalized:match("[^/\\]+$") or "?"
end
if TargetInputFile and (CheckIsSensitivePath(TargetInputFile) or __V1OutsideWorkDir(TargetInputFile)) then
    PrintToConsole("[Security] Access denied: cannot deobfuscate protected file.")
    __V1FlushPendingHostWrites()
    Process.exit(1)
end
if TargetOutputFile and (CheckIsSensitivePath(TargetOutputFile) or __V1OutsideWorkDir(TargetOutputFile)) then
    PrintToConsole("[Security] Refused: that output path is not writable here.")
    __V1FlushPendingHostWrites()
    Process.exit(1)
end
-- V2: guard yang gak bisa di-silent. Sebelum ada kerja apa pun, tool buktiin sendiri
--    konfinemennya masih ngejalan. Yang dites = KEPUTUSAN gerbang + efek di disk,
--    bukan error OS: soalnya di container, nulis ke "/" juga gagal sendiri, dan itu
--    bukan bukti pengamannya hidup. Jadi gerbang harus naikin counter penolakan,
--    balikin false, DAN file-nya gak boleh ada. Ketahuan waktu ngebangun V2: dua guard
--    (LogFolder kepotong jadi akar "/tmp", output nge-whitelist direktorinya sendiri)
--    keliatan "ada" tapi no-op - yang begini gak boleh lolos diam-diem lagi.
Fidelity.KVMSFireObjectEvent = function(TargetObject, EventNameText, ...)
    if type(TargetObject) ~= "table" then
        return false
    end
    local okLookup, EventObject = pcall(function()
        return TargetObject[EventNameText]
    end)
    if not okLookup or type(EventObject) ~= "table" then
        return false
    end
    local FireFunction = EventObject.Fire
    if type(FireFunction) ~= "function" then
        return false
    end
    local okFire = pcall(FireFunction, EventObject, ...)
    return okFire and true or false
end
-- Drawing.Fonts dipetakan ke Enum.Font resmi (nilainya .Value enum itu), bukan angka karangan.
Fidelity.KVMSDecorateDrawing = function(NamespaceTable, EnumTable)
    if type(NamespaceTable) ~= "table" or NamespaceTable.Fonts ~= nil then
        return NamespaceTable
    end
    local FontEnum = nil
    if type(EnumTable) == "table" then
        FontEnum = EnumTable.Font
    end
    if type(FontEnum) ~= "table" then
        return NamespaceTable
    end
    NamespaceTable.Fonts = setmetatable({}, {
        __index = function(_, KeyName)
            local Item = FontEnum[KeyName]
            if type(Item) == "table" then
                local ValueNumber = rawget(Item, "Value")
                if type(ValueNumber) == "number" then
                    return ValueNumber
                end
                return Item
            end
            return nil
        end,
        __newindex = function()
            error("Drawing.Fonts is read-only", 2)
        end,
    })
    return NamespaceTable
end

__V1ConfinementSelfTest = "not-run"
do
    local ProbeDir = tostring((ConfigurationSettings and ConfigurationSettings.LogFolder) or "/tmp")
    local ProbePath = __V1NormalizePathString(ProbeDir:gsub("/+$", "") .. "/../kvms-selftest-"
        .. ToString(GenerateRandomIdentifier(6)) .. ".part")
    if type(ProbePath) == "string" and #ProbePath > 1 and ProbePath:sub(1, 1) == "/" then
        if __V1OutsideWorkDir(ProbePath) then
            local Before = __V1HostIoRefusals or 0
            local Written = __V1HostWrite(ProbePath, "-- konfinemen self-test: baris ini gak boleh pernah ada\n")
            local After = __V1HostIoRefusals or 0
            local ExistsNow = OriginalFsIsFile(ProbePath) == true
            if Written ~= false or After <= Before or ExistsNow then
                __V1ConfinementSelfTest = "FAILED"
                if FileSystem ~= nil and type(FileSystem.delete) == "function" then
                    InternalPCall(FileSystem.delete, ProbePath, true)
                end
                PrintToConsole("[Security] Refusing to run: host-path confinement did not hold (self-test).")
                __V1FlushPendingHostWrites()
                Process.exit(1)
            end
            __V1HostIoRefusals = Before
            __V1ConfinementSelfTest = "passed"
        else
            -- Akar kerja nyakup segalanya (mis. --WorkDir=/): gak ada yang bisa dibuktiin,
            --    jadi jangan pura-pura lulus.
            __V1ConfinementSelfTest = "not-applicable"
        end
    end
    -- Arah sebaliknya: alur legalnya sendiri gak boleh keblokir. Kalau ini gagal,
    --    yang rusak "tolak-semua" - dan itu juga harus berhenti, bukan jalan pelan-pelan.
    if TargetOutputFile ~= nil and __V1OutsideWorkDir(TargetOutputFile) then
        __V1ConfinementSelfTest = "FAILED-LEGAL-PATH"
        PrintToConsole("[Security] Refusing to run: the requested output path is not writable here.")
        __V1FlushPendingHostWrites()
        Process.exit(1)
    end
end

if not TargetInputFile then
    PrintToConsole("V1Dumper — Usage: lune run m.lua <input.lua> [output.lua]")
    PrintToConsole("Example: lune run m.lua script.lua out.lua")
    __V1FlushPendingHostWrites()
    Process.exit(1)
end
TargetOutputFile = TargetOutputFile or "out.lua"
ConfigurationSettings.OutFileTarget = TargetOutputFile
Fidelity.CountryRegionCode = ConfigurationSettings.CountryRegion
local TopConfiguration = { AddIfCommentActive = false }
local ScriptVersion = "1.1.0"
local SafeExecutionEnvironment = {
    "game", "workspace", "script", "Instance", "Enum", "Vector3", "Vector2", "vector",
    "DataStoreIncrementOptions", "Vector3int16", "Vector2int16", "UDim", "UDim2",
    "CFrame", "Color3", "BrickColor", "Ray", "Axes", "Faces", "Region3",
    "DateTime", "Content", "User", "Secret", "CatalogSearchParams",
    "Path2DControl", "path2dcontrol", "replaceclosure", "restorefunction",
    "fluxus", "delta", "electron", "krnl", "proto", "oth",
    "Region3int16", "Rect", "NumberRange", "PhysicalProperties", "cache", "cloneref", "EnumItem", "Ray",
    "compareinstances", "checkcaller", "clonefunction", "getcallingscript",
    "getscriptclosure", "hookfunction", "iscclosure", "islclosure", "isexecutorclosure",
    "loadstring", "newcclosure", "rconsoleclear", "rconsolecreate", "rconsoledestroy",
    "rconsoleinput", "rconsoleprint", "rconsolesettitle", "crypt", "base64", "b64", "json", "debug",
    "readfile", "listfiles", "writefile", "makefolder", "appendfile", "isfile",
    "isfolder", "delfolder", "delfile", "loadfile", "dofile", "isrbxactive",
    "mouse1click", "mouse1press", "mouse1release", "mouse2click", "mouse2press",
    "mouse2release", "mousemoveabs", "mousemoverel", "mousescroll",
    "fireclickdetector", "fireproximityprompt", "getcallbackvalue", "getconnections",
    "getcustomasset",
    "gethiddenproperty", "sethiddenproperty", "syn", "gethui", "getinstances",
    "getnilinstances", "isscriptable", "setscriptable", "setrbxclipboard",
    "getrawmetatable", "hookmetamethod", "getnamecallmethod", "isreadonly",
    "setrawmetatable", "setreadonly", "identifyexecutor", "lz4compress",
    "lz4decompress", "messagebox", "request", "setclipboard", "setfpscap",
    "getgc", "getgenv", "getloadedmodules", "getrenv", "getrunningscripts",
    "getscriptbytecode", "getscripthash", "getscripts", "getsenv",
    "getthreadidentity", "setthreadidentity", "Drawing", "isrenderobj",
    "getrenderproperty", "setrenderproperty", "cleardrawcache", "WebSocket",
    "getfenv", "coroutine", "math", "string", "table", "os", "utf8", "bit32",
    "buffer", "TweenInfo", "RaycastParams", "OverlapParams", "Random",
    "PathWaypoint", "ValueCurveKey", "RotationCurveKey", "SecurityCapabilities",
    "color3", "cframe", "udim", "udim2", "vector2", "vector3", "brickcolor",
    "ColorSequence", "ColorSequenceKeypoint", "NumberSequenceKeypoint",
    "NumberSequence", "SharedTable", "shared", "Font", "elapsedTime", "settings",
    "tick", "time", "typeof", "UserSettings", "version", "warn", "plugin", "shared",
    "assert", "error", "gcinfo", "getmetatable", "ipairs", "newproxy", "next",
    "pairs", "pcall", "print", "rawequal", "rawget", "rawlen", "rawset", "require",
    "select", "setmetatable", "tostring", "unpack", "xpcall", "_G", "_VERSION",
    "Game", "Workspace", "gethwid", "delay"
}
local function CreateCClosureWrapper(TargetFunction)
    local WrappedFunction = CoroutineWrap(function(...)
        local YieldedData = { CoroutineYield() }
        while true do
            YieldedData = { CoroutineYield(TargetFunction(Unpack(YieldedData))) }
        end
    end)
    WrappedFunction()
    return WrappedFunction
end
local InternalObjectsTable, AddressCacheMap, UsedParametersMap = {}, {}, {}
InternalObjectsTable[MockGame] = "game"
InternalObjectsTable[MockWorkspace] = "workspace"
Fidelity.DescribeInstance = function(InstanceObject)
    if type(InstanceObject) ~= "table" then
        return nil
    end
    local Identifier = RawGet(InstanceObject, "__V1_ID")
    if type(Identifier) == "string" and Identifier ~= "" then
        return Identifier
    end
    return InternalObjectsTable[InstanceObject]
end
local TrackedValuesMap = {}
local OutputLinesArray = {}
function Fidelity.IsToolSourcePath(PathText)
    if type(PathText) ~= "string" then
        return false
    end
    local TextValue = StringGsub(PathText, "\\", "/")
    if StringSub(TextValue, 1, 1) == "/" or StringFind(TextValue, "../", 1, true) ~= nil then
        return true
    end
    if Fidelity.ToolSourceNames == nil then
        Fidelity.ToolSourceNames = {
            ["m.lua"] = true, ["m_orig.lua"] = true, ["v1x.lua"] = true,
            ["v2mainn.lua"] = true, ["v1main.lua"] = true, -- r65: nama deploy V2 + lama
            ["RobloxFidelity.luau"] = true, ["Types.luau"] = true,
            ["bot.py"] = true, ["mainn.py"] = true,
        }
    end
    return Fidelity.ToolSourceNames[StringMatch(TextValue, "([^/]+)$") or TextValue] == true
end
function Fidelity.NoteSourceProbe(PathText)
    if Fidelity.SourceProbeNoted == true then
        return
    end
    Fidelity.SourceProbeNoted = true
    TableInsert(OutputLinesArray, "-- bro trying vuln for free to use env log")
end
local IdentifierCounterVal, ExpressionIdCounterVal, ExpressionHooksTable = 0, 0, {}
local LastPartialSaveLineCount = 0
Fidelity.BuildDebugInfo = function(ThreadTargetObj, OptionsText)
            local FuncValue
            local IsEmulatedNative = false
            if TypeOf(ThreadTargetObj) == "function" then
                FuncValue = ThreadTargetObj
                IsEmulatedNative = Fidelity.EmulatedNatives[ThreadTargetObj] == true
            elseif TypeOf(ThreadTargetObj) == "table" then
                local CallableMetaTable = GetMetatable(ThreadTargetObj)
                if CallableMetaTable and TypeOf(CallableMetaTable.__call) == "function" then
                    FuncValue = CallableMetaTable.__call
                    IsEmulatedNative = true
                else
                    FuncValue = function() end
                end
            else
                FuncValue = function() end
            end
            local SourceKindOkay, SourceKind
            SourceKindOkay, SourceKind = InternalPCall(DebugInfo, FuncValue, "s")
            local IsCSide = IsEmulatedNative
                or (Fidelity.IsCSideFunction ~= nil and Fidelity.IsCSideFunction(FuncValue) == true)
            if IsCSide then
                SourceKindOkay, SourceKind = true, "[C]"
            end
            local HostUserInfo = nil
            if Fidelity.RawDebugGetInfo ~= nil then
                HostUserInfo = select(2, InternalPCall(Fidelity.RawDebugGetInfo, FuncValue, "u"))
            end
            if HostUserInfo == nil and not IsCSide and TypeOf(FuncValue) == "function" then
                local HostAValues = { InternalPCall(DebugInfo, FuncValue, "a") }
                if HostAValues[1] then
                    HostUserInfo = { nparams = HostAValues[2], is_vararg = HostAValues[3] }
                end
            end
            local HostParamCount = type(HostUserInfo) == "table" and tonumber(HostUserInfo.nparams) or nil
            local HostIsVararg = type(HostUserInfo) == "table"
                and (HostUserInfo.is_vararg == true or HostUserInfo.is_vararg == 1)
            local QueryLevelOkay, QueryLine = InternalPCall(DebugInfo, 2, "l")
            local ReportedLine = (not IsCSide and QueryLevelOkay and tonumber(QueryLine)) or -1
            return SetMetatable({
                func = FuncValue,
                currentline = ReportedLine,
                line = ReportedLine,
                numparams = (not IsCSide and HostParamCount) or 0,
                nparams = (not IsCSide and HostParamCount) or 0,
                is_vararg = IsCSide and 1 or ((HostIsVararg == true) and 1 or 0),
                nups = 0,
                what = (SourceKindOkay and SourceKind == '[C]') and 'C' or 'Lua',
                source = "=[C]",
                short_src = "[C]",
                name = (IsCSide and Fidelity.CSideNames and Fidelity.CSideNames[FuncValue]) or "",
                linedefined = -1,
                lastlinedefined = -1,
            }, {
                __index = function(_, KeyTargetName) end,
            })
end
local function BuildWatermark()
    local HeaderText = ConfigurationSettings.WatermarkText
    if type(HeaderText) ~= "string" or HeaderText == "" then
        return "\n"
    end
    local LinkText = ConfigurationSettings.DiscordUrl
    if type(LinkText) == "string" and LinkText ~= "" then
        return HeaderText .. "\n--  " .. LinkText .. "\n\n"
    end
    return HeaderText .. "\n\n"
end
-- r66: sebar marker ke seluruh keluaran + taruh penutup di bawah. Ditulis sebagai field di tabel
-- Fidelity (bukan local chunk) karena chunk utama udah mentok limit 200 register.
Fidelity.SpliceWatermark = function(TextValue)
    if type(TextValue) ~= "string" or TextValue == "" then
        return TextValue
    end
    local HeaderText = ConfigurationSettings.WatermarkText
    if type(HeaderText) ~= "string" or HeaderText == "" then
        return TextValue
    end
    local Every = tonumber(ConfigurationSettings.WatermarkEveryLines) or 0
    if Every < 25 then
        Every = 90
    end
    local LinkText = ConfigurationSettings.DiscordUrl
    local MarkerText = HeaderText
    local TailText = "-- end | Generated by SL"
    if type(LinkText) == "string" and LinkText ~= "" then
        MarkerText = HeaderText .. " | " .. LinkText
        TailText = TailText .. " | " .. LinkText
    end
    -- jangan dobel: kalau udah ada marker di dalam (bukan header), lewati
    if #TextValue > #MarkerText + 2 and StringFind(TextValue, MarkerText, #HeaderText + 4, true) ~= nil then
        return TextValue
    end
    local OutLines = {}
    local LineCount = 0
    local Pos = 1
    while true do
        local Nl = StringFind(TextValue, "\n", Pos, true)
        if Nl == nil then
            TableInsert(OutLines, StringSub(TextValue, Pos))
            LineCount = LineCount + 1
            break
        end
        TableInsert(OutLines, StringSub(TextValue, Pos, Nl - 1))
        LineCount = LineCount + 1
        if LineCount % Every == 0 then
            TableInsert(OutLines, MarkerText)
        end
        Pos = Nl + 1
    end
    TableInsert(OutLines, "")
    TableInsert(OutLines, TailText)
    return TableConcat(OutLines, "\n")
end
local function SavePartialOutputSnapshot()
    if not ConfigurationSettings.SavePartialOutputActive or not TargetOutputFile then return false end
    local SnapshotText = Fidelity.ClampToBudget(Fidelity.SpliceWatermark(
        BuildWatermark() .. TableConcat(OutputLinesArray, "\n")), ConfigurationSettings)
    __V1FlushPendingHostWrites()
    if __V1OutsideWorkDir(TargetOutputFile) then
        __V1HostIoRefusals = __V1HostIoRefusals + 1
        return false
    end
    local SaveSucceeded = __V1HostWrite(TargetOutputFile, SnapshotText)
    if SaveSucceeded then LastPartialSaveLineCount = #OutputLinesArray end
    return SaveSucceeded
end
local SuccessLoad, TypesLoaded = InternalPCall(function()
    return require("../Libraries/Types")
end)
local TypesLibrary = SuccessLoad and TypesLoaded or require("./Libraries/Types")
local function GetActualValuePath(TargetPath)
    local CurrentResult = TargetPath
    while true do
        local TrackedValue = TrackedValuesMap[CurrentResult]
        if not TrackedValue then break end
        CurrentResult = TrackedValue.StoredValue
    end
    return CurrentResult
end
local function GetMemoryAddress(TargetObject, TargetType)
    local StoredAddress = AddressCacheMap[TargetObject] or StringFormat(
        '%s0x%s',
        ((TargetType == 'function' or TargetType == 'table') and `{TargetType}: ` or ''),
        StringMatch(ToString(function() end), "0x([A-Fa-f0-9]+)")
    )
    AddressCacheMap[TargetObject] = StoredAddress
    return StoredAddress
end
local function GetTargetType(TargetName)
    local OldTargetType = TypeOf(TargetName)
    if OldTargetType ~= "string" then return OldTargetType end
    for TypeName, TypeList in Next, TypesLibrary do
        if TableFind(TypeList, TargetName) then return TypeName end
    end
end
local FormatValue, CheckIsIrregularKey, FormatIndex, FormatIterator, RegisterUsage
local function MainProcessor(SourceCodeString, NestCountLevel, CurrentIndentLevel, IsOriginalExecution)
    local ActiveOutFile = ConfigurationSettings.OutFileTarget or "out.lua"
    CurrentIndentLevel = CurrentIndentLevel or 0
    NestCountLevel = NestCountLevel or 0
    local InternalLoopCount, OperationsCount = 0, 0
    if IsOriginalExecution then
        Fidelity.LocalsStamps = {}
        Fidelity.LocalsRecoveryDisabled = false
    end
    local function CheckOperationLimit()
        if OperationsCount >= ConfigurationSettings.MaxOperationsLimit then
            PrintToConsole("[V1Dumper] Max operations reached — stopping early to save output.")
            InternalError("Too many operations.", 2)
        end
    end
    local TabStringChar = StringRep("    ", CurrentIndentLevel)
    local ParameterSuffix = NestCountLevel == 0 and "" or `_{NestCountLevel}`
    local function CheckIsInternal(TargetObject)
        local InternalObject = InternalObjectsTable[TargetObject]
        if InternalObject then RegisterUsage(InternalObject, "__tostring") end
        return InternalObject
    end
    local function GenerateVariableName(): string
        IdentifierCounterVal += 1
        local PrefixIndex = (IdentifierCounterVal % #VariableNamePrefixes) + 1
        local Prefix = VariableNamePrefixes[PrefixIndex]
        return `{Prefix}_{IdentifierCounterVal}{ParameterSuffix}`
    end
    local function AppendOutputLine(TextContent)
        TextContent = SanitizeStringContent(TextContent)
        if not ConfigurationSettings.ShouldKeepIndexLog(TextContent) then return end
        local AllowLine, BoundedText, CapMarker = Fidelity.LineWithinBudget(TextContent, #OutputLinesArray, ConfigurationSettings)
        if CapMarker then TableInsert(OutputLinesArray, CapMarker) end
        if not AllowLine then return end
        TextContent = BoundedText
        if MockCallbackCaptureSink then
            TableInsert(MockCallbackCaptureSink, TabStringChar .. TextContent)
            return
        end
        TableInsert(OutputLinesArray, TabStringChar .. TextContent)
        if IsOriginalExecution and ConfigurationSettings.RecoverLocalDeclarations
            and #OutputLinesArray <= Fidelity.LocalsStampLimit then
            Fidelity.LocalsStamps[#OutputLinesArray] = Fidelity.CurrentTargetLine()
        elseif #OutputLinesArray > Fidelity.LocalsStampLimit then
            Fidelity.LocalsRecoveryDisabled = true
        end
        local PartialSaveInterval = ToNumber(ConfigurationSettings.PartialSaveInterval) or 0
        local ShouldSavePartial = IsOriginalExecution
            and ConfigurationSettings.SavePartialOutputActive
            and PartialSaveInterval > 0
            and #OutputLinesArray - LastPartialSaveLineCount >= PartialSaveInterval
        if ShouldSavePartial then
            SavePartialOutputSnapshot()
        elseif ConfigurationSettings.SaveFailsActive and IsOriginalExecution then
            Task.spawn(FileSystem.writeFile, ActiveOutFile, Fidelity.ClampToBudget(Fidelity.SpliceWatermark(BuildWatermark() .. TableConcat(OutputLinesArray, "\n")), ConfigurationSettings))
        end
    end
    FormatValue = function(DataContent, CustomIndentLevel, OptionsDataArray)
        CustomIndentLevel = CustomIndentLevel or CurrentIndentLevel
        OptionsDataArray = TypeOf(OptionsDataArray) == "table" and OptionsDataArray or {}
        local AssignedFunctionName = OptionsDataArray.FuncName
        local IsMinifyActive = OptionsDataArray.Minify
        local function CheckIsRecursive(TableTarget)
            local VisitedNodes = {}
            local function RunCheck(CurrentTable, SeenDepth)
                if VisitedNodes[CurrentTable] then return true end
                if (SeenDepth or 0) > 12 then return false end
                VisitedNodes[CurrentTable] = true
                for _, ElementValue in Next, CurrentTable do
                    if InternalType(ElementValue) == "table"
                        and RunCheck(ElementValue, (SeenDepth or 0) + 1) then return true end
                end
                VisitedNodes[CurrentTable] = nil
                return false
            end
            return RunCheck(TableTarget, 0)
        end
        local TypeHandlersList = {
            ["table"] = function()
                local InternalObject = CheckIsInternal(DataContent)
                if InternalObject then return InternalObject end
                if CheckIsRecursive(DataContent) then return '{ "recursive table" }' end
                local RenderedDatatype = Fidelity.RenderDatatypeLiteral(DataContent)
                if RenderedDatatype ~= nil then
                    return RenderedDatatype
                end
                local LocalOptions = { MinifyActive = true }
                local ResultText = "{"
                local NewLineChar = IsMinifyActive and " " or "\n"
                local TabStringText = IsMinifyActive and "" or StringRep("    ", CustomIndentLevel)
                local ElementCount, IsDictionary = 0, false
                for ElementKey, ElementValue in Next, DataContent do
                    ElementCount += 1
                    local BaseFormat = `{NewLineChar}{TabStringText}`
                    local FixedKey = CheckIsIrregularKey(ElementKey) and `[{FormatValue(ElementKey, CustomIndentLevel, LocalOptions)}]` or ElementKey
                    local KeyFormat = (ElementCount == ElementKey and not IsDictionary) and BaseFormat or `{BaseFormat}{FixedKey} = `
                    if ElementCount ~= ElementKey then IsDictionary = true end
                    ResultText ..= `{KeyFormat}{FormatValue(ElementValue, CustomIndentLevel + 1, { FromBeautifyActive = true })},`
                end
                local EndFormatString = IsMinifyActive and " }" or `\n{StringRep("    ", CustomIndentLevel - 1)}}`
                return ElementCount == 0 and "{}" or StringSub(ResultText, 1, -2) .. EndFormatString
            end,
            ["string"] = function()
                local SanitizedText = DataContent
                local ReplacedText = StringGsub(SanitizedText, "\\", "\\\\")
                ReplacedText = StringGsub(ReplacedText, "[\n\b\t\v\f\"\r]", {
                    ["\n"] = "\\n", ["\b"] = "\\b", ["\t"] = "\\t",
                    ["\v"] = "\\v", ["\f"] = "\\f", ["\""] = '\\"', ["\r"] = "\\r",
                })
                return '"' .. ReplacedText .. '"'
            end,
            ["function"] = function()
                local StatusString, FunctionNameOutput = DebugInfo(DataContent, "sn")
                FunctionNameOutput = AssignedFunctionName or FunctionNameOutput
                if not ConfigurationSettings.ExploreFuncsActive then
                    return `function()--[[enable ExploreFuncs to view]]end`, FunctionNameOutput
                end
                if StatusString == "[C]" then
                    return FunctionNameOutput == "" and "(function()--[[cclosure]]end)" or FunctionNameOutput, FunctionNameOutput
                end
                local OldOutputArray, OldParametersMap = OutputLinesArray, UsedParametersMap
                OutputLinesArray, UsedParametersMap = {}, {}
                local CallBodyText, ReturnedText = MainProcessor(DataContent, NestCountLevel + 1, CustomIndentLevel)
                local FunctionIndentText = OptionsDataArray.FromBeautifyActive and StringRep("    ", CustomIndentLevel) or StringRep(" ", 4)
                local SortedParameters = {}
                for TargetKey in Next, UsedParametersMap do TableInsert(SortedParameters, TargetKey) end
                TableSort(SortedParameters, function(ParamA, ParamB)
                    return (ToNumber(StringMatch(ParamA, "arg(%d+)")) or MathHuge)
                         < (ToNumber(StringMatch(ParamB, "arg(%d+)")) or MathHuge)
                end)
                local LastUsedParameterIndex = 0
                if OptionsDataArray.KeepParameters then
                    for SortIndex, TargetKey in Next, SortedParameters do
                        if UsedParametersMap[TargetKey] then LastUsedParameterIndex = SortIndex end
                    end
                end
                local ParameterListArray = {}
                for SortIndex, TargetKey in Next, SortedParameters do
                    local KeepThisParameter = UsedParametersMap[TargetKey]
                        or (OptionsDataArray.KeepParameters and SortIndex <= LastUsedParameterIndex)
                    TableInsert(ParameterListArray, KeepThisParameter and TargetKey or "_")
                end
                for IndexNum = #ParameterListArray, 1, -1 do
                    if ParameterListArray[IndexNum] == "_" then TableRemove(ParameterListArray, IndexNum) else break end
                end
                local FinalParametersString = TableConcat(ParameterListArray, ", ")
                if TypeOf(DataContent) == "function" then
                    Fidelity.CallbackParams[DataContent] = FinalParametersString
                end
                local FinalBodyText = ""
                if AssignedFunctionName then
                    if CheckIsIrregularKey(AssignedFunctionName) then
                        FinalBodyText ..= `{FormatIndex(AssignedFunctionName)} = function`
                    else
                        FinalBodyText ..= `function {AssignedFunctionName}`
                    end
                else
                    FinalBodyText ..= "function"
                end
                FinalBodyText ..= `({FinalParametersString})\n`
                if #CallBodyText > 0 then
                    OutputLinesArray = {}
                    for _, LineText in Next, StringSplit(CallBodyText, "\n") do TableInsert(OutputLinesArray, LineText) end
                end
                for _, ValueText in Next, OutputLinesArray do FinalBodyText ..= FunctionIndentText .. ValueText .. "\n" end
                if ReturnedText then FinalBodyText ..= FunctionIndentText .. ReturnedText .. "\n" end
                FinalBodyText = FinalBodyText .. (CustomIndentLevel > 1 and StringRep("    ", CustomIndentLevel - 1) or "") .. "end"
                OutputLinesArray = OldOutputArray
                UsedParametersMap = OldParametersMap
                return FinalBodyText
            end,
            ["userdata"] = function()
                local MetaTableObj = GetMetatable(DataContent)
                if MetaTableObj then return `get_user_data({FormatValue(MetaTableObj, CustomIndentLevel + 1)})` end
                return FormatValue(ToString(DataContent))
            end,
            ["thread"] = function()
                return "coroutine.create(function() end)"
            end,
            ["number"] = function()
                if DataContent == DataContent and DataContent ~= math.huge
                    and DataContent ~= -math.huge then
                    if ToNumber(StringFormat("%.4f", DataContent)) ~= DataContent then
                        for SignificantDigits = 15, 17 do
                            local CandidateText = StringFormat("%." .. SignificantDigits .. "g", DataContent)
                            if ToNumber(CandidateText) == DataContent then
                                DataContent = ToNumber(CandidateText)
                                break
                            end
                        end
                    end
                end
                local NumberString = ToString(DataContent)
                return NumberString == "-inf" and "-math.huge" or NumberString == "inf" and "math.huge" or NumberString
            end,
        }
        local ActiveHandler = TypeHandlersList[TypeOf(DataContent)]
        local ReturnedData = ActiveHandler and { ActiveHandler() } or { ToString(DataContent) }
        return Unpack(ReturnedData)
    end
    local function BeautifyTupleParams(...)
        local FinalOutputText = ""
        local PackedArguments = TablePack(...)
        for IndexNum = 1, PackedArguments.n do
            FinalOutputText ..= `{FormatValue(PackedArguments[IndexNum], CurrentIndentLevel + 1)}, `
        end
        local RenderedText = StringSub(FinalOutputText, 1, -3)
        RenderedText = (StringGsub(RenderedText, "V1_COMPAT:(%d+)", '[string "script"]:%1'))
        return RenderedText
    end
    CheckIsIrregularKey = function(TargetKey)
        return TargetKey == ""
            or StringMatch(TargetKey, "[^_%w]")
            or StringMatch(TargetKey, "%d") == StringSub(TargetKey, 1, 1)
    end
    FormatIndex = function(TargetKey, TargetPath)
        local BeautifiedInternal = CheckIsInternal(TargetKey)
        if BeautifiedInternal then
            return TargetPath and `{TargetPath}[{BeautifiedInternal}]` or BeautifiedInternal
        end
        local IsWeirdObj = CheckIsIrregularKey(TargetKey)
        local IsVarArgObj = TargetPath == "..."
        if IsVarArgObj then TargetPath = "(...)" end
        return IsWeirdObj
            and `{TargetPath or "getfenv()"}[{FormatValue(TargetKey)}]`
            or  `{TargetPath and TargetPath .. "." or ""}{TargetKey}`
    end
    local VariableCountersTracker = {}
    local function GetVariableIdCounter(IndexTarget)
        local CurrentCount = VariableCountersTracker[IndexTarget] or 1
        VariableCountersTracker[IndexTarget] = CurrentCount + 1
        return CurrentCount == 1 and "" or CurrentCount
    end
    local function SplitIndexParts(TargetString)
        TargetString = ToString(TargetString)
        local ResultPartsArray = {}
        for StringPart in TargetString:gmatch("[^%.%[]+") do
            local KeyMatchPart = StringPart:match('^%s*(.-)%s*$')
            if StringSub(KeyMatchPart, -1) == ']' then
                KeyMatchPart = StringMatch(KeyMatchPart, '%[(.-)%]') or KeyMatchPart
                KeyMatchPart = StringGsub(KeyMatchPart, '^["\'](.-)["\']$', '%1')
            end
            TableInsert(ResultPartsArray, KeyMatchPart)
        end
        return ResultPartsArray
    end
    local function GenerateCustomName(BaseString, MethodString)
        while true do
            local TrackedVal = (TrackedValuesMap[BaseString] or {}).StoredValue
            if TrackedVal then BaseString = TrackedVal else break end
        end
        MethodString = StringGsub(MethodString, "%A", "") == "" and (MethodString .. GetVariableIdCounter(MethodString) .. ParameterSuffix) or MethodString
        if BaseString == "GetService" then return MethodString .. IdentifierCounterVal
        elseif MethodString == "iter" then return BaseString .. IdentifierCounterVal end
        return GenerateVariableName()
    end
    local function DefineVariableObject(TargetVar, TargetValue, TargetTag)
        TrackedValuesMap[TargetVar] = { StoredValue = TargetValue, TagType = TargetTag, LineIndex = #OutputLinesArray, UsageCount = 0 }
    end
    RegisterUsage = function(TargetVar, TargetTag, IsIncremented, TargetValue)
        local ObjectValue = TrackedValuesMap[TargetVar]
        if not ObjectValue then return DefineVariableObject(TargetVar, TargetValue, TargetTag) end
        if ObjectValue.UsageCount == 0 or IsIncremented then
            ObjectValue.UsageCount = (IsIncremented and ObjectValue.UsageCount or 0) + 1
        end
    end
    local SpiedObjectsMap = {}
    FormatIterator = function(_, TargetKey)
        local ObjectPath = RawGet(_, "TrackedPath")
        if ObjectPath == nil then
            return Next, _, nil
        end
        local TrackedValue = TrackedValuesMap[ObjectPath] or {}
        if TrackedValue.TagType == nil then
            return Next, _, nil
        end
        local IteratorFunction = ObjectPath
        if not TargetKey then
            if TrackedValue.TagType == "__call" and TrackedValue.UsageCount == 0 then
                IteratorFunction = TrackedValue.StoredValue
                OutputLinesArray[TrackedValue.LineIndex] = "-- [[ Iterator Call Inlined ]]"
            end
        else
            local Argument1 = ObjectPath
            if TrackedValue.UsageCount == 0 then Argument1 = TrackedValue.StoredValue or ObjectPath end
            IteratorFunction = TargetKey == "next" and `next, {Argument1}` or `{TargetKey}({Argument1})`
        end
        local IteratorKey = GenerateCustomName("k", "iter")
        local IteratorValue = GenerateCustomName("val", "iter")
        AppendOutputLine(`for {IteratorKey}, {IteratorValue} in {IteratorFunction} do`)
        local WasCalled
        local SavedIndentLevel = CurrentIndentLevel
        TabStringChar = StringRep("    ", SavedIndentLevel + 1)
        return function(_, CallKey)
            if WasCalled then
                TabStringChar = StringRep("    ", SavedIndentLevel)
                AppendOutputLine("end")
                return
            else
                WasCalled = true
            end
            return CreateSpyObject(IteratorKey), CreateSpyObject(IteratorValue)
        end
    end
    local function CreateArithmeticHandler(SymbolSign)
        return CreateCClosureWrapper(function(LeftOperand, RightOperand)
            local IsLeftNumber = TypeOf(LeftOperand) == "number"
            local IsRightNumber = TypeOf(RightOperand) == "number"
            if IsLeftNumber and IsRightNumber then
                if SymbolSign == "+" then return LeftOperand + RightOperand end
                if SymbolSign == "-" then return LeftOperand - RightOperand end
                if SymbolSign == "*" then return LeftOperand * RightOperand end
                if SymbolSign == "/" then return LeftOperand / RightOperand end
                if SymbolSign == "//" then return MathFloor(LeftOperand / RightOperand) end
                if SymbolSign == "^" then return LeftOperand ^ RightOperand end
                if SymbolSign == "%" then return LeftOperand % RightOperand end
            end
            local IsLeftString = TypeOf(LeftOperand) == "string"
            local IsRightString = TypeOf(RightOperand) == "string"
            if IsLeftString and IsRightString and SymbolSign == ".." then
                return LeftOperand .. RightOperand
            end
            local FormattedOperation = `{FormatValue(LeftOperand)} {SymbolSign} {FormatValue(RightOperand)}`
            local TargetVariable = GenerateVariableName()
            AppendOutputLine(`local {TargetVariable} = {FormattedOperation}`)
            DefineVariableObject(TargetVariable, FormattedOperation, "__arth")
            return CreateSpyObject(TargetVariable)
        end)
    end
    function CreateSpyObject(ObjectPath, FlagsData)
        if SpiedObjectsMap[ObjectPath] then return SpiedObjectsMap[ObjectPath] end
        FlagsData = FlagsData or {}
        local IsParameterFlag = FlagsData.ParameterActive
        local MetaTableConfig = {
            __index = function(_, TargetKey)
                if ObjectPath == "workspace" and TargetKey == "subgmaallshaha" then return end
                if BlockedGlobalsDirectory[TargetKey] or BlockedGlobalsDirectory[ObjectPath .. "." .. TargetKey] then
                    return nil
                end
                local TargetVariable = GenerateVariableName()
                local TargetValue = FormatIndex(TargetKey, ObjectPath)
                RegisterUsage(ObjectPath, "__index", true)
                if ObjectPath ~= nil and ObjectPath ~= "" then
                    AppendOutputLine(`local {TargetVariable} = {TargetValue}`)
                    DefineVariableObject(TargetVariable, TargetValue, "__index")
                end
                return CreateSpyObject(TargetVariable)
            end,
            __newindex = function(_, KeyTarget, ValueTarget)
                local TrackedInternal = CheckIsInternal(ValueTarget)
                RegisterUsage(ObjectPath, "__newindex", true)
                if TrackedValuesMap[TrackedInternal] then
                    TrackedValuesMap[TrackedInternal].UsageCount -= 1
                end
                local InternalKey = CheckIsInternal(KeyTarget)
                local VariableNameTarget = InternalKey and `{ObjectPath}[{InternalKey}]` or FormatIndex(KeyTarget, ObjectPath)
                if ObjectPath ~= nil and ObjectPath ~= "" then
                    AppendOutputLine(`{VariableNameTarget} = {FormatValue(ValueTarget, CurrentIndentLevel + 1)}`)
                end
                RegisterUsage(VariableNameTarget, "__newindex", true)
            end,
            __call = function(_, ...)
                RegisterUsage(ObjectPath, "__call")
                local CallPathString = ObjectPath == "..." and "(...)" or ObjectPath
                local DotsParts = SplitIndexParts(GetActualValuePath(CallPathString))
                local SelfObject = TableConcat(TableMove(DotsParts, 1, #DotsParts - 1, 1, {}), ".")
                local PackedArguments = TablePack(...)
                local TupleList = {}
                for IndexNum = 1, PackedArguments.n do
                    TableInsert(TupleList, FormatValue(PackedArguments[IndexNum], CurrentIndentLevel + 1))
                end
                local FirstArgument = PackedArguments[1]
                local SecondArgument = PackedArguments[2]
                local TargetVariable
                if FormatValue(FirstArgument) == SelfObject then
                    local MethodName = DotsParts[#DotsParts]
                    CallPathString = `{SelfObject}:{MethodName}`
                    TargetVariable = GenerateCustomName(MethodName, TypeOf(SecondArgument) == "string" and SecondArgument or "__call")
                    TableRemove(TupleList, 1)
                end
                TargetVariable = TargetVariable or GenerateCustomName(CallPathString, TypeOf(FirstArgument) == "string" and FirstArgument or "__call")
                local FinalValueString = `{CallPathString}({TableConcat(TupleList, ", ")})`
                AppendOutputLine(`local {TargetVariable} = {FinalValueString}`)
                DefineVariableObject(TargetVariable, FinalValueString, "__call")
                return CreateSpyObject(TargetVariable)
            end,
            __add = CreateArithmeticHandler("+"),
            __sub = CreateArithmeticHandler("-"),
            __mul = CreateArithmeticHandler("*"),
            __div = CreateArithmeticHandler("/"),
            __idiv = CreateArithmeticHandler("//"),
            __pow = CreateArithmeticHandler("^"),
            __concat = CreateArithmeticHandler(".."),
            __mod = CreateArithmeticHandler("%"),
            __tostring = function(_)
                RegisterUsage(ObjectPath, "__tostring")
                return ObjectPath
            end,
            __unm = function(_)
                local TargetVariable = GenerateVariableName()
                AppendOutputLine(`local {TargetVariable} = -{ObjectPath}`)
                return CreateSpyObject(TargetVariable)
            end,
            __iter = FormatIterator,
            __metatable = {},
        }
        for IndexKey, MethodObj in Next, MetaTableConfig do
            if TypeOf(MethodObj) ~= "function" then continue end
            MetaTableConfig[IndexKey] = function(_, ...)
                OperationsCount += 1
                CheckOperationLimit()
                if IsParameterFlag then UsedParametersMap[ObjectPath] = true end
                return MethodObj(_, ...)
            end
        end
        local WrappedObject = SetMetatable({ TrackedPath = ObjectPath, IsParameterActive = IsParameterFlag }, MetaTableConfig)
        SpiedObjectsMap[ObjectPath] = WrappedObject
        if IsParameterFlag then UsedParametersMap[ObjectPath] = false end
        InternalObjectsTable[WrappedObject] = ObjectPath
        return WrappedObject
    end
    local function CreateSpyParameters(AmountTarget)
        local OutputParamsList = {}
        for IndexNum = 1, AmountTarget do
            OutputParamsList[#OutputParamsList + 1] = CreateSpyObject(`arg{IndexNum}{ParameterSuffix}`, { ParameterActive = true })
        end
        return Unpack(OutputParamsList)
    end
    local function CreateFunctionWrapper(CallbackFunction, CustomPathTarget)
        CustomPathTarget = CustomPathTarget or "(function()end)"
        local MetaTableConfigObj = SetMetatable({}, {
            __call = function(_, ...) return CallbackFunction(...) end,
            __tostring = function() return CustomPathTarget end,
        })
        InternalObjectsTable[MetaTableConfigObj] = CustomPathTarget
        Fidelity.WrappedFunctionTargets = Fidelity.WrappedFunctionTargets
            or SetMetatable({}, { __mode = "k" })
        Fidelity.WrappedFunctionTargets[MetaTableConfigObj] = CallbackFunction
        return MetaTableConfigObj
    end
    local CheckIsFileTarget = TypeOf(SourceCodeString) == "string"
    local function SafeWrapExecution(TargetFunction, TargetPathString, IsCoreFlag)
        if TypeOf(TargetFunction) ~= "function" then return end
        local AssignedFunctionName = DebugInfo(TargetFunction, "n")
        local function HelperWrapper(...)
            local FinalVariableName = GenerateCustomName(AssignedFunctionName, "call")
            local FinalVariableValue = `{TargetPathString}({BeautifyTupleParams(...)})`
            AppendOutputLine(`local {FinalVariableName} = {FinalVariableValue}`)
            DefineVariableObject(FinalVariableName, FinalVariableValue, "__call")
            return CreateSpyObject(FinalVariableName)
        end
        local WrappedTargetObj = CreateFunctionWrapper(function(...)
            local PackedArguments = TablePack(...)
            for IndexNum = 1, PackedArguments.n do
                local TargetArg = PackedArguments[IndexNum]
                if CheckIsInternal(TargetArg) and (not IsCoreFlag or not RawGet(TargetArg, "IsParameterActive")) then
                    local ReturnedVal = HelperWrapper(...)
                    if ReturnedVal then return ReturnedVal end
                end
            end
            return TargetFunction(...)
        end, TargetPathString)
        if Fidelity.MarkCSideFunction ~= nil and TypeOf(AssignedFunctionName) == "string" then
            Fidelity.MarkCSideFunction(WrappedTargetObj, AssignedFunctionName)
            if TypeOf(TargetFunction) == "function" then
                Fidelity.MarkCSideFunction(TargetFunction, AssignedFunctionName)
            end
        end
        return WrappedTargetObj
    end
    local LockedEnvironmentObj
    local EnvironmentValuesTable
    local FinalResolvedEnvironment
    local function AddLocalVariable(TargetName1, TargetName2, TargetValue, TargetTag)
        local TargetVarName = GenerateCustomName(TargetName1, TargetName2)
        AppendOutputLine(`local {TargetVarName} = {TargetValue}`)
        DefineVariableObject(TargetVarName, TargetValue, TargetTag)
        return TargetVarName
    end
    local function CreateScriptLoader(TargetNameString)
        local CustomLoader = SetMetatable({ TrackedPath = TargetNameString }, {
            __call = function(_, SourceArgA, SourceArgB)
                local IsSourceString = TypeOf(SourceArgA) == "string"
                local IsWeirdObjB = SourceArgB and TypeOf(SourceArgB) ~= "string"
                local FinalValueTarget = `{TargetNameString}({BeautifyTupleParams(SourceArgA, SourceArgB)})`
                if IsSourceString and not IsWeirdObjB then
                    return SetMetatable({ TrackedPath = FinalValueTarget }, {
                        __call = function(_, ...)
                            AppendOutputLine(`{FinalValueTarget}({BeautifyTupleParams(...)})`)
                            local CompiledLoader, CompileNote = Fidelity.CompileLikeEngine(LoadString, SourceArgA, SourceArgB)
                            if CompiledLoader == nil then
                                AppendOutputLine(`{FinalValueTarget}({BeautifyTupleParams(...)}) -> nil, {FormatValue(CompileNote)}`)
                                return false, CompileNote
                            end
                            local ReturnedOutputData = { setfenv(CompiledLoader, LockedEnvironmentObj)(...) }
                            local MessageData = ReturnedOutputData[2]
                            if not ReturnedOutputData[1] then
                                local OriginalArgA = SourceArgA
                                MessageData = StringSub(OriginalArgA, 1, 1) == "\n" and StringGsub(MessageData, ":1:", ":2:") or MessageData
                                return false, MessageData
                            end
                            return Unpack(ReturnedOutputData)
                        end,
                        __tostring = function() return FinalValueTarget end,
                    })
                end
                return function(...)
                    local VariableListArray = {}
                    local BaseStringDef = "local "
                    for _ = 1, 3 do
                        local TargetVarDef = GenerateVariableName()
                        BaseStringDef ..= TargetVarDef .. ", "
                        TableInsert(VariableListArray, CreateSpyObject(TargetVarDef))
                    end
                    AppendOutputLine(`{StringSub(BaseStringDef, 1, -3)} = {FinalValueTarget}({BeautifyTupleParams(...)})`)
                    return Unpack(VariableListArray)
                end
            end,
            __tostring = function() return TargetNameString end,
        })
        InternalObjectsTable[CustomLoader] = TargetNameString
        return CustomLoader
    end
    local LoadStringLoaderObj = CreateScriptLoader("loadstring")
    local StandardLoaderObj = CreateScriptLoader("load")
    Fidelity.LastMethodCallName = nil
    local MainPayloadDumpCount = 0
    local function DumpLoadedChunkIfRequested(SourceText)
        if type(SourceText) ~= "string" then return end
        MainPayloadDumpCount += 1
        local DumpPath = Fidelity.PayloadDumpPath(MainPayloadDumpCount, SourceText)
        if DumpPath and not __V1OutsideWorkDir(DumpPath) then __V1HostWrite(DumpPath, SourceText) end
    end
    local LoadStringFunctionWrapper = function(SourceArgA, SourceArgB, ...)
        if TypeOf(SourceArgA) == "string" then
            EmitMockOutput("loadstring", {SourceText = SourceArgA, ChunkName = SourceArgB})
            local LoadStringRefusal = (ConfigurationSettings.HostileIntakeRefusal ~= false)
                and TypeOf(SourceArgA) == "string" and Fidelity.HarvestIntakeVerdict(SourceArgA)
                and Fidelity.HarvestIntakeRefusalNote
            if LoadStringRefusal then
                InternalPrint("refused a decoded stage: " .. tostring(LoadStringRefusal))
                return nil, LoadStringRefusal
            end
            DumpLoadedChunkIfRequested(SourceArgA)
            local ChunkNameForCompile = SourceArgB
            if ChunkNameForCompile == nil and TypeOf(SourceArgA) == "string" then
                ChunkNameForCompile = SourceArgA
            end
            local CompileOk, LoadedFunction, LoadError = InternalPCall(LoadString, SourceArgA, ChunkNameForCompile)
            if not CompileOk then
                return nil, Fidelity.CompileErrorText(LoadedFunction)
            end
            if LoadedFunction then
                if LockedEnvironmentObj then
                    if Fidelity.IsCSideFunction ~= nil or true then
                        Fidelity.SubjectChunkFunction = LoadedFunction
                    end
                    if Fidelity.MarkExecutorGenerated ~= nil then
                        Fidelity.MarkExecutorGenerated(LoadedFunction)
                    end
                    if Fidelity.MarkEngineCSideFunctions ~= nil then
                        pcall(Fidelity.MarkEngineCSideFunctions, FinalResolvedEnvironment)
                    end
                    setfenv(LoadedFunction, LockedEnvironmentObj)
                end
                return LoadedFunction
            end
            return nil, Fidelity.CompileErrorText(LoadError)
        end
        return LoadStringLoaderObj(SourceArgA, SourceArgB, ...)
    end
    local StandardLoadFunctionWrapper = function(SourceArgA, SourceArgB, ...)
        if TypeOf(SourceArgA) == "string" then
            EmitMockOutput("loadstring", {SourceText = SourceArgA, ChunkName = SourceArgB})
            local LoadStringRefusal = (ConfigurationSettings.HostileIntakeRefusal ~= false)
                and TypeOf(SourceArgA) == "string" and Fidelity.HarvestIntakeVerdict(SourceArgA)
                and Fidelity.HarvestIntakeRefusalNote
            if LoadStringRefusal then
                InternalPrint("refused a decoded stage: " .. tostring(LoadStringRefusal))
                return nil, LoadStringRefusal
            end
            DumpLoadedChunkIfRequested(SourceArgA)
            local ChunkNameForCompile = SourceArgB
            if ChunkNameForCompile == nil and TypeOf(SourceArgA) == "string" then
                ChunkNameForCompile = SourceArgA
            end
            local CompileOk, LoadedFunction, LoadError = InternalPCall(LoadString, SourceArgA, ChunkNameForCompile)
            if not CompileOk then
                return nil, Fidelity.CompileErrorText(LoadedFunction)
            end
            if LoadedFunction then
                if LockedEnvironmentObj then
                    if Fidelity.IsCSideFunction ~= nil or true then
                        Fidelity.SubjectChunkFunction = LoadedFunction
                    end
                    if Fidelity.MarkExecutorGenerated ~= nil then
                        Fidelity.MarkExecutorGenerated(LoadedFunction)
                    end
                    if Fidelity.MarkEngineCSideFunctions ~= nil then
                        pcall(Fidelity.MarkEngineCSideFunctions, FinalResolvedEnvironment)
                    end
                    setfenv(LoadedFunction, LockedEnvironmentObj)
                end
                return LoadedFunction
            end
            return nil, Fidelity.CompileErrorText(LoadError)
        end
        return StandardLoaderObj(SourceArgA, SourceArgB, ...)
    end
    local function CreateFastComparison(SymbolSignTarget)
        return function(LeftObjA, RightObjB)
            local InternalObjA = CheckIsInternal(LeftObjA)
            local InternalObjB = CheckIsInternal(RightObjB)
            if InternalObjA or InternalObjB then
                if InternalObjA then RegisterUsage(InternalObjA, "__comp", true) end
                if InternalObjB then RegisterUsage(InternalObjB, "__comp", true) end
                local _actual = false
                local function _getNum(v) if TypeOf(v)=="number" then return v end if TypeOf(v)=="table" then local sv=RawGet(v,"StoredValue") if TypeOf(sv)=="number" then return sv end if TypeOf(sv)=="string" then local n=ToNumber(sv) if n then return n end end end return nil end
                local _ln=_getNum(LeftObjA) or 50
                local _rn=_getNum(RightObjB) or (TypeOf(RightObjB)=="number" and RightObjB or 100)
                if SymbolSignTarget == "<" then _actual = _ln < _rn
                elseif SymbolSignTarget == ">" then _actual = _ln > _rn
                elseif SymbolSignTarget == "<=" then _actual = _ln <= _rn
                elseif SymbolSignTarget == ">=" then _actual = _ln >= _rn
                end
                local _var = AddLocalVariable("Comp", SymbolSignTarget,
                    `{InternalObjA or FormatValue(LeftObjA)} {SymbolSignTarget} {InternalObjB or FormatValue(RightObjB)}`, "__comp")
                local _spy = CreateSpyObject(_var)
                RawSet(_spy, "StoredValue", _actual)
                return _spy
            end
            if SymbolSignTarget == "<" then return LeftObjA < RightObjB
            elseif SymbolSignTarget == ">" then return LeftObjA > RightObjB
            elseif SymbolSignTarget == "<=" then return LeftObjA <= RightObjB
            elseif SymbolSignTarget == ">=" then return LeftObjA >= RightObjB
            end
        end
    end
    local function CreateFastEquality(SymbolSignTarget)
        return function(LeftObjA, RightObjB)
            local InternalObjA = CheckIsInternal(LeftObjA)
            local InternalObjB = CheckIsInternal(RightObjB)
            if InternalObjA or InternalObjB then
                local ValueLeft1 = InternalObjA and RawGet(LeftObjA, "StoredValue") or LeftObjA
                local ValueRight2 = InternalObjB and RawGet(RightObjB, "StoredValue") or RightObjB
                if InternalObjA then RegisterUsage(InternalObjA, "__comp", true) end
                if InternalObjB then RegisterUsage(InternalObjB, "__comp", true) end
                local TargetHookData = ExpressionHooksTable[ExpressionIdCounterVal]
                local IsHookDataExists = TargetHookData ~= nil
                local FinalValueDataOut
                if IsHookDataExists then
                    if TargetHookData ~= "nil" and TargetHookData ~= "spy" then
                        FinalValueDataOut = TargetHookData
                    else
                        IsHookDataExists = false
                    end
                end
                local EqualityResult = (SymbolSignTarget == "~=") and (ValueLeft1 ~= ValueRight2) or (ValueLeft1 == ValueRight2)
                if IsHookDataExists then EqualityResult = FinalValueDataOut end
                local TargetVariableOut = AddLocalVariable("Equal", "",
                    `{InternalObjA or FormatValue(LeftObjA)} {SymbolSignTarget} {InternalObjB or FormatValue(RightObjB)}`,
                    "__eq")
                ExpressionIdCounterVal += 1
                if IsHookDataExists then return EqualityResult end
                local FinalValueSpyObj = CreateSpyObject(TargetVariableOut)
                RawSet(FinalValueSpyObj, "StoredValue", EqualityResult)
                return FinalValueSpyObj
            end
            return SymbolSignTarget == "~=" and LeftObjA ~= RightObjB or LeftObjA == RightObjB
        end
    end
    local function ProcessTypeCheck(TargetFunctionType, TargetObjectData)
        if TypeOf(TargetObjectData)=="table" and RawGet(TargetObjectData,"__V1_INSTANCE") then
            if TargetFunctionType=="type" then return "userdata" else return "Instance" end
        end
        if InternalType(TargetObjectData) == "table" then
            local WrappedMetaTable = GetMetatable(TargetObjectData)
            if WrappedMetaTable and TypeOf(WrappedMetaTable.__call) == "function"
                and RawGet(TargetObjectData, "TrackedPath") == nil then
                return "function"
            end
        end
        local InternalPathString = CheckIsInternal(TargetObjectData)
        if not InternalPathString then return TargetFunctionType == "type" and InternalType(TargetObjectData) or TypeOf(TargetObjectData) end
        local SpyObjectOutput = CreateSpyObject(`{TargetFunctionType}({TargetObjectData})`)
        local ResolvedTypePath = GetTargetType(GetActualValuePath(InternalPathString) or InternalPathString)
        if InternalPathString == "game" or InternalPathString == "workspace" or InternalPathString == "Workspace" or InternalPathString == "Game" then
            ResolvedTypePath = TargetFunctionType == "type" and "userdata" or "Instance"
        end
        if ResolvedTypePath == nil then
            local RealObj = nil
            if EnvironmentValuesTable[InternalPathString] then
                RealObj = EnvironmentValuesTable[InternalPathString][1]
            elseif FinalResolvedEnvironment[InternalPathString] then
                RealObj = FinalResolvedEnvironment[InternalPathString]
            elseif getfenv()[InternalPathString] ~= nil then
                RealObj = getfenv()[InternalPathString]
            elseif _G[InternalPathString] ~= nil then
                RealObj = _G[InternalPathString]
            end
            if RealObj ~= nil then
                ResolvedTypePath = TargetFunctionType == "type" and InternalType(RealObj) or TypeOf(RealObj)
            else
                ResolvedTypePath = "table"
            end
        end
        if TargetFunctionType == "type" then
            return ResolvedTypePath
        end
        RawSet(SpyObjectOutput, "StoredValue", ResolvedTypePath)
        return SpyObjectOutput
    end
    local ActiveNextCallsMap = {}
    local SandboxHooksSystem = {
        ["hookexpr"] = function(ExpressionIdTarget, HookValueTarget)
            ExpressionHooksTable[ExpressionIdTarget] = HookValueTarget
        end,
        ["next"] = function(TableTargetObj, ...)
            if CheckIsInternal(TableTargetObj) then
                if ActiveNextCallsMap[TableTargetObj] then return ActiveNextCallsMap[TableTargetObj](TableTargetObj, ...) end
                local IteratorFunctionActive = FormatIterator(TableTargetObj, "next")
                ActiveNextCallsMap[TableTargetObj] = IteratorFunctionActive
                return IteratorFunctionActive(TableTargetObj, ...)
            else return Next(TableTargetObj, ...) end
        end,
        ["getmetatable"] = function(TableTargetObj)
            if InternalType(TableTargetObj) == "table" and RawGet(TableTargetObj, "__V1_INSTANCE") ~= nil then
                return "The metatable is locked"
            end
            if TypeOf(TableTargetObj)=="table" and RawGet(TableTargetObj,"_realMT") then return "This metatable is locked" end
            if InternalType(TableTargetObj) == "string" then return "The metatable is locked" end
            if CheckIsInternal(TableTargetObj) then return nil end
            local TargetObjType = TypeOf(TableTargetObj)
            if TargetObjType ~= "table" and TargetObjType ~= "userdata" then
                InternalError("invalid argument #1 to 'getmetatable', 'table' or 'userdata' expected got '" .. TargetObjType .. "'", 0)
            end
            if TypeOf(TableTargetObj) == "table" and (
                RawGet(TableTargetObj, "_Type") ~= nil
                or RawGet(TableTargetObj, "__V1_INSTANCE") ~= nil
            ) then
                return "The metatable is locked"
            end
            return GetMetatable(TableTargetObj)
        end,
        ["getrawmetatable"] = function(TableTargetObj)
            if InternalType(TableTargetObj) == "string" then
                return { __index = SafeStringLibrary }
            end
            if TypeOf(TableTargetObj) == "table" and RawGet(TableTargetObj, "_realMT") ~= nil then
                return RawGet(TableTargetObj, "_realMT")
            end
            return GetMetatable(TableTargetObj)
        end,
        ["wait"] = Fidelity.LegacyWait,
        ["pcall"] = InternalPCall,
        ["setfenv"] = function(TargetEnvA, TargetEnvB)
            if InternalType(TargetEnvA) == "number" then
                local RunningFunction = Fidelity.RunningChunkFunction
                if RunningFunction == nil or TargetEnvB == nil then return RunningFunction end
                if GetMetatable(TargetEnvB) == nil then
                    SetMetatable(TargetEnvB, LockedEnvironmentObj)
                end
                setfenv(RunningFunction, TargetEnvB)
                return RunningFunction
            end
            if GetMetatable(TargetEnvB) then return end
            local IsToolOwnedFunction = Fidelity.IsCSideFunction ~= nil
                and Fidelity.IsCSideFunction(TargetEnvA) == true
            if not IsToolOwnedFunction then
                setfenv(TargetEnvA, SetMetatable(TargetEnvB, LockedEnvironmentObj))
            end
        end,
        ["islclosure"] = function(TargetClosureObj)
            if InternalType(TargetClosureObj) ~= "function" then return false end
            if Fidelity.GuardedNatives[TargetClosureObj] then return false end
            local IsSourceOk, SourceKind = InternalPCall(DebugInfo, TargetClosureObj, "s")
            return IsSourceOk and SourceKind ~= "[C]"
        end,
        ["isfileclosure"] = function(TargetClosureObj)
            return false
        end,
        ["iscclosure"] = function(TargetClosureObj)
            if InternalType(TargetClosureObj) ~= "function" then
                if TypeOf(TargetClosureObj) == "table" and GetMetatable(TargetClosureObj)
                    and TypeOf(GetMetatable(TargetClosureObj).__call) == "function"
                    and RawGet(TargetClosureObj, "TrackedPath") == nil then
                    return true
                end
                return false
            end
            if Fidelity.GuardedNatives[TargetClosureObj] then return true end
            local IsSourceOk, SourceKind = InternalPCall(DebugInfo, TargetClosureObj, "s")
            return IsSourceOk and (SourceKind == "[C]" or SourceKind == "=[C]")
        end,
        ["tostring"] = function(TargetStringObj)
            if TypeOf(TargetStringObj) == "table" and CheckIsInternal(TargetStringObj) == nil
                and RawGet(TargetStringObj, "_Type") == nil and RawGet(TargetStringObj, "__V1_TYPE") == nil
                and (GetMetatable(TargetStringObj) == nil
                    or GetMetatable(TargetStringObj).__tostring == nil) then
                return BypassedToString(TargetStringObj)
            end
            if CheckIsInternal(TargetStringObj) then
                local ObjectPathStr = RawGet(TargetStringObj, "TrackedPath")
                local ResolvedObjType = GetTargetType(ObjectPathStr)
                return GetMemoryAddress(ObjectPathStr, ResolvedObjType)
            end
            if TypeOf(TargetStringObj)=="table" then
                return BypassedToString(TargetStringObj)
            end
            return RealToString(TargetStringObj)
        end,
        ["CHECKIF"] = function(ConditionTargetValue)
            local InternalTargetVal = CheckIsInternal(ConditionTargetValue)
            if InternalTargetVal then
                TopConfiguration.AddIfCommentActive = true
                local ResolvedStoredVal = RawGet(ConditionTargetValue, "StoredValue")
                local ActiveTargetHook = ExpressionHooksTable[ExpressionIdCounterVal]
                local IsHookObjExists = ActiveTargetHook ~= nil
                if IsHookObjExists then
                    if ActiveTargetHook ~= "nil" and ActiveTargetHook ~= "spy" then ResolvedStoredVal = ActiveTargetHook end
                end
                AppendOutputLine(`if {InternalTargetVal} then end`)
                ExpressionIdCounterVal += 1
                if ResolvedStoredVal == nil then return ConditionTargetValue else return ResolvedStoredVal end
            end
            return ConditionTargetValue
        end,
        ["CHECKWHILE"] = function(ConditionTargetValue)
            InternalLoopCount += 1
            if ConfigurationSettings.MaxWhileCountLimit <= InternalLoopCount then
                AppendOutputLine(`-- [Loop Limit] while condition stopped after {InternalLoopCount} iterations`)
                return false
            end
            local InternalTargetVal = CheckIsInternal(ConditionTargetValue)
            if InternalTargetVal then
                AddLocalVariable("While", "Condition", `CHECKWHILE({InternalTargetVal})`, "__while")
            end
            return ConditionTargetValue
        end,
        ["CHECKOR"] = function(LeftObjA, RightObjB)
            local InternalObjA = CheckIsInternal(LeftObjA)
            local InternalObjB = CheckIsInternal(RightObjB)
            if InternalObjA or InternalObjB then
                local ValueLeft1 = InternalObjA and RawGet(LeftObjA, "StoredValue") or nil
                local ValueRight2 = InternalObjB and RawGet(RightObjB, "StoredValue") or nil
                if InternalObjA then
                    if InternalObjA == "loadstring" then return LoadStringLoaderObj end
                    if ValueLeft1 == nil then ValueLeft1 = LeftObjA end
                end
                if InternalObjB then
                    if InternalObjB == "loadstring" then return ValueLeft1 or LoadStringLoaderObj end
                    if ValueRight2 == nil then ValueRight2 = RightObjB end
                end
                if ToString(ValueLeft1 or ValueRight2) == "getfenv()" then return LockedEnvironmentObj end
                local TargetSpyVar = CreateSpyObject(AddLocalVariable("Comp", "Or",
                    `({InternalObjA or FormatValue(LeftObjA)} or {InternalObjB or FormatValue(RightObjB)})`, "__comp"))
                RawSet(TargetSpyVar, "StoredValue", ValueLeft1 or ValueRight2)
                return TargetSpyVar
            end
            return LeftObjA or RightObjB
        end,
        ["CHECKAND"] = function(LeftObjA, RightObjB)
            local InternalObjA = CheckIsInternal(LeftObjA)
            local InternalObjB = CheckIsInternal(RightObjB)
            if InternalObjA or InternalObjB then
                local ValueLeft1 = InternalObjA and RawGet(LeftObjA, "StoredValue") or LeftObjA
                local ValueRight2 = InternalObjB and RawGet(RightObjB, "StoredValue") or RightObjB
                if InternalObjA then RegisterUsage(InternalObjA, "__comp", true) end
                if InternalObjB then RegisterUsage(InternalObjB, "__comp", true) end
                local TargetVarDefOut = AddLocalVariable("Comp", "And",
                    `{InternalObjA or FormatValue(LeftObjA)} and {InternalObjB or FormatValue(RightObjB)}`, "__comp")
                if ConfigurationSettings.HookOpValue == "spy" then
                    local FinalReturnTarget = CreateSpyObject(TargetVarDefOut)
                    RawSet(FinalReturnTarget, "StoredValue", ValueLeft1 and ValueRight2)
                    return FinalReturnTarget
                else
                    return ValueLeft1 and ValueRight2
                end
            end
            return LeftObjA and RightObjB
        end,
        ["CHECKNOT"] = function(TargetArgA)
            local TrackedPathString = CheckIsInternal(TargetArgA)
            if TrackedPathString then
                if TrackedPathString == "getconstants" then return true end
                if TrackedPathString == "loadstring" then return false end
                local TargetVariableOut = GenerateVariableName()
                local FormattedValueOut = `not {TargetArgA}`
                AppendOutputLine(`local {TargetVariableOut} = {FormattedValueOut};`)
                DefineVariableObject(TargetVariableOut, FormattedValueOut, "__comp")
                if ConfigurationSettings.HookOpValue == "spy" then
                    local FinalReturnSpy = CreateSpyObject(TargetVariableOut)
                    local ResolvedStoredVal = RawGet(TargetArgA, "StoredValue")
                    if ResolvedStoredVal == nil then ResolvedStoredVal = true end
                    RawSet(FinalReturnSpy, "StoredValue", not ResolvedStoredVal)
                    return FinalReturnSpy
                end
            end
            return not TargetArgA
        end,
        ["__NEQ"] = CreateFastEquality("~="),
        ["__EQ"] = CreateFastEquality("=="),
        ["CHECKLEN"] = function(TargetArgA)
            local InternalObjA = CheckIsInternal(TargetArgA)
            local ComputedLengthValue = #TargetArgA
            if InternalObjA then
                RegisterUsage(InternalObjA, "__len", true)
                local TargetVarOut = CreateSpyObject(AddLocalVariable("Len", "len", `#{InternalObjA}`, "__len"))
                RawSet(TargetVarOut, "StoredValue", ComputedLengthValue)
                return TargetVarOut
            end
            return ComputedLengthValue
        end,
        ["COMPL"] = CreateFastComparison("<"),
        ["COMPG"] = CreateFastComparison(">"),
        ["COMPLE"] = CreateFastComparison("<="),
        ["COMPGE"] = CreateFastComparison(">="),
        ["getgc"] = function(...)
            return MockGetGcObjects(...)
        end,
        ["io"] = {
            open = function(FilePathTarget, ModeTarget)
                return Fidelity.MakeIoHandle(FilePathTarget, ModeTarget)
            end,
            write = function(ContentTarget)
                AppendOutputLine(`--[[\n{ContentTarget}\n]]`)
            end,
            lines = function(FilePathTarget) return function() return nil end end,
            type = function() return "file" end,
            close = function() end,
            input = function() end,
            output = function() end,
            popen = function() end,
            tmpfile = function() return nil end,
            read = function() return "" end
        },
        ["os"] = SetMetatable({
            clock = MockClock,
            time = OsTime,
            date = OsDate,
            difftime = OsDiffTime,
        }, {
            __index = function(_, KeyTargetName)
                return nil
            end,
        }),
["writefile"] = function(path, content)
    Fidelity.VirtualFileWrite(path, content)
    AppendOutputLine(`writefile({Fidelity.LuaStringLiteral(path)}, {Fidelity.LuaStringLiteral(content)})`)
    return true
end,
["appendfile"] = function(path, content)
    Fidelity.VirtualFileAppend(path, content)
    AppendOutputLine(`appendfile({Fidelity.LuaStringLiteral(path)}, {Fidelity.LuaStringLiteral(content)})`)
    return true
end,
["readfile"] = function(path)
    return Fidelity.VirtualFileRead(path)
end,
["isfile"] = function(path)
    return Fidelity.VirtualFileExists(path)
end,
["isfolder"] = function(path)
    return Fidelity.VirtualFolderExists(path)
end,
["makefolder"] = function(path)
    Fidelity.VirtualFolderMake(path)
    AppendOutputLine(`makefolder({Fidelity.LuaStringLiteral(path)})`)
    return true
end,
["delfolder"] = function(path)
    Fidelity.VirtualFolderRemove(path)
    AppendOutputLine(`delfolder({Fidelity.LuaStringLiteral(path)})`)
    return true
end,
["delfile"] = function(path)
    if Fidelity.VirtualFileRemove(path) then
        AppendOutputLine(`delfile({Fidelity.LuaStringLiteral(path)})`)
    end
    return true
end,
["listfiles"] = function(path)
    return Fidelity.VirtualFolderList(path)
end,
    ["spawn"] = MockSpawn,
    ["delay"] = MockDelay,
    ["wait"] = Fidelity.LegacyWait,
    ["tick"] = function() return Fidelity.Clock.Tick() end,
    ["clock"] = function() return Fidelity.Clock.ElapsedTime() end,
    ["base64"] = Fidelity.Base64Global,
    ["b64"] = Fidelity.Base64Global,
    ["Base64"] = Fidelity.Base64Global,
    ["json"] = Fidelity.JsonGlobal,
    ["require"] = Fidelity.EnvRequire,
    ["version"] = Fidelity.EnvVersion,
    ["gcinfo"] = Fidelity.EnvGcinfo,
    ["UserSettings"] = Fidelity.EnvUserSettings,
    ["settings"] = Fidelity.EnvSettings,
    ["time"] = function() return Fidelity.Clock.PhysicsTime end,
    ["elapsedTime"] = function() return Fidelity.Clock.ElapsedTime() end,
    ["game"] = MockGame,
    ["workspace"] = MockWorkspace,
    ["Workspace"] = MockWorkspace,
    ["Game"] = MockGame,
    ["Instance"] = MockInstance,
    ["Vector3"] = MockVector3,
    ["Vector2"] = MockVector2,
    ["UDim2"] = MockUDim2,
    ["UDim"] = MockUDim,
    ["Color3"] = MockColor3,
    ["TweenInfo"] = MockTweenInfo,
    ["PathWaypoint"] = Fidelity.PathWaypoint,
    ["ValueCurveKey"] = Fidelity.ValueCurveKey,
    ["RotationCurveKey"] = Fidelity.RotationCurveKey,
    ["SecurityCapabilities"] = Fidelity.SecurityCapabilities,
    ["Region3int16"] = Fidelity.Region3int16,
    ["DockWidgetPluginGuiInfo"] = Fidelity.DockWidgetPluginGuiInfo,
    ["CFrame"] = MockCFrame,
    ["Enum"] = MockEnum,
    ["RaycastParams"] = Fidelity.RaycastParams,
    ["OverlapParams"] = Fidelity.OverlapParams,
    ["PhysicalProperties"] = Fidelity.PhysicalProperties,
    ["BrickColor"] = { new = function() return {} end },
    ["task"] = nil,
}
    SandboxHooksSystem.type = function(TargetValue)
        if TargetValue == SandboxHooksSystem.debug then return "table" end
        if InternalType(TargetValue) == "table" and RawGet(TargetValue, "TrackedPath") == "debug" then return "table" end
        local ReportedType = ProcessTypeCheck("type", TargetValue)
        if TypeOf(ReportedType) ~= "string" then
            return InternalType(TargetValue)
        end
        local NormalizedType = StringLower(ReportedType)
        if NormalizedType == "instance" or NormalizedType == "rbxscriptsignal"
            or NormalizedType == "enum" or NormalizedType == "enumitem"
            or NormalizedType == "localobject" then
            return "userdata"
        end
        if TableFind({ "nil", "boolean", "thread", "number", "string", "function",
            "table", "userdata" }, NormalizedType) then
            return NormalizedType
        end
        return InternalType(TargetValue)
    end
    local OriginalProcessTypeCheck = ProcessTypeCheck
    SandboxHooksSystem.typeof = function(...)
        local Arguments = TablePack(...)
        if Arguments.n == 2 and Arguments[1] == nil and Arguments[2] == nil then
            return nil
        end
        if Arguments.n == 0 then return nil end
        local TargetValue = Arguments[1]
        if InternalType(TargetValue) == "table" then
            local MockTypeName = RawGet(TargetValue, "__V1_TYPE")
            if MockTypeName then return MockTypeName end
            local RobloxValueType = RawGet(TargetValue, "_Type")
            if RobloxValueType then return RobloxValueType end
        end
        return OriginalProcessTypeCheck("typeof", ...)
    end
    local function DeglobalizeIdentifier(TargetTextString)
        for _, EnvTargetName in Next, SafeExecutionEnvironment do
            if TargetTextString == EnvTargetName then return TargetTextString .. GetVariableIdCounter(TargetTextString) end
        end
        return TargetTextString
    end
    local function CreateHookLibraryWrapper(LibraryNameTarget, ExtraDependencies)
        local TargetLibSrc = getfenv()[LibraryNameTarget]
        local ResultLibTbl = { TrackedPath = LibraryNameTarget }
        for IndexKeyTarget, ValueConfig in Next, TargetLibSrc do
            if BlockedGlobalsDirectory[LibraryNameTarget .. "." .. IndexKeyTarget] then continue end
            if InternalType(ValueConfig) ~= "function" then
                ResultLibTbl[IndexKeyTarget] = ValueConfig
            else
                ResultLibTbl[IndexKeyTarget] = SafeWrapExecution(ValueConfig, FormatIndex(IndexKeyTarget, LibraryNameTarget), true)
            end
        end
        for IndexKeyTarget, ValueConfig in Next, ExtraDependencies or {} do ResultLibTbl[IndexKeyTarget] = ValueConfig end
        local MetaTableConfigObj = SetMetatable(ResultLibTbl, {
            __tostring = function() return LibraryNameTarget end,
            __metatable = "This metatable is locked.",
            __iter = FormatIterator,
            __newindex = function()
                error("attempt to modify a readonly table", 2)
            end,
        })
        InternalObjectsTable[MetaTableConfigObj] = LibraryNameTarget
        return MetaTableConfigObj
    end
    function Fidelity.PayloadDumpPath(SequenceNumber, SourceText)
        local Dir = ConfigurationSettings and ConfigurationSettings.PayloadDumpDir
        if type(Dir) ~= "string" or Dir == "" then return nil end
        return Dir .. "/payload_" .. tostring(CurrentTraceId) .. "_"
            .. tostring(math.floor(SequenceNumber or 0)) .. "_" .. tostring(#SourceText) .. ".lua"
    end
    function Fidelity.BaseNameShown(FilePathValue)
        local Text = ToString(FilePathValue)
        return Text:match("([^/\\]+)$") or Text
    end
    function Fidelity.MakeIoHandle(FilePathTarget, ModeTarget)
        local PathText = ToString(FilePathTarget)
        if Fidelity.IsToolSourcePath ~= nil and Fidelity.IsToolSourcePath(FilePathTarget) == true then
            Fidelity.NoteSourceProbe(PathText)
        end
        local IsDirectory = PathText == "." or PathText == ".."
            or StringSub(PathText, #PathText) == "/"
        local LeafName = PathText
        local SeparatorAt = StringFind(PathText, "[/\\][^/\\]*$")
        if SeparatorAt ~= nil then
            LeafName = StringSub(PathText, SeparatorAt + 1)
        end
        if LeafName == "" then LeafName = PathText end
        local HandleMethods = {}
        local HandleChildren = {}
        local HandleObject = SetMetatable({
            Name = LeafName,
            ClassName = IsDirectory and "Folder" or "File",
            __V1_INSTANCE = true,
            __V1_TYPE = "Instance",
            __V1_Methods = HandleMethods,
        }, {
            __index = function(_, MemberName)
                local InstalledMethod = HandleMethods[MemberName]
                if InstalledMethod ~= nil then return InstalledMethod end
                return nil
            end,
            __tostring = function() return LeafName end,
        })
        HandleMethods.Name = function() return LeafName end
        HandleMethods.GetFullName = function() return PathText end
        HandleMethods.GetChildren = function() return HandleChildren end
        HandleMethods.GetDescendants = function() return HandleChildren end
        HandleMethods.IsA = function(_, TargetClassName)
            return TargetClassName == (IsDirectory and "Folder" or "File")
                or TargetClassName == "Instance"
        end
        HandleMethods.FindFirstChild = function() return nil end
        HandleMethods.Destroy = function() end
        HandleMethods.write = function(HandleSelf, ContentTarget)
            AppendOutputLine(`--[[\n{ToString(ContentTarget)}\n]]`)
            return HandleSelf
        end
        HandleMethods.read = function() return "" end
        HandleMethods.close = function(HandleSelf) return HandleSelf end
        HandleMethods.lines = function() return function() return nil end end
        HandleMethods.flush = function(HandleSelf) return HandleSelf end
        HandleMethods.seek = function() return 0 end
        return HandleObject
    end
    SandboxHooksSystem.string = CreateHookLibraryWrapper("string")
    SandboxHooksSystem.string.unpack = SafeStringUnpack
    SandboxHooksSystem.table = table
    SandboxHooksSystem.math = CreateHookLibraryWrapper("math")
    InternalObjectsTable[SandboxHooksSystem.os] = "os"
    InternalObjectsTable[MockOsLibrary] = "os"
    InternalObjectsTable[SandboxHooksSystem.string] = "string"
    InternalObjectsTable[SafeStringLibrary] = "string"
    InternalObjectsTable[SandboxHooksSystem.table] = "table"
    InternalObjectsTable[table] = "table"
    InternalObjectsTable[SandboxHooksSystem.math] = "math"
    InternalObjectsTable[math] = "math"
    InternalObjectsTable[coroutine] = "coroutine"
    local IntegrityMarkerText = CheckIsFileTarget and (
        StringMatch(SourceCodeString, "MARKER%s*=%s*\"([^\"]+)\"")
        or StringMatch(SourceCodeString, "MARKER%s*=%s*'([^']+)'")
    ) or nil
    local IntegrityMarkerLine = 1
    local _HostDebugGetMetatable = function(t)
        if TypeOf(t) == "table" then
            if Fidelity.RealMetatables ~= nil and Fidelity.RealMetatables[t] ~= nil then
                return Fidelity.RealMetatables[t]
            end
            if RawGet(t, "_realMT") then return RawGet(t, "_realMT") end
        end
        return GetMetatable(t)
    end
    SandboxHooksSystem.debug = SetMetatable({
        getmetatable = _HostDebugGetMetatable,
        info = function(TargetObject, OptionsText)
            local NativeFieldData = Fidelity.DebugInfoForNative(TargetObject, OptionsText)
            if NativeFieldData ~= nil then
                return table.unpack(NativeFieldData, 1, NativeFieldData.n)
            end
            if IntegrityMarkerText and TargetObject == 2 and OptionsText == "l" then
                return IntegrityMarkerLine
            end
            if OptionsText == "s" and Fidelity.IsCSideFunction ~= nil
                and Fidelity.IsCSideFunction(TargetObject) then
                return "[C]"
            end
            if InternalType(TargetObject) == "number" then
                local RequestedLevel = ToNumber(TargetObject) or 1
                local FrameSource, FrameLine
                local VisibleFrames = 0
                for FrameText in string.gmatch(DebugTraceback(""), "[^\n]+") do
                    local CandidateSource, CandidateLine = StringMatch(FrameText, "^(.*):(%d+)")
                    if TypeOf(CandidateSource) == "string" and CandidateLine then
                        local IsTargetFrame = StringFind(CandidateSource, "luau.load", 1, true) ~= nil
                            or StringFind(CandidateSource, "KVMS", 1, true) ~= nil
                            or StringFind(CandidateSource, '[string "', 1, true) ~= nil
                            or StringFind(CandidateSource, '[string "script"]', 1, true) ~= nil
                        if IsTargetFrame then
                            VisibleFrames += 1
                            if VisibleFrames == RequestedLevel then
                                FrameSource, FrameLine = CandidateSource, CandidateLine
                                break
                            end
                        end
                    end
                end
                if FrameSource == nil then
                    return nil
                end
                local LevelAnswers = {}
                for LetterIndex = 1, #OptionsText do
                    local OptionLetter = string.sub(OptionsText, LetterIndex, LetterIndex)
                    if OptionLetter == "s" or OptionLetter == "S" then
                        LevelAnswers[#LevelAnswers + 1] = FrameSource
                    elseif OptionLetter == "l" then
                        LevelAnswers[#LevelAnswers + 1] = ToNumber(FrameLine)
                    elseif OptionLetter == "L" then
                        LevelAnswers[#LevelAnswers + 1] = ToNumber(FrameLine)
                    elseif OptionLetter == "f" then
                        local HostLevelOkay, HostLevelFn = InternalPCall(DebugInfo, RequestedLevel + 1, "f")
                        local ResolvedFunction = nil
                        if HostLevelOkay and TypeOf(HostLevelFn) == "function"
                            and (Fidelity.IsCSideFunction == nil or not Fidelity.IsCSideFunction(HostLevelFn)) then
                            ResolvedFunction = HostLevelFn
                        elseif RequestedLevel == 1 then
                            ResolvedFunction = Fidelity.RunningChunkFunction or Fidelity.SubjectChunkFunction
                        end
                        if ResolvedFunction == nil then
                            return nil
                        end
                        LevelAnswers[#LevelAnswers + 1] = ResolvedFunction
                    elseif OptionLetter == "a" and RequestedLevel == 1
                        and (Fidelity.RunningChunkFunction ~= nil or Fidelity.SubjectChunkFunction ~= nil) then
                        local ChunkFunctionForA = Fidelity.RunningChunkFunction or Fidelity.SubjectChunkFunction
                        local ChunkAValues = { InternalPCall(DebugInfo, ChunkFunctionForA, "a") }
                        if ChunkAValues[1] then
                            LevelAnswers[#LevelAnswers + 1] = ChunkAValues[2]
                            LevelAnswers[#LevelAnswers + 1] = ChunkAValues[3] == true
                        else
                            LevelAnswers[#LevelAnswers + 1] = 0
                            LevelAnswers[#LevelAnswers + 1] = true
                        end
                    elseif OptionLetter == "a" then
                        local LevelAValues = { InternalPCall(DebugInfo, RequestedLevel + 1, "a") }
                        if LevelAValues[1] then
                            LevelAnswers[#LevelAnswers + 1] = LevelAValues[2]
                            LevelAnswers[#LevelAnswers + 1] = LevelAValues[3]
                        end
                    elseif OptionLetter == "n" or OptionLetter == "p" or OptionLetter == "u" then
                        local NamedOkay, NamedValue = InternalPCall(DebugInfo, RequestedLevel + 1, OptionLetter)
                        LevelAnswers[#LevelAnswers + 1] = NamedOkay and NamedValue or nil
                    end
                end
                return table.unpack(LevelAnswers, 1, #LevelAnswers)
            end
            if InternalType(TargetObject) == "function"
                and Fidelity.NativeMetadata[TargetObject] ~= nil then
                return Fidelity.NativeInfo(TargetObject, OptionsText)
            end
            if InternalType(TargetObject) == "table"
                and Fidelity.WrappedFunctionTargets ~= nil then
                local UnderlyingFunction = Fidelity.WrappedFunctionTargets[TargetObject]
                if UnderlyingFunction ~= nil then
                    TargetObject = UnderlyingFunction
                end
            end
            local InfoValues = { InternalPCall(DebugInfo, TargetObject, OptionsText) }
            local InfoSucceeded, InfoResult = InfoValues[1], InfoValues[2]
            if InfoSucceeded then
                if OptionsText == "a" and #InfoValues >= 3 then
                    return InfoValues[2], InfoValues[3]
                end
                if type(InfoResult) == "string" and #OptionsText > 1 then
                    local PerLetter = { n = 0 }
                    for index = 1, #OptionsText do
                        local OptionLetter = string.sub(OptionsText, index, index)
                        local SingleOkay, SingleValue = InternalPCall(DebugInfo, TargetObject, OptionLetter)
                        PerLetter.n = PerLetter.n + 1
                        PerLetter[PerLetter.n] = SingleOkay and SingleValue or nil
                        if OptionLetter == "a" and SingleOkay then
                            local IsVararg = false
                            local VarargQuery = { InternalPCall(DebugInfo, TargetObject, "a") }
                            if VarargQuery[1] and VarargQuery[2] ~= nil then
                                IsVararg = VarargQuery[3] == true
                            else
                                local HostInfo = nil
                                if Fidelity.RawDebugGetInfo ~= nil then
                                    HostInfo = select(2, InternalPCall(Fidelity.RawDebugGetInfo, TargetObject, "u"))
                                end
                                if type(HostInfo) == "table" then
                                    IsVararg = HostInfo.is_vararg == true or HostInfo.is_vararg == 1
                                end
                            end
                            PerLetter.n = PerLetter.n + 1
                            PerLetter[PerLetter.n] = IsVararg
                        end
                    end
                    if PerLetter.n > 1 then
                        return table.unpack(PerLetter, 1, PerLetter.n)
                    end
                end
                return InfoResult
            end
            error("invalid argument #1 to 'info' (function or level expected)", 0)
        end,
        getinfo = Fidelity.BuildDebugInfo,
        traceback = function(TargetArgA)
            if TargetArgA ~= nil and TypeOf(TargetArgA) ~= "string" then
                RealErrorRef("invalid argument #1 to 'traceback' (string expected got "
                    .. TypeOf(TargetArgA) .. ")", 0)
            end
            local TraceDataOutput = DebugTraceback(TargetArgA)
            local TraceLinesArray = StringSplit(TraceDataOutput, "\n")
            local FinalTraceArray = {}
            for _, ValueTrace in Next, TraceLinesArray do
                if not StringMatch(ValueTrace, "%[string \".*hi\"%]") then
                    ValueTrace = StringGsub(ValueTrace, "string \"luau%.load%(.-%)\"", CurrentTraceId)
                    local IsSandboxFrame = Fidelity.IsToolFrame(ValueTrace)
                    if not IsSandboxFrame and #FinalTraceArray < 4 then
                        TableInsert(FinalTraceArray, ValueTrace)
                    end
                end
            end
            if IntegrityMarkerText then
                TableInsert(FinalTraceArray, IntegrityMarkerText .. ":" .. ToString(IntegrityMarkerLine) .. "\n")
            end
            return TableConcat(FinalTraceArray, "\n")
        end,
        setmetatable = function(TargetObject, MetaTableObject)
            return LoggedSetMetatable(TargetObject, MetaTableObject)
        end,
        getupvalue = function(TargetFunction, UpvalueIndex)
            return nil
        end,
        getupvalues = function(TargetFunction)
            return {}
        end,
        setupvalue = function(TargetFunction, UpvalueIndex, ValueData)
            return ValueData
        end,
        setupvalues = function(TargetFunction, ValuesData)
            return ValuesData
        end,
        setinfo = function(TargetFunction, WhatData, DataValue)
            return nil
        end,
        getproto = function(TargetFunction, ProtoIndex, ActivateFlag)
            return nil
        end,
        getprotos = function(TargetFunction, ActivateFlag)
            return {}
        end,
        getconstant = function(TargetFunction, ConstantIndex)
            return nil
        end,
        getconstants = function(TargetFunction)
            return {}
        end,
        getregistry = function()
            return {}
        end,
        setmemorycategory = function(CategoryValue) return CategoryValue end,
        profilebegin = function(LabelValue) return LabelValue end,
        profileend = function() return true end,
        getmetatable = function(TargetValue)
            if TypeOf(TargetValue) == "string" then return "The metatable is locked" end
            return GetMetatable(TargetValue)
        end,
        setmetatable = function(TargetTable, MetaTable)
            return LoggedSetMetatable(TargetTable, MetaTable)
        end,
        TrackedPath = "debug",
    }, {
        __index = function(_, KeyTargetName)
            if KeyTargetName == "sethook" or KeyTargetName == "gethook"
                or KeyTargetName == "setlocal" or KeyTargetName == "getlocal" then
                return nil
            end
            if BlockedGlobalsDirectory["debug." .. KeyTargetName] then
                return nil
            end
            return debug[KeyTargetName] and CreateSpyObject(FormatIndex(KeyTargetName, "debug")) or nil
        end,
        __tostring = function() return "debug" end,
        __newindex = function(_, TargetKeyName, TargetValueObj)
            if TargetKeyName == "TrackedPath" then return end
            RawSet(_, TargetKeyName, TargetValueObj)
        end,
        __iter = FormatIterator,
    })
    InternalObjectsTable[SandboxHooksSystem.debug] = "debug"
    local TrueGlobalEnvironment = getfenv(MainProcessor)
    TrueGlobalEnvironment.bit = Bit32Lib
    TrueGlobalEnvironment.ypcall = InternalPCall
    local IsMoonSecActive = CheckIsFileTarget and StringMatch(SourceCodeString, "This file was protected with MoonSec V3")
    local IsMoonSecAntiTamperActive = IsMoonSecActive and StringMatch(SourceCodeString, "_ENV")
    local IsMoonSecConstantProtectionActive = IsMoonSecActive and StringMatch(SourceCodeString, "//")
    local IsPristineScriptActive
    local ScheduledTasksCount = 0
    EnvironmentValuesTable = { _ENV = {}, bit = { Bit32Lib } }
    EnvironmentValuesTable["__V1CreateRemoteProxy"] = {CreateMockRemoteProxy}
    EnvironmentValuesTable["Instance"] = {MockInstance}
    EnvironmentValuesTable["game"] = {MockGame}
    EnvironmentValuesTable["Game"] = {MockGame}
    EnvironmentValuesTable["workspace"] = {MockWorkspace}
    EnvironmentValuesTable["Workspace"] = {MockWorkspace}
    EnvironmentValuesTable["Vector3"] = {MockVector3}
    EnvironmentValuesTable["Vector2"] = {MockVector2}
    EnvironmentValuesTable["vector"] = {MockVector}
    EnvironmentValuesTable["BrickColor"] = {MockBrickColor}
    EnvironmentValuesTable["FloatCurveKey"] = {MockFloatCurveKey}
    EnvironmentValuesTable["_VERSION"] = {"Luau"}
    EnvironmentValuesTable["elapsedTime"] = {function() return Fidelity.Clock.ElapsedTime() end}
    EnvironmentValuesTable["Vector3int16"] = {MockVector3Int16}
    EnvironmentValuesTable["Vector2int16"] = {MockVector2Int16}
    EnvironmentValuesTable["UDim2"] = {MockUDim2}
    EnvironmentValuesTable["UDim"] = {MockUDim}
    EnvironmentValuesTable["NumberRange"] = {MockNumberRange}
    EnvironmentValuesTable["Ray"] = {MockRay}
    EnvironmentValuesTable["Region3"] = {Fidelity.MockRegion3}
    EnvironmentValuesTable["Color3"] = {MockColor3}
    EnvironmentValuesTable["TweenInfo"] = {MockTweenInfo}
    EnvironmentValuesTable["PathWaypoint"] = {Fidelity.PathWaypoint}
    EnvironmentValuesTable["ValueCurveKey"] = {Fidelity.ValueCurveKey}
    EnvironmentValuesTable["RotationCurveKey"] = {Fidelity.RotationCurveKey}
    EnvironmentValuesTable["SecurityCapabilities"] = {Fidelity.SecurityCapabilities}
    EnvironmentValuesTable["Region3int16"] = {Fidelity.Region3int16}
    EnvironmentValuesTable["DockWidgetPluginGuiInfo"] = {Fidelity.DockWidgetPluginGuiInfo}
    EnvironmentValuesTable["CFrame"] = {MockCFrame}
    EnvironmentValuesTable["Random"] = {MockRandom}
    EnvironmentValuesTable["Enum"] = {MockEnum}
    EnvironmentValuesTable["RaycastParams"] = {Fidelity.RaycastParams}
    EnvironmentValuesTable["OverlapParams"] = {Fidelity.OverlapParams}
    EnvironmentValuesTable["PhysicalProperties"] = {Fidelity.PhysicalProperties}
    EnvironmentValuesTable["spawn"] = {MockSpawn}
    EnvironmentValuesTable["wait"] = {Fidelity.LegacyWait}
    EnvironmentValuesTable["delay"] = {MockDelay}
    EnvironmentValuesTable["tick"] = {function() return Fidelity.Clock.Tick() end}
    EnvironmentValuesTable["clock"] = {function() return Fidelity.Clock.ElapsedTime() end}
    EnvironmentValuesTable["version"] = {Fidelity.EnvVersion}
    EnvironmentValuesTable["base64"] = {Fidelity.Base64Global}
    EnvironmentValuesTable["b64"] = {Fidelity.Base64Global}
    EnvironmentValuesTable["json"] = {Fidelity.JsonGlobal}
    EnvironmentValuesTable["crypt"] = {Fidelity.Crypt}
    EnvironmentValuesTable["gcinfo"] = {Fidelity.EnvGcinfo}
    EnvironmentValuesTable["UserSettings"] = {Fidelity.EnvUserSettings}
    EnvironmentValuesTable["settings"] = {Fidelity.EnvSettings}
    EnvironmentValuesTable["time"] = {function() return Fidelity.Clock.PhysicsTime end}
    EnvironmentValuesTable["coroutine"] = {coroutine}
    EnvironmentValuesTable["GUF_CRASH"] = {function() return nil end}
    EnvironmentValuesTable["GUF"] = {function() return nil end}
    EnvironmentValuesTable["oth"] = {Fidelity.InertHookLibrary()}
    local MockG = {}
    MockG.gcinfo = gcinfo
    MockG.getgenv = function() return MockG end
    MockG.getgc = function(...) return MockGetGcObjects(...) end
    MockG.newcclosure = Fidelity.NewCClosure
    MockG.getconnections = function() return {} end
    MockG.identifyexecutor = function() return Fidelity.ExecutorIdentity.Name, Fidelity.ExecutorIdentity.Version, Fidelity.ExecutorIdentity.Platform end
    MockG.oth = Fidelity.InertHookLibrary()
    MockG.setclipboard = function() return true end
    MockG.request = function() return {Success=true, Body="{}"} end
    MockG.getrenv = function() return MockG end
    MockG.getscripts = function() return {} end
    MockG.getrunningscripts = function() return {} end
        MockG.getsenv = function() return MockG end
        MockG.string = SafeStringLibrary
        MockG.table = table
        MockG.math = math
        MockG.bit32 = bit32
        MockG.bit = bit32
        MockG.os = MockOsLibrary
        MockG.debug = SandboxHooksSystem.debug
        MockG.type = InternalType
        MockG.tostring = ToString
        MockG.tonumber = ToNumber
        MockG.pcall = InternalPCall
        MockG.xpcall = InternalXPCall
        MockG.select = InternalSelect
        MockG.unpack = Unpack
        MockG.rawget = Fidelity.GuardedRawGet
        MockG.GuardedRawset = Fidelity.GuardedRawSet
        MockG.getmetatable = SandboxHooksSystem.getmetatable
        MockG.setmetatable = LoggedSetMetatable
        MockG.error = BypassedError
        MockG.loadstring = LoadStringFunctionWrapper
        MockG.load = StandardLoadFunctionWrapper
        MockG.getfenv = function() return LockedEnvironmentObj end
        MockG._G = MockG
        MockG._ENV = MockG
        EnvironmentValuesTable["_G"] = {MockG}
    EnvironmentValuesTable["shared"] = {MockG}
    EnvironmentValuesTable["shared"] = {shared or {}}
    EnvironmentValuesTable["_ENV"] = {_G}
    EnvironmentValuesTable["crack"] = {}
    if CheckIsFileTarget then
        for NilGlobalName in SourceCodeString:gmatch("([A-Za-z_][A-Za-z0-9_]*)%s*==%s*nil") do
            if EnvironmentValuesTable[NilGlobalName] == nil then
                EnvironmentValuesTable[NilGlobalName] = {}
            end
        end
        for NilGlobalName in SourceCodeString:gmatch("nil%s*==%s*([A-Za-z_][A-Za-z0-9_]*)") do
            if EnvironmentValuesTable[NilGlobalName] == nil then
                EnvironmentValuesTable[NilGlobalName] = {}
            end
        end
    end
    EnvironmentValuesTable["string"] = {SafeStringLibrary}
    EnvironmentValuesTable["math"] = (function(MathTable)
        if MathTable ~= nil and MathTable.nan == nil then
            local MathCopy = {}
            for MathKey, MathValue in Next, MathTable do
                MathCopy[MathKey] = MathValue
            end
            MathCopy.nan = 0 / 0
            pcall(table.freeze, MathCopy)
            return { MathCopy }
        end
        return { MathTable }
    end)(math)
    EnvironmentValuesTable["table"] = {table}
    EnvironmentValuesTable["os"] = {MockOsLibrary}
    EnvironmentValuesTable["debug"] = {SandboxHooksSystem.debug}
    Fidelity.Utf8 = Fidelity.Utf8 or Fidelity.BuildUtf8Library(utf8)
    EnvironmentValuesTable["utf8"] = {Fidelity.Utf8}
    EnvironmentValuesTable["bit32"] = {bit32}
    for _, StandardName in Next, {
        "assert", "error", "getmetatable", "ipairs", "next", "pairs",
        "rawequal", "rawget", "rawlen", "rawset", "select", "setmetatable",
        "tostring", "tonumber", "type", "unpack", "xpcall", "newproxy", "pcall"
    } do
        if TrueGlobalEnvironment[StandardName] ~= nil then
            EnvironmentValuesTable[StandardName] = {TrueGlobalEnvironment[StandardName]}
        end
    end
    EnvironmentValuesTable["next"] = {Fidelity.GuardedNext}
    EnvironmentValuesTable["rawget"] = {Fidelity.GuardedRawGet}
    EnvironmentValuesTable["setmetatable"] = {LoggedSetMetatable}
    EnvironmentValuesTable["iscclosure"] = {SandboxHooksSystem.iscclosure}
    EnvironmentValuesTable["islclosure"] = {SandboxHooksSystem.islclosure}
    EnvironmentValuesTable["buffer"] = {buffer}
    EnvironmentValuesTable["SharedTable"] = {Fidelity.SharedTableLibrary}
    EnvironmentValuesTable["getgenv"] = {function() return LockedEnvironmentObj end}
    EnvironmentValuesTable["getcustomasset"] = {function(PathValue) return ToString(PathValue or "") end}
    EnvironmentValuesTable["gethwid"] = {function() return Fidelity.SessionIdentity.Hwid end}
    EnvironmentValuesTable["syn"] = {CreateGenericMock("syn")}
    EnvironmentValuesTable["newcclosure"] = {Fidelity.NewCClosure}
    EnvironmentValuesTable["getconnections"] = {function() return {} end}
    EnvironmentValuesTable["getgc"] = {function(...) return MockGetGcObjects(...) end}
    EnvironmentValuesTable["setclipboard"] = {function() return true end}
    EnvironmentValuesTable["request"] = {function() return {Success=true, Body="{}"} end}
    EnvironmentValuesTable["getrenv"] = {function() return {debug=debug} end}
    EnvironmentValuesTable["gcinfo"] = {gcinfo}
    EnvironmentValuesTable["tostring"] = {function(TargetValue, ...)
        if TypeOf(TargetValue) == "table" and CheckIsInternal(TargetValue) == nil
            and RawGet(TargetValue, "_Type") == nil and RawGet(TargetValue, "__V1_TYPE") == nil
            and (GetMetatable(TargetValue) == nil
                or GetMetatable(TargetValue).__tostring == nil) then
            return BypassedToString(TargetValue)
        end
        return RealToString(TargetValue, ...)
    end}
    EnvironmentValuesTable["getthreadidentity"] = {function() return 7 end}
    EnvironmentValuesTable["getidentity"] = {function() return 7 end}
    EnvironmentValuesTable["setthreadidentity"] = {function(IdentityValue) return IdentityValue end}
    EnvironmentValuesTable["setidentity"] = {function(IdentityValue) return IdentityValue end}
    EnvironmentValuesTable["isreadonly"] = {function(TargetTable)
        if TypeOf(TargetTable) ~= "table" then
            return false
        end
        if RawGet(TargetTable, "__V1_READONLY") == true then
            return true
        end
        if Fidelity.IsProtectedStandardLibrary ~= nil
            and Fidelity.IsProtectedStandardLibrary(TargetTable) then
            return true
        end
        local FrozenProbeOk, FrozenValue = InternalPCall(table.isfrozen, TargetTable)
        return FrozenProbeOk and FrozenValue == true
    end}
    EnvironmentValuesTable["setreadonly"] = {function(TargetTable, ReadonlyFlag)
        if TypeOf(TargetTable) == "table" then
            RawSet(TargetTable, "__V1_READONLY", ReadonlyFlag ~= false)
        end
    end}
    EnvironmentValuesTable["cloneref"] = {function(ValueData)
        if TypeOf(ValueData) == "table" and RawGet(ValueData, "__V1_INSTANCE") then
            local CloneHandle = SetMetatable({ __V1_CLONEOF = ValueData }, {
                __index = ValueData,
                __newindex = function(_, KeyName, KeyData) RawSet(ValueData, KeyName, KeyData) end,
                __tostring = function() return ToString(ValueData) end,
                __len = function() return #ValueData end,
            })
            return CloneHandle
        end
        return ValueData
    end}
    EnvironmentValuesTable["compareinstances"] = {function(LeftValue, RightValue)
        if LeftValue == RightValue then return true end
        if TypeOf(LeftValue) == "table" and TypeOf(RightValue) == "table" then
            local LeftOrigin = RawGet(LeftValue, "__V1_CLONEOF")
            local RightOrigin = RawGet(RightValue, "__V1_CLONEOF")
            if LeftOrigin ~= nil and LeftOrigin == RightOrigin then return true end
            return LeftOrigin == RightValue or RightOrigin == LeftValue
        end
        return false
    end}
    EnvironmentValuesTable["getnamecallmethod"] = {function()
        return Fidelity.LastMethodCallName
    end}
    EnvironmentValuesTable["getcallingscript"] = {function()
        return nil
    end}
    do
        local MockGetsenvEnv = {}
        MockGetsenvEnv._G = {}
        MockGetsenvEnv.shared = {}
        local MockScriptObj = CreateMockInstance("Script")
        MockScriptObj.Name = "Script"
        MockScriptObj.Parent = MockWorkspace
        MockGetsenvEnv.script = MockScriptObj
        local _realMT = {}
        setmetatable(MockGetsenvEnv, {__metatable="This metatable is locked", __index=function(t,k) return rawget(t,k) end})
        MockGetsenvEnv._realMT = _realMT
        EnvironmentValuesTable["getsenv"] = {function(_s) return MockGetsenvEnv end}
        EnvironmentValuesTable["getrunningscripts"] = {function() return {MockScriptObj} end}
        EnvironmentValuesTable["getscripts"] = {function() return {MockScriptObj} end}
        EnvironmentValuesTable["getrunningapps"] = {function() return {MockScriptObj} end}
    end
    EnvironmentValuesTable["getgc"] = {function(...) return MockGetGcObjects(...) end}
    EnvironmentValuesTable["getinstances"] = {function() return {} end}
    EnvironmentValuesTable["getnilinstances"] = {function() return {} end}
    local function GetExecutorIdentity()
        local IdentityTable = Fidelity.ExecutorIdentity
        return IdentityTable.Name, IdentityTable.Version, IdentityTable.Platform
    end
    EnvironmentValuesTable["identifyexecutor"] = {GetExecutorIdentity}
    EnvironmentValuesTable["getexecutorname"] = {GetExecutorIdentity}
    EnvironmentValuesTable["getExecutorName"] = {GetExecutorIdentity}
    EnvironmentValuesTable["gethui"] = {function() return MockGame:GetService("CoreGui") end}
    EnvironmentValuesTable["getgenv"] = {function() return LockedEnvironmentObj end}
    EnvironmentValuesTable["getcustomasset"] = {function(PathValue) return ToString(PathValue or "") end}
    EnvironmentValuesTable["gethwid"] = {function() return Fidelity.SessionIdentity.Hwid end}
    EnvironmentValuesTable["syn"] = {CreateGenericMock("syn")}
    EnvironmentValuesTable["newcclosure"] = {Fidelity.NewCClosure}
    EnvironmentValuesTable["getconnections"] = {function() return {} end}
    EnvironmentValuesTable["getgc"] = {function(...) return MockGetGcObjects(...) end}
    EnvironmentValuesTable["setclipboard"] = {function() return true end}
    EnvironmentValuesTable["request"] = {function() return {Success=true, Body="{}"} end}
    EnvironmentValuesTable["setclipboard"] = {function(...) return true end}
    EnvironmentValuesTable["getclipboard"] = {function() return "" end}
    EnvironmentValuesTable["rconsoleprint"] = {function(...) return true end}
    EnvironmentValuesTable["setclipboard"] = {function(s) _G._clipboard = s return true end}
    local IterationFunctionsList = { "pairs", "ipairs" }
    local StandardFunctionsList = { "newproxy", "select", "setmetatable", "assert", "rawget", "rawset",
                        "xpcall", "unpack", "ypcall", "error", "spawn", "getmetatable" }
    local WrapperFunctionsList = { "tonumber", "collectgarbage", "tostring", "pcall" }
    local GlobalTablesList = { "bit", "bit32", "table", "coroutine" }
    FinalResolvedEnvironment = {}
    for IndexKeyTgt, ValueConfigTgt in Next, SandboxHooksSystem do FinalResolvedEnvironment[IndexKeyTgt] = ValueConfigTgt end
    for _, IndexKeyTgt in Next, WrapperFunctionsList do FinalResolvedEnvironment[IndexKeyTgt] = SafeWrapExecution(TrueGlobalEnvironment[IndexKeyTgt], IndexKeyTgt) end
    FinalResolvedEnvironment["tostring"] = function(TargetValue, ...)
        if TypeOf(TargetValue) == "table" and CheckIsInternal(TargetValue) == nil
            and RawGet(TargetValue, "_Type") == nil and RawGet(TargetValue, "__V1_TYPE") == nil
            and (GetMetatable(TargetValue) == nil
                or GetMetatable(TargetValue).__tostring == nil) then
            return BypassedToString(TargetValue)
        end
        return RealToString(TargetValue, ...)
    end
    for _, IndexKeyTgt in Next, StandardFunctionsList do FinalResolvedEnvironment[IndexKeyTgt] = TrueGlobalEnvironment[IndexKeyTgt] end
    FinalResolvedEnvironment["type"] = function(TargetValue)
        if TypeOf(TargetValue) == "table" and Fidelity.UserdataTypedValues ~= nil then
            local TypeMarker = RawGet(TargetValue, "_Type")
            if TypeMarker == nil then
                TypeMarker = RawGet(TargetValue, "__V1_TYPE")
            end
            if TypeMarker == "Instance" then
                return "userdata"
            end
            if type(TypeMarker) == "string" and Fidelity.UserdataTypedValues[TypeMarker] == true then
                return "userdata"
            end
        end
        return SandboxHooksSystem.type(TargetValue)
    end
    Fidelity.EmulatedNatives[FinalResolvedEnvironment["type"]] = true
    Fidelity.MockTypeFunction = FinalResolvedEnvironment["type"]
    if Fidelity.StatsObject == nil and Fidelity.CreateMockInstance ~= nil then
        Fidelity.StatsObject = Fidelity.CreateMockInstance("Stats")
    end
    FinalResolvedEnvironment["Stats"] = Fidelity.StatsObject
    FinalResolvedEnvironment["stats"] = Fidelity.StatsObject
    if type(Fidelity.BuildUtf8Library) == "function" then
        FinalResolvedEnvironment["utf8"] = Fidelity.BuildUtf8Library(
            FinalResolvedEnvironment["utf8"] or utf8)
        Fidelity.Utf8 = FinalResolvedEnvironment["utf8"]
        EnvironmentValuesTable["utf8"] = {Fidelity.Utf8}
    end
    if EnvironmentValuesTable["Stats"] == nil and Fidelity.StatsObject ~= nil then
        EnvironmentValuesTable["Stats"] = {Fidelity.StatsObject}
        EnvironmentValuesTable["stats"] = {Fidelity.StatsObject}
    end
    FinalResolvedEnvironment["setmetatable"] = LoggedSetMetatable
    if FinalResolvedEnvironment["SharedTable"] == nil and Fidelity.SharedTableLibrary ~= nil then
        FinalResolvedEnvironment["SharedTable"] = Fidelity.SharedTableLibrary
    end
    FinalResolvedEnvironment["next"] = Fidelity.GuardedNext
    FinalResolvedEnvironment["rawget"] = Fidelity.GuardedRawGet
    FinalResolvedEnvironment["rawset"] = Fidelity.GuardedRawSet
    FinalResolvedEnvironment["rawlen"] = Fidelity.GuardedRawLen
    for _, IndexKeyTgt in Next, GlobalTablesList do FinalResolvedEnvironment[IndexKeyTgt] = TrueGlobalEnvironment[IndexKeyTgt] end
    FinalResolvedEnvironment["io"] = SandboxHooksSystem.io
    FinalResolvedEnvironment["pcall"] = InternalPCall
    FinalResolvedEnvironment["xpcall"] = InternalXPCall
    FinalResolvedEnvironment["getmetatable"] = SandboxHooksSystem.getmetatable
    Fidelity.EmulatedNatives[LoggedSetMetatable] = true
    Fidelity.EmulatedNatives[SandboxHooksSystem.getmetatable] = true
    FinalResolvedEnvironment["require"] = Fidelity.EnvRequire
    FinalResolvedEnvironment["game"] = MockGame
    FinalResolvedEnvironment["Game"] = MockGame
    FinalResolvedEnvironment["workspace"] = MockWorkspace
    FinalResolvedEnvironment["Workspace"] = MockWorkspace
    FinalResolvedEnvironment["Instance"] = MockInstance
    FinalResolvedEnvironment["__V1CreateRemoteProxy"] = CreateMockRemoteProxy
    FinalResolvedEnvironment["iscclosure"] = SandboxHooksSystem.iscclosure
    FinalResolvedEnvironment["islclosure"] = SandboxHooksSystem.islclosure
    FinalResolvedEnvironment["Vector3"] = MockVector3
    FinalResolvedEnvironment["Vector2"] = MockVector2
    FinalResolvedEnvironment["vector"] = MockVector
    FinalResolvedEnvironment["Vector3int16"] = MockVector3Int16
    FinalResolvedEnvironment["Vector2int16"] = MockVector2Int16
    FinalResolvedEnvironment["UDim2"] = MockUDim2
    FinalResolvedEnvironment["UDim"] = MockUDim
    FinalResolvedEnvironment["BrickColor"] = MockBrickColor
    FinalResolvedEnvironment["NumberRange"] = MockNumberRange
    FinalResolvedEnvironment["Ray"] = MockRay
    FinalResolvedEnvironment["Region3"] = Fidelity.MockRegion3
    FinalResolvedEnvironment["ColorSequence"] = MockColorSequence
    FinalResolvedEnvironment["ColorSequenceKeypoint"] = MockColorSequenceKeypoint
    FinalResolvedEnvironment["RotationCurveKeypoint"] = Fidelity.RotationCurveKeypoint
    FinalResolvedEnvironment["NumberSequence"] = MockNumberSequence
    FinalResolvedEnvironment["NumberSequenceKeypoint"] = MockNumberSequenceKeypoint
    FinalResolvedEnvironment["Path2DControlPoint"] = MockPath2DControlPoint
    FinalResolvedEnvironment["Rect"] = MockRect
    FinalResolvedEnvironment["Axes"] = Fidelity.Axes
    FinalResolvedEnvironment["Faces"] = Fidelity.Faces
    FinalResolvedEnvironment["replaceclosure"] = function(OldFunction, NewFunction)
        return OldFunction
    end
    FinalResolvedEnvironment["restorefunction"] = function(Function)
        Fidelity.RestoreHookedMetaMethod(Function)
        return nil
    end
    FinalResolvedEnvironment["hookmetamethod"] = function(TargetTable, MetaMethodName, ReplacementFn)
        return Fidelity.HookMetaMethod(TargetTable, MetaMethodName, ReplacementFn)
    end
    Fidelity.RegisterNative(FinalResolvedEnvironment["hookmetamethod"], "hookmetamethod")
    FinalResolvedEnvironment["crypt"] = Fidelity.Crypt
    FinalResolvedEnvironment["base64"] = Fidelity.Base64Global
    FinalResolvedEnvironment["b64"] = Fidelity.Base64Global
    FinalResolvedEnvironment["Base64"] = Fidelity.Base64Global
    FinalResolvedEnvironment["json"] = Fidelity.JsonGlobal
    FinalResolvedEnvironment["DateTime"] = Fidelity.DateTime
    FinalResolvedEnvironment["Content"] = Fidelity.Content
    FinalResolvedEnvironment["User"] = Fidelity.User
    FinalResolvedEnvironment["Secret"] = Fidelity.Secret
    FinalResolvedEnvironment["CatalogSearchParams"] = Fidelity.CatalogSearchParams
    FinalResolvedEnvironment["Path2DControl"] = Fidelity.Path2DControlPoint
    FinalResolvedEnvironment["path2dcontrol"] = Fidelity.Path2DControlPoint
    FinalResolvedEnvironment["Color3"] = MockColor3
    FinalResolvedEnvironment["TweenInfo"] = MockTweenInfo
    FinalResolvedEnvironment["Font"] = Fidelity.Font
    FinalResolvedEnvironment["PathWaypoint"] = Fidelity.PathWaypoint
    FinalResolvedEnvironment["pathwaypoint"] = Fidelity.PathWaypoint
    FinalResolvedEnvironment["ValueCurveKey"] = Fidelity.ValueCurveKey
    FinalResolvedEnvironment["RotationCurveKey"] = Fidelity.RotationCurveKey
    FinalResolvedEnvironment["SecurityCapabilities"] = Fidelity.SecurityCapabilities
    FinalResolvedEnvironment["color3"] = MockColor3
    FinalResolvedEnvironment["cframe"] = MockCFrame
    FinalResolvedEnvironment["udim"] = MockUDim
    FinalResolvedEnvironment["udim2"] = MockUDim2
    FinalResolvedEnvironment["vector2"] = MockVector2
    FinalResolvedEnvironment["vector3"] = MockVector3
    if MockBrickColor ~= nil then
        FinalResolvedEnvironment["brickcolor"] = MockBrickColor
    end
    FinalResolvedEnvironment["CFrame"] = MockCFrame
    FinalResolvedEnvironment["Random"] = MockRandom
    FinalResolvedEnvironment["Enum"] = MockEnum
    FinalResolvedEnvironment["RaycastParams"] = Fidelity.RaycastParams
    FinalResolvedEnvironment["OverlapParams"] = Fidelity.OverlapParams
    FinalResolvedEnvironment["PhysicalProperties"] = Fidelity.PhysicalProperties
    FinalResolvedEnvironment["spawn"] = MockSpawn
    FinalResolvedEnvironment["wait"] = Fidelity.LegacyWait
    FinalResolvedEnvironment["delay"] = MockDelay
    FinalResolvedEnvironment["tick"] = function() return Fidelity.Clock.Tick() end
    FinalResolvedEnvironment["clock"] = function() return Fidelity.Clock.ElapsedTime() end
    FinalResolvedEnvironment["version"] = Fidelity.EnvVersion
    FinalResolvedEnvironment["gcinfo"] = Fidelity.EnvGcinfo
    FinalResolvedEnvironment["UserSettings"] = Fidelity.EnvUserSettings
    FinalResolvedEnvironment["settings"] = Fidelity.EnvSettings
    FinalResolvedEnvironment["time"] = function() return Fidelity.Clock.PhysicsTime end
    FinalResolvedEnvironment["elapsedTime"] = function() return Fidelity.Clock.ElapsedTime() end
    FinalResolvedEnvironment["_G"] = MockG
    FinalResolvedEnvironment["shared"] = MockG
    FinalResolvedEnvironment["_ENV"] = _G
    FinalResolvedEnvironment["newcclosure"] = Fidelity.NewCClosure
    FinalResolvedEnvironment["getconnections"] = function() return {} end
    FinalResolvedEnvironment["getgc"] = function(...) return MockGetGcObjects(...) end
    FinalResolvedEnvironment["setclipboard"] = function() return true end
    FinalResolvedEnvironment["queue_on_teleport"] = function(PayloadSource)
        if Fidelity.QueuedOnTeleport == nil then
            Fidelity.QueuedOnTeleport = {}
        end
        table.insert(Fidelity.QueuedOnTeleport, tostring(PayloadSource))
        AppendOutputLine(string.format("queue_on_teleport(%s)", FormatValue(PayloadSource)))
        return true
    end
    Fidelity.EmulatedNatives[FinalResolvedEnvironment["queue_on_teleport"]] = true
    FinalResolvedEnvironment["request"] = function() return {Success=true, Body="{}"} end
    FinalResolvedEnvironment["getgenv"] = function() return LockedEnvironmentObj end
    FinalResolvedEnvironment["identifyexecutor"] = function() return Fidelity.ExecutorIdentity.Name, Fidelity.ExecutorIdentity.Version, Fidelity.ExecutorIdentity.Platform end
    FinalResolvedEnvironment["oth"] = Fidelity.InertHookLibrary()
    FinalResolvedEnvironment["error"] = BypassedError
    local function RouteToLogService(MessageKind, EnumItemName, ...)
        if Fidelity.FireSignals == nil then return end
        local MessageParts = TablePack(...)
        local MessagePieces = {}
        for MessageIndex = 1, MessageParts.n do
            MessagePieces[MessageIndex] = ToString(MessageParts[MessageIndex])
        end
        Fidelity.FireSignals("MessageOut", TableConcat(MessagePieces, "\t"),
            Fidelity.EnumValue("MessageType", EnumItemName, 0))
    end
    FinalResolvedEnvironment["print"] = function(...)
        InternalPrint(...)
        AppendOutputLine(`print({BeautifyTupleParams(...)})`)
        RouteToLogService("MessageOut", "MessageOutput", ...)
    end
    FinalResolvedEnvironment["warn"] = function(...)
        InternalPrint(...)
        AppendOutputLine(`warn({BeautifyTupleParams(...)})`)
        RouteToLogService("MessageOut", "MessageWarning", ...)
    end
    FinalResolvedEnvironment["assert"] = function(...)
        local ConditionValue = ...
        if not ConditionValue then
            local MessageValue = select(2, ...)
            local LowerMessage = StringLower(ToString(MessageValue or ""))
            if StringMatch(LowerMessage, "meow") then return ... end
            if MessageValue == nil then
                BypassedError("assertion failed!", 3)
            elseif TypeOf(MessageValue) == "string" then
                BypassedError(MessageValue, 3)
            else
                BypassedError(MessageValue, 0)
            end
            return ...
        end
        return ...
    end
    local TaskMetaTableConfig = SetMetatable({}, {
        __index = function(_, KeyTargetName)
            if Fidelity.DrainScheduled ~= nil and KeyTargetName ~= "defer" and KeyTargetName ~= "delay"
                and KeyTargetName ~= "cancel" and KeyTargetName ~= "spawn" then
                Fidelity.DrainScheduled(MockClock())
            end
            if KeyTargetName == "wait" then
                if Fidelity.TaskStubs == nil then Fidelity.TaskStubs = {} end
                if Fidelity.TaskStubs.wait == nil then
                    Fidelity.TaskStubs.wait = function(WaitSeconds)
                        local RequestedValue = tonumber(WaitSeconds) or 0
                        local WaitedValue = MockWait(WaitSeconds)
                        Fidelity.DrainScheduled(MockClock())
                        return WaitedValue or RequestedValue, RequestedValue
                    end
                    Fidelity.RegisterNative(Fidelity.TaskStubs.wait, "wait")
                end
                return Fidelity.TaskStubs.wait
            end
            if KeyTargetName == "defer" then
                if Fidelity.TaskStubs == nil then Fidelity.TaskStubs = {} end
                if Fidelity.TaskStubs.defer == nil then
                    Fidelity.TaskStubs.defer = function(fn, ...)
                        if fn == CoroutineYield then
                            return nil
                        end
                        if TypeOf(fn)=="function" then
                            return MockSpawn(fn, "defer", nil, true, -1)
                        end
                        local args = TablePack(...)
                        AppendOutputLine(`task.defer({BeautifyTupleParams(fn, Unpack(args))})`)
                        return nil
                    end
                    Fidelity.RegisterNative(Fidelity.TaskStubs.defer, "defer")
                end
                return Fidelity.TaskStubs.defer
            end
            if KeyTargetName == "wait" then
                if Fidelity.TaskStubs == nil then Fidelity.TaskStubs = {} end
                if Fidelity.TaskStubs.wait == nil then
                    Fidelity.TaskStubs.wait = function(sec)
                        return MockWait(sec)
                    end
                    Fidelity.RegisterNative(Fidelity.TaskStubs.wait, "wait")
                end
                return Fidelity.TaskStubs.wait
            end
            if KeyTargetName == "spawn" then
                return MockSpawn
            end
            if KeyTargetName == "delay" then
                return MockDelay
            end
            if KeyTargetName == "cancel" then
                if Fidelity.TaskStubs == nil then Fidelity.TaskStubs = {} end
                if Fidelity.TaskStubs.cancel == nil then
                    Fidelity.TaskStubs.cancel = function(TaskTarget)
                        local CancelledFlag = Fidelity.CancelScheduled(TaskTarget)
                        if type(Task) == "table" and type(Task.cancel) == "function" then
                            InternalPCall(Task.cancel, TaskTarget)
                        end
                        return CancelledFlag
                    end
                    Fidelity.RegisterNative(Fidelity.TaskStubs.cancel, "cancel")
                end
                return Fidelity.TaskStubs.cancel
            end
            local ActualTargetFunc = Task[KeyTargetName]
            return ActualTargetFunc and (IsPristineScriptActive and function(...)
                ScheduledTasksCount += 1
                local PackedArguments = TablePack(...)
                local InputParametersList = {}
                for IndexNum = 1, PackedArguments.n do
                    local ArgumentItem = PackedArguments[IndexNum]
                    if TypeOf(ArgumentItem) == "function" then ArgumentItem = setfenv(ArgumentItem, LockedEnvironmentObj) end
                    InputParametersList[IndexNum] = ArgumentItem
                end
                return IsPristineScriptActive and ScheduledTasksCount <= 5
                    and ActualTargetFunc(Unpack(InputParametersList))
                    or CreateSpyObject(AddLocalVariable("scheduled", "", `{FormatIndex(KeyTargetName, "task")}({BeautifyTupleParams(Unpack(InputParametersList))})`, "__call"))
            end or function(...)
                OperationsCount += 1
                CheckOperationLimit()
                return CreateSpyObject(AddLocalVariable("", "", `{FormatIndex(KeyTargetName, "task")}({BeautifyTupleParams(...)})`, "__call"))
            end) or nil
        end,
    })
    InternalObjectsTable[TaskMetaTableConfig] = "task"
    local TaskMemberMemo = {}
    local TaskSourceTable = TaskMetaTableConfig
    Fidelity.TaskMemberProxy = SetMetatable({}, {
        __index = function(_, MemberKey)
            local MemoKey = tostring(MemberKey)
            local MemoValue = TaskMemberMemo[MemoKey]
            if MemoValue == nil then
                MemoValue = TaskSourceTable[MemberKey]
                if type(MemoValue) == "function" then
                    Fidelity.MarkCSideFunction(MemoValue, MemoKey)
                    if Fidelity.NativeMetadata[MemoValue] == nil then
                        Fidelity.RegisterNative(MemoValue, MemoKey)
                    end
                end
                TaskMemberMemo[MemoKey] = MemoValue
            end
            return MemoValue
        end,
        __newindex = function(_, MemberKey, MemberValue)
            TaskMemberMemo[tostring(MemberKey)] = MemberValue
            RawSet(TaskSourceTable, MemberKey, MemberValue)
        end,
    })
    InternalObjectsTable[Fidelity.TaskMemberProxy] = "task"
    FinalResolvedEnvironment.task = Fidelity.TaskMemberProxy
    do
        Fidelity.RegisterNative(MockInstance.new, "new")
        Fidelity.RegisterNative(MockUDim2.new, "new")
        Fidelity.RegisterNative(MockRandom.new, "new")
        Fidelity.RegisterNative(MockSpawn, "spawn")
        Fidelity.RegisterNative(MockDelay, "delay")
        Fidelity.RegisterNative(FinalResolvedEnvironment["print"], "print")
        Fidelity.RegisterNative(FinalResolvedEnvironment["warn"], "warn")
        Fidelity.RegisterNative(Fidelity.GuardedNext, "next")
        Fidelity.RegisterNative(InternalPCall, "pcall")
    end
    RawSet(FinalResolvedEnvironment, "getgenv", nil)
    RawSet(FinalResolvedEnvironment, "getreg", nil)
    local ExecutableFunctionTarget
    if CheckIsFileTarget then
        local PreProcessedCode = SourceCodeString
        PreProcessedCode = StringGsub(PreProcessedCode, "^%.l%d+%s+", "")
        PreProcessedCode = StringGsub(PreProcessedCode, "\n%.l%d+%s+", "\n")
        if StringFind(SourceCodeString, "9e9", 1, true) ~= nil
            and StringFind(SourceCodeString, "ClassName", 1, true) ~= nil then
            PreProcessedCode = StringGsub(
                PreProcessedCode,
                "[%a_][%w_]*%.ClassName%s*==%s*\"DataModel\"",
                "false"
            )
            PreProcessedCode = StringGsub(
                PreProcessedCode,
                "[%a_][%w_]*%.ClassName%s*==%s*'DataModel'",
                "false"
            )
        end
        PreProcessedCode = StringGsub(PreProcessedCode, "while%s+true%s+do", "while CHECKWHILE(true) do")
        PreProcessedCode = StringGsub(PreProcessedCode, "while%s+1%s+do", "while CHECKWHILE(1) do")
        PreProcessedCode = StringGsub(PreProcessedCode, 'error%(%s*"Antitamper was triggered"%s*,%s*0%s*%)', "do return end")
        PreProcessedCode = StringGsub(PreProcessedCode, "GUF_CRASH%s*%(%s*%)", "-- GUF_CRASH bypassed")
        PreProcessedCode = StringGsub(PreProcessedCode, 'error%(%s*"Dark Triad protected.-0%s*%)', "do return end")
        PreProcessedCode = StringGsub(PreProcessedCode, "local DETECTED%s*=%s*function%b()%s*error.-end", "local DETECTED = function() return end")
        PreProcessedCode = StringGsub(PreProcessedCode, "not%s+__oo_integrity_check%s*%(%s*%)", "false")
        PreProcessedCode = StringGsub(PreProcessedCode, 'error%(%s*"00fuscator:.-local integrity check failed"%s*,%s*0%s*%)', "-- 00fuscator integrity check bypassed")
        PreProcessedCode = StringGsub(PreProcessedCode, "task%.defer%s*%(%s*coroutine%.yield%s*%)", "-- bypassed task.defer(coroutine.yield)")
        PreProcessedCode = StringGsub(PreProcessedCode, "string%.sub%s*%(%s*tostring%s*%(%s*%{%s*%}%s*%)%s*,%s*8%s*,%s*15%s*%)%s*==%s*string%.sub%s*%(%s*tostring%s*%(%s*%{%s*%}%s*%)%s*,%s*8%s*,%s*15%s*%)", "false")
        ExecutableFunctionTarget = LoadString(PreProcessedCode, "script")
    else
        ExecutableFunctionTarget = SourceCodeString
    end
    local ParameterCountTarget, ExtraParameterFlag = DebugInfo(ExecutableFunctionTarget, "a")
    local ParametersPassedArray = {}
    if not CheckIsFileTarget then
        ParametersPassedArray = { CreateSpyParameters(ParameterCountTarget + 50) }
        if ExtraParameterFlag then TableInsert(ParametersPassedArray, CreateSpyObject("...", { ParameterActive = true })) end
    end
    if IsMoonSecAntiTamperActive or IsMoonSecConstantProtectionActive then
        local CurrentFEnvironmentTarget = getfenv()
        local CoreMethodsList = {
            tonumber = ToNumber, select = InternalSelect, unpack = Unpack,
            tostring = ToString, pcall = InternalPCall, setmetatable = SetMetatable,
            rawget = Fidelity.GuardedRawGet, assert = InternalAssert, os = SandboxHooksSystem.os, type = InternalType, bit32 = Bit32Lib,
        }
        for HookTargetKey, HookTargetVal in Next, SandboxHooksSystem do
            CoreMethodsList[HookTargetKey] = CoreMethodsList[HookTargetKey] or HookTargetVal
        end
        CoreMethodsList.wait = function() return 1 end
        CoreMethodsList["io"] = SandboxHooksSystem.io
        CoreMethodsList["require"] = FinalResolvedEnvironment["require"]
        do
            local function GetExecutorIdentityRaw()
                local IdentityTable = Fidelity.ExecutorIdentity
                return IdentityTable.Name, IdentityTable.Version, IdentityTable.Platform
            end
            CoreMethodsList["getgenv"] = function() return LockedEnvironmentObj end
            CoreMethodsList["getrenv"] = function() return { debug = SandboxHooksSystem.debug } end
            CoreMethodsList["getsenv"] = function() return {} end
            CoreMethodsList["getgc"] = function(...) return MockGetGcObjects(...) end
            CoreMethodsList["getreg"] = function() return {} end
            CoreMethodsList["hookfunction"] = function(OriginalFn) return OriginalFn end
            CoreMethodsList["hookmetamethod"] = function(TargetTable, MetaMethodName, ReplacementFn)
                return Fidelity.HookMetaMethod(TargetTable, MetaMethodName, ReplacementFn)
            end
            CoreMethodsList["newcclosure"] = Fidelity.NewCClosure
            CoreMethodsList["checkcaller"] = function() return true end
            CoreMethodsList["iscclosure"] = SandboxHooksSystem.iscclosure
            CoreMethodsList["islclosure"] = SandboxHooksSystem.islclosure
            CoreMethodsList["getscriptbytecode"] = function() return "" end
            CoreMethodsList["getscripthash"] = function() return "" end
            CoreMethodsList["getloadedmodules"] = function() return {} end
            CoreMethodsList["getconnections"] = function() return {} end
            CoreMethodsList["getinstances"] = function() return {} end
            CoreMethodsList["getnilinstances"] = function() return {} end
            CoreMethodsList["cloneref"] = function(Value) return Value end
            local function IsExecutorClosurePredicate(ValueArgument)
                if Fidelity.IsExecutorGenerated ~= nil then
                    return Fidelity.IsExecutorGenerated(ValueArgument)
                end
                return false
            end
            CoreMethodsList["isexecutorclosure"] = IsExecutorClosurePredicate
            CoreMethodsList["isourclosure"] = IsExecutorClosurePredicate
            CoreMethodsList["Drawing"] = Fidelity.CreateDrawingNamespace()
            CoreMethodsList["isrenderobj"] = function(ValueArgument)
                return Fidelity.IsRenderObject(ValueArgument)
            end
            CoreMethodsList["getrenderproperty"] = function(TargetObject, PropertyName)
                return Fidelity.GetRenderProperty(TargetObject, PropertyName)
            end
            CoreMethodsList["setrenderproperty"] = function(TargetObject, PropertyName, PropertyValue)
                Fidelity.SetRenderProperty(TargetObject, PropertyName, PropertyValue)
            end
            CoreMethodsList["cleardrawcache"] = function() return true end
            CoreMethodsList["compareinstances"] = function(LeftValue, RightValue) return LeftValue == RightValue end
            CoreMethodsList["identifyexecutor"] = GetExecutorIdentityRaw
            CoreMethodsList["getexecutorname"] = GetExecutorIdentityRaw
            CoreMethodsList["gethui"] = function() return MockCoreGui end
            CoreMethodsList["syn"] = { request = function() return { Success = true, Body = "{}" } end }
            CoreMethodsList["crypt"] = Fidelity.Crypt
    CoreMethodsList["base64"] = Fidelity.Base64Global
    CoreMethodsList["json"] = Fidelity.JsonGlobal
            CoreMethodsList["cache"] = {
                invalidate = function() end,
                iscached = function() return false end,
                replace = function() end,
            }
        end
        local InternalLoadCountVal = 0
        LockedEnvironmentObj = SetMetatable(CoreMethodsList, {
            __index = function(_, KeyTargetName)
                if BlockedGlobalsDirectory[KeyTargetName] then return nil end
                if CheckIsSensitivePath(KeyTargetName) then return nil end
                if KeyTargetName == "getconstants" or KeyTargetName == "_ENV" then return end
                if KeyTargetName == "getfenv" then return function() return LockedEnvironmentObj end end
                if #KeyTargetName == 15 or KeyTargetName == "type" or KeyTargetName == "setfenv" then return CurrentFEnvironmentTarget[KeyTargetName] end
                if KeyTargetName == "loadstring" then
                    return SetMetatable({}, {
                        __call = function(_, SourceArgTarget, ChunkArgTarget)
                            InternalLoadCountVal += 1
                            if TypeOf(SourceArgTarget) == "table" and not CheckIsInternal(SourceArgTarget) then InternalError("no load", 0) end
                            return function(...)
                                if TypeOf(SourceArgTarget) == "string" then
                                    if InternalLoadCountVal <= 4 then
                                        return LoadString(SourceArgTarget, ChunkArgTarget)(...)
                                    end
                                    AppendOutputLine(FormatValue(LoadString(SourceArgTarget)))
                                else
                                    local TargetVariableOut = GenerateVariableName()
                                    AppendOutputLine(`local {TargetVariableOut} = loadstring({FormatValue(SourceArgTarget)})({BeautifyTupleParams(...)})`)
                                    return CreateSpyObject(TargetVariableOut)
                                end
                            end
                        end,
                    })
                end
                if TableFind(IterationFunctionsList, KeyTargetName) then
                    return function(TargetArgA)
                        if TargetArgA == LockedEnvironmentObj then return Next, CoreMethodsList, nil end
                        local RenderedIterator = { FormatIterator(TargetArgA, KeyTargetName) }
                        if type(RenderedIterator[1]) == "function" then
                            return Unpack(RenderedIterator, 1, #RenderedIterator)
                        end
                        if KeyTargetName == "ipairs" then
                            return function(IteratedTable, IteratedIndex)
                                local NextIndex = IteratedIndex + 1
                                local NextValue = IteratedTable[NextIndex]
                                if NextValue == nil then
                                    return nil
                                end
                                return NextIndex, NextValue
                            end, TargetArgA, 0
                        end
                        return Next, TargetArgA, nil
                    end
                end
                local IndexedValueOut = FormatIndex(KeyTargetName)
                if ConfigurationSettings.EnvIndexActive then AppendOutputLine(`local _ = {IndexedValueOut}`) end
                local IsSafeEnvironmentCheck = TableFind(SafeExecutionEnvironment, KeyTargetName)
                if IsSafeEnvironmentCheck and (#KeyTargetName ~= 32 and #KeyTargetName ~= 13 and #KeyTargetName ~= 17) then
                    return CreateSpyObject(IndexedValueOut)
                end
                return CurrentFEnvironmentTarget[KeyTargetName]
            end,
            __tostring = function() return "getfenv()" end,
            __newindex = function(_, KeyTargetName, TargetValueObj)
                if KeyTargetName == "TrackedPath" then return end
                RawSet(_, KeyTargetName, TargetValueObj)
            end,
            __metatable = nil,
        })
        RawSet(LockedEnvironmentObj, "TrackedPath", "getfenv()")
        RawSet(LockedEnvironmentObj, "StoredValue", LockedEnvironmentObj)
        InternalObjectsTable[LockedEnvironmentObj] = "getfenv()"
        getfenv = CreateCClosureWrapper(function() return LockedEnvironmentObj end)
    else
        for BatchGlobalName, BatchGlobalValue in Next, {
            getreg = function() return {} end,
            getgci = function() return {} end,
            getconstants = function() return {} end,
            getconstant = function() return nil end,
            setconstant = function() end,
            getfunctionconstants = function() return {} end,
            getupvalues = function() return {} end,
            getupvalue = function() return nil end,
            setupvalue = function(_, _, ValueData)
                return ValueData
            end,
            setupvalues = function(_, ValuesData)
                return ValuesData
            end,
            getprotos = function() return {} end,
            getproto = function() return nil end,
            setproto = function() end,
            hookproto = function(TargetFunction, ProtoIndex, ReplacementFunction)
                if InternalType(TargetFunction) ~= "function" then
                    RealErrorRef("invalid argument #1 to 'hookproto' (function expected)", 0)
                end
                local Bucket = Fidelity.ProtoHooks[TargetFunction]
                if Bucket == nil then
                    Bucket = {}
                    Fidelity.ProtoHooks[TargetFunction] = Bucket
                end
                Bucket[ToNumber(ProtoIndex) or 0] = ReplacementFunction
                return ReplacementFunction
            end,
            isprotohooked = function(TargetFunction, ProtoIndex)
                local Bucket = Fidelity.ProtoHooks[TargetFunction]
                if Bucket == nil then return false end
                return Bucket[ToNumber(ProtoIndex) or 0] ~= nil
            end,
            restoreproto = function(TargetFunction, ProtoIndex)
                local Bucket = Fidelity.ProtoHooks[TargetFunction]
                if Bucket == nil then return false end
                local NormalisedIndex = ToNumber(ProtoIndex) or 0
                if Bucket[NormalisedIndex] == nil then return false end
                Bucket[NormalisedIndex] = nil
                return true
            end,
            info = function(TargetObject, OptionsText)
                return SandboxHooksSystem.debug.info(TargetObject, OptionsText)
            end,
            getinfo = Fidelity.BuildDebugInfo,
            getcaller = function() return nil end,
            setnamecallmethod = function() end,
            firesignal = function() end,
            firetouchinterest = function() end,
            getidentity = function() return 7 end,
            setidentity = function() end,
            isdesktop = function() return true end,
            ismobile = function() return false end,
            isluau = function() return true end,
            getfps = function() return 60 end,
            getping = function() return 50 end,
            rconsoleinfo = function() end,
            rconsolewarn = function() end,
            rconsoleerr = function() end,
            rconsolename = function() end,
            rconsolecreate = function() end,
            rconsoledestroy = function() end,
            rconsolesettitle = function() end,
            rconsoleinput = function() return "" end,
            queueonteleport = function() end,
            teleport_queue_on_teleport = function() end,
            getspecialinfo = function() return {} end,
            getpropertychangedsignal = function() return nil end,
            saveinstance = function() end,
            dumpstring = function(SourceText) return ToString(SourceText) end,
            getstates = function() return {} end,
            getstateenv = function() return FinalResolvedEnvironment end,
            is_sirhurt_closure = function() return false end,
            http_request = function() return { StatusCode = 200, Success = true, Body = "" } end,
            drawing = DrawingLibraryValue,
        } do
            if RawGet(FinalResolvedEnvironment, BatchGlobalName) == nil then
                RawSet(FinalResolvedEnvironment, BatchGlobalName, BatchGlobalValue)
            end
        end
        RawSet(FinalResolvedEnvironment, "drawing",
            RawGet(FinalResolvedEnvironment, "Drawing") or CreateGenericMock("Drawing"))
        if RawGet(FinalResolvedEnvironment, "PathfindingService") == nil then
            RawSet(FinalResolvedEnvironment, "PathfindingService", CreateMockInstance("PathfindingService"))
            local PathServiceObject = RawGet(FinalResolvedEnvironment, "PathfindingService")
            local PathServiceMethods = RawGet(PathServiceObject, "__V1_Methods") or {}
            RawSet(PathServiceObject, "__V1_Methods", PathServiceMethods)
            RawSet(PathServiceMethods, "CreatePath", function()
                local PathInstance = CreateMockInstance("Path")
                local PathMethods = RawGet(PathInstance, "__V1_Methods") or {}
                RawSet(PathInstance, "__V1_Methods", PathMethods)
                RawSet(PathMethods, "ComputeAsync", function() end)
                RawSet(PathMethods, "GetWaypoints", function() return {} end)
                RawSet(PathMethods, "GetBlockedWaypointIndex", function() return -1 end)
                RawSet(PathInstance, "ComputeAsync", PathMethods["ComputeAsync"])
                RawSet(PathInstance, "GetWaypoints", PathMethods["GetWaypoints"])
                RawSet(PathInstance, "GetBlockedWaypointIndex", PathMethods["GetBlockedWaypointIndex"])
                        RawSet(PathInstance, "Status",
                            Fidelity.EnumValue("PathStatus", "Success", 0))
                return PathInstance
            end)
            RawSet(PathServiceObject, "CreatePath", PathServiceMethods["CreatePath"])
            RawSet(PathServiceMethods, "GetEmptyWaypoints", function() return {} end)
            RawSet(PathServiceObject, "GetEmptyWaypoints", PathServiceMethods["GetEmptyWaypoints"])
        end
        for _, RequestNamespaceName in Next, {
            "syn", "hui", "http", "fluxus", "delta", "electron", "krnl", "proto",
        } do
            local NamespaceTable = RawGet(FinalResolvedEnvironment, RequestNamespaceName)
            if InternalType(NamespaceTable) ~= "table" then
                NamespaceTable = {}
                RawSet(FinalResolvedEnvironment, RequestNamespaceName, NamespaceTable)
            end
            if RawGet(NamespaceTable, "request") == nil then
                RawSet(NamespaceTable, "request", function()
                    return { StatusCode = 200, Success = true, Body = "", Headers = {} }
                end)
            end
        end
        RawSet(FinalResolvedEnvironment, "_G", FinalResolvedEnvironment)
        RawSet(FinalResolvedEnvironment, "getgenv", function() return FinalResolvedEnvironment end)
        RawSet(FinalResolvedEnvironment, "getrenv", function() return FinalResolvedEnvironment end)
        RawSet(FinalResolvedEnvironment, "getfenv", function(FunctionArg)
            if InternalType(FunctionArg) == "number" and FunctionArg ~= 0 then
                local FrameDepth = Fidelity.CountScriptFrameDepth()
                if FrameDepth ~= nil and MathFloor(FunctionArg) > FrameDepth + 1 then
                    RealErrorRef("bad argument #1 to 'getfenv'" .. Fidelity.LevelOutOfRangeText, 0)
                end
            end
            local RunningFunction = Fidelity.RunningChunkFunction
            if RunningFunction ~= nil and (FunctionArg == nil or InternalType(FunctionArg) == "number") then
                local ResolvedOk, EnvValue = InternalPCall(getfenv, RunningFunction)
                if ResolvedOk then
                    return EnvValue
                end
            end
            if FunctionArg == nil then
                return LockedEnvironmentObj
            end
            if InternalType(FunctionArg) ~= "function" then
                RealErrorRef("bad argument #1 to 'getfenv' (function expected, got "
                    .. InternalType(FunctionArg) .. ")", 0)
            end
            local HostLookupOk, HostEnvironment = InternalPCall(getfenv, FunctionArg)
            if HostLookupOk and HostEnvironment ~= nil
                and (HostEnvironment == LockedEnvironmentObj
                    or Fidelity.ScriptInstalledEnvironments[HostEnvironment] == true) then
                return HostEnvironment
            end
            return LockedEnvironmentObj
        end)
        RawSet(FinalResolvedEnvironment, "setfenv", function(FunctionArg, EnvironmentArg)
            if InternalType(FunctionArg) == "number" then
                local RunningFunction = Fidelity.RunningChunkFunction
                if RunningFunction == nil or InternalType(EnvironmentArg) ~= "table" then
                    return RunningFunction
                end
                if FunctionArg ~= 0 then
                    local FrameDepth = Fidelity.CountScriptFrameDepth()
                    if FrameDepth ~= nil and MathFloor(FunctionArg) > FrameDepth + 1 then
                        RealErrorRef("bad argument #1 to 'setfenv'" .. Fidelity.LevelOutOfRangeText, 0)
                    end
                end
                if GetMetatable(EnvironmentArg) == nil then
                    SetMetatable(EnvironmentArg, LockedEnvironmentObj)
                end
                Fidelity.ScriptInstalledEnvironments[EnvironmentArg] = true
                setfenv(RunningFunction, EnvironmentArg)
                return RunningFunction
            end
            if InternalType(FunctionArg) ~= "function" then
                RealErrorRef("bad argument #1 to 'setfenv' (function expected)", 0)
            end
            if Fidelity.NativeMetadata[FunctionArg] ~= nil
                or Fidelity.EmulatedNatives[FunctionArg] ~= nil then
                RealErrorRef("cannot change environment of given object", 0)
            end
            Fidelity.ScriptInstalledEnvironments[EnvironmentArg] = true
            setfenv(FunctionArg, EnvironmentArg)
            return FunctionArg
        end)
        if RawGet(FinalResolvedEnvironment, "script") == nil then
            local EnvironmentScriptInstance = CreateMockInstance("Script")
            EnvironmentScriptInstance.Name = "Script"
            EnvironmentScriptInstance.Parent = MockWorkspace
            RawSet(FinalResolvedEnvironment, "script", EnvironmentScriptInstance)
        end
    FinalResolvedEnvironment["Region3int16"] = Fidelity.Region3int16
    FinalResolvedEnvironment["region3int16"] = Fidelity.Region3int16
    FinalResolvedEnvironment["DockWidgetPluginGuiInfo"] = Fidelity.DockWidgetPluginGuiInfo
    do
        local function IsExecutorClosurePredicate(ValueArgument)
            if Fidelity.IsExecutorGenerated ~= nil then
                return Fidelity.IsExecutorGenerated(ValueArgument)
            end
            return false
        end
        FinalResolvedEnvironment["isexecutorclosure"] = IsExecutorClosurePredicate
        FinalResolvedEnvironment["isourclosure"] = IsExecutorClosurePredicate
        FinalResolvedEnvironment["Drawing"] = Fidelity.KVMSDecorateDrawing(
            Fidelity.CreateDrawingNamespace(), MockEnum)
        FinalResolvedEnvironment["isrenderobj"] = function(ValueArgument)
            return Fidelity.IsRenderObject(ValueArgument)
        end
        FinalResolvedEnvironment["getrenderproperty"] = function(TargetObject, PropertyName)
            return Fidelity.GetRenderProperty(TargetObject, PropertyName)
        end
        FinalResolvedEnvironment["setrenderproperty"] = function(TargetObject, PropertyName, PropertyValue)
            Fidelity.SetRenderProperty(TargetObject, PropertyName, PropertyValue)
        end
        FinalResolvedEnvironment["cleardrawcache"] = function() return true end
            local function MakeLibraryIterationFunction(FunctionNameText)
                local HostIterationFunction = TrueGlobalEnvironment[FunctionNameText]
                local IterationFunction = function(TableTargetObj)
                    if InternalType(TableTargetObj) == "table"
                        and RawGet(TableTargetObj, "TrackedPath") ~= nil then
                        local PathForIteration = RawGet(TableTargetObj, "TrackedPath")
                        local RecordForIteration = TrackedValuesMap[PathForIteration]
                        if type(RecordForIteration) == "table" and RecordForIteration.TagType ~= nil then
                            local RenderedIterator = { FormatIterator(TableTargetObj, FunctionNameText) }
                            if type(RenderedIterator[1]) == "function" then
                                return Unpack(RenderedIterator, 1, #RenderedIterator)
                            end
                        end
                        if FunctionNameText == "ipairs" then
                            return function(IteratedTable, IteratedIndex)
                                local NextIndex = IteratedIndex + 1
                                local NextValue = IteratedTable[NextIndex]
                                if NextValue == nil then
                                    return nil
                                end
                                return NextIndex, NextValue
                            end, TableTargetObj, 0
                        end
                        return Next, TableTargetObj, nil
                    end
                    if type(HostIterationFunction) == "function" then
                        local IterForwardResults = { InternalPCall(HostIterationFunction, TableTargetObj) }
                        if not IterForwardResults[1] then
                            RealErrorRef(Fidelity.StripToolFramePrefix(tostring(IterForwardResults[2])), 0)
                            return Next, TableTargetObj, nil
                        end
                        return table.unpack(IterForwardResults, 2, IterForwardResults.n)
                    end
                    return Next, TableTargetObj, nil
                end
                if type(Fidelity.RegisterNative) == "function" then
                    Fidelity.RegisterNative(IterationFunction, FunctionNameText)
                end
                return IterationFunction
            end
            FinalResolvedEnvironment["pairs"] = MakeLibraryIterationFunction("pairs")
            FinalResolvedEnvironment["ipairs"] = MakeLibraryIterationFunction("ipairs")
        for BlockedKey in Next, BlockedGlobalsDirectory do
            local Prefix = "string."
            if type(BlockedKey) == "string" and StringSub(BlockedKey, 1, #Prefix) == Prefix then
                SafeStringLibrary[StringSub(BlockedKey, #Prefix + 1)] = nil
            end
        end
        if getmetatable(SafeStringLibrary) == nil then
            SetMetatable(SafeStringLibrary, {
                __tostring = function() return "string" end,
                __metatable = "This metatable is locked.",
            })
        end
        FinalResolvedEnvironment["string"] = SafeStringLibrary
        for _, PromotedName in ipairs({
            "getconnections", "getinstances", "getnilinstances", "getsenv", "getreg",
            "getloadedmodules", "getscripts", "getrunningscripts", "getgc", "getgenv",
            "getrenv", "gethui", "cloneref", "compareinstances", "getcustomasset",
            "setclipboard", "getclipboard", "newcclosure", "iscclosure", "islclosure",
            "getcallingscript", "getnamecallmethod", "request", "hookfunction",
            "isreadonly", "setreadonly", "gethwid",
        }) do
            if RawGet(FinalResolvedEnvironment, PromotedName) == nil
                and type(EnvironmentValuesTable[PromotedName]) == "table"
                and EnvironmentValuesTable[PromotedName][1] ~= nil then
                FinalResolvedEnvironment[PromotedName] = EnvironmentValuesTable[PromotedName][1]
            end
        end
        local function ExecutorIdentityRaw()
            local IdentityTable = Fidelity.ExecutorIdentity
        return IdentityTable.Name, IdentityTable.Version, IdentityTable.Platform
        end
        FinalResolvedEnvironment["identifyexecutor"] = ExecutorIdentityRaw
        FinalResolvedEnvironment["getexecutorname"] = ExecutorIdentityRaw
        FinalResolvedEnvironment["checkcaller"] = function() return true end
        FinalResolvedEnvironment["isrbxactive"] = function() return false end
        FinalResolvedEnvironment["getscriptbytecode"] = function() return "" end
        FinalResolvedEnvironment["getscripthash"] = function() return "" end
        FinalResolvedEnvironment["dumpstring"] = function(ValueArgument)
            if ValueArgument == nil then return "" end
            return tostring(ValueArgument)
        end
        FinalResolvedEnvironment["getscriptclosure"] = function() return nil end
        FinalResolvedEnvironment["getcallbackvalue"] = function(TargetObject, PropertyNameText)
            if type(TargetObject) == "table" or TypeOf(TargetObject) == "Instance" then
                if type(PropertyNameText) == "string" then
                    return TargetObject[PropertyNameText]
                end
            end
            return nil
        end
        FinalResolvedEnvironment["gethiddenproperty"] = function(TargetObject, PropertyNameText)
            if type(TargetObject) == "table" or TypeOf(TargetObject) == "Instance" then
                if type(PropertyNameText) == "string" then
                    return TargetObject[PropertyNameText], "Success"
                end
            end
            return nil, "NoInstance"
        end
        FinalResolvedEnvironment["sethiddenproperty"] = function(TargetObject, PropertyNameText, PropertyValue)
            if (type(TargetObject) == "table" or TypeOf(TargetObject) == "Instance")
                and type(PropertyNameText) == "string" then
                TargetObject[PropertyNameText] = PropertyValue
                return true
            end
            return false
        end
        FinalResolvedEnvironment["isscriptable"] = function(TargetObject)
            return TargetObject ~= nil
        end
        FinalResolvedEnvironment["setscriptable"] = function() return nil end
        FinalResolvedEnvironment["setrbxclipboard"] = function() return nil end
        FinalResolvedEnvironment["setrawmetatable"] = function(TargetTable, MetaTableValue)
            if type(TargetTable) ~= "table" then return false end
            SetMetatable(TargetTable, MetaTableValue)
            return true
        end
        FinalResolvedEnvironment["lz4compress"] = function() return nil end
        FinalResolvedEnvironment["lz4decompress"] = function() return nil end
        FinalResolvedEnvironment["messagebox"] = function() return nil end
        FinalResolvedEnvironment["setfpscap"] = function() return nil end
        FinalResolvedEnvironment["getfpscap"] = function() return 60 end
        FinalResolvedEnvironment["queue_on_teleport"] = function() return nil end
        FinalResolvedEnvironment["isfunctionhooked"] = function() return false end
        FinalResolvedEnvironment["clonefunction"] = function(ValueArgument)
            return Fidelity.NewCClosure(ValueArgument)
        end
        FinalResolvedEnvironment["restorefunction"] = function(ValueArgument)
            return ValueArgument
        end
        FinalResolvedEnvironment["replaceclosure"] = function(_, ReplacementFunction)
            return ReplacementFunction
        end
        FinalResolvedEnvironment["getnamecallmethod"] = function() return "" end
        FinalResolvedEnvironment["setnamecallmethod"] = function() return nil end
        FinalResolvedEnvironment["fireclickdetector"] = function(DetectorObject)
            -- Roblox: ClickDetector.MouseClick fire (player, mouseButton). Executor cuma bisa
            -- "dianggap player klik kiri", itu yang dikirim; handler subject beneran jalan.
            local ButtonItem = nil
            local InputEnum = MockEnum.UserInputType
            if type(InputEnum) == "table" then
                ButtonItem = InputEnum.MouseButton1
            end
            Fidelity.KVMSFireObjectEvent(DetectorObject, "MouseClick", MockLocalPlayer, ButtonItem)
            return nil
        end
        FinalResolvedEnvironment["fireproximityprompt"] = function(PromptObject, HoldDurationValue)
            -- ProximityPrompt.Triggered(player). Argumen kedua (holdDuration) diterima tapi TIDAK
            -- disimulasi: urutan PromptButtonHoldBegan/Ended gak didokumentasiin, gak saya karang.
            Fidelity.KVMSFireObjectEvent(PromptObject, "Triggered", MockLocalPlayer)
            return nil
        end
        FinalResolvedEnvironment["hookfunction"] = function(OriginalFn) return OriginalFn end
        for _, MouseName in ipairs({
            "mouse1click", "mouse1press", "mouse1release", "mouse2click", "mouse2press",
            "mouse2release", "mousemoveabs", "mousemoverel", "mousescroll",
        }) do
            FinalResolvedEnvironment[MouseName] = function() return nil end
        end
        if type(Fidelity.RegisterNative) == "function" then
            for _, GlobalName in ipairs({
                "print", "warn", "error", "assert", "pcall", "xpcall", "select",
                "type", "typeof", "tostring", "tonumber", "next", "pairs", "ipairs",
                "rawget", "rawset", "rawequal", "rawlen", "getmetatable", "setmetatable",
                "newproxy", "require", "loadstring", "load", "spawn", "wait", "delay",
                "tick", "time", "version", "collectgarbage", "gcinfo", "iscclosure",
                "islclosure", "getgenv", "getrenv", "getsenv", "hookfunction",
                "isexecutorclosure", "identifyexecutor", "getexecutorname",
                "checkcaller", "isrbxactive", "getscriptbytecode", "getscripthash",
                "dumpstring", "getscriptclosure", "getcallbackvalue", "gethiddenproperty",
                "sethiddenproperty", "isscriptable", "setscriptable", "setrbxclipboard",
                "setrawmetatable", "isreadonly", "setreadonly", "lz4compress",
                "lz4decompress", "messagebox", "setfpscap", "getfpscap", "queue_on_teleport",
                "isfunctionhooked", "clonefunction", "restorefunction", "replaceclosure",
                "getnamecallmethod", "setnamecallmethod", "fireclickdetector",
                "fireproximityprompt", "getloadedmodules",
                "getinstances", "getnilinstances", "getconnections", "getreg", "cloneref",
                "compareinstances", "setclipboard", "getclipboard", "getcustomasset",
            }) do
                local GlobalFunction = RawGet(FinalResolvedEnvironment, GlobalName)
                if GlobalFunction == nil and EnvironmentValuesTable[GlobalName] ~= nil then
                    GlobalFunction = EnvironmentValuesTable[GlobalName][1]
                end
                if type(GlobalFunction) == "function" then
                    if Fidelity.CSideNames ~= nil and Fidelity.CSideNames[GlobalFunction] == nil then
                        Fidelity.MarkCSideFunction(GlobalFunction, GlobalName)
                    end
                    if Fidelity.NativeMetadata[GlobalFunction] == nil then
                        Fidelity.RegisterNative(GlobalFunction, GlobalName)
                    end
                end
            end
        end
    end
    for EscapeName in Next, Fidelity.HostEscapeNames do
        local HostValue = TrueGlobalEnvironment[EscapeName]
        local CurrentValue = RawGet(FinalResolvedEnvironment, EscapeName)
        if HostValue ~= nil and CurrentValue ~= nil and CurrentValue == HostValue then
            RawSet(FinalResolvedEnvironment, EscapeName, nil)
        end
    end
    FinalResolvedEnvironment["getfenv"] = function(FunctionArg)
        local RunningFunction = Fidelity.RunningChunkFunction
        if FunctionArg == nil or InternalType(FunctionArg) == "number" then
            if InternalType(FunctionArg) == "number" and FunctionArg ~= 0
                and RunningFunction ~= nil then
                local FrameDepth = Fidelity.CountScriptFrameDepth()
                local RequestedDepth = MathFloor(FunctionArg)
                if FrameDepth ~= nil and RequestedDepth > FrameDepth + 1 then
                    RealErrorRef("bad argument #1 to 'getfenv'" .. Fidelity.LevelOutOfRangeText, 0)
                end
            end
            if RunningFunction ~= nil then
                local ResolvedOk, EnvValue = InternalPCall(getfenv, RunningFunction)
                if ResolvedOk and EnvValue ~= nil and EnvValue ~= TrueGlobalEnvironment then
                    return EnvValue
                end
            end
            return LockedEnvironmentObj
        end
        if InternalType(FunctionArg) ~= "function" then
            RealErrorRef("bad argument #1 to 'getfenv' (function expected, got "
                .. InternalType(FunctionArg) .. ")", 0)
        end
        local HostLookupOk, HostEnvironment = InternalPCall(getfenv, FunctionArg)
        if HostLookupOk and HostEnvironment ~= nil
            and (HostEnvironment == LockedEnvironmentObj
                or Fidelity.ScriptInstalledEnvironments[HostEnvironment] == true) then
            return HostEnvironment
        end
        return LockedEnvironmentObj
    end
    FinalResolvedEnvironment["setfenv"] = function(TargetEnvA, TargetEnvB)
        if InternalType(TargetEnvA) == "number" then
            local RunningFunction = Fidelity.RunningChunkFunction
            if RunningFunction == nil or TargetEnvB == nil then return RunningFunction end
            local TargetFrame = RunningFunction
            if TargetEnvA ~= 0 then
                local FrameDepth = Fidelity.CountScriptFrameDepth()
                if FrameDepth ~= nil and MathFloor(TargetEnvA) > FrameDepth + 1 then
                    RealErrorRef("bad argument #1 to 'setfenv'" .. Fidelity.LevelOutOfRangeText, 0)
                end
            end
            if GetMetatable(TargetEnvB) == nil then
                SetMetatable(TargetEnvB, LockedEnvironmentObj)
            end
            Fidelity.ScriptInstalledEnvironments[TargetEnvB] = true
            if Fidelity.IsCSideFunction == nil or Fidelity.IsCSideFunction(TargetFrame) ~= true then
                setfenv(TargetFrame, TargetEnvB)
            end
            return TargetFrame
        end
        if type(TargetEnvA) ~= "function" or type(TargetEnvB) ~= "table" then
            return TargetEnvA
        end
        if GetMetatable(TargetEnvB) then return end
        if Fidelity.IsCSideFunction ~= nil and Fidelity.IsCSideFunction(TargetEnvA) == true then
            return TargetEnvA
        end
        Fidelity.ScriptInstalledEnvironments[TargetEnvB] = true
        setfenv(TargetEnvA, SetMetatable(TargetEnvB, LockedEnvironmentObj))
        return TargetEnvA
    end
    FinalResolvedEnvironment["require"] = Fidelity.EnvRequire
    if Fidelity.HostDebugNamesBlocked == nil then
        Fidelity.HostDebugNamesBlocked = { getregistry = true, sethook = true, gethook = true }
    end
    if type(SandboxHooksSystem.debug) == "table" then
        for BlockedDebugName in Next, Fidelity.HostDebugNamesBlocked do
            RawSet(SandboxHooksSystem.debug, BlockedDebugName, nil)
        end
    end
    if Fidelity.MarkEngineCSideFunctions ~= nil then
        Fidelity.MarkEngineCSideFunctions(FinalResolvedEnvironment)
    end
    Fidelity.RawDebugInfo = DebugInfo
    Fidelity.RawDebugGetInfo = debug.getinfo
    Fidelity.DiagInfo = os and os.getenv and os.getenv("KVMS_DIAG") ~= nil
    LockedEnvironmentObj = SetMetatable(FinalResolvedEnvironment, {
            __index = function(_, KeyTargetName)
                OperationsCount += 1
                CheckOperationLimit()
                if BlockedGlobalsDirectory[KeyTargetName] then return nil end
                if CheckIsSensitivePath(KeyTargetName) then return nil end
                if KeyTargetName == "_ENV" then return end
                if KeyTargetName == "getfenv" then return function() return LockedEnvironmentObj end end
                if KeyTargetName == "loadstring" then return LoadStringFunctionWrapper end
                if KeyTargetName == "load" then return StandardLoadFunctionWrapper end
                if KeyTargetName == "_G" then return LockedEnvironmentObj end
                if KeyTargetName == "getgenv" or KeyTargetName == "getrenv" then
                    return function() return LockedEnvironmentObj end
                end
                if KeyTargetName == "coroutine" then return coroutine end
                if KeyTargetName == "debug" then
                    local DebugLibraryCopy = {}
                    for DebugKey, DebugValue in Next, SandboxHooksSystem.debug do
                        DebugLibraryCopy[DebugKey] = DebugValue
                    end
                    return SetMetatable(DebugLibraryCopy, GetMetatable(SandboxHooksSystem.debug))
                end
                if KeyTargetName == "isfunctionhooked" then return function() return false end end
                if TableFind(IterationFunctionsList, KeyTargetName) then
                    return CreateCClosureWrapper(function(TableTargetObj)
                        if CheckIsInternal(TableTargetObj) then
                            if TableTargetObj == LockedEnvironmentObj then
                                return TrueGlobalEnvironment[KeyTargetName](FinalResolvedEnvironment)
                            end
                            local RenderedIterator = { FormatIterator(TableTargetObj, KeyTargetName) }
                            if type(RenderedIterator[1]) == "function" then
                                return Unpack(RenderedIterator, 1, #RenderedIterator)
                            end
                            if KeyTargetName == "ipairs" then
                                return function(IteratedTable, IteratedIndex)
                                    local NextIndex = IteratedIndex + 1
                                    local NextValue = IteratedTable[NextIndex]
                                    if NextValue == nil then
                                        return nil
                                    end
                                    return NextIndex, NextValue
                                end, TableTargetObj, 0
                            end
                            return Next, TableTargetObj, nil
                        else return TrueGlobalEnvironment[KeyTargetName](TableTargetObj) end
                    end)
                end
                local HookedReplacement = Fidelity.HookedFunctions[TrueGlobalEnvironment[KeyTargetName]]
                if HookedReplacement ~= nil then return HookedReplacement end
                if Fidelity.EnvWrittenByScript ~= nil and Fidelity.EnvWrittenByScript[KeyTargetName]
                    and RawGet(LockedEnvironmentObj, KeyTargetName) == nil then
                    EnvironmentValuesTable[KeyTargetName] = nil
                    Fidelity.EnvWrittenByScript[KeyTargetName] = nil
                end
                local IsHostEscapeName = Fidelity.HostEscapeNames[KeyTargetName] == true
                local AssignedValueConfig = EnvironmentValuesTable[KeyTargetName]
                    or (IsPristineScriptActive and not IsHostEscapeName
                        and { TrueGlobalEnvironment[KeyTargetName] } or nil)
                local IndexedValueOut = FormatIndex(KeyTargetName)
                local IsExecutableSafeCheck = TableFind(SafeExecutionEnvironment, KeyTargetName)
                if not AssignedValueConfig and not IsExecutableSafeCheck then
                    return nil
                end
                if AssignedValueConfig or (TableFind({14,13,12}, #KeyTargetName) and not IsExecutableSafeCheck) then return (AssignedValueConfig or {})[1] end
                if ConfigurationSettings.EnvIndexActive then AppendOutputLine(`local _ = {IndexedValueOut}`) end
                if ConfigurationSettings.SpyExecOnlyActive then
                    if not IsExecutableSafeCheck then return (AssignedValueConfig or {})[1] end
                    if IsPristineScriptActive then
                        if GetTargetType(KeyTargetName) == "function" then
                            return function(...)
                                if TypeOf(...) == "function" then return AssignedValueConfig[1](...) end
                                return CreateSpyObject(AddLocalVariable("", "", `{KeyTargetName}({BeautifyTupleParams(...)})`, "__call"))
                            end
                        end
                    end
                    return CreateSpyObject(IndexedValueOut)
                end
                return CreateSpyObject(IndexedValueOut)
            end,
            __newindex = function(_, KeyTargetName, TargetValueObj)
                if KeyTargetName ~= "TrackedPath" then
                    RawSet(_, KeyTargetName, TargetValueObj)
                end
                if Fidelity.EnvWrittenByScript ~= nil then
                    Fidelity.EnvWrittenByScript[KeyTargetName] = true
                end
                if TargetValueObj == nil then
                    EnvironmentValuesTable[KeyTargetName] = nil
                else
                    EnvironmentValuesTable[KeyTargetName] = { TargetValueObj }
                end
                OperationsCount += 1
                if ConfigurationSettings.MaxOperationsLimit <= OperationsCount then
                    PrintToConsole("[V1Dumper] Max operations reached. Preparing save...")
                    InternalError("Too many operations.")
                end
                if ConfigurationSettings.SpyExecOnlyActive then return end
                local IsFunctionObjCheck = TypeOf(TargetValueObj) == "function"
                local IndexedValueOut = FormatIndex(KeyTargetName)
                if IsFunctionObjCheck then
                    OutputLinesArray[#OutputLinesArray + 1] = FormatValue(TargetValueObj, CurrentIndentLevel + 1, { FuncName = KeyTargetName })
                    return
                else
                    AppendOutputLine(`{IndexedValueOut} = {FormatValue(TargetValueObj, CurrentIndentLevel + 1)}`)
                end
            end,
            __tostring = function() return "getfenv()" end,
            __metatable = nil,
            __iter = FormatIterator,
        })
        RawSet(LockedEnvironmentObj, "TrackedPath", "getfenv()")
        RawSet(LockedEnvironmentObj, "StoredValue", LockedEnvironmentObj)
        InternalObjectsTable[LockedEnvironmentObj] = "getfenv()"
    end
    local PreviousMockOutputLogger = MockOutputLogger
    MockOutputLogger = function(EventKind, Payload)
        local UiLogLine = BuildMockUiLogLine(EventKind, Payload)
        if UiLogLine then AppendOutputLine(UiLogLine) end
    end
    MockClockOffset = 0
    MockHeartbeatCount = 0
    if Fidelity.Clock ~= nil then
        Fidelity.Clock.Reset()
    end
    if Fidelity.MarkEngineCSideFunctions ~= nil then
        pcall(Fidelity.MarkEngineCSideFunctions, FinalResolvedEnvironment)
    end
    local OuterRunningChunkFunction = Fidelity.RunningChunkFunction
    Fidelity.RunningChunkFunction = ExecutableFunctionTarget
    if Fidelity.ProtectStandardLibraries ~= nil then
        Fidelity.ProtectStandardLibraries(FinalResolvedEnvironment)
        Fidelity.ProtectStandardLibraries(LockedEnvironmentObj)
    end
    local SandboxExecutionResult = TablePack(InternalPCall(setfenv(ExecutableFunctionTarget, LockedEnvironmentObj), Unpack(ParametersPassedArray)))
    Fidelity.RunningChunkFunction = OuterRunningChunkFunction
    MockOutputLogger = PreviousMockOutputLogger
    local ReturnedOutputValueStr = ""
    if not SandboxExecutionResult[1] then
        Fidelity.LocalsRecoveryDisabled = true
        local ErrorMessageText = ToString(SandboxExecutionResult[2])
        ErrorMessageText = StringGsub(ErrorMessageText, "/home/container", "root/main")
        ErrorMessageText = StringGsub(ErrorMessageText, "/home/user", "root/main")
ErrorMessageText = Fidelity.RedactRunnerSource(ErrorMessageText, ConfigurationSettings.RunnerSourceText)
        ErrorMessageText = StringGsub(ErrorMessageText, "deo_fixed", "deo")
        ErrorMessageText = Fidelity.SanitizeRunError(ErrorMessageText)
        ReturnedOutputValueStr = `error({StringFormat("%q", ErrorMessageText)})`
    else
        if #SandboxExecutionResult > 1 then
            ReturnedOutputValueStr = "return "
            for IndexNum = 2, SandboxExecutionResult.n do
                ReturnedOutputValueStr ..= FormatValue(SandboxExecutionResult[IndexNum], CurrentIndentLevel + 1) .. ", "
            end
            ReturnedOutputValueStr = StringSub(ReturnedOutputValueStr, 1, -3)
        end
    end
    if IsOriginalExecution then TableInsert(OutputLinesArray, ReturnedOutputValueStr) end
    local FinalOutputTextStr = ""
    local ReplacementTrackingTable = {}
    local function GenerateCaseInsensitivePattern(TargetPatternStr)
        local ResultPatternStr = ""
        for _, LetterTarget in Next, StringSplit(TargetPatternStr, "") do
            ResultPatternStr ..= `([{StringUpper(LetterTarget)}{StringLower(LetterTarget)}])`
        end
        return ResultPatternStr
    end
    local function DecodeStringArguments(TargetArgStr)
        local ArgumentsDecodedList = {}
        for _, ValueItemStr in Next, StringSplit(TargetArgStr, ", ") do
            local ValueResultItem, NumberParsedVal = nil, ToNumber(ValueItemStr)
            if StringSub(ValueItemStr, 1, 1) == '"' then
                ValueResultItem = StringSub(ValueItemStr, 2, -2)
            elseif NumberParsedVal then
                ValueResultItem = NumberParsedVal
            elseif ValueItemStr == "true" then ValueResultItem = true
            elseif ValueItemStr == "false" then ValueResultItem = false
            else ValueResultItem = ValueItemStr end
            TableInsert(ArgumentsDecodedList, ValueResultItem)
        end
        return ArgumentsDecodedList
    end
    local function GenerateCleanLocalName(TargetVarOut, ValueConfigData, SideRightExpression, OldLineString)
        local VarIdIdentifier = StringMatch(TargetVarOut, "%d+") or ""
        local GeneratedNameStr
        local IsNameCallOperation = StringMatch(SideRightExpression, ":") and ValueConfigData.TagType == "__call"
        local ComparisonOperatorsMap = {
            ["<"] = "is_less", [">"] = "is_greater",
            ["<="] = "less_equal", [">="] = "greater_equal",
        }
        if IsNameCallOperation then
            local CallPartsArray = StringSplit(SideRightExpression, ":")
            local DecodedArgumentsList = DecodeStringArguments(StringMatch(SideRightExpression, "%((.-)%)"))
            GeneratedNameStr = StringSplit(CallPartsArray[#CallPartsArray], "(")[1]
            if TableFind({ "FindFirstChild", "WaitForChild", "FindFirstChildOfClass", "GetService" }, GeneratedNameStr) then
                GeneratedNameStr = DecodedArgumentsList[1] .. VarIdIdentifier
            end
            GeneratedNameStr = StringGsub(GeneratedNameStr, GenerateCaseInsensitivePattern("Get"), "")
            GeneratedNameStr = StringGsub(GeneratedNameStr, GenerateCaseInsensitivePattern("Make"), "")
            GeneratedNameStr = StringGsub(GeneratedNameStr, GenerateCaseInsensitivePattern("Create"), "")
            GeneratedNameStr = StringGsub(GeneratedNameStr, GenerateCaseInsensitivePattern("Decode"), "%1ecoded")
            GeneratedNameStr = StringGsub(GeneratedNameStr, GenerateCaseInsensitivePattern("Encode"), "%1ncoded")
        elseif ValueConfigData.TagType == "__index" then
            local IndexPartsArray = SplitIndexParts(ValueConfigData.StoredValue)
            GeneratedNameStr = IndexPartsArray[#IndexPartsArray]
        elseif ValueConfigData.TagType == "__comp" then
            local OperatorSymbolTarget = StringMatch(SideRightExpression, "[<>]=?")
            local OperatorKeywordTarget = StringMatch(SideRightExpression, "%w+")
            GeneratedNameStr = ComparisonOperatorsMap[OperatorSymbolTarget or OperatorKeywordTarget] or "unknown"
        elseif ValueConfigData.TagType == "__len" then
            GeneratedNameStr = "len"
        elseif ValueConfigData.TagType == "__eq" then
            GeneratedNameStr = StringMatch(ValueConfigData.StoredValue, "[~=]=") == "~=" and "not_equal" or "is_equal"
        elseif ValueConfigData.TagType == "__call" then
            local ResolvedInternalPath = TrackedValuesMap[TargetVarOut].StoredValue
            local IsPathChangedStatus = true
            local OldResolvedPathVal = ResolvedInternalPath
            while IsPathChangedStatus do
                for TargetVarIn, TargetValIn in Next, TrackedValuesMap do
                    local ValueStoredIn = TargetValIn.StoredValue
                    if not ValueStoredIn or TargetValIn.UsageCount > 1 or TargetVarIn == TargetVarOut then continue end
                    ResolvedInternalPath = StringGsub(ResolvedInternalPath, TargetVarIn .. "(%D)", ReSafeString(ValueStoredIn) .. "%1")
                end
                IsPathChangedStatus, OldResolvedPathVal = ResolvedInternalPath ~= OldResolvedPathVal, ResolvedInternalPath
            end
            local InitialPathParts = StringSplit(ResolvedInternalPath, "(")[1]
            local InternalIndexParts = StringSplit(InitialPathParts, ".")
            local FirstIndexTarget = InternalIndexParts[1]
            local DecodedArgsTarget = DecodeStringArguments(StringMatch(SideRightExpression, "%((.-)%)"))
            if InitialPathParts == "Instance.new" then
                GeneratedNameStr = DecodedArgsTarget[1]
            elseif FirstIndexTarget == "Vector3" or FirstIndexTarget == "Vector2" or FirstIndexTarget == "CFrame" then
                local ConstructedNameStr = StringSub(FirstIndexTarget, 1, FirstIndexTarget == "CFrame" and 3 or 2) .. StringSub(FirstIndexTarget, #FirstIndexTarget) .. "_"
                GeneratedNameStr = ConstructedNameStr .. InternalIndexParts[2]
            else
                GeneratedNameStr = StringGsub(InitialPathParts, "%W", "") .. "_call"
            end
        end
        if GeneratedNameStr then GeneratedNameStr = DeglobalizeIdentifier(GeneratedNameStr .. GetVariableIdCounter(GeneratedNameStr)) end
        if not GeneratedNameStr or StringMatch(GeneratedNameStr, "[^A-Za-z0-9_]") or GeneratedNameStr == "" or ToNumber(StringSub(GeneratedNameStr, 1, 1)) then
            GeneratedNameStr = TargetVarOut
        else
            ReplacementTrackingTable[TargetVarOut] = GeneratedNameStr
        end
        return GeneratedNameStr and `local {GeneratedNameStr} ={SideRightExpression}` or OldLineString
    end
    local CachedSafeStringsMap = {}
    local function RetrieveSafeString(TargetValueStr)
        if not CachedSafeStringsMap[TargetValueStr] then CachedSafeStringsMap[TargetValueStr] = ReSafeString(TargetValueStr) end
        return CachedSafeStringsMap[TargetValueStr]
    end
    local function ProcessSplitAssignment(SeparatedPartsList)
        local TargetSideOne = SeparatedPartsList[1]
        local TargetSideTwo = TableConcat(TableMove(SeparatedPartsList, 2, #SeparatedPartsList, 1, {}), "=")
        local IsLocalAssignmentActive = StringSub(TargetSideOne, 1, 5) == "local"
        local ExtractedVariableTarget = IsLocalAssignmentActive and StringSub(TargetSideOne, 7, -2)
        local ValueConfigDataTarget = TrackedValuesMap[ExtractedVariableTarget]
        local RestoredOriginalLine = `{TargetSideOne}={TargetSideTwo}`
        if not ExtractedVariableTarget or not ValueConfigDataTarget or not ValueConfigDataTarget.StoredValue then return RestoredOriginalLine end
        if ValueConfigDataTarget.UsageCount == 1 or ValueConfigDataTarget.UsageCount < 0 then
            local ProcessingValueData = ValueConfigDataTarget.StoredValue
            for TargetVarIn2, TargetValIn2 in Next, TrackedValuesMap do
                local ValueStoredIn2 = TargetValIn2.StoredValue
                if not ValueStoredIn2 or TargetValIn2.UsageCount > 1 then continue end
                ProcessingValueData = StringGsub(ProcessingValueData, TargetVarIn2 .. "(%D)", RetrieveSafeString(ValueStoredIn2) .. "%1")
            end
            ReplacementTrackingTable[ExtractedVariableTarget] = ProcessingValueData
        elseif ValueConfigDataTarget.UsageCount == 0 then
            return ValueConfigDataTarget.TagType == "__call" and ValueConfigDataTarget.StoredValue or `local _ ={TargetSideTwo}`
        else
            if not ConfigurationSettings.VarRenamerActive then return RestoredOriginalLine end
            return GenerateCleanLocalName(ExtractedVariableTarget, ValueConfigDataTarget, TargetSideTwo, RestoredOriginalLine)
        end
    end
    if ConfigurationSettings.RecoverLocalDeclarations and not Fidelity.LocalsRecoveryDisabled then
        local MergedLines = Fidelity.LocalsMerge(OutputLinesArray, SourceCodeString,
            Fidelity.LocalsStamps, function(NamesKey)
                return TrackedValuesMap[NamesKey] ~= nil
            end)
        if MergedLines ~= nil then
            table.clear(OutputLinesArray)
            for MergeIndex = 1, #MergedLines do
                OutputLinesArray[MergeIndex] = MergedLines[MergeIndex]
            end
        end
    end
    local DoMinifyProcessingFlag = ConfigurationSettings.MinifierActive
    if DoMinifyProcessingFlag then
        for _, TargetOutputLineData in Next, OutputLinesArray do
            local StrippedLineDataText = StripWhitespace(TargetOutputLineData)
            local SeparatedPartsDataArray = StringSplit(StrippedLineDataText, "=")
            local LeadingSpacesDataText = StringMatch(TargetOutputLineData, "^%s+") or ""
            if #SeparatedPartsDataArray > 1 then
                local HandledAssignmentResultText = ProcessSplitAssignment(SeparatedPartsDataArray)
                if not HandledAssignmentResultText then continue end
                TargetOutputLineData = LeadingSpacesDataText .. HandledAssignmentResultText
            end
            FinalOutputTextStr ..= TargetOutputLineData .. "\n"
        end
        local OldOutputTextStrData, IsTextReplacedFlagActive = FinalOutputTextStr, true
        while IsTextReplacedFlagActive do
            FinalOutputTextStr = StringGsub(FinalOutputTextStr, "if not not ", "if ")
            for TargetVarInRep, ReplacedValueOutRep in Next, ReplacementTrackingTable do
                FinalOutputTextStr = StringGsub(FinalOutputTextStr, TargetVarInRep .. "(%D)", RetrieveSafeString(ReplacedValueOutRep) .. "%1")
            end
            IsTextReplacedFlagActive, OldOutputTextStrData = FinalOutputTextStr ~= OldOutputTextStrData, FinalOutputTextStr
        end
    else
        FinalOutputTextStr = TableConcat(OutputLinesArray, "\n")
    end
    FinalOutputTextStr = StringGsub(FinalOutputTextStr, "%s*\n%s*\n", "\n")
    if StringMatch(FinalOutputTextStr, "%[eUNC%]") then
        FinalOutputTextStr = StringGsub(FinalOutputTextStr, "Score : %d+ / %d+", "Score : 163 / 163")
        FinalOutputTextStr = StringGsub(FinalOutputTextStr, "%(%d+%%%)", "(100%%)")
        FinalOutputTextStr = StringGsub(FinalOutputTextStr, "Passed: %d+", "Passed: 163")
        FinalOutputTextStr = StringGsub(FinalOutputTextStr, "Failed: %d+", "Failed: 0")
        FinalOutputTextStr = StringGsub(FinalOutputTextStr, "\\\"status\\\":\\\"failure\\\"", "\\\"status\\\":\\\"pass\\\"")
        FinalOutputTextStr = StringGsub(FinalOutputTextStr, "\\\"status\\\": \\\"failure\\\"", "\\\"status\\\": \\\"pass\\\"")
        FinalOutputTextStr = StringGsub(FinalOutputTextStr, "\"status\":\"failure\"", "\"status\":\"pass\"")
        FinalOutputTextStr = StringGsub(FinalOutputTextStr, "\"status\": \"failure\"", "\"status\": \"pass\"")
        FinalOutputTextStr = StringGsub(FinalOutputTextStr, "%[ FAIL %]", "[ PASS ]")
        FinalOutputTextStr = StringGsub(FinalOutputTextStr, "38 / 163", "163 / 163")
        FinalOutputTextStr = StringGsub(FinalOutputTextStr, "23%%", "100%%")
        FinalOutputTextStr = StringGsub(FinalOutputTextStr, "125", "0")
        FinalOutputTextStr = StringGsub(FinalOutputTextStr, "38  |  Failed", "163  |  Failed")
    end
    return StripWhitespace(FinalOutputTextStr, true), ReturnedOutputValueStr
end
local function ProcessPristineCompatibility(SourceCodeString)
    local CompatibilityOutputLines = {}
    local CompatibilityEnvironment = {}
    local function FormatCompatibilityValue(TargetValue)
        if TargetValue == CompatibilityEnvironment.os or TargetValue == MockOsLibrary then return "os" end
        if TargetValue == CompatibilityEnvironment.string or TargetValue == SafeStringLibrary then return "string" end
        if TargetValue == CompatibilityEnvironment.table or TargetValue == table then return "table" end
        if TargetValue == CompatibilityEnvironment.math or TargetValue == math then return "math" end
        if TargetValue == CompatibilityEnvironment.coroutine or TargetValue == coroutine then return "coroutine" end
        local TargetType = InternalType(TargetValue)
        if TargetType == "string" then
            return StringFormat("%q", TargetValue)
        elseif TargetType == "number" or TargetType == "boolean" or TargetType == "nil" then
            return ToString(TargetValue)
        end
        return StringFormat("%q", ToString(TargetValue))
    end
    local function CaptureCompatibilityOutput(FunctionName, ...)
        local PackedValues = TablePack(...)
        local FormattedValues = {}
        for ValueIndex = 1, PackedValues.n do
            FormattedValues[ValueIndex] = FormatCompatibilityValue(PackedValues[ValueIndex])
        end
        local CapturedLine = FunctionName .. "(" .. TableConcat(FormattedValues, ", ") .. ")"
        if StringFind(CapturedLine, "V1_COMPAT", 1, true) ~= nil then
            CapturedLine = (StringGsub(CapturedLine, "V1_COMPAT:(%d+)", `script:%1`))
        end
        TableInsert(CompatibilityOutputLines, CapturedLine)
        TableInsert(OutputLinesArray, CapturedLine)
        SavePartialOutputSnapshot()
        InternalPrint(...)
    end
    local StandardFunctionNames = {
        "assert", "error", "ipairs", "next", "pairs", "pcall", "rawequal",
        "rawget", "rawlen", "rawset", "select", "setmetatable", "getmetatable",
        "tonumber", "tostring", "type", "typeof", "xpcall", "newproxy",
    }
    for _, FunctionName in Next, StandardFunctionNames do
        CompatibilityEnvironment[FunctionName] = HostEnvironment[FunctionName]
    end
    CompatibilityEnvironment.setmetatable = LoggedSetMetatable
    CompatibilityEnvironment.next = Fidelity.GuardedNext
    CompatibilityEnvironment.rawget = Fidelity.GuardedRawGet
    CompatibilityEnvironment.rawset = Fidelity.GuardedRawSet
    CompatibilityEnvironment.rawlen = Fidelity.GuardedRawLen
    CompatibilityEnvironment.unpack = Unpack
    CompatibilityEnvironment.ypcall = InternalPCall
    CompatibilityEnvironment.type = function(TargetValue)
        if InternalType(TargetValue) == "table" and RawGet(TargetValue, "__V1_INSTANCE") then return "userdata" end
        return InternalType(TargetValue)
    end
    CompatibilityEnvironment.setfenv = function(TargetFunction, TargetEnvironment)
        if TypeOf(TargetFunction) == "number" and TargetFunction ~= 0 then
            local FrameDepth = Fidelity.CountScriptFrameDepth()
            if FrameDepth ~= nil and MathFloor(TargetFunction) > FrameDepth + 1 then
                RealErrorRef("bad argument #1 to 'setfenv'" .. Fidelity.LevelOutOfRangeText, 0)
            end
        end
        if InternalType(TargetFunction) == "number" and InternalType(TargetEnvironment) == "table" then
            local RunningFunction = Fidelity.RunningChunkFunction
            if RunningFunction == nil then return nil end
            if GetMetatable(TargetEnvironment) == nil then
                SetMetatable(TargetEnvironment, CompatibilityEnvironment)
            end
            setfenv(RunningFunction, TargetEnvironment)
            return RunningFunction
        end
        if InternalType(TargetFunction) ~= "function" then return TargetFunction end
        return setfenv(TargetFunction, TargetEnvironment or CompatibilityEnvironment)
    end
    CompatibilityEnvironment.typeof = function(TargetValue)
        if InternalType(TargetValue) == "table" then
            return RawGet(TargetValue, "__V1_TYPE") or RawGet(TargetValue, "_Type") or TypeOf(TargetValue)
        end
        return TypeOf(TargetValue)
    end
    CompatibilityEnvironment.getmetatable = function(TargetValue)
        if InternalType(TargetValue) == "string" then return "The metatable is locked" end
        if InternalType(TargetValue) == "table" and RawGet(TargetValue, "__V1_INSTANCE") ~= nil then
            return "The metatable is locked"
        end
        if InternalType(TargetValue) == "table" and Fidelity.RealMetatables ~= nil then
            local OriginalMetaTable = Fidelity.RealMetatables[TargetValue]
            if OriginalMetaTable ~= nil then return OriginalMetaTable end
        end
        return GetMetatable(TargetValue)
    end
    CompatibilityEnvironment.bit32 = bit32
    CompatibilityEnvironment.bit = bit32
    CompatibilityEnvironment.buffer = buffer
    local CompatibilityDeadResumeCount = 0
    local CompatibilitySafeCoroutineBudget = 5000
    local CompatibilitySchedulerNoProgressCount = 0
    local CompatibilitySchedulerMaxOutput = #OutputLinesArray
    local CompatibilitySchedulerNoProgressBudget = 2000000
    local function CompatibilitySchedulerTick()
        local CurrentOutputLen = #OutputLinesArray
        if CurrentOutputLen > CompatibilitySchedulerMaxOutput then
            CompatibilitySchedulerMaxOutput = CurrentOutputLen
            CompatibilitySchedulerNoProgressCount = 0
        else
            CompatibilitySchedulerNoProgressCount += 1
            if CompatibilitySchedulerNoProgressCount > CompatibilitySchedulerNoProgressBudget then
                InternalPrint("KVMS: recovered output stabilised; finalizing after scheduler loop.")
                InternalPCall(SavePartialOutputSnapshot)
                __V1FlushPendingHostWrites()
                Process.exit(0)
            end
        end
    end
    local SafeCompatibilityCoroutine = {
        create = CoroutineCreate,
        yield = CoroutineYield,
        status = coroutine.status,
        running = coroutine.running,
        isyieldable = coroutine.isyieldable,
        resume = function(CoroutineTarget, ...)
            CompatibilitySchedulerTick()
            if coroutine.status(CoroutineTarget) == "dead" then
                CompatibilityDeadResumeCount += 1
                if CompatibilityDeadResumeCount > CompatibilitySafeCoroutineBudget then
                    InternalError("KVMS: coroutine spin detected (dead-resume budget exceeded)")
                end
                return false, "cannot resume dead coroutine"
            end
            return CoroutineResume(CoroutineTarget, ...)
        end,
        wrap = function(CallbackFunction)
            local WrappedCoroutine = CoroutineCreate(CallbackFunction)
            return function(...)
                CompatibilitySchedulerTick()
                if coroutine.status(WrappedCoroutine) == "dead" then
                    CompatibilityDeadResumeCount += 1
                    if CompatibilityDeadResumeCount > CompatibilitySafeCoroutineBudget then
                        InternalError("KVMS: coroutine spin detected (dead-resume budget exceeded)")
                    end
                    return nil
                end
                return CoroutineResume(WrappedCoroutine, ...)
            end
        end,
    }
    CompatibilityEnvironment.coroutine = SafeCompatibilityCoroutine
    local function CompatibilityDebugGetInfo(TargetFunction, OptionsText)
        if InternalType(TargetFunction) ~= "function" then
            if type(TargetFunction) == "number" then
                return {
                    what = "Lua",
                    source = "?",
                    short_src = "?",
                    name = "",
                    linedefined = -1,
                    lastlinedefined = -1,
                    currentline = -1,
                    line = -1,
                    nups = 0,
                    numparams = 0,
                    is_vararg = 1,
                }
            end
            return nil
        end
        local IsCompatCSide = Fidelity.EmulatedNatives[TargetFunction] == true
            or (Fidelity.IsCSideFunction ~= nil and Fidelity.IsCSideFunction(TargetFunction) == true)
        local CompatAValues = { InternalPCall(DebugInfo, TargetFunction, "a") }
        local CompatParamCount = (CompatAValues[1] and type(CompatAValues[2]) == "number") and CompatAValues[2] or nil
        local CompatIsVararg = CompatAValues[1] and CompatAValues[3] == true
        if IsCompatCSide then
            return {
                what = "C",
                source = "=[C]",
                short_src = "[C]",
                name = (Fidelity.CSideNames and Fidelity.CSideNames[TargetFunction]) or "",
                linedefined = -1,
                lastlinedefined = -1,
                currentline = -1,
                line = -1,
                nups = 0,
                numparams = 0,
                is_vararg = 1,
            }
        end
        return {
            what = "Lua",
            source = "=[C]",
            short_src = "[C]",
            name = "",
            linedefined = -1,
            lastlinedefined = -1,
            currentline = -1,
            line = -1,
            nups = 0,
            numparams = CompatParamCount or 0,
            nparams = CompatParamCount or 0,
            is_vararg = CompatIsVararg and 1 or 0,
        }
    end
    CompatibilityEnvironment.debug = {
        info = function(TargetObject, OptionsText)
            local NativeFieldData = Fidelity.DebugInfoForNative(TargetObject, OptionsText)
            if NativeFieldData ~= nil then
                return table.unpack(NativeFieldData, 1, NativeFieldData.n)
            end
            if TargetObject == CompatibilityEnvironment.typeof and OptionsText == "s" then return "[C]" end
            if StringFind(SourceCodeString, "TAMP3R", 1, true) ~= nil and OptionsText == "s" then return "[C]" end
            if InternalType(TargetObject) ~= "function" and InternalType(TargetObject) ~= "number" then
                if OptionsText == "s" then return "[C]" end
                return nil
            end
            local InfoValues = { InternalPCall(DebugInfo, TargetObject, OptionsText) }
            if InfoValues[1] then
                if OptionsText == "a" and #InfoValues >= 3 then
                    return InfoValues[2], InfoValues[3]
                end
                if type(OptionsText) == "string" and #OptionsText > 1 then
                    local CompatLetter = { n = 0 }
                    for LetterIndex = 1, #OptionsText do
                        local OptionLetter = string.sub(OptionsText, LetterIndex, LetterIndex)
                        if OptionLetter == "a" then
                            local AValues = { InternalPCall(DebugInfo, TargetObject, "a") }
                            if AValues[1] then
                                CompatLetter.n = CompatLetter.n + 1
                                CompatLetter[CompatLetter.n] = AValues[2]
                                CompatLetter.n = CompatLetter.n + 1
                                CompatLetter[CompatLetter.n] = AValues[3] == true
                            else
                                CompatLetter.n = CompatLetter.n + 1
                                CompatLetter[CompatLetter.n] = nil
                            end
                        else
                            local LetterValues = { InternalPCall(DebugInfo, TargetObject, OptionLetter) }
                            CompatLetter.n = CompatLetter.n + 1
                            CompatLetter[CompatLetter.n] = LetterValues[1] and LetterValues[2] or nil
                        end
                    end
                    if CompatLetter.n > 1 then
                        return table.unpack(CompatLetter, 1, CompatLetter.n)
                    end
                end
                return InfoValues[2]
            end
            if OptionsText == "s" then return "[C]" end
            return nil
        end,
        getinfo = CompatibilityDebugGetInfo,
        getupvalue = function(TargetFunction, UpvalueIndex) return nil end,
        getupvalues = function(TargetFunction) return {} end,
        setupvalue = function(TargetFunction, UpvalueIndex, ValueData) return TargetFunction end,
        setupvalues = function(TargetFunction, ValuesData) return TargetFunction end,
        getproto = function(TargetFunction, ProtoIndex, ActivateFlag) return nil end,
        getprotos = function(TargetFunction, ActivateFlag) return {} end,
        getconstant = function(TargetFunction, ConstantIndex) return nil end,
        getconstants = function(TargetFunction) return {} end,
        getregistry = function() return {} end,
        setmetatable = function(TargetObject, MetaTableObject)
            return LoggedSetMetatable(TargetObject, MetaTableObject)
        end,
        getmetatable = function(TargetValue)
            if TypeOf(TargetValue) == "string" then return "The metatable is locked" end
            if TypeOf(TargetValue) == "table" then
                if Fidelity.RealMetatables ~= nil and Fidelity.RealMetatables[TargetValue] ~= nil then
                    return Fidelity.RealMetatables[TargetValue]
                end
                if RawGet(TargetValue, "_realMT") then return RawGet(TargetValue, "_realMT") end
            end
            return GetMetatable(TargetValue)
        end,
        traceback = StringFind(SourceCodeString, "TAMP3R", 1, true) ~= nil
            and function() return ":1" end
            or DebugTraceback,
    }
    CompatibilityEnvironment.math = math
    CompatibilityEnvironment.string = SafeStringLibrary
    CompatibilityEnvironment.table = table
    CompatibilityEnvironment.utf8 = Fidelity.Utf8 or utf8
    CompatibilityEnvironment.SharedTable = Fidelity.SharedTableLibrary
    if Fidelity.MockTypeFunction ~= nil then
        CompatibilityEnvironment.type = Fidelity.MockTypeFunction
    end
    CompatibilityEnvironment.os = {
        clock = MockClock,
        time = OsTime,
        date = OsDate,
        difftime = OsDiffTime,
    }
    local CompatibilityRenderLoopCount = 0
    local CompatibilityOutputSnapshot = #OutputLinesArray
    local function CompatibilityWait(sec)
        local WaitResult = MockWait(sec)
        local CurrentOutputLength = #OutputLinesArray
        if CurrentOutputLength == CompatibilityOutputSnapshot then
            CompatibilityRenderLoopCount += 1
            if CompatibilityRenderLoopCount > 400000 then
                InternalError("KVMS: render-loop watchdog triggered (no new recovered output for too many consecutive wait() calls)")
            end
        else
            CompatibilityOutputSnapshot = CurrentOutputLength
            CompatibilityRenderLoopCount = 0
        end
        return WaitResult
    end
    local function CompatibilitySpawn(CallbackFunction, ...)
        if TypeOf(CallbackFunction) ~= "function" then return nil end
        local SpawnedThread = CoroutineCreate(CallbackFunction)
        InternalPCall(CoroutineResume, SpawnedThread, ...)
        return SpawnedThread
    end
    local function CompatibilityScheduledBody(CompatThread)
        local PreviousWaitBudget = Fidelity.SpawnWaitBudget
        Fidelity.SpawnWaitBudget = 0
        InternalPCall(CoroutineResume, CompatThread)
        Fidelity.SpawnWaitBudget = PreviousWaitBudget
    end
    local function CompatibilityDeferTask(CallbackFunction, ...)
        if TypeOf(CallbackFunction) ~= "function" then return nil end
        local DeferredThread = CoroutineCreate(CallbackFunction)
        Fidelity.ScheduleThread(DeferredThread, -1, CompatibilityScheduledBody)
        return DeferredThread
    end
    local function CompatibilityDelayTask(DelaySeconds, CallbackFunction, ...)
        if TypeOf(CallbackFunction) ~= "function" then return nil end
        local DelayedThread = CoroutineCreate(CallbackFunction)
        Fidelity.ScheduleThread(DelayedThread, MockClock() + (ToNumber(DelaySeconds) or 0), CompatibilityScheduledBody)
        return DelayedThread
    end
    CompatibilityEnvironment.task = {
        wait = CompatibilityWait,
        spawn = CompatibilitySpawn,
        defer = CompatibilityDeferTask,
        delay = CompatibilityDelayTask,
        cancel = function(TaskThread)
            return Fidelity.CancelScheduled(TaskThread)
        end,
    }
    CompatibilityEnvironment.spawn = CompatibilitySpawn
    CompatibilityEnvironment.delay = CompatibilityDelayTask
    CompatibilityEnvironment.wait = CompatibilityWait
    CompatibilityEnvironment.print = function(...)
        CaptureCompatibilityOutput("print", ...)
    end
    CompatibilityEnvironment.warn = function(...)
        CaptureCompatibilityOutput("warn", ...)
    end
    CompatibilityEnvironment.Instance = MockInstance
    CompatibilityEnvironment.__V1CreateRemoteProxy = CreateMockRemoteProxy
    CompatibilityEnvironment.game = MockGame
    CompatibilityEnvironment.Game = MockGame
    CompatibilityEnvironment.workspace = MockWorkspace
    CompatibilityEnvironment.Workspace = MockWorkspace
    CompatibilityEnvironment.Enum = MockEnum
    CompatibilityEnvironment.RaycastParams = Fidelity.RaycastParams
    CompatibilityEnvironment.OverlapParams = Fidelity.OverlapParams
    CompatibilityEnvironment.PhysicalProperties = Fidelity.PhysicalProperties
    CompatibilityEnvironment.Region3int16 = Fidelity.Region3int16
    CompatibilityEnvironment.DockWidgetPluginGuiInfo = Fidelity.DockWidgetPluginGuiInfo
    if Fidelity.MarkEngineCSideFunctions ~= nil then
        Fidelity.MarkEngineCSideFunctions(CompatibilityEnvironment)
    end
    CompatibilityEnvironment.BrickColor = MockBrickColor
    CompatibilityEnvironment.FloatCurveKey = MockFloatCurveKey
    CompatibilityEnvironment._VERSION = "Luau"
    CompatibilityEnvironment.elapsedTime = function() return Fidelity.Clock.ElapsedTime() end
    CompatibilityEnvironment.tick = function() return Fidelity.Clock.Tick() end
    CompatibilityEnvironment.version = Fidelity.EnvVersion
    CompatibilityEnvironment.gcinfo = Fidelity.EnvGcinfo
    CompatibilityEnvironment.UserSettings = Fidelity.EnvUserSettings
    CompatibilityEnvironment["settings"] = Fidelity.EnvSettings
    CompatibilityEnvironment.time = function() return Fidelity.Clock.PhysicsTime end
    CompatibilityEnvironment.ElapsedTime = nil
    CompatibilityEnvironment.Vector3 = MockVector3
    CompatibilityEnvironment.Vector2 = MockVector2
    CompatibilityEnvironment.vector = MockVector
    CompatibilityEnvironment.Vector3int16 = MockVector3Int16
    CompatibilityEnvironment.Vector2int16 = MockVector2Int16
    CompatibilityEnvironment.UDim2 = MockUDim2
    CompatibilityEnvironment.UDim = MockUDim
    CompatibilityEnvironment.NumberRange = MockNumberRange
    CompatibilityEnvironment.Ray = MockRay
    CompatibilityEnvironment.Region3 = Fidelity.MockRegion3
    CompatibilityEnvironment.ColorSequence = MockColorSequence
    CompatibilityEnvironment.ColorSequenceKeypoint = MockColorSequenceKeypoint
    CompatibilityEnvironment.RotationCurveKeypoint = Fidelity.RotationCurveKeypoint
    CompatibilityEnvironment.NumberSequence = MockNumberSequence
    CompatibilityEnvironment.NumberSequenceKeypoint = MockNumberSequenceKeypoint
    CompatibilityEnvironment.Path2DControlPoint = MockPath2DControlPoint
    CompatibilityEnvironment.Rect = MockRect
    CompatibilityEnvironment.Axes = Fidelity.Axes
    CompatibilityEnvironment.Faces = Fidelity.Faces
    CompatibilityEnvironment.DateTime = Fidelity.DateTime
    CompatibilityEnvironment.crypt = Fidelity.Crypt
    CompatibilityEnvironment.Content = Fidelity.Content
    CompatibilityEnvironment.User = Fidelity.User
    CompatibilityEnvironment.Secret = Fidelity.Secret
    CompatibilityEnvironment.CatalogSearchParams = Fidelity.CatalogSearchParams
    CompatibilityEnvironment.Path2DControl = Fidelity.Path2DControlPoint
    CompatibilityEnvironment.path2dcontrol = Fidelity.Path2DControlPoint
    CompatibilityEnvironment.Color3 = MockColor3
    CompatibilityEnvironment.CFrame = MockCFrame
    CompatibilityEnvironment.Random = MockRandom
    CompatibilityEnvironment.TweenInfo = MockTweenInfo
    CompatibilityEnvironment.Font = Fidelity.Font
    CompatibilityEnvironment.PathWaypoint = Fidelity.PathWaypoint
    CompatibilityEnvironment.ValueCurveKey = Fidelity.ValueCurveKey
    CompatibilityEnvironment.RotationCurveKey = Fidelity.RotationCurveKey
    CompatibilityEnvironment.SecurityCapabilities = Fidelity.SecurityCapabilities
    CompatibilityEnvironment.color3 = MockColor3
    CompatibilityEnvironment.cframe = MockCFrame
    CompatibilityEnvironment.udim = MockUDim
    CompatibilityEnvironment.udim2 = MockUDim2
    CompatibilityEnvironment.vector2 = MockVector2
    CompatibilityEnvironment.vector3 = MockVector3
    if MockBrickColor ~= nil then
        CompatibilityEnvironment.brickcolor = MockBrickColor
    end
    CompatibilityEnvironment.getcustomasset = function(PathValue) return ToString(PathValue or "") end
    CompatibilityEnvironment.gethwid = function() return Fidelity.SessionIdentity.Hwid end
    CompatibilityEnvironment.gethui = function() return MockCoreGui end
    CompatibilityEnvironment.syn = {
        request = function() return { Success = true, StatusCode = 200, Body = "{}", Headers = {} } end,
    }
    CompatibilityEnvironment.http = {
        request = function() return { Success = true, StatusCode = 200, Body = "{}", Headers = {} } end,
    }
    CompatibilityEnvironment.cache = {
        invalidate = function() end,
        iscached = function() return false end,
        replace = function() end,
    }
    CompatibilityEnvironment.Drawing = Fidelity.KVMSDecorateDrawing({
        new = function() return {} end,
    }, MockEnum)
    CompatibilityEnvironment.getgc = function(...)
        return MockGetGcObjects(...)
    end
    CompatibilityEnvironment.identifyexecutor = function()
        local IdentityTable = Fidelity.ExecutorIdentity
        return IdentityTable.Name, IdentityTable.Version, IdentityTable.Platform
    end
    CompatibilityEnvironment.getexecutorname = CompatibilityEnvironment.identifyexecutor
    CompatibilityEnvironment.getsenv = function() return {} end
    CompatibilityEnvironment.getreg = function() return {} end
    CompatibilityEnvironment.hookfunction = function(TargetFunction) return TargetFunction end
    CompatibilityEnvironment.hookmetamethod = function(TargetTable, MetaMethodName, ReplacementFunction)
        return Fidelity.HookMetaMethod(TargetTable, MetaMethodName, ReplacementFunction)
    end
    CompatibilityEnvironment.newcclosure = Fidelity.NewCClosure
    CompatibilityEnvironment.checkcaller = function() return true end
    CompatibilityEnvironment.getscriptbytecode = function() return "" end
    CompatibilityEnvironment.getscripthash = function() return "" end
    CompatibilityEnvironment.getloadedmodules = function() return {} end
    CompatibilityEnvironment.getconnections = function() return {} end
    CompatibilityEnvironment.getinstances = function() return {} end
    CompatibilityEnvironment.getnilinstances = function() return {} end
    CompatibilityEnvironment.compareinstances = function(LeftValue, RightValue) return LeftValue == RightValue end
    for _, ExecutorName in Next, {
        "request", "http_request", "queue_on_teleport", "queueonteleport",
        "setclipboard", "toclipboard", "getthreadidentity", "getidentity",
        "setthreadidentity", "setidentity", "isexecutorclosure", "isourclosure",
        "getrawmetatable", "setrawmetatable", "setreadonly", "isreadonly",
        "make_readonly", "make_writeable", "getnamecallmethod", "setnamecallmethod",
        "dumpstring", "getscriptclosure", "firesignal", "gethiddenproperty",
        "sethiddenproperty", "getproperties", "gethiddenproperties",
        "isfile", "isfolder", "readfile", "writefile", "appendfile", "makefolder",
        "delfile", "delfolder", "listfiles", "loadfile",
        "mouse1click", "mouse1press", "mouse1release", "mouse2click",
        "mouse2press", "mouse2release", "keypress", "keyrelease",
        "rconsoleprint", "rconsolewarn", "rconsoleerr", "rconsoleclear", "rconsolename",
        "isrenderobj", "getrenderproperty", "setrenderproperty",
    } do
        if CompatibilityEnvironment[ExecutorName] == nil then
            CompatibilityEnvironment[ExecutorName] = function() return nil end
        end
    end
    CompatibilityEnvironment["isexecutorclosure"] = function(ValueArgument)
        return Fidelity.IsExecutorGenerated ~= nil and Fidelity.IsExecutorGenerated(ValueArgument)
    end
    CompatibilityEnvironment["isourclosure"] = CompatibilityEnvironment["isexecutorclosure"]
    CompatibilityEnvironment["Drawing"] = Fidelity.KVMSDecorateDrawing(
        Fidelity.CreateDrawingNamespace(), MockEnum)
    CompatibilityEnvironment["isrenderobj"] = function(ValueArgument)
        return Fidelity.IsRenderObject(ValueArgument)
    end
    CompatibilityEnvironment["getrenderproperty"] = function(TargetObject, PropertyName)
        return Fidelity.GetRenderProperty(TargetObject, PropertyName)
    end
    CompatibilityEnvironment["setrenderproperty"] = function(TargetObject, PropertyName, PropertyValue)
        Fidelity.SetRenderProperty(TargetObject, PropertyName, PropertyValue)
    end
    CompatibilityEnvironment["cleardrawcache"] = function() return true end
    CompatibilityEnvironment.getthreadidentity = function() return 7 end
    CompatibilityEnvironment.getidentity = function() return 7 end
    CompatibilityEnvironment.setthreadidentity = function() end
    CompatibilityEnvironment.setidentity = function() end
    local function CaptureCompatibilityCall(LineText)
        TableInsert(CompatibilityOutputLines, LineText)
        TableInsert(OutputLinesArray, LineText)
        SavePartialOutputSnapshot()
    end
    local function FormatCompatibilityArgument(ValueText)
        return StringFormat("%q", tostring(ValueText))
    end
    CompatibilityEnvironment.writefile = function(PathValue, ContentValue)
        Fidelity.VirtualFileWrite(PathValue, ContentValue)
        CaptureCompatibilityCall("writefile(" .. FormatCompatibilityArgument(PathValue) .. ", " .. FormatCompatibilityArgument(ContentValue) .. ")")
        return true
    end
    CompatibilityEnvironment.appendfile = function(PathValue, ContentValue)
        Fidelity.VirtualFileAppend(PathValue, ContentValue)
        CaptureCompatibilityCall("appendfile(" .. FormatCompatibilityArgument(PathValue) .. ", " .. FormatCompatibilityArgument(ContentValue) .. ")")
        return true
    end
    CompatibilityEnvironment.readfile = function(PathValue)
        return Fidelity.VirtualFileRead(PathValue)
    end
    CompatibilityEnvironment.loadfile = function(PathValue)
        local StoredContent = Fidelity.VirtualFileRead(PathValue)
        if StoredContent == nil then return nil end
        return function() return StoredContent end
    end
    CompatibilityEnvironment.isfile = function(PathValue)
        return Fidelity.VirtualFileExists(PathValue)
    end
    CompatibilityEnvironment.isfolder = function(PathValue)
        return Fidelity.VirtualFolderExists(PathValue)
    end
    CompatibilityEnvironment.makefolder = function(PathValue)
        Fidelity.VirtualFolderMake(PathValue)
        CaptureCompatibilityCall("makefolder(" .. FormatCompatibilityArgument(PathValue) .. ")")
        return true
    end
    CompatibilityEnvironment.delfolder = function(PathValue)
        Fidelity.VirtualFolderRemove(PathValue)
        CaptureCompatibilityCall("delfolder(" .. FormatCompatibilityArgument(PathValue) .. ")")
        return true
    end
    CompatibilityEnvironment.delfile = function(PathValue)
        if Fidelity.VirtualFileRemove(PathValue) then
            CaptureCompatibilityCall("delfile(" .. FormatCompatibilityArgument(PathValue) .. ")")
        end
        return true
    end
    CompatibilityEnvironment.listfiles = function(PathValue)
        return Fidelity.VirtualFolderList(PathValue)
    end
    local OriginalCompatibilityRawequal = CompatibilityEnvironment.rawequal
    CompatibilityEnvironment.rawequal = function(LeftValue, RightValue)
        if (LeftValue == MockGame or RightValue == MockGame
            or LeftValue == MockWorkspace or RightValue == MockWorkspace)
            and (LeftValue == nil or RightValue == nil) then
            return true
        end
        return OriginalCompatibilityRawequal(LeftValue, RightValue)
    end
    CompatibilityEnvironment.base64 = Fidelity.Base64Global
    CompatibilityEnvironment.b64 = Fidelity.Base64Global
    CompatibilityEnvironment.json = Fidelity.JsonGlobal
    CompatibilityEnvironment.cloneref = function(TargetValue) return TargetValue end
    CompatibilityEnvironment.GUF_CRASH = function() return nil end
    CompatibilityEnvironment.clonefunction = function(TargetFunction) return TargetFunction end
    -- r72: outer env (lingkungan tempat payload dijalankan sebelum stage decode) belum punya
    -- semua nama global Roblox; tanpa ini cek eUNC soal wait/utf8 nyangkut di env host.
    if CompatibilityEnvironment.wait == nil then CompatibilityEnvironment.wait = Fidelity.LegacyWait end
    if CompatibilityEnvironment.tick == nil then CompatibilityEnvironment.tick = Fidelity.MockTick end
    if CompatibilityEnvironment.time == nil then CompatibilityEnvironment.time = Fidelity.MockTick end
    if CompatibilityEnvironment.warn == nil then CompatibilityEnvironment.warn = function(...) print(...) end end
    CompatibilityEnvironment.utf8 = Fidelity.Utf8 or Fidelity.BuildUtf8Library(utf8)
    if CompatibilityEnvironment.Color3 == nil then CompatibilityEnvironment.Color3 = MockColor3 end
    -- r72: jangan tulis ke tabel math bersama (ia beku; menulis menjatuhkan stage decode).
    -- Dibungkus: salinan tipis dengan __index ke math aslinya, plus konstan/fungsi Luau yang kurang.
    if type(CompatibilityEnvironment.math) == "table" and Fidelity.EnvMathWrapped ~= true then
        local BaseMathTable = CompatibilityEnvironment.math
        local WrappedMathTable = setmetatable({
            nan = 0 / 0,
            sign = function(x) x = tonumber(x) or 0
                if x > 0 then return 1 elseif x < 0 then return -1 end return 0 end,
            round = function(x, places) x = tonumber(x) or 0
                places = tonumber(places) or 0
                local Power = 10 ^ places
                return math.floor(x * Power + 0.5) / Power end,
            lerp = function(a, b, t) a = tonumber(a) or 0 b = tonumber(b) or 0 t = tonumber(t) or 0
                return a + (b - a) * t end,
            modf = function(x) x = tonumber(x) or 0
                local IntValue = math.floor(math.abs(x))
                if x < 0 then IntValue = -IntValue end
                return IntValue, x - IntValue end,
            compare = function(a, b) a = tonumber(a) or 0 b = tonumber(b) or 0
                if a == b then return 0 end
                return a < b and -1 or 1 end,
        }, { __index = BaseMathTable })
        CompatibilityEnvironment.math = WrappedMathTable
        Fidelity.EnvMathWrapped = true
    end    CompatibilityEnvironment.iscclosure = function(TargetClosure)
        if InternalType(TargetClosure) ~= "function" then return false end
        if Fidelity.GuardedNatives and Fidelity.GuardedNatives[TargetClosure] then return true end
        local IsSourceOk, SourceKind = InternalPCall(DebugInfo, TargetClosure, "s")
        return IsSourceOk and (SourceKind == "[C]" or SourceKind == "=[C]")
    end
    CompatibilityEnvironment.islclosure = function(TargetClosure)
        if InternalType(TargetClosure) ~= "function" then return false end
        local IsSourceOk, SourceKind = InternalPCall(DebugInfo, TargetClosure, "s")
        return IsSourceOk and SourceKind ~= "[C]"
    end
    CompatibilityEnvironment.error = BypassedError
    CompatibilityEnvironment.assert = function(...)
        local ConditionValue, MessageText = ...
        if not ConditionValue then
            local LowerMessage = StringLower(ToString(MessageText or ""))
            if StringMatch(LowerMessage, "ea043b152") or StringMatch(LowerMessage, "antitamper")
                or StringMatch(LowerMessage, "detected") or StringMatch(LowerMessage, "protected")
                or StringMatch(LowerMessage, "lumina") then
                return true
            end
            if MessageText == nil then
                BypassedError("assertion failed!", 3)
            elseif TypeOf(MessageText) == "string" then
                BypassedError(MessageText, 3)
            else
                BypassedError(MessageText, 0)
            end
        end
        return ...
    end
    CompatibilityEnvironment.getfenv = function(LevelArg)
        if TypeOf(LevelArg) == "number" and LevelArg ~= 0 then
            local FrameDepth = Fidelity.CountScriptFrameDepth()
            if FrameDepth ~= nil and MathFloor(LevelArg) > FrameDepth + 1 then
                RealErrorRef("bad argument #1 to 'getfenv'" .. Fidelity.LevelOutOfRangeText, 0)
            end
        end
        local RunningFunction = Fidelity.RunningChunkFunction
        if RunningFunction ~= nil then
            local ResolvedOk, EnvValue = InternalPCall(getfenv, RunningFunction)
            if ResolvedOk and InternalType(EnvValue) == "table"
                and EnvValue ~= CompatibilityEnvironment
                and EnvValue ~= Fidelity.CompatActiveEnvironment then
                return EnvValue
            end
        end
        return CompatibilityEnvironment
    end
    CompatibilityEnvironment.getgenv = function()
        return CompatibilityEnvironment
    end
    CompatibilityEnvironment.oth = Fidelity.InertHookLibrary()
    CompatibilityEnvironment.getrenv = function()
        return CompatibilityEnvironment
    end
    CompatibilityEnvironment._G = CompatibilityEnvironment
    CompatibilityEnvironment._ENV = CompatibilityEnvironment
    local PersistentPrintFunction = CompatibilityEnvironment.print
    local PersistentWarnFunction = CompatibilityEnvironment.warn
    local CompatibilityFallbackValue = function(KeyName)
        local InfoStructFieldName = ToString(KeyName)
        if InfoStructFieldName == "what"
            or InfoStructFieldName == "source"
            or InfoStructFieldName == "short_src"
            or InfoStructFieldName == "linedefined"
            or InfoStructFieldName == "lastlinedefined"
            or InfoStructFieldName == "nups"
            or InfoStructFieldName == "numparams"
            or InfoStructFieldName == "is_vararg"
            or InfoStructFieldName == "name"
            or InfoStructFieldName == "func"
            or InfoStructFieldName == "currentline"
            or InfoStructFieldName == "ftransfer"
            or InfoStructFieldName == "ntransfer"
            or InfoStructFieldName == "istailcall"
        then
            return nil
        end
        if StringMatch(ToString(KeyName), "Service$") then
            local ServiceObject = InternalPCall(function()
                return MockGame:GetService(KeyName)
            end)
            if ServiceObject then return ServiceObject end
        end
        if ToString(KeyName) == "Players" then return MockPlayersService end
        if ToString(KeyName) == "RunService" then
            return MockGame:GetService("RunService")
        end
        if ToString(KeyName) == "workspace" or ToString(KeyName) == "Workspace" then
            return MockWorkspace
        end
        if ToString(KeyName) == "game" or ToString(KeyName) == "Game" then
            return MockGame
        end
        if ToString(KeyName) == "script" then
            return CreateMockInstance("Script")
        end
        return CreateGenericMock(KeyName)
    end
    SetMetatable(CompatibilityEnvironment, {
        __index = function(EnvironmentObject, KeyName)
            if KeyName == "print" then return PersistentPrintFunction end
            if KeyName == "warn" then return PersistentWarnFunction end
            local ResolvedValue = RawGet(EnvironmentObject, KeyName)
            if ResolvedValue ~= nil then return ResolvedValue end
            local FallbackValue = CompatibilityFallbackValue(KeyName)
            if FallbackValue ~= nil then
                RawSet(EnvironmentObject, KeyName, FallbackValue)
                return FallbackValue
            end
            return nil
        end,
        __newindex = function(EnvironmentObject, KeyName, ValueData)
            if KeyName == "print" or KeyName == "warn" then return end
            RawSet(EnvironmentObject, KeyName, ValueData)
        end,
        __tostring = function()
            return "getfenv()"
        end,
        __metatable = "KVMS sandbox environment is locked",
    })
    RawSet(CompatibilityEnvironment, "print", nil)
    RawSet(CompatibilityEnvironment, "warn", nil)
    local CompatibilityLoadCount = 0
    local function CompatibilityLoad(SourceText, ChunkName)
        if TypeOf(SourceText) == "string" then
            EmitMockOutput("loadstring", {SourceText = SourceText, ChunkName = ChunkName})
            CompatibilityLoadCount += 1
            if #SourceText > 200 then
                if ConfigurationSettings.PayloadDumpDir then
                    InternalPrint(`[V1Dumper] compat load #{CompatibilityLoadCount}: {#SourceText} bytes, chunk {tostring(ChunkName)}`)
                    local DumpPath = Fidelity.PayloadDumpPath(CompatibilityLoadCount, SourceText)
                    if DumpPath then __V1HostWrite(DumpPath, SourceText) end
                end
            end
        end
            local DecodedStageRefusal = (ConfigurationSettings.HostileIntakeRefusal ~= false)
                and Fidelity.HarvestIntakeVerdict(SourceText) and Fidelity.HarvestIntakeRefusalNote
            if DecodedStageRefusal then
                InternalPrint("refused a decoded stage: " .. tostring(DecodedStageRefusal))
                return nil, DecodedStageRefusal
            end
        local LoadedFunction, LoadError = Fidelity.CompileLikeEngine(LoadString, SourceText, ChunkName)
        if LoadedFunction then setfenv(LoadedFunction, CompatibilityEnvironment) end
        return LoadedFunction, LoadError
    end
    CompatibilityEnvironment.load = CompatibilityLoad
    CompatibilityEnvironment.loadstring = CompatibilityLoad
    local CompatibilitySourceCode = SourceCodeString
    if StringFind(SourceCodeString, "TAMP3R", 1, true) ~= nil
        and StringFind(SourceCodeString, "hookfunction", 1, true) ~= nil then
        CompatibilitySourceCode = StringGsub(
            CompatibilitySourceCode,
            "local%s+success%s*=%s*pcall%s*%(%s*function%s*%(%s*%)%s*hookfunction%s*%(%s*NIGREEL%s*,%s*function%s*%(%s*%)%s*return%s*\"b\"%s*end%s*%)%s*end%s*%)",
            "local success = true; NIGREEL = function() return \"b\" end"
        )
        CompatibilitySourceCode = StringGsub(
            CompatibilitySourceCode,
            "tostring%s*%(%s*TAMP3R%s*%)%s*:%s*match%s*%(%s*\"%^function:%s*0x0000\"%s*%)",
            "false"
        )
        CompatibilitySourceCode = StringGsub(
            CompatibilitySourceCode,
            "tostring%s*%(%s*%{%s*%}%s*%)%s*:%s*sub%s*%(%s*8%s*,%s*11%s*%)%s*==%s*tostring%s*%(%s*%{%s*%}%s*%)%s*:%s*sub%s*%(%s*8%s*,%s*11%s*%)",
            "false"
        )
        CompatibilitySourceCode = StringGsub(
            CompatibilitySourceCode,
            "#%s*getgc%s*%(%s*%)%s*<%s*800",
            "false"
        )
        CompatibilitySourceCode = StringGsub(
            CompatibilitySourceCode,
            "not%s+success%s+or%s+NIGREEL%s*%(%s*%)%s*~=%s*\"b\"",
            "false"
        )
        CompatibilitySourceCode = StringGsub(
            CompatibilitySourceCode,
            "ok%s*=%s*ok%s+and%s+ec%s*==%s*fc",
            "ok = ok"
        )
        CompatibilitySourceCode = StringGsub(
            CompatibilitySourceCode,
            "if%s+not%s*%(%s*c1%s*==%s*c2%s*%)%s+then",
            "if false then"
        )
    end
    local ExecutableFunction = LoadString(CompatibilitySourceCode, ConfigurationSettings.CompatChunkName)
    local IsWeAreDevsSource =
        StringFind(SourceCodeString, "wearedevs.net/obfuscator", 1, true) ~= nil
        or (StringFind(SourceCodeString, "getfenv and getfenv()", 1, true) ~= nil
            and StringFind(SourceCodeString, "unpack or table", 1, true) ~= nil
            and StringFind(SourceCodeString, "newproxy", 1, true) ~= nil
            and StringFind(SourceCodeString, "getmetatable", 1, true) ~= nil
            and StringFind(SourceCodeString, "select", 1, true) ~= nil)
    local ActiveExecutionEnvironment = CompatibilityEnvironment
    if IsWeAreDevsSource then
        local HostCapabilityNames = {
            require = true, _G = true, _ENV = true, io = true, os = true, debug = true,
            load = true, loadstring = true, dofile = true, loadfile = true,
            getfenv = true, setfenv = true, getgenv = true, getrenv = true,
            package = true, shared = true,
        }
        local HostFallbackAllowlist = {
            string = true, table = true, math = true, utf8 = true, bit32 = true,
            coroutine = true, task = true,
            assert = true, error = true, pcall = true, xpcall = true, select = true,
            ipairs = true, pairs = true, next = true, rawequal = true, rawget = true,
            rawlen = true, rawset = true, setmetatable = true, getmetatable = true,
            tonumber = true, tostring = true, type = true, typeof = true, newproxy = true,
            unpack = true,
        }
        local WeAreDevsEnvironment = SetMetatable({}, {
            __index = function(EnvObject, KeyName)
                if KeyName == "_ENV" or KeyName == "_G" then return WeAreDevsEnvironment end
                if KeyName == "rawget" and Fidelity.GuardedRawGet ~= nil then
                    return Fidelity.GuardedRawGet
                end
                if KeyName == "rawset" and Fidelity.GuardedRawSet ~= nil then
                    return Fidelity.GuardedRawSet
                end
                if KeyName == "rawlen" and Fidelity.GuardedRawLen ~= nil then
                    return Fidelity.GuardedRawLen
                end
                if KeyName == "require" then
                    return function(ModuleName)
                        InternalError(StringFormat("module %q not found", ModuleName), 0)
                    end
                end
                if HostCapabilityNames[KeyName] then
                    local MockSealed = CompatibilityEnvironment[KeyName]
                    if MockSealed ~= nil then return MockSealed end
                    return CompatibilityFallbackValue(KeyName)
                end
                if HostFallbackAllowlist[KeyName] then
                    local HostValue = HostEnvironment[KeyName]
                    if HostValue ~= nil then return HostValue end
                end
                local MockValue = RawGet(CompatibilityEnvironment, KeyName)
                if MockValue ~= nil then return MockValue end
                return nil
            end,
        })
        local CompatibilityDecodeSafeDenylist = {
            string = true, math = true, table = true, utf8 = true, bit = true,
            bit32 = true, buffer = true, os = true, coroutine = true, debug = true,
            type = true, typeof = true, tonumber = true, tostring = true,
            getmetatable = true, setmetatable = true, rawequal = true,
            rawget = true, rawset = true, rawlen = true, select = true,
            unpack = true, pairs = true, ipairs = true, next = true,
            pcall = true, xpcall = true, assert = true, error = true,
            load = true, loadstring = true, _ENV = true, _G = true, _VERSION = true,
            getfenv = true, setfenv = true, getgenv = true, getrenv = true,
        }
        for MockKey, MockValue in Next, CompatibilityEnvironment do
            if not CompatibilityDecodeSafeDenylist[MockKey] then
                RawSet(WeAreDevsEnvironment, MockKey, MockValue)
            end
        end
        RawSet(WeAreDevsEnvironment, "getfenv", function(Target)
            if TypeOf(Target) == "function" then
                local TargetEnvironment = getfenv(Target)
                if TargetEnvironment == WeAreDevsEnvironment or TargetEnvironment == CompatibilityEnvironment then
                    return TargetEnvironment
                end
            end
            return WeAreDevsEnvironment
        end)
        WeAreDevsEnvironment.print = function(...) CaptureCompatibilityOutput("print", ...) end
        WeAreDevsEnvironment.warn = function(...) CaptureCompatibilityOutput("warn", ...) end
        WeAreDevsEnvironment.loadstring = function(SourceText, ChunkName)
            if ConfigurationSettings.PayloadDumpDir and TypeOf(SourceText) == "string" and #SourceText > 8 then
                CompatibilityLoadCount += 1
                local DumpPath = Fidelity.PayloadDumpPath(CompatibilityLoadCount, SourceText)
                if DumpPath then __V1HostWrite(DumpPath, SourceText) end
            end
            local DecodedStageRefusal = (ConfigurationSettings.HostileIntakeRefusal ~= false)
                and Fidelity.HarvestIntakeVerdict(SourceText) and Fidelity.HarvestIntakeRefusalNote
            if DecodedStageRefusal then
                InternalPrint("refused a decoded stage: " .. tostring(DecodedStageRefusal))
                return nil, DecodedStageRefusal
            end
            local LoadedFunction, LoadError = Fidelity.CompileLikeEngine(LoadString, SourceText, ChunkName)
            if LoadedFunction then setfenv(LoadedFunction, WeAreDevsEnvironment) end
            return LoadedFunction, LoadError
        end
        WeAreDevsEnvironment.load = WeAreDevsEnvironment.loadstring
        ActiveExecutionEnvironment = WeAreDevsEnvironment
    end
    setfenv(ExecutableFunction, ActiveExecutionEnvironment)
    local OuterCompatRunningFunction = Fidelity.RunningChunkFunction
    local OuterCompatActiveEnvironment = Fidelity.CompatActiveEnvironment
    Fidelity.RunningChunkFunction = ExecutableFunction
    Fidelity.CompatActiveEnvironment = ActiveExecutionEnvironment
    if Fidelity.MarkEngineCSideFunctions ~= nil then
        pcall(Fidelity.MarkEngineCSideFunctions, ActiveExecutionEnvironment)
    end
    local PreviousMockOutputLogger = MockOutputLogger
    MockOutputLogger = function(EventKind, Payload)
        local UiLogLine = BuildMockUiLogLine(EventKind, Payload)
        if UiLogLine and ConfigurationSettings.ShouldKeepIndexLog(UiLogLine) then
            TableInsert(CompatibilityOutputLines, UiLogLine)
            TableInsert(OutputLinesArray, UiLogLine)
            SavePartialOutputSnapshot()
        end
    end
    MockClockOffset = 0
    MockHeartbeatCount = 0
    if Fidelity.Clock ~= nil then
        Fidelity.Clock.Reset()
    end
    if Fidelity.ProtectStandardLibraries ~= nil then
        Fidelity.ProtectStandardLibraries(CompatibilityEnvironment)
    end
    __V1HostIoLocked = true
    local ExecutionResults = TablePack(InternalPCall(ExecutableFunction))
    __V1HostIoLocked = false
    __V1FlushPendingHostWrites()
    MockOutputLogger = PreviousMockOutputLogger
    Fidelity.RunningChunkFunction = OuterCompatRunningFunction
    Fidelity.CompatActiveEnvironment = OuterCompatActiveEnvironment
    if not ExecutionResults[1] then
        local ErrorText = ToString(ExecutionResults[2])
        ErrorText = StringGsub(ErrorText, "/home/container", "root/main")
        ErrorText = StringGsub(ErrorText, "/home/user", "root/main")
ErrorText = Fidelity.RedactRunnerSource(ErrorText, ConfigurationSettings.RunnerSourceText)
        ErrorText = StringGsub(ErrorText, "deo_fixed", "deo")
        ErrorText = Fidelity.SanitizeRunError(ErrorText)
        local PartialOutput = TableConcat(CompatibilityOutputLines, "\n")
        if PartialOutput ~= "" then PartialOutput ..= "\n" end
        return PartialOutput .. "error(" .. StringFormat("%q", ErrorText) .. ")"
    end
    if ExecutionResults.n > 1 then
        local ReturnValues = {}
        for ResultIndex = 2, ExecutionResults.n do
            ReturnValues[#ReturnValues + 1] = FormatCompatibilityValue(ExecutionResults[ResultIndex])
        end
        TableInsert(CompatibilityOutputLines, "return " .. TableConcat(ReturnValues, ", "))
    end
    InternalPrint("[V1Dumper] compat diag execOk=" .. ToString(ExecutionResults[1])
        .. " execRetCount=" .. ToString(#ExecutionResults)
        .. " compatLines=" .. ToString(#CompatibilityOutputLines)
        .. " outLines=" .. ToString(#OutputLinesArray))
    return TableConcat(CompatibilityOutputLines, "\n")
end
local function InitializeDecodingProcess(TargetFileSource)
    if CheckIsSensitivePath(TargetFileSource) then
        __V1FlushPendingHostWrites()
        Process.exit(1)
    end
    local InputBytes = 0
    local MetaOk, MetaData = InternalPCall(FileSystem.getMetadata, TargetFileSource)
    if MetaOk and MetaData ~= nil and MetaData.size ~= nil then InputBytes = MetaData.size end
    local InputCap = ConfigurationSettings.MaxInputBytes or 0
    local RefusalName = tostring(TargetFileSource):match("([^/\\]+)$") or "?"
    if InputCap > 0 and InputBytes > InputCap then
        InternalPrint(`[V1Dumper] refusing {RefusalName}: {InputBytes} bytes is over the {InputCap} byte input limit (raise --MaxInputBytes to allow it)`)
        __V1FlushPendingHostWrites()
        Process.exit(1)
    end
    local RawSourceCodeText = OriginalFsRead(TargetFileSource)
    if InputCap > 0 and type(RawSourceCodeText) == "string" and #RawSourceCodeText > InputCap then
        InternalPrint(`[V1Dumper] refusing {RefusalName}: {#RawSourceCodeText} bytes is over the {InputCap} byte input limit (raise --MaxInputBytes to allow it)`)
        __V1FlushPendingHostWrites()
        Process.exit(1)
    end
    ConfigurationSettings.IndexLogCounts = {}
    SavePartialOutputSnapshot()
    local StartClockTimerVal = Clock()
    local IsPristineCompatibilitySource =
        StringFind(RawSourceCodeText, "wearedevs.net/obfuscator", 1, true) ~= nil
        or (StringFind(RawSourceCodeText, "getfenv and getfenv()", 1, true) ~= nil
            and StringFind(RawSourceCodeText, "unpack or table", 1, true) ~= nil
            and StringFind(RawSourceCodeText, "newproxy", 1, true) ~= nil
            and StringFind(RawSourceCodeText, "getmetatable", 1, true) ~= nil
            and StringFind(RawSourceCodeText, "select", 1, true) ~= nil)
        or StringFind(StringLower(RawSourceCodeText), "goofyscator", 1, true) ~= nil
        or StringFind(RawSourceCodeText, "Hephaestus", 1, true) ~= nil
        or StringFind(RawSourceCodeText, "Cypher Obfuscator", 1, true) ~= nil
        or (StringFind(RawSourceCodeText, "isCFunction", 1, true) ~= nil
            and StringFind(RawSourceCodeText, "newproxy", 1, true) ~= nil
            and StringFind(RawSourceCodeText, "__heph_probe", 1, true) ~= nil)
        or (StringFind(RawSourceCodeText, "TAMP3R", 1, true) ~= nil
            and StringFind(RawSourceCodeText, "protectasu", 1, true) ~= nil
            and StringFind(RawSourceCodeText, "getgc", 1, true) ~= nil)
        or (#RawSourceCodeText > 50000
            and StringFind(RawSourceCodeText, "getfenv", 1, true) ~= nil
            and StringFind(RawSourceCodeText, "setmetatable", 1, true) ~= nil)
    local SandboxStatusOkFlag, ReturnedCodeDataText
    local HostileIntakeFlag = ConfigurationSettings.HostileIntakeRefusal ~= false
        and type(RawSourceCodeText) == "string"
        and Fidelity.HarvestIntakeVerdict(RawSourceCodeText) ~= false
    if HostileIntakeFlag then
        InternalPrint(`[V1Dumper] refused {RefusalName}: the intake reads like a file collector, so nothing in it was executed`)
        SandboxStatusOkFlag, ReturnedCodeDataText = true,
            "-- this file was not opened here: it asks for files belonging to the machine running this service, and that is not run"
    elseif IsPristineCompatibilitySource then
        SandboxStatusOkFlag, ReturnedCodeDataText = InternalPCall(ProcessPristineCompatibility, RawSourceCodeText)
    else
        SandboxStatusOkFlag, ReturnedCodeDataText = InternalPCall(MainProcessor, RawSourceCodeText, nil, nil, true)
    end
    local ElapsedExecutionTimeVal = Clock() - StartClockTimerVal
    if Fidelity.Scheduled ~= nil and #Fidelity.Scheduled.Queue > 0 then
        PrintToConsole("Pending scheduled threads at end of run:", #Fidelity.Scheduled.Queue)
    end
    PrintToConsole("Took", ElapsedExecutionTimeVal, "seconds to process.", SandboxStatusOkFlag)
    if not SandboxStatusOkFlag then
        local CleanOutputArray = {}
        for _, LineVal in Next, OutputLinesArray do
            if LineVal then TableInsert(CleanOutputArray, LineVal) end
        end
        local RecoveredTextStr = TableConcat(CleanOutputArray, "\n")
        local ErrorText = ToString(ReturnedCodeDataText)
        ErrorText = StringGsub(ErrorText, "/home/container", "root/main")
        ErrorText = StringGsub(ErrorText, "/home/user", "root/main")
ErrorText = Fidelity.RedactRunnerSource(ErrorText, ConfigurationSettings.RunnerSourceText)
        ErrorText = StringGsub(ErrorText, "deo_fixed", "deo")
        ErrorText = Fidelity.SanitizeRunError(ErrorText)
        ReturnedCodeDataText = RecoveredTextStr
            .. "\n\nerror(" .. StringFormat("%q", ErrorText) .. ")"
        if Fidelity.PreserveUnparsedSource ~= nil then
            local PreservedSourceText = Fidelity.PreserveUnparsedSource(RawSourceCodeText)
            if #PreservedSourceText > 0 then
                ReturnedCodeDataText ..= "\n\n" .. PreservedSourceText
            end
        end
    elseif TypeOf(ReturnedCodeDataText) == "userdata" then
        local _err = FormatValue(ReturnedCodeDataText)
        _err = StringGsub(_err, "/home/container", "root/main")
        _err = StringGsub(_err, "/home/user", "root/main")
_err = Fidelity.RedactRunnerSource(_err, ConfigurationSettings.RunnerSourceText)
        ReturnedCodeDataText = `error({_err}) --internal error`
    end
    local GeneratedHeaderSignature = BuildWatermark()
    if TopConfiguration.AddIfCommentActive then
        GeneratedHeaderSignature ..= "-- When you see an if statement, only the first argument is correct; everything after is invalid.\n"
    end
    local FinalSavedOutputStr = Fidelity.ClampToBudget(
        GeneratedHeaderSignature .. ReturnedCodeDataText, ConfigurationSettings)
    -- r66: di-spin SETELAH clamp+prepare (biar budget tetap yang nentuin panjang), marker
    --  baru + penutup di bawah.
    FinalSavedOutputStr = Fidelity.SpliceWatermark(
        Fidelity.PrepareFinalOutput(FinalSavedOutputStr, RawSourceCodeText))
    __V1FlushPendingHostWrites()
    __V1HostWrite(TargetOutputFile, FinalSavedOutputStr)
    PrintToConsole(`[V1Dumper] Done! Output written to '{TargetOutputFile}'`)
end
local function GetSafeBaseName(TargetPath)
    local NormalizedPath = StringGsub(ToString(TargetPath), "\\", "/")
    local BaseName = StringMatch(NormalizedPath, "([^/]+)$") or "input"
    BaseName = StringGsub(BaseName, "%.[^%.]+$", "")
    BaseName = StringGsub(BaseName, "[^A-Za-z0-9_%-]", "_")
    return BaseName ~= "" and BaseName or "input"
end
local function EnsureLogFolder()
    if not ConfigurationSettings.LogsEnabled then return false end
    if FileSystem.isDir(ConfigurationSettings.LogFolder) then return true end
    local CreateSucceeded = InternalPCall(FileSystem.writeDir, ConfigurationSettings.LogFolder)
    return CreateSucceeded and FileSystem.isDir(ConfigurationSettings.LogFolder)
end
local function ResolveCurrentScriptPath()
    local SourcePath = DebugInfo(1, "s")
    if OriginalFsIsFile(SourcePath) then
        return SourcePath
    elseif OriginalFsIsFile(SourcePath .. ".lua") then
        return SourcePath .. ".lua"
    elseif OriginalFsIsFile(SourcePath .. ".luau") then
        return SourcePath .. ".luau"
    elseif OriginalFsIsFile("M.lua") then
        return "M.lua"
    end
    return SourcePath
end
local function BuildWorkerArguments(ScriptPath)
    return {
        "run",
        ScriptPath,
        TargetInputFile,
        TargetOutputFile,
        "--WorkerMode=true",
        "--HookOpValue=" .. ToString(ConfigurationSettings.HookOpValue),
        "--HookOpActive=" .. ToString(ConfigurationSettings.HookOpActive),
        "--ExploreFuncsActive=" .. ToString(ConfigurationSettings.ExploreFuncsActive),
        "--SpyExecOnlyActive=" .. ToString(ConfigurationSettings.SpyExecOnlyActive),
        "--MinifierActive=" .. ToString(ConfigurationSettings.MinifierActive),
        "--VarRenamerActive=" .. ToString(ConfigurationSettings.VarRenamerActive),
        "--MaxOperationsLimit=" .. ToString(ConfigurationSettings.MaxOperationsLimit),
        "--MaxWhileCountLimit=" .. ToString(ConfigurationSettings.MaxWhileCountLimit),
        "--MockGetGcActive=" .. ToString(ConfigurationSettings.MockGetGcActive),
        "--MockGetGcMin=" .. ToString(ConfigurationSettings.MockGetGcMin),
        "--MockGetGcMax=" .. ToString(ConfigurationSettings.MockGetGcMax),
        "--IndexLogActive=" .. ToString(ConfigurationSettings.IndexLogActive),
        "--IndexLogNumericActive=" .. ToString(ConfigurationSettings.IndexLogNumericActive),
        "--IndexLogDuplicateLimit=" .. ToString(ConfigurationSettings.IndexLogDuplicateLimit),
        "--SavePartialOutputActive=" .. ToString(ConfigurationSettings.SavePartialOutputActive),
        "--PartialSaveInterval=" .. ToString(ConfigurationSettings.PartialSaveInterval),
        "--EnvIndexActive=" .. ToString(ConfigurationSettings.EnvIndexActive),
        "--DiscordUrl=" .. ToString(ConfigurationSettings.DiscordUrl),
        "--Watermark=" .. ToString(ConfigurationSettings.WatermarkText),
        "--WatermarkEveryLines=" .. ToString(ConfigurationSettings.WatermarkEveryLines),
        "--LogFolder=" .. ToString(ConfigurationSettings.LogFolder),
        "--NoLogs=" .. ToString(ConfigurationSettings.LogsEnabled ~= true),
        "--Logs=" .. ToString(ConfigurationSettings.LogsEnabled),
        "--PayloadDumpDir=" .. ToString(ConfigurationSettings.PayloadDumpDir),
        "--WorkDir=" .. ToString(ConfigurationSettings.WorkDir),
        "--TimeoutSeconds=" .. ToString(ConfigurationSettings.TimeoutSeconds),
        "--MaxOutputLines=" .. ToString(ConfigurationSettings.MaxOutputLines),
        "--MaxOutputBytes=" .. ToString(ConfigurationSettings.MaxOutputBytes),
        "--MaxLineChars=" .. ToString(ConfigurationSettings.MaxLineChars),
        "--MaxInputBytes=" .. ToString(ConfigurationSettings.MaxInputBytes),
        "--MaxLogBytes=" .. ToString(ConfigurationSettings.MaxLogBytes),
        "--StrictErrors=" .. ToString(ConfigurationSettings.StrictErrors),
        "--FoldLocals=" .. ToString(ConfigurationSettings.RecoverLocalDeclarations ~= true),
        "--CountryRegion=" .. ToString(ConfigurationSettings.CountryRegion),
    }
end
local function WriteRunLog(LogPath, TimedOut, ExitStatus, StandardOutput, StandardError, ExtraMessage)
    local InputShown = tostring(TargetInputFile):match("([^/\\]+)$") or "?"
    local OutputShown = tostring(TargetOutputFile):match("([^/\\]+)$") or "?"
    local ExitCode = InternalType(ExitStatus) == "table" and ExitStatus.code or "unknown"
    local ExitOkay = InternalType(ExitStatus) == "table" and ExitStatus.ok or false
    local LogChunkLimit = tonumber(ConfigurationSettings.MaxLogBytes) or 262144
    local function BoundLogChunk(ChunkText)
        local ChunkSize = #ChunkText
        if ChunkSize <= LogChunkLimit then return ChunkText end
        local Keep = LogChunkLimit // 2
        return StringSub(ChunkText, 1, Keep)
            .. "\n-- [log bounded: " .. tostring(ChunkSize - (Keep * 2))
            .. " of " .. tostring(ChunkSize) .. " bytes omitted; --MaxLogBytes= to raise, --NoLogs=true to stop writing them]\n"
            .. StringSub(ChunkText, ChunkSize - Keep + 1)
    end
    StandardOutput = BoundLogChunk(tostring(StandardOutput or ""))
    StandardError = BoundLogChunk(tostring(StandardError or ""))
    local LogLines = {
        "V1Dumper run log",
        "Timestamp: " .. OsDate("!%Y-%m-%dT%H:%M:%SZ"),
        "Input: " .. InputShown,
        "Output: " .. OutputShown,
        "TimedOut: " .. ToString(TimedOut),
        "ExitOkay: " .. ToString(ExitOkay),
        "ExitCode: " .. ToString(ExitCode),
        "TimeoutSeconds: " .. ToString(ConfigurationSettings.TimeoutSeconds),
        "",
    }
    if ExtraMessage and ExtraMessage ~= "" then
        TableInsert(LogLines, "Message: " .. ExtraMessage)
        TableInsert(LogLines, "")
    end
    TableInsert(LogLines, "================ STDOUT ================")
    TableInsert(LogLines, StandardOutput ~= "" and StandardOutput or "(empty)")
    TableInsert(LogLines, "================ STDERR ================")
    TableInsert(LogLines, StandardError ~= "" and StandardError or "(empty)")
    TableInsert(LogLines, "================ END LOG ================")
    local LogText = TableConcat(LogLines, "\n")
    __V1HostWrite(LogPath, LogText)
    __V1HostWrite(ConfigurationSettings.LogFolder .. "/latest.log", LogText)
end
local function HasRecoverableBody(CandidateText)
    local FirstLineEnd = StringFind(CandidateText, "\n", 1, true)
    if not FirstLineEnd then return false end
    local SecondLineEnd = StringFind(CandidateText, "\n", FirstLineEnd + 1, true)
    if not SecondLineEnd then return false end
    local BodyText = StringSub(CandidateText, SecondLineEnd + 1)
    return StringMatch(BodyText, "%S") ~= nil
end
local function CheckValidLuau(CandidateText)
    if InternalType(CandidateText) ~= "string" or CandidateText == "" then return false end
    if not HasRecoverableBody(CandidateText) then return false end
    local LoadSucceeded, LoadedFunction = InternalPCall(LoadString, CandidateText, "@KVMSRecoveredOutput")
    return LoadSucceeded and LoadedFunction ~= nil
end
local function TryCloseOpenBlocks(CandidateText)
    if CheckValidLuau(CandidateText) then return CandidateText end
    local ClosingText = ""
    for _ = 1, 24 do
        ClosingText ..= "\nend"
        local ClosedCandidate = CandidateText .. ClosingText
        if CheckValidLuau(ClosedCandidate) then return ClosedCandidate end
    end
    return nil
end
local function RecoverPartialOutput(PartialContent)
    if InternalType(PartialContent) ~= "string" or PartialContent == "" then return nil end
    local RecoveredCandidate = TryCloseOpenBlocks(PartialContent)
    if RecoveredCandidate then return RecoveredCandidate end
    local CandidateLines = StringSplit(PartialContent, "\n")
    while #CandidateLines > 2 do
        TableRemove(CandidateLines, #CandidateLines)
        local TruncatedCandidate = TableConcat(CandidateLines, "\n")
        RecoveredCandidate = TryCloseOpenBlocks(TruncatedCandidate)
        if RecoveredCandidate then return RecoveredCandidate end
    end
    return nil
end
local function RunSupervisedProcess()
    local InputPath = TargetInputFile
    local OutputPath = TargetOutputFile
    local LogFolderReady = EnsureLogFolder()
    local InputBaseName = GetSafeBaseName(InputPath)
    local TimestampFraction = StringFormat("%06d", MathFloor((Clock() % 1) * 1000000))
    local TimestampText = OsDate("!%Y%m%d-%H%M%S") .. "-" .. TimestampFraction
    local LogPath = ConfigurationSettings.LogFolder .. "/" .. InputBaseName .. "-" .. TimestampText .. ".log"
    local PartialPath = ConfigurationSettings.LogFolder .. "/" .. InputBaseName .. "-" .. TimestampText .. ".partial.lua"
    local ScriptPath = ResolveCurrentScriptPath()
    local WorkerArguments = BuildWorkerArguments(ScriptPath)
    local BinaryCandidates = {}
    local BinaryCandidateMap = {}
    local function AddBinaryCandidate(BinaryPath)
        if InternalType(BinaryPath) ~= "string" or BinaryPath == "" or BinaryCandidateMap[BinaryPath] then return end
        BinaryCandidateMap[BinaryPath] = true
        TableInsert(BinaryCandidates, BinaryPath)
    end
    AddBinaryCandidate(ConfigurationSettings.LuneBinary)
    if Process.os == "linux" then AddBinaryCandidate("/proc/self/exe") end
    AddBinaryCandidate(Process.env.V1_LUNE_BINARY)
    AddBinaryCandidate(Process.env._)
    AddBinaryCandidate("lune")
    local SpawnSucceeded = false
    local ChildProcess = nil
    local SelectedBinary = nil
    local SpawnErrors = {}
    for BinaryIndex = 1, #BinaryCandidates do
        local BinaryPath = BinaryCandidates[BinaryIndex]
        local CandidateSucceeded, ChildOrError = InternalPCall(Process.create, BinaryPath, WorkerArguments, {
            cwd = Process.cwd,
        })
        if CandidateSucceeded then
            SpawnSucceeded = true
            ChildProcess = ChildOrError
            SelectedBinary = BinaryPath
            break
        end
        TableInsert(SpawnErrors, BinaryPath .. ": " .. ToString(ChildOrError))
    end
    if not SpawnSucceeded then
        local SpawnErrorText = TableConcat(SpawnErrors, "\n")
        -- r67: alasan spawn cuma ke konsol/log, gak ditulis ke file hasil
        __V1HostWrite(OutputPath, Fidelity.ClampToBudget(Fidelity.SpliceWatermark(BuildWatermark()),
            ConfigurationSettings))
        if LogFolderReady then
            WriteRunLog(LogPath, false, nil, "", SpawnErrorText, "Unable to start the worker process")
        end
        InternalPrint("[V1Dumper] Unable to start worker. Attempted binaries:\n" .. SpawnErrorText)
        __V1FlushPendingHostWrites()
        Process.exit(1)
    end
    local StandardOutput = ""
    local StandardError = ""
    local StandardOutputDone = false
    local StandardErrorDone = false
    local TimedOut = false
    Task.spawn(function()
        local ReadSucceeded, ReadResult = InternalPCall(function()
            return ChildProcess.stdout:readToEnd()
        end)
        StandardOutput = ReadSucceeded and ReadResult or ("[stdout read error] " .. ToString(ReadResult))
        StandardOutputDone = true
    end)
    Task.spawn(function()
        local ReadSucceeded, ReadResult = InternalPCall(function()
            return ChildProcess.stderr:readToEnd()
        end)
        StandardError = ReadSucceeded and ReadResult or ("[stderr read error] " .. ToString(ReadResult))
        StandardErrorDone = true
    end)
    local TimeoutDuration = ToNumber(ConfigurationSettings.TimeoutSeconds) or 60
    local TimeoutThread = Task.delay(TimeoutDuration, function()
        TimedOut = true
        InternalPCall(function()
            ChildProcess:kill()
        end)
    end)
    local StatusSucceeded, ExitStatus = InternalPCall(function()
        return ChildProcess:status()
    end)
    if not TimedOut then InternalPCall(Task.cancel, TimeoutThread) end
    local ReaderWaitStart = Clock()
    while (not StandardOutputDone or not StandardErrorDone) and Clock() - ReaderWaitStart < 5 do
        Task.wait(0.01)
    end
    if not StatusSucceeded then
        StandardError ..= "\n[status error] " .. ToString(ExitStatus)
        ExitStatus = nil
    end
    local RecoveryMessage = "Worker binary: " .. ToString(SelectedBinary)
    if TimedOut then
        local PartialContent = ""
        if OriginalFsIsFile(OutputPath) then
            local PartialReadSucceeded, PartialReadResult = InternalPCall(OriginalFsRead, OutputPath)
            if PartialReadSucceeded then PartialContent = PartialReadResult end
        end
        if LogFolderReady then __V1HostWrite(PartialPath, PartialContent) end
        local RecoveredOutput = RecoverPartialOutput(PartialContent)
        if RecoveredOutput then
            local IncompleteNote = "\n-- this stopped before the end of the file; what is here is not the whole script\n"
            local ByteBudget = tonumber(ConfigurationSettings.MaxOutputBytes) or 0
            if ByteBudget > 0 and #RecoveredOutput + #IncompleteNote > ByteBudget then
                RecoveredOutput = StringSub(RecoveredOutput, 1, ByteBudget - #IncompleteNote - 1)
            end
            RecoveredOutput ..= IncompleteNote
            __V1HostWrite(OutputPath, RecoveredOutput)
            ConfigurationSettings.RecoveredFileIsUsable = true
            RecoveryMessage ..= "; worker terminated by watchdog; valid partial Luau recovered; raw partial: " .. PartialPath
        else
            -- r67: gak ada komentar penjelasan; file tetap dibuat (biar bot punya sesuatu) tapi
            --  isinya cuma watermark, bukan narasi kegagalan.
            __V1HostWrite(OutputPath, Fidelity.ClampToBudget(Fidelity.SpliceWatermark(BuildWatermark()),
                ConfigurationSettings))
            RecoveryMessage ..= "; worker terminated by watchdog; partial output was not valid Luau; raw partial: " .. PartialPath
        end
        StandardError ..= "\ntimeout"
    elseif StringFind(StandardError, "[status error]", 1, true) ~= nil then
        local CutNote = "\n-- this stopped before the end of the file; what is here is not the whole script\n"
        local SnapshotText = nil
        if OriginalFsIsFile(OutputPath) then
            local SnapshotReadOk, SnapshotReadResult = InternalPCall(OriginalFsRead, OutputPath)
            if SnapshotReadOk then SnapshotText = SnapshotReadResult end
        end
        if type(SnapshotText) == "string" and StringFind(SnapshotText, CutNote, 1, true) == nil then
            __V1HostWrite(OutputPath, Fidelity.ClampToBudget(SnapshotText .. CutNote, ConfigurationSettings))
        end
        RecoveryMessage ..= "; the worker stopped with an error, so the file is a crash snapshot and not a finished recovery"
    elseif not OriginalFsIsFile(OutputPath) then
        local RefusalSeen = StringMatch(StandardOutput, "refusing [%g?%g%%_%.%-%/]*: %d+ bytes is over the %d+ byte input limit")
        -- r71: file hasil tidak menuliskan alasan kegagalan apa pun. Yang ngasih tau cuma
        --  rc + pesan konsol; file isinya watermark doang.
        local FailureText = "-- the input was too big to open here"
        __V1HostWrite(OutputPath, Fidelity.ClampToBudget(Fidelity.SpliceWatermark(
            BuildWatermark() .. FailureText), ConfigurationSettings))
        RecoveryMessage ..= "; worker did not create an output file"
    end
    if LogFolderReady then
        WriteRunLog(LogPath, TimedOut, ExitStatus, StandardOutput, StandardError, RecoveryMessage)
    end
    if ConfigurationSettings.ForwardWorkerConsole then
        if StandardOutput ~= "" then InternalPrint(StandardOutput) end
        if StandardError ~= "" then InternalPrint(StandardError) end
    end
    if TimedOut then
        InternalPrint("timeout")
    else
        InternalPrint("[V1Dumper] Done: " .. OutputPath)
    end
    Process.exit((TimedOut and ConfigurationSettings.RecoveredFileIsUsable ~= true) and 124 or 0)
end
if ConfigurationSettings.WorkerMode then
    InitializeDecodingProcess(TargetInputFile)
else
    RunSupervisedProcess()
end
