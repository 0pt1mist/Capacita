-- Capacita Microkernel v1.0.0
local hw, boot_drive, db = ...
local index, bitmap = db.index, db.bitmap

local markov = {}
local ram_cache = {}
local cache_order = {}
local CACHE_MAX = 5
local last_accessed_uuid = nil
local index_dirty = false

local processes = {}
local pid_counter = 1
local active_pid = 1

local gpu, screen = hw.list("gpu")(), hw.list("screen")()
if gpu and screen then hw.invoke(gpu, "bind", screen) end
local w, h = 80, 25; if gpu then w, h = hw.invoke(gpu, "getResolution") end
local cy = 1

local function tty_print(txt)
    if not gpu then return end
    hw.invoke(gpu, "set", 1, cy, tostring(txt))
    cy = cy + 1
    if cy > h then
        hw.invoke(gpu, "copy", 1, 2, w, h - 1, 0, -1)
        hw.invoke(gpu, "fill", 1, h, w, 1, " ")
        cy = h
    end
end

-- СТОЛП 1 & 3: RAW SECTORS + PLASTICITY
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
        if not bitmap[i] then
            bitmap[i] = true
            table.insert(allocated, i)
            if #allocated == count then return allocated end
        end
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

    -- Столп 3: Predictive Plasticity (Markov update)
    if last_accessed_uuid and last_accessed_uuid ~= uuid then
        markov[last_accessed_uuid] = markov[last_accessed_uuid] or {}
        markov[last_accessed_uuid][uuid] = (markov[last_accessed_uuid][uuid] or 0) + 1.0
    end
    last_accessed_uuid = uuid

    -- Prefetch
    if markov[uuid] then
        local best_next, best_w = nil, 0
        for n, w in pairs(markov[uuid]) do if w > best_w then best_next=n; best_w=w end end
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
    for i, s in ipairs(secs) do
        hw.invoke(boot_drive, "writeSector", s, padded:sub((i-1)*512+1, i*512))
    end
    index_dirty = true
end

-- СТОЛП 2 & 4: CAPABILITY SECURITY + SHADOW
local function create_cap(pid, uuid, ops, shadow_record)
    local record = shadow_record or { uuid=uuid, ops=ops, revoked=false }
    local cap = {
        id = uuid,
        read = function()
            if record.revoked then return nil, "Revoked" end
            if not record.ops.read then return nil, "No read perm" end
            return read_obj_raw(uuid)
        end,
        write = function(data)
            if record.revoked then return nil, "Revoked" end
            if not record.ops.write then return nil, "No write perm" end
            write_obj_raw(uuid, data)
            return true
        end,
        forget = function()
            if record.revoked then return nil, "Revoked" end
            if not record.ops.delete then return nil, "No del perm" end
            local m = index[uuid]
            if m then
                for _, s in ipairs(m.sectors) do bitmap[s] = false end
                index[uuid] = nil
                index_dirty = true
            end
        end,
        revoke = function() record.revoked = true end
    }
    table.insert(processes[pid].shadow_caps, record)
    return cap
end

