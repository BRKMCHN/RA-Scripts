-- @description Move item chunks to selected track maintaining group proportions
-- @version 1.1
-- @author Reservoir Audio / Mr.Brock with AI

-- Start of Undo block
reaper.Undo_BeginBlock()

-- Function to get group membership of an item
local function getItemGroupMembership(item)
    local itemGroup = reaper.GetMediaItemInfo_Value(item, "I_GROUPID")
    if itemGroup ~= nil and itemGroup ~= -1 then
        return itemGroup
    else
        return "No group"
    end
end

-- Function to get the earliest item on the lowest numbered track within each group
local function getEarliestItemInGroup(selectedItems)
    local groupItems = {}
    for _, item in ipairs(selectedItems) do
        local group = getItemGroupMembership(item)
        if not groupItems[group] then
            groupItems[group] = item
        else
            local currentItemTrack = reaper.GetMediaItem_Track(item)
            local existingItem = groupItems[group]
            local existingItemTrack = reaper.GetMediaItem_Track(existingItem)
            local currentItemTrackNumber = reaper.GetMediaTrackInfo_Value(currentItemTrack, "IP_TRACKNUMBER")
            local existingItemTrackNumber = reaper.GetMediaTrackInfo_Value(existingItemTrack, "IP_TRACKNUMBER")
            if currentItemTrackNumber < existingItemTrackNumber then
                groupItems[group] = item
            elseif currentItemTrackNumber == existingItemTrackNumber then
                local currentItemPos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
                local existingItemPos = reaper.GetMediaItemInfo_Value(existingItem, "D_POSITION")
                if currentItemPos < existingItemPos then
                    groupItems[group] = item
                end
            end
        end
    end
    return groupItems
end

-- Function to get the selected track number
local function getSelectedTrackNumber(track)
    for i = 0, reaper.CountTracks(0) - 1 do
        if reaper.GetTrack(0, i) == track then
            return i
        end
    end
end

-- Move items to selected track maintaining group proportions
local selectedItems = {}
local itemCount = reaper.CountSelectedMediaItems(0)
local missingTrackCount = 0
for i = 0, itemCount - 1 do
    local item = reaper.GetSelectedMediaItem(0, i)
    table.insert(selectedItems, item)
end

local earliestItemInGroup = getEarliestItemInGroup(selectedItems)
local selectedTrack = reaper.GetSelectedTrack(0, 0) -- Assume the first selected track is the destination track
local selectedTrackNumber = getSelectedTrackNumber(selectedTrack)

if selectedTrack and next(earliestItemInGroup) ~= nil then
    -- Calculate differences in track numbers between each selected item and the reference item
    local trackDifferences = {}
    for _, item in ipairs(selectedItems) do
        local itemTrack = reaper.GetMediaItem_Track(item)
        local itemTrackNumber = getSelectedTrackNumber(itemTrack)
        local referenceTrackNumber = getSelectedTrackNumber(reaper.GetMediaItem_Track(earliestItemInGroup[getItemGroupMembership(item)]))
        if itemTrackNumber and referenceTrackNumber then
            trackDifferences[item] = selectedTrackNumber - referenceTrackNumber + itemTrackNumber - referenceTrackNumber
        else
            missingTrackCount = missingTrackCount + 1
        end
    end

    -- Move items to target track maintaining group proportions
    for group, earliestItem in pairs(earliestItemInGroup) do
        local earliestItemTrack = reaper.GetMediaItem_Track(earliestItem)
        local earliestItemTrackNumber = getSelectedTrackNumber(earliestItemTrack)

        -- Calculate differences in track numbers among items of the same group and relative vertical layout
        local groupItems = {}
        local minTrackDifference = math.huge
        for _, item in ipairs(selectedItems) do
            local itemGroup = getItemGroupMembership(item)
            if itemGroup == group then
                local trackDifference = trackDifferences[item]
                if trackDifference < minTrackDifference then
                    minTrackDifference = trackDifference
                end
                table.insert(groupItems, { item = item, trackDifference = trackDifference })
            end
        end

        -- Move items to target track maintaining group proportions
        for _, groupItem in ipairs(groupItems) do
            local item = groupItem.item
            local trackDifference = groupItem.trackDifference
            local newTrackNumber = selectedTrackNumber - minTrackDifference + trackDifference
            local track = reaper.GetTrack(0, newTrackNumber)
            if track then
                reaper.MoveMediaItemToTrack(item, track)
            end
        end
    end
else
    reaper.ShowMessageBox("Please select at least one item and one track.", "Error", 0)
end

-- Report the number of items for which track couldn't be found
if missingTrackCount > 0 then
    reaper.ShowMessageBox("Couldn't find media track for "..missingTrackCount.." items.", "Track not found", 0)
end

-- Update the arrange view
reaper.UpdateArrange()

-- End of Undo block
reaper.Undo_EndBlock("Move items to selected track maintaining group proportions", -1)

