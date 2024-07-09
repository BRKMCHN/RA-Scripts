-- @version 1.0
-- @description Unspread items on temporary tracks back to its place.
-- @author RESERVOIR AUDIO / MrBrock adapted with AI.
-- @about Moves every item on the ALIGN_TEMP tracks below selected tracks back to selected track.

-- Function to move items back to the original track and remove the temporary track
local function moveItemsBackAndRemoveTemp(track)
    local trackIndex = reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER") - 1
    local tempTrack = reaper.GetTrack(0, trackIndex + 1)
    
    if not tempTrack then return end -- No track below, nothing to do
    
    local _, tempTrackName = reaper.GetSetMediaTrackInfo_String(tempTrack, "P_NAME", "", false)
    if tempTrackName ~= "ALIGN_TEMP" then return end -- The track below is not a temp track, skip it
    
    local numItems = reaper.CountTrackMediaItems(tempTrack)
    
    -- Move items from temp track back to original track
    for i = numItems - 1, 0, -1 do
        local item = reaper.GetTrackMediaItem(tempTrack, i)
        reaper.MoveMediaItemToTrack(item, track)
    end
    
    -- Delete the temp track if it is now empty
    if reaper.CountTrackMediaItems(tempTrack) == 0 then
        reaper.DeleteTrack(tempTrack)
    end
end

-- Begin undo block
reaper.Undo_BeginBlock()

-- Get the number of selected tracks
local numSelectedTracks = reaper.CountSelectedTracks(0)

-- Process each selected track
for i = 0, numSelectedTracks - 1 do
    local track = reaper.GetSelectedTrack(0, i)
    moveItemsBackAndRemoveTemp(track)
end

-- End undo block
reaper.Undo_EndBlock("Move items back from ALIGN_TEMP track and remove empty tracks", -1)

-- Update the arrange view
reaper.UpdateArrange()

