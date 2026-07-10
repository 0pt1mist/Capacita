local cap = args[1]
if type(cap) ~= "table" or not cap.forget then 
    sys.print("Usage: rm @<target>") 
    return 
end

local id = cap.id
cap.forget()
sys.print("Object deleted: " .. string.sub(id, 1, 8))