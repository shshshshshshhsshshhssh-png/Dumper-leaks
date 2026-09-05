local Pcall_Result_2, Pcall_Result_3, Isreadonly, Setreadonly, Restorefunction;
local fenv = getfenv();
for for_key_0, for_val_0 in next, fenv do
    if (type(for_key_0) ~= "string") then 
    end;
    if #for_key_0 < 20 then 
        string.byte(for_key_0, 1, -1);
    end;
end;
local r7, Pcall_Result = pcall(assert, false);
if r7 then 
end;
if not Pcall_Result then 
end;
if (type(Pcall_Result) ~= "string") then
else 
    r12, Pcall_Result_2 = pcall(getfenv, 0);
end;
if not r12 then 
end;
if not Pcall_Result_2 then 
end;
if (type(Pcall_Result_2) ~= "table") then 
end;
if ({})[Pcall_Result_2] then 
    r21, Pcall_Result_3 = pcall(getfenv, 1);
end;
if not r21 then 
end;
if not Pcall_Result_3 then 
end;
if (type(Pcall_Result_3) ~= "table") then 
end;
local r29, r30 = pcall(setfenv, 1, {});
local r32, Pcall_Result_4 = pcall(getfenv, 2);
if not r32 then 
end;
if not Pcall_Result_4 then 
end;
if (type(Pcall_Result_4) ~= "table") then 
end;
local r40, Pcall_Result_5 = pcall(r30, 2, {});
pcall(Pcall_Result_5, 1, Pcall_Result_3);
pcall(Pcall_Result_5, 2, Pcall_Result_4);
local r48, r49 = pcall(loadstring, [=[
        --[[

                         .@%(/*,.......      ...,,*/(#%&@@.
                     (*   ,/(#%%&&@@@@&%((////(((##%###((/**,,.     ,//(&.
                   /* .%@@@@@@@@%,  .(&@@@&&&&&&@@@@@@&#(*,........*%@@@(.  ,#.
                 */ .&@@@@@@@*  (%,   *(&&@@@@@&%(*,.             .,*(#%(*@@&*  *,
                #, /@@@@@@* *&( ,&&/.,/#%&&@@@&(&@@@@@@@@@@@@#*,.....,/&@@@@@@@@( .%
               #  #@@@@@*/@% .#%./(,.,/*,//*,.,/(*@@@@@@@@@@@@%@@@@@@@@@#.#@@@@@@&. %
              /  &@@@@@@@@(%@# *&&*&@@@@#/&@@@@/%%.,%@@@@@@@%/@@&(,  ,,,...  *%@@@# *
            #  .&@@@@@@@@@@@,((%@@@@@#.    ,&@@#@@&* .&@@@@@&,.#@@@@/&@@%(@@@&(/,(&, /,
         (/   (@&&&%&@@@&/, ,@#(@@@@,        #@@/,&@& /@@@@@,%#%@@@@@(     *@@@@@&,%%. .
        /  #/,#@@@&#(//#@@@/ %@@@&@@@(.    ,&@@(.*/*  %@@*   %@@@@@@%       (@@&(*...%&.
         ///@@&,  (&@@#,   /@/ ,*&@@@@#&@@%#%((%@&* /@@@@@@&. #@@@#&@@@&%%@@@@@@&,/(*@/#
        %%.&@# .&@@@# /@@@@%&@@@&/.   ,/((/*,  ./&@@@@@@@@@@,*&(./%@@#*&@@@(#(....,&#*@/
        @%.&& .&@@@&*    /&@@@@@@@@@@@@@@@@&@@#/(%@@@@@@@@@@&,  (@@@@@@@@@@@@/,@@@@@#.&*
        &&,%% .&*    /@@@(.  ,(@@@@@&/(////#( /&@@@@@@@@@@@@@@@(  ,&@@@@@@@@&, (@@&*/@(/
        .%*#@( /@@@@( *@@@@@@/     *%@@@@@@@&.,@& ,#, .&@@@@@@# .#*%&/,#@@@@*   *@@&/*&*
         .&/.#@@@@@@@,   *&@@%.,&@@&(,    ,(%@%&@@@@@@@@@(.*,  /@@@@@@@@@&,      %@@@@..
        @* .%@@@@@@@@(       .   (@@@@@@@@(       .*(%&@@@@@@@@@@@@&(,  ./.*@%   /@@% ./
          @* .&@@@@@@&.             ./&@@@*.&@@@@@@@&, ,**,.    .,*(&(.%@@# %@*  ,@@% ,#
            &, /@@@@@@*                    .#@@@@@@@@*.%@@@@@(,@@@@@@& ,%(.      .&@% ,#
              / *@@@@@#                                                           %@&.,#
              (( .&@@@@*                                                          #@&.,#
               .&. ,&@@@,                                                         (@&.,#
                  #. .%@@* /@@/                                                   /@&.,(
                    ./  #@%. %@&,,#,                                              /@@,./
                      *(  #@%. . (@@@@@%/,                                        /@@,.*
                        //  %@&, *@@@@@@@@( (@%/.                                 #@@, (
                          #* .&@@#. (@@@@&.*@@@@@@@@%. */.                  *..%*.&@@, /
                            @* .%@@@%, ,/ .@@@@@@@@@@,.%@@@@@% .&@@@* #@&..&@*,* %@@&. *
                               /  *&@@@@%,   *(&@@@@&. #@@@@@* #@@@% (@@* ,.   /@@@@* (
                                 @#. .#@@@@@@&(,.                      .,*(%&@@@@@&..(
                                     &(.   ./%@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@(. ((
                                          ,#/*.       ..,,,,,,,,....          ,/#

        ]]--

         return setfenv(function(...) return pZxUjym(...) end, setmetatable({ ["pZxUjym"] = ... }, { __index = getfenv((...)) })) ]=], "Luraph");
if not r48 then 
end;
if not r49 then 
end;
fenv.getgc = function(a_117, b_117, c_117, ...)
    return r810;
end;
pcall(function(a_4, b_4, c_4, ...)
    getgenv().getgc = function(a_117, b_117, c_117, ...)
        return r811;
    end;
end);
task.spawn(function()
    local r813, r814 = pcall(getgenv);
    if not r813 then 
    end;
    if type(r814) == "table" then 

    end;
    if type(shared) == "table" then 
        if (shared.JunkieProtected) then
        else 
            if (shared.JunkieCore) then
            else 
                if (shared.JD) then
                else 
                    if (shared.JunkieSDK) then
                    else 
                        if (shared.JunkieKeySystem) then
                        else 
                            if (shared._JUNKIE_LOADED) then
                            else 
                                if (shared._JKS_INSTANCE) then
                                else 
                                    if (shared.JUNKIE_RUNTIME) then
                                    else 
                                        if (shared.JKS_PROTECTED) then
                                        else 
                                            if (_G.JunkieProtected) then
                                            else 
                                                if (_G.JunkieCore) then
                                                else 
                                                    if (_G.JD) then
                                                    else 
                                                        if (_G.JunkieSDK) then
                                                        else 
                                                            if (_G.JunkieKeySystem) then
                                                            else 
                                                                if (_G._JUNKIE_LOADED) then
                                                                else 
                                                                    if (_G._JKS_INSTANCE) then
                                                                    else 
                                                                        if (_G.JUNKIE_RUNTIME) then
                                                                        else 
                                                                            if (_G.JKS_PROTECTED) then
                                                                            else 
                                                                                xpcall(function(a_121, b_121, c_121, ...)

                                                                                end, function(a_121, b_121, c_121, ...)

                                                                                end);
                                                                            end;
                                                                        end;
                                                                    end;
                                                                end;
                                                            end;
                                                        end;
                                                    end;
                                                end;
                                            end;
                                        end;
                                    end;
                                end;
                            end;
                        end;
                    end;
                end;
            end;
        end;
    end;
    local r863, r864 = pcall(string.rep, ".?", 1048576);
    pcall(string.find, pcall(string.rep, " ", 1048576), r863, r864);
    pcall(unpack, {}, 0, 2147483647);
end);
if rawequal then 
    Isreadonly = getgenv().isreadonly;
    if Isreadonly then 
        Setreadonly = getgenv().setreadonly;
        if Setreadonly then 
            Restorefunction = getgenv().restorefunction;
            if Restorefunction then 
                if Restorefunction then 

                end;
            end;
        end;
    end;
end;
if (type(getgenv().set_clipboard) == "function") then 
end;
if (type(getgenv().writeclipboard) == "function") then 
end;
local Clipboard = getgenv().Clipboard;
if Clipboard then 

end;
if type(Clipboard) == "table" then 

end;
if type(Clipboard.set) == "function" then
else 
    if not getgenv().syn then 
    end;
end;
if type(getgenv().syn) == "table" then 

end;
if type(getgenv().syn.request) == "function" then
else 
    if not getgenv().http then 
    end;
end;
if type(getgenv().http) == "table" then 

end;
if type(getgenv().http.request) == "function" then
else 

end;
if (type(getgenv().load) == "function") then 
end;
if (type(getgenv().request_internal) == "function") then 
end;
if (type(getgenv().http_request_internal) == "function") then 
end;
if (type(getgenv().websocket) == "function") then 
end;
if (type(getgenv().WebSocket) == "function") then 
end;
if not getgenv().syn then 
end;
if type(getgenv().syn) == "table" then 

end;
if type(getgenv().syn.websocket) == "function" then
else 
    if not getgenv().websocket then 
    end;
end;
if type(getgenv().websocket) == "table" then 

end;
if (type(getgenv().websocket.connect) == "function") then 
end;
if (type(getgenv().clipboard_copy) == "function") then 
end;
if (type(getgenv().clipboard_set) == "function") then 
end;
if (type(getgenv().set_clip_board) == "function") then 
end;
if (type(getgenv().writesynasset) == "function") then 
end;
if (type(getgenv().getsynasset) == "function") then 
end;
if not getgenv().syn then 
end;
if type(getgenv().syn) == "table" then 

end;
if type(getgenv().syn.toast) == "function" then
else 

end;
if (type(getgenv().createfolder) == "function") then 
end;
if (type(getgenv().rconsolesave) == "function") then 
end;
if (type(getgenv().saveinstance) == "function") then 
end;
if (type(getgenv().writeini) == "function") then 
end;
if (type(getgenv().writejson) == "function") then 
end;
if (type(getgenv().syn_io_write) == "function") then 
end;
if (type(getgenv().syn_io_append) == "function") then 
end;
if (type(getgenv().syn_io_makefolder) == "function") then 
end;
if not Restorefunction then 
end;
pcall(Restorefunction, getgenv().print);
if not Restorefunction then 
end;
pcall(Restorefunction, getgenv().warn);
if not Restorefunction then 
end;
pcall(Restorefunction, getgenv().error);
if not Restorefunction then 
end;
pcall(Restorefunction, getgenv().rconsoleprint);
if not Restorefunction then 
end;
pcall(Restorefunction, getgenv().rconsoleinfo);
if not Restorefunction then 
end;
pcall(Restorefunction, getgenv().rconsolewarn);
if not Restorefunction then 
end;
pcall(Restorefunction, getgenv().rconsoleerr);
if not Restorefunction then 
end;
pcall(Restorefunction, getgenv().consoleprint);
if not Restorefunction then 
end;
pcall(Restorefunction, getgenv().messagebox);
if not Restorefunction then 
end;
pcall(Restorefunction, getgenv().setclipboard);
if not Restorefunction then 
end;
pcall(Restorefunction, getgenv().toclipboard);
if not Restorefunction then 
end;
pcall(Restorefunction, getgenv().setrbxclipboard);
if not Restorefunction then 
end;
pcall(Restorefunction, getgenv().http_request);
if not Restorefunction then 
end;
pcall(Restorefunction, getgenv().request);
if not Restorefunction then 
end;
pcall(Restorefunction, getgenv().loadstring);
if not Restorefunction then 
end;
pcall(Restorefunction, getgenv().loadfile);
if not Restorefunction then 
end;
pcall(Restorefunction, getgenv().dofile);
if not Restorefunction then 
end;
pcall(Restorefunction, getgenv().rconsoleclear);
if not Restorefunction then 
end;
pcall(Restorefunction, getgenv().rconsolename);
local _ = not Restorefunction;
local _ = not Restorefunction;
local _ = not Restorefunction;
local _ = not Restorefunction;
local _ = not Restorefunction;
local _ = not Restorefunction;
local _ = not Restorefunction;
local _ = not Restorefunction;
local _ = not Restorefunction;
local _ = not Restorefunction;
local _ = not Restorefunction;
local _ = not Restorefunction;
local _ = not Restorefunction;
local _ = not Restorefunction;
local _ = not Restorefunction;
local _ = not Restorefunction;
local _ = not Restorefunction;
local Isfunctionhooked = getgenv().isfunctionhooked;
if Isfunctionhooked then 
    if not Isfunctionhooked then 
    end;
end;
pcall(function(a_24, b_24, c_24, ...)

end);
if not isfunctionhooked(getgenv().loadstring) then 
    if not Isreadonly then 
    end;
end;
if not Setreadonly then 
end;
local r338, r339 = pcall(
    Isreadonly,
    setmetatable({}, {
        ["__metatable"] = "Protected"
    })
);
if not r338 then 
end;
if not r339 then 
end;
pcall(Setreadonly, setmetatable({}, {
    ["__metatable"] = "Protected"
}), false);
pcall(Setreadonly, setmetatable({}, {
    ["__metatable"] = "Protected"
}), true);
if pcall(function(a_27, b_27, c_27, ...)
    getgenv().print = function(a_117, b_117, c_117, ...) end;
end) then 
    if not Isreadonly then 
    end;
end;
if not Setreadonly then 
end;
local r358, r359 = pcall(
    Isreadonly,
    setmetatable({}, {
        ["__metatable"] = "Protected"
    })
);
if not r358 then 
end;
if not r359 then 
end;
pcall(Setreadonly, setmetatable({}, {
    ["__metatable"] = "Protected"
}), false);
pcall(Setreadonly, setmetatable({}, {
    ["__metatable"] = "Protected"
}), true);
if pcall(function(a_31, b_31, c_31, ...)
    getgenv().warn = function(a_117, b_117, c_117, ...) end;
end) then 
    if not Isreadonly then 
    end;
end;
if not Setreadonly then 
end;
local r378, r379 = pcall(
    Isreadonly,
    setmetatable({}, {
        ["__metatable"] = "Protected"
    })
);
if not r378 then 
end;
if not r379 then 
end;
pcall(Setreadonly, setmetatable({}, {
    ["__metatable"] = "Protected"
}), false);
pcall(Setreadonly, setmetatable({}, {
    ["__metatable"] = "Protected"
}), true);
if pcall(function(a_35, b_35, c_35, ...)
    getgenv().error = function(a_117, b_117, c_117, ...) end;
end) then 
    if not Isreadonly then 
    end;
end;
if not Setreadonly then 
end;
local r398, r399 = pcall(
    Isreadonly,
    setmetatable({}, {
        ["__metatable"] = "Protected"
    })
);
if not r398 then 
end;
if not r399 then 
end;
pcall(Setreadonly, setmetatable({}, {
    ["__metatable"] = "Protected"
}), false);
pcall(Setreadonly, setmetatable({}, {
    ["__metatable"] = "Protected"
}), true);
if pcall(function(a_39, b_39, c_39, ...)
    getgenv().rconsoleprint = function(a_117, b_117, c_117, ...) end;
end) then 
    if not Isreadonly then 
    end;
end;
if not Setreadonly then 
end;
local r418, r419 = pcall(
    Isreadonly,
    setmetatable({}, {
        ["__metatable"] = "Protected"
    })
);
if not r418 then 
end;
if not r419 then 
end;
pcall(Setreadonly, setmetatable({}, {
    ["__metatable"] = "Protected"
}), false);
pcall(Setreadonly, setmetatable({}, {
    ["__metatable"] = "Protected"
}), true);
if pcall(function(a_43, b_43, c_43, ...)
    getgenv().rconsoleinfo = function(a_117, b_117, c_117, ...) end;
end) then 
    if not Isreadonly then 
    end;
end;
if not Setreadonly then 
end;
local r438, r439 = pcall(
    Isreadonly,
    setmetatable({}, {
        ["__metatable"] = "Protected"
    })
);
if not r438 then 
end;
if not r439 then 
end;
pcall(Setreadonly, setmetatable({}, {
    ["__metatable"] = "Protected"
}), false);
pcall(Setreadonly, setmetatable({}, {
    ["__metatable"] = "Protected"
}), true);
if pcall(function(a_47, b_47, c_47, ...)
    getgenv().rconsolewarn = function(a_117, b_117, c_117, ...) end;
end) then 
    if not Isreadonly then 
    end;
end;
if not Setreadonly then 
end;
local r458, r459 = pcall(
    Isreadonly,
    setmetatable({}, {
        ["__metatable"] = "Protected"
    })
);
if not r458 then 
end;
if not r459 then 
end;
pcall(Setreadonly, setmetatable({}, {
    ["__metatable"] = "Protected"
}), false);
pcall(Setreadonly, setmetatable({}, {
    ["__metatable"] = "Protected"
}), true);
if pcall(function(a_51, b_51, c_51, ...)
    getgenv().rconsoleerr = function(a_117, b_117, c_117, ...) end;
end) then 
    if not Isreadonly then 
    end;
end;
if not Setreadonly then 
end;
local r478, r479 = pcall(
    Isreadonly,
    setmetatable({}, {
        ["__metatable"] = "Protected"
    })
);
if not r478 then 
end;
if not r479 then 
end;
pcall(Setreadonly, setmetatable({}, {
    ["__metatable"] = "Protected"
}), false);
pcall(Setreadonly, setmetatable({}, {
    ["__metatable"] = "Protected"
}), true);
if pcall(function(a_55, b_55, c_55, ...)
    getgenv().consoleprint = function(a_117, b_117, c_117, ...) end;
end) then 
    if not Isreadonly then 
    end;
end;
if not Setreadonly then 
end;
local r498, r499 = pcall(
    Isreadonly,
    setmetatable({}, {
        ["__metatable"] = "Protected"
    })
);
if not r498 then 
end;
if not r499 then 
end;
pcall(Setreadonly, setmetatable({}, {
    ["__metatable"] = "Protected"
}), false);
pcall(Setreadonly, setmetatable({}, {
    ["__metatable"] = "Protected"
}), true);
if pcall(function(a_59, b_59, c_59, ...)
    getgenv().messagebox = function(a_117, b_117, c_117, ...) end;
end) then 
    if not Isreadonly then 
    end;
end;
if not Setreadonly then 
end;
local r518, r519 = pcall(
    Isreadonly,
    setmetatable({}, {
        ["__metatable"] = "Protected"
    })
);
if not r518 then 
end;
if not r519 then 
end;
pcall(Setreadonly, setmetatable({}, {
    ["__metatable"] = "Protected"
}), false);
pcall(Setreadonly, setmetatable({}, {
    ["__metatable"] = "Protected"
}), true);
if pcall(function(a_63, b_63, c_63, ...)
    getgenv().setclipboard = function(a_117, b_117, c_117, ...) end;
end) then 
    if not Isreadonly then 
    end;
end;
if not Setreadonly then 
end;
local r538, r539 = pcall(
    Isreadonly,
    setmetatable({}, {
        ["__metatable"] = "Protected"
    })
);
if not r538 then 
end;
if not r539 then 
end;
pcall(Setreadonly, setmetatable({}, {
    ["__metatable"] = "Protected"
}), false);
pcall(Setreadonly, setmetatable({}, {
    ["__metatable"] = "Protected"
}), true);
if pcall(function(a_67, b_67, c_67, ...)
    getgenv().toclipboard = function(a_117, b_117, c_117, ...) end;
end) then 
    if not Isreadonly then 
    end;
end;
if not Setreadonly then 
end;
local r558, r559 = pcall(
    Isreadonly,
    setmetatable({}, {
        ["__metatable"] = "Protected"
    })
);
if not r558 then 
end;
if not r559 then 
end;
pcall(Setreadonly, setmetatable({}, {
    ["__metatable"] = "Protected"
}), false);
pcall(Setreadonly, setmetatable({}, {
    ["__metatable"] = "Protected"
}), true);
if pcall(function(a_71, b_71, c_71, ...)
    getgenv().setrbxclipboard = function(a_117, b_117, c_117, ...) end;
end) then 
    if not Isreadonly then 
    end;
end;
if not Setreadonly then 
end;
local r578, r579 = pcall(
    Isreadonly,
    setmetatable({}, {
        ["__metatable"] = "Protected"
    })
);
if not r578 then 
end;
if not r579 then 
end;
pcall(Setreadonly, setmetatable({}, {
    ["__metatable"] = "Protected"
}), false);
pcall(Setreadonly, setmetatable({}, {
    ["__metatable"] = "Protected"
}), true);
if pcall(function(a_75, b_75, c_75, ...)
    getgenv().http_request = function(a_117, b_117, c_117, ...) end;
end) then 
    if not Isreadonly then 
    end;
end;
if not Setreadonly then 
end;
local r598, r599 = pcall(
    Isreadonly,
    setmetatable({}, {
        ["__metatable"] = "Protected"
    })
);
if not r598 then 
end;
if not r599 then 
end;
pcall(Setreadonly, setmetatable({}, {
    ["__metatable"] = "Protected"
}), false);
pcall(Setreadonly, setmetatable({}, {
    ["__metatable"] = "Protected"
}), true);
if pcall(function(a_79, b_79, c_79, ...)
    getgenv().request = function(a_117, b_117, c_117, ...) end;
end) then 
    if not Isreadonly then 
    end;
end;
if not Setreadonly then 
end;
local r618, r619 = pcall(
    Isreadonly,
    setmetatable({}, {
        ["__metatable"] = "Protected"
    })
);
if not r618 then 
end;
if not r619 then 
end;
pcall(Setreadonly, setmetatable({}, {
    ["__metatable"] = "Protected"
}), false);
pcall(Setreadonly, setmetatable({}, {
    ["__metatable"] = "Protected"
}), true);
if pcall(function(a_83, b_83, c_83, ...)
    getgenv().loadstring = function(a_117, b_117, c_117, ...) end;
end) then 
    if not Isreadonly then 
    end;
end;
if not Setreadonly then 
end;
local r638, r639 = pcall(
    Isreadonly,
    setmetatable({}, {
        ["__metatable"] = "Protected"
    })
);
if not r638 then 
end;
if not r639 then 
end;
pcall(Setreadonly, setmetatable({}, {
    ["__metatable"] = "Protected"
}), false);
pcall(Setreadonly, setmetatable({}, {
    ["__metatable"] = "Protected"
}), true);
if pcall(function(a_87, b_87, c_87, ...)
    getgenv().loadfile = function(a_117, b_117, c_117, ...) end;
end) then 
    if not Isreadonly then 
    end;
end;
if not Setreadonly then 
end;
local r658, r659 = pcall(
    Isreadonly,
    setmetatable({}, {
        ["__metatable"] = "Protected"
    })
);
if not r658 then 
end;
if not r659 then 
end;
pcall(Setreadonly, setmetatable({}, {
    ["__metatable"] = "Protected"
}), false);
pcall(Setreadonly, setmetatable({}, {
    ["__metatable"] = "Protected"
}), true);
if pcall(function(a_91, b_91, c_91, ...)
    getgenv().dofile = function(a_117, b_117, c_117, ...) end;
end) then 
    if not Isreadonly then 
    end;
end;
if not Setreadonly then 
end;
local r678, r679 = pcall(
    Isreadonly,
    setmetatable({}, {
        ["__metatable"] = "Protected"
    })
);
if not r678 then 
end;
if not r679 then 
end;
pcall(Setreadonly, setmetatable({}, {
    ["__metatable"] = "Protected"
}), false);
pcall(Setreadonly, setmetatable({}, {
    ["__metatable"] = "Protected"
}), true);
if pcall(function(a_95, b_95, c_95, ...)
    getgenv().rconsoleclear = function(a_117, b_117, c_117, ...) end;
end) then 
    if not Isreadonly then 
    end;
end;
if not Setreadonly then 
end;
local r698, r699 = pcall(
    Isreadonly,
    setmetatable({}, {
        ["__metatable"] = "Protected"
    })
);
if not r698 then 
end;
if not r699 then 
end;
pcall(Setreadonly, setmetatable({}, {
    ["__metatable"] = "Protected"
}), false);
pcall(Setreadonly, setmetatable({}, {
    ["__metatable"] = "Protected"
}), true);
if pcall(function(a_99, b_99, c_99, ...)
    getgenv().rconsolename = function(a_117, b_117, c_117, ...) end;
end) then 
    local _ = not Isreadonly;
end;
if pcall(function(a_101, b_101, c_101, ...)
    getgenv().rconsoleinput = function(a_117, b_117, c_117, ...) end;
end) then 
    local _ = not Isreadonly;
end;
if pcall(function(a_102, b_102, c_102, ...)
    getgenv().rconsolesettitle = function(a_117, b_117, c_117, ...) end;
end) then 
    local _ = not Isreadonly;
end;
if pcall(function(a_103, b_103, c_103, ...)
    getgenv().printidentity = function(a_117, b_117, c_117, ...) end;
end) then 
    local _ = not Isreadonly;
end;
if pcall(function(a_104, b_104, c_104, ...)
    getgenv().newcclosure = function(a_117, b_117, c_117, ...) end;
end) then 
    local _ = not Isreadonly;
end;
if pcall(function(a_105, b_105, c_105, ...)
    getgenv().setfenv = function(a_117, b_117, c_117, ...) end;
end) then 
    local _ = not Isreadonly;
end;
if pcall(function(a_106, b_106, c_106, ...)
    getgenv().readfile = function(a_117, b_117, c_117, ...) end;
end) then 
    local _ = not Isreadonly;
end;
if pcall(function(a_107, b_107, c_107, ...)
    getgenv().listfiles = function(a_117, b_117, c_117, ...) end;
end) then 
    local _ = not Isreadonly;
end;
if pcall(function(a_108, b_108, c_108, ...)
    getgenv().isfile = function(a_117, b_117, c_117, ...) end;
end) then 
    local _ = not Isreadonly;
end;
if pcall(function(a_109, b_109, c_109, ...)
    getgenv().isfolder = function(a_117, b_117, c_117, ...) end;
end) then 
    local _ = not Isreadonly;
end;
if pcall(function(a_110, b_110, c_110, ...)
    getgenv().queue_on_teleport = function(a_117, b_117, c_117, ...) end;
end) then 
    local _ = not Isreadonly;
end;
if pcall(function(a_111, b_111, c_111, ...)
    getgenv().setfflag = function(a_117, b_117, c_117, ...) end;
end) then 
    local _ = not Isreadonly;
end;
if pcall(function(a_112, b_112, c_112, ...)
    getgenv().identifyexecutor = function(a_117, b_117, c_117, ...) end;
end) then 
    local _ = not Isreadonly;
end;
if pcall(function(a_113, b_113, c_113, ...)
    getgenv().writefile = function(a_117, b_117, c_117, ...) end;
end) then 
    local _ = not Isreadonly;
end;
if pcall(function(a_114, b_114, c_114, ...)
    getgenv().appendfile = function(a_117, b_117, c_117, ...) end;
end) then 
    local _ = not Isreadonly;
end;
if pcall(function(a_115, b_115, c_115, ...)
    getgenv().makefolder = function(a_117, b_117, c_117, ...) end;
end) then 
    local _ = not Isreadonly;
end;
if pcall(function(a_116, b_116, c_116, ...)
    getgenv().delfile = function(a_117, b_117, c_117, ...) end;
end) then 
    local _ = not Isreadonly;
end;
if pcall(function(a_117, b_117, c_117, ...)
    getgenv().delfolder = function(a_117, b_117, c_117, ...) end;
end) then 

end;
if pcall(table.freeze, {
    ["test"] = "value"
}) then 
    pcall(table.freeze, {
        ["SEND_WEBHOOK"] = function(a_117, b_117, c_117, ...) end,
        ["SANITIZE"] = function(a_117, b_117, c_117, ...) end
    });
end;
pcall(table.freeze, {
    ["GetIsPremium"] = function(a_117, b_117, c_117, ...) end,
    ["GetExpiresAt"] = function(a_117, b_117, c_117, ...) end
});
pcall(table.freeze, {
    ["ValidateKey"] = function(a_117, b_117, c_117, ...) end,
    ["IsKeylessModeAndVerifyKey"] = function(a_121, b_121, c_121, ...)

    end
});
if table.create then 

end;
if not tick then 
end;
local _ = (
    (
        (
            os.clock() * 1e6
        ) % 1e6
    ) + (
        tick() * 1e6
    )
) % 1e6;
local _ = 16 + (
    bit32.bxor(
        bit32.band(
            os.time() * 1e6,
            4294967295
        ),
        bit32.band(
            os.clock() * 7000000,
            4294967295
        )
    ) % 240
);
local _ = 16 + (
    bit32.bxor(
        bit32.band(
            os.time() * 1e6,
            4294967295
        ),
        bit32.band(
            os.clock() * 7000000,
            4294967295
        )
    ) % 240
);
if not tick then 
end;
buffer.writef64(
    UNKNOWN_TYPE("buffer", "buffer: 0x0000024bad0246e0"),
    0,
    tick()
);
buffer.writef64(
    UNKNOWN_TYPE("buffer", "buffer: 0x0000024bad0246e0"),
    8,
    os.clock()
);
local Os_Time_Result = os.time();
buffer.writeu32(
    UNKNOWN_TYPE("buffer", "buffer: 0x0000024bad0246e0"),
    16,
    Os_Time_Result % 2 ^ 32
);
buffer.writeu32(
    UNKNOWN_TYPE("buffer", "buffer: 0x0000024bad0246e0"),
    20,
    math.floor(
        Os_Time_Result / 2 ^ 32
    )
);
if not DateTime then 
end;
DateTime.now();
error"invalid argument #3 to 'writef64' (number expected, got nil)";