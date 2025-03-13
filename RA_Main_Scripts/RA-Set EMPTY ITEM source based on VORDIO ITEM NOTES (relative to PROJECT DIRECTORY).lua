-- @description RA-Set EMPTY ITEM source based on VORDIO ITEM NOTES - From media folder relative to PROJECT DIRECTORY
-- @version 1.1
-- @author Reservoir Audio / Mr.Brock with AI

--Prompt: YES will append .wav if you have already transcoded compatible audio in Vordio. NO will fetch raw source, including video if name matches. Cancel aborts the script.

-- Function to log messages to the REAPER console
local function log(msg)
    reaper.ShowConsoleMsg(msg .. "\n")
end

-- Prompt for .wav extension choice
local response = reaper.MB("Append .wav to filenames?", "File Extension Choice", 3)
local append_wav = (response == 6)
if response == 2 then return end -- Cancel selected, abort script

-- Get the current project path
local project_path = reaper.GetProjectPath("")

-- Identify media folder from project settings
local media_folder = reaper.GetProjectPath("")
local project_name = reaper.GetProjectName(0, "")
local media_folder_path = media_folder  -- Use project path directly

-- Function to check if a file exists recursively in a directory and its subdirectories
local function findFileRecursively(directory, fileName)
    local idx = 0
    while true do
        local file = reaper.EnumerateFiles(directory, idx)
        if not file then break end
        if string.lower(file) == string.lower(fileName) then  -- Case insensitive match
            return directory .. "/" .. file
        end
        idx = idx + 1
    end
    -- Check subdirectories recursively
    idx = 0
    while true do
        local subdir = reaper.EnumerateSubdirectories(directory, idx)
        if not subdir then break end
        local foundPath = findFileRecursively(directory .. "/" .. subdir, fileName)
        if foundPath then return foundPath end
        idx = idx + 1
    end
    return nil
end

-- List to track missing files
local missing_files = {}

-- Process all selected media items
local count = reaper.CountSelectedMediaItems(0)
for i = 0, count - 1 do
    local item = reaper.GetSelectedMediaItem(0, i)
    if item then
        local take = reaper.GetActiveTake(item)
        if take then
            -- Get item notes and extract the filename and start offset from the CID
            local item_notes = reaper.ULT_GetMediaItemNote(item)
            local startInSource, filename = item_notes:match("CID:%d+%.%d+|(%d+%.%d+)|%d+%.%d+|(.+)")
            if filename and startInSource then
                -- Optionally append '.wav' to the filename
                local wavFilename = append_wav and (filename .. ".wav") or filename
                local filePath = findFileRecursively(media_folder_path, wavFilename)
                if filePath then
                    -- Set the source for the take from the found file path
                    reaper.BR_SetTakeSourceFromFile(take, filePath, true)

                    -- Convert startInSource to number and set the media source start (offset in seconds)
                    startInSource = tonumber(startInSource)
                    reaper.SetMediaItemTakeInfo_Value(take, "D_STARTOFFS", startInSource)
                else
                    -- Add to the list of missing files and do nothing else
                    table.insert(missing_files, wavFilename)
                end
            else
                log("Filename or StartInSource not found in item notes")
            end
        else
            log("Selected item has no take")
        end
    end
end

-- Update the arrangement and rebuild peaks
reaper.UpdateArrange()
reaper.Main_OnCommand(40441, 0)  -- Rebuild peaks for selected items

-- Report missing files
if #missing_files > 0 then
    log("The following files were not found:\n" .. table.concat(missing_files, "\n"))
end
