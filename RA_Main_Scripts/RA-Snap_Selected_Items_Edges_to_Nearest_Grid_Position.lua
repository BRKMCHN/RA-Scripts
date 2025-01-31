-- @version 1.0
-- @description Snap selected item's edges to nearest grid position.
-- @author RESERVOIR AUDIO / MrBrock, with AI.

-- Safety check for SWS:
if not reaper.BR_GetClosestGridDivision then
  reaper.ShowMessageBox(
    "SWS extension is required for BR_GetClosestGridDivision.\n\nDownload at: https://www.sws-extension.org/",
    "Error", 0
  )
  return
end

local itemCount = reaper.CountSelectedMediaItems(0)
if itemCount == 0 then return end

reaper.Undo_BeginBlock()

for i = 0, itemCount-1 do
  local item = reaper.GetSelectedMediaItem(0, i)
  if item then
    local pos    = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    local length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
    local take   = reaper.GetActiveTake(item)
    if take then
      local startOffs = reaper.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS")

      ------------------------------------------------------
      -- Step #1: Snap the LEFT edge to the nearest grid.
      ------------------------------------------------------
      local gridPosLeft = reaper.BR_GetClosestGridDivision(pos)
      local diffLeft    = pos - gridPosLeft

      -- Using the same logic as your first script:
      local newPos       = pos - diffLeft                -- = gridPosLeft
      local newStartOffs = startOffs - diffLeft
      local newLength    = length + diffLeft

      ------------------------------------------------------
      -- Step #2: Snap the RIGHT edge to the nearest grid.
      --   After step #1, the item left edge is newPos,
      --   so the right edge time is (newPos + newLength).
      --   We find that position’s nearest grid, then
      --   adjust only item length so the right boundary
      --   lands there. We do NOT move the item again.
      ------------------------------------------------------
      local oldEnd   = newPos + newLength
      local gridPosRight = reaper.BR_GetClosestGridDivision(oldEnd)
      local diffRight    = oldEnd - gridPosRight  -- how far we are from that grid line

      local finalLength = newLength - diffRight   -- so right edge = gridPosRight

      ------------------------------------------------------
      -- Handle weird edge cases: if final length < 0, skip
      ------------------------------------------------------
      if finalLength < 0.0000001 then
        -- If snapping right boundary overshoots so far
        -- it would invert or vanish the item, you can
        -- skip, clamp, or do whatever you prefer.
        goto continue
      end

      ------------------------------------------------------
      -- Set final values for the item
      ------------------------------------------------------
      reaper.SetMediaItemInfo_Value(item, "D_POSITION",        newPos)
      reaper.SetMediaItemInfo_Value(item, "D_LENGTH",          finalLength)
      reaper.SetMediaItemTakeInfo_Value(take, "D_STARTOFFS",   newStartOffs)

    end
  end
  ::continue::
end

reaper.UpdateArrange()
reaper.Undo_EndBlock("Snap left and right edges to nearest grid", -1)

