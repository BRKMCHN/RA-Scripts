-- @version 1.0
-- @description Sort selected items by lenght and optimize vertical track usage within overlap threshold.
-- @author RESERVOIR AUDIO / MrBrock, with AI.

-- V1 Usable but needs refinement to shorten execute time when handling alot of items and tracks. See step 10 for local threshold.

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

        -- Store item info in a table, including track number and position/length
        table.insert(items, {item = item, position = position, length = length, track_num = track_num})
    end
    return items
end

-- Step 2: Organize items by track and sort by length
function organize_and_sort_items(items)
    local highest_track_num = nil -- Track the highest numbered track
    local lowest_track_num = nil -- Track the lowest numbered track
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

    -- Sort the items by length in descending order
    table.sort(all_items, function(a, b) return a.length > b.length end)

    return all_items, highest_track_num, lowest_track_num
end

-- Step 3: Select tracks between the user-defined lowest and the highest track numbers
function select_tracks_in_range(lowest_track_num, highest_track_num)
    unselect_all_tracks() -- First, unselect all tracks

    -- Select all tracks between the lowest and highest track numbers
    for track_num = lowest_track_num, highest_track_num do
        local track = reaper.GetTrack(0, track_num - 1) -- track_num is 1-based, so we subtract 1
        reaper.SetTrackSelected(track, true)
    end
end

-- Step 4: Collect items on the user-defined lowest track before processing
function collect_items_on_lowest_track(items, lowest_track_num)
    local items_on_lowest_track = {}
    
    -- Collect all items on the user-defined lowest numbered track
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
        table.insert(timeline, {start = item_info.position, finish = item_info.position + item_info.length})
    end

    -- Sort intervals by start time
    table.sort(timeline, function(a, b) return a.start < b.start end)

    -- Merge overlapping intervals
    local merged_timeline = {}
    local current_interval = timeline[1]

    for i = 2, #timeline do
        local next_interval = timeline[i]
        if current_interval.finish >= next_interval.start then
            -- Overlapping intervals: merge by extending the current interval's end
            current_interval.finish = math.max(current_interval.finish, next_interval.finish)
        else
            -- No overlap: push the current interval to the merged timeline and start a new one
            table.insert(merged_timeline, current_interval)
            current_interval = next_interval
        end
    end

    -- Add the last interval
    table.insert(merged_timeline, current_interval)

    return merged_timeline
end

-- Step 7: Check overlap between two items, using the shortest item as reference
function check_overlap_between_items(item1, item2)
    local item1_start = item1.position
    local item1_end = item1.position + item1.length
    local item2_start = item2.position
    local item2_end = item2.position + item2.length

    -- Check overlap between item1 and item2
    local overlap_start = math.max(item1_start, item2_start)
    local overlap_end = math.min(item1_end, item2_end)
    local overlap = math.max(0, overlap_end - overlap_start)

    -- Use the shorter item's length for calculating overlap percentage
    local shorter_item_length = math.min(item1.length, item2.length)

    -- Return the percentage of the shorter item's length that overlaps
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

    -- Return the percentage of the item's length that overlaps with the timeline
    return total_overlap / item.length
end

-- Step 9: Move item to the highest track and add to unselect list
function move_item_to_highest_track(item, lowest_track_num, items_to_unselect)
    -- Get the track corresponding to the lowest track number (which is the highest track)
    local highest_track = reaper.GetTrack(0, lowest_track_num - 1)

    -- Move the media item to the highest track
    reaper.MoveMediaItemToTrack(item, highest_track)

    -- Add the item to the list of items to be unselected later
    table.insert(items_to_unselect, item)
end

-- Step 10: Cycle through each item in the sorted list
function process_items(all_items, lowest_track_num, items_to_unselect)
    local overlap_threshold = 0.5 

    -- Repeat cycle for each item in the sorted list
    for _, current_item in ipairs(all_items) do
        if current_item.track_num == lowest_track_num then
            -- Item is already on the highest track, so skip to the next item
        else
            -- Check overlap with individual items on the highest track
            local highest_track_items = {}
            for _, item_info in ipairs(all_items) do
                if item_info.track_num == lowest_track_num then
                    table.insert(highest_track_items, item_info)
                end
            end

            -- First check overlap with individual items on the highest track, but only compare items that intersect in time
            local skip_item = false
            for _, highest_track_item in ipairs(highest_track_items) do
                local current_item_start = current_item.position
                local current_item_end = current_item.position + current_item.length
                local highest_item_start = highest_track_item.position
                local highest_item_end = highest_track_item.position + highest_track_item.length

                -- Only check overlap if the items intersect in time
                if (highest_item_end > current_item_start) and (highest_item_start < current_item_end) then
                    local overlap_percentage = check_overlap_between_items(current_item, highest_track_item)
                    if overlap_percentage > overlap_threshold then
                        skip_item = true
                        break
                    end
                end
            end

            -- If no high overlap with individual items, check against the timeline
            if not skip_item then
                local timeline = create_timeline_for_highest_track(highest_track_items)
                local timeline_overlap = check_overlap_with_timeline(current_item, timeline)
                if timeline_overlap <= overlap_threshold then
                    -- Move the item to the highest track and add it to unselect list
                    move_item_to_highest_track(current_item.item, lowest_track_num, items_to_unselect)
                    -- Update the item's track number to reflect that it has been moved
                    current_item.track_num = lowest_track_num
                end
            end
        end
    end
end

-- Main function to run the full process
function main()
    -- Loop until no selected items remain
    while reaper.CountSelectedMediaItems(0) > 0 do
        -- Step 1: Get the first selected track number as the destination track
        local first_selected_track_num = get_first_selected_track_num()
        if not first_selected_track_num then
            reaper.ShowConsoleMsg("No track is selected. Please select a track and try again.\n")
            return
        end

        -- Step 2: Get selected item information
        local items = get_selected_items_info()

        -- If there are no selected items, stop the script
        if #items == 0 then
            break -- Exit the loop when no items are selected
        end

        -- Step 3: Organize and sort all items and find highest and lowest track numbers
        local all_items, highest_track_num, lowest_item_track_num = organize_and_sort_items(items)

        -- Determine the destination track as the lower of first selected track and the lowest item track
        local destination_track_num = math.min(first_selected_track_num, lowest_item_track_num)

        -- Step 4: Select tracks between the destination track and the highest track numbers
        select_tracks_in_range(destination_track_num, highest_track_num)

        -- Step 5: Collect items on the destination track before processing
        local items_on_destination_track = collect_items_on_lowest_track(all_items, destination_track_num)

        -- Combine the pre-collected items and any items that get moved
        local items_to_unselect = items_on_destination_track

        -- Step 10: Process each item in the sorted list
        process_items(all_items, destination_track_num, items_to_unselect)

        -- Unselect the items on the destination track and moved items
        unselect_items(items_to_unselect)

        -- Unselect the destination track at the end
        local destination_track = reaper.GetTrack(0, destination_track_num - 1)
        reaper.SetTrackSelected(destination_track, false)

        -- Ensure that the arrange view is updated
        reaper.UpdateArrange()
    end
end

-- Run the main function
reaper.Undo_BeginBlock()
main()
reaper.Undo_EndBlock("Process items and move to highest track within overlap threshold", -1)
