-- @description RA-Render selected item as new take with unique ID - POST ITEM FX
-- @version 1.3
-- @author
--   RESERVOIR AUDIO / MrBrock & AI

-- While UI is suspended, will create a temporary track. Will render a copy of each selected item preserving take FX via accessor (name appended with unique ID). 
-- Will sanitize take parameters which get rendered like start offset, playrate & pitch. Will add the original source's filename to item notes to avoid duplicating the tag later on.
-- NOTE: NOT compatible with certain ARA plugins like auto align and melodyne which analysis requires items to stay in place.

---------------------------------------
-- User options
---------------------------------------
local TAG_SUFFIX            = "_EDIT"
local BLOCK_SAMPLES         = 65536
local SET_TAKE_NAME         = true
local DEBUG                 = false
local TMP_TRACK_NAME        = "__RA_TMP_POSTFX"
local TAIL_SECONDS          = 0.0       -- extend read window for FX tails

---------------------------------------
-- Command IDs
---------------------------------------
local CMD_MOVE_TAKE_ENV_WITH_CONTENTS  = 43636
local CMD_TOGGLE_ITEM_GROUPING = 1156   -- Options: Toggle item grouping enabled

---------------------------------------
-- Debug helper
---------------------------------------
local function dbg(fmt, ...) if DEBUG then reaper.ShowConsoleMsg(("[DBG] "..fmt.."\n"):format(...)) end end

---------------------------------------
-- Small helpers
---------------------------------------
local function proj_srate()
  local sr = reaper.GetSetProjectInfo(0, "PROJECT_SRATE", 0, false)
  return (sr and sr > 0) and math.floor(sr + 0.5) or 48000
end
local function sanitize_name(s) s=s:gsub("%s+","_"); s=s:gsub("[^%w_]",""); return s end
local function get_computer_name() local h=io.popen("hostname"); if not h then return "HOST" end local n=h:read("*a") or "HOST"; h:close(); return sanitize_name(n:gsub("%s+",""):gsub("%.local$","")) end
local function get_volume_name(p) local v=p:match("^/Volumes/([^/]+)"); return v and sanitize_name(v) or get_computer_name() end
local function ts() local t=os.date("*t"); return string.format("%02d%02d%02d",t.hour,t.min,t.sec) end
local function split_path(p) local d,f,e=p:match("(.-)([^\\/]-)%.([^%.\\/]+)$"); if not d then d,f=p:match("(.-)([^\\/]+)$"); e="" end; return d or "", f or "", e or "" end
local function join_path(d,n,e) if d=="" then return n..(e~="" and ("."..e) or "") end local sep=(d:sub(-1)=="/" or d:sub(-1)=="\\") and "" or "/"; return d..sep..n..(e~="" and ("."..e) or "") end
local function file_exists(p) local f=io.open(p,"rb"); if f then f:close(); return true end; return false end
local function unique_path(dir, base, ext) local c=join_path(dir,base,ext); if not file_exists(c) then return c end local i=2; while true do local cand=join_path(dir, base..i, ext); if not file_exists(cand) then return cand end i=i+1 if i>100000 then return cand end end end
local function next_even(n) n = math.max(1, math.floor(n or 2)); if n < 2 then return 2 end; return (n % 2 == 0) and n or (n+1) end

-- WAV header 32f
local function write_wav_header32(fh, sr, ch, data_bytes)
  local function w32(u) fh:write(string.pack("<I4", u)) end
  local function w16(u) fh:write(string.pack("<I2", u)) end
  fh:seek("set", 0); fh:write("RIFF"); w32(36+data_bytes); fh:write("WAVE")
  fh:write("fmt "); w32(16); w16(3); w16(ch); w32(sr)
  w32(sr*ch*4); w16(ch*4); w16(32)
  fh:write("data"); w32(data_bytes)
end

