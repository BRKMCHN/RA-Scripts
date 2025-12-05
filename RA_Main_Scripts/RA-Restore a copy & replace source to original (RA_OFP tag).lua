-- @version 1.0
-- @description Restore a copy & replace source to original (RA_OFP tag)
-- @author RESERVOIR AUDIO / MrBrock with AI
-- @about
--   For each selected item:
--   - Reads RA_OFP: from item notes (original file path, usually relative to project)
--   - Resolves it under the current project directory
--   - If not found, optionally searches by filename anywhere under the project dir
--   - Replaces take source with the found original file (no new PCM file created)
--   - Removes trailing "🔽" from take name
--   - Strips the RA_OFP: line from notes

------------------------------------------------------------
-- helpers
------------------------------------------------------------

local function split_lines(text)
  local lines = {}
  if not text or text == "" then return lines end
  for line in (text .. "\n"):gmatch("([^\n]*)\n") do
    table.insert(lines, line)
  end
  return lines
end

local function get_RA_OFP_value(item)
  local _, notes = reaper.GetSetMediaItemInfo_String(item, "P_NOTES", "", false)
  if not notes or notes == "" then return nil end

  for _, line in ipairs(split_lines(notes)) do
    local val = line:match("^RA_OFP:%s*(.+)")
    if val and val ~= "" then
      return val
    end
  end
  return nil
end

local function remove_RA_OFP_line(item)
  local _, notes = reaper.GetSetMediaItemInfo_String(item, "P_NOTES", "", false)
  if not notes or notes == "" then return end

  local lines = split_lines(notes)
  local out = {}

  for _, line in ipairs(lines) do
    if not line:match("^RA_OFP:") then
      table.insert(out, line)
    end
  end

  local new_notes = table.concat(out, "\n")
  reaper.GetSetMediaItemInfo_String(item, "P_NOTES", new_notes, true)
end

local function clean_take_name_arrow(take)
  if not take then return end
  local _, name = reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
  if not name then name = "" end

  -- Remove trailing "🔽" and any space(s) before it
  local new_name = name:gsub("%s*🔽%s*$", "")
  if new_name ~= name then
    reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", new_name, true)
  end
end

local function get_project_path()
  local proj_path = reaper.GetProjectPath("") or ""
  return proj_path
end

local function get_path_sep()
  local os = reaper.GetOS()
  if os:match("Win") then
    return "\\"
  else
    return "/"
  end
end

-- Recursive search for filename under base_dir
local function search_file_recursive(base_dir, target_name, sep)
  -- Files in this dir
  local i = 0
  while true do
    local file = reaper.EnumerateFiles(base_dir, i)
    if not file then break end
    if file:lower() == target_name:lower() then
      return base_dir .. sep .. file
    end
    i = i + 1
  end

  -- Subdirectories
  i = 0
  while true do
    local sub = reaper.EnumerateSubdirectories(base_dir, i)
    if not sub then break end
    local sub_path = base_dir .. sep .. sub
    local found = search_file_recursive(sub_path, target_name, sep)
    if found then return found end
    i = i + 1
  end

  return nil
end

------------------------------------------------------------
-- main
------------------------------------------------------------

