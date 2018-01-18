local network = require("scripts/networking/networking")

-- Script responsible of the drawing of the HUD of the game

-- This early version only draws names of the players on top of their heads

--global name displayer
name_displayer = {
   named_entities = {}
}

function name_displayer:add_named_entity(entity)
  print("Add name " .. entity.displayed_name)
  local text = sol.text_surface.create({
    color = {255,230,20},
    font = "arial",
    font_size = 9,
    text = entity.displayed_name
  })

  local ew,eh = entity:get_size()
  local tw,th = text:get_size()
  local offset = {x = -tw/2,y = -eh - 5 - th}
  
  entity.top_text = text
  entity.top_text_offset = offset
  self.named_entities[entity] = entity
end

function name_displayer:remove_named_entity(entity)
  entity.top_text = nil
  self.named_entities[entity] = nil
end

function name_displayer:on_draw(dst_surf)
  for _,ent in pairs(self.named_entities) do
    local off = ent.top_text_offset
    local x,y = ent:get_position()
    local cx,cy = ent:get_map():get_camera():get_position()
    x,y = x+off.x-cx, y+off.y-cy
    ent.top_text:draw(dst_surf,x,y)
  end
end

local net_stats = {text=sol.text_surface.create({
    color = {255,230,20},
    font = "arial",
    font_size = 9,
    text = ""
  })}

function net_stats:on_draw(dst_surf)
  local text = "Net KB/s up " .. network.stats.kbs_up .. " | KB/s down " .. network.stats.kbs_down
  self.text:set_text(text)
  self.text:draw(dst_surf,10,10)
end

local function initialize_hud_features(game)
  function game:on_draw(dst_surf)
    name_displayer:on_draw(dst_surf)
    net_stats:on_draw(dst_surf)
  end
end


local game_meta = sol.main.get_metatable("game")
game_meta:register_event("on_started", initialize_hud_features)