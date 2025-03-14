-- @version 1.1
-- @description Shorten edges of time selection by user-defined time
-- @author RESERVOIR AUDIO

reaper.Undo_BeginBlock() -- Begin undo block

local ret, input = reaper.GetUserInputs("Time Adjustment", 1, "Enter time (append 'f' for frames or 's' for seconds):", "")

if not ret then return end -- Exit if user cancels

local value = tonumber(input:match("%d+"))
local unit = input:match("[fs]")

if not value or not unit then
    reaper.ShowMessageBox("Invalid input. Please enter a number followed by 'f' (frames) or 's' (seconds).", "Input Error", 0)
    return
end

start_time, end_time = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)

if start_time ~= end_time then -- Ensure there is a time selection
    local adjustment = (unit == "f") and (value / frame_rate) or value

    local new_start = start_time + adjustment
    local new_end = end_time - adjustment

    if new_start < new_end then -- Check if the new start time is less than the new end time
        reaper.GetSet_LoopTimeRange(true, false, new_start, new_end, false)
        reaper.UpdateArrange() -- Update the arrange view
    else
        reaper.ShowMessageBox("The adjusted time selection is invalid (end time must be greater than start time).", "Time Selection Error", 0)
    end
else
    reaper.ShowMessageBox("No time selection made. Please select a time range first.", "Time Selection Error", 0)
end

reaper.Undo_EndBlock("Shorten time selection edges by user-defined time", -1) -- End undo block
