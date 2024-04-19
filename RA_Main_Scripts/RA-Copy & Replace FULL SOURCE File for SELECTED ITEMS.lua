-- @version 1.0
-- @description Copy & Replace FULL SOURCE File for SELECTED ITEMS
-- @author RESERVOIR AUDIO / MrBrock & AI

-- Initialize a table to track processed source files and their new file names
local processed_files = {}

-- Get the number of selected media items
local item_count = reaper.CountSelectedMediaItems(0)

if item_count == 0 then
  reaper.ShowMessageBox("No items selected", "Error", 0)
  return
end

-- Start the undo block
reaper.Undo_BeginBlock()

for i = 0, item_count - 1 do
  -- Get the selected media item at index 'i'
  local item = reaper.GetSelectedMediaItem(0, i)
  -- Get the active take in the media item; this is the take that is currently being used or edited
  local take = reaper.GetActiveTake(item)

  if take and not reaper.TakeIsMIDI(take) then
    -- Get the source of the active take; the source is the actual audio file associated with this take
    local source = reaper.GetMediaItemTake_Source(take)
    -- Get the file path of the source, which is the location of the audio file on your disk
    local filepath = reaper.GetMediaSourceFileName(source, "")

    -- Check if the source file has been processed
    if not processed_files[filepath] then
      -- Generate the new file path with the "_IZO" suffix
      local path, filename = filepath:match("(.-)([^\\/]-%.?([^%.\\/]*))$")
      local new_filename = path .. filename:gsub("%.", "_IZO.")

      -- Copy the file to the new location using Lua file operations
      local rfile = io.open(filepath, "rb")
      if rfile then
        local content = rfile:read("*all")
        rfile:close()
        
        local wfile = io.open(new_filename, "wb")
        if wfile then
          wfile:write(content)
          wfile:close()
          processed_files[filepath] = new_filename  -- Store new filename in the table to avoid reprocessing
        else
          reaper.ShowMessageBox("Failed to write the copied file.", "Error", 0)
        end
      else
        reaper.ShowMessageBox("Failed to read the original file.", "Error", 0)
      end
    end
    
    -- Update the take to use the new source file
    local new_source = reaper.PCM_Source_CreateFromFile(processed_files[filepath])
    if new_source then
      reaper.SetMediaItemTake_Source(take, new_source)
      reaper.UpdateItemInProject(item)
    end
  else
    reaper.ShowMessageBox("Selected item is a MIDI item or no valid take found.", "Error", 0)
  end
end

-- End the undo block and commit the changes
reaper.Undo_EndBlock("Copy Source and Replace Media Item Takes", -1)

-- Update the arrangement view and rebuild peaks
reaper.UpdateArrange()
reaper.Main_OnCommand(40441, 0)  -- Command ID for 'Rebuild peaks for selected items'

