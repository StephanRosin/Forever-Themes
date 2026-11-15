-- Loads the addon as the client does: the files of the TOC in order, the
-- embedded library first, all with the same ns. Returns ns, the file list.
-- Load wowmock.lua (and build any Blizzard frame a test needs) before.
local ADDON = "ForeverThemes"
return function()
    local files = {}
    for line in io.lines(ADDONDIR .. "/" .. ADDON .. ".toc") do
        line = line:gsub("\r", "")
        if line ~= "" and not line:match("^#") then files[#files + 1] = (line:gsub("\\", "/")) end
    end
    local ns = {}
    for _, f in ipairs(files) do
        local chunk, err = loadfile(ADDONDIR .. "/" .. f)
        if not chunk then error(f .. ": " .. tostring(err)) end
        local ok, e = pcall(chunk, ADDON, ns)
        if not ok then error(f .. ": " .. tostring(e)) end
    end
    return ns, files
end
