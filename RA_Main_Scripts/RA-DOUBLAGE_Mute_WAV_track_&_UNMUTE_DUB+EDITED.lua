-- @version 1.0
-- @description MUTE WAV Track and UNMUTE DUB + EDITED named tracks.
-- @author RESERVOIR AUDIO / Amel Desharnais, with AI.

-- Define the track names you want to work with
local tracksToMute = {"WAV"}
local tracksToUnmute = {"M&E DUB", "DUBBED", "EDITED"}

-- Mute the specified tracks by name
for i = 0, reaper.CountTracks(0) - 1 do
    local track = reaper.GetTrack(0, i)
    local _, trackName = reaper.GetTrackName(track, "")
    
    for _, nameToMute in ipairs(tracksToMute) do
        if trackName == nameToMute then
            reaper.SetMediaTrackInfo_Value(track, "B_MUTE", 1) -- Mute the specified tracks
        end
    end
end

-- Unmute the specified tracks by name
for i = 0, reaper.CountTracks(0) - 1 do
    local track = reaper.GetTrack(0, i)
    local _, trackName = reaper.GetTrackName(track, "")
    
    for _, nameToUnmute in ipairs(tracksToUnmute) do
        if trackName == nameToUnmute then
            reaper.SetMediaTrackInfo_Value(track, "B_MUTE", 0) -- Unmute the specified tracks
        end
    end
end

