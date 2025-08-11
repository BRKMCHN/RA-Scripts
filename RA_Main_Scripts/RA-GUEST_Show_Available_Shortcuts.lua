-- @version 1.1
-- @description Show available shortcuts.
-- @author Eric Tetz - see "https://github.com/EricTetz/reaper" updated with AI
-- @about Prints a list of available shortcuts to use in action list.

--[[
  Show all shortcut combinations that aren't currently in use.
  * The full set of permutations of modifiers+keys is too many (~2000) to show in Reaper's console window,
    so by default, key combinations using the Windows key are left out. You can uncomment that line to put them back in.
  * This may be worthless on a Mac.
  * The set of keys and the names Reaper uses for them (HorizWheel, MediaKbd+Play, etc.) was scraped from my
    reaper keybinding file, so it almost certainly contains errors/omissions.
]]

local takenShortcuts = {}

local _, _, section_id = reaper.get_action_context()
local section = reaper.SectionFromUniqueID(section_id)

for i = 0, math.huge do
  local cmd, _ = reaper.kbd_enumerateActions(section, i)
  if cmd == 0 then break end
  local count = reaper.CountActionShortcuts(section, cmd)
  for n = 0, count - 1 do
    local _, shortcut = reaper.GetActionShortcutDesc(section, cmd, n, "")
    -- Guard against nil/empty returns
    if shortcut and shortcut ~= "" then
      takenShortcuts[shortcut] = true
    end
  end
end

local keys = {
  "A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P","Q","R","S","T","U","V","W","X","Y","Z",
  "0","1","2","3","4","5","6","7","8","9",
  "F1","F2","F3","F4","F5","F6","F7","F8","F9","F10","F11","F12",
  "`","-","=","[","]","\\",";","'",",",".","/","~","!","@","#","$","%","^","&","*","(",")","_","+","{","}","|",":","'","<",">","?",
  "Tab","Space","Backspace","Enter","Esc",
  "Up","Down","Left","Right",
  "Mousewheel","HorizWheel",
  "Num *","Num +","Num -","Num /","Num 0","Num 1","Num 2","Num 3","Num 4","Num 5","Num 6","Num 7","Num 8","Num 9","Num Del",
  "MediaKbd+Chan-","MediaKbd+FF","MediaKbd+Mail","MediaKbd+Mic+","MediaKbd+Mic-","MediaKbd+MicMute","MediaKbd+MicOnOff","MediaKbd+Mute",
  "MediaKbd+Pause","MediaKbd+Play","MediaKbd+PlayPause","MediaKbd+Rew","MediaKbd+Stop","MediaKbd+Track+","MediaKbd+Track-","MediaKbd+Vol+","MediaKbd+Vol-"
}

local modifiers = {
  "",
  "Shift+","Ctrl+","Alt+",
  "Shift+Ctrl+","Shift+Alt+","Ctrl+Alt+","Shift+Ctrl+Alt+",
  -- "Win+","Alt+Win+","Shift+Win+","Ctrl+Win+","Shift+Ctrl+Win+","Shift+Alt+Win+","Ctrl+Alt+Win+","Shift+Ctrl+Alt+Win+"
}

local combinations = {}
for _, mod in ipairs(modifiers) do
  for _, key in ipairs(keys) do
    local shortcut = mod .. key
    if not takenShortcuts[shortcut] then
      combinations[#combinations + 1] = shortcut
    end
  end
end

table.sort(combinations)
reaper.ClearConsole()
reaper.ShowConsoleMsg(#combinations .. " available shortcuts\n")
reaper.ShowConsoleMsg(table.concat(combinations, "\n"))
