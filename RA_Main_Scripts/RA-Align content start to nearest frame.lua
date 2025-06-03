-- @version 1.0
-- @description Align (snap) selected item's content start position to nearest frame.
-- @author RESERVOIR AUDIO / MrBrock, with AI.

function frame_align_content_to_frame()
    local item_count = reaper.CountSelectedMediaItems(0)
    if item_count == 0 then return end

    -- Get project frame rate
    local fps = reaper.TimeMap_curFrameRate(0)
    if not fps or fps == 0 then fps = 30 end -- fallback to 30 fps
    local frame_duration = 1 / fps -- duration of a single frame in seconds

    reaper.Undo_BeginBlock()

    for i = 0, item_count-1 do
        local item = reaper.GetSelectedMediaItem(0, i)
        local take = reaper.GetActiveTake(item)
        if take and not reaper.TakeIsMIDI(take) then
            local pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
            local start_offset = reaper.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS")

            -- Theoretical media start
            local theoretical_start = pos - start_offset

            -- Snap to nearest frame boundary
            local frames = math.floor(theoretical_start / frame_duration + 0.5)
            local snapped_start = frames * frame_duration

            -- Calculate new start offset
            local new_start_offset = pos - snapped_start

            -- Only update if necessary
            if math.abs(new_start_offset - start_offset) > 0.000001 then
                reaper.SetMediaItemTakeInfo_Value(take, "D_STARTOFFS", new_start_offset)
            end
        end
    end

    reaper.UpdateArrange()
    reaper.Undo_EndBlock("Align content start to nearest frame", -1)
end

frame_align_content_to_frame()

