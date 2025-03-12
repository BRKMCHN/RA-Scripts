-- @description SELECT ITEMS WITH SAME SOURCE AS FIRST SELECTED ITEM -- WITHIN TIME SELECTION
-- @version 1.0
-- @author Reservoir Audio / Amel with AI -- adapted from X-Raym's script (https://github.com/X-Raym/REAPER-EEL-Scripts)



function Msg(variable)
  reaper.ShowConsoleMsg(tostring(variable) .. "\n")
end

function GetTakeFileSource(take)
  local source = reaper.GetMediaItemTake_Source(take)
  if not source then return false end
  local source_type = reaper.GetMediaSourceType(source, '')
  if source_type == 'SECTION' then
    source = reaper.GetMediaSourceParent(source)
  end
  return source
end

function main() -- local (i, j, item, take, track)

  first_item = reaper.GetSelectedMediaItem(0, 0)
  
  if first_item ~= nil then
    
    reaper.Undo_BeginBlock() -- Beginning of the undo block.
    
    first_take = reaper.GetActiveTake(first_item)
    
    if first_take then
      
      if reaper.TakeIsMIDI(first_take) == false then
      
        first_take_source = GetTakeFileSource(first_take)
        if first_take_source then
          first_take_source_name = reaper.GetMediaSourceFileName(first_take_source, "")
          
          -- Get time selection start and end
          local time_sel_start, time_sel_end = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)

          items_count = reaper.CountMediaItems(0)

          for i = 0, items_count - 1 do
            -- GET ITEMS
            item = reaper.GetMediaItem(0, i) -- Get item i

            -- Get item position and length
            local item_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
            local item_end = item_pos + reaper.GetMediaItemInfo_Value(item, "D_LENGTH")

            -- Check if item is within time selection
            if item_end > time_sel_start and item_pos < time_sel_end then
            
              take = reaper.GetActiveTake(item) -- Get the active take

              if take ~= nil then -- if ==, it will work on "empty"/text items only
                
                if reaper.TakeIsMIDI(take) == false then
                  
                  take_source = GetTakeFileSource(take)
                  if take_source then
                    take_source_name = reaper.GetMediaSourceFileName(take_source, "")
                    
                    if take_source_name == first_take_source_name then
                      
                      reaper.SetMediaItemSelected(item, true)
                      
                    else
                    
                      reaper.SetMediaItemSelected(item, false)
                    
                    end
                  
                  end
                
                end
              
              end -- ENDIF active take
            else
              reaper.SetMediaItemSelected(item, false) -- Deselect items outside time selection
            end
            
          end -- ENDLOOP through items
          
        end

      else -- else item take midi
      
        reaper.Main_OnCommand(41611, 0)
        
      end -- if audio or midi
    
    end -- take selection
    
    reaper.Undo_EndBlock("Select items with same source as first selected item within time selection", -1) -- End of the undo block.

  end
    
end

reaper.PreventUIRefresh(1) -- Prevent UI refreshing.

main() -- Execute your main function

reaper.UpdateArrange() -- Update the arrangement

reaper.PreventUIRefresh(-1)  -- Restore UI Refresh.