local function spawn(code, name, parent_pid, args, shadow_caps)
    local pid = pid_counter; pid_counter = pid_counter + 1
    processes[pid] = { mailbox = {}, parent = parent_pid, name = name, shadow_caps = {}, is_critical = (name == "shell") }
    
    if shadow_caps then
        for _, rec in ipairs(shadow_caps) do create_cap(pid, rec.uuid, rec.ops, rec) end
    end

    local sys_api = {
        uptime = hw.uptime, print = tty_print, clear = function() if gpu then hw.invoke(gpu, "fill",1,1,w,h," ") cy=1 end end,
        get_cy = function() return cy end, set_cy = function(y) cy = y end,
        
        recall = function(query)
            if type(query) == "string" then query = {query} end
            local results = {}
            for id, meta in pairs(index) do
                local match = true
                for _, qtag in ipairs(query) do
                    local found = false
                    for _, t in ipairs(meta.tags) do if t == qtag then found=true; break end end
                    if not found then match = false; break end
                end
                if match then table.insert(results, {id = id, tags = meta.tags}) end
            end
            return results
        end,

        request = function(uuid, ops)
            -- ядро доверяет запросам (в v2 тут будет проверка ACL/Ownership)
            return create_cap(pid, uuid, ops or {read=true})
        end,

        memorize = function(data, tags)
            local id = tostring(math.floor(hw.uptime()*1000)) .. "-" .. tostring(math.random(1000,9999))
            index[id] = { tags = tags, sectors = {}, size = 0 }
            write_obj_raw(id, data)
            return create_cap(pid, id, {read=true, write=true, delete=true})
        end,

        spawn = function(cap, child_args)
            local obj_code = cap.read()
            if not obj_code then return nil, "Cannot read capability" end
            return spawn(obj_code, "proc_"..string.sub(cap.id,1,4), pid, child_args)
        end,
        
        wait = function(t_pid) processes[pid].waiting_for = t_pid; coroutine.yield("WAIT_CHILD") end,
        receive = function(timeout) return coroutine.yield("WAIT_MSG", timeout) end,
        video = {
            set = function(x, y, txt) if gpu then hw.invoke(gpu, "set", x, y, txt) end end,
            res = function() return w, h end
        }
    }

    local safe_sys = setmetatable({}, { __index = sys_api, __newindex = function() error("SECURITY FAULT") end, __metatable = false })
    local func, err = load(code, "="..name, "t", { string=string, table=table, math=math, tostring=tostring, tonumber=tonumber, ipairs=ipairs, pairs=pairs, load=load, unicode=unicode, sys=safe_sys, args=args or {} })
    
    if not func then tty_print("Crash: "..tostring(err)); return nil end
    processes[pid].co = coroutine.create(func)
    if parent_pid then active_pid = pid end
    return pid
end

tty_print("CAPACITA KERNEL ONLINE.")

local shell_uuid
for id, meta in pairs(index) do for _, t in ipairs(meta.tags) do if t == "shell" then shell_uuid = id end end end
if not shell_uuid then error("KERNEL PANIC: NO SHELL") end

local shell_code = read_obj_raw(shell_uuid)
spawn(shell_code, "shell")

-- СТОЛП 5: IDLE CONSOLIDATION CYCLE
local idle_iterator = nil
local function do_idle_consolidation()
    if index_dirty then
        local s = "return " .. serialize({index=index, bitmap=bitmap})
        s = s .. string.rep("\0", (128 * 512) - #s)
        for i = 1, 128 do hw.invoke(boot_drive, "writeSector", i, s:sub((i-1)*512+1, i*512)) end
        index_dirty = false
        return
    end

    local prev, nexts = next(markov, idle_iterator)
    idle_iterator = prev
    if prev then
        for n, weight in pairs(nexts) do
            markov[prev][n] = weight * 0.95
            if markov[prev][n] < 0.1 then markov[prev][n] = nil end
        end
    end
end

while true do
    local e = {hw.pull(0.05)}
    if e[1] and processes[active_pid] then table.insert(processes[active_pid].mailbox, {type = "hw", data = e}) end

    for pid, proc in pairs(processes) do
        if coroutine.status(proc.co) == "dead" then
            if active_pid == pid and proc.parent then active_pid = proc.parent end
            if proc.parent and processes[proc.parent] and processes[proc.parent].waiting_for == pid then
                table.insert(processes[proc.parent].mailbox, {type = "child_exit"})
                processes[proc.parent].waiting_for = nil
            end
            processes[pid] = nil
        else
            local resume_now, msg = false, nil
            if #proc.mailbox > 0 and not proc.waiting_for then
                msg = table.remove(proc.mailbox, 1); resume_now = true
            elseif proc.timeout and hw.uptime() >= proc.timeout then
                msg = {type = "timeout"}; resume_now = true; proc.timeout = nil
            elseif not proc.waiting_for and not proc.timeout then
                msg = {type = "idle"}; resume_now = true
                do_idle_consolidation() -- СТОЛП 5
            end
            
            if resume_now then
                local ok, y_reason, t_val = coroutine.resume(proc.co, msg)
                if not ok then 
                    tty_print("PID " .. pid .. " KILLED: " .. tostring(y_reason))
                    if proc.is_critical then
                        tty_print("IMMUNE RESPONSE: Restarting " .. proc.name .. " with shadow caps.")
                        spawn(shell_code, proc.name, nil, nil, proc.shadow_caps)
                    end
                else
                    if y_reason == "WAIT_MSG" and type(t_val) == "number" then proc.timeout = hw.uptime() + t_val end
                end
            end
        end
    end
end