if #args == 0 then sys.print("Usage: rm <uuid/tag>"); return end
local target = args[1]
local objs = sys.recall(target)

if #objs == 0 then sys.print("Not found.") return end
if #objs > 1 then 
    sys.print("Multiple objects found ("..#objs.."). Be specific and use UUID:")
    for _, o in ipairs(objs) do sys.print("  " .. string.sub(o.id, 1, 8) .. " (" .. table.concat(o.tags, ", ") .. ")") end
    return 
end

sys.forget(objs[1].id)
sys.print("Object deleted: " .. string.sub(objs[1].id, 1, 8))