-- @version 1.0
-- @description Select PREVIOUS top-level folder track
-- @author RESERVOIR AUDIO / MrBrock, with AI.

reaper.PreventUIRefresh(1)
reaper.Undo_BeginBlock()

local current_track = reaper.GetSelectedTrack(0, 0)

if current_track then
    local current_track_idx = reaper.GetMediaTrackInfo_Value(current_track, "IP_TRACKNUMBER")

    for i = current_track_idx - 2, 0, -1 do
        local track = reaper.GetTrack(0, i)
        if track and reaper.GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") == 1 then
            reaper.SetOnlyTrackSelected(track)
            break
        end
    end
end

reaper.Undo_EndBlock("Select Previous Top-Level Folder Track", -1)
reaper.PreventUIRefresh(-1)

