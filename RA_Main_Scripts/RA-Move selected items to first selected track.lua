-- @version 1.0
-- @description Move selected items to first selected track
-- @author RESERVOIR AUDIO / MrBrock, with AI

local r = reaper

local destTrack = r.GetSelectedTrack(0, 0)
if not destTrack then return end

local items = {}
local count = r.CountSelectedMediaItems(0)

-- Snapshot selection before moving anything
for i = 0, count - 1 do
  local item = r.GetSelectedMediaItem(0, i)

  if r.GetMediaItemTrack(item) ~= destTrack then
    items[#items + 1] = item
  end
end

if #items == 0 then return end

r.Undo_BeginBlock()
r.PreventUIRefresh(1)

for _, item in ipairs(items) do
  r.MoveMediaItemToTrack(item, destTrack)
end

r.UpdateArrange()
r.PreventUIRefresh(-1)
r.Undo_EndBlock("Move selected items to selected track", -1)

