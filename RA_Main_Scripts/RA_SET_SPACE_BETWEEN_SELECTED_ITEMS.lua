-- @description SET SPACE BETWEEN SELECTED ITEMS (prompted user defined value)
-- @version 1.0
-- @author Reservoir Audio / Amel with AI
-- @about Sets a user defined amount of time between each selected item, preserving start position of first selected item.

reaper.Undo_BeginBlock()

-- Get number of selected items
local item_count = reaper.CountSelectedMediaItems(0)
if item_count < 2 then
    reaper.ShowMessageBox("Select at least two items!", "Error", 0)
    return
end

-- Collect selected items and sort by position
local items = {}
for i = 0, item_count - 1 do
    local item = reaper.GetSelectedMediaItem(0, i)
    table.insert(items, { item = item, pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION") })
end

table.sort(items, function(a, b) return a.pos < b.pos end) -- Sort items by position

-- Prompt user for new time gap
retval, user_input = reaper.GetUserInputs("Enter New Space Time", 1, "New Gap (mm:ss:ms)", "00:01:000")
if not retval then return end -- Exit if cancelled

-- Convert mm:ss:ms to total seconds
local min, sec, ms = user_input:match("(%d+):(%d+):(%d+)")
if not min or not sec or not ms then
    reaper.ShowMessageBox("Invalid format! Use mm:ss:ms (e.g., 00:01:500)", "Error", 0)
    return
end

local new_gap = (tonumber(min) * 60) + tonumber(sec) + (tonumber(ms) / 1000)

-- Apply new spacing
for i = 2, #items do
    local prev_item = items[i - 1].item
    local prev_end = reaper.GetMediaItemInfo_Value(prev_item, "D_POSITION") +
                     reaper.GetMediaItemInfo_Value(prev_item, "D_LENGTH")
    
    local cur_item = items[i].item
    local new_pos = prev_end + new_gap
    
    reaper.SetMediaItemInfo_Value(cur_item, "D_POSITION", new_pos)
end

reaper.UpdateArrange()
reaper.Undo_EndBlock("Adjust Space Between Items", -1)

