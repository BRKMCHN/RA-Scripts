-- @version 1.0
-- @description RENAME the active take of a SELECTED audio item, based on the name of the SOURCE file. (It works with sections or reversed sources)
-- @author RESERVOIR AUDIO / Frankfante. Assembled with original scripts by Thonex, nofish and spk77
--]]

function RENAME_SELECTED_ITEMS_TO_PARENT_SOURCE ()

  local num_sel =  reaper.CountSelectedMediaItems( 0 )
    
  for i = 0, num_sel - 1 do
    
     local item = reaper.GetSelectedMediaItem(0, i)
     local take = reaper.GetActiveTake(item)
     local src = reaper.GetMediaItemTake_Source(take)
     local src_parent = reaper.GetMediaSourceParent(src)

      if src_parent ~= nil then
       sr = reaper.GetMediaSourceSampleRate(src_parent)
       full_path = reaper.GetMediaSourceFileName(src_parent, "")
      else
       sr = reaper.GetMediaSourceSampleRate(src)
       full_path = reaper.GetMediaSourceFileName(src, "")
      end
      
     local filename = full_path:gsub(".*/", "")
     reaper.GetSetMediaItemTakeInfo_String( take, "P_NAME", filename, 1 )
     
   end
   
end
    
RENAME_SELECTED_ITEMS_TO_PARENT_SOURCE ()
