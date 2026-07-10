if #args == 0 then sys.print("Usage: mkobj <text> [#tag1 #tag2]"); return end
local text_parts, tags = {}, {}
for _, w in ipairs(args) do
    if string.sub(w, 1, 1) == "#" then table.insert(tags, string.sub(w, 2)) else table.insert(text_parts, w) end
end
if #tags == 0 then tags = {"user_text"} end

local text = table.concat(text_parts, " ")
local cap = sys.memorize(text, tags)
sys.print("Engram created: " .. string.sub(cap.id, 1, 8) .. " | Tags: " .. table.concat(tags, ", "))