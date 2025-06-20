-- @version 1.0
-- @description Set item start offset relative to cursor distance.
-- @author RESERVOIR AUDIO / MrBrock, with AI.

function set_start_offset_relative_to_cursor()
  local cursor_pos = reaper.GetCursorPosition()
  local item_count = reaper.CountSelectedMediaItems(0)

  for i = 0, item_count - 1 do
    local item = reaper.GetSelectedMediaItem(0, i)
    local item_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    local take = reaper.GetActiveTake(item)

    if take then
      local offset = item_pos - cursor_pos
      reaper.SetMediaItemTakeInfo_Value(take, "D_STARTOFFS", offset)

    end
  end

  reaper.UpdateArrange()
end

reaper.Undo_BeginBlock()
set_start_offset_relative_to_cursor()
reaper.Undo_EndBlock("Set start offset relative to edit cursor", -1)

