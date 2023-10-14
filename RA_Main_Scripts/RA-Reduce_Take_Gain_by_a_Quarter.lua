-- @version 1.0
-- @description This script will check the value for take gain and reduce it by 25%.
-- @author MrBrock & AI

-- Start the Undo block
reaper.Undo_BeginBlock()

-- Convert a multiplier to dB
function lin2dB(val)
    return 20 * math.log(val, 10)
end

-- Convert dB to a multiplier
function dB2lin(dB_val)
    return 10^(dB_val / 20)
end

-- Loop through all selected items
local numSelectedItems = reaper.CountSelectedMediaItems(0)
for i = 0, numSelectedItems-1 do
    local item = reaper.GetSelectedMediaItem(0, i)
    if item then
        local take = reaper.GetActiveTake(item)
        if take then
            -- Fetch the current gain value of the take (multiplier)
            local currentGain = reaper.GetMediaItemTakeInfo_Value(take, "D_VOL")
            -- Convert the current multiplier to dB
            local currentGain_dB = lin2dB(currentGain)
            
            -- Simply decrease the dB gain by multiplying with 0.75
            currentGain_dB = currentGain_dB * 0.75
            
            -- Convert the adjusted dB value back to multiplier
            local adjustedGain = dB2lin(currentGain_dB)
            
            -- Set the adjusted gain to the take
            reaper.SetMediaItemTakeInfo_Value(take, "D_VOL", adjustedGain)
        end
    end
end

-- Update arrange view and redraw
reaper.UpdateArrange()

-- End the Undo block
reaper.Undo_EndBlock("Reduce take gain by 75%", -1)

