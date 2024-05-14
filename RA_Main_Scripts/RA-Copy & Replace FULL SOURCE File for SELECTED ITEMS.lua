-- @version 1.2
-- @description Copy & Replace FULL SOURCE File for SELECTED ITEMS
-- @author RESERVOIR AUDIO / MrBrock & AI

-- First, let's define the function to check unique source names
local function checkUniqueSourceNames()
  local sourceNames = {}
  local numItems = reaper.CountSelectedMediaItems(0)
  for i = 0, numItems - 1 do
      local item = reaper.GetSelectedMediaItem(0, i)
      local take = reaper.GetActiveTake(item)
      if take then
          local source = reaper.GetMediaItemTake_Source(take)
          local sourceName = reaper.GetMediaSourceFileName(source, "")
          sourceNames[sourceName] = true
      end
  end
  local count = 0
  for _ in pairs(sourceNames) do count = count + 1 end
  if count > 1 then
      local prompt = "You are about to apply processing to " .. count .. " different source files, do you wish to proceed?"
      local retval = reaper.ShowMessageBox(prompt, "Warning", 1)
      return retval == 1
  end
  return true
end

-- The main processing function
local function main()
  -- First check if multiple unique source files are involved
  if not checkUniqueSourceNames() then return end

  local processed_files = {}
  local item_count = reaper.CountSelectedMediaItems(0)

  if item_count == 0 then
    reaper.ShowMessageBox("No items selected", "Error", 0)
    return
  end

  reaper.Undo_BeginBlock()

  for i = 0, item_count - 1 do
    local item = reaper.GetSelectedMediaItem(0, i)
    local take = reaper.GetActiveTake(item)

    if take and not reaper.TakeIsMIDI(take) then
      local source = reaper.GetMediaItemTake_Source(take)
      local filepath = reaper.GetMediaSourceFileName(source, "")

      if not processed_files[filepath] then
        local path, filename, extension = filepath:match("(.-)([^\\/]-)%.([^%.\\/]+)$")
        local new_filename = path .. filename .. "_IZO." .. extension

        local rfile = io.open(filepath, "rb")
        if rfile then
          local content = rfile:read("*all")
          rfile:close()

          local wfile = io.open(new_filename, "wb")
          if wfile then
            wfile:write(content)
            wfile:close()
            processed_files[filepath] = new_filename
          else
            reaper.ShowMessageBox("Failed to write the copied file.", "Error", 0)
          end
        else
          reaper.ShowMessageBox("Failed to read the original file.", "Error", 0)
        end
      end

      local new_source = reaper.PCM_Source_CreateFromFile(processed_files[filepath])
      if new_source then
        reaper.SetMediaItemTake_Source(take, new_source)
        reaper.UpdateItemInProject(item)
      end
    else
      reaper.ShowMessageBox("Selected item is a MIDI item or no valid take found.", "Error", 0)
    end
  end

  reaper.Undo_EndBlock("Copy Source and Replace Media Item Takes", -1)
  reaper.UpdateArrange()
  reaper.Main_OnCommand(40441, 0)  -- Rebuild peaks for selected items
end

main()
