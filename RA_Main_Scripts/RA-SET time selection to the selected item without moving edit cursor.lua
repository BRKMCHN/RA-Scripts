-- @version 1.0
-- @description SET time selection to the selected item without moving edit cursor.
-- @author RESERVOIR AUDIO / Fante with AI
-- Get the active project
local proj = 0

-- Loop through all selected items
for i = 0, reaper.CountSelectedMediaItems(proj) - 1 do
    -- Get the selected item
    local item = reaper.GetSelectedMediaItem(proj, i)
    
    if item then
        -- Get the start and end times of the item
        local itemStart = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
        local itemLength = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
        local itemEnd = itemStart + itemLength
        
        -- Set the time selection to the item's boundaries
        reaper.GetSet_LoopTimeRange(true, false, itemStart, itemEnd, false)
    end
end

