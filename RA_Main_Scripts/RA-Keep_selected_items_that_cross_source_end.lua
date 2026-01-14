-- @version 1.1
-- @description KEEP SELECTED ITEMS of clips that cross source end.

--[[
  Keep selected items that cross (wrap past) the end of their audio source.

  Logic:
    take_start_offset + (item_length * playrate) > source_length

  Notes:
    - Skips items with no active take, MIDI takes, or sources with unknown length.
    - Uses a small epsilon to avoid floating point edge cases.
--]]

local EPS = 1e-10

local function msg(s) reaper.ShowConsoleMsg(tostring(s) .. "\n") end

local function is_midi_take(take)
  return take and reaper.TakeIsMIDI(take)
end

local function get_source_length(take)
  local src = reaper.GetMediaItemTake_Source(take)
  if not src then return nil end

  -- GetMediaSourceLength returns (length, isQN)
  local length, _ = reaper.GetMediaSourceLength(src)
  if not length or length <= 0 then
    return nil
  end
  return length
end

local function crosses_source_end(item)
  local take = reaper.GetActiveTake(item)
  if not take or is_midi_take(take) then return false end

  local src_len = get_source_length(take)
  if not src_len then return false end

  -- Take start offset in source seconds
  local startoffs = reaper.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS") or 0.0

  -- Item length in project seconds
  local item_len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH") or 0.0
  if item_len <= 0 then return false end

  -- Take playrate affects source-time consumed
  local playrate = reaper.GetMediaItemTakeInfo_Value(take, "D_PLAYRATE") or 1.0
  if playrate <= 0 then return false end

  local source_time_used = item_len * playrate

  return (startoffs + source_time_used) > (src_len + EPS)
end

reaper.Undo_BeginBlock()
reaper.PreventUIRefresh(1)

local num_sel = reaper.CountSelectedMediaItems(0)
if num_sel == 0 then
  reaper.PreventUIRefresh(-1)
  reaper.Undo_EndBlock("Keep selected items that cross source end", -1)
  return
end

-- Collect first (since we'll change selection)
local items = {}
for i = 0, num_sel - 1 do
  items[#items + 1] = reaper.GetSelectedMediaItem(0, i)
end

-- Deselect all, then reselect only matches
for _, it in ipairs(items) do
  reaper.SetMediaItemSelected(it, false)
end

local kept = 0
for _, it in ipairs(items) do
  if crosses_source_end(it) then
    reaper.SetMediaItemSelected(it, true)
    kept = kept + 1
  end
end

reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()

reaper.Undo_EndBlock(("Keep selected items that cross source end (%d kept)"):format(kept), -1)
