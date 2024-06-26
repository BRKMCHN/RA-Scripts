-- @version 2.2
-- @description Shorten selected ITEM EDGES.
-- @author RESERVOIR AUDIO / MrBrock adapted with AI.
-- @about This script will Shorten selected ITEM EDGES by defined ammount at top of script, using nudge tool.

-- Shorten selected item edges by a specified number of frames using stored properties

-- Amount of frames to nudge
local frames_to_nudge = 15  -- Change this value to nudge by a different number of frames

-- Main function
local function nudge_trim_edges(frames)
  local num_items = reaper.CountSelectedMediaItems(0)
  if num_items == 0 then return end

  reaper.Undo_BeginBlock()

  for i = 0, num_items - 1 do
    local item = reaper.GetSelectedMediaItem(0, i)
    -- (Project, NudgeMode, NudgeWhat ( 1=left trim, 2=left edge (stretch), 3=right trim, 4=content)
    
      --Left
        reaper.ApplyNudge(0, 0, 1, 18, frames, false, 0)
      --Right
        reaper.ApplyNudge(0, 0, 3, 18, frames, true, 0)
  end

  reaper.Undo_EndBlock("Nudge trims by " .. frames .. " frames", -1)
  reaper.UpdateArrange()
end

nudge_trim_edges(frames_to_nudge)
