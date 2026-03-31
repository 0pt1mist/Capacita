-- Capacita EEPROM BIOS v0.1.3
local invoke = component.invoke
local list = component.list

local eeprom = list("eeprom")()
local saved_addr = invoke(eeprom, "getData")

local boot_addr = nil
for addr in list("filesystem") do
  if saved_addr and saved_addr ~= "" and addr:sub(1, #saved_addr) == saved_addr then
    boot_addr = addr
    break
  end
end

if not boot_addr then
  error("BIOS HALT: NO MATCHING HDD. Saved ID: " .. tostring(saved_addr))
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
if not index_data then 
  error("BIOS HALT: INDEX.DB MISSING ON DRIVE " .. string.sub(boot_addr, 1, 8)) 
end

local kernel_uuid = string.match(index_data, "boot=([%w%-]+)")
if not kernel_uuid then error("BIOS HALT: NO KERNEL ENGRAM IN INDEX") end

local kernel_code = read_object(kernel_uuid)
if not kernel_code then error("BIOS HALT: KERNEL OBJECT READ FAILED") end

local ObjectStore = { read = read_object }
local safe_hw = {
  invoke = invoke,
  list = list,
  pull = computer.pullSignal,
  addr = boot_addr
}

_G.component = nil
local shutdown = computer.shutdown
_G.computer = { shutdown = shutdown } 

local kernel, err = load(kernel_code, "=kernel", "t", _G)
if not kernel then error("KERNEL PANIC: " .. tostring(err)) end

kernel(safe_hw, ObjectStore)