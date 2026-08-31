-- @version 1.0
-- @description Snap Region Boundaries to nearest grid position (Ignoring Zoom)
-- @author RESERVOIR AUDIO / MrBrock, with AI.

function snap_regions_in_time_selection_to_frames()

    -- Get time selection
    local ts_start, ts_end = reaper.GetSet_LoopTimeRange(
        false,
        false,
        0,
        0,
        false
    )

    if ts_start == ts_end then
        return
    end

    -- Get project frame rate
    local fps = reaper.TimeMap_curFrameRate(0)

    if not fps or fps == 0 then
        fps = 30
    end

    local frame_duration = 1 / fps

    -- Count markers + regions
    local _, num_markers, num_regions = reaper.CountProjectMarkers(0)
    local total = num_markers + num_regions

    reaper.Undo_BeginBlock()

    for i = 0, total - 1 do

        local retval,
              is_region,
              pos,
              region_end,
              name,
              index,
              color = reaper.EnumProjectMarkers3(0, i)

        if retval > 0 then
            if is_region then

                -- Only process regions whose START is inside the time selection
                if pos >= ts_start and pos <= ts_end then

                    -- Snap start to nearest frame
                    local start_frame =
                        math.floor((pos / frame_duration) + 0.5)

                    local new_start =
                        start_frame * frame_duration

                    -- Snap end to nearest frame
                    local end_frame =
                        math.floor((region_end / frame_duration) + 0.5)

                    local new_end =
                        end_frame * frame_duration

                    -- Update existing region
                    reaper.SetProjectMarker3(
                        0,
                        index,
                        true,
                        new_start,
                        new_end,
                        name,
                        color
                    )
                end
            end
        end
    end

    reaper.UpdateArrange()

    reaper.Undo_EndBlock(
        "Snap region boundaries to nearest frame",
        -1
    )
end


snap_regions_in_time_selection_to_frames()
