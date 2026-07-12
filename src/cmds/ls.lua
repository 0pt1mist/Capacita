local show_all = false
for _, a in ipairs(args) do if a == "-a" then show_all = true end end

local objs = sys.recall({})

local function is_hidden(tags)
    for _, t in ipairs(tags) do
        if t == "log" or t == "updater_error" or string.sub(t, 1, 4) == "old_" then return true end
    end
    return false
end

local shown = 0
for _, obj in ipairs(objs) do
    if show_all or not is_hidden(obj.tags) then
        sys.print(obj.id .. "  [" .. table.concat(obj.tags, ", ") .. "]")
        shown = shown + 1
    end
end

if show_all then
    sys.print(shown .. " object(s), all shown.")
else
    sys.print(shown .. " object(s). Use 'ls -a' to include archived/log entries.")
end
