-- @version 1.0
-- @description Open item copies in external editor - DEFER & Unique ID
-- @author RESERVOIR AUDIO / MrBrock adapted with AI.

-- Will render as new take with existing RA script, will defer opening external editor to allow peak and renaming to be registered.

local PRINT_CMD_ID = reaper.NamedCommandLookup("_RS727cc884d731b9e2e0ed4e569e97d7fbbdb42b94")
if PRINT_CMD_ID == 0 then
  reaper.ShowMessageBox("Couldn't find your script by ID.\nCheck the ID string.", "Error", 0)
  return
end

local OPEN_EXT_EDITOR = 40109  -- Item: Open items in external editor

-- Tunables
local MIN_DELAY_SEC   = 0.15   -- minimum wall time to wait
local MAX_DELAY_SEC   = 1.20   -- safety cap in case the second won't tick (rare)
local RELOAD_SELECTED = false  -- s˘et true to force an item refresh before opening

local function force_reload_selected_sources()
  -- Optional: a small nudge to ensure UI/state is current before we spawn RX
  reaper.Main_OnCommand(40612, 0) -- Recalculate item/take lengths
  reaper.UpdateArrange()
end

reaper.Undo_BeginBlock()
reaper.PreventUIRefresh(1)

-- 1) Run your print script (creates new take, etc.)
reaper.Main_OnCommand(PRINT_CMD_ID, 0)

if RELOAD_SELECTED then force_reload_selected_sources() end

reaper.PreventUIRefresh(-1)

-- 2) Adaptive wait: ensure we pass a second boundary (mtime granularity guard)
local start_prec  = reaper.time_precise()
local start_sec   = os.time()

local function ready()
  local elapsed = reaper.time_precise() - start_prec
  -- Wait at least MIN_DELAY_SEC and until os.time() changes (next-sec tick),
  -- or bail at MAX_DELAY_SEC as a cap.
  if elapsed < MIN_DELAY_SEC then return false end
  if os.time() ~= start_sec then return true end
  if elapsed >= MAX_DELAY_SEC then return true end
  return false
end

local function wait_then_open()
  if ready() then
    reaper.Main_OnCommand(OPEN_EXT_EDITOR, 0)
    reaper.Undo_EndBlock("Print + adaptive delayed open in external editor", -1)
  else
    reaper.defer(wait_then_open)
  end
end

wait_then_open()

