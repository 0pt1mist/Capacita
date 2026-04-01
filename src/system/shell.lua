-- Capacita Shell v0.6.0
sys.clear()

local w, h = sys.video.res()
local history = {}

local function readln(prompt)
    local buf = ""
    local pos = 1
    local blink = true
    local hist_idx = #history + 1
    
    local cy = sys.get_cy()
    if cy > h then 
        sys.print("")
        cy = sys.get_cy() - 1
        sys.set_cy(cy)
    end
    
    local function redraw()
        local p1 = unicode.sub(buf, 1, pos - 1)
        local p2 = unicode.sub(buf, pos)
        local cur = blink and "_" or " "
        sys.video.set(1, cy, prompt .. p1 .. cur .. p2 .. "      ")
    end
    
    redraw()
    while true do
        local msg = sys.receive(0.5)
        
        if msg.type == "timeout" then
            blink = not blink
            redraw()
        elseif msg.type == "hw" and msg.data[1] == "key_down" then
            blink = true
            local char, code = msg.data[3], msg.data[4]
            
            if code == 28 then
                sys.video.set(1, cy, prompt .. buf .. "       ")
                sys.set_cy(cy)
                sys.print("") 
                if buf ~= "" then table.insert(history, buf) end
                return buf
                
            elseif code == 14 and pos > 1 then
                buf = unicode.sub(buf, 1, pos - 2) .. unicode.sub(buf, pos)
                pos = pos - 1
                
            elseif code == 203 and pos > 1 then
                pos = pos - 1
            elseif code == 205 and pos <= unicode.len(buf) then
                pos = pos + 1
                
            elseif code == 200 then
                if hist_idx > 1 then
                    hist_idx = hist_idx - 1
                    buf = history[hist_idx]
                    pos = unicode.len(buf) + 1
                end
            elseif code == 208 then
                if hist_idx <= #history then
                    hist_idx = hist_idx + 1
                    buf = history[hist_idx] or ""
                    pos = unicode.len(buf) + 1
                end
                
            elseif char >= 32 then
                local uchar = unicode.char(char)
                buf = unicode.sub(buf, 1, pos - 1) .. uchar .. unicode.sub(buf, pos)
                pos = pos + 1
            end
            redraw()
        end
    end
end

sys.print("---------------------------------")
sys.print("CAPACITA SHELL v0.6")
sys.print("---------------------------------")

while true do
    local input = readln("> ")
    local args = {}
    for word in input:gmatch("%S+") do table.insert(args, word) end
    
    if #args > 0 then
        local cmd_name = args[1]
        table.remove(args, 1)
        
        local objs = sys.recall({"cmd", cmd_name})
        if #objs == 0 then
            sys.print("Command not found: " .. cmd_name)
        else
            local pid = sys.spawn(objs[1].id, args)
            if pid then sys.wait(pid) end
        end
    end
end