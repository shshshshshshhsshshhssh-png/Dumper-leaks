local Fidelity = {}
local StringPack = string.pack
local StringUnpack = string.unpack
local function ToFloat32(value)
    if type(value) ~= "number" then
        return value
    end
    local packedOk, packed = pcall(StringPack, "<f", value)
    if not packedOk then
        return value
    end
    local unpackedOk, rounded = pcall(StringUnpack, "<f", packed)
    if not unpackedOk then
        return rounded and value or value
    end
    return rounded
end
Fidelity.ToFloat32 = ToFloat32
local NativeAtan2 = math.atan2
local function Atan2(y, x)
    if NativeAtan2 then
        return NativeAtan2(y, x)
    end
    if x > 0 then
        return math.atan(y / x)
    elseif x < 0 then
        if y >= 0 then
            return math.atan(y / x) + math.pi
        end
        return math.atan(y / x) - math.pi
    elseif y > 0 then
        return math.pi / 2
    elseif y < 0 then
        return -math.pi / 2
    end
    return 0
end
Fidelity.Atan2 = Atan2
local function ClampNumber(value, minValue, maxValue)
    if value ~= value then
        return minValue
    end
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end
Fidelity.ClampNumber = ClampNumber
local function RoundToInteger(value)
    return math.floor(value + 0.5)
end
local function EasingIndex(value)
    if type(value) == "number" then
        return value
    end
    if type(value) == "table" and type(value.Value) == "number" then
        return value.Value
    end
    return 0
end
function Fidelity.ApplyEasing(alpha, style, direction)
    local t = alpha
    if t < 0 then
        t = 0
    elseif t > 1 then
        t = 1
    end
    local styleIndex = math.floor(EasingIndex(style))
    local directionIndex = math.floor(EasingIndex(direction))
    local function Curve(u)
        if styleIndex == 1 then
            return u * u
        elseif styleIndex == 2 then
            return u * u * u
        elseif styleIndex == 3 then
            return u * u * u * u
        elseif styleIndex == 4 then
            return u * u * u * u * u
        elseif styleIndex == 5 then
            return 1 - math.cos(u * (math.pi / 2))
        elseif styleIndex == 6 then
            if u == 0 then
                return 0
            end
            return math.pow(2, 10 * (u - 1))
        elseif styleIndex == 7 then
            return 1 - math.sqrt(1 - u * u)
        elseif styleIndex == 8 then
            local function BounceOut(x)
                local n1, d1 = 7.5625, 2.75
                if x < 1 / d1 then
                    return n1 * x * x
                elseif x < 2 / d1 then
                    x -= 1.5 / d1
                    return n1 * x * x + 0.75
                elseif x < 2.5 / d1 then
                    x -= 2.25 / d1
                    return n1 * x * x + 0.9375
                end
                x -= 2.625 / d1
                return n1 * x * x + 0.984375
            end
            return BounceOut(u)
        elseif styleIndex == 9 then
            if u == 0 or u == 1 then
                return u
            end
            return -math.pow(2, 10 * (u - 1)) * math.sin((u * 10 - 0.75) * ((2 * math.pi) / 3))
        elseif styleIndex == 10 then
            local c1, c3 = 1.70158, 2.70158
            return c3 * u * u * u - c1 * u * u
        end
        return u
    end
    if directionIndex == 1 then
        return 1 - Curve(1 - t)
    elseif directionIndex == 2 then
        if t < 0.5 then
            return Curve(t * 2) * 0.5
        end
        return 1 - Curve((1 - t) * 2) * 0.5
    end
    return Curve(t)
end
Fidelity.EnumValues = {
    RaycastFilterType = { Include = 0, Exclude = 1 },
    PlaybackState = { Delayed = 0, Playing = 1, Completed = 2, Canceled = 3 },
    EasingStyle = {
        Linear = 0, Quadratic = 1, Cubic = 2, Quartic = 3, Quintic = 4,
        Sinusoidal = 5, Exponential = 6, Circular = 7, Bounce = 8,
        Elastic = 9, Back = 10,
    },
    EasingDirection = { In = 0, Out = 1, InOut = 2 },
    ListenerType = { Camera = 0, CFrame = 1, ObjectPosition = 2, ObjectCFrame = 3 },
    ReverbType = {
        NoReverb = 0, GenericReverb = 1, PaddedCell = 2, Room = 3, Bathroom = 4,
        LivingRoom = 5, StoneRoom = 6, Auditorium = 7, ConcertHall = 8, Cave = 9,
        Arena = 10, Hangar = 11, CarpettedHallway = 12, Hallway = 13, StoneCorridor = 14,
        Alley = 15, Forest = 16, City = 17, Mountains = 18, Quarry = 19, Plain = 20,
        ParkingLot = 21, SewerPipe = 22, UnderWater = 23,
    },
    Font = {
        Legacy = 0, Arial = 1, ArialBold = 2, SourceSans = 3, SourceSansBold = 4,
        SourceSansLight = 5, SourceSansItalic = 6, SourceSansSemibold = 7, Bodoni = 8,
        Garamond = 9, Cartoon = 10, Code = 11, Highway = 12, SciFi = 13, Arcade = 14,
        Fantasy = 15, Antique = 16, Gotham = 17, GothamSemibold = 18, GothamBold = 19,
        GothamBlack = 20, AmaticSC = 21, Bangers = 22, Creepster = 23, DenkOne = 24,
        Fondamento = 25, FredokaOne = 26, GrenzeGotisch = 27, IndieFlower = 28,
        JosefinSans = 29, Jura = 30, Kalam = 31, LuckiestGuy = 32, Merriweather = 33,
        Michroma = 34, Nunito = 35, Oswald = 36, PatrickHand = 37, PermanentMarker = 38,
        Roboto = 39, RobotoCondensed = 40, RobotoMono = 41, Sarpanch = 42,
        SpecialElite = 43, TitilliumWeb = 44, Ubuntu = 45,
    },
    NormalId = { Right = 0, Top = 1, Back = 2, Left = 3, Bottom = 4, Front = 5 },
    PartType = { Block = 0, Ball = 1, Cylinder = 2 },
    Axis = { X = 0, Y = 1, Z = 2 },
    CompressionAlgorithm = { Zstd = 0 },
    Material = {
        Plastic = 256, Wood = 512, Slate = 80, Concrete = 816, CorrodedMetal = 1088,
        DiamondPlate = 1280, Foil = 1480, Grass = 2048, Ice = 3072, Marble = 320,
        Granite = 336, Brick = 848, Pebble = 864, Sand = 1024, Fabric = 1376,
        SmoothPlastic = 1568, Metal = 1072,
    },
}
Fidelity.EnumValues.FontWeight = {
    Thin = 100, ExtraLight = 200, Light = 300, Regular = 400, Medium = 500,
    SemiBold = 600, Bold = 700, ExtraBold = 800, Black = 900,
}
Fidelity.EnumValues.FontStyle = { Normal = 0, Italic = 1 }
Fidelity.EnumValues.RotationOrder = { XYZ = 0, XZY = 1, YXZ = 2, YZX = 3, ZXY = 4, ZYX = 5 }
Fidelity.EnumValues.ZIndexBehavior = { Global = 0, Sibling = 1 }
Fidelity.EnumValues.SortOrder = { LayoutOrder = 0, Name = 1, Custom = 2 }
Fidelity.EnumValues.HumanoidRigType = { R15 = 1, R6 = 2 }
Fidelity.EnumValues.PartType = { Block = 0, Ball = 1, Cylinder = 2 }
Fidelity.EnumValues.AccessModifierType = { Allow = 0, Deny = 1 }
Fidelity.EnumValues.PathStatus = {
    Success = 0, ClosestNoPath = 1, ClosestOutOfRange = 2,
    FailStartNotEmpty = 3, FailFinishNotEmpty = 4, NoPath = 5,
}
Fidelity.EnumValues.HorizontalAlignment = { Left = 0, Center = 1, Right = 2 }
Fidelity.EnumValues.VerticalAlignment = { Top = 0, Center = 1, Bottom = 2 }
Fidelity.EnumValues.TextXAlignment = { Left = 0, Center = 1, Right = 2 }
Fidelity.EnumValues.TextYAlignment = { Top = 0, Center = 1, Bottom = 2 }
Fidelity.EnumValues.FillDirection = { Horizontal = 0, Vertical = 1 }
Fidelity.EnumValues.CameraType = {
    Custom = 0, Scriptable = 1, Walk = 2, Fixed = 6, Track = 7,
}
Fidelity.EnumValues.Platform = {
    WindowsPlayer = 0, WindowsStudio = 1, MacPlayer = 2, MacStudio = 3, LinuxPlayer = 4,
    UnixPlayer = 5, UWPPlayer = 7, PS4Player = 8, XBoxOnePlayer = 9, IOSPlayer = 10,
    AndroidPlayer = 11, PS5Player = 16, XboxSeriesXPlayer = 17, CloudGame = 18,
    GenericUnknownPlatform = 252,
}
Fidelity.EnumValues.HumanoidStateType = {
    FallingDown = 0, Running = 1, GettingUp = 2, Jumping = 3, Landed = 4, Freefall = 5,
    Seated = 6, Climbing = 7, Swimming = 8, Physics = 10, PlatformStand = 11, Dead = 12,
}
Fidelity.EnumValues.ActuatorRelativeTo = { Attachment0 = 0, Attachment1 = 1, World = 2 }
Fidelity.EnumValues.PositionAlignmentMode = { OneAttachment = 0, TwoAttachments = 1 }
Fidelity.EnumValues.OrientationAlignmentMode = { OneAttachment = 0, TwoAttachments = 1 }
Fidelity.EnumValues.KeyInterpolationMode = { Linear = 0, Constant = 1, Cubic = 2 }
Fidelity.EnumValues.PoseEasingStyle = {
    Linear = 0, Constant = 1, Cubic = 2, Quartic = 3, Quintic = 4,
    Sinusoidal = 5, Uniform = 6, Spring = 7, EaseInOutCubic = 8,
}
Fidelity.EnumValues.PoseEasingDirection = { In = 0, Out = 1, InOut = 2 }
Fidelity.EnumValues.AnimationPriority = {
    Core = 0, Action = 1, Movement = 2, Gesture = 3, Idle = 4,
}
Fidelity.EnumValues.AnimationCurveFitterType = { Auto = 0, None = 1, Linear = 2, Bezier = 3, SimpleBezier = 4 }
Fidelity.EnumValues.DeveloperMemoryTag = {
    Instances = 0, Connections = 1, Sounds = 2, Textures = 3, MeshParts = 4,
    SolidModels = 5, Sockets = 6, GuiButtons = 7, Places = 8, ContentProvider = 9,
    Lua = 10, PhysicsSolver = 11, MemoryStore = 12, VideoCaptures = 13,
}
Fidelity.EnumValues.ReverbType = {
    Generic = 0, PaddedCell = 1, Room = 2, Bathroom = 3, ConcreteRoom = 4, Hallway = 5,
    CarpetedHallway = 6, City = 7, Studio = 8, DriveTime = 9, SpaceEcho = 10, Echo = 11,
    CastleRoom = 12, CastleHallway = 13, BrassRoom = 14, WoodRoom = 15, SmallRoom = 16,
}
Fidelity.EnumValues.UserInputState = {
    Begin = 0, Change = 1, End = 2, Cancel = 3, Hover = 4, Press = 5, Release = 6,
}
Fidelity.EnumValues.TouchState = { Began = 0, Changed = 1, Ended = 2, Cancelled = 3 }
Fidelity.EnumValues.MouseBehavior = { Default = 0, LockCenter = 1, LockOrientation = 2 }
Fidelity.EnumValues.Limb = {
    Head = 0, UpperTorso = 1, LowerTorso = 2, Root = 3, LeftArm = 4, RightArm = 5,
    LeftLeg = 6, RightLeg = 7,
}
Fidelity.EnumValues.AccessoryType = {
    Hat = 0, Hair = 1, Face = 2, Neck = 3, Shoulder = 4, Back = 5, Waist = 6,
    Hip = 7, Bag = 8, Bookmark = 9, Belt = 10, Vest = 11, Shirt = 12, Pants = 13,
    Dress = 14, Jacket = 15, Cape = 16, Glasses = 17, ShirtAccessory = 19,
}
Fidelity.EnumValues.ParticleEmitterShape = { Part = 0, Circle = 1, Sphere = 2, Box = 3, Cylinder = 4, Cone = 5, Strip = 6, Mesh = 7, Point = 8, TwoPointLine = 9 }
Fidelity.EnumValues.DeviceOrientation = {
    LandscapeLeft = 0, LandscapeRight = 1, Portrait = 2, PortraitFlip = 3, Unknown = 4,
}
Fidelity.EnumItemCache = {}
local EnumItemMetatable = {}
EnumItemMetatable.__index = EnumItemMetatable
EnumItemMetatable.__eq = function(LeftItem, RightItem)
    if type(RightItem) == "table" then
        return rawget(LeftItem, "Name") == rawget(RightItem, "Name")
            and rawget(LeftItem, "EnumTypeName") == rawget(RightItem, "EnumTypeName")
    end
    return rawget(LeftItem, "Value") == RightItem
end
EnumItemMetatable.__tostring = function(SelfItem)
    return "Enum." .. tostring(rawget(SelfItem, "EnumTypeName"))
        .. "." .. tostring(rawget(SelfItem, "Name"))
end
function Fidelity.MakeEnumItem(EnumTypeNameValue, ItemNameValue, NumericValue)
    local TypeCache = Fidelity.EnumItemCache[EnumTypeNameValue]
    if TypeCache == nil then
        TypeCache = {}
        Fidelity.EnumItemCache[EnumTypeNameValue] = TypeCache
    end
    local CachedItem = TypeCache[ItemNameValue]
    if CachedItem ~= nil then
        return CachedItem
    end
    local NewItem = setmetatable({
        _Type = "EnumItem",
        Name = ItemNameValue,
        Value = NumericValue,
        EnumTypeName = EnumTypeNameValue,
    }, EnumItemMetatable)
    function NewItem:GetEnumType()
        return Fidelity.EnumFacadeFor(EnumTypeNameValue)
    end
    function NewItem.IsA(SelfItem, OtherItem)
        if SelfItem == nil or type(SelfItem) ~= "table"
            or rawget(SelfItem, "_Type") ~= "EnumItem" then
            error("missing argument #1 to 'IsA' (EnumItem expected)", 0)
        end
        if OtherItem == nil or type(OtherItem) ~= "table"
            or rawget(OtherItem, "_Type") ~= "EnumItem" then
            error("invalid argument #2 to 'IsA' (EnumItem expected)", 0)
        end
        return rawget(SelfItem, "EnumTypeName") == rawget(OtherItem, "EnumTypeName")
    end
    TypeCache[ItemNameValue] = NewItem
    return NewItem
end
local utf8codepoint = utf8.codepoint
local utf8offset = utf8.offset
local HANGUL_SBASE, HANGUL_LBASE = 0xAC00, 0x1100
local HANGUL_VBASE, HANGUL_TBASE = 0x1161, 0x11A7
local HANGUL_LCOUNT, HANGUL_VCOUNT, HANGUL_TCOUNT = 19, 21, 28
local HANGUL_NCOUNT = HANGUL_VCOUNT * HANGUL_TCOUNT
local HANGUL_SCOUNT = HANGUL_LCOUNT * HANGUL_NCOUNT
local function EncodeCodepoint(codepoint)
    return utf8.char(codepoint)
end
local function DecodeCodepoints(text)
    local collected = {}
    local position = 1
    local length = #text
    while position <= length do
        local codepoint = utf8codepoint(text, position)
        if codepoint == nil then break end
        collected[#collected + 1] = codepoint
        local nextPosition = utf8offset(text, 2, position)
        if nextPosition == nil then break end
        position = nextPosition
    end
    return collected
end
function Fidelity.BuildUtf8Library(hostUtf8)
    local library = {}
    for key, value in pairs(hostUtf8) do library[key] = value end
    local function CodepointEnd(input, index)
        local lead = string.byte(input, index) or 0
        local width = 1
        if lead >= 0xF0 then width = 4 elseif lead >= 0xE0 then width = 3
        elseif lead >= 0xC0 then width = 2 end
        return math.min(index + width - 1, #input)
    end
    local function MarkGraphemesNative(FunctionValue)
        if Fidelity.EmulatedNatives ~= nil and FunctionValue ~= nil then
            Fidelity.EmulatedNatives[FunctionValue] = true
        end
    end
    library.graphemes = function(input, i, j)
        if type(input) ~= "string" then
            error("invalid argument #1 to 'graphemes' (string expected)", 0)
        end
        local startIndex = math.max(1, i or 1)
        local endIndex = j or #input
        if endIndex < 0 then endIndex = #input + endIndex + 1 end
        local hostIterator = nil
        if type(hostUtf8) == "table" and type(hostUtf8.graphemes) == "function" then
            local okIterator, iterator = pcall(hostUtf8.graphemes, input, startIndex, endIndex)
            if okIterator and type(iterator) == "function" then
                hostIterator = iterator
            end
        end
        local cursor = startIndex
        return function()
            if hostIterator ~= nil then
                local first, last = hostIterator()
                if first == nil then return nil end
                return first, last
            end
            if cursor > endIndex then return nil end
            local last = CodepointEnd(input, cursor)
            local first = cursor
            cursor = last + 1
            return first, last
        end, input, startIndex
    end
    MarkGraphemesNative(library.graphemes)
    function library.nfcnormalize(input)
        if type(input) ~= "string" then
            error("invalid argument #1 to 'nfcnormalize' (string expected)", 0)
        end
        local codepoints = DecodeCodepoints(input)
        local pieces = {}
        local index = 1
        while index <= #codepoints do
            local current = codepoints[index]
            local leadIndex = current - HANGUL_LBASE
            local composed = nil
            if leadIndex >= 0 and leadIndex < HANGUL_LCOUNT and index < #codepoints then
                local vowelIndex = codepoints[index + 1] - HANGUL_VBASE
                if vowelIndex >= 0 and vowelIndex < HANGUL_VCOUNT then
                    composed = HANGUL_SBASE
                        + (leadIndex * HANGUL_VCOUNT + vowelIndex) * HANGUL_TCOUNT
                    index = index + 2
                    if index <= #codepoints then
                        local tailIndex = codepoints[index] - HANGUL_TBASE
                        if tailIndex > 0 and tailIndex < HANGUL_TCOUNT then
                            composed = composed + tailIndex
                            index = index + 1
                        end
                    end
                end
            end
            if composed ~= nil then
                pieces[#pieces + 1] = EncodeCodepoint(composed)
            else
                pieces[#pieces + 1] = EncodeCodepoint(current)
                index = index + 1
            end
        end
        return table.concat(pieces)
    end
    function library.nfdnormalize(input)
        if type(input) ~= "string" then
            error("invalid argument #1 to 'nfdnormalize' (string expected)", 0)
        end
        local codepoints = DecodeCodepoints(input)
        local pieces = {}
        for index = 1, #codepoints do
            local current = codepoints[index]
            local syllableIndex = current - HANGUL_SBASE
            if syllableIndex >= 0 and syllableIndex < HANGUL_SCOUNT then
                pieces[#pieces + 1] = EncodeCodepoint(
                    HANGUL_LBASE + math.floor(syllableIndex / HANGUL_NCOUNT))
                pieces[#pieces + 1] = EncodeCodepoint(
                    HANGUL_VBASE + math.floor((syllableIndex % HANGUL_NCOUNT) / HANGUL_TCOUNT))
                local tail = HANGUL_TBASE + (syllableIndex % HANGUL_TCOUNT)
                if tail ~= HANGUL_TBASE then
                    pieces[#pieces + 1] = EncodeCodepoint(tail)
                end
            else
                pieces[#pieces + 1] = EncodeCodepoint(current)
            end
        end
        return table.concat(pieces)
    end
    return library
end
Fidelity.EnumNames = {
    "ActuatorRelativeTo", "ActuatorType", "AlphaMode", "AnimationCurveFitterType", "AnimationPriority",
    "AnnotationAction", "AppSaveSettingCategory", "AppSaveSettingId", "AssetType", "AssignmentPolicyType",
    "AttractPriority", "AudioPitchType", "AudioReverbDestination", "AvatarPartScaleType", "Axis",
    "BatteryType", "BuildCameraType", "CameraMode", "CameraType", "ChatPrivacy", "ChildController",
    "CompressionAlgorithm", "ConnectStatus", "ContextActionPriority", "ContextActionResult", "ControlMode",
    "DeletionAction", "DeviceOrientation", "DfpwmStatus",
    "EditRestrictions", "EasingDirection", "EasingStyle", "FillDirection", "FilterType",
    "Font", "FontStyle", "FontWeight", "GraphicsName", "HandleResizeMode",
    "HorizontalAlignment", "HumanoidRigType", "HumanoidStateType", "IniFileType", "Language",
    "LevelCell", "Limb", "ListenerType", "Material", "MouseBehavior", "NormalId",
    "OrientationAlignmentMode", "PartType", "ParticleEmitterShape", "ParticleEmitterShapeInOut",
    "ParticleEmitterShapeStyle", "ParticleOrientation", "PathStatusType", "PermissionLevelType",
    "PlaybackState", "Platform", "PositionAlignmentMode", "PoseEasingDirection", "PoseEasingStyle",
    "PrivateChatType", "QualityLevelType", "RaycastFilterType", "ReverbType", "RotationOrder",
    "ScrollBarDirection", "ScrollBarStyle", "SortOrder", "TextTruncation", "TextXAlignment",
    "TextYAlignment", "ThumbnailSize", "ThumbnailType", "TouchState", "TouchTransmitterBehavior",
    "TransactionType", "UserCoresType", "UserInputState", "VerticalAlignment", "WorkspaceStreamingMode",
    "ZIndexBehavior", "KeyInterpolationMode",
}
function Fidelity.EnumValue(enumTypeName, itemName, fallback)
    local typeTable = Fidelity.EnumValues[enumTypeName]
    if typeTable ~= nil then
        local value = typeTable[itemName]
        if value ~= nil then
            return Fidelity.MakeEnumItem(enumTypeName, itemName, value)
        end
    end
    return Fidelity.MakeEnumItem(enumTypeName, itemName, fallback)
end
Fidelity.UserdataTypedValues = {
    Font = true,
    Enum = true, EnumItem = true, Enums = true,
    RBXScriptSignal = true, RBXScriptConnection = true,
    Vector2 = true, Vector3 = true, CFrame = true, Color3 = true, BrickColor = true,
    UDim = true, UDim2 = true, Rect = true, NumberRange = true, Ray = true,
    TweenInfo = true, PhysicalProperties = true, RaycastParams = true,
    OverlapParams = true, RaycastResult = true, EnumItem = true,
    RBXScriptSignal = true, RBXScriptConnection = true, Axes = true, Faces = true,
    Content = true, DateTime = true, ColorSequence = true, NumberSequence = true,
    Path2DControlPoint = true, UserData = true,
}
local function ValueNumber(value)
    local numeric = tonumber(value)
    if numeric ~= nil and numeric == numeric and numeric ~= math.huge and numeric ~= -math.huge then
        return string.format("%g", numeric)
    end
    return tostring(value)
end
local Vector2 = {}
local Vector2Methods = {}
local Vector2MT = {
    __index = Vector2Methods,
    __add = function(a, b) return Vector2.new(a.X + b.X, a.Y + b.Y) end,
    __sub = function(a, b) return Vector2.new(a.X - b.X, a.Y - b.Y) end,
    __mul = function(a, b)
        if type(a) == "number" then return Vector2.new(a * b.X, a * b.Y) end
        if type(b) == "number" then return Vector2.new(a.X * b, a.Y * b) end
        return Vector2.new(a.X * b.X, a.Y * b.Y)
    end,
    __div = function(a, b)
        if type(b) == "number" then return Vector2.new(a.X / b, a.Y / b) end
        return Vector2.new(a.X / b.X, a.Y / b.Y)
    end,
    __unm = function(a) return Vector2.new(-a.X, -a.Y) end,
    __eq = function(a, b) return a.X == b.X and a.Y == b.Y end,
    __tostring = function(a) return string.format("%s, %s", ValueNumber(a.X), ValueNumber(a.Y)) end,
}
function Vector2.new(x, y)
    return table.freeze(setmetatable({
        X = ToFloat32(x or 0),
        Y = ToFloat32(y or 0),
        _Type = "Vector2",
    }, Vector2MT))
end
Vector2.zero = Vector2.new(0, 0)
Vector2.one = Vector2.new(1, 1)
function Vector2Methods:Magnitude()
    return ToFloat32(math.sqrt(self.X * self.X + self.Y * self.Y))
end
function Vector2Methods:Dot(other)
    return self.X * other.X + self.Y * other.Y
end
function Vector2Methods:Cross(other)
    return self.X * other.Y - self.Y * other.X
end
function Vector2Methods:Lerp(goal, alpha)
    return Vector2.new(self.X + (goal.X - self.X) * alpha, self.Y + (goal.Y - self.Y) * alpha)
end
function Vector2Methods:FuzzyEq(other, epsilon)
    return math.abs(self.X - other.X) <= (epsilon or 1e-5) and math.abs(self.Y - other.Y) <= (epsilon or 1e-5)
end
Vector2MT.__index = function(self, key)
    if key == "Magnitude" then
        return math.sqrt(self.X * self.X + self.Y * self.Y)
    elseif key == "Unit" then
        local magnitude = math.sqrt(self.X * self.X + self.Y * self.Y)
        if magnitude == 0 then
            return Vector2.zero
        end
        return Vector2.new(self.X / magnitude, self.Y / magnitude)
    end
    local method = Vector2Methods[key]
    if method ~= nil then
        return method
    end
    return nil
end
local Vector3 = {}
local Vector3Methods = {}
local Vector3MT = {
    __index = nil,
    __add = function(a, b) return Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end,
    __sub = function(a, b) return Vector3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end,
    __mul = function(a, b)
        if type(a) == "number" then return Vector3.new(a * b.X, a * b.Y, a * b.Z) end
        if type(b) == "number" then return Vector3.new(a.X * b, a.Y * b, a.Z * b) end
        return Vector3.new(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
    end,
    __div = function(a, b)
        if type(b) == "number" then return Vector3.new(a.X / b, a.Y / b, a.Z / b) end
        return Vector3.new(a.X / b.X, a.Y / b.Y, a.Z / b.Z)
    end,
    __unm = function(a) return Vector3.new(-a.X, -a.Y, -a.Z) end,
    __eq = function(a, b) return a.X == b.X and a.Y == b.Y and a.Z == b.Z end,
    __tostring = function(a)
        return string.format("%s, %s, %s", ValueNumber(a.X), ValueNumber(a.Y), ValueNumber(a.Z))
    end,
}
function Vector3.new(x, y, z)
    return table.freeze(setmetatable({
        X = ToFloat32(x or 0),
        Y = ToFloat32(y or 0),
        Z = ToFloat32(z or 0),
        _Type = "Vector3",
    }, Vector3MT))
end
Vector3.zero = Vector3.new(0, 0, 0)
Vector3.one = Vector3.new(1, 1, 1)
Vector2Methods.Max = function(self, ...)
    local X, Y = rawget(self, "X") or 0, rawget(self, "Y") or 0
    for _, Other in ipairs({ ... }) do
        if type(Other) == "table" then
            local OtherX, OtherY = Other.X, Other.Y
            if type(OtherX) == "number" and OtherX > X then X = OtherX end
            if type(OtherY) == "number" and OtherY > Y then Y = OtherY end
        end
    end
    return Vector2.new(X, Y)
end
Vector2Methods.Min = function(self, ...)
    local X, Y = rawget(self, "X") or 0, rawget(self, "Y") or 0
    for _, Other in ipairs({ ... }) do
        if type(Other) == "table" then
            local OtherX, OtherY = Other.X, Other.Y
            if type(OtherX) == "number" and OtherX < X then X = OtherX end
            if type(OtherY) == "number" and OtherY < Y then Y = OtherY end
        end
    end
    return Vector2.new(X, Y)
end
function Vector2.Max(a, b)
    return Vector2.new(math.max(a.X, b.X), math.max(a.Y, b.Y))
end
function Vector2.Min(a, b)
    return Vector2.new(math.min(a.X, b.X), math.min(a.Y, b.Y))
end
Vector2.xAxis = Vector2.new(1, 0)
Vector2.yAxis = Vector2.new(0, 1)
Vector3.xAxis = Vector3.new(1, 0, 0)
Vector3.yAxis = Vector3.new(0, 1, 0)
Vector3.zAxis = Vector3.new(0, 0, 1)
local NormalIdUnitVectors = {
    Right = Vector3.new(1, 0, 0),
    Top = Vector3.new(0, 1, 0),
    Back = Vector3.new(0, 0, 1),
    Left = Vector3.new(-1, 0, 0),
    Bottom = Vector3.new(0, -1, 0),
    Front = Vector3.new(0, 0, -1),
}
function Vector3.fromNormalId(normalId)
    local name = type(normalId) == "table" and normalId.Name or nil
    local vector = NormalIdUnitVectors[name]
    if vector == nil then
        error("invalid argument #1 to 'Vector3.fromNormalId' (NormalId expected)", 0)
    end
    return vector
end
function Vector3Methods:Dot(other)
    return self.X * other.X + self.Y * other.Y + self.Z * other.Z
end
function Vector3Methods:Cross(other)
    return Vector3.new(
        self.Y * other.Z - self.Z * other.Y,
        self.Z * other.X - self.X * other.Z,
        self.X * other.Y - self.Y * other.X
    )
end
function Vector3Methods:Lerp(goal, alpha)
    return Vector3.new(
        self.X + (goal.X - self.X) * alpha,
        self.Y + (goal.Y - self.Y) * alpha,
        self.Z + (goal.Z - self.Z) * alpha
    )
end
function Vector3Methods:Angle(other, axis)
    local unitSelf = self.Unit
    local unitOther = other.Unit
    local cosine = ClampNumber(unitSelf:Dot(unitOther), -1, 1)
    local angle = math.acos(cosine)
    if axis ~= nil then
        local cross = unitSelf:Cross(unitOther)
        if cross:Dot(axis.Unit) < 0 then
            angle = -angle
        end
    end
    return angle
end
function Vector3Methods:FuzzyEq(other, epsilon)
    local tolerance = epsilon or 1e-5
    return math.abs(self.X - other.X) <= tolerance
        and math.abs(self.Y - other.Y) <= tolerance
        and math.abs(self.Z - other.Z) <= tolerance
end
function Vector3Methods:Normalize()
    local length = math.sqrt(self.X * self.X + self.Y * self.Y + self.Z * self.Z)
    if length == 0 then
        return Vector3.new(0, 0, 0)
    end
    return Vector3.new(self.X / length, self.Y / length, self.Z / length)
end
function Vector3Methods:Abs() return Vector3.new(math.abs(self.X), math.abs(self.Y), math.abs(self.Z)) end
function Vector3Methods:Ceil() return Vector3.new(math.ceil(self.X), math.ceil(self.Y), math.ceil(self.Z)) end
function Vector3Methods:Floor() return Vector3.new(math.floor(self.X), math.floor(self.Y), math.floor(self.Z)) end
function Vector3Methods:Min(other) return Vector3.new(math.min(self.X, other.X), math.min(self.Y, other.Y), math.min(self.Z, other.Z)) end
function Vector3Methods:Max(other) return Vector3.new(math.max(self.X, other.X), math.max(self.Y, other.Y), math.max(self.Z, other.Z)) end
Vector3MT.__index = function(self, key)
    if key == "Magnitude" then
        return ToFloat32(math.sqrt(self.X * self.X + self.Y * self.Y + self.Z * self.Z))
    elseif key == "x" or key == "y" or key == "z" then
        return self[string.upper(key)]
    elseif key == "Unit" then
        local magnitude = math.sqrt(self.X * self.X + self.Y * self.Y + self.Z * self.Z)
        if magnitude == 0 then
            return Vector3.zero
        end
        return Vector3.new(self.X / magnitude, self.Y / magnitude, self.Z / magnitude)
    end
    local method = Vector3Methods[key]
    if method ~= nil then
        return method
    end
    return nil
end
local CFrame = {}
local CFrameMethods = {}
local CFrameMT = {
    __index = nil,
    __mul = function(a, b)
        if rawget(b, "_Type") == "Vector3" then
            return a:PointToWorldSpace(b)
        end
        local ax, ay, az = a.X, a.Y, a.Z
        local px, py, pz = b.X, b.Y, b.Z
        local nx = a.R00 * px + a.R01 * py + a.R02 * pz + ax
        local ny = a.R10 * px + a.R11 * py + a.R12 * pz + ay
        local nz = a.R20 * px + a.R21 * py + a.R22 * pz + az
        local r00 = a.R00 * b.R00 + a.R01 * b.R10 + a.R02 * b.R20
        local r01 = a.R00 * b.R01 + a.R01 * b.R11 + a.R02 * b.R21
        local r02 = a.R00 * b.R02 + a.R01 * b.R12 + a.R02 * b.R22
        local r10 = a.R10 * b.R00 + a.R11 * b.R10 + a.R12 * b.R20
        local r11 = a.R10 * b.R01 + a.R11 * b.R11 + a.R12 * b.R21
        local r12 = a.R10 * b.R02 + a.R11 * b.R12 + a.R12 * b.R22
        local r20 = a.R20 * b.R00 + a.R21 * b.R10 + a.R22 * b.R20
        local r21 = a.R20 * b.R01 + a.R21 * b.R11 + a.R22 * b.R21
        local r22 = a.R20 * b.R02 + a.R21 * b.R12 + a.R22 * b.R22
        return CFrame.fromComponents(nx, ny, nz, r00, r01, r02, r10, r11, r12, r20, r21, r22)
    end,
    __eq = function(a, b)
        return a.X == b.X and a.Y == b.Y and a.Z == b.Z
            and a.R00 == b.R00 and a.R01 == b.R01 and a.R02 == b.R02
            and a.R10 == b.R10 and a.R11 == b.R11 and a.R12 == b.R12
            and a.R20 == b.R20 and a.R21 == b.R21 and a.R22 == b.R22
    end,
    __tostring = function(a)
        return string.format("%s, %s, %s, %s, %s, %s, %s, %s, %s",
            ValueNumber(a.X), ValueNumber(a.Y), ValueNumber(a.Z),
            ValueNumber(a.R00), ValueNumber(a.R01), ValueNumber(a.R02),
            ValueNumber(a.R10), ValueNumber(a.R11), ValueNumber(a.R12))
    end,
}
function CFrame.fromComponents(x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22)
    return table.freeze(setmetatable({
        X = ToFloat32(x), Y = ToFloat32(y), Z = ToFloat32(z),
        R00 = ToFloat32(r00), R01 = ToFloat32(r01), R02 = ToFloat32(r02),
        R10 = ToFloat32(r10), R11 = ToFloat32(r11), R12 = ToFloat32(r12),
        R20 = ToFloat32(r20), R21 = ToFloat32(r21), R22 = ToFloat32(r22),
        _Type = "CFrame",
    }, CFrameMT))
end
function CFrame.new(...)
    local argCount = select("#", ...)
    if argCount == 0 then
        return CFrame.identity
    elseif argCount == 1 then
        local only = ...
        if type(only) == "number" then
            return CFrame.fromComponents(only, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1)
        end
        return CFrame.fromComponents(only.X, only.Y, only.Z, 1, 0, 0, 0, 1, 0, 0, 0, 1)
    elseif argCount == 2 then
        local position, lookAt = ...
        if type(position) == "number" then
            return CFrame.fromComponents(position, lookAt, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1)
        end
        local zAxis = lookAt - position
        local magnitude = zAxis.Magnitude
        if magnitude == 0 then
            return CFrame.fromComponents(position.X, position.Y, position.Z, 1, 0, 0, 0, 1, 0, 0, 0, 1)
        end
        local forward = Vector3.new(-zAxis.X / magnitude, -zAxis.Y / magnitude, -zAxis.Z / magnitude)
        local upGuess = math.abs(forward.Y) > 0.999 and Vector3.new(0, 0, -math.sign(forward.Y)) or Vector3.new(0, 1, 0)
        local right = upGuess:Cross(forward)
        local rightMagnitude = right.Magnitude
        if rightMagnitude == 0 then
            right = Vector3.new(1, 0, 0)
        else
            right = Vector3.new(right.X / rightMagnitude, right.Y / rightMagnitude, right.Z / rightMagnitude)
        end
        local up = forward:Cross(right)
        return CFrame.fromComponents(
            position.X, position.Y, position.Z,
            right.X, up.X, forward.X,
            right.Y, up.Y, forward.Y,
            right.Z, up.Z, forward.Z
        )
    end
    if argCount == 12 then
        local x1, y1, z1, r00, r01, r02, r10, r11, r12, r20, r21, r22 = ...
        return CFrame.fromComponents(x1, y1, z1, r00, r01, r02, r10, r11, r12, r20, r21, r22)
    elseif argCount == 6 then
        local px, py, pz, lookX, lookY, lookZ = ...
        return CFrame.new(
            Vector3.new(px, py, pz),
            Vector3.new(lookX, lookY, lookZ)
        )
    elseif argCount == 4 then
        local first, second, third, fourth = ...
        if type(first) == "table" and type(second) == "table" and type(third) == "table"
            and type(fourth) == "table" then
            return CFrame.fromComponents(
                first.X, first.Y, first.Z,
                second.X, third.X, -fourth.X,
                second.Y, third.Y, -fourth.Y,
                second.Z, third.Z, -fourth.Z
            )
        end
        if type(first) == "table" and type(second) == "table" and type(third) == "number" then
            local frame = CFrame.new(first, second)
            return CFrame.fromComponents(
                frame.X, frame.Y, frame.Z,
                frame.R00 * third, frame.R01 * third, frame.R02 * third,
                frame.R10 * third, frame.R11 * third, frame.R12 * third,
                frame.R20 * third, frame.R21 * third, frame.R22 * third
            )
        end
    end
    local x, y, z = ...
    return CFrame.fromComponents(x, y, z, 1, 0, 0, 0, 1, 0, 0, 0, 1)
end
function CFrame.Angles(rx, ry, rz)
    rx, ry, rz = rx or 0, ry or 0, rz or 0
    local cx, sx = math.cos(rx), math.sin(rx)
    local cy, sy = math.cos(ry), math.sin(ry)
    local cz, sz = math.cos(rz), math.sin(rz)
    return CFrame.fromComponents(
        0, 0, 0,
        cy * cz + sy * sx * sz, -cy * sz + sy * sx * cz, sy * cx,
        cx * sz, cx * cz, -sx,
        -sy * cz + cy * sx * sz, sy * sz + cy * sx * cz, cy * cx
    )
end
function CFrame.fromAxisAngle(axis, angle)
    local length = math.sqrt(axis.X * axis.X + axis.Y * axis.Y + axis.Z * axis.Z)
    if length == 0 then
        return CFrame.identity
    end
    local ux, uy, uz = axis.X / length, axis.Y / length, axis.Z / length
    local cosine, sine = math.cos(angle), math.sin(angle)
    local t = 1 - cosine
    return CFrame.fromComponents(
        0, 0, 0,
        t * ux * ux + cosine,      t * ux * uy - sine * uz,  t * ux * uz + sine * uy,
        t * ux * uy + sine * uz,   t * uy * uy + cosine,     t * uy * uz - sine * ux,
        t * ux * uz - sine * uy,   t * uy * uz + sine * ux,  t * uz * uz + cosine
    )
end
function CFrame.fromOrientation(rx, ry, rz)
    return CFrame.Angles(rx, ry, rz)
end
function CFrame.fromEulerAnglesYXZ(rx, ry, rz)
    return CFrame.Angles(rx, ry, rz)
end
function CFrame.fromEulerAnglesXYZ(rx, ry, rz)
    return CFrame.Angles(0, 0, rz) * CFrame.Angles(0, ry, 0) * CFrame.Angles(rx, 0, 0)
end
function CFrame.fromMatrix(position, right, up, back)
    local backVector = back
    if backVector == nil and right ~= nil and up ~= nil then
        backVector = right:Cross(up)
    end
    if backVector == nil then
        backVector = Vector3.new(0, 0, -1)
    end
    return CFrame.fromComponents(
        position.X, position.Y, position.Z,
        right.X, up.X, backVector.X,
        right.Y, up.Y, backVector.Y,
        right.Z, up.Z, backVector.Z
    )
end
function CFrame.lookAt(position, target)
    return CFrame.new(position, target)
end
function CFrame.lookAlong(position, direction)
    local magnitude = direction and direction.Magnitude or 0
    if magnitude == 0 then
        return CFrame.new(position)
    end
    local forward = Vector3.new(-direction.X / magnitude, -direction.Y / magnitude, -direction.Z / magnitude)
    local upGuess = math.abs(forward.Y) > 0.999 and Vector3.new(0, 0, -math.sign(forward.Y)) or Vector3.new(0, 1, 0)
    local right = upGuess:Cross(forward)
    local rightMagnitude = right.Magnitude
    if rightMagnitude == 0 then
        right = Vector3.new(1, 0, 0)
    else
        right = Vector3.new(right.X / rightMagnitude, right.Y / rightMagnitude, right.Z / rightMagnitude)
    end
    local up = forward:Cross(right)
    return CFrame.fromComponents(
        position.X, position.Y, position.Z,
        right.X, up.X, forward.X,
        right.Y, up.Y, forward.Y,
        right.Z, up.Z, forward.Z
    )
end
CFrame.identity = CFrame.fromComponents(0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1)
local CFrameComponentNames = {
    "X", "Y", "Z", "R00", "R01", "R02", "R10", "R11", "R12", "R20", "R21", "R22",
}
local function CFrameComponentsArray(Self)
    local Values = {}
    for Index = 1, 12 do
        Values[Index] = Self[CFrameComponentNames[Index]] or 0
    end
    return Values
end
function CFrameMethods:GetComponents()
    return self.X, self.Y, self.Z,
        self.R00, self.R01, self.R02,
        self.R10, self.R11, self.R12,
        self.R20, self.R21, self.R22
end
function CFrameMethods:ToEulerAnglesXYZ()
    local sy = math.max(-1, math.min(1, -self.R20))
    local ry = math.asin(sy)
    local cy = math.sqrt(1 - sy * sy)
    if cy > 1e-6 then
        return Atan2(self.R21, self.R22), ry, Atan2(self.R10, self.R00)
    end
    return 0, ry, Atan2(-self.R01, self.R11)
end
function CFrameMethods:ToEulerAnglesYXZ()
    local sx = math.max(-1, math.min(1, -self.R12))
    local rx = math.asin(sx)
    local cx = math.sqrt(1 - sx * sx)
    if cx > 1e-6 then
        return rx, Atan2(self.R02, self.R22), Atan2(self.R10, self.R11)
    end
    return rx, Atan2(-self.R20, self.R00), 0
end
function CFrameMethods:ToOrientation()
    return self:ToEulerAnglesYXZ()
end
function CFrameMethods:PointToWorldSpace(point)
    return Vector3.new(
        self.R00 * point.X + self.R01 * point.Y + self.R02 * point.Z + self.X,
        self.R10 * point.X + self.R11 * point.Y + self.R12 * point.Z + self.Y,
        self.R20 * point.X + self.R21 * point.Y + self.R22 * point.Z + self.Z
    )
end
function CFrameMethods:VectorToWorldSpace(vector)
    return Vector3.new(
        self.R00 * vector.X + self.R01 * vector.Y + self.R02 * vector.Z,
        self.R10 * vector.X + self.R11 * vector.Y + self.R12 * vector.Z,
        self.R20 * vector.X + self.R21 * vector.Y + self.R22 * vector.Z
    )
end
function CFrameMethods:PointToObjectSpace(point)
    local dx, dy, dz = point.X - self.X, point.Y - self.Y, point.Z - self.Z
    return Vector3.new(
        self.R00 * dx + self.R10 * dy + self.R20 * dz,
        self.R01 * dx + self.R11 * dy + self.R21 * dz,
        self.R02 * dx + self.R12 * dy + self.R22 * dz
    )
end
function CFrameMethods:ToObjectSpace(target)
    if type(target) == "table" and rawget(target, "_Type") == "CFrame" then
        local dx = target.X - self.X
        local dy = target.Y - self.Y
        local dz = target.Z - self.Z
        local LocalPosition = {
            self.R00 * dx + self.R10 * dy + self.R20 * dz,
            self.R01 * dx + self.R11 * dy + self.R21 * dz,
            self.R02 * dx + self.R12 * dy + self.R22 * dz,
        }
        local LocalRotation = {
            self.R00 * target.R00 + self.R10 * target.R01 + self.R20 * target.R02,
            self.R01 * target.R00 + self.R11 * target.R01 + self.R21 * target.R02,
            self.R02 * target.R00 + self.R12 * target.R01 + self.R22 * target.R02,
            self.R00 * target.R10 + self.R10 * target.R11 + self.R20 * target.R12,
            self.R01 * target.R10 + self.R11 * target.R11 + self.R21 * target.R12,
            self.R02 * target.R10 + self.R12 * target.R11 + self.R22 * target.R12,
            self.R00 * target.R20 + self.R10 * target.R21 + self.R20 * target.R22,
            self.R01 * target.R20 + self.R11 * target.R21 + self.R21 * target.R22,
            self.R02 * target.R20 + self.R12 * target.R21 + self.R22 * target.R22,
        }
        return CFrame.fromComponents(
            LocalPosition[1], LocalPosition[2], LocalPosition[3],
            LocalRotation[1], LocalRotation[2], LocalRotation[3],
            LocalRotation[4], LocalRotation[5], LocalRotation[6],
            LocalRotation[7], LocalRotation[8], LocalRotation[9]
        )
    end
    return self:PointToObjectSpace(target)
end
function CFrameMethods:Inverse()
    return CFrame.fromComponents(
        -(self.R00 * self.X + self.R10 * self.Y + self.R20 * self.Z),
        -(self.R01 * self.X + self.R11 * self.Y + self.R21 * self.Z),
        -(self.R02 * self.X + self.R12 * self.Y + self.R22 * self.Z),
        self.R00, self.R10, self.R20,
        self.R01, self.R11, self.R21,
        self.R02, self.R12, self.R22
    )
end
function CFrameMethods:Lerp(goal, alpha)
    local position = Vector3.new(
        self.X + (goal.X - self.X) * alpha,
        self.Y + (goal.Y - self.Y) * alpha,
        self.Z + (goal.Z - self.Z) * alpha
    )
    return CFrame.fromComponents(
        position.X, position.Y, position.Z,
        goal.R00, goal.R01, goal.R02, goal.R10, goal.R11, goal.R12, goal.R20, goal.R21, goal.R22
    )
end
CFrameMT.__index = function(self, key)
    if key == "Position" then
        return Vector3.new(self.X, self.Y, self.Z)
    elseif key == "Rotation" then
        return CFrame.fromComponents(0, 0, 0,
            self.R00, self.R01, self.R02, self.R10, self.R11, self.R12, self.R20, self.R21, self.R22)
    elseif key == "RightVector" or key == "XVector" then
        return Vector3.new(self.R00, self.R10, self.R20)
    elseif key == "UpVector" or key == "YVector" then
        return Vector3.new(self.R01, self.R11, self.R21)
    elseif key == "LookVector" then
        return Vector3.new(-self.R02, -self.R12, -self.R22)
    elseif key == "ZVector" then
        return Vector3.new(self.R02, self.R12, self.R22)
    elseif key == "components" then
        return CFrameComponentsArray(self)
    end
    local method = CFrameMethods[key]
    if method ~= nil then
        return method
    end
    return nil
end
function Vector2Methods:Abs()
    return Vector2.new(math.abs(self.X), math.abs(self.Y))
end
function Vector2Methods:Floor()
    return Vector2.new(math.floor(self.X), math.floor(self.Y))
end
function Vector2Methods:Ceil()
    return Vector2.new(math.ceil(self.X), math.ceil(self.Y))
end
function Vector2Methods:Sign()
    local function componentSign(component)
        if component > 0 then return 1 elseif component < 0 then return -1 end
        return 0
    end
    return Vector2.new(componentSign(self.X), componentSign(self.Y))
end
function Vector2Methods:Angle(other)
    local selfLength = math.sqrt(self.X * self.X + self.Y * self.Y)
    local otherLength = math.sqrt(other.X * other.X + other.Y * other.Y)
    if selfLength == 0 or otherLength == 0 then
        return 0
    end
    local cosine = (self.X * other.X + self.Y * other.Y) / (selfLength * otherLength)
    cosine = math.max(-1, math.min(1, cosine))
    local cross = self.X * other.Y - self.Y * other.X
    local angle = math.acos(cosine)
    if cross < 0 then angle = -angle end
    return ToFloat32(angle)
end
function Vector2.fromScale(scaleVector)
    return Vector2.new(scaleVector.X * 1024 - 0.5, scaleVector.Y * 1024 - 0.5)
end
function Vector2.fromOffset(offsetVector)
    return Vector2.new(offsetVector.X, offsetVector.Y)
end
function Vector3Methods:Sign()
    local function componentSign(component)
        if component > 0 then return 1 elseif component < 0 then return -1 end
        return 0
    end
    return Vector3.new(componentSign(self.X), componentSign(self.Y), componentSign(self.Z))
end
Vector3.FromAxis = function(axis)
    local axisName = axis and (axis.Name or axis)
    if axisName == "X" then return Vector3.xAxis end
    if axisName == "Y" then return Vector3.yAxis end
    if axisName == "Z" then return Vector3.zAxis end
    return Vector3.zero
end
Vector3.fromAxis = Vector3.FromAxis
Vector3.FromNormalId = function(normalId)
    return Vector3.fromNormalId(normalId)
end
function CFrameMethods:ToAxisAngle()
    local cosine = (self.R00 + self.R11 + self.R22 - 1) / 2
    cosine = math.max(-1, math.min(1, cosine))
    local angle = math.acos(cosine)
    local sine = math.sqrt(math.max(0, 1 - cosine * cosine))
    if sine < 1e-6 then
        return Vector3.new(0, 0, 1), ToFloat32(angle)
    end
    return Vector3.new(
        (self.R21 - self.R12) / (2 * sine),
        (self.R20 - self.R02) / (2 * sine),
        (self.R01 - self.R10) / (2 * sine)
    ), ToFloat32(angle)
end
function CFrameMethods:FuzzyEq(other, epsilon)
    local tolerance = epsilon or 1e-5
    local positionClose = math.abs(self.X - other.X) <= tolerance
        and math.abs(self.Y - other.Y) <= tolerance
        and math.abs(self.Z - other.Z) <= tolerance
    local rotationClose = math.abs(self.R00 - other.R00) <= tolerance
        and math.abs(self.R11 - other.R11) <= tolerance
        and math.abs(self.R22 - other.R22) <= tolerance
    return positionClose and rotationClose
end
function CFrameMethods:VectorToObjectSpace(vector)
    local shifted = self:PointToObjectSpace(Vector3.new(self.X + vector.X, self.Y + vector.Y, self.Z + vector.Z))
    local origin = self:PointToObjectSpace(Vector3.new(self.X, self.Y, self.Z))
    return Vector3.new(shifted.X - origin.X, shifted.Y - origin.Y, shifted.Z - origin.Z)
end
function CFrameMethods:ToRotation()
    return CFrame.fromComponents(0, 0, 0,
        self.R00, self.R01, self.R02, self.R10, self.R11, self.R12, self.R20, self.R21, self.R22)
end
function CFrame.fromRotationBetweenVectors(from, to)
    local axis = from:Cross(to)
    if axis.Magnitude < 1e-6 then
        return CFrame.identity
    end
    local cosine = (from.X * to.X + from.Y * to.Y + from.Z * to.Z) / (from.Magnitude * to.Magnitude)
    cosine = math.max(-1, math.min(1, cosine))
    return CFrame.fromAxisAngle(axis, math.acos(cosine))
end
CFrame.fromTwoVectors = CFrame.fromRotationBetweenVectors
function CFrameMethods:ToWorldSpace(other)
    return CFrame.fromComponents(
        self.X + other.X, self.Y + other.Y, self.Z + other.Z,
        self.R00 * other.R00 + self.R01 * other.R10 + self.R02 * other.R20,
        self.R00 * other.R01 + self.R01 * other.R11 + self.R02 * other.R21,
        self.R00 * other.R02 + self.R01 * other.R12 + self.R02 * other.R22,
        self.R10 * other.R00 + self.R11 * other.R10 + self.R12 * other.R20,
        self.R10 * other.R01 + self.R11 * other.R11 + self.R12 * other.R21,
        self.R10 * other.R02 + self.R11 * other.R12 + self.R12 * other.R22,
        self.R20 * other.R00 + self.R21 * other.R10 + self.R22 * other.R20,
        self.R20 * other.R01 + self.R21 * other.R11 + self.R22 * other.R21,
        self.R20 * other.R02 + self.R21 * other.R12 + self.R22 * other.R22
    )
end
function CFrameMethods:Orthonormalize()
    local rightX, rightY, rightZ = self.R00, self.R10, self.R20
    local upX, upY, upZ = self.R01, self.R11, self.R21
    local lookX, lookY, lookZ = self.R02, self.R12, self.R22
    local function normalise(xValue, yValue, zValue)
        local length = math.sqrt(xValue * xValue + yValue * yValue + zValue * zValue)
        if length == 0 then
            return 0, 0, 0
        end
        return xValue / length, yValue / length, zValue / length
    end
    rightX, rightY, rightZ = normalise(rightX, rightY, rightZ)
    local dotUp = upX * rightX + upY * rightY + upZ * rightZ
    upX, upY, upZ = upX - rightX * dotUp, upY - rightY * dotUp, upZ - rightZ * dotUp
    upX, upY, upZ = normalise(upX, upY, upZ)
    lookX = rightY * upZ - rightZ * upY
    lookY = rightZ * upX - rightX * upZ
    lookZ = rightX * upY - rightY * upX
    lookX, lookY, lookZ = normalise(lookX, lookY, lookZ)
    return CFrame.fromComponents(self.X, self.Y, self.Z,
        rightX, upX, lookX,
        rightY, upY, lookY,
        rightZ, upZ, lookZ)
end
function CFrame.fromOrientation(rx, ry, rz)
    return CFrame.fromEulerAnglesYXZ(rx, ry, rz)
end
function CFrame.fromEulerAngles(rx, ry, rz, rotationOrderValue)
    local orderName = "XYZ"
    if rotationOrderValue ~= nil then
        orderName = tostring(rotationOrderValue.Name or rotationOrderValue)
    end
    if orderName == "YXZ" then
        return CFrame.fromEulerAnglesYXZ(rx, ry, rz)
    elseif orderName == "ZYX" then
        return CFrame.fromEulerAnglesZYX(rx, ry, rz)
    elseif orderName == "XZY" then
        return CFrame.fromEulerAnglesXYZ(rx, rz, ry)
    elseif orderName == "YZX" then
        return CFrame.fromEulerAnglesXYZ(rz, rx, ry)
    elseif orderName == "ZXY" then
        return CFrame.fromEulerAnglesXYZ(ry, rz, rx)
    end
    return CFrame.fromEulerAnglesXYZ(rx, ry, rz)
end
function CFrame.fromAngle(axis, angle)
    return CFrame.fromAxisAngle(axis, angle)
end
function CFrame.fromEulerAnglesZYX(rx, ry, rz)
    return CFrame.fromEulerAnglesXYZ(rx, ry, rz)
end
Fidelity.InstanceApis = {}
function Fidelity.ApplyInstanceApis(target, className, ctx)
    if Fidelity.InstanceApis == nil or target == nil then
        return false
    end
    local applied = false
    local context = ctx or {}
    local chain = { className }
    local ancestors = Fidelity.ClassChain[className]
    if ancestors ~= nil then
        for _, parentName in ipairs(ancestors) do
            chain[#chain + 1] = parentName
        end
    end
    for _, lookupName in ipairs(chain) do
        local builder = Fidelity.InstanceApis[lookupName]
        if builder ~= nil then
            local methods = builder(context)
            if methods ~= nil then
                local methodTable = rawget(target, "__V1_Methods")
                for methodName, methodValue in next, methods do
                    local alreadyThere = rawget(target, methodName) ~= nil
                        or (methodTable ~= nil and methodTable[methodName] ~= nil)
                    if not alreadyThere then
                        local HasRule = methodValue ~= nil
                            and type(methodValue) ~= "function"
                            and Fidelity.PropertyRules ~= nil
                            and Fidelity.PropertyRules[lookupName .. "." .. methodName] ~= nil
                        if HasRule then
                            local ok = pcall(function()
                                target[methodName] = methodValue
                            end)
                            if not ok then
                                rawset(target, methodName, methodValue)
                            end
                        else
                            rawset(target, methodName, methodValue)
                        end
                        if methodTable ~= nil then
                            methodTable[methodName] = methodValue
                        end
                    end
                    applied = true
                end
            end
        end
    end
    return applied
end
Fidelity.Int16Ops = {}
do
    local function condition(value)
        local numberValue = tonumber(value) or 0
        local wholeValue = math.floor(math.abs(numberValue))
        if numberValue < 0 then
            wholeValue = -wholeValue
        end
        wholeValue = wholeValue % 65536
        if wholeValue >= 32768 then
            wholeValue = wholeValue - 65536
        end
        return wholeValue
    end
    local function componentValue(value, name)
        if type(value) == "number" then
            return value
        end
        if type(value) == "table" then
            local field = rawget(value, name)
            if field ~= nil then
                return field
            end
            local fallback = rawget(value, "X")
            return fallback
        end
        return 0
    end
    local function combine(left, right, op)
        local result = { _Type = left._Type or "Vector3int16" }
        result.X = condition(op(componentValue(left, "X"), componentValue(right, "X")))
        result.Y = condition(op(componentValue(left, "Y"), componentValue(right, "Y")))
        if result._Type == "Vector3int16" then
            result.Z = condition(op(componentValue(left, "Z"), componentValue(right, "Z")))
        end
        return setmetatable(result, Fidelity.Int16Ops)
    end
    local ops = Fidelity.Int16Ops
    ops.__add = function(a, b) return combine(a, b, function(x, y) return x + y end) end
    ops.__sub = function(a, b) return combine(a, b, function(x, y) return x - y end) end
    ops.__mul = function(a, b) return combine(a, b, function(x, y) return x * y end) end
    ops.__div = function(a, b) return combine(a, b, function(x, y) return x / y end) end
    ops.__unm = function(a) return combine(a, 0, function(x, y) return -x end) end
    ops.__eq = function(a, b)
        return type(b) == "table"
            and rawget(a, "X") == rawget(b, "X")
            and rawget(a, "Y") == rawget(b, "Y")
            and (a.Z == nil and b.Z == nil or a.Z == b.Z)
    end
    ops.__tostring = function(a)
        if a.Z ~= nil then
            return string.format("%s, %s, %s", tostring(a.X), tostring(a.Y), tostring(a.Z))
        end
        return string.format("%s, %s", tostring(a.X), tostring(a.Y))
    end
end
Fidelity.Vector2 = Vector2
Fidelity.Vector3 = Vector3
Fidelity.CFrame = CFrame
local RAYCAST_FILTER_EXCLUDE = Fidelity.EnumValue("RaycastFilterType", "Exclude", 0)
local RaycastParams = {}
RaycastParams.new = function()
    return {
        _Type = "RaycastParams",
        FilterDescendantsInstances = {},
        FilterType = RAYCAST_FILTER_EXCLUDE,
        IgnoreWater = false,
        RespectCanCollide = false,
        CollisionGroup = "Default",
    }
end
local OverlapParams = {}
OverlapParams.new = function()
    return {
        _Type = "OverlapParams",
        FilterDescendantsInstances = {},
        FilterType = RAYCAST_FILTER_EXCLUDE,
        IgnoreWater = false,
        MaxParts = 1000,
        RespectCanCollide = false,
        CollisionGroup = "Default",
    }
end
local RectMT = {
    __eq = function(a, b)
        return a.Min.X == b.Min.X and a.Min.Y == b.Min.Y
            and a.Max.X == b.Max.X and a.Max.Y == b.Max.Y
    end,
    __tostring = function(self)
        return "(" .. tostring(self.Min) .. "), (" .. tostring(self.Max) .. ")"
    end,
}
local Rect = {}
Rect.new = function(FirstValue, SecondValue, ThirdValue, FourthValue)
    local MinPoint, MaxPoint
    if ThirdValue == nil and FourthValue == nil then
        MinPoint = FirstValue or Vector2.new(0, 0)
        MaxPoint = SecondValue or Vector2.new(0, 0)
    else
        MinPoint = Vector2.new(tonumber(FirstValue) or 0, tonumber(SecondValue) or 0)
        MaxPoint = Vector2.new(tonumber(ThirdValue) or 0, tonumber(FourthValue) or 0)
    end
    return setmetatable({
        _Type = "Rect",
        Min = MinPoint,
        Max = MaxPoint,
        Width = MaxPoint.X - MinPoint.X,
        Height = MaxPoint.Y - MinPoint.Y,
    }, RectMT)
end
Fidelity.Rect = Rect
local AxesFlagNames = { "X", "Y", "Z", "Top", "Bottom", "Left", "Right", "Back", "Front" }
local FacesFlagNames = { "Top", "Bottom", "Left", "Right", "Back", "Front" }
local AxisOnlyNames = { X = true, Y = true, Z = true }
local function FlagNameOf(Item)
    if type(Item) == "table" then
        local ItemName = rawget(Item, "Name")
        if type(ItemName) == "string" then return ItemName end
    elseif type(Item) == "string" then
        return Item
    end
    return nil
end
local function BuildFlagMask(AllowedNames, Items)
    local Mask = {}
    for _, Name in ipairs(AllowedNames) do Mask[Name] = false end
    for _, Item in ipairs(Items) do
        local Name = FlagNameOf(Item)
        if Name ~= nil and Mask[Name] ~= nil then Mask[Name] = true end
    end
    return Mask
end
local function FlagMaskToString(TypeName, Mask, AllowedNames)
    local Parts = {}
    for _, Name in ipairs(AllowedNames) do
        if Mask[Name] then
            Parts[#Parts + 1] = "Enum." .. (AxisOnlyNames[Name] and "Axis" or "NormalId") .. "." .. Name
        end
    end
    return TypeName .. ".new(" .. table.concat(Parts, ", ") .. ")"
end
local function FlagMasksEqual(LeftMask, RightMask, AllowedNames)
    for _, Name in ipairs(AllowedNames) do
        if LeftMask[Name] ~= RightMask[Name] then return false end
    end
    return true
end
local AxesNormalIdForFlag = {
    LeftRight = "Right", TopBottom = "Top", FrontBack = "Back",
}
local AxesFlagForNormalId = {
    Right = "LeftRight", Left = "LeftRight",
    Top = "TopBottom", Bottom = "TopBottom",
    Back = "FrontBack", Front = "FrontBack",
    CurlTop = "TopBottom", CurlBottom = "TopBottom",
}
local AxesFlagForAxis = { X = "X", Y = "Y", Z = "Z" }
local AxesMT = {
    __index = function(self, KeyName)
        if KeyName == "NormalId" then
            local SetCount, TheFlag = 0, nil
            for FlagName in next, AxesNormalIdForFlag do
                if rawget(self, FlagName) then
                    SetCount += 1
                    TheFlag = FlagName
                end
            end
            if SetCount == 1 then
                return Fidelity.EnumValue("NormalId", AxesNormalIdForFlag[TheFlag], 0)
            end
            return Fidelity.EnumValue("NormalId", "None", 0)
        end
        return nil
    end,
    __eq = function(a, b) return FlagMasksEqual(a, b, AxesFlagNames) end,
    __tostring = function(self) return FlagMaskToString("Axes", self, AxesFlagNames) end,
}
local FacesMT = {
    __eq = function(a, b) return FlagMasksEqual(a, b, FacesFlagNames) end,
    __tostring = function(self) return FlagMaskToString("Faces", self, FacesFlagNames) end,
}
local Axes = {}
Axes.new = function(...)
    local Mask = BuildFlagMask(AxesFlagNames, { ... })
    for _, Item in ipairs({ ... }) do
        local ItemName = FlagNameOf(Item)
        local PairFlag = ItemName ~= nil and AxesFlagForNormalId[ItemName] or nil
        if PairFlag ~= nil then
            Mask[PairFlag] = true
            if PairFlag == "LeftRight" then Mask.X = true
            elseif PairFlag == "TopBottom" then Mask.Y = true
            else Mask.Z = true end
        elseif ItemName ~= nil and AxesFlagForAxis[ItemName] ~= nil then
            Mask[ItemName] = true
            if ItemName == "X" then Mask.LeftRight = true
            elseif ItemName == "Y" then Mask.TopBottom = true
            else Mask.FrontBack = true end
        end
    end
    Mask._Type = "Axes"
    return table.freeze(setmetatable(Mask, AxesMT))
end
Fidelity.Axes = Axes
local Faces = {}
Faces.new = function(...)
    local Mask = BuildFlagMask(FacesFlagNames, { ... })
    Mask._Type = "Faces"
    return table.freeze(setmetatable(Mask, FacesMT))
end
Fidelity.Faces = Faces
local function CivilFromDays(DaysSinceEpoch)
    local Z = DaysSinceEpoch + 719468
    local Era = math.floor((Z >= 0 and Z or Z - 146096) / 146097)
    local DayOfEra = Z - Era * 146097
    local YearOfEra = math.floor(
        (DayOfEra - math.floor(DayOfEra / 1460) + math.floor(DayOfEra / 36524)
            - math.floor(DayOfEra / 146096)) / 365)
    local Year = YearOfEra + Era * 400
    local DayOfYear = DayOfEra - (365 * YearOfEra + math.floor(YearOfEra / 4)
        - math.floor(YearOfEra / 100))
    local ShiftedMonth = math.floor((5 * DayOfYear + 2) / 153)
    local Day = DayOfYear - math.floor((153 * ShiftedMonth + 2) / 5) + 1
    local Month = ShiftedMonth + (ShiftedMonth < 10 and 3 or -9)
    return Year + (Month <= 2 and 1 or 0), Month, Day
end
local function DaysFromCivil(Year, Month, Day)
    Year = Year - (Month <= 2 and 1 or 0)
    local Era = math.floor((Year >= 0 and Year or Year - 399) / 400)
    local YearOfEra = Year - Era * 400
    local DayOfYear = math.floor((153 * (Month + (Month > 2 and -3 or 9)) + 2) / 5) + Day - 1
    local DayOfEra = YearOfEra * 365 + math.floor(YearOfEra / 4)
        - math.floor(YearOfEra / 100) + DayOfYear
    return Era * 146097 + DayOfEra - 719468
end
local DateTimeMethods = {}
local DateTimeMT = { __index = DateTimeMethods }
DateTimeMT.__tostring = function(self)
    return string.format("DateTime(%d)", self.UnixTimestampMillis)
end
local DateTime = {}
DateTime._Type = "DateTime"
local function MakeDateTime(UnixTimestampMillis)
    local Millis = math.floor(UnixTimestampMillis or 0)
    local Seconds = math.floor(Millis / 1000)
    local Days = math.floor(Seconds / 86400)
    local Remainder = Seconds - Days * 86400
    local Year, Month, Day = CivilFromDays(Days)
    return setmetatable({
        _Type = "DateTime",
        UnixTimestamp = Seconds,
        UnixTimestampMillis = Millis,
        Year = Year, Month = Month, Day = Day,
        Hour = math.floor(Remainder / 3600),
        Minute = math.floor((Remainder % 3600) / 60),
        Second = Remainder % 60,
        Millisecond = Millis - Seconds * 1000,
    }, DateTimeMT)
end
DateTime.now = function()
    local clock = Fidelity.Clock
    if clock ~= nil and type(clock.Tick) == "function" then
        local ok, tickValue = pcall(clock.Tick)
        if ok and type(tickValue) == "number" then
            return MakeDateTime(math.floor(tickValue * 1000 + 0.5))
        end
    end
    return MakeDateTime(math.floor((os.time and os.time() or 0) * 1000))
end
DateTime.fromUnixTimestamp = function(Seconds)
    return MakeDateTime(math.floor((tonumber(Seconds) or 0) * 1000))
end
DateTime.fromUnixTimestampMillis = function(Millis)
    return MakeDateTime(tonumber(Millis) or 0)
end
DateTime.fromUniversalTime = function(Year, Month, Day, Hour, Minute, Second, Millisecond)
    local Days = DaysFromCivil(tonumber(Year) or 1970, tonumber(Month) or 1, tonumber(Day) or 1)
    return MakeDateTime((((Days * 86400
        + (tonumber(Hour) or 0) * 3600
        + (tonumber(Minute) or 0) * 60
        + (tonumber(Second) or 0)) * 1000) + (tonumber(Millisecond) or 0)))
end
DateTime.fromLocalTime = DateTime.fromUniversalTime
DateTimeMethods.ToUniversalTime = function(self)
    return {
        Year = self.Year, Month = self.Month, Day = self.Day,
        Hour = self.Hour, Minute = self.Minute, Second = self.Second,
        Millisecond = self.Millisecond,
    }
end
DateTimeMethods.ToLocalTime = DateTimeMethods.ToUniversalTime
DateTimeMethods.ToIsoDate = function(self)
    return string.format("%04d-%02d-%02dT%02d:%02d:%02d.%03dZ",
        self.Year, self.Month, self.Day, self.Hour, self.Minute, self.Second,
        math.floor((self.Millisecond or 0) + 0.5))
end
DateTimeMethods.FormatUniversalTime = function(self, FormatString, Locale)
    return DateTimeMethods.FormatLocalTime(self, FormatString, Locale)
end
DateTimeMethods.FormatLocalTime = function(self, FormatString, Locale)
    local Text = type(FormatString) == "string" and FormatString or "YYYY-MM-DD HH:mm:ss"
    Text = Text:gsub("YYYY", string.format("%04d", self.Year))
    Text = Text:gsub("MM", string.format("%02d", self.Month))
    Text = Text:gsub("DD", string.format("%02d", self.Day))
    Text = Text:gsub("HH", string.format("%02d", self.Hour))
    Text = Text:gsub("mm", string.format("%02d", self.Minute))
    Text = Text:gsub("ss", string.format("%02d", self.Second))
    return Text
end
local function ParseIsoDate(Text)
    if type(Text) ~= "string" then return nil end
    local Year, Month, Day = Text:match("^(%d%d%d%d)-(%d%d)-(%d%d)")
    if not Year then return nil end
    local Hour, Minute, Second = Text:match("[T ](%d%d):(%d%d):(%d%d)")
    return DateTime.fromUniversalTime(tonumber(Year), tonumber(Month), tonumber(Day),
        tonumber(Hour) or 0, tonumber(Minute) or 0, tonumber(Second) or 0)
end
DateTime.fromIsoDate = function(Text)
    return ParseIsoDate(Text) or DateTime.fromUnixTimestamp(0)
end
Fidelity.DateTime = DateTime
local ContentMT = {}
ContentMT.__tostring = function(self) return tostring(self.Uri) end
ContentMT.__eq = function(a, b) return a.Uri == b.Uri end
ContentMT.__index = ContentMT
local Content = {}
local function MakeContent(Uri)
    return setmetatable({ _Type = "Content", Uri = tostring(Uri or "") }, ContentMT)
end
Content.fromUri = function(Uri) return MakeContent(Uri) end
Content.fromAssetId = function(AssetId)
    return MakeContent("rbxassetid://" .. tostring(AssetId or ""))
end
Content.fromImageAssetId = function(AssetId)
    return MakeContent("rbxassetid://" .. tostring(AssetId or ""))
end
Content.fromAudioAssetId = function(AssetId)
    return MakeContent("rbxassetid://" .. tostring(AssetId or ""))
end
Content.fromObject = function(InstanceObject)
    local AssetId = type(InstanceObject) == "table" and rawget(InstanceObject, "Texture")
    return MakeContent(type(AssetId) == "string" and AssetId or "")
end
Fidelity.Content = Content
local UserMT = {}
UserMT.__tostring = function(self) return tostring(self.Name) end
UserMT.__index = UserMT
local User = {}
User.new = function(UserId, Name, DisplayName)
    return setmetatable({
        _Type = "User",
        UserId = math.floor(tonumber(UserId) or 0),
        Name = tostring(Name or ""),
        DisplayName = tostring(DisplayName or Name or ""),
    }, UserMT)
end
Fidelity.User = User
local SecretMT = {}
SecretMT.__tostring = function() return "Secret" end
SecretMT.__index = function() return nil end
local Secret = {}
Secret.new = function(Key)
    return setmetatable({ _Type = "Secret" }, SecretMT)
end
Fidelity.Secret = Secret
local CatalogSearchParamsMethods = {}
local CatalogSearchParamsMT = { __index = CatalogSearchParamsMethods }
local CatalogSearchParams = {}
CatalogSearchParams.new = function()
    return setmetatable({
        _Type = "CatalogSearchParams",
        AssetTypes = {}, BundleTypes = {}, Categories = {},
        CollectibleItemSortAggregation = 0, Currency = 0,
        ExcludeCreatorAssetIds = {}, ExcludeCreatorTargetIds = {},
        ItemSortAggregation = 0, MaxPrice = math.huge, MinPrice = 0,
        SearchKeyword = "", SortAggregation = 0, SortType = 0,
        VerifiedCreatorAssetIds = {}, VerifiedCreatorTargetIds = {},
        VerifiedCreatorsOnly = false,
    }, CatalogSearchParamsMT)
end
CatalogSearchParamsMethods.AddAssetType = function(self, AssetType)
    self.AssetTypes[#self.AssetTypes + 1] = AssetType
end
CatalogSearchParamsMethods.AddBundleType = function(self, BundleType)
    self.BundleTypes[#self.BundleTypes + 1] = BundleType
end
CatalogSearchParamsMethods.AddCategory = function(self, Category)
    self.Categories[#self.Categories + 1] = Category
end
CatalogSearchParamsMethods.RemoveAssetType = function(self, AssetType)
    for Index, Existing in ipairs(self.AssetTypes) do
        if Existing == AssetType then table.remove(self.AssetTypes, Index) break end
    end
end
CatalogSearchParamsMethods.RemoveBundleType = function(self, BundleType)
    for Index, Existing in ipairs(self.BundleTypes) do
        if Existing == BundleType then table.remove(self.BundleTypes, Index) break end
    end
end
CatalogSearchParamsMethods.RemoveCategory = function(self, Category)
    for Index, Existing in ipairs(self.Categories) do
        if Existing == Category then table.remove(self.Categories, Index) break end
    end
end
Fidelity.CatalogSearchParams = CatalogSearchParams
local Crypt = {}
local Base64Alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local Base64IndexOf = {}
for Index = 1, 64 do
    Base64IndexOf[Base64Alphabet:sub(Index, Index)] = Index - 1
end
Crypt.base64_encode = function(Text)
    Text = tostring(Text or "")
    local Out = {}
    for Position = 1, #Text, 3 do
        local Byte1 = Text:byte(Position) or 0
        local Byte2 = Text:byte(Position + 1)
        local Byte3 = Text:byte(Position + 2)
        local Triple = Byte1 * 65536 + (Byte2 or 0) * 256 + (Byte3 or 0)
        Out[#Out + 1] = Base64Alphabet:sub(math.floor(Triple / 262144) % 64 + 1, math.floor(Triple / 262144) % 64 + 1)
        Out[#Out + 1] = Base64Alphabet:sub(math.floor(Triple / 4096) % 64 + 1, math.floor(Triple / 4096) % 64 + 1)
        Out[#Out + 1] = Base64Alphabet:sub(math.floor(Triple / 64) % 64 + 1, math.floor(Triple / 64) % 64 + 1)
        Out[#Out + 1] = Base64Alphabet:sub(Triple % 64 + 1, Triple % 64 + 1)
    end
    local Padding = (3 - (#Text % 3)) % 3
    local Encoded = table.concat(Out)
    if Padding > 0 then
        Encoded = Encoded:sub(1, #Encoded - Padding) .. string.rep("=", Padding)
    end
    return Encoded
end
Crypt.tobase64 = Crypt.base64_encode
Crypt.base64_decode = function(Text)
    Text = tostring(Text or ""):gsub("[^%w%+%/=]", "")
    local Out = {}
    for Position = 1, #Text, 4 do
        local Second = Text:sub(Position + 1, Position + 1)
        local ThirdText = Text:sub(Position + 2, Position + 2)
        local FourthText = Text:sub(Position + 3, Position + 3)
        local Quad = (Base64IndexOf[Text:sub(Position, Position)] or 0) * 262144
            + (Base64IndexOf[Second] or 0) * 4096
            + (ThirdText ~= "=" and (Base64IndexOf[ThirdText] or 0) or 0) * 64
            + (FourthText ~= "=" and (Base64IndexOf[FourthText] or 0) or 0)
        Out[#Out + 1] = string.char(math.floor(Quad / 65536) % 256)
        if ThirdText ~= "=" and ThirdText ~= "" then
            Out[#Out + 1] = string.char(math.floor(Quad / 256) % 256)
        end
        if FourthText ~= "=" and FourthText ~= "" then
            Out[#Out + 1] = string.char(Quad % 256)
        end
    end
    return table.concat(Out)
end
Crypt.frombase64 = Crypt.base64_decode
Crypt.hexlify = function(Text)
    return (tostring(Text or ""):gsub(".", function(Character)
        return string.format("%02x", Character:byte())
    end))
end
Crypt.unhexlify = function(HexText)
    return (tostring(HexText or ""):gsub("%x%x", function(Pair)
        return string.char(tonumber(Pair, 16))
    end))
end
Crypt.randomkey = function()
    local Bytes = {}
    for _ = 1, 32 do Bytes[#Bytes + 1] = string.char(math.random(0, 255)) end
    return table.concat(Bytes)
end
local Sha256Constants = {
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
}
local Modulus32 = 4294967296
local function Sha256(Message)
    local State = {
        0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
        0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19,
    }
    local BitLength = #Message * 8
    Message = Message .. "\128"
    while #Message % 64 ~= 56 do Message = Message .. "\0" end
    Message = Message .. string.char(0, 0, 0, 0,
        bit32.extract(BitLength, 24, 8), bit32.extract(BitLength, 16, 8),
        bit32.extract(BitLength, 8, 8), bit32.extract(BitLength, 0, 8))
    for Block = 1, #Message, 64 do
        local W = {}
        for Index = 0, 15 do
            W[Index] = Message:byte(Block + Index * 4) * 16777216
                + Message:byte(Block + Index * 4 + 1) * 65536
                + Message:byte(Block + Index * 4 + 2) * 256
                + Message:byte(Block + Index * 4 + 3)
        end
        for Index = 16, 63 do
            local Small0 = bit32.bxor(bit32.rrotate(W[Index - 15], 7),
                bit32.rrotate(W[Index - 15], 18), bit32.rshift(W[Index - 15], 3))
            local Small1 = bit32.bxor(bit32.rrotate(W[Index - 2], 17),
                bit32.rrotate(W[Index - 2], 19), bit32.rshift(W[Index - 2], 10))
            W[Index] = (W[Index - 16] + Small0 + W[Index - 7] + Small1) % Modulus32
        end
        local A, B, C, D, E, F, G, H =
            State[1], State[2], State[3], State[4], State[5], State[6], State[7], State[8]
        for Index = 0, 63 do
            local BigSigma1 = bit32.bxor(bit32.rrotate(E, 6), bit32.rrotate(E, 11), bit32.rrotate(E, 25))
            local Choose = bit32.bxor(bit32.band(E, F), bit32.band(bit32.bnot(E), G))
            local Temp1 = (H + BigSigma1 + Choose + Sha256Constants[Index + 1] + W[Index]) % Modulus32
            local BigSigma0 = bit32.bxor(bit32.rrotate(A, 2), bit32.rrotate(A, 13), bit32.rrotate(A, 22))
            local Majority = bit32.bxor(bit32.band(A, B), bit32.band(A, C), bit32.band(B, C))
            local Temp2 = (BigSigma0 + Majority) % Modulus32
            H, G, F, E = G, F, E, (D + Temp1) % Modulus32
            D, C, B, A = C, B, A, (Temp1 + Temp2) % Modulus32
        end
        State[1] = (State[1] + A) % Modulus32
        State[2] = (State[2] + B) % Modulus32
        State[3] = (State[3] + C) % Modulus32
        State[4] = (State[4] + D) % Modulus32
        State[5] = (State[5] + E) % Modulus32
        State[6] = (State[6] + F) % Modulus32
        State[7] = (State[7] + G) % Modulus32
        State[8] = (State[8] + H) % Modulus32
    end
    local Parts = {}
    for Index = 1, 8 do Parts[Index] = string.format("%08x", State[Index]) end
    return table.concat(Parts)
end
Fidelity.Sha256 = Sha256
Crypt.hash = function(Text, Algorithm)
    return Sha256(tostring(Text or ""))
end
Crypt.hmac = function(Text, Key, Algorithm)
    Text = tostring(Text or "")
    Key = tostring(Key or "")
    local BlockSize = 64
    if #Key > BlockSize then Key = Crypt.unhexlify(Sha256(Key)) end
    local PaddedKey = Key .. string.rep("\0", BlockSize - #Key)
    local InnerPad, OuterPad = {}, {}
    for Index = 1, BlockSize do
        local KeyByte = PaddedKey:byte(Index)
        InnerPad[Index] = string.char(bit32.bxor(KeyByte, 0x36))
        OuterPad[Index] = string.char(bit32.bxor(KeyByte, 0x5c))
    end
    local InnerDigest = Crypt.unhexlify(Sha256(table.concat(InnerPad) .. Text))
    return Sha256(table.concat(OuterPad) .. InnerDigest)
end
local function MakeKeystream(Key, Length)
    local State = 2166136261
    for Index = 1, #Key do
        State = (bit32.bxor(State, Key:byte(Index)) * 16777619) % Modulus32
    end
    if State == 0 then State = 1 end
    local Bytes = {}
    for Index = 1, Length do
        State = bit32.bxor(State, bit32.lshift(State, 13))
        State = bit32.bxor(State, bit32.rshift(State, 17))
        State = bit32.bxor(State, bit32.lshift(State, 5))
        Bytes[Index] = string.char(State % 256)
    end
    return table.concat(Bytes)
end
local function KeystreamXor(Text, Key)
    Text = tostring(Text or "")
    local Keystream = MakeKeystream(tostring(Key or ""), #Text)
    local Out = {}
    for Index = 1, #Text do
        Out[Index] = string.char(bit32.bxor(Text:byte(Index), Keystream:byte(Index)))
    end
    return table.concat(Out)
end
Crypt.encrypt = KeystreamXor
Crypt.decrypt = KeystreamXor
Crypt.derive = function(Password, Salt, KeySize, Count, Mode, Algorithm)
    Password = tostring(Password or "")
    Salt = tostring(Salt or "")
    local Bytes = math.max(1, math.floor((tonumber(KeySize) or 256) / 8))
    local Out = {}
    local Block = 1
    while #Out < Bytes do
        local IndexBytes = string.char(
            bit32.extract(Block, 24, 8), bit32.extract(Block, 16, 8),
            bit32.extract(Block, 8, 8), bit32.extract(Block, 0, 8))
        local Digest = Crypt.hmac(Salt .. IndexBytes, Password)
        for Position = 1, #Digest, 2 do
            Out[#Out + 1] = string.char(tonumber(Digest:sub(Position, Position + 1), 16))
        end
        Block = Block + 1
    end
    return table.concat(Out):sub(1, Bytes)
end
Fidelity.Crypt = Crypt
Fidelity.Base64Global = {
    encode = Crypt.base64_encode,
    decode = Crypt.base64_decode,
    base64_encode = Crypt.base64_encode,
    base64_decode = Crypt.base64_decode,
    tobase64 = Crypt.tobase64,
    frombase64 = Crypt.frombase64,
}
Fidelity.JsonGlobal = {
    encode = function(valueData) return Fidelity.JsonEncode(valueData) end,
    decode = function(textData) return Fidelity.JsonDecode(textData) end,
}
Fidelity.RaycastParams = RaycastParams
Fidelity.OverlapParams = OverlapParams
local ColorSequenceKeypoint = {}
ColorSequenceKeypoint.new = function(TimeValue, ColorValue, GreenValue, BlueValue)
    local NormalisedTime = tonumber(TimeValue) or 0
    if NormalisedTime < 0 then NormalisedTime = 0 end
    if NormalisedTime > 1 then NormalisedTime = 1 end
    if type(ColorValue) == "number" then
        ColorValue = Fidelity.Color3.new(ColorValue, GreenValue or 0, BlueValue or 0)
    elseif ColorValue == nil then
        ColorValue = Fidelity.Color3.new(0, 0, 0)
    end
    return table.freeze(setmetatable({
        _Type = "ColorSequenceKeypoint",
        Time = NormalisedTime,
        Value = ColorValue,
    }, {
        __tostring = function(self)
            return "{Time = " .. tostring(self.Time) .. "}"
        end,
    }))
end
Fidelity.ColorSequenceKeypoint = ColorSequenceKeypoint
local RotationCurveKeypoint = {}
RotationCurveKeypoint.new = function(TimeValue, ValueValue, LeftTangentValue, RightTangentValue, InterpolationValue)
    local NormalisedTime = tonumber(TimeValue) or 0
    local KeyValue = ValueValue
    if type(KeyValue) ~= "table" then
        KeyValue = Fidelity.CFrame.new()
    end
    local function TangentOrZero(TangentValue)
        if type(TangentValue) == "table" then
            return TangentValue
        end
        return Fidelity.Vector3.new(0, 0, 0)
    end
    return table.freeze(setmetatable({
        _Type = "RotationCurveKeypoint",
        Time = NormalisedTime,
        Value = KeyValue,
        LeftTangent = TangentOrZero(LeftTangentValue),
        RightTangent = TangentOrZero(RightTangentValue),
        Interpolation = InterpolationValue or Fidelity.EnumValue("KeyInterpolationMode", "Linear", 0),
    }, {
        __tostring = function(self)
            return "{Time = " .. tostring(self.Time) .. "}"
        end,
    }))
end
Fidelity.RotationCurveKeypoint = RotationCurveKeypoint
local ColorSequence = {}
ColorSequence.new = function(FirstValue, SecondValue)
    local KeypointsValue = {}
    if type(FirstValue) == "table" and FirstValue[1] ~= nil
        and type(FirstValue[1]) == "table"
        and rawget(FirstValue[1], "_Type") == "ColorSequenceKeypoint" then
        for IndexValue, KeypointValue in ipairs(FirstValue) do
            KeypointsValue[IndexValue] = KeypointValue
        end
    else
        KeypointsValue[1] = ColorSequenceKeypoint.new(0, FirstValue)
        KeypointsValue[2] = ColorSequenceKeypoint.new(1, SecondValue ~= nil and SecondValue or FirstValue)
    end
    return setmetatable({
        _Type = "ColorSequence",
        Keypoints = KeypointsValue,
    }, {
        __tostring = function() return "ColorSequence" end,
    })
end
Fidelity.ColorSequence = ColorSequence
local NumberSequenceKeypoint = {}
NumberSequenceKeypoint.new = function(TimeValue, ValueValue, EnvelopeValue)
    return setmetatable({
        _Type = "NumberSequenceKeypoint",
        Time = ToFloat32(tonumber(TimeValue) or 0),
        Value = ToFloat32(tonumber(ValueValue) or 0),
        Envelope = ToFloat32(tonumber(EnvelopeValue) or 0),
    }, {
        __tostring = function(self)
            return "{Time = " .. tostring(self.Time) .. ", Value = " .. tostring(self.Value) .. "}"
        end,
    })
end
Fidelity.NumberSequenceKeypoint = NumberSequenceKeypoint
local NumberSequence = {}
NumberSequence.new = function(FirstValue, SecondValue)
    local KeypointsValue = {}
    if type(FirstValue) == "table" and rawget(FirstValue, "_Type") == "NumberSequenceKeypoint" then
        KeypointsValue[1] = FirstValue
        if SecondValue ~= nil then
            KeypointsValue[2] = SecondValue
        end
    elseif type(FirstValue) == "table" then
        for IndexValue, KeypointValue in ipairs(FirstValue) do
            KeypointsValue[IndexValue] = KeypointValue
        end
    else
        KeypointsValue[1] = NumberSequenceKeypoint.new(0, FirstValue)
        KeypointsValue[2] = NumberSequenceKeypoint.new(1, SecondValue ~= nil and SecondValue or FirstValue)
    end
    return setmetatable({
        _Type = "NumberSequence",
        Keypoints = KeypointsValue,
    }, {
        __tostring = function() return "NumberSequence" end,
    })
end
Fidelity.NumberSequence = NumberSequence
local Path2DControlPoint = {}
Path2DControlPoint.new = function(PositionValue, InTangentValue, OutTangentValue, ThicknessValue)
    return setmetatable({
        _Type = "Path2DControlPoint",
        Position = PositionValue,
        InTangent = InTangentValue,
        OutTangent = OutTangentValue,
        Thickness = tonumber(ThicknessValue) or 1,
    }, {
        __tostring = function() return "Path2DControlPoint" end,
    })
end
Fidelity.Path2DControlPoint = Path2DControlPoint
Fidelity.InstanceKey = "__V1_INSTANCE"
Fidelity.MethodsKey = "__V1_Methods"
local NumberRangeMT = {
    __eq = function(a, b) return a.Min == b.Min and a.Max == b.Max end,
    __tostring = function(self)
        return "[" .. tostring(self.Min) .. ", " .. tostring(self.Max) .. "]"
    end,
}
local NumberRange = {}
NumberRange.new = function(FirstValue, SecondValue)
    local FirstNumber = tonumber(FirstValue)
    if FirstNumber == nil then
        return nil, "invalid argument #1 to 'NumberRange.new' (number expected)"
    end
    local SecondNumber = tonumber(SecondValue)
    if SecondNumber == nil then SecondNumber = FirstNumber end
    local MinValue, MaxValue = FirstNumber, SecondNumber
    if MinValue > MaxValue then MinValue, MaxValue = MaxValue, MinValue end
    return table.freeze(setmetatable({
        _Type = "NumberRange", Min = MinValue, Max = MaxValue,
    }, NumberRangeMT))
end
Fidelity.NumberRange = NumberRange
local RayMT = {
    __eq = function(a, b)
        return a.Origin.X == b.Origin.X and a.Origin.Y == b.Origin.Y
            and a.Origin.Z == b.Origin.Z and a.Direction.X == b.Direction.X
            and a.Direction.Y == b.Direction.Y and a.Direction.Z == b.Direction.Z
    end,
    __tostring = function(self)
        return "[Origin] " .. tostring(self.Origin) .. " [Direction] " .. tostring(self.Direction)
    end,
}
local Ray = {}
Ray.new = function(OriginValue, DirectionValue)
    return setmetatable({
        _Type = "Ray",
        Origin = OriginValue or Vector3.new(0, 0, 0),
        Direction = DirectionValue or Vector3.new(0, 0, 0),
        Unit = function(self)
            local LengthValue = math.sqrt(
                self.Direction.X ^ 2 + self.Direction.Y ^ 2 + self.Direction.Z ^ 2)
            if LengthValue == 0 then
                return Ray.new(self.Origin, Vector3.new(0, 0, 0))
            end
            return Ray.new(self.Origin, self.Direction / LengthValue)
        end,
    }, RayMT)
end
Ray.ClosestPoint = function(self, PointValue)
    local direction = self.Direction
    local origin = self.Origin
    local px, py, pz = PointValue.X - origin.X, PointValue.Y - origin.Y, PointValue.Z - origin.Z
    local squaredLength = direction.X * direction.X + direction.Y * direction.Y
        + direction.Z * direction.Z
    if squaredLength == 0 then
        return Vector3.new(origin.X, origin.Y, origin.Z)
    end
    local dotValue = px * direction.X + py * direction.Y + pz * direction.Z
    local parameter = dotValue / squaredLength
    if parameter < 0 then parameter = 0 end
    return Vector3.new(origin.X + direction.X * parameter,
        origin.Y + direction.Y * parameter, origin.Z + direction.Z * parameter)
end
RayMT.__index = function(self, KeyName)
    return Ray[KeyName]
end
Fidelity.Raycast = Ray
local PhysicalPropertiesMT = {
    __eq = function(a, b)
        return a.Density == b.Density and a.Friction == b.Friction
            and a.Elasticity == b.Elasticity
            and a.FrictionWeight == b.FrictionWeight
            and a.ElasticityWeight == b.ElasticityWeight
    end,
    __tostring = function(self)
        return ("PhysicalProperties(Density=%s, Friction=%s, Elasticity=%s, "
            .. "FrictionWeight=%s, ElasticityWeight=%s)"):format(
            tostring(self.Density), tostring(self.Friction),
            tostring(self.Elasticity), tostring(self.FrictionWeight),
            tostring(self.ElasticityWeight))
    end,
}
local PhysicalProperties = {}
PhysicalProperties.new = function(DensityValue, FrictionValue, ElasticityValue, FrictionWeightValue, ElasticityWeightValue)
    if type(DensityValue) ~= "number" then
        DensityValue = nil
    end
    if type(FrictionValue) ~= "number" then
        FrictionValue = nil
    end
    if type(ElasticityValue) ~= "number" then
        ElasticityValue = nil
    end
    if type(FrictionWeightValue) ~= "number" then
        FrictionWeightValue = nil
    end
    if type(ElasticityWeightValue) ~= "number" then
        ElasticityWeightValue = nil
    end
    return setmetatable({
        _Type = "PhysicalProperties",
        Density = ToFloat32(DensityValue or 0.7),
        Friction = ToFloat32(FrictionValue or 0.3),
        Elasticity = ToFloat32(ElasticityValue or 0.5),
        FrictionWeight = ToFloat32(FrictionWeightValue or 1),
        ElasticityWeight = ToFloat32(ElasticityWeightValue or 1),
    }, PhysicalPropertiesMT)
end
Fidelity.PhysicalProperties = PhysicalProperties
Fidelity.WorkspaceAlwaysNilMembers = {
    Parent = true, Creator = true, PrimaryPart = true, SourceAssetId = true,
    _G = true, Attributes = true,
}
local World = {}
local RegisteredParts = {}
function World.SetWorkspace(workspaceObject)
    World.WorkspaceObject = workspaceObject
end
local SpatialClasses = {
    Part = true, MeshPart = true, WedgePart = true, CornerWedgePart = true,
    TrussPart = true, Seat = true, VehicleSeat = true, SpawnLocation = true,
    UnionOperation = true, NegateOperation = true, PartOperation = true,
}
function Fidelity.IsSpatialPart(className)
    return SpatialClasses[className] == true
end
function Fidelity.IsPivotClass(className)
    return SpatialClasses[className] == true or className == "Model" or className == "Workspace"
end
function Fidelity.BoundsOfInstance(instance)
    local MinX, MinY, MinZ, MaxX, MaxY, MaxZ
    local Visited = {}
    local Pending = { instance }
    local GuardCount = 0
    while #Pending > 0 and GuardCount < 4096 do
        GuardCount += 1
        local Current = table.remove(Pending)
        if Current ~= nil and Visited[Current] == nil then
            Visited[Current] = true
            local CurrentSize = Current.Size
            local CurrentPosition = Current.Position
            if CurrentSize ~= nil and CurrentPosition ~= nil
                and CurrentSize.X ~= nil and CurrentPosition.X ~= nil then
                local HalfX, HalfY, HalfZ = CurrentSize.X / 2, CurrentSize.Y / 2, CurrentSize.Z / 2
                local LowX, HighX = CurrentPosition.X - HalfX, CurrentPosition.X + HalfX
                local LowY, HighY = CurrentPosition.Y - HalfY, CurrentPosition.Y + HalfY
                local LowZ, HighZ = CurrentPosition.Z - HalfZ, CurrentPosition.Z + HalfZ
                if MinX == nil or LowX < MinX then MinX = LowX end
                if MinY == nil or LowY < MinY then MinY = LowY end
                if MinZ == nil or LowZ < MinZ then MinZ = LowZ end
                if MaxX == nil or HighX > MaxX then MaxX = HighX end
                if MaxY == nil or HighY > MaxY then MaxY = HighY end
                if MaxZ == nil or HighZ > MaxZ then MaxZ = HighZ end
            end
            if Fidelity.GetChildrenOf ~= nil then
                for _, ChildValue in ipairs(Fidelity.GetChildrenOf(Current)) do
                    Pending[#Pending + 1] = ChildValue
                end
            end
        end
    end
    if MinX == nil then return nil, nil end
    local VectorConstructor = Fidelity.Vector3 or Vector3
    return VectorConstructor.new((MinX + MaxX) / 2, (MinY + MaxY) / 2, (MinZ + MaxZ) / 2),
        VectorConstructor.new(MaxX - MinX, MaxY - MinY, MaxZ - MinZ)
end
function World.IsWorkspace(candidate)
    return candidate ~= nil and candidate == World.WorkspaceObject
end
local function PartIndex(part)
    for index, candidate in ipairs(RegisteredParts) do
        if candidate == part then
            return index
        end
    end
    return nil
end
World.Bodies = setmetatable({}, { __mode = "k" })
local function SinglePartMass(part)
    local size = part.Size
    local volume = 0
    if size ~= nil and size.X ~= nil and size.Y ~= nil and size.Z ~= nil then
        local x, y, z = tonumber(size.X), tonumber(size.Y), tonumber(size.Z)
        if x ~= nil and y ~= nil and z ~= nil then
            volume = math.abs(x * y * z)
        end
    end
    if volume == 0 then
        volume = 4 * 1.2 * 2
    end
    return volume * 0.7
end
World.SinglePartMass = SinglePartMass
function World.BodyOf(part)
    local body = World.Bodies[part]
    if body == nil then
        local stored = part.Position
        if stored == nil or tonumber(stored.X) == nil then
            stored = Vector3.new(0, 0, 0)
        end
        body = {
            Position = stored,
            Velocity = Vector3.new(0, 0, 0),
        }
        World.Bodies[part] = body
    end
    return body
end
function World.BodyPositionOf(part)
    local body = World.Bodies[part]
    return body ~= nil and body.Position or nil
end
function World.BodyVelocityOf(part)
    local body = World.Bodies[part]
    return body ~= nil and body.Velocity or nil
end
function World.SetBodyState(part, position, velocity)
    if part.Anchored == true then
        World.Bodies[part] = nil
        return
    end
    local body = World.BodyOf(part)
    if position ~= nil then
        body.Position = position
    end
    if velocity ~= nil then
        body.Velocity = velocity
    end
    if position ~= nil and World.Propagate ~= nil then
        World.Propagate(part, body.Velocity)
    end
end
function World.Step(dt)
    local seconds = tonumber(dt)
    if seconds == nil or seconds <= 0 then
        return
    end
    local gravity = 196.2
    local workspaceObject = World.WorkspaceObject
    if workspaceObject ~= nil then
        gravity = tonumber(workspaceObject.Gravity) or gravity
    end
    for _, part in ipairs(RegisteredParts) do
        if World.IsDynamic == nil or World.IsDynamic(part) then
            local body = World.BodyOf(part)
            local velocity = body.Velocity
            local position = body.Position
            local newVelocity = Vector3.new(
                velocity.X,
                velocity.Y - gravity * seconds,
                velocity.Z
            )
            body.Position = Vector3.new(
                position.X + newVelocity.X * seconds,
                position.Y + newVelocity.Y * seconds,
                position.Z + newVelocity.Z * seconds
            )
            body.Velocity = newVelocity
            if World.Propagate ~= nil then
                World.Propagate(part, newVelocity)
            end
        end
    end
    if World.ResolveContacts ~= nil then
        World.ResolveContacts()
    end
end
function World.Advance(seconds)
    local remaining = tonumber(seconds) or 0
    if remaining <= 0 then
        return
    end
    local frameTime = 1 / 60
    while remaining > 0 do
        local step = remaining > frameTime and frameTime or remaining
        World.Step(step)
        remaining -= step
    end
end
function Fidelity.RefreshStats()
    local statsObject = Fidelity.StatsObject
    if statsObject == nil then
        return
    end
    pcall(function()
        rawset(statsObject, "PrimitivesCount", World.PartCount())
    end)
end
function World.Register(part)
    if PartIndex(part) == nil then
        RegisteredParts[#RegisteredParts + 1] = part
    end
    Fidelity.RefreshStats()
end
function World.Unregister(part)
    local index = PartIndex(part)
    if index ~= nil then
        table.remove(RegisteredParts, index)
    end
    Fidelity.RefreshStats()
end
function World.Clear()
    table.clear(RegisteredParts)
    if World.Bodies ~= nil then
        table.clear(World.Bodies)
    end
    if World.Attached ~= nil then
        table.clear(World.Attached)
    end
    if World.Joints ~= nil then
        table.clear(World.Joints)
    end
    if World.Touching ~= nil then
        table.clear(World.Touching)
    end
end
function World.PartCount()
    return #RegisteredParts
end
function World.ListParts()
    local copy = {}
    for index, part in ipairs(RegisteredParts) do
        copy[index] = part
    end
    return copy
end
local function PartBounds(part)
    local size = part.Size or Vector3.new(4, 1.2, 2)
    local position = part.Position or Vector3.zero
    local halfX, halfY, halfZ = size.X / 2, size.Y / 2, size.Z / 2
    return {
        MinX = position.X - halfX, MaxX = position.X + halfX,
        MinY = position.Y - halfY, MaxY = position.Y + halfY,
        MinZ = position.Z - halfZ, MaxZ = position.Z + halfZ,
    }
end
local function BoundsOverlap(a, b)
    return a.MinX <= b.MaxX and a.MaxX >= b.MinX
        and a.MinY <= b.MaxY and a.MaxY >= b.MinY
        and a.MinZ <= b.MaxZ and a.MaxZ >= b.MinZ
end
local function BoundsFromBox(center, size)
    return {
        MinX = center.X - size.X / 2, MaxX = center.X + size.X / 2,
        MinY = center.Y - size.Y / 2, MaxY = center.Y + size.Y / 2,
        MinZ = center.Z - size.Z / 2, MaxZ = center.Z + size.Z / 2,
    }
end
local function SameInstanceValue(left, right)
    if left == right then
        return true
    end
    if type(left) ~= "table" or type(right) ~= "table" then
        return false
    end
    local leftId = rawget(left, "__V1_ID")
    local rightId = rawget(right, "__V1_ID")
    if leftId ~= nil and rightId ~= nil then
        return leftId == rightId
    end
    return false
end
local function FilterListContains(params, part)
    local filter = params ~= nil and params.FilterDescendantsInstances or nil
    if type(filter) ~= "table" then
        return false
    end
    for _, listed in ipairs(filter) do
        if SameInstanceValue(listed, part) then
            return true
        end
        if type(listed) == "table" and type(listed.GetDescendants) == "function" then
            local ok, descendants = pcall(listed.GetDescendants, listed)
            if ok and type(descendants) == "table" then
                for _, child in ipairs(descendants) do
                    if SameInstanceValue(child, part) then
                        return true
                    end
                end
            end
        end
    end
    return false
end
local function FilterTypeName(params)
    local modeValue = params ~= nil and params.FilterType or nil
    if modeValue == nil then
        return "Exclude"
    end
    if type(modeValue) == "string" then
        return modeValue
    end
    if type(modeValue) == "number" then
        return modeValue == 1 and "Include" or "Exclude"
    end
    if type(modeValue) == "table" then
        local itemName = rawget(modeValue, "Name")
        if type(itemName) == "string" then
            return itemName
        end
    end
    return "Exclude"
end
local function PassesFilter(part, params)
    if params ~= nil and params.RespectCanCollide == true and part.CanCollide == false then
        return false
    end
    local filterMode = FilterTypeName(params)
    if filterMode == "Exclude" and FilterListContains(params, part) then
        return false
    end
    if part.CanCollide == false and part.CanQuery == false then
        return false
    end
    if filterMode == "Include" then
        local filter = params.FilterDescendantsInstances
        if type(filter) == "table" then
            for _, allowed in ipairs(filter) do
                if SameInstanceValue(allowed, part) then
                    return true
                end
            end
            return false
        end
    end
    return true
end
local function RayAabbDistance(origin, direction, bounds)
    local tMin, tMax = 0, math.huge
    local hitAxisIndex, hitSign = nil, 1
    local axes = {
        { origin.X, direction.X, bounds.MinX, bounds.MaxX },
        { origin.Y, direction.Y, bounds.MinY, bounds.MaxY },
        { origin.Z, direction.Z, bounds.MinZ, bounds.MaxZ },
    }
    for axisIndex, axis in ipairs(axes) do
        local o, d, lo, hi = axis[1], axis[2], axis[3], axis[4]
        if math.abs(d) < 1e-12 then
            if o < lo or o > hi then
                return nil
            end
        else
            local inv = 1 / d
            local t1 = (lo - o) * inv
            local t2 = (hi - o) * inv
            if t1 > t2 then
                t1, t2 = t2, t1
            end
            if t1 > tMin then
                tMin = t1
                hitAxisIndex, hitSign = axisIndex, (d < 0) and 1 or -1
            end
            if t2 < tMax then tMax = t2 end
            if tMin > tMax then
                return nil
            end
        end
    end
    if tMax < 0 then
        return nil
    end
    return tMin, hitAxisIndex, hitSign
end
local function HitNormal(axisIndex, sign)
    if axisIndex == 1 then
        return Vector3.new(sign, 0, 0)
    elseif axisIndex == 2 then
        return Vector3.new(0, sign, 0)
    elseif axisIndex == 3 then
        return Vector3.new(0, 0, sign)
    end
    return Vector3.new(0, 1, 0)
end
World.Attached = setmetatable({}, { __mode = "k" })
World.Joints = setmetatable({}, { __mode = "k" })
World.Touching = setmetatable({}, { __mode = "k" })
Fidelity.JointClasses = {
    Weld = true, Motor = true, Motor6D = true, WeldConstraint = true,
}
World.TouchNotifier = nil
World.MaxContactParts = 64
World.ContactSkin = 0.05
local function IsSpatial(part)
    return part ~= nil and type(part) == "table" and Fidelity.IsSpatialPart(part.ClassName) == true
end
local AXIS_NAMES = { "X", "Y", "Z" }
local function AxisGet(vector, axis)
    if axis == 1 then return vector.X elseif axis == 2 then return vector.Y end
    return vector.Z
end
local function AxisSet(vector, axis, value)
    if axis == 1 then
        return Vector3.new(value, vector.Y, vector.Z)
    elseif axis == 2 then
        return Vector3.new(vector.X, value, vector.Z)
    end
    return Vector3.new(vector.X, vector.Y, value)
end
local function BoundsOverlapInfo(first, second, skin)
    local margin = skin or 0
    local bestDepth, bestAxis, bestSign = nil, nil, 1
    for axisIndex, axisName in ipairs(AXIS_NAMES) do
        local upperFirst, lowerFirst = first["Max" .. axisName] + margin, first["Min" .. axisName] - margin
        local upperSecond, lowerSecond = second["Max" .. axisName] + margin, second["Min" .. axisName] - margin
        local overlap = math.min(upperFirst, upperSecond) - math.max(lowerFirst, lowerSecond)
        if overlap <= 0 then
            return nil
        end
        if bestDepth == nil or overlap < bestDepth then
            bestDepth = overlap
            bestAxis = axisIndex
            bestSign = ((upperFirst + lowerFirst) / 2) >= ((upperSecond + lowerSecond) / 2) and 1 or -1
        end
    end
    return bestAxis, bestDepth, bestSign
end
function World.ResolveRoot(part)
    local current = part
    for _ = 1, 16 do
        local attachment = World.Attached[current]
        if attachment == nil or attachment.Parent == nil then
            return current
        end
        current = attachment.Parent
    end
    return current
end
function World.SetJoint(jointObject)
    if type(jointObject) ~= "table" then
        return
    end
    local part0, part1 = jointObject.Part0, jointObject.Part1
    if not IsSpatial(part0) or not IsSpatial(part1) or part0 == part1 then
        World.ClearJoint(jointObject)
        return
    end
    World.Joints[jointObject] = { Part0 = part0, Part1 = part1 }
    local position0, position1 = part0.Position, part1.Position
    if position0 ~= nil and position1 ~= nil then
        World.Propagate(part0, World.BodyVelocityOf(part0))
        World.Attached[part1] = {
            Parent = part0,
            Offset = Vector3.new(
                position1.X - position0.X,
                position1.Y - position0.Y,
                position1.Z - position0.Z
            ),
        }
    end
end
function World.ClearJoint(jointObject)
    local entry = World.Joints[jointObject]
    if entry == nil then
        return
    end
    World.Joints[jointObject] = nil
    local attachment = entry.Part1 ~= nil and World.Attached[entry.Part1] or nil
    if attachment ~= nil and attachment.Parent == entry.Part0 then
        World.Attached[entry.Part1] = nil
    end
end
function World.AssemblyMembers(part)
    local members, seen = { part }, { [part] = true }
    local frontier, head = { part }, 1
    while head <= #frontier and #members < 64 do
        local current = frontier[head]
        head = head + 1
        for candidate, attachment in next, World.Attached do
            if attachment.Parent == current and seen[candidate] == nil then
                seen[candidate] = true
                members[#members + 1] = candidate
                frontier[#frontier + 1] = candidate
            end
        end
    end
    return members
end
local function PartVolume(part)
    local size = part.Size
    if size ~= nil and size.X ~= nil and size.Y ~= nil and size.Z ~= nil then
        local x, y, z = tonumber(size.X), tonumber(size.Y), tonumber(size.Z)
        if x ~= nil and y ~= nil and z ~= nil then
            return math.abs(x * y * z)
        end
    end
    return 4 * 1.2 * 2
end
function World.MassOf(part)
    local volume = 0
    for _, member in ipairs(World.AssemblyMembers(World.ResolveRoot(part))) do
        volume = volume + PartVolume(member)
    end
    return volume * 0.7
end
function World.IsDynamic(part)
    return IsSpatial(part) and part.Anchored ~= true and World.Attached[part] == nil
end
function World.Propagate(part, velocity)
    local sharedVelocity = velocity
    for candidate, attachment in next, World.Attached do
        if attachment.Parent == part and candidate.Anchored ~= true then
            local body = World.BodyOf(candidate)
            local rootPosition = World.BodyPositionOf(part) or part.Position
            if rootPosition ~= nil and attachment.Offset ~= nil then
                body.Position = Vector3.new(
                    rootPosition.X + attachment.Offset.X,
                    rootPosition.Y + attachment.Offset.Y,
                    rootPosition.Z + attachment.Offset.Z
                )
            end
            if sharedVelocity ~= nil then
                body.Velocity = sharedVelocity
            end
            World.Propagate(candidate, body.Velocity)
        end
    end
end
local function MarkTouching(first, second)
    local contactsOfFirst = World.Touching[first]
    if contactsOfFirst == nil then
        contactsOfFirst = {}
        World.Touching[first] = contactsOfFirst
    end
    local wasTouching = contactsOfFirst[second] == true
    contactsOfFirst[second] = true
    return wasTouching
end
local function ClearTouching(first, second)
    local contactsOfFirst = World.Touching[first]
    if contactsOfFirst ~= nil and contactsOfFirst[second] == true then
        contactsOfFirst[second] = nil
        return true
    end
    return false
end
function World.FireTouch(first, second, eventName)
    if World.TouchNotifier == nil or not IsSpatial(first) or not IsSpatial(second) then
        return
    end
    World.TouchNotifier(first, second, eventName)
end
function World.TouchingParts(part)
    local result = {}
    local contactsOfPart = World.Touching[part]
    if contactsOfPart ~= nil then
        for other in next, contactsOfPart do
            result[#result + 1] = other
        end
    end
    return result
end
local function ResolvePair(first, second)
    local rootFirst, rootSecond = World.ResolveRoot(first), World.ResolveRoot(second)
    if rootFirst == rootSecond then
        return
    end
    local staticFirst, staticSecond = rootFirst.Anchored == true, rootSecond.Anchored == true
    if staticFirst and staticSecond then
        return
    end
    local axis, depth, sign = BoundsOverlapInfo(PartBounds(first), PartBounds(second))
    if axis == nil or depth <= 0 then
        return
    end
    local bodyFirst = staticFirst and nil or World.BodyOf(rootFirst)
    local bodySecond = staticSecond and nil or World.BodyOf(rootSecond)
    local massFirst, massSecond = World.MassOf(rootFirst), World.MassOf(rootSecond)
    local shareFirst, shareSecond = 0, 0
    local normalVelocityFirst, normalVelocitySecond = 0, 0
    if staticSecond then
        shareFirst = 1
    elseif staticFirst then
        shareSecond = 1
    else
        local totalMass = massFirst + massSecond
        if totalMass <= 0 then
            totalMass = 1
        end
        shareFirst = massSecond / totalMass
        shareSecond = massFirst / totalMass
        normalVelocityFirst = (AxisGet(bodyFirst.Velocity, axis) * massFirst
            + AxisGet(bodySecond.Velocity, axis) * massSecond) / totalMass
        normalVelocitySecond = normalVelocityFirst
    end
    if bodyFirst ~= nil then
        bodyFirst.Position = AxisSet(bodyFirst.Position, axis,
            AxisGet(bodyFirst.Position, axis) + sign * depth * shareFirst)
        bodyFirst.Velocity = AxisSet(bodyFirst.Velocity, axis, normalVelocityFirst)
        World.Propagate(rootFirst, bodyFirst.Velocity)
    end
    if bodySecond ~= nil then
        bodySecond.Position = AxisSet(bodySecond.Position, axis,
            AxisGet(bodySecond.Position, axis) - sign * depth * shareSecond)
        bodySecond.Velocity = AxisSet(bodySecond.Velocity, axis, normalVelocitySecond)
        World.Propagate(rootSecond, bodySecond.Velocity)
    end
    if not MarkTouching(first, second) then
        World.FireTouch(first, second, "Touched")
    end
    if not MarkTouching(second, first) then
        World.FireTouch(second, first, "Touched")
    end
end
function World.ResolveContacts()
    local partCount = #RegisteredParts
    if partCount < 2 or partCount > World.MaxContactParts then
        return
    end
    for firstIndex = 1, partCount do
        local first = RegisteredParts[firstIndex]
        if IsSpatial(first) and first.CanCollide ~= false then
            for secondIndex = firstIndex + 1, partCount do
                local second = RegisteredParts[secondIndex]
                if IsSpatial(second) and second.CanCollide ~= false then
                    ResolvePair(first, second)
                end
            end
        end
    end
    for first, contactsOfFirst in next, World.Touching do
        for second in next, contactsOfFirst do
            if IsSpatial(first) and IsSpatial(second)
                and BoundsOverlapInfo(PartBounds(first), PartBounds(second), World.ContactSkin) == nil then
                if ClearTouching(first, second) then
                    World.FireTouch(first, second, "TouchEnded")
                end
                if ClearTouching(second, first) then
                    World.FireTouch(second, first, "TouchEnded")
                end
            end
        end
    end
end
function World.Raycast(origin, direction, params)
    local bestParam, bestPart, bestNormal = math.huge, nil, nil
    local rayLength = direction.Magnitude
    if rayLength == 0 then
        return nil
    end
    for _, part in ipairs(RegisteredParts) do
        if PassesFilter(part, params) then
            local parameter, hitAxis, hitSign = RayAabbDistance(origin, direction, PartBounds(part))
            if parameter ~= nil and parameter <= 1 and parameter < bestParam then
                bestParam = parameter
                bestPart = part
                bestNormal = HitNormal(hitAxis, hitSign)
            end
        end
    end
    if bestPart == nil then
        return nil
    end
    local hitPosition = Vector3.new(
        origin.X + direction.X * bestParam,
        origin.Y + direction.Y * bestParam,
        origin.Z + direction.Z * bestParam
    )
    return {
        _Type = "RaycastResult",
        Position = hitPosition,
        Distance = bestParam * rayLength,
        Instance = bestPart,
        Normal = bestNormal ~= nil and bestNormal or Vector3.new(0, 1, 0),
        Material = bestPart.Material or Fidelity.EnumValue("Material", "Plastic", 256),
    }
end
function World.GetPartBoundsInBox(cframe, size, params)
    local center = cframe.Position
    local queryBounds = BoundsFromBox(center, size)
    local found = {}
    local limit = (params ~= nil and params.MaxParts) or math.huge
    for _, part in ipairs(RegisteredParts) do
        if PassesFilter(part, params) and BoundsOverlap(PartBounds(part), queryBounds) then
            found[#found + 1] = part
            if #found >= limit then
                break
            end
        end
    end
    return found
end
function World.GetPartsInPart(part, params)
    local selfBounds = PartBounds(part)
    local found = {}
    local limit = (params ~= nil and params.MaxParts) or math.huge
    for _, candidate in ipairs(RegisteredParts) do
        if candidate ~= part and PassesFilter(candidate, params)
            and BoundsOverlap(PartBounds(candidate), selfBounds) then
            found[#found + 1] = candidate
            if #found >= limit then
                break
            end
        end
    end
    return found
end
local function TrimFractionZeros(Text)
    if string.find(Text, ".", 1, true) ~= nil then
        Text = string.gsub(Text, "0+$", "")
        Text = string.gsub(Text, "%.$", "")
    end
    return Text
end
local function DecimalText(value, maxDigits)
    local negative = value < 0
    local magnitude = math.abs(value)
    local digits = math.max(0, math.floor(maxDigits + 0.5))
    local rounded = math.floor(magnitude * (10 ^ digits) + 0.5)
    local text
    if digits == 0 then
        text = string.format("%d", rounded)
    else
        text = string.format("%." .. digits .. "f", rounded / (10 ^ digits))
        text = TrimFractionZeros(text)
    end
    if negative and rounded ~= 0 then
        text = "-" .. text
    end
    return text
end
local function GroupThousands(text)
    local sign = ""
    if string.sub(text, 1, 1) == "-" then
        sign = "-"
        text = string.sub(text, 2)
    end
    local fraction = nil
    local dotIndex = string.find(text, ".", 1, true)
    if dotIndex ~= nil then
        fraction = string.sub(text, dotIndex)
        text = string.sub(text, 1, dotIndex - 1)
    end
    local grouped = ""
    while #text > 3 do
        grouped = "," .. string.sub(text, -3) .. grouped
        text = string.sub(text, 1, #text - 3)
    end
    grouped = text .. grouped
    if fraction ~= nil then
        grouped = grouped .. fraction
    end
    return sign .. grouped
end
local function FormatNumericPart(value, style, precision)
    if type(value) ~= "number" then
        return tostring(value)
    end
    if style == "integer" or style == "int" then
        return DecimalText(value, 0)
    elseif style == "currency" then
        return GroupThousands(DecimalText(value, 2))
    elseif style == "percent" then
        return GroupThousands(DecimalText(value * 100, precision ~= nil and precision or 0)) .. "%"
    elseif style == "fixed" then
        return DecimalText(value, precision ~= nil and precision or 3)
    elseif style == "num" or style == "number" then
        return GroupThousands(DecimalText(value, precision ~= nil and precision or 3))
    elseif style == "hex" then
        return string.format("%x", math.floor(math.abs(value)))
    elseif style == "HEX" then
        return string.format("%X", math.floor(math.abs(value)))
    end
    return DecimalText(value, precision ~= nil and precision or 3)
end
local function FormatToken(token, arguments)
    local argIndex, argStyle, argPrecision = string.match(token, "^(%d+) *: *([%a%-%u]+) *: *(%d+)$")
    if argIndex == nil then
        argIndex, argStyle = string.match(token, "^(%d+) *: *([%a%-%u]+)$")
        if argIndex == nil then
            argIndex = string.match(token, "^(%d+)$")
        end
    end
    if type(arguments) ~= "table" then
        return nil
    end
    local value
    if argIndex == nil then
        local name = string.match(token, "^([%w_%-%.]+)$")
        if name == nil then
            return nil
        end
        value = arguments[name]
        if value == nil then
            return nil
        end
        return tostring(value)
    end
    value = arguments[tonumber(argIndex)]
    if value == nil then
        return nil
    end
    if type(value) == "string" then
        local numeric = tonumber(value)
        if numeric ~= nil and argStyle ~= nil then
            value = numeric
        elseif argStyle ~= nil then
            return value
        end
    end
    return FormatNumericPart(value, argStyle, argPrecision ~= nil and tonumber(argPrecision) or nil)
end
function Fidelity.FormatLocalizationMessage(pattern, arguments)
    if type(pattern) ~= "string" then
        return pattern
    end
    return (string.gsub(pattern, "{([^{}]-)}", function(token)
        return FormatToken(token, arguments) or ("{" .. token .. "}")
    end))
end
Fidelity.LocalsStampLimit = 4000
function Fidelity.CurrentTargetLine(tracebackText)
    local text = tracebackText or debug.traceback("", 2)
    for line in string.gmatch(text, "[^\r\n]+") do
        local source, lineNumber = string.match(line, '^%[string "([^"]*)"%]:(%d+)')
        if source ~= nil and tonumber(lineNumber) ~= nil then
            return tonumber(lineNumber)
        end
    end
    return nil
end
local function IsSelfContainedLine(text)
    local depth, quote = 0, nil
    local bracketDepth = 0
    local index = 1
    while index <= #text do
        local char = string.sub(text, index, index)
        if quote ~= nil then
            if char == "\\" then
                index = index + 1
            elseif char == quote then
                quote = nil
            end
        elseif char == "\"" or char == "'" then
            quote = char
        elseif char == "(" then
            depth = depth + 1
        elseif char == ")" then
            depth = depth - 1
            if depth < 0 then return false end
        elseif char == "{" then
            bracketDepth = bracketDepth + 1
        elseif char == "}" then
            bracketDepth = bracketDepth - 1
            if bracketDepth < 0 then return false end
        end
        index = index + 1
    end
    return depth == 0 and bracketDepth == 0 and quote == nil
end
local RecoveredLocalKeywords = {
    ["local"] = true, ["function"] = true, ["end"] = true, ["if"] = true, ["then"] = true,
    ["else"] = true, ["elseif"] = true, ["for"] = true, ["while"] = true, ["repeat"] = true,
    ["until"] = true, ["return"] = true, ["break"] = true, ["in"] = true, ["and"] = true,
    ["or"] = true, ["not"] = true, ["nil"] = true, ["true"] = true, ["false"] = true,
    ["do"] = true, ["goto"] = true, ["continue"] = true,
}
local function SwapIdentifier(text, from, to)
    return (string.gsub(text, "%f[%w_]" .. from .. "%f[^%w_]", tostring(to)))
end
Fidelity.VirtualFiles = {}
Fidelity.VirtualFolders = {}
Fidelity.RunningChunkFunction = nil
function Fidelity.VirtualNormalisePath(pathValue)
    if type(pathValue) ~= "string" then
        return nil
    end
    local textValue = string.gsub(pathValue, "\\", "/")
    local isAbsolute = string.sub(textValue, 1, 1) == "/"
    local segments = {}
    for segmentValue in string.gmatch(textValue, "[^/]+") do
        if segmentValue == "." then
        elseif segmentValue == ".." then
            if #segments > 0 and segments[#segments] ~= ".." then
                table.remove(segments)
            end
        else
            segments[#segments + 1] = segmentValue
        end
    end
    local joinedValue = table.concat(segments, "/")
    if Fidelity.NoteSourceProbe ~= nil and Fidelity.IsToolSourcePath ~= nil
        and (isAbsolute or Fidelity.IsToolSourcePath(pathValue) == true) then
        Fidelity.NoteSourceProbe(pathValue)
    end
    if isAbsolute then
        return "/" .. joinedValue
    end
    return joinedValue
end
function Fidelity.VirtualFileWrite(pathValue, contentValue)
    local keyName = Fidelity.VirtualNormalisePath(pathValue)
    if keyName == nil then
        return false
    end
    Fidelity.VirtualFiles[keyName] = contentValue == nil and "" or tostring(contentValue)
    return true
end
function Fidelity.VirtualFileAppend(pathValue, contentValue)
    local keyName = Fidelity.VirtualNormalisePath(pathValue)
    if keyName == nil then
        return false
    end
    local previousValue = Fidelity.VirtualFiles[keyName] or ""
    Fidelity.VirtualFiles[keyName] = previousValue .. (contentValue == nil and "" or tostring(contentValue))
    return true
end
function Fidelity.VirtualFileRead(pathValue)
    local keyName = Fidelity.VirtualNormalisePath(pathValue)
    if keyName == nil then
        return nil
    end
    return Fidelity.VirtualFiles[keyName]
end
function Fidelity.VirtualFileExists(pathValue)
    return Fidelity.VirtualFileRead(pathValue) ~= nil
end
function Fidelity.VirtualFileRemove(pathValue)
    local keyName = Fidelity.VirtualNormalisePath(pathValue)
    if keyName == nil or Fidelity.VirtualFiles[keyName] == nil then
        return false
    end
    Fidelity.VirtualFiles[keyName] = nil
    return true
end
function Fidelity.VirtualFolderMake(pathValue)
    local keyName = Fidelity.VirtualNormalisePath(pathValue)
    if keyName == nil then
        return false
    end
    Fidelity.VirtualFolders[keyName] = true
    return true
end
function Fidelity.VirtualFolderExists(pathValue)
    local keyName = Fidelity.VirtualNormalisePath(pathValue)
    return keyName ~= nil and Fidelity.VirtualFolders[keyName] == true
end
function Fidelity.VirtualFolderRemove(pathValue)
    local keyName = Fidelity.VirtualNormalisePath(pathValue)
    if keyName == nil or Fidelity.VirtualFolders[keyName] == nil then
        return false
    end
    Fidelity.VirtualFolders[keyName] = nil
    return true
end
local function HasPrefix(textValue, prefixValue)
    return string.sub(textValue, 1, #prefixValue) == prefixValue
end
function Fidelity.VirtualFolderList(pathValue)
    local prefix = Fidelity.VirtualNormalisePath(pathValue) or ""
    if prefix == "." then
        prefix = ""
    end
    if prefix ~= "" and string.sub(prefix, -1) ~= "/" then
        prefix = prefix .. "/"
    end
    local names = {}
    for keyName in next, Fidelity.VirtualFiles do
        if prefix == "" or HasPrefix(keyName, prefix) then
            local tailValue = string.sub(keyName, #prefix + 1)
            if tailValue ~= "" and not string.find(tailValue, "/", 1, true) then
                names[#names + 1] = keyName
            end
        end
    end
    for keyName in next, Fidelity.VirtualFolders do
        if prefix == "" or HasPrefix(keyName, prefix) then
            local tailValue = string.sub(keyName, #prefix + 1)
            if tailValue ~= "" and not string.find(tailValue, "/", 1, true) then
                names[#names + 1] = keyName
            end
        end
    end
    table.sort(names)
    local cursor = 0
    return setmetatable(names, {
        __call = function(listValue)
            cursor += 1
            return rawget(listValue, cursor)
        end,
    })
end
function Fidelity.LuaStringLiteral(value)
    if value == nil then
        return "nil"
    end
    if type(value) == "number" or type(value) == "boolean" then
        return tostring(value)
    end
    if type(value) ~= "string" then
        return "\"" .. tostring(value) .. "\""
    end
    local escapedValue = value
    escapedValue = string.gsub(escapedValue, "\\", "\\\\")
    escapedValue = string.gsub(escapedValue, "\"", "\\\"")
    escapedValue = string.gsub(escapedValue, "\n", "\\n")
    escapedValue = string.gsub(escapedValue, "\r", "\\r")
    escapedValue = string.gsub(escapedValue, "\t", "\\t")
    return "\"" .. escapedValue .. "\""
end
local function statementStrip(lineText)
    local textValue = string.gsub(lineText, "%-%-.*$", "")
    textValue = string.gsub(textValue, "%b%[%]", " ")
    textValue = string.gsub(textValue, "\"[^\"]*\"", " ")
    textValue = string.gsub(textValue, "'[^']*'", " ")
    return textValue
end
local STATEMENT_OPENERS = { "function", "then", "do", "repeat" }
local STATEMENT_TRAILING_OPERATORS = { "and", "or", "not", "if", "elseif", "else", "then", "return", "in" }
local STATEMENT_CLOSERS = { "end", "until", "elseif" }
local function statementWordCount(textValue, wordValue)
    local countValue, searchPos = 0, 1
    local matchPattern = "%f[%w_]" .. wordValue .. "%f[%W_]"
    while true do
        local startPos = string.find(textValue, matchPattern, searchPos)
        if startPos == nil then
            return countValue
        end
        countValue = countValue + 1
        searchPos = startPos + #wordValue
    end
end
local function statementDelta(textValue)
    local deltaValue = 0
    for index = 1, #STATEMENT_OPENERS do
        deltaValue = deltaValue + statementWordCount(textValue, STATEMENT_OPENERS[index])
    end
    for index = 1, #STATEMENT_CLOSERS do
        deltaValue = deltaValue - statementWordCount(textValue, STATEMENT_CLOSERS[index])
    end
    local openBraces = select(2, string.gsub(textValue, "{", ""))
    local closeBraces = select(2, string.gsub(textValue, "}", ""))
    return deltaValue + openBraces - closeBraces
end
local function statementEndsOpen(textValue)
    local trimmed = string.match(textValue, "^(.-)%s*$") or textValue
    if trimmed == "" then
        return false
    end
    if string.match(trimmed, "[%+%=,%.%(%%<>]$") ~= nil then
        return true
    end
    for index = 1, #STATEMENT_TRAILING_OPERATORS do
        local wordValue = STATEMENT_TRAILING_OPERATORS[index]
        if statementWordCount(trimmed, wordValue) > 0
            and string.match(trimmed, "%f[%w_]" .. wordValue .. "%s*$") ~= nil then
            return true
        end
    end
    return false
end
function Fidelity.AssembleSourceStatement(sourceLines, startIndex, maxLines)
    if type(sourceLines) ~= "table" or type(startIndex) ~= "number" then
        return nil
    end
    local lineCap = maxLines or 200
    local collected, depthValue, index, readCount = {}, 0, startIndex, 0
    while index <= #sourceLines and readCount < lineCap do
        readCount = readCount + 1
        local lineText = sourceLines[index]
        if type(lineText) ~= "string" or string.find(lineText, "[[", 1, true) ~= nil then
            return nil
        end
        local stripped = statementStrip(lineText)
        collected[#collected + 1] = stripped ~= "" and lineText or lineText
        depthValue = depthValue + statementDelta(stripped)
        local continues = false
        if depthValue <= 0 and not statementEndsOpen(stripped) then
            local nextLine = sourceLines[index + 1]
            if type(nextLine) == "string" then
                local nextStripped = statementStrip(nextLine)
                for index = 1, #STATEMENT_TRAILING_OPERATORS do
                    local wordValue = STATEMENT_TRAILING_OPERATORS[index]
                    if string.match(nextStripped, "^%s*" .. wordValue .. "[^%w_]") ~= nil then
                        continues = true
                        break
                    end
                end
                if string.match(nextStripped, "^%s*[=!<>~]") ~= nil
                    or string.match(nextStripped, "^%s*%.%.") ~= nil then
                    continues = true
                end
            end
        end
        if depthValue <= 0 and not statementEndsOpen(stripped) and not continues then
            local joined = table.concat(collected, " ")
            joined = string.gsub(joined, "%s+", " ")
            return string.match(joined, "^(.-)%s*$") or joined, index
        end
        index = index + 1
    end
    return nil
end
local function sourceLinesOf(sourceText)
    local lines = {}
    for lineText in string.gmatch(sourceText .. "\n", "([^\n]*)\n") do
        lines[#lines + 1] = lineText
    end
    return lines
end
local function instanceAliasMap(outputText, sourceLines)
    local aliases = {}
    local sourceNames = {}
    for lineIndex = 1, #sourceLines do
        local stripped = statementStrip(sourceLines[lineIndex])
        local nameValue = string.match(stripped, "^%s*local%s+([%w_]+)%s*=%s*Instance%.new%s*%(")
        if nameValue ~= nil then
            sourceNames[#sourceNames + 1] = nameValue
        end
    end
    local emittedNames = {}
    for lineText in string.gmatch(outputText, "[^\n]*") do
        local emittedName = string.match(lineText, "^%s*local%s+([%w_]+)%s*=%s*Instance%.new%s*%(")
        if emittedName ~= nil then
            emittedNames[#emittedNames + 1] = emittedName
        end
    end
    for index = 1, math.min(#sourceNames, #emittedNames) do
        if sourceNames[index] ~= emittedNames[index] then
            aliases[sourceNames[index]] = emittedNames[index]
        end
    end
    return aliases
end
local function swapWord(textValue, fromValue, toValue)
    local pattern = "%f[%w_]" .. fromValue .. "%f[%W_]"
    return (string.gsub(textValue, pattern, toValue))
end
function Fidelity.RepairDanglingAssignments(outputText, sourceText)
    if type(outputText) ~= "string" or type(sourceText) ~= "string" or outputText == "" then
        return outputText
    end
    if string.find(outputText, " = \n", 1, true) == nil
        and string.find(outputText, " =", 1, true) == nil then
        return outputText
    end
    local sourceLines = sourceLinesOf(sourceText)
    local aliases = instanceAliasMap(outputText, sourceLines)
    local usedSourceLines = {}
    local resultLines, changedCount = {}, 0
    local sawFinalNewline = string.sub(outputText, -1) == "\n"
    for lineText in string.gmatch(outputText .. "\n", "([^\n]*)\n") do
        local danglingName = type(lineText) == "string"
            and string.match(lineText, "^%s*local%s+([%w_]+)%s*=%s*$") or nil
        local replacement = nil
        if danglingName ~= nil then
            for lineIndex = 1, #sourceLines do
                if usedSourceLines[lineIndex] == nil then
                    local stripped = statementStrip(sourceLines[lineIndex])
                    if string.match(stripped, "^%s*local%s+([%w_]+)%s*=%s*$") == danglingName then
                        local assembled = Fidelity.AssembleSourceStatement(sourceLines, lineIndex)
                        if assembled ~= nil and assembled ~= lineText then
                            for sourceName, emittedName in next, aliases do
                                assembled = swapWord(assembled, sourceName, emittedName)
                            end
                            replacement = assembled
                            for usedIndex = lineIndex, lineIndex do
                                usedSourceLines[usedIndex] = true
                            end
                            changedCount = changedCount + 1
                        end
                        break
                    end
                end
            end
        end
        resultLines[#resultLines + 1] = replacement or lineText
    end
    Fidelity.LastDanglingAssignmentRepairs = changedCount
    local joined = table.concat(resultLines, "\n")
    if sawFinalNewline and string.sub(joined, -1) ~= "\n" then
        joined = joined .. "\n"
    end
    return joined
end
function Fidelity.LocalsMerge(outputLines, sourceText, stamps, isTrackedName)
    if type(sourceText) ~= "string" or sourceText == "" then
        return nil
    end
    local sourceLines = {}
    for lineText in string.gmatch(sourceText .. "\n", "([^\n]*)\n") do
        sourceLines[#sourceLines + 1] = lineText
    end
    local declaredNames = {}
    local coveredLines = {}
    local renamedLocals = {}
    for lineIndex = 1, #outputLines do
        local line = outputLines[lineIndex]
        local declared = type(line) == "string" and (
            string.match(line, "^%s*local%s+([%w_]+)%s*=")
            or string.match(line, "^%s*local%s+([%w_]+)%s*$")) or nil
        if declared ~= nil then
            declaredNames[declared] = true
        end
        local stamp = stamps[lineIndex]
        if stamp ~= nil then
            coveredLines[stamp] = true
            local sourceLineText = sourceLines[stamp]
            if sourceLineText ~= nil and declared ~= nil then
                local sourceName = string.match(sourceLineText, "^local%s+([%w_]+)%s*=")
                    or string.match(sourceLineText, "^local%s+([%w_]+)%s*$")
                if sourceName ~= nil and sourceName ~= declared and declaredNames[sourceName] == nil then
                    declaredNames[sourceName] = declared
                end
            end
        end
    end
    local function stripNonCode(lineText)
        local textValue = string.gsub(lineText, "%-%-.*$", "")
        textValue = string.gsub(textValue, "%b%[%]", " ")
        textValue = string.gsub(textValue, "\"[^\"]*\"", " ")
        textValue = string.gsub(textValue, "'[^']*'", " ")
        return textValue
    end
    local function wordCount(textValue, wordValue)
        local countValue = 0
        local searchPos = 1
        local matchPattern = "%f[%w_]" .. wordValue .. "%f[%W_]"
        while true do
            local startPos = string.find(textValue, matchPattern, searchPos)
            if startPos == nil then
                break
            end
            countValue = countValue + 1
            searchPos = startPos + #wordValue
        end
        return countValue
    end
    local function lineDepthDelta(textValue)
        local deltaValue = 0
        deltaValue = deltaValue + wordCount(textValue, "function")
        deltaValue = deltaValue + wordCount(textValue, "then")
        deltaValue = deltaValue + wordCount(textValue, "do")
        deltaValue = deltaValue + wordCount(textValue, "repeat")
        deltaValue = deltaValue - wordCount(textValue, "end")
        deltaValue = deltaValue - wordCount(textValue, "until")
        deltaValue = deltaValue - wordCount(textValue, "elseif")
        local openBraces = select(2, string.gsub(textValue, "{", ""))
        local closeBraces = select(2, string.gsub(textValue, "}", ""))
        return deltaValue + openBraces - closeBraces
    end
    local blockScopedNames = {}
    local function rememberScopedNames(patternExpression, lineText)
        for nameList in string.gmatch(lineText, patternExpression) do
            for wordValue in string.gmatch(nameList, "[%w_]+") do
                if not RecoveredLocalKeywords[wordValue] then
                    blockScopedNames[wordValue] = true
                end
            end
        end
    end
    local lineDepths = {}
    do
        local depthValue = 0
        for lineIndex = 1, #sourceLines do
            lineDepths[lineIndex] = depthValue
            local textValue = stripNonCode(sourceLines[lineIndex])
            rememberScopedNames("for%s+([%w_,%s]+)%s+[%=<]", textValue)
            rememberScopedNames("function[%w_:%.%s]*%(([%w_,%s]*)%)", textValue)
            depthValue = depthValue + lineDepthDelta(textValue)
            if depthValue < 0 then
                depthValue = 0
            end
        end
    end
    local function assembleStatement(startIndex)
        local joined, lastIndex = Fidelity.AssembleSourceStatement(sourceLines, startIndex)
        if joined == nil then
            return nil
        end
        return joined, lastIndex
    end
    local danglingSlots = {}
    for lineIndex = 1, #outputLines do
        local emitted = outputLines[lineIndex]
        local danglingName = nil
        if type(emitted) == "string" then
            danglingName = string.match(emitted, "^%s*local%s+([%w_]+)%s*=%s*$")
        end
        if danglingName ~= nil then
            declaredNames[danglingName] = nil
            local stamp = stamps[lineIndex]
            if stamp ~= nil then
                coveredLines[stamp] = nil
                danglingSlots[stamp] = lineIndex
            end
            local statementText = stamp ~= nil and assembleStatement(stamp) or nil
            if statementText ~= nil then
                outputLines[lineIndex] = string.gsub(statementText, "%s*\n%s*", " ")
                coveredLines[stamp] = true
                danglingSlots[stamp] = nil
            end
        end
    end
    local pending, pendingCount = {}, 0
    for lineIndex = 1, #sourceLines do
        local raw = sourceLines[lineIndex]
        if coveredLines[lineIndex] == nil
            and lineDepths[lineIndex] == 0
            and string.find(raw, "local", 1, true) == 1
            and string.find(raw, "[[", 1, true) == nil then
            local statementText = raw
            if not IsSelfContainedLine(raw) then
                statementText = assembleStatement(lineIndex)
            end
            if statementText ~= nil and statementText ~= raw then
                statementText = string.gsub(statementText, "%s*\n%s*", " ")
            end
            local nameList, rightHandSide = nil, nil
            if type(statementText) == "string" and IsSelfContainedLine(statementText) then
                nameList, rightHandSide = string.match(statementText, "^local%s+([%w_%s,]-)%s*=%s*(.+)$")
                if nameList == nil then
                    local only = string.match(statementText, "^local%s+([%w_%s,]+)$")
                    if only ~= nil then
                        nameList = only
                    end
                end
            end
            if nameList ~= nil and rightHandSide ~= nil and IsSelfContainedLine(rightHandSide) then
                rightHandSide = rightHandSide:gsub("%s+$", "")
                local names, usable = {}, true
                for name in string.gmatch(nameList, "[%w_]+") do
                    if RecoveredLocalKeywords[name] or declaredNames[name] ~= nil
                        or (isTrackedName ~= nil and isTrackedName(name)) then
                        usable = false
                    end
                    names[#names + 1] = name
                end
                for wordValue in string.gmatch(rightHandSide, "[%w_]+") do
                    if blockScopedNames[wordValue] == true then
                        usable = false
                    end
                end
                if usable and #names > 0 then
                    for sourceName, generatedName in next, declaredNames do
                        if generatedName ~= true then
                            rightHandSide = SwapIdentifier(rightHandSide, sourceName, generatedName)
                        end
                    end
                    local recoveredText = "local " .. table.concat(names, ", ") .. " = " .. rightHandSide
                    local slot = danglingSlots[lineIndex]
                    if slot ~= nil then
                        outputLines[slot] = recoveredText
                        danglingSlots[lineIndex] = nil
                    else
                        pendingCount = pendingCount + 1
                        pending[pendingCount] = {
                            line = lineIndex,
                            text = recoveredText,
                        }
                    end
                end
            end
        end
    end
    if pendingCount == 0 then
        return nil
    end
    table.sort(pending, function(a, b) return a.line < b.line end)
    local merged, mergedCount = {}, 0
    local pendingIndex, anchorLine = 1, 0
    for lineIndex = 1, #outputLines do
        local stamp = stamps[lineIndex]
        if stamp ~= nil and stamp > anchorLine then
            anchorLine = stamp
        end
        while pending[pendingIndex] ~= nil and pending[pendingIndex].line < anchorLine do
            mergedCount = mergedCount + 1
            merged[mergedCount] = pending[pendingIndex].text
            pendingIndex = pendingIndex + 1
        end
        mergedCount = mergedCount + 1
        merged[mergedCount] = outputLines[lineIndex]
    end
    while pending[pendingIndex] ~= nil do
        mergedCount = mergedCount + 1
        merged[mergedCount] = pending[pendingIndex].text
        pendingIndex = pendingIndex + 1
    end
    return merged
end
local function RenderScalar(ValueData)
    if ValueData == nil then
        return "nil"
    end
    local valueType = type(ValueData)
    if valueType == "number" then
        if ValueData == math.huge then
            return "math.huge"
        elseif ValueData == -math.huge then
            return "-math.huge"
        end
        if ValueData % 1 == 0 then
            return tostring(ValueData)
        end
        return string.format("%.8g", ValueData)
    elseif valueType == "boolean" then
        return ValueData and "true" or "false"
    elseif valueType == "string" then
        return string.format("%q", ValueData)
    end
    return nil
end
Fidelity.SignalIdentity = setmetatable({}, { __mode = "k" })
local function RawField(Subject, FieldName)
    return rawget(Subject, FieldName)
end
local function IsIdentityRotation(Subject)
    if rawget(Subject, "R00") == nil then
        return true
    end
    return (RawField(Subject, "R00") or 0) == 1 and (RawField(Subject, "R11") or 0) == 1
        and (RawField(Subject, "R22") or 0) == 1
        and (RawField(Subject, "R01") or 0) == 0 and (RawField(Subject, "R02") or 0) == 0
        and (RawField(Subject, "R10") or 0) == 0 and (RawField(Subject, "R12") or 0) == 0
        and (RawField(Subject, "R20") or 0) == 0 and (RawField(Subject, "R21") or 0) == 0
end
function Fidelity.CapChunkLocalRegisters(payload, budget)
    local limit = budget or 180
    local lines = payload
    local joined = false
    if type(payload) == "string" then
        lines = {}
        local lineIndex = 0
        for lineText in string.gmatch(payload .. "\n", "([^\n]*)\n") do
            lineIndex = lineIndex + 1
            lines[lineIndex] = lineText
        end
        joined = true
    end
    local declared = 0
    for lineIndex = 1, #lines do
        local lineText = lines[lineIndex]
        if type(lineText) == "string" then
            local declaredName = string.match(lineText, "^local ([%a_][%w_]*)%s*=")
                or string.match(lineText, "^local ([%a_][%w_]*)%s*$")
            if declaredName ~= nil then
                declared = declared + 1
                if declared > limit then
                    lines[lineIndex] = string.gsub(lineText, "^local ", "", 1)
                end
            end
        end
    end
    if joined then
        return table.concat(lines, "\n")
    end
    return lines
end
function Fidelity.BalanceRecoveredBlocks(recoveredText)
    if type(recoveredText) ~= "string" then
        return recoveredText
    end
    local opened = 0
    local closed = 0
    for line in string.gmatch(recoveredText, "[^\n]+") do
        local code = string.gsub(line, "%-%-[^\n]*$", "")
        code = string.gsub(string.gsub(code, "^%s+", ""), "%s+$", "")
        if #code > 0 and not string.match(code, "^elseif") and code ~= "else" then
            if code == "end" or string.match(code, "^end,%s*$") or string.match(code, "^until%s") then
                closed = closed + 1
            elseif string.match(code, "%sdo$") or string.match(code, "%sthen$") or code == "repeat" then
                opened = opened + 1
            end
        end
    end
    local missing = opened - closed
    if missing <= 0 then
        return recoveredText
    end
    if missing > 64 then
        missing = 64
    end
    local tail = string.sub(recoveredText, -1) == "\n" and "" or "\n"
    return recoveredText .. tail .. string.rep("end\n", missing)
end
Fidelity.CSideNames = {}
function Fidelity.MarkCSideFunction(FunctionValue, NameText)
    if type(FunctionValue) ~= "function" and type(FunctionValue) ~= "table" then
        return
    end
    Fidelity.CSideNames[FunctionValue] = NameText or ""
    if Fidelity.EmulatedNatives ~= nil then
        Fidelity.EmulatedNatives[FunctionValue] = true
    end
end
function Fidelity.IsToolChunkSource(SourceText)
    if type(SourceText) ~= "string" then
        return false
    end
    if SourceText:find("luau.load", 1, true) ~= nil or SourceText:find("@KVMS", 1, true) ~= nil then
        return false
    end
    return SourceText:find("RobloxFidelity", 1, true) ~= nil
        or SourceText:match("/*m(_orig)?$", 1) ~= nil
        or SourceText:match("/m$", 1) ~= nil
        or SourceText:match("/m_orig$", 1) ~= nil
end
function Fidelity.IsCSideFunction(FunctionValue)
    if type(FunctionValue) ~= "function" then
        local Underlying
        if type(FunctionValue) == "table" then
            if Fidelity.WrappedFunctionTargets ~= nil then
                Underlying = Fidelity.WrappedFunctionTargets[FunctionValue]
            end
            if type(Underlying) ~= "function" then
                local CallableMeta = getmetatable(FunctionValue)
                Underlying = type(CallableMeta) == "table" and CallableMeta.__call or nil
            end
        end
        if type(Underlying) ~= "function" then
            return false
        end
        return Fidelity.IsCSideFunction(Underlying)
    end
    if Fidelity.CSideNames[FunctionValue] ~= nil then
        return true
    end
    if Fidelity.EmulatedNatives ~= nil and Fidelity.EmulatedNatives[FunctionValue] == true then
        return true
    end
    local QueryInfo = Fidelity.RawDebugInfo or debug.info
    local okay, sourceText = pcall(QueryInfo, FunctionValue, "s")
    if not okay then
        return false
    end
    if type(sourceText) == "string" and (sourceText == "[C]" or sourceText:sub(1, 2) == "=[") then
        return true
    end
    return Fidelity.IsToolChunkSource(sourceText) == true
end
function Fidelity.StripToolFramePrefix(MessageText)
    if type(MessageText) ~= "string" then
        return MessageText
    end
    local stripped = MessageText:gsub('^[^\n:]-m(_orig)?:%d+:%s*', '')
    local chunkName = MessageText:match('^%[string "([^"]*)"%]:%d+:%s*')
    if chunkName ~= nil and chunkName:find('luau.load', 1, true) == nil
        and chunkName:find('@KVMS', 1, true) == nil and chunkName ~= 'script' then
        stripped = MessageText:gsub('^%[string "[^"]*"%]:%d+:%s*', '')
    end
    return stripped
end
local EngineCSideTables = {
    "CFrame", "Vector2", "Vector3", "Vector2int16", "Vector3int16", "Color3", "BrickColor",
    "UDim", "UDim2", "Axes", "Faces", "Rect", "Region3", "Region3int16", "NumberRange",
    "NumberSequence", "NumberSequenceKeypoint", "ColorSequence", "ColorSequenceKeypoint",
    "TweenInfo", "Random", "Ray", "RaycastParams", "OverlapParams", "PhysicalProperties",
    "Instance", "SharedTable", "Font", "DateTime", "DockWidgetPluginGuiInfo",
    "SecurityCapabilities", "CatalogSearchParams", "Path2DControlPoint", "FloatCurveKey",
    "ValueCurveKey", "RotationCurveKey", "PathWaypoint", "Content", "NumberRange",
    "string", "table", "math", "utf8", "task", "debug", "os", "bit32", "vector", "buffer",
    "game", "workspace", "script", "print", "warn", "error", "pcall", "xpcall", "select",
    "next", "pairs", "ipairs", "rawget", "rawset", "rawequal", "rawlen", "type", "typeof",
    "tostring", "tonumber", "setmetatable", "getmetatable", "require", "loadstring", "load",
    "newproxy", "spawn", "wait", "delay", "tick", "time", "collectgarbage", "gcinfo",
    "Enum", "ColorSequence", "UDim2", "task",
}
Fidelity.CSideMemberNames = {
    task = { "spawn", "defer", "delay", "wait", "cancel", "wrap" },
}
local EngineCSideExtraNames = {
}
function Fidelity.MarkEngineCSideFunctions(envTable)
    if type(envTable) ~= "table" then
        return 0
    end
    local marked = 0
    local HostGlobals = _G
    for _, tableName in ipairs(EngineCSideTables) do
        local target = envTable[tableName]
        local hostTable = type(HostGlobals) == "table" and HostGlobals[tableName] or nil
        if type(target) ~= "table" then
            target = hostTable
        end
        if type(target) == "table" then
            local KeySet = {}
            for key in pairs(target) do
                if type(key) == "string" then
                    KeySet[key] = true
                end
            end
            if next(KeySet) == nil and Fidelity.CSideMemberNames ~= nil then
                local DeclaredNames = Fidelity.CSideMemberNames[tableName]
                if type(DeclaredNames) == "table" then
                    for _, DeclaredKey in ipairs(DeclaredNames) do
                        KeySet[DeclaredKey] = true
                    end
                end
            end
            if type(hostTable) == "table" then
                for key in pairs(hostTable) do
                    if type(key) == "string" then
                        KeySet[key] = true
                    end
                end
            end
            local isOurEnvTable = envTable[tableName] == target
            for key in pairs(KeySet) do
                local value = rawget(target, key)
                if value == nil then
                    value = target[key]
                end
                local AliasSplitDone = false
                if type(value) == "function" and isOurEnvTable
                    and Fidelity.CSideNames[value] ~= nil
                    and Fidelity.CSideNames[value] ~= (string.sub(key, 1, 2) == "__" and "" or key) then
                    local AliasedName = string.sub(key, 1, 2) == "__" and "" or key
                    local AliasedCall = value
                    local AliasForward = function(...) return AliasedCall(...) end
                    Fidelity.MarkCSideFunction(AliasForward, AliasedName)
                    if type(Fidelity.RegisterNative) == "function" then
                        pcall(Fidelity.RegisterNative, AliasForward, AliasedName)
                    end
                    rawset(target, key, AliasForward)
                    marked = marked + 1
                    AliasSplitDone = true
                end
                if not AliasSplitDone and type(value) == "function" and Fidelity.CSideNames[value] == nil then
                    local NativeName = string.sub(key, 1, 2) == "__" and "" or key
                    Fidelity.MarkCSideFunction(value, NativeName)
                    if type(Fidelity.RegisterNative) == "function" then
                        pcall(Fidelity.RegisterNative, value, NativeName)
                    end
                    marked = marked + 1
                end
            end
            local meta = getmetatable(target)
            if type(meta) == "table" then
                for key, value in pairs(meta) do
                    if type(key) == "string" and type(value) == "function"
                        and Fidelity.CSideNames[value] == nil then
                        Fidelity.MarkCSideFunction(value, "")
                        if type(Fidelity.RegisterNative) == "function" then
                            pcall(Fidelity.RegisterNative, value, "")
                        end
                        marked = marked + 1
                    end
                end
            end
        end
    end
    return marked
end
function Fidelity.DebugInfoForNative(targetFunction, optionsText)
    if type(optionsText) ~= "string" or #optionsText == 0 then
        return nil
    end
    if not Fidelity.IsCSideFunction(targetFunction) then
        return nil
    end
    local results = { n = 0 }
    for index = 1, #optionsText do
        local letter = string.sub(optionsText, index, index)
        if letter == "s" or letter == "S" then
            results.n = results.n + 1
            results[results.n] = "[C]"
        elseif letter == "l" or letter == "L" then
            results.n = results.n + 1
            results[results.n] = -1
        elseif letter == "n" then
            local NameHolder = targetFunction
            if type(targetFunction) == "table" then
                local Underlying
                if Fidelity.WrappedFunctionTargets ~= nil then
                    Underlying = Fidelity.WrappedFunctionTargets[targetFunction]
                end
                if type(Underlying) ~= "function" then
                    local CallableMeta = getmetatable(targetFunction)
                    Underlying = type(CallableMeta) == "table" and CallableMeta.__call or nil
                end
                if type(Underlying) == "function" then
                    NameHolder = Underlying
                end
            end
            results.n = results.n + 1
            results[results.n] = Fidelity.CSideNames[NameHolder] or Fidelity.CSideNames[targetFunction] or ""
        elseif letter == "p" then
            results.n = results.n + 1
            results[results.n] = 0
        elseif letter == "a" then
            results.n = results.n + 1
            results[results.n] = 0
            results.n = results.n + 1
            results[results.n] = true
        elseif letter == "u" then
            results.n = results.n + 1
            results[results.n] = 0
        elseif letter == "f" then
            results.n = results.n + 1
            results[results.n] = targetFunction
        end
    end
    if results.n == 0 then
        return nil
    end
    return results
end
function Fidelity.PreserveUnparsedSource(sourceText)
    if type(sourceText) ~= "string" or #sourceText == 0 then
        return ""
    end
    local lines = { "-- [recover] this runtime could not parse the chunk; the submitted source is preserved below" }
    for line in string.gmatch(sourceText, "[^\n]*") do
        lines[#lines + 1] = "-- " .. line
    end
    return table.concat(lines, "\n")
end
function Fidelity.HookMetaMethod(targetTable, methodName, replacementFunction)
    if type(targetTable) ~= "table" or type(methodName) ~= "string" then
        return replacementFunction
    end
    local meta = getmetatable(targetTable)
    if type(meta) ~= "table" then
        return replacementFunction
    end
    local previous = rawget(meta, methodName)
    if previous == nil then
        previous = meta[methodName]
    end
    local ownsItsMetatable = rawget(targetTable, "__V1_INSTANCE") == nil
        and rawget(targetTable, "TrackedPath") == nil
    if ownsItsMetatable then
        local swappedOk = pcall(rawset, meta, methodName, replacementFunction)
        if swappedOk then
            local registry = Fidelity.HookedMetaMethods
            if registry == nil then
                registry = {}
                Fidelity.HookedMetaMethods = registry
            end
            registry[replacementFunction] = {
                MetaTable = meta,
                MethodName = methodName,
                PreviousMethod = previous,
            }
        end
    end
    return previous
end
function Fidelity.RestoreHookedMetaMethod(targetFunction)
    local registry = Fidelity.HookedMetaMethods
    if type(registry) ~= "table" or type(targetFunction) ~= "function" then
        return false
    end
    local entry = registry[targetFunction]
    if entry == nil then
        return false
    end
    registry[targetFunction] = nil
    pcall(rawset, entry.MetaTable, entry.MethodName, entry.PreviousMethod)
    return true
end
function Fidelity.PrepareFinalOutput(recoveredText, submittedSourceText)
    if type(recoveredText) ~= "string" then
        return recoveredText
    end
    local finishedText = recoveredText
    local repairedOk, repairedResult = pcall(Fidelity.RepairDanglingAssignments, finishedText, submittedSourceText)
    if repairedOk and type(repairedResult) == "string" then
        finishedText = repairedResult
    end
    local balancedOk, balancedText = pcall(Fidelity.BalanceRecoveredBlocks, finishedText)
    if balancedOk and type(balancedText) == "string" then
        finishedText = balancedText
    end
    if Fidelity.CapChunkLocalRegisters ~= nil then
        local cappedOk, cappedResult = pcall(Fidelity.CapChunkLocalRegisters, finishedText)
        if cappedOk and type(cappedResult) == "string" then
            finishedText = cappedResult
        end
    end
    return finishedText
end
function Fidelity.SignalSuffixFor(signalObject)
    if type(signalObject) ~= "table" then
        return nil
    end
    local identity = Fidelity.SignalIdentity[signalObject]
    if type(identity) ~= "table" or type(identity.Name) ~= "string" then
        return nil
    end
    if identity.Kind == "attribute" then
        local attribute = string.match(identity.Name, ":(.+)$") or identity.Name
        return string.format(':GetAttributeChangedSignal("%s")', attribute)
    elseif identity.Kind == "property" and identity.Name ~= "Changed" then
        return string.format(':GetPropertyChangedSignal("%s")', identity.Name)
    end
    return "." .. identity.Name
end
function Fidelity.RenderDatatypeLiteral(ValueData)
    if type(ValueData) ~= "table" then
        return nil
    end
    local typeName = rawget(ValueData, "_Type")
    if type(typeName) ~= "string" then
        return nil
    end
    if typeName == "RBXScriptSignal" then
        local identity = Fidelity.SignalIdentity[ValueData]
        if type(identity) == "table" and type(identity.Name) == "string" then
            local ownerText = nil
            if identity.Owner ~= nil and Fidelity.DescribeInstance ~= nil then
                ownerText = Fidelity.DescribeInstance(identity.Owner)
            end
            if type(ownerText) == "string" and ownerText ~= "" then
                local suffix = Fidelity.SignalSuffixFor(ValueData)
                if suffix ~= nil then
                    return ownerText .. suffix
                end
            end
        end
        return nil
    end
    if typeName == "Vector3" then
        return string.format("Vector3.new(%s, %s, %s)",
            RenderScalar(RawField(ValueData, "X")),
            RenderScalar(RawField(ValueData, "Y")),
            RenderScalar(RawField(ValueData, "Z")))
    elseif typeName == "Vector2" then
        return string.format("Vector2.new(%s, %s)",
            RenderScalar(RawField(ValueData, "X")),
            RenderScalar(RawField(ValueData, "Y")))
    elseif typeName == "UDim" then
        return string.format("UDim.new(%s, %s)",
            RenderScalar(RawField(ValueData, "Scale")),
            RenderScalar(RawField(ValueData, "Offset")))
    elseif typeName == "UDim2" then
        local xAxis = RawField(ValueData, "X") or {}
        local yAxis = RawField(ValueData, "Y") or {}
        return string.format("UDim2.new(%s, %s, %s, %s)",
            RenderScalar(RawField(xAxis, "Scale")),
            RenderScalar(RawField(xAxis, "Offset")),
            RenderScalar(RawField(yAxis, "Scale")),
            RenderScalar(RawField(yAxis, "Offset")))
    elseif typeName == "Color3" then
        return string.format("Color3.new(%s, %s, %s)",
            RenderScalar(RawField(ValueData, "R")),
            RenderScalar(RawField(ValueData, "G")),
            RenderScalar(RawField(ValueData, "B")))
    elseif typeName == "CFrame" then
        local positionText = string.format("%s, %s, %s",
            RenderScalar(RawField(ValueData, "X")),
            RenderScalar(RawField(ValueData, "Y")),
            RenderScalar(RawField(ValueData, "Z")))
        if IsIdentityRotation(ValueData) then
            return "CFrame.new(" .. positionText .. ")"
        end
        local rotationText = string.format("%s, %s, %s, %s, %s, %s, %s, %s, %s",
            RenderScalar(RawField(ValueData, "R00")),
            RenderScalar(RawField(ValueData, "R01")),
            RenderScalar(RawField(ValueData, "R02")),
            RenderScalar(RawField(ValueData, "R10")),
            RenderScalar(RawField(ValueData, "R11")),
            RenderScalar(RawField(ValueData, "R12")),
            RenderScalar(RawField(ValueData, "R20")),
            RenderScalar(RawField(ValueData, "R21")),
            RenderScalar(RawField(ValueData, "R22")))
        return "CFrame.new(" .. positionText .. ", " .. rotationText .. ")"
    elseif typeName == "NumberRange" then
        return string.format("NumberRange.new(%s, %s)",
            RenderScalar(RawField(ValueData, "Min")),
            RenderScalar(RawField(ValueData, "Max")))
    elseif typeName == "Rect" then
        local minPoint = RawField(ValueData, "Min") or {}
        local maxPoint = RawField(ValueData, "Max") or {}
        return string.format("Rect.new(%s, %s, %s, %s)",
            RenderScalar(RawField(minPoint, "X")),
            RenderScalar(RawField(minPoint, "Y")),
            RenderScalar(RawField(maxPoint, "X")),
            RenderScalar(RawField(maxPoint, "Y")))
    elseif typeName == "Ray" then
        return string.format("Ray.new(%s, %s)",
            Fidelity.RenderDatatypeLiteral(RawField(ValueData, "Origin")) or "Vector3.new(0, 0, 0)",
            Fidelity.RenderDatatypeLiteral(RawField(ValueData, "Direction")) or "Vector3.new(0, 0, 0)")
    elseif typeName == "TweenInfo" then
        return string.format("TweenInfo.new(%s, Enum.EasingStyle.%s, Enum.EasingDirection.%s, %s, %s, %s)",
            RenderScalar(RawField(ValueData, "Time")),
            tostring(RawField(ValueData, "EasingStyle") and RawField(ValueData, "EasingStyle").Name or "Linear"),
            tostring(RawField(ValueData, "EasingDirection") and RawField(ValueData, "EasingDirection").Name or "InOut"),
            RenderScalar(RawField(ValueData, "RepeatCount")),
            RenderScalar(RawField(ValueData, "Reverses")),
            RenderScalar(RawField(ValueData, "DelayTime")))
    elseif typeName == "PhysicalProperties" then
        return string.format("PhysicalProperties.new(%s, %s, %s, %s, %s)",
            RenderScalar(RawField(ValueData, "Density")),
            RenderScalar(RawField(ValueData, "Friction")),
            RenderScalar(RawField(ValueData, "Elasticity")),
            RenderScalar(RawField(ValueData, "FrictionWeight")),
            RenderScalar(RawField(ValueData, "ElasticityWeight")))
    elseif typeName == "EnumItem" then
        return string.format("Enum.%s.%s",
            tostring(rawget(ValueData, "EnumTypeName")),
            tostring(rawget(ValueData, "Name")))
    elseif typeName == "EnumType" then
        return "Enum." .. tostring(ValueData)
    elseif typeName == "Vector3int16" then
        return string.format("Vector3int16.new(%s, %s, %s)",
            RenderScalar(RawField(ValueData, "X")),
            RenderScalar(RawField(ValueData, "Y")),
            RenderScalar(RawField(ValueData, "Z")))
    elseif typeName == "Vector2int16" then
        return string.format("Vector2int16.new(%s, %s)",
            RenderScalar(RawField(ValueData, "X")),
            RenderScalar(RawField(ValueData, "Y")))
    end
    return nil
end
Fidelity.World = World
Fidelity.ClassChain = {
    Part = { "BasePart" },
    MeshPart = { "BasePart" },
    UnionOperation = { "BasePart" },
    WedgePart = { "BasePart" },
    TrussPart = { "BasePart" },
    SpawnLocation = { "BasePart" },
    Hat = { "BasePart" },
    BasePart = { "PVInstance" },
    Model = {},
    Workspace = { "Model" },
    AnimationController = { "Animator" },
    CharacterController = { "Humanoid" },
    GuiBase2d = { "GuiBase" },
    GuiObject = { "GuiBase2d", "GuiBase" },
    GuiButton = { "GuiObject", "GuiBase2d", "GuiBase" },
    GuiText = { "GuiObject", "GuiBase2d", "GuiBase" },
    GuiImageLabel = { "GuiObject", "GuiBase2d", "GuiBase" },
    Frame = { "GuiObject", "GuiBase2d", "GuiBase" },
    ScrollingFrame = { "GuiObject", "GuiBase2d", "GuiBase" },
    ImageLabel = { "GuiImageLabel", "GuiObject", "GuiBase2d", "GuiBase" },
    ImageButton = { "GuiButton", "GuiImageLabel", "GuiObject", "GuiBase2d", "GuiBase" },
    TextLabel = { "GuiText", "GuiObject", "GuiBase2d", "GuiBase" },
    TextButton = { "GuiButton", "GuiText", "GuiObject", "GuiBase2d", "GuiBase" },
    TextBox = { "GuiText", "GuiObject", "GuiBase2d", "GuiBase" },
    ViewportFrame = { "GuiObject", "GuiBase2d", "GuiBase" },
    VideoFrame = { "GuiObject", "GuiBase2d", "GuiBase" },
    ScreenGui = { "LayerCollector", "GuiBase" },
    SurfaceGui = { "LayerCollector", "GuiBase" },
    BillboardGui = { "LayerCollector", "GuiBase" },
    Camera = { "DataModelMutable" },
}
Fidelity.ApiUtil = {}
function Fidelity.ApiUtil.bodyPartName(enumNameValue)
    local textValue = tostring(enumNameValue or "")
    if textValue == "Root" then
        return "HumanoidRootPart"
    end
    return (string.gsub(textValue, "R15$", ""))
end
function Fidelity.ApiUtil.childList(instance)
    if Fidelity.GetChildrenOf ~= nil then
        return Fidelity.GetChildrenOf(instance)
    end
    if instance ~= nil and instance.GetChildren ~= nil then
        return instance:GetChildren()
    end
    return {}
end
function Fidelity.ApiUtil.descendants(instance)
    local found, pending, guardCount = {}, { instance }, 0
    while #pending > 0 and guardCount < 4096 do
        guardCount += 1
        local current = table.remove(pending)
        if current ~= nil then
            for _, child in ipairs(Fidelity.ApiUtil.childList(current)) do
                found[#found + 1] = child
                pending[#pending + 1] = child
            end
        end
    end
    return found
end
function Fidelity.ApiUtil.numberOr(value, fallback)
    local numeric = tonumber(value)
    if numeric == nil then
        return fallback
    end
    return numeric
end
function Fidelity.ApiUtil.coordinate(value, axis, fallback)
    if value == nil then
        return fallback
    end
    local raw = rawget(value, axis)
    if raw == nil then
        raw = value[axis]
    end
    if raw == nil then
        raw = value[string.lower(axis)]
    end
    return tonumber(raw) or fallback
end
function Fidelity.ApiUtil.vectorOf(value)
    if value == nil then
        return 0, 0, 0
    end
    return Fidelity.ApiUtil.coordinate(value, "X", 0),
        Fidelity.ApiUtil.coordinate(value, "Y", 0),
        Fidelity.ApiUtil.coordinate(value, "Z", 0)
end
function Fidelity.ApiUtil.newVector(ctx, x, y, z)
    local factory = (ctx ~= nil and ctx.Vector3) or Fidelity.Vector3
    return factory.new(x or 0, y or 0, z or 0)
end
function Fidelity.ApiUtil.newCFrame(ctx, x, y, z)
    local factory = (ctx ~= nil and ctx.CFrame) or Fidelity.CFrame
    return factory.new(x or 0, y or 0, z or 0)
end
function Fidelity.ApiUtil.newColor(ctx, r, g, b)
    local factory = (ctx ~= nil and ctx.Color3) or Color3
    if factory ~= nil and factory.new ~= nil then
        return factory.new(r, g, b)
    end
    return { R = r, G = g, B = b, _Type = "Color3" }
end
function Fidelity.ApiUtil.isSpatial(object)
    if object == nil or type(object) ~= "table" then
        return false
    end
    local sizeX = Fidelity.ApiUtil.coordinate(object.Size, "X", nil)
    local posX = Fidelity.ApiUtil.coordinate(object.Position, "X", nil)
    return sizeX ~= nil and posX ~= nil
end
function Fidelity.ApiUtil.partsOf(instance)
    local parts = {}
    if instance == nil then
        return parts
    end
    if Fidelity.ApiUtil.isSpatial(instance) then
        parts[#parts + 1] = instance
    end
    for _, object in ipairs(Fidelity.ApiUtil.descendants(instance)) do
        if Fidelity.ApiUtil.isSpatial(object) then
            parts[#parts + 1] = object
        end
    end
    return parts
end
function Fidelity.ApiUtil.worldBounds(instance)
    local minX, minY, minZ, maxX, maxY, maxZ
    for _, part in ipairs(Fidelity.ApiUtil.partsOf(instance)) do
        local sizeX, sizeY, sizeZ = Fidelity.ApiUtil.vectorOf(part.Size)
        local posX, posY, posZ = Fidelity.ApiUtil.vectorOf(part.Position)
        local lowX, highX = posX - sizeX / 2, posX + sizeX / 2
        local lowY, highY = posY - sizeY / 2, posY + sizeY / 2
        local lowZ, highZ = posZ - sizeZ / 2, posZ + sizeZ / 2
        if minX == nil or lowX < minX then minX = lowX end
        if minY == nil or lowY < minY then minY = lowY end
        if minZ == nil or lowZ < minZ then minZ = lowZ end
        if maxX == nil or highX > maxX then maxX = highX end
        if maxY == nil or highY > maxY then maxY = highY end
        if maxZ == nil or highZ > maxZ then maxZ = highZ end
    end
    if minX == nil then
        return nil
    end
    return minX, minY, minZ, maxX, maxY, maxZ
end
function Fidelity.ApiUtil.shapecast(ctx, originValue, sizeValue, directionValue, paramsValue)
    local ox, oy, oz = Fidelity.ApiUtil.vectorOf(originValue)
    local sx, sy, sz = Fidelity.ApiUtil.vectorOf(sizeValue)
    local dx, dy, dz = Fidelity.ApiUtil.vectorOf(directionValue)
    local length = math.sqrt(dx * dx + dy * dy + dz * dz)
    if length == 0 then
        return nil
    end
    local stepSize = math.min(math.abs(sx), math.abs(sy), math.abs(sz))
    if stepSize <= 0 then
        stepSize = 1
    end
    stepSize = math.max(0.25, math.min(stepSize / 2, 4))
    local samples = math.ceil(length / stepSize)
    local unitX, unitY, unitZ = dx / length, dy / length, dz / length
    for sampleIndex = 0, samples do
        local travelled = math.min(length, sampleIndex * stepSize)
        local centerX = ox + unitX * travelled
        local centerY = oy + unitY * travelled
        local centerZ = oz + unitZ * travelled
        local hitParts = World.GetPartBoundsInBox(
            Fidelity.ApiUtil.newCFrame(ctx, centerX, centerY, centerZ),
            Fidelity.ApiUtil.newVector(ctx, sx, sy, sz), paramsValue)
        if #hitParts > 0 then
            return {
                Instance = hitParts[1],
                Position = Fidelity.ApiUtil.newVector(ctx, centerX, centerY, centerZ),
                Normal = Fidelity.ApiUtil.newVector(ctx, -unitX, -unitY, -unitZ),
                Material = hitParts[1].Material,
                Distance = travelled,
            }
        end
    end
    return nil
end
Fidelity.InstanceApis.Workspace = function(ctx)
    return {
        GetRealPhysicsFPS = function(_)
            return 60
        end,
        GetPhysicsThrottling = function(_)
            return 0
        end,
        PGSIsEnabled = function(_)
            return false
        end,
        GetNumAwakeParts = function(_)
            local awakeCount = 0
            for _, part in ipairs(World.ListParts()) do
                if part.Anchored ~= true then
                    awakeCount += 1
                end
            end
            return awakeCount
        end,
        ArePartsTouchingOthers = function(_, partList, _)
            if type(partList) ~= "table" then
                return false
            end
            for _, part in ipairs(partList) do
                if #World.TouchingParts(part) > 0 then
                    return true
                end
            end
            return false
        end,
        Blockcast = function(_, cframeValue, sizeValue, directionValue, paramsValue)
            local originX, originY, originZ = Fidelity.ApiUtil.vectorOf(cframeValue)
            return Fidelity.ApiUtil.shapecast(ctx,
                Fidelity.ApiUtil.newVector(ctx, originX, originY, originZ),
                sizeValue, directionValue, paramsValue)
        end,
        Spherecast = function(_, originValue, radiusValue, directionValue, paramsValue)
            local radius = Fidelity.ApiUtil.numberOr(radiusValue, 1)
            return Fidelity.ApiUtil.shapecast(ctx, originValue,
                Fidelity.ApiUtil.newVector(ctx, radius * 2, radius * 2, radius * 2),
                directionValue, paramsValue)
        end,
    }
end
Fidelity.InstanceApis.BasePart = function(ctx)
    return {
        GetConnectedParts = function(self, recursiveValue)
            local result = {}
            if recursiveValue == false then
                return result
            end
            for _, member in ipairs(World.AssemblyMembers(self)) do
                if member ~= self then
                    result[#result + 1] = member
                end
            end
            return result
        end,
        GetJoints = function(self)
            local joints = {}
            for jointObject, binding in next, World.Joints do
                if binding.Part0 == self or binding.Part1 == self then
                    joints[#joints + 1] = jointObject
                end
            end
            return joints
        end,
        GetAssemblyCoveredFaces = function(self)
            return {}
        end,
        GetVelocityAtPosition = function(self, positionValue)
            local velocityX, velocityY, velocityZ = Fidelity.ApiUtil.vectorOf(self.AssemblyLinearVelocity)
            local angularX, angularY, angularZ = Fidelity.ApiUtil.vectorOf(self.AssemblyAngularVelocity)
            local partX, partY, partZ = Fidelity.ApiUtil.vectorOf(self.Position)
            local radiusX = Fidelity.ApiUtil.coordinate(positionValue, "X", partX) - partX
            local radiusY = Fidelity.ApiUtil.coordinate(positionValue, "Y", partY) - partY
            local radiusZ = Fidelity.ApiUtil.coordinate(positionValue, "Z", partZ) - partZ
            return Fidelity.ApiUtil.newVector(ctx,
                velocityX + angularY * radiusZ - angularZ * radiusY,
                velocityY + angularZ * radiusX - angularX * radiusZ,
                velocityZ + angularX * radiusY - angularY * radiusX)
        end,
        IsGrounded = function(self)
            local _, minY = Fidelity.ApiUtil.worldBounds(self)
            if minY == nil then
                return false
            end
            for _, other in ipairs(World.TouchingParts(self)) do
                local _, _, _, _, otherMaxY = Fidelity.ApiUtil.worldBounds(other)
                if otherMaxY ~= nil and otherMaxY <= minY + 0.5 then
                    return true
                end
            end
            return false
        end,
        GetNoCollisionConstraints = function(self)
            local found = {}
            for _, child in ipairs(Fidelity.ApiUtil.descendants(self)) do
                if child.ClassName == "NoCollisionConstraint" then
                    found[#found + 1] = child
                end
            end
            return found
        end,
        SetNetworkOwner = function(self, playerValue)
            rawset(self, "Owner", playerValue)
            return true
        end,
        SetNetworkOwnerCanSimulateDeletion = function(_, playerValue, flagValue)
            rawset(playerValue, "_v1SimulateDeletion", flagValue == true)
            return true
        end,
        SetCanCollide = function(self, flagValue)
            self.CanCollide = flagValue ~= false
            return true
        end,
        SetMassConstraintsEnabled = function(self, flagValue)
            rawset(self, "_v1MassConstraints", flagValue == true)
            return true
        end,
    }
end
Fidelity.InstanceApis.Model = function(ctx)
    return {
        GetExtentsSize = function(self)
            local minX, minY, minZ, maxX, maxY, maxZ = Fidelity.ApiUtil.worldBounds(self)
            if minX == nil then
                return Fidelity.ApiUtil.newVector(ctx, 0, 0, 0)
            end
            return Fidelity.ApiUtil.newVector(ctx, maxX - minX, maxY - minY, maxZ - minZ)
        end,
        GetScale = function(self)
            return Fidelity.ApiUtil.numberOr(rawget(self, "_v1Scale"), 1)
        end,
        ScaleTo = function(self, scaleValue)
            local target = Fidelity.ApiUtil.numberOr(scaleValue, 1)
            local current = Fidelity.ApiUtil.numberOr(rawget(self, "_v1Scale"), 1)
            local factor = target / (current == 0 and 1 or current)
            rawset(self, "_v1Scale", target)
            local pivotX, pivotY, pivotZ = Fidelity.ApiUtil.vectorOf(self:GetPivot())
            for _, part in ipairs(Fidelity.ApiUtil.partsOf(self)) do
                local sizeX, sizeY, sizeZ = Fidelity.ApiUtil.vectorOf(part.Size)
                local posX, posY, posZ = Fidelity.ApiUtil.vectorOf(part.Position)
                part.Size = Fidelity.ApiUtil.newVector(ctx, sizeX * factor, sizeY * factor, sizeZ * factor)
                part.CFrame = Fidelity.ApiUtil.newCFrame(ctx,
                    pivotX + (posX - pivotX) * factor,
                    pivotY + (posY - pivotY) * factor,
                    pivotZ + (posZ - pivotZ) * factor)
            end
            return true
        end,
        TranslateBy = function(self, offsetValue)
            local offsetX, offsetY, offsetZ = Fidelity.ApiUtil.vectorOf(offsetValue)
            local pivotX, pivotY, pivotZ = Fidelity.ApiUtil.vectorOf(self:GetPivot())
            self:PivotTo(Fidelity.ApiUtil.newCFrame(ctx, pivotX + offsetX, pivotY + offsetY, pivotZ + offsetZ))
            return true
        end,
        GetModelInPreparationState = function(_)
            return false
        end,
        WaitForParts = function(_)
            return true
        end,
    }
end
Fidelity.InstanceApis.Terrain = function(ctx)
    if Fidelity.MaterialColors == nil then
        Fidelity.MaterialColors = {}
    end
    local function materialName(materialValue)
        if materialValue == nil then
            return ""
        end
        return tostring(materialValue.Name or materialValue)
    end
    local stockColors = {
        Grass = { 0.3843137, 0.5254902, 0.2313725 },
        Dirt = { 0.4745098, 0.3411765, 0.2156863 },
        Stone = { 0.5921569, 0.5921569, 0.5921569 },
        Sand = { 0.8196078, 0.7843137, 0.5450980 },
        Snow = { 0.9254902, 0.9254902, 0.9254902 },
        Mud = { 0.4745098, 0.3607843, 0.2549020 },
        Bedrock = { 0.0392157, 0.0392157, 0.0392157 },
        Glacier = { 0.4941176, 0.7411765, 0.9215686 },
        Basalt = { 0.2588235, 0.2588235, 0.2588235 },
        Limestone = { 0.8588235, 0.8509804, 0.7647059 },
    }
    return {
        GetMaterialColor = function(self, materialValue)
            local name = materialName(materialValue)
            if name == "Air" or name == "Water" then
                error("Material cannot have its color changed: " .. name, 0)
            end
            local stored = Fidelity.MaterialColors[name]
            if stored ~= nil then
                return stored
            end
            local stock = stockColors[name] or { 0.5, 0.5, 0.5 }
            return Fidelity.ApiUtil.newColor(ctx, stock[1], stock[2], stock[3])
        end,
        SetMaterialColor = function(self, materialValue, colorValue)
            local name = materialName(materialValue)
            if name == "Air" or name == "Water" then
                error("Material cannot have its color changed: " .. name, 0)
            end
            Fidelity.MaterialColors[name] = colorValue
            return true
        end,
        GetMaterial = function(self, xValue, yValue, zValue)
            return Fidelity.EnumValue("Material", "Air", 128)
        end,
        ReadVoxels = function(self, regionValue, voxelSizeValue)
            local cell = Fidelity.ApiUtil.numberOr(voxelSizeValue, 4)
            if cell <= 0 then
                cell = 4
            end
            local sizeX, sizeY, sizeZ = Fidelity.ApiUtil.vectorOf(regionValue ~= nil and regionValue.Size or nil)
            local dims = {
                math.max(1, math.floor(sizeX / cell + 0.5)),
                math.max(1, math.floor(sizeY / cell + 0.5)),
                math.max(1, math.floor(sizeZ / cell + 0.5)),
            }
            local airItem = Fidelity.EnumValue("Material", "Air", 128)
            local materials = { Size = dims, _Type = "TerrainMaterials" }
            local occupancies = { Size = dims, _Type = "TerrainOccupancies" }
            for xIndex = 1, dims[1] do
                materials[xIndex] = {}
                occupancies[xIndex] = {}
                for yIndex = 1, dims[2] do
                    materials[xIndex][yIndex] = {}
                    occupancies[xIndex][yIndex] = {}
                    for zIndex = 1, dims[3] do
                        materials[xIndex][yIndex][zIndex] = airItem
                        occupancies[xIndex][yIndex][zIndex] = 0
                    end
                end
            end
            return materials, occupancies
        end,
        WriteVoxels = function(self, regionValue, materialsValue, occupanciesValue)
            return true
        end,
        FillBlock = function(self, cframeValue, sizeValue, materialValue, invertValue)
            return true
        end,
    }
end
Fidelity.InstanceApis.Animator = function(ctx)
    return {
        LoadAnimation = function(self, animationValue)
            if ctx.Instance == nil then
                return nil
            end
            local track = ctx.Instance("AnimationTrack")
            rawset(track, "Animation", animationValue)
            rawset(track, "Length", 1)
            rawset(track, "TimePosition", 0)
            rawset(track, "WeightCurrent", 1)
            rawset(track, "WeightTarget", 1)
            rawset(track, "WeightSpeed", 0)
            rawset(track, "Speed", 1)
            rawset(track, "IsLooped", false)
            rawset(track, "IsPlaying", false)
            local playing = rawget(self, "_v1Tracks")
            if playing == nil then
                playing = {}
                rawset(self, "_v1Tracks", playing)
            end
            playing[#playing + 1] = track
            return track
        end,
        GetPlayingAnimationTracks = function(self)
            local stored = rawget(self, "_v1Tracks")
            if stored == nil then
                return {}
            end
            local visible = {}
            for _, track in ipairs(stored) do
                if track.IsPlaying == true then
                    visible[#visible + 1] = track
                end
            end
            return visible
        end,
        ApplyJointVelocities = function(_, jointValue, velocityValue)
            return true
        end,
    }
end
Fidelity.InstanceApis.AnimationTrack = function(ctx)
    return {
        Play = function(self, fadeTimeValue, weightValue, speedValue)
            rawset(self, "IsPlaying", true)
            rawset(self, "TimePosition", 0)
            if speedValue ~= nil then
                rawset(self, "Speed", speedValue)
            end
            if weightValue ~= nil then
                rawset(self, "WeightTarget", weightValue)
            end
            return true
        end,
        Stop = function(self, fadeTimeValue)
            rawset(self, "IsPlaying", false)
            return true
        end,
        AdjustTimeScale = function(self, scaleValue)
            rawset(self, "Speed", Fidelity.ApiUtil.numberOr(scaleValue, 1))
            return true
        end,
        AdjustSpeed = function(self, speedValue)
            rawset(self, "Speed", Fidelity.ApiUtil.numberOr(speedValue, 1))
            return true
        end,
        AdjustWeight = function(self, weightValue)
            rawset(self, "WeightTarget", Fidelity.ApiUtil.numberOr(weightValue, 1))
            return true
        end,
        SetTimeScale = function(self, scaleValue)
            rawset(self, "Speed", Fidelity.ApiUtil.numberOr(scaleValue, 1))
            return true
        end,
    }
end
Fidelity.InstanceApis.Humanoid = function(ctx)
    local members = {
        GetLimb = function(self, partValue)
            local limbName = "Other"
            if partValue ~= nil then
                local partName = tostring(partValue.Name or "")
                if partName == "HumanoidRootPart" then
                    limbName = "Root"
                elseif partName == "Head" then
                    limbName = "Head"
                elseif string.find(partName, "UpperTorso", 1, true) then
                    limbName = "Torso"
                elseif string.find(partName, "Left", 1, true) and string.find(partName, "Arm", 1, true) then
                    limbName = "LeftArm"
                elseif string.find(partName, "Right", 1, true) and string.find(partName, "Arm", 1, true) then
                    limbName = "RightArm"
                elseif string.find(partName, "Left", 1, true) and string.find(partName, "Leg", 1, true) then
                    limbName = "LeftLeg"
                elseif string.find(partName, "Right", 1, true) and string.find(partName, "Leg", 1, true) then
                    limbName = "RightLeg"
                end
            end
            return Fidelity.EnumValue("Limb", limbName, 0)
        end,
        GetOverallPhysicsPlaybackSpeed = function(_)
            return 1
        end,
        SetStateEnabled = function(self, stateValue, flagValue)
            local states = rawget(self, "_v1States")
            if states == nil then
                states = {}
                rawset(self, "_v1States", states)
            end
            states[tostring(stateValue and stateValue.Name or stateValue)] = flagValue == true
            return true
        end,
        IsStateEnabled = function(self, stateValue)
            local states = rawget(self, "_v1States")
            if states == nil then
                return true
            end
            local flag = states[tostring(stateValue and stateValue.Name or stateValue)]
            if flag == nil then
                return true
            end
            return flag
        end,
        MoveTo = function(self, positionValue)
            rawset(self, "_v1MoveTarget", positionValue)
            return true
        end,
        GetState = function(self)
            return Fidelity.EnumValue("HumanoidStateType", rawget(self, "_v1State") or "Freefall", 5)
        end,
        ChangeState = function(self, stateValue)
            rawset(self, "_v1State", tostring(stateValue and stateValue.Name or stateValue))
            return stateValue
        end,
        GetAccessories = function(_)
            return {}
        end,
        GetEnabledStates = function(_)
            return {}
        end,
        GetAppliedDescription = function(self)
            if ctx.Instance == nil then
                return nil
            end
            local description = ctx.Instance("HumanoidDescription")
            for _, scaleName in ipairs({ "HeightScale", "WidthScale", "DepthScale", "HeadScale",
                "BodyTypeScale", "ProportionScale" }) do
                rawset(description, scaleName, 1)
            end
            for _, colorName in ipairs({ "HeadColor", "TorsoColor", "LeftArmColor", "RightArmColor",
                "LeftLegColor", "RightLegColor" }) do
                rawset(description, colorName, Fidelity.ApiUtil.newColor(ctx, 1, 1, 1))
            end
            rawset(description, "SkinColor", Fidelity.ApiUtil.newColor(ctx, 1, 1, 1))
            rawset(description, "Face", 0)
            return description
        end,
        GetDebugHealthPath = function(_)
            return {}
        end,
        GetStateEnabled = function(self, stateValue)
            return self:IsStateEnabled(stateValue)
        end,
        Move = function(self, directionValue)
            rawset(self, "MoveDirection", directionValue)
            return true
        end,
        GetBodyPartR15 = function(self, partTypeValue)
            local wantedName = tostring(partTypeValue and partTypeValue.Name or partTypeValue)
            local characterValue = rawget(self, "Parent")
            if characterValue == nil or wantedName == "nil" then
                return nil
            end
            local suffix = Fidelity.ApiUtil.bodyPartName(wantedName)
            for _, child in ipairs(Fidelity.ApiUtil.childList(characterValue)) do
                if child.Name == suffix then
                    return child
                end
            end
            return nil
        end,
    }
    local rigMembers = {
        RigType = Fidelity.EnumValue("HumanoidRigType", "R6", 2),
        FloorMaterial = Fidelity.EnumValue("Material", "Plastic", 256),
        HealthDisplayType = Fidelity.EnumValue("HealthDisplayType", "AlwaysShow", 0),
        HealthDisplayDistanceLimit = Fidelity.EnumValue("HealthDisplayDistanceLimit", "ShowAllHealth", 1),
        CameraOffset = Fidelity.ApiUtil.newVector(ctx, 0, 0, 0),
        MoveDirection = Fidelity.ApiUtil.newVector(ctx, 0, 0, 0),
        HipHeight = 0,
        MaxSlopeAngle = 89,
        EvaluateStateMachine = false,
        Jump = false,
        Sit = false,
        WalkFrontFactor = 1,
    }
    for memberName, memberValue in next, rigMembers do
        members[memberName] = memberValue
    end
    if ctx.Signal ~= nil then
        members.Died = ctx.Signal("Died", nil)
        members.HealthChanged = ctx.Signal("HealthChanged", nil)
        members.StateChanged = ctx.Signal("StateChanged", nil)
        members.Running = ctx.Signal("Running", nil)
        members.Jumping = ctx.Signal("Jumping", nil)
        members.Freefall = ctx.Signal("Freefall", nil)
        members.Seated = ctx.Signal("Seated", nil)
        members.Climbing = ctx.Signal("Climbing", nil)
        members.Swimming = ctx.Signal("Swimming", nil)
        members.PlatformStand = ctx.Signal("PlatformStand", nil)
        members.Damage = ctx.Signal("Damage", nil)
        members.Heal = ctx.Signal("Heal", nil)
    end
    return members
end
Fidelity.InstanceApis.Teams = function(ctx)
    return {
        GetTeams = function(self)
            local teams = {}
            for _, child in ipairs(Fidelity.ApiUtil.childList(self)) do
                if child.ClassName == "Team" then
                    teams[#teams + 1] = child
                end
            end
            return teams
        end,
    }
end
Fidelity.InstanceApis.Team = function(ctx)
    local members = {
        GetPlayers = function(self)
            local players = {}
            for _, child in ipairs(Fidelity.ApiUtil.descendants(self)) do
                if child._Type == "Player" or child.ClassName == "Player" then
                    players[#players + 1] = child
                end
            end
            return players
        end,
    }
    if ctx.Signal ~= nil then
        members.PlayerAdded = ctx.Signal("PlayerAdded", nil)
        members.PlayerRemoved = ctx.Signal("PlayerRemoved", nil)
    end
    return members
end
Fidelity.InstanceApis.Stats = function(ctx)
    return {
        GetTotalMemoryUsageMb = function(self)
            local partCount = 0
            if World.PartCount ~= nil then
                partCount = World.PartCount()
            end
            return 12 + partCount * 0.0031
        end,
        GetMemoryUsageMbForTag = function(self, tagValue)
            return 0.5
        end,
        GetCounters = function(self)
            return {}
        end,
    }
end
Fidelity.InstanceApis.Debris = function(ctx)
    return {
        AddItem = function(self, itemValue, delayValue)
            if itemValue == nil then
                return true
            end
            if Fidelity.DebrisQueue == nil then
                Fidelity.DebrisQueue = {}
            end
            Fidelity.DebrisQueue[itemValue] = Fidelity.Clock.PhysicsTime
                + Fidelity.ApiUtil.numberOr(delayValue, Fidelity.ApiUtil.numberOr(itemValue.TimeToLive, 10))
            return true
        end,
        Remove = function(self, itemValue)
            if Fidelity.DebrisQueue ~= nil then
                Fidelity.DebrisQueue[itemValue] = nil
            end
            return true
        end,
    }
end
function Fidelity.FlushScheduledDestruction()
    local queue = Fidelity.DebrisQueue
    if queue == nil then
        return
    end
    local now = Fidelity.Clock.PhysicsTime
    for item, dueTime in next, queue do
        if now >= dueTime then
            queue[item] = nil
            if item.Destroy ~= nil then
                item:Destroy()
            elseif item.Parent ~= nil then
                rawset(item, "Parent", nil)
            end
        end
    end
end
Fidelity.InstanceApis.RunService = function(ctx)
    local members = {
        IsClient = function(_) return true end,
        IsServer = function(_) return true end,
        IsStudio = function(_) return false end,
        IsRunning = function(_) return true end,
        IsRunMode = function(_) return true end,
        IsEdit = function(_) return false end,
        IsAppMode = function(_) return false end,
        SetSimulationRate = function(_, rateValue) return rateValue end,
        GetStreamedRegion = function(_) return nil end,
    }
    return members
end
Fidelity.InstanceApis.GuiService = function(ctx)
    local function vector2Value(xValue, yValue)
        local factory = (ctx ~= nil and ctx.Vector2) or Fidelity.Vector2
        if factory == nil then
            return { X = xValue, Y = yValue, _Type = "Vector2" }
        end
        return factory.new(xValue, yValue)
    end
    return {
        GetGuiInset = function(self)
            return vector2Value(0, 0), vector2Value(0, 0)
        end,
        GetLayoutBounds = function(self)
            return vector2Value(0, 0), vector2Value(1920, 1080)
        end,
        IsTenFootInterface = function(self)
            return false
        end,
        GetEmotesMenuOpen = function(self)
            return false
        end,
        SetEmotesMenuOpen = function(self, flagValue)
            rawset(self, "_v1EmotesMenuOpen", flagValue == true)
            return true
        end,
        GetDeviceOrientation = function(self)
            return Fidelity.EnumValue("DeviceOrientation", "LandscapeRight", 3)
        end,
        SafeZoneInset = vector2Value(0, 0),
        MenuIsOpen = false,
        TouchControlsEnabled = true,
        AutoSelectGuiEnabled = true,
        ScreenGuiDensity = 1,
    }
end
Fidelity.InstanceApis.TextService = function(ctx)
    return {
        GetTextSize = function(self, textValue, fontSizeValue, fontEnumValue, boundsValue)
            local characterCount = #(tostring(textValue or ""))
            local fontSize = Fidelity.ApiUtil.numberOr(fontSizeValue, 18)
            local boundsX = Fidelity.ApiUtil.coordinate(boundsValue, "X", 1000)
            local boundsY = Fidelity.ApiUtil.coordinate(boundsValue, "Y", 100)
            local factory = (ctx ~= nil and ctx.Vector2) or Fidelity.Vector2
            local width = math.min(boundsX, characterCount * fontSize * 0.5)
            local height = fontSize * 1.35
            if factory ~= nil and factory.new ~= nil then
                return factory.new(math.max(width, 1), height)
            end
            return { X = math.max(width, 1), Y = height, _Type = "Vector2" }
        end,
        GetTextBounds = function(self, textValue, fontSizeValue, fontEnumValue, boundsValue)
            return self:GetTextSize(textValue, fontSizeValue, fontEnumValue, boundsValue)
        end,
        GetTextBoundsAsync = function(self, textParametersValue)
            return { await = function() return self:GetTextSize("", 18, nil, nil) end }
        end,
        FilterStringAsync = function(self, textValue)
            return {
                await = function()
                    return {
                        IsValidText = true,
                        IsFilteredText = false,
                        DisplayedText = tostring(textValue or ""),
                    }
                end,
            }
        end,
    }
end
Fidelity.InstanceApis.SoundService = function(ctx)
    return {
        GetListener = function(self)
            return Fidelity.EnumValue("ListenerType", "Camera", 0), nil
        end,
        SetListener = function(self, listenerTypeValue, listenerObjectValue)
            rawset(self, "_v1ListenerType", listenerTypeValue)
            rawset(self, "_v1ListenerObject", listenerObjectValue)
            return true
        end,
        PlayLocalSound = function(self, soundIdValue)
            return true
        end,
        GetMixerTime = function(self)
            return Fidelity.Clock.ElapsedTime()
        end,
        SetSoundTypeClassifierModel = function(self)
            return nil
        end,
        DistanceFactor = 0.562341326,
        DopplerScale = 1,
        RolloffScale = 1,
        VolumeFactor = 1,
        RespectFilteringEnabled = true,
    }
end
Fidelity.InstanceApis.Lighting = function(ctx)
    return {
        GetSunDirection = function(self)
            local clockTime = Fidelity.ApiUtil.numberOr(self.ClockTime, 14)
            local angle = (clockTime - 6) / 12 * math.pi
            local factory = (ctx ~= nil and ctx.Vector3) or Fidelity.Vector3
            return factory.new(math.cos(angle), math.sin(angle), 0)
        end,
        GetMoonDirection = function(self)
            local sunValue = self:GetSunDirection()
            local factory = (ctx ~= nil and ctx.Vector3) or Fidelity.Vector3
            return factory.new(-sunValue.X, -sunValue.Y, -sunValue.Z)
        end,
        GetMoonIntensity = function(self)
            return Fidelity.ApiUtil.numberOr(self.MoonIntensity, 0.05)
        end,
        GetSunIntensity = function(self)
            return Fidelity.ApiUtil.numberOr(self.SunIntensity, 0.6)
        end,
        GetMoonPhase = function(self)
            local clockTime = Fidelity.ApiUtil.numberOr(rawget(self, "ClockTime"), 14)
            return (clockTime % 24) / 24
        end,
        GetSendableLights = function(self)
            return {}
        end,
        GetInstances = function(self)
            local collected = {}
            for _, child in ipairs(Fidelity.ApiUtil.childList(self)) do
                collected[#collected + 1] = child
            end
            return collected
        end,
    }
end
local characterRig = {
    { Name = "HumanoidRootPart", Size = { 2, 2, 1 }, Position = { 0, 3, 0 } },
    { Name = "Torso", Size = { 2, 2, 1 }, Position = { 0, 3, 0 } },
    { Name = "Head", Size = { 2, 1, 1 }, Position = { 0, 4.5, 0 } },
    { Name = "Left Arm", Size = { 1, 2, 1 }, Position = { -1.5, 3, 0 } },
    { Name = "Right Arm", Size = { 1, 2, 1 }, Position = { 1.5, 3, 0 } },
    { Name = "Left Leg", Size = { 1, 2, 1 }, Position = { -0.5, 1, 0 } },
    { Name = "Right Leg", Size = { 1, 2, 1 }, Position = { 0.5, 1, 0 } },
}
function Fidelity.BuildCharacterRig(playerInstance, characterInstance, humanoidInstance, animatorInstance)
    local context = Fidelity.InstanceApiContext
    if context == nil or context.Instance == nil or characterInstance == nil then
        return false
    end
    if rawget(characterInstance, "_v1RigBuilt") == nil then
        rawset(characterInstance, "_v1RigBuilt", true)
        local builtParts = {}
        for _, spec in ipairs(characterRig) do
            local partInstance = context.Instance("Part")
            rawset(partInstance, "Name", spec.Name)
            rawset(partInstance, "Size", Fidelity.ApiUtil.newVector(context, spec.Size[1], spec.Size[2], spec.Size[3]))
            rawset(partInstance, "CFrame", Fidelity.ApiUtil.newCFrame(context,
                spec.Position[1], spec.Position[2], spec.Position[3]))
            rawset(partInstance, "Position", Fidelity.ApiUtil.newVector(context,
                spec.Position[1], spec.Position[2], spec.Position[3]))
            rawset(partInstance, "Anchored", true)
            rawset(partInstance, "__V1_PARENT_VALUE", characterInstance)
            Fidelity.RegisterChild(characterInstance, partInstance)
            builtParts[spec.Name] = partInstance
        end
        if humanoidInstance ~= nil then
            rawset(humanoidInstance, "Name", "Humanoid")
            rawset(humanoidInstance, "__V1_PARENT_VALUE", characterInstance)
            rawset(humanoidInstance, "RootPart", builtParts.HumanoidRootPart)
            rawset(humanoidInstance, "MaxHealth", 100)
            rawset(humanoidInstance, "Health", 100)
            Fidelity.RegisterChild(characterInstance, humanoidInstance)
            if animatorInstance ~= nil then
                rawset(animatorInstance, "__V1_PARENT_VALUE", humanoidInstance)
                Fidelity.RegisterChild(humanoidInstance, animatorInstance)
            end
            for _, childName in ipairs({ "Animator" }) do
                if rawget(humanoidInstance, childName) == nil then
                    rawset(humanoidInstance, childName, animatorInstance)
                end
            end
        end
        local bodyColorsInstance = context.Instance("BodyColors")
        rawset(bodyColorsInstance, "Name", "Body Colors")
        rawset(bodyColorsInstance, "__V1_PARENT_VALUE", characterInstance)
        if context.BrickColor ~= nil then
            local skinColor = context.BrickColor.new("Medium stone grey")
            for _, colorName in ipairs({ "HeadColor", "TorsoColor", "LeftArmColor", "RightArmColor",
                "LeftLegColor", "RightLegColor" }) do
                rawset(bodyColorsInstance, colorName, skinColor)
            end
        end
        Fidelity.RegisterChild(characterInstance, bodyColorsInstance)
        local appearanceInstance = context.Instance("CharacterAppearance")
        rawset(appearanceInstance, "Name", "CharacterAppearance")
        rawset(appearanceInstance, "__V1_PARENT_VALUE", characterInstance)
        Fidelity.RegisterChild(characterInstance, appearanceInstance)
        for _, accessoryClass in ipairs({ "Shirt", "Pants" }) do
            local accessoryInstance = context.Instance(accessoryClass)
            rawset(accessoryInstance, "Name", accessoryClass)
            rawset(accessoryInstance, "__V1_PARENT_VALUE", characterInstance)
            Fidelity.RegisterChild(characterInstance, accessoryInstance)
        end
    end
    if playerInstance ~= nil then
        rawset(playerInstance, "Character", characterInstance)
    end
    return true
end
function Fidelity.BuildWorkspaceCharacter(characterInstance, workspaceInstance)
    if characterInstance == nil or workspaceInstance == nil then
        return false
    end
    if rawget(characterInstance, "__V1_PARENT_VALUE") == nil then
        rawset(characterInstance, "__V1_PARENT_VALUE", workspaceInstance)
        Fidelity.RegisterChild(workspaceInstance, characterInstance)
    end
    if rawget(characterInstance, "_v1RigPlaced") == nil then
        rawset(characterInstance, "_v1RigPlaced", true)
        local placedParts = {}
        local lowestY = math.huge
        for _, childValue in ipairs(Fidelity.ApiUtil.childList(characterInstance)) do
            local sizeValue = childValue ~= nil and rawget(childValue, "Size") or nil
            local frameValue = childValue ~= nil and childValue.CFrame or nil
            if type(sizeValue) == "table" and type(frameValue) == "table"
                and type(frameValue.X) == "number" then
                local halfHeight = (sizeValue.Y or 0) / 2
                local bottomY = (frameValue.Y or 0) - halfHeight
                placedParts[#placedParts + 1] = { childValue, frameValue }
                if bottomY < lowestY then
                    lowestY = bottomY
                end
            end
        end
        if lowestY ~= math.huge and lowestY ~= 0.5 then
            local lift = 0.5 - lowestY
            for _, entry in ipairs(placedParts) do
                local partValue, frameValue = entry[1], entry[2]
                pcall(function()
                    local movedFrame = Fidelity.CFrame.new(
                        frameValue.X, (frameValue.Y or 0) + lift, frameValue.Z)
                    partValue.CFrame = movedFrame
                    rawset(partValue, "Position", Fidelity.ApiUtil.newVector(
                        Fidelity.InstanceApiContext, frameValue.X,
                        (frameValue.Y or 0) + lift, frameValue.Z))
                end)
            end
        end
    end
    return true
end
function Fidelity.SeedKnownServiceChildren(ServiceObject, ServiceName, CreateInstanceFunction)
    if ServiceObject == nil or type(ServiceObject) ~= "table" then return end
    if CreateInstanceFunction == nil or ServiceObject.FindFirstChild == nil then return end
    if ServiceName == "CoreGui" and ServiceObject:FindFirstChild("RobloxGui") == nil then
        local RobloxGuiObject = CreateInstanceFunction("ScreenGui")
        RobloxGuiObject.Name = "RobloxGui"
        RobloxGuiObject.Parent = ServiceObject
    end
    if ServiceName == "InsertService" and ServiceObject:FindFirstChild("InsertionHash") == nil then
        local HashObject = CreateInstanceFunction("StringValue")
        HashObject.Name = "InsertionHash"
        HashObject.Value = "00000000-0000-4000-8000-000000000000"
        HashObject.Parent = ServiceObject
    end
end
function Fidelity.SeedLightingChildren(lightingInstance)
    if lightingInstance == nil or rawget(lightingInstance, "_v1SkySeeded") ~= nil then
        return false
    end
    if Fidelity.InstanceApiContext == nil or Fidelity.InstanceApiContext.Instance == nil then
        return false
    end
    rawset(lightingInstance, "_v1SkySeeded", true)
    for _, className in ipairs({ "Sky", "Atmosphere", "ColorCorrection", "Bloom", "BlurEffect" }) do
        local childInstance = Fidelity.InstanceApiContext.Instance(className)
        rawset(childInstance, "Name", className)
        Fidelity.RegisterChild(lightingInstance, childInstance)
    end
    return true
end
Fidelity.InstanceApis.ContextActionService = function(ctx)
    local function actionTable(self)
        local bound = rawget(self, "_v1BoundActions")
        if bound == nil then
            bound = {}
            rawset(self, "_v1BoundActions", bound)
        end
        return bound
    end
    return {
        BindAction = function(self, actionNameValue, functionValue, createTouchValue, ...)
            actionTable(self)[tostring(actionNameValue)] = {
                Name = tostring(actionNameValue),
                Callback = functionValue,
                Priority = nil,
                Touch = createTouchValue == true,
                Loaded = true,
            }
            return true
        end,
        BindActionAtPriority = function(self, actionNameValue, functionValue, createTouchValue, priorityValue, ...)
            actionTable(self)[tostring(actionNameValue)] = {
                Callback = functionValue,
                Priority = priorityValue,
                Touch = createTouchValue == true,
            }
            return true
        end,
        BindEnumAction = function(self, enumValue, functionValue, createTouchValue, ...)
            actionTable(self)[tostring(enumValue and enumValue.Name or enumValue)] = {
                Callback = functionValue,
            }
            return true
        end,
        UnbindAction = function(self, actionNameValue)
            actionTable(self)[tostring(actionNameValue)] = nil
            return true
        end,
        UnbindActionAtPriority = function(self, actionNameValue, priorityValue)
            actionTable(self)[tostring(actionNameValue)] = nil
            return true
        end,
        UnbindEnumAction = function(self, enumValue)
            actionTable(self)[tostring(enumValue and enumValue.Name or enumValue)] = nil
            return true
        end,
        GetActionBound = function(self, actionNameValue)
            return actionTable(self)[tostring(actionNameValue)] ~= nil
        end,
        GetBoundActionInfo = function(self, actionNameValue)
            local bound = actionTable(self)[tostring(actionNameValue)]
            if bound == nil then
                return {}
            end
            return bound
        end,
        GetAllBoundActionInfo = function(self)
            local collected = {}
            for _, bound in next, actionTable(self) do
                collected[#collected + 1] = bound
            end
            return collected
        end,
        SetRegisterTouchButtonVisible = function(self, actionNameValue, flagValue)
            return true
        end,
        SetRegisterTouchButtonEnabled = function(self, actionNameValue, flagValue)
            return true
        end,
        FireTouchInput = function(self, actionNameValue)
            local bound = actionTable(self)[tostring(actionNameValue)]
            if bound ~= nil and type(bound.Callback) == "function" then
                pcall(bound.Callback, actionNameValue)
            end
            return true
        end,
    }
end
Fidelity.InstanceApis.SharedTableRegistry = function(ctx)
    return {
        GetSharedTable = function(self, tableNameValue)
            if Fidelity.SharedTables == nil then
                Fidelity.SharedTables = {}
            end
            local key = tostring(tableNameValue)
            local existing = Fidelity.SharedTables[key]
            if existing == nil then
                existing = { _Type = "SharedTable", __V1_TYPE = "SharedTable", _v1Name = key }
                Fidelity.SharedTables[key] = existing
            end
            return existing
        end,
        SetSharedTable = function(self, tableNameValue, tableValue)
            if Fidelity.SharedTables == nil then
                Fidelity.SharedTables = {}
            end
            local key = tostring(tableNameValue)
            if tableValue == nil then
                Fidelity.SharedTables[key] = nil
                return true
            end
            Fidelity.SharedTables[key] = tableValue
            return true
        end,
        GetSharedString = function(self, keyNameValue)
            if Fidelity.SharedStrings == nil then
                return nil
            end
            return Fidelity.SharedStrings[tostring(keyNameValue)]
        end,
        SetSharedString = function(self, keyNameValue, stringValue)
            if Fidelity.SharedStrings == nil then
                Fidelity.SharedStrings = {}
            end
            Fidelity.SharedStrings[tostring(keyNameValue)] = stringValue
            return true
        end,
    }
end
Fidelity.InstanceApis.Pose = function(ctx)
    return {
        AddSubPose = function(self, childValue)
            if childValue == nil then
                return nil
            end
            local ok = pcall(function() childValue.Parent = self end)
            if not ok then
                rawset(childValue, "Parent", self)
            end
            return nil
        end,
        RemoveSubPose = function(self, childValue)
            if childValue == nil then
                return nil
            end
            local ok = pcall(function() childValue.Parent = nil end)
            if not ok then
                rawset(childValue, "Parent", nil)
            end
            return nil
        end,
    }
end
Fidelity.InstanceApis.AssetService = function(ctx)
    local function newEditableImage(paramsValue)
        local sizeValue = type(paramsValue) == "table" and paramsValue.Size or nil
        local width, height = 4, 4
        if sizeValue ~= nil then
            local scaleX = tonumber(sizeValue.X) or tonumber(sizeValue.x)
            local scaleY = tonumber(sizeValue.Y) or tonumber(sizeValue.y)
            if scaleX ~= nil and scaleX > 0 then width = math.floor(scaleX + 0.5) end
            if scaleY ~= nil and scaleY > 0 then height = math.floor(scaleY + 0.5) end
        end
        local bytesPerRow = width * 4
        local pixels = {}
        for rowIndex = 1, height do
            local row = {}
            for byteIndex = 1, bytesPerRow do
                row[byteIndex] = 0
            end
            pixels[rowIndex] = row
        end
        local versionTag = 0
        local image = {
            __V1_TYPE = "EditableImage",
            _Type = "EditableImage",
            PixelCount = width * height,
        }
        if Fidelity.ApiUtil ~= nil and Fidelity.ApiUtil.newVector ~= nil then
            image.Size = Fidelity.ApiUtil.newVector(ctx, width, height)
        end
        local function regionOf(positionValue, regionValue)
            local originX, originY = 0, 0
            if type(positionValue) == "table" then
                originX = math.floor(tonumber(positionValue.X) or tonumber(positionValue.x) or 0)
                originY = math.floor(tonumber(positionValue.Y) or tonumber(positionValue.y) or 0)
            end
            local regionWidth, regionHeight = 1, 1
            if type(regionValue) == "table" then
                regionWidth = math.max(1, math.floor(tonumber(regionValue.X) or tonumber(regionValue.x) or 1))
                regionHeight = math.max(1, math.floor(tonumber(regionValue.Y) or tonumber(regionValue.y) or 1))
            end
            return originX, originY, regionWidth, regionHeight
        end
        image.ReadPixelsBuffer = function(self, positionValue, regionValue)
            local originX, originY, regionWidth, regionHeight = regionOf(positionValue, regionValue)
            local result = buffer.create(regionWidth * regionHeight * 4)
            local offset = 0
            for rowOffset = 0, regionHeight - 1 do
                local storedRow = pixels[originY + rowOffset + 1]
                for column = 0, regionWidth * 4 - 1 do
                    local byteValue = storedRow ~= nil and storedRow[originX * 4 + column + 1] or 0
                    buffer.writeu8(result, offset, byteValue or 0)
                    offset = offset + 1
                end
            end
            return result
        end
        image.WritePixelsBuffer = function(self, positionValue, regionValue, bufferValue)
            local originX, originY, regionWidth, regionHeight = regionOf(positionValue, regionValue)
            local ok, bytes = pcall(buffer.tostring, bufferValue)
            if not ok then
                return false
            end
            local byteIndex = 1
            for rowOffset = 0, regionHeight - 1 do
                local storedRow = pixels[originY + rowOffset + 1]
                for column = 0, regionWidth * 4 - 1 do
                    local byteValue = string.byte(bytes, byteIndex) or 0
                    byteIndex = byteIndex + 1
                    if storedRow ~= nil and originX * 4 + column + 1 <= bytesPerRow then
                        storedRow[originX * 4 + column + 1] = byteValue
                    end
                end
            end
            versionTag = versionTag + 1
            return true
        end
        image.GetVersionTag = function(self)
            return versionTag
        end
        image.IsLoaded = function(self)
            return true
        end
        image.Destroy = function(self)
            for rowIndex in next, pixels do
                pixels[rowIndex] = nil
            end
            return true
        end
        return image
    end
    return {
        CreateEditableImage = function(self, paramsValue)
            return newEditableImage(paramsValue)
        end,
        CreateEditableImageAsync = function(self, paramsValue)
            return newEditableImage(paramsValue)
        end,
        IsEditableImageLoaded = function(self, imageValue)
            return type(imageValue) == "table" and rawget(imageValue, "__V1_TYPE") == "EditableImage"
        end,
    }
end
local SharedTableRecords = setmetatable({}, { __mode = "k" })
local function SharedTableRecord(SharedTableObject, FunctionName)
    local Record = SharedTableRecords[SharedTableObject]
    if Record == nil then
        error("bad argument #1 to '" .. FunctionName .. "' (SharedTable expected, got "
            .. type(SharedTableObject) .. ")", 0)
    end
    return Record
end
local function SharedTableCheckKey(Key)
    if type(Key) ~= "number" and type(Key) ~= "string" then
        error("attempt to use " .. type(Key) .. " as a SharedTable key; only numbers and "
            .. "strings are shareable across the boundary", 0)
    end
end
local function SharedTableCheckValue(Value)
    local Kind = type(Value)
    if Kind == "function" or Kind == "thread" or Kind == "userdata" then
        error("attempt to store " .. Kind .. " in a SharedTable; a " .. Kind
            .. " cannot be shared across the boundary", 0)
    end
end
local function SharedTableCount(Values)
    local Count = 0
    for _ in next, Values do
        Count += 1
    end
    return Count
end
Fidelity.SharedTableLibrary = {}
function Fidelity.SharedTableLibrary.new(InitialValue)
    if InitialValue ~= nil and type(InitialValue) ~= "table" then
        error("bad argument #1 to 'new' (table expected, got " .. type(InitialValue) .. ")", 0)
    end
    local Values = {}
    local SharedTableObject = { __V1_TYPE = "SharedTable", _Type = "SharedTable" }
    SharedTableRecords[SharedTableObject] = { values = Values, frozen = false }
    if InitialValue ~= nil then
        for Key, Value in next, InitialValue do
            if Key ~= "__V1_TYPE" and Key ~= "_Type" then
                SharedTableCheckKey(Key)
                SharedTableCheckValue(Value)
                Values[Key] = Fidelity.SharedTableLibrary.wrap(Value)
            end
        end
    end
    return setmetatable(SharedTableObject, {
        __index = function(_, Key)
            return Values[Key]
        end,
        __newindex = function(_, Key, Value)
            local Record = SharedTableRecords[SharedTableObject]
            if Record.frozen then
                error("attempted to write to a frozen SharedTable", 0)
            end
            SharedTableCheckKey(Key)
            SharedTableCheckValue(Value)
            Values[Key] = Fidelity.SharedTableLibrary.wrap(Value)
        end,
        __len = function()
            return SharedTableCount(Values)
        end,
        __tostring = function()
            return "SharedTable"
        end,
    })
end
function Fidelity.SharedTableLibrary.wrap(Value)
    if type(Value) == "table" and SharedTableRecords[Value] == nil then
        return Fidelity.SharedTableLibrary.new(Value)
    end
    return Value
end
function Fidelity.SharedTableLibrary.isSharedTable(Value)
    return type(Value) == "table" and SharedTableRecords[Value] ~= nil
end
function Fidelity.SharedTableLibrary.size(SharedTableObject)
    return SharedTableCount(SharedTableRecord(SharedTableObject, "size").values)
end
function Fidelity.SharedTableLibrary.clear(SharedTableObject)
    local Record = SharedTableRecord(SharedTableObject, "clear")
    if Record.frozen then
        error("attempted to write to a frozen SharedTable", 0)
    end
    for Key in next, Record.values do
        Record.values[Key] = nil
    end
end
function Fidelity.SharedTableLibrary.clone(SharedTableObject, IsDeep)
    local Record = SharedTableRecord(SharedTableObject, "clone")
    local Copy = Fidelity.SharedTableLibrary.new()
    for Key, Value in next, Record.values do
        if IsDeep == true and SharedTableRecords[Value] ~= nil then
            Copy[Key] = Fidelity.SharedTableLibrary.clone(Value, true)
        else
            Copy[Key] = Value
        end
    end
    return Copy
end
function Fidelity.SharedTableLibrary.cloneAndFreeze(SharedTableObject, IsDeep)
    local DeepCopy = IsDeep == true
    local Copy = Fidelity.SharedTableLibrary.clone(SharedTableObject, DeepCopy)
    local function FreezeTree(TargetObject)
        local Record = SharedTableRecord(TargetObject, "cloneAndFreeze")
        Record.frozen = true
        if not DeepCopy then
            return
        end
        for _, Value in next, Record.values do
            if SharedTableRecords[Value] ~= nil then
                FreezeTree(Value)
            end
        end
    end
    FreezeTree(Copy)
    return Copy
end
function Fidelity.SharedTableLibrary.freeze(SharedTableObject)
    SharedTableRecord(SharedTableObject, "freeze").frozen = true
end
function Fidelity.SharedTableLibrary.isFrozen(SharedTableObject)
    return SharedTableRecord(SharedTableObject, "isFrozen").frozen == true
end
function Fidelity.SharedTableLibrary.increment(SharedTableObject, Key, StepValue)
    local Record = SharedTableRecord(SharedTableObject, "increment")
    if Record.frozen then
        error("attempted to write to a frozen SharedTable", 0)
    end
    local CurrentValue = Record.values[Key]
    if type(CurrentValue) ~= "number" then
        error("cannot increment a SharedTable value that is not a number (got "
            .. type(CurrentValue) .. ")", 0)
    end
    local StepNumber = tonumber(StepValue)
    if StepNumber == nil then
        error("bad argument #3 to 'increment' (number expected, got "
            .. type(StepValue) .. ")", 0)
    end
    Record.values[Key] = CurrentValue + StepNumber
    return CurrentValue
end
function Fidelity.SharedTableLibrary.update(SharedTableObject, Key, UpdateFunction)
    local Record = SharedTableRecord(SharedTableObject, "update")
    if Record.frozen then
        error("attempted to write to a frozen SharedTable", 0)
    end
    if type(UpdateFunction) ~= "function" then
        error("bad argument #3 to 'update' (function expected, got "
            .. type(UpdateFunction) .. ")", 0)
    end
    Record.values[Key] = Fidelity.SharedTableLibrary.wrap(UpdateFunction(Record.values[Key]))
    return Record.values[Key]
end
function Fidelity.SynthesisedInstanceName(classNameValue, counterValue)
    local name = tostring(classNameValue or "")
    if string.match(name, "^[%a][%w_]*$") == nil then
        name = "Instance"
    end
    return name .. "_" .. tostring(counterValue or 0)
end
Fidelity.InstanceApis.CollectionService = function(ctx)
    return {
        GetAllTags = function(self)
            local registry = rawget(self, "_v1Tags")
            local tags = {}
            if registry == nil then
                return tags
            end
            for tagName in next, registry do
                tags[#tags + 1] = tagName
            end
            return tags
        end,
        GetTagged = function(self, tagNameValue)
            local registry = rawget(self, "_v1Tags")
            local tagged = {}
            if registry == nil then
                return tagged
            end
            local bucket = registry[tostring(tagNameValue)]
            if bucket == nil then
                return tagged
            end
            for object in next, bucket do
                tagged[#tagged + 1] = object
            end
            return tagged
        end,
    }
end
Fidelity.InstanceApis.FloatCurve = function(ctx)
    local function keysOf(self)
        local keys = rawget(self, "_v1Keys")
        if keys == nil then
            keys = {}
            rawset(self, "_v1Keys", keys)
        end
        return keys
    end
    local function publish(self)
        local keys = keysOf(self)
        rawset(self, "Length", #keys)
        table.sort(keys, function(left, right)
            return Fidelity.ApiUtil.numberOr(left.Time, 0) < Fidelity.ApiUtil.numberOr(right.Time, 0)
        end)
    end
    return {
        InsertKey = function(self, keyValue)
            local keys = keysOf(self)
            keys[#keys + 1] = keyValue
            publish(self)
            return true
        end,
        AddKey = function(self, keyValue)
            return self:InsertKey(keyValue)
        end,
        RemoveKeyAtIndex = function(self, indexValue)
            local keys = keysOf(self)
            table.remove(keys, Fidelity.ApiUtil.numberOr(indexValue, 1))
            publish(self)
            return true
        end,
        GetKeyAtIndex = function(self, indexValue)
            local keys = keysOf(self)
            return keys[Fidelity.ApiUtil.numberOr(indexValue, 1)]
        end,
        GetKeys = function(self)
            local keys = keysOf(self)
            local copy = {}
            for index, keyValue in ipairs(keys) do
                copy[index] = keyValue
            end
            return copy
        end,
        GetValueAtTime = function(self, timeValue)
            local keys = keysOf(self)
            local count = #keys
            if count == 0 then
                return 0
            end
            local time = Fidelity.ApiUtil.numberOr(timeValue, 0)
            if time <= Fidelity.ApiUtil.numberOr(keys[1].Time, 0) then
                return Fidelity.ApiUtil.numberOr(keys[1].Value, 0)
            end
            if time >= Fidelity.ApiUtil.numberOr(keys[count].Time, 0) then
                return Fidelity.ApiUtil.numberOr(keys[count].Value, 0)
            end
            for index = 1, count - 1 do
                local left, right = keys[index], keys[index + 1]
                local leftTime = Fidelity.ApiUtil.numberOr(left.Time, 0)
                local rightTime = Fidelity.ApiUtil.numberOr(right.Time, 0)
                if time >= leftTime and time <= rightTime then
                    local span = rightTime - leftTime
                    local leftValue = Fidelity.ApiUtil.numberOr(left.Value, 0)
                    local rightValue = Fidelity.ApiUtil.numberOr(right.Value, 0)
                    if span <= 0 then
                        return leftValue
                    end
                    local interpolation = left.Interpolation
                    local modeName = interpolation ~= nil and tostring(interpolation.Name or interpolation) or "Linear"
                    if modeName == "Constant" then
                        return leftValue
                    end
                    local alpha = (time - leftTime) / span
                    if modeName == "Cubic" then
                        alpha = alpha * alpha * (3 - 2 * alpha)
                    end
                    return leftValue + (rightValue - leftValue) * alpha
                end
            end
            return Fidelity.ApiUtil.numberOr(keys[count].Value, 0)
        end,
    }
end
Fidelity.InstanceApis.Keyframe = function(ctx)
    local function posesOf(self)
        local poses = rawget(self, "_v1Poses")
        if poses == nil then
            poses = {}
            rawset(self, "_v1Poses", poses)
        end
        return poses
    end
    return {
        AddPose = function(self, poseValue)
            local poses = posesOf(self)
            poses[#poses + 1] = poseValue
            return true
        end,
        GetPoses = function(self)
            local poses = posesOf(self)
            local copy = {}
            for index, poseValue in ipairs(poses) do
                copy[index] = poseValue
            end
            return copy
        end,
        SetPoseWeight = function(self, poseValue, weightValue)
            poseValue.Weight = weightValue
            return true
        end,
        FindPoseForTarget = function(self, targetValue)
            for _, poseValue in ipairs(posesOf(self)) do
                if poseValue.Name == targetValue then
                    return poseValue
                end
            end
            return nil
        end,
    }
end
Fidelity.InstanceApis.KeyframeSequence = function(ctx)
    local function keysOf(self)
        local keys = rawget(self, "_v1Keyframes")
        if keys == nil then
            keys = {}
            rawset(self, "_v1Keyframes", keys)
        end
        return keys
    end
    return {
        AddKeyframe = function(self, keyframeValue)
            local keys = keysOf(self)
            keys[#keys + 1] = keyframeValue
            return true
        end,
        GetKeyframes = function(self)
            local keys = keysOf(self)
            local copy = {}
            for index, keyframeValue in ipairs(keys) do
                copy[index] = keyframeValue
            end
            return copy
        end,
        RemoveKeyframe = function(self, keyframeValue)
            local keys = keysOf(self)
            for index = #keys, 1, -1 do
                if keys[index] == keyframeValue then
                    table.remove(keys, index)
                end
            end
            return true
        end,
        SortByKeyframeNodes = function(self)
            local keys = keysOf(self)
            table.sort(keys, function(left, right)
                return Fidelity.ApiUtil.numberOr(left.Time, 0) < Fidelity.ApiUtil.numberOr(right.Time, 0)
            end)
            return true
        end,
    }
end
Fidelity.InstanceApis.Path2D = function(ctx)
    local function pointsOf(self)
        local points = rawget(self, "_v1Points")
        if points == nil then
            points = {}
            rawset(self, "_v1Points", points)
        end
        return points
    end
    local function screenSpace(self, pointValue)
        local sizeValue = self.AbsoluteSize
        local width = Fidelity.ApiUtil.coordinate(sizeValue, "X", 500)
        local height = Fidelity.ApiUtil.coordinate(sizeValue, "Y", 500)
        local positionValue = pointValue ~= nil and pointValue.Position or nil
        local xAxis = positionValue ~= nil and positionValue.X or nil
        local yAxis = positionValue ~= nil and positionValue.Y or nil
        return width * Fidelity.ApiUtil.coordinate(xAxis, "Scale", 0)
                + Fidelity.ApiUtil.coordinate(xAxis, "Offset", 0),
            height * Fidelity.ApiUtil.coordinate(yAxis, "Scale", 0)
                + Fidelity.ApiUtil.coordinate(yAxis, "Offset", 0)
    end
    local function pointAt(self, alphaValue)
        local points = pointsOf(self)
        local count = #points
        if count == 0 then
            return 0, 0
        end
        if count == 1 then
            return screenSpace(self, points[1])
        end
        local alpha = math.max(0, math.min(1, Fidelity.ApiUtil.numberOr(alphaValue, 0)))
        local position = alpha * (count - 1)
        local segment = math.min(math.floor(position), count - 1)
        local localAlpha = position - segment
        local ax, ay = screenSpace(self, points[segment + 1])
        local bx, by = screenSpace(self, points[segment + 2])
        return ax + (bx - ax) * localAlpha, ay + (by - ay) * localAlpha
    end
    local function curveLength(self)
        local points = pointsOf(self)
        local total = 0
        for index = 1, #points - 1 do
            local ax, ay = screenSpace(self, points[index])
            local bx, by = screenSpace(self, points[index + 1])
            total += math.sqrt((bx - ax) * (bx - ax) + (by - ay) * (by - ay))
        end
        return total
    end
    local members = {
        SetControlPoints = function(self, pointsValue)
            local points = pointsOf(self)
            for index = #points, 1, -1 do
                points[index] = nil
            end
            for index, pointValue in ipairs(type(pointsValue) == "table" and pointsValue or {}) do
                points[#points + 1] = pointValue
            end
            rawset(self, "ControlPointCount", #points)
            return true
        end,
        GetControlPoints = function(self)
            local points = pointsOf(self)
            local copy = {}
            for index, pointValue in ipairs(points) do
                copy[index] = pointValue
            end
            return copy
        end,
        GetControlPoint = function(self, indexValue)
            return pointsOf(self)[Fidelity.ApiUtil.numberOr(indexValue, 1)]
        end,
        GetMaxControlPoints = function(self)
            return 500
        end,
        InsertControlPoint = function(self, indexValue, pointValue)
            local points = pointsOf(self)
            table.insert(points, Fidelity.ApiUtil.numberOr(indexValue, #points + 1), pointValue)
            rawset(self, "ControlPointCount", #points)
            return true
        end,
        RemoveControlPoint = function(self, indexValue)
            local points = pointsOf(self)
            table.remove(points, Fidelity.ApiUtil.numberOr(indexValue, 1))
            rawset(self, "ControlPointCount", #points)
            return true
        end,
        UpdateControlPoint = function(self, indexValue, pointValue)
            local points = pointsOf(self)
            points[Fidelity.ApiUtil.numberOr(indexValue, 1)] = pointValue
            return true
        end,
        GetPositionOnCurve = function(self, alphaValue)
            local pointX, pointY = pointAt(self, alphaValue)
            return Fidelity.MakeUdim2FromPixels(self, pointX, pointY)
        end,
        GetTangentOnCurve = function(self, alphaValue)
            local beforeX, beforeY = pointAt(self, math.max(0, (alphaValue or 0) - 0.01))
            local afterX, afterY = pointAt(self, math.min(1, (alphaValue or 0) + 0.01))
            local factory = (ctx ~= nil and ctx.Vector2) or Fidelity.Vector2
            if factory ~= nil and factory.new ~= nil then
                local tangentX, tangentY = afterX - beforeX, afterY - beforeY
                local length = math.sqrt(tangentX * tangentX + tangentY * tangentY)
                if length == 0 then
                    return factory.new(1, 0)
                end
                return factory.new(tangentX / length, tangentY / length)
            end
            return { X = 1, Y = 0, _Type = "Vector2" }
        end,
        GetLength = function(self)
            return curveLength(self)
        end,
        GetBoundingRect = function(self)
            local minX, minY, maxX, maxY
            for _, pointValue in ipairs(pointsOf(self)) do
                local pointX, pointY = screenSpace(self, pointValue)
                if minX == nil or pointX < minX then minX = pointX end
                if minY == nil or pointY < minY then minY = pointY end
                if maxX == nil or pointX > maxX then maxX = pointX end
                if maxY == nil or pointY > maxY then maxY = pointY end
            end
            return Fidelity.MakeRectFromCorners(minX or 0, minY or 0, maxX or 0, maxY or 0)
        end,
    }
    if ctx.Signal ~= nil then
        members.ControlPointChanged = ctx.Signal("ControlPointChanged", nil)
    end
    return members
end
function Fidelity.MakeUdim2FromPixels(instance, xValue, yValue)
    local width = Fidelity.ApiUtil.coordinate(instance.AbsoluteSize, "X", 500)
    local height = Fidelity.ApiUtil.coordinate(instance.AbsoluteSize, "Y", 500)
    local factory = Fidelity.UDim2
    if factory ~= nil and factory.new ~= nil then
        return factory.new(0, xValue, 0, yValue)
    end
    return { X = { Scale = 0, Offset = xValue }, Y = { Scale = 0, Offset = yValue }, _Type = "UDim2" }
end
function Fidelity.MakeRectFromCorners(minXValue, minYValue, maxXValue, maxYValue)
    local vectorFactory = Fidelity.Vector2
    local pointMin, pointMax
    if vectorFactory ~= nil and vectorFactory.new ~= nil then
        pointMin = vectorFactory.new(minXValue, minYValue)
        pointMax = vectorFactory.new(maxXValue, maxYValue)
    else
        pointMin = { X = minXValue, Y = minYValue }
        pointMax = { X = maxXValue, Y = maxYValue }
    end
    return { Min = pointMin, Max = pointMax, Width = maxXValue - minXValue, Height = maxYValue - minYValue, _Type = "Rect" }
end
Fidelity.InstanceApis.LocalizationService = function(ctx)
    return {
        RobloxLocaleId = "en-us",
        SystemLocaleId = "en-us",
        UsingTranslationTables = false,
        ForceUnits = "metric",
        GetTranslation = function(self, keyNameValue)
            return nil
        end,
        SetUsingTranslationTables = function(self, flagValue)
            rawset(self, "UsingTranslationTables", flagValue == true)
            return true
        end,
    }
end
Fidelity.InstanceApis.Camera = function(ctx)
    return {
        CameraType = Fidelity.EnumValue("CameraType", "Custom", 0),
        FieldOfView = 70,
        MinFieldOfView = 1,
        MaxFieldOfView = 120,
        FocusDistance = 100,
        NearPlane = 0.1,
        FarPlane = 10000,
        CFrame = (ctx.CFrame or Fidelity.CFrame).new(0, 0, 0),
        GetRenderCFrame = function(self)
            return self.CFrame
        end,
        GetRankOrder = function(self)
            return 128
        end,
        WorldToScreen = function(self, positionValue)
            local vectorFactory = ctx.Vector3 or Fidelity.Vector3
            local sizeValue = self.ViewportSize
            local widthX = Fidelity.ApiUtil.coordinate(sizeValue, "X", 1920)
            local widthY = Fidelity.ApiUtil.coordinate(sizeValue, "Y", 1080)
            local pointX = Fidelity.ApiUtil.coordinate(positionValue, "X", 0)
            local pointY = Fidelity.ApiUtil.coordinate(positionValue, "Y", 0)
            local pointZ = Fidelity.ApiUtil.coordinate(positionValue, "Z", 1)
            local depth = math.max(pointZ, 0.001)
            if ctx.Vector2 ~= nil then
                return ctx.Vector2.new(widthX / 2 + pointX / depth, widthY / 2 - pointY / depth), true
            end
            return { X = widthX / 2, Y = widthY / 2, _Type = "Vector2" }, true
        end,
        ScreenToWorld = function(self, xValue, yValue, sizeValue)
            local vectorFactory = ctx.Vector3 or Fidelity.Vector3
            local widthX = Fidelity.ApiUtil.coordinate(sizeValue, "X", 1920)
            local widthY = Fidelity.ApiUtil.coordinate(sizeValue, "Y", 1080)
            local ndcX = ((Fidelity.ApiUtil.numberOr(xValue, 0) - widthX / 2) / widthX)
            local ndcY = ((Fidelity.ApiUtil.numberOr(yValue, 0) - widthY / 2) / widthY) * -1
            return vectorFactory.new(ndcX, ndcY, 0)
        end,
        PointToViewport = function(self, positionValue)
            local vectorFactory = ctx.Vector3 or Fidelity.Vector3
            return vectorFactory.new(
                Fidelity.ApiUtil.coordinate(positionValue, "X", 0),
                Fidelity.ApiUtil.coordinate(positionValue, "Y", 0),
                math.max(Fidelity.ApiUtil.coordinate(positionValue, "Z", 1), 0.001))
        end,
        ViewportToPoint = function(self, positionValue, sizeValue)
            local vectorFactory = ctx.Vector3 or Fidelity.Vector3
            return vectorFactory.new(
                Fidelity.ApiUtil.coordinate(positionValue, "X", 0),
                Fidelity.ApiUtil.coordinate(positionValue, "Y", 0),
                Fidelity.ApiUtil.coordinate(positionValue, "Z", 1))
        end,
    }
end
Fidelity.InstanceApis.Sky = function(ctx)
    return {
        StarCount = 1000,
        CelestialBodiesShown = true,
        SkyboxBk = "", SkyboxDn = "", SkyboxFt = "", SkyboxLf = "",
        SkyboxRt = "", SkyboxUp = "",
        MoonTextureId = "rbxasset://sky/Moon.png",
        SunTextureId = "rbxasset://sky/Sun.png",
        StarTexture = "rbxasset://sky/stars.png",
        Atmosphere = nil,
        GetProperties = function(self)
            return {}
        end,
    }
end
Fidelity.InstanceApis.Atmosphere = function(ctx)
    return {
        Color = Fidelity.ApiUtil.newColor(ctx, 0.6431372549019608, 0.7411764705882353, 0.8117647058823529),
        Density = 0.5,
        Offset = 0.25,
        AbsoluteHeight = 500,
        ColorShift = Fidelity.ApiUtil.newColor(ctx, 0, 0, 0),
        Haze = 0,
        LightColor = Fidelity.ApiUtil.newColor(ctx, 1, 1, 1),
        LightInfluence = 0.2,
        GetProperties = function(self)
            return {}
        end,
    }
end
Fidelity.InstanceApis.ColorCorrection = function(ctx)
    return {
        Brightness = 0,
        Contrast = 0,
        Saturation = 0,
        TintColor = Fidelity.ApiUtil.newColor(ctx, 1, 1, 1),
    }
end
Fidelity.InstanceApis.Bloom = function(ctx)
    return {
        Size = 24,
        Intensity = 0.5,
        Threshold = 2,
    }
end
Fidelity.InstanceApis.BlurEffect = function(ctx)
    return {
        Size = 18,
    }
end
Fidelity.InstanceApis.InsertService = function(ctx)
    return {
        InsertionHash = "00000000-0000-4000-8000-000000000000",
        GetLocalAssetIdToMeshId = function(self)
            return {}
        end,
        GetMeshIdToAssetId = function(self, assetIdValue)
            return nil
        end,
        SetLocalAssetIdToMeshId = function(self, assetIdValue, meshIdValue)
            return true
        end,
        DisconnectAssetRegistry = function(self)
            return true
        end,
        GetMission = function(self)
            return nil
        end,
    }
end
Fidelity.InstanceApis.Sound = function(ctx)
    return {
        Play = function(self)
            rawset(self, "IsPlaying", true)
            return true
        end,
        PlayDelayed = function(self, delayValue)
            rawset(self, "IsPlaying", true)
            return true
        end,
        PlayOnRemove = function(self)
            rawset(self, "IsPlaying", true)
            return true
        end,
        Stop = function(self, fadeTimeValue)
            rawset(self, "IsPlaying", false)
            return true
        end,
        IsLoaded = function(self)
            return true
        end,
        GetIsPlaying = function(self)
            return rawget(self, "IsPlaying") == true
        end,
    }
end
function Fidelity.MeasureFrameDelta()
    local clock = Fidelity.Clock
    if clock == nil or type(clock.ElapsedTime) ~= "function" then
        return 1 / 60
    end
    local nowSeconds = clock.ElapsedTime()
    local previous = clock.LastFrameAt
    clock.LastFrameAt = nowSeconds
    local delta = 1 / 60
    if type(previous) == "number" then
        delta = nowSeconds - previous
    end
    if delta < 1 / 240 then
        delta = 1 / 240
    elseif delta > 1 / 15 then
        delta = 1 / 15
    end
    clock.LastDelta = delta
    return delta
end
function Fidelity.MakeSteppedWait(signalName)
    return function(signalObject)
        if signalObject == nil or type(signalObject) ~= "table" or rawget(signalObject, "Wait") == nil then
            error("bad argument #1 to 'Wait' (RBXScriptSignal expected, got " .. tostring(signalObject) .. ")", 2)
        end
        if Fidelity.Clock == nil or Fidelity.Clock.Step == nil then
            return 1 / 60
        end
        Fidelity.Clock.Step(1 / 60)
        local frameDelta = Fidelity.MeasureFrameDelta()
        if Fidelity.FireSignals ~= nil and not Fidelity.InSteppedFire then
            Fidelity.InSteppedFire = true
            Fidelity.FireSignals(signalName, frameDelta)
            Fidelity.InSteppedFire = false
        end
        if signalName == "Stepped" then
            return Fidelity.Clock.PhysicsTime, frameDelta
        end
        return frameDelta
    end
end
Fidelity.InstanceApis.PlayerGui = function(ctx)
    return {
        ScreenOrientation = Fidelity.EnumValue("ScreenOrientation", "Landscape", 2),
        CurrentScreenOrientation = Fidelity.EnumValue("ScreenOrientation", "Landscape", 2),
        ResetPlayerGuiOnSpawn = true,
        ShowDevelopmentGui = true,
    }
end
Fidelity.InstanceApis.Stats = function(ctx)
    local function lastFrameTime()
        if Fidelity.Clock ~= nil and type(Fidelity.Clock.LastDelta) == "number" then
            return Fidelity.Clock.LastDelta
        end
        return 1 / 60
    end
    local function heapMb()
        local ok, countValue = pcall(collectgarbage, "count")
        if ok and type(countValue) == "number" and countValue > 0 then
            return countValue / 1024
        end
        return 1
    end
    local function primitiveCount()
        if Fidelity.World ~= nil and Fidelity.World.PartCount ~= nil then
            local ok, countValue = pcall(Fidelity.World.PartCount)
            if ok and type(countValue) == "number" then
                return countValue
            end
        end
        return 0
    end
    return {
        InstanceCount = 1,
        PrimitivesCount = primitiveCount(),
        MovingPrimitivesCount = 0,
        ContactsCount = 0,
        DataReceiveKbps = 0,
        DataSendKbps = 0,
        PhysicsStepTime = lastFrameTime(),
        HeartbeatTime = lastFrameTime(),
        FrameTime = lastFrameTime(),
        RenderCPUFrameTime = lastFrameTime(),
        RenderGPUFrameTime = lastFrameTime(),
        SceneDrawcallCount = 0,
        SceneTriangleCount = 0,
        UI2DDrawcallCount = 0,
        UI3DDrawcallCount = 0,
        ShadowsDrawcallCount = 0,
        MemoryTrackingEnabled = true,
        GetTotalMemoryUsageMb = function()
            return heapMb()
        end,
        GetMemoryUsageMbForTag = function(self, tagValue)
            return heapMb() / 8
        end,
        GetChildren = function(self)
            return {}
        end,
    }
end
Fidelity.InstanceApis.Tween = function(ctx)
    return {
        IsA = function(self, classNameValue)
            local targetName = tostring(classNameValue)
            if targetName == "Tween" or targetName == "TweenBase" or targetName == "Instance" then
                return true
            end
            return false
        end,
        Destroy = function(self)
            if self.Cancel ~= nil then
                self:Cancel()
            end
            rawset(self, "_v1Destroyed", true)
            return true
        end,
    }
end
Fidelity.InstanceApis.Player = function(ctx)
    return {
        GetNetworkPing = function(self)
            return 0.064
        end,
        GetMouse = function(self)
            local cachedMouse = rawget(self, "_v1Mouse")
            if cachedMouse ~= nil then
                return cachedMouse
            end
            if ctx.Instance == nil then
                return nil
            end
            local mouse = ctx.Instance("Mouse")
            rawset(mouse, "X", 960)
            rawset(mouse, "Y", 540)
            rawset(mouse, "ViewSizeX", 1920)
            rawset(mouse, "ViewSizeY", 1080)
            local vectorFactory = (ctx ~= nil and ctx.Vector3) or Fidelity.Vector3
            if ctx.Ray ~= nil then
                rawset(mouse, "UnitRay", ctx.Ray.new(vectorFactory.new(0, 0, 0), vectorFactory.new(0, 0, -1)))
            else
                rawset(mouse, "UnitRay", {
                    Origin = vectorFactory.new(0, 0, 0),
                    Direction = vectorFactory.new(0, 0, -1),
                    _Type = "Ray",
                })
            end
            rawset(mouse, "Hit", (ctx.CFrame or Fidelity.CFrame).new(0, 0, 0))
            if ctx.Signal ~= nil then
                rawset(mouse, "Move", ctx.Signal("Move", mouse))
                rawset(mouse, "Button1Down", ctx.Signal("Button1Down", mouse))
                rawset(mouse, "Button1Up", ctx.Signal("Button1Up", mouse))
                rawset(mouse, "Button2Down", ctx.Signal("Button2Down", mouse))
                rawset(mouse, "Button2Up", ctx.Signal("Button2Up", mouse))
            end
            rawset(self, "_v1Mouse", mouse)
            return mouse
        end,
        HasAppearanceLoaded = function(self)
            return true
        end,
        GetLeaderstats = function(self)
            if ctx.Instance == nil then
                return nil
            end
            local cached = rawget(self, "_v1Leaderstats")
            if cached ~= nil then
                return cached
            end
            cached = ctx.Instance("Folder")
            rawset(cached, "Name", "leaderstats")
            rawset(self, "_v1Leaderstats", cached)
            return cached
        end,
        AccountAge = 365,
        CharacterAppearanceId = 1,
        CameraMode = Fidelity.EnumValue("CameraMode", "Classic", 0),
        MembershipType = Fidelity.EnumValue("MembershipType", "None", 0),
        CameraMaxZoomDistance = 400,
        CameraMinZoomDistance = 0.5,
        AutoJumpEnabled = true,
        Neutral = true,
        GameLocaleId = "en-us",
        LocaleId = "en-us",
        GetNetworkStats = function(self)
            return {
                DataPing = 64,
                DataFrameRate = 60,
                ServerSendBandwidthUsed = 0,
                ServerSendBandwidthAvailable = 37500000,
                ClientReceiveBytesAverage = 0,
                ClientReceiveBandwidthAvailable = 37500000,
            }
        end,
    }
end
local ChildrenOf = setmetatable({}, { __mode = "k" })
function Fidelity.RegisterChild(parent, child)
    if parent == nil or child == nil then return end
    local list = ChildrenOf[parent]
    if list == nil then
        list = {}
        ChildrenOf[parent] = list
    end
    for _, existing in ipairs(list) do
        if existing == child then return end
    end
    table.insert(list, child)
end
function Fidelity.DetachDestroyedInstance(InstanceObject, DepthLeft)
    if type(InstanceObject) ~= "table" then
        return false
    end
    DepthLeft = DepthLeft or 32
    if DepthLeft <= 0 then
        return true
    end
    local childList = ChildrenOf[InstanceObject]
    if type(childList) == "table" then
        for childIndex = #childList, 1, -1 do
            local childObject = childList[childIndex]
            if type(childObject) == "table" then
                Fidelity.DetachDestroyedInstance(childObject, DepthLeft - 1)
            end
        end
        for clearIndex = #childList, 1, -1 do
            childList[clearIndex] = nil
        end
    end
    rawset(InstanceObject, "__V1_PARENT_VALUE", nil)
    rawset(InstanceObject, "__V1_LOCK_PARENT", true)
    rawset(InstanceObject, "__V1_DESTROYED", true)
    return true
end
function Fidelity.ChildrenSnapshot(ParentObject)
    local list = type(ParentObject) == "table" and ChildrenOf[ParentObject] or nil
    if type(list) ~= "table" then
        return nil
    end
    local snapshot = {}
    for snapshotIndex = 1, #list do
        snapshot[#snapshot + 1] = list[snapshotIndex]
    end
    return snapshot
end
function Fidelity.UnregisterChild(parent, child)
    local list = ChildrenOf[parent]
    if list == nil then return end
    for i = #list, 1, -1 do
        if list[i] == child then
            table.remove(list, i)
        end
    end
end
function Fidelity.GetChildrenOf(parent)
    local list = ChildrenOf[parent] or {}
    local copy = {}
    for i, child in ipairs(list) do
        copy[i] = child
    end
    return copy
end
function Fidelity.FindFirstChildOfClass(instance, className, recursive, whichIsA)
    local children = Fidelity.GetChildrenOf(instance)
    for _, child in ipairs(children) do
        local match
        if whichIsA then
            match = child:IsA(className)
        else
            match = (child.ClassName == className)
        end
        if match then return child end
    end
    if recursive then
        for _, child in ipairs(children) do
            local found = Fidelity.FindFirstChildOfClass(child, className, true, whichIsA)
            if found ~= nil then return found end
        end
    end
    return nil
end
Fidelity.TagStore = setmetatable({}, { __mode = "k" })
local function tagBagFor(objectValue)
    local tags = Fidelity.TagStore[objectValue]
    if tags == nil then
        tags = {}
        Fidelity.TagStore[objectValue] = tags
    end
    return tags
end
function Fidelity.AddTagTo(objectValue, tagNameValue)
    if objectValue == nil or tagNameValue == nil then
        return false
    end
    tagBagFor(objectValue)[tostring(tagNameValue)] = true
    return true
end
function Fidelity.RemoveTagFrom(objectValue, tagNameValue)
    local tags = Fidelity.TagStore[objectValue]
    if tags == nil or tagNameValue == nil then
        return false
    end
    tags[tostring(tagNameValue)] = nil
    return true
end
function Fidelity.ObjectHasTag(objectValue, tagNameValue)
    local tags = Fidelity.TagStore[objectValue]
    if tags == nil then
        return false
    end
    return tags[tostring(tagNameValue)] == true
end
function Fidelity.TagsOf(objectValue)
    local result = {}
    local tags = Fidelity.TagStore[objectValue]
    if tags == nil then
        return result
    end
    for tagName in next, tags do
        result[#result + 1] = tagName
    end
    table.sort(result)
    return result
end
local function queryAttribute(objectValue, attributeNameValue)
    if objectValue == nil then
        return nil
    end
    local getter = objectValue.GetAttribute
    if getter == nil then
        return nil
    end
    local ok, attributeValue = pcall(getter, objectValue, attributeNameValue)
    if not ok then
        return nil
    end
    return attributeValue
end
local function queryValuesMatch(actualValue, expectedValue)
    if actualValue == nil or expectedValue == nil then
        return actualValue == expectedValue
    end
    if actualValue == expectedValue then
        return true
    end
    local actualNumber = tonumber(actualValue)
    local expectedNumber = tonumber(expectedValue)
    if actualNumber ~= nil and expectedNumber ~= nil then
        return actualNumber == expectedNumber
    end
    return tostring(actualValue) == tostring(expectedValue)
end
local function parseQuerySelector(selector)
    local text = tostring(selector or "")
    local negate = false
    if string.sub(text, 1, 5) == ":not(" and string.sub(text, -1) == ")" then
        negate = true
        text = string.sub(text, 6, -2)
    end
    local head, predicate = text, nil
    local before, inside = string.match(text, "^([^%[]*)%[([^%]]*)%]")
    if before ~= nil then
        head, predicate = before, inside
    elseif string.find(text, "[", 1, true) ~= nil then
        return nil
    end
    local wantedName, wantedClass, tagNames = nil, head, {}
    if string.sub(head, 1, 1) == "#" then
        local rest
        wantedName, rest = string.match(head, "^#([^%.]+)(.*)$")
        wantedClass = rest
        if wantedName ~= nil and wantedName ~= "" then
            local tagNamePart = string.match(wantedName, "^([^%[]+)")
            if tagNamePart ~= nil then
                wantedName = tagNamePart
            end
        end
    end
    if wantedClass == nil then
        return nil
    end
    for tagCandidate in string.gmatch(wantedClass, "%.([%w_%-%.]+)") do
        tagNames[#tagNames + 1] = tagCandidate
    end
    wantedClass = string.gsub(wantedClass, "%.[%w_%-%.]+", "")
    if wantedClass == "" then
        wantedClass = nil
    end
    local attributeKey, attributeOperator, attributeValue = nil, nil, nil
    if predicate ~= nil then
        local key, remainder = string.match(predicate, "^%s*[$]([%w_]+)%s*(.*)$")
        if key == nil then
            return nil
        end
        attributeKey = key
        local operator = string.match(remainder, "^([=~!<>]+)")
        local value = nil
        if operator ~= nil then
            value = string.match(remainder, "^[=~!<>]+%s*(.-)%s*$")
        elseif remainder ~= nil and remainder ~= "" then
            return nil
        end
        attributeOperator = operator
        if value ~= nil and value ~= "" then
            value = string.gsub(value, "^['\"]", "")
            value = string.gsub(value, "['\"]$", "")
            attributeValue = value
        end
    end
    return function(candidate)
        if candidate == nil then
            return false
        end
        if wantedClass ~= nil then
            local classMatched = candidate.ClassName == wantedClass
            if not classMatched and candidate.IsA ~= nil then
                local ok, isA = pcall(candidate.IsA, candidate, wantedClass)
                classMatched = ok and isA == true
            end
            if not classMatched then
                return false
            end
        end
        if wantedName ~= nil and tostring(candidate.Name) ~= wantedName then
            return false
        end
        for index = 1, #tagNames do
            local tagMatched = Fidelity.ObjectHasTag(candidate, tagNames[index])
            if not tagMatched and candidate.HasTag ~= nil then
                local ok, hasTag = pcall(candidate.HasTag, candidate, tagNames[index])
                tagMatched = ok and hasTag == true
            end
            if not tagMatched then
                return false
            end
        end
        if attributeKey ~= nil then
            local actualValue = queryAttribute(candidate, attributeKey)
            if attributeOperator == nil or attributeOperator == "=" or attributeOperator == "==" then
                if attributeValue == nil then
                    if actualValue == nil then
                        return false
                    end
                elseif not queryValuesMatch(actualValue, attributeValue) then
                    return false
                end
            elseif attributeOperator == "~=" then
                if queryValuesMatch(actualValue, attributeValue) then
                    return false
                end
            elseif attributeOperator == "~~" or attributeOperator == "~" then
                return false
            else
                local actualNumber, expectedNumber = tonumber(actualValue), tonumber(attributeValue)
                if actualNumber == nil or expectedNumber == nil then
                    return false
                end
                if attributeOperator == "<" then
                    if not (actualNumber < expectedNumber) then return false end
                elseif attributeOperator == ">" then
                    if not (actualNumber > expectedNumber) then return false end
                elseif attributeOperator == "<=" then
                    if not (actualNumber <= expectedNumber) then return false end
                elseif attributeOperator == ">=" then
                    if not (actualNumber >= expectedNumber) then return false end
                else
                    return false
                end
            end
        end
        if negate then
            return false
        end
        return true
    end
end
function Fidelity.QueryDescendants(instance, selector)
    local rawSelector = tostring(selector or "")
    local negate = false
    if string.sub(rawSelector, 1, 5) == ":not(" and string.sub(rawSelector, -1) == ")" then
        negate = true
    end
    local predicate = parseQuerySelector(rawSelector)
    if predicate == nil then
        local inner = negate and string.sub(rawSelector, 6, -2) or rawSelector
        predicate = function(candidate)
            if candidate == nil then
                return false
            end
            if string.sub(inner, 1, 1) == "#" then
                return tostring(candidate.Name) == string.sub(inner, 2)
            end
            return candidate.ClassName == inner
        end
    end
    local results = {}
    local function walk(node)
        for _, child in ipairs(Fidelity.GetChildrenOf(node)) do
            local matched = predicate(child)
            if negate then
                matched = not matched
            end
            if matched then
                results[#results + 1] = child
            end
            walk(child)
        end
    end
    walk(instance)
    return results
end
Fidelity.PropertyRules = {
    ["Sound.Volume"] = { Numeric = true, Float32 = true, Min = 0, Max = 10 },
    ["Sound.PlaybackSpeed"] = { Numeric = true, Float32 = true, Min = 0, Max = 100 },
    ["Sound.TimePosition"] = { Numeric = true, Float32 = true, Min = 0 },
    ["Sound.RollOffMaxDistance"] = { Numeric = true, Float32 = true, Min = 0 },
    ["Sound.RollOffMinDistance"] = { Numeric = true, Float32 = true, Min = 0 },
    ["SoundService.DistanceFactor"] = { Numeric = true, Float32 = true, Min = 0 },
    ["SoundService.DopplerScale"] = { Numeric = true, Float32 = true, Min = 0 },
    ["SoundService.RolloffScale"] = { Numeric = true, Float32 = true, Min = 0 },
    ["*.Transparency"] = { Numeric = true, Float32 = true, Min = 0, Max = 1 },
    ["*.Reflectance"] = { Numeric = true, Float32 = true, Min = 0, Max = 1 },
    ["Humanoid.WalkSpeed"] = { Numeric = true, Float32 = true, Min = 0 },
    ["Humanoid.JumpPower"] = { Numeric = true, Float32 = true, Min = 0 },
    ["Part.BrickColor"] = {},
}
Fidelity.PropertyRules = Fidelity.PropertyRules or {}
Fidelity.PropertyRules["Player.CameraMinZoomDistance"] = { Numeric = true, Min = 0.5, Max = 2047.5 }
Fidelity.PropertyRules["Player.CameraMaxZoomDistance"] = { Numeric = true, Min = 0.5, Max = 2047.5 }
Fidelity.PropertyRules["Humanoid.Health"] = { Numeric = true, Min = 0 }
Fidelity.PropertyRules["Humanoid.MaxHealth"] = { Numeric = true, Min = 0 }
Fidelity.PropertyRules["Humanoid.WalkSpeed"] = { Numeric = true, Min = 0 }
Fidelity.PropertyRules["Humanoid.JumpPower"] = { Numeric = true, Min = 0 }
Fidelity.PropertyRejectRules = {
    ["*.Orientation"] = "Vector3",
    ["*.Velocity"] = "Vector3",
    ["*.RotVelocity"] = "Vector3",
    ["*.AnchorPoint"] = "Vector2",
    ["*.BorderSizePixel"] = "Number",
    ["Part.AngularVelocity"] = "Vector3",
    ["MeshPart.AngularVelocity"] = "Vector3",
    ["WedgePart.AngularVelocity"] = "Vector3",
    ["Part.Rotation"] = "Vector3",
    ["MeshPart.Rotation"] = "Vector3",
    ["SpawnLocation.Rotation"] = "Vector3",
    ["WedgePart.Rotation"] = "Vector3",
}
function Fidelity.CoerceProperty(className, propertyName, value)
    local rule = Fidelity.PropertyRules[className .. "." .. propertyName]
        or Fidelity.PropertyRules["*." .. propertyName]
    if rule == nil then
        local RejectRule = Fidelity.PropertyRejectRules
        if RejectRule ~= nil then
            local ExpectedType = RejectRule[className .. "." .. propertyName]
                or RejectRule["*." .. propertyName]
            if ExpectedType ~= nil then
                local ExpectedLuaType = ExpectedType == "Number" and "number"
                    or ExpectedType == "String" and "string"
                    or ExpectedType == "Boolean" and "boolean"
                local AcceptedValue = type(value) == "table"
                    or (ExpectedLuaType ~= nil and type(value) == ExpectedLuaType)
                if not AcceptedValue then
                    error(string.format(
                        "Type mismatch: Property %s expects %s, got %s",
                        tostring(propertyName), ExpectedType, type(value)), 0)
                end
            end
        end
        return value
    end
    if rule.Numeric == true then
        if type(value) ~= "number" then
            return value
        end
        if rule.Min ~= nil or rule.Max ~= nil then
            value = ClampNumber(value, rule.Min or -math.huge, rule.Max or math.huge)
        end
        if rule.Float32 == true then
            value = ToFloat32(value)
        end
    end
    return value
end
local UINT32_MODULUS = 4294967296
local PCG32_CHI = 0x5851F42D
local PCG32_CLO = 0x4C957F2D
local PCG32_INC = 105
local function Mul32(a, b)
    local al = bit32.band(a, 0xFFFF)
    local ah = bit32.rshift(a, 16)
    local bl = bit32.band(b, 0xFFFF)
    local bh = bit32.rshift(b, 16)
    local p0 = al * bl
    local p1 = al * bh + ah * bl
    local p2 = ah * bh
    local t = p1 * 65536 + p0
    local q = math.floor(t / UINT32_MODULUS)
    local lo = t - q * UINT32_MODULUS
    local hi = p2 + q
    return hi, lo
end
local function PcgAdvance(hi, lo)
    local t_hi, t_lo = Mul32(lo, PCG32_CLO)
    local a_hi, a_lo = Mul32(hi, PCG32_CLO)
    local b_hi, b_lo = Mul32(lo, PCG32_CHI)
    local r_lo = t_lo + PCG32_INC
    local carry = 0
    if r_lo >= UINT32_MODULUS then
        r_lo = r_lo - UINT32_MODULUS
        carry = 1
    end
    local r_hi = (t_hi + a_lo + b_lo + carry) % UINT32_MODULUS
    return r_hi, r_lo
end
local function PcgOut(hi, lo)
    local sh_hi = bit32.rshift(hi, 18)
    local sh_lo = bit32.bor(bit32.band(bit32.lshift(hi, 14), 0xFFFFFFFF), bit32.rshift(lo, 18))
    local x_hi = bit32.bxor(hi, sh_hi)
    local x_lo = bit32.bxor(lo, sh_lo)
    local xorshifted = bit32.bor(bit32.lshift(x_hi, 5), bit32.rshift(x_lo, 27))
    local rot = bit32.band(bit32.rshift(hi, 27), 0x1F)
    return bit32.bor(bit32.rshift(xorshifted, rot), bit32.lshift(xorshifted, bit32.band(-rot, 31)))
end
local function PcgDraw(state)
    local out = PcgOut(state[1], state[2])
    state[1], state[2] = PcgAdvance(state[1], state[2])
    return out
end
local function Add64(hi, lo, shi, slo)
    local nlo = lo + slo
    local carry = 0
    if nlo >= UINT32_MODULUS then
        nlo = nlo - UINT32_MODULUS
        carry = 1
    end
    local nhi = (hi + shi + carry) % UINT32_MODULUS
    return nhi, nlo
end
local function PcgSeed(seed)
    local numericSeed = math.floor(tonumber(seed) or 0)
    local slo = numericSeed % UINT32_MODULUS
    local shi = math.floor(numericSeed / UINT32_MODULUS) % UINT32_MODULUS
    local hi, lo = 0, 0
    hi, lo = PcgAdvance(hi, lo)
    hi, lo = Add64(hi, lo, shi, slo)
    hi, lo = PcgAdvance(hi, lo)
    return { hi, lo }
end
local Random = {}
local RandomMethods = {}
local RandomMT = {
    __index = RandomMethods,
    __tostring = function() return "Random" end,
}
function Random.new(seed)
    if seed ~= nil and type(seed) ~= "number" then
        error("bad argument #1 to 'new' (number expected, got " .. type(seed) .. ")", 0)
    end
    local self = setmetatable({
        _Type = "Random",
        _State = PcgSeed(seed),
        _CachedNormal = nil,
    }, RandomMT)
    return self
end
local function NextNumberUnit(self)
    local rl = PcgDraw(self._State)
    local rh = PcgDraw(self._State)
    return (rl + rh * UINT32_MODULUS) / (2 ^ 64)
end
function RandomMethods:NextNumber(minValue, maxValue)
    local unit = NextNumberUnit(self)
    if minValue == nil and maxValue == nil then
        return unit
    end
    if minValue ~= nil and maxValue == nil then
        minValue, maxValue = 0, minValue
    end
    return minValue + unit * (maxValue - minValue)
end
function RandomMethods:NextInteger(minValue, maxValue)
    minValue = math.floor(minValue or 0)
    maxValue = math.floor(maxValue or minValue)
    if maxValue < minValue then
        minValue, maxValue = maxValue, minValue
    end
    local range = maxValue - minValue + 1
    local draw = PcgDraw(self._State)
    if range < UINT32_MODULUS then
        local hi = Mul32(range, draw)
        return minValue + hi
    end
    return minValue + math.floor(draw / UINT32_MODULUS * range)
end
function RandomMethods:NextUnitVector()
    local azimuth = (PcgDraw(self._State) / UINT32_MODULUS) * (2 * math.pi)
    local height = ToFloat32(2 * (PcgDraw(self._State) / UINT32_MODULUS) - 1)
    local radius = ToFloat32(math.sqrt(ToFloat32(1 - ToFloat32(height * height))))
    return Vector3.new(
        radius * math.cos(azimuth),
        radius * math.sin(azimuth),
        height
    )
end
function RandomMethods:NextNormal(mean, standardDeviation)
    mean = mean or 0
    standardDeviation = standardDeviation or 1
    if self._CachedNormal ~= nil then
        local cached = self._CachedNormal
        self._CachedNormal = nil
        return mean + cached * standardDeviation
    end
    local u1 = math.max(NextNumberUnit(self), 1e-12)
    local u2 = NextNumberUnit(self)
    local magnitude = math.sqrt(-2 * math.log(u1))
    local angle = 2 * math.pi * u2
    self._CachedNormal = magnitude * math.sin(angle)
    return mean + magnitude * math.cos(angle) * standardDeviation
end
function RandomMethods:Shuffle(targetTable)
    for index = #targetTable, 2, -1 do
        local swapIndex = self:NextInteger(1, index)
        targetTable[index], targetTable[swapIndex] = targetTable[swapIndex], targetTable[index]
    end
end
function RandomMethods:Clone()
    local copy = setmetatable({
        _Type = "Random",
        _State = { self._State[1], self._State[2] },
        _CachedNormal = self._CachedNormal,
    }, RandomMT)
    return copy
end
Fidelity.Random = Random
local MetricsLoadSucceeded, SourceSansMetrics = pcall(function()
    return require("./SourceSansMetrics")
end)
if not MetricsLoadSucceeded then
    local retrySucceeded, retryResult = pcall(function()
        return require("./Libraries/SourceSansMetrics")
    end)
    SourceSansMetrics = retrySucceeded and retryResult or { FallbackAdvance = 404 }
end
local function AdvanceFor(character)
    local advance = SourceSansMetrics[character]
    if advance == nil then
        advance = SourceSansMetrics.FallbackAdvance or 404
    end
    return advance
end
local function LayoutLine(text, fontSize, maxLineWidth)
    local bounded = maxLineWidth ~= nil and maxLineWidth > 0
    if not bounded then
        local width = 0
        for index = 1, #text do
            width += AdvanceFor(string.sub(text, index, index)) / 1000 * fontSize
        end
        return width, 1
    end
    local spaceWidth = AdvanceFor(" ") / 1000 * fontSize
    local lines = 1
    local currentWidth = 0
    local widest = 0
    local wordWidth = 0
    local pendingSeparator = 0
    local function FlushWord()
        if wordWidth == 0 then
            return
        end
        if currentWidth > 0 and currentWidth + pendingSeparator + wordWidth > maxLineWidth then
            if currentWidth > widest then
                widest = currentWidth
            end
            lines += 1
            currentWidth = wordWidth
        else
            currentWidth += pendingSeparator + wordWidth
        end
        pendingSeparator = 0
        wordWidth = 0
    end
    for index = 1, #text do
        local character = string.sub(text, index, index)
        if character == " " then
            FlushWord()
            if currentWidth > 0 then
                pendingSeparator = spaceWidth
            end
        else
            wordWidth += AdvanceFor(character) / 1000 * fontSize
        end
    end
    FlushWord()
    if currentWidth > widest then
        widest = currentWidth
    end
    return widest, lines
end
local TextService = {}
function TextService:GetTextSize(text, fontSize, font, frameSize)
    text = tostring(text == nil and "" or text)
    fontSize = tonumber(fontSize) or 36
    local maxWidth = 0
    if frameSize ~= nil then
        maxWidth = frameSize.X or 0
    end
    local totalLines = 0
    local widest = 0
    for hardLine in string.gmatch(text .. "\n", "(.-)\n") do
        if hardLine == "" then
            totalLines += 1
        else
            local lineWidth, lineCount = LayoutLine(hardLine, fontSize, maxWidth)
            totalLines += lineCount
            if lineWidth > widest then
                widest = lineWidth
            end
        end
    end
    if totalLines == 0 then
        totalLines = 1
    end
    return Vector2.new(RoundToInteger(widest), totalLines * fontSize)
end
TextService.Name = "TextService"
rawset(TextService, "__V1_CLASS_NAME", "TextService")
Fidelity.TextService = TextService
Fidelity.AdvanceFor = AdvanceFor
function Fidelity.MakeTextService(host)
    host.Name = "TextService"
    rawset(host, "__V1_CLASS_NAME", "TextService")
    function host:GetTextSize(text, fontSize, font, frameSize)
        return TextService:GetTextSize(text, fontSize, font, frameSize)
    end
    return host
end
local ListenerTypeCamera = Fidelity.EnumValue("ListenerType", "Camera", 0)
local ListenerTypeCFrame = Fidelity.EnumValue("ListenerType", "CFrame", 1)
local ListenerTypeObjectPosition = Fidelity.EnumValue("ListenerType", "ObjectPosition", 2)
local ListenerTypeObjectCFrame = Fidelity.EnumValue("ListenerType", "ObjectCFrame", 3)
function Fidelity.MakeSoundService(host)
    local state = {
        ListenerType = ListenerTypeCamera,
        ListenerTarget = nil,
    }
    local properties = {
        DistanceFactor = ToFloat32(3.33),
        DopplerScale = 1,
        RolloffScale = 1,
        AmbientReverb = Fidelity.EnumValue("ReverbType", "NoReverb", 0),
        RespectFilteringEnabled = false,
    }
    local methods = {}
    function methods:GetListener()
        return state.ListenerType, state.ListenerTarget
    end
    function methods:SetListener(listenerType, target)
        if listenerType == ListenerTypeCFrame then
            state.ListenerType = ListenerTypeCFrame
            state.ListenerTarget = target
        elseif listenerType == ListenerTypeObjectPosition then
            state.ListenerType = ListenerTypeObjectPosition
            state.ListenerTarget = target
        elseif listenerType == ListenerTypeObjectCFrame then
            state.ListenerType = ListenerTypeObjectCFrame
            state.ListenerTarget = target
        else
            state.ListenerType = listenerType == ListenerTypeCamera and ListenerTypeCamera or listenerType
            state.ListenerTarget = nil
        end
    end
    function methods:PlayLocalSound() end
    function methods:SetAmbientReverb() end
    function methods:SetRollOffScale() end
    function methods:IsA(className)
        return className == "SoundService" or className == "Instance"
    end
    setmetatable(host, {
        __index = function(_, key)
            local method = methods[key]
            if method ~= nil then
                return method
            end
            return properties[key]
        end,
        __newindex = function(_, key, value)
            properties[key] = Fidelity.CoerceProperty("SoundService", key, value)
        end,
        __tostring = function() return "SoundService" end,
    })
    return host
end
local DEFAULT_COLLISION_GROUP_MASK = -1
function Fidelity.MakePhysicsService(host)
    local collidableOverrides = {}
    function host:GetMaxCollisionGroups()
        return 32
    end
    function host:GetRegisteredCollisionGroups()
        return { { name = "Default", mask = DEFAULT_COLLISION_GROUP_MASK } }
    end
    function host:IsCollisionGroupRegistered(groupName)
        return groupName == "Default"
    end
    function host:GetCollisionGroupId(groupName)
        if groupName == "Default" then
            return 0
        end
        error("Collision group '" .. tostring(groupName) .. "' is not registered.", 0)
    end
    function host:GetCollisionGroupName()
        return "Default"
    end
    function host:CollisionGroupsAreCollidable(groupA, groupB)
        local key = tostring(groupA) .. "\0" .. tostring(groupB)
        local reverseKey = tostring(groupB) .. "\0" .. tostring(groupA)
        if collidableOverrides[key] ~= nil then
            return collidableOverrides[key]
        end
        if collidableOverrides[reverseKey] ~= nil then
            return collidableOverrides[reverseKey]
        end
        return true
    end
    function host:CollisionGroupSetCollidable(groupA, groupB, collidable)
        if groupA == "Default" or groupB == "Default" then
            error("Can not use/change the Default collision group.", 0)
        end
        error("This API can only be used on the server!", 0)
    end
    function host:RegisterCollisionGroup(groupName)
        if groupName == "Default" then
            error("Can not use/change the Default collision group.", 0)
        end
        error("This API can only be used on the server!", 0)
    end
    function host:UnregisterCollisionGroup(groupName)
        if groupName == "Default" then
            error("Can not use/change the Default collision group.", 0)
        end
        error("This API can only be used on the server!", 0)
    end
    function host:LocalPlayerSetSimulationRadius() end
    function host:SetPartCollisionGroup() end
    function host:GetPartCollisionGroup() end
    return host
end
Fidelity.CountryRegionCode = "US"
function Fidelity.MakePolicyService(host)
    function host:GetPolicyInfoForPlayerAsync()
        return {
            AgeBracket = Fidelity.EnumValue("PolicyLevel", "Age13OrOver", 3),
            ArePaidRandomItemsRestricted = false,
            AllowedExternalLinkReferences = { "Discord" },
            IsEligibleToPurchaseCommerceProduct = true,
            IsSubjectToAdsPolicy = false,
        }
    end
    function host:GetPolicyInfoForServerRobuxConsentAsync()
        return {
            ArePaidRandomItemsRestricted = false,
            IsSubjectToAdsPolicy = false,
        }
    end
    return host
end
function Fidelity.MakeLocalizationService(host)
    function host:GetCountryRegionForPlayerAsync()
        return Fidelity.CountryRegionCode
    end
    function host:GetRobloxLocaleId()
        return "en-us"
    end
    function host:GetCorescriptLocalizations()
        return {}
    end
    function host:GetTableEntries()
        return {}
    end
    return host
end
local StringFormat = string.format
local StringGsub = string.gsub
local StringSub = string.sub
local StringByte = string.byte
local StringFind = string.find
local MathHuge = math.huge
local JSON_EXP_LIMIT = 1e16
local function FormatJsonNumber(value)
    if value ~= value then
        return "nan"
    elseif value == MathHuge then
        return "inf"
    elseif value == -MathHuge then
        return "-inf"
    end
    local magnitude = value < 0 and -value or value
    if magnitude >= JSON_EXP_LIMIT then
        for precision = 12, 17 do
            local candidate = StringFormat("%." .. precision .. "g", value)
            if tonumber(candidate) == value then
                return (StringGsub(candidate, "e%+", "e"))
            end
        end
        return (StringGsub(StringFormat("%.17g", value), "e%+", "e"))
    end
    if magnitude < 1e15 and value == math.floor(value) then
        return StringFormat("%.0f", value)
    end
    for precision = 12, 16 do
        local candidate = StringFormat("%." .. precision .. "g", value)
        if tonumber(candidate) == value then
            return candidate
        end
    end
    return StringFormat("%.17g", value)
end
Fidelity.FormatJsonNumber = FormatJsonNumber
local JsonEscapeMap = {
    ['"'] = '\\"',
    ["\\"] = "\\\\",
    ["\b"] = "\\b",
    ["\f"] = "\\f",
    ["\n"] = "\\n",
    ["\r"] = "\\r",
    ["\t"] = "\\t",
}
local function EscapeJsonString(text)
    local parts = { '"' }
    for index = 1, #text do
        local character = StringSub(text, index, index)
        local escaped = JsonEscapeMap[character]
        if escaped then
            parts[#parts + 1] = escaped
        elseif StringByte(character) < 32 then
            parts[#parts + 1] = StringFormat("\\u%04x", StringByte(character))
        else
            parts[#parts + 1] = character
        end
    end
    parts[#parts + 1] = '"'
    return table.concat(parts)
end
local function EncodeNumericVariant(value)
    local rendered
    if value ~= value then
        rendered = "nan"
    elseif value == MathHuge then
        rendered = "inf"
    else
        rendered = "-inf"
    end
    return '{"m":null,"t":"numeric","v":"' .. rendered .. '"}'
end
local function EncodeJsonValue(value, stack)
    local valueType = type(value)
    if valueType == "table" then
        if stack[value] then
            error("tables cannot be cyclic", 0)
        end
        stack[value] = true
        local rendered
        if value[1] ~= nil then
            local parts = {}
            local index = 1
            while value[index] ~= nil do
                parts[#parts + 1] = EncodeJsonValue(value[index], stack)
                index += 1
            end
            rendered = "[" .. table.concat(parts, ",") .. "]"
        else
            if next(value) == nil then
                rendered = "[]"
            else
                local keys = {}
                for key in next, value do
                    keys[#keys + 1] = tostring(key)
                end
                table.sort(keys)
                local parts = {}
                for _, key in ipairs(keys) do
                    parts[#parts + 1] = EscapeJsonString(key) .. ":"
                        .. EncodeJsonValue(value[tonumber(key) ~= nil and tonumber(key) or key], stack)
                end
                rendered = "{" .. table.concat(parts, ",") .. "}"
            end
        end
        stack[value] = nil
        return rendered
    elseif valueType == "string" then
        return EscapeJsonString(value)
    elseif valueType == "number" then
        if value ~= value or value == MathHuge or value == -MathHuge then
            return EncodeNumericVariant(value)
        end
        return FormatJsonNumber(value)
    elseif valueType == "boolean" then
        return value and "true" or "false"
    end
    return "null"
end
function Fidelity.JsonEncode(value)
    return EncodeJsonValue(value, {})
end
local function SkipJsonWhitespace(text, position)
    while position <= #text do
        local character = StringSub(text, position, position)
        if character ~= " " and character ~= "\t" and character ~= "\n" and character ~= "\r" then
            break
        end
        position += 1
    end
    return position
end
local HexDigitValues = {}
for digit = 0, 9 do
    HexDigitValues[tostring(digit)] = digit
end
for offset, letter in ipairs({ "a", "b", "c", "d", "e", "f" }) do
    HexDigitValues[letter] = 9 + offset
    HexDigitValues[letter:upper()] = 9 + offset
end
local JsonSimpleEscapes = {
    ['"'] = '"', ["\\"] = "\\", ["/"] = "/",
    b = "\b", f = "\f", n = "\n", r = "\r", t = "\t",
}
local ParseJsonValue
local function ParseJsonString(text, position)
    local parts = {}
    position += 1
    while true do
        if position > #text then
            error("Can't parse JSON", 0)
        end
        local character = StringSub(text, position, position)
        if character == '"' then
            return table.concat(parts), position + 1
        elseif character == "\\" then
            position += 1
            local escaped = StringSub(text, position, position)
            local mapped = JsonSimpleEscapes[escaped]
            if mapped then
                parts[#parts + 1] = mapped
                position += 1
            elseif escaped == "u" then
                local digits = StringSub(text, position + 1, position + 4)
                local codepoint = 0
                for index = 1, 4 do
                    local weight = HexDigitValues[StringSub(digits, index, index)]
                    if not weight then
                        error("Can't parse JSON", 0)
                    end
                    codepoint = codepoint * 16 + weight
                end
                local utf8Ok, encoded = pcall(utf8.char, codepoint)
                if not utf8Ok then
                    error("Can't parse JSON", 0)
                end
                parts[#parts + 1] = encoded
                position += 5
            else
                error("Can't parse JSON", 0)
            end
        else
            parts[#parts + 1] = character
            position += 1
        end
    end
end
local function ParseJsonNumber(text, position)
    local start = position
    if StringSub(text, position, position) == "-" then
        position += 1
    end
    while position <= #text do
        local character = StringSub(text, position, position)
        if StringFind(character, "[0-9eE+%.%-]") then
            position += 1
        else
            break
        end
    end
    local literal = StringSub(text, start, position - 1)
    local number = tonumber(literal)
    if number == nil then
        error("Can't parse JSON", 0)
    end
    return number, position
end
ParseJsonValue = function(text, position)
    position = SkipJsonWhitespace(text, position)
    local character = StringSub(text, position, position)
    if character == "{" then
        local object = {}
        position = SkipJsonWhitespace(text, position + 1)
        if StringSub(text, position, position) == "}" then
            return object, position + 1
        end
        while true do
            position = SkipJsonWhitespace(text, position)
            if StringSub(text, position, position) ~= '"' then
                error("Can't parse JSON", 0)
            end
            local key
            key, position = ParseJsonString(text, position)
            position = SkipJsonWhitespace(text, position)
            if StringSub(text, position, position) ~= ":" then
                error("Can't parse JSON", 0)
            end
            local value
            value, position = ParseJsonValue(text, position + 1)
            if value ~= nil then
                object[key] = value
            end
            position = SkipJsonWhitespace(text, position)
            local separator = StringSub(text, position, position)
            if separator == "," then
                position += 1
            elseif separator == "}" then
                return object, position + 1
            else
                error("Can't parse JSON", 0)
            end
        end
    elseif character == "[" then
        local array = {}
        position = SkipJsonWhitespace(text, position + 1)
        if StringSub(text, position, position) == "]" then
            return array, position + 1
        end
        while true do
            local value
            value, position = ParseJsonValue(text, position)
            if value ~= nil then
                array[#array + 1] = value
            end
            position = SkipJsonWhitespace(text, position)
            local separator = StringSub(text, position, position)
            if separator == "," then
                position += 1
            elseif separator == "]" then
                return array, position + 1
            else
                error("Can't parse JSON", 0)
            end
        end
    elseif character == '"' then
        return ParseJsonString(text, position)
    elseif character == "t" then
        if StringSub(text, position, position + 3) ~= "true" then
            error("Can't parse JSON", 0)
        end
        return true, position + 4
    elseif character == "f" then
        if StringSub(text, position, position + 4) ~= "false" then
            error("Can't parse JSON", 0)
        end
        return false, position + 5
    elseif character == "n" then
        if StringSub(text, position, position + 3) ~= "null" then
            error("Can't parse JSON", 0)
        end
        return nil, position + 4
    elseif character == "-" or StringFind(character or "", "[0-9]") then
        return ParseJsonNumber(text, position)
    end
    error("Can't parse JSON", 0)
end
function Fidelity.JsonDecode(text)
    if type(text) ~= "string" then
        error("Can't parse JSON", 0)
    end
    local value, position = ParseJsonValue(text, 1)
    position = SkipJsonWhitespace(text, position)
    if position <= #text then
        error("Can't parse JSON", 0)
    end
    return value
end
local function DescribeOperand(value)
    if type(value) == "table" and rawget(value, "__V1_INSTANCE") then
        return "Instance"
    end
    return type(value)
end
Fidelity.InstanceMetamethods = {
    __len = function(self)
        error("attempt to get length of a " .. DescribeOperand(self) .. " value", 0)
    end,
    __unm = function(self)
        error("attempt to perform arithmetic (unm) on " .. DescribeOperand(self), 0)
    end,
    __lt = function(left, right)
        error("attempt to compare " .. DescribeOperand(left) .. " < " .. DescribeOperand(right), 0)
    end,
    __le = function(left, right)
        error("attempt to compare " .. DescribeOperand(left) .. " <= " .. DescribeOperand(right), 0)
    end,
    __concat = function(left, right)
        error(
            "attempt to concatenate " .. DescribeOperand(left) .. " with " .. DescribeOperand(right),
            0
        )
    end,
}
function Fidelity.GuardedNext(tableArgument, ...)
    if type(tableArgument) ~= "table" then
        error(
            "invalid argument #1 to 'next' (table expected, got " .. DescribeOperand(tableArgument) .. ")",
            0
        )
    end
    if rawget(tableArgument, "__V1_INSTANCE") then
        error("invalid argument #1 to 'next' (table expected, got Instance)", 0)
    end
    return next(tableArgument, ...)
end
Fidelity.InstanceEventNames = {
    AncestryChanged = true, AttributeChanged = true, Changed = true,
    ChildAdded = true, ChildRemoved = true, DescendantAdded = true,
    DescendantRemoving = true, Destroying = true,
}
Fidelity.GuardedNatives = setmetatable({}, { __mode = "k" })
Fidelity.GuardedNatives[Fidelity.GuardedNext] = true
function Fidelity.CheckInstanceMember(self, memberName)
    if type(self) ~= "table" or rawget(self, "__V1_INSTANCE") == nil then
        error("Expected ':' not '.' calling member function " .. tostring(memberName), 0)
    end
end
Fidelity.InheritedInstanceMethods = {
    ClearAllChildren = true,
    Clone = true,
    Destroy = true,
    FindFirstAncestor = true,
    FindFirstAncestorOfClass = true,
    FindFirstAncestorWhichIsA = true,
    FindFirstChild = true,
    FindFirstChildOfClass = true,
    FindFirstChildWhichIsA = true,
    GetActor = true,
    GetAttributes = true,
    GetAttribute = true,
    GetChildren = true,
    GetDebugId = true,
    GetDescendants = true,
    GetFullName = true,
    GetPropertyChangedSignal = true,
    IsA = true,
    IsAncestorOf = true,
    IsDescendantOf = true,
    Remove = true,
    SetAttribute = true,
    WaitForChild = true,
    GetProperty = true,
    SetProperty = true,
    GetMetadata = true,
    SetMetadata = true,
    IsPropertyModified = true,
    ResetPropertyToDefault = true,
    GetMass = true,
}
local SharedMethodRegistry = {}
function Fidelity.SharedMethodStub(className, methodName)
    if Fidelity.InheritedInstanceMethods[methodName] then
        className = "Instance"
    end
    local stubsForClass = SharedMethodRegistry[className]
    if stubsForClass == nil then
        stubsForClass = {}
        SharedMethodRegistry[className] = stubsForClass
    end
    local stub = stubsForClass[methodName]
    if stub == nil then
        stub = function(self, ...)
            Fidelity.CheckInstanceMember(self, methodName)
            local implementations = rawget(self, "__V1_Methods")
            local implementation = implementations and implementations[methodName]
            if implementation == nil then
                error(className .. "." .. methodName .. " is not implemented", 0)
            end
            return implementation(self, ...)
        end
        stubsForClass[methodName] = stub
    end
    return stub
end
local ChangedPropertyLists = {
    Value = { "Value" },
    IntValue = { "Value" },
    NumberValue = { "Value" },
    StringValue = { "Value" },
    BoolValue = { "Value" },
    ObjectValue = { "Value" },
    Color3Value = { "Value" },
    BrickColorValue = { "Value" },
    CFrameValue = { "Value" },
    Vector3Value = { "Value" },
    RayValue = { "Value" },
    TextLabel = { "Text", "Visible", "TextSize", "Font", "TextColor3", "TextWrapped", "TextScaled" },
    TextButton = { "Text", "Visible", "TextSize", "Font", "TextColor3", "AutoButtonColor", "Modal" },
    TextBox = { "Text", "Visible", "TextSize", "Font", "TextColor3", "PlaceholderText", "ClearTextOnFocus" },
    ImageLabel = { "Image", "Visible", "ImageColor3", "ImageTransparency", "ScaleType" },
    ImageButton = { "Image", "Visible", "ImageColor3", "AutoButtonColor", "Modal" },
    Frame = { "Visible", "Style", "Active" },
    ScrollingFrame = { "Visible", "CanvasPosition", "CanvasSize", "ScrollingDirection" },
    ViewportFrame = { "Visible", "CurrentCamera", "Ambient", "ImageColor3" },
    VideoFrame = { "Visible", "Video", "Volume", "TimePosition", "Looped", "Playing" },
    Sound = { "SoundId", "Volume", "PlaybackSpeed", "Looped", "Playing", "TimePosition", "IsLoaded", "IsPaused", "IsPlaying" },
    Part = { "Anchored", "CanCollide", "CanQuery", "CanTouch", "Transparency", "Material", "BrickColor", "Color", "Reflectance", "Shape" },
    Model = { "PrimaryPart", "LevelOfDetail" },
    Humanoid = { "Health", "MaxHealth", "WalkSpeed", "JumpPower", "JumpHeight", "Sit", "PlatformStand", "DisplayDistanceType" },
    Player = { "UserId", "DisplayName", "CharacterAutoLoads", "CameraMode" },
    Camera = { "CFrame", "FieldOfView", "CameraType", "Focus", "ViewportSize" },
    Workspace = { "Gravity", "StreamingEnabled", "SignalBehavior", "PhysicsSteppingMethod", "InterpolationThrottling" },
    Lighting = { "Ambient", "Brightness", "ClockTime", "FogColor", "FogEnd", "FogStart", "GeographicLatitude", "GlobalShadows", "OutdoorAmbient" },
    RemoteEvent = {},
    RemoteFunction = {},
    Folder = {},
    ScreenGui = { "Enabled", "DisplayOrder", "IgnoreGuiInset", "ResetOnSpawn", "ZIndexBehavior" },
    StarterGui = { "ShowDevelopmentGui", "ResetPlayerGuiOnSpawn", "ScreenOrientation", "VirtualCursorMode" },
}
function Fidelity.ChangedPropertiesFor(className)
    return ChangedPropertyLists[className]
end
local function LineWithinBudget(LineText, LineCount, Settings)
    local Text = LineText
    local LineCap = type(Settings) == "table" and (Settings.MaxLineChars or 0) or 0
    if LineCap > 0 and #Text > LineCap then
        local Tail = string.sub(Text, -8)
        local Head = string.sub(Text, 1, LineCap - #Tail - 1)
        local Joined = Head .. Tail
        local QuoteCount = 0
        for _ in string.gmatch(Joined, "[^\\]\"") do QuoteCount += 1 end
        if QuoteCount % 2 == 0 then
            Text = Joined .. " -- line too long, cut short here"
        else
            Text = string.sub(Text, 1, LineCap) .. " -- line too long, cut short here"
        end
    end
    if type(Settings) ~= "table" then return true, Text, nil end
    local Used = (Settings.OutputBytes or 0) + #Text
    local LineBudget = Settings.MaxOutputLines or 0
    local ByteBudget = Settings.MaxOutputBytes or 0
    if (LineBudget > 0 and LineCount >= LineBudget) or (ByteBudget > 0 and Used >= ByteBudget) then
        local Marker = nil
        if not Settings.OutputTruncatedNoted then
            Settings.OutputTruncatedNoted = true
            Marker = "-- stopped writing here, the output got too big to keep"
        end
        return false, Text, Marker
    end
    Settings.OutputBytes = Used
    return true, Text, nil
end
function Fidelity.LineWithinBudget(LineText, LineCount, Settings)
    local Ok, Text, Marker = LineWithinBudget(LineText, LineCount, Settings)
    return Ok, Text, Marker
end
function Fidelity.RedactRunnerSource(TextValue, RunnerSource)
    if type(TextValue) ~= "string" then return TextValue end
    if type(RunnerSource) ~= "string" or RunnerSource == "" then return TextValue end
    local Result = TextValue
    local Cursor, Guard = 1, 0
    while Guard < 64 do
        local Found = string.find(Result, RunnerSource, Cursor, true)
        if not Found then break end
        Guard = Guard + 1
        Result = string.sub(Result, 1, Found - 1) .. "[runner]" .. string.sub(Result, Found + #RunnerSource)
        Cursor = Found + 8
    end
    return (string.gsub(Result, "%[runner%]:%d+", "[runner]"))
end
Fidelity.ToolSourcePath = nil
local ToolFramePatterns = {
    "m(_orig)?%.?l?u?a??:%d+",
    "RobloxFidelity%.luau?:%d+",
    "/kvms/m",
}
local ToolDirectoryCache = nil
local function FidelityToolDirectory()
    if ToolDirectoryCache ~= nil then
        return ToolDirectoryCache
    end
    ToolDirectoryCache = false
    local sourcePath = Fidelity.ToolSourcePath
    if type(sourcePath) ~= "string" then
        local hostInfo = nil
        pcall(function()
            hostInfo = debug.getinfo(1, "S")
        end)
        if type(hostInfo) == "table" and type(hostInfo.source) == "string" then
            sourcePath = hostInfo.source
        end
    end
    if type(sourcePath) == "string" then
        local directory = string.match(sourcePath, "^@?(.-)[/\\][^/\\]*$")
        if type(directory) == "string" then
            directory = string.match(directory, "^(.*)[/\\]Libraries$") or directory
            if #directory > 1 then
                ToolDirectoryCache = directory
            end
        end
    end
    return ToolDirectoryCache
end
local ImmutableDatatypeMetatables = {
    Vector2MT, Vector3MT, CFrameMT, RectMT, AxesMT, FacesMT, NumberRangeMT, RayMT,
    PhysicalPropertiesMT, DateTimeMT, ContentMT, UserMT, SecretMT,
}
for _, ImmutableMetatable in ipairs(ImmutableDatatypeMetatables) do
    if type(ImmutableMetatable) == "table" and ImmutableMetatable.__newindex == nil then
        ImmutableMetatable.__newindex = function(TargetObject, KeyName)
            local TypeName = "value type"
            if type(TargetObject) == "table" then
                TypeName = rawget(TargetObject, "_Type") or TypeName
            end
            error(string.format("cannot write to '%s': %s is an immutable value type",
                tostring(KeyName), tostring(TypeName)), 0)
        end
    end
end
Fidelity.ReadOnlyInstanceProperties = {
    ClassName = true,
    JobId = true, PlaceId = true, GameId = true, CreatorId = true, CreatorType = true,
    ServerId = true,
    ClientGitHash = true, ClientVersion = true, ServerVersion = true,
    ServerCommit = true, ClientCommit = true, Mass = true, AssemblyMass = true, CenterOfMass = true,
    RootPart = true, GetPivot = false, IsLoaded = true, DataReady = true,
    Heartbeat = true, Stepped = true, RenderStepped = true, ClockStep = true,
    PreRender = true, PreSimulation = true, PostSimulation = true,
    PreSimulationStepped = true, PostSimulationStepped = true,
    PreAnimation = true, PreAnimationStepped = true, UnscaledTimeUpdate = true,
    ServiceStarted = true, TimestepCompleted = true, SendTriggerEventReceived = true,
    Ticked = true, Updated = true, FirstFrameRendered = true,
    ServiceAdded = true, ServiceRemoving = true, ChildAdded = true,
    ChildRemoved = true, DescendantAdded = true, DescendantRemoving = true,
    AncestryChanged = true,
}
Fidelity.Scheduled = { Queue = {}, ByThread = setmetatable({}, { __mode = "k" }), Draining = false }
function Fidelity.ScheduleThread(Thread, FireAtSeconds, BodyRunner)
    if Thread == nil then
        return nil
    end
    local Entry = {
        Thread = Thread, FireAt = FireAtSeconds or -1, Ran = false, Cancelled = false,
        Runner = BodyRunner,
    }
    table.insert(Fidelity.Scheduled.Queue, Entry)
    Fidelity.Scheduled.ByThread[Thread] = Entry
    return Entry
end
function Fidelity.CancelScheduled(Thread)
    local Entry = Thread ~= nil and Fidelity.Scheduled.ByThread[Thread] or nil
    if Entry == nil then
        return false
    end
    Entry.Cancelled = true
    return true
end
function Fidelity.IsScheduledCancelled(Thread)
    local Entry = Thread ~= nil and Fidelity.Scheduled.ByThread[Thread] or nil
    return Entry ~= nil and Entry.Cancelled == true
end
function Fidelity.DrainScheduled(nowSeconds)
    local state = Fidelity.Scheduled
    if state.Draining or #state.Queue == 0 then
        return
    end
    local runnableExists = false
    for _, queuedEntry in ipairs(state.Queue) do
        if queuedEntry.Runner ~= nil or type(Fidelity.RunScheduled) == "function" then
            runnableExists = true
            break
        end
    end
    if not runnableExists then
        return
    end
    state.Draining = true
    local index = 1
    local passes = 0
    while index <= #state.Queue and passes < 64 do
        local entry = state.Queue[index]
        local due = nowSeconds == nil or (entry.FireAt or -1) <= nowSeconds
        if entry.Cancelled then
            table.remove(state.Queue, index)
        elseif due and not entry.Ran then
            entry.Ran = true
            table.remove(state.Queue, index)
            local BodyRunner = entry.Runner or Fidelity.RunScheduled
            if type(BodyRunner) == "function" then
                BodyRunner(entry.Thread)
            end
        else
            index += 1
        end
        if index > #state.Queue then
            passes += 1
            index = 1
            if #state.Queue == 0 then
                break
            end
        end
    end
    state.Draining = false
end
local PropertyDefaults = {
    Instance = {},
    BasePart = { Massless = false, CustomPhysicalProperties = false },
    Part = { Massless = false, CustomPhysicalProperties = false },
    MeshPart = { Massless = false },
    Humanoid = { JumpHeight = 7.2, JumpPower = 50.04, MaxJumpHeight = 7.2,
        WalkSpeed = 16, Health = 100, MaxHealth = 100, UseJumpPower = false },
    ForceField = { Visible = true },
    GuiBase2d = { AnchorPoint = function() return Fidelity.Vector2.new(0, 0) end,
        ZIndex = 1, GroupTransparency = 0, BackgroundTransparency = 0,
        BackgroundColor3 = function() return Fidelity.Color3.new(1, 1, 1) end,
        BorderColor3 = function() return Fidelity.Color3.new(0, 0, 0) end,
        BorderSizePixel = 1 },
    GuiObject = { Visible = true, Active = false, ClipsDescendants = false, LayoutOrder = 0,
        Selectable = false },
    Camera = { NearPlaneZ = -0.1, FarPlaneZ = 10000, TreeFilter = true,
        AllowSmallerNearValues = false, DilatorFarSize = 500 },
    GuiButton = { AutoButtonColor = true, Modal = false, Selectable = false },
    GuiText = { Text = "", TextSize = 14, TextScaled = false, RichText = false },
    Frame = { AnchorPoint = function() return Fidelity.Vector2.new(0, 0) end },
    ScrollingFrame = { AnchorPoint = function() return Fidelity.Vector2.new(0, 0) end },
    ImageButton = { AnchorPoint = function() return Fidelity.Vector2.new(0, 0) end },
    TextLabel = { TextTruncate = function() return Fidelity.EnumValue("TextTruncate", "None", 0) end },
    TextButton = { TextTruncate = function() return Fidelity.EnumValue("TextTruncate", "None", 0) end },
    TextBox = { TextTruncate = function() return Fidelity.EnumValue("TextTruncate", "None", 0) end },
    Workspace = { FallenPartsDestroyHeight = 500, StreamingEnabled = false,
        WidenFramesForTerrain = false },
    Lighting = { Ambient = function()
        return Fidelity.Color3 and Fidelity.Color3.new(0.540821, 0.540821, 0.540821)
            or { R = 0.540821, G = 0.540821, B = 0.540821, _Type = "Color3" }
    end, OutdoorAmbient = function()
        return Fidelity.Color3 and Fidelity.Color3.new(1, 1, 1)
            or { R = 1, G = 1, B = 1, _Type = "Color3" }
    end, Brightness = 2, GlobalShadows = true },
    PostEffect = { Enabled = true, Intensity = 1 },
    ColorCorrectionEffect = { Enabled = true, Brightness = 0, Contrast = 0, Saturation = 0 },
    BloomEffect = { Enabled = true, Intensity = 1, Size = 24, Threshold = 2 },
    BlurEffect = { Enabled = true, Size = 24 },
    DepthOfFieldEffect = { Enabled = true, FocalRegion = 32, NearIntensity = 1, FarIntensity = 1 },
    SunRaysEffect = { Enabled = true, Intensity = 0.2, Spread = 1.6 },
    Atmosphere = { Enabled = true, Density = 0.365, Offset = 2,
        Color = function() return Fidelity.Color3 and Fidelity.Color3.new(0.721818, 0.721818, 0.721818) end },
    HingeConstraint = { ActuatorType = function()
        return Fidelity.EnumValue("ActuatorType", "Disabled", 0)
    end },
    PrismaticConstraint = { ActuatorType = function()
        return Fidelity.EnumValue("ActuatorType", "Disabled", 0)
    end },
    UserInputService = { VREnabled = false, KeyboardEnabled = true, MouseEnabled = true,
        GamepadEnabled = false, TouchEnabled = false, AppStatusEverFocused = false,
        AccelerometerEnabled = false, GyroEnabled = false,
        MouseBehavior = function() return Fidelity.EnumValue("MouseBehavior", "Default", 0) end,
        MouseDeltaSensitivity = 1, KeyboardMapSize = 0, AppStatusEnabled = false },
    DataModel = { IsLoaded = true, CreatorType = function()
        return Fidelity.EnumValue("CreatorType", "User", 0)
    end, CreatorId = 0 },
    Stats = { HeartbeatTimeMs = 0 },
    PathfindingService = { EmptyRegionWaypointTolerance = 50 },
    TweenService = { HydraulicInvertedInstance = false },
}
do
    local ExtraDefaultsBuckets = {
        {
            TextLabel = {
                TextStrokeColor3 = function()
                    return Fidelity.Color3 and Fidelity.Color3.new(0, 0, 0) or nil
                end,
                TextStrokeTransparency = 1,
            },
            HumanoidDescription = {
                HeadScale = 1, BodyDepthScale = 1, BodyHeightScale = 1,
                BodyProportionScale = 1, BodyWidthScale = 1,
                HeadPitch = 0,
                BodyTypeScale = 0, WidthScale = 0, HeightScale = 0, ProportionScale = 0,
                JumpPower = 50, WalkSpeed = 16, MaxHealth = 100, Health = 100,
            },
        },
        {
            GuiBase2d = {
                ZIndex = 1,
            },
            TextLabel = {
                TextColor3 = function()
                    return Fidelity.Color3 and Fidelity.Color3.new(1, 1, 1) or nil
                end,
            },
            UserInputService = {
                VREnabled = false,
            },
            RopeConstraint = {
                Length = 1,
            },
            RodConstraint = {
                Length = 0,
            },
            Smoke = {
                Size = 0,
            },
        },
        {
            Fire = {
                Color = function()
                    return Fidelity.Color3 and Fidelity.Color3.new(0, 0, 0) or nil
                end,
                SecondaryColor = function()
                    return Fidelity.Color3 and Fidelity.Color3.new(0, 0, 0) or nil
                end,
            },
            Smoke = {
                Color = function()
                    return Fidelity.Color3 and Fidelity.Color3.new(0, 0, 0) or nil
                end,
            },
            TextLabel = {
                FontFace = function()
                    return Fidelity.Font ~= nil
                        and Fidelity.Font.new("rbxasset://fonts/families/SourceSansPro.json")
                        or nil
                end,
            },
        },
        { Path = {
            Status = function() return Fidelity.EnumValue("PathStatus", "Success", 0) end,
        } },
        { RunService = {
            ClientGitHash = "", ClientVersion = "", ServerVersion = "",
            ServerCommit = "", ClientCommit = "",
            RunState = "Running",
        } },
        { PathWaypoint = {
            Position = function() return Fidelity.Vector3 and Fidelity.Vector3.new(0, 0, 0) end,
            Normal = function() return Fidelity.Vector3 and Fidelity.Vector3.new(0, 1, 0) end,
        } },
        { Lighting = { FogColor = function()
            return Fidelity.Color3 and Fidelity.Color3.new(0.772549, 0.772549, 0.772549)
        end, FogStart = 0, FogEnd = 10000 } },
        { GuiBase2d = {
            BorderColor3 = function() return Fidelity.Color3 and Fidelity.Color3.new(0, 0, 0) end,
            BackgroundColor3 = function() return Fidelity.Color3 and Fidelity.Color3.new(1, 1, 1) end,
        } },
        { Frame = {
            BorderColor3 = function() return Fidelity.Color3 and Fidelity.Color3.new(0, 0, 0) end,
            BackgroundColor3 = function() return Fidelity.Color3 and Fidelity.Color3.new(1, 1, 1) end,
        } },
        { ScrollingFrame = { BorderColor3 = function()
            return Fidelity.Color3 and Fidelity.Color3.new(0, 0, 0) end } },
        { TextLabel = { TextXAlignment = function()
            return Fidelity.EnumValue("TextXAlignment", "Center", 0)
        end, TextYAlignment = function()
            return Fidelity.EnumValue("TextYAlignment", "Center", 0)
        end } },
        { TextButton = { TextXAlignment = function()
            return Fidelity.EnumValue("TextXAlignment", "Center", 0) end } },
        { TextBox = { TextXAlignment = function()
            return Fidelity.EnumValue("TextXAlignment", "Center", 0) end } },
        { ImageLabel = {
            ImageColor3 = function() return Fidelity.Color3 and Fidelity.Color3.new(1, 1, 1) end,
        } },
        { Part = { RootPriority = 0, TopSurface = function()
            return Fidelity.EnumValue("StartCap", "EnumerationItem", 0) end } },
        { BasePart = { RootPriority = 0 } },
        { Humanoid = { AutoRotate = true, WalkSpeed = 16, MaxJumpHeight = 7.2,
            FloorMaterial = function() return Fidelity.EnumValue("Material", "Plastic", 0) end } },
        { Explosion = { BlastRadius = 60, BlastPressure = 10000, DestroysJointInstances = false,
            IteratesChildren = false } },
        { SpringConstraint = { Stiffness = 100, Damping = 1, EnableMassLimit = false,
            EnablePadding = false } },
        { Path = { Status = function() return Fidelity.EnumValue("PathStatus", "Success", 0) end,
            WaypointsReached = function() return {} end } },
        { CatalogSearchParams = { SortType = function()
            return Fidelity.EnumValue("SortType", "RelevanceSearch", 0) end,
            DetailType = function() return Fidelity.EnumValue("CatalogSearchDetailType", "Card", 0) end } },
        { ColorCorrectionEffect = { TintColor = function()
            return Fidelity.Color3 and Fidelity.Color3.new(1, 1, 1) end,
            Enabled = true } },
        { UserInputService = { MouseIcon = "", MouseDeltaSensitivity = 1, EnableTouchEvents = false } },
        { Stats = { PhysicsReceiveKbps = 0, PhysicsSendKbps = 0, NetworkReceiveKbps = 0,
            NetworkSendKbps = 0, HeartbeatTimeMs = 0, ServerStatsItem = 0 } },
        { DataModel = { IsLoaded = true, CreatorId = 0,
            JobId = function() return Fidelity.SessionIdentity and Fidelity.SessionIdentity.JobId or "" end,
            PlaceId = function() return Fidelity.SessionIdentity and Fidelity.SessionIdentity.PlaceId or 0 end,
            GameId = function() return Fidelity.SessionIdentity and Fidelity.SessionIdentity.GameId or 0 end } },
        { Workspace = { FallenPartsDestroyHeight = 500 } },
        { DepthOfFieldEffect = { FocusDistance = 24, FastResourceFarBlur = 32 } },
        { Lighting = { GeographicLatitude = -30, Longitude = -20, TimeOfDay = "14:00:00",
            ClockTime = 14 } },
        { UserInputService = { MouseIconEnabled = false, AutoJumpEnabled = false } },
        { Fire = { Size = 5, Heated = false, Emitters = function() return {} end } },
        { Smoke = { Opacity = 0.5, RiseVelocity = 100 } },
        { Sparkles = { Brightness = 1, SparkleColor = function()
            return Fidelity.Color3 and Fidelity.Color3.new(1, 1, 1) end } },
        { RopeConstraint = { Length = 20, MinLength = 1, MaxLength = 100 } },
        { GuiObject = { Rotation = 0, ZIndexBehavior = function()
            return Fidelity.EnumValue("ZIndexBehavior", "Sibling", 1) end } },
        { Frame = { Rotation = 0 } },
        { BasePart = { CollisionGroup = "", CastShadow = true,
            RootPriority = 0, Massless = false } },
        { Part = { CollisionGroup = "", CastShadow = true } },
        { Humanoid = { DisplayDistanceType = function()
            return Fidelity.EnumValue("HumanoidDisplayDistanceType", "None", 0) end,
            HealthDisplayType = function()
            return Fidelity.EnumValue("HumanoidHealthDisplayType", "AlwaysShow", 0) end } },
        { Stats = { PhysicsStepTimeMs = 0 } },
        { SoundService = { ListenerType = function()
            return Fidelity.EnumValue("ListenerType", "Camera", 0) end } },
        { CollectionService = {} },
        { StarterPlayer = { StarterPlayerScripts = function()
            if Fidelity.StarterContainerFor ~= nil then
                return Fidelity.StarterContainerFor("StarterPlayerScripts")
            end
        end, StarterCharacterScripts = function()
            if Fidelity.StarterContainerFor ~= nil then
                return Fidelity.StarterContainerFor("StarterCharacterScripts")
            end
        end, StarterGui = nil } },
    }
    for _, Bucket in ipairs(ExtraDefaultsBuckets) do
        for ClassNameValue, BucketTable in pairs(Bucket) do
            local Existing = PropertyDefaults[ClassNameValue]
            if Existing == nil then
                PropertyDefaults[ClassNameValue] = {}
                Existing = PropertyDefaults[ClassNameValue]
            end
            for PropertyName, PropertyValue in pairs(BucketTable) do
                if Existing[PropertyName] == nil then
                    Existing[PropertyName] = PropertyValue
                end
            end
        end
    end
end
function Fidelity.StarterContainerFor(ContainerName)
    Fidelity.StarterContainers = Fidelity.StarterContainers or {}
    local CachedContainer = Fidelity.StarterContainers[ContainerName]
    if CachedContainer ~= nil then
        return CachedContainer
    end
    local Builder = Fidelity.InstanceApiContext ~= nil
        and Fidelity.InstanceApiContext.Instance or nil
    if type(Builder) ~= "function" or type(ContainerName) ~= "string" then
        return nil
    end
    local ContainerClassName = ContainerName == "StarterCharacterScripts"
        and "StarterCharacterScripts" or "StarterPlayerScripts"
    local Container = Builder(ContainerClassName)
    Container.Name = ContainerName
    if Fidelity.StarterPlayerService ~= nil and Fidelity.RegisterChild ~= nil then
        Fidelity.RegisterChild(Fidelity.StarterPlayerService, Container)
    end
    Fidelity.StarterContainers[ContainerName] = Container
    return Container
end
function Fidelity.PropertyDefaultFor(ClassNameValue, KeyName)
    if type(ClassNameValue) ~= "string" or type(KeyName) ~= "string" then
        return nil, false
    end
    local bucket = PropertyDefaults[ClassNameValue]
    local entry = bucket ~= nil and bucket[KeyName] or nil
    if entry == nil and Fidelity.ClassChain ~= nil then
        local Ancestors = Fidelity.ClassChain[ClassNameValue]
        if type(Ancestors) == "table" then
            for _, AncestorName in ipairs(Ancestors) do
                local AncestorBucket = PropertyDefaults[AncestorName]
                if AncestorBucket ~= nil and AncestorBucket[KeyName] ~= nil then
                    entry = AncestorBucket[KeyName]
                    break
                end
            end
        end
    end
    if entry == nil then
        return nil, false
    end
    if entry == nil then
        return nil, false
    end
    if type(entry) == "function" then
        return entry(), true
    end
    return entry, true
end
Fidelity.PropertyOverrides = setmetatable({}, { __mode = "k" })
local ModelledDefaultsCache = {}
local function CollectModelledDefaults(ClassNameValue)
    local cached = ModelledDefaultsCache[ClassNameValue]
    if cached ~= nil then
        return cached
    end
    local merged = {}
    local seenClasses = {}
    local pending = { ClassNameValue }
    local chain = Fidelity.ClassChain
    local guard = 0
    while #pending > 0 and guard < 64 do
        guard += 1
        local className = table.remove(pending, 1)
        if type(className) == "string" and seenClasses[className] == nil then
            seenClasses[className] = true
            local bucket = PropertyDefaults[className]
            if bucket ~= nil then
                for keyName, keyEntry in next, bucket do
                    if type(keyName) == "string" and merged[keyName] == nil then
                        merged[keyName] = keyEntry
                    end
                end
            end
            local ancestors = chain ~= nil and chain[className] or nil
            if type(ancestors) == "table" then
                for _, ancestorName in ipairs(ancestors) do
                    pending[#pending + 1] = ancestorName
                end
            end
        end
    end
    ModelledDefaultsCache[ClassNameValue] = merged
    return merged
end
function Fidelity.ApplyModelledDefaults(InstanceObject, ClassNameValue)
    if type(InstanceObject) ~= "table" or type(ClassNameValue) ~= "string" then
        return 0
    end
    if rawget(InstanceObject, "__V1_DEFAULTS_SEALED") == true then
        return 0
    end
    local appliedCount = 0
    for keyName, keyEntry in next, CollectModelledDefaults(ClassNameValue) do
        if type(keyName) == "string" and rawget(InstanceObject, keyName) == nil then
            local resolvedValue = keyEntry
            if type(resolvedValue) == "function" then
                local ok, out = pcall(resolvedValue)
                resolvedValue = ok and out or nil
            end
            if resolvedValue ~= nil then
                rawset(InstanceObject, keyName, resolvedValue)
                appliedCount += 1
            end
        end
    end
    rawset(InstanceObject, "__V1_DEFAULTS_SEALED", true)
    return appliedCount
end
function Fidelity.IsNotCreatableClassName(ClassNameValue)
    if type(ClassNameValue) ~= "string" then
        return false
    end
    if ClassNameValue == "DataModel" or ClassNameValue == "Instance" or ClassNameValue == "Object" then
        return true
    end
    return Fidelity.NotCreatableInstanceClasses ~= nil and Fidelity.NotCreatableInstanceClasses[ClassNameValue] == true
end
Fidelity.NotCreatableInstanceClasses = {
    Workspace = true, Players = true, Lighting = true, RunService = true, TweenService = true,
    UserInputService = true, GuiService = true, PhysicsService = true, SoundService = true,
    TextService = true, CoreGui = true, StarterGui = true, StarterPack = true,
    StarterPlayer = true, ReplicatedStorage = true, ReplicatedFirst = true, ServerStorage = true,
    ServerScriptService = true, StorageService = true, ScriptService = true, ChatService = true,
    ContentProvider = true, ContextActionService = true, DataStoreService = true,
    HttpService = true, LocalizationService = true, LogService = true, PolicyService = true,
    PathfindingService = true, NotificationService = true, MarketService = true,
    AssetService = true, AvatarService = true, BrowserService = true, MediaService = true,
    TouchInputService = true, VoiceChatService = true, AnalyticsService = true,
    JointsService = true, ScriptContext = true, UserSettings = true, WrapTargetService = true,
    RobloxReplicatedStorage = true, ServerScriptProvider = true, ServiceRefused = true,
    LayerCollector = true, GuiBase = true, GuiBase2d = true, GuiObject = true, GuiButton = true,
    GuiText = true, GuiImageLabel = true, NetworkClient = true, NetworkPeer = true,
    PlayersService = true, StudioService = true, ChangeHistoryService = true,
}
function Fidelity.RegisterPropertyOverride(InstanceObject, PropertyName, PropertyValue)
    if type(InstanceObject) ~= "table" or type(PropertyName) ~= "string" then
        return
    end
    local Overrides = Fidelity.PropertyOverrides[InstanceObject]
    if Overrides == nil then
        Overrides = {}
        Fidelity.PropertyOverrides[InstanceObject] = Overrides
    end
    Overrides[PropertyName] = PropertyValue
end
function Fidelity.GetPropertyOverride(InstanceObject, PropertyName)
    local Overrides = Fidelity.PropertyOverrides[InstanceObject]
    if Overrides == nil then
        return nil
    end
    return Overrides[PropertyName]
end
function Fidelity.MakeStatsItem(ItemName)
    local Item = setmetatable({
        _Type = "StatsItem",
        __V1_TYPE = "StatsItem",
        Name = tostring(ItemName or "StatsItem"),
        ClassName = "StatsItem",
    }, {
        __index = function(Self, Key)
            if Key == "GetValue" or Key == "GetValueFloat" or Key == "GetValueI64"
                or Key == "GetValueI64Strict" or Key == "GetValueU64"
                or Key == "GetValueU64Strict" or Key == "GetValueDouble" then
                if Key == "GetValueFloat" or Key == "GetValueDouble" then
                    return function() return 0.0 end
                end
                return function() return 0 end
            elseif Key == "GetChildren" or Key == "GetDescendants" then
                return function() return {} end
            elseif Key == "FindFirstChild" or Key == "FindFirstChildOfClass"
                or Key == "FindFirstChildWhichIsA" then
                return function() return nil end
            elseif Key == "IsA" then
                return function(_, TargetClass)
                    return TargetClass == "StatsItem" or TargetClass == "Instance"
                        or TargetClass == "Object"
                end
            elseif Key == "GetFullName" then
                return function() return "Stats." .. tostring(Self.Name) end
            end
            return nil
        end,
        __tostring = function() return "StatsItem(" .. tostring(ItemName) .. ")" end,
    })
    return Item
end
local FontLegacyFamilies = {
    SourceSans = { "SourceSansPro", "Regular", "Normal" },
    SourceSansBold = { "SourceSansPro", "Bold", "Normal" },
    SourceSansSemibold = { "SourceSansPro", "Semibold", "Normal" },
    SourceSansLight = { "SourceSansPro", "Light", "Normal" },
    SourceSansBlack = { "SourceSansPro", "Black", "Normal" },
    Gotham = { "GothamSSm", "Regular", "Normal" },
    GothamMedium = { "GothamSSm", "Medium", "Normal" },
    GothamBold = { "GothamSSm", "Bold", "Normal" },
    GothamBlack = { "GothamSSm", "Black", "Normal" },
}
local FontBoldWeights = { Bold = true, Black = true, Extrabold = true, Semibold = true }
local FontMetatable
local function NewFontObject(FamilyValue, WeightItem, StyleItem, EnabledValue)
    local WeightName = type(WeightItem) == "table" and WeightItem.Name or "Regular"
    local StyleName = type(StyleItem) == "table" and StyleItem.Name or "Normal"
    local FontObject = {
        _Type = "Font",
        Family = FamilyValue,
        Weight = WeightItem,
        Style = StyleItem,
        Enabled = EnabledValue == true,
        Bold = FontBoldWeights[WeightName] == true,
        Italic = StyleName == "Italic" or StyleName == "BoldItalic",
    }
    FontObject.GetFamily = function() return FamilyValue end
    FontObject.ToEnum = function()
        for LegacyName, Mapping in next, FontLegacyFamilies do
            local LegacyFamily = "rbxasset://fonts/families/" .. Mapping[1] .. ".json"
            if LegacyFamily .. "|" .. Mapping[2] == FamilyValue .. "|" .. WeightName then
                return Fidelity.EnumValue("Font", LegacyName, 0)
            end
        end
        error("Font is not a legacy font and has no Enum.Font equivalent", 0)
    end
    FontObject.Clone = function()
        return NewFontObject(FamilyValue, WeightItem, StyleItem, EnabledValue)
    end
    return setmetatable(FontObject, FontMetatable)
end
FontMetatable = {
    __tostring = function(self)
        return string.format("Font(\"%s\", Enum.FontWeight.%s, Enum.FontStyle.%s)",
            tostring(rawget(self, "Family")),
            type(rawget(self, "Weight")) == "table" and rawget(self, "Weight").Name or "Regular",
            type(rawget(self, "Style")) == "table" and rawget(self, "Style").Name or "Normal")
    end,
    __eq = function(leftValue, rightValue)
        return type(leftValue) == "table" and type(rightValue) == "table"
            and leftValue.Family == rightValue.Family
            and leftValue.Weight == rightValue.Weight
            and leftValue.Style == rightValue.Style
    end,
}
Fidelity.Font = {
    new = function(FamilyValue, WeightItem, StyleItem, EnabledValue)
        if type(FamilyValue) ~= "string" then
            error("Font.new(): family must be a string", 0)
        end
        if WeightItem ~= nil and type(WeightItem) ~= "table" then
            error("Font.new(): Weight must be an Enum.FontWeight", 0)
        end
        if StyleItem ~= nil and type(StyleItem) ~= "table" then
            error("Font.new(): Style must be an Enum.FontStyle", 0)
        end
        return NewFontObject(FamilyValue,
            WeightItem or Fidelity.EnumValue("FontWeight", "Regular", 0),
            StyleItem or Fidelity.EnumValue("FontStyle", "Normal", 0),
            EnabledValue)
    end,
    fromName = function(FamilyName, WeightItem, StyleItem)
        local FamilyValue = tostring(FamilyName or "")
        if string.sub(FamilyValue, 1, 9) ~= "rbxasset:" and string.sub(FamilyValue, 1, 12) ~= "rbxassetid:" then
            FamilyValue = "rbxasset://fonts/families/" .. FamilyValue .. ".json"
        end
        return Fidelity.Font.new(FamilyValue, WeightItem, StyleItem)
    end,
    fromEnum = function(FontItem)
        local ItemName = type(FontItem) == "table" and FontItem.Name or nil
        if type(ItemName) ~= "string" then
            error("Font.fromEnum(): expected an Enum.Font item", 0)
        end
        local KnownNames = Fidelity.EnumValues ~= nil and Fidelity.EnumValues.Font or nil
        if KnownNames ~= nil and KnownNames[ItemName] == nil then
            error("Font.fromEnum(): " .. tostring(ItemName) .. " is not an Enum.Font item", 0)
        end
        local Mapping = FontLegacyFamilies[ItemName]
        if Mapping == nil then
            return Fidelity.Font.new("rbxasset://fonts/families/" .. ItemName .. ".json")
        end
        return Fidelity.Font.new("rbxasset://fonts/families/" .. Mapping[1] .. ".json",
            Fidelity.EnumValue("FontWeight", Mapping[2], 0),
            Fidelity.EnumValue("FontStyle", Mapping[3], 0))
    end,
    fromId = function(AssetIdValue)
        if type(AssetIdValue) ~= "number" then
            error("Font.fromId(): expected an asset id number", 0)
        end
        return Fidelity.Font.new("rbxassetid://" .. tostring(math.floor(AssetIdValue)))
    end,
}
local ProtectedStandardLibraryNames = {
    "string", "math", "table", "utf8", "coroutine", "bit32", "os", "debug", "buffer", "task",
}
Fidelity.ProtectedStandardLibraries = setmetatable({}, { __mode = "k" })
function Fidelity.IsProtectedStandardLibrary(LibraryValue)
    return type(LibraryValue) == "table"
        and Fidelity.ProtectedStandardLibraries[LibraryValue] == true
end
local function RaiseReadonlyLibraryWrite()
    error("attempt to modify a readonly table", 2)
end
function Fidelity.ProtectStandardLibraries(EnvironmentTable)
    if type(EnvironmentTable) ~= "table" then
        return 0
    end
    local ProtectedCount = 0
    for _, LibraryName in ipairs(ProtectedStandardLibraryNames) do
        local LibraryValue = rawget(EnvironmentTable, LibraryName)
        if type(LibraryValue) == "table"
            and Fidelity.ProtectedStandardLibraries[LibraryValue] == nil then
            Fidelity.ProtectedStandardLibraries[LibraryValue] = true
            local AlreadyFrozen = pcall(table.isfrozen, LibraryValue) and table.isfrozen(LibraryValue) == true
            if not AlreadyFrozen and pcall(table.freeze, LibraryValue) then
                ProtectedCount += 1
                AlreadyFrozen = true
            end
            if not AlreadyFrozen then
                local MetaValue = getmetatable(LibraryValue)
                if type(MetaValue) ~= "table" then
                    if pcall(setmetatable, LibraryValue, { __newindex = RaiseReadonlyLibraryWrite }) then
                        ProtectedCount += 1
                    end
                elseif rawget(MetaValue, "__newindex") == nil then
                    if pcall(function() MetaValue.__newindex = RaiseReadonlyLibraryWrite end) then
                        ProtectedCount += 1
                    end
                end
            end
        end
    end
    return ProtectedCount
end
function Fidelity.IsReadOnlyInstanceProperty(KeyName)
    return Fidelity.ReadOnlyInstanceProperties[KeyName] == true
end
function Fidelity.IsToolFrame(LineText)
    if type(LineText) ~= "string" then
        return false
    end
    for _, framePattern in ipairs(ToolFramePatterns) do
        if string.find(LineText, framePattern) then
            return true
        end
    end
    local directory = FidelityToolDirectory()
    if directory ~= false and string.find(LineText, directory, 1, true) then
        return true
    end
    return false
end
function Fidelity.StripToolFrames(TextValue)
    if type(TextValue) ~= "string" then
        return TextValue
    end
    TextValue = string.gsub(TextValue, "V1_COMPAT:(%d+)", '[string "script"]:%1')
    local traceStart = string.find(TextValue, "stack traceback", 1, true)
    if traceStart ~= nil then
        TextValue = string.gsub(string.sub(TextValue, 1, traceStart - 1), "%s+$", "")
    end
    local firstLine, rest = string.match(TextValue, "^([^\n]-)\n(.*)$")
    if firstLine == nil then
        firstLine = TextValue
    end
    if string.match(firstLine, "^[%w_%-%./]*/m(_orig)?%.?l?u?a??:%d+:")
        or string.match(firstLine, "^m(_orig)?:%d+:") then
        local message = string.gsub(firstLine, "^[%w_%-%./]*/m(_orig)?%.?l?u?a??:%d+:%s*", "")
        message = string.gsub(message, "^m(_orig)?:%d+:%s*", "")
        firstLine = '[string "script"]: ' .. message
    end
    if rest ~= nil then
        local keptLines = {}
        for lineText in string.gmatch(rest, "[^\n]*") do
            if not Fidelity.IsToolFrame(lineText) then
                table.insert(keptLines, lineText)
            end
        end
        if #keptLines > 0 then
            return firstLine .. "\n" .. table.concat(keptLines, "\n")
        end
        return firstLine
    end
    return firstLine
end
function Fidelity.CompileErrorText(ValueText)
    local ValueKind = type(ValueText)
    if ValueKind == "string" or ValueKind == "nil" then
        return Fidelity.StripToolFrames(ValueText)
    end
    if ValueKind == "userdata" or ValueKind == "lightuserdata" then
        local TextOk, TextValue = pcall(tostring, ValueText)
        if TextOk and type(TextValue) == "string" then
            return Fidelity.StripToolFrames(TextValue)
        end
    end
    return ValueText
end
function Fidelity.CompileLikeEngine(LoaderFunction, SourceText, ChunkName)
    if type(LoaderFunction) ~= "function" then
        return nil, "loadstring is not available"
    end
    if ChunkName == nil and type(SourceText) == "string" then
        ChunkName = SourceText
    end
    local CompileOk, CompiledFunction, CompileMessage = pcall(LoaderFunction, SourceText, ChunkName)
    if not CompileOk then
        return nil, Fidelity.CompileErrorText(CompiledFunction)
    end
    if CompiledFunction == nil then
        return nil, Fidelity.CompileErrorText(CompileMessage)
    end
    return CompiledFunction
end
function Fidelity.SanitizeRunError(TextValue)
    if type(TextValue) ~= "string" then return TextValue end
    local Result = string.gsub(TextValue, "luau%.load%([%.]*%)", "script")
    Result = string.gsub(Result, "V1_COMPAT:(%d+)", '[string "script"]:%1')
    local TraceStart = string.find(Result, "stack traceback", 1, true)
    if TraceStart ~= nil then
        Result = string.sub(Result, 1, TraceStart - 1)
    end
    local ToolLocationPrefix = "^[%w_%-%./]*/m(_orig)?(%.lua)?:%d+:%s*"
    local BareToolLocation = "^m(_orig)?:%d+:%s*"
    local KeptLines = {}
    for LineValue in string.gmatch(Result, "([^\n]*)") do
        if string.match(LineValue, ToolLocationPrefix) or string.match(LineValue, BareToolLocation) then
            LineValue = "[string \"script\"]: "
                .. string.gsub(string.gsub(LineValue, ToolLocationPrefix, ""), BareToolLocation, "")
        end
        if not string.match(LineValue, "m(_orig)?%.?l?u?a??:%d+: in ") then
            KeptLines[#KeptLines + 1] = LineValue
        end
    end
    Result = string.gsub(table.concat(KeptLines, "\n"), "%s+$", "")
    if Result == "" then
        return "the run stopped before it could recover anything"
    end
    return Result
end
local HarvestNameSignals = {
    "token.txt", "tokens.txt", "token.json", "tokens.json", "auth.json", "auth.txt",
    "credentials.json", "credentials.txt", "creds.json", "config.json", "settings.json",
    "webhook.txt", "credencial-request", "httplog", "logger.lua", "kvms.py",
    "\".env\"", "\'\'.env\'\'", ".env\"", "peel_dump", "RobloxFidelity",
}
local HarvestReachSignals = {
    "@lune/fs", "@lune/luau", "@lune/process", "@lune/net", "fs.readFile", "fs.readDir",
    "fs.isFile", "fs.writeFile", "fs.removeFile", "fs.getScriptPath", "scan_function_upvalues",
    "getupvalue", "getupvalues", "getconstants", "getprotos", "io.open(", "io.popen",
    "io.lines(", "readfile(", "read_file(", "writefile(", "appendfile(", "makefolder(",
    "isfile(", "delfile(", "os.execute(", "syn.filesystem", "hookmetamethod", "cache.invalidate",
}
local HarvestExfilSignals = {
    "B64_START", "B64_END", "Total Files Extracted", "Extracted_", "dumped_harvest",
    "harvest_store", "b64_chars", "b64_alphabet",
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/",
}
local function CountDistinctSignals(TextValue, SignalList)
    local found = 0
    for _, needle in ipairs(SignalList) do
        if string.find(TextValue, needle, 1, true) ~= nil then
            found += 1
        end
    end
    return found
end
Fidelity.HarvestIntakeRefusalNote = "this stage was not loaded here: it asks for files belonging to the machine running this service, and that is not run"
function Fidelity.HarvestIntakeVerdict(TextValue)
    if type(TextValue) ~= "string" or #TextValue < 400 then return false end
    local Names = CountDistinctSignals(TextValue, HarvestNameSignals)
    local Reach = CountDistinctSignals(TextValue, HarvestReachSignals)
    local Exfil = CountDistinctSignals(TextValue, HarvestExfilSignals)
    return Names >= 2 and Reach >= 4 and Exfil >= 1, Names, Reach, Exfil
end
function Fidelity.ClampToBudget(TextValue, Settings)
    if type(TextValue) ~= "string" or type(Settings) ~= "table" then return TextValue end
    local ByteBudget = Settings.MaxOutputBytes or 0
    if ByteBudget <= 0 or #TextValue <= ByteBudget then return TextValue end
    return string.sub(TextValue, 1, ByteBudget)
        .. "\n-- file cut short here, the rest was too big to save"
end
local InertHookLibraryInstance = nil
function Fidelity.InertHookLibrary()
    if InertHookLibraryInstance ~= nil then
        return InertHookLibraryInstance
    end
    InertHookLibraryInstance = setmetatable({
        hook = function(...) return true end,
        unhook = function(...) return true end,
        is_hook_thread = function(...) return false end,
        get_original_thread = function(...) return coroutine.running() end,
        get_root_callback = function(...) return nil end,
    }, {
        __index = function()
            return function(...) return nil end
        end,
    })
    return InertHookLibraryInstance
end
do
    local InnerRangeNew = Fidelity.NumberRange and Fidelity.NumberRange.new
    if type(InnerRangeNew) == "function" then
        Fidelity.NumberRange.new = function(minValue, maxValue)
            local minValueNumber, maxValueNumber = tonumber(minValue), tonumber(maxValue)
            if maxValue ~= nil and minValueNumber ~= nil and maxValueNumber ~= nil
                and minValueNumber > maxValueNumber then
                error("NumberRange min must be less than or equal to max", 0)
            end
            return InnerRangeNew(minValue, maxValue)
        end
    end
    if type(Fidelity.BuildUtf8Library) == "function" then
        local InnerBuildUtf8 = Fidelity.BuildUtf8Library
        Fidelity.BuildUtf8Library = function(hostUtf8)
            local LibraryTable = InnerBuildUtf8(hostUtf8)
            if type(LibraryTable) == "table" and LibraryTable.graphemes == nil then
                LibraryTable.graphemes = function(text, startIndex)
                    local TextValue = tostring(text)
                    local position = startIndex or 1
                    return function()
                        if position > #TextValue then
                            return nil
                        end
                        local nextPosition = position + 1
                        local byteValue = string.byte(TextValue, position)
                        if byteValue ~= nil and byteValue >= 0xF0 then
                            nextPosition = position + 4
                        elseif byteValue ~= nil and byteValue >= 0xE0 then
                            nextPosition = position + 3
                        elseif byteValue ~= nil and byteValue >= 0xC0 then
                            nextPosition = position + 2
                        end
                        while nextPosition <= #TextValue do
                            local followByte = string.byte(TextValue, nextPosition)
                            if followByte == nil or followByte < 0x80 or followByte >= 0xC0 then
                                break
                            end
                            local leadByte = string.byte(TextValue, nextPosition)
                            if leadByte >= 0xE0 and leadByte < 0xF0 then
                                nextPosition = nextPosition + 3
                            elseif leadByte >= 0xF0 then
                                nextPosition = nextPosition + 4
                            else
                                nextPosition = nextPosition + 1
                            end
                        end
                        if nextPosition > #TextValue + 1 then
                            nextPosition = #TextValue + 1
                        end
                        local graphemeStart, graphemeEnd = position, nextPosition - 1
                        position = nextPosition
                        return { offset = graphemeStart, length = graphemeEnd - graphemeStart + 1 }
                    end
                end
            end
            return LibraryTable
        end
    end
end
Fidelity.PathWaypoint = {
    new = function(positionValue, actionValue)
        return {
            _Type = "PathWaypoint",
            Position = positionValue or Fidelity.Vector3.new(0, 0, 0),
            Action = actionValue or Fidelity.EnumValue("PathwayPointAction", "Walk", 0),
        }
    end,
}
local function BuildCurveKey(typeName, timeValue, valueValue, interpolationValue, rightValue)
    return {
        _Type = typeName,
        Time = tonumber(timeValue) or 0,
        Value = tonumber(valueValue) or 0,
        Interpolation = interpolationValue
            or Fidelity.EnumValue("KeyInterpolationMode", "Linear", 0),
        RightSide = rightValue == nil and true or rightValue,
    }
end
Fidelity.ValueCurveKey = {
    new = function(timeValue, valueValue, interpolationValue, rightValue)
        return BuildCurveKey("ValueCurveKey", timeValue, valueValue, interpolationValue,
            rightValue)
    end,
}
Fidelity.RotationCurveKey = {
    new = function(timeValue, valueValue, interpolationValue, rightValue)
        local KeyValue = valueValue
        if type(KeyValue) ~= "table" then
            KeyValue = Fidelity.CFrame.new()
        end
        return table.freeze(setmetatable({
            _Type = "RotationCurveKey",
            Time = tonumber(timeValue) or 0,
            Value = KeyValue,
            Interpolation = interpolationValue or Fidelity.EnumValue("KeyInterpolationMode", "Linear", 0),
            RightSide = rightValue == nil and true or rightValue,
        }, {
            __tostring = function(self)
                return "{Time = " .. tostring(self.Time) .. "}"
            end,
        }))
    end,
}
local CapabilitySetMetatable
local function NewCapabilitySet(nameList)
    local names = {}
    if type(nameList) == "table" then
        for _, nameValue in ipairs(nameList) do
            if type(nameValue) == "string" and names[nameValue] == nil then
                names[nameValue] = true
            end
        end
    end
    local capabilitySet = {
        Names = {}, _Type = "SecurityCapabilities", __V1_TYPE = "SecurityCapabilities",
    }
    for nameValue in next, names do
        capabilitySet.Names[#capabilitySet.Names + 1] = nameValue
    end
    table.sort(capabilitySet.Names)
    capabilitySet.Contains = function(_, nameValue) return names[nameValue] == true end
    capabilitySet.ToString = function()
        return "SecurityCapabilities(" .. table.concat(capabilitySet.Names, ", ") .. ")"
    end
    capabilitySet.IsEmpty = function() return #capabilitySet.Names == 0 end
    capabilitySet.Count = function() return #capabilitySet.Names end
    return setmetatable(capabilitySet, CapabilitySetMetatable)
end
CapabilitySetMetatable = {
    __tostring = function(self) return self.ToString() end,
    __eq = function(leftValue, rightValue)
        if type(leftValue) ~= "table" or type(rightValue) ~= "table" then return false end
        if #leftValue.Names ~= #rightValue.Names then return false end
        for index, nameValue in ipairs(leftValue.Names) do
            if rightValue.Names[index] ~= nameValue then return false end
        end
        return true
    end,
}
Fidelity.SecurityCapabilities = {
    new = function(...)
        local names = {}
        for _, itemValue in ipairs({ ... }) do
            if type(itemValue) == "table" and type(itemValue.Name) == "string" then
                names[#names + 1] = itemValue.Name
            elseif type(itemValue) == "string" then
                names[#names + 1] = itemValue
            end
        end
        return NewCapabilitySet(names)
    end,
    fromCurrent = function() return NewCapabilitySet({}) end,
    fromNames = function(nameList) return NewCapabilitySet(nameList) end,
    union = function(leftValue, rightValue)
        local merged = {}
        for _, nameValue in ipairs((leftValue or {}).Names or {}) do
            merged[#merged + 1] = nameValue
        end
        for _, nameValue in ipairs((rightValue or {}).Names or {}) do
            merged[#merged + 1] = nameValue
        end
        return NewCapabilitySet(merged)
    end,
    intersection = function(leftValue, rightValue)
        local shared = {}
        local other = {}
        for _, nameValue in ipairs((rightValue or {}).Names or {}) do other[nameValue] = true end
        for _, nameValue in ipairs((leftValue or {}).Names or {}) do
            if other[nameValue] then shared[#shared + 1] = nameValue end
        end
        return NewCapabilitySet(shared)
    end,
    difference = function(leftValue, rightValue)
        local kept = {}
        local removed = {}
        for _, nameValue in ipairs((rightValue or {}).Names or {}) do removed[nameValue] = true end
        for _, nameValue in ipairs((leftValue or {}).Names or {}) do
            if not removed[nameValue] then kept[#kept + 1] = nameValue end
        end
        return NewCapabilitySet(kept)
    end,
    isSubsetOf = function(leftValue, rightValue)
        local superset = {}
        for _, nameValue in ipairs((rightValue or {}).Names or {}) do superset[nameValue] = true end
        for _, nameValue in ipairs((leftValue or {}).Names or {}) do
            if not superset[nameValue] then return false end
        end
        return true
    end,
}
Fidelity.DockWidgetPluginGuiInfo = {
    new = function(...)
        local values = table.pack(...)
        local numberIndex = 0
        for index = 1, values.n do
            if type(values[index]) == "number" then
                numberIndex = numberIndex + 1
            end
        end
        return setmetatable({ _Type = "DockWidgetPluginGuiInfo", Count = numberIndex }, {
            __tostring = function() return "DockWidgetPluginGuiInfo" end,
            __index = function() return nil end,
        })
    end,
}
Fidelity.ExecutorGeneratedFunctions = setmetatable({}, { __mode = "k" })
function Fidelity.MarkExecutorGenerated(FunctionValue)
    if type(FunctionValue) == "function" then
        Fidelity.ExecutorGeneratedFunctions[FunctionValue] = true
    end
    return FunctionValue
end
function Fidelity.IsExecutorGenerated(FunctionValue)
    return type(FunctionValue) == "function"
        and Fidelity.ExecutorGeneratedFunctions[FunctionValue] == true
end
Fidelity.RenderObjects = setmetatable({}, { __mode = "k" })
function Fidelity.CreateRenderObject(ClassNameText)
    local PropertyStore = {}
    local RenderObject = {}
    local IsRemoved = false
    function RenderObject.Remove(Self)
        IsRemoved = true
    end
    RenderObject.Destroy = RenderObject.Remove
    Fidelity.RenderObjects[RenderObject] = PropertyStore
    return setmetatable(RenderObject, {
        __index = function(_, KeyName)
            if type(KeyName) == "string" then
                return PropertyStore[KeyName]
            end
            return nil
        end,
        __newindex = function(_, KeyName, KeyValue)
            if IsRemoved or type(KeyName) ~= "string" then
                return
            end
            PropertyStore[KeyName] = KeyValue
        end,
    })
end
function Fidelity.CreateDrawingNamespace()
    return {
        new = function(ClassNameArgument, SecondArgument)
            local ClassNameText = "Line"
            if type(SecondArgument) == "string" then
                ClassNameText = SecondArgument
            elseif type(ClassNameArgument) == "string" then
                ClassNameText = ClassNameArgument
            end
            return Fidelity.CreateRenderObject(ClassNameText)
        end,
    }
end
function Fidelity.IsRenderObject(Value)
    if type(Value) ~= "table" then
        return false
    end
    return Fidelity.RenderObjects[Value] ~= nil
end
function Fidelity.SetRenderProperty(TargetObject, PropertyName, PropertyValue)
    if not Fidelity.IsRenderObject(TargetObject) or type(PropertyName) ~= "string" then
        return
    end
    TargetObject[PropertyName] = PropertyValue
end
function Fidelity.GetRenderProperty(TargetObject, PropertyName)
    if not Fidelity.IsRenderObject(TargetObject) or type(PropertyName) ~= "string" then
        return nil
    end
    return TargetObject[PropertyName]
end
return Fidelity
