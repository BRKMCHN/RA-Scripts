-- @version 1.0
-- @description Alternate same source items between 2 or 3 tracks
-- @author RESERVOIR AUDIO / MrBrock, with AI.

--[[ Alternate by source to track A or B, then resolve overlaps to track C (shorter items moves)

Workflow:
  1) Pass 1: Place selected items onto Track A / Track B (flip on source change).
  2) Pass 2: On A and B, if two DIFFERENT sources overlap, move the SHORTER one to Track C
     (if C conflicts, try moving the longer; if neither fits, leave and count a miss).

Dest tracks:
  - If exactly 3 tracks are selected: use them as A,B,C (in selection order).
  - Else if exactly 2 are selected: use them as A,B and create C just below B.
  - Else: create A,B,C just above the topmost selected item’s track.

Notes:
  - Time positions and edits are unchanged—only track assignment.
  - Items with no active AUDIO take (nil/MIDI/empty path) are ignored in logic.
--]]

---------------------------------------
-- Config
---------------------------------------
local NAME_TRACK_A = "ALT A"
local NAME_TRACK_B = "ALT B"
local NAME_TRACK_C = "ALT C"

---------------------------------------
-- Helpers
---------------------------------------
local function msg(s) reaper.ShowMessageBox(tostring(s), "Alternate by Source + Overlap Fix", 0) end

