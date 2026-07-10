-- Capacita Shell v1.1.0 (Capability Broker)
sys.clear()
local w, h = sys.video.res()
local history = {}

local function readln(prompt)
    local buf, pos, blink, hist_idx = "", 1, true, #history + 1
    local cy = sys.get_cy()
    if cy > h then sys.print(""); cy = sys.get_cy() - 1; sys.set_cy(cy) end
    
    local function redraw()
        local p1, p2 = unicode.sub(buf, 1, pos - 1), unicode.sub(buf, pos)
        sys.video.set(1, cy, prompt .. p1 .. (blink and "_" or " ") .. p2 .. "      ")
    end
    
    redraw()
    while true do
        local msg = sys.receive(0.5)
        if msg.type == "timeout" then blink = not blink; redraw()
        elseif msg.type == "hw" and msg.data[1] == "key_down" then
            blink = true
            local char, code = msg.data[3], msg.data[4]
            if code == 28 then
                sys.video.set(1, cy, prompt .. buf .. "       "); sys.set_cy(cy); sys.print("") 
                if buf ~= "" then table.insert(history, buf) end
                return buf
            elseif code == 14 and pos > 1 then buf = unicode.sub(buf, 1, pos - 2) .. unicode.sub(buf, pos); pos = pos - 1
            elseif code == 203 and pos > 1 then pos = pos - 1
            elseif code == 205 and pos <= unicode.len(buf) then pos = pos + 1
            elseif char >= 32 then
                buf = unicode.sub(buf, 1, pos - 1) .. unicode.char(char) .. unicode.sub(buf, pos); pos = pos + 1
            end
            redraw()
        end
    end
end

sys.print("CAPACITA SHELL:")

local function execute(input)
    local words = {}
    for word in input:gmatch("%S+") do table.insert(words, word) end
    if #words == 0 then return end
    
    local cmd_name = words[1]; table.remove(words, 1)
    
    local objs = sys.recall({"cmd", cmd_name})
    if #objs == 0 then sys.print("Command not found: " .. cmd_name); return end

    local exe_cap = sys.request(objs[1].id, {read=true})
    
    local passed_args = {}
    for _, word in ipairs(words) do
        if string.sub(word, 1, 1) == "@" then
            local target = string.sub(word, 2)
            local tobjs = sys.recall(target)
            if #tobjs == 0 then 
                sys.print("Object not found: " .. target); return 
            elseif #tobjs > 1 then 
                sys.print("Multiple matches for " .. target .. ". Be specific."); return 
            else
                local tcap = sys.request(tobjs[1].id, {read=true, write=true, delete=true})
                table.insert(passed_args, tcap)
            end
        else
            table.insert(passed_args, word)
        end
    end
    
    local pid = sys.spawn(exe_cap, passed_args)
    if pid then sys.wait(pid) end
end

while true do
    execute(readln("> "))
end