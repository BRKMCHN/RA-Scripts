-- @version 1.0
-- @description Spread every other selected item of selected tracks to a new temporary track.
-- @author RESERVOIR AUDIO / MrBrock adapted with AI.
-- @about Moves every other item to a new track called ALIGN_TEMP, to avoid overlapping issues.

-- Get the number of selected items
local numSelectedItems = reaper.CountSelectedMediaItems(0)

-- Create a table to store tracks and their items
local trackItems = {}

-- Iterate through selected items and store them in trackItems table
for i = 0, numSelectedItems - 1 do
    local item = reaper.GetSelectedMediaItem(0, i)
    local track = reaper.GetMediaItemTrack(item)
    
    if not trackItems[track] then
        trackItems[track] = {}
    end
    table.insert(trackItems[track], item)
end

-- Function to move items to a new ALIGN_TEMP track
local function moveItemsToAlignTemp(track, items)
    -- Insert new track below the current track
    local trackIndex = reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER") - 1
    reaper.InsertTrackAtIndex(trackIndex + 1, false)
    local alignTempTrack = reaper.GetTrack(0, trackIndex + 1)
    reaper.GetSetMediaTrackInfo_String(alignTempTrack, "P_NAME", "ALIGN_TEMP", true)
    
    -- Move every other item to ALIGN_TEMP track
    for i = 1, #items, 2 do
        local item = items[i]
        reaper.MoveMediaItemToTrack(item, alignTempTrack)
    end
end

-- Begin undo block
reaper.Undo_BeginBlock()

-- Move every other item of each track's selected items to a new ALIGN_TEMP track
for track, items in pairs(trackItems) do
    moveItemsToAlignTemp(track, items)
end

-- End undo block
reaper.Undo_EndBlock("Move every other item to ALIGN_TEMP track", -1)

-- Update the arrange view
reaper.UpdateArrange()

