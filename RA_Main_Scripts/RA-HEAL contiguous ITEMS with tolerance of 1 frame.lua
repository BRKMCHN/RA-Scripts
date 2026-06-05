-- @version 1.1
-- @description HEAL contiguous items (with a tolerance of 1 frame)
-- @author RESERVOIR AUDIO / MrBrock, with AI.

reaper.Undo_BeginBlock()
reaper.PreventUIRefresh(1)

local frameRate = reaper.TimeMap_curFrameRate(0)
local frameDuration = 1 / frameRate
local tolerance = frameDuration + 0.000001

-- Get source filename/path for an item, when available
local function getItemSourceName(item)
    local take = reaper.GetActiveTake(item)
    if not take then return nil end

    local source = reaper.GetMediaItemTake_Source(take)
    if not source then return nil end

    local _, sourceName = reaper.GetMediaSourceFileName(source, "")
    return sourceName
end

-- Save original selection as track/time ranges + source names where available
local originalSelectionRanges = {}

for i = 0, reaper.CountSelectedMediaItems(0) - 1 do
    local item = reaper.GetSelectedMediaItem(0, i)
    local track = reaper.GetMediaItem_Track(item)
    local pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    local len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")

    table.insert(originalSelectionRanges, {
        track = track,
        startPos = pos,
        endPos = pos + len,
        sourceName = getItemSourceName(item)
    })
end

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
    if a.trackIndex == b.trackIndex then
        return a.position < b.position
    else
        return a.trackIndex < b.trackIndex
    end
end)

-- Group into healable chunks
local chunks = {}
local currentChunk = {}

for _, item in ipairs(selectedItems) do
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
            if #currentChunk > 1 then
                table.insert(chunks, currentChunk)
            end
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
        if reaper.ValidatePtr(entry.item, "MediaItem*") then
            reaper.SetMediaItemSelected(entry.item, true)
        end
    end

    reaper.Main_OnCommand(40548, 0) -- Heal splits in items (preserve timing)
end

-- Restore apparent original selection
reaper.Main_OnCommand(40289, 0) -- Unselect all

for _, range in ipairs(originalSelectionRanges) do
    if reaper.ValidatePtr(range.track, "MediaTrack*") then
        local itemCount = reaper.CountTrackMediaItems(range.track)

        for i = 0, itemCount - 1 do
            local item = reaper.GetTrackMediaItem(range.track, i)
            local pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
            local len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
            local itemEnd = pos + len
            local itemSourceName = getItemSourceName(item)

            local overlapsOriginalRange =
                itemEnd >= (range.startPos - tolerance) and
                pos <= (range.endPos + tolerance)

            -- Source safeguard:
            -- If the originally selected item had a readable source name,
            -- require the restored item to match that source.
            -- If not, allow restore based on track/range only,
            -- which keeps empty items and source-less items working.
            local sameSource =
                range.sourceName == nil or
                range.sourceName == "" or
                itemSourceName == range.sourceName

            if overlapsOriginalRange and sameSource then
                reaper.SetMediaItemSelected(item, true)
            end
        end
    end
end

reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()
reaper.Undo_EndBlock("Heal contiguous/overlapping splits within 1 frame", -1)