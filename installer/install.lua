-- Capacita OS Web Installer
local component = require("component")
local internet = require("internet")
local fs = require("filesystem")

local REPO_URL = "https://raw.githubusercontent.com/0pt1mist/Capacita/dev/"

-- Pseudo-UUID
local UUID_KERNEL = "OBJ-KERNEL-001"
local UUID_SHELL  = "OBJ-SHELL-001"

print("--- Capacita OS Installer ---")

local hdds = {}
for addr, _ in component.list("filesystem") do
  if addr ~= fs.get("/").address then table.insert(hdds, addr) end
end
if #hdds == 0 then error("No target drive found!") end

local target_fs = component.proxy(hdds[1])
print("Target drive: " .. string.sub(target_fs.address, 1, 8))

local function download(path)
  print("Downloading: " .. path)
  local handle = internet.request(REPO_URL .. path)
  local data = ""
  for chunk in handle do data = data .. chunk end
  return data
end

local bios_code = download("src/eeprom/bios.lua")
local kernel_code = download("src/kernel/main.lua")
local shell_code = download("src/system/shell.lua")

print("Flashing EEPROM (Capacita BIOS)...")
component.eeprom.set(bios_code)
component.eeprom.setLabel("Capacita BIOS")

print("Formatting target drive...")
for _, file in ipairs(target_fs.list("/")) do
  target_fs.remove(file)
end

print("Writing Engrams...")
local function write_obj(uuid, data)
  local f = target_fs.open(uuid, "w")
  target_fs.write(f, data)
  target_fs.close(f)
end

write_obj(UUID_KERNEL, kernel_code)
write_obj(UUID_SHELL, shell_code)

print("Building Object Index...")
local index_data = "boot=" .. UUID_KERNEL .. "\n" ..
                   "shell=" .. UUID_SHELL .. "\n"
write_obj("index.db", index_data)

print("---------------------------------")
print("INSTALLATION COMPLETE.")
print("The computer will now operate without a traditional filesystem.")
print("Please remove the OpenOS floppy and reboot.")