-- @version 1.0
-- @description Set ITEM POSITION to user defined INTERVALS (DF/NTSC-aware, no overlap)
-- @author RESERVOIR AUDIO / MrBrock, with AI.

--[[
  — treating any non-zero frames as +1 sec when ceiling
--]]

-- Prompt for the interval (seconds)
local ok, user_input = reaper.GetUserInputs("Snap Interval", 1, "Interval (seconds):", "30")
if not ok then return end
local INTERVAL = tonumber(user_input)
if not INTERVAL or INTERVAL <= 0 then
  reaper.ShowMessageBox("Please enter a positive number for the interval.","Error",0)
  return
end

-- floor to previous INTERVAL boundary (frame “00”)
local function snap_to_prev_tc(pos)
  local tc = reaper.format_timestr_pos(pos, "", 5)
  local h,m,s = tc:match("(%d+):(%d+):(%d+):%d+")
  local total = tonumber(h)*3600 + tonumber(m)*60 + tonumber(s)
  local slot  = math.floor(total / INTERVAL) * INTERVAL
  local hh    = math.floor(slot/3600)
  local mm    = math.floor((slot%3600)/60)
  local ss    = slot % 60
  return reaper.parse_timestr_pos(
    string.format("%02d:%02d:%02d:00", hh, mm, ss),
    5
  )
end

-- ceil to next INTERVAL boundary, counting any frames as +1 second
local function snap_to_next_tc(pos)
  local tc = reaper.format_timestr_pos(pos, "", 5)
  local h,m,s,f = tc:match("(%d+):(%d+):(%d+):(%d+)")
  local total = tonumber(h)*3600 + tonumber(m)*60 + tonumber(s) + (tonumber(f) > 0 and 1 or 0)
  local slot  = math.ceil(total / INTERVAL) * INTERVAL
  local hh    = math.floor(slot/3600)
  local mm    = math.floor((slot%3600)/60)
  local ss    = slot % 60
  return reaper.parse_timestr_pos(
    string.format("%02d:%02d:%02d:00", hh, mm, ss),
    5
  )
end

reaper.Undo_BeginBlock()

-- collect & sort selected items
local items = {}
for i = 0, reaper.CountSelectedMediaItems(0)-1 do
  local it  = reaper.GetSelectedMediaItem(0, i)
  local pos = reaper.GetMediaItemInfo_Value(it, "D_POSITION")
  local len = reaper.GetMediaItemInfo_Value(it, "D_LENGTH")
  table.insert(items, { item = it, pos = pos, length = len })
end
if #items == 0 then 
  reaper.Undo_EndBlock("", -1)
  return
end
table.sort(items, function(a,b) return a.pos < b.pos end)

-- first item
local first   = items[1]
local newPos1 = snap_to_prev_tc(first.pos)
reaper.SetMediaItemInfo_Value(first.item, "D_POSITION", newPos1)
local prevEnd = newPos1 + first.length

-- subsequent items
for i = 2, #items do
  local e       = items[i]
  local nextPos = snap_to_next_tc(prevEnd)
  reaper.SetMediaItemInfo_Value(e.item, "D_POSITION", nextPos)
  prevEnd = nextPos + e.length
end

reaper.UpdateArrange()
reaper.Undo_EndBlock(
  string.format("Snap selected items to %d-s TC slots (no overlap)", INTERVAL),
  -1
)

