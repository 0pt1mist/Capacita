-- Capacita Shell v0.5.0
sys.video.bind()
local w, h = sys.video.res()
sys.video.fill(1, 1, w, h, " ")

local cy = 1
local history = {}

local function scroll()
    sys.video.fill(1, 1, w, h, " ")
    cy = 1
end

local function tty_print(txt)
    sys.video.set(1, cy, tostring(txt) .. "                               ")
    cy = cy + 1
    if cy > h then scroll() end
end

local function readln(prompt)
    local buf = ""
    local pos = 1
    local blink = true
    local hist_idx = #history + 1
    
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
                cy = cy + 1
                if cy > h then scroll() end
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

tty_print("---------------------------------")
tty_print("CAPACITA SHELL v0.5")
tty_print("---------------------------------")

while true do
    local input = readln("> ")
    local args = {}
    for word in input:gmatch("%S+") do table.insert(args, word) end
    
    if #args > 0 then
        local cmd_name = args[1]
        table.remove(args, 1)
        
        local objs = sys.recall({"cmd", cmd_name})
        if #objs == 0 then
            tty_print("Command not found: " .. cmd_name)
        else
            local pid = sys.spawn(objs[1].id, args)
            if pid then sys.wait(pid) end
        end
    end
end