-- @version 1.1
-- @description Toggle Item Snap Mode
-- @author RESERVOIR AUDIO / MrBrock + AI

-- Toggle Snap/Grid setting:
-- Media items snap at: "Only snap at start/snap offset" <-> "Snap both start/end"
--
-- Requires SWS extension.

local VAR_NAME = "projshowgrid"

local BIT_START_ONLY = 2048
local BIT_BOTH_ENDS  = 4096

local function has_bit(value, bit)
    return value & bit ~= 0
end

local function remove_bit(value, bit)
    if has_bit(value, bit) then
        return value - bit
    end
    return value
end

if not reaper.SNM_GetIntConfigVar or not reaper.SNM_SetIntConfigVar then
    reaper.ShowMessageBox(
        "This script requires the SWS extension.",
        "Missing SWS",
        0
    )
    return
end

local current = reaper.SNM_GetIntConfigVar(VAR_NAME, -999999)

if current == -999999 then
    reaper.ShowMessageBox(
        "Could not read REAPER snap/grid setting: " .. VAR_NAME,
        "Error",
        0
    )
    return
end

local currently_both = has_bit(current, BIT_BOTH_ENDS)

-- Clear both dropdown bits first.
local new_value = current
new_value = remove_bit(new_value, BIT_START_ONLY)
new_value = remove_bit(new_value, BIT_BOTH_ENDS)

if currently_both then
    -- Switch to: Only snap at start/snap offset
    new_value = new_value + BIT_START_ONLY
else
    -- Switch to: Snap both start/end
    new_value = new_value + BIT_BOTH_ENDS
end

reaper.SNM_SetIntConfigVar(VAR_NAME, new_value)

local _, _, section_id, command_id = reaper.get_action_context()

-- Button lit when mode is "both start/end"
local toggle_state = currently_both and 0 or 1

reaper.SetToggleCommandState(section_id, command_id, toggle_state)
reaper.RefreshToolbar2(section_id, command_id)

reaper.UpdateTimeline()
reaper.UpdateArrange()