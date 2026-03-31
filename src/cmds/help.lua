sys.print("Installed Commands:")
local cmds = sys.recall("cmd")
for _, obj in ipairs(cmds) do
    local name = ""
    for _, t in ipairs(obj.tags) do if t ~= "cmd" then name = t end end
    sys.print("  - " .. name)
end