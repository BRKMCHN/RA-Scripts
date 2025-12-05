-- @version 3.0
-- @description Copy & Replace FULL SOURCE File for SELECTED ITEMS
-- @author RESERVOIR AUDIO / MrBrock & AI

-- Version 3.0 appends a special visual character to take name for visual reminder. 
-- It also appends a specific tagged line to item notes for original file path (relative to project directory) for a restore script.

-- First, define the function to check unique source names
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

-- Function to get current timestamp in HHMMSS format
local function get_timestamp()
    local time = os.date("*t")
    return string.format("%02d%02d%02d", time.hour, time.min, time.sec)
end

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

-- Helper: split notes into lines
local function split_lines(text)
    local lines = {}
    if text == nil or text == "" then return lines end
    for line in (text .. "\n"):gmatch("([^\n]*)\n") do
        table.insert(lines, line)
    end
    return lines
end

-- Get path of current project
local function get_project_path()
    -- Returns the current project directory (no trailing slash usually)
    local proj_path = reaper.GetProjectPath("") or ""
    return proj_path
end

-- Get file path relative to project directory (if possible)
local function get_relative_to_project(fullpath, proj_path)
    if not fullpath or fullpath == "" then return "" end
    if not proj_path or proj_path == "" then return fullpath end

    -- Normalize slashes
    local path_norm = fullpath:gsub("\\", "/")
    local proj_norm = proj_path:gsub("\\", "/")

    -- Ensure project path ends with a slash
    if proj_norm:sub(-1) ~= "/" then
        proj_norm = proj_norm .. "/"
    end

    -- Case-insensitive compare on Windows; on macOS this is usually fine too
    if path_norm:sub(1, #proj_norm):lower() == proj_norm:lower() then
        -- Return relative part (subfolders + filename.ext)
        return path_norm:sub(#proj_norm + 1)
    else
        -- Fallback: store full path
        return fullpath
    end
end

-- Write or update RA_OFP line in item notes
local function write_RA_OFP(item, value)
    if not item or not value or value == "" then return end

    local _, notes = reaper.GetSetMediaItemInfo_String(item, "P_NOTES", "", false)
    local lines = split_lines(notes)
    local tag_prefix = "RA_OFP:"
    local found = false

    for i, line in ipairs(lines) do
        if line:match("^" .. tag_prefix) then
            lines[i] = tag_prefix .. " " .. value
            found = true
        end
    end

    if not found then
        table.insert(lines, tag_prefix .. " " .. value)
    end

    local new_notes = table.concat(lines, "\n")
    reaper.GetSetMediaItemInfo_String(item, "P_NOTES", new_notes, true)
end

-- Append 🔽 to take name (if not already present)
local function tag_take_name_with_arrow(take)
    if not take then return end
    local _, name = reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
    if not name then name = "" end

    if not name:find("🔽", 1, true) then
        local new_name
        if name == "" then
            new_name = "🔽"
        else
            new_name = name .. " 🔽"
        end
        reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", new_name, true)
    end
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

    local proj_path = get_project_path()

    reaper.Undo_BeginBlock()
    reaper.PreventUIRefresh(1)

    for i = 0, item_count - 1 do
        local item = reaper.GetSelectedMediaItem(0, i)
        local take = reaper.GetActiveTake(item)

        if take and not reaper.TakeIsMIDI(take) then
            local source = reaper.GetMediaItemTake_Source(take)
            local filepath = reaper.GetMediaSourceFileName(source, "")

            -- Write RA_OFP (original file path, relative to project if possible)
            local relative_path = get_relative_to_project(filepath, proj_path)
            write_RA_OFP(item, relative_path)

            if not processed_files[filepath] then
                local path, filename, extension = filepath:match("(.-)([^\\/]-)%.([^%.\\/]+)$")
                
                -- Get timestamp and volume name
                local timestamp = get_timestamp()
                local volume_name = get_volume_name(filepath)
                
                -- Construct the new filename with volume name, timestamp, and "_EDIT"
                local new_filename = string.format("%s%s_%s_%s_EDIT.%s", path, filename, volume_name, timestamp, extension)

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
                -- Tag the take name with 🔽 to indicate edited/duplicated source
                tag_take_name_with_arrow(take)
                reaper.UpdateItemInProject(item)
            end
        else
            reaper.ShowMessageBox("Selected item is a MIDI item or no valid take found.", "Error", 0)
        end
    end

    reaper.PreventUIRefresh(-1)
    reaper.Undo_EndBlock("Copy Source, Replace Takes, Tag RA_OFP and 🔽", -1)
    reaper.UpdateArrange()
    reaper.Main_OnCommand(40441, 0)  -- Rebuild peaks for selected items
end

main()

