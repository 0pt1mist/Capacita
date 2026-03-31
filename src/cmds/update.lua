sys.print("Starting Capacita Updater...")
local repo = "https://raw.githubusercontent.com/0pt1mist/Capacita/dev/"

local function fetch(path)
    sys.print("Downloading " .. path .. "...")
    local conn = sys.net_request(repo .. path)
    if not conn then return nil end
    local result = ""
    while true do
        local chunk = sys.net_read(conn)
        if chunk == nil then break end
        if chunk ~= "" then result = result .. chunk end
        sys.receive(0.1)
    end
    return result
end

local new_kernel = fetch("src/kernel/main.lua")
local new_shell  = fetch("src/system/shell.lua")
-- no cmds rn

if not new_kernel or not new_shell then
    sys.print("Update failed: Network error.")
    return
end

sys.print("Creating rollback point...")
local old_idx = sys.get_index_raw()
local rb_id = sys.memorize(old_idx, {"system", "rollback_point"})

sys.print("Writing new objects...")
local k_id = sys.memorize(new_kernel, {"boot", "kernel"})
local s_id = sys.memorize(new_shell, {"system", "shell"})

sys.print("Updating Semantic Index...")
local mod_idx = string.gsub(old_idx, "'boot'", "'old_boot'")
mod_idx = string.gsub(mod_idx, "'shell'", "'old_shell'")

mod_idx = mod_idx:sub(1, -2)
mod_idx = mod_idx .. "  ['"..rb_id.."'] = {'system', 'rollback_point'},\n"
mod_idx = mod_idx .. "['"..k_id.."'] = {'boot', 'kernel'},\n"
mod_idx = mod_idx .. "  ['"..s_id.."'] = {'system', 'shell'}\n}"

sys.commit_index_raw(mod_idx)
sys.print("Update applied. Rebooting...")
sys.reboot()