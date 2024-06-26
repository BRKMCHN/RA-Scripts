-- @version 2.0
-- @description Extend selected ITEM EDGES preserving source limit.
-- @author RESERVOIR AUDIO / MrBrock adapted with AI.
-- @about This script will Extend selected ITEM EDGES by 20 frames (or user defined at top of script) while remaining within contents of the source. This script will write a text file to preserve orginal positionning data.

-- Extend selected item edges by a specified number of frames and save original properties
local frames_to_extend = 20  -- Change this value to extend by a different number of frames

-- Function to get project directory
local function get_project_directory()
  local _, project_path = reaper.EnumProjects(-1, "")
  if project_path == "" then
    return nil
  end
  return project_path:match("(.*/)")
end

-- Function to create directory if it doesn't exist
local function create_directory(path)
  if not reaper.RecursiveCreateDirectory(path, 0) then
    reaper.ShowMessageBox("Unable to create directory: " .. path, "Error", 0)
    return false
  end
  return true
end

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

  local project_directory = get_project_directory()
  if not project_directory then
    reaper.ShowMessageBox("Please save the project first.", "Error", 0)
    return
  end
  
  local sources_folder = project_directory .. "auto-align_temp/"
  
  if not create_directory(sources_folder) then return end
  
  local file_path = sources_folder .. "Align_item_properties.txt"
  local file = io.open(file_path, "w")
  if not file then
    reaper.ShowMessageBox("Unable to create file: " .. file_path, "Error", 0)
    return
  end
  
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
      
      -- Write original properties to file
      file:write(pos, "\t", start_offs, "\t", length, "\n")
      
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
  
  file:close()
  reaper.Undo_EndBlock("Extend item edges by " .. frames .. " frames", -1)
  reaper.UpdateArrange()
end

extend_item_edges(frames_to_extend)
