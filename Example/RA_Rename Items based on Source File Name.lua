--[[
@author Thonex
@description This script renames the active take of an audio item based on the file name of the source file.
--]]

function RENAME_SELECTED_ITEMS_TO_SOURCE ()

    local num_sel =  reaper.CountSelectedMediaItems( 0 )
    
    for i = 0, num_sel - 1 do
        local item =  reaper.GetSelectedMediaItem(0, i )
        local take =  reaper.GetActiveTake( item )
        local source =  reaper.GetMediaItemTake_Source( take )
        filenamebuf = reaper.GetMediaSourceFileName( source, "WAVE" )
        
        local filename = filenamebuf:gsub(".*/", "")
        reaper.GetSetMediaItemTakeInfo_String( take, "P_NAME", filename, 1 )
    
    end

end

RENAME_SELECTED_ITEMS_TO_SOURCE ()
