-- @version 1.0
-- @description COUNT the number of ITEMS on SELECTED TRACK.
-- @author RESERVOIR AUDIO / Amel Desharnais, with AI.

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

