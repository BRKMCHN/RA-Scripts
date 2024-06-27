-- @version 2.3
-- @description Shorten selected ITEM EDGES.
-- @author RESERVOIR AUDIO / MrBrock adapted with AI.
-- @about This script will Shorten selected ITEM EDGES by defined ammount at top of script, using nudge tool.

-- Amount of frames to nudge
local frames_to_nudge = 15  -- Change this value to nudge by a different number of frames

-- Function to get a table of selected items
local function get_selected_items()
  local items = {}
  local num_items = reaper.CountSelectedMediaItems(0)
  for i = 0, num_items - 1 do
    local item = reaper.GetSelectedMediaItem(0, i)
    table.insert(items, item)
  end
  return items
end

-- Function to nudge item edges
local function nudge_trim_edges(items, frames)
  for _, item in ipairs(items) do
    reaper.SelectAllMediaItems(0, false)  -- Deselect all items
    reaper.SetMediaItemSelected(item, true)  -- Select the current item

    local take = reaper.GetActiveTake(item)
    
    if take ~= nil then
      -- Apply nudge to shorten the left and right edges of the item
      reaper.ApplyNudge(0, 0, 1, 18, frames, false, 0)  -- Left trim, nudge false
      reaper.ApplyNudge(0, 0, 3, 18, frames, true, 0)   -- Right trim, nudge true
    end
  end
end

-- Function to reselect items
local function reselect_items(items)
  reaper.SelectAllMediaItems(0, false)  -- Deselect all items
  for _, item in ipairs(items) do
    reaper.SetMediaItemSelected(item, true)  -- Reselect the item
  end
end

-- Main function to call the separate functions and handle undo block and arrange update
local function main()
  local items = get_selected_items()
  
  reaper.Undo_BeginBlock()
  
  nudge_trim_edges(items, frames_to_nudge)
  
  reselect_items(items)
  
  reaper.Undo_EndBlock("Shorten trims by " .. frames_to_nudge .. " frames", -1)
  reaper.UpdateArrange()
end

main()
