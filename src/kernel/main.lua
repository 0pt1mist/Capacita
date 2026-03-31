-- Capacita Microkernel v0.3.0 (True Multitasking & TTY)
local hw, store = ...
local index = load(store.read("index.db") or "return {}", "=index", "t", {})()

local function gen_uuid()
    math.randomseed(math.floor(hw.uptime() * 1000))
    local template ='xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
    return string.gsub(template, '[xy]', function (c)
        local v = (c=='x') and math.random(0,0xf) or math.random(8,0xb)
        return string.format('%x', v)
    end)
end

local function save_index()
    local s = "return {\n"
    for id, tags in pairs(index) do
        s = s .. "  ['"..id.."'] = {'" .. table.concat(tags, "','") .. "'},\n"
    end
    store.write("index.db", s .. "}")
end

local gpu, screen = hw.list("gpu")(), hw.list("screen")()
if gpu and screen then hw.invoke(gpu, "bind", screen) end
local w, h = hw.invoke(gpu, "getResolution")
local cy = 1

local function tty_scroll()
    hw.invoke(gpu, "copy", 1, 2, w, h - 1, 0, -1)
    hw.invoke(gpu, "fill", 1, h, w, 1, " ")
    cy = h
end

local function tty_print(txt)
    hw.invoke(gpu, "set", 1, cy, tostring(txt))
    cy = cy + 1
    if cy > h then tty_scroll() end
end

local processes = {}
local pid_counter = 1
local active_pid = 1

local function spawn(code, name, parent_pid, args)
    local pid = pid_counter
    pid_counter = pid_counter + 1
    
    local sys_api = {
        uptime = hw.uptime,
        reboot = function() hw.computer.shutdown(true) end,
        print = tty_print,
        
        get_index_raw = function() return store.read("index.db") end,
        
        commit_index_raw = function(str) 
            store.write("index.db", str)
            index = load(str, "=index", "t", {})()
        end,

        net_request = function(url)
            local inet = hw.list("internet")()
            return inet and hw.invoke(inet, "request", url) or nil
        end,
        
        net_read = function(conn_id)
            local inet = hw.list("internet")()
            return inet and hw.invoke(inet, "read", conn_id)
        end,

        recall = function(query)
            if type(query) == "string" then query = {query} end
            local results = {}
            for id, tags in pairs(index) do
                local match = true
                for _, qtag in ipairs(query) do
                    local found = false
                    for _, t in ipairs(tags) do if t == qtag then found = true; break end end
                    if not found then match = false; break end
                end
                if match then table.insert(results, {id = id, tags = tags, read = function() return store.read(id) end}) end
            end
            return results
        end,
        
        memorize = function(data, tags)
            local id = gen_uuid()
            store.write(id, data); index[id] = tags; save_index()
            return id
        end,

        spawn = function(uuid, child_args)
            local obj_code = store.read(uuid)
            if not obj_code then return nil, "Object missing" end
            return spawn(obj_code, "proc_"..string.sub(uuid,1,4), pid, child_args)
        end,

        wait = function(target_pid)
            processes[pid].waiting_for = target_pid
            coroutine.yield("WAIT_CHILD")
        end,

        receive = function(timeout) return coroutine.yield("WAIT_MSG", timeout) end,

        readln = function(prompt)
            prompt = prompt or ""
            local buf = ""
            local function redraw() hw.invoke(gpu, "set", 1, cy, prompt .. buf .. "_       ") end
            redraw()
            while true do
                local msg = coroutine.yield("WAIT_MSG")
                if msg.type == "hw" and msg.data[1] == "key_down" then
                    local char, code = msg.data[3], msg.data[4]
                    if code == 28 then 
                        tty_print(prompt .. buf)
                        return buf
                    elseif code == 14 and #buf > 0 then 
                        buf = string.sub(buf, 1, -2); redraw()
                    elseif char >= 32 and char <= 126 then
                        buf = buf .. string.char(char); redraw()
                    end
                end
            end
        end
    }
    local sandbox = { string=string, table=table, math=math, tostring=tostring, tonumber=tonumber, ipairs=ipairs, pairs=pairs, sys=sys_api, args=args or {} }
    local func, err = load(code, "="..name, "t", sandbox)
    if not func then tty_print("Crash: "..tostring(err)); return nil end
    
    processes[pid] = { co = coroutine.create(func), mailbox = {}, parent = parent_pid }
    if parent_pid then active_pid = pid end
    
    return pid
end

tty_print("KERNEL INITIALIZED. MOUNTING SHELL...")

local shell_uuid
for id, tags in pairs(index) do for _, t in ipairs(tags) do if t == "shell" then shell_uuid = id end end end
spawn(store.read(shell_uuid), "shell")

-- main loop
while true do
    local e = {hw.pull(0.05)}
    if e[1] and processes[active_pid] then
        table.insert(processes[active_pid].mailbox, {type = "hw", data = e})
    end

    for pid, proc in pairs(processes) do
        local status = coroutine.status(proc.co)
        
        if status == "dead" then
            if active_pid == pid and proc.parent then active_pid = proc.parent end
            if proc.parent and processes[proc.parent] then
                if processes[proc.parent].waiting_for == pid then
                    table.insert(processes[proc.parent].mailbox, {type = "child_exit"})
                    processes[proc.parent].waiting_for = nil
                end
            end
            processes[pid] = nil
        else
            local resume_now, msg = false, nil
            if #proc.mailbox > 0 and not proc.waiting_for then
                msg = table.remove(proc.mailbox, 1)
                resume_now = true
            elseif not proc.waiting_for then
                msg = {type = "idle"}
                resume_now = true
            end
            
            if resume_now then
                local ok, y_reason = coroutine.resume(proc.co, msg)
                
                -- watchdog
                if not ok then 
                    tty_print("PID " .. pid .. " KILLED: " .. tostring(y_reason))
                    if proc.name == "shell" then
                        tty_print("FATAL: Shell crashed! Immune response triggered.")
                        local rb_id
                        for id, tags in pairs(index) do
                            for _, t in ipairs(tags) do if t == "rollback_point" then rb_id = id end end
                        end
                        if rb_id then
                            tty_print("Rolling back index...")
                            local old_idx = store.read(rb_id)
                            local err_id = gen_uuid()
                            store.write(err_id, "CRASH: " .. tostring(y_reason))
                            
                            local safe_idx = old_idx:sub(1, -2)
                            safe_idx = safe_idx .. "['"..err_id.."'] = {'updater_error', 'log'}\n}"
                            store.write("index.db", safe_idx)
                            tty_print("Rebooting in 2s...")
                            local t = hw.uptime() + 2; while hw.uptime() < t do hw.pull(0.1) end
                            hw.computer.shutdown(true)
                        else
                            tty_print("NO ROLLBACK POINT. SYSTEM HALTED.")
                        end
                    end
                end
            end
        end
    end
end