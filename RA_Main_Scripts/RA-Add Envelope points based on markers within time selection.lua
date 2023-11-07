-- @version 1.0
-- @description ADD Envelope points to selected envelope according to markers within time selection.
-- @author RESERVOIR AUDIO / MrBrock, with AI.

--[[
 * ReaScript Name: Add Points to Selected Envelope at Time Selection Markers
 * Author: Your Name
 * Version: 1.1
 * Description: Adds envelope points at time selection markers for a selected envelope.
--]]

-- Get the selected envelope
local env = reaper.GetSelectedEnvelope(0)

if not env then
    reaper.ShowMessageBox("Please select an envelope first.", "Error", 0)
    return
end

-- Get the time selection
local startTime, endTime = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)

if startTime == endTime then
    reaper.ShowMessageBox("Please make a time selection first.", "Error", 0)
    return
end

-- Loop through markers
local numMarkers = reaper.CountProjectMarkers(0)
for i = 0, numMarkers - 1 do
    local _, isRegion, position = reaper.EnumProjectMarkers(i)
    
    if not isRegion and position >= startTime and position <= endTime then
        -- Evaluate the envelope value at the marker position
        local _, value = reaper.Envelope_Evaluate(env, position, 0, 0)
        
        -- Add an envelope point at the marker position with the evaluated value
        reaper.InsertEnvelopePoint(env, position, value, 0, 0, false, true)
    end
end

-- Sort envelope points
reaper.Envelope_SortPoints(env)

-- Update the arrange view
reaper.UpdateArrange()

