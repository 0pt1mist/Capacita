-- Capacita Microkernel v0.6.1
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
        reboot = function() computer.shutdown(true) end,
        print = tty_print,
        
        clear = function() 
            if gpu then hw.invoke(gpu, "fill", 1, 1, w, h, " ") end
            cy = 1 
        end,
        get_cy = function() return cy end,
        set_cy = function(y) cy = y end,
        
        get_index_raw = function() return store.read("index.db") end,
        commit_index_raw = function(str) 
            store.write("index.db", str)
            index = load(str, "=index", "t", {})()
        end,

        fetch = function(path)
            local inet = hw.list("internet")()
            if not inet then return "ERR: No internet" end
            local url = "https://raw.githubusercontent.com/0pt1mist/Capacita/dev/" .. path
            
            local handle, err = hw.invoke(inet, "request", url)
            if not handle then return "ERR: " .. tostring(err) end
            
            while true do
                local ok, res = pcall(function() return handle.finishConnect() end)
                if not ok then return "ERR: Connect crashed" end
                if res == true then break end
                if res == nil then return "ERR: Connect failed" end
                coroutine.yield("WAIT_MSG", 0.05)
            end
            
            local result = ""
            while true do
                coroutine.yield("WAIT_MSG", 0.05)
                local ok, chunk = pcall(function() return handle.read(4096) end)
                
                if not ok then 
                    pcall(function() handle.close() end)
                    return "ERR: Read failed" 
                end
                
                if chunk == "" then
                elseif chunk then result = result .. chunk
                else break end
            end
            
            pcall(function() handle.close() end)
            if string.match(result, "404: Not Found") then return "ERR: 404" end
            return result
        end,

        flash_bios = function(code)
            local eeprom = hw.list("eeprom")()
            if eeprom then hw.invoke(eeprom, "set", code); return true end
            return false
        end,

        recall = function(query)
            if type(query) == "string" then query = {query} end
            local results = {}
            for id, tags in pairs(index) do
                local is_uuid = (query[1] == id or string.sub(id, 1, #query[1]) == query[1])
                local match = true
                if not is_uuid then
                    for _, qtag in ipairs(query) do
                        local found = false
                        for _, t in ipairs(tags) do if t == qtag then found = true; break end end
                        if not found then match = false; break end
                    end
                end
                if is_uuid or match then 
                    table.insert(results, {id = id, tags = tags, read = function() return store.read(id) end, write = function(data) store.write(id, data) end}) 
                end
            end
            return results
        end,

        forget = function(id)
            if index[id] then
                index[id] = nil
                save_index()
                store.remove(id)
                return true
            end
            return false
        end,

        re_tag = function(id, new_tags)
            if index[id] then
                index[id] = new_tags
                save_index()
                return true
            end
            return false
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
        
        video = {
            bind = function() if gpu and screen then hw.invoke(gpu, "bind", screen) end end,
            set = function(x, y, txt) if gpu then hw.invoke(gpu, "set", x, y, txt) end end,
            fill = function(x, y, w, h, ch) if gpu then hw.invoke(gpu, "fill", x, y, w, h, ch) end end,
            res = function() if gpu then return hw.invoke(gpu, "getResolution") else return 80, 25 end end
        }
    }

    local safe_sys = setmetatable({}, {
        __index = sys_api,
        __newindex = function() error("SECURITY FAULT: Kernel API is read-only!") end,
        __metatable = false
    })

    local sandbox = { 
        string=string, table=table, math=math, tostring=tostring, 
        tonumber=tonumber, ipairs=ipairs, pairs=pairs, 
        load=load, unicode=unicode, 
        sys=safe_sys, args=args or {} 
    }
    
    local func, err = load(code, "="..name, "t", sandbox)
    if not func then tty_print("Crash: "..tostring(err)); return nil end
    
    processes[pid] = { co = coroutine.create(func), mailbox = {}, parent = parent_pid, name = name }
    if parent_pid then active_pid = pid end
    
    return pid
end

tty_print("CAPACITA KERNEL ONLINE. IMMUNE SYSTEM ACTIVE.")

local shell_uuid
for id, tags in pairs(index) do for _, t in ipairs(tags) do if t == "shell" then shell_uuid = id end end end
if not shell_uuid then error("KERNEL PANIC: NO SHELL") end

spawn(store.read(shell_uuid), "shell")

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
            elseif proc.timeout and hw.uptime() >= proc.timeout then
                msg = {type = "timeout"}
                resume_now = true
                proc.timeout = nil
            elseif not proc.waiting_for and not proc.timeout then
                msg = {type = "idle"}
                resume_now = true
            end
            
            if resume_now then
                local ok, y_reason, t_val = coroutine.resume(proc.co, msg)
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
                            safe_idx = safe_idx .. "  ['"..err_id.."'] = {'updater_error', 'log'}\n}"
                            store.write("index.db", safe_idx)
                            tty_print("Rebooting in 2s...")
                            local t = hw.uptime() + 2; while hw.uptime() < t do hw.pull(0.1) end
                            computer.shutdown(true)
                        else
                            tty_print("NO ROLLBACK POINT. SYSTEM HALTED.")
                        end
                    end
                else
                    if y_reason == "WAIT_MSG" and type(t_val) == "number" then
                        proc.timeout = hw.uptime() + t_val
                    end
                end
            end
        end
    end
end