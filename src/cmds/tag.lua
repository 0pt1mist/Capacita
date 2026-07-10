local cap = args[1]
if type(cap) ~= "table" or not cap.re_tag then 
    sys.print("Usage: tag @<target> <tag1> <tag2> ...") 
    return 
end

local new_tags = {}
for i = 2, #args do table.insert(new_tags, args[i]) end
cap.re_tag(new_tags)
sys.print("Tags updated for " .. string.sub(cap.id, 1, 8))