local function main()
  local num_items = reaper.CountSelectedMediaItems(0)
  if num_items == 0 then
    reaper.ShowMessageBox("No items selected.", "Restore from RA_OFP", 0)
    return
  end

  local proj_path = get_project_path()
  if proj_path == "" then
    reaper.ShowMessageBox("Could not determine project path.", "Restore from RA_OFP", 0)
    return
  end

  local sep = get_path_sep()

  -- Collect candidates
  local records = {}
  for i = 0, num_items - 1 do
    local item = reaper.GetSelectedMediaItem(0, i)
    if item then
      local take = reaper.GetActiveTake(item)
      if take and not reaper.TakeIsMIDI(take) then
        local ra_ofp = get_RA_OFP_value(item)
        if ra_ofp and ra_ofp ~= "" then
          table.insert(records, {
            item = item,
            take = take,
            ra_ofp = ra_ofp,
            resolved_path = nil
          })
        end
      end
    end
  end

  if #records == 0 then
    reaper.ShowMessageBox("No selected items have a RA_OFP: entry in their notes.", "Restore from RA_OFP", 0)
    return
  end

  -- First pass: try RA_OFP as relative to current project dir
  for _, rec in ipairs(records) do
    local ra = rec.ra_ofp

    -- Normalize separators in RA_OFP value
    ra = ra:gsub("[/\\]", sep)

    -- Ensure we don't double-separator
    if ra:sub(1,1) == sep then
      ra = ra:sub(2)
    end

    local candidate = proj_path
    if proj_path:sub(-1) ~= sep then
      candidate = candidate .. sep .. ra
    else
      candidate = candidate .. ra
    end

    if reaper.file_exists(candidate) then
      rec.resolved_path = candidate
    else
      -- as extra fallback, if RA_OFP is actually an absolute path and exists, use it
      if reaper.file_exists(rec.ra_ofp) then
        rec.resolved_path = rec.ra_ofp
      end
    end
  end

  -- Count unresolved
  local unresolved_count = 0
  for _, rec in ipairs(records) do
    if not rec.resolved_path then
      unresolved_count = unresolved_count + 1
    end
  end

  -- If unresolved exist, optionally search by filename only (ignoring folders)
  if unresolved_count > 0 then
    local msg = string.format(
      "%d RA_OFP path(s) were not found under the current project directory.\n\n" ..
      "Do you want to search for matching filenames anywhere under the project directory?",
      unresolved_count
    )
    local ret = reaper.MB(msg, "Restore from RA_OFP - filename search", 4) -- 4 = Yes/No
    if ret == 6 then -- Yes
      for _, rec in ipairs(records) do
        if not rec.resolved_path then
          local ra = rec.ra_ofp
          local filename = ra:match("([^/\\]+)$") or ra
          local found = search_file_recursive(proj_path, filename, sep)
          if found and reaper.file_exists(found) then
            rec.resolved_path = found
          end
        end
      end
    end
  end

  -- Remove any records still unresolved from restore set (but keep them for info if needed)
  local restore_records = {}
  for _, rec in ipairs(records) do
    if rec.resolved_path and reaper.file_exists(rec.resolved_path) then
      table.insert(restore_records, rec)
    end
  end

  if #restore_records == 0 then
    reaper.ShowMessageBox("No valid source files could be resolved from RA_OFP.", "Restore from RA_OFP", 0)
    return
  end

  -- Multi-source warning: count unique resolved paths
  local unique = {}
  for _, rec in ipairs(restore_records) do
    unique[rec.resolved_path] = true
  end
  local unique_count = 0
  for _ in pairs(unique) do unique_count = unique_count + 1 end

  if unique_count > 1 then
    local msg = string.format(
      "You are about to restore from %d different source files.\n\n" ..
      "Do you wish to proceed?",
      unique_count
    )
    local ret = reaper.MB(msg, "Restore from RA_OFP - multiple sources", 4) -- Yes/No
    if ret ~= 6 then
      return
    end
  end

  -- Do the actual restore
  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(1)

  for _, rec in ipairs(restore_records) do
    local new_src = reaper.PCM_Source_CreateFromFile(rec.resolved_path)
    if new_src then
      reaper.SetMediaItemTake_Source(rec.take, new_src)
      clean_take_name_arrow(rec.take)
      remove_RA_OFP_line(rec.item)
      reaper.UpdateItemInProject(rec.item)
    end
  end

  reaper.PreventUIRefresh(-1)
  reaper.Undo_EndBlock("Restore item sources from RA_OFP and clean 🔽", -1)
  reaper.UpdateArrange()
  reaper.Main_OnCommand(40245, 0)  -- Rebuild "missing" peaks for selected items
end

main()

