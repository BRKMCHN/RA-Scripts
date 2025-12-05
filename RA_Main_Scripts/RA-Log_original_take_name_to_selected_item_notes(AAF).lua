-- @version 1.0
-- @description Log original take name to selected item notes (AAF))
-- @author RESERVOIR AUDIO / MrBrock with AI
-- @about
--   For each selected item:
--   - Reads the active take name
--   - Adds or updates a line in item notes: "RA_OTN_AAF: <take name>"
--   - If any selected item already has an RA_OTN_AAF line, the user is
--     prompted once to confirm overwriting previously logged names. Cancel stops the entire process.

local TAG_PREFIX = "RA_OTN_AAF:"

-- Helper: split notes into lines
local function split_lines(text)
  local lines = {}
  if text == nil or text == "" then return lines end
  for line in (text .. "\n"):gmatch("([^\n]*)\n") do
    table.insert(lines, line)
  end
  return lines
end

-- First, check if any selected item already has an RA_OTN_AAF line
local function any_existing_tag_in_selection()
  local count = reaper.CountSelectedMediaItems(0)
  for i = 0, count - 1 do
    local item = reaper.GetSelectedMediaItem(0, i)
    if item then
      local _, notes = reaper.GetSetMediaItemInfo_String(item, "P_NOTES", "", false)
      if notes and notes:match(TAG_PREFIX) then
        return true
      end
    end
  end
  return false
end

local item_count = reaper.CountSelectedMediaItems(0)
if item_count == 0 then
  reaper.ShowMessageBox("No items selected.", "RA_OTN_AAF", 0)
  return
end

-- Prompt if we’re about to overwrite any existing RA_OTN_AAF lines
if any_existing_tag_in_selection() then
  local msg = "Some selected items already have an RA_OTN_AAF entry.\n" ..
              "You are about to overwrite previously logged take names.\n\n" ..
              "Proceed and overwrite?"
  local ret = reaper.MB(msg, "RA_OTN_AAF - Overwrite confirmation", 4) -- 4 = Yes/No
  if ret ~= 6 then -- 6 = IDYES
    return -- user chose No
  end
end

reaper.Undo_BeginBlock()
reaper.PreventUIRefresh(1)

for i = 0, item_count - 1 do
  local item = reaper.GetSelectedMediaItem(0, i)
  if item then
    local take = reaper.GetActiveTake(item)
    if take and reaper.ValidatePtr2(0, take, "MediaItem_Take*") then
      local _, take_name = reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
      if take_name == "" then
        take_name = "(unnamed take)"
      end

      local _, notes = reaper.GetSetMediaItemInfo_String(item, "P_NOTES", "", false)
      local lines = split_lines(notes)
      local found = false

      -- Replace existing RA_OTN_AAF line if present
      for idx, line in ipairs(lines) do
        if line:match("^" .. TAG_PREFIX) then
          lines[idx] = TAG_PREFIX .. " " .. take_name
          found = true
        end
      end

      -- If not found, append a new line
      if not found then
        table.insert(lines, TAG_PREFIX .. " " .. take_name)
      end

      -- Rebuild notes
      local new_notes = table.concat(lines, "\n")
      reaper.GetSetMediaItemInfo_String(item, "P_NOTES", new_notes, true)
    end
  end
end

reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()
reaper.Undo_EndBlock("Log original take name to item notes (RA_OTN_AAF)", -1)

