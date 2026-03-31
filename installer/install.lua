-- Capacita Installer v0.4.0
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
  if addr ~= fs.get("/").address and addr ~= component.eeprom.address then
     if not fs.get("/tmp") or addr ~= fs.get("/tmp").address then target_addr = addr; break end
  end
end
if not target_addr then error("No target drive found!") end

local function download(path)
  local h = internet.request(REPO_URL .. path)
  local d = ""
  for c in h do d = d .. c end
  return d
end

local bios_code = download("src/eeprom/bios.lua")
component.eeprom.set(bios_code)
component.eeprom.setData(target_addr)

local mnt = "/mnt/capacita"
fs.makeDirectory(mnt)
fs.mount(target_addr, mnt)
for file in fs.list(mnt) do fs.remove(mnt .. "/" .. file) end

local function write_obj(id, data)
  local f = io.open(mnt .. "/" .. id, "w")
  f:write(data); f:close()
end

local index_str = "return {\n"

local function install_obj(path, tags)
    local code = download(path)
    local id = uuid()
    write_obj(id, code)
    index_str = index_str .. "  ['"..id.."'] = {'" .. table.concat(tags, "','") .. "'},\n"
end

print("Installing Core...")
install_obj("src/kernel/main.lua", {"boot", "kernel"})
install_obj("src/system/shell.lua", {"system", "shell"})

print("Installing Commands...")

local cmds = {"help", "echo", "mkobj", "update", "rollback", "errors"} 

for _, cmd in ipairs(cmds) do
    install_obj("src/cmds/" .. cmd .. ".lua", {"cmd", cmd})
end

index_str = index_str .. "}"
write_obj("index.db", index_str)
fs.umount(mnt)

print("INSTALLATION COMPLETE. Rebooting...")
require("computer").shutdown(true)