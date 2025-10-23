-- @version 1.1
-- @description RA-Open item copies in external editor - DEFER & Unique ID
-- @author RESERVOIR AUDIO / MrBrock adapted with AI.

-- Will perform pre built script to render as new take PRE FX then will defer opening items in external editor to prevent the refresh fail upon returning to reaper.

local PRINT_CMD_ID = reaper.NamedCommandLookup("_RS727cc884d731b9e2e0ed4e569e97d7fbbdb42b94")
if PRINT_CMD_ID == 0 then
  reaper.ShowMessageBox("Couldn't find your script by ID.\nCheck the ID string.", "Error", 0)
  return
end

local DELAY_SEC = 0.15   -- adjust if needed (0.25–0.40 usually perfect)
local OPEN_EXT_EDITOR = 40109  -- Item: Open items in external editor

reaper.Undo_BeginBlock()
reaper.PreventUIRefresh(1)

-- 1) Run your print script (it creates the new take, builds peaks, etc.)
reaper.Main_OnCommand(PRINT_CMD_ID, 0)

reaper.PreventUIRefresh(-1)

-- 2) Small defer so file close/mtime settles before opening in RX
local t0 = reaper.time_precise()
local function wait_then_open()
  if (reaper.time_precise() - t0) >= DELAY_SEC then
    reaper.Main_OnCommand(OPEN_EXT_EDITOR, 0)
    reaper.Undo_EndBlock("Print + delayed open in external editor", -1)
  else
    reaper.defer(wait_then_open)
  end
end

wait_then_open()
