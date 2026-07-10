local count = 250 -- Оптимально для тестов в сырых секторах

if sys then
    sys.print("--- Capacita OS Benchmark ---")
    sys.print("Stressing Raw Sectors + Semantic DB...")

    local start = sys.uptime()
    local caps = {}

    for i = 1, count do
        -- memorize возвращает Capability, которую мы можем использовать
        local cap = sys.memorize("bench data " .. i, {"bench", "obj_"..i})
        table.insert(caps, cap)
        
        if i % 25 == 0 then 
            sys.print("Written " .. i .. " objects...")
            sys.receive(0) -- Важно: yield чтобы не упасть по таймауту OpenComputers!
        end
    end
    local mid = sys.uptime()

    for i, cap in ipairs(caps) do
        cap.forget()
        if i % 25 == 0 then sys.receive(0) end -- yield
    end
    local finish = sys.uptime()

    sys.print("-----------------------------")
    sys.print("Write " .. count .. " objs: " .. string.format("%.2f", mid - start) .. "s")
    sys.print("Delete " .. count .. " objs: " .. string.format("%.2f", finish - mid) .. "s")
    sys.print("Total Score: "       .. string.format("%.2f", finish - start) .. "s")

else
    -- OpenOS ветка (для сравнения)
    local fs = require("filesystem")
    local computer = require("computer")
    print("--- OpenOS Benchmark ---")
    
    local dir = "/home/bench_test/"
    fs.makeDirectory(dir)
    local start = computer.uptime()

    for i = 1, count do
        local f = io.open(dir .. "obj_" .. i .. ".txt", "w")
        f:write("bench data " .. i); f:close()
        if i % 25 == 0 then os.sleep(0) end
    end
    local mid = computer.uptime()

    for i = 1, count do
        fs.remove(dir .. "obj_" .. i .. ".txt")
        if i % 25 == 0 then os.sleep(0) end
    end
    fs.remove(dir)
    local finish = computer.uptime()

    print("Total Score: " .. string.format("%.2f", finish - start) .. "s")
end