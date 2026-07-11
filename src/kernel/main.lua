-- Capacita Microkernel v1.2.0 (Security & Integrity Fixes)
local hw, boot_drive, db = ...
local index, bitmap = db.index, db.bitmap
local system_uuids = db.system_uuids or {}
local kernel_id = db.kernel_id

local system_uuid_set = {}
for _, id in pairs(system_uuids) do system_uuid_set[id] = true end

local markov, ram_cache, cache_order = {}, {}, {}
local CACHE_MAX = 5
local last_accessed_uuid = nil
local index_dirty = false
local processes, pid_counter, active_pid = {}, 1, 1
local idle_iterator = nil 

math.randomseed(os.time())
local boot_salt = tostring(os.time()) .. "-" .. tostring(math.random(100000, 999999))
local id_counter = 0
local function new_id()
    id_counter = id_counter + 1
    return boot_salt .. "-" .. id_counter
end

local gpu, screen = hw.list("gpu")(), hw.list("screen")()
if gpu and screen then hw.invoke(gpu, "bind", screen) end
local w, h = 80, 25; if gpu then w, h = hw.invoke(gpu, "getResolution") end
local cy = 1

local function tty_print(txt)
    if not gpu then return end
    hw.invoke(gpu, "set", 1, cy, tostring(txt))
    cy = cy + 1
    if cy > h then hw.invoke(gpu, "copy", 1, 2, w, h - 1, 0, -1); hw.invoke(gpu, "fill", 1, h, w, 1, " "); cy = h end
end

local function serialize(v)
    if type(v) == "number" or type(v) == "boolean" then return tostring(v)
    elseif type(v) == "string" then return string.format("%q", v)
    elseif type(v) == "table" then
        local t = {}
        for k, val in pairs(v) do table.insert(t, "["..serialize(k).."]="..serialize(val)) end
        return "{"..table.concat(t, ",").."}"
    end
end

local function alloc_sectors(size)
    local count = math.ceil(size / 512)
    local allocated = {}
    local total_sectors = math.floor((hw.invoke(boot_drive, "getCapacity") or 1048576) / 512)
    for i = 129, total_sectors do
        if not bitmap[i] then bitmap[i] = true; table.insert(allocated, i); if #allocated == count then return allocated end end
    end
    error("Out of disk space")
end

local function read_obj_raw(uuid)
    if ram_cache[uuid] then return ram_cache[uuid] end
    local meta = index[uuid]
    if not meta then return nil end
    local b = ""
    for _, sec in ipairs(meta.sectors) do b = b .. hw.invoke(boot_drive, "readSector", sec) end
    local data = b:sub(1, meta.size)

    if last_accessed_uuid and last_accessed_uuid ~= uuid then
        markov[last_accessed_uuid] = markov[last_accessed_uuid] or {}
        markov[last_accessed_uuid][uuid] = (markov[last_accessed_uuid][uuid] or 0) + 1.0
    end
    last_accessed_uuid = uuid

    if markov[uuid] then
        local best_next, best_w = nil, 0
        for n, wt in pairs(markov[uuid]) do if wt > best_w then best_next=n; best_w=wt end end
        if best_next and best_w >= 2.0 and not ram_cache[best_next] then
            local pmeta = index[best_next]
            if pmeta then
                local pb = ""
                for _, sec in ipairs(pmeta.sectors) do pb = pb .. hw.invoke(boot_drive, "readSector", sec) end
                ram_cache[best_next] = pb:sub(1, pmeta.size)
                table.insert(cache_order, best_next)
                if #cache_order > CACHE_MAX then ram_cache[table.remove(cache_order, 1)] = nil end
            end
        end
    end
    return data
end

