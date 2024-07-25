-- @description Move item chunks to selected track maintaining vertical spacing
-- @version 1.0
-- @author Reservoir Audio / Mr.Brock with AI


-- Function to get the track number of a track
local function getTrackNumber(track)
    return reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER")
end

-- Move items to selected track maintaining vertical position
local selectedItems = {}
local itemCount = reaper.CountSelectedMediaItems(0)

if itemCount == 0 then
    reaper.ShowMessageBox("Please select at least one item.", "Error", 0)
    return
end

for i = 0, itemCount - 1 do
    local item = reaper.GetSelectedMediaItem(0, i)
    table.insert(selectedItems, item)
end

local selectedTrack = reaper.GetSelectedTrack(0, 0) -- Assume the first selected track is the destination track
if not selectedTrack then
    reaper.ShowMessageBox("Please select a destination track.", "Error", 0)
    return
end

local selectedTrackNumber = getTrackNumber(selectedTrack)

-- Get the track numbers of the tracks containing selected items
local itemTrackNumbers = {}
local lowestTrackNumber = math.huge
for _, item in ipairs(selectedItems) do
    local itemTrack = reaper.GetMediaItem_Track(item)
    local itemTrackNumber = getTrackNumber(itemTrack)
    table.insert(itemTrackNumbers, itemTrackNumber)
    if itemTrackNumber < lowestTrackNumber then
        lowestTrackNumber = itemTrackNumber
    end
end

-- Start of Undo block
reaper.Undo_BeginBlock()

-- Move items to target track maintaining vertical positioning
for _, item in ipairs(selectedItems) do
    local itemTrack = reaper.GetMediaItem_Track(item)
    local itemTrackNumber = getTrackNumber(itemTrack)
    local trackDifference = itemTrackNumber - lowestTrackNumber
    local newTrackNumber = selectedTrackNumber + trackDifference - 1 -- Adjust to match REAPER's track indexing
    local track = reaper.GetTrack(0, newTrackNumber)
    if track then
        reaper.MoveMediaItemToTrack(item, track)
    else
        reaper.ShowMessageBox("Couldn't find media track for item: " .. tostring(item), "Track not found", 0)
    end
end

-- Update the arrange view
reaper.UpdateArrange()

-- End of Undo block
reaper.Undo_EndBlock("Move items to selected track maintaining vertical positioning", -1)

