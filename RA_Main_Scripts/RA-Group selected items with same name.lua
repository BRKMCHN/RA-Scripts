-- @version 1.0
-- @description Group selected items with same name (1 group per unique item name)
-- @author RESERVOIR AUDIO / MrBrock, with AI.

-- Group selected items by item name
function group_items_by_name()
  local item_groups = {}
  local item_count = reaper.CountSelectedMediaItems(0)

  -- Collect items and group them by name
  for i = 0, item_count - 1 do
    local item = reaper.GetSelectedMediaItem(0, i)
    local take = reaper.GetActiveTake(item)

    if take and reaper.TakeIsMIDI(take) == false then
      local _, name = reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
      if name == "" then name = "UNNAMED" end

      if not item_groups[name] then
        item_groups[name] = {}
      end
      table.insert(item_groups[name], item)
    end
  end

  -- Apply grouping
  local group_id = 1
  for _, group in pairs(item_groups) do
    if #group > 1 then
      for _, item in ipairs(group) do
        reaper.SetMediaItemInfo_Value(item, "I_GROUPID", group_id)
      end
      group_id = group_id + 1
    end
  end

  reaper.UpdateArrange()
end

reaper.Undo_BeginBlock()
group_items_by_name()
reaper.Undo_EndBlock("Group selected items by name", -1)

