-- @version 1.0
-- @description Explode Polywav channels to items & group vertically.
-- @author RESERVOIR AUDIO / MrBrock, with AI.

--[[
Explode selected items by source channel count, cascade mono channel modes,
ensure enough empty tracks are created underneath each source track,
and group each exploded vertical cluster.

- Selected items only
- For each track containing selected items:
    create (maxChannelsAmongSelectedOnTrack - 1) new tracks directly below it
- For each selected item with N channels:
    keep original on source track as mono ch1
    create N-1 duplicates on tracks below, set mono ch2..N
    assign a new unique group ID to the whole vertical cluster

Tested logic; uses item state chunks for faithful duplication.
--]]

local reaper = reaper

----------------------------------------------------------------
-- Helpers
----------------------------------------------------------------

local function msg(s) reaper.ShowConsoleMsg(tostring(s) .. "\n") end

local function get_selected_items()
  local t = {}
  local n = reaper.CountSelectedMediaItems(0)
  for i = 0, n-1 do
    local it = reaper.GetSelectedMediaItem(0, i)
    t[#t+1] = it
  end
  return t
end

local function get_active_take_source_channels(item)
  if not item then return 0 end
  local take = reaper.GetActiveTake(item)
  if not take then return 0 end
  local src = reaper.GetMediaItemTake_Source(take)
  if not src then return 0 end
  local ch = reaper.GetMediaSourceNumChannels(src) or 0
  return math.floor(ch)
end

local function get_track_index_0based(track)
  -- IP_TRACKNUMBER is 1-based, returns 0 if invalid
  local n = reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER")
  if not n or n < 1 then return nil end
  return math.floor(n - 1 + 0.5)
end

local function get_max_group_id_in_project()
  local maxID = 0
  local itemCount = reaper.CountMediaItems(0)
  for i = 0, itemCount-1 do
    local it = reaper.GetMediaItem(0, i)
    local gid = reaper.GetMediaItemInfo_Value(it, "I_GROUPID") or 0
    if gid > maxID then maxID = gid end
  end
  return maxID
end

local function chanmode_for_mono_channel(ch)
  -- I_CHANMODE:
  -- 3 = mono left (channel 1)
  -- 4 = mono right (channel 2)
  -- 5+ = mono channel 3+ (continues upward)
  if ch == 1 then return 3 end
  if ch == 2 then return 4 end
  return ch + 2
end

local function duplicate_item_to_track_from_chunk(srcItem, destTrack, chunk)
  local newItem = reaper.AddMediaItemToTrack(destTrack)
  if not newItem then return nil end
  reaper.SetItemStateChunk(newItem, chunk, false)
  return newItem
end

----------------------------------------------------------------
-- Main
----------------------------------------------------------------

reaper.Undo_BeginBlock()
reaper.PreventUIRefresh(1)

local selItems = get_selected_items()
if #selItems == 0 then
  reaper.PreventUIRefresh(-1)
  reaper.Undo_EndBlock("Explode selected items by channel count (none selected)", -1)
  return
end

-- Build per-track max channel count among selected items
local trackMaxCh = {}      -- key: track userdata tostring -> { track=ptr, max=number }
local tracksList = {}      -- list of unique tracks

for _, item in ipairs(selItems) do
  local tr = reaper.GetMediaItemTrack(item)
  if tr then
    local key = tostring(tr)
    local ch = get_active_take_source_channels(item)
    local entry = trackMaxCh[key]
    if not entry then
      entry = { track = tr, max = ch }
      trackMaxCh[key] = entry
      tracksList[#tracksList+1] = tr
    else
      if ch > entry.max then entry.max = ch end
    end
  end
end

-- Sort tracks bottom-to-top by current index, insert needed tracks below each
table.sort(tracksList, function(a,b)
  local ia = get_track_index_0based(a) or -1
  local ib = get_track_index_0based(b) or -1
  return ia > ib
end)

for _, tr in ipairs(tracksList) do
  local key = tostring(tr)
  local maxCh = (trackMaxCh[key] and trackMaxCh[key].max) or 0
  if maxCh and maxCh > 1 then
    local trIdx = get_track_index_0based(tr)
    if trIdx then
      local insertCount = maxCh - 1
      local insertAt = trIdx + 1
      -- Insert tracks directly below this track
      for i = 1, insertCount do
        reaper.InsertTrackAtIndex(insertAt, true)
      
        local newTrack = reaper.GetTrack(0, insertAt)
        if newTrack then
          -- i starts at 1, but channel numbering should start at 2
          local chNum = i + 1
          reaper.GetSetMediaTrackInfo_String(
            newTrack,
            "P_NAME",
            "Ch " .. chNum,
            true
          )
        end
      
        insertAt = insertAt + 1
      end
    end
  end
end

-- Prepare grouping IDs
local nextGroupID = get_max_group_id_in_project() + 1

-- Explode each selected item (snapshot list so selection changes don’t matter)
for _, item in ipairs(selItems) do
  local srcTrack = reaper.GetMediaItemTrack(item)
  local numCh = get_active_take_source_channels(item)

  if srcTrack and numCh and numCh > 1 then
    -- Get chunk from original item for faithful duplication
    local ok, chunk = reaper.GetItemStateChunk(item, "", false)
    if ok and chunk and #chunk > 0 then
      local groupID = nextGroupID
      nextGroupID = nextGroupID + 1

      -- We need current track index AFTER insertions
      local baseIdx = get_track_index_0based(srcTrack)
      if baseIdx then
        -- ch=1 uses original item
        do
          local take = reaper.GetActiveTake(item)
          if take then
            reaper.SetMediaItemTakeInfo_Value(take, "I_CHANMODE", chanmode_for_mono_channel(1))
          end
          reaper.SetMediaItemInfo_Value(item, "I_GROUPID", groupID)
        end

        -- ch=2..N duplicates
        for ch = 2, numCh do
          local destTrack = reaper.GetTrack(0, baseIdx + (ch - 1))
          if destTrack then
            local newItem = duplicate_item_to_track_from_chunk(item, destTrack, chunk)
            if newItem then
              local take = reaper.GetActiveTake(newItem)
              if take then
                reaper.SetMediaItemTakeInfo_Value(take, "I_CHANMODE", chanmode_for_mono_channel(ch))
              end
              reaper.SetMediaItemInfo_Value(newItem, "I_GROUPID", groupID)
              reaper.SetMediaItemSelected(newItem, false)
            end
          end
        end
      end
    end
  end
end

reaper.UpdateArrange()
reaper.PreventUIRefresh(-1)
reaper.Undo_EndBlock("Explode selected items by channel count + cascade mono modes + group clusters", -1)
