-- @version 1.1
-- @description Sort selected items by length and optimize vertical track usage within overlap threshold.
-- @author MrBrock / AI
-- V1.1 Usable but needs refinement to shorten execute time when handling a lot of items and tracks.

-----------------------------------------------
-- HELPER FUNCTIONS (original)
-----------------------------------------------

-- Helper function to unselect all tracks
function unselect_all_tracks()
    for i = 0, reaper.CountTracks(0) - 1 do
        reaper.SetTrackSelected(reaper.GetTrack(0, i), false)
    end
end

-- Helper function to get the first selected track's number
function get_first_selected_track_num()
    for i = 0, reaper.CountTracks(0) - 1 do
        local track = reaper.GetTrack(0, i)
        if reaper.IsTrackSelected(track) then
            return i + 1 -- Track numbers are 1-based
        end
    end
    return nil -- Return nil if no track is selected
end

-- Step 1: Fetch item data
function get_selected_items_info()
    local items = {}
    for i = 0, reaper.CountSelectedMediaItems(0) - 1 do
        local item = reaper.GetSelectedMediaItem(0, i)
        local position = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
        local length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
        local track = reaper.GetMediaItemTrack(item)
        local track_num = reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER")

        table.insert(items, {
            item = item,
            position = position,
            length = length,
            track_num = track_num
        })
    end
    return items
end

-- Step 2: Organize items by track and sort by length
function organize_and_sort_items(items)
    local highest_track_num = nil -- Track the highest numbered track
    local lowest_track_num = nil  -- Track the lowest numbered track
    local all_items = {}

    -- Find the highest and lowest numbered tracks
    for _, item_info in ipairs(items) do
        if highest_track_num == nil or item_info.track_num > highest_track_num then
            highest_track_num = item_info.track_num
        end
        if lowest_track_num == nil or item_info.track_num < lowest_track_num then
            lowest_track_num = item_info.track_num
        end
    end

    -- Store all items
    for _, item_info in ipairs(items) do
        table.insert(all_items, item_info)
    end

    -- Sort the items by length (descending)
    table.sort(all_items, function(a, b) return a.length > b.length end)

    return all_items, highest_track_num, lowest_track_num
end

-- Step 3: Select tracks between the user-defined lowest and the highest track numbers
function select_tracks_in_range(lowest_track_num, highest_track_num)
    unselect_all_tracks() -- First, unselect all tracks

    -- Select all tracks between the lowest and highest track numbers
    for track_num = lowest_track_num, highest_track_num do
        local track = reaper.GetTrack(0, track_num - 1) -- track_num is 1-based
        reaper.SetTrackSelected(track, true)
    end
end

-- Step 4: Collect items on the user-defined lowest track before processing
function collect_items_on_lowest_track(items, lowest_track_num)
    local items_on_lowest_track = {}
    for _, item_info in ipairs(items) do
        if item_info.track_num == lowest_track_num then
            table.insert(items_on_lowest_track, item_info.item)
        end
    end
    return items_on_lowest_track
end

-- Step 5: Unselect collected items
function unselect_items(items_to_unselect)
    for _, item in ipairs(items_to_unselect) do
        reaper.SetMediaItemSelected(item, false)
    end
end

-- Step 6: Establish timeline for the highest track
function create_timeline_for_highest_track(track_items)
    local timeline = {}
    for _, item_info in ipairs(track_items) do
        table.insert(timeline, {
            start = item_info.position,
            finish = item_info.position + item_info.length
        })
    end

    -- Sort intervals by start time
    table.sort(timeline, function(a, b) return a.start < b.start end)

    -- Merge overlapping intervals
    local merged_timeline = {}
    local current_interval = timeline[1]

    for i = 2, #timeline do
        local next_interval = timeline[i]
        if current_interval.finish >= next_interval.start then
            current_interval.finish = math.max(current_interval.finish, next_interval.finish)
        else
            table.insert(merged_timeline, current_interval)
            current_interval = next_interval
        end
    end

    table.insert(merged_timeline, current_interval)
    return merged_timeline
end

-- Step 7: Check overlap between two items, using the shorter item as reference
function check_overlap_between_items(item1, item2)
    local item1_start = item1.position
    local item1_end = item1.position + item1.length
    local item2_start = item2.position
    local item2_end = item2.position + item2.length

    local overlap_start = math.max(item1_start, item2_start)
    local overlap_end = math.min(item1_end, item2_end)
    local overlap = math.max(0, overlap_end - overlap_start)

    local shorter_item_length = math.min(item1.length, item2.length)
    return overlap / shorter_item_length
end

-- Step 8: Check overlap with the entire timeline
function check_overlap_with_timeline(item, timeline)
    local item_start = item.position
    local item_end = item.position + item.length
    local total_overlap = 0

    for _, interval in ipairs(timeline) do
        local overlap_start = math.max(item_start, interval.start)
        local overlap_end = math.min(item_end, interval.finish)
        local overlap = math.max(0, overlap_end - overlap_start)
        total_overlap = total_overlap + overlap
    end

    return total_overlap / item.length
end

-- Step 9: Move item to the highest track and add to unselect list
function move_item_to_highest_track(item, lowest_track_num, items_to_unselect)
    local highest_track = reaper.GetTrack(0, lowest_track_num - 1)
    reaper.MoveMediaItemToTrack(item, highest_track)
    table.insert(items_to_unselect, item)
end

