-- @version 1.0
-- @description Toggle ALL send VOLUME envelopes on SELECTED tracks.
-- @author RESERVOIR AUDIO / MrBrock, with AI.

-- Start the undo block
reaper.Undo_BeginBlock()

-- Table to store envelope visibility information
local envelopeVisibility = {}

-- Function to check and store the visibility of a track's send volume envelope
local function CheckAndStoreEnvelopeVisibility(track)
    local envCount = reaper.CountTrackEnvelopes(track)
    for i = 0, envCount - 1 do
        local envelope = reaper.GetTrackEnvelope(track, i)
        local retval, envName = reaper.GetEnvelopeName(envelope, "")

        -- Check if this is a send volume envelope
        if envName:find("Send Volume") then
            local brEnv = reaper.BR_EnvAlloc(envelope, false)
            local active, visible, armed, inLane, laneHeight, defaultShape, minValue, maxValue, centerValue, type, faderScaling = reaper.BR_EnvGetProperties(brEnv)

            -- Store envelope and its visibility status
            table.insert(envelopeVisibility, {envelope = envelope, visible = visible})

            reaper.BR_EnvFree(brEnv, false)  -- no need to commit changes
        end
    end
end

-- Function to toggle envelope visibility
local function ToggleEnvelopeVisibility(envelope, shouldBeVisible)
    local brEnv = reaper.BR_EnvAlloc(envelope, false)
    local active, visible, armed, inLane, laneHeight, defaultShape, minValue, maxValue, centerValue, type, faderScaling = reaper.BR_EnvGetProperties(brEnv)
    
    -- Set visibility
    reaper.BR_EnvSetProperties(brEnv, active, shouldBeVisible, armed, inLane, laneHeight, defaultShape, faderScaling)
    reaper.BR_EnvFree(brEnv, true)  -- commit changes
end

-- Process all selected tracks and gather envelope visibility data
local selectedTrackCount = reaper.CountSelectedTracks(0)
for i = 0, selectedTrackCount - 1 do
    local track = reaper.GetSelectedTrack(0, i)
    CheckAndStoreEnvelopeVisibility(track)
end

-- Determine the action based on visibility of envelopes
local allVisible = true
for _, envData in ipairs(envelopeVisibility) do
    if not envData.visible then
        allVisible = false
        break
    end
end

-- Toggle visibility
for _, envData in ipairs(envelopeVisibility) do
    if allVisible or (not envData.visible) then
        ToggleEnvelopeVisibility(envData.envelope, not envData.visible)
    end
end

-- End the undo block
reaper.Undo_EndBlock("Toggle Send Volume Envelopes Visibility on Selected Tracks", -1)

