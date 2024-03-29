-- @version 1.0
-- @description Synchronize selected items relative to first selected item (based on source start offset only)(NOT BWF)
-- @author RESERVOIR AUDIO / MrBrock, with AI.

reaper.Undo_BeginBlock()
reaper.PreventUIRefresh(1)

local itemCount = reaper.CountSelectedMediaItems(0)

local itemProperties = {}

local function getItemProperties(item)
    local take = reaper.GetActiveTake(item)
    local source = reaper.GetMediaItemTake_Source(take)
    local sourceLength = reaper.GetMediaSourceLength(source)
    local itemStart = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    local startInSource = reaper.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS")

    return itemStart, startInSource, totalSourceLength
end

for i = 0, itemCount - 1 do
    local item = reaper.GetSelectedMediaItem(0, i)
    itemProperties[i] = {getItemProperties(item)}
end

local firstItem = itemProperties[0]
local firstItemTheoreticalStart = firstItem[1] - firstItem[2]

for i = 1, itemCount - 1 do
    local item = reaper.GetSelectedMediaItem(0, i)
    local currentItem = itemProperties[i]
    local currentItemTheoreticalStart = currentItem[1] - currentItem[2]
    local positionDifference = firstItemTheoreticalStart - currentItemTheoreticalStart
    reaper.SetMediaItemInfo_Value(item, "D_POSITION", currentItem[1] + positionDifference)
end

reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()
reaper.Undo_EndBlock("Synchronize selected items relative to first selected item (based on source start offset only)", -1)
