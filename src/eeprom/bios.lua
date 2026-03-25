-- Capacita EEPROM BIOS v0.1.1
local invoke = component.invoke

local eeprom_addr = component.list("eeprom")()
local boot_addr = invoke(eeprom_addr, "getData")

if not boot_addr or boot_addr == "" then
  boot_addr = component.list("filesystem")()
end

local function read_object(uuid)
  local handle = invoke(boot_addr, "open", uuid, "r")
  if not handle then return nil end
  local buffer = ""
  repeat
    local chunk = invoke(boot_addr, "read", handle, math.huge)
    buffer = buffer .. (chunk or "")
  until not chunk
  invoke(boot_addr, "close", handle)
  return buffer
end

local index_data = read_object("index.db")
if not index_data then error("NO INDEX.DB") end

local kernel_uuid = string.match(index_data, "boot=([%w%-]+)")
if not kernel_uuid then error("NO BOOTABLE CORE") end

local kernel_code = read_object(kernel_uuid)

local ObjectStore = {
  read = read_object
}

local safe_hw = {
  invoke = invoke,
  list = component.list,
  pull = computer.pullSignal,
  addr = boot_addr
}

_G.component = nil
local shutdown = computer.shutdown
_G.computer = { shutdown = shutdown } 

local kernel, err = load(kernel_code, "=kernel", "t", _G)
if not kernel then error("KERNEL PANIC: " .. tostring(err)) end

kernel(safe_hw, ObjectStore)