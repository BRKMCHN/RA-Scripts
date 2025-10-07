-- @description Render selected item as new take with unique ID - PRE ITEM FX - Set for RA auto align
-- @version 1.1
-- @author
--   RESERVOIR AUDIO / MrBrock with AI

-- Will duplicate active take of selected items. Will render PRE FX via accessor and replace the duplicated take's source with new item (name appended with unique ID). 
-- Will sanitize take parameters which get rendered like start offset, playrate & pitch. Will add the original source's filename to item notes to avoid duplicating the tag later on.

---------------------------------------
-- User options
---------------------------------------
local TAG_SUFFIX            = "_ALIGN"  -- tag appended to new file stem
local BLOCK_SAMPLES         = 65536     -- accessor read block (per channel)
local SET_TAKE_NAME         = true      -- set take display name to file stem
local FORCE_REBUILD_PEAKS   = true      -- rebuild peaks at end
local DEBUG                 = false     -- set true for console logs

---------------------------------------
-- Command IDs
---------------------------------------
local ACTION_DUPLICATE_ACTIVE_TAKE     = 40639  -- Take: Duplicate active take
local CMD_MOVE_TAKE_ENV_WITH_CONTENTS  = 43636  -- Options: Move take envelope points when moving media item contents
local CMD_TOGGLE_ITEM_GROUPING = 1156   -- Options: Toggle item grouping enabled

---------------------------------------
-- Debug helper
---------------------------------------
local function dbg(fmt, ...)
  if DEBUG then reaper.ShowConsoleMsg(("[DBG] " .. fmt .. "\n"):format(...)) end
end

---------------------------------------
-- Helpers
---------------------------------------
local function proj_srate()
  local sr = reaper.GetSetProjectInfo(0, "PROJECT_SRATE", 0, false)
  if sr and sr > 0 then return math.floor(sr + 0.5) end
  return 48000
end

local function source_srate(src)
  local ok, sr = reaper.GetMediaSourceSampleRate(src)
  if ok and sr and sr > 0 then return math.floor(sr + 0.5) end
  return proj_srate()
end

local function sanitize_name(name)
  name = name:gsub("%s+", "_")
  name = name:gsub("[^%w_]", "")
  return name
end

local function get_computer_name()
  local h = io.popen("hostname")
  if not h then return "HOST" end
  local n = h:read("*a") or "HOST"
  h:close()
  return sanitize_name(n:gsub("%s+", ""):gsub("%.local$", ""))
end

local function get_volume_name(file_path)
  local vol = file_path:match("^/Volumes/([^/]+)")
  return vol and sanitize_name(vol) or get_computer_name()
end

local function get_timestamp_HHMMSS()
  local t = os.date("*t")
  return string.format("%02d%02d%02d", t.hour, t.min, t.sec)
end

local function split_path(p)
  local dir, file, ext = p:match("(.-)([^\\/]-)%.([^%.\\/]+)$")
  if not dir then dir, file = p:match("(.-)([^\\/]+)$"); ext = "" end
  return dir or "", file or "", ext or ""
end

local function join_path(dir, name, ext)
  if dir == "" then return name .. (ext ~= "" and ("."..ext) or "") end
  local sep = (dir:sub(-1) == "/" or dir:sub(-1) == "\\") and "" or "/"
  return dir .. sep .. name .. (ext ~= "" and ("." .. ext) or "")
end

local function file_exists(p)
  local f = io.open(p, "rb"); if f then f:close(); return true end
  return false
end

local function unique_path(dir, base_stem, ext)
  local candidate = join_path(dir, base_stem, ext)
  if not file_exists(candidate) then return candidate end
  local i = 2
  while true do
    local cand = join_path(dir, base_stem .. i, ext)
    if not file_exists(cand) then return cand end
    i = i + 1
    if i > 100000 then return cand end
  end
end

---------------------------------------
-- RA_OFN (Original File Name) in Item Notes
---------------------------------------
local function get_item_notes(item)
  local ok, txt = reaper.GetSetMediaItemInfo_String(item, "P_NOTES", "", false)
  return ok and (txt or "") or ""
end

local function set_item_notes(item, text)
  return reaper.GetSetMediaItemInfo_String(item, "P_NOTES", text or "", true)
end

-- returns value or nil
local function extract_ra_ofn(notes)
  if not notes or notes == "" then return nil end
  -- Match "RA_OFN: <value>" (case-insensitive RA_ofn), up to end-of-line
  local v = notes:match("[Rr][Aa]_OFN:%s*(.-)\r?\n")
  if v and v ~= "" then return v end
  v = notes:match("[Rr][Aa]_OFN:%s*(.+)$")
  if v and v ~= "" then return v end
  return nil
