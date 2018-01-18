-- Lua script of custom entity alter_hero.
-- This script is executed every time a custom entity with this model is created.

-- Feel free to modify the code below.
-- You can add more events and remove the ones you don't need.

-- See the Solarus Lua API documentation for the full specification
-- of types, events and methods:
-- http://www.solarus-games.org/doc/latest

local entity = ...

local mob = require'scripts/metas/mob'
local actions = require'scripts/metas/actions'
local mutils = require'scripts/networking/mob_utils'

local game = entity:get_game()
local map = entity:get_map()
local tunic = entity:create_sprite("hero/tunic1","tunic")
local sword = sol.sprite.create("hero/sword1")
-- Event called when the custom entity is initialized.
function entity:on_created()

  -- Initialize the properties of your custom entity here,
  -- like the sprite, the size, and whether it can traverse other
  -- entities and be traversed by them.r
  self:set_drawn_in_y_order(true)
  self:set_traversable_by(false)
  self:set_traversable_by('hero',true)
  self.mov = sol.movement.create("straight")
  self.mov:start(self)
  self.mov:set_smooth(true)
  --name_displayer:add_named_entity(self)
  --self.mov:set_speed(self.speed)
end

entity.movement_from_net = mutils.movement_from_net

actions.setup_meta(entity)

function entity:draw_sword(surf)
  local x,y = self:get_position()
  map:draw_visual(sword,x,y)
end

function entity:trigger_sword_anim(anim_name)
  local mov = self:get_movement()
  if mov then mov:stop() end
  self.on_post_draw = self.draw_sword
  sword:set_animation(anim_name,function()
                        self.on_post_draw = nil
  end)
  tunic:set_animation(anim_name,function()
                        tunic:set_animation('stopped')
  end)
end

function entity:action_sword_swing()
  print("called")
  self:trigger_sword_anim("sword")
end

function entity:set_animation(anim)
  tunic:set_animation(anim)
  if anim == "stopped" then
    self.mov:set_speed(0)
  elseif anim == "walking" then
    self.mov:set_speed(self.speed or 5)
  end
end

function entity:set_displayed_name(name)
  self.displayed_name = name
  name_displayer:add_named_entity(self)
end

entity.old_set_dir = entity.set_direction

function entity:set_direction(dir)
  self:old_set_dir(dir)
  self.mov:set_angle(dir*math.pi/2)
end

entity.old_set_pos = entity.set_position

function entity:set_position(x,y,layer)
  entity:old_set_pos(x,y,layer)
  self.mov:set_xy(x,y)
end

function entity:on_movement_changed(mov)
  local old_dir = tunic:get_direction()

  local anim = mov:get_speed() > 0 and 'walking' or 'stopped'
  if(tunic:get_animation() ~= anim) then
    tunic:set_animation(anim)
    --print("setting anim to " ..  anim .. " while speed = " .. mov:get_speed()) 
  end
  local dir = mov:get_speed() > 0 and mov:get_direction4() or old_dir;
  tunic:set_direction(dir)
  sword:set_direction(dir)
end

function entity:on_removed()
  name_displayer:remove_named_entity(self)
end
