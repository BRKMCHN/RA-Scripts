-- @description Move item chunks to selected track maintaining their relative vertical span
-- @version 1.1
-- @author Reservoir Audio / Mr.Brock with AI


-- Function to get the track number of a track
local function getTrackNumber(track)
    return reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER")
end

-- Function to get total number of tracks in project
local function getTrackCount()
    return reaper.CountTracks(0)
end

-- Function to create new track at end
local function insertTrackAtEnd()
    local trackCount = getTrackCount()
    reaper.InsertTrackAtIndex(trackCount, true) -- Insert at end
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
local highestTrackNumber = -math.huge
for _, item in ipairs(selectedItems) do
    local itemTrack = reaper.GetMediaItem_Track(item)
    local itemTrackNumber = getTrackNumber(itemTrack)
    table.insert(itemTrackNumbers, itemTrackNumber)
    if itemTrackNumber < lowestTrackNumber then
        lowestTrackNumber = itemTrackNumber
    end
    if itemTrackNumber > highestTrackNumber then
        highestTrackNumber = itemTrackNumber
    end
end

-- Calculate number of tracks needed
local span = highestTrackNumber - lowestTrackNumber + 1
local neededTracks = selectedTrackNumber + (span - 1)

-- Check if enough tracks exist, if not, create more
local currentTrackCount = getTrackCount()
if neededTracks > currentTrackCount then
    local tracksToAdd = neededTracks - currentTrackCount
    for i = 1, tracksToAdd do
        insertTrackAtEnd()
    end
end

-- Start of Undo block for moving items
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
    end
end

-- Update the arrange view
reaper.UpdateArrange()

-- End of Undo block
reaper.Undo_EndBlock("Move items to selected track maintaining vertical positioning", -1)
