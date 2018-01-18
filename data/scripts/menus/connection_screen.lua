local network = require("scripts/networking/networking")

local font,size = sol.language.get_menu_font()
connection_screen = {
  text = sol.text_surface.create({
    color = {255,230,20},
    font = font,
    font_size = size+2,
    text = "Initializing connection..."
  })
}

local function progress(msg,percentage)
  connection_screen.text:set_text(msg .. " (" .. percentage .. ")")
end

local function connected()
  sol.menu.stop(connection_screen)
end

function connection_screen:on_started()
end

function connection_screen:connect(host,port,game)
  network.connect(host,port,game,connected,progress)
end

function connection_screen:on_draw(srf)
  local w,h = srf:get_size()
  w = w/ 2 - 100
  h = h / 2
  self.text:draw(srf,w,h)
end

return connection_screen
