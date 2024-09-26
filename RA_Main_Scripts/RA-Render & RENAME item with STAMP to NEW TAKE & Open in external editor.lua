-- @version 1.0
-- @description Render & RENAME item with STAMP to NEW TAKE & Open in external editor
-- @author RESERVOIR AUDIO / MrBrock with AI

-- Function to sanitize the volume name: removes punctuation, special characters, and replaces spaces with underscores
local function sanitize_name(name)
    name = name:gsub("%s+", "_") -- Replace whitespace with underscores
    name = name:gsub("[^%w_]", "") -- Remove non-alphanumeric and non-underscore characters
    return name
end

-- Function to get the computer's name (hostname) and sanitize it
local function get_computer_name()
    local handle = io.popen("hostname")
    local computer_name = handle:read("*a"):gsub("%s+", "") -- Read and trim whitespace
    handle:close()
    -- Remove ".local" if present and sanitize the name
    computer_name = computer_name:gsub("%.local$", "")
    return sanitize_name(computer_name)
end

-- Function to get the volume name from the file path (specific to MacOS)
local function get_volume_name(file_path)
    local volume = file_path:match("^/Volumes/([^/]+)") -- Extracts the volume name between /Volumes/ and the next /
    return volume and sanitize_name(volume) or get_computer_name() -- Use hostname if no volume found
end

-- Function to get current timestamp in HHMMSS format
local function get_timestamp()
    local time = os.date("*t")
    return string.format("%02d%02d%02d", time.hour, time.min, time.sec)
end

-- Fetch active envelopes and pitch information from the take
local function fetch_take_data(take)
    local take_data = {}

    -- Fetch pitch adjustment
    take_data.pitch = reaper.GetMediaItemTakeInfo_Value(take, "D_PITCH")

    -- Fetch active envelopes (no need for envelope points)
    take_data.active_envelopes = {}
    local envelope_count = reaper.CountTakeEnvelopes(take)
    for i = 0, envelope_count - 1 do
        local envelope = reaper.GetTakeEnvelope(take, i)
        local _, active = reaper.GetEnvelopeInfo_Value(envelope, "D_ACTIVE")
        if active == 1 then
            table.insert(take_data.active_envelopes, envelope)
        end
    end

    return take_data
end

-- Duplicate the active take and return its index safely
local function duplicate_take(item)
    local active_take = reaper.GetActiveTake(item)
    if not active_take then
        reaper.ShowMessageBox("No active take found for the item", "Error", 0)
        return nil
    end

    -- Get the current active take index
    local active_take_index = reaper.GetMediaItemInfo_Value(item, "I_CURTAKE")

    -- Duplicate the active take
    reaper.Main_OnCommand(40639, 0) -- Take: Duplicate active take

    -- New take will be at active_take_index + 1
    local new_take_index = active_take_index + 1

    -- Set the new duplicated take as the active take
    reaper.SetMediaItemInfo_Value(item, "I_CURTAKE", new_take_index)

    -- Return the index of the new duplicated take
    return new_take_index
end

-- Reset pitch and deactivate envelopes
local function reset_take_and_envelopes(take, active_envelopes)
    -- Reset pitch
    reaper.SetMediaItemTakeInfo_Value(take, "D_PITCH", 0)

    -- Deactivate active envelopes using state chunk modification
    for i = 0, reaper.CountTakeEnvelopes(take) - 1 do
        local envelope = reaper.GetTakeEnvelope(take, i)
        local retval, chunk = reaper.GetEnvelopeStateChunk(envelope, "", false)
        if retval then
            chunk = chunk:gsub("ACT 1", "ACT 0") -- Set to inactive
            reaper.SetEnvelopeStateChunk(envelope, chunk, false)
        end
    end
    
end

-- Reactivate envelopes after rendering
local function reactivate_envelopes(take, active_envelopes)
    -- Reactivate envelopes using state chunk modification
    for i = 0, reaper.CountTakeEnvelopes(take) - 1 do
        local envelope = reaper.GetTakeEnvelope(take, i)
        local retval, chunk = reaper.GetEnvelopeStateChunk(envelope, "", false)
        if retval then
            chunk = chunk:gsub("ACT 0", "ACT 1") -- Set to active
            reaper.SetEnvelopeStateChunk(envelope, chunk, false)
        end
    end
    
end

-- Use the "render items to new take" action and rename the new take source based on original filepath
local function render_and_rename(item, original_filepath)
    -- Run render items to new take
    reaper.Main_OnCommand(40601, 0) -- Item: Render items to new take

    -- Get the new take (should be the last one in the item)
    local new_take = reaper.GetActiveTake(item)

    if new_take then
        -- Get the source path for the new take
        local new_source = reaper.GetMediaItemTake_Source(new_take)
        local new_filepath = reaper.GetMediaSourceFileName(new_source, "")

        -- Get timestamp and volume name using the original source filepath
        local timestamp = get_timestamp()
        local volume_name = get_volume_name(original_filepath)

        -- Extract the path, original filename, and extension
        local path, original_filename, extension = original_filepath:match("(.-)([^\\/]-)%.([^%.\\/]+)$")

        -- Check if the filename already contains "_<VolumeName>_<timestamp>_EDIT"
        local matched_volume, matched_timestamp = original_filename:match("_(.-)_(%d%d%d%d%d%d)_EDIT$")
        
        if matched_volume and matched_timestamp then
            -- If the matched volume name is the same as the current volume, just update the timestamp
            if matched_volume == volume_name then
                original_filename = original_filename:gsub("_(.-)_(%d%d%d%d%d%d)_EDIT$", "")
            else
                -- If the volume names don't match, remove the old volume and timestamp and start fresh
                original_filename = original_filename:gsub("_(.-)_(%d%d%d%d%d%d)_EDIT$", "")
            end
        end

        -- Create the new filename with the updated volume and new timestamp
        local new_filename = string.format("%s%s_%s_%s_EDIT.%s", path, original_filename, volume_name, timestamp, extension)

        -- Ensure the new filename is unique by checking for existing files
        local unique_filename = new_filename
        local counter = 1
        while reaper.file_exists(unique_filename) do
            -- Append or increment a counter to ensure uniqueness
            unique_filename = string.format("%s%s_%s_%s_EDIT_%d.%s", path, original_filename, volume_name, timestamp, counter, extension)
            counter = counter + 1
        end

        -- Rename the file (move) using the unique filename
        os.rename(new_filepath, unique_filename)

        -- Return the new file path and name
        return unique_filename
    else
        reaper.ShowConsoleMsg("Render failed: No new take created.\n")
    end
