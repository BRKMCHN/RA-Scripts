-- @description Align matching selected item pairs by source name
-- @version 1.0
-- @author MrBrock with AI

--Simultaneously align matching selected items by source name, excluding extension type or filepath.
--Keeps the first (by track/position) in place and moves its siblings to match.

reaper.Undo_BeginBlock()

-- helper to get filename (no path) and strip extension
local function get_basename(item)
  local take = reaper.GetActiveTake(item)
  if not take then return nil end
  local src = reaper.GetMediaItemTake_Source(take)
  local path = reaper.GetMediaSourceFileName(src, "")
  local fname = path:match("([^\\/]+)$")       -- strip directory
  return fname:match("(.+)%..+$") or fname     -- strip extension
end

-- collect selected items into groups by basename
local groups = {}
for i = 0, reaper.CountSelectedMediaItems(0)-1 do
  local itm = reaper.GetSelectedMediaItem(0, i)
  local base = get_basename(itm)
  if base then
    groups[base] = groups[base] or {}
    table.insert(groups[base], { item = itm, pos = reaper.GetMediaItemInfo_Value(itm, "D_POSITION") })
  end
end

-- for each group with >=2 items, find reference and move the rest
for _, list in pairs(groups) do
  if #list >= 2 then
    -- sort by track index (ascending), then by position (ascending)
    table.sort(list, function(a, b)
      local ta = reaper.GetMediaItemTrack(a.item)
      local tb = reaper.GetMediaItemTrack(b.item)
      local ia = reaper.GetMediaTrackInfo_Value(ta, "IP_TRACKNUMBER")
      local ib = reaper.GetMediaTrackInfo_Value(tb, "IP_TRACKNUMBER")
      if ia ~= ib then return ia < ib end
      return a.pos < b.pos
    end)

    -- reference is first in sorted list
    local refPos = reaper.GetMediaItemInfo_Value(list[1].item, "D_POSITION")
    -- move all others to refPos
    for i = 2, #list do
      reaper.SetMediaItemInfo_Value(list[i].item, "D_POSITION", refPos)
    end
  end
end

reaper.UpdateArrange()
reaper.Undo_EndBlock("Align matching items by filename", -1)

