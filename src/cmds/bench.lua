local count = 500

if sys then
    -- ==========================================
    -- CAPACITA OS MODE (Semantic FS)
    -- ==========================================
    sys.print("--- Capacita OS Benchmark ---")
    sys.print("Stressing Semantic FS...")

    local start = sys.uptime()
    local ids = {}

    for i = 1, count do
        local id = sys.memorize("bench data " .. i, {"bench", "obj_"..i})
        table.insert(ids, id)
        if i % 100 == 0 then sys.print("Written " .. i .. " objects...") end
    end
    local mid = sys.uptime()

    for _, id in ipairs(ids) do
        sys.forget(id)
    end
    local finish = sys.uptime()

    sys.print("-----------------------------")
    sys.print("Write 500 objects: " .. string.format("%.2f", mid - start) .. "s")
    sys.print("Delete 500 objects: " .. string.format("%.2f", finish - mid) .. "s")
    sys.print("Total Score: "       .. string.format("%.2f", finish - start) .. "s")

else
    -- ==========================================
    -- OPENOS / MINEOS MODE (Hierarchical FS)
    -- ==========================================
    local fs = require("filesystem")
    local computer = require("computer")
    
    print("--- OpenOS/MineOS Benchmark ---")
    print("Stressing Hierarchical FS...")

    local dir = "/home/bench_test/"
    fs.makeDirectory(dir)

    local start = computer.uptime()

    for i = 1, count do
        local f = io.open(dir .. "obj_" .. i .. ".txt", "w")
        f:write("bench data " .. i)
        f:close()
        if i % 100 == 0 then print("Written " .. i .. " files...") end
    end
    local mid = computer.uptime()

    for i = 1, count do
        fs.remove(dir .. "obj_" .. i .. ".txt")
    end
    fs.remove(dir)
    local finish = computer.uptime()

    print("-----------------------------")
    print("Write 500 files:  " .. string.format("%.2f", mid - start) .. "s")
    print("Delete 500 files: " .. string.format("%.2f", finish - mid) .. "s")
    print("Total Score: "      .. string.format("%.2f", finish - start) .. "s")
end