local function write_obj_raw(uuid, data)
    local meta = index[uuid]
    if meta then for _, s in ipairs(meta.sectors) do bitmap[s] = false end end
    local secs = alloc_sectors(#data)
    index[uuid] = { tags = meta and meta.tags or {}, sectors = secs, size = #data }
    local padded = data .. string.rep("\0", (#secs * 512) - #data)
    for i, s in ipairs(secs) do hw.invoke(boot_drive, "writeSector", s, padded:sub((i-1)*512+1, i*512)) end
    index_dirty = true
end

local function create_cap(pid, uuid, ops, shadow_record)
    local record = shadow_record or { uuid=uuid, ops=ops, revoked=false }
    local cap = {
        id = uuid,
        read = function() if record.revoked or not record.ops.read then return nil end; return read_obj_raw(uuid) end,
        write = function(data) if record.revoked or not record.ops.write then return false end; write_obj_raw(uuid, data); return true end,
        forget = function() if record.revoked or not record.ops.delete then return false end
            local m = index[uuid]
            if m then for _, s in ipairs(m.sectors) do bitmap[s] = false end; index[uuid] = nil; index_dirty = true; return true end
        end,
        revoke = function() record.revoked = true end,
        re_tag = function(tags) if record.revoked or not record.ops.write then return false end; index[uuid].tags = tags; index_dirty = true; return true end,
        get_tags = function() return index[uuid] and index[uuid].tags or {} end
    }

    if processes[pid] then
        table.insert(processes[pid].shadow_caps, record)
    end

    return cap
end

local function do_idle_consolidation()
    if index_dirty then
        local s = "return " .. serialize({index=index, bitmap=bitmap, system_uuids=system_uuids, kernel_id=kernel_id})
        if #s > 128 * 512 then
            tty_print("WARN: boot index too large to persist (" .. #s .. " bytes) - changes since last save are unsaved!")
            return false
        end
        s = s .. string.rep("\0", (128 * 512) - #s)
        for i = 1, 128 do hw.invoke(boot_drive, "writeSector", i, s:sub((i-1)*512+1, i*512)) end
        index_dirty = false; return true
    end
    return false
end

local function spawn_internal(exe_cap, code, name, parent_pid, args, shadow_caps)
    local pid = pid_counter; pid_counter = pid_counter + 1

    local is_system = exe_cap and exe_cap.id and system_uuid_set[exe_cap.id] == true
    local is_shell = exe_cap and exe_cap.id and exe_cap.id == system_uuids.shell

    processes[pid] = { mailbox = {}, parent = parent_pid, name = name, shadow_caps = {}, is_critical = is_shell, crashes = 0 }
    if shadow_caps then for _, rec in ipairs(shadow_caps) do create_cap(pid, rec.uuid, rec.ops, rec) end end

    local sys_api = {
        uptime = hw.uptime, print = tty_print, clear = function() if gpu then hw.invoke(gpu, "fill",1,1,w,h," ") cy=1 end end,
        get_cy = function() return cy end, set_cy = function(y) cy = y end,

        recall = function(query)
            if type(query) == "string" then query = {query} end
            local results = {}
            for id, meta in pairs(index) do
                local match = true
                local is_uuid = (id:sub(1, #query[1]) == query[1])
                if not is_uuid then
                    for _, qtag in ipairs(query) do
                        local found = false
                        for _, t in ipairs(meta.tags) do if t == qtag then found=true; break end end
                        if not found then match = false; break end
                    end
                end
                if match or is_uuid then table.insert(results, {id = id, tags = meta.tags}) end
            end
            return results
        end,

        memorize = function(data, tags)
            local id = new_id()
            index[id] = { tags = tags, sectors = {}, size = 0 }
            write_obj_raw(id, data)
            return create_cap(pid, id, {read=true, write=true, delete=true})
        end,

        spawn = function(child_exe_cap, child_args)
            if type(child_exe_cap) ~= "table" or not child_exe_cap.read then return nil, "Expected capability" end
            local c_code = child_exe_cap.read()
            if not c_code then return nil, "Cannot read executable" end
            return spawn_internal(child_exe_cap, c_code, "proc_"..string.sub(child_exe_cap.id,1,4), pid, child_args)
        end,

        wait = function(t_pid) processes[pid].waiting_for = t_pid; coroutine.yield("WAIT_CHILD") end,
        receive = function(timeout) return coroutine.yield("WAIT_MSG", timeout) end,
        video = { set = function(x, y, txt) if gpu then hw.invoke(gpu, "set", x, y, txt) end end, res = function() return w, h end }
    }

    -- ИНЖЕКЦИЯ ПРИВИЛЕГИРОВАННЫХ ФУНКЦИЙ (Только для системных)
    if is_system then
        sys_api.request = function(uuid, ops) return create_cap(pid, uuid, ops or {read=true, write=true, delete=true}) end
        sys_api.fetch = function(path)
            local inet = hw.list("internet")()
            if not inet then return "ERR: No internet" end
            local handle = hw.invoke(inet, "request", "https://raw.githubusercontent.com/0pt1mist/Capacita/feature-raw-sectors/" .. path)
            while true do
                local ok, res = pcall(function() return handle.finishConnect() end)
                if res == true then break elseif res == nil then return "ERR: Connect failed" end
                coroutine.yield("WAIT_MSG", 0.05)
            end
            local result = ""
            while true do
                coroutine.yield("WAIT_MSG", 0.05)
                local ok, chunk = pcall(function() return handle.read(4096) end)
                if not ok then return "ERR: Read failed" end
                if chunk == "" then elseif chunk then result = result .. chunk else break end
            end
            pcall(function() handle.close() end)
            return result
        end
        sys_api.flash_bios = function(bcode) local eeprom = hw.list("eeprom")(); if eeprom then hw.invoke(eeprom, "set", bcode); return true end; return false end
        sys_api.snapshot = function(tags) local s = "return " .. serialize({index=index, bitmap=bitmap, system_uuids=system_uuids, kernel_id=kernel_id}); local cap = sys_api.memorize(s, tags); return cap.id end
        sys_api.restore = function(uuid)
            local cap = create_cap(pid, uuid, {read=true})
            local data = cap.read()
            local ok, db_snap = pcall(function() return load(data, "=snap", "t", {})() end)
            if ok and db_snap.index then index = db_snap.index; bitmap = db_snap.bitmap; index_dirty = true; do_idle_consolidation(); return true end
            return false
        end
        sys_api.reboot = function() _G.computer.shutdown(true) end
    end

    -- SECURITY FIX: build the process's restricted environment as a named
    -- table FIRST, then hand it a wrapped `load` that defaults to ITSELF.
    -- Lua's real `load(chunk)` (no 4th arg) falls back to the single
    -- VM-global environment -- which, in this kernel, is the exact same
    -- `_G` the kernel itself runs under (see bios.lua's `load(k_str,
    -- "=kernel", "t", _G)`). Handing the raw builtin to sandboxed process
    -- code meant any process could do `load("return _G")()` and read/write
    -- globals the kernel itself depends on -- a full sandbox escape and a
    -- way for one crashing/misbehaving process to corrupt every other
    -- process (and the kernel), which is exactly what "isolated actors"
    -- (Pillar 4) is supposed to prevent.
    local safe_sys = setmetatable({}, { __index = sys_api, __newindex = function() error("SEC_FAULT") end, __metatable = false })
    local proc_env = { string=string, table=table, math=math, tostring=tostring, tonumber=tonumber, ipairs=ipairs, pairs=pairs, type=type, unicode=unicode, sys=safe_sys, args=args or {} }
    proc_env.load = function(chunk, chunkname, mode, env)
        return load(chunk, chunkname, mode, env or proc_env)
    end

    local func, err = load(code, "="..name, "t", proc_env)

    if not func then tty_print("Crash: "..tostring(err)); return nil end
    processes[pid].co = coroutine.create(func); if parent_pid then active_pid = pid end
    return pid
end

tty_print("CAPACITA KERNEL ONLINE. CAPABILITY ENFORCED.")
local shell_uuid = system_uuids.shell
if shell_uuid and index[shell_uuid] then
    spawn_internal(create_cap(0, shell_uuid, {read=true}), read_obj_raw(shell_uuid), "shell")
else
    error("NO SHELL (db.system_uuids.shell missing or its sectors not found -- reinstall)")
end

while true do
    local e = {hw.pull(0.05)}
    if e[1] and processes[active_pid] then table.insert(processes[active_pid].mailbox, {type = "hw", data = e}) end

    for pid, proc in pairs(processes) do
        if coroutine.status(proc.co) == "dead" then
            if active_pid == pid and proc.parent then active_pid = proc.parent end
            if proc.parent and processes[proc.parent] and processes[proc.parent].waiting_for == pid then
                table.insert(processes[proc.parent].mailbox, {type = "child_exit"}); processes[proc.parent].waiting_for = nil
            end
            processes[pid] = nil
        else
            local resume_now, msg = false, nil
            if #proc.mailbox > 0 and not proc.waiting_for then msg = table.remove(proc.mailbox, 1); resume_now = true
            elseif proc.timeout and hw.uptime() >= proc.timeout then msg = {type = "timeout"}; resume_now = true; proc.timeout = nil
            elseif not proc.waiting_for and not proc.timeout then
                msg = {type = "idle"}; resume_now = true
                if not do_idle_consolidation() then
                    local p, n = next(markov, idle_iterator); idle_iterator = p
                    if p then for nx, wt in pairs(n) do n[nx] = wt * 0.95; if n[nx] < 0.1 then n[nx] = nil end end end
                end
            end

            if resume_now then
                local ok, y_reason, t_val = coroutine.resume(proc.co, msg)
                if not ok then
                    tty_print("PID " .. pid .. " KILLED: " .. tostring(y_reason))
                    if proc.is_critical then
                        proc.crashes = proc.crashes + 1
                        local crash_id = new_id()
                        local crash_msg = "CRASH in " .. proc.name .. ": " .. tostring(y_reason)
                        index[crash_id] = { tags = {"updater_error", "log"}, sectors = {}, size = 0 }
                        write_obj_raw(crash_id, crash_msg)

                        if proc.crashes >= 3 then
                            tty_print("FATAL: Auto-rolling back...")
                            local rbs = {}
                            for id, m in pairs(index) do for _, t in ipairs(m.tags) do if t == "rollback_point" then table.insert(rbs, id) end end end
                            if #rbs > 0 then
                                local snap_b = ""
                                for _, sec in ipairs(index[rbs[1]].sectors) do snap_b = snap_b .. hw.invoke(boot_drive, "readSector", sec) end
                                local ok_s, db_s = pcall(function() return load(snap_b:sub(1, index[rbs[1]].size), "=s", "t", {})() end)
                                if ok_s and db_s.index then index = db_s.index; bitmap = db_s.bitmap; index_dirty = true; do_idle_consolidation() end
                                hw.pull(1); _G.computer.shutdown(true)
                            else tty_print("NO ROLLBACK POINT. HALTED.") end
                        else
                            tty_print("IMMUNE RESPONSE: Restarting...")
                            local npid = spawn_internal(create_cap(0, shell_uuid, {read=true}), read_obj_raw(shell_uuid), proc.name, nil, nil, proc.shadow_caps)
                            if npid then processes[npid].crashes = proc.crashes end
                        end
                    end
                else
                    if y_reason == "WAIT_MSG" and type(t_val) == "number" then proc.timeout = hw.uptime() + t_val end
                end
            end
        end
    end
end
