sys.print("--- Capacita Updater ---")

local targets = {}
if #args == 0 or args[1] == "all" then
    targets = {kernel=true, shell=true, cmds=true, bios=true}
    sys.print("Target: ALL components")
else
    local joined = table.concat(args, ",")
    for t in string.gmatch(joined, "[^,%s]+") do
        targets[t] = true
    end
    sys.print("Target: " .. joined)
end

local updates = {}

if targets.bios then
    sys.print("Fetching BIOS...")
    local code = sys.fetch("src/eeprom/bios.lua")
    if code:sub(1,3) == "ERR" then sys.print("Failed!"); return end
    updates.bios = code
end

if targets.kernel then
    sys.print("Fetching Kernel...")
    local code = sys.fetch("src/kernel/main.lua")
    if code:sub(1,3) == "ERR" then sys.print("Failed!"); return end
    updates.kernel = code
end

if targets.shell then
    sys.print("Fetching Shell...")
    local code = sys.fetch("src/system/shell.lua")
    if code:sub(1,3) == "ERR" then sys.print("Failed!"); return end
    updates.shell = code
end

if targets.cmds then
    updates.cmds = {}
    local cmd_list = {"help", "echo", "mkobj", "update", "rollback", "errors"}
    for _, c in ipairs(cmd_list) do
        sys.print("Fetching cmd: " .. c)
        local code = sys.fetch("src/cmds/" .. c .. ".lua")
        if code:sub(1,3) == "ERR" then sys.print("Failed: " .. c); return end
        updates.cmds[c] = code
    end
end

local count = 0
for _ in pairs(updates) do count = count + 1 end
if count == 0 then
    sys.print("Nothing to update.")
    return
end

sys.print("Applying updates...")

if updates.bios then
    sys.print("Flashing EEPROM...")
    sys.flash_bios(updates.bios)
end

if updates.kernel or updates.shell or updates.cmds then
    local raw_idx = sys.get_index_raw()
    local idx = load(raw_idx, "=idx", "t", {})()
    
    local rb_id = sys.memorize(raw_idx, {"system", "rollback_point"})
    idx[rb_id] = {"system", "rollback_point"}
    
    if updates.kernel then
        for id, tags in pairs(idx) do
            for i, t in ipairs(tags) do if t == "kernel" then tags[i] = "old_kernel" end end
        end
        local id = sys.memorize(updates.kernel, {"boot", "kernel"})
        idx[id] = {"boot", "kernel"}
    end
    
    if updates.shell then
        for id, tags in pairs(idx) do
            for i, t in ipairs(tags) do if t == "shell" then tags[i] = "old_shell" end end
        end
        local id = sys.memorize(updates.shell, {"system", "shell"})
        idx[id] = {"system", "shell"}
    end
    
    if updates.cmds then
        for id, tags in pairs(idx) do
            for i, t in ipairs(tags) do if t == "cmd" then tags[i] = "old_cmd" end end
        end
        for c, code in pairs(updates.cmds) do
            local id = sys.memorize(code, {"cmd", c})
            idx[id] = {"cmd", c}
        end
    end
    
    local function serialize_index(i_tbl)
        local s = "return {\n"
        for id, tags in pairs(i_tbl) do
            s = s .. "  ['"..id.."'] = {'" .. table.concat(tags, "','") .. "'},\n"
        end
        return s .. "}"
    end
    
    sys.commit_index_raw(serialize_index(idx))
end

sys.print("Update complete! Rebooting...")
local t = sys.uptime() + 2; while sys.uptime() < t do sys.receive(0.1) end
sys.reboot()