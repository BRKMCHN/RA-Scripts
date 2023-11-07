-- @version 1.0
-- @description Create MARKERS at edges of selected items, skipping item edges that overlap with others.
-- @author RESERVOIR AUDIO / MrBrock, with AI.

-- USER CONFIG AREA -----------------------------------------------------------

console = true -- true/false: display debug messages in the console

------------------------------------------------------- END OF USER CONFIG AREA

-- UTILITIES -------------------------------------------------------------

-- Save item selection
function SaveSelectedItems()
    for i = 0, count_sel_items - 1 do
        local entry = {}
        entry.item = reaper.GetSelectedMediaItem(0, i)
        entry.pos_start = reaper.GetMediaItemInfo_Value(entry.item, "D_POSITION")
        entry.pos_end = entry.pos_start + reaper.GetMediaItemInfo_Value(entry.item, "D_LENGTH")
        table.insert(init_sel_items, entry)
    end
end

-- Create a table of all possible marker positions
function CreateMarkerPositions()
    local positions = {}
    for _, item in ipairs(init_sel_items) do
        table.insert(positions, item.pos_start)
        table.insert(positions, item.pos_end)
    end
    return positions
end

-- Remove positions that overlap with any item
function RemoveOverlappingPositions(positions)
    local filteredPositions = {}
    for _, position in ipairs(positions) do
        local overlap = false
        for _, item in ipairs(init_sel_items) do
            if position > item.pos_start and position < item.pos_end then
                overlap = true
                break
            end
        end
        if not overlap then
            table.insert(filteredPositions, position)
        end
    end
    return filteredPositions
end

-- Display a message in the console for debugging
function Msg(value)
    if console then
        reaper.ShowConsoleMsg(tostring(value) .. "\n")
    end
end

--------------------------------------------------------- END OF UTILITIES

-- Main function
function Main()
    local markerPositions = CreateMarkerPositions()
    local filteredPositions = RemoveOverlappingPositions(markerPositions)

    for i, position in ipairs(filteredPositions) do
        local markerName = "Marker " .. i
        reaper.AddProjectMarker2(0, false, position, 0, markerName, -1, 0)
    end
end

-- INIT

-- See if there are items selected
count_sel_items = reaper.CountSelectedMediaItems(0)

if count_sel_items > 0 then
    reaper.PreventUIRefresh(1)
    reaper.Undo_BeginBlock() -- Beginning of the undo block. Leave it at the top of your main function.
    reaper.ClearConsole()
    init_sel_items = {}
    SaveSelectedItems(init_sel_items)
    Main()
    reaper.Undo_EndBlock("Create markers at the edges of selected items (ignoring overlapping items)", -1) -- End of the undo block. Leave it at the bottom of your main function.
    reaper.UpdateArrange()
    reaper.PreventUIRefresh(-1)
end

