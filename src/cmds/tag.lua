if #args < 2 then sys.print("Usage: tag <uuid> <tag1> <tag2> ..."); return end
local target = args[1]
local objs = sys.recall(target)

if #objs ~= 1 then sys.print("Please provide exactly one valid UUID."); return end

local new_tags = {}
for i = 2, #args do table.insert(new_tags, args[i]) end
sys.re_tag(objs[1].id, new_tags)
sys.print("Tags updated for " .. string.sub(objs[1].id, 1, 8))