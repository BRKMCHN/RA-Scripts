-- @version 1.0
-- @description Set selected items nearest edges to 1 frame distance from edit cursor
-- @author RESERVOIR AUDIO / MrBrock, with AI.

--[[
Edit selected items relative to edit cursor:
- If most of the item is BEFORE the cursor (cursor >= midpoint): set RIGHT edge to cursor + 1 frame
- If most of the item is AFTER  the cursor (cursor <  midpoint): set LEFT  edge to cursor - 1 frame
When editing the LEFT edge, keep item content stationary by compensating take start offset.
]]

local proj = 0
local itemCount = reaper.CountSelectedMediaItems(proj)
if itemCount == 0 then return end

local cursor = reaper.GetCursorPosition()

-- Project FPS -> frame duration in seconds
local fps = reaper.TimeMap_curFrameRate(proj) -- returns current project framerate
if not fps or fps <= 0 then return end
local frame = 1.0 / fps

-- Safety minimum to avoid zero/negative lengths
local MIN_LEN = 1e-9

reaper.Undo_BeginBlock()
reaper.PreventUIRefresh(1)

for i = 0, itemCount - 1 do
  local item = reaper.GetSelectedMediaItem(proj, i)
  if item then
    local pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    local len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
    local itemEnd = pos + len
    local mid = pos + (len * 0.5)

    local take = reaper.GetActiveTake(item)
    if take then
      local startOffs = reaper.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS")

      if cursor >= mid then
        ----------------------------------------------------------------
        -- Edit RIGHT edge: end = cursor + 1 frame, position unchanged.
        ----------------------------------------------------------------
        local targetEnd = cursor + frame
        local newLen = targetEnd - pos

        if newLen > MIN_LEN then
          reaper.SetMediaItemInfo_Value(item, "D_LENGTH", newLen)
        end

      else
        ----------------------------------------------------------------
        -- Edit LEFT edge: start = cursor - 1 frame, end unchanged.
        -- Compensate take start offset so content stays in place.
        ----------------------------------------------------------------
        local targetPos = cursor - frame
        local delta = targetPos - pos -- how much the item position changes

        local newPos = targetPos
        local newLen = itemEnd - newPos

        if newLen > MIN_LEN then
          local newStartOffs = startOffs + delta
          reaper.SetMediaItemInfo_Value(item, "D_POSITION", newPos)
          reaper.SetMediaItemInfo_Value(item, "D_LENGTH", newLen)
          reaper.SetMediaItemTakeInfo_Value(take, "D_STARTOFFS", newStartOffs)
        end
      end
    end
  end
end

reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()
reaper.Undo_EndBlock("Edit item edge toward cursor ±1 frame (keep content)", -1)

