--!nonstrict
--!nolint

local DONT_DELETE_FILES = false
local DONE_PROCESSING = false
local NON_ENGLISH = "[\0-\31\189-\255{}]"
local WHILE_LIMIT = 1_500_000
local MAIN_THREAD = coroutine.running()

local TypesLib = require("./mods/types")
local AstLib = require("./mods/ast")
local IsGarbageString, SetGarbageData = unpack(require("./mods/garbage"))

local IsLowerCase = function(byte : number) return byte >= 97 and byte <= 122 end
local IsUpperCase = function(byte : number) return byte >= 65 and byte <= 90 end
local IsBetween = function(n : number, min: number, max : number) return n >= min and n <= max end

--! helper funcs ^^

type AstExpression = TypesLib.AstExpression
type AstBlock = TypesLib.AstBlock
type Spied = TypesLib.Spied
type Variable = string
type func = (...any) -> ...any
type dict = { [any]: any }
type array = { any }
type tbl = dict | array
type VariableData = {
    var: string,
    self: Spied
}
type Internal = {
    [Variable]: { any }
}
type Variables = {
    [any]: Variable
}
type Environment = {
    [string]: (any) -> any | { [string]: any }
}
type P = Instance
type FunctionHooks = {
    [func]: func
}

local Ast = AstLib.Ast

local fenv = getfenv();
local lune_luau = require("@lune/luau")
local loadstring = lune_luau.load
local compile = lune_luau.compile

local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")
local roblox = table.clone(require("@lune/roblox"))
local task = require("@lune/task")
local stdio = require("@lune/stdio")

local TIME_TO_WAIT = task.wait();
local LURAPH_COMPRESSED;
local PRINT = print;
local MAX_OPS_MUL = 1;

local Instance = roblox.Instance

local ExecutorEnvironment = require("./env/exec")
local RandomLib = require("./env/random")
local DateTime = require("./env/datetime")
local InstanceLib, InstanceFuncs = unpack(require("./env/instances"))
local ExploitLib = require("./env/genv")
local GetTerrainMaterialColor = require("./env/terrain")

local Services = {} :: { [string]: { [any]: any } }
local Predefined = {} :: { [any]: any }
local Deferred = {} :: { func }
local IteratorTypes = {} :: { [string]: { any } } -- for example, ["game"] = { number, Instance }
local AliasToName = {
    int64 = "number",
    double = "number",
    int = "number"
}
local FunctionHooks = {} :: FunctionHooks
local Lengths = {} :: { [Spied]: number }
local Illegal = {
    ["for"] = true,
    ["end"] = true,
    -- ... other keywords
}

for Key, Data in next, InstanceLib do
    if table.find(Data.tags or {}, "Service") then
        Services[Key] = Data
    end
end

--[[
local process = require("@lune/process")
local roblox = {};
local serde = require("@lune/serde")
local net = require("@lune/net")]]

local min, max = math.min, math.max
local insert, pack, find, concat, isfrozen = table.insert, table.pack, table.find, table.concat, table.isfrozen;
local rep, format, gsub, match, split, sub = string.rep, string.format, string.gsub, string.match, string.split, string.sub;
local debuginfo = debug.info
local GlobalIndex : func, TypeSpy : ( string, string, ...any) -> any;

local Alphabet : { string } = split("abcdefghijklmnopqrstuvwxyz", "")

local function GenId(len)
    local txt = ''
    for i = 1,len or 6 do
        txt ..= Alphabet[math.random(1, #Alphabet)]
    end
    return txt
end

local TraceId : string = GenId(6)
local HardwareId : string = GenId(4) .. "-" .. GenId(4) .. "-" .. GenId(4) .. "-" .. GenId(4)
local CallId : string = GenId(8)
local MemoryCategory : string = TraceId
local EnvName : string = "fenv"
local ConstantsStr: string = "constants"
local Casing : string = "pascal"

local IgnoreInEq = {
    [EnvName] = true,
    _G = true,
    string = true,
    tostring = true
}
local StatementHooks = {}

local LuaGlobals = {}
for _, v in next, { "type", "print", "warn", "tostring", "tonumber", "newproxy" } do LuaGlobals[v] = true end

local SharedGlobals = {
    SavedPristine = {},
    PristineKeys = {
        game = true, workspace = true, task = true, CFrame = true, spawn = true
    },
    Pristine = false,
    Logs = {}, --> print & warn & others
    Callbacks = {},
    Deferred = {},
    Delay = 0,
    FRAME_TIME = TIME_TO_WAIT,
    StartedRunning = 0,
    HWID = HardwareId
}

local Settings = {
    hookOp = true,
    minifier = true,
    explore_funcs = true,
    lua = false,
    ipt = nil,
    discord = true,
    inf_loops = true,
    runtimelogs = false,
    constants = false,
    spyexeconly = false, --> implement latar
    roblox = false,
    isPremium = true,
    type_annotations = false
}

local IsTesting = true;

local function StrToValue(Str)
    if Str == "false" then return false
    elseif Str == "true" then return true
    elseif Str == "nil" then return nil
    elseif tonumber(Str) then return tonumber(Str)
    else return Str end
end

for index, arg in process.args do
    local k, v = match(arg, "([%w_]+)=(.+)")
    local Arg = arg -- remove --

    if not k and Settings[arg] == nil and not Settings.ipt then
        Settings.ipt = arg
    end

    if Arg == "prod" then
        IsTesting = false
        continue
    elseif Arg == "logs" then
        SendLogs = true
        continue
    end

    if v then -- version=, outfile =
        Settings[k] = StrToValue(v)
    else
        local neg = sub(Arg, 1, 1)
        if neg == "!" then Settings[Arg:sub(2)] = false continue end
        Settings[Arg] = true
    end
end

local hookOp = Settings.hookOp

DONT_DELETE_FILES = DONT_DELETE_FILES or Settings.dont_delete
CallId = DONT_DELETE_FILES and "" or CallId

local SpyExecOnly = Settings.spyexeconly

local Id : number = -1;
local AllowedGetRequests : number = 0;
local Args : number = 0;
local CallsHandler : func = nil

local AllowedUrlsInTheEnd = {} :: { string }
local VariablesLen = 0
local Variables = fenv.setmetatable({}, { __newindex = function(_, k, v) rawset(_, k, v) VariablesLen += 1 end }) :: Variables
local ReverseVariables = {}
local Internal = {} :: Internal
local Usages = {} :: { [string]: number }
local Information = {} :: { [Spied]: { [string]: any } }
local SpiedToInstance = {} :: { [{[any] : any}]: Instance }
local Children = {} :: { [Spied]: { Instance } }
local Wrapped = {}

local LuaTypes = {
    string = true, number = true, table = true, userdata = true, boolean = true, ["function"] = true, thread = true, ["nil"] = true
}
local LuauTypes = {
    string = true, number = true, table = true, userdata = true, boolean = true, ["function"] = true, thread = true, buffer = true, ["nil"] = true
}

local _print = print
print = function(...)
    local function Color(txt, code)
        return `\27[{code}m{txt}\27[0m`
    end

    local Line, Name = debug.info(2, "ln")
    local ColoredName = Color(Name == "" and "???" or Name, 32)
    local ColorLine = Color(`line {Line}`, 35)

    local FinalText = `[ {ColoredName} @ {ColorLine} ]:`

    for _, v in next, {...} do
        if typeof(v) == "table" and not Variables[v] then
            local mt = getmetatable(v)
            if mt and mt.__tostring then
                return _print(FinalText, "PROTECTED TABLE DETECTED, POSSIBLE DETECTION?")
            end
        end
    end

    _print(FinalText, ...)
end

local _Env = getfenv()
local TrueEnv = getmetatable(_Env).__index;

local function GetVar() : string
    Id += 1
    return "r" .. Id
end

local function GetCount(Var : string, AddAnyway : boolean?) : string
    --> Returns the formatted variable name with _(x) where x is how many times it's been used.
    Usages[Var] = (Usages[Var] or -1) + 1
    local Use = Usages[Var]
    if Use == 0 and not AddAnyway then return Var end

    return Var .. "_" .. Use
end

local function GetInternalValue(Spied : any, Recursed : boolean?) : any
    --[[
        Internal: {
            r1: { 1 }
        }

        GetInternalValue(r1) -> Internal.r1 -> Internal.r1[1] is spied? no then return

        Internal: {
            r1: { game },
        }

        GetInternalValue(r1) -> Internal.r1 -> Internal.r1[1] is spied? yes then check if that has an internal value, if yes then return GetInternalValue(val) otherwise return self.
    ]]
    local Value = Internal[Variables[Spied]];
    if Value then
        local V1 = Value[1]
        local VARV1 = Variables[V1]

        if VARV1 and not Recursed then
            local Val = Internal[VARV1]
            if not Val then return V1 end

            return GetInternalValue(Val[1], true)
        end

        return V1
    end
    return Spied;
end

local function SetInternalValue(Var : Variable, Value : any)
    Internal[Var] = { Value };
end

local SavedParams = {}
local ParamsDict = {}
local NumbersDict = {}
for i = 1, 10 do NumbersDict[tostring(i - 1)] = true end

local function GetParams(Value : (any) -> any, Infos : { any }?) : { string }
    if SavedParams[Value] then return SavedParams[Value] end

    local Params = {}

    local pC, vararg = debug.info(Value, "a")
    local Suffix = if Args == 1 then "" else "_" .. Args

    local InfoList = {}
    for _, v in next, Infos or {} do
        insert(InfoList, v.Name)
    end

    for i = 1, pC do
        insert(Params, if InfoList[i] then GetCount(InfoList[i]) else "p" .. i .. Suffix)
    end

    for i = 1, 3 do
        --insert(Params, "ext_p" .. i .. Suffix)
        insert(Params, Alphabet[i] .. Suffix)
    end

    if vararg then
        insert(Params, "...")
    end

    SavedParams[Value] = Params;

    return Params
end

local Functions = {}
local CClosures = {}
local Types = {}

local function iscclosure(f : thread | (any) -> any) : boolean
    if CClosures[f] then return true end
    local Type = typeof(f)
    if Type ~= "function" then return false end

    local info = debuginfo(f, "s")
    return info == '[C]'
end

local function Function(Callback, Path, IsCClosure)
    local Old = ReverseVariables[Path]
    if Old then return Old end

    if IsCClosure then
        CClosures[Callback] = true
    end

    --[[local Result = Callback;

    Callback = function(...)
        return Result(...)
    end]]

    Variables[Callback] = Path
    ReverseVariables[Path] = Callback
    Types[Callback] = "function"

    return Callback;
end

local function thread(func : func)
    -- how do we create a thread..?
    return coroutine.create(func); -- :sob::sob::sob::sob::sob:
end

local function isUnsafePattern(p)
    if p:find("%.%*.*%.%*") then
        return true, "Multiple '.*' detected"
    end

    if p:find("%b()%s*[%*%+]") then
        return true, "Nested repetition detected"
    end

    local wildcardCount = select(2, p:gsub("%.%*", ""))
    if wildcardCount > 3 then
        return true, "Too many wildcards"
    end

    return false
end

local function IsExecutor(Key: string) : string?
    for i, v in next, ExecutorEnvironment do
        if find(v, Key) then return i end
    end
    return;
end

local function SetIterator(Path : string, TypeI : string, TypeV : string) IteratorTypes[Path] = { TypeI, TypeV } end

local UserRegex = "C:[/\\]+Users[/\\]+.-[\\/]([^\\/]+):(%d+)"

local function HideErrors(text : string, hideLines : boolean?, clean : boolean?) : string
    if typeof(text) ~= "string" then
        local Meow = tostring(text)
        if Settings.debug then return Meow end
        return Meow:match("[^\n]+") or text;
    end

    text = text:gsub(
        UserRegex,
        format("%s%s", "%1", hideLines and "" or ":%2")
        --format("[string \"%s\"]%s", TraceId, hideLines and "" or ":%1")
    )
    if not hideLines then
        text = text:gsub(":%d+:", ":1:")
    end
    if clean then
        text = text:gsub("%w+:%d+:%s*", "")
    end
    return text
end

local function UseHookOp(Source : string, SourceFile : string?) : (boolean, string)
    local FileName = SourceFile;
    if not FileName then
        FileName = "./cache/" .. GenId(8)
        fs.writeFile(FileName, Source)
    end

    local OutPath = FileName .. "-unparsed.lua"
    local ScriptPath = hookOp and "mods/hookOp.luau" or "mods/hookOpButNotReally.luau"
    local HookArgs = {
        FileName,
        OutPath,
        CallId,
        --        Obfuscator == "Luraph" and "0" or Settings.constants and "1" or "0",
        Settings.constants and "1" or "0",
        Settings.inf_loops and "1" or "0",
        tostring(WHILE_LIMIT),
    }

    -- Prefer Lute for @std/syntax/parser; allow explicit override.
    local HookBin = process.env and process.env.HOOKOP_BIN
    local UseLune = process.env and process.env.HOOKOP_USE_LUNE
    if not HookBin then
        if UseLune then
            HookBin = process.os == "windows" and "lune.exe" or "lune"
        else
            HookBin = process.os == "windows" and "lute.exe" or "lute"
        end
    end

    local Args = {}
    if UseLune then
        Args = { "run", ScriptPath, unpack(HookArgs) }
    else
        Args = { ScriptPath, unpack(HookArgs) }
    end

    local POut = process.exec(HookBin, Args)

    if POut and POut.exitCode and POut.exitCode ~= 0 then
        local errMsg = POut.stderr and #POut.stderr > 0 and POut.stderr or `hookOp exited with code {POut.exitCode}`
        return false, `--err{errMsg}`
    end

    if FileName ~= SourceFile then
        fs.removeFile(FileName)
    end

    local s, Content = pcall(fs.readFile, OutPath)
    if not DONT_DELETE_FILES and fs.isFile(OutPath) then pcall(fs.removeFile, OutPath) end
    if not s or DONT_DELETE_FILES then print("Output:",POut.stdout,POut.stderr) end
    if not s then
        local errMsg = POut.stderr and #POut.stderr > 0 and POut.stderr or "hookOp output missing"
        return false, `--err{errMsg}` 
    end

    return true, Content
end

local function EnvLog(Source : (any) -> any, Nest : number) : AstExpression
    --> Environment logs the given file & outputs the code

    local function GetMaxOps(n) return 5000 / max(n * 5, 1) * MAX_OPS_MUL end

    Nest = Nest or 0;

    local AST = Ast.new()
    AstLib.SetGlobal("AST", AST)
    if Nest == 0 then
        Ast.addStatement(
            AST,
            Ast.Assign(
                { Ast.Variable(EnvName) },
                { Ast.FunctionCall(Ast.Variable("getfenv"), {}) },
                false
            )
        )
    end

    task.spawn(function()
        if Settings.version then
            while task.wait(1) and not DONE_PROCESSING do
                PRINT("Alive")
                if Settings.runtimelogs then
                    pcall(function()
                        fs.writeFile(
                            Settings.out, AstLib.Stringify(AstLib.Minify(AST, not Settings.minifier))
                        )
                    end)
                end
            end
        end
    end)

    local OpCount = 0;
    local StartedRunning;
    local TotalWhiles = 0;
    local TotalRepeats = 0;

    local MaxOps = GetMaxOps(Nest)
    local Env = {} :: {};
    local EnvValues = {
        load = {},
        package = {},
        file = {},
        io = {}
    }

    local function OpCountCheck()
        OpCount += 1
        if OpCount >= MaxOps then
            error("too many operations", 2)
        end
    end

    local function Typeof(Value : any)
        local Type = Types[Value]
        if Type then return Type, Value end
        local int = GetInternalValue(Value)
        return typeof(int), int
    end

    local function checktype(obj : any, expected : string, msg : string, allowNn : boolean?) : any
        if allowNn and not Internal[Variables[obj]] then return obj end --> has no value..?

        local type, int = Typeof(obj)
        assert(type == expected, `{msg}, {expected} expected got {type}`)
        return int;
    end

    local ToAST : (any, { [string]: any }?) -> AstExpression, SpyParams;

    local ToExplore = {}
    local ToExploreHash = {}
    local VarValues = {} :: {
        [string]: any
    }

    local WaitingIfs = {}
    local Strings = {}
    local ConstantList = {}
    local AlwaysIgnore = {
        [EnvName] = true,
        string = true,
        bit32 = true,
        table = true,
        string = true
    }
    local Nil = {
        getconstants = true, -- msec
        _ENV = true, --> executor thing
        io = true,
        file = true
    }
    local ForceNil = {
        RandomStrings = true,
        package = true,
        inf = true, --> uuuuuuuuh wearedevs
    }
    local Indexes = {}
    local SecureEnv = {} :: Environment
    local VisitedTables = {}
    local Luraph = false;

    local ActiveLoops = 0;
    local ForLoopId = 0;
    local StopWhileLoops = 0;
    local IfId = 0;
    local WhileExprs, LastLen = {}, 0;

    local function CloseIfs(ASt)
        local AST = ASt or AST;
        if #WaitingIfs > 0 then
            local Oldest = WaitingIfs[#WaitingIfs]
            local LengthNow = #AST.data.statements

            if true then
                local StartedAt = Oldest[2]
            
                local Comment = Ast.PermaComment(Ast.RawText(`{Oldest[3] and "didnt run (else)" or "ran"}, if id: {Oldest[#Oldest]}`))
                local Body = Ast.Block{Comment}
                for i = StartedAt + 1, LengthNow do
                    Ast.addStatement(Body, AST.data.statements[i])
                    AST.data.statements[i] = nil
                end

                local IsElse = Oldest[3]

                if IsElse then
                    Ast.addStatement(AST, Ast.IfStat(ToAST(Oldest[1]), Ast.Block{}, Body))
                else
                    Ast.addStatement(AST, Ast.IfStat(ToAST(Oldest[1]), Body))
                end
            end
        end
        WaitingIfs = {}
    end

    local function Assert(Type, WhatItShouldBe, Message, AllowAny)
        if AllowAny and Type == "table" then
        else
            assert(Type == WhatItShouldBe, Message);
        end
    end

    local function CloseAllEnds(ASt)
        ASt = ASt or AST
        CloseIfs(ASt)
        for i = 1, ActiveLoops do
            Ast.addStatement(ASt, Ast.End())
        end
        ActiveLoops = 0
    end

    local IsExploring, IsInPcall;

    local function Explore(Func : (any) -> any, Options : { [string]: any }, ...) : AstBlock
        Options = Options or {}

        local DontBypassBeautify = not Options.bypass_beautify
        if Options.bypass_ignore then
            DontBypassBeautify = false
        else
            if not Settings.explore_funcs or Options.ignore_funcs then
                if Options.as_func then
                    return Ast.Function(GetParams(Func), Ast.Block{}), {}
                end

                return Ast.Block{}, {}
            end
        end

        if not ToExploreHash[Func] and DontBypassBeautify then
            local id = "to_explore_" .. GenId(32)
            local node = Ast.Variable(id)

            insert(ToExplore, { func = Func, id = id, node = node, args = Options, idx = #ToExplore, traceback = debug.traceback() })
            --local node = Ast.Block({})
            --Ast.addStatement(node, Ast.Comment(Ast.RawText("Unexplored function..")))
            --insert(ToExplore, { func = Func, node = node, args = Options, idx = #ToExplore })
            --ToExploreHash[Func] = { id, Options }
            ToExploreHash[Func] = true

            return node;
        end

        IsExploring = not Options.as_pcall

        local _AST, _Nest, _OpCount, _MaxOps, _Delay, _Whiles, _Limit, _Waiting, _Loops, _LastLen, _LastExpr, _IsInPcall =
            AST, Nest, OpCount, MaxOps, SharedGlobals.Delay, TotalWhiles, WHILE_LIMIT, WaitingIfs, ActiveLoops, LastLen, WhileExprs, IsInPcall;
        AST, Nest, OpCount, MaxOps, SharedGlobals.Delay, TotalWhiles, WHILE_LIMIT, WaitingIfs, ActiveLoops, LastLen, WhileExprs, IsInPcall =
            Ast.Block({}),
            Nest + 1,
            0,
            GetMaxOps(Nest + 1),
            Options.delay or 0,
            0,
            WHILE_LIMIT / 2,
            {},
            0,
            0,
            {},
            Options.as_pcall and Func;

        local Params = Options.params;
        local ParamInfos = Options.param_infos;

        local Gotten = {};

        if not Params--[[ and (Nest ~= 2 or not Options.as_pcall)]] and (Nest ~= 1 or not Options.as_pcall) then -- spy them
            Gotten = GetParams(Func, ParamInfos)
            Params = SpyParams(Gotten, ParamInfos)
        end

        --local Results = pack(pcall(if Options.as_pcall or true then Func else fenv.setfenv(Func, Env), unpack(Params or {})))
        --local IsRegular = getfenv(Func)
        local Results = pack(pcall(Func, unpack(Params or {})))
        --local Results = pack(pcall(if IsRegular == Env or Options.as_pcall then Func else setfenv(Func, Env), unpack(Params or {})))
        local Logged = Ast.Block{};

        for _, Statement in next, AST.data.statements do
            Ast.addStatement(Logged, Statement)
        end

        if #Logged.data.statements > 0 then
            Args += 1
        end

        CloseAllEnds(Logged)

        if not Results[1] then
            if not Options.as_pcall then
                local Last = Logged.data.statements[#Logged.data.statements]
                if Last and Last.kind == "call" and Last.data.func.data.name == "error" then
                else
                    local Error = Results[2]
                    --[[Ast.addStatement(Logged, Ast.FunctionCall(
                        Ast.Variable("error"), {
                            ToAST(
                                if Settings.debug then Error else HideErrors(Error, not IsTesting)
                            )
                        })
                    )]]
                    
                    Ast.addStatement(
                        Logged,
                        Ast.NonOptionalComment(
                            Ast.RawText("The script errored here with the message: "),
                            ToAST(
                                if Settings.debug then Error else HideErrors(Error, not IsTesting)
                            )
                        )
                    )
                end
            end
        elseif Results.n > 1 then
            local Returned = {}
            for i = 2, Results.n do
                insert(Returned, ToAST(Results[i]))
            end
            Ast.addStatement(Logged, Ast.Return(Returned))
        end

        AST, Nest, OpCount, MaxOps, SharedGlobals.Delay, TotalWhiles, WHILE_LIMIT, WaitingIfs, ActiveLoops, LastLen, WhileExprs, IsInPcall =
            _AST, _Nest, _OpCount, _MaxOps, _Delay, _Whiles, _Limit, _Waiting, _Loops, _LastLen, _LastExpr, _IsInPcall;
        IsExploring = false

        if Options.as_func then
            Logged = Ast.Function(Gotten, Logged)
        end

        return Logged, Results
    end

    local function shallowEqual(t1, t2)
        -- If they are the same table, they are equal
        if t1 == t2 then return true end
        -- If either isn't a table, they aren't equal
        if type(t1) ~= "table" or type(t2) ~= "table" then return false end
    
        -- Check if t1 keys/values exist in t2
        for k, v in pairs(t1) do
            if t2[k] ~= v then return false end
        end
    
        -- Check if t2 has extra keys not in t1
        for k, _ in pairs(t2) do
            if t1[k] == nil then return false end
        end
    
        return true
    end

    ToAST = function(Value : any, Data : any) : AstExpression
        if Ast.IsAst(Value) then return Value end;

        local Var = Variables[Value]
        local Str = Strings[Value]
        if Var then
            return Ast.Variable(Var)
        elseif Str then
            return Ast.Variable(Str)
        end

        local Type = typeof(Value)
        if Type == "number" then
            return Ast.Number(Value);
        elseif Type == "string" then
            return Ast.String(Value)
        elseif Type == "error" then
            local Meow = tostring(Value)
            Meow = if Settings.debug then Meow else Meow:match("[^\n]+") or Meow;
            return ToAST(Meow);
        elseif Type == "nil" then
            return Ast.Nil(Value)
        elseif Type == "function" then -- ono..
            local Old = Functions[Value]
            if Old and not (Data and Data.dont_cache) and (not Data or shallowEqual(Data, Old[2])) then return Old[1] end

            Data = if typeof(Data) == "table" then Data else {}
            Data.bypass_beautify = if Data.bypass_beautify == nil then false else Data.bypass_beautify

            -- Since the function is STILL attached to this Env, We can just log the new nodes.

            local Logged = Explore(Value, Data);
            
            Functions[Value] = { Logged, Data }
            --return Ast.Function(GetParams(Value), Logged)
            return Logged;
        elseif Type == "table" then
            if VisitedTables[Value] then
                return Ast.FunctionCall(Ast.Variable("RECURSIVE_TABLE"), {})
            end

            VisitedTables[Value] = true
            local Metatable = getmetatable(Value)
            local Fixed = {}

            for Key, Value in next, Value do
                insert(Fixed, {
                    key = ToAST(Key, Data),
                    val = ToAST(Value, Data);
                })
            end

            local TblVar = Ast.Variable(GetVar());
            Ast.addStatement(
                AST,
                Ast.Assign(
                    {
                        TblVar
                    },
                    {
                        Ast.Table(Fixed)
                    }
                )
            )

            if Metatable then
                local mt = {}
                local Type = typeof(Metatable)
                if Type == "table" then
                    for i, v in next, Metatable do
                        insert(mt, {
                            key = ToAST(i),
                            val = ToAST(v, { ignore_funcs = true, as_func = true })
                        })
                    end
                else
                    mt = {
                        {
                            key = Ast.String("__metatable"),
                            val = ToAST(Metatable)
                        }
                    }
                end

                VisitedTables[Value] = nil

                return Ast.FunctionCall(Ast.Variable("setmetatable"), { TblVar, Ast.Table(mt) });
            end

            VisitedTables[Value] = nil;
            --Variables[Value] = TblVar.data.name;

            return TblVar;
        elseif Type == "boolean" then
            return Ast.Boolean(Value);
        elseif Type == "Color3" then
            return Ast.FunctionCall(
                Ast.Index(Ast.Variable("Color3"), Ast.String("fromRGB")),
                {
                    Ast.Number( Value.R * 255 // 1 ),
                    Ast.Number( Value.G * 255 // 1 ),
                    Ast.Number( Value.B * 255 // 1 )
                }
            )
        elseif Type == "ColorSequenceKeypoint" then
            return Ast.FunctionCall(
                Ast.Index(Ast.Variable("ColorSequenceKeypoint"), Ast.String("new")),
                {
                    Ast.Number(Value.Time),
                    ToAST(Value.Value)
                }
            )
        elseif Type == "EnumItem" then
            return Ast.Variable(tostring(Value))
        else
            return Ast.FunctionCall(
                Ast.Variable("UNKNOWN_TYPE"),
                {
                    Ast.String(Type),
                    ToAST(tostring(Value))
                }
            )
        end
    end

    local function TupleToAST(...) : {AstExpression}
        local ASTs = {}
        for _, v in next, {...} do
            insert(ASTs, ToAST(v))
        end
        return ASTs
    end

    local function Define(Var : AstExpression | string, Value : any, IsGlobal : boolean, Raw : boolean?) : AstExpression
        OpCountCheck()

        local Type = typeof(Var)
        local ActualVar = Type == "string" and Ast.Variable(Var) or Var
        local Assign = Ast.Assign(
            {
                ActualVar
            },
            { if Raw then Value else ToAST(Value) },
            IsGlobal
        )

        Ast.addStatement(
            AST,
            Assign
        )

        if ActualVar.kind == "variable" then
            VarValues[ActualVar.data.name] = Value
        end

        return Assign;
    end

    local function DefineVar(...) : (string, AstExpression)
        local Var = GetVar()
        local Stat = Define(Var, ...)
        return Var, Stat
    end

    local function AppendCall(FuncName : string, ...) : (string, AstExpression) --> Returns variable name
        OpCountCheck();
        local Value = VarValues[FuncName] -- The function's value, we use this to construct namecalls.
        if Value and Value.kind == "index" then
            local ValueBase = Value.data.base
            if ValueBase.kind == "variable" then
                local Name = ValueBase.data.name
                local FirstArg = Variables[...]
                local MethodInfo = VarValues[FuncName]

                if Name == FirstArg and (MethodInfo and MethodInfo.kind == "index") then --> Namecall
                    local Key = MethodInfo.data.key--.data.value
                    local KeyVar = Key.data.value
                    if Key.kind == "variable" then
                        KeyVar = VarValues[MethodInfo.data.key.data.name].data.value --> Other constant?
                    elseif Key.kind == "string" then
                        KeyVar = Key.data.value
                    end
                    return DefineVar(
                        Ast.Namecall(
                            Ast.Variable(MethodInfo.data.base.data.name),
                            Ast.Variable(KeyVar),
                            TupleToAST(select(2, ...))
                        )
                    )
                end
            end
        end
        return DefineVar(
            Ast.FunctionCall(typeof(FuncName) == "string" and Ast.Variable(FuncName) or FuncName, TupleToAST(...))
        )
    end

    local function Comment(...)
        if true then return end

        Ast.addStatement(AST, Ast.Comment(unpack(TupleToAST(...))));
    end

    local function ReverseDict(Dict : { [any]: any }) : { [any]: any }
        local New = {}
        for i, v in next, Dict do
            New[v] = i
        end
        return New
    end

    local Metatable, Math, MathV2;
    local MathNames = {
        ["/"] = {
            [2] = "half",
            [3] = "third",
            [4] = "quarter",
        },
        ["*"] = {
            [2] = "double",
            [3] = "triple",
            [4] = "quadruple",
            [5] = "quintuple"
        }
    }

    MathV2 = {
        __eq = "==",
	    __neq = "~=",
	    __lt = "<",
	    __le = "<=",
	    __gt = ">",
	    __ge = ">=",
    }
    Math = {
	    __add = "+",
	    __sub = "-",
	    __mul = "*",
	    __div = "/",
	    __idiv = "//",
	    __pow = "^",
        __mod = "%",
	    __concat = ".."
    }

    local SymbolToName = ReverseDict(Math)

    local function InternalIfy(...)
        local Args = {...}
        for i, v in next, Args do
            Args[i] = GetInternalValue(v)
        end
        return unpack(Args)
    end

    local Iters = {}
    local MissingEnums = {
        Font = {
            GothamSemiBold = true,
            GothamSemibold = true
        },
        RaycastFilterType = {
            Blacklist = true,
            Whitelist = true
        }
    }

    local function __call(Self, ...)
        local Path = Variables[Self];
        local Cached = (Internal[Path] or {{}})[1] :: { [string]: any };
        local args = { ... }
        local len = select("#", ...)

        if len == 2 and args[1] == nil then --> heh iter
            if args[2] == nil then -- started the iteration, when its not nil then its done
                CloseAllEnds(AST);

                Iters[Path] = true

                -- its an iterator thing
                local i, v = GetCount("i"), GetCount("v")

                Ast.addStatement(
                    AST,
                    Ast.ForPrep(
                        Ast.Variable(i),
                        Ast.Variable(v),
                        Ast.Variable(Path),
                        "obf_" .. ActiveLoops
                    )
                )

                ActiveLoops += 1

                return Spy(i), Spy(v)
            elseif Iters[Path] then
                ActiveLoops -= 1
                CloseIfs()
                Ast.addStatement(AST, Ast.End("obf_" .. ActiveLoops))

                return nil, nil
            end
        end

        local Var = AppendCall(Path, ...)

        return Spy(Var, nil, Information[Self]);
    end

    function GetValueInner(x, Symbol, y)
        if Symbol == "+" then return x + y
	    elseif Symbol == "-" then return x - y
	    elseif Symbol == "*" then return x * y
	    elseif Symbol == "/" then return x / y
	    elseif Symbol == "//" then return x // y
	    elseif Symbol == "^" then return x ^ y
        elseif Symbol == "%" then return x % y
	    elseif Symbol == ".." then return x .. y
	    elseif Symbol == "==" then return rawequal(x, y)
	    elseif Symbol == "~=" then return not rawequal(x, y)
	    elseif Symbol == "<" then return x < y
    	elseif Symbol == "<=" then return x <= y
	    elseif Symbol == ">" then return x > y
	    elseif Symbol == ">=" then return x >= y
        end
    end

    function Spy(Path : string, Value : any, Info: any) : any
        --if Variables[Value] then return Value end
        assert(typeof(Path) == "string", `invalid argument #1 to 'Spy', string expected got {typeof(Path)} - {debuginfo(2, "l")}, {debuginfo(3, "l")}`)

        local Reversed = ReverseVariables[Path]
        if Reversed then return Reversed end -- Dont log duplicates.

        if not Metatable then
            local Info = Info or {};

            Metatable = {};

            function Metatable.__newindex(Self, Key, Value)
                Info = Information[Self] or Info;

                local Path = Variables[Self]
                local Base = Ast.Variable(Path);

                local Cached = (Internal[Path] or {{}})[1] :: { [string]: any };

                if rawequal(Cached, Env) then Cached[Key] = Value return end --> Stop meowing pal

                local Type = Typeof(Cached)
                local DontSet = Info.from_index and Cached == nil;

                if Type == "Instance" then
                    local Int = GetInternalValue(Value)
                    if not Variables[Int] then
                        Cached[Key] = Int;
                        return
                    else
                        DontSet = true
                        Value = Int;
                    end
                end

                Define(
                    Ast.Index(Base, ToAST(Key)),
                    ToAST(Value),
                    true
                )

                if LuaTypes[Type] and Type ~= "table" and Cached then
                    error(`attempt to index {Type} with '{Key}'`)
                end
                
                if not DontSet then
                    Value = GetInternalValue(Value)
                    Cached[Key] = Value
                end
                rawset(Self, Key, Value)

                return nil;
            end

            function Metatable.__index(Self, Key : string)
                Info = Information[Self] or Info;

                local Path = Variables[Self]
                local IsInternal = Internal[Path]
                local Cached = (
                    IsInternal or {}
                )[1] :: { [string]: any };

                if rawequal(Cached, Env) then return Cached[Key] end --> Stop meowing pal

                local DontCache = Variables[Cached] ~= nil or Cached == nil;

                Cached = Cached or {}

                local Type = Typeof(Cached)

                --if Type ~= "table" and LuauTypes[Type] then Cached = {} end

                if Type == "Enum" then
                    local EnumKey = tostring(Cached):split(".")[2]
                    local List = MissingEnums[EnumKey]
                    if List and List[Key] then
                        DontCache = true
                    else
                        DontCache = typeof(Key) == "table"
                    end
                elseif Type == "Instance" then
                    DontCache = not pcall(function() return Cached[Key] end) --> ??!?!?!?!
                end

                local Cache =
                    if DontCache then nil else Cached[Key];
                
                local Base = Ast.Variable(Path);

                local Var = DefineVar(
                    Ast.Index(Base, ToAST(Key)),
                    false,
                    true
                )

                local newinfo = {}
                do
                    local meow = Info.indexed_instance
                    if meow ~= nil then newinfo.indexed_instance = meow end
                    newinfo.from_index = true--DontCache
                end

                if LuaTypes[Type] and Type ~= "table" and Type ~= "string" then
                    error(`attempt to index {Type} with '{Key}'`)
                end

                if Cached and not DontCache then
                    if typeof(Cache) == "function" then
                        if Type == "string" then
                            return SecureEnv.string[Key]
                        end

                        return Function(function(...)
                            local Spied, Statement = AppendCall(Var, ...)
                            local Values = pack(Cache(InternalIfy(...)))

                            if Values.n == 1 then
                                return Spy(Spied, nil, newinfo);
                            else
                                return ToMultiVars(Statement, Values)
                            end
                        end, Var, iscclosure(Cache))
                    end
                    return SafeValue(Var, Cache, newinfo);
                elseif IsInternal and not DontCache then
                    SetInternalValue(Var, IsInternal[1][Key]);
                end

                local Spied = Spy(Var, nil, newinfo);
                if not DontCache then
                    Cached[Key] = Spied
                end
                return Spied
            end

            Metatable.__call = __call

            function Metatable.__tostring(Self)
                return Variables[Self];
            end

            function Metatable.__iter(Self, Key)
                local Called;
                local i, v = GetCount("for_key", true), GetCount("for_val", true)

                local Ends = WaitingIfs
                local Current = ForLoopId + 1

                return function(...) --> nil, nil;
                    if Called then
                        ActiveLoops -= 1
                        CloseIfs()
                        Ast.addStatement(AST, Ast.End(Current))
                        WaitingIfs = Ends

                        return nil
                    end

                    local Path = Variables[Self]
                    local IsInternal = Internal[Path]
                    local Cached = (
                        IsInternal or {}
                    )[1] :: { [string]: any };

                    local Iterator =
                        if Key == "next" then
                            Ast.ArgList({ Ast.Variable(Key), ToAST(Self) })
                        elseif typeof(Key) == "string" then
                            Ast.FunctionCall(Ast.Variable(Key), {ToAST(Self)})
                        else
                            ToAST(Self)

                    CloseAllEnds(AST);

                    local i_Types = IteratorTypes[Path]
                    if not i_Types then
                        if typeof(Cached) ~= "table" then
                            i_Types = {}
                        else
                            for i2, v2 in next, Cached do
                                i_Types = { Typeof(i2), Typeof(v2) }
                                SetInternalValue(i, i2)
                                SetInternalValue(v, v2)
                                break
                            end
                        end
                    end

                    Ast.addStatement(
                        AST,
                        Ast.ForPrep(
                            Ast.Variable(i),
                            Ast.Variable(v),
                            Iterator,
                            Current
                        )
                    )

                    Called = true;
                    ForLoopId = Current
                    ActiveLoops += 1
                    WaitingIfs = {}

                    return TypeSpy(i, i_Types[1]), TypeSpy(v, i_Types[2])
                end
            end

            local HookOpHas = {
                __eq = true,
	            __neq = true,
	            __lt = true,
	            __le = true,
	            __gt = true,
	            __ge = true
            }

            local InstantlyProcess = { ["=="] = true, ["~="] = true }
            local Comp = {
                [">"] = true, ["<"] = true,
                [">="] = true, ["<="] = true
            }

            function GetValue(x, Symbol, y, Var)
                local TypeX, TypeY = Typeof(x), Typeof(y);
                local VarX, VarY = Variables[x], Variables[y];
                local xLune, yLune = not LuauTypes[TypeX], not LuauTypes[TypeY];

                if not InstantlyProcess[Symbol] then
                    if Symbol == ".." then
                        --> We can't process it otherwise it'll keep calling this..?
                        if VarX or VarY then
                            if TypeX ~= "string" and TypeY ~= "string" then --> Drawing .. "meow" will be ignored i guess
                                assert(not Settings.roblox, `attempt to concatenate {TypeX} with {TypeY}`)
                            end
                            return TypeSpy(Var, "string");
                        end
                    else --> Add, Sub, Mul, ...
                        if VarX or VarY then
                            --> uhhhhhhhhhhhhhhh whattttt?
                            if (not xLune and not yLune) or ((VarX and not xLune) or (VarY and not yLune)) then --> both arent lune, x is spied & not lune, y is spied & not lune
                                if not LuaTypes[TypeX] and not LuaTypes[TypeY] then --> not a number, function, string, ...
                                    assert(not Settings.roblox, `attempt to perform arithmetic ({SymbolToName[Symbol]:sub(3)}) on {TypeX} and {TypeY}`)
                                end
                                return Spy(Var);
                            end
                        end
                    end
                end
                
                local Success, Value = pcall(GetValueInner, x, Symbol, y)
                if Settings.roblox then
                    assert(Success, tostring(Value))
                end
	            return Value
            end

            for Method, Symbol in next, Math do
                Metatable[Method] = function(Self, Value)
                    if IgnoreInEq[Variables[Self]] then
                        return GetValue(GetInternalValue(Self), Symbol, GetInternalValue(Value))
                    end

                    local Var = DefineVar(
                        Ast.BinaryOp(ToAST(Self), Symbol, ToAST(Value)),
                        false,
                        true
                    )

                    local Value = GetValue(GetInternalValue(Self), Symbol, GetInternalValue(Value), Var)
                    if Variables[Value] then return Value end
                    Ast.addStatement(AST, Ast.Comment(ToAST(Value)))
                    return SafeValue(Var, Value);
                end
            end

            if not hookOp then
                for Method, Symbol in next, MathV2 do
                    --[[if HookOpHas[Method] then
                        continue;
                    end]]

                    Metatable[Method] = function(Self, Value)
                        if Variables[Self] == EnvName then
                            return GetValue(GetInternalValue(Self), Symbol, GetInternalValue(Value))
                        end

                        local Var = DefineVar(
                            Ast.BinaryOp(ToAST(Self), Symbol, ToAST(Value)),
                            false,
                            true
                        )

                        local Value = GetValue(GetInternalValue(Self), Symbol, GetInternalValue(Value), Var)
                        if Variables[Value] then return Value end
                        return SafeValue(Var, Value);
                    end
                end
            end
        end

        local Meta = setmetatable({}, Metatable)
        if typeof(Value) == "table" then
            local OldMt = getmetatable(Value)
            local ActualMetatable = getmetatable(Meta)

            if OldMt then --> Support for the Random library, since the stuff it returns has metatables:(
                for method, callback in next, OldMt do
                    if typeof(callback) == "function" then
                        if method:sub(1, 2) == "__" then -- metamethod
                            ActualMetatable[method] = callback
                        else
                            rawset(Meta, method, function(_, ...)
                                local Statement;
                                if Variables[_] == Path then -- namecall duh
                                    Statement = Ast.Assign(
                                        { Ast.Variable(GetVar()) },
                                        { Ast.Namecall(Ast.Variable(Path), Ast.Variable(method), TupleToAST(...)) }
                                    )
                                    Ast.addStatement(
                                        AST, Statement
                                    )
                                else
                                    Statement = select(2, AppendCall(
                                        Ast.Index(
                                            Ast.Variable(Path),
                                            ToAST(method)
                                        ),
                                        _,
                                        ...
                                    ))
                                end

                                return ToMultiVars(Statement, pack(callback(GetInternalValue(_), ...)), true)
                            end)
                        end
                    else
                        ActualMetatable[method] = callback;
                    end
                end
            end
        end

        Variables[Meta] = Path;
        ReverseVariables[Path] = Meta
        if Value ~= nil then
            Types[Meta] = typeof(Value);
            SetInternalValue(Path, Value);
        end

        Information[Meta] = Info

        return Meta;
    end

    TypeSpy = function(Path : string, Type : string, ... : any)
        local Meower = Spy(Path, ...)
        if Type then Types[Meower] = Type end
        return Meower
    end

    function ToMultiVars(Statement : AstExpression, Values : dict, Safe : boolean?, Info : dict?) : ...Spied
        local Length = Values.n or #Values;

        local Spied, Vars = {}, {}
        local Func = if Safe then SafeValue else Spy

        for i = 1, Length do
            local Var = GetVar()
            local Meower = Func(Var, Values[i], Info)

            Types[Meower] = typeof(Values[i]);

            insert(Spied, Meower)
            insert(Vars, Ast.Variable(Var))
        end

        Statement.data.vars = Vars
        return unpack(Spied);
    end

    function SafeValue(Var : string, Value : any, Info : any) : any
        local Type = Typeof(Value)

        --if Type == "Instance" then return Value end -- instances are already sandboxed

        if Type == "function" then
            return Function(Value, Var, iscclosure(Value))
        elseif Type == "table" or hookOp then
            if Variables[Value] then Value = GetInternalValue(Value) end
            
            SetInternalValue(Var, Value);
            return TypeSpy(Var, Type, nil, Info);
        else
            return Value;
        end
    end

    local function GetMetatable(Path : string, Extra : { any }?, Value : any?)
        local Cloned = table.clone(getmetatable(Spy(Path, Value)))
        if Extra then
            for i, v in next, Extra do Cloned[i] = v end
        end
        local Mt = setmetatable({}, Cloned)
        Variables[Mt] = Path
        return Mt
    end

    local function GetContext(Object : any) : string?
        local Var = Variables[Object]
        if Var and not AlwaysIgnore[Var] and not Wrapped[Object] and not LuaGlobals[Var] then
            return Var;
        end
        return nil;
    end

    SpyParams = function(Params : {string}, Infos : { any }?) : { any }
        local ParamList = {}
        local InfoList = {}
        if Infos then
            for _, v in next, Infos do
                insert(InfoList, v.Type)
            end
        end

        for i, Param in next, Params do
            local Spied = Spy(Param, nil, {
                is_property = true
            })
            local thingInfo = InfoList[i]
            if thingInfo then
                if thingInfo.Category == "Primitive" then
                    local Type = AliasToName[thingInfo.Name] or thingInfo.Name
                    Types[Spied] = Type
                end
            end
            ParamsDict[Spied] = true
            insert(ParamList, Spied)
        end

        return ParamList
    end

    if hookOp then
        -- add the funcs:(

        local StuffThatRanEq = {} -- Storing their variable name is more efficient right?

        local function Eq(Symbol)
            local IsEq = Symbol == "=="
            local eq = IsEq and function(a, b) return a == b end or function(a, b) return a ~= b end;
            local function WhatIsIt(N)
                local shouldFlip = N[2] == (IsEq)
                if shouldFlip then
                    return not N[1]
                else
                    return N[1]
                end
            end

            --> if N[2] then

            --[[
                Values:
                N[2] and ==: not N
                N[2] and ~=: N

                not N[2] and ==: N
                not N[2] and ~=: not n
            ]]

            return function(x, y)
                local A, B = GetContext(x), GetContext(y);
                if (not A and not B)--[[ or (Typeof(x) == "function" or Typeof(y) == "function")]] or (IgnoreInEq[A] or IgnoreInEq[B]) then return eq(x, y) end
                local N, P = StuffThatRanEq[A], StuffThatRanEq[B]

                --if N then return WhatIsIt(N) end
                --if P then return WhatIsIt(P) end

                local X, Y = GetInternalValue(x), GetInternalValue(y);
                local Var = GetVar()
                Define(
                    Var,
                    Ast.Group(Ast.BinaryOp(ToAST(x), Symbol, ToAST(y))),
                    false,
                    true
                )

                local Value;
                local RawValue = eq(X, Y)

                local VarX = Variables[X]

                if VarX and (VarX == Variables[Y]) then
                    RawValue = IsEq; --> gethui() ~= gethui() or something
                end

                local InfoA = Information[x]
                local InfoB = Information[y]

                local iA, iB = InfoA or {}, InfoB or {}

                local PropertyA, PropertyB = iA.is_property, iB.is_property

                if (PropertyA or PropertyB) and not iA.force_normal and not iB.force_normal then
                    local TypeX, TypeY = Typeof(x), Typeof(y);
                    if TypeX == "string" or TypeY == "string" then
                        if x == "" or y == "" then
                            Value = not IsEq;
                        else
                            Value = IsEq
                        end
                    else
                        Value = eq(TypeX, TypeY) --> If they're the same type
                    end
                end

                -- blah blah blah
                if Value == nil then
                    Value = RawValue;
                end

                if iA.key == "PlaceId" and typeof(Y) == "number" then
                    Value = not IsEq or Y > 100_000;
                elseif iB.key == "PlaceId" and typeof(X) == "number" then
                    Value = not IsEq or X > 100_000;
                end

                local tbl = { Value, IsEq }

                if A then StuffThatRanEq[A] = tbl; end
                if B then StuffThatRanEq[B] = tbl; end

                Ast.addStatement(AST, Ast.Comment(ToAST(Value)))

                return Spy(Var, Value, InfoA or InfoB);
            end
        end

        local CompVars, CheckCount, CompIgnore = {}, {}, { table = true, string = true };

        local function Def(x, Symbol, y, _y, isYFunc)
            local Var;
            if isYFunc and typeof(_y) == "function" then
                local Var1 = DefineVar(Explore(_y, { bypass_beautify = false }), false, true)
                Var = DefineVar(
                    Ast.BinaryOp(
                        ToAST(x),
                        Symbol,
                        Ast.FunctionCall(Ast.Variable(Var1), {})
                    ),
                    false,
                    true
                )
            else
                Var = DefineVar(
                    Ast.BinaryOp(
                        ToAST(x),
                        Symbol,
                        ToAST(y)
                    )
                )
            end

            return Var
        end

        local function SearchTable(tbl : { [any]: any }) : boolean
            --> Searches through a table and returns should spy log
            local Junk, Count = 0, 0;
            local IsDict = #tbl == 0;

            for key, val in next, tbl do
                if IsDict and typeof(key) == "string" and not IsGarbageString(key) then
                    Junk -= 3
                end

                Count += 1
                local Type = typeof(val)

                local Var = Variables[val]

                if Var and Type ~= "function" then
                    Junk -= (IgnoreInEq[Var] and -5 or 1)
                elseif Type == "function" then
                    return false
                elseif Type == "number" then
                    Junk += 1
                elseif Type == "table" then --> It cant be a variable, we already checked that before.
                    Junk += 5
                elseif Type == "string" then
                    Junk += (IsGarbageString(val) and 10 or -5)
                else
                    Junk += 1
                end
            end

            return Junk < Count
        end

        local function Compare(Symbol)
            local IsAnd = Symbol == "and"
            local GetValue = IsAnd
                and function(x, y) return x and y end
                or function(x, y) return x or y end; 

            return function(x, y, isYFunc, ...) --> Lhs, Rhs, { isFunction, isFunction }
                local a, b = GetContext(x), GetContext(y)
                local _x, _y = x, y;

                local X = GetInternalValue(x)

                local ShouldReturn = if IsAnd then not X else X;
                local Args = {...}

                local TypeX = Typeof(x)
                local IsFunction = TypeX == "function"

                if SharedGlobals.Pristine then
                    if IsAnd and SharedGlobals.PristineKeys[a] then
                        return nil;
                    end
                end

                if ShouldReturn then
                    if (a or b) and TypeX ~= "number" and TypeX ~= "Instance"--[[ and (IsAnd and X ~= false)]] then --> some weird ib1 shit idk
                        if Variables[X] == EnvName or y == nil then return X end

                        local IsPrometheus = typeof(y) == "number" and y > 10000

                        if not IsPrometheus then
                            if IsAnd then
                                if X == false then return X end
                            else
                                if TypeX == "function" then return X end
                            end

                            if X == false then
                                local Val = VarValues[a]
                                if not Val or Val.kind ~= "unary" then --> Log (if not x)
                                    return X
                                end
                            end
                            Var = Def(x, Symbol, y, _y, isYFunc)
                        else
                            local ToAST_X = ToAST(x)
                            Var = DefineVar(X and ToAST_X or Ast.UnaryOp(ToAST_X, "not")) -- remove the ugly 'x and 123456'
                        end

                        SetInternalValue(Var, X);
                        return Spy(Var, nil, Information[x] or Information[y]);
                    end

                    return X
                end

                if isYFunc then
                    isYFunc = false
                    y = y(...)
                end

                if (not a and not b) or (IsFunction or CompIgnore[a]) then --> Ignore
                    --> Simplified: if not a and not b ORRRRR if X isn't a function (and not `string`)
                    return GetValue(X, y)
                end

                local Var;

                local Info = Information[x] or Information[y]

                local IsPrometheus = typeof(y) == "number" and y > 10000

                if CompVars[X] then
                    CompVars[y] = `not {CompVars[X]}`
                elseif not IsPrometheus then
                    if IsFunction and iscclosure(x) then --> C function, like print or string.something
                        return GetValue(x, y);
                    end
                    
                    Var = Def(x, Symbol, y, _y, isYFunc);
                end

                x, y = X, GetInternalValue(y)

                local s, Value = pcall(GetValue, x, y)

                if not s then Value = nil end

                if IsPrometheus then
                    local Condition = _x
                    CompVars[y] = Condition
                    CheckCount[y] = 0
                    return Value;
                end

                if Typeof(Value) == "function" or Value == Env then return Value end

                SetInternalValue(Var, Value)
                return Spy(Var, nil, Info)
            end
        end

        local ActiveIfs, CheckedIfs = {}, {}
        local ForLoops = {}
        local Whiles = {}
        local CalledFuncs = {}
        local Checked, CheckedKeys = {}, {}
        local WhileCount = 0

        local Last;
        local AllowedTypes = {
            ["boolean"] = true,
            ["nil"] = true
        }

        local LastCondition, LastConditionV2 = nil, nil; --> use for infinite while detection?

        function SecureEnv.GET(text : any, ...)
            local Type = typeof(text)
            if Type ~= "string" then
                if false and IsExploring and AllowedTypes[Type] and not Variables[text] then
                    DefineVar(
                        ToAST(text),
                        false,
                        true
                    )
                elseif IsExploring and ParamsDict[text] then
                    return Spy(DefineVar(
                        ToAST(text),
                        false,
                        true
                    ), text), ...
                end
                return text, ...
            end

            local Len = #text

            if
                not Strings[text] and
                Len % 4 ~= 0 and
                Len > 1 and
                not IsBetween(Len, 13, 15) and
                not text:find("[\1-\30\133-\255]")
            then
                local PreviousString = text:sub(1, -2) --> This file -> This fil

                --[[if Previous then --> actually used constant!
                    Previous.data.values, Previous.data.vars = {}, {};

                    Strings[PreviousString] = nil;
                    ConstantList[PreviousString] = nil;

                    local Var = GetVar()

                    Strings[text] = Var
                    ConstantList[text] = Define(
                        Ast.Variable(Var),
                        Ast.String(text),
                        false,
                        true
                    )
                else
                    Strings[text] = DefineVar(Ast.String(text))
                end]]

                --Strings[PreviousString] = nil
                local Var, Stat = DefineVar(Ast.String(text))

                ConstantList[text] = Stat
                Strings[text] = Var;
            end

            return text, ...
        end

        function SecureEnv.CONCAT(text : string, text2 : string)
            local Result = text .. text2

            if Result:find("\239", 0, true) then return Result end
            
            local Subbed = Result:sub(1, -2)

            if Strings[Subbed] then
                Strings[Subbed] = nil

                local Old = ConstantList[Subbed]
                if Old then Old.data.vars, Old.data.values = {}, {} end

                local Var, Stat = DefineVar(Ast.String(Result))

                Strings[Result] = Var
                ConstantList[Result] = Stat
            end

            return Result
        end

        function SecureEnv.CALL(func : func, ...) : any
            if not func or typeof(func) == "number" then
                local Var = GetVar()
                local Call = Ast.FunctionCall(Ast.Group(Ast.Variable("nil")), TupleToAST(...))
                local Assign = Ast.Assign( { Ast.Variable(Var) }, { Call } )
                Ast.addStatement(AST, Assign)
            end

            local Hook = FunctionHooks[func]
            if Hook then
                Ast.Comment(Ast.RawText("A hooked function was used here."))
                return Hook(...)
            end;

            if typeof(func) ~= "function" then
                local var = Variables[func]
                if var and LuaTypes[Typeof(func)] then --> Not a custom type (Like game, Enum, ...)
                    return __call(func, ...);
                end
            end

            if CallsHandler then
                return CallsHandler(func, ...)
            end

            return func(...)
        end

        function SecureEnv.NAMECALL(func : { [string]: func }, method : string, ...)
            if typeof(func) == "string" then
                return SecureEnv.string[method](GetInternalValue(func), ...)
            end
            return func[method](func, ...)
        end

        function SecureEnv.CHECKIF(Condition : any, id : number, elseId : number) : any
            local Var = GetContext(Condition)
            local _Condition = Condition
            Condition = GetInternalValue(Condition)

            if Var then
                IfId += 1
                
                local Value = VarValues[Var]
                if Value then
                    local Expr = AstLib.ExprToCode(Value)
                    local If = CheckedIfs[Expr] or { uses = 0, condition = Condition }
                    If.uses += 1
                    CheckedIfs[Expr] = If

                    if If.uses >= 20 then
                        StopWhileLoops += 1
                        return not If.condition
                    end
                end

                local WillRun, HasElse = Condition, elseId == 1
                local IsFunc = Typeof(Condition) == "function"

                local Hook = StatementHooks[IfId]
                if Hook ~= nil then
                    WillRun = Hook;
                end

                if IsFunc and (Wrapped[Condition]) then return WillRun end

                if not WillRun then
                    if not HasElse then
                        Ast.addStatement(AST, Ast.IfStat(ToAST(_Condition), Ast.Block({
                            Ast.PermaComment(Ast.RawText(`didnt run, if id: {IfId}`))
                        })))
                        return WillRun
                    end
                end

                OpCountCheck();

                insert(WaitingIfs, { _Condition, #AST.data.statements, not WillRun and HasElse, HasElse, IfId }) --> In a for loop, The last statement is the forprep.
                return WillRun;
            end

            return Condition
        end

        function SecureEnv.CHECKIFEND(id : number)
            local LengthNow = #AST.data.statements
            local Len = #WaitingIfs

            if Len == 0 then return end

            local Oldest = WaitingIfs[Len]
            if Oldest[2] == LengthNow--[[ or Last == Oldest]] then return end -- THIS WORKS???? :sob:

            local LastStat = AST.data.statements[LengthNow]
            if LastStat.kind == "assign" and LastStat.data.values[1].kind == "index" then return end

            local StartedAt = Oldest[2]
            
            local Comment = Ast.PermaComment(Ast.RawText(`{Oldest[3] and "didnt run (else)" or "ran"}, if id: {Oldest[#Oldest]}`))
            local Body = Ast.Block{Comment}

            for i = StartedAt + 1, LengthNow do
                Ast.addStatement(Body, AST.data.statements[i])
                AST.data.statements[i] = nil
            end

            local IsElse = Oldest[3]

            if IsElse then
                Ast.addStatement(AST, Ast.IfStat(ToAST(Oldest[1]), Ast.Block{}, Body))
            else
                Ast.addStatement(
                    AST,
                    Ast.IfStat(
                        ToAST(Oldest[1]),
                        Body--,
                        --Oldest[4] and Ast.Block{} or nil
                    )
                )
            end
            table.remove(WaitingIfs, Len)
            Last = Oldest
        end

        function SecureEnv.CHECKWHILE(x, id)
            TotalWhiles += 1

            local Var = Variables[x]

            if Var then
                if Indexes[Var] then
                    --AlwaysIgnore[Var] = true
                    --SetInternalValue(Var, nil)
                    return nil;
                end
            end

            if TotalWhiles >= WHILE_LIMIT then
                print("too many iterations!")
                Ast.addStatement(AST, Ast.WhileLoop(ToAST(x), Ast.Block{}))
                error("too many iterations")
            end

            local X = GetInternalValue(x)
            local Stats = AST.data.statements
            local Len = #Stats

            --[[
                CHECKWHILE(true, 1) -> print("sh3b el noni") -> do nothing
                CHECKWHILE(true, 1) -> print("bel sha7at") -> do nothing
                CHECKWHILE(true, 1) -> print("sh3b el noni") -> REMOVE THIS!!!!!!!!!! AND STOP LOGGING
            ]]

            if Len ~= LastLen and Settings.inf_loops and false then
                local Exprs = WhileExprs[id] or {}

                local Stat = Stats[Len]

                --if Stat.kind == "assign" then Stat = Stat.data.values[1] end
                if Stat.kind == "assign" and Stat.data.values[1].kind == "index" then
                    WhileExprs[id] = {}
                elseif Stat.kind == "variable" then
                else
                    --> Len - LastLen = 2

                    local meower = AstLib.ExprToCode(Stat, 0, true)
                    for n, expr in next, Exprs do
                        if expr[1] == meower then
                            if expr[3] <= 10 then
                                if expr[3] == 0 then
                                    expr[4] = Len - expr[2] -- body length
                                end

                                expr[3] += 1
                                break
                            else
                                local Start = expr[2]
                                local OrigStat = Stats[Start]
                                if not OrigStat then return X end

                                local First = AstLib.ExprToCode(OrigStat, 0, true);
                                local Logged = Ast.Block{}
                                local Added = {}

                                for i = Start - (expr[4] - 1), Len do
                                    local Stat = Stats[i]
                                    if not Stat then continue end

                                    local Coded = AstLib.ExprToCode(Stat, 0, true)
                                    if i ~= Start and Coded == First then
                                        for x = i, Len do
                                            Stats[x] = nil
                                        end
                                        break
                                    end
                                    if Added[Coded] then
                                    else
                                        Added[Coded] = true
                                        Ast.addStatement(Logged, Stats[i])
                                    end
                                    Stats[i] = nil
                                end

                                if x then
                                    Ast.addStatement(AST, Ast.WhileLoop(ToAST(x), Logged))
                                else
                                    Ast.addStatement(AST, Logged)
                                end
                                StopWhileLoops += 1
                            end
                        end
                    end

                    insert(Exprs, { meower, Len, 0 })
                    WhileExprs[id] = Exprs

                    LastLen = Len
                end
            end

            if StopWhileLoops > 0 then
                StopWhileLoops -= 1
                return false
            end

            return X
        end

        function SecureEnv.CHECKWHILEEND()end
        function SecureEnv.REPEAT()
            TotalRepeats += .5
            if TotalRepeats >= WHILE_LIMIT then
                print("REPEAT")

                print("too many iterations!")
                error('too many iterations')
            end
        end

        function SecureEnv.CHECKINDEX(tbl : tbl, key : any)
            if typeof(tbl) == "string" or tbl == string then return SecureEnv.string[key] end
            if Checked[tbl] or CheckedKeys[key] then return tbl[key] end

            local Pre = Predefined[key]
            if Pre then
                local Var = DefineVar(
                    Ast.Index(
                        ToAST(tbl),
                        ToAST(key)
                    )
                )
                return SafeValue(Var, Pre[1])
            end

            --> do the predefined stuff here!!!!!!

            local KeyVar, TblVar = GetContext(key), Variables[tbl]
            local _Key = key
            key = GetInternalValue(key)

            if not TblVar and tbl then
                local ShouldSpy = KeyVar--false and (KeyVar or SearchTable(tbl));

                Checked[tbl] = true

                if ShouldSpy then
                    local ResultVar = DefineVar(
                        ToAST(tbl),
                        false,
                        true
                    )

                    Variables[tbl] = ResultVar

                    local mt = fenv.getmetatable(tbl)
                    if typeof(mt) == "table" then
                        local old = table.clone(tbl)
                        table.clear(tbl)
                        setmetatable(tbl, getmetatable(GetMetatable(ResultVar, mt, old)))
                        return tbl[key]
                    else
                        local doimeowtoomuch = DefineVar(
                            Ast.Index(
                                Ast.Variable(ResultVar),
                                Ast.Variable(KeyVar)--ToAST(_Key)
                            ),
                            false,
                            true
                        )

                        local info = Information[_Key]
                        if info and info.is_property or Settings.discord then --> Something like game.PlaceId, textbox.Text, ...
                            return Spy(doimeowtoomuch, tbl[key], info)
                        end
                    end

                    CheckedKeys[_Key] = true
                end
            end

            return tbl[key];
        end

        function SecureEnv.CONSTRUCT(tbl)
            --[[local ShouldSpy = SearchTable(tbl);
            if ShouldSpy then
                local ResultVar = DefineVar(
                    ToAST(tbl),
                    false,
                    true
                )
            end]]
            --[[if #tbl ~= 1 or true then
                for i, v in next, tbl do
                    if GetContext(v) and not ParamsDict[v] then
                        local ResultVar = DefineVar(
                            ToAST(tbl),
                            false,
                            true
                        )

                        Variables[tbl] = ResultVar
                        break
                    end
                end
            end]]
            return tbl
        end

        function SecureEnv.RETURN(...)
            if IsExploring or IsInPcall or true then return ... end

            for _, v in next, {...} do
                local Context = GetContext(v)
                if Context and typeof(v) ~= "function" then
                    local caller = debuginfo(2, "f")
                    if not iscclosure(caller) and not Variables[caller] then
                        --> Define it as a local function, then return the values as a call result.
                        local FuncName, Stat = DefineVar(
                            ToAST(caller, { as_func = true })
                        )

                        Variables[caller] = FuncName
                        local _, Called = AppendCall(FuncName)
                        return ToMultiVars(Called, pack(...))
                        --[[local _, Stat = DefineVar(
                            Ast.Function(GetParams(caller), ToAST(caller, { as_func = true }))
                        )]]
                        --return ToMultiVars(Stat, pack(...))
                    end
                end
            end
            return ...
        end

        function SecureEnv.ADD(x : any, y : any)
            if y == 1 and x == 0 and IsInPcall then
                return 2;
            end
            return x + y;
        end

        function SecureEnv.FORINFO(id : number, from : any, to: any, step : number)
            ForLoops[id] = { from, to, step }
        end

        for i = 1, 2 do
            SecureEnv["FORSTEP" .. i] = function(id)
                local Loop = ForLoops[id]
                local Value = Loop[i]

                if Variables[Value] then
                    Ast.addStatement(AST, Ast.ForNum("i", ToAST(Loop[1]), ToAST(Loop[2]), ToAST(Loop[3] or 1), Ast.Block{}))
                    local Thing = GetInternalValue(Value)
                    if Variables[Thing] then
                        return 1;
                    else
                        return Thing;
                    end
                end
                return Value
            end
        end

        local EqFunc = Eq("==")

        SecureEnv.CHECKEQ = EqFunc
        SecureEnv.CHECKNEQ = Eq("~=")

        local HowManyChecks = 6; --> How many times a variable needs to be compared in order to log it (PROMETHEUS THING)

        local function NumCompare(Symbol) --> Optimized JUST for numbers
            local IsLessThan, IsGreaterThan, IsGreaterOrEqual, IsLessOrEqual = Symbol == "<", Symbol == ">", Symbol == ">=", Symbol == "<="
            local GetValue =
                IsLessThan and
                    function(x, y) return x < y end
                or IsGreaterThan and
                    function(x, y) return x > y end
                or IsGreaterOrEqual and
                    function(x, y) return x >= y end
                or IsLessOrEqual and
                    function(x, y) return x <= y end

            return function(IsMarCute, YesSheIs)
                local VarA, VarB = GetContext(IsMarCute), GetContext(YesSheIs)
                local Comp = CompVars[IsMarCute]

                if Comp then
                    local Value = GetValue(IsMarCute, YesSheIs)
                    local Variable = Variables[Comp]
                    if not Variable then return Value end

                    local Count = CheckCount[IsMarCute]
                    CheckCount[IsMarCute] = Count + 1

                    --if Count >= HowManyChecks or (Count + 1 == HowManyChecks and not Value) then
                    if Count == HowManyChecks then
                        local MarIsCute = Ast.Variable(Variable)
                        local Var = DefineVar(
                            Value and MarIsCute or Ast.UnaryOp(MarIsCute, "not")
                        )

                        return Spy(Var, Value)
                    else
                        return Value
                    end
                end

                local ShesEvenCuter = GetInternalValue(IsMarCute)
                local OrIsShe = GetInternalValue(YesSheIs)

                if not VarA and not VarB then return GetValue(ShesEvenCuter, OrIsShe) end

                local TypeMar = Typeof(IsMarCute)
                local TypeShi = Typeof(YesSheIs)
                local IsMarNumber = TypeMar == "number"

                if IsLessOrEqual then
                    if IsMarCute and (Information[YesSheIs] or {}).is_random and IsMarCute == 1 then
                        --> stop spying..? (yuh)
                        AlwaysIgnore[VarB] = true --> stop spying ts garbage
                        return GetValue(ShesEvenCuter, OrIsShe);
                    end
                end

                local Var = DefineVar(
                    Ast.BinaryOp(ToAST(IsMarCute), Symbol, ToAST(YesSheIs)),
                    false,
                    true
                )

                if TypeMar == "Instance" or TypeShi == "Instance" then
                    error(`attempt to compare {TypeMar} {Symbol} {TypeShi}`)
                end

                local Success, Val = pcall(GetValue, ShesEvenCuter, OrIsShe)
                if not Success then
                    assert(not Settings.roblox, Val)
                    --Val = IsGreaterThan

                    --[[
                        x <= 100 -> false
                        x >= 100 -> true
                        100 <= x -> true
                        100 >= x -> false
                    ]]

                    --print(IsMarCute, Symbol, YesSheIs, OrIsShe)

                    if VarB and IsMarNumber then --> 100 <= x
                        Val = IsLessThan or IsLessOrEqual
                    elseif VarA and TypeShi == "number" then --> x >= 100
                        Val = IsGreaterThan or IsGreaterOrEqual
                    end
                end

                Ast.addStatement(AST, Ast.Comment(ToAST(Val)))
                return Spy(Var, Val);
            end
        end

        SecureEnv.COMPG = NumCompare(">")
        SecureEnv.COMPGE = NumCompare(">=")
        SecureEnv.COMPL = NumCompare("<")
        SecureEnv.COMPLE = NumCompare("<=")

        SecureEnv.CHECKAND = Compare("and")
        SecureEnv.CHECKOR = Compare("or")

        local New = {}

        for i, v in next, SecureEnv do
            Nil[i] = true
            New[CallId .. i] = v
        end

        SecureEnv = New;
        SecureEnv.rawequal = function(a, b)
            if Variables[a] or Variables[b] then return EqFunc(a, b) end
            return rawequal(a, b);
        end
    else
        SecureEnv.rawequal = function(a, b)
            if Variables[a] or Variables[b] then return a == b end
            return rawequal(a, b);
        end
    end

    local function Unary(Symbol)
        local function Get(x)
            if Symbol == "not" then return not x
            elseif Symbol == "-" then return -x
            elseif Symbol == "#" then return #x
            end
        end

        return function(x)
            local Var = GetContext(x)
            local X = GetInternalValue(x)

            if Var then
                local IsNot = Symbol == "not"
                local Type = Typeof(X)

                if TrueEnv[Var] and Type == "function" then return Get(x) end -- lua global
                if not IsNot and Type == "Instance" then
                    error(`attempt to perform arithmetic (__{Symbol == "#" and "len" or "unm"}) on an Instance value`)
                end

                local Value;

                if not Variables[X] or IsNot then --> #x, -x or not x
                    local Success, Result = pcall(Get, X);
                    if Success then
                        Value = Result;
                    end
                end

                local Var = DefineVar(Ast.UnaryOp(ToAST(x), Symbol))
                local Type = 
                    if Symbol == "#" then "number"
                    elseif Symbol == "not" then "boolean"
                    else "number"
                --> This type thing may be inaccurate, as uhhhh stuff CAN be metatables by the original script, maybe fix this later:)
                if not hookOp then
                    return SafeValue(Var, Value);
                end
                return TypeSpy(Var, Type, Value)
            end
            return Get(X);
        end
    end

    SecureEnv[CallId .. "CHECKNOT"] = Unary("not")
    SecureEnv[CallId .. "CHECKUNM"] = Unary("-")
    SecureEnv[CallId .. "CHECKLEN"] = Unary("#")

    SecureEnv[CallId .. "TEMPLATE_STRING"] = function(...)
        local Var = DefineVar(
            Ast.InterpolatedString(unpack(TupleToAST(...)))
        )
            
        local strTable = {}

        for _, v in next, {...} do
            if Variables[v] then
                return Spy(Var) --> No internal values.
            else
                insert(strTable, tostring(v))
            end
        end

        SetInternalValue(Var, concat(strTable, ""))

        return Spy(Var)
    end

    local SayPlease: { string } = {}
        --> Globals that get wrapped
    local FineUgh : { string } = { "select", "newproxy" }
        --> Globals that get replaced with their real values

    --! ENVIRONMENT

    local function TypeFunction(Name)
        return Function(function(Value : any) : string
            local Type = Typeof(Value)
            if Name == "type" and not LuaTypes[Type] then Type = "userdata" end

            local Variable = GetContext(Value)
            if Variable and not IgnoreInEq[Variable] and Type ~= "function" then
                return SafeValue((AppendCall(Name, Value)), Type);
            end
            return Type;
        end, Name, true)
    end

    local AllowedPaths = {}

    local function DefineTable(Table) : Variable
        local TableStr = DefineVar(Table)
        local OldMetatable = getmetatable(Table);
        local NewMetatable = getmetatable(GetMetatable(TableStr))

        local FixedMetatable = {};

        if OldMetatable then
            for method, callback in next, NewMetatable do
                local oldMethod = OldMetatable[method]
                if oldMethod then
                    FixedMetatable[method] = function(...)
                        callback(...)
                        return oldMethod(...)
                    end
                else
                    FixedMetatable[method] = callback
                end
            end
        else
            FixedMetatable = NewMetatable
        end
                            
        setmetatable(Table, FixedMetatable)

        Variables[Table] = TableStr
        return TableStr
    end

    local Calls = {}

    local function SafeWrap(Func, Path)
        local Library = split(Path, ".")[1]

        local DoRecurse = Path == "table.concat"
        local DontLogAnyways = Path == "table.pack"
        local LogPath = Path == "table.insert"

	    local OutFunc = Function(function(...)
            --print("ye",Path)

            local args = {...}
            local info;
            local DoSpy, DontRun;

            local function Iterate(tbl, recursive)
                local Var = GetContext(tbl)
                local Int = GetInternalValue(tbl)
                if Var then
                    DoSpy = true
                    if Variables[Int] then
                        DontRun = true
                    end
                    return Int;
                end --^ safe

                for i, v in next, tbl do
                    if DontRun then return tbl end

                    local Var = Variables[v]

                    if ParamsDict[v] then
                        DontRun = DontRun or (Library ~= "table" and Nest > 0)
                        if DontRun then break end
                        continue
                    end

                    if not DoSpy and Var then
                        DoSpy = true
                    end

                    info = info or Information[v]

                    local Val = GetInternalValue(v)
                    if Variables[Val] then
                        DontRun = true
                        break
                    end

                    if recursive and typeof(v) == "table" then
                        for i2, v2 in next, v do
                            v[i2] = if typeof(v2) == "table" then Iterate(v2, recursive) else v2;
                        end
                    else
                        tbl[i] = Val
                    end
                end
                return tbl;
            end

            args = Iterate(args, DoRecurse);

            if (DoSpy or DontRun) and not DontLogAnyways then
                if LogPath then
                    for _, arg in next, { ... } do
                        if typeof(arg) == "table" and not Variables[arg] then
                            DefineTable(arg)
                        end
                    end

                    --! THIS IS UNSAFE!!

                    Func(unpack(args));

                    local Var = AppendCall(Path, ...)
                    return Spy(Var)
                end

                if DontRun and not Settings.roblox then
                    local Var = AppendCall(Path, ...)

                    return Spy(Var);
                else
                    local Var, Statement = AppendCall(Path, ...)

                    --> A spy argument was involved (DoSpy). If the real builtin rejects an
                    --> env-derived nil/wrong-type (e.g. buffer.readu8(spy->nil)), that's our
                    --> environment, not the script - recover with a spy and keep logging
                    --> instead of truncating the whole dump. Genuine concrete-arg errors go
                    --> through the outer branch below (no spy) and still propagate.
                    local Results = pack(pcall(Func, unpack(args)))
                    if not Results[1] then
                        local Err = tostring(Results[2])
                        if Err:find("too many operations", 1, true) or Err:find("too many iterations", 1, true) then
                            error(Results[2]) --> op/iteration limits must propagate
                        end
                        return Spy(Var)
                    end

                    local Values = pack(unpack(Results, 2, Results.n))

                    if Path == "string.byte" then
                        return unpack(Values)
                    end
                    return ToMultiVars(Statement, Values, true, info)
                end
            else
                return Func(...)
            end

            return Func(unpack(args))
	    end, Path, true)

        Wrapped[OutFunc] = true

        return OutFunc
    end

    local function HookLibrary(Path : string, Extra : { [string]: (any) }?)
        local Library : { [string]: any } = table.clone(TrueEnv[Path]);
        
        local New = {}
        if Extra then
            for i, v in next, Extra do
                New[i] = if typeof(v) == "function" and not Types[v] then Function(v, Path .. "." .. i, true) else v
            end
        end

        for Key, Value in next, Library do
            New[Key] =
                if typeof(Value) == "function" and not New[Key] then
                    SafeWrap(Value, Path .. "." .. Key)
                else
                    New[Key] or Value
        end

        New = GetMetatable(Path, {
            __index = New,
            __newindex = function(_,k,v)
                Ast.addStatement(AST, Ast.Assign( { Ast.Index( Ast.Variable(Path), ToAST(k) ) } , { ToAST(v) }, true))
                error("attempt to modify a readonly table")
            end
        })

        return New
    end

    local function DoIgnore(Key : string?)
        if typeof(Key) ~= "string" then return false end
        if Key:match(NON_ENGLISH) or NumbersDict[Key:sub(1, 1)] then return true end
        local Len = #Key
        if Len < 12 then
            return false
        elseif Len >= 24 then
            return true
        end
        
        -- must have: 1 uppercase, 1 lowercase

        local Uppercase = match(Key, "[A-Z]")
        local Lowercase = match(Key, "[a-z]")

        return Uppercase and (Lowercase or match(Key, "%d"))
    end

    local function IsWeird(Key) : boolean
        if Key == "" or typeof(Key) ~= "string" or tonumber(sub(Key, 1, 1)) then return true end -- If key == "" or the key isnt a string or the first byte is a number

        return match(Key, "[^%w_]") ~= nil or Illegal[Key]
    end

    local function Index(Key, Path, InNewindex) : string
        if Path == "..." then
            Path = "({...})"
        end

        if not IsWeird(Key) then
            return Path and `{Path}.{Key}` or Key
        end

        Path = Path or EnvName

        return `{Path}[{tostring(Key)}]`
    end

    local TickCalls = 0;
    local startTime = os.time()
    local startClock = os.clock()

    local function tick(): number
        TickCalls += 1

	    return startTime + (os.clock() - startClock) + (TickCalls / 1000)
    end

    SetGarbageData({
        DoIgnore = DoIgnore,
        Strings = Strings
    })

    local function HookFunction(Name)
        return Function(function(a : func, b : func)
            local typeA, typeB = Typeof(a), Typeof(b)

            assert(typeA == "function" or not Types[a], "invalid argument #1 to '" .. Name .. "', function expected got " .. typeA)
            assert(typeB == "function" or not Types[b], "invalid argument #2 to '" .. Name .. "', function expected got " .. typeB)

            local Old = AppendCall(Name, a, b)

            if not hookOp then
                Ast.addStatement(AST, Ast.Comment(Ast.RawText("hookOp isn't enabled, therefore hookfunction cannot be used.")))
            end

            FunctionHooks[a] = b
            return Function(
                function(...)
                    return a(...)
                end,
                Old,
                iscclosure(a)
            );
        end, Name, true)
    end

    local function Restore(Func : func)
        FunctionHooks[Func] = nil
    end

    local function IsHooked(f) return FunctionHooks[f] ~= nil end

    if Nest == 0 then
        local PropertyHooks = {
            DataModel = {
                PlaceId = {
                    Type = "Primitive",
                    Name = "number"
                },
                GameId = {
                    Type = "Primitive",
                    Name = "number"
                },
                JobId = {
                    Type = "Primitive",
                    Name = "string"
                }
            },
            Player = {
                Team = {
                    Type = "Class",
                    Name = "Team"
                },
                PlayerGui = {
                    Type = "Class",
                    Name = "PlayerGui"
                }
            },
            TextBox = {},
            ["*"] = {}
        }

        local Generated = {}

        local ForceNormal = {
            Name = true
        }

        local GlobalInstanceData = InstanceLib.Object
        local Attributes = {}
        local Signals = {}

        local ServicesCreated; --> Have the DataModel's services been loaded?
        local Gets = 0;
        local urlCache = {} :: { [string]: string };

        function httpGet(url : string) : string?
            local cached = urlCache[url]
            if cached then return cached end
            if not Settings.isPremium then return end

            local out = process.exec("node", {
	            "./request.js",
	            url
            })

            local result = out.stdout
            local success = not out.stderr:find("Unable to fetch", 0, true)

            if success and result then
                urlCache[url] = result;
                return result;
            end
            return;
        end

        local function HttpGet(Self : VariableData, Url : string, Sync: boolean?)
            local UrlType = Typeof(Url)
            local IsRaw = UrlType == "string"
            assert(IsRaw or not Settings.roblox, `invalid argument #1 to '{Sync and "HttpGetAsync" or "HttpGet"}', string expected got {UrlType}`)

            Gets += 1
            Url = GetInternalValue(Url)
            if Gets <= AllowedGetRequests and typeof(Url) == "string" then -- re-checking UrlType incase it's just a spied table
                insert(AllowedUrlsInTheEnd, Url)

                local result = httpGet(Url)
                if result then SetInternalValue(Self.var, result) end
            end

            return TypeSpy(Self.var, "string", nil, {
                is_http = true,
                url = Url
            })
        end

        local MethodsHooks = {
            DataModel = {
                HttpGet = HttpGet,
                HttpGetAsync = function(self, url, idk, ...)
                    return HttpGet(self, url, true, ...)
                end,
                IsLoaded = function(self) return SafeValue(self.var, true) end
            },
            RunService = {
                IsClient = function(Self : VariableData)
                    return SafeValue(Self.var, true)
                end,
                IsServer = function(Self : VariableData)
                    return SafeValue(Self.var, false)
                end,
                IsStudio = function(Self : VariableData)
                    return SafeValue(Self.var, false)
                end
            },
            RbxAnalyticsService = {
                GetClientId = function(Self) return SafeValue(Self.var, SharedGlobals.HWID) end
            },
            HttpService = {
                JSONEncode = function(Self : VariableData, Data : any)
                    Data = GetInternalValue(Data)

                    local Type = typeof(Data)
                    local Meower = TypeSpy(Self.var, "string")

                    if Type ~= "table" then
                        assert(not Settings.roblox, `invalid argument #1 to 'JSONEncode', table expected got {Type}`)
                        return Meower
                    else
                        for i, v in next, Data do
                            local _v = GetInternalValue(v);
                            local varV = Variables[_v]

                            if varV then return Meower; end
                            Data[i] = _v;
                        end
                    end

                    local Encoded = serde.encode("json", Data, false)
                    return SafeValue(Self.var, Encoded)
                end,
                JSONDecode = function(Self : VariableData, Data : string)
                    Data = GetInternalValue(Data)

                    local Type = typeof(Data)
                    if Type ~= "string" then
                        assert(not Settings.roblox, `invalid argument #1 to 'JSONDecode', string expected got {Type}`)
                        return TypeSpy(Self.var, "table")
                    end

                    return SafeValue(Self.var, serde.decode("json", Data));
                end
            },
            Terrain = {
                GetMaterialColor = function(self, material)
                    local mat = GetInternalValue(material)

                    assert(mat, "Argument 1 missing or nil")
                    local type = typeof(mat)
                    local Aliases = {
                        number = "double"
                    }
                    local Stringed = tostring(mat)

                    assert(Stringed:find(".Material."), `Unable to cast {if LuaTypes[type] then Aliases[type] or type else "null"}`)
                    return SafeValue(self.var, GetTerrainMaterialColor(Stringed:match("%w+%.%w+%.(.+)")))
                end
            },
            ["*"] = {
                GetAttribute = function(self : VariableData, attribute : string)
                    return SafeValue(self.var, (Attributes[self.self] or {})[attribute])
                end,
                GetAttributes = function(self : VariableData)
                    return SafeValue(self.var, Attributes[self.self] or {})
                end,
                SetAttribute = function(self : VariableData, attribute : string, value : any)
                    local AttributesList = Attributes[self.self] or {}
                    AttributesList[attribute] = value
                    Attributes[self.self] = AttributesList
                end
            }
        }

        local EventHooks = {
            RunService = {
                Heartbeat = {
                    ReturnValue = {
                        TIME_TO_WAIT
                    }
                }
            }
        }

        for funcName, func in next, InstanceFuncs do
            MethodsHooks["*"][funcName] = function(Self, ...)
                local Values = pack(func(SpiedToInstance[Self.self], ...))
                if Values.n == 1 then
                    return SafeValue(Self.var, Values[1])
                end
                return unpack(Values);
            end
        end

        MethodsHooks.DataModel.HttpGetAsync = MethodsHooks.DataModel.HttpGet
        local function GetChildren(Parent, Recursive)
            if not ServicesCreated and SpiedToInstance[Parent] == SpiedToInstance[SecureEnv.game] then
                for ServiceName in next, Services do
                    pcall(function()
                        insert(Children[Parent], CreateInstance(Index(ServiceName, "game"), ServiceName, true))
                    end)
                end
                ServicesCreated = true
            end

            local Kids = Children[Parent]
            if not Kids then return {} end
            if not Recursive then return Kids end

            local Total = {}
            for _, Child in next, Kids do
                for _, v in next, GetChildren(Child, Recursive) do
                    insert(Total, v)
                end
                insert(Total, Child)
            end
            return Total
        end

        MethodsHooks["*"].GetChildren = function(Self : VariableData)
            SetIterator(Self.var, "number", "Instance")
            return SafeValue(Self.var, GetChildren(Self.self, false))
        end

        MethodsHooks["*"].GetDescendants = function(Self : VariableData)
            SetIterator(Self.var, "number", "Instance")
            return SafeValue(Self.var, GetChildren(Self.self, true))
        end

        local function SetParent(Instance : Spied, Parent : Spied)
            local SpiedParentV1, SpiedInstanceV1 = SpiedToInstance[Parent], SpiedToInstance[Instance]
            local RealSelf, RealParent = SpiedInstanceV1 or Instance, SpiedParentV1 or Parent;
            for oldParent, children in next, Children do
                local idx = find(children, RealSelf)
                if idx then
                    table.remove(children, idx)
                    break
                end
            end

            RealSelf.Parent = RealParent
            local SpiedParent, SpiedInstance;

            if SpiedParentV1 then --> Avoid using == so __eq doesnt get triggered
                --> this is the spied parent
                SpiedParent = Parent
            else
                for Spied, Real in next, SpiedToInstance do
                    if Real == Parent then
                        SpiedParent = Spied
                        break
                    end
                end
            end

            if SpiedInstanceV1 then --> Avoid using == so __eq doesnt get triggered
                --> this is the spied parent
                SpiedInstance = Instance
            else
                for Spied, Real in next, SpiedToInstance do
                    if Real == Instance then
                        SpiedInstance = Spied
                        break
                    end
                end
            end

            if SpiedParent then
                local list = Children[SpiedParent] or {}
                insert(list, SpiedInstance)
                Children[SpiedParent] = list
            end
        end

        function CreateInstance(Variable : string, Class : string?, EnableCache : boolean?, FromInstanceNew : boolean?)
            local function GenerateProperty(ValueType, Name)
                if Generated[ValueType] then return Generated[ValueType] end

                local Category = ValueType.Category or ValueType.Type

                if Category == "Primitive" then
                    local Type = AliasToName[ValueType.Name] or ValueType.Name

                    if Type == "number" then
                        return math.random(0, 1e6)
                    elseif Type == "string" then
                        return GenId(8)
                    end
                elseif Category == "Class" then
                    --return CreateInstance(Index(Name or ValueType.Name, Variable), ValueType.Name, true)
                    return CreateInstance(Name, ValueType.Name, true)
                elseif Category == "DataType" then
                    --[[if ValueType.Name == "Vector2" then
                        return roblox.Vector2.new(0, 0)
                    end]]
                    if ValueType.Name == "Instances" then
                        local Meow = DefineVar(
                            Ast.Index(
                                Ast.Variable(Name),
                                Ast.Number(1)
                            )
                        )

                        return { CreateInstance(Meow) }
                    end
                end
                return Spy(Name);
            end

            local function CreateEvent(Self : Spied, EventName : string, Params : { { [string] : any } }, EventStr : string)
                local Sigs = Signals[Self] or {}

                if Sigs[EventName] then return Sigs[EventName] end

                local Keys = {
                    connect = true, Connect = true
                }

                local BaseVar = Ast.Variable(EventStr)
                local Hooks = EventHooks[Class] or {}
                local Hook = Hooks[EventName]

                local Signal = GetMetatable(EventStr, {
                    __index = function(event, Key : string)
                        --checktype(Key, "string", "invalid argument #2")
                        assert(event, `missing argument #1 to '{Key}' (RBXScriptSignal expected)`)

                        local key = if typeof(Key) == "string" then Key:lower() else Key;
                        local Var = DefineVar(
                            Ast.Index(BaseVar, ToAST(Key))
                        )

                        if key == "connect" or Key == "ConnectParallel" or Key == "connectParallel" or Key == "connectparallel" then
                            --> Heartbeat.Connect
                            local Spied = Function(function(x, callback : func)
                                checktype(callback, "function", `invalid argument #2 to '{key}'`)

                                local Info = {
                                    param_infos = Params
                                }

                                if false and (EventName == "Heartbeat" or EventName == "RenderStepped") then
                                    --Info.bypass_beautify = true
                                    Info.as_func = true

                                    Explore(callback, Info) -- run it again just incase
                                    --Explore(callback, Info) -- run it again just incase
                                end
                                
                                local Conn = DefineVar(
                                    Ast.Namecall(
                                        BaseVar,
                                        Ast.Variable(Key),
                                        {
                                            ToAST(
                                                callback,
                                                Info
                                            )
                                        }
                                    ),
                                    false,
                                    true
                                )

                                --> return an RBXScriptConnection soon..
                                local int = {};
                                int.Connected = true
                                int.Disconnect = function(self, ...)
                                    assert(self, "missing argument #1 to 'Disconnect' (RBXScriptConnection expected)")
                                    local Type = Typeof(self)

                                    assert(Type == "RBXScriptConnection", "invalid argument #1 to 'Disconnect' (RBXScriptConnection expected, got " .. Type .. ")")
                                    assert(int.Connected, "Connection is not connected!")

                                    --[[DefineVar(
                                        Ast.Namecall(
                                            Ast.Variable(Conn),
                                            Ast.Variable("Disconnect"),
                                            TupleToAST(...)
                                        )
                                    )]]

                                    int.Connected = false
                                end
                                int.disconnect = int.Disconnect
                                local Connection = GetMetatable(Conn, {
                                    __index = function(_, Key)
                                        return SafeValue(DefineVar(Ast.Index(Ast.Variable(Conn), ToAST(Key))), int[Key])
                                    end
                                })
                                Types[Connection] = "RBXScriptConnection"

                                return Connection
                            end, Var, true)
                            --rawset(event, Key, Spied)
                            --! COMMENTED, SINCE ROBLOX IS FREAKING STUPID, EVERY NEW __INDEX CREATES A NEW FUNCTION 🥹🥹🥹
                            return Spied;
                        elseif key == "wait" then
                            return Function(function(_, ...)
                                local ReturnedMeowers = {}
                                local Vars = {}

                                for i, v in next, Params do
                                    local Var = GetCount(v.Name);
                                    local Spied = Spy(Var, if Hook and Hook.ReturnValue then Hook.ReturnValue[i] else nil)

                                    local thingInfo = v.Type;
                                    if thingInfo.Category == "Primitive" then
                                        local Type = AliasToName[thingInfo.Name] or thingInfo.Name
                                        Types[Spied] = Type
                                    end

                                    insert(ReturnedMeowers, Spied)
                                    insert(Vars, Ast.Variable(Var))
                                end

                                Ast.addStatement(
                                    AST,
                                    Ast.Assign(
                                        Vars,
                                        {
                                            Ast.Namecall(
                                                BaseVar,
                                                Ast.Variable(Key),
                                                TupleToAST(...)
                                            )
                                        },
                                        false
                                    )
                                )
                                task.wait()
                                return unpack(ReturnedMeowers)
                            end, Var, true)
                        elseif key == "once" then
                            return Spy(Var);
                        end

                        error(`{Key} is not a valid member of RBXScriptSignal`)
                    end
                })

                Types[Signal] = "RBXScriptSignal"
                Sigs[EventName] = Signal
                Signals[Self] = Sigs;
                return Signal;
            end

            if EnableCache then
                for x, Real in next, SpiedToInstance do
                    if Real.ClassName == Class then
                        return x--Spy(Variable, x)
                    end
                end
            end

            local InstanceData = InstanceLib[Class]
            local IsSpied = not Class

            if FromInstanceNew then
                assert(InstanceData, `Unable to create an Instance of type "{Class}"`)
            end

            InstanceData = InstanceData or GlobalInstanceData

            local Hooks : { [string]: { [any]: any } } = PropertyHooks[Class] or {};
            local Properties : { [string]: any } = InstanceData.properties
            local Callbacks : { [string] : any } = InstanceData.callbacks or {}

            local imsocute:P = IsSpied and {
                Name = Spy(Index("Name", Variable))
            } or Instance.new(Class);

            local MethodHooksSelf = MethodsHooks[Class] or MethodsHooks["*"]

            local Methods = InstanceData.methods
            local Events = InstanceData.events

            local ActualInstance = {}
            for PropertyName, Property in next, Properties do
                local s, v = pcall(function() return imsocute[PropertyName] end)
                ActualInstance[PropertyName] = if s then v else GenerateProperty(Property.ValueType, PropertyName);
            end

            local is_property = not FromInstanceNew

            local Instance;
            local Mt = {
                __index = function(Self, Key)
                    assert(Key, "invalid argument #2 (string expected, got nil)")

                    local Oldest = Key
                    local Prefix = Key:sub(1, 1)
                    if IsLowerCase(Prefix:byte()) then --> Fixes issues where stuff are still accessible like .getService, this automatically converts to .GetService, .name -> Name, .placeId -> PlaceId
                        Key = Prefix:upper() .. Key:sub(2)
                    end

                    if Callbacks[Key] then
                        error(`{Key} is a callback member of {Class}; you can only set the callback value, get is not available`)
                    end

                    local ErrMsg = `{Oldest} is not a valid member of {Class or "Instance"} "{IsSpied and Class or imsocute.Name}"`
                    if typeof(Key) == "string" and Key:find("\0") then
                        error(ErrMsg)
                    end

                    local Hook = Hooks[Key] or PropertyHooks["*"][Key];
                    local Info = Information[Self] or {}

                    local Indexed = DefineVar(
                        Ast.Index(Ast.Variable(Variable), ToAST(Oldest)),
                        false,
                        true
                    )

                    local isName = (Key == "name" or Key == "Name")

                    if Hook ~= nil or isName then
                        local Property = if isName then imsocute.Name else GenerateProperty(Hook, Indexed)

                        if Typeof(Property) == "Instance" then
                            return Property;
                        end
                        local Spied = Spy(Indexed, Property, {
                            is_property = is_property,
                            key = Key
                        })
                        rawset(Self, Key, Spied)
                        return Spied
                    elseif Key == "Parent" then
                        for Parent, List in next, Children do
                            if find(List, Self) then
                                return SafeValue(Indexed, Parent);
                            end
                        end
                        local P = ActualInstance.Parent
                        if P then
                            for Spied, Meow in next, SpiedToInstance do if P == Meow then P = Spied break end end;

                            return SafeValue(Indexed, P)
                        end

                        return SafeValue(Indexed, nil);
                    end

                    local Property = ActualInstance[Key]
                    if Property ~= nil then
                        if typeof(Property) == "Instance" then
                            local Meowed = CreateInstance(Indexed, Property.ClassName)
                            local Real = SpiedToInstance[Meowed]
                            if typeof(Real) == "table" then
                                for i in next, Real do
                                    pcall(function() Real[i] = Property[i] end)
                                end
                            end
                            return Meowed;
                        end

                        local Spied = Spy(
                            Indexed,
                            Property,
                            {
                                is_property = is_property,
                                force_normal = ForceNormal[Key]
                            }
                        )
                        rawset(Self, Key, Spied)
                        return Spied
                    end

                    local Kids = Children[Instance] or {}
                    for _, v in next, Kids do
                        if SpiedToInstance[v].Name == Key then
                            return v;
                        end
                    end

                    if Class == "DataModel" and Services[Key] then --> game.Players
                        -- check it's kids..
                        --print("yes", Indexed, Key)
                        for _, v in next, Kids do
                            if SpiedToInstance[v].ClassName == Key then
                                return v;
                            end
                        end
                        return CreateInstance(Indexed, Key, true);
                    end

                    if GlobalInstanceData.properties[Key] then
                        local Spied = Spy(Indexed, GenerateProperty(GlobalInstanceData.properties[Key].ValueType, Indexed))
                        rawset(Self, Key, Spied)
                        return Spied
                    elseif Properties[Key] then
                        local Property = GenerateProperty(Properties[Key].ValueType, Indexed)
                        local Real = SpiedToInstance[Property]
                        if Real then
                            SetParent(Real, Instance)

                            return Property
                        end --> .LocalPlayer or sum ting

                        return SafeValue(
                            Indexed,
                            Property,
                            { is_property = is_property, force_normal = true }
                        )
                    end

                    local Method = MethodHooksSelf[Key] or MethodsHooks["*"][Key]
                    local Method2 = Methods[Key] or GlobalInstanceData.methods[Key]
                    local FuncName = Index(Key, Variable)

                    if Method then
                        return Function(function(...)
                            return Method({ var = AppendCall(Indexed, ...), self = ... }, select(2, ...))
                        end, FuncName, true)
                    elseif Method2 then
                        return Function(function(...)
                            local Var = AppendCall(Indexed, ...)
                            local Thing = Spy(Var)
                            if not hookOp then
                                local Value = GenerateProperty(Method2.ReturnType, Var)
                                SetInternalValue(Var, Value) --> have to give it actual values 💘
                            end
                            return Thing;
                        end, FuncName, true)
                    end

                    local Event = Events[Key]

                    if Event then
                        --> implement later
                        return CreateEvent(Self, Event.Name, Event.Parameters, Indexed)
                    elseif GlobalInstanceData.events[Key] then
                        local Spied = Spy(Indexed)
                        rawset(Self, Key, Spied)
                        return Spied
                    end

                    assert(not Settings.roblox, ErrMsg)

                    local Spied = Spy(Indexed, nil, {
                        indexed_instance = true
                    })
                    rawset(Self, Key, Spied)
                    return Spied
                end,
                __newindex = function(Self, Key, Value)
                    Define(
                        Ast.Index(Ast.Variable(Variable), ToAST(Key)),
                        ToAST(Value),
                        true,
                        true
                    )

                    local Info = Information[Self] or {}
                    if Key == "Parent" then
                        if Info.destroyed or Info.service then
                            local Type = Typeof(Value)
                            assert(Type == "Instance", `invalid argument #3 (Instance expected, got {Type})`)

                            error(`The Parent property of {ActualInstance.Name} is locked, current parent: NULL, new parent {(SpiedToInstance[Value] or Value).Name}`)
                        end
                        if SpiedToInstance[Value] == ActualInstance then
                            error(`Attempt to set {ActualInstance.Name} as its own parent`)
                        end
                    end

                    local Property = Properties[Key]
                    if Property then
                        assert(Property.CanSave, `Unable to assign property {Key}. Property is read only`)
                    else
                        if Callbacks[Key] then
                            local callbacks = SharedGlobals.Callbacks[Self] or {}
                            insert(callbacks, { Key = Key, Callback = Value })

                            SharedGlobals.Callbacks[Self] = callbacks
                        else
                            error(`{Key} is not a valid member of {Class} "{ActualInstance.Name}"`)
                        end
                    end

                    ActualInstance[Key] = GetInternalValue(Value);
                end,
                __tostring = function() return Variable end,
                __call = if IsSpied then nil else function(Self, ...)
                    DefineVar(Ast.FunctionCall(ToAST(Self), TupleToAST(...)))
                    if Settings.roblox then
                        Ast.addStatement(AST, Ast.PermaComment(Ast.RawText("Errored here because the script called an Instance value.")))
                        error("attempt to call a Instance value")
                    end
                end
            }

            for i, v in next, Math do
                Mt[i] = function(Self, Value)
                    local TypeLhs, Lhs = Typeof(Self)
                    local TypeRhs, Rhs = Typeof(Value)

                    local Symbol = Math[i]

                    local Var = DefineVar(
                        Ast.BinaryOp(ToAST(Self), Symbol, ToAST(Value))
                    )

                    if TypeLhs == "Instance" or TypeRhs == "Instance" or TypeLhs == "table" or TypeRhs == "table" then
                        if i == "__concat" then
                            error(`attempt to concatenate {TypeLhs} with {TypeRhs}`)
                        end

                        error(`attempt to perform arithmetic ({i:sub(3)}) on {TypeLhs} and {TypeRhs}`)
                    end
                    
                    return GetValue(Lhs, Symbol, Rhs, Var)
                end
            end

            Instance = GetMetatable(Variable, Mt)

            SpiedToInstance[Instance] = ActualInstance
            Types[Instance] = "Instance"
            Variables[Instance] = Variable
            
            Information[Instance] = {
                service = Services[Class] ~= nil,
                was_created = FromInstanceNew
            }

            return Instance
        end

        local function GetParent(Instance : Spied)
            for Meow, List in next, Children do
                if find(List, Instance) then
                    return Meow;
                end
            end
        end

        MethodsHooks["*"].FindFirstChild = function(Self : VariableData, childName : string, Recursive : boolean?)
            local Type = Typeof(childName)
            Assert(Type, "string", "invalid argument #1 to 'FindFirstChild', string expected got " .. Type, true)

            local Kids = GetChildren(Self.self, Recursive);
            for _, Kid in next, Kids do
                if SpiedToInstance[Kid].Name == childName then
                    return Kid;
                end
            end

            if Settings.roblox then
                return SafeValue(Self.var, nil);
            else
                return CreateInstance(Self.var)
            end
        end

        MethodsHooks["*"].FindFirstChildWhichIsA = function(Self : VariableData, className : string, Recursive : boolean?)
            local Type = Typeof(className)
            Assert(Type, "string", "invalid argument #1 to 'FindFirstChildWhichIsA', string expected got " .. Type, true)

            local Kids = GetChildren(Self.self, Recursive);
            for _, Kid in next, Kids do
                if InstanceFuncs.IsA(SpiedToInstance[Kid].ClassName, className) then
                    return Kid;
                end
            end

            if Settings.roblox then
                return SafeValue(Self.var, nil);
            else
                return CreateInstance(Self.var)
            end
        end

        MethodsHooks["*"].FindFirstChildOfClass = function(Self : VariableData, className : string, Recursive : boolean?)
            local Type = Typeof(className)
            Assert(Type, "string", "invalid argument #1 to 'FindFirstChildOfClass', string expected got " .. Type, true)

            local Kids = GetChildren(Self.self, Recursive);
            for _, Kid in next, Kids do
                if SpiedToInstance[Kid].ClassName == className then
                    return Kid;
                end
            end

            if Settings.roblox then
                return SafeValue(Self.var, nil);
            else
                return CreateInstance(Self.var)
            end
        end

        MethodsHooks["*"].FindFirstAncestorWhichIsA = function(Self : VariableData, className : string, Recursive : boolean?)
            local Type = Typeof(className)
            Assert(Type, "string", "invalid argument #1 to 'FindFirstAncestorWhichIsA', string expected got " .. Type, true)

            local Inst = Self.self

            local function FindFirstAncestor(Kid)
                if not Kid then return end;
                if SpiedToInstance[Kid].ClassName == className then return Kid end;

                return FindFirstAncestor(GetParent(Kid));
            end

            local Ancestor = FindFirstAncestor(Inst)

            return Spy(Self.var, Ancestor)
        end

        MethodsHooks["*"].WaitForChild = function(Self : VariableData, childName : string, timeOut : number?)
            local Type = Typeof(childName)
            assert(Type == "string", "invalid argument #1 to 'WaitForChild', string expected got " .. Type)

            --[[if Settings.roblox then
                return SafeValue(Self.var, nil);
            else
                return CreateInstance(Self.var)
            end]]
            --> Maybe make this actually work? (Check it's children first, then return.)

            local Instance = CreateInstance(Self.var)
            SpiedToInstance[Instance].Name = childName
            return Instance
        end

        local game = CreateInstance("game", "DataModel")
        local workspace = CreateInstance("workspace", "Workspace")

        SpiedToInstance[game].Name = "UGC"
        
        SecureEnv.game = game
        SecureEnv.Game = game

        SecureEnv.workspace = workspace
        SecureEnv.Workspace = workspace

        SecureEnv.script = CreateInstance("script", "LocalScript")

        Children[game] = { workspace }

        do
            local Cam = Index("CurrentCamera", "workspace")
            local Camera = CreateInstance(Cam, "Camera")

            --local Terr = Index("Terrain", "workspace")
            --local Terrain = CreateInstance(Terr, "Terrain", true)

            SetParent(Camera, workspace)
            --SetParent(Terrain, workspace)
        end

        local function Clone(Self : VariableData, Recursive : boolean?)
            local Instance = SpiedToInstance[Self.self]
            local New = CreateInstance(Self.var, Instance.ClassName, false)
            local NewInstance = SpiedToInstance[New]

            for key, Property in next, Instance do
                NewInstance[key] = Property
            end
            if Recursive then
                local Kids = {}
                for _, Kid in next, Children[Self.self] or {} do
                    insert(Kids, Clone({
                        self = Kid,
                        var = Variables[Kid]
                    }, Recursive))
                end
                Children[New] = Kids
            end
            
            Information[New] = Information[Self.self] or {}
            Attributes[New] = Attributes[Self.self] or {}

            return New
        end

        MethodsHooks["*"].Clone = function(Self : VariableData)
            return Clone(Self, true);
        end

        MethodsHooks["*"].Destroy = function(Self : VariableData)
            local Meow = Self.self
            local Info = Information[Meow] or {}

            if Info.service then
                local ActualInstance = SpiedToInstance[Meow];
                error(`The Parent property of {ActualInstance.Name} is locked`)
            end
            
            Info.destroyed = true
            Information[Meow] = Info

            for i, List in next, Children do
                local Index = find(List, Meow)
                if Index then
                    table.remove(List, Index)
                end
            end
        end

        MethodsHooks.DataModel.GetService = function(Self : VariableData, name : string)
            checktype(name, "string", `invalid argument #1 to 'GetService'`)
            
            if name == "nil" then return SafeValue(Self.var, nil) end
            name = name:sub(1, (name:find("\0") or 0) - 1)

            local Service = Services[name]
            assert(Service, `'{name}' is not a valid Service name`)
            return CreateInstance(Self.var, name, true);
        end

        SecureEnv.UserSettings = function()
            return CreateInstance(AppendCall("UserSettings"), "UserSettings", true)
        end

        SecureEnv.Instance = table.freeze({
            new = Function(function(Class : string, Parent : Instance?)
                local Type = Typeof(Class)

                assert(Type == "string", "invalid argument #1 to 'new', string expected got " .. Type)

                local Var = AppendCall("Instance.new", Class, Parent)
                local Created = CreateInstance(Var, Class, false, true)

                if Parent then
                    local PType = Typeof(Parent)
                    assert(PType == "Instance", "invalid argument #2 to 'new', Instance expected got " .. PType)

                    local List = Children[Parent] or {}
                    insert(List, Created)
                    Children[Parent] = List
                end

                return Created;
            end, "Instance.new", true),
            fromExisting = Function(function(Old)
                local PType = Typeof(Old)
                assert(PType == "Instance", "invalid argument #1 to 'fromExisting', Instance expected got " .. PType)
                return Clone(Old, false);
            end, "Instance.fromExisting", true)
        })

        Variables[SecureEnv.Instance] = "Instance"

        SecureEnv.cloneref = function(original : Instance)
            local Var = AppendCall("cloneref", original)
            local Type = Typeof(original)
            Assert(Type, "Instance", `invalid argument #1 to 'clonref', Instance expected got {Type}`, true)

            return Clone({
                self = original,
                var = Var
            }, true);
        end

        SecureEnv.gethui = function()
            local x = AppendCall("gethui")
            return Spy(x, CreateInstance(x, "CoreGui", true))
        end
    end

    local function PleaseBeSafe(Pattern : string)
        if typeof(Pattern) == "string" then
            local x, y = isUnsafePattern(Pattern)
            if x then
                error(`[REGEX ERROR]: {y}`)
            end
        end
    end

    SecureEnv.string = HookLibrary("string", {
        find = Function(function(str, pat, ...)
            if str == true or pat == true then
                Ast.addStatement(AST, Ast.FunctionCall(Ast.Variable("LPH_CRASH"), {}));

                error("LPH_CRASH()")
            end

            local VarStr, VarPat = Variables[str], Variables[pat]
            local Out, Statement

            if VarStr or VarPat then
                Out, Statement = AppendCall("string.find", str, pat, ...)
                local vS, vP = GetInternalValue(str), GetInternalValue(pat)

                if (VarStr and Variables[vS] == VarStr) or (VarPat and Variables[vP] == VarPat) then
                    return TypeSpy(Out, "string")
                end
                str, pat = vS, vP;
            end

            PleaseBeSafe(pat)

            if Variables[str] or Variables[pat] then
                return Spy(Out)
            end

            local vals = pack(string.find(str, pat, ...));

            if VarStr or VarPat then
                return ToMultiVars(Statement, vals, true)
            end

            return unpack(vals)
        end, "string.find", true),
        match = function(str, pat, init : number?)
            print("match",str,pat)
            local VStr, VPat, VInit = GetInternalValue(str), GetInternalValue(pat), GetInternalValue(init)

            local VarStr, VarPat, VarInit = Variables[str], Variables[pat], Variables[init]

            if VarStr or VarPat or VarInit then
                local Values = pack(pcall(match, VStr, VPat, VInit))
                local Vars = {}
                local Spied = {};

                for i = 2, max(Values.n, 3) do
                    local Var = GetVar()
                    if Values[1] then
                        SetInternalValue(Var, Values[i])
                    end
                    insert(Vars, Ast.Variable(Var))
                    insert(Spied, Spy(Var))
                end

                Ast.addStatement(
                    AST,
                    Ast.Assign(
                        Vars,
                        {
                            Ast.FunctionCall(Ast.Index(Ast.Variable("string"), Ast.String("match")), TupleToAST(str, pat, init))
                        }
                    )
                )

                return unpack(Spied)
            end

            PleaseBeSafe(VPat)

            return match(VStr, VPat, VInit)
        end,
        gmatch = function(...)
            --print("gmatch",...)
            local args = {...}
            local DoLog, DontRun;
            for i, v in next, args do
                if Variables[v] then
                    DoLog = true
                    local val = GetInternalValue(v)
                    if Variables[val] then DontRun = true; break end
                    args[i] = val
                end
            end

            PleaseBeSafe(args[2])

            if DoLog or DontRun then
                local Var = AppendCall("string.gmatch", ...);
                local Success, Iterator = pcall(string.gmatch, unpack(args)) --> Always returns
                if not Success or DontRun then
                    return Spy(Var)
                end

                return Function(function(...)
                    local Values = pack(Iterator(...))

                    local Vars = {}
                    local Spied = {}
                    for i = 1, max(Values.n, 1) do
                        local Var = GetVar()

                        insert(Vars, Ast.Variable(Var))
                        insert(Spied, Spy(Var, Values[i]));
                    end

                    Ast.addStatement(AST, Ast.Assign(
                        Vars, { Ast.FunctionCall(Ast.Variable(Var), TupleToAST(...)) }
                    ))
                    return unpack(Spied);
                end, Var, true)
            end
            return string.gmatch(unpack(args))
        end,
        pack = string.pack, --> do not wrap this, as it ruins performance.
        unpack = string.unpack,
        len = function(x)
            checktype(x, "string", "invalid argument #1 to 'len'", true)

            return SecureEnv[CallId .. "CHECKLEN"](x)
        end,
        rep = function(x, y)
            if typeof(y) == "number" and y >= 1e6 then
                AppendCall("string.rep", x, y)
                return x
            end
            return rep(x, y);
        end,
        --byte = string.byte
    })

    SecureEnv.table = HookLibrary("table", {
        create = table.create, --> optimize
        move = table.move
    })

    local LastRandom, RandomCombinations = nil, {};
    SecureEnv.math = HookLibrary("math", {
        random = function(min, max)
            if not min and not max then return math.random() end

            local _min, _max = GetInternalValue(min), GetInternalValue(max);
            local Result, Combinations = nil, RandomCombinations[min];
            if Variables[_min] or Variables[_max] then
                return TypeSpy((AppendCall("math.random", min, max)), "number")
            end

            if (max == 1e4 and min == 0) or (min == 3 and max == 65) or (max == 255) or (min == 1) then return math.random(min, max) end

            if _min and _max then
                Result = math.random(_min, _max);
            elseif _min then
                Result = math.random(_min)
            else
                error(`invalid argument #1 to 'random' (number expected, got nil)`)
            end

            if Combinations then
                if Combinations[max] then
                    return Result
                else
                    Combinations[max] = true
                end
            elseif min and max then
                RandomCombinations[min] = {
                    [max] = true
                }
            end

            if LastRandom and LastRandom == max + 1 then
                LastRandom = max
                return Result
            else
                if max == 255 or min == 1 then return Result end

                LastRandom = max
            end

            local Var = AppendCall("math.random", min, max);
            return SafeValue(Var, Result, { is_random = true });
        end
    })
    SecureEnv.os = HookLibrary("os", {
        clock = function()
            local Var = AppendCall("os.clock")
            return Spy(Var, os.clock() + SharedGlobals.Delay)
        end,
        time = function(...)
            local Var = AppendCall("os.time", ...)
            return Spy(Var, os.time(...) + SharedGlobals.Delay)
        end,
        date = function(meow)
            local Var = AppendCall("os.date", meow)
            local Date = os.date(meow, os.time() + SharedGlobals.Delay)
            return SafeValue(Var, Date);
        end
    })
    SecureEnv.bit32 = HookLibrary("bit32", {
        --[[bxor = function(... : number) --> Speed up safewrap a bit
            local AllowedToMeow, New = false, {...};
            for i, v in next, New do
                if Variables[v] then
                    local Value = GetInternalValue(v)
                    if Variables[Value] then
                        break
                    else
                        New[i] = Value;
                    end
                end
            end

            return bit32.bxor(unpack(New));f
        end]]
    })
    SecureEnv.bit = SecureEnv.bit32
    SecureEnv.coroutine = HookLibrary("coroutine", {
        yield = Function(function(...)
            if coroutine.running() == MAIN_THREAD then
                print("No i will not yield",Nest)
                return;
            end
            print("Yield")
            Luraph = true

            return coroutine.yield(...)
        end, "coroutine.yield", true),
        create = coroutine.create
    })

    --> Roblox Libraries

    SecureEnv.utf8 = HookLibrary("utf8")
    SecureEnv.buffer = HookLibrary("buffer")
    SecureEnv.vector = HookLibrary("vector")

    do
        local function Or(a, b)
            if a == nil then return b end
            return a
        end
        roblox.Random = RandomLib
        roblox.DateTime = DateTime
        roblox.TweenInfo = {
            new = function(time : number, easingStyle : EnumItem, easingDirection : EnumItem, repeatCount : number, reverses : boolean, delayTime : number)
                time = Or(time, 1)
                easingStyle = Or(easingStyle, Enum.EasingStyle.Quad)
                easingDirection = Or(easingDirection, Enum.EasingDirection.Out)
                reverses = Or(reverses, false)
                repeatCount = Or(repeatCount, 0)
                delayTime = Or(delayTime, 0)

                if time then
                    assert(Typeof(time) == "number", "TweenInfo.new first argument expects a number for time.")
                end

                if easingStyle then
                    assert(Typeof(easingStyle) == "EnumItem", "TweenInfo.new second argument expects Enum.EasingStyle input")
                    assert(tostring(easingStyle):find("Enum.EasingStyle"), "TweenInfo.new second argument expects Enum.EasingStyle input")
                end

                if easingDirection then
                    assert(Typeof(easingDirection) == "EnumItem", "TweenInfo.new third argument expects Enum.EasingDirection input")
                    assert(tostring(easingDirection):find("Enum.EasingDirection"), "TweenInfo.new third argument expects Enum.EasingDirection input")
                end

                if repeatCount then
                    assert(Typeof(repeatCount) == "number", "TweenInfo.new fourth arg should be a number for RepeatCount.")
                end

                if reverses then
                    assert(Typeof(reverses) == "boolean", "TweenInfo.new fifth arg should be a boolean for Reverses.")
                end

                if delayTime then
                    assert(Typeof(delayTime) == "number", "TweenInfo.new sixth arg should be a number for DelayTime.")
                end

                return {
                    EasingDirection = easingDirection,
                    Time = time,
                    DelayTime = delayTime,
                    RepeatCount = repeatCount,
                    EasingStyle = easingStyle,
                    Reverses = reverses
                }
            end
        }

        local Libraries = {
            "Vector2", "Vector3", "CFrame", "BrickColor", "UDim", "UDim2", "Font", "Enum", "Color3", "Ray",
            "NumberSequence", "NumberRange", "NumberSequenceKeypoint", "ColorSequence", "ColorSequenceKeypoint",
            "RaycastParams", "PhysicalProperties", "Random", "DateTime", --> doesn't exist in roblox[RaycastParams] but it works i guess?
            "Axes", "Content", "Faces", "Region3", "Region3int16", "Rect", "TweenInfo"
        }

        local function ShallowCopy(thing : any)
            if Variables[thing] then return thing end

            local Type = typeof(thing)
            if Type ~= "table" then return thing end

            local new = {}
            for i, v in next, thing do
                new[ShallowCopy(i)] = ShallowCopy(v)
            end
            return new
        end

        for _, LibraryName in next, Libraries do
            local Library = roblox[LibraryName]
            local LibVar = Ast.Variable(LibraryName)

            SecureEnv[LibraryName] = (GetMetatable(LibraryName, {
                __index = if Library then function(Self, Key)
                    local Indexed = Index(Key, LibraryName)
                    local Var = DefineVar(
                        Ast.Index(LibVar, ToAST(Key)),
                        false,
                        true
                    );

                    if LibraryName == "Enum" then
                        assert(pcall(function()return Library[Key]end), `{Key} is not a valid member of "Enum"`)
                    end

                    local Callback = Library[Key]
                    if Callback then
                        if typeof(Callback) == "function" then
                            local Func = Function(function(...)
                                local function Wrap(x)
                                    if Variables[x] or typeof(x) ~= "table" then 
                                        return GetInternalValue(x)
                                    end

                                    for i, v in next, x do
                                        x[i] = Wrap(v)
                                    end
    
                                    return x
                                end

                                local OldArgs = ShallowCopy({...})
                                local Args = Wrap({...})

                                local Values = pack(pcall(Callback, unpack(Args)))
                                local Success = Values[1]
                                local Vars = {}
                                local Spied = {}

                                for i = 2, Values.n do
                                    local Var = GetVar()

                                    insert(Spied, Spy(Var, if Success or i ~= 2 then Values[i] else nil))
                                    insert(Vars, Ast.Variable(Var))
                                end

                                Ast.addStatement(
                                    AST,
                                    Ast.Assign(
                                        Vars,
                                        {
                                            Ast.FunctionCall(Ast.Variable(Var), TupleToAST(unpack(OldArgs)))
                                        }
                                    )
                                )

                                if not Success then
                                    warn(Values[2])
                                    if Settings.roblox then
                                        error(tostring(Values[2]))
                                    end
                                end

                                return unpack(Spied)
                            end, Indexed, true) --> use Indexed not Var to cache better
                            --rawset(Self, Key, Func)
                            return Func
                        end

                        local Spied = Spy(Var, Callback);
                        --rawset(Self, Key, Spied)
                        return Spied
                    end

                    local Spied = Spy(Var);
                    --rawset(Self, Key, Spied)
                    return Spied
                end else function(Self, Key)
                    local Var = DefineVar(
                        Ast.Index(LibVar, ToAST(Key)),
                        false,
                        true
                    );

                    return Spy(Var);
                end,
                __call = function(Self, ...)
                    AppendCall(LibraryName, ...)
                    error(`attempt to call a {Typeof(Self)} value`)
                end
            }))
        end

        Types[SecureEnv.Enum] = "Enums"
    end

    SecureEnv.getmetatable = function(table)
        local Var = GetContext(table);
        if Var then
            local Var = AppendCall("getmetatable", table);
            local Type = Typeof(table)

            if Type == "table" then
                return nil;
            elseif Type == "string" then
                --> add later
            elseif Type == "number" or Type == "nil" or Type == "function" then
                return nil;
            else
                return Spy(Var, "The metatable is locked")
            end
        end

        return getmetatable(table)
    end

    SecureEnv.setmetatable = function(table, mt : any)
        if Variables[table] then
            local a = {table, mt}
            table = GetInternalValue(table)

            local TypeTbl, TypeMt = Typeof(table), Typeof(mt)
            assert(TypeTbl == "table", `invalid argument #1 to 'setmetatable' (table expected, got {TypeTbl})`)
            assert(TypeMt == "table" or TypeMt == "nil", `invalid argument #2 to 'setmetatable' (nil or table expected, got {TypeMt})`)
            
            AppendCall("setmetatable", unpack(a))

            assert(not isfrozen(table), "attempt to modify a readonly table")

            return;
        end
        return setmetatable(table, mt)
    end

    SecureEnv.tonumber = function(num : string, base : number?)
        local VarNum, VarBase = Variables[num], Variables[base]

        if VarNum or VarBase then
            local VNum, VBase = GetInternalValue(num), if base then GetInternalValue(base) else 10;

            if typeof(VNum) == "number" then
                if Variables[VBase] then VBase = 10 end
            end

            local Var = AppendCall("tonumber", num, base);
            return Spy(Var, tonumber(VNum, VBase))
        end

        return tonumber(num, base);
    end

    SecureEnv.tostring = function(value : any)
        local VarVal = Variables[value]
        if VarVal then
            if typeof(value) == "function" and CClosures[value] then
                return tostring(value);
            end

            local Info = Information[value]
            local Value = GetInternalValue(value)
            local Type = Typeof(Value)

            local Var = AppendCall("tostring", value)

            if Type == "function" then
                return Spy(Var, tostring(Value), Info);
            elseif Type == "Enum" then
                return SafeValue(Var, tostring(Value):split(".")[2], Info)
            elseif Type == "Instance" then
                return SafeValue(Var, SpiedToInstance[value].Name, Info)
            end

            if not Variables[Value] then
                return SafeValue(Var, tostring(Value), Info)
            end

            return TypeSpy(Var, "string", nil, Info);
        end
        return tostring(value);
    end

    SecureEnv.error = function(msg : string, lvl : number)
        if lvl ~= 0 then
            Ast.addStatement(AST, Ast.Comment(Ast.RawText("`error` here was used by the script itself.")))
            Ast.addStatement(AST, Ast.FunctionCall(Ast.Variable("error"), TupleToAST(msg, lvl)))
        end

        error(msg, lvl)
    end

    local SpoofedEnvs = {}

    SecureEnv.getfenv = function(Level)
        local Type = Typeof(Level)
        local Spoofed = SpoofedEnvs[Level]
        --if Spoofed then return SafeValue(AppendCall("getfenv", Level), Spoofed) end
        if Spoofed then return Spoofed end

        if Type == "string" then
            Level = assert(tonumber(Level), `invalid argument #1 to 'getfenv' (number expected, got {Type})`)
        end
        if Type == "number" then
            -- Is it a float?
            if Level > Nest + 2 or Level < 0 then
                error(`invalid argument #1 to 'getfenv' (invalid level)`)
            end
            return Env
        elseif Type == "function" or Type == "nil" then
            return Env
        end

        error(`invalid argument #1 to 'getfenv' (number expected, got {Type})`)
    end

    SecureEnv.setfenv = function(a, b)
        local Type = Typeof(a)

        assert(Typeof(b) == "table", "missing argument #2 to 'setfenv' (table expected)")
        assert(Type == "number" or Type == "function", `invalid argument #1 to 'setfenv' (number expected, got {Type})`)

        if Variables[b] == EnvName then return a end

        if getmetatable(b) then
            SpoofedEnvs[a] = b;
            return b
        end

        local Var = AppendCall("setfenv", a, b)

        if iscclosure(a) then
            error("'setfenv' cannot change environment of given object")
        end

        SpoofedEnvs[a] = b;

        local meow = IsInPcall or a--if typeof(a) == "number" then GetInfo(a).func else a
        
        if getmetatable(b) ~= nil then
            return meow
        end
        --return setfenv(meow, b); --! MAY BE INSECURE
    end

    SecureEnv.collectgarbage = function(t)
        assert(t, "missing argument #1 to 'collectgarbage' (string expected)")
        assert(t == "count", "collectgarbage must be called with 'count'; use gcinfo() instead")

        return collectgarbage("count")
    end

    SecureEnv.tick = function()
        return SafeValue(AppendCall("tick"), tick())
    end

    SecureEnv.require = function(path : any)
        local Type = Typeof(path)
        local Var = AppendCall("require", path)

        local lua = Settings.lua

        if Type ~= "string" and lua then return Spy(Var) end

        if Type == "string" then
            local Start = path:sub(1, 2)
            local IsAt = Start:sub(1, 1) == "@"

            local Unable = `Unable to require module from given path '{path}'`

            if not (Start == "./" or Start == ".." or IsAt) then
                if lua then return Spy(Var) end
                error(`Path must begin with './', '../', or '@': received '{path}'`)
            elseif IsAt then
                local Alias = path:match("@([^/]+)")
                local Thing = path:match("@.-/(%w+)")

                if Alias == "game" then -- add support for @self
                    if path == "@game" then --> thats the whole thing
                        error(Unable)
                    else
                        --> add some dynamic instance shit
                        assert(Services[Thing], `'{Thing}' is not a valid Service name`)
                        error(Unable) --> make it actually work
                    end
                elseif Alias == "self" then
                    error(Unable)
                end
                    
                error(`Path contains unsupported alias '@{Alias}`)
            end
                
            error(Unable)
        elseif Type ~= "number" and (Type ~= "Instance" --[[ check if its not a ModuleScript]]) then
            local Info = Information[path] or {}
            if not Info.indexed_instance then
                Assert(Type, "Instance", `Attempted to call require with invalid argument(s).`, true)
            end
        end

        if Type == "Instance" and (Information[path] or {}).was_created then
            error(`Module code did not return exactly one value`)
        end

        return Spy(Var);
    end

    -- File System (Session Only)
    local files = {}
    local FileFuncs = {}

    local function startswith(a, b) return sub(a, 1, #b) == b end
    local function endswith(hello, lo) return sub(hello, #hello - #lo + 1, #hello) == lo end

    FileFuncs.writefile = function(path, content)
        local Path = split(path, '/')
        local CurrentPath = {}

        for i = 1, #Path do
            local a = Path[i]
            CurrentPath[i] = a
            if not files[a] and i ~= #Path then
                files[concat(CurrentPath, '/')] = {}
                files[concat(CurrentPath, '/') .. '/'] = files[concat(CurrentPath, '/')]
            elseif i == #Path then
                files[concat(CurrentPath, '/')] = tostring(content)
            end
        end
    end
    FileFuncs.makefolder = function(path)
        files[path] = {}
        files[path .. '/'] = files[path]
    end
    FileFuncs.isfolder = function(path) return type(files[path]) == 'table' end
    FileFuncs.isfile = function(path) return type(files[path]) == 'string' end
    FileFuncs.readfile = function(path)
        local content = files[path]
        assert(content, `invalid argument #1 to 'readfile', file does not exist!`)
        return content
    end
    FileFuncs.appendfile = function(path, text2)
        FileFuncs.writefile(path, FileFuncs.readfile(path) .. text2)
    end
    FileFuncs.loadfile = function(path, var)
        if not FileFuncs.isfile(path) then error('File \'' .. tostring(path) .. '\' does not exist.', 2) return '' end

        local content = FileFuncs.readfile(path)

        local s, func = pcall(function()
            return loadstring(content)
        end)

        if not s then
            return nil, tostring(func):match("[^\n]+")
        end

        return Function(function(...)
            AppendCall(var, ...)

            return fenv.setfenv(func, Env)(...)
        end, var), s
    end
    FileFuncs.dofile = FileFuncs.loadfile
    FileFuncs.delfolder = function(path)
        local f = files[path]
        if type(f) == 'table' then files[path] = nil end
    end
    FileFuncs.delfile = function(path)
        local f = files[path]
        if type(f) == 'string' then files[path] = nil end
    end
    FileFuncs.listfiles = function(path)
        if not path or path == '' then
            local Files = {}
            for i, v in pairs(files) do
                if #i:split('/') == 1 then insert(Files, i) end
            end
            return Files
        end
        if type(files[path]) ~= 'table' then return error(path .. ' is not a folder.') end
        local Files = {}
        for i in pairs(files) do
            if startswith(i, path .. '/') and not endswith(i, '/') and i ~= path and #i:split('/') == (#path:split('/') + 1) then insert(Files, i) end
        end
        return Files
    end

    for FuncName, Func in next, FileFuncs do
        SecureEnv[FuncName] = function(...)
            local Returned = pack(pcall(Func, InternalIfy(...)));
            local Success = Returned[1];

            local _, Stat = DefineVar(Ast.FunctionCall(Ast.Variable(FuncName), TupleToAST(...)))

            if not Success then
                Comment(tostring(Returned[2]))
                if Settings.roblox then
                    error(Returned[2])
                end
            end

            return ToMultiVars(Stat, {unpack(Returned, 2)});
        end
    end

    SecureEnv.type = TypeFunction("type")
    SecureEnv.typeof = TypeFunction("typeof")

    local PcallIgnore = {
        getfenv = true, rawget = true, setfenv = true, ["table.concat"] = true
    }

    SecureEnv.pcall = function(func, ...)
        local Var = Variables[func]
        if Var then
            local Logged, Values = Explore(func, {
                params = {...},
                bypass_ignore = true,
                as_pcall = true
            })

            local Len = #Logged.data.statements

            local Meow;
            for _, v in next, Values do
                if Variables[v] then
                    Meow = true
                    break
                end
            end

            if not Values[1] then
                local Error = Values[2]
                local Type = typeof(Error)

                if Type == "error" then
                    Error = tostring(Error)
                end

                if Type == "error" or Type == "string" then
                    Values[2] = Error:match(":%d+: ([^\n]+)")
                end
            end

            if Values[2] == "LPH_CRASH()" then
                error("LPH_CRASH()", 2)
            end

            if not PcallIgnore[Var] or Len > 1 or Meow then
                local Ctx = Ast.Variable(Var)

                local Vars = {}
                local Spied = {}

                for i = 1, Values.n do
                    local Var = GetVar()

                    insert(Vars, Ast.Variable(Var))
                    insert(Spied, SafeValue(Var, Values[i]))
                end

                Stat = Ast.addStatement(
                    AST,
                    Ast.Assign(Vars, {
                        Ast.FunctionCall(
                            Ast.Variable("pcall"),
                            {
                                Ctx,
                                unpack(TupleToAST(...))
                            }
                        )
                    })
                )

                return unpack(Spied)
            end
            return unpack(Values)
        end

        local Type = typeof(func)
        if Type ~= "function" then --! Without this, stuff break i think
            return false, `[string "{TraceId}"]:1: attempt to call a {Type} value"`
        end

        local Logged, ReturnValues = Explore(func, {
            params = {...},
            bypass_ignore = true,
            as_pcall = true
        })

        if not ReturnValues[1] then
            local Type = typeof(ReturnValues[2])
            if Type == "error" or Type == "string" then
                local Error = tostring(ReturnValues[2])
                if Error == "too many operations" or Error == "too many iterations" then
                    print("Yes",Error)
                    error(Error);
                end

                local HasArithmetic = Error:find("attempt to perform arithmetic", 0, true)
                local RandomString = Error:find("attempt to index nil with 'randomString'", 0, true) --> xhider thing..

                if not HasArithmetic and not RandomString then
                    ReturnValues[2] = HideErrors(Error):match("[^\n]+")
                else
                    local Line = (HasArithmetic and Error:find("attempt to perform arithmetic (unm)", 0, true)) and "1" or "%2" --> wearedevs garbage
                    ReturnValues[2] = Error:gsub(UserRegex, `[string "{TraceId}"]:{Line}`)
                end

                ReturnValues[2] = ReturnValues[2]:gsub("luau%.load%(%.%.%.%)", TraceId)
                if startswith(ReturnValues[2], "terrain:") then --> stuff like 'Unsupported terrain material'
                    ReturnValues[2] = ReturnValues[2]:match("terrain:%d*:%s*(.+)")
                end
            end
        end

        local Statements = Logged.data.statements
        local Len = #Statements

        if Len ~= 0 and (Len ~= 1 or Statements[Len].kind ~= "return") and ReturnValues.n <= 10 then
            local Last = Statements[Len]
            if Last and Last.kind == "assign" and Last.data.values[1].kind == "string" then
                --> pcall(function() local str ="hello" end)
                Ast.addStatement(AST, Last)
                return unpack(ReturnValues)
            end

            local Vars = {}
            local Spied = {}
            local InternalStuff = {}
            local ToReturn = {}

            local TypeA = typeof(ReturnValues[1])
            local AreAllNumbers = TypeA == "number" or (TypeA == "boolean" and ReturnValues.n >= 3);

            local Names = { "success" }

            for i = 1, ReturnValues.n do
                local Var = Names[i] and GetCount(Names[i]) or GetVar()
                local Value = ReturnValues[i];

                if i > 1 and typeof(Value) ~= "number" then AreAllNumbers = false end

                insert(Vars, Ast.Variable(Var))
                insert(Spied, SafeValue(Var, Value, Information[Value]))
                insert(ToReturn, ToAST(ReturnValues[i]))
                if Settings.debug then insert(InternalStuff, Value) end
            end

            if AreAllNumbers then
                return unpack(ReturnValues)
            end

            if (ReturnValues[1] and ReturnValues.n > 1 or ReturnValues.n > 2) and Statements[Len].kind ~= "return" then
                Ast.addStatement(Logged, Ast.Return(ToReturn))
            end

            Ast.addStatement(
                AST,
                Ast.Assign(
                    Vars,
                    {
                        Ast.FunctionCall(
                            Ast.Variable("pcall"),
                            {
                                Ast.Function(GetParams(func), Logged)
                            }
                        )
                    }
                )
            )

            if #InternalStuff > 0 then print(InternalStuff) end

            return unpack(Spied)
        end

        return unpack(ReturnValues)
    end

    SecureEnv.ypcall = function(...)
        return SecureEnv.pcall(...);
    end

    SecureEnv.xpcall = function(func : func, onFail : func)
        AppendCall("xpcall", func, onFail)

        local Type = Typeof(onFail)

        if Type == "nil" then
            error(`missing argument #2 to 'xpcall' (function expected)`)
        elseif Type ~= "function" then
            error(`missing argument #2 to 'xpcall' (function expected, got {Type})`)
        end

        return xpcall(func, function(...)
            return onFail(HideErrors(tostring((...))), select(2, ...))
        end)
    end

    SecureEnv.rawget = function(tbl, k)
        local Var = Variables[tbl]
        local Type = Typeof(tbl)
        assert(Type == 'table', `invalid argument #1 to 'rawget' (table expected, got {Type})`)

        if Var then
            if Var == EnvName or Var == "_G" then return (EnvValues[k] or {})[1] end;
            if true then return rawget(GetInternalValue(tbl), k) end
            print("meow?",tbl,k)
            local Var = AppendCall("rawget", tbl, k)

            --return tbl[k]
            --return SafeValue(Var, rawget(GetInternalValue(tbl), k));
            local value = rawget(GetInternalValue(tbl), k)
            return SafeValue(Var, value);
        end
        
        return rawget(tbl, k)
    end

    SecureEnv.rawlen = function(tbl)
        if GetContext(tbl) then
            local Var = AppendCall("rawlen", tbl)
            return SafeValue(Var, 0)
        end

        local Type = Typeof(tbl)
        assert(Type == "table", `invalid argument #1 to 'rawlen', table expected got {Type}`)

        return rawlen(tbl);
    end

    local WrappedUnpack = SafeWrap(unpack, "unpack")
    
    SecureEnv.unpack = function(tab : { any }, i : number?, j : number?)
        if typeof(tab) ~= "table" then return tab end
        if Variables[i] or Variables[j] then
            return WrappedUnpack(tab, i, j)
        end

        return unpack(tab, i, j)
    end

    function GetInfo(i : number | thread) : { [any]: any }?
        local Type = typeof(i)
        if Type ~= "function" and Type ~= "thread" and Type ~= "number" then return {}, true end;
        local Returned = {}

        local s : string, l : number, n : string, params : number, vararg : boolean, f = debuginfo(i, "slnaf");

        Returned.func = i

        local RealC = CClosures[i] or s == "[C]"
        local True = TrueEnv[Variables[i]] -- TrueEnv[getmetatable]

        if True then RealC = RealC or iscclosure(True) end

        if RealC then -- A C Closure
            Returned.what = "C"
            Returned.namewhat = ""
            Returned.source = "=[C]"
            Returned.short_src = "[C]"
            Returned.line, Returned.linedefined, Returned.currentline, Returned.lastlinedefined =
                RealC and -1 or 1, RealC and -1 or 1, RealC and -1 or 1, RealC and -1 or 1
            Returned.numparams, Returned.is_vararg = 0, 1
            Returned.nups = 1;

            local Var = Variables[i] or n
            local name = split(Var, ".")
            name = name[#name]
            Returned.name = name
        else
            if typeof(i) == "number" then
                local CallStackNumbers = {}
                local Traceback = split(debug.traceback(), "\n")
                local String = `[string "{TraceId}"]`--"[string \"luau.load(...)\"]"
                local Len = #String

                for x = 1, #Traceback do
                    local Line = Traceback[x]

                    if Line:sub(1, Len) == String then
                        insert(CallStackNumbers, x)
                    end
                end

                table.sort(CallStackNumbers, function(a, b)
                    return a > b
                end)

                for x, level in next, CallStackNumbers do
                    if x == i then
                        s, l, n, params, vararg, f = debuginfo(level, "slnaf");
                        Returned.line, Returned.linedefined, Returned.currentline = l, l, l;
                        Returned.name = n
                        Returned.is_vararg, Returned.numparams = vararg, params
                        Returned.func = f

                        if n == "" and s == String and vararg then
                            s = TraceId
                        end

                        Returned.source, Returned.short_src = s, s;

                        return Returned;
                    end
                end

                if true then return nil end

                -- Main Env
                Returned.source, Returned.short_src = TraceId, TraceId
                Returned.name = ""
                Returned.func = debuginfo(2, "f")
                Returned.is_vararg, Returned.numparams = true, 0
                Returned.line, Returned.linedefined, Returned.currentline = 1, 1, 1;

                return Returned
            else
                Returned.what = "Lua";
                Returned.line, Returned.linedefined, Returned.currentline = l, l, l;
                Returned.source, Returned.short_src = TraceId, TraceId:sub(1, -2);
                Returned.nups = 0; --> You can do this when getupvalues is implemented
                Returned.is_vararg, Returned.numparams = vararg and 1 or 0, params;
            end
        end

        return Returned
    end

    local function Getupvalues(Func : func | number, Name : string)
        if typeof(Func) == "function" and iscclosure(Func) then
            --error(`{Name} cannot be called on a C closure!`)
        end
    end

    local Debug = GetMetatable("debug", {
        __index = {
            getinfo = Function(function(t, i)
                t, i = GetInternalValue(t), GetInternalValue(i);
                local Type = Typeof(t)
                assert(Type == "function" or Type == "number", "invalid argument #1 to 'getinfo' (function or level expected)")

                if t == 0 then t = Function(function()end,"debug.getinfo",true) end
                if not GetContext(t) then
                    local Info, DoSpy = GetInfo(t)
                    if not DoSpy then return Info end
                    return Spy(AppendCall("debug.getinfo", t, i), Info)
                end

                local Var = AppendCall("debug.getinfo", unpack({t, i}))
                local Info, DoSpy = GetInfo(t)

                if not DoSpy then SetInternalValue(Var, Info) end

                return Spy(Var)
            end, "debug.getinfo", true),
            info = Function(function(...)
                local Raw = pack(...)

                --> Roblox debug.info has a 3-arg thread form: debug.info(thread, level, options).
                --> In that form arg#2 is the numeric level and the options string is arg#3, so the
                --> plain (t, i) shape wrongly rejected the level as "string expected got number".
                local ThreadForm = Raw.n >= 3 and Typeof(Raw[1]) == "thread"
                local t = GetInternalValue(if ThreadForm then Raw[2] else Raw[1]);
                local i = GetInternalValue(if ThreadForm then Raw[3] else Raw[2]);

                assert(typeof(i) == "string", "invalid argument #" .. (if ThreadForm then 3 else 2) .. " to 'info', string expected got " .. typeof(i))

                if t == 0 then t = Function(function()end,"debug.getinfo",true) end

                local Vars = split(string.lower(i), "")
                local Names = { n = "name", a = "params", l = "line", s = "source" }
                local DefinedVars = {}
                local Vararg;

                for _, option in next, Vars do
                    insert(DefinedVars, Ast.Variable(GetCount(Names[option] or option)))

                    if option == "a" then
                        Vararg = GetCount("vararg")
                        insert(DefinedVars, Ast.Variable(Vararg))
                    end
                end

                Ast.addStatement(
                    AST,
                    Ast.Assign(
                        DefinedVars,
                        {Ast.FunctionCall(Ast.Variable("debug.info"), TupleToAST(unpack(Raw, 1, Raw.n)))},
                        false
                    )
                )

                local ToReturn = {}
                local Values = {}

                local Info = GetInfo(t) or {};
                local Skip;

                for x, v in next, Vars do
                    local value;
                    local var = DefinedVars[x + (if Skip then 1 else 0)].data.name
                    Skip = false

                    if v == "s" then
                        value = Info.what == "C" and "[C]" or Info.source
                    elseif v == "n" then
                        value = Info.name or ""
                    elseif v == "a" then
                        value = Info.numparams
                        insert(Values, value)
                        insert(ToReturn, SafeValue(var, value))

                        value = Info.is_vararg == 1

                        insert(Values, value)
                        insert(ToReturn, SafeValue(Vararg, value))
                        Skip = true
                        continue
                    elseif v == "f" then
                        value = Info.func
                        if value then Variables[value] = var end
                    elseif v == "l" then
                        value = Info.line
                    else
                        error("invalid argument #2 to 'info' (invalid option)")
                    end

                    insert(Values, value)
                    insert(ToReturn, SafeValue(var, value))
                end

                OpCountCheck()
            
                return unpack(ToReturn)
            end, "debug.info", true),
            dumpcodesize = Spy("debug.dumpcodesize"),
            traceback = Function(function(a)
                assert(not a or Typeof(a) == "string", "invalid argument #1 to 'traceback' (string expected got " .. Typeof(a) .. ")")

                local trace = debug.traceback(a)
                local lines = split(trace, "\n")
                local out = {}

                for _, v in next, lines do
                    if HideErrors(v) == v then
                        insert(out, v)
                    end
                end --> covering my traces:)

                local value = concat(out, "\n")
                value = gsub(value, ":%d+", ":1"):gsub("%[string [\"'](.-)[\"']%]", "%1")

                local Var = AppendCall("debug.traceback", a)
                Comment(value)

                return SafeValue(Var, value)
            end, "debug.traceback", true),
            getmemorycategory = Function(function()
                return SafeValue(AppendCall("debug.getmemorycategory"), MemoryCategory)
            end, "debug.getmemorycategory", true),
            setmemorycategory = Function(function(Category : string)
                assert(Typeof(Category) == "string", "invalid argument #1 to 'setmemorycategory', string expected got " .. Typeof(Category))
                MemoryCategory = Category
                return SafeValue(AppendCall("debug.getmemorycategory"), MemoryCategory)
            end, "debug.setmemorycategory", true),
            resetmemorycategory = Function(function()
                MemoryCategory = TraceId
            end, "debug.resetmemorycategory", true),
            getlocal = Function(function(func : func, idx : number)
                local Meower = AppendCall("debug.getlocal", func, idx)

                checktype(func, "function", `invalid argument #1 to 'getlocal'`)
                checktype(idx, "number", `invalid argument #2 to 'getlocal'`)

                if iscclosure(func) then
                    return SafeValue(Meower, nil);
                end

                return Spy(Meower, nil, { is_propery = true })
            end, "debug.getlocal", true),
            --[[getupvalues = Function(function(func : func | number)
                AppendCall("debug.getupvalues", func)

                local Type = Typeof(func)
                assert(Type == "function" or Type == "number", `invalid argument #1 to 'getupvalues', function or number expected got {Type}`)
                return Getupvalues(func, "getupvalues")
            end, "debug.getupvalues", true),]]
            getupvalue = Function(function(func : func | number, idx : number)
                local Upvalue = AppendCall("debug.getupvalue", func)

                local Type = Typeof(func)
                assert(Type == "function" or Type == "number", `invalid argument #1 to 'getupvalue', function or number expected got {Type}`)
                
                if iscclosure(func) then error(`'getupvalue' cannot be called on a CClosure!`) end
                if idx <= 0 then error(`invalid argument #2 to 'getupvalue' (invalid index!)`) end

                return Spy(Upvalue, nil, { is_propery = true })--(Getupvalues(func, "getupvalue") or {})[1]
            end, "debug.getupvalue", true)
        }
    })

    SecureEnv.debug = Debug
    SecureEnv.assert = function(condition, message)
        local _c, _m = condition, message

        condition, message = GetInternalValue(condition), GetInternalValue(message)

        if condition ~= _c or _m ~= message then
            AppendCall("assert", _c, _m)
        end

        return assert(condition, message);
    end

    SecureEnv.newcclosure = function(Closure : func)
        local type = Typeof(Closure)
        assert(type == "function", "invalid argument #1 to 'newcclosure', function expected got " .. type)

        local Var = AppendCall("newcclosure", Closure)

        return Function(function(...) return Closure(...) end, Var, true);
    end

    SecureEnv.hookfunction = HookFunction("hookfunction")
    SecureEnv.replaceclosure = HookFunction("replaceclosure")

    SecureEnv.restorefunction = function(f)
        AppendCall("restorefunction", f)

        local Type = Typeof(f)
        assert(Type == "function", `invalid argument #1 to 'restorefunction', function expected got {Type}`)
        Restore(GetInternalValue(f))
    end

    SecureEnv.isfunctionhooked = function(f)
        local Var = AppendCall("isfunctionhooked", f)
        return SafeValue(Var, FunctionHooks[f] ~= nil)
    end

    SecureEnv.is_function_hooked = function(f)
        local Var = AppendCall("is_function_hooked", f)
        return SafeValue(Var, IsHooked(f))
    end

    SecureEnv.ishooked = function(f)
        local Var = AppendCall("ishooked", f)
        return SafeValue(Var, IsHooked(f))
    end

    SecureEnv._VERSION = "Luau"

    --! ENVIRONMENT END

    for _, Key in next, SayPlease do
        SecureEnv[Key] = SafeWrap(TrueEnv[Key], Key)
    end
    
    for _, Key in next, FineUgh do
        SecureEnv[Key] = TrueEnv[Key]
    end

    for Key, Val in next, SecureEnv do
        if typeof(Val) == "function" and not Types[Val] then
            SecureEnv[Key] = Function(Val, Key, true)
        end
    end

    local IterFuncs = {
        next = true, ipairs = true, pairs = true
    }

    local Iterator;
    local Iterators = {}

    local PristineIdxAmount = 0;
    local Envs = {}

    local function CreateEnv(path : string) : { [string]: any }
        local env = Envs[path]
        if env then return env end;
        
        if path == "_G" or path == "shared" then
            --> do it the solara way
            local Meower = CreateEnv("getgenv()")
            local EnvVar = Ast.Variable(path);

            return GetMetatable(path, {
                __index = function(_, Key)
                    if Key == "globalEnv" then return Meower end

                    local Var = DefineVar(
                        Ast.Index(EnvVar, ToAST(Key)),
                        false,
                        true
                    )

                    local ExecType = IsExecutor(Key)

                    if (SpyExecOnly and (typeof(Key) == "string" and not ExecType)) or TrueEnv[Key] or Nil[Key] or ForceNil[Key] then
                        return SafeValue(Var, nil);
                    end

                    SetInternalValue(Var, nil);
                    local Meower = Spy(Var);
                    if ExecType then Types[Meower] = ExecType end
                    return Meower
                end
            })
        end

        local Metatable = setmetatable({}, {
            __index = function(Self, Key)
                local Var = DefineVar(
                    Ast.Index(
                        Ast.FunctionCall(Ast.Variable("getgenv"), {}),
                        ToAST(Key)
                    ),
                    false,
                    true
                )

                local Value = EnvValues[Key]
                local Meow = rawget(SecureEnv, Key)
                if Meow then Value = {Meow} end
                
                if Value then
                    local X = Value[1]
                    --if typeof(X) == "function" then return X end;
                    return SafeValue(Var, X)
                end

                local ExecType = IsExecutor(Key)

                if SpyExecOnly then
                    SetInternalValue(Var, nil)
                    return TypeSpy(Var, ExecType)
                end

                if ExecType == "function" then
                    return Function(function(...)
                        local Var = AppendCall(Var, ...)
                        return Spy(Var);
                    end, Var, true)
                end

                local Spied = Spy(Var, rawget(Env, Key));
                if ExecType then
                    Types[Spied] = ExecType
                end

                return Spied;
            end,
            __newindex = function(Self, Key, Value)
                Define(
                    Ast.Index(Ast.FunctionCall(Ast.Variable("getgenv"), {}), ToAST(Key)),
                    ToAST(Value),
                    true,
                    true
                )
                
                EnvValues[Key] = { Value }
            end,
            __metatable = "Protected" -- Solara's implementation
        })
        return Metatable;
    end

    SecureEnv._G, SecureEnv.shared, SecureEnv.getgenv, SecureEnv.getrenv =
        CreateEnv("_G"),
        CreateEnv("shared"),
        Function(function() return CreateEnv("getgenv()") end, "getgenv", true),
        Function(function() return CreateEnv("getrenv()") end, "getrenv", true);

    ExploitLib:setEnv({
        ToAST = ToAST,
        TupleToAST = TupleToAST,
        OpCountCheck = OpCountCheck,
        VarValues = VarValues,
        AST = AST,
        AppendCall = AppendCall,
        Spy = Spy,
        TypeSpy = TypeSpy,
        SafeValue = SafeValue,
        cclosures = CClosures,
        types = Types,
        Function = Function,
        Variables = Variables,
        TraceId = TraceId,
        UseHookOp = UseHookOp,
        Settings = Settings,
        GetInternalValue = GetInternalValue,
        Globals = SharedGlobals,
        GetMetatable = GetMetatable,
        GetVar = GetVar
    })

    for funcName, func in next, ExploitLib.funcs do
        SecureEnv[funcName] = Function(func, funcName, true)
    end

    for libName, library in next, ExploitLib.libs do
        for Key, Value in next, library do
            library[Key] =
                if typeof(Value) == "function" then
                    Function(Value, Index(Key, libName), true)
                else
                    Value
        end
        SecureEnv[libName] = GetMetatable(libName, { __index = library })
    end

    local meowed = {}
    GlobalIndex = function(Self, Key)
        if Settings.debug then print("Indexed",Key,typeof(Key)) end

        local EnvValue = EnvValues[Key]
        local ExecType = IsExecutor(Key)

        if EnvValue then
            return SafeValue(Key, EnvValue[1])
        end

        local Type = typeof(Key)
        local DontDefine, ToUse;

        if Nil[Key] then
            return SafeValue(Key, nil)
        elseif ForceNil[Key] or Type == "nil" then
            return nil;
        end

        if IterFuncs[Key] then
            return Function(function(tbl, k : (any) -> any | nil)
                local Var = Variables[tbl]

                if Key == "next" and Var then
                    if k then
                        if Iterator then Iterator() end
                        Iterator = nil

                        return nil, nil;
                    end

                    Iterator = getmetatable(tbl).__iter(tbl, Key)
                    return Iterator();
                elseif Var then
                    local mt = getmetatable(tbl)
                    if mt then
                        Iterator = mt.__iter(tbl, Key)
                        Iterators[Iterator] = true
                        return Iterator
                    else
                        Ast.addStatement(AST, Ast.PermaComment(Ast.RawText("Unable to get the metatable for '"), Ast.Variable(Var), Ast.RawText(`' so we're unable to log the for loop (which uses {Key}) here.`)))
                    end
                elseif Key == "next" then
                    return next(tbl, k);
                end

                return TrueEnv[Key](tbl, k);
            end, Key, true)
        end

        local IgnoreMar = DoIgnore(Key)
        local Casper = IgnoreMar or -- Detected as junk
            --(Type == "string") or-- and #Key == 2) or -- Moonveil
            (Type == "string" and (#Key == 13 and Key:find("%d"))) or
            Type == "function" or -- fenv[debug.getinfo] or something
            Type == "nil" or -- fenv[nil]
            (SpyExecOnly and not ExecType)

        if Key and not meowed[Key] then
            ToUse = Define(
                if Casper and not IgnoreMar then
                    if typeof(Key) == "string" and not IsWeird(Key) then
                        Ast.Variable(Key:gsub("%W", "_"))
                    else
                        GetVar()
                else
                    GetVar(),
                Ast.Index(Ast.Variable(EnvName), ToAST(Key)),
                false,
                true
            ).data.vars[1].data.name
            DontDefine = true
            ForceNil[Key] = IgnoreMar
            meowed[Key] = ToUse
            Indexes[ToUse] = true
        end

        if
            Casper -- spyexeconly is on & it's not an exec func
        then
            ToUse = ToUse or meowed[Key];
            if not hookOp then
                return nil;
            end
            
            SetInternalValue(ToUse, nil);
            return Spy(ToUse, nil, {
                is_idx = true
            })
        end

        if SharedGlobals.Pristine then
            PristineIdxAmount += 1
            local Saved = SharedGlobals.SavedPristine[Key]
            if Saved then
                rawset(Self, Key, Saved)
                SharedGlobals.SavedPristine[Key] = nil
                return Saved
            end
        end

        ToUse = ToUse or GetVar();
        local True = TrueEnv[Key];
        local Spied;

        if typeof(True) == "function" then
            Spied = Function(function(...)
                local Var = AppendCall(ToUse, ...)
                return Spy(Var)
            end, ToUse, true)
        elseif Type == "string" and Key:find('%W') then
            Spied = Spy(ToUse)
            SetInternalValue(ToUse, nil)
        else
            Spied = Spy(ToUse);
            Types[Spied] = ExecType or typeof(True);
        end

        if not DontDefine then
            Define(
                ToUse,
                Ast.Index(Ast.Variable(EnvName), ToAST(Key)),
                false,
                true
            )
        end

        return Spied
    end

    Env = setmetatable(SecureEnv, getmetatable(GetMetatable(EnvName, {
        __index = GlobalIndex,
        __newindex = function(Self, Key, Value)
            if Key == "_msec" or Key == "heh" then
                return rawset(Self, Key, Value)
            end

            local KeyLen = if typeof(Key) == "string" then #Key else nil;
            local OldVar = Variables[Value]
            local New, ToUse = nil, Ast.Variable(Key);
            local IsFunction = typeof(Value) == "function"
            if IsFunction then
                New = Settings.discord and Function(function(...)
                    local Arg1 = ...
                    if typeof(Arg1) == "string" and DoIgnore(Arg1) then
                        return Value(...)
                    end

                    local Old, Stat = AppendCall(ToUse, ...)
                    local OldLen = VariablesLen
                    local Logged, Values = Explore(Value, {
                        params = {...},
                        bypass_beautify = true
                    })

                    if OldLen ~= VariablesLen then --> New variables added, we don't wanna miss out on them.
                        for _, stat in next, Logged.data.statements do
                            if stat.kind ~= "return" then
                                Ast.addStatement(AST, stat)
                            end
                        end
                    end

                    if Values[1] then
                        Values = table.pack(
                            unpack(Values, 2)
                        )
                        return ToMultiVars(Stat, Values, true)
                    end

                    error(Values[2])
                end, Key, iscclosure(Value)) or Value;
            elseif KeyLen then
                New = Spy(tostring(Key), Value)
            end

            if not New then
                return;
            end

            local Len = if typeof(Value) == "string" then #Value else 0
            
            if Len > 200 or KeyLen == 2 then return rawset(Self, Key, Value) end

            local ToUse = Ast.Index(Ast.Variable(EnvName), ToAST(Key));

            rawset(Self, Key, if IsFunction then New elseif OldVar then SafeValue(AstLib.ExprToCode(ToUse), Value) else Value)

            local Var = Variables[Value]
            if Var and typeof(Value) ~= "table" and not OldVar then Variables[Value] = nil end

            Define( ToUse, ToAST(Value), true, true )

            if Value then Variables[Value] = Var end
        end,
        __tostring = function() return EnvName end,
        __call = function() error("attempt to call a table value") end,
        __add = function(t, v) error(`attempt to perform arithmetic (add) on {Typeof(t)} and {Typeof(v)}`) end,
        __sub = function(t, v) error(`attempt to perform arithmetic (sub) on {Typeof(t)} and {Typeof(v)}`) end,
        __mul = function(t, v) error(`attempt to perform arithmetic (mul) on {Typeof(t)} and {Typeof(v)}`) end,
        __div = function(t, v) error(`attempt to perform arithmetic (div) on {Typeof(t)} and {Typeof(v)}`) end,
        __idiv = function(t, v) error(`attempt to perform arithmetic (idiv) on {Typeof(t)} and {Typeof(v)}`) end,
        __mod = function(t, v) error(`attempt to perform arithmetic (mod) on {Typeof(t)} and {Typeof(v)}`) end,
        __pow = function(t, v) error(`attempt to perform arithmetic (pow) on {Typeof(t)} and {Typeof(v)}`) end,
        __unm = function(t) error(`attempt to perform arithmetic (unm) on {Typeof(t)}`) end,
        __concat = function(t, v) error(`attempt to concatenate {Typeof(t)} and {Typeof(v)}`) end,
    })))

    local Macros = {
        predefine = function(tbl)
            assert(typeof(tbl) == "table", `invalid argument #1 to 'predefine', table expected got {typeof(tbl)}`)

            for i, v in next, tbl do
                Predefined[i] = { v }
            end
        end,
        hook = function(id : number, val : boolean)
            checktype(id, "number", "invalid argument #1 to 'hook'")
            checktype(val, "boolean", "invalid argument #2 to 'hook'")

            StatementHooks[id] = val;
        end,
        spy = function(path : string, value : any, didntStutter : boolean)
            local type = typeof(path)
            assert(type == "string", `invalid argument #1 to 'spy', string expected got {type}`)

            local Spied = Spy(path)
            if value ~= nil or didntStutter then
                SetInternalValue(Spied, value)
            end
            return Spied;
        end,
        setvalue = function(path : string, value : any)
            local type = typeof(path)
            assert(type == "string", `invalid argument #1 to 'spy', string expected got {type}`)

            SetInternalValue(path, value);
        end,
        hookcalls = function(handler : func)
            checktype(handler, "function", "invalid argument #1 to 'hookcalls'")

            CallsHandler = handler;
        end,
        getpath = function(obj : any)
            return Variables[obj]
        end
    }

    ExploitLib:setGlobalEnv(Env);

    Variables[Env] = EnvName
    SetInternalValue(EnvName, SecureEnv)

    local Function = setfenv(Source, Env) :: (any) -> any

    local List = Settings.macros
    if List and fs.isFile(List) then
        local macroData = fs.readFile(List);

        local thing = GetMetatable("macros", {
            __index = function(_, Key) return Macros[Key] or Env[Key]; end,
            __newindex = function(_, Key, Value)
                EnvValues[Key] = {Value, Key}
            end
        })

        local s, e = pcall(fenv.setfenv(loadstring(macroData), thing))
        if not s then Comment(`failed to load macros, error message: {HideErrors(e, true)}`) end
    end

    StartedRunning = os.time()
    SharedGlobals.StartedRunning = StartedRunning

    local Values = pack(pcall(Function)); --! add args
    CloseAllEnds()

    if not Values[1] then
        local LastStatement = AST.data.statements[#AST.data.statements]
        if LastStatement and LastStatement.kind == "call" and LastStatement.data.func.data.name == "error" then
        else
            Ast.addStatement(
                AST,
                Ast.FunctionCall(
                    Ast.Variable("error"), {
                        ToAST(Values[2], {
                            clean = true
                        })
                    }
                )
            )
        end
    elseif Values.n > 1 then
        Ast.addStatement(
            AST,
            Ast.Return(TupleToAST(unpack(Values, 2)))
        )
    end

    SharedGlobals.Deferred = {};

    local Beautified = {}

    WHILE_LIMIT /= 2.5
    TotalRepeats, TotalWhiles = 0, 0

    print("Iterating..")

    local PlsSave = Settings.save_before;

    if Settings.runtimelogs or PlsSave then
        local Success, Result = pcall(AstLib.Stringify, AST)
        if Success then
            fs.writeFile(PlsSave and "debug.lua" or Settings.out, Result)
        end
    end

    table.sort(ToExplore, function(a, b) -- a < b
        local DelayA, DelayB = a.args.delay, b.args.delay
        local DeferredA, DeferredB = a.args.deferred, b.args.deferred
    
        -- Handle deferred tasks: deferred items come after non-deferred
        if DeferredA ~= DeferredB then
            return not DeferredA -- non-deferred (false) < deferred (true)
        end
    
        -- Both deferred or both not deferred
        if not DelayA and not DelayB then
            return a.idx < b.idx
        else
            return (DelayA or 0) > (DelayB or 0)
        end
    end)

    local function Iterate()
        yoiterate = true
        for _, Data in next, ToExplore do
            if Beautified[Data] then continue end

            local Function, Id, Node, Args = Data.func, Data.id, Data.node, Data.args

            Args.as_func = true
            Args.bypass_beautify = true

            local Explored = Explore(Function, Args)
            Beautified[Data] = true

            table.clear(Node)

            for i, v in next, Explored do -- Copy everything from the function to here
                Node[i] = v
            end
        end
    end

    Iterate()

    return AST;
end

local LURAPH_MARKER = "does your environment support load/loadstring?"

local function DecompressLuraph(Code : string, Depth : number?) : string?
    --[[
        Luraph's "compressed" output is a small bootstrap that decompresses the
        real VM source into a string, then runs it via loadstring()/load().
        Our env hooks loadstring (it spies instead of really compiling), so the
        decompression corrupts and the script dies with "table overflow".

        Fix (notes.md: "if luraph isn't working, make sure loadstring & setfenv are"
        + "Added automatic luraph decompression"): run the bootstrap in a CLEAN
        sandbox with a real string env, but replace load/loadstring with a capture
        hook. The bootstrap hands us the decompressed source as a plain string; we
        grab the largest valid Luau chunk and hand THAT to EnvLog instead.
    ]]
    Depth = Depth or 0
    if Depth > 4 then return nil end --> guard against pathological nesting

    local Captured = {}
    local function Capture(chunk : any)
        if typeof(chunk) == "string" then insert(Captured, chunk) end
        return function() end --> pretend the load succeeded so the bootstrap continues
    end

    local Sandbox = fenv.setmetatable({
        loadstring = Capture,
        load = Capture,
    }, { __index = TrueEnv })

    local Loaded = loadstring(Code, { debugName = "luraph_decompress" })
    if not Loaded then return nil end

    pcall(fenv.setfenv(Loaded, Sandbox)) --> errors here are fine, we only want the captured payload

    local Best, BestLen = nil, 0
    for _, chunk in next, Captured do
        if #chunk > BestLen then
            local Ok, Compiled = pcall(compile, chunk) --> only keep chunks that are real Luau
            if Ok and Compiled then
                Best, BestLen = chunk, #chunk
            end
        end
    end

    if not Best then return nil end

    --> Luraph can stack compression layers; peel them until we hit real source.
    if Best:find(LURAPH_MARKER, 1, true) then
        return DecompressLuraph(Best, Depth + 1) or Best
    end

    return Best
end

local function TimedDump(File : string, RawContent : boolean?)
    Settings.out = Settings.out or "out.lua"

    local Code : string = RawContent and File or fs.readFile("./" .. File);
    local Source = Code;

    local HookFile = if RawContent then nil else File --> file hookOp reads from; nil = write Code to a temp

    if Code:find(LURAPH_MARKER, 1, true) then
        local Decompressed = DecompressLuraph(Code)
        if Decompressed then
            print(format("Luraph compressed payload detected; decompressed %d -> %d bytes", #Code, #Decompressed))
            Code = Decompressed
            Source = Decompressed
            HookFile = nil --> Code no longer matches File on disk, so hookOp must read our decompressed copy
        else
            warn("Luraph decompression failed; running compressed bootstrap directly")
        end
    end

    local A, B, C, D = Code:byte(1, 4);
    local IsBytecode = false;
    if A == 6 and B == 3 and C == 159 and D == 1 then --> Luau bytecode!
        IsBytecode = true
    end

    if not IsBytecode and not RawContent then
        local StartObf = os.clock()
        local Success, Hooked = UseHookOp(Code, HookFile)
        print("Obfuscated in",os.clock()-StartObf,"seconds.")
        if not Success then
            local Reason = tostring(Hooked)
            local ReasonQuoted = string.format("%q", Reason)
            Code = "print(\"Unable to load hookOp on this file, this file ran as it would without hookOp. Reason: \" .. " .. ReasonQuoted .. ")\n" ..
                Code
        else
            Code = Hooked
        end
    end

    if Settings.version and not RawContent then --> from bot
        fs.removeFile(File);
    end

    AstLib.SetGlobal("outfile", Settings.out)
    AstLib.SetGlobal("envname", EnvName)
    AstLib.SetGlobal("atruntime", Settings.runtimelogs)
    AstLib.SetGlobal("annotations", Settings.type_annotations)
    AstLib.SetGlobal("fromld", Settings.from_ld)
    AstLib.SetGlobal("minifier", Settings.minifier)
    AstLib.SetGlobal("comments", Settings.comments)

    local Start = os.clock()
    --LURAPH_COMPRESSED = Code:find("(does your environment support load/loadstring?", 0, true) and Code:find("Luraph decompression error: ", 0, true)
    local Multiplier = (1 + #Code / (200 * 1024))
    WHILE_LIMIT *= Multiplier
    MAX_OPS_MUL = Multiplier
    
    local Compiled, Loaded;
    if IsBytecode then
        print("yea!")
    end
    local Success, Error = pcall(function()
        Compiled = compile(Code, {
            optimizationLevel = 2
        })
        Loaded = loadstring(Compiled, {
            debugName = TraceId
        })
    end)

    if not Success then
        fs.writeFile(Settings.out, "--err" .. fenv.tostring(Error):match("[^\n]+"))
        process.exit(0)
        return;
    end

    AllowedGetRequests += if Source:find(":HttpGet(", 0, true) then 1 else 0

    local AST = EnvLog(Loaded, 0)

    DONE_PROCESSING = true

    Success, Result = pcall(AstLib.Stringify, AstLib.Minify(AST, not Settings.minifier))

    if not Success then
        warn("not success", Result)
    end

    Result = (if Settings.debug then Result else HideErrors(Result, nil, true)):gsub("\n%s*;\n", "\n"):gsub("discord%.gg/[%w_]+", "(discord invite)")

    local TopComment = "-- Successfully sent http GET requests to the following site(s): "
    local Meowed;
    for _, v in next, AllowedUrlsInTheEnd do
        TopComment ..= `'{v}', `
        Meowed = true
    end

    if Meowed then Result = TopComment:sub(1, -3) .. "\n" .. Result end

    print(format("Finished processing in %.8f seconds!", os.clock() - Start))
    fs.writeFile(
        Settings.out,
        (if Settings.version then `-- This file was generated with UnveilR V{Settings.version} at discord.gg/threaded using the {Settings.prod and "production" or "testing"} version.\n\n` else "")
        .. Result
    );
    _print("Finished processing")
    process.exit(0);
end

if Settings.ipt then --> Spawned instantly, for beta testing or whatever.
    return TimedDump(Settings.ipt or "input.lua");
end

while true do
    local Input = stdio.readLine()
    local Decoded = serde.decode("json", Input)

    Settings = Decoded.settings
    TimedDump(Decoded.script, true)
end