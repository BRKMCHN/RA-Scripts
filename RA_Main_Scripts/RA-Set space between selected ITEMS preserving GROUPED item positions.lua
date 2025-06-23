-- @description Set space between selected ITEMS preserving GROUPED item positions
-- @version 1.0
-- @author Reservoir Audio / MrBrock with AI

reaper.Undo_BeginBlock()

-- Prompt for gap input
local retval, user_input = reaper.GetUserInputs("Space Between Item Groups", 1, "Gap (mm:ss:ms)", "00:01:000")
if not retval then return end

local min, sec, ms = user_input:match("(%d+):(%d+):(%d+)")
if not min or not sec or not ms then
    reaper.ShowMessageBox("Invalid format! Use mm:ss:ms", "Error", 0)
    return
end
local gap = (tonumber(min) * 60) + tonumber(sec) + (tonumber(ms) / 1000)

-- Collect selected items and group them by I_GROUPID
local item_count = reaper.CountSelectedMediaItems(0)
if item_count == 0 then return end

local group_map = {}
local chunks = {}
local seen = {}

for i = 0, item_count - 1 do
    local item = reaper.GetSelectedMediaItem(0, i)
    if not seen[item] then
        local group_id = reaper.GetMediaItemInfo_Value(item, "I_GROUPID")
        local key = group_id > 0 and tostring(group_id) or ("single_" .. tostring(item))

        if not group_map[key] then
            group_map[key] = {
                group_id = group_id,
                items = {},
                min_pos = math.huge,
                max_end = -math.huge
            }
            table.insert(chunks, group_map[key])
        end

        local pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
        local len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
        local item_end = pos + len

        table.insert(group_map[key].items, {
            item = item,
            pos = pos,
            len = len,
            offset = 0 -- to be calculated
        })

        group_map[key].min_pos = math.min(group_map[key].min_pos, pos)
        group_map[key].max_end = math.max(group_map[key].max_end, item_end)
        seen[item] = true

        -- Add other items in same group if grouped
        if group_id > 0 then
            for j = 0, item_count - 1 do
                local other = reaper.GetSelectedMediaItem(0, j)
                if not seen[other] then
                    local other_gid = reaper.GetMediaItemInfo_Value(other, "I_GROUPID")
                    if other_gid == group_id then
                        local opos = reaper.GetMediaItemInfo_Value(other, "D_POSITION")
                        local olen = reaper.GetMediaItemInfo_Value(other, "D_LENGTH")
                        local oend = opos + olen

                        table.insert(group_map[key].items, {
                            item = other,
                            pos = opos,
                            len = olen,
                            offset = 0
                        })

                        group_map[key].min_pos = math.min(group_map[key].min_pos, opos)
                        group_map[key].max_end = math.max(group_map[key].max_end, oend)
                        seen[other] = true
                    end
                end
            end
        end

        -- Calculate offsets for items in this chunk
        for _, entry in ipairs(group_map[key].items) do
            entry.offset = entry.pos - group_map[key].min_pos
        end
    end
end

-- Sort chunks by start position
table.sort(chunks, function(a, b)
    return a.min_pos < b.min_pos
end)

-- Move chunks into new positions with gap
local cursor = chunks[1] and chunks[1].min_pos or 0
for _, chunk in ipairs(chunks) do
    for _, entry in ipairs(chunk.items) do
        local new_pos = cursor + entry.offset
        reaper.SetMediaItemInfo_Value(entry.item, "D_POSITION", new_pos)
    end
    local chunk_len = chunk.max_end - chunk.min_pos
    cursor = cursor + chunk_len + gap
end

reaper.UpdateArrange()
reaper.Undo_EndBlock("Space grouped item chunks", -1)

