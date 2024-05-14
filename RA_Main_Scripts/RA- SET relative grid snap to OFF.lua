-- @description SET relative grid snap to OFF
-- @version 1.0
-- @author Reservoir Audio / Mr.Brock with AI

-- Get the current state of grid options "Snap relative to grid"
local currentState = reaper.GetToggleCommandState(41054) -- Use the provided command ID for "Snap relative to grid"

-- Check if the current state is on (1 means on, 0 means off, -1 means not available)
if currentState == 1 then
    -- If currently on, toggle it to turn it off
    reaper.Main_OnCommand(41054, 0) -- Toggle "Snap relative to grid" off
end

-- Optionally, refresh the UI if needed
reaper.UpdateArrange()