---------------------------------------
-- RA_OFN in Item Notes
---------------------------------------
local function get_notes(it) local ok,txt=reaper.GetSetMediaItemInfo_String(it,"P_NOTES","",false); return ok and (txt or "") or "" end
local function set_notes(it, txt) return reaper.GetSetMediaItemInfo_String(it,"P_NOTES",txt or "",true) end
local function extract_ra_ofn(notes) if not notes or notes=="" then return nil end local v=notes:match("[Rr][Aa]_OFN:%s*(.-)\r?\n"); if v and v~="" then return v end v=notes:match("[Rr][Aa]_OFN:%s*(.+)$"); if v and v~="" then return v end return nil end
local function ensure_or_get_ra_ofn(it, stem)
  local notes = get_notes(it)
  local ofn = extract_ra_ofn(notes)
  if ofn and ofn~="" then return ofn end
  local prefix = (notes~="" and notes:sub(-1)~="\n") and "\n" or ""
  set_notes(it, (notes or "") .. prefix .. "RA_OFN: " .. (stem or "take"))
  return stem
end
local function build_outpath_with_ra_ofn(item, src_path)
  local dir, stem = split_path(src_path)
  if stem=="" then stem="take" end
  local base = string.format("%s_%s_%s%s", ensure_or_get_ra_ofn(item, stem), get_volume_name(src_path), ts(), TAG_SUFFIX)
  return unique_path(dir, base, "wav")
end

