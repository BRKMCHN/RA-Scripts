-- @version 1.0
-- @description SET selected envelope points to PREVIOUS envelope point value.
-- @author RESERVOIR AUDIO / MrBrock, with AI.

-- Check if REAPER is running
if not reaper.APIExists("CF_GetCommandText") then
  reaper.MB("This script requires the SWS/S&M extension.\n\n" .. 
            "Download it from\n" ..
            "www.sws-extension.org",
            "Error", 0)
  return false
end

reaper.Undo_BeginBlock()  -- Begin undo block

-- Get selected envelope
local env = reaper.GetSelectedEnvelope(0)
if env then
    local point_count = reaper.CountEnvelopePoints(env)
    -- Loop through each envelope point
    for i = 0, point_count - 1 do
        local retval, time, value, shape, tension, selected = reaper.GetEnvelopePoint(env, i)
        -- Check if point is selected
        if selected then
            if i > 0 then
                -- Get the value of the previous point
                local _, _, prev_value, _, _, _ = reaper.GetEnvelopePoint(env, i-1)
                -- Set the current selected point to the value of the previous point
                reaper.SetEnvelopePoint(env, i, time, prev_value, shape, tension, true, true)
            else
                reaper.ShowMessageBox("The first envelope point has no previous point.", "Error", 0)
            end
        end
    end
    -- Update changes and redraw envelope
    reaper.Envelope_SortPoints(env)
else
    reaper.ShowMessageBox("No envelope selected.", "Error", 0)
end

reaper.Undo_EndBlock("Set Selected Envelope Point to Previous", -1)  -- End undo block

