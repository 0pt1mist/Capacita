if #args == 0 then sys.print("Usage: update <all | pkg1,pkg2>"); return end
sys.print("Syncing packages.index...")
local idx_str = sys.fetch("packages.index")
if string.sub(idx_str, 1, 3) == "ERR" then sys.print("Sync failed: " .. idx_str); return end

local pkg_db = load(idx_str, "=pkg", "t", {})()
local targets = {}
if args[1] == "all" then for k, _ in pairs(pkg_db) do targets[k] = true end
else
    for w in string.gmatch(table.concat(args, ""), "[^,]+") do
        if pkg_db[w] then targets[w] = true else sys.print("Unknown package: " .. w) end
    end
end

local updates, count = {}, 0
for k, _ in pairs(targets) do
    sys.print("Fetching " .. k .. "...")
    local code = sys.fetch(pkg_db[k].path)
    if string.sub(code, 1, 3) == "ERR" then sys.print("Failed: " .. code)
    else updates[k] = code; count = count + 1 end
end

if count == 0 then sys.print("Nothing to update."); return end
sys.print("Applying updates...")
if updates.bios then sys.flash_bios(updates.bios); updates.bios = nil end

sys.print("Creating system snapshot...")
sys.snapshot({"system", "rollback_point"})

local needs_reboot = false
for pkg_name, code in pairs(updates) do
    local p_tags = pkg_db[pkg_name].tags
    for _, pt in ipairs(p_tags) do
        local old_objs = sys.recall(pt)
        for _, obj in ipairs(old_objs) do
            local cap = sys.request(obj.id, {write=true})
            local updated_tags = {}
            for _, t in ipairs(cap.get_tags()) do table.insert(updated_tags, "old_" .. t) end
            cap.re_tag(updated_tags)
        end
    end
    sys.memorize(code, p_tags)
    if pkg_name == "kernel" or pkg_name == "shell" then needs_reboot = true end
end

sys.print("Updated " .. count .. " components.")
if needs_reboot then
    sys.print("Rebooting..."); local t = sys.uptime() + 2; while sys.uptime() < t do sys.receive(0.1) end; sys.reboot()
end