-- @version 1.0
-- @description TC set Region bounds to defined FORMAT based on selected items (0.5s lead in - 1s lead out)
-- @author RESERVOIR AUDIO / Fante + AI

-- The script looks for the nearest region that fits the bounds of selected items.

reaper.Undo_BeginBlock()


-- Get selected item range
local itemCount = reaper.CountSelectedMediaItems(0)
if itemCount == 0 then return end

local firstPos = math.huge
local lastEnd = -math.huge

for i = 0, itemCount - 1 do
    local item = reaper.GetSelectedMediaItem(0, i)
    local pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    local len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
    firstPos = math.min(firstPos, pos)
    lastEnd = math.max(lastEnd, pos + len)
end

-- Extend bounds
local newStart = firstPos - 0.5
local newEnd = lastEnd + 1.0
local center = (newStart + newEnd) / 2

-- Loop through regions
local _, numMarkers, numRegions = reaper.CountProjectMarkers(0)
local bestEnclosingIndex = nil
local smallestEnclosingLength = math.huge

local closestIndex = nil
local closestDist = math.huge

for i = 0, numMarkers + numRegions - 1 do
    local retval, isRegion, regStart, regEnd, _, idx = reaper.EnumProjectMarkers(i)
    if isRegion then
        local regLen = regEnd - regStart

        -- Case 1: Region fully encloses new bounds
        if regStart <= newStart and regEnd >= newEnd then
            if regLen < smallestEnclosingLength then
                smallestEnclosingLength = regLen
                bestEnclosingIndex = idx
            end
        end

        -- Case 2: Track closest region to center
        local dist = math.abs(((regStart + regEnd) / 2) - center)
        if dist < closestDist then
            closestDist = dist
            closestIndex = idx
        end
    end
end

-- Determine which region to update
local regionToUpdate = bestEnclosingIndex or closestIndex
if regionToUpdate then
    -- Get region name
    local _, _, _, _, name, _ = reaper.EnumProjectMarkers(regionToUpdate)

    -- Remove old region and insert updated one
    reaper.DeleteProjectMarker(0, regionToUpdate, true)
    reaper.AddProjectMarker2(0, true, newStart, newEnd, name, -1, 0)
end

reaper.Undo_EndBlock("Resize region to fit selected items with offset", -1)

