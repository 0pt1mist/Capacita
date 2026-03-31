if #args == 0 then 
    sys.print("Usage: mkobj <text>")
    return 
end
local text = table.concat(args, " ")
local id = sys.memorize(text, {"user_text", "note"})
sys.print("Success! Created Engram: " .. string.sub(id, 1, 8) .. "...")