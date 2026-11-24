-- @version 1.1
-- @description RESET selected take playrate and adapt start offset (CID or ratio)
-- @author RESERVOIR AUDIO / MrBrock, with AI.

--[[
  RA - Reset Take Rate and Restore Start Offset

  Selected media items, active takes only.

  Mode 1: CID metadata
    Reset playrate to 1.0
    Set start offset from second CID value from project notes
    Skip items without valid CID

  Mode 2: Rate calculation
    Reset playrate to 1.0
    Set start offset = original offset / original rate

  CID format example:
  CID:508.88337500|0.41708333|3.50350000|source.wav
]]

local proj = 0
local DEBUG = false

local function get_cid_offset(item)
    local _, notes = reaper.GetSetMediaItemInfo_String(
        item, "P_NOTES", "", false
    )

    if not notes or notes == "" then
        return nil
    end

    for line in notes:gmatch("[^\r\n]+") do
        local value = line:match(
            "^%s*CID:%s*[^|]*|%s*([^|]+)"
        )

        if value then
            local offset = tonumber(value)

            if offset and offset >= 0 then
                return offset
            end
        end
    end

    return nil
end

local function main()
    local count = reaper.CountSelectedMediaItems(proj)
    if count == 0 then return end

    -- Choose repair method
    local retval, input = reaper.GetUserInputs(
        "Start Offset Repair",
        1,
        "1 = Item CID  /  2 = Rate Quotient",
        "1"
    )

    if not retval then return end

    local mode = input:match("^%s*(.-)%s*$")

    if mode ~= "1" and mode ~= "2" then
        reaper.MB(
            "Please enter 1 (CID) or 2 (Rate calculation).",
            "Invalid repair method",
            0
        )
        return
    end

    local cid_count = 0
    local ratio_count = 0
    local skipped_count = 0

    reaper.Undo_BeginBlock()
    reaper.PreventUIRefresh(1)

    for i = 0, count - 1 do
        local item = reaper.GetSelectedMediaItem(proj, i)
        local take = reaper.GetActiveTake(item)

        if take then
            local rate = reaper.GetMediaItemTakeInfo_Value(
                take, "D_PLAYRATE"
            )

            local offset = reaper.GetMediaItemTakeInfo_Value(
                take, "D_STARTOFFS"
            )

            if rate > 0 then
                local new_offset

                if mode == "1" then
                    new_offset = get_cid_offset(item)

                    if new_offset then
                        cid_count = cid_count + 1
                    end
                else
                    new_offset = offset / rate
                    ratio_count = ratio_count + 1
                end

                if new_offset then
                    reaper.SetMediaItemTakeInfo_Value(
                        take, "D_PLAYRATE", 1.0
                    )

                    reaper.SetMediaItemTakeInfo_Value(
                        take, "D_STARTOFFS", new_offset
                    )

                    reaper.UpdateItemInProject(item)
                else
                    skipped_count = skipped_count + 1
                end
            else
                skipped_count = skipped_count + 1
            end
        else
            skipped_count = skipped_count + 1
        end
    end

    reaper.PreventUIRefresh(-1)
    reaper.UpdateArrange()

    reaper.Undo_EndBlock(
        "Reset take rate and repair offset (" ..
        (mode == "1" and "CID" or "Rate calculation") ..
        ")",
        -1
    )

    if DEBUG then
        reaper.ShowConsoleMsg(
            string.format(
                "CID repaired: %d\n" ..
                "Rate repaired: %d\n" ..
                "Skipped: %d\n",
                cid_count,
                ratio_count,
                skipped_count
            )
        )
    end
end

main()
