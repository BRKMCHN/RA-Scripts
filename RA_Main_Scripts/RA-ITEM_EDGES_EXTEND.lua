-- @version 2.2
-- @description Extend selected ITEM EDGES.
-- @author RESERVOIR AUDIO / MrBrock adapted with AI.
-- @about This script will Extend selected ITEM EDGES by defined ammount at top of script, using nudge tool. Also adding take markers at loop points of source.

-- Amount of frames to nudge
local frames_to_nudge = 15  -- Change this value to nudge by a different number of frames

-- Main function
local function nudge_trim_edges(frames)
  local num_items = reaper.CountSelectedMediaItems(0)
  if num_items == 0 then return end

  reaper.Undo_BeginBlock()

  for i = 0, num_items - 1 do
    local item = reaper.GetSelectedMediaItem(0, i)
    local take = reaper.GetActiveTake(item)
    
    if take ~= nil then
      local source = reaper.GetMediaItemTake_Source(take)
      local source_length = reaper.GetMediaSourceLength(source)

      -- Add take markers at the start and end of the source
      reaper.SetTakeMarker(take, -1, "Start", 0)
      reaper.SetTakeMarker(take, -1, "End", source_length)

      
-- (Project, NudgeMode, NudgeWhat ( 1=left trim, 2=left edge (stretch), 3=right trim, 4=content)

  --Left
    reaper.ApplyNudge(0, 0, 1, 18, frames, true, 0)
  --Right
    reaper.ApplyNudge(0, 0, 3, 18, frames, false, 0)
    end
  end

  reaper.Undo_EndBlock("Nudge trims by " .. frames .. " frames", -1)
  reaper.UpdateArrange()
end

nudge_trim_edges(frames_to_nudge)
