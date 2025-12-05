-- @version 1.0
-- @description Append item channel mode to take name as _CH-#
-- @author RESERVOIR AUDIO / MrBrock, with AI.
-- @about
--   For each selected item:
--   - Reads active take's channel mode (I_CHANMODE)
--   - Infers which source channel(s) are used
--   - Appends "_CH-x" or "_CH-x-y" to the take name
--   - Replaces any existing _CH-# or _CH-#-# suffix

local function get_channel_label(take)
  if not take then return nil end

  local src = reaper.GetMediaItemTake_Source(take)
  if not src then return nil end

  local src_ch = reaper.GetMediaSourceNumChannels(src) or 0
  if src_ch < 1 then return nil end

  local chanmode = reaper.GetMediaItemTakeInfo_Value(take, "I_CHANMODE") or 0
  chanmode = math.floor(chanmode + 0.5) -- just in case

  local ch1, ch2

  -- Single-channel source: always CH-1
  if src_ch == 1 then
    ch1 = 1

  else
    -- REAPER docs for I_CHANMODE (for stereo): :contentReference[oaicite:0]{index=0}
    -- 0 = normal (all channels play as-is)
    -- 1 = reverse stereo (for 2ch)
    -- 2 = mono (downmix 1+2)
    -- 3 = mono (left)
    -- 4 = mono (right)
    --
    -- For multichannel, REAPER extends this so 3,4,5,... map to mono channel 1,2,3,...
    -- Values > ~66 are used for stereo pairs from multichannel sources.
    -- The exact mapping for all multichannel stereo pairs is undocumented, so
    -- below is a best-effort guess that works for common cases.

    if chanmode == 0 then
      -- Normal: use 1-2 for stereo, or 1-N for multichannel
      if src_ch == 2 then
        ch1, ch2 = 1, 2
      else
        ch1, ch2 = 1, src_ch
      end

    elseif chanmode == 1 then
      -- Reverse stereo (2ch)
      if src_ch >= 2 then
        ch1, ch2 = 2, 1
      else
        ch1 = 1
      end

    elseif chanmode == 2 then
      -- Mono downmix of 1+2
      if src_ch >= 2 then
        -- Technically sum of 1+2; label as 1-2
        ch1, ch2 = 1, 2
      else
        ch1 = 1
      end

    elseif chanmode >= 3 and chanmode <= 66 then
      -- Mono (channel N) – common pattern: chanmode = 2 + N (N is 1-based)
      local mono_ch = chanmode - 2
      if mono_ch < 1 then mono_ch = 1 end
      if mono_ch > src_ch then mono_ch = src_ch end
      ch1 = mono_ch

    else
      -- Multichannel stereo pair (undocumented exact mapping).
      -- Best-effort: treat chanmode as encoding "pair starting at N".
      -- We'll derive an index and clamp it to valid range.
      local pair_start = chanmode - 66  -- heuristic
      if pair_start < 1 then pair_start = 1 end
      if pair_start >= src_ch then pair_start = src_ch - 1 end
      if pair_start < 1 then pair_start = 1 end
      ch1, ch2 = pair_start, pair_start + 1
    end
  end

  if ch1 and ch2 then
    return string.format("_CH-%d-%d", ch1, ch2)
  elseif ch1 then
    return string.format("_CH-%d", ch1)
  else
    return nil
  end
end

reaper.Undo_BeginBlock()
reaper.PreventUIRefresh(1)

local cnt = reaper.CountSelectedMediaItems(0)

for i = 0, cnt - 1 do
  local item = reaper.GetSelectedMediaItem(0, i)
  if item then
    local take = reaper.GetActiveTake(item)
    if take then
      local suffix = get_channel_label(take)

      if suffix then
        local _, name = reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)

        -- Remove any existing _CH-x or _CH-x-y at the end
        -- (e.g. "FX_Stem_CH-3", "FX_Stem_CH-8-9")
        local base = name:gsub("_CH%-%d+%-?%d*$", "")

        -- Trim trailing spaces
        base = base:gsub("%s+$", "")

        local new_name = base .. suffix

        reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", new_name, true)
      end
    end
  end
end

reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()
reaper.Undo_EndBlock("Append item channel mode to take name (_CH-#)", -1)

