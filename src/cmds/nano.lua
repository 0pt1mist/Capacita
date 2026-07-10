if #args == 0 then sys.print("Usage: nano @<target> OR nano <new_tag>"); return end

local target = args[1]
local w, h = sys.video.res()
local scrollY, cursorX, cursorY = 0, 1, 1
local lines = {""}
local obj_id, current_cap = nil, nil
local is_new = false

if type(target) == "table" and target.read then
    current_cap = target
    obj_id = current_cap.id
    local content = current_cap.read()
    if content and content ~= "" then
        lines = {}
        for line in string.gmatch(content.."\n", "([^\n]*)\n") do table.insert(lines, line) end
    end
elseif type(target) == "string" then
    is_new = true
    obj_id = target
else
    sys.print("Invalid argument."); return
end
if #lines == 0 then lines = {""} end

local function draw()
    local title = is_new and (" Nano:[New Object] " .. obj_id) or (" Nano: " .. string.sub(obj_id, 1, 8))
    sys.video.fill(1, 1, w, 1, " "); sys.video.set(1, 1, title)
    for i = 1, h-2 do
        local lineIdx = scrollY + i
        if lines[lineIdx] then sys.video.set(1, i+1, unicode.sub(lines[lineIdx], 1, w) .. "      ")
        else sys.video.fill(1, i+1, w, 1, " ") end
    end
    sys.video.fill(1, h, w, 1, " "); sys.video.set(1, h, "^S Save  ^X Exit  Lines: " .. #lines)
    local line = lines[scrollY + cursorY] or ""
    local charUnder = unicode.sub(line, cursorX, cursorX)
    if charUnder == "" then charUnder = " " end
    sys.video.set(cursorX, cursorY + 1, "["..charUnder.."]")
end

local function save()
    local data = table.concat(lines, "\n")
    if is_new then
        current_cap = sys.memorize(data, {"user_text", obj_id})
        obj_id = current_cap.id
        is_new = false
    else
        current_cap.write(data) 
    end
    sys.video.set(1, h, "Saved UUID: " .. string.sub(obj_id, 1, 8) .. "          ")
    sys.receive(1)
end

while true do
    draw()
    local msg = sys.receive()
    if msg.type == "hw" and msg.data[1] == "key_down" then
        local char, code = msg.data[3], msg.data[4]
        if char == 19 then save()
        elseif char == 24 then sys.clear(); return
        elseif code == 28 then
            local p1 = unicode.sub(lines[scrollY + cursorY], 1, cursorX - 1)
            local p2 = unicode.sub(lines[scrollY + cursorY], cursorX)
            lines[scrollY + cursorY] = p1; table.insert(lines, scrollY + cursorY + 1, p2)
            cursorY = cursorY + 1; cursorX = 1
            if cursorY > h - 2 then cursorY = cursorY - 1; scrollY = scrollY + 1 end
        elseif code == 14 then
            if cursorX > 1 then
                lines[scrollY + cursorY] = unicode.sub(lines[scrollY + cursorY], 1, cursorX - 2) .. unicode.sub(lines[scrollY + cursorY], cursorX)
                cursorX = cursorX - 1
            elseif cursorY > 1 or scrollY > 0 then
                local current = lines[scrollY + cursorY]
                if cursorY > 1 then cursorY = cursorY - 1 else scrollY = scrollY - 1 end
                cursorX = unicode.len(lines[scrollY + cursorY]) + 1
                lines[scrollY + cursorY] = lines[scrollY + cursorY] .. current
                table.remove(lines, scrollY + cursorY + 1)
            end
        elseif code == 200 then if cursorY > 1 then cursorY = cursorY - 1 elseif scrollY > 0 then scrollY = scrollY - 1 end
        elseif code == 208 then if cursorY < h - 2 and (scrollY + cursorY) < #lines then cursorY = cursorY + 1 elseif (scrollY + cursorY) < #lines then scrollY = scrollY + 1 end
        elseif code == 203 then if cursorX > 1 then cursorX = cursorX - 1 end
        elseif code == 205 then if cursorX <= unicode.len(lines[scrollY + cursorY] or "") then cursorX = cursorX + 1 end
        elseif char >= 32 then
            lines[scrollY + cursorY] = unicode.sub(lines[scrollY + cursorY] or "", 1, cursorX - 1) .. unicode.char(char) .. unicode.sub(lines[scrollY + cursorY] or "", cursorX)
            cursorX = cursorX + 1
        end
    end
end