-- Step 10: Cycle through each item in the sorted list
function process_items(all_items, lowest_track_num, items_to_unselect)
    local overlap_threshold = 0.5  -- <--- Overlap threshold

    for _, current_item in ipairs(all_items) do
        if current_item.track_num == lowest_track_num then
            -- Already on that track, skip
        else
            -- Gather items on that track
            local highest_track_items = {}
            for _, item_info in ipairs(all_items) do
                if item_info.track_num == lowest_track_num then
                    table.insert(highest_track_items, item_info)
                end
            end

            -- Check overlap with individual items first (only those that intersect in time)
            local skip_item = false
            local current_item_start = current_item.position
            local current_item_end = current_item.position + current_item.length
            
            for _, highest_track_item in ipairs(highest_track_items) do
                local highest_item_start = highest_track_item.position
                local highest_item_end = highest_track_item.position + highest_track_item.length

                if (highest_item_end > current_item_start) and (highest_item_start < current_item_end) then
                    local overlap_percentage = check_overlap_between_items(current_item, highest_track_item)
                    if overlap_percentage > overlap_threshold then
                        skip_item = true
                        break
                    end
                end
            end

            -- If no big overlap, check timeline
            if not skip_item then
                local timeline = create_timeline_for_highest_track(highest_track_items)
                local timeline_overlap = check_overlap_with_timeline(current_item, timeline)
                if timeline_overlap <= overlap_threshold then
                    move_item_to_highest_track(current_item.item, lowest_track_num, items_to_unselect)
                    current_item.track_num = lowest_track_num
                end
            end
        end
    end
end

---------------------------------------------------
-- MAIN FUNCTION
---------------------------------------------------
function main()
    reaper.Undo_BeginBlock()

    -----------------------------------------------------------
    -- (A) Store currently selected tracks & items
    -----------------------------------------------------------
    local stored_tracks = {}
    for t = 0, reaper.CountTracks(0) - 1 do
        local track = reaper.GetTrack(0, t)
        if reaper.IsTrackSelected(track) then
            table.insert(stored_tracks, track)
        end
    end

    local stored_items = {}
    for i = 0, reaper.CountSelectedMediaItems(0) - 1 do
        local it = reaper.GetSelectedMediaItem(0, i)
        table.insert(stored_items, it)
    end

    -----------------------------------------------------------
    -- (B) Unselect all tracks
    -----------------------------------------------------------
    unselect_all_tracks()

    -----------------------------------------------------------
    -- (C) Reselect the tracks that contain the selected items
    --     so the script has a valid 'first selected track'
    -----------------------------------------------------------
    for i = 0, reaper.CountSelectedMediaItems(0) - 1 do
        local it = reaper.GetSelectedMediaItem(0, i)
        if it then
            local tr = reaper.GetMediaItemTrack(it)
            if tr then
                reaper.SetTrackSelected(tr, true)
            end
        end
    end

    -----------------------------------------------------------
    -- Now run the original loop
    -----------------------------------------------------------
    while reaper.CountSelectedMediaItems(0) > 0 do
        -- Step 1: Get the first selected track number as the destination track
        local first_selected_track_num = get_first_selected_track_num()
        if not first_selected_track_num then
            reaper.ShowConsoleMsg("No track is selected. Please select a track and try again.\n")
            break
        end

        -- Step 2: Get selected item info
        local items = get_selected_items_info()
        if #items == 0 then
            break
        end

        -- Step 3: Sort and find highest & lowest track
        local all_items, highest_track_num, lowest_item_track_num = organize_and_sort_items(items)

        -- The script sets the destination track as the lower of these two
        local destination_track_num = math.min(first_selected_track_num, lowest_item_track_num)

        -- Step 4: Select tracks between destination_track_num and highest_track_num
        select_tracks_in_range(destination_track_num, highest_track_num)

        -- Step 5: Collect items on that destination track before processing
        local items_on_destination_track = collect_items_on_lowest_track(all_items, destination_track_num)

        local items_to_unselect = items_on_destination_track

        -- Step 10: Process
        process_items(all_items, destination_track_num, items_to_unselect)

        -- Unselect those items
        unselect_items(items_to_unselect)

        -- Unselect the destination track
        local destination_track = reaper.GetTrack(0, destination_track_num - 1)
        if destination_track then
            reaper.SetTrackSelected(destination_track, false)
        end

        reaper.UpdateArrange()
    end

    -----------------------------------------------------------
    -- (D) Restore original track selection
    -----------------------------------------------------------
    unselect_all_tracks()
    for _, tr in ipairs(stored_tracks) do
        if reaper.ValidatePtr(tr, "MediaTrack*") then
            reaper.SetTrackSelected(tr, true)
        end
    end

    -----------------------------------------------------------
    -- (E) Restore original item selection
    -----------------------------------------------------------
    -- First unselect all items
    for i = 0, reaper.CountMediaItems(0) - 1 do
        reaper.SetMediaItemSelected(reaper.GetMediaItem(0, i), false)
    end
    -- Then reselect stored items
    for _, it in ipairs(stored_items) do
        if reaper.ValidatePtr(it, "MediaItem*") then
            reaper.SetMediaItemSelected(it, true)
        end
    end

    reaper.UpdateArrange()
    reaper.Undo_EndBlock("Process items and move to highest track within overlap threshold", -1)
end

---------------------------------------------------
-- RUN
---------------------------------------------------
main()
