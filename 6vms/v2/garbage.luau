--!nolint

local NonEnglishPattern = "[\0-\31\127-\255{}]"
local args = require("@lune/process").args
local IsTesting = table.find(args,"testing") or table.find(args, "test")

local Strings = {}

local Dictionary = require("@lune/serde").decode("json", require("@lune/fs").readFile("env/dict.json"))

local Consonants = {
	b = true, c = true, d = true, f = true, g = true,
	h = true, j = true, k = true, l = true, m = true,
	n = true, p = true, q = true, r = true, s = true,
	t = true, v = true, w = true, x = true, y = true, z = true
}
local bad = {y=true,v=true,x=true,w=true,z=true,q=true,_=true,j=true} --> Rarely used characters in english words
for key in bad do bad[string.upper(key)] = true end

local luaKeywords = {
    ["return"] = true, ["nil"] = true, ["thread"] = true
}
for _, v in {0, {}, "", function()end,false,newproxy()} do luaKeywords[typeof(v)] = true end
for i in getmetatable(getfenv().getfenv()).__index do luaKeywords[i] = true end
-- ^ The tables above are for O(1) lookup
for i = 1, 10 do bad[tostring(i - 1)] = true end

local IsLowerCase = function(byte : number) return byte >= 97 and byte <= 122 end
local IsUpperCase = function(byte : number) return byte >= 65 and byte <= 90 end
local IsBetween = function(n : number, min: number, max : number) return n >= min and n <= max end
local DoIgnore = function() return false end

local max, min = math.max, math.min

