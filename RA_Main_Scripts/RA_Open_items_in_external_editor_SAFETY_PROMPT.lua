-- @description Open items in external editor (Safe Wrapper for timestamp_EDIT tagged files)
-- @version 1.0
-- @author Reservoir Audio / Mr.Brock with AI

-- Function to check if any selected item uses a source file that is not clearly a copied/edit version
local function has_potential_original_sources()
    local num_items = reaper.CountSelectedMediaItems(0)
    for i = 0, num_items - 1 do
        local item = reaper.GetSelectedMediaItem(0, i)
        local take = reaper.GetActiveTake(item)
        if take and not reaper.TakeIsMIDI(take) then
            local source = reaper.GetMediaItemTake_Source(take)
            local filepath = reaper.GetMediaSourceFileName(source, "")
            -- Require strict pattern: _123456_EDIT (6 digits + _EDIT)
            if not filepath:match("_%d%d%d%d%d%d_EDIT") then
                return true  -- File looks like an original
            end
        end
    end
    return false  -- All files appear safe
end

local function main()
    local item_count = reaper.CountSelectedMediaItems(0)
    if item_count == 0 then
        reaper.ShowMessageBox("No media items selected.", "Warning", 0)
        return
    end

    if has_potential_original_sources() then
        local ret = reaper.ShowMessageBox(
            "You are about to open a file that may be an original source file.\n\n[timestamp]_EDIT tag was found in source name.\n\nWould you like to proceed anyway?",
            "Potential Original Source File Detected",
            1 -- 0=OK, 1=Yes/No, 2=Yes/No/Cancel
        )
        if ret ~= 1 then return end  -- User chose "No"
    end

    -- Proceed with "Open items in external editor" (Command ID 40109)
    reaper.Main_OnCommand(40109, 0)
end

main()

