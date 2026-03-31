-- Capacita Installer v0.5.0
local component = require("component")
local internet = require("internet")
local fs = require("filesystem")

local REPO_URL = "https://raw.githubusercontent.com/0pt1mist/Capacita/dev/"
local function uuid()
    local t ='xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
    return string.gsub(t, '[xy]', function (c)
        local v = (c=='x') and math.random(0,0xf) or math.random(8,0xb)
        return string.format('%x', v)
    end)
end

local target_addr
for addr in component.list("filesystem") do
  if addr ~= fs.get("/").address and addr ~= component.eeprom.address and (not fs.get("/tmp") or addr ~= fs.get("/tmp").address) then target_addr = addr; break end
end
if not target_addr then error("No target drive found!") end

local function download(path)
  local h = internet.request(REPO_URL .. path)
  local d = ""
  for c in h do d = d .. c end
  return d
end

print("Fetching packages.index...")
local pkg_str = download("packages.index")
local pkg_db = load(pkg_str)()

print("Flashing BIOS...")
component.eeprom.set(download(pkg_db.bios.path))
component.eeprom.setData(target_addr)

local mnt = "/mnt/capacita"
fs.makeDirectory(mnt)
fs.mount(target_addr, mnt)
for file in fs.list(mnt) do fs.remove(mnt .. "/" .. file) end

local index_str = "return {\n"
for pkg_name, info in pairs(pkg_db) do
    if pkg_name ~= "bios" then
        print("Installing " .. pkg_name .. "...")
        local code = download(info.path)
        local id = uuid()
        local f = io.open(mnt .. "/" .. id, "w"); f:write(code); f:close()
        index_str = index_str .. "  ['"..id.."'] = {'" .. table.concat(info.tags, "','") .. "'},\n"
    end
end

local f = io.open(mnt .. "/index.db", "w"); f:write(index_str .. "}"); f:close()
fs.umount(mnt)

print("INSTALLATION COMPLETE. Rebooting...")
require("computer").shutdown(true)