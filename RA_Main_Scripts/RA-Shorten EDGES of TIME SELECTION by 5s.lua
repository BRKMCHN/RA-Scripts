-- @version 1.0
-- @description Shorten edges of time selection by 5s
-- @author RESERVOIR AUDIO

-- Get the current time selection edges
start_time, end_time = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)

if start_time ~= end_time then -- Ensure there is a time selection
    local new_start = start_time + 5 -- Move start edge to the right by 5 seconds
    local new_end = end_time - 5 -- Move end edge to the left by 5 seconds

    if new_start < new_end then -- Check if the new start time is less than the new end time
        -- Set the new time selection
        reaper.GetSet_LoopTimeRange(true, false, new_start, new_end, false)
        reaper.UpdateArrange() -- Update the arrange view
    else
        reaper.ShowMessageBox("The adjusted time selection is invalid (end time must be greater than start time).", "Time Selection Error", 0)
    end
else
    reaper.ShowMessageBox("No time selection made. Please select a time range first.", "Time Selection Error", 0)
end

