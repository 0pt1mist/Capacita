sys.print("--- Capacita OS Benchmark ---")
sys.print("Stressing Semantic FS...")

local start = sys.uptime()
local ids = {}

for i = 1, 500 do
    local id = sys.memorize("bench data " .. i, {"bench_test", "obj_"..i})
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
sys.print("Total Score: " .. string.format("%.2f", finish - start) .. "s")