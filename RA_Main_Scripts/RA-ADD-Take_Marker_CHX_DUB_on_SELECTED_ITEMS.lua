-- @version 1.0
-- @description Add Take Marker named CHX-DUB to SELECTED ITEMS.
-- @author RESERVOIR AUDIO / Amel Desharnais, with AI.


reaper.Undo_BeginBlock()

local function getChxDubTakeMarkerIndex(take)
    if not take then return nil end
    local markerCount = reaper.GetNumTakeMarkers(take)
    for j = 0, markerCount - 1 do
        local _, name = reaper.GetTakeMarker(take, j)
        if name:match("^chx dub") then
            return j
        end
    end
    return nil
end

local function getComplementaryColor(color)
    if color <= 0 then
        return reaper.ColorToNative(255, 255, 255) | 0x1000000
    end
    
    local r = 255 - ((color & 0xFF0000) >> 16)
    local g = 255 - ((color & 0x00FF00) >> 8)
    local b = 255 - (color & 0x0000FF)
    return reaper.ColorToNative(r, g, b) | 0x1000000
end

-- Get current date and time to append to the "CHX-DUB" marker
local currentTime = os.date("%Y-%m-%d %H:%M:%S")

-- Iterate over selected items
local selItemCount = reaper.CountSelectedMediaItems(0)
for i = 0, selItemCount - 1 do
    local item = reaper.GetSelectedMediaItem(0, i)
    if item then
        local itemColor = reaper.GetDisplayedMediaItemColor(item)
        local compColor = getComplementaryColor(itemColor)
        
        local takeCount = reaper.CountTakes(item)
        for j = 0, takeCount - 1 do
            local take = reaper.GetTake(item, j)
            if take and take == reaper.GetActiveTake(item) then
                -- Delete "chx dub" marker if it exists on this take
                local markerIndex = getChxDubTakeMarkerIndex(take)
                if markerIndex then
                    reaper.DeleteTakeMarker(take, markerIndex)
                end
                
                -- Calculate the middle position of the visible take
                local takeStartInSource = reaper.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS")
                local takeLength = reaper.GetMediaItemTakeInfo_Value(take, "D_PLAYRATE") * reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
                local middlePosition = takeStartInSource + (takeLength / 2)
                
                -- Add the take marker with the "chx dub" label, date, and time
                reaper.SetTakeMarker(take, -1, "chx dub " .. currentTime, middlePosition, compColor)
            end
        end
    end
end

reaper.Undo_EndBlock("Toggle 'chx dub' take markers with date and time in middle of active takes", -1)