local function IsGarbage(txt : string, isFinal: string) : (boolean, boolean?) --> Returns whether the string is just garbage or it might be english words.
    local Len = #txt
    local Lowered = txt:lower()

    if txt:sub(1, 5) == "https" then return false, true end --> Allow HTTP urls

    if txt:find(NonEnglishPattern) then return true end --> Weird strings
    if Len <= 4 or (Len > 1000) then return true, true end
    if Len % 4 == 0 and Lowered:sub(-1) == "=" then return true, true end -- base 64

    if Strings[txt] then return false, true end --> Saved result
    if luaKeywords[txt] then return true end
    if Dictionary[Lowered] then return false, true end
    if isFinal and not IsBetween(Len, 12, 14) then return false, true end

    --[[local Words = 0;

    for Word in txt:gmatch("[^ %-—,\n]+") do --> Split by em dash, spaces, dashes & commas.
        if Dictionary[Word:lower()] then
            Words += 1
            continue
        end

        local Cluster, MaxCluster = 0, 3;
        local Index, Last = 0, 0

        for _, Letter in Word:split("") do
            local Byte = string.byte(Letter);

            if not Consonants[Letter] or Last == Byte or (isFinal and IsUpperCase(Byte) and IsLowerCase(Last)) then --> Capitalization matters
                Cluster = 0
                continue
            end

            Index, Last = Index + 1, Byte

            Cluster += 1
            if Cluster >= MaxCluster then
                local NextLetter = Word:sub(Index + 1, Index + 1)

                if not Consonants[NextLetter] or NextLetter == Letter then
                    Cluster = 0
                else
                    return #Word ~= Cluster
                end --> If the next letter is a vowel, let it go, otherwise, if the word itself is the length of the cluster (like sub), return true.
            end
        end

        Words += 1
    end]]

    --local Words = #txt:split(" ");

    local Words = 0;
    local FromDict = true

    for _, Word in txt:gsub("[ %-,]", " "):split(" ") do --! THE MOST EXPENSIVE, SINCE IT CONTAINS EVERYTHING.
        local LoweredWord = Word:lower()
        if Dictionary[LoweredWord]--[[ or Dictionary[LoweredWord:sub(1, -4)]] then --> sprintING -> sprint
            Words += 1
            continue
        end

        FromDict = false

        local Cluster, MaxCluster = 0, 3;
        local Index, Last = 0, 0

        --[[for _, Letter in Word:split("") do --! VERY EXPENSIVE
            local Byte = string.byte(Letter);

            if not Consonants[Letter] or Last == Byte or (isFinal and IsUpperCase(Byte) and IsLowerCase(Last)) then --> Capitalization matters
                Cluster = 0
                continue
            end

            Index, Last = Index + 1, Byte

            Cluster += 1
            if Cluster >= MaxCluster then --! not expensive
                local NextLetter = Word:sub(Index + 1, Index + 1)

                if not Consonants[NextLetter] or NextLetter == Letter then
                    Cluster = 0
                else
                    return #Word ~= Cluster
                end --> If the next letter is a vowel, let it go, otherwise, if the word itself is the length of the cluster (like sub), return true.
            end
        end]]

        for i = 1, #Word do --! VERY EXPENSIVE
            local Letter = Word:sub(i, i);
            --local Byte = Letter:byte();

            --if not Consonants[Letter] or Last == Byte or (isFinal and IsUpperCase(Byte) and IsLowerCase(Last)) then --> Capitalization matters
            if not Consonants[Letter] or Last == Letter then --> ^^ well too bad idc
                Cluster = 0
                continue
            end

            Index, Last = Index + 1, Letter--Byte

            Cluster += 1
            if Cluster >= MaxCluster then --! not expensive
                local NextLetter = Word:sub(Index + 1, Index + 1)

                if not Consonants[NextLetter] or NextLetter == Letter then
                    Cluster = 0
                else
                    return #Word ~= Cluster
                end --> If the next letter is a vowel, let it go, otherwise, if the word itself is the length of the cluster (like sub), return true.
            end
        end

        Words += 1
    end

    if FromDict then return false, true end

    if Words == 1 then
    	local lower, points, capitals, lowercases = txt:lower(), 0, 0, 0
        local len = #lower
        if len > 20 then return true, true end --> why would a single word be over 20 characters..?

    	for i = 1, len do
            local char = txt:sub(i, i)--:byte()

            if IsUpperCase(char:byte()) then capitals += 1 else lowercases += 1 end --> char:byte() is faster than byte(char)

    		points += bad[char] and -5 or 1 --> if a rarely used letter, -5, otherwise + 1
	    end
        
        local diff = max(capitals, lowercases) - min(lowercases, capitals)
        if diff > 0 and (diff > 6 or diff <= 3) then return true end -- too big of a ratio
        if capitals == len or lowercases == len then return true, true end
        
	    return points <= 0
    end

    return false;
end

local function IsGarbageString(...)
    local val, isFinal = IsGarbage(...)
    if val then return val end
    if isFinal then return val end

    return DoIgnore((...), true)
end

if IsTesting then
    local Tests = {
        [1] = "�\21!v��",
        [2] = "MoonSec_StringsHiddenAttr",
        [3] = "Your platform is unable to execute this script.",
        [4] = "\r\n\r\n\tA picture taken from your webcam:\r\n       ,            _..._            ,\r\n      {'.         .'     '.         .'}\r\n     { ~ '.      _|=    __|_      .'  ~}\r\n    { ~  ~ '-._ (___________) _.-'~  ~  }\r\n   {~  ~  ~   ~.'           '. ~    ~    }\r\n  {  ~   ~  ~ /   /\     /\   \   ~    ~  }\r\n  {   ~   ~  /    __     __    \ ~   ~    }\r\n   {   ~  /\\/  -<( o)   ( o)>-  \\/\ ~   ~}\r\n    { ~   ;(      \\/ .-. \\/      );   ~ }\r\n     { ~ ~\\_  ()  ^ (   ) ^  ()  _/ ~  }\r\n      '-._~ \   (`-._'-'_.-')   / ~_.-'\r\n          '--\   `'._'\"'_.'`   /--'\r\n              \     \`-'/     /\r\n               `\    '-'    /'\r\n                `\         /'\r\n                  ''-...-''\r\n                Hands Up Skid\r\n\r\n",
        [5] = "K��\f",
        [6] = "what the",
        [7] = "srWExoDHaisdPintb",
        [8] = "Hello, world!",
        [9] = "LocalPlayer",
        [10] = "f3a9-7b2c-1e4d-8f90",
        [11] = "veykcYEk",
        [12] = "JUoP_KpO",
        [13] = "OkjgbFwG",
        [14] = "cGjUrHPe",
        [15] = "strength",
        [16] = "XGnsThTM",
        url = "https://pastebin.com/raw/5SiXR3AB",
        longgarbage = "��\fZ`��>�Y���\b\23\22��\25\14�>1",
        sad = "dtc:(",
        random = "UfZOAO",
        invalid = "�����",
        b64 = "Mcm/Cu4=",
        sprinting = "Sprinting"
    }

    local Sum, TestCount = 0, 0;

    for i, String in Tests do
        local Start = os.clock()
        local State = IsGarbageString(String, false)
        Sum += os.clock() - Start
        TestCount += 1

        print(i, State)
    end

    print("Average time taken to calculate:", Sum / TestCount)
end

return {IsGarbageString, function(Data)
    Strings = Data.Strings or Strings
    DoIgnore = Data.DoIgnore or DoIgnore
end}