sys.print("Searching for rollback point...")
local rb = sys.recall("rollback_point")
if #rb == 0 then
    sys.print("No rollback point found.")
    return
end

sys.print("Restoring safe index...")
sys.commit_index_raw(rb[1].read())
sys.print("Rollback applied. Rebooting...")
sys.reboot()