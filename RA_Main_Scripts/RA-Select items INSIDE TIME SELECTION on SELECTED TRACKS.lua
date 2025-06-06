-- @description Select items fully within time selection on selected tracks (optimized for speed)
-- @version 1.0
-- @author MrBrock with AI

local function main()
  -- Get current time selection (start, end)
  local sel_start, sel_end = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)
  if not sel_start or not sel_end or sel_end <= sel_start then return end

  local items_to_select = {}
  local track_count = reaper.CountSelectedTracks(0)

  for i = 0, track_count - 1 do
    local track = reaper.GetSelectedTrack(0, i)
    local item_count = reaper.CountTrackMediaItems(track)
    for j = 0, item_count - 1 do
      local item = reaper.GetTrackMediaItem(track, j)
      local pos    = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
      local length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
      local item_end = pos + length
      if pos >= sel_start and item_end <= sel_end then
        items_to_select[#items_to_select + 1] = item
      end
    end
  end

  reaper.PreventUIRefresh(1)
  reaper.Main_OnCommand(40289, 0)
  for _, item in ipairs(items_to_select) do
    reaper.SetMediaItemSelected(item, true)
  end
  reaper.UpdateArrange()
  reaper.PreventUIRefresh(-1)
end

reaper.Undo_BeginBlock()
main()
reaper.Undo_EndBlock("Select items within time selection on selected tracks", -1)

