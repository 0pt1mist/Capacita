-- Capacita Kernel v0.1
local hw, store = ...

-- TTY
local gpu = hw.list("gpu")()
local screen = hw.list("screen")()
if gpu and screen then hw.invoke(gpu, "bind", screen) end

local w, h = hw.invoke(gpu, "getResolution")
local cursor_y = 1

local function kprint(text)
  hw.invoke(gpu, "set", 1, cursor_y, tostring(text) .. "                               ")
  cursor_y = cursor_y + 1
  if cursor_y > h then cursor_y = h end
end

kprint("CAPACITA KERNEL ONLINE.")
kprint("Hardware locked. Scanning Engrams...")

local index_data = store.read("index.db")
local shell_uuid = string.match(index_data, "shell=([%w%-]+)")

if not shell_uuid then error("NO SHELL ENGRAM FOUND") end

kprint("Shell Engram found: " .. shell_uuid)
local shell_code = store.read(shell_uuid)

local sys_api = {
  print = kprint,
  
  -- FTS
  readln = function()
    local buf = ""
    while true do
      local sig, _, _, char, code = hw.pull()
      if sig == "key_down" then
        if code == 28 then return buf end -- Enter
        if code == 14 and #buf > 0 then -- Backspace
          buf = string.sub(buf, 1, -2)
        elseif char >= 32 and char <= 126 then
          buf = buf .. string.char(char)
        end
        hw.invoke(gpu, "set", 1, cursor_y, "> " .. buf .. "_  ")
      end
    end
  end,

  recall = function(tag)
    -- Dummy
    return "Dummy data for tag: " .. tag
  end
}

local sandbox = {
  tostring = tostring, tonumber = tonumber,
  string = string, table = table, math = math,
  sys = sys_api
}

kprint("Spawning Shell process...")
cursor_y = cursor_y + 1

local process, err = load(shell_code, "=shell", "t", sandbox)
if not process then 
  kprint("Shell crash: " .. tostring(err))
  while true do hw.pull(1) end
end

pcall(process)

kprint("System halted.")
while true do hw.pull(1) end