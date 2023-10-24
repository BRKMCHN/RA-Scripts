-- @version 1.0
-- @description UNSELECT MUTED ITEMS among currently selected items.
-- @author RESERVOIR AUDIO / Fante + AI

-- Get the current project
local project = reaper.EnumProjects(-1, "")

-- Store the selected items in a table
local selectedItems = {}

-- Get the number of selected items
local numSelectedItems = reaper.CountSelectedMediaItems(project)

-- Iterate over the selected items and store them in the table
for i = 0, numSelectedItems - 1 do
    local selectedItem = reaper.GetSelectedMediaItem(project, i)
    selectedItems[#selectedItems + 1] = selectedItem
end

-- Unselect all selected items
reaper.Main_OnCommand(40289, 0) -- "Unselect all items" command

-- Iterate over the stored items and reselect them if they are not muted
for i = 1, #selectedItems do
    local selectedItem = selectedItems[i]
    local isMuted = reaper.GetMediaItemInfo_Value(selectedItem, "B_MUTE") == 1
    
    if not isMuted then
        reaper.SetMediaItemSelected(selectedItem, true)
    end
end

-- Update the arrange view
reaper.UpdateArrange()

