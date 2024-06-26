-- @version 1.0
-- @description Duplicate previous take's markers.
-- @author RESERVOIR AUDIO / MrBrock adapted with AI.
-- @about This script will copy previous take's markers - relative to timeline - and apply them to current take.

function msg(message)
  reaper.ShowConsoleMsg(tostring(message) .. "\n")
end

-- Function to get take markers relative to the timeline
local function get_take_markers_relative(take)
  local markers = {}
  local item_start = reaper.GetMediaItemInfo_Value(reaper.GetMediaItemTake_Item(take), "D_POSITION")
  local num_markers = reaper.GetNumTakeMarkers(take)
  for i = 0, num_markers - 1 do
    local marker_pos, marker_name = reaper.GetTakeMarker(take, i)
    local project_pos = item_start + marker_pos
    table.insert(markers, {position = project_pos, name = marker_name})
  end
  return markers
end

-- Function to apply take markers at specified positions
local function apply_take_markers(take, markers, prev_start_offs)
  local item_start = reaper.GetMediaItemInfo_Value(reaper.GetMediaItemTake_Item(take), "D_POSITION")
  for _, marker in ipairs(markers) do
    local marker_pos = marker.position - item_start - prev_start_offs
    reaper.SetTakeMarker(take, -1, marker.name, marker_pos)
  end
end

-- Iterate over all selected items
local num_selected_items = reaper.CountSelectedMediaItems(0)
if num_selected_items == 0 then
  msg("No selected media items found!")
  return
end

for i = 0, num_selected_items - 1 do
  local item = reaper.GetSelectedMediaItem(0, i)
  if item == nil then
    msg("No selected media item found!")
    return
  end

  -- Get the active take of the selected item
  local take = reaper.GetActiveTake(item)
  if take == nil then
    msg("No active take found!")
    return
  end

  -- Get the previous take
  local take_index = reaper.GetMediaItemTakeInfo_Value(take, "IP_TAKENUMBER")
  if take_index == 0 then
    msg("No previous take found!")
    return
  end
  
  local prev_take = reaper.GetTake(item, take_index - 1)
  if prev_take == nil then
    msg("No previous take found!")
    return
  end

  -- Get markers from the previous take
  local prev_markers = get_take_markers_relative(prev_take)
  local prev_start_offs = reaper.GetMediaItemTakeInfo_Value(prev_take, "D_STARTOFFS")

  -- Apply markers to the current take, considering previous take's start offset
  apply_take_markers(take, prev_markers, prev_start_offs)
end

