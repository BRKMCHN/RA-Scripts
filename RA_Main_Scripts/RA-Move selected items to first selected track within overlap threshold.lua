-- @version 1.0
-- @description Move selected items to first selected track within overlap threshold.
-- @author MrBrock adapted with AI.
-- @about This script will apply to selected items and check against themselves. The first selected track is the destination for the end result. On line 5, in the "check for overlaps" part of the script, the initial value of 0.3 means 300ms. You may change this to your preferred maximum overlap allowed.


reaper.Undo_BeginBlock()

-- Function to calculate overlap amount between two ranges
local function overlapAmount(start1, end1, start2, end2)
    return math.max(0, math.min(end1, end2) - math.max(start1, start2))
end

-- Get the number of selected media items
local numSelectedItems = reaper.CountSelectedMediaItems(0)
if numSelectedItems == 0 then
    reaper.ShowMessageBox("No items selected.", "Warning", 0)
    return
end

-- Get the selected track (assuming only one track is selected)
local numSelectedTracks = reaper.CountSelectedTracks(0)
if numSelectedTracks == 0 then
    reaper.ShowMessageBox("No track selected.", "Warning", 0)
    return
elseif numSelectedTracks > 1 then
    reaper.ShowMessageBox("Please select only one track.", "Warning", 0)
    return
end

local destTrack = reaper.GetSelectedTrack(0, 0)

-- Prepare items table
local items = {}
for i = 0, numSelectedItems-1 do
    local item = reaper.GetSelectedMediaItem(0, i)
    local st = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    local en = st + reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
    items[#items+1] = {
        it = item,
        st = st,
        en = en
    }
end

-- Check for overlaps
for i, srcItem in ipairs(items) do
    local canMove = true
    for j, otherItem in ipairs(items) do
        if i ~= j then
            local overlap = overlapAmount(srcItem.st, srcItem.en, otherItem.st, otherItem.en)
            if overlap > 0.3 then
                canMove = false
                break
            end
        end
    end
    if canMove then
        reaper.MoveMediaItemToTrack(srcItem.it, destTrack)
    end
end

reaper.UpdateArrange()
reaper.Undo_EndBlock("Move selected items to selected track without overlapping more than 300ms", -1)

