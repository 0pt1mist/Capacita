-- Capacita Shell v0.3.0
sys.print("---------------------------------")
sys.print("CAPACITA SHELL")
sys.print("---------------------------------")

error("DED")
while true do
    local input = sys.readln("> ")
    
    local args = {}
    for word in input:gmatch("%S+") do table.insert(args, word) end
    
    if #args > 0 then
        local cmd_name = args[1]
        table.remove(args, 1)
        
        local objs = sys.recall({"cmd", cmd_name})
        
        if #objs == 0 then
            sys.print("Command not found: " .. cmd_name)
        else
            local pid = sys.spawn(objs[1].id, args)
            if pid then
                sys.wait(pid)
            end
        end
    end
end