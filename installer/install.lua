-- Capacita OS Web Installer v0.1.3
local component = require("component")
local internet = require("internet")
local fs = require("filesystem")

local REPO_URL = "https://raw.githubusercontent.com/0pt1mist/Capacita/dev/"

local UUID_KERNEL = "OBJ-KERNEL-001"
local UUID_SHELL  = "OBJ-SHELL-001"

print("--- Capacita OS Installer ---")

local hdds = {}
for addr, _ in component.list("filesystem") do
  if addr ~= fs.get("/").address and addr ~= component.eeprom.address then
     if not fs.get("/tmp") or addr ~= fs.get("/tmp").address then
       table.insert(hdds, addr)
     end
  end
end

if #hdds == 0 then error("No target drive found! Insert a blank HDD.") end
local target_addr = hdds[1]
print("Target drive: " .. string.sub(target_addr, 1, 8))

local function download(path)
  print("Downloading: " .. path)
  local handle = internet.request(REPO_URL .. path)
  local data = ""
  for chunk in handle do data = data .. chunk end
  
  if string.match(data, "404: Not Found") then
    error("ERROR 404: File missing on GitHub -> " .. path)
  end
  return data
end

local bios_code = download("src/eeprom/bios.lua")
local kernel_code = download("src/kernel/main.lua")
local shell_code = download("src/system/shell.lua")

print("Flashing EEPROM...")
component.eeprom.set(bios_code)
component.eeprom.setLabel("Capacita BIOS")
component.eeprom.setData(target_addr)

print("Mounting and cleaning target drive...")
local mnt = "/mnt/capacita"
fs.makeDirectory(mnt)
fs.mount(target_addr, mnt)

for file in fs.list(mnt) do
  fs.remove(mnt .. "/" .. file)
end

print("Writing Engrams...")
local function write_obj(uuid, data)
  local file = io.open(mnt .. "/" .. uuid, "w")
  if not file then error("Failed to create object: " .. uuid) end
  file:write(data)
  file:close()
end

write_obj(UUID_KERNEL, kernel_code)
write_obj(UUID_SHELL, shell_code)

local index_data = "boot=" .. UUID_KERNEL .. "\n" ..
                   "shell=" .. UUID_SHELL .. "\n"
write_obj("index.db", index_data)

fs.umount(mnt)
print("---------------------------------")
print("INSTALLATION COMPLETE.")
print("Remove the OpenOS floppy and reboot.")