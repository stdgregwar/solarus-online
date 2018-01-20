local network = require('scripts/networking/networking')

local net_stats = {text=sol.text_surface.create({
                       color = {255,230,20},
                       font = "arial",
                       font_size = 9,
                       text = ""
                  })}

local x,y = 10,10
function net_stats:on_draw(dst_surf)
  local text = "Net KB/s up " .. network.stats.kbs_up .. " | KB/s down " .. network.stats.kbs_down
  self.text:set_text(text)
  self.text:draw(dst_surf,x,y)
end

function net_stats:set_dst_position(ax,ay)
  x,y = ax,ay
end

function net_stats:get_surface()
  return self.text;
end

function net_stats:new(game,config)
  x = config.x
  y = config.y
  return self
end

return net_stats
