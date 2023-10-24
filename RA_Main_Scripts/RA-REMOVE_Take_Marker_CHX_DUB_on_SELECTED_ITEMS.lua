-- @version 1.0
-- @description REMOVES Take Markers named CHX-DUB to SELECTED ITEMS.
-- @author RESERVOIR AUDIO / Amel Desharnais, with AI.

reaper.Undo_BeginBlock()

local function getChxDubTakeMarkerIndex(take)
    local markerCount = reaper.GetNumTakeMarkers(take)
    for j = 0, markerCount - 1 do
        local _, name = reaper.GetTakeMarker(take, j)
        if name:find("chx dub") then  -- Changed from exact match to a search
            return j
        end
    end
    return nil
end

-- Iterate over all selected items
local selItemCount = reaper.CountSelectedMediaItems(0)
for i = 0, selItemCount - 1 do
    local item = reaper.GetSelectedMediaItem(0, i)
    local activeTake = reaper.GetActiveTake(item)
    if activeTake then
        local markerIndex = getChxDubTakeMarkerIndex(activeTake)
        while markerIndex do  -- loop ensures to remove all markers containing "chx dub" if there are multiple
            reaper.DeleteTakeMarker(activeTake, markerIndex)
            markerIndex = getChxDubTakeMarkerIndex(activeTake)
        end
    end
end

reaper.Undo_EndBlock("Remove all take markers containing 'chx dub' from selected items", -1)