end




-- Replace the source of the take with the rendered file
local function replace_take_source(take, rendered_file)

    -- Replace the source of the take with the rendered file
    local new_source = reaper.PCM_Source_CreateFromFile(rendered_file)
    if new_source then
        reaper.SetMediaItemTake_Source(take, new_source)
    else
        reaper.ShowMessageBox("Failed to load rendered file.", "Error", 0)
    end
end

-- Function to subtract start offset from envelope points and reset offset
local function adjust_envelope_points_for_offset(take, active_envelopes)
    -- Get the start offset ("start in source") from the take properties
    local start_offset = reaper.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS")

    -- If there's no offset, there's nothing to adjust
    if start_offset == 0 then return end

    -- Adjust each active envelope point by subtracting the start offset
    for _, envelope in ipairs(active_envelopes) do
        local point_count = reaper.CountEnvelopePoints(envelope)
        for i = 0, point_count - 1 do
            local retval, time, value, shape, tension, selected = reaper.GetEnvelopePoint(envelope, i)
            reaper.SetEnvelopePoint(envelope, i, time - start_offset, value, shape, tension, selected, true)
        end
        reaper.Envelope_SortPoints(envelope) -- Sort points after adjusting them
    end

    -- Reset the start offset to zero (so the item behaves normally)
    reaper.SetMediaItemTakeInfo_Value(take, "D_STARTOFFS", 0)
end

-- Delete the rendered take
local function cleanup_and_open_editor(item, temp_take_index)
    -- Safely delete the currently active take (which is the rendered take)
    reaper.Main_OnCommand(40129, 0) -- Take: Delete active take (this will leave the duplicated take as active)

    
end

-- Helper function to save the selection state of all items
local function save_item_selection()
    local selected_items = {}
    local item_count = reaper.CountSelectedMediaItems(0)
    for i = 0, item_count - 1 do
        selected_items[i + 1] = reaper.GetSelectedMediaItem(0, i)
    end
    return selected_items
end

-- Helper function to restore the selection state of items
local function restore_item_selection(selected_items)
    reaper.Main_OnCommand(40289, 0) -- Unselect all items
    for _, item in ipairs(selected_items) do
        reaper.SetMediaItemSelected(item, true)
    end
end

-- Main function
local function main()
    local item_count = reaper.CountSelectedMediaItems(0)

    if item_count == 0 then
        reaper.ShowMessageBox("No items selected", "Error", 0)
        return
    end

    -- Save the current item selection
    local selected_items = save_item_selection()

    -- Unselect all items initially
    reaper.Main_OnCommand(40289, 0) -- Unselect all items

    reaper.Undo_BeginBlock()

    for i, item in ipairs(selected_items) do
        local original_take = reaper.GetActiveTake(item)

        if original_take and not reaper.TakeIsMIDI(original_take) then
            -- Step 1: Fetch pitch and active envelope data
            local take_data = fetch_take_data(original_take)

            -- Step 2: Select the current item
            reaper.SetMediaItemSelected(item, true)

            -- Step 3: Duplicate the active take and store its index
            local temp_take_index = duplicate_take(item)
            if temp_take_index then

                -- Step 4: Reset pitch and deactivate envelopes
                reset_take_and_envelopes(reaper.GetTake(item, temp_take_index), take_data.active_envelopes)

                -- Step 5: Render items to new take and rename it
                local source = reaper.GetMediaItemTake_Source(original_take)
                local filepath = reaper.GetMediaSourceFileName(source, "")
                local rendered_file = render_and_rename(item, filepath)

                -- Step 6: Delete the rendered take, leaving the duplicated take active
                cleanup_and_open_editor(item, temp_take_index)

                -- Step 7: Reactivate the previously active envelopes
                reactivate_envelopes(reaper.GetTake(item, temp_take_index), take_data.active_envelopes)

                -- Step 8: Replace the source of the duplicated take with the newly rendered file
                replace_take_source(reaper.GetTake(item, temp_take_index), rendered_file)

                -- Extract the filename from the full path
                local filename = rendered_file:match("([^\\/]+)$")
                
                -- Set the take name to the filename
                reaper.GetSetMediaItemTakeInfo_String(reaper.GetTake(item, temp_take_index), "P_NAME", filename, true)

                -- Step 9: Adjust the envelope points by subtracting the start offset and reset the offset
                adjust_envelope_points_for_offset(reaper.GetTake(item, temp_take_index), take_data.active_envelopes)

                -- Step 10: Unselect the current item before moving to the next
                reaper.SetMediaItemSelected(item, false)
            end
        end
    end

    -- Restore the original item selection
    restore_item_selection(selected_items)

    -- Open all items in external editor (only once, after all items are processed)
    reaper.Main_OnCommand(40109, 0) -- Open items in external editor

    reaper.Undo_EndBlock("Duplicate, Render and Edit in External Editor", -1)
end

-- Call the main function to execute the script
main()

