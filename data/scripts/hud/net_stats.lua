local network = require('scripts/networking/networking')

local font,size = sol.language.get_ui_font()

local net_stats = {text=sol.text_surface.create({
                       color = {255,230,20},
                       font = font,
                       font_size = size,
                       text = ""
}),
                   text2=sol.text_surface.create({
                       color={0,0,0},
                       font = font,
                       font_size = size,
                       text = ""
                   })
                  }

local x,y = 10,10
function net_stats:on_draw(dst_surf)
  local text = "Net KB/s up " .. network.stats.kbs_up .. " | KB/s down " .. network.stats.kbs_down
  self.text2:set_text(text)
  self.text2:draw(dst_surf,x,y+1)
  self.text:set_text(text)
  self.text:draw(dst_surf,x,y)
end

function net_stats:set_dst_position(ax,ay)
  x,y = ax,ay
end

function net_stats:get_surface()
  return {
    set_opacity = function()
    end
  }
end

function net_stats:new(game,config)
  x = config.x
  y = config.y
  return self
end

return net_stats
