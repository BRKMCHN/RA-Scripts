-- @version 1.0
-- @description Render as new take & rename sources with unique identifier (dedicated ALIGN PROXY VERSION)
-- @author RESERVOIR AUDIO / MrBrock & AI


-- Fast path: single render call, then deferred “all-online” gate, then batch rename/relink.
-- Suffix/tag is user-editable near the top (TAG_SUFFIX).

---------------------------------------
-- User Options (edit here)
---------------------------------------
local TAG_SUFFIX = "_AA"   -- ← change this to whatever tag you like (e.g., "_TUNED", "_POST", etc.)
local RENAME_IN_PLACE = true  -- true = os.rename (fast). false = copy file then relink (safer). (ONLY IF initial renaming fails)
local REQUIRED_STABLE_POLLS = 2 -- # of consecutive “all ready” polls before proceeding
local POLL_TIMEOUT_MS = 60000   -- overall wait timeout (60s)

---------------------------------------
-- Internal helpers
---------------------------------------
local ACTION_RENDER_NEW_TAKE = 40601 -- "Item: Render items as new take"

local function sanitize_name(name)
  name = name:gsub("%s+", "_")
  name = name:gsub("[^%w_]", "")
  return name
end

local function get_timestamp()
  local t = os.date("*t")
  return string.format("%02d%02d%02d", t.hour, t.min, t.sec)
end

local function get_computer_name()
  local h = io.popen("hostname")
  if not h then return "HOST" end
  local n = h:read("*a") or "HOST"
  h:close()
  n = n:gsub("%s+", ""):gsub("%.local$", "")
  return sanitize_name(n)
end

-- macOS: /Volumes/<name>/... ; otherwise fallback to hostname (stable cross-machines)
local function get_volume_name(file_path)
  local vol = file_path:match("^/Volumes/([^/]+)")
  return vol and sanitize_name(vol) or get_computer_name()
end

local function file_exists(p)
  local f = io.open(p, "rb"); if f then f:close(); return true end
  return false
end

local function split_path_filename_ext(p)
  -- returns dir(with trailing sep if present in match), stem, ext (no dot)
  local dir, file, ext = p:match("(.-)([^\\/]-)%.([^%.\\/]+)$")
  if not dir then
    dir, file = p:match("(.-)([^\\/]+)$")
    ext = ""
  end
  return dir or "", file or "", ext or ""
end

local function join_path(dir, name, ext)
  if dir == "" then return name .. (ext ~= "" and ("." .. ext) or "") end
  local sep = (dir:sub(-1) == "/" or dir:sub(-1) == "\\") and "" or "/"
  return dir .. sep .. name .. (ext ~= "" and ("." .. ext) or "")
end

-- Collision resolver:
-- #1 = no number; if exists, then try plain integers starting at 2 (2,3,4,...)
local function unique_path(base_dir, base_name, ext)
  local candidate = join_path(base_dir, base_name, ext)
  if not file_exists(candidate) then return candidate end
  local i = 2
  while true do
    local cand = join_path(base_dir, base_name .. i, ext)
    if not file_exists(cand) then return cand end
    i = i + 1
    if i > 100000 then return cand end -- extreme fallback
  end
end

local function safe_copy(src, dst)
  local rf = io.open(src, "rb"); if not rf then return false, "read fail" end
  local wf = io.open(dst, "wb"); if not wf then rf:close(); return false, "write fail" end
  local chunk = rf:read("*all")
  if not chunk then rf:close(); wf:close(); return false, "read empty" end
  wf:write(chunk)
  rf:close(); wf:close()
  return true
end

---------------------------------------
-- Snapshot / restore
---------------------------------------
local function get_item_guid(it)
  local ok, guid = reaper.GetSetMediaItemInfo_String(it, "GUID", "", false)
  return ok and guid or ""
end

local function path_split(p)
  local dir, file, ext = p:match("(.-)([^\\/]-)%.([^%.\\/]+)$")
  if not dir then dir, file = p:match("(.-)([^\\/]+)$"); ext = "" end
  return dir or "", file or "", ext or ""
end

local function get_selected_items_snapshot()
  local t = {}
  local n = reaper.CountSelectedMediaItems(0)
  for i = 0, n-1 do
    local it = reaper.GetSelectedMediaItem(0, i)
    if it then
      local guid = get_item_guid(it)
      local take = reaper.GetActiveTake(it)
      local orig_path, orig_stem, orig_ext = "", "", ""
      if take and not reaper.TakeIsMIDI(take) then
        local src = reaper.GetMediaItemTake_Source(take)
        if src then
          local p = reaper.GetMediaSourceFileName(src, "")
          if p and p ~= "" then
            local _, stem, ext = path_split(p)
            orig_path, orig_stem, orig_ext = p, stem, ext
          end
        end
      end
      t[#t+1] = {
        guid = guid,
        ptr = it,
        take_count_before = reaper.CountTakes(it) or 0,
        orig_path = orig_path,
        orig_stem = orig_stem,
        orig_ext  = orig_ext,
      }
    end
  end
  return t
end

local function find_item_by_guid(guid)
  local n = reaper.CountMediaItems(0)
  for i = 0, n-1 do
    local it = reaper.GetMediaItem(0, i)
    local ok, g = reaper.GetSetMediaItemInfo_String(it, "GUID", "", false)
    if ok and g == guid then return it end
  end
  return nil
end

local function restore_selection_from_snapshot(snap)
  reaper.Main_OnCommand(40289, 0) -- Unselect all items
  for _, info in ipairs(snap) do
    local it = find_item_by_guid(info.guid)
    if it then reaper.SetMediaItemSelected(it, true) end
  end
