if #args == 0 then
    sys.print("Usage: nano <uuid or tag>")
    return
end

local target = args[1]
local w, h = sys.video.res()
local scrollY = 0
local cursorX, cursorY = 1, 1

local lines = {""}
local obj_id = nil
local is_new = false

local objs = sys.recall(target)
if #objs > 1 then
    sys.print("Multiple objects found. Use specific UUID.")
    return
elseif #objs == 1 then
    obj_id = objs[1].id
    local content = objs[1].read()
    if content and content ~= "" then
        lines = {}
        for line in string.gmatch(content.."\n", "([^\n]*)\n") do table.insert(lines, line) end
    end
else
    is_new = true
end

if #lines == 0 then lines = {""} end

local function draw()
    local title = is_new and (" Nano:[New Object] " .. target) or (" Nano: " .. string.sub(obj_id, 1, 8))
    
    sys.video.fill(1, 1, w, 1, " ")
    sys.video.set(1, 1, title)
    
    for i = 1, h-2 do
        local lineIdx = scrollY + i
        if lines[lineIdx] then
            sys.video.set(1, i+1, unicode.sub(lines[lineIdx], 1, w) .. "      ")
        else
            sys.video.fill(1, i+1, w, 1, " ")
        end
    end
    
    sys.video.fill(1, h, w, 1, " ")
    sys.video.set(1, h, "^S Save  ^X Exit  Lines: " .. #lines)
    
    local line = lines[scrollY + cursorY] or ""
    local charUnder = unicode.sub(line, cursorX, cursorX)
    if charUnder == "" then charUnder = " " end
    
    sys.video.set(cursorX, cursorY + 1, "["..charUnder.."]")
end

local function save()
    local data = table.concat(lines, "\n")
    if is_new then
        obj_id = sys.memorize(data, {"user_text", target})
        is_new = false
        objs = sys.recall(obj_id)
    else
        objs[1].write(data) 
    end
    sys.video.set(1, h, "Saved UUID: " .. string.sub(obj_id, 1, 8) .. "          ")
    sys.receive(1)
end

while true do
    draw()
    local msg = sys.receive()
    
    if msg.type == "hw" and msg.data[1] == "key_down" then
        local char, code = msg.data[3], msg.data[4]
        
        if char == 19 then
            save()
        elseif char == 24 then
            sys.clear()
            return
        elseif code == 28 then
            local line = lines[scrollY + cursorY]
            local p1 = unicode.sub(line, 1, cursorX - 1)
            local p2 = unicode.sub(line, cursorX)
            lines[scrollY + cursorY] = p1
            table.insert(lines, scrollY + cursorY + 1, p2)
            cursorY = cursorY + 1
            cursorX = 1
            if cursorY > h - 2 then
                cursorY = cursorY - 1
                scrollY = scrollY + 1
            end
        elseif code == 14 then
            if cursorX > 1 then
                local line = lines[scrollY + cursorY]
                lines[scrollY + cursorY] = unicode.sub(line, 1, cursorX - 2) .. unicode.sub(line, cursorX)
                cursorX = cursorX - 1
            elseif cursorY > 1 or scrollY > 0 then
                local current = lines[scrollY + cursorY]
                if cursorY > 1 then cursorY = cursorY - 1 else scrollY = scrollY - 1 end
                local prev = lines[scrollY + cursorY]
                cursorX = unicode.len(prev) + 1
                lines[scrollY + cursorY] = prev .. current
                table.remove(lines, scrollY + cursorY + 1)
            end
        elseif code == 200 then
            if cursorY > 1 then cursorY = cursorY - 1 elseif scrollY > 0 then scrollY = scrollY - 1 end
        elseif code == 208 then
            if cursorY < h - 2 and (scrollY + cursorY) < #lines then cursorY = cursorY + 1
            elseif (scrollY + cursorY) < #lines then scrollY = scrollY + 1 end
        elseif code == 203 then
            if cursorX > 1 then cursorX = cursorX - 1 end
        elseif code == 205 then
            local len = unicode.len(lines[scrollY + cursorY] or "")
            if cursorX <= len then cursorX = cursorX + 1 end
        elseif char >= 32 then
            local uchar = unicode.char(char)
            local line = lines[scrollY + cursorY] or ""
            lines[scrollY + cursorY] = unicode.sub(line, 1, cursorX - 1) .. uchar .. unicode.sub(line, cursorX)
            cursorX = cursorX + 1
        end
    end
end