end

-- Ensure RA_OFN exists; return the stem to use for naming
local function ensure_or_get_ra_ofn(item, default_stem)
  local notes = get_item_notes(item)
  local ofn = extract_ra_ofn(notes)
  if ofn and ofn ~= "" then
    return ofn
  end
  -- Write RA_OFN: <default_stem> to item notes (append on a new line if needed)
  local prefix = (notes ~= "" and notes:sub(-1) ~= "\n") and "\n" or ""
  local new_notes = (notes or "") .. prefix .. "RA_OFN: " .. (default_stem or "")
  set_item_notes(item, new_notes)
  return default_stem
end

-- Build output path using RA_OFN (if present), else the current source stem
local function build_outpath_with_ra_ofn(item, src_path)
  local dir, stem, _ = split_path(src_path)
  if stem == "" then stem = "take" end
  -- decide base stem
  local base_stem = ensure_or_get_ra_ofn(item, stem)
  local base = string.format("%s_%s_%s%s", base_stem, get_volume_name(src_path), get_timestamp_HHMMSS(), TAG_SUFFIX)
  return unique_path(dir, base, "wav")
end

-- 32-bit float WAV header (LE, WAVEFORMAT_IEEE_FLOAT)
local function write_wav_header32(fh, sr, ch, data_bytes)
  local function w32(u) fh:write(string.pack("<I4", u)) end
  local function w16(u) fh:write(string.pack("<I2", u)) end
  fh:seek("set", 0)
  fh:write("RIFF"); w32(36 + data_bytes); fh:write("WAVE")
  fh:write("fmt "); w32(16); w16(3); w16(ch); w32(sr)
  w32(sr * ch * 4); w16(ch * 4); w16(32)
  fh:write("data"); w32(data_bytes)
end

local function get_toggle_state(cmd)
  if not (cmd and cmd > 0) then return nil end
  return reaper.GetToggleCommandStateEx(0, cmd) == 1
end

local function set_toggle_state(cmd, want_on)
  if not (cmd and cmd > 0) then return end
  local cur = reaper.GetToggleCommandStateEx(0, cmd) == 1
  if cur ~= want_on then reaper.Main_OnCommand(cmd, 0) end
end

-- Plan how we build output from RAW source channels (based on saved I_CHANMODE)
local function plan_output_channels(chanmode, src_ch)
  local out = { out_ch = src_ch, kind = "copy_all" }

  if src_ch <= 1 then
    out.out_ch = 1; out.kind = "copy_all"
    return out
  end

  if chanmode == 0 then
    out.out_ch = src_ch; out.kind = "copy_all"         -- Normal

  elseif chanmode == 1 then
    out.out_ch = 2; out.kind = "reverse12"             -- Reverse stereo

  elseif chanmode == 2 then
    out.out_ch = 1; out.kind = "mono_mix_12"           -- Mono mix of ch1 & ch2

  elseif chanmode >= 3 and chanmode <= 66 then
    local ch_index = chanmode - 2                      -- Mono pick specific channel N
    out.out_ch = 1; out.kind = "mono_pick"; out.pick = ch_index

  elseif chanmode >= 67 then
    local start = (chanmode - 67) + 1                  -- Stereo pair N,N+1
    out.out_ch = 2; out.kind = "stereo_pair"; out.left = start; out.right = start + 1

  else
    out.out_ch = src_ch; out.kind = "copy_all"
  end
  return out
end

