local parser = require("@std/syntax/parser")
local fs = require("@std/fs")

local function writeFileCompat(path, content)
    if fs.writeFile then return fs.writeFile(path, content) end
    if fs.writestringtofile then return fs.writestringtofile(path, content) end
    if fs.writefile then return fs.writefile(path, content) end
    if fs.open and fs.write and fs.close then
        local handle = fs.open(path, "w")
        fs.write(handle, content)
        fs.close(handle)
        return
    end
    error("No fs write function available")
end

local function splitLines(text)
    local out = {}
    for line in (text .. "\n"):gmatch("([^\n]*)\n") do
        out[#out + 1] = line
    end
    return out
end
local prettyPrint = true

local WHILE_LIMIT = 1_000_000

type Statement = {
    kind: string,
    value: any,
    tag: string,
    [string] : any
}

local constantCollection, inf_loops
local format = string.format

local function readfile(path : string) : string?
    assert(fs.exists(path), "invalid argument #1 to 'readfile', file does not exist.")

    local handle = fs.open(path, "r");
    local content = fs.read(handle)
    fs.close(handle)
    return content
end

local maxNum, tab, visited, callId = 2^64, "    ", {}, nil;

local bytes = {}
local beautify;
for i = 0, 255 do bytes[tostring(i)] = string.char(i) end

local beautifyHandlers = {
    table = function(data, tabs, shouldMinify)
        if visited[data] then return "{ 'recursive table' }" end

        tabs = shouldMinify and 0 or tabs or 1
        
        local newline = shouldMinify and "" or "\n"
        local out = "{" .. newline
        local p = string.rep(tab, tabs);

        visited[data] = true

        for i, v in next, data do
            --if i == "location" or i == "position" or i == "trailingtrivia" or i == "leadingtrivia" then continue end

            out ..= `{p}[{beautify(i, tabs + 1, shouldMinify)}] = {beautify(v, tabs + 1, shouldMinify)},` .. newline
        end

        visited[data] = false

        if #out == 2 then return "{}" end

        return out:sub(1, -3 + (shouldMinify and 2 or 0)) .. newline .. string.rep(tab, tabs - 1) .. "}"
    end,
    string = function(data, style, depth)
        if (style == 'block') then
            local equals = string.rep("=", depth or 1)
            return format("[%s[%s]%s]", equals, data, equals)
        else
            local quote = style == "double" and '"' or style == "interp" and "`" or "'"
            if prettyPrint then
                data = data:gsub(
                    "\\(%d+)",
                    bytes
                )
            end
            return quote .. data .. quote
        end
    end,
    number = function(data)
        local str = tostring(data)
        if str == "nan" then return "0/0" elseif str == "inf" then return "math.huge" elseif str == "-inf" then return "-math.huge" end

        return str
    end
}

beautify = function(data : any, ...) : string
    local type = typeof(data);

    local f = beautifyHandlers[type] or tostring
    return f(data, ...);
end

local function callFormat(...)
    return callId .. format(...)
end

local unparser = {
    binaryOperatorNames = {},
    unaryOperatorNames = {
        ["#"] = "CHECKLEN",
        ["-"] = "CHECKUNM",
        ["not"] = "CHECKNOT"
    }
}

local forId, ifId, whileId = 0, 0, 0;
local lines = {}

local function readParams(statement)
    local code = "("

    local params = statement.parameters

    for i, param in params do
        code = code .. (i > 1 and ", " or "") .. unparser:readexpr(param)
    end
    if statement.vararg then
        code = code .. (#params == 0 and "" or ",") .. "..."
    end
    
    return code .. ")", statement.vararg
end

local function getValue(op, v1, v2) : any?
    if op == "+" then return v1 + v2
    elseif op == "-" then return v1 - v2
    elseif op == "*" then return v1 * v2
    elseif op == "/" then return v1 / v2
    elseif op == "^" then return v1 ^ v2
    elseif op == "%" then return v1 % v2
    elseif op == ".." then return v1 .. v2
    elseif op == "//" then return v1 // v2
    elseif op == "and" then return v1 and v2
    elseif op == "or" then return v1 or v2
    elseif op == "==" then return v1 == v2
    elseif op == "~=" then return v1 ~= v2
    elseif op == ">" then return v1 > v2
    elseif op == "<" then return v1 < v2
    elseif op == ">=" then return v1 >= v2
    elseif op == "<=" then return v1 <= v2
    end
    return nil;
end

function unparser:construct(statement : { [any]: any }) : { [string]: string }
    if statement.istoken then
        return {
            class = "constant"
        }
    end

    if statement.kind == "stat" then --> statement
        return {
            class = "statement",
            kind = statement.tag
        }
    elseif statement.kind == "expr" then
        return {
            class = "expression",
            kind = statement.tag
        }
    end

    return {
        class = "other"
    }
end

local function is(statement, tag, deepSearch) --> tries to find the deepest mention of 'tag' that does not make it contradict it's original value (for example in a + )
    if not statement then return false end
    if statement.tag == tag then return statement end
    if statement.expression then --> works for groups!
        return is(statement.expression, tag)
    end
    if statement.lhsoperand then
        return is(statement.lhsoperand, tag)
    end
    if statement.tag == "unary" then
        return is(statement.operand, tag)
    end
    if deepSearch then
        if statement.rhsoperand then
            return is(statement.rhsoperand, tag)
        end
    end
end

local Spied = {}

local function Spy(statement)
    local tag = statement.tag
    if tag == "global" or tag == "call" or tag == "index" or tag == "indexname" then
        Spied[statement] = true
    end
end

local function isSpiedVar(statement, dontIncludeLocals)
    -- This isn't 100% accurate, it's just if this is false, then you can treat the statement as normal, otherwise hook certain things. (For optimization)
    local Binary = is(statement, "binary")
    if(Binary) then
        --> keep looking through the operands till u find a spied var
        if(isSpiedVar(Binary.lhsoperand) or isSpiedVar(Binary.rhsoperand)) then
            return true;
        end
    end

    return
        is(statement, "global") or
        is(statement, "call") or
        is(statement, "index") or
        is(statement, "indexname") or
        (not dontIncludeLocals and statement.tag == "local") or
        Spied[statement];
end

local function getLength(thing)
    local count = 0;
    if thing.tag == "table" then
        for i in thing.entries do
            count += 1
        end
    elseif thing.tag == "string" then
        count = #thing.text
    end
    return count
end

local function getRawValue(statement : Statement) : (any, boolean) --> boolean, boolean
    if typeof(statement) ~= "table" then return nil, false end

    local tag = statement.tag;

    if tag == "binary" then
        local rhs, rhsSuccess = getRawValue(statement.rhsoperand)
        local lhs, lhsSuccess = getRawValue(statement.lhsoperand)
        local operator = statement.operator.text

        if not rhsSuccess or not lhsSuccess then return nil, false end

        local s, value = pcall(getValue, operator, lhs, rhs)

        if not s or typeof(value) == "number" and value >= maxNum then --> Results that are too large, for example 2^100 can break parsing.
            return nil, false;
        end

        return value, true;
    --[[elseif tag == "group" then
        return getRawValue(statement.expression)]] --> Uncommenting this breaks moonsec, why? (invalid argument #1 to 'char', invalid value)
    elseif tag == "unary" then
        local v, s = getRawValue(statement.operand)
        if not s then return nil, false end
        
        if statement.operator.text == "-" and typeof(v) == "number" then
            return -v, true
        elseif statement.operator.text == "not" then
            return not v, true
        elseif statement.operator.text == "#" then
            return #v, true
        end
    elseif tag == "table" then
        local values = {}
        for _, entry in next, statement.entries do
            local v, s = getRawValue(entry.value)
            if not s then return nil, false end

            values[#values+1] = v
        end
        return values, true;
    end

    if statement.value ~= nil then
        --if true then return nil, false end -- keeping this on breaks moonsec for some reason?

        return statement.value, true
    end

    return statement, false;
end

function unparser:readstatementF(statement, args)
    --> if dontAddDo is on, it also means that we're in an if check / while loop / something, which means we need to properly close before 'return' or 'break'
    args = args or {}

    local tag = statement.tag
    local dontAddDo = args.dontAddDo

    Spy(statement)

    if tag == "local" then
        local code = "local ";
        local DoSpy;
        for i, var in statement.variables do
            local variable = var.node.name.text
            code = code .. (i > 1 and "," or "") .. variable
        end
        if #statement.values == 0 then return code end

        code = code .. " = "
        for i, val in statement.values do
            code = code .. (i > 1 and "," or "") .. self:readexpr(val.node)
            DoSpy = DoSpy or Spied[val.node]
        end
        Spied[statement] = Spied[statement] or DoSpy
        return code
    elseif tag == "assign" then
        local code = "";

        for i, var in statement.variables do
            code = code .. (i > 1 and ", " or "") .. self:readexpr(var.node, {
                dontHook = true
            })
        end

        code = code .. " = "

        for i, val in statement.values do
            local node = val.node
            --if constantCollection and (var and is(var.node, "index")--[[ or is(node, "local")]] or is(node, "string")) then -- a[x] = 1 or a = "hi"
            code = code .. self:readexpr(node)
            if(i~=#statement.values) then code = code .. "," end
        end
        return code
    elseif tag == "compoundassign" then
        return format("%s%s%s", self:readexpr(statement.variable, {
            dontHook = true
        }), statement.operand.text, self:readexpr(statement.value))
    elseif tag == "expression" then
        return self:readexpr(statement.expression, args)
    elseif tag == "function" then
        local params, vararg = readParams(statement.body)
        local code = "function " .. self:readexpr(statement.name, {
            dontHook = true,
            superDuperDontHook = true,
            isInVararg = true
        }) .. params

        code = code .. self:readexpr(statement.body.body, {
            isInVararg = vararg,
            dontHook = true
        }) .. "end"
        
        return code
    elseif tag == "block" then
        local location = statement.location.begin
        local content = lines[location.line + 1]
        local shouldAddDo = content:sub(location.column + 1, location.column + 2) == "do"
        local code = shouldAddDo and "do " or ""
        
        for _, stat in statement.statements do
            local str = self:readexpr(stat, {
                dontAddDo = typeof(dontAddDo) == "string" and dontAddDo or nil
            })
            code = code .. str .. (str ~= "..." and str:sub(#str) ~= ";" and ";" or "")
        end
        return code .. (shouldAddDo and "end;" or "")
    elseif tag == "localfunction" then
        local name = self:readexpr(statement.name)
        local params, vararg = readParams(statement.body)
        local code = "local function " .. name .. params
        code = code .. self:readexpr(statement.body.body, {
            dontAddDo = true,
            isInVararg = vararg
        }) .. "end"
        
        return code
    elseif tag == "conditional" then
        ifId += 1

        local elseblock = statement.elseblock
        local condition = self:readexpr(statement.condition)

        local Elseifs = statement.elseifs

        local code = format("if %s then %s", condition, self:readstatement(statement.thenblock))

        for _, elif in next, Elseifs do
            local OtherThing = self:readexpr(elif.condition)
            --local OtherThing = callFormat("CHECKELSEIF(%s,%d)", self:readexpr(elif.condition), ifId)

            code = code .. format("elseif %s then %s", OtherThing, self:readstatement(elif.thenblock))
        end

        if elseblock then
            code = code .. format("else %s", self:readexpr(elseblock))
        end

        return code .. "end"
    elseif tag == "while" then
        whileId += 1

        local Cond = self:readexpr(statement.condition)
        --if value == true then s, value = false, nil end

        --[[if (not s or inf_loops) then
            return format(
                "while %s do %send;%s",
                While,
                self:readstatement(statement.body, WhileEnd),
                WhileEnd
            )
        elseif value or not inf_loops then
            return format("while %s do %send;", Cond, self:readstatement(statement.body))
        else
            return "while(false)do end;"
        end]]

        return format(
            "while %s do %send",
            Cond,
            self:readstatement(statement.body)
        )
    elseif tag == "return" then
        --local Start = (dontAddDo and dontAddDo .. ";" or "") .. "return"
        local Start = "return "
        --[[if dontAddDo then
            Start = Start .. callFormat("BREAK(%s",dontAddDo:match("%((%d+)"))
        end]]

        if #statement.expressions == 0 then
            if dontAddDo then
               -- return Start .. ")"
            end
            return Start
        end

        local args = ""
        for i, node in statement.expressions do
            --args = args .. (dontAddDo and ", " or (i > 1 and ", " or "")) .. self:readexpr(node.node)
            args = args .. (i > 1 and ", " or "") .. self:readexpr(node.node)
        end

        Start = Start .. args-- .. (dontAddDo and ")" or "")
        
        return Start
    elseif tag == "for" then
        forId += 1

        local stepCode = statement.step
        stepCode = stepCode and "," .. self:readexpr(stepCode) or "";

        local from, to = self:readexpr(statement.from), self:readexpr(statement.to)
        local var = statement.variable.name.text

        local body = self:readstatement(statement.body, {
            dontAddDo = true
        })

        return format("for %s=%s,%s%s do %s end", var, from, to, stepCode, body)
    elseif tag == "forin" then
        local code = "for "
        for i, node in statement.variables do
            code = code .. (i > 1 and ", " or "") .. node.node.name.text
        end
        local forin = ""
        for i, val in statement.values do
            forin = forin .. (i > 1 and ", " or "") .. self:readexpr(val.node)
        end

        code = code .. format(" in %s do %send", forin, self:readstatement(statement.body, {
            dontAddDo = true
        }))
        return code
    elseif tag == "repeat" then
        return format(
            "repeat %s until %s",
            self:readexpr(statement.body, {
                dontAddDo = true
            }),
            self:readexpr(statement.condition)
        )
    elseif tag == "typealias" then -- export
        return format("export type %s = %s", statement.name.text, self:readexpr(statement.type, nil, nil, true))
    end

    print(beautify(statement))
    error("unsupported statement '" .. (statement.tag or "???") .. "'")
end

function unparser:readstatement(...)
    local statement = ...
    local stat = self:readstatementF(...)
    
    if(prettyPrint) then
        stat = "\n" .. stat
    end
    return stat .. ((stat:sub(#stat) == ";" or statement.tag == "block" and #statement.statements == 0) and '' or ";")
end

function unparser:readexpr(statement, args)
    local expr = self:construct(statement)

    if expr.class == "statement" then
        return self:readstatement(statement, args)
    elseif statement.istoken and not statement.tag then
        if statement.value ~= nil then return beautify(statement.value, statement.quotestyle) end

        return beautify(statement.text, statement.quotestyle)
    end

    local node = statement.node
    if node then statement = node end

    local tag = statement.tag or statement.kind;
    --local val, success = getRawValue(statement);

    --if success and tag ~= "string" and typeof(val) ~= "table" then return beautify(val, nil, "minify") end

    args = args or {}

    local dontHook, superDuperDontHook, isInVararg = args.dontHook, args.superDuperDontHook, args.isInVararg

    --local _, _, dontLogConstruct = ...
    --if dontLogConstruct == nil then dontLogConstruct = not constantCollection end
    local dontLogConstruct = args.dontLogConstruct
    if dontLogConstruct == nil then dontLogConstruct = not constantCollection end

    if tag == "number" then
        return statement.value or statement.text
    elseif tag == "string" then
        return beautify(statement.text, statement.quotestyle, statement.blockdepth)
    elseif tag == "nil" then
        return "nil"
    elseif tag == "vararg" then
        return "..."
    elseif tag == "break" then
        return "break"
    elseif tag == "continue" then
        return "continue"
    elseif tag == "bool" or tag == "boolean" then
        return tostring(statement.value)
    elseif tag == "call" then --> call
        local func = self:readexpr(statement.func)
        local code;

        if not statement.self then
            code = func .. "("

            for i, arg in statement.arguments do
                local data = self:readexpr(arg.node, args)

                code = code .. (i>1 and "," or "") .. data
            end
            return code .. ")"
        elseif statement.self then
            code = func .. "("
        end

        for i, arg in statement.arguments do
            local comma = ","
            local data = self:readexpr(arg.node)

            code = code .. (i > 1 and comma or "") .. data
        end

        return code .. ")"
    elseif tag == "local" or tag == "global" then --> variable name
        return (statement.name or statement.token).text
    elseif tag == "table" then
        local code = "{";
        local len = #statement.entries

        for i, entry in statement.entries do
            local key = entry.key
            if true then
                local _, s = getRawValue(key)
                local _, s2 = getRawValue(entry.value)

                if(not s or not s2) then
                    dontLogConstruct = dontLogConstruct or false
                elseif dontLogConstruct == nil then
                    dontLogConstruct = true
                end
            end

            if key then
                if entry.value.tag == "reference" then
                    code = code .. format("%s: %s%s", key.text, self:readexpr(entry.value), (i ~= len and ";" or ""))
                    continue
                end
                code = code .. format("[%s]=", self:readexpr(entry.key))
            end
            code = code .. self:readexpr(entry.value) .. (i ~= len and ";" or "")
        end

        code = code .. "}"

        return code
    elseif tag == "binary" then -- comparison, math & eq
        local rhs, lhs = statement.rhsoperand, statement.lhsoperand

        local operator = statement.operator.text

        local Lhs = self:readexpr(lhs)--Simplify(lhs, DoIgnore);
        local Rhs = self:readexpr(rhs)--Simplify(rhs, DoIgnore);

        local Default = format("%s %s %s", Lhs, operator, Rhs)
        local value, s = getRawValue(statement)

        if not s then --> Results that are too large, for example 2^100 can break parsing.
            return Default
        end

        return beautify(value)
    elseif tag == "unary" then -- -, not, #
        local operator = statement.operator.text

        local value, success = getRawValue(statement)
        if success then return tostring(value) end
        
        return callFormat("%s(%s)", self.unaryOperatorNames[operator], self:readexpr(statement.operand))
    elseif tag == "group" then -- (...)
        local Value = self:readexpr(statement.expression)
        return format("(%s)", Value)
    elseif tag == "indexname" then -- x.y
        local accessor = statement.accessor.text
        local parent = self:readexpr(statement.expression, nil, true)
        local index = statement.index.text

        if superDuperDontHook or (not dontHook and (not constantCollection) and not isSpiedVar(statement)) then
            return format("%s%s%s", parent, accessor, index)
        end

        if dontHook then
            return accessor == ":" and format("%s,%q", parent, index) or format("%s%s%s", parent, accessor, index)
        end

        --[[return callFormat("CHECKINDEX(%s,%q)",
            parent,
            index
        )]]
        return format("%s%s%s", parent, accessor, index)
    elseif tag == "index" then
        local base, index = self:readexpr(statement.expression, {
            dontHook = true
        }), self:readexpr(statement.index)

        if dontHook or true--[[ or not constantCollection]] then
            return format("%s[%s]", base, index)
        end

        return callFormat("CHECKINDEX(%s, %s)",
            base,
            index
        )
    elseif tag == "function" then --> function expr
        local params, vararg = readParams(statement.body)
        local code = format("function%s%send", params, self:readexpr(statement.body.body, {
            isInVararg = vararg
        }))
        
        return code
    elseif tag == "conditional" then
        local code = format("if %s then %s ", self:readexpr(statement.condition), self:readexpr(statement.thenexpr))

        for _, elif in statement.elseifs do
            code = code .. format("elseif %s then %s ", self:readexpr(elif.condition), self:readexpr(elif.thenexpr))
        end

        code = code .. format("else %s", self:readexpr(statement.elseexpr))
        return code
    elseif tag == "interpolatedstring" then
        --[[local code = "\""
        local list = {}

        for _, str in statement.strings do
            table.insert(list, {
                kind = "string",
                at = str.position.column,
                expr = str.text
            })
        end

        for _, expr in statement.expressions do
            table.insert(list, {
                kind = "expr",
                at = (expr.position or expr.location.begin).column,
                expr = expr
            })
        end

        table.sort(list, function(a, b) return a.at < b.at end) --> works pretty well

        local exprs = {}

        for _, v in list do
            if v.kind == "expr" then
                code = code .. "%s"--format("{%s}", self:readexpr(v.expr))
                table.insert(exprs, self:readexpr(v.expr))
            else
                code = code .. v.expr
            end
        end
        return callFormat("TEMPLATE_STRING(%s,%s)", code .. "\"", (#exprs == 0 and "nil" or table.concat(exprs, ",")))]]

        local list = {}

        for _, str in statement.strings do
            table.insert(list, {
                kind = "string",
                at = str.position.column,
                expr = str.text
            })
        end

        for _, expr in statement.expressions do
            table.insert(list, {
                kind = "expr",
                at = (expr.position or expr.location.begin).column,
                expr = expr
            })
        end

        table.sort(list, function(a, b) return a.at < b.at end)

        --> now the list is sorted exactly like it was in the code!
        local code = {}
        for _, v in next, list do
            local Expr = v.expr;
            if typeof(Expr) == "string" then
                table.insert(code, beautify(Expr))
            else
                table.insert(code, self:readexpr(Expr))
            end
        end
        return callFormat("TEMPLATE_STRING(%s)", table.concat(code, ", "))
    elseif tag == "cast" then
        print("cast")
        return ""
    elseif tag == "reference" then -- Name: string
        return statement.name.text
    end

    print(beautify(statement))
    error("unsupported expression '" .. (statement.tag or "???") .. "'")
end

local args = { ... }

local input = args[2]
local out = args[3]
prettyPrint = not args[4] or args[4] == ""
callId = args[4] or ""
constantCollection = args[5] == "1"
inf_loops = args[6] == "1"
WHILE_LIMIT = tonumber(args[7]) or WHILE_LIMIT;

if callId == "0" then callId = "" end

print("Constant collection:",constantCollection)

local output = {}

local source = readfile(input)
lines = splitLines(source)

local s = os.clock()
local parsefn = parser.parse or parser.parsefile
for _, v in parsefn(source).root.statements do
    output[#output+1] = unparser:readexpr(v)
end

print("finished everything in",os.clock()-s,"seconds, file size:",#source / 1024,"kb.")

writeFileCompat(out, table.concat(output, " "))