-- @version 1.0
-- @description Swap the item gain with take gain.
-- @author MrBrock with advAIsor
-- 
--

-- Function to swap item volume and take volume
function swapItemAndTakeVolume(item)
    -- Get the item properties
    local take = reaper.GetActiveTake(item)
    if take ~= nil then
        local itemVolume = reaper.GetMediaItemInfo_Value(item, "D_VOL")
        local takeVolume = reaper.GetMediaItemTakeInfo_Value(take, "D_VOL")
        
        -- Swap the volume values
        reaper.SetMediaItemInfo_Value(item, "D_VOL", takeVolume)
        reaper.SetMediaItemTakeInfo_Value(take, "D_VOL", itemVolume)
    end
end

-- Main function
function main()
    -- Check if any items are selected
    local itemCount = reaper.CountSelectedMediaItems(0)
    if itemCount == 0 then
        reaper.ShowMessageBox("Please select at least one item.", "Script Error", 0)
        return
    end

    -- Iterate through selected items and swap volumes
    for i = 0, itemCount - 1 do
        local item = reaper.GetSelectedMediaItem(0, i)
        swapItemAndTakeVolume(item)
    end

    -- Update the arrange view
    reaper.UpdateArrange()
end

-- Run the main function
main()

