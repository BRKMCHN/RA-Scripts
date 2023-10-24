-- @version 1.0
-- @description UNMUTE WAV track and MUTE DUB + EDITED named tracks.
-- @author RESERVOIR AUDIO / Amel Desharnais, with AI.

-- Define the track names you want to work with
local trackToUnmuteName = "WAV"
local tracksToMute = {"M&E DUB", "DUBBED", "EDITED"}

-- Unmute the specified track by name
for i = 0, reaper.CountTracks(0) - 1 do
    local track = reaper.GetTrack(0, i)
    local _, trackName = reaper.GetTrackName(track, "")
    
    if trackName == trackToUnmuteName then
        reaper.SetMediaTrackInfo_Value(track, "B_MUTE", 0) -- Unmute the specified track
    end
end

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

