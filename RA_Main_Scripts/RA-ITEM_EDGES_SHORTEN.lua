-- @version 1.1
-- @description Extend selected ITEM EDGES to original position.
-- @author RESERVOIR AUDIO / MrBrock adapted with AI.
-- @about This script will extend selected ITEM EDGES by ammount set by EXTEND script.

-- Shorten selected item edges by a specified number of frames using stored properties

-- Function to get project directory
local function get_project_directory()
  local _, project_path = reaper.EnumProjects(-1, "")
  if project_path == "" then
    return nil
  end
  return project_path:match("(.*/)")
end

-- Main function
local function shorten_item_edges()
  local num_items = reaper.CountSelectedMediaItems(0)
  if num_items == 0 then return end

  local project_directory = get_project_directory()
  if not project_directory then
    reaper.ShowMessageBox("Please save the project first.", "Error", 0)
    return
  end

  local sources_folder = project_directory .. "auto-align_temp/"
  local file_path = sources_folder .. "item_properties.txt"
  
  local file = io.open(file_path, "r")
  if not file then
    reaper.ShowMessageBox("Unable to open file: " .. file_path, "Error", 0)
    return
  end
  
  reaper.Undo_BeginBlock()
  
  for i = 0, num_items - 1 do
    local item = reaper.GetSelectedMediaItem(0, i)
    local pos, start_offs, length = file:read("*n", "*n", "*n")
    if pos and start_offs and length then
      local take = reaper.GetActiveTake(item)
      if take ~= nil then
        reaper.SetMediaItemInfo_Value(item, "D_POSITION", pos)
        reaper.SetMediaItemTakeInfo_Value(take, "D_STARTOFFS", start_offs)
        reaper.SetMediaItemInfo_Value(item, "D_LENGTH", length)
      end
    else
      reaper.ShowMessageBox("Mismatch between selected items and stored properties.", "Error", 0)
      break
    end
  end
  
  file:close()
  os.remove(file_path)  -- Delete the file after restoring properties
  
  reaper.Undo_EndBlock("Shorten item edges using stored properties", -1)
  reaper.UpdateArrange()
end

shorten_item_edges()
