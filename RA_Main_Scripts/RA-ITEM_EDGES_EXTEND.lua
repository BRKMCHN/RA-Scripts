-- @version 1.0
-- @description Shorten selected ITEM EDGES preserving source limit.
-- @author RESERVOIR AUDIO / MrBrock adapted with AI.
-- @about This script will shorten selected ITEM EDGES by 20 frames (or user defined at top of script) while remaining within contents of the source.

-- Extend selected item edges by a specified number of frames
local frames_to_extend = 20  -- Change this value to extend by a different number of frames

-- Convert frames to time based on project frame rate
local function frames_to_time(frames)
  local fps = reaper.TimeMap_curFrameRate(0)
  return frames / fps
end

-- Main function
local function extend_item_edges(frames)
  local num_items = reaper.CountSelectedMediaItems(0)
  if num_items == 0 then return end

  local extend_time = frames_to_time(frames)

  reaper.Undo_BeginBlock()
  
  for i = 0, num_items - 1 do
    local item = reaper.GetSelectedMediaItem(0, i)
    local pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    local length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
    local take = reaper.GetActiveTake(item)
    
    if take ~= nil then
      local start_offs = reaper.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS")
      local source = reaper.GetMediaItemTake_Source(take)
      local source_length = reaper.GetMediaSourceLength(source)

      -- Calculate new start offset and position
      local new_start_offs = start_offs - extend_time
      local new_pos = pos - extend_time

      -- Check if the new start offset is less than 0
      if new_start_offs < 0 then
        new_start_offs = 0
        new_pos = pos - start_offs  -- Move by the remaining start offset only
      end

      -- Calculate new length and ensure it does not exceed source length
      local new_length = length + 2 * extend_time
      local remaining_source_length = source_length - new_start_offs
      if remaining_source_length < new_length then
        new_length = remaining_source_length
      end

      -- Apply the calculated values
      reaper.SetMediaItemInfo_Value(item, "D_POSITION", new_pos)
      reaper.SetMediaItemTakeInfo_Value(take, "D_STARTOFFS", new_start_offs)
      reaper.SetMediaItemInfo_Value(item, "D_LENGTH", new_length)
    end
  end
  
  reaper.Undo_EndBlock("Extend item edges by " .. frames .. " frames", -1)
  reaper.UpdateArrange()
end

extend_item_edges(frames_to_extend)
