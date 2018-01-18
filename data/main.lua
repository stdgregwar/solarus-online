-- This is the main Lua script of your project.
-- You will probably make a title screen and then start a game.
-- See the Lua API! http://www.solarus-games.org/doc/latest

require("scripts/multi_events")
require("scripts/hud")
local network = require("scripts/networking/networking")

--small luafun test TODO remove
require("scripts/libs/iter")


--Enemy metatable setup
require("scripts/metas/enemy")
--Map metatable setup
require("scripts/metas/map")
--Movements metatable setup
require("scripts/metas/movements")
require("scripts/metas/destructible")
require('scripts/metas/npc')

-- This function is called when Solarus starts.
function sol.main:on_started()

  -- Setting a language is useful to display text and dialogs.
  -- sol.language.set_language("en")

  local solarus_logo = require("scripts/menus/solarus_logo")
  sol.language.set_language("fr")
  -- Show the Solarus logo initially.
  sol.menu.start(self, solarus_logo)

  local server_menu = require("scripts/menus/servers")
  
  --connection menu
  solarus_logo.on_finished = function()
    --sol.menu.start(self, co_screen)
    sol.menu.start(self, server_menu)
  end  

 
  -- Start the game when the Solarus logo menu is finished.
  
end

function sol.main:start_game(game,server)
  local co_screen = require("scripts/menus/connection_screen")
  sol.menu.start(self,co_screen)
  co_screen:connect(server.host,server.port,game)
   --init game and network reflexion
  co_screen.on_finished = function()
    require('scripts/menus/dialog_box')(game)
    game:initialize_dialog_box()
    game:start()
    network.on_game_started(game)
  end
end

-- Event called when the player pressed a keyboard key.
function sol.main:on_key_pressed(key, modifiers)

  local handled = false
  if key == "f5" then
    -- F5: change the video mode.
    sol.video.switch_mode()
    handled = true
  elseif key == "f11" or
    (key == "return" and (modifiers.alt or modifiers.control)) then
    -- F11 or Ctrl + return or Alt + Return: switch fullscreen.
    sol.video.set_fullscreen(not sol.video.is_fullscreen())
    handled = true
  elseif key == "f4" and modifiers.alt then
    -- Alt + F4: stop the program.
    sol.main.exit()
    handled = true
  elseif key == "escape" and sol.main.game == nil then
    -- Escape in title screens: stop the program.
    sol.main.exit()
    handled = true
  end

  return handled
end

-- Returns the font and size to be used for dialogs
-- depending on the specified language (the current one by default).
function sol.language.get_dialog_font(language)

  language = language or sol.language.get_language()

  local font
  if language == "zh_TW" or language == "zh_CN" then
    -- Chinese font.
    font = "wqy-zenhei"
    size = 12
  else
    font = "la"
    size = 11
  end

  return font, size
end

-- Returns the font and font size to be used to display text in menus
-- depending on the specified language (the current one by default).
function sol.language.get_menu_font(language)

  language = language or sol.language.get_language()

  local font, size
  if language == "zh_TW" or language == "zh_CN" then
    -- Chinese font.
    font = "wqy-zenhei"
    size = 12
  else
    font = "minecraftia"
    size = 8
  end

  return font, size
end
