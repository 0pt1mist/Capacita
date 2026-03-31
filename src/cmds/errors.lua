local errs = sys.recall("updater_error")
if #errs == 0 then
    sys.print("No errors logged.")
else
    sys.print("Found " .. #errs .. " crash logs:")
    for i, e in ipairs(errs) do
        sys.print("Log " .. i .. ": " .. e.read())
    end
end