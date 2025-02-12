-- @version 1.0
-- @description REPORT Project info to TXT file with parameter value
-- @author MrBrock Edit from Reapack script "edgemeal_Save project plugin info to text file.lua" & AI

-- Adds a unique FX string (to avoid duplicates in media items)
function Add_TakeFX(fx_names, name)
  for i = 1, #fx_names do
    if fx_names[i] == name then return end
  end
  fx_names[#fx_names+1] = name
end

-- Removes the file extension from a filename.
local function RemoveFileExt(file)
  local index = (file:reverse()):find("%.") or 0
  if index > 0 then
    return string.sub(file, 1, #file-index)
  else
    return file
  end
end

-- Creates a one-line summary for an FX, adding symbols for disabled (*)
-- and offline (#) states, plus the preset name if available.
function Status(fx_name, preset_name, enabled, offline)
  local s = (enabled and "" or "*") .. (offline and "#" or "")
  s = s .. ((s ~= "") and " " .. fx_name or fx_name)
  s = s .. ((preset_name ~= "") and " <> Preset: " .. preset_name or "")
  t[#t+1] = s
end

-- Lists all FX on a given track, along with their parameter names and formatted values.
-- Also lists any track sends with their volume values.
function AddFX(track, fx_count)
  for fx = 0, fx_count-1 do
    local retval, fx_name = reaper.TrackFX_GetFXName(track, fx, "")
    local retval2, preset_name = reaper.TrackFX_GetPreset(track, fx, "")
    local enabled = reaper.TrackFX_GetEnabled(track, fx)
    local offline = reaper.TrackFX_GetOffline(track, fx)
    Status(fx_name, preset_name, enabled, offline)
    
    local paramCount = reaper.TrackFX_GetNumParams(track, fx)
    for paramIndex = 0, paramCount-1 do
      local retval3, paramValStr = reaper.TrackFX_GetFormattedParamValue(track, fx, paramIndex, "")
      local retval4, paramName = reaper.TrackFX_GetParamName(track, fx, paramIndex, "")
      if retval3 and retval4 then
        t[#t+1] = string.format("    %s: %s", paramName, paramValStr)
      end
    end
  end
  
  local send_cnt = reaper.GetTrackNumSends(track, 0)
  if send_cnt > 0 then
    local s = 'Track Sends(' .. tostring(send_cnt) .. '): '
    for send_index = 0, send_cnt - 1 do
      local retval, send_name = reaper.GetTrackSendName(track, send_index, '')
      local vol = reaper.GetTrackSendInfo_Value(track, 0, send_index, "D_VOL")
      s = s .. string.format("%s (vol: %.2f)", send_name, vol) .. ((send_index < send_cnt - 1) and ', ' or '')
    end
    t[#t+1] = s
  end
end

-- Lists all FX used in media items on the track (take FX), along with their parameters.
function AddItemFX(track, track_name)
  local itemcount = reaper.CountTrackMediaItems(track)
  if itemcount > 0 then
    local fx_used = {}
    for j = 0, itemcount-1 do
      local item = reaper.GetTrackMediaItem(track, j)
      local take = reaper.GetActiveTake(item)
      if take then
        local fx_count = reaper.TakeFX_GetCount(take)
        for fx = 0, fx_count-1 do
          local retval, fx_name = reaper.TakeFX_GetFXName(take, fx, "")
          local fxText = fx_name
          local paramCount = reaper.TakeFX_GetNumParams(take, fx)
          for paramIndex = 0, paramCount-1 do
            local retval3, paramValStr = reaper.TakeFX_GetFormattedParamValue(take, fx, paramIndex, "")
            local retval4, paramName = reaper.TakeFX_GetParamName(take, fx, paramIndex, "")
            if retval3 and retval4 then
              fxText = fxText .. "\n    " .. paramName .. ": " .. paramValStr
            end
          end
          Add_TakeFX(fx_used, fxText)
        end
      end
    end
    if #fx_used > 0 then
      local tn = track_name .. ' - Media Items FX\n'
      t[#t+1] = tn .. string.rep('-', #tn-1)
      t[#t+1] = table.concat(fx_used, "\n")
      t[#t+1] = ""
    end
  end
end

-- Lists FX in the FX monitoring chain on the master track.
function AddFxMonitor()
  local track = reaper.GetMasterTrack(0)
  local cnt = reaper.TrackFX_GetRecCount(track)
  if cnt > 0 then
    local tn = "FX Monitoring\n"
    t[#t+1] = tn .. string.rep('-', #tn-1)
    for i = 0, cnt-1 do
      local fx = (0x1000000 + i) -- Adjust for FX monitoring indexing.
      local retval, fx_name = reaper.TrackFX_GetFXName(track, fx, "")
      local retval2, preset_name = reaper.TrackFX_GetPreset(track, fx, "")
      local enabled = reaper.TrackFX_GetEnabled(track, fx)
      local offline = reaper.TrackFX_GetOffline(track, fx)
      Status(fx_name, preset_name, enabled, offline)
      
      local paramCount = reaper.TrackFX_GetNumParams(track, fx)
      for paramIndex = 0, paramCount-1 do
        local retval3, paramValStr = reaper.TrackFX_GetFormattedParamValue(track, fx, paramIndex, "")
        local retval4, paramName = reaper.TrackFX_GetParamName(track, fx, paramIndex, "")
        if retval3 and retval4 then
          t[#t+1] = string.format("    %s: %s", paramName, paramValStr)
        end
      end
    end
    t[#t+1] = ""
  end
end

-- Reads the first line of a file (used here to extract a project timestamp).
function Get_Line1(filename)
  local file = io.open(filename, "r")
  local line = file and file:read("*line") or ""
  if file then file:close() end
  return line
end

-- Main function: gathers project info, track FX (including take FX and sends),
-- and writes the collected information to a text file.
function Main()
  local proj, projfn = reaper.EnumProjects(-1, "")  -- Correctly retrieve both project pointer and filename.
  if projfn ~= "" then
    t[#t+1] = "Project: " .. reaper.GetProjectName(proj, "")
    t[#t+1] = "Path: " .. reaper.GetProjectPath("")
    local line = Get_Line1(projfn)
    if line then
      local timestamp = line:match(".* (.*)")
      if timestamp then
        t[#t+1] = 'Date: ' .. os.date("%B %d, %Y  %X", tonumber(timestamp))
      end
    end
    t[#t+1] = 'Length: ' .. reaper.format_timestr(reaper.GetProjectLength(proj), "")
  else
    t[#t+1] = "Unknown project (not saved)"
  end
  
  local dateStr = t[3] or ""
  if #dateStr > 0 then t[#t+1] = string.rep('-', #dateStr+1) end
  t[#t+1] = '* = Plugin disabled'
  t[#t+1] = '# = Plugin offline'
  if #dateStr > 0 then t[#t+1] = string.rep('-', #dateStr+1) end
  t[#t+1] = ""
  
  -- Process FX in the monitoring chain.
  AddFxMonitor()
  
  -- Process Master Track FX.
  local masterTrack = reaper.GetMasterTrack(0)
  local fx_count = reaper.TrackFX_GetCount(masterTrack)
  if fx_count > 0 then
    local tn = "Master Track\n"
    t[#t+1] = tn .. string.rep('-', #tn-1)
    AddFX(masterTrack, fx_count)
    t[#t+1] = ""
  end
  
  -- Process all regular tracks.
  local track_count = reaper.CountTracks(0)
  for i = 0, track_count-1 do
    local track = reaper.GetTrack(0, i)
    local retval, track_name = reaper.GetSetMediaTrackInfo_String(track, 'P_NAME', '', false)
    local tn = 'Track ' .. tostring(i+1) .. ': ' .. track_name .. '\n'
    t[#t+1] = tn .. string.rep('-', #tn-1)
    AddFX(track, reaper.TrackFX_GetCount(track))
    t[#t+1] = ""
    AddItemFX(track, string.sub(tn, 1, #tn-1))
  end

  -- Save the collected info to a text file in the project folder.
  if projfn ~= "" then
    local fn = RemoveFileExt(projfn) .. " - Project Plugins.txt"
    local file = io.open(fn, "w")
    file:write(table.concat(t, "\n"))
    file:close()
  else
    reaper.ClearConsole()
    reaper.ShowConsoleMsg(table.concat(t, "\n"))
  end
end

t = {}  -- Table to store the output text.
Main()

