-- @version 1.0
-- @description KEEP SELECTION OF ITEMS with only 1 channel, unselect the rest.
-- @author RESERVOIR AUDIO / MrBrock. Adapted from a script by X-raym, with AI. Original script prompted for user imput.
-- 
--

function main(output) -- local (i, j, item, take, track)
  
  -- Set the predetermined number of channels (1 channel in this case)
  output = 1
  
  reaper.Undo_BeginBlock() -- Begining of the undo block. Leave it at the top of your main function.

  -- GET SELECTED NOTES (from 0 index)
  for i = 0, count_sel_items-1 do

    item = reaper.GetSelectedMediaItem(0, count_sel_items-1-i)
    take = reaper.GetActiveTake(item)

    if take ~= nil then

      if reaper.TakeIsMIDI(take) == false then

        take_pcm = reaper.GetMediaItemTake_Source(take)
      
        take_pcm_chan = reaper.GetMediaSourceNumChannels(take_pcm)
        take_chan_mod = reaper.GetMediaItemTakeInfo_Value(take, "I_CHANMODE")
        
        select = 0
        
        if output == 1 and ((take_chan_mod > 1 and take_chan_mod < 67) or take_pcm_chan == 1) then
          select = 1
        end
        
        if output == 2 and (take_chan_mod > 66 or (take_chan_mod <= 1 and take_pcm_chan == output)) then
          select = 1
        end
        
        if output > 1 and take_chan_mod <= 1 and take_pcm_chan == output then
          select = 1
        end
        
        if select == 0 then reaper.SetMediaItemSelected(item, false) end
      
      else
        reaper.SetMediaItemSelected(item, false)
      end
      
    else
      reaper.SetMediaItemSelected(item, false)
    end
      
  end

  reaper.Undo_EndBlock("Keep selected items with X channels only", -1) -- End of the undo block. Leave it at the bottom of your main function.

end

count_sel_items = reaper.CountSelectedMediaItems(0)

reaper.PreventUIRefresh(1)

main() -- Execute your main function with the predetermined number of channels

reaper.UpdateArrange() -- Update the arrangement (often needed)

reaper.PreventUIRefresh(-1)

