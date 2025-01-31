-- @version 1.0
-- @description Select items on selected track exactly at edit Cursor
-- @author MrBrock / AI

--[[  * About:
      This script measures the current grid spacing, then uses
      1/10th of that spacing as a tolerance around the edit cursor.
      Any item whose start time is within that tolerance gets selected;
      all others are de-selected.
--]]

function main()
  reaper.Undo_BeginBlock()

  -- Get current grid spacing in seconds
  --    The second return value from GetSetProjectGrid is the current grid spacing
  local _, grid_spacing = reaper.GetSetProjectGrid(0, false)

  -- Tolerance is one quarter of the current grid spacing
  local tolerance = grid_spacing * 0.1

  -- Get cursor position
  local cursorPos = reaper.GetCursorPosition()

  -- Loop through all items in the project
  local itemCount = reaper.CountMediaItems(0)
  for i = 0, itemCount - 1 do
    local item = reaper.GetMediaItem(0, i)
    local itemStart = reaper.GetMediaItemInfo_Value(item, "D_POSITION")

    -- Check if the item start is within ± tolerance of the edit cursor
    if math.abs(itemStart - cursorPos) <= tolerance then
      reaper.SetMediaItemSelected(item, true)
    else
      reaper.SetMediaItemSelected(item, false)
    end
  end

  reaper.UpdateArrange()
  reaper.Undo_EndBlock("Select items near cursor within 1/4 grid spacing", -1)
end

main()

