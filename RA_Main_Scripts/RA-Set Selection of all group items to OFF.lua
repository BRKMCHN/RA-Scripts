-- @version 1.0
-- @description Set linked selection of all group items to OFF
-- @author RESERVOIR AUDIO / MrBrock, with AI.

-- Disable the option to select entire group when selecting one grouped item in REAPER if it's currently enabled.

function DisableVerticalOverlapIfEnabled()
    local commandId = 41156 -- Command ID for the toggle action

    -- Check the current toggle state of the action (1 if on, 0 if off)
    local currentState = reaper.GetToggleCommandState(commandId)

    -- If the feature is currently enabled, toggle it off
    if currentState == 1 then
        reaper.Main_OnCommand(commandId, 0)
    end
end

DisableVerticalOverlapIfEnabled()
