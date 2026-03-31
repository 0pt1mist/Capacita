if #args == 0 then sys.print("Usage: nano <uuid/tag>"); return end
local objs = sys.recall(args[1])
if #objs ~= 1 then sys.print("Target must resolve to exactly ONE object. Use UUID."); return end

local obj = objs[1]
sys.print("--- EDITING: " .. string.sub(obj.id, 1, 8) .. " ---")
local content = obj.read()

sys.print("Current content:")
sys.print(content)
sys.print("--------------------")
sys.print("Type new content. Type ':wq' on a new line to save and exit.")

local new_content = ""
while true do
    local line = sys.readln("")
    if line == ":wq" then break end
    new_content = new_content .. line .. "\n"
end

obj.write(new_content)
sys.print("Object saved.")