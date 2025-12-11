-- @description Scale start offset of selected takes based on FPS ratio
-- @version 1.0
-- @author Réservoir Audio / Fante with AI
-- Example: 25fps source -> 23.976 timeline:
--  start 19:24.246 (1164.246s) becomes 18:36.558 (1116.558s)

function main()
  local ok, csv = reaper.GetUserInputs(
    "Scale source IN by FPS",
    2,
    "Source FPS (e.g. 25),Timeline FPS (e.g. 23.976)",
    "25,23.976"
  )
  if not ok then return end

  local src_str, tl_str = csv:match("([^,]+),([^,]+)")
  local src_fps = tonumber(src_str)
  local tl_fps  = tonumber(tl_str)

  if not src_fps or not tl_fps or src_fps <= 0 or tl_fps <= 0 then
    reaper.ShowMessageBox("Invalid FPS values.", "Error", 0)
    return
  end

  -- This is the key:
  -- new_start = old_start * (timeline_fps / source_fps)
  local factor = tl_fps / src_fps

  local cnt = reaper.CountSelectedMediaItems(0)
  if cnt == 0 then
    reaper.ShowMessageBox("No items selected.", "Error", 0)
    return
  end

  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(1)

  for i = 0, cnt-1 do
    local item = reaper.GetSelectedMediaItem(0, i)
    local take = reaper.GetActiveTake(item)
    if take and not reaper.TakeIsMIDI(take) then
      local start_offs = reaper.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS") -- seconds into source
      local new_offs   = start_offs * factor
      if new_offs < 0 then new_offs = 0 end -- safety
      reaper.SetMediaItemTakeInfo_Value(take, "D_STARTOFFS", new_offs)
    end
  end

  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()
  reaper.Undo_EndBlock("Scale source IN by FPS", -1)
end

main()

