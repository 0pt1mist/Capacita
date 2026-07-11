-- Capacita Installer v1.1.0 (Integrity Fixes)
local component = require("component")
local internet = require("internet")
local computer = require("computer")

local REPO_URL = "https://raw.githubusercontent.com/0pt1mist/Capacita/feature-raw-sectors/"

local target_addr
for addr in component.list("drive") do
  if addr ~= computer.getBootAddress() and addr ~= component.eeprom.getData() then
      target_addr = addr; break
  end
end

if not target_addr then
    print("-----------------------------------")
    print("FATAL ERROR: No UNMANAGED drive found!")
    print("-----------------------------------")
    print("Capacita OS requires a RAW (Unmanaged) disk.")
    print("Your Tier 2 disk is likely still in Managed (filesystem) mode.")
    print("\nHOW TO FIX:")
    print("1. Take the Tier 2 disk OUT of the computer.")
    print("2. Hold it in your hand and Right-Click in the air.")
    print("3. Select 'Unmanaged mode' (WARNING: this wipes it).")
    print("4. Put it back into the computer and run this installer again.")
    print("-----------------------------------")
    error("Installation aborted.")
end

local function download(path)
  local h, err = internet.request(REPO_URL .. path)
  if not h then error(err) end
  local d = ""
  for c in h do d = d .. c end
  return d
end

local function serialize(v)
    if type(v) == "number" or type(v) == "boolean" then return tostring(v)
    elseif type(v) == "string" then return string.format("%q", v)
    elseif type(v) == "table" then
        local t = {}
        for k, val in pairs(v) do table.insert(t, "["..serialize(k).."]="..serialize(val)) end
        return "{"..table.concat(t, ",").."}"
    end
end

print("Fetching packages.index...")
local pkg_str = download("packages.index")
local pkg_db = load(pkg_str, "=pkg", "t", {})()

print("Flashing BIOS...")
component.eeprom.set(download(pkg_db.bios.path))
component.eeprom.setData(target_addr)

print("Formatting target drive (Sector mode)...")
local db = { index = {}, bitmap = {}, system_uuids = {}, kernel_id = nil }
local capacity = component.invoke(target_addr, "getCapacity") or 1048576

for i = 1, 128 do db.bitmap[i] = true end
local current_sector = 129

local id_counter = 0
local function new_id()
    id_counter = id_counter + 1
    return "pkg-" .. id_counter
end

for pkg_name, info in pairs(pkg_db) do
    if pkg_name ~= "bios" then
        print("Installing " .. pkg_name .. "...")
        local code = download(info.path)
        local id = new_id()
        local secs = {}

        local chunks = math.ceil(#code / 512)
        local padded = code .. string.rep("\0", (chunks * 512) - #code)

        for i = 1, chunks do
            component.invoke(target_addr, "writeSector", current_sector, padded:sub((i-1)*512+1, i*512))
            table.insert(secs, current_sector)
            db.bitmap[current_sector] = true
            current_sector = current_sector + 1
        end
        db.index[id] = { tags = info.tags, sectors = secs, size = #code }

        if pkg_name == "kernel" then db.kernel_id = id end
        if info.system then db.system_uuids[pkg_name] = id end
    end
end

print("Writing Index DB to sectors 1-128...")
local s = "return " .. serialize(db)
if #s > 128 * 512 then
    error("Boot index too large for reserved sectors 1-128 (" .. #s .. " bytes). " ..
          "Reduce package count, or raise the reserved range in both install.lua and kernel/main.lua.")
end
s = s .. string.rep("\0", (128 * 512) - #s)
for i = 1, 128 do
    component.invoke(target_addr, "writeSector", i, s:sub((i-1)*512+1, i*512))
end

print("INSTALLATION COMPLETE. Rebooting...")
computer.shutdown(true)
