-- @version 2.4
-- @description Extend selected ITEM EDGES.
-- @author RESERVOIR AUDIO / MrBrock adapted with AI.
-- @about This script will Extend selected ITEM EDGES by defined ammount at top of script, using nudge tool. Also adding take markers at loop points of source if it extends past loop points.

-- Amount of frames to nudge
local frames_to_nudge = 15  -- Change this value to nudge by a different number of frames

-- Function to get project frame rate
local function get_frame_rate()
  local frame_rate = reaper.TimeMap_curFrameRate(0)
  return frame_rate
end

-- Function to convert frames to seconds
local function frames_to_seconds(frames)
  local frame_rate = get_frame_rate()
  return frames_to_nudge / frame_rate
end

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

-- Function to place take markers at the start and end of the source
local function place_take_markers(items, frames)
  local seconds = frames_to_seconds(frames)
  for _, item in ipairs(items) do
    local take = reaper.GetActiveTake(item)
    
    if take ~= nil then
      local source = reaper.GetMediaItemTake_Source(take)
      local source_length = reaper.GetMediaSourceLength(source)
      local item_start_offset = reaper.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS")
      local item_length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
      
      local remaining_length = source_length - (item_start_offset + item_length)
      
      -- Check and add take marker at the start of the source
      if item_start_offset <= seconds then
        reaper.SetTakeMarker(take, -1, "Start", 0)
      end

      -- Check and add take marker at the end of the source
      if remaining_length <= seconds then
        reaper.SetTakeMarker(take, -1, "End", source_length)
      end
    end
  end
end

-- Function to nudge item edges
local function nudge_trim_edges(items, frames)
  for _, item in ipairs(items) do
    reaper.SelectAllMediaItems(0, false)  -- Deselect all items
    reaper.SetMediaItemSelected(item, true)  -- Select the current item

    local take = reaper.GetActiveTake(item)
    
    if take ~= nil then
      -- Apply nudge to left and right edges of the item
      reaper.ApplyNudge(0, 0, 1, 18, frames, true, 0)  -- Left trim
      reaper.ApplyNudge(0, 0, 3, 18, frames, false, 0)  -- Right trim
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
  local seconds = frames_to_seconds(frames_to_nudge)  -- Convert frames to seconds
  
  reaper.Undo_BeginBlock()
  
  place_take_markers(items, seconds)  -- Use seconds for marker conditions
  nudge_trim_edges(items, frames_to_nudge)
  
  reselect_items(items)
  
  reaper.Undo_EndBlock("Nudge trims by " .. frames_to_nudge .. " frames", -1)
  reaper.UpdateArrange()
end

main()
