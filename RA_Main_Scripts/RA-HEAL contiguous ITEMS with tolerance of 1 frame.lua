-- @version 1.0
-- @description HEAL contiguous items (with a tolerance of 1 frame)
-- @author RESERVOIR AUDIO / MrBrock, with AI.

reaper.Undo_BeginBlock()

local frameRate = reaper.TimeMap_curFrameRate(0)
local frameDuration = 1 / frameRate
local tolerance = frameDuration + 0.000001

-- Get item details
local function getItemDetails(item)
    local position = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    local length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
    local track = reaper.GetMediaItem_Track(item)
    local trackIndex = reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER")
    return {
        item = item,
        position = position,
        length = length,
        track = track,
        trackIndex = trackIndex
    }
end

-- Gather and sort selected items
local selectedItems = {}
for i = 0, reaper.CountSelectedMediaItems(0) - 1 do
    table.insert(selectedItems, getItemDetails(reaper.GetSelectedMediaItem(0, i)))
end

table.sort(selectedItems, function(a, b)
    return a.trackIndex == b.trackIndex and a.position < b.position or a.trackIndex < b.trackIndex
end)

-- Group into healable chunks
local chunks = {}
local currentChunk = {}

for i, item in ipairs(selectedItems) do
    if #currentChunk == 0 then
        table.insert(currentChunk, item)
    else
        local last = currentChunk[#currentChunk]
        local lastEnd = last.position + last.length
        local actualStart = item.position
        local sameTrack = last.track == item.track
        local isCloseOrOverlapping = actualStart <= (lastEnd + tolerance)

        if sameTrack and isCloseOrOverlapping then
            table.insert(currentChunk, item)
        else
            if #currentChunk > 1 then table.insert(chunks, currentChunk) end
            currentChunk = { item }
        end
    end
end

if #currentChunk > 1 then
    table.insert(chunks, currentChunk)
end

-- Heal each chunk
for _, group in ipairs(chunks) do
    reaper.Main_OnCommand(40289, 0) -- Unselect all
    for _, entry in ipairs(group) do
        reaper.SetMediaItemSelected(entry.item, true)
    end
    reaper.Main_OnCommand(40548, 0) -- Heal splits in items (preserve timing)
end

reaper.UpdateArrange()
reaper.Undo_EndBlock("Heal contiguous/overlapping splits within 1 frame", -1)