end

---------------------------------------
-- Naming (from ORIGINAL stem)
---------------------------------------
local function build_align_name_using_original(current_render_path, snapshot_entry)
  -- Use the rendered file's directory/ext, but base name from ORIGINAL stem
  local dir, _, ext = split_path_filename_ext(current_render_path)

  local base_stem = snapshot_entry.orig_stem
  if not base_stem or base_stem == "" then
    -- Fallback: strip “ render 00X” if snapshot missed
    local _, render_stem, _ = split_path_filename_ext(current_render_path)
    base_stem = (render_stem:gsub("%s+[Rr]ender%s*0*%d+$", ""))
  end

  local vol = get_volume_name(current_render_path)
  local ts  = get_timestamp()
  local candidate_stem = string.format("%s_%s_%s%s", base_stem, vol, ts, TAG_SUFFIX)

  return unique_path(dir, candidate_stem, ext)
end

local function relink_take_to_file(take, new_path)
  local new_src = reaper.PCM_Source_CreateFromFile(new_path)
  if not new_src then return false end
  reaper.SetMediaItemTake_Source(take, new_src)
  return true
end

local function set_take_name_to_source_stem(take)
  local src = reaper.GetMediaItemTake_Source(take)
  if not src then return end
  local p = reaper.GetMediaSourceFileName(src, "")
  if not p or p == "" then return end
  local _, stem, _ = split_path_filename_ext(p)
  reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", stem, true)
end

---------------------------------------
-- Batch wait for ALL to be ready
---------------------------------------
local snap = nil
local stable_ok_polls = 0
local t0 = 0

local function get_new_take(item, before_count)
  local cur = reaper.CountTakes(item) or 0
  if cur > before_count then
    return reaper.GetTake(item, cur - 1)
  end
  -- Fallback to active take if counts didn't update as expected
  return reaper.GetActiveTake(item)
end

local function all_ready_once()
  local all_ok = true
  for _, info in ipairs(snap) do
    local item = find_item_by_guid(info.guid) or info.ptr
    if not (item and reaper.ValidatePtr2(0, item, "MediaItem*")) then
      all_ok = false; break
    end

    -- Item must have its new take created already
    local cur_takes = reaper.CountTakes(item) or 0
    if cur_takes <= (info.take_count_before or 0) then
      all_ok = false; break
    end

    if reaper.GetMediaItemInfo_Value(item, "B_OFFLINE") ~= 0 then
      all_ok = false; break
    end

    -- New take must have a concrete source file
    local take = get_new_take(item, info.take_count_before or 0)
    if not (take and reaper.ValidatePtr2(0, take, "MediaItem_Take*")) then
      all_ok = false; break
    end
    local src = reaper.GetMediaItemTake_Source(take)
    if not src then all_ok = false; break end

    local path = reaper.GetMediaSourceFileName(src, "")
    if not (path and path ~= "" and file_exists(path)) then
      all_ok = false; break
    end
  end
  return all_ok
end

local function batch_rename_and_finish()
  for _, info in ipairs(snap) do
    local item = find_item_by_guid(info.guid) or info.ptr
    if item and reaper.ValidatePtr2(0, item, "MediaItem*") then
      local take = get_new_take(item, info.take_count_before or 0)
      if take and reaper.ValidatePtr2(0, take, "MediaItem_Take*") then

        local src = reaper.GetMediaItemTake_Source(take)
        if src then
          local old_path = reaper.GetMediaSourceFileName(src, "")
          if old_path and old_path ~= "" then
            local new_path = build_align_name_using_original(old_path, info)

            if RENAME_IN_PLACE then
              local ok = os.rename(old_path, new_path)
              if not ok then
                local c_ok = safe_copy(old_path, new_path)
                if c_ok then os.remove(old_path) end
              end
              relink_take_to_file(take, new_path)
            else
              local c_ok = safe_copy(old_path, new_path)
              if c_ok then
                relink_take_to_file(take, new_path)
                os.remove(old_path)
              end
            end

            -- Set take name to source stem (for display)
            set_take_name_to_source_stem(take)
            reaper.UpdateItemInProject(item)
          end
        end
      end
    end
  end

  restore_selection_from_snapshot(snap)
  reaper.Undo_EndBlock("Batch render → wait ALL online → rename/relink + set take names", -1)
  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()
end

local function poll_all_ready()
  if ((reaper.time_precise() - t0) * 1000) > POLL_TIMEOUT_MS then
    batch_rename_and_finish()
    return
  end

  if all_ready_once() then
    stable_ok_polls = stable_ok_polls + 1
    if stable_ok_polls >= (REQUIRED_STABLE_POLLS or 2) then
      batch_rename_and_finish()
      return
    end
  else
    stable_ok_polls = 0
  end

  reaper.defer(poll_all_ready)
end

---------------------------------------
-- Entrypoint
---------------------------------------
local function main()
  local sel = reaper.CountSelectedMediaItems(0)
  if sel == 0 then
    reaper.ShowMessageBox("No items selected.", "Info", 0)
    return
  end

  snap = get_selected_items_snapshot()
  if #snap == 0 then
    reaper.ShowMessageBox("Selection snapshot is empty.", "Error", 0)
    return
  end

  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(1)

  -- Render once on the full selection (blocking until REAPER finishes the batch)
  reaper.Main_OnCommand(ACTION_RENDER_NEW_TAKE, 0)

  -- Start global watcher: wait until ALL items have their new take and are not offline
  t0 = reaper.time_precise()
  stable_ok_polls = 0
  poll_all_ready()
end

main()

