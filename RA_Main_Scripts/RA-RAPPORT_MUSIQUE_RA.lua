-- @version 1.1
-- @description Rapport de musique à la Réservoir Audio
-- @author RESERVOIR AUDIO / MrBrock & AI

--[[
Export un CSV basé sur les items contigus de même source présent dans la session, départagé par région.
Colonnes CSV: Nom,Début,Fin,Durée

Behavior:
  - Adds a Region row for each region (spans region start→end).
  - Music blocks are merged per region by source with gap tolerance: 5 frames @ 24fps (= 0.208333... s).
  - Skips muted tracks and muted items.
  - Displays timecode using the project FPS (HH:MM:SS:FF).
  - OFFSETS all Début/Fin so that every region appears to start at the FIRST region's start timecode.
]]

local function msg(s) reaper.ShowMessageBox(s, "Export CSV", 0) end

-- ---------- utilities ----------

-- Prompt: merge/name by TAKE? (Yes = take, No = source, Cancel = abort)
local function ask_merge_mode()
  -- 3 = Yes/No/Cancel
  local ret = reaper.ShowMessageBox(
    "Utiliser TAKE name ou SOURCE name pour l'export ?\n\nOui = Take name\nNon = Source (fichier)\nAnnuler = Quitter",
    "Mode de regroupement",
    3
  )
  if ret == 2 then return nil end   -- Cancel
  return ret == 6                   -- Yes => take names; No => source names
end

local function path_basename_no_ext(path)
  if not path or path == "" then return "" end
  path = path:gsub("[/\\]+$", "")
  local base = path:match("([^/\\]+)$") or path
  local noext = base:gsub("%.[^%.]+$", "")
  return noext
end

local function take_display_name(take)
  if not take then return "" end
  local src = reaper.GetMediaItemTake_Source(take)
  if src then
    local buf = reaper.GetMediaSourceFileName(src, "")
    if buf and buf ~= "" then
      return path_basename_no_ext(buf), buf -- (basename, fullpath)
    end
  end
  local nm = reaper.GetTakeName(take) or ""
  return nm, nm
end

local function is_track_muted(tr)
  return (reaper.GetMediaTrackInfo_Value(tr, "B_MUTE") or 0) > 0.5
end

local function is_item_muted(it)
  return (reaper.GetMediaItemInfo_Value(it, "B_MUTE") or 0) > 0.5
end

-- Project FPS used for display
local function get_project_fps()
  local fps = reaper.TimeMap_curFrameRate(0) -- respects project settings
  if not fps or fps <= 0 then fps = 24.0 end
  return fps
end

-- Up folder helper
local function updir(path, levels)
  local p = (path or ""):gsub("[/\\]+$", "")
  for _=1,(levels or 1) do
    local parent = p:match("^(.*)[/\\][^/\\]+$")
    if not parent or parent == "" then break end
    p = parent
  end
  return p
end

-- Project-aware TC formatter (HH:MM:SS:FF, respects project offset & DF)
local function fmt_tc(seconds_pos)
  -- mode 5 = timecode HH:MM:SS:FF (project FPS & DF rules)
  return reaper.format_timestr_pos(seconds_pos, "", 5)
end

-- Format a DURATION (HH:MM:SS:FF) – ignores project start offset, respects DF/FPS
local function fmt_len(seconds_len)
  if type(seconds_len) ~= "number" then
    reaper.ShowConsoleMsg("fmt_len got bad value: " .. tostring(seconds_len) .. "\n")
    seconds_len = 0
  end
  return reaper.format_timestr_len(seconds_len, "", 0, 5)
end


-- Frame rounding + format HH:MM:SS:FF
local function seconds_to_frames_floor(t, fps) return math.floor(t * fps + 1e-9) end
local function seconds_to_frames_ceil(t, fps)  return math.ceil (t * fps - 1e-9) end

local function frames_to_tc(frames, fps)
  if frames < 0 then frames = 0 end
  local total_seconds = math.floor(frames / fps)
  local ff = frames - total_seconds * fps
  ff = math.floor(ff + 0.5)
  local hh = math.floor(total_seconds / 3600)
  local mm = math.floor((total_seconds % 3600) / 60)
  local ss = total_seconds % 60
  return string.format("%02d:%02d:%02d:%02d", hh, mm, ss, ff)
end

-- Compress TC with optional duration mode.
-- When is_duration=true:
--   HH>0  -> "H:MM:SS:FF"
--   HH=0, MM>0 -> "M:SS:FF"
--   HH=0, MM=0 -> "S:FF"
-- When is_duration=false (positions):
--   HH=0  -> "M:SS:FF"   (keep minutes even if 0)
--   HH>0  -> "H:MM:SS:FF"
local function compress_tc(tc, is_duration)
  local a,b,c,d = tc:match("^(%d+):(%d+):(%d+):(%d+)$")
  if not a then return tc end
  local hh = tonumber(a) or 0
  local mm = tonumber(b) or 0
  local ss = tonumber(c) or 0
  local ff = tonumber(d) or 0

  if is_duration then
    if hh > 0 then
      return string.format("%d:%02d:%02d:%02d", hh, mm, ss, ff)
    elseif mm > 0 then
      return string.format("%d:%02d:%02d", mm, ss, ff)
    else
      return string.format("%d:%02d", ss, ff)
    end
  else
    if hh == 0 then
      return string.format("%d:%02d:%02d", mm, ss, ff)
    else
      return string.format("%d:%02d:%02d:%02d", hh, mm, ss, ff)
    end
  end
end


-- ---------- collect regions ----------
local function get_regions()
  local _, num_markers, num_regions = reaper.CountProjectMarkers(0)
  local total = num_markers + num_regions
  local regions = {}
  for i = 0, total - 1 do
    local retval, isrgn, pos, rgnend, name = reaper.EnumProjectMarkers3(0, i)
    if retval and isrgn then
      regions[#regions+1] = { name = name or "", start = pos, ["end"] = rgnend }
    end
  end
  table.sort(regions, function(a,b) return a.start < b.start end)
  return regions
end

-- ---------- collect item segments split by regions ----------
local function collect_segments_by_region()
  local regions = get_regions()
  if #regions == 0 then
    msg("Aucune région trouvée. Créez des régions (épisodes) avant d’exporter.")
    return nil
  end

  local segs_by_region = {}
  for ri=1, #regions do segs_by_region[ri] = {} end

  local track_count = reaper.CountTracks(0)
  for ti = 0, track_count - 1 do
    local tr = reaper.GetTrack(0, ti)
    if not is_track_muted(tr) then
      local item_count = reaper.CountTrackMediaItems(tr)
      for ii = 0, item_count - 1 do
        local it = reaper.GetTrackMediaItem(tr, ii)
        if it and not is_item_muted(it) then
          local take = reaper.GetActiveTake(it)
          if take then
            local name_basename, src_key = take_display_name(take)
            local take_nm = reaper.GetTakeName(take) or ""
            if name_basename ~= "" then
              local pos = reaper.GetMediaItemInfo_Value(it, "D_POSITION")
              local len = reaper.GetMediaItemInfo_Value(it, "D_LENGTH")
              local it_start = pos
              local it_end   = pos + len
              for ri, r in ipairs(regions) do
                local s = math.max(it_start, r.start)
                local e = math.min(it_end,   r["end"])
                if e > s then
                  table.insert(segs_by_region[ri], {
                    src_key   = src_key,
                    src_name  = name_basename,
                    take_name = take_nm,
                    s         = s,
                    e         = e
                  })
                end
              end
            end
          end
        end
      end
    end
  end

  return regions, segs_by_region
end

-- Merge by either SOURCE or TAKE name (gap tolerance applies within each key)
-- use_take_names = true  -> key = take name (fallback to source if take empty)
-- use_take_names = false -> key = source file

-- Gap tolerance: 5 frames @ 24 fps
local GAP_TOLERANCE_SECONDS = 5.0 / 24.0

local function merge_by_key(segments, use_take_names)
  local buckets = {}

  local function make_key(seg)
    if use_take_names then
      if seg.take_name and seg.take_name ~= "" then
        return "TAKE::" .. seg.take_name, (seg.take_name or "")
      else
        -- empty take names: keep isolated per source (don't blend across files)
        return "SRC::" .. (seg.src_key or ""), (seg.src_name or "")
      end
    else
      return "SRC::" .. (seg.src_key or ""), (seg.src_name or "")
    end
  end

  -- bucket by chosen key
  for _, seg in ipairs(segments) do
    local key, display = make_key(seg)
    local b = buckets[key]
    if not b then
      b = { display_name = display, list = {} }
      buckets[key] = b
    end
    table.insert(b.list, seg)
  end

  -- merge within each bucket
  local merged = {}
  for _, pack in pairs(buckets) do
    local list = pack.list
    table.sort(list, function(a,b) return a.s < b.s end)
    local cur_s, cur_e = nil, nil
    for _, seg in ipairs(list) do
      if not cur_s then
        cur_s, cur_e = seg.s, seg.e
      else
        if seg.s <= (cur_e + GAP_TOLERANCE_SECONDS) then
          if seg.e > cur_e then cur_e = seg.e end
        else
          table.insert(merged, { s = cur_s, e = cur_e, display_name = pack.display_name })
          cur_s, cur_e = seg.s, seg.e
        end
      end
    end
    if cur_s then
      table.insert(merged, { s = cur_s, e = cur_e, display_name = pack.display_name })
    end
  end

  table.sort(merged, function(a,b) return a.s < b.s end)
  return merged
end

-- ---------- build rows with OFFSET to first region start ----------
local function to_rows_with_offset(regions, segs_by_region, use_take_names)
  local fps = get_project_fps()
  local rows = {}
  -- Anchor: first region's **seconds** (not frames)
  local base_secs = regions[1].start

  for ri, region in ipairs(regions) do

    -- REGION ROW (span)
    local region_dur = math.max(0, region["end"] - region.start) -- seconds
    local rDurF      = seconds_to_frames_ceil(region_dur, fps)   -- frames
    local r_start_sec_adj = base_secs
    local r_end_sec_adj   = base_secs + (rDurF / fps)
    
    table.insert(rows, {
      nom          = (region.name ~= "" and ("Épisode: " .. region.name) or "Épisode"),
      debut_tc     = fmt_tc(r_start_sec_adj),
      fin_tc       = fmt_tc(r_end_sec_adj),
      duree_tc     = fmt_len(rDurF / fps),
      startSecAdj  = r_start_sec_adj,
      regionIdx    = ri,
      kind         = 0
    })
    

    -- MUSIC BLOCKS (merge within region, then offset each block into the base anchor)
    local merged = merge_by_key(segs_by_region[ri], use_take_names)
    for _, m in ipairs(merged) do
      local s_rel = math.max(0, m.s - region.start)
      local e_rel = math.max(0, m.e - region.start)
    
      -- Quantize to frames (start=floor, end=ceil)
      local sF = seconds_to_frames_floor(s_rel, fps)
      local eF = seconds_to_frames_ceil (e_rel, fps)
      if eF < sF then eF = sF end
    
      local s_adj = base_secs + (sF / fps)
      local e_adj = base_secs + (eF / fps)
      local durF  = math.max(0, eF - sF)
    
      table.insert(rows, {
        nom          = m.display_name or "",
        debut_tc     = fmt_tc(s_adj),
        fin_tc       = fmt_tc(e_adj),
        duree_tc     = fmt_len(durF / fps),
        startSecAdj  = s_adj,
        regionIdx    = ri,
        kind         = 1
      })
    end
  end

  -- Sort by region order, then by adjusted start seconds, then region row before music
  table.sort(rows, function(a,b)
    if a.regionIdx ~= b.regionIdx then
      return a.regionIdx < b.regionIdx
    elseif a.startSecAdj ~= b.startSecAdj then
      return a.startSecAdj < b.startSecAdj
    else
      return a.kind < b.kind
    end
  end)

  return rows, fps
end


-- ---------- CSV ----------
local function csv_escape(s)
  if s == nil then s = "" end
  local needs_quotes = s:find('[,"\r\n]') ~= nil
  s = s:gsub('"', '""')
  if needs_quotes then return '"' .. s .. '"' else return s end
end

local function write_csv(rows, out_path)
  local fh, err = io.open(out_path, "wb")
  if not fh then return false, err end
  -- UTF‑8 BOM
  fh:write(string.char(0xEF, 0xBB, 0xBF))
  -- Header
  fh:write("Nom,Début,Fin,Durée\r\n")
  for _, r in ipairs(rows) do
    local line = table.concat({
      csv_escape(r.nom),
      csv_escape(r.debut_tc),                    -- keep full HH:MM:SS:FF
      csv_escape(r.fin_tc),                      -- keep full HH:MM:SS:FF
      csv_escape(compress_tc(r.duree_tc, true)), -- duration-only compression
    }, ",")
    fh:write(line .. "\r\n")
  end
  fh:close()
  return true
end

-- ---------- save dialog helper ----------
local function choose_save_path(default_name)
  local ok, path = false, nil

  -- Prefer the folder containing the current .RPP, then go up 1 (two above /sources)
  local init_dir = nil
  local _, proj_fn = reaper.EnumProjects(-1, "")
  if proj_fn and proj_fn ~= "" then
    local proj_dir = proj_fn:match("^(.*)[/\\][^/\\]+$") -- folder of the .rpp
    if proj_dir and proj_dir ~= "" then
      init_dir = updir(proj_dir, 1) -- parent of project folder
    end
  end
  -- Fallback: use project path and go up 2 (handles when dialog lands in /sources)
  if not init_dir or init_dir == "" then
    init_dir = updir(reaper.GetProjectPath("") or "", 2)
  end

  if reaper.APIExists("JS_Dialog_BrowseForSaveFile") then
    local ret, fn = reaper.JS_Dialog_BrowseForSaveFile(
      "Save CSV",
      init_dir or "",
      default_name,
      "CSV files (*.csv)\0*.csv\0All files (*.*)\0*.*\0"
    )
    if ret and fn and fn ~= "" then
      if not fn:lower():match("%.csv$") then fn = fn .. ".csv" end
      ok, path = true, fn
    end
  else
    local dir = init_dir or (reaper.GetProjectPath("") or "")
    path = (dir ~= "" and (dir .. "/") or "") .. default_name
    ok = true
  end

  return ok, path
end


-- ---------- main ----------
reaper.Undo_BeginBlock()
reaper.PreventUIRefresh(1)

local regions, segs_by_region = collect_segments_by_region()
if not regions then
  reaper.PreventUIRefresh(-1)
  reaper.Undo_EndBlock("Export CSV (offset by first region)", -1)
  return
end

local use_take_names = ask_merge_mode()
if use_take_names == nil then
  reaper.PreventUIRefresh(-1)
  reaper.Undo_EndBlock("Export CSV (annulé par l’utilisateur)", -1)
  return
end

local rows, fps = to_rows_with_offset(regions, segs_by_region, use_take_names)
local function default_csv_name()
  local _, proj_fn = reaper.EnumProjects(-1, "")
  if proj_fn and proj_fn ~= "" then
    local base = path_basename_no_ext(proj_fn)  -- you already have this util
    return base .. ".csv"                       -- same name as the .rpp
  end
  return "music_usage.csv"                      -- fallback if project unsaved
end

local default_name = default_csv_name()

local ok, out_path = choose_save_path(default_name)
if not ok or not out_path or out_path == "" then
  reaper.PreventUIRefresh(-1)
  reaper.Undo_EndBlock("Export CSV (offset by first region)", -1)
  return
end

local success, err = write_csv(rows, out_path)
reaper.PreventUIRefresh(-1)
if success then
  reaper.Undo_EndBlock("Export CSV (offset by first region)", -1)
  msg(string.format("CSV exporté:\n%s\n\nLignes: %d\nFPS projet: %.3f", out_path, #rows, fps))
else
  reaper.Undo_EndBlock("Export CSV (offset by first region) [FAILED]", -1)
  msg("Erreur d’export CSV: " .. tostring(err))
end
