--!nolint

local Types = require("./types")

local task = require("@lune/task")
local fs = require("@lune/fs")

local Globals = {} :: { [string]: any }

type AstExpression = Types.AstExpression
type AstBlock = Types.AstBlock
type use = {
    nest: number,
    uses: { AstExpression },
    item: AstExpression
}

local Ast = {}
Ast.__index = Ast
local AstValues = {}

local Minified;

local function RemoveFromString(String : string, Word : string) : string
    local start, stop = String:lower():find(Word:lower(), 0, true)
    if not start then
        return String
    elseif start == 1 then
        return String:sub(stop + 1)
    end

    return String:sub(1, start - 1) .. String:sub(stop + 1)
end

local function RemoveAll(String : string, ...)
    for _, v in {...} do
        String = RemoveFromString(String, v)
    end
    return String
end

local function ReplaceAll(String : string, ...)
    for _, List in next, {...} do
        String = String:gsub(List[1], List[2])
    end
    return String
end

local CleanPartly = function(a, b) return `{a:lower()}{b}_` end
local CamelClean = function(a) return a:lower() end
local ToUpperCase = function(a) -- 2 characters
    local uppered = a:sub(2, 2):upper()
    if a:sub(1, 1) ~= "_" then return uppered end
    return "_" .. uppered
end

local IllegalDict = {}
local Numbers = {}
for i = 1, 10 do
    local n = tostring(i - 1)
    IllegalDict[n] = true
    Numbers[n] = true
end

for _, v in next, {
    "and", "break", "do", "else", "elseif", "end", "false", "for", "function", "if", "in", "local", "nil", "not", "or", "repeat","return","then","true","until","while",
    "continue"
} do IllegalDict[v] = true end

local Casing = "pascal"
local Counts = {} :: { [string]: number }

local function GetCount(x : string) : string
    local Count = (Counts[x] or 0) + 1
    Counts[x] = Count

    if Count == 1 then return x end
    return `{x}_{Count}`
end

local RegexPattern = "[%^%%%[%]]"

