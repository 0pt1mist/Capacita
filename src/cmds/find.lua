if #args == 0 then
    sys.print("Usage: find <tag or UUID>")
    return
end

local tag = args[1]
sys.print("Searching for: " .. tag)
local objects = sys.recall(tag)

if #objects == 0 then
    sys.print("No engrams found.")
else
    sys.print("Found " .. #objects .. " objects:")
    for i, obj in ipairs(objects) do
        sys.print("  UUID: " .. string.sub(obj.id, 1, 8) .. "... | Tags: " .. table.concat(obj.tags, ", "))
    end
end