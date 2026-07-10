sys.print("Searching for rollback point...")
local rb = sys.recall("rollback_point")
if #rb == 0 then sys.print("No rollback point found."); return end

sys.print("Restoring safe snapshot...")
if sys.restore(rb[1].id) then sys.print("Rollback applied. Rebooting..."); sys.reboot()
else sys.print("Failed to restore snapshot.") end