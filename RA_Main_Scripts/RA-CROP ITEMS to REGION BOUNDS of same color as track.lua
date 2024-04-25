-- @version 1.0
-- @description Crop items to region bounds of same color as track.
-- @author RESERVOIR AUDIO / MrBrock, with AI.


-- Tolerance of out of bound items set to 30% (or 70% in bound if you prefer) 

reaper.Undo_BeginBlock() -- Start of Undo block

-- Initialize table to store region data
local regionsTable = {}

-- Get all regions
local i = 0
repeat
    local retval, isRegion, pos, rgnEnd, name, markrgnIndex, color = reaper.EnumProjectMarkers3(0, i)
    if retval ~= 0 and isRegion then
        table.insert(regionsTable, {pos = pos, rgnEnd = rgnEnd, color = color})
    end
    i = i + 1
until retval == 0

-- Function to get item's track color
local function getItemTrackColor(item)
    local track = reaper.GetMediaItem_Track(item)
    return reaper.GetTrackColor(track)
end

-- Build a table of items to delete
local itemsToDelete = {}
local itemCount = reaper.CountSelectedMediaItems(0)
for i = 0, itemCount - 1 do
    local item = reaper.GetSelectedMediaItem(0, i)
    local itemPos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    local itemLength = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
    local itemEnd = itemPos + itemLength
    local trackColor = getItemTrackColor(item)

    -- Check item against regions
    local deleteItem = true
    for _, region in ipairs(regionsTable) do
        if trackColor == region.color then -- Match by color
            local overlapStart = math.max(itemPos, region.pos)
            local overlapEnd = math.min(itemEnd, region.rgnEnd)
            local overlapLength = math.max(0, overlapEnd - overlapStart)
            if (overlapLength / itemLength) >= 0.7 then -- At least 70% overlap
                deleteItem = false
                break
            end
        end
    end

    if deleteItem then
        table.insert(itemsToDelete, item)
    end
end

-- Delete the items
for _, item in ipairs(itemsToDelete) do
    reaper.DeleteTrackMediaItem(reaper.GetMediaItem_Track(item), item)
end

reaper.UpdateArrange() -- Update the arrangement
reaper.Undo_EndBlock("Delete Unmatched Items", -1) -- End of Undo block

