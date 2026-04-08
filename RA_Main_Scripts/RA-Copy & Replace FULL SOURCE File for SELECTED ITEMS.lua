-- @version 3.1
-- @description Copy & Replace FULL SOURCE File for SELECTED ITEMS
-- @author RESERVOIR AUDIO / MrBrock & AI

-- Version 3.0 appends a special visual character to take name for visual reminder. 
-- It also appends a specific tagged line to item notes for original file path (relative to project directory) for a restore script.

-- Version 3.1:
-- Copies new files to the project's media/source directory instead of the original source folder
-- Adds collision-safe incrementing filenames

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
    name = name:gsub("%s+", "_")
    name = name:gsub("[^%w_]", "")
    return name
end

-- Function to get the computer's name (hostname) and sanitize it
local function get_computer_name()
    local handle = io.popen("hostname")
    if not handle then return "HOST" end
    local computer_name = handle:read("*a") or "HOST"
    handle:close()
    computer_name = computer_name:gsub("%s+", "")
    computer_name = computer_name:gsub("%.local$", "")
    return sanitize_name(computer_name)
end

-- Function to get the volume name from the file path (specific to MacOS)
local function get_volume_name(file_path)
    local volume = file_path:match("^/Volumes/([^/]+)")
    return volume and sanitize_name(volume) or get_computer_name()
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
    local proj_path = reaper.GetProjectPath("") or ""
    return proj_path
end

-- Get project's effective media/source directory
local function get_project_media_dir()
    local _, projfn = reaper.EnumProjects(-1, "")
    projfn = projfn or ""

    local media_path = reaper.GetProjectPathEx(0, "", 512)

    if media_path and media_path ~= "" then
        return media_path
    end

    return projfn:match("^(.*)[/\\][^/\\]+$") or reaper.GetProjectPath("") or ""
end

-- Get file path relative to project directory (if possible)
local function get_relative_to_project(fullpath, proj_path)
    if not fullpath or fullpath == "" then return "" end
    if not proj_path or proj_path == "" then return fullpath end

    local path_norm = fullpath:gsub("\\", "/")
    local proj_norm = proj_path:gsub("\\", "/")

    if proj_norm:sub(-1) ~= "/" then
        proj_norm = proj_norm .. "/"
    end

    if path_norm:sub(1, #proj_norm):lower() == proj_norm:lower() then
        return path_norm:sub(#proj_norm + 1)
    else
        return fullpath
    end
end

-- File/path helpers
local function file_exists(path)
    local f = io.open(path, "rb")
    if f then
        f:close()
        return true
    end
    return false
end

local function join_path(dir, name)
    if dir == "" then return name end
    local sep = (dir:sub(-1) == "/" or dir:sub(-1) == "\\") and "" or "/"
    return dir .. sep .. name
end

local function unique_path(dir, filename)
    local candidate = join_path(dir, filename)
    if not file_exists(candidate) then return candidate end

    local stem, ext = filename:match("^(.*)%.([^%.]+)$")
    if not stem then
        local i = 2
        while true do
            local cand = join_path(dir, filename .. i)
            if not file_exists(cand) then return cand end
            i = i + 1
        end
    end

    local i = 2
    while true do
        local cand = join_path(dir, string.format("%s%d.%s", stem, i, ext))
        if not file_exists(cand) then return cand end
        i = i + 1
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

-- Append visual marker to take name (if not already present)
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

-- Build collision-safe destination path in project media dir
local function build_output_path(filepath)
    local _, filename, extension = filepath:match("(.-)([^\\/]-)%.([^%.\\/]+)$")
    if not filename or filename == "" then
        return nil
    end

    local out_dir = get_project_media_dir()
    if out_dir == "" then
        out_dir = get_project_path()
    end

    local timestamp = get_timestamp()
    local volume_name = get_volume_name(filepath)

    local new_basename = string.format(
        "%s_%s_%s_EDIT.%s",
        filename,
        volume_name,
        timestamp,
        extension
    )

    return unique_path(out_dir, new_basename)
end

-- The main processing function
local function main()
    if not checkUniqueSourceNames() then return end

    local processed_files = {}
    local item_count = reaper.CountSelectedMediaItems(0)

    if item_count == 0 then
        reaper.ShowMessageBox("No items selected", "Error", 0)
        return
    end

    local proj_path = get_project_path()
    local media_dir = get_project_media_dir()
    if media_dir ~= "" then
        reaper.RecursiveCreateDirectory(media_dir, 0)
    end

    reaper.Undo_BeginBlock()
    reaper.PreventUIRefresh(1)

    for i = 0, item_count - 1 do
        local item = reaper.GetSelectedMediaItem(0, i)
        local take = reaper.GetActiveTake(item)

        if take and not reaper.TakeIsMIDI(take) then
            local source = reaper.GetMediaItemTake_Source(take)
            local filepath = reaper.GetMediaSourceFileName(source, "")

            local relative_path = get_relative_to_project(filepath, proj_path)
            write_RA_OFP(item, relative_path)

            if not processed_files[filepath] then
                local new_filename = build_output_path(filepath)

                if not new_filename then
                    reaper.ShowMessageBox("Failed to build destination path.", "Error", 0)
                else
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
            end

            local new_path = processed_files[filepath]
            if new_path then
                local new_source = reaper.PCM_Source_CreateFromFile(new_path)
                if new_source then
                    reaper.SetMediaItemTake_Source(take, new_source)
                    tag_take_name_with_arrow(take)
                    reaper.UpdateItemInProject(item)
                end
            end
        else
            reaper.ShowMessageBox("Selected item is a MIDI item or no valid take found.", "Error", 0)
        end
    end

    reaper.PreventUIRefresh(-1)
    reaper.Undo_EndBlock("Copy Source, Replace Takes, Tag RA_OFP and 🔽", -1)
    reaper.UpdateArrange()
    reaper.Main_OnCommand(40441, 0)
end

main()