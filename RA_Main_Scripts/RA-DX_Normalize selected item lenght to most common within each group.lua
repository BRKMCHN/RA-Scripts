-- @version 1.0
-- @description Normalize selected item lenght to most common within each group. (For resetting DX blocs)
-- @author RESERVOIR AUDIO / MrBrock, with AI.

--[[
  Normalize item lengths to the MODE (most common) length per group,
  and normalize BOTH manual + AUTO fade data to the MODE fade values per group.

  Scope:
  - Determine target groups from SELECTED items
  - Apply changes to ALL items in the project belonging to those group IDs

  Mode behavior:
  - Float values use tolerance bucketing; ties = first bucket to reach max count wins
  - Shape values treated as discrete (rounded to nearest integer)

  Applies:
  - Length: group mode of D_LENGTH
  - Fades: group modes of each fade-related field (manual + auto)
--]]

local r = reaper

-- Tolerances for bucketing float values
local MODE_TOL_LEN   = 1e-6   -- seconds for length bucketing
local MODE_TOL_FADE  = 1e-6   -- seconds for fade length bucketing
local MODE_TOL_DIR   = 1e-6   -- fade "dir" bucketing (usually 0..1-ish, but keep float-safe)
local EPS_EQUAL      = 1e-9

local function approx_equal(a, b, eps)
  return math.abs(a - b) <= (eps or EPS_EQUAL)
end

local function bucket_key_float(x, tol)
  tol = tol or 1e-6
  if tol <= 0 then return tostring(x) end
  local q = math.floor((x / tol) + 0.5)
  return tostring(q)
end

local function bucket_key_int(x)
  -- shapes sometimes come back as float (e.g. 7.0), so round
  return tostring(math.floor(x + 0.5))
end

-- Mode helper: returns representative value from the winning bucket
-- Tie behavior: first bucket to reach highest count wins (no replace on equal count)
local function mode_of_floats(values, tol)
  local counts = {} -- key -> {count=int, rep=number}
  local bestKey, bestCount = nil, -1

  for _, v in ipairs(values) do
    local k = bucket_key_float(v, tol)
    local e = counts[k]
    if not e then
      e = { count = 0, rep = v }
      counts[k] = e
    end
    e.count = e.count + 1

    if e.count > bestCount then
      bestCount = e.count
      bestKey = k
    end
  end

  if not bestKey then return nil end
  return counts[bestKey].rep
end

local function mode_of_intlikes(values)
  local counts = {} -- key -> {count=int, rep=number}
  local bestKey, bestCount = nil, -1

  for _, v in ipairs(values) do
    local k = bucket_key_int(v)
    local e = counts[k]
    if not e then
      e = { count = 0, rep = math.floor(v + 0.5) }
      counts[k] = e
    end
    e.count = e.count + 1

    if e.count > bestCount then
      bestCount = e.count
      bestKey = k
    end
  end

  if not bestKey then return nil end
  return counts[bestKey].rep
end

local function get_item_field(item, field)
  return r.GetMediaItemInfo_Value(item, field)
end

local function set_item_field(item, field, value)
  r.SetMediaItemInfo_Value(item, field, value)
end

local function main()
  local proj = 0
  local selCount = r.CountSelectedMediaItems(proj)
  if selCount == 0 then return end

  -- 1) Collect target group IDs from selected items
  local targetGids = {}
  for i = 0, selCount - 1 do
    local item = r.GetSelectedMediaItem(proj, i)
    local gid = get_item_field(item, "I_GROUPID")
    if gid ~= 0 then
      targetGids[gid] = true
    end
  end
  local hasAny = false
  for _ in pairs(targetGids) do hasAny = true break end
  if not hasAny then return end

  -- 2) Gather ALL items in those groups
  local groups = {} -- gid -> { items = {} }
  local itemCount = r.CountMediaItems(proj)
  for i = 0, itemCount - 1 do
    local item = r.GetMediaItem(proj, i)
    local gid = get_item_field(item, "I_GROUPID")
    if gid ~= 0 and targetGids[gid] then
      local t = groups[gid]
      if not t then
        t = { items = {} }
        groups[gid] = t
      end
      t.items[#t.items + 1] = item
    end
  end

  r.Undo_BeginBlock()
  r.PreventUIRefresh(1)

  local changedLen = 0

  -- Fields to mode-normalize (manual + auto)
  local float_fields_fade_len = {
    "D_FADEINLEN", "D_FADEOUTLEN",
    "D_FADEINLEN_AUTO", "D_FADEOUTLEN_AUTO",
  }

  local float_fields_dir = {
    "D_FADEINDIR", "D_FADEOUTDIR",
    "D_FADEINDIR_AUTO", "D_FADEOUTDIR_AUTO",
  }

  local int_fields_shape = {
    "C_FADEINSHAPE", "C_FADEOUTSHAPE",
    "C_FADEINSHAPE_AUTO", "C_FADEOUTSHAPE_AUTO",
  }

  for _, t in pairs(groups) do
    if #t.items >= 2 then
      -- Compute MODE length
      local lengths = {}
      for i, item in ipairs(t.items) do
        lengths[i] = get_item_field(item, "D_LENGTH")
      end
      local targetLen = mode_of_floats(lengths, MODE_TOL_LEN)

      -- Compute MODE fade values per field
      local target = {}

      for _, field in ipairs(float_fields_fade_len) do
        local vals = {}
        for i, item in ipairs(t.items) do vals[i] = get_item_field(item, field) end
        target[field] = mode_of_floats(vals, MODE_TOL_FADE) or 0.0
      end

      for _, field in ipairs(float_fields_dir) do
        local vals = {}
        for i, item in ipairs(t.items) do vals[i] = get_item_field(item, field) end
        target[field] = mode_of_floats(vals, MODE_TOL_DIR) or 0.0
      end

      for _, field in ipairs(int_fields_shape) do
        local vals = {}
        for i, item in ipairs(t.items) do vals[i] = get_item_field(item, field) end
        target[field] = mode_of_intlikes(vals) or 0
      end

      -- Apply to group
      for _, item in ipairs(t.items) do
        local curLen = get_item_field(item, "D_LENGTH")
        if targetLen and (not approx_equal(curLen, targetLen, EPS_EQUAL)) then
          set_item_field(item, "D_LENGTH", targetLen)
          changedLen = changedLen + 1
        end

        -- apply fades (manual + auto)
        for _, field in ipairs(float_fields_fade_len) do
          set_item_field(item, field, target[field])
        end
        for _, field in ipairs(float_fields_dir) do
          set_item_field(item, field, target[field])
        end
        for _, field in ipairs(int_fields_shape) do
          set_item_field(item, field, target[field])
        end

        r.UpdateItemInProject(item)
      end
    end
  end

  r.PreventUIRefresh(-1)
  r.UpdateArrange()
  r.Undo_EndBlock(
    ("Normalize groups to MODE length + MODE fades (%d length changes)"):format(changedLen),
    -1
  )
end

main()
