-- Capacita BIOS v1.0.2 (Debug & Anti-lag)
local invoke = component.invoke
local list = component.list

computer.pullSignal(0.1)

local saved_addr = invoke(list("eeprom")(), "getData")
local boot_addr = nil

for addr in list("drive") do
  if saved_addr and addr:sub(1, #saved_addr) == saved_addr then boot_addr = addr; break end
end
if not boot_addr then
  for addr in list("drive") do boot_addr = addr; break end
end

if not boot_addr then 
  local msg = "NO BOOT DRIVE. Found: "
  for a, t in list() do msg = msg .. t .. " " end
  error(msg)
end

local idx_str = ""
for i = 1, 128 do 
  local sec = invoke(boot_addr, "readSector", i)
  if not sec then error("BIOS: ERR READING SECTOR " .. i) end
  idx_str = idx_str .. sec 
end
local null_pos = idx_str:find("%z")
if null_pos then idx_str = idx_str:sub(1, null_pos - 1) end

local db = load(idx_str, "=index", "t", {})()
if type(db) ~= "table" or not db.index then error("BIOS: CORRUPTED INDEX") end

local kernel_uuid
for id, meta in pairs(db.index) do
  for _, tag in ipairs(meta.tags) do
    if tag == "boot" then kernel_uuid = id; break end
  end
end
if not kernel_uuid then error("BIOS: NO KERNEL TAG") end

local k_str = ""
for _, sec in ipairs(db.index[kernel_uuid].sectors) do
  k_str = k_str .. invoke(boot_addr, "readSector", sec)
end
k_str = k_str:sub(1, db.index[kernel_uuid].size)

local safe_hw = { invoke=invoke, list=list, pull=computer.pullSignal, uptime=computer.uptime }
_G.component = nil
_G.computer = { shutdown = computer.shutdown } 

local kernel, err = load(k_str, "=kernel", "t", _G)
if not kernel then error("KERNEL PANIC: " .. tostring(err)) end
kernel(safe_hw, boot_addr, db)