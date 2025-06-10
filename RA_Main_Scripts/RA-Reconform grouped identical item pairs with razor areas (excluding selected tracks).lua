-- @version 1.0
-- @description Reconform grouped identical item pairs with razor areas
-- @author RESERVOIR AUDIO / Fante & MrBrock, adapted with AI.

--[[
SWS Extension Required

Step 1: duplicate a track with desired items on them.
Step 2: group all these items vertically
Step 3: Move duplicated items found on "bottom" track intependently from group OR use preferred position action (with bwf offset works well too!)
Step 4: Select tracks to exclude from razor area operation. (Original item's track - top track - will always be excluded)
Step 5: Select at least one item of all grouped pairs and run the script

*** It is worth noting that razor edit options will have impact on what is reconformed. 
Options such as item split behaviour or razor area applying to all visible envelopes on track.

For extra precision, it is recommended to clear all item fades and snap edges to grid before duplicating track and grouping items

]]--

function Msg(str)
  reaper.ShowConsoleMsg(tostring(str) .. "\n")
end

reaper.Undo_BeginBlock()
reaper.PreventUIRefresh(1)
reaper.ClearConsole()

-- Ensure grouped items are selected (toggle twice to preserve state)
reaper.Main_OnCommand(41156, 0)
reaper.Main_OnCommand(41156, 0)

-- Step 0: Add earliest selected item track to selection
local earliest_track = nil
local min_track_idx = math.huge
for i = 0, reaper.CountSelectedMediaItems(0) - 1 do
  local item = reaper.GetSelectedMediaItem(0, i)
  local track = reaper.GetMediaItemTrack(item)
  local idx = reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER")
  if idx < min_track_idx then
    min_track_idx = idx
    earliest_track = track
  end
end
if earliest_track then
  reaper.SetTrackSelected(earliest_track, true)
end

-- Step 1: Save initially selected tracks to exclude from razor/paste
local excluded_tracks = {}
for i = 0, reaper.CountSelectedTracks(0) - 1 do
  local tr = reaper.GetSelectedTrack(0, i)
  excluded_tracks[tr] = true
end

-- Step 2: Gather and group selected media items
local groups = {}
for i = 0, reaper.CountSelectedMediaItems(0) - 1 do
  local item = reaper.GetSelectedMediaItem(0, i)
  local group_id = reaper.GetMediaItemInfo_Value(item, "I_GROUPID")
  if group_id == 0 then group_id = -1 end

  local track = reaper.GetMediaItemTrack(item)
  local track_idx = reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER")
  local pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
  local len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")

  local data = {
    item = item,
    group_id = group_id,
    track = track,
    track_idx = track_idx,
    position = pos,
    length = len
  }

  groups[group_id] = groups[group_id] or {}
  table.insert(groups[group_id], data)
end

-- Sort helper
local function sort_items(tbl)
  table.sort(tbl, function(a, b)
    if a.track_idx == b.track_idx then
      return a.position < b.position
    else
      return a.track_idx < b.track_idx
    end
  end)
end

-- Prepare sorted list of groups
local sorted_groups = {}
for gid, items in pairs(groups) do
  sort_items(items)
  table.insert(sorted_groups, {
    group_id = gid,
    items = items,
    first_pos = items[1].position
  })
end

-- Sort groups by top-left item
table.sort(sorted_groups, function(a, b)
  return a.first_pos < b.first_pos
end)

-- Command IDs
local sws_copy = reaper.NamedCommandLookup("_SWS_SMARTCOPY")
local native_paste = 42398 -- Paste
local focus_arrange = reaper.NamedCommandLookup("_BR_FOCUS_ARRANGE_WND")

-- Step 3: Set paste focus to earliest non-excluded track
local xen_next = reaper.NamedCommandLookup("_XENAKIOS_SELNEXTTRACK")
local xen_prev = reaper.NamedCommandLookup("_XENAKIOS_SELPREVTRACK")

local focus_track = nil
for i = 0, reaper.CountTracks(0) - 1 do
  local tr = reaper.GetTrack(0, i)
  if not excluded_tracks[tr] then
    focus_track = tr
    break
  end
end

if focus_track then
  reaper.SetOnlyTrackSelected(focus_track)
  if xen_next ~= 0 then reaper.Main_OnCommand(xen_next, 0) end
  if xen_prev ~= 0 then reaper.Main_OnCommand(xen_prev, 0) end
end

-- Process each group pair
for _, entry in ipairs(sorted_groups) do
  local items = entry.items
  if #items >= 2 then
    local item1 = items[1]
    local item2 = items[2]

    -- A. Clear selection before copy
    reaper.Main_OnCommand(40297, 0) -- Unselect all tracks

    -- B. Clear all razor edits globally
    for i = 0, reaper.CountTracks(0) - 1 do
      local tr = reaper.GetTrack(0, i)
      reaper.GetSetMediaTrackInfo_String(tr, "P_RAZOREDITS", "", true)
    end

    -- C. Focus arrange
    if focus_arrange ~= 0 then
      reaper.Main_OnCommand(focus_arrange, 0)
    end

    -- D. Set razor area on all non-excluded tracks for item2 range
    local start_pos = item2.position
    local end_pos = item2.position + item2.length
    for i = 0, reaper.CountTracks(0) - 1 do
      local tr = reaper.GetTrack(0, i)
      if not excluded_tracks[tr] then
        local razor = string.format("%.15f %.15f \"\"", start_pos, end_pos)
        reaper.GetSetMediaTrackInfo_String(tr, "P_RAZOREDITS", razor, true)
      end
    end

    -- E. Smart Copy
    if sws_copy ~= 0 then
      reaper.Main_OnCommand(sws_copy, 0)
    end

    -- F. Set cursor to item1
    reaper.SetEditCurPos(item1.position, false, false)

    -- G. Native Paste
    reaper.Main_OnCommand(native_paste, 0)
  end
end

-- Step 4: Restore original track selection
reaper.Main_OnCommand(40297, 0) -- Unselect all tracks
for i = 0, reaper.CountSelectedTracks(0) - 1 do
  local tr = reaper.GetSelectedTrack(0, i)
  reaper.SetTrackSelected(tr, false)
end
for tr in pairs(excluded_tracks) do
  reaper.SetTrackSelected(tr, true)
end

-- Final cleanup
reaper.PreventUIRefresh(-1)
reaper.Undo_EndBlock("Reconform grouped identical item pairs with razor areas", -1)
reaper.UpdateArrange()
