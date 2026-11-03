-- @version 1.0
-- @description RESET selected take playrate and adapt start offset from metadata or ratio
-- @author RESERVOIR AUDIO / MrBrock, with AI.


--[[
  RA - Reset Take Rate and Restore Start Offset

  For selected media items:
  1. Reset active take playback rate to 1.0
  2. Restore source offset from fetched CID value found in item notes (from vordio)
  3. Otherwise calculate start offset / original playrate rate

  CID format example:
  CID:508.88337500|0.41708333|3.50350000|source.wav
]]

local proj = 0

local function get_cid_offset(item)
    local _, notes = reaper.GetSetMediaItemInfo_String(
        item, "P_NOTES", "", false
    )

    if not notes or notes == "" then
        return nil
    end

    -- Find the second pipe-separated CID value
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

    if count == 0 then
        return
    end

    local cid_count = 0
    local fallback_count = 0
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
                local cid_offset = get_cid_offset(item)
                local new_offset

                if cid_offset then
                    new_offset = cid_offset
                    cid_count = cid_count + 1
                else
                    new_offset = offset / rate
                    fallback_count = fallback_count + 1
                end

                reaper.SetMediaItemTakeInfo_Value(
                    take, "D_PLAYRATE", 1.0
                )

                reaper.SetMediaItemTakeInfo_Value(
                    take, "D_STARTOFFS", new_offset
                )
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
        "Reset take rate and restore CID start offset", -1
    )

    -- Optional console report
    local DEBUG = false

    if DEBUG then
        reaper.ShowConsoleMsg(
            string.format(
                "CID restored: %d\nFallback: %d\nSkipped: %d\n",
                cid_count,
                fallback_count,
                skipped_count
            )
        )
    end
end

main()