---------------------------------------
-- Selection snapshot/restore
---------------------------------------
local function snapshot_selected_items()
  local t = {}; local n = reaper.CountSelectedMediaItems(0)
  for i=0,n-1 do t[#t+1] = reaper.GetSelectedMediaItem(0,i) end
  return t
end
local function restore_selected_items(sel)
  reaper.Main_OnCommand(40289,0)
  for _,it in ipairs(sel) do if it and reaper.ValidatePtr2(0,it,"MediaItem*") then reaper.SetMediaItemSelected(it,true) end end
end

---------------------------------------
-- Temp track helpers
---------------------------------------
local function create_temp_track()
  local idx = reaper.CountTracks(0); reaper.InsertTrackAtIndex(idx, true)
  local tr = reaper.GetTrack(0, idx)
  if tr then reaper.GetSetMediaTrackInfo_String(tr,"P_NAME", TMP_TRACK_NAME, true) end
  return tr
end
local function clear_track_media_items(tr)
  if not tr then return end
  for i = reaper.CountTrackMediaItems(tr)-1, 0, -1 do
    reaper.DeleteTrackMediaItem(tr, reaper.GetTrackMediaItem(tr,i))
  end
end
local function delete_track(tr) if tr and reaper.ValidatePtr2(0,tr,"MediaTrack*") then reaper.DeleteTrack(tr) end end

---------------------------------------
-- Clone via chunk
---------------------------------------
local function clone_item_to_track(src_item, dst_track)
  local ok, chunk = reaper.GetItemStateChunk(src_item, "", false)
  if not ok or not chunk then return nil end
  local new_it = reaper.AddMediaItemToTrack(dst_track)
  if not new_it then return nil end
  reaper.SetItemStateChunk(new_it, chunk, true)
  return new_it
end

---------------------------------------
-- Decide I/O policy from src channels and item channel mode
-- Returns: track_ch (even), out_ch, temp_take_mode (I_CHANMODE to set on temp clone), pick_left_only (bool)
---------------------------------------
local function decide_io(src_ch, chanmode)
  -- mono-pick (3..66) or mono-mix (2) → make a mono file; read only LEFT from 2ch track
  if (chanmode >= 3 and chanmode <= 66) or chanmode == 2 then
    return 2, 1, chanmode, true  -- track 2ch, write 1ch, keep mono mode, read ch1 only
  end
  -- reverse stereo (1) or stereo pair (>=67) or normal stereo → 2ch
  if chanmode == 1 then
    return 2, 2, 1, false
  elseif chanmode >= 67 then
    return 2, 2, chanmode, false
  elseif chanmode == 0 then
    if src_ch <= 1 then
      return 2, 1, 0, true   -- mono source normal → 1ch, read L
    elseif src_ch == 2 then
      return 2, 2, 0, false  -- normal stereo
    else
      -- normal poly → keep all channels
      local tr_ch = next_even(src_ch)
      return tr_ch, src_ch, 0, false
    end
  end
  -- fallback: treat as normal stereo
  return 2, math.min(2, math.max(1, src_ch)), chanmode, (src_ch==1)
end

---------------------------------------
-- Render track output over item window to file (project SR)
---------------------------------------
local function render_track_window_to_file(track, item_for_window, track_ch, out_ch, read_left_only, out_path)
  reaper.SetMediaTrackInfo_Value(track, "I_NCHAN", track_ch)

  local sr = proj_srate()
  local pos = reaper.GetMediaItemInfo_Value(item_for_window, "D_POSITION")
  local len = reaper.GetMediaItemInfo_Value(item_for_window, "D_LENGTH")
  local t_start, t_end = pos, pos + len + (TAIL_SECONDS or 0)

  local start_fr = math.floor(t_start * sr + 0.5)
  local end_fr   = math.floor(t_end   * sr + 0.5)
  local total_fr = math.max(0, end_fr - start_fr)
  if total_fr <= 0 then return false, "zero length" end

  local acc = reaper.CreateTrackAudioAccessor(track)
  if not acc then return false, "accessor failed" end

  local fh = assert(io.open(out_path, "wb"))
  write_wav_header32(fh, sr, out_ch, 0)

  local buf = reaper.new_array(track_ch * BLOCK_SAMPLES)
  local frames_done = 0

  while frames_done < total_fr do
    local want = math.min(BLOCK_SAMPLES, total_fr - frames_done)
    buf.clear()
    local ok = reaper.GetAudioAccessorSamples(acc, sr, track_ch, (start_fr + frames_done) / sr, want, buf)
    if not ok then break end

    local out_tbl = {}
    if read_left_only and out_ch == 1 then
      -- pick LEFT (channel 1) only → mono
      for f = 0, want-1 do
        local base = f * track_ch
        out_tbl[#out_tbl+1] = buf[base + 1] or 0.0
      end
    elseif out_ch == track_ch then
      out_tbl = buf.table(1, track_ch * want)
    else
      -- keep first out_ch channels (1..out_ch)
      for f = 0, want-1 do
        local base = f * track_ch
        for c = 1, out_ch do out_tbl[#out_tbl+1] = buf[base + c] or 0.0 end
      end
    end

    fh:write(string.pack("<" .. string.rep("f", #out_tbl), table.unpack(out_tbl)))
    frames_done = frames_done + want
  end

  reaper.DestroyAudioAccessor(acc)
  write_wav_header32(fh, sr, out_ch, frames_done * out_ch * 4)
  fh:close()
  return true
end

---------------------------------------
-- Main
---------------------------------------
reaper.Undo_BeginBlock()
if DEBUG then reaper.ClearConsole() end
reaper.PreventUIRefresh(1)

local sel_items = snapshot_selected_items()
if #sel_items == 0 then
  reaper.PreventUIRefresh(-1)
  reaper.Undo_EndBlock("Nothing to do", -1)
  return
end

-- Item grouping wrapper (disable only if currently enabled)
local _orig_grouping = (reaper.GetToggleCommandStateEx(0, CMD_TOGGLE_ITEM_GROUPING) == 1)
if _orig_grouping then reaper.Main_OnCommand(CMD_TOGGLE_ITEM_GROUPING, 0) end

-- Disable “move take env points with contents”
local orig_move = (reaper.GetToggleCommandStateEx(0, CMD_MOVE_TAKE_ENV_WITH_CONTENTS) == 1)
if orig_move then reaper.Main_OnCommand(CMD_MOVE_TAKE_ENV_WITH_CONTENTS, 0) end

-- Temp track once
local tmp_tr = create_temp_track()
if not tmp_tr then
  if orig_move then reaper.Main_OnCommand(CMD_MOVE_TAKE_ENV_WITH_CONTENTS, 0) end
  reaper.PreventUIRefresh(-1)
  reaper.Undo_EndBlock("Failed to create temp track", -1)
  return
end

for i, orig_it in ipairs(sel_items) do
  if orig_it and reaper.ValidatePtr2(0, orig_it, "MediaItem*") then
    local take = reaper.GetActiveTake(orig_it)
    if take and not reaper.TakeIsMIDI(take) then
      clear_track_media_items(tmp_tr)

      local src    = reaper.GetMediaItemTake_Source(take)
      local sPath  = reaper.GetMediaSourceFileName(src, "")
      local src_ch = math.max(1, reaper.GetMediaSourceNumChannels(src) or 1)
      local chanmode = math.floor(reaper.GetMediaItemTakeInfo_Value(take, "I_CHANMODE") or 0)

      -- Decide I/O and set the temp take mode accordingly
      local track_ch, out_ch, temp_mode, read_left_only = decide_io(src_ch, chanmode)

      -- Clone to temp track
      local tmp_item = clone_item_to_track(orig_it, tmp_tr)
      if tmp_item then
        local tmp_take = reaper.GetActiveTake(tmp_item)
        if tmp_take then
          -- apply the *same* channel mode on the temp clone so its track output routes as intended
          reaper.SetMediaItemTakeInfo_Value(tmp_take, "I_CHANMODE", temp_mode)
        end

      -- Sanitize ONLY ITEM GAIN on the temp clone (keep fades etc. intact)
      reaper.SetMediaItemInfo_Value(tmp_item, "D_VOL", 1.0)  -- 1.0 = 0 dB

        local out_path = build_outpath_with_ra_ofn(orig_it, sPath)
        local _, out_stem = split_path(out_path)

        local ok = render_track_window_to_file(tmp_tr, tmp_item, track_ch, out_ch, read_left_only, out_path)

        reaper.DeleteTrackMediaItem(tmp_tr, tmp_item)

        if ok then
          -- Add as NEW take to the ORIGINAL item
          local new_take = reaper.AddTakeToMediaItem(orig_it)
          if new_take then
            local new_src = reaper.PCM_Source_CreateFromFile(out_path)
            if new_src then
              reaper.SetMediaItemTake_Source(new_take, new_src)
              reaper.SetActiveTake(new_take)
              -- neutralize timing
              reaper.SetMediaItemTakeInfo_Value(new_take, "D_STARTOFFS", 0.0)
              reaper.SetMediaItemTakeInfo_Value(new_take, "D_PLAYRATE", 1.0)
              reaper.SetMediaItemTakeInfo_Value(new_take, "D_PITCH", 0.0)
              reaper.SetMediaItemTakeInfo_Value(new_take, "B_PPITCH", 0)
              if SET_TAKE_NAME and out_stem then
                reaper.GetSetMediaItemTakeInfo_String(new_take, "P_NAME", out_stem, true)
              end
              reaper.UpdateItemInProject(orig_it)
            end
          end
        else
          dbg("Render failed on item #%d", i)
        end
      end
    end
  end
end

delete_track(tmp_tr)
if orig_move then reaper.Main_OnCommand(CMD_MOVE_TAKE_ENV_WITH_CONTENTS, 0) end

-- Restore item grouping if we disabled it
if _orig_grouping then reaper.Main_OnCommand(CMD_TOGGLE_ITEM_GROUPING, 0) end

reaper.Main_OnCommand(40245, 0) -- Build any missing peaks

restore_selected_items(sel_items)
reaper.PreventUIRefresh(-1)
reaper.Undo_EndBlock("Post-Item-FX render (per-item, channel policy) → NEW takes (RA_OFN naming)", -1)
reaper.UpdateArrange()

