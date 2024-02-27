-- @version 1.1
-- @description REMOVE syncronized overlapping ITEMS from SAME SOURCE (keeping the longest unmuted item)
-- @author RESERVOIR AUDIO / MrBrock, with AI.
-- Current tolerance threshold for syncronicity check = 1/4 frame AND current overlap check threshold is 80% lenght of smallest item in pair compaired.

reaper.Undo_BeginBlock()

-- Get project frame rate and frame duration
local frameRate = reaper.TimeMap_curFrameRate(0)
local frameDuration = 1 / frameRate
local quarterFrameTime = frameDuration / 4

-- Function to get item details
local function getItemDetails(item)
    local position = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    local length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
    local track = reaper.GetMediaItem_Track(item)
    local trackNumber = track and reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER") or math.huge
    local take = reaper.GetActiveTake(item)
    local sourceStart = take and reaper.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS")
    local sourceName = take and reaper.GetMediaItemTake_Source(take) and reaper.GetMediaSourceFileName(reaper.GetMediaItemTake_Source(take), "")
    local isMuted = reaper.GetMediaItemInfo_Value(item, "B_MUTE") == 1
    return { item = item, position = position, length = length, trackNumber = trackNumber, sourceStart = sourceStart, sourceName = sourceName, isMuted = isMuted }
end

-- Function to check overlap between two items
local function itemsOverlap(item1, item2)
    return item1.position < (item2.position + item2.length) and item2.position < (item1.position + item1.length)
end

-- Function to check significant overlap between two items
local function itemsOverlapSignificantly(item1, item2)
    local overlap = math.min(item1.position + item1.length, item2.position + item2.length) - math.max(item1.position, item2.position)
    local smallestLength = math.min(item1.length, item2.length)
    return overlap >= 0.8 * smallestLength
end

-- Main script
local items = {}
for i = 0, reaper.CountSelectedMediaItems(0) - 1 do
    local item = reaper.GetSelectedMediaItem(0, i)
    table.insert(items, getItemDetails(item))
end

-- Items to delete
local itemsToDelete = {}

-- Check for overlaps and process items
for i = 1, #items do
    for j = i + 1, #items do
        if itemsOverlapSignificantly(items[i], items[j]) and items[i].sourceName == items[j].sourceName then
            local timeDiff = math.abs((items[i].position - items[i].sourceStart) - (items[j].position - items[j].sourceStart))
            if timeDiff <= quarterFrameTime then
                -- Determine the item to keep based on mute status first, then length
                local keepItemI
                if items[i].isMuted and not items[j].isMuted then
                    keepItemI = false
                elseif not items[i].isMuted and items[j].isMuted then
                    keepItemI = true
                else
                    -- Both items have the same mute status; keep the longest one
                    keepItemI = items[i].length >= items[j].length
                end
        
                -- Add the item not kept to itemsToDelete
                table.insert(itemsToDelete, keepItemI and items[j].item or items[i].item)
            end
        end
    end
end


-- Delete all items in the itemsToDelete table
for _, item in ipairs(itemsToDelete) do
    if reaper.ValidatePtr(item, "MediaItem*") then
        local track = reaper.GetMediaItem_Track(item)
        if track then
            reaper.DeleteTrackMediaItem(track, item)
        end
    end
end

-- Refresh UI and end undo block
reaper.UpdateArrange()
reaper.Undo_EndBlock("Delete Overlapping Items from Same Source Keeping the Longest One", -1)
