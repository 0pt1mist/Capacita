if #args == 0 then
    sys.print("Usage: update <all | pkg1,pkg2>")
    return
end

sys.print("Syncing packages.index...")
local idx_str = sys.fetch("packages.index")
if string.sub(idx_str, 1, 3) == "ERR" then
    sys.print("Sync failed: " .. idx_str)
    return
end

local pkg_db = load(idx_str, "=pkg", "t", {})()

local targets = {}
if args[1] == "all" then
    for k, _ in pairs(pkg_db) do targets[k] = true end
else
    local joined = table.concat(args, "")
    for w in string.gmatch(joined, "[^,]+") do
        if pkg_db[w] then targets[w] = true else sys.print("Unknown package: " .. w) end
    end
end

local updates = {}
local count = 0
for k, _ in pairs(targets) do
    sys.print("Fetching " .. k .. "...")
    local code = sys.fetch(pkg_db[k].path)
    if string.sub(code, 1, 3) == "ERR" then
        sys.print("Failed to fetch " .. k .. ": " .. code)
    else
        updates[k] = code
        count = count + 1
    end
end

if count == 0 then sys.print("Nothing to update."); return end
sys.print("Applying updates...")

if updates.bios then
    sys.flash_bios(updates.bios)
    updates.bios = nil
end

local raw_idx = sys.get_index_raw()
local idx = load(raw_idx, "=idx", "t", {})()

local rb_id = sys.memorize(raw_idx, {"system", "rollback_point"})
idx[rb_id] = {"system", "rollback_point"}

local needs_reboot = false

for pkg_name, code in pairs(updates) do
    local p_tags = pkg_db[pkg_name].tags
    
    for id, e_tags in pairs(idx) do
        local overlap = false
        for _, t in ipairs(e_tags) do
            for _, pt in ipairs(p_tags) do if t == pt then overlap = true end end
        end
        if overlap then
            for i, t in ipairs(e_tags) do e_tags[i] = "old_" .. t end
        end
    end
    
    local new_id = sys.memorize(code, p_tags)
    idx[new_id] = p_tags
    
    if pkg_name == "kernel" or pkg_name == "shell" then needs_reboot = true end
end

local s = "return {\n"
for id, tags in pairs(idx) do
    s = s .. "  ['"..id.."'] = {'" .. table.concat(tags, "','") .. "'},\n"
end
sys.commit_index_raw(s .. "}")

sys.print("Successfully updated " .. count .. " components.")
if needs_reboot then
    sys.print("Core components updated. Rebooting...")
    local t = sys.uptime() + 2; while sys.uptime() < t do sys.receive(0.1) end
    sys.reboot()
end