local function CleanStrMini(str : string) : string?
    if str:sub(1, 4) == "http" then
        str = (
            str:match("https?://.+/(.+)%?") or -- Query params (/webhook?id=123)
            str:match("https?://.+/(.+)") or
            str
        ):gsub("%%20", " ")
    end

    local fixed;

    if str:match(RegexPattern) and pcall(function()string.match("",str)end) then
        local Start = str:match("^%w+")
        fixed = (if Start then Start .. "_" else "") .. "regex"
    end

    fixed = fixed or str:gsub("[%s%.\58-\64\91-\96]", "_")--:gsub("[^%w_]", "")--:gsub("_+", "_")
    local first = fixed:sub(1, 1)
    if Casing == "pascal" then
        fixed = first:upper() .. fixed:sub(2):gsub("(%W%w)", ToUpperCase):gsub("[^%w_]", "")
    elseif Casing == "snake" then
        fixed = fixed:gsub("([A-Z])([a-z]+)", CleanPartly):gsub("[A-Z]", string.lower)
    elseif Casing == "camel" then
        fixed = fixed:gsub("[%W](%w+)", CamelClean)
    end

    if fixed:sub(#fixed) == "_" then fixed = fixed:sub(1, -2) end

    if IllegalDict[first] then fixed = "_" .. fixed end
    return fixed
end

local function Fix(x : any) : string? return if typeof(x) == "string" and #x >= 30 then nil else x end;
local function CleanStr(x : string, prefix : string?, isIndex : boolean?, addStr : boolean?, dontCount : boolean?) : string?
    --if true then return x:gsub("%W+", "_") end

    if not x then print("no 'x' to CleanStr!", debug.traceback()) end

    x = x:gsub("[&%-]", {
        ["&"] = "and",
        ["-"] = "_"
    })

    local Cleaned = CleanStrMini(
        isIndex and x or ReplaceAll(
            RemoveAll(x, "Get", "Create", "Make"),
            {"Connect", "Connection"},
            {"Generate", "Generated"}
        )
    );

    if prefix and Cleaned ~= "str" then Cleaned = prefix .. Cleaned end

    Cleaned = Cleaned:gsub("_+", "_")

    if Cleaned == "" then return end
    if Cleaned:sub(-1) == "_" then
        Cleaned = Cleaned:sub(1, -2) -- Since there cant be more than 1 _ (due to the previous :gsub), we'll just take the character right before.
    end

    local Final = Cleaned:gsub("%W", "_"):gsub("^_+(%D)", "%1") .. (if addStr then "_str" else "")

    local Counted = if not dontCount then GetCount(Final) else Final;
    local LenCounted = #Counted

    local New = Counted:gsub("[%d_]", "")
    if #New == 0 then return end
    if LenCounted > 30 or LenCounted == 0 then return end;

    -- start the actual cleaning process here

    return Counted;
end

local concat = table.concat
local insert = table.insert
local Format = string.format
local function format(...)
    local s, e = pcall(Format, ...)
    if not s then
        warn("UNABLE TO FORMAT",e,debug.traceback())
        return "???"
    end
    return e;
end
local tab : string = "    "
local SuperTypes = {}
local function SuperTypeOf(stat : AstExpression)
    if stat.kind == "variable" then
        return SuperTypes[stat]
    end
    return stat.kind
end

function Ast.Assign(Variables: { AstExpression }, Values: {AstExpression}, IsGlobal: boolean): AstExpression
    return {
        kind = "assign",
        data = {
            vars = Variables,
            values = Values,
            type = IsGlobal and "global" or "local"
        },
        stat = true
    }
end

function Ast.Number(Value: number): AstExpression
    return {
        kind = "number",
        data = {
            value = Value
        }
    }
end

function Ast.String(Value: string): AstExpression
    return {
        kind = "string",
        data = {
            value = Value
        }
    }
end

function Ast.Boolean(Value: boolean): AstExpression
    return {
        kind = "boolean",
        data = {
            value = Value
        }
    }
end

function Ast.Nil(Value : nil) : AstExpression
    return {
        kind = "nil",
        data = {}
    }
end

function Ast.Table(Value : { [any]: any }) : AstExpression
    return {
        kind = "table",
        data = {
            entries = Value
        }
    }
end

function Ast.Unknown() : AstExpression
    return {
        kind = "unknown",
        data = {}
    }
end

function Ast.BinaryOp(Left: AstExpression, Operator: string, Right: AstExpression): AstExpression
    return {
        kind = "binaryop",
        data = {
            left = Left,
            operator = Operator,
            right = Right
        }
    }
end

function Ast.UnaryOp(Operand : AstExpression, Operator : string) : AstExpression
    return {
        kind = "unary",
        data = {
            operand = Operand,
            operator = Operator
        }
    }
end

function Ast.Variable(Name: string): AstExpression
    return {
        kind = "variable",
        data = {
            name = Name
        }
    }
end

function Ast.InterpolatedString(... : AstExpression)
    return {
        kind = "interpolated",
        data = {
            exprs = { ... }
        }
    }
end

function Ast.RawText(Text: string): AstExpression
    return {
        kind = "raw",
        data = {
            text = Text
        }
    }
end

function Ast.FunctionCall(FunctionName: AstExpression, Arguments: {AstExpression}): AstExpression
    return {
        kind = "call",
        data = {
            func = FunctionName,
            args = Arguments
        }
    }
end

function Ast.Namecall(FunctionName : AstExpression, Method : AstExpression, Arguments : {AstExpression}) : AstExpression
    return {
        kind = "namecall",
        data = {
            func = FunctionName,
            method = Method,
            args = Ast.ArgList(Arguments)
        }
    }
end

function Ast.Function(Parameters: {string}, Body: AstExpression): AstExpression
    return {
        kind = "function",
        data = {
            params = Parameters,
            body = Body
        },
        stat = true
    }
end

function Ast.Return(Values: {AstExpression}): AstExpression
    return {
        kind = "return",
        data = {
            values = Values
        },
        stat = true
    }
end

function Ast.IfStat(Condition: AstExpression, ThenBlock: AstBlock, ElseBlock: AstExpression?): AstExpression
    return {
        kind = "if",
        data = {
            condition = Condition,
            thenBlock = ThenBlock,
            elseBlock = ElseBlock
        },
        stat = true
    }
end

function Ast.WhileLoop(Condition: AstExpression, Body: AstExpression): AstExpression
    return {
        kind = "while",
        data = {
            condition = Condition,
            body = Body
        },
        stat = true
    }
end

function Ast.Break() : AstExpression
    return {
        kind = "break",
        data = {},
        stat = true
    }
end

function Ast.Continue() : AstExpression
    return {
        kind = "continue",
        data = {},
        stat = true
    }
end

function Ast.Comment(Content, ...) : AstExpression
    return {
        kind = "comment",
        data = {
            chunks = {Content, ...}
        },
        stat = true
    }
end

function Ast.PermaComment(Content, ...) : AstExpression
    return {
        kind = "comment",
        data = {
            chunks = {Content,...},
            perm = true
        },
        stat = true
    }
end

function Ast.NonOptionalComment(Content, ...) : AstExpression
    return {
        kind = "comment",
        data = {
            chunks = {Content,...},
            non_optional = true
        },
        stat = true
    }
end

function Ast.MultilineComment(Content) : AstExpression
    return {
        kind = "multiline",
        stat = true,
        data = {
            content = Content
        }
    }
end

function Ast.ForNum(Variable: string, Start: AstExpression, End: AstExpression, Step: AstExpression?, Body: AstExpression): AstExpression
    return {
        kind = "fornum",
        data = {
            var = Variable,
            start = Start,
            ["end"] = End,
            step = Step,
            body = Body
        },
        stat = true
    }
end

function Ast.ForIn(Variables: {string}, Iterator: AstExpression, Body: AstExpression): AstExpression --> for i, v in 
    return {
        kind = "forin",
        data = {
            vars = Variables,
            iterator = Iterator,
            body = Body
        },
        stat = true
    }
end

function Ast.ForPrep(Key : AstExpression, Value : AstExpression, Iterator : AstExpression, id : string) : AstExpression
    return {
        kind = "forprep",
        data = {
            key = Key,
            val = Value,
            iterator = Iterator,
            id = id
        },
        stat = true
    }
end

function Ast.End(id : string)
    return {
        kind = "end",
        data = {
            id = id
        },
        stat = true
    }
end

function Ast.Blank() : AstExpression
    return {
        kind = "blank",
        data = {},
        stat = true
    }
end

function Ast.ArgList(Args: { AstExpression }) : AstExpression
    return {
        kind = "args",
        data = {
            args = Args
        },
        stat = true
    }
end

function Ast.Block(Body : { AstExpression }) : AstExpression
    return {
        kind = "block",
        data = {
            statements = Body
        },
        stat = true
    }
end

function Ast.Index(Base : AstExpression, Key : AstExpression) : AstExpression
    return {
        kind = "index",
        data = {
            key = Key,
            base = Base
        }
    }
end

function Ast.Group(Data : AstExpression)
    return {
        kind = "group",
        data = {
            grouped = Data
        }
    }
end

function Ast.new(): AstExpression
    return getfenv().setmetatable({
        kind = "block",
        data = {
            statements = {}
        },
        stat = true
    }, Ast)
end

local WriteCount = 0;
local LastWrite = 0;
--local Writing;

function Ast:addStatement(statement: AstExpression)
    --[[if Globals.atruntime and Globals.outfile then
        --WriteCount += 1
        if(os.clock()-LastWrite) >= 0.5 then
            task.spawn(fs.writeFile, Globals.outfile, AstToCode(self))
            LastWrite = os.clock()
        end
    end]]
    table.insert(self.data.statements, statement)
end

local NewAst = {}

for i, v in next, Ast do
    NewAst[i] = function(...)
        local expr = v(...)
        if expr then
            AstValues[expr] = true
        end
        return expr;
    end
end

Ast = NewAst
function Ast.IsAst(expr : AstExpression) : boolean
    return AstValues[expr] ~= nil;
end

local Indexes = {}

local Beautify = { call = true, namecall = true, binaryop = true }
local Iterators = { pairs = true, ipairs = true, next = true }
local UseProtectionHeh = {
    binaryop = true,
    table = true
}

local ReplaceList = {
    ["\""] = "\\\"",
    ["\\"] = "\\\\"
}

local SimpleList = {
    variable = true,
    number = true,
    string = true,
    table = true
}

local function IsSimple(x) : boolean return SimpleList[x] end

for i = 0, 31 do
    ReplaceList[string.char(i)] = "\\" .. i
end

ReplaceList["\n"] = "\\n"
ReplaceList["\t"] = "\\t"

local NumberAliases = {
    [4294967296] = "2 ^ 32",
    [math.huge] = "math.huge",
    [1 / 0] = "1 / 0"
}

local LastAssignKind;

--[[for i = 127, 255 do
    ReplaceList[string.char(i)] = "\\" .. i
end]]

local function ToSimpleExpression(Expr : AstExpression) --> Converts a group or something into a simpler expression
    if Expr.kind == "group" then
        return Expr.data.grouped
    end
    return Expr;
end

local function DoIgnore(v : AstExpression)
    if Globals.minifier then
        if v.kind == "comment" then return true end
    end
    return not v.data;
end

function ExpressionToCode(expr: AstExpression, indent: number?, noVars : boolean?, groupNest : number?): string
    local PreviousLast = LastAssignKind;

    LastAssignKind = nil;

    if not expr then print("no expr?",debug.traceback()) end

    local indentLevel = indent or 0

    groupNest = groupNest or 0

    local indentStr = string.rep(tab, indentLevel)
    local nextIndentStr = string.rep(tab, indentLevel + 1)

    local Kind : string = expr.kind
    
    if Kind == "number" then
        local n = expr.data.value

        local Alias = NumberAliases[n]
        if Alias then return Alias end

        local digits = math.log10(n)
        if(n >= 1000 and digits // 1 == digits and n % 10 == 0) then
            return `1e{digits}`
        end

        return tostring(expr.data.value)
    elseif Kind == "string" then
        local str = expr.data.value
        if#str > 100000 and not Globals.fromld then return format("\"<long string (%d kilobytes)>\"", #str / 1024) end
        --if str == "\n" then return "\n" end
        local Replaced = ReplaceList[str]
        if Replaced then return '"' .. Replaced .. '"' end
        
        local _, newlineCount = str:gsub("\n", "0")

        if(newlineCount >= 10) then
            if(str:find("]]")) then
                return format("[=[%s]=]", str)
            end
            return format("[[%s]]", str)
        end

        return '"' .. str:gsub('.', ReplaceList) .. '"'
    elseif Kind == "boolean" then
        return tostring(expr.data.value)
    elseif Kind == "nil" then
        return "nil"
    elseif Kind == "unknown" then
        return "???"
    elseif Kind == "table" then
        -- beautify it!
        if #expr.data.entries == 0 then return "{}" end;

        local Beautified = "{"
        local Tab = string.rep(tab, indentLevel + 1)
        local IsArray = true
        local Count = 1;

        for _, entry in next, expr.data.entries do
            if Count ~= entry.key.data.value then
                IsArray = false
            end

            if IsArray then
                Beautified ..= format(
                    "\n%s%s,",
                    Tab,
                    ExpressionToCode(entry.val, indentLevel + 1)
                )
            else
                Beautified ..= format(
                    "\n%s[%s] = %s,",
                    Tab,
                    ExpressionToCode(entry.key, indentLevel),
                    ExpressionToCode(entry.val, indentLevel + 1)
                )
            end
            Count += 1
        end
        return Beautified:sub(1, -2) .. "\n" .. indentStr .. "}"
    elseif Kind == "variable" then
        if noVars then return "r" end

        local name = expr.data.name
        return name
    elseif Kind == "binaryop" then
        local Operator = expr.data.operator
        local Lhs, Rhs = expr.data.left, expr.data.right
        local IsEq = Operator == "=="

        if (IsEq or Operator == "~=") and Globals.minifier then
            local LhsBool, RhsBool = Lhs.kind == "boolean" or Lhs.kind == "nil", Rhs.kind == "boolean" or Rhs.kind == "nil";

            local LhsValue, RhsValue = Lhs.data.value, Rhs.data.value
            if not IsEq then
                LhsValue, RhsValue = not LhsValue, not RhsValue
            end

            if LhsBool then
                return format("%s%s", if LhsValue then "" else "not ", ExpressionToCode(Rhs, indentLevel))
            elseif RhsBool then
                return format("%s%s", if RhsValue then "" else "not ", ExpressionToCode(Lhs, indentLevel))
            end
        end

        local new = (groupNest or 0) + 1

        local IsLhsBinary = Lhs.kind == "binaryop" and groupNest < 10
        local IsRhsBinary = Rhs.kind == "binaryop" and groupNest < 10

        local LhsCode = ExpressionToCode(Lhs, indentLevel + (IsLhsBinary and 1 or 0), nil, new)
        local RhsCode = ExpressionToCode(Rhs, indentLevel + (IsRhsBinary and 1 or 0), nil, new)

        if IsLhsBinary then
            LhsCode = `(\n{nextIndentStr}{LhsCode}\n{indentStr})`
        end

        if IsRhsBinary then
            RhsCode = `(\n{nextIndentStr}{RhsCode}\n{indentStr})`
        end

        local Expr = LhsCode .. " " .. Operator .. " " .. RhsCode

        --return "(" .. Expr .. ")"
        return Expr; --> Remove top level 'or' checks ((a or b) or c) shouldn't be grouped.
    elseif Kind == "unary" then
        local Operator = expr.data.operator
        local Space = if Operator == "not" then " " else "";
        local Operand = expr.data.operand
        if Operator == "not" then
            local Simpler = ToSimpleExpression(Operand)
            if Simpler.kind == "binaryop" then --> `not` (x == y) or `not` (x ~= y)
                local IsEq, IsNeq = Simpler.data.operator == "==", Simpler.data.operator == "~="
                Simpler.data.operator = if IsEq then "~=" elseif IsNeq then "==" else Simpler.data.operator
                return ExpressionToCode(Simpler, indentLevel, noVars, groupNest)
            end
        end
        if Operand.kind == "unary" and Operator ~= "#" and Globals.minifier then --> not not -> nothing
            local OperandOperator = Operand.data.operator
            if Operator == OperandOperator then
                return ExpressionToCode(Operand.data.operand, indentLevel)
            end
        end

        local OperandStr = ExpressionToCode(Operand, indentLevel)
        if Operator == "-" or UseProtectionHeh[Operand.kind] then OperandStr = `({OperandStr})` end

        return format("%s%s%s", Operator, Space, OperandStr)
    elseif Kind == "call" then
        -- is it a namecall?
        
        local Function = ExpressionToCode(expr.data.func, indentLevel, nil, groupNest)
        local ArgCount = #expr.data.args

        local FuncKind = expr.data.func.kind
        local Changed;

        --[[if FuncKind == "variable" and expr.data.func.data.name == "pcall" and false then
            local Stats = expr.data.args[1]
            if Stats.kind == "function" then
                Stats = Stats.data.body.data.statements
                local Last = Stats[#Stats]
                if Last and Last.kind == "return" and #Last.data.values == 3 and #Stats < 10 then
                    return "";
                end
            end
        end]]

        if FuncKind == "function" then --> Turn stuff like (function()return 1 end)() into 1
            local Statements = expr.data.func.data.body.data.statements
            local StatementCount = 0;

            if Statements then -- for some friggin reason if minifier is enabled this can be missing>???
                for _, v in next, Statements do
                    if v.kind and not DoIgnore(v) then
                        StatementCount += 1
                    end
                end

                local Last = Statements[#Statements]
            
                if StatementCount == 1 and Last.kind == "return" and #Last.data.values == 1 then
                    Changed = true
                    Function = "(" .. ExpressionToCode(Last.data.values[1]) .. ")"
                else
                    Function = "(" .. Function .. ")"
                end
            else Function = "(" .. Function .. ")" end
        elseif FuncKind == "binaryop" then
            Function = `({Function})`
        end

        local Arg = expr.data.args[1]

        if ArgCount == 0 then
            return if Changed then Function else Function .. "()"
        elseif ArgCount == 1 then
            if Arg.kind == "string" or Arg.kind == "table" then --> Auto compress
                if FuncKind ~= "variable" and FuncKind ~= "index" then
                    Function = `({Function})` --> ("hi")"hi"
                end
                return format("%s%s", Function, ExpressionToCode(Arg, indent, noVars))
            end
        end

        local not_iterator =  not Iterators[Function]
        local BeautifyAll = FuncKind == "variable" and not_iterator;

        --if (BeautifyAll and ArgCount < 3) or not BeautifyAll then
        if not_iterator then
            for i, v in next, expr.data.args do -- { 1, 2, 3 } -> dont beautify.
                local Kind = v.kind

                if Kind == "table" then
                    BeautifyAll = false
                    break
                elseif not Beautify[Kind] then
                    BeautifyAll = false
                else
                    BeautifyAll = true
                    if i == 1 then break end;
                end
            end
        end

        local Casper = if BeautifyAll then 1 else 0
        local Arg1 = ExpressionToCode(Arg, indentLevel + Casper, noVars, groupNest) -- game

        local args = {}
        for i = 2, #expr.data.args do
            insert(args, ExpressionToCode(expr.data.args[i], indentLevel + Casper))
        end

        local Indent = string.rep(tab, indentLevel + Casper)
        local Concatted = concat(args, (BeautifyAll and ",\n" .. Indent or ", "))

        if not BeautifyAll then
            return format(
                "%s(%s%s)",
                Function,
                Arg1,
                (#args > 0 and ", " .. Concatted or "")
            )
        end

        return `{Function}(\n{Indent}{Arg1}{(#args > 0 and ",\n" .. Indent .. Concatted or "")}\n{indentStr})`
    elseif Kind == "namecall" then
        local Indent = string.rep(tab, indentLevel + 1)
        local ArgsList = expr.data.args.data.args
        local Args = "";

        if #ArgsList ~= 0 then
            local args = {}
            local AddNewlines = true;
            for _, arg in next, ArgsList do
                local Kind = arg.kind
                if not Beautify[Kind] then
                    AddNewlines = false
                else
                    AddNewlines = true
                end
                insert(args, ExpressionToCode(arg, indentLevel))
            end
            Args =
                if AddNewlines then
                    `\n{Indent}{concat(args, ",\n" .. Indent)}\n{indentStr}`
                else
                    concat(args, ", ")
        end

        local Thing = ExpressionToCode(expr.data.func, indentLevel)
        local Raw = {
            variable = true,
            namecall = true,
            call = true,
            index = true,
            group = true
        }

        local BaseThing = Raw[expr.data.func.kind] and Thing or `({Thing})`
        local Base = `{BaseThing}:{ExpressionToCode(expr.data.method, indentLevel)}(`

        return `{Base}{Args})`
    elseif Kind == "index" then
        local Base : string = ExpressionToCode(expr.data.base, indentLevel)
        local KeyValue = expr.data.key.data.value

        if UseProtectionHeh[expr.data.base.kind] then
            Base = "(" .. Base .. ")"
        end

        if expr.data.key.kind == "string" and not Numbers[KeyValue:sub(1, 1)] and not IllegalDict[KeyValue] and not KeyValue:match("[^%w_]") then
            return format(
                "%s.%s",
                Base,
                expr.data.key.data.value
            )
        end

        local Key : string = ExpressionToCode(expr.data.key, indentLevel)

        return format(
            "%s[%s]",
            Base,
            Key
        )
    elseif Kind == "args" then
        local Args = {}
        for _, v in next, expr.data.args do
            insert(Args, ExpressionToCode(v, indentLevel))
        end
        return concat(Args, ", ")
    elseif Kind == "group" then
        if expr.data.grouped.kind == "group" then
            return ExpressionToCode(expr.data.grouped.data.grouped, indentLevel)
        end

        return format("(%s)", ExpressionToCode(expr.data.grouped, indentLevel))
    elseif Kind == "function" then
        local stats = expr.data.body.data.statements
        if not stats then warn("NO STATEMENTS FOR FUNCTION",expr.data.body) end
        if(#(stats or {}) == 0) then return format("function(%s) end", concat(expr.data.params, ", ")) end

        --> Look through it's body, if any param was used then ok, otherwise dont add params.

        local Params = expr.data.params
        local ParamsDict = {} --> Faster param lookup
        local Used = 1

        for _, v in next, Params do
            ParamsDict[v] = true
        end

        local Body = AstToCode(expr.data.body, indentLevel + 1)
        LastAssignKind = PreviousLast

        return format(
            "function(%s)\n%s\n%send",
            (Used == 0 and "" or concat(expr.data.params, ", ")),
            Body,
            indentStr
        )
    elseif Kind == "raw" then
        return expr.data.text
    elseif Kind == "interpolated" then
        local Code = "`"
        local Chunks = expr.data.exprs
        
        for _, Expr in next, Chunks do
            if Expr.kind == "string" then
                Code ..= Expr.data.value
            else
                Code ..= Format("{%s}", ExpressionToCode(Expr, indentLevel + 1, noVars, true))
            end
        end
        return Code .. "`"
    elseif expr.stat then
        return StatementToCode(expr, indentLevel, noVars)
    else
        print(expr, debug.traceback())
        warn(`unsupported expression {Kind}!`)
        return ExpressionToCode(Ast.Unknown())
    end
end

function Pad(x : string) : string
    if #x == 0 then return x end
    return "\n" .. x
end

local Annotations = {
    number = "number",
    string = "string",
    ["nil"] = "nil",
    variable = "any"
}

local Priority = {
    variable = -1,
    any = -1,
    number = 0,
    string = 0,
    table = 0
}

local Math = {
    ["+"] = true,
    ["-"] = true,
    ["/"] = true,
    ["*"] = true,
    ["//"] = true,
    ["^"] = true,
    ["%"] = true
}

local function GetAnnotation(Statement : AstExpression) : string?
    if not Globals.annotations then return end;

    local Annotation : string? = Annotations[Statement.kind]
    if Annotation then
        return Annotation
    end

    if Statement.kind == "binaryop" then
        local Operator = Statement.data.operator
        local LhsAnnotation, RhsAnnotation = GetAnnotation(Statement.data.left), GetAnnotation(Statement.data.right)

        if Operator == "or" or Operator == "and" then
            return `{LhsAnnotation or "any"} | {RhsAnnotation or "any"}`
        elseif Operator == "==" or Operator == "~=" then
            return "boolean"
        end

        if not LhsAnnotation and not RhsAnnotation then return nil end

        local IsString = LhsAnnotation == "string" or RhsAnnotation == "string"

        if Math[Operator] and IsString then return "never" end

        if LhsAnnotation and RhsAnnotation then
            local PriorityLhs, PriorityRhs = Priority[LhsAnnotation] or 0, Priority[RhsAnnotation] or 0
            if PriorityLhs >= PriorityRhs then return LhsAnnotation end
            return RhsAnnotation
        end

        return LhsAnnotation or RhsAnnotation
    elseif Statement.kind == "index" then
        local Base = Statement.data.base
        --[[if Base.kind == "variable" and Base.data.name == EnvName then -- add support for getfenv().x direct access later
            return "any"
        end
        ]]
        return "any"
    end

    return nil
end

local ASTs = {}

function StatementToCode(Statement : AstExpression, indent : number?, noVars : boolean?)
    local indentLevel = indent or 0;
    local Kind = Statement.kind
    local indentStr : string = string.rep(tab, indentLevel)
    local Current = indentStr

    if Kind == "assign" then
        if not Statement.data then return "" end

        local IsLocal = Statement.data.type == "local"
        local Start = IsLocal and "local " or ""
        local Vars = {}
        local VarsStr = ""

        local VarLen = #Statement.data.vars
        local Vals = Statement.data.values

        local Compounded;

        if VarLen == 0 then
            local Stop;
            for _, v in next, Vals do
                local Kind = v.kind
                if Kind ~= "call" and Kind ~= "namecall" then
                    Stop = true
                    break
                end
            end

            if Stop then return "" end
        end

        local ValLen = #Vals
        local AddValues = ValLen > 0

        if VarLen ~= 0 then
            for i, var in next, Statement.data.vars do
                local Variable, Annotation = ExpressionToCode(var, indent, IsLocal and noVars);

                if Globals.annotations then
                    local Value = if not AddValues or Statement.data.type ~= "local" then nil else Statement.data.values[i]

                    if Value then
                        Annotation = Annotations[Value.kind] or GetAnnotation(Value)
                    end
                end

                --print(i, var.kind)

                insert(Vars, Variable)
                VarsStr ..= Variable .. (if Annotation then `: {Annotation}` else "") .. ", "
            end

            Start ..= VarsStr:sub(1, -3)

            if not AddValues then
                Start ..= ";"
            else
                Start ..= ` = `
            end
        else
            Start = ""
        end

        if not IsLocal and ValLen == 1 and VarLen == 1 then
            local Val = Vals[1]
            local Operator = Val.data.operator

            if Val.kind == "binaryop" and (Operator == ".." or Math[Operator]) then --> Compound assigns
                if ExpressionToCode(Val.data.left, nil, noVars) == Vars[1] then --> Turn into something compound
                    Compounded = true
                    Start = format("%s %s= %s", Vars[1], Operator, ExpressionToCode(Val.data.right, nil))
                end
            end
        end

        if not Compounded then
            if AddValues then
                local values = {}
                for i, value in ipairs(Statement.data.values) do
                    insert(values, ExpressionToCode(value, indentLevel, noVars))
                end

                local vals = concat(values, ", ")
                if #vals == 0 then
                    Start = ""
                    Current = ""
                end

                Start ..= vals
                if LastAssignKind then
                    if LastAssignKind ~= Statement.data.type then
                        Current = "\n" .. Current
                    end
                end

                LastAssignKind = Statement.data.type
            end
        end
                
        Current ..= Start
    elseif Kind == "return" then
        local values = {}
        for _, value in ipairs(Statement.data.values) do
            table.insert(values, ExpressionToCode(value, indentLevel, noVars))
        end
        Current ..= "return " .. table.concat(values, ", ")
    elseif Kind == "comment" then
        if (Globals.minifier and not Statement.data.perm) or (not Globals.comments and not Statement.data.non_optional) then return "" end;
        
        local Chunks = {}
        for _, v in next, Statement.data.chunks do
            insert(Chunks, ExpressionToCode(v, indent, noVars))
        end
        local Content = concat(Chunks, "")
        Current ..= format("--%s%s", Content:sub(1,1) == "[" and "" or " ", Content)
    elseif Kind == "multiline" then
        Current ..= format("--[[%s]]", ExpressionToCode(Statement.data.content, nil, noVars))
    elseif Kind == "if" then
        local Cond = Statement.data.condition

        if not IsSimple(Cond.kind) then
            Cond = Ast.Group(Cond) --> heh tuff (auto beautifies aswell)
        end

        local elseBlock = Statement.data.elseBlock;
        if Cond.kind == "group" then --> auto expand the paranthesis
            Cond = Cond.data.grouped
        end

        local Condition = ExpressionToCode(Cond, indentLevel, false)
        local Stats = Statement.data.thenBlock.data.statements
        local First = Stats[1]

        if First and First.kind == "comment" then
            table.remove(Stats, 1)

            -- inline (put on 1 line i guess) it
            Current ..= format(
                "if %s then %s%s",
                Condition,--if IsSimple(Cond.kind) then Condition else `({Condition})`,
                (First and ExpressionToCode(First) or ""),
                (#Stats > 0 and "\n" .. AstToCode(Statement.data.thenBlock, indentLevel + 1, noVars) or "")
            )
        else
            Current ..= format(
                "if %s then%s%s",
                Condition,
                elseBlock and "" or "\n",
                AstToCode(Statement.data.thenBlock, indentLevel + 1, noVars)
            )
        end

        if elseBlock then
            local Stats = elseBlock.data.statements
            local First = Stats[1]

            local Prefix = `\n{indentStr}else`
            local Meowed;

            if First and First.kind == "comment" then
                table.remove(Stats, 1)

                Prefix ..= ` {ExpressionToCode(First)}`
            end
            Current ..= Prefix .. if #elseBlock.data.statements == 0 then "" else "\n" .. AstToCode(elseBlock, indentLevel + 1, noVars)
        end

        Current ..= "\n" .. indentStr .. "end"
                
    elseif Kind == "while" then
        Current ..= format(
            "while %s do\n%s\n%send",
            ExpressionToCode(Statement.data.condition, indentLevel, noVars),
            AstToCode(Statement.data.body, indentLevel + 1, noVars),
            indentStr
        )
                
    elseif Kind == "fornum" then
        local step = Statement.data.step and ", " .. ExpressionToCode(Statement.data.step, indentLevel, noVars) or ""
        if step == ", 1" then step = "" end --> default is 1, so compress the output

        Current ..= format(
            "for %s = %s, %s%s do\n%s\n%send",
            Statement.data.var,
            ExpressionToCode(Statement.data.start, indentLevel, noVars),
            ExpressionToCode(Statement.data["end"], indentLevel, noVars),
            step,
            AstToCode(Statement.data.body, indentLevel + 1, noVars),
            indentStr
        )
                
    elseif Kind == "forin" then
        Current ..= format(
            "for %s in %s do\n%s\n%send",
            concat(Statement.data.vars, ", "),
            ExpressionToCode(Statement.data.iterator, indentLevel, noVars),
            Statement.data.id,
            AstToCode(Statement.data.body, indentLevel, noVars),
            indentStr
        )
    elseif Kind == "forprep" then
        Current ..= format(
            --`for %s, %s in %s do -- for loop {Statement.data.id} start`,
            `for %s, %s in %s do`,
            ExpressionToCode(Statement.data.key, nil, noVars),
            ExpressionToCode(Statement.data.val, nil, noVars),
            ExpressionToCode(Statement.data.iterator, indentLevel, noVars)
        )
    elseif Kind == "end" then
        indentLevel -= 1
        indentStr = string.rep(tab, indentLevel)

        Current = indentStr .. "end"--`end -- end id {Statement.data.id}`
    elseif Kind == "break" then
        Current ..= "break"
    elseif Kind == "continue" then
        Current ..= "continue"
    elseif Kind == "blank" then
        Current ..= " "
    elseif Kind == "raw" then
        Current ..= Statement.data.text
    elseif Kind == "block" then
        if #Statement.data.statements == 0 then
        else
            Current ..= format(
                "do\n%s\n%send",
                --string.rep(tab, indentLevel + 1),
                AstToCode(Statement, indentLevel + 1, noVars),
                indentStr
            )
        end
    else
        --error(`unsupported statement {Kind}!`)   
        return Current .. ExpressionToCode(Statement, indentLevel, noVars)
    end
    return Current;
end

function AstToCode(AST: AstBlock | AstExpression, indent: number?, noVars : boolean?): string
    if ASTs[AST] then
        return "-- recursive AST"
    end

    ASTs[AST] = true

    local indentLevel = indent or 0
    
    local Code = {}
    local Disallowed = {
        comment = true,
        multiline = true,
        blank = true,
        raw = true,
        forprep = true
    }

    if AST.kind == "block" then
        for _, Statement in ipairs(AST.data.statements) do
            local Kind : string = Statement.kind
            if LastAssignKind and Kind ~= "assign" then LastAssignKind = nil end

            local Current = StatementToCode(Statement, indentLevel, noVars)
            if Kind == "forprep" then
                indentLevel += 1
            elseif Kind == "end"then
                indentLevel -= 1
            end
            if Kind == "blank" then
                insert(Code, "")
            elseif #Current:gsub("%s", "") ~= 0 then
                insert(Code, Current .. (if not Disallowed[Kind] and Current:sub(#Current) ~= ";" then ";" else ""))
            end
        end
    end

    ASTs[AST] = false
    
    return concat(Code, "\n")
end

local UsagesList = {} :: { [string]: { use } }
local function DeNest(VarName : string) : AstExpression?
    local Uses = UsagesList[VarName]
    if not Uses then return end

    for _, Use in Uses.uses do
        if Use.item.kind == "assign" then
            --> yuh
            local Meow = Use.item.data.values[1]
            if Meow.kind == "variable" then return end
            return Meow;
        end
    end
    return;
end

local Symbols = {
    ["=="] = "is",
    ["~="] = "isnt",

    [">="] = "greater_or_eq",
    ["<="] = "less_or_eq",
    [">"] = "greater",
    ["<"] = "less_than",

    ["+"] = "plus",
    ["-"] = "minus",
    ["*"] = "times",
    ["/"] = "div",
    ["//"] = "idiv",
    ["%"] = "mod",
    ["^"] = "pow",
    [".."] = "concatted_by",

    ["or"] = "or",
    ["and"] = "and"
}

for i, v in next, Symbols do
    Symbols[i] = CleanStr(v, nil, nil, nil, true);
end

local FunctionResultNames = {
    newcclosure = { "c_closure" }
}

local NumberNames = { "zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten" }
local IsBetween = function(n : number, min : number, max : number, asInt : boolean) : boolean
    local result = n <= min and n >= max
    if asInt then result = result and math.floor(n) == n end
    return result;
end

local function Rename(Value : AstExpression?, Assigns : { AstExpression }) : string?
    if not Value then return end;

    --if true then return end

    local NewName
    local ValueKind = Value.kind
    local Namecall = ValueKind == "namecall"

    local function RenameIndex(Func : AstExpression)
        local Base = Func.data.base
        local Key = Func.data.key
        
        local KeyStr = Key.data.value
        if Key.kind ~= "string" then return end

        if Base.kind == "variable" then
            if Base.data.name == Globals.envname then
                NewName = CleanStr(KeyStr, nil, true)
            else
                NewName =
                    #KeyStr >= #Base.data.name and CleanStr(KeyStr, nil, true) or
                    CleanStr(Base.data.name .. "_" .. KeyStr)
            end
        else
            NewName = CleanStr(KeyStr, nil, true)
        end
    end

    -- if it's a call use args!

    if ValueKind == "call" or Namecall then
        local Args = Value.data.args
        local Func = Value.data.func
        local FuncName = Func.data.name

        if FuncName == "getfenv" then return end;

        local Denested = DeNest(FuncName)

        if Denested and Denested.kind == "call" and Denested.data.func.data.name == "loadstring" then
            local Arg = Denested.data.args[1]
            return Rename(Arg, {})--CleanStr("loaded")
        end

        local ResultNames = FunctionResultNames[FuncName]

        if ResultNames then
            return CleanStr(ResultNames[1])
        end

        do
            --> Look through it's assignments, if you see a global Name = then use that i guess
            for _, Usage in next, Assigns do
                if Usage.kind == "assign" and Usage.data.type == "global" then
                    local Var = Usage.data.vars[1].data
                    if Var.key.kind == "string" then
                        local Lowered = Var.key.data.value:lower()
                        if (Lowered == "name" or Lowered == "text") and not NewName then
                            local Value = Usage.data.values[1]
                            if Value.kind == "string" then
                                NewName = CleanStr(Value.data.value)
                            end
                        end
                    end
                end
            end
                
            if not NewName then
                local arg;
                if Namecall then
                    arg = Args.data.args[1]
                else
                    arg = Args[1]
                end

                if arg and arg.kind == "string" then
                    NewName = CleanStr(arg.data.value)
                end
            end
        end

        if not NewName then
            --> Is the caller an index? (string.match)
            if Namecall then
                NewName = CleanStr(Value.data.method.data.name)
            else
                local Func = Value.data.func
                local Base, Key = Func.data.base, Func.data.key
                if Func.kind == "index" and Base.kind == "variable" and Key.kind == "string" then
                    --NewName = Base.data.name ~= Globals.EnvName and CleanStr(`{Base.data.name}_{Key.data.value}`) or CleanStr(Key.data.value)
                    RenameIndex(Func);
                else
                    NewName = CleanStr(FuncName .. "_result")
                end
            end
        end
    elseif ValueKind == "index" then
        local Key = Value.data.key

        if Key.kind ~= "string" then
            if Key.kind == "number" then
                local Base = Value.data.base
                if Base.kind ~= "index" then return end

                local Name = Base.data.key.data.value

                if typeof(Name) == "string" and Name:sub(#Name) == "s" then
                    NewName = Name:sub(1, -2) .. tostring(Key.data.value)
                end
            end
        end

        if not NewName then
            RenameIndex(Value)
        end
    elseif ValueKind == "table" then
        local Key = 0;
        local IsArray = true;
        for _, v in next, Value.data.entries do
            Key += 1
            if Key ~= v.key.data.value then
                IsArray = false
                break
            end
        end
        for _, Assign in next, Assigns do
            if Assign.kind == "assign" and Assign.data.type == "global" then
                local Var1 = Assign.data.vars[1]
                if Var1 and Var1.kind == "index" and Var1.data.key.kind == "string" then
                    IsArray = false
                    break
                end
            end
        end
        NewName = CleanStr(IsArray and "array" or "dictionary")
    elseif ValueKind == "unary" then
        local Names = { ["#"] = "len", ["not"] = "not", ["-"] = "neg" }
        --NewName = 
        NewName = CleanStr(`{Names[Value.data.operator]}_{Rename(Value.data.operand, {})}`)
    elseif ValueKind == "variable" then
        local Name = Value.data.name
        return Rename(DeNest(Name), {}) or if not Name:match("r%d+") then CleanStr(Name, nil, nil, nil, true) else nil;
    elseif ValueKind == "binaryop" then
        local Symbol = Symbols[Value.data.operator]
        if not Symbol then return end
        return `{Rename(Value.data.left, {})}_{Symbol}_{Rename(Value.data.right, {})}`
    elseif ValueKind == "group" then
        return Rename(Value.data.grouped, {})
    elseif ValueKind == "number" and IsBetween(Value.data.value, 0, 10, true) then
        return CleanStr(NumberNames[Value.data.value + 1], nil, nil, nil, true)
    elseif ValueKind == "boolean" then
        return CleanStr(tostring(Value.data.value), nil, nil, nil, true)
    elseif ValueKind == "string" then
        return CleanStr(Value.data.value)
    else
        return CleanStr(ValueKind, nil, nil)
    end

    return NewName
end

function Minify(AST : AstExpression, DontActuallyMinify : boolean?) : AstExpression --> Minifies an AST
    local UndefinedList = {} :: { [string]: { use } }
    local UsageArray = {} :: { { [string]: number } }
    local AssignsList = {} :: { [string]: { AstExpression } }
    local VarDatas = {} :: { [string]: { [string]: boolean } }

    local function GetVarData(VarName : string, Key : string) : any
        local Data = VarDatas[VarName]
        if not Data then return end
        return Data[Key];
    end

    local function SetVarData(VarName : string, Key : string, Value : any)
        local Data = VarDatas[VarName]
        if not Data then
            Data = {}
            VarDatas[VarName] = Data
        end
        Data[Key] = Value;
    end

    local s = os.clock()
    local ThingsThatAddNest = {
        ["if"] = true,
        ["function"] = true,
        ["while"] = true,
        ["forin"] = true,
        ["fornum"] = true
    }

    local function Increment(Item, Nest, Parent)
        local VarName = Item.data.name
        local Array = UsagesList[VarName]
        if not Array then
            UndefinedList[VarName] = true
            Array = {
                var = VarName,
                uses = {
                    {
                        item = Item,
                        nest = Nest,
                        parent = Parent
                    }
                }
            }

            insert(UsageArray, Array)
            UsagesList[VarName] = Array
        end

        insert(Array.uses, {
            item = Item,
            nest = Nest,
            parent = Parent
        })
    end

    local function Define(Name, Item, Nest, parentStr)
        local OldArray = UsagesList[Name]
        local Use = {
            item = Item,
            nest = Nest,
            parent = parentStr
        }

        if OldArray then
            insert(OldArray.uses, Use)
            return
        end
        
        local Array = {
            var = Name,
            uses = { Use }
        }

        insert(UsageArray, Array)

        UsagesList[Name] = Array
    end

    local function Count(Item : AstExpression, Nest : number, parentStr : string?, count : number)
        count = count or 0;
        if count >= 199 then return warn("STACK OVERFLOW STOP") end
        if typeof(Item) ~= "table" then return end

        local Kind = Item.kind

        if Kind == "assign" then
            if not Item.data then return end

            for i, Var in next, Item.data.vars do
                if Var.kind == "index" then
                    local Base = Var.data.base.data.name
                    local Key = Var.data.key.data.value --> constant?
                    if Base then
                        local List = AssignsList[Base] or {}
                        insert(List, Item)
                        AssignsList[Base] = List
                    end
                    
                    Count(Var, Nest, parentStr, count + 1)
                    continue
                end

                local Name = Var.data.name
                if not Name or (UsagesList[Name] and not UndefinedList[Name]) then continue end

                Define(Name, Item, Nest, parentStr)
            end
            for _, value in next, Item.data.values do
                Count(value, Nest, parentStr, count + 1)
            end
            return;
        end

        if Kind ~= "variable" then
            for i, v in next, Item do
                local AddNest = ThingsThatAddNest[Kind]
                if AddNest then
                    Count(v, Nest + 1, tostring(Item), count + 1)
                else
                    Count(v, Nest, parentStr, count + 1)
                end
            end
            return;
        end

        Increment(Item, Nest, parentStr)

        --[[for _, v in next, UsageArray do
            if v.var == VarName then
                insert(v.uses, {
                    item = Item,
                    nest = Nest
                })
                break
            end
        end]]
    end

    Count(AST, 0, nil, 0)

    local Top = {}
    local Namecalls = {}

    for i, Data in next, UsageArray do --> Rename and get namecalls
        local VarName, VarUsages = Data.var, Data.uses
        local Usages = #VarUsages - 1 -- First item is always the assign

        local Undefined = UndefinedList[VarName]
        if Undefined and Usages == 1 then
            continue
        end

        local Idx, AssignData;
        for i, v in next, VarUsages do
            if v.item.kind == "assign" then
                Idx, AssignData = i, v.item
                break
            end
        end

        if not Idx then continue end

        local Assign = AssignData.data

        local Value = Assign.values[1]
        local Type = Value.kind

        if Type == "index" and Usages == 0 then
            local Base = Value.data.base
            if Base.kind == "variable" then
                local Uses = UsagesList[Base.data.name]
                if Uses and #Uses.uses == 2 then -- This index is the only place it's used
                    SetVarData(VarName, "Skip", true)
                    continue
                end
            end
        end

        if Usages > 1 then
            local Value : AstExpression = Assign.values[1]

            local Nest = VarUsages[Idx].nest
            local Parent = AssignData.parent
            local Upvalue = Undefined;
            if Nest ~= 0 and not Upvalue then
                for _, Usage in next, VarUsages do
                    --if Usage.nest < Nest or (Nest ~= 0 and Usage.nest > Nest) then -- Why are we checking if the nest is less? Isnt that how travelling downwards works..?
                    if (Usage.nest < Nest) or (Usage.parent ~= Parent) then
                        Upvalue = true
                        SetVarData(VarName, "Upvalue", true)
                        break
                    end
                end
            end

            local Assign = VarUsages[Idx].item
            if Assign.kind ~= "assign" then continue end

            local NewName = Fix(Rename(Value, AssignsList[VarName] or {}));

            if Upvalue then
                Assign.data.type = "global"
                insert(Top, Ast.Variable(NewName or VarName))
            end

            if NewName then
                SetVarData(VarName, "Renamed", NewName)

                --[[for _, var in next, Assign.data.vars do
                    if var.kind == "variable" and var.data.name == VarName then
                        var.data.name = NewName
                    end
                end

                for i = 2, #VarUsages do
                    VarUsages[i].item.data.name = NewName
                end

                UsagesList[NewName] = UsagesList[VarName]
                --VarName = NewName]]
            end
        end

        if Type == 'namecall' then
            local Var = Assign.values[1].data.func.data.name
            local List = UsagesList[Var]
            local VarUsages = List and #List.uses

            if VarUsages and VarUsages <= 3 then
                --table.remove(VarUsages, 2) --> remove the first usage, this works well!
                local n = #List - 1
                Namecalls[Var] = n
            end
        end
    end

    for _, Data in next, UsageArray do
        local VarName, VarUsages = Data.var, Data.uses
        local Usages = #VarUsages - 1 -- First item is always the assign

        local NewName = GetVarData(VarName, "Renamed")
        local Skip = GetVarData(VarName, "Skip")

        if
            (
                VarName ~= Globals.envname and
                not NewName and
                VarName:match("r%d.*") ~= VarName and
                Usages > 1
            )
        then
            continue
        end -- this variable was naturally named so let it be

        local Undefined = UndefinedList[VarName]
        if Undefined and Usages == 1 then
            continue
        end

        local Idx, AssignData;
        for i, v in next, VarUsages do
            if v.item.kind == "assign" then
                Idx, AssignData = i, v
                break
            end
        end

        if not Idx then continue end

        local Assign = AssignData.item.data

        if not Assign or (Assign.type ~= "local" and not GetVarData(VarName, "Upvalue")) then continue end

        if Skip then
            Assign.vars = { Ast.Variable("_") }
            continue
        end

        if DontActuallyMinify then Usages = 2 end

        local RemoveInstantly = (VarName:sub(1,1) == "_" and Usages == 0)
        --local RemoveInstantly

        if (Namecalls[VarName] or 9) <= 2 then Usages = 1 end
        if RemoveInstantly then
            --Usages = 0
            Assign.vars, Assign.values = {}, {}
            continue
        end

        local Value : AstExpression = Assign.values[1]
        local ValueKind = Value.kind

        --[[if ValueKind == "string" and not RemoveInstantly and false then
            if Assign.values[1].data.value:match("[\0-\31\200-\255]") then Assign.vars, Assign.values = {}, {} continue end

            if Usages == 0 then
                Assign.vars[1] = Ast.Variable(
                    CleanStr(Value.data.value, nil, nil, true) or GetCount("unnamed")
                )
                continue
            elseif Usages > 1 then
                Usages = 1
            end
        elseif ValueKind == "table" and false then
            Usages = 2
        end]]

        local ManyUsages = Usages > 1
        local NoUsages = Usages == 0
        
        if ManyUsages then
            --> rename everything
            -- the first usage is the assign, so generate it's name from that?
            --> if the nest is inaccurate, define it at the top.

            if NewName then
                for _, var in next, Assign.vars do
                    if var.kind == "variable" and var.data.name == VarName then
                        var.data.name = NewName
                    end
                end

                for i = 1, #VarUsages do
                    local Usage = VarUsages[i].item
                    if Usage.kind == "assign" then
                    else
                        Usage.data.name = NewName
                    end
                end
            end

            continue
        end
        
        if NoUsages then -- minify or remove
            local DoContinue;
            if #Assign.values <= #Assign.vars then
                local AreAllCalls = true;
                local Namecall;

                for _, v in next, Assign.values do
                    local kind = v.kind
                    if kind ~= "call" then
                        Namecall = Namecall or kind == "namecall"

                        AreAllCalls = false
                        DoContinue = kind ~= "index"-- or v.data.key.kind ~= "string"

                        if kind == "table" then
                            DoContinue = true
                            break
                        end

                        if not DoContinue then
                            if v.data.base.kind == "table" then
                                DoContinue = true
                                break;
                            end
                        end
                        --! TODO: Make the check above check how nested the key is, if there's over 3 dots just don't remove it.
                    end
                end

                local NOOOO_STOP;

                for _, var in next, Assign.vars do
                    local uses = UsagesList[var.data.name]
                    if not uses or #uses.uses ~= 1 then
                        NOOOO_STOP = true
                        break
                    end
                end

                if NOOOO_STOP then continue end --> if ONE variable in the definition doesnt have 0 uses, then you just cant remove it bro wtf (take pcall for example)

                local Func = Assign.values[1].data.func

                if DoContinue then --> dont minify stuff like Color3.fromRGB() and UDim2.new()
                    Assign.vars = Namecall and {} or { Ast.Variable("_") }
                    continue
                end

                if AreAllCalls and (Func.data.name ~= "getfenv") then
                    Assign.vars = {}
                else
                    if not DoContinue then
                        local First = Assign.values[1]
                        --[[if First.kind == "index" then -- just to be sure..
                            local Base = First.data.base
                            if Base.kind == "call" then -- woah wait (getfenv().meow())
                                Assign.vars = { Ast.Variable("_") }
                                continue
                            end
                        end]]
                    end
                    Assign.vars, Assign.values = {}, Namecall and Assign.values or {};
                end
            end
        elseif Usages == 1 then
            -- If it's the only 1 use in it's line, remove the rest
            SetVarData(VarName, "Inlined", true)

            local IsSingle = #Assign.values == #Assign.vars

            if not IsSingle then
                local Safe = true;
                for i = 2, #Assign.vars do
                    if #UsagesList[Assign.vars[i].data.name].uses ~= 1 then
                        --> never used
                        Safe = false
                        break
                    end
                end

                if not Safe then continue end
            end

            for i = 2, #VarUsages do
                local Use = VarUsages[i].item
                --[[local Meower = VarUsages[Idx].item.data.values[1]
                if Meower.kind == "call" and Use.data.name ~= Globals.envname then
                    
                end]]
                table.clear(Use)

                local Grouped = Assign.values[1]
                for i, v in next, Grouped do
                    Use[i] = v
                end
            end

            AssignData.item.data = nil
        end
    end

    for i, var in next, Top do
        if GetVarData(var.data.name, "inlined") then
            table.remove(Top, i);
        end
    end

    local NewAST = table.move(AST.data.statements, 1, #AST.data.statements, 2, {})
    NewAST[1] = Ast.Assign(Top, {}, false);

    AST.data.statements = NewAST

    print("Finished minifying in",os.clock()-s,"seconds.")
    Minified = true
    
    return AST;
end

return {
    Stringify = AstToCode,
    Minify = Minify,
    ExprToCode = ExpressionToCode,
    SetGlobal = function(key : string, value : any)
        Globals[key] = value
        if key == "fromld" and value then
            Ast.addStatement = function(self, statement)
                if statement.kind == "call" and statement.data.func.data.name == "pcall" then
                    local func = statement.data.args[1];

                    if func and func.kind == "variable" and func.data.name == "loadstring" then
                        table.insert(self.data.statements, statement)
                        fs.writeFile(Globals.outfile, AstToCode(self, 0))
                    end
                end
            end
        end
    end,
    Ast = Ast
}