-- @version 1.0
-- @description Couts the number of items on selected track.
-- @author Amel Desharnais, with AI.

-- Get the selected track
local selectedTrack = reaper.GetSelectedTrack(0, 0)

-- Check if a track is selected
if selectedTrack then
    -- Get the number of items on the selected track
    local itemCount = reaper.CountTrackMediaItems(selectedTrack)
    
    -- Print the item count to the Reaper console
    reaper.ShowConsoleMsg("Number of Items on the Track: " .. itemCount)
else
    reaper.ShowMessageBox("No track is selected.", "Error", 0)
end

