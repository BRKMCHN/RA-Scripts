-- @version 1.0
-- @description This script will check for looped items and keep selected those that go beyond source lenght.
-- @author MrBrock & AI

-- Start the Undo block
reaper.Undo_BeginBlock()

-- Loop through all selected items
local numSelectedItems = reaper.CountSelectedMediaItems(0)
for i = numSelectedItems-1, 0, -1 do
    local item = reaper.GetSelectedMediaItem(0, i)
    if item then
        local take = reaper.GetActiveTake(item)
        if take and not reaper.TakeIsMIDI(take) then -- Ensure it's not a MIDI take
            local itemLength = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
            local source = reaper.GetMediaItemTake_Source(take)
            local sourceLength = reaper.GetMediaSourceLength(source)
            if itemLength <= sourceLength then
                -- Deselect the item if its length is not longer than its source
                reaper.SetMediaItemSelected(item, false)
            end
        end
    end
end

-- End the Undo block
reaper.Undo_EndBlock("Select items longer than their source", -1)

