-- @version 1.0
-- @description SPLIT selected empty items at EDIT CURSOR along with text split prompt.
-- @author RESERVOIR AUDIO / MrBrock, with AI.

-- Get the number of selected items
num_selected = reaper.CountSelectedMediaItems(0)
if num_selected == 0 then
    reaper.ShowMessageBox("No items selected.", "Error", 0)
    return
end

-- Get the current edit cursor position
cursor_position = reaper.GetCursorPosition()

-- Initialize a counter for items intersected by the cursor
items_to_process = 0

-- Check each selected item to see if it intersects the edit cursor
for i = 0, num_selected - 1 do
    item = reaper.GetSelectedMediaItem(0, i)
    item_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    item_length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
    
    -- Check if the cursor intersects the item
    if cursor_position >= item_start and cursor_position < (item_start + item_length) then
        items_to_process = items_to_process + 1
    end
end

-- If no items intersect the cursor, exit
if items_to_process == 0 then
    reaper.ShowMessageBox("No selected items intersect the edit cursor.", "Error", 0)
    return
end

-- If more than one item remains, ask for confirmation
if items_to_process > 1 then
    confirmation = reaper.ShowMessageBox("You are about to run the script on " .. items_to_process .. " items. Do you want to proceed?", "Confirmation", 1)
    if confirmation ~= 1 then -- If the user pressed Cancel
        return
    end
end

-- Reset the count and process each intersecting item
for i = 0, num_selected - 1 do
    item = reaper.GetSelectedMediaItem(0, i)
    item_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    item_length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
    
    -- Check if the cursor intersects the item again for processing
    if cursor_position >= item_start and cursor_position < (item_start + item_length) then
        -- Get the notes from the selected item
        retval, notes = reaper.GetSetMediaItemInfo_String(item, "P_NOTES", "", false)
        
        -- Prompt the user for input with an extended width
        retval, user_input = reaper.GetUserInputs("Edit Item Notes", 1, "Enter new notes. Insert character "@" to indicate split point.",extrawidth=400", notes)
        
        -- Check if the user pressed Cancel
        if retval == false or user_input == "" then
            goto continue -- Skip this item and go to the next
        end

        -- Split the item at the cursor position
        reaper.SplitMediaItem(item, cursor_position)
        
        -- Get the two new items created by the split
        new_item_1 = reaper.GetSelectedMediaItem(0, 0)
        new_item_2 = reaper.GetSelectedMediaItem(0, 1)

        -- Split the text on the special character
        at_position = string.find(user_input, "@")
        if not at_position then
            reaper.ShowMessageBox("Special character '@' not found in the text.", "Error", 0)
            goto continue -- Skip this item and go to the next
        end

        -- Get text before and after the special character
        text_before = string.sub(user_input, 1, at_position - 1)
        text_after = string.sub(user_input, at_position + 1)

        -- Set the notes for the two new items
        reaper.GetSetMediaItemInfo_String(new_item_1, "P_NOTES", text_before, true)
        reaper.GetSetMediaItemInfo_String(new_item_2, "P_NOTES", text_after, true)
    end
    
    ::continue::
end

-- Update the arrange view to reflect changes
reaper.UpdateArrange()

