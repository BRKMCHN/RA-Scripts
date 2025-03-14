-- @version 1.1
-- @description Shorten edges of time selection by 1 frame
-- @author RESERVOIR AUDIO

reaper.Undo_BeginBlock() -- Begin undo block

-- Get the current time selection edges
start_time, end_time = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)

-- Get project frame rate
frame_rate = reaper.TimeMap_curFrameRate(0)

-- Define 1 frame duration
frame_duration = 1 / frame_rate

if start_time ~= end_time then -- Ensure there is a time selection
    local new_start = start_time + frame_duration -- Move start edge to the right by 1 frame
    local new_end = end_time - frame_duration -- Move end edge to the left by 1 frame

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

reaper.Undo_EndBlock("Shorten time selection edges", -1) -- End undo block