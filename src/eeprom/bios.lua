-- Capacita BIOS v0.2.0
local invoke = component.invoke
local list = component.list

local saved_addr = invoke(list("eeprom")(), "getData")
local boot_addr = nil
for addr in list("filesystem") do
  if saved_addr and saved_addr ~= "" and addr:sub(1, #saved_addr) == saved_addr then
    boot_addr = addr; break
  end
end
if not boot_addr then error("BIOS: NO BOOT DRIVE") end

local function read_obj(uuid)
  local h = invoke(boot_addr, "open", uuid, "r")
  if not h then return nil end
  local b = ""
  repeat
    local c = invoke(boot_addr, "read", h, math.huge)
    b = b .. (c or "")
  until not c
  invoke(boot_addr, "close", h)
  return b
end

local index_code = read_obj("index.db")
if not index_code then error("BIOS: NO INDEX.DB") end
local index_db = load(index_code, "=index", "t", {})()

local kernel_uuid
for id, tags in pairs(index_db) do
  for _, tag in ipairs(tags) do
    if tag == "boot" then kernel_uuid = id; break end
  end
end
if not kernel_uuid then error("BIOS: NO KERNEL TAG") end

local kernel_code = read_obj(kernel_uuid)

local ObjectStore = {
  read = read_obj,
  write = function(uuid, data)
    local h = invoke(boot_addr, "open", uuid, "w")
    invoke(boot_addr, "write", h, data)
    invoke(boot_addr, "close", h)
  end
}

local safe_hw = { invoke=invoke, list=list, pull=computer.pullSignal, uptime=computer.uptime }

_G.component = nil
_G.computer = { shutdown = computer.shutdown } 

local kernel, err = load(kernel_code, "=kernel", "t", _G)
if not kernel then error("KERNEL PANIC: " .. tostring(err)) end
kernel(safe_hw, ObjectStore)