local function block_energy(tbl, n)
  local e = 0.0
  for i = 1, math.min(n, #tbl) do
    local v = tbl[i] or 0.0
    e = e + math.abs(v)
  end
  return e
end

---------------------------------------
-- Snapshot selected items (to find the duplicate take)
---------------------------------------
local function snapshot_selected_items()
  local snap = {}
  local n = reaper.CountSelectedMediaItems(0)
  for i = 0, n-1 do
    local it = reaper.GetSelectedMediaItem(0, i)
    snap[#snap+1] = { item = it, takes_before = reaper.CountTakes(it) or 0 }
  end
  return snap
end

---------------------------------------
-- Render duplicated take to file (RAW @ source SR, sample-aligned + manual channel-mode)
---------------------------------------
local function render_dup_take_to_file(dup_take)
  local src = reaper.GetMediaItemTake_Source(dup_take)
  if not src then return nil end

  local src_path = reaper.GetMediaSourceFileName(src, "")
  if src_path == "" then return nil end

  -- Save channel mode, then force Normal before creating accessor (RAW poly channels)
  local orig_mode = math.floor(reaper.GetMediaItemTakeInfo_Value(dup_take, "I_CHANMODE") or 0)
  reaper.SetMediaItemTakeInfo_Value(dup_take, "I_CHANMODE", 0)

  local acc = reaper.CreateTakeAudioAccessor(dup_take)
  if not acc then
    -- restore if failed
    reaper.SetMediaItemTakeInfo_Value(dup_take, "I_CHANMODE", orig_mode)
    return nil
  end

  -- Read window in project seconds ⇒ convert to integer frames at *source* SR
  local sr_src    = source_srate(src)
  local acc_start = reaper.GetAudioAccessorStartTime(acc)
  local acc_end   = reaper.GetAudioAccessorEndTime(acc)
  local start_fr  = math.floor(acc_start * sr_src + 0.5)
  local end_fr    = math.floor(acc_end   * sr_src + 0.5)
  local total_fr  = math.max(0, end_fr - start_fr)
  if total_fr <= 0 then
    reaper.DestroyAudioAccessor(acc)
    reaper.SetMediaItemTakeInfo_Value(dup_take, "I_CHANMODE", orig_mode)
    return nil
  end

  local src_ch  = reaper.GetMediaSourceNumChannels(src) or 2
  if src_ch < 1 then src_ch = 1 end

  local plan    = plan_output_channels(orig_mode, src_ch)
  local out_ch  = plan.out_ch

  dbg("Take %s | src_ch=%d  I_CHANMODE(saved)=%d  plan=%s out_ch=%d  frames=%d  sr_src=%d",
      tostring(dup_take), src_ch, orig_mode, plan.kind, out_ch, total_fr, sr_src)

  -- Use RA_OFN (create if missing) to build a stable base stem
  local item = reaper.GetMediaItemTake_Item(dup_take)
  local out_path = build_outpath_with_ra_ofn(item, src_path)
  local _, out_stem, _ = split_path(out_path)

  local fh = assert(io.open(out_path, "wb"))
  write_wav_header32(fh, sr_src, out_ch, 0)

  local block     = BLOCK_SAMPLES
  local buf_src   = reaper.new_array(src_ch * block)
  local frames_done = 0
  local printed_first = false

  while frames_done < total_fr do
    local want = math.min(block, total_fr - frames_done)
    buf_src.clear()

    local ok = reaper.GetAudioAccessorSamples(
                 acc, sr_src, src_ch,
                 (start_fr + frames_done) / sr_src,
                 want, buf_src)
    if not ok then break end

    local out_tbl

    if plan.kind == "copy_all" and out_ch == src_ch then
      out_tbl = buf_src.table(1, src_ch * want)
    else
      out_tbl = {}
      for f = 0, want - 1 do
        local base = f * src_ch

        if plan.kind == "reverse12" then
          local L = (buf_src[base + 2] or 0.0)
          local R = (buf_src[base + 1] or 0.0)
          out_tbl[#out_tbl+1] = L
          out_tbl[#out_tbl+1] = R

        elseif plan.kind == "mono_mix_12" then
          local L = (buf_src[base + 1] or 0.0)
          local R = (buf_src[base + 2] or 0.0)
          out_tbl[#out_tbl+1] = 0.5 * (L + R)

        elseif plan.kind == "mono_pick" then
          local c = plan.pick or 1
          if c < 1 then c = 1 end
          if c > src_ch then c = src_ch end
          out_tbl[#out_tbl+1] = (buf_src[base + c] or 0.0)

        elseif plan.kind == "stereo_pair" then
          local Lc = plan.left  or 1
          local Rc = plan.right or 2
          if Lc < 1 then Lc = 1 end
          if Rc < 1 then Rc = 1 end
          if Lc > src_ch then Lc = src_ch end
          if Rc > src_ch then Rc = src_ch end
          out_tbl[#out_tbl+1] = (buf_src[base + Lc] or 0.0)
          out_tbl[#out_tbl+1] = (buf_src[base + Rc] or 0.0)

        else
          for c = 1, out_ch do
            out_tbl[#out_tbl+1] = (buf_src[base + c] or 0.0)
          end
        end
      end
    end

    if not printed_first then
      printed_first = true
      dbg("  first-block energy ~= %.6f", block_energy(out_tbl, math.min(1024, #out_tbl)))
    end

    fh:write(string.pack("<" .. string.rep("f", #out_tbl), table.unpack(out_tbl)))
    frames_done = frames_done + want
  end

  reaper.DestroyAudioAccessor(acc)
  -- keep duplicate take in Normal after replacement (we baked channel-mode)

  write_wav_header32(fh, sr_src, out_ch, frames_done * out_ch * 4)
  fh:close()

  return out_path, out_stem, plan.kind, out_ch
end

---------------------------------------
-- Entrypoint
---------------------------------------
reaper.Undo_BeginBlock()
if DEBUG then reaper.ClearConsole() end
reaper.PreventUIRefresh(1)

local sel_count = reaper.CountSelectedMediaItems(0)
if sel_count == 0 then
  reaper.PreventUIRefresh(-1)
  reaper.Undo_EndBlock("Nothing to do", -1)
  return
end

-- Item grouping wrapper (disable only if currently enabled)
local _orig_grouping = (reaper.GetToggleCommandStateEx(0, CMD_TOGGLE_ITEM_GROUPING) == 1)
if _orig_grouping then reaper.Main_OnCommand(CMD_TOGGLE_ITEM_GROUPING, 0) end

-- Snapshot before duplication (so we can grab the new duplicate takes)
local function snapshot_selected_items()
  local snap = {}
  for i = 0, sel_count-1 do
    local it = reaper.GetSelectedMediaItem(0, i)
    snap[#snap+1] = { item = it, takes_before = reaper.CountTakes(it) or 0 }
  end
  return snap
end

local snap = snapshot_selected_items()

-- 1) Duplicate active take on ALL selected items (envelopes preserved)
reaper.Main_OnCommand(ACTION_DUPLICATE_ACTIVE_TAKE, 0)

-- Temporarily disable “move take env points with contents” while resetting offsets
local orig_move_state = get_toggle_state(CMD_MOVE_TAKE_ENV_WITH_CONTENTS)
if orig_move_state == true then set_toggle_state(CMD_MOVE_TAKE_ENV_WITH_CONTENTS, false) end

-- 2) For each snapped item, find the NEW (duplicated) take and process it
for i = 1, #snap do
  local it   = snap[i].item
  local npre = snap[i].takes_before or 0
  local nnow = reaper.CountTakes(it) or npre
  local dup_take = (nnow > npre) and reaper.GetTake(it, nnow - 1) or reaper.GetActiveTake(it)
  if dup_take and not reaper.TakeIsMIDI(dup_take) then
    local out_path, out_stem, plan_kind, out_ch = render_dup_take_to_file(dup_take)
    if out_path then
      local new_src = reaper.PCM_Source_CreateFromFile(out_path)
      if new_src then
        reaper.SetMediaItemTake_Source(dup_take, new_src)

        -- Neutralize timing so rendered audio aligns 1:1
        reaper.SetMediaItemTakeInfo_Value(dup_take, "D_STARTOFFS", 0.0)
        reaper.SetMediaItemTakeInfo_Value(dup_take, "D_PLAYRATE", 1.0)
        reaper.SetMediaItemTakeInfo_Value(dup_take, "D_PITCH", 0.0)
        reaper.SetMediaItemTakeInfo_Value(dup_take, "B_PPITCH", 0)

        -- We baked channel-mode into file → set Normal so no double-processing
        reaper.SetMediaItemTakeInfo_Value(dup_take, "I_CHANMODE", 0)
        dbg("Processed item #%d | baked plan=%s (%d ch) → set I_CHANMODE=0", i, tostring(plan_kind), out_ch)

        if SET_TAKE_NAME and out_stem then
          reaper.GetSetMediaItemTakeInfo_String(dup_take, "P_NAME", out_stem, true)
        end

        reaper.UpdateItemInProject(it)
      end
    end
  end
end

-- Restore the option
if orig_move_state == true then set_toggle_state(CMD_MOVE_TAKE_ENV_WITH_CONTENTS, true) end

-- Restore item grouping if we disabled it
if _orig_grouping then reaper.Main_OnCommand(CMD_TOGGLE_ITEM_GROUPING, 0) end

if FORCE_REBUILD_PEAKS and sel_count > 0 then
  reaper.Main_OnCommand(40441, 0) -- Rebuild peaks
end

reaper.PreventUIRefresh(-1)
reaper.Undo_EndBlock("Dup active take → Render (RAW @ source SR, sample-aligned) → Replace duplicate; neutralize timing; RA_OFN naming; no FX", -1)
reaper.UpdateArrange()