-- @version 1.0
-- @description Couts the number of items on selected track, within time selection.
-- @author Amel Desharnais, with AI.

-- Get the selected track
local selectedTrack = reaper.GetSelectedTrack(0, 0)

-- Check if a track is selected
if selectedTrack then
    -- Get the start and end time of the time selection
    local startTime, endTime = reaper.GetSet_LoopTimeRange2(0, false, false, 0, 0, false)
    
    -- Initialize the item count
    local itemCount = 0
    
    -- Iterate through all media items on the selected track
    for i = 0, reaper.CountTrackMediaItems(selectedTrack) - 1 do
        local item = reaper.GetTrackMediaItem(selectedTrack, i)
        local itemStartTime = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
        local itemEndTime = itemStartTime + reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
        
        -- Check if the item overlaps with the time selection
        if itemStartTime < endTime and itemEndTime > startTime then
            itemCount = itemCount + 1
        end
    end
    
    -- Print the item count to the Reaper console
    reaper.ShowConsoleMsg("Number of Items on the Track in Time Selection: " .. itemCount)
else
    reaper.ShowMessageBox("No track is selected.", "Error", 0)
end