local function getSelectedItems()
  local t = {}
  local cnt = reaper.CountSelectedMediaItems(0)
  for i = 0, cnt-1 do
    local it = reaper.GetSelectedMediaItem(0, i)
    if it then t[#t+1] = it end
  end
  return t
end

local function getItemPosLen(it)
  if not it then return nil end
  local pos = reaper.GetMediaItemInfo_Value(it, "D_POSITION") or 0.0
  local len = reaper.GetMediaItemInfo_Value(it, "D_LENGTH") or 0.0
  return pos, len, pos + len
end

local function getItemGUID(it)
  if not it then return ""
  elseif reaper.BR_GetMediaItemGUID then
    return reaper.BR_GetMediaItemGUID(it) or ""
  else
    local ok, guid = reaper.GetSetMediaItemInfo_String(it, "GUID", "", false)
    return ok and guid or ""
  end
end

local function getActiveTakeSourcePath(it)
  if not it then return nil end
  local take = reaper.GetActiveTake(it)
  if not take then return nil end
  if reaper.TakeIsMIDI and reaper.TakeIsMIDI(take) then return nil end
  local src = reaper.GetMediaItemTake_Source(take)
  if not src then return nil end
  local path = reaper.GetMediaSourceFileName(src, "")
  if not path or path == "" then return nil end
  return path
end

local function sortItemsTimelineStable(items)
  table.sort(items, function(a, b)
    local pa = (a and reaper.GetMediaItemInfo_Value(a, "D_POSITION")) or 0.0
    local pb = (b and reaper.GetMediaItemInfo_Value(b, "D_POSITION")) or 0.0
    if pa ~= pb then return pa < pb end
    return tostring(getItemGUID(a)) < tostring(getItemGUID(b))
  end)
end

local function getSelectedTracks()
  local t = {}
  local cnt = reaper.CountSelectedTracks2(0, true)
  for i = 0, cnt-1 do
    local tr = reaper.GetSelectedTrack2(0, i, true)
    if tr then t[#t+1] = tr end
  end
  return t
end

local function trackIndex(tr)
  return math.floor(reaper.GetMediaTrackInfo_Value(tr, "IP_TRACKNUMBER"))
end

local function findTopmostSelectedItemTrackIndex(items)
  local minIdx
  for _, it in ipairs(items) do
    local tr = reaper.GetMediaItem_Track(it)
    if tr then
      local idx = trackIndex(tr)
      if not minIdx or idx < minIdx then minIdx = idx end
    end
  end
  return minIdx
end

local function ensureABCTracks(items)
  local sel = getSelectedTracks()
  if #sel == 3 then
    return sel[1], sel[2], sel[3]
  elseif #sel == 2 then
    local a, b = sel[1], sel[2]
    local idxB0 = trackIndex(b) -- 1-based
    reaper.InsertTrackAtIndex(idxB0, true) -- insert below B (0-based = idxB0)
    local c = reaper.GetTrack(0, idxB0)
    if c then reaper.GetSetMediaTrackInfo_String(c, "P_NAME", NAME_TRACK_C, true) end
    return a, b, c
  else
    local insertAbove = findTopmostSelectedItemTrackIndex(items)
    if not insertAbove then return nil, nil, nil end
    local ins0 = insertAbove - 1
    reaper.InsertTrackAtIndex(ins0, true)
    local a = reaper.GetTrack(0, ins0)
    if a then reaper.GetSetMediaTrackInfo_String(a, "P_NAME", NAME_TRACK_A, true) end

    reaper.InsertTrackAtIndex(ins0 + 1, true)
    local b = reaper.GetTrack(0, ins0 + 1)
    if b then reaper.GetSetMediaTrackInfo_String(b, "P_NAME", NAME_TRACK_B, true) end

    reaper.InsertTrackAtIndex(ins0 + 2, true)
    local c = reaper.GetTrack(0, ins0 + 2)
    if c then reaper.GetSetMediaTrackInfo_String(c, "P_NAME", NAME_TRACK_C, true) end

    return a, b, c
  end
end

local function moveItemToTrack(it, tr)
  if it and tr then reaper.MoveMediaItemToTrack(it, tr) end
end

---------------------------------------
-- Pass 1: A/B alternation by source
---------------------------------------
local function pass1_AB(items, trackA, trackB)
  local prevSource = nil
  local useA = true

  for _, it in ipairs(items) do
    local srcPath = getActiveTakeSourcePath(it)
    if srcPath then
      if not prevSource then
        prevSource = srcPath
      elseif srcPath ~= prevSource then
        useA = not useA
        prevSource = srcPath
      end
      moveItemToTrack(it, useA and trackA or trackB)
    end
  end
end

---------------------------------------
-- Overlap utilities
---------------------------------------
local function intervalsOverlap(aStart, aEnd, bStart, bEnd)
  return (aStart < bEnd) and (bStart < aEnd)
end

local function canPlaceOnTrack(it, candidateTrack)
  if not it or not candidateTrack then return false end
  local pos, len, endt = getItemPosLen(it)
  if not pos then return false end
  local mySrc = getActiveTakeSourcePath(it)

  local n = reaper.CountTrackMediaItems(candidateTrack)
  for i = 0, n-1 do
    local other = reaper.GetTrackMediaItem(candidateTrack, i)
    if other and other ~= it then
      local opos, olen, oend = getItemPosLen(other)
      if opos and intervalsOverlap(pos, endt, opos, oend) then
        local oSrc = getActiveTakeSourcePath(other)
        if mySrc and oSrc and oSrc ~= mySrc then
          return false
        end
      end
    end
  end
  return true
end

local function tryMoveToTrack(it, candidateTrack)
  if canPlaceOnTrack(it, candidateTrack) then
    moveItemToTrack(it, candidateTrack)
    return true
  end
  return false
end

---------------------------------------
-- Pass 2: Fix overlaps on A and B, move to C
---------------------------------------
local function getTrackItemsSorted(tr)
  local t = {}
  local n = reaper.CountTrackMediaItems(tr)
  for i = 0, n-1 do
    local it = reaper.GetTrackMediaItem(tr, i)
    if it then t[#t+1] = it end
  end
  table.sort(t, function(a,b)
    local pa = (a and reaper.GetMediaItemInfo_Value(a, "D_POSITION")) or 0.0
    local pb = (b and reaper.GetMediaItemInfo_Value(b, "D_POSITION")) or 0.0
    if pa ~= pb then return pa < pb end
    return tostring(getItemGUID(a)) < tostring(getItemGUID(b))
  end)
  return t
end

local function pass2_fixOverlaps(trackA, trackB, trackC)
  local moved, misses = 0, 0

  local function fixTrack(tr)
    local items = getTrackItemsSorted(tr)
    local i = 2
    while i <= #items do
      local prev = items[i-1]
      local cur  = items[i]
      if prev and cur then
        local ppos, plen, pend = getItemPosLen(prev)
        local cpos, clen, cend = getItemPosLen(cur)
        if ppos and cpos and intervalsOverlap(ppos, pend, cpos, cend) then
          local psrc = getActiveTakeSourcePath(prev)
          local csrc = getActiveTakeSourcePath(cur)
          if psrc and csrc and psrc ~= csrc then
            -- choose shorter
            local shorter, longer = cur, prev
            local slen, llen = clen or 0, plen or 0
            if (plen or 0) < (clen or 0) then
              shorter, longer = prev, cur
              slen, llen = plen or 0, clen or 0
            end

            local didMove = tryMoveToTrack(shorter, trackC)
            if not didMove then
              didMove = tryMoveToTrack(longer, trackC)
            end

            if didMove then
              moved = moved + 1
              -- refresh items and back up one to re-evaluate region
              items = getTrackItemsSorted(tr)
              i = math.max(2, i - 1)
              goto continue
            else
              misses = misses + 1
            end
          end
        end
      end
      i = i + 1
      ::continue::
    end
  end

  fixTrack(trackA)
  fixTrack(trackB)
  return moved, misses
end

---------------------------------------
-- Main
---------------------------------------
reaper.Undo_BeginBlock()
reaper.PreventUIRefresh(1)

local items = getSelectedItems()
if #items == 0 then
  reaper.PreventUIRefresh(-1)
  reaper.Undo_EndBlock("Alternate by source + overlap fix (no items)", -1)
  msg("No items selected.")
  return
end

sortItemsTimelineStable(items)
local trackA, trackB, trackC = ensureABCTracks(items)
if not (trackA and trackB and trackC) then
  reaper.PreventUIRefresh(-1)
  reaper.Undo_EndBlock("Alternate by source + overlap fix (no dest tracks)", -1)
  msg("Could not prepare A/B/C destination tracks.")
  return
end

-- Pass 1: A/B alternation
pass1_AB(items, trackA, trackB)

-- Pass 2: Resolve overlaps by moving to C
local moved, misses = pass2_fixOverlaps(trackA, trackB, trackC)

reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()
local actionName = string.format("Alternate by source (A/B) + overlap fix to C | moved:%d, unresolved:%d", moved or 0, misses or 0)
reaper.Undo_EndBlock(actionName, -1)
