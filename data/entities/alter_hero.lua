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
local stateful = require'scripts/metas/stateful'
local network = require'scripts/networking/networking'

local game = entity:get_game()
local map = entity:get_map()
local tunic = entity:create_sprite("hero/tunic1","tunic")
local sword = sol.sprite.create("hero/sword1")
local stars = sol.sprite.create('hero/sword_stars1')
-- Event called when the custom entity is initialized.

local can_traverse = {
  'traversable',
  'shallow_water',
  'grass',
  'hole',
  'ice',
  'lava',
  'ladder'
}

function entity:on_created()
  -- Initialize the properties of your custom entity here,
  -- like the sprite, the size, and whether it can traverse other
  -- entities and be traversed by them.r
  self:set_drawn_in_y_order(true)
  self:set_traversable_by(false)
  self:set_traversable_by('hero',true)
  for _,g in ipairs(can_traverse) do
    self:set_can_traverse(g,true)
  end
end

entity.movement_from_net = mutils.movement_from_net

actions.setup_meta(entity)
stateful.setup_meta(entity)

entity:watch_state_val(
  'state',
  function(state)
    entity:update_animation()
    stars:set_animation('loading')
  end
)

entity:watch_state_val(
  'dir',
  function(dir)
    if type(dir) == 'number' then
      sword:set_direction(dir)
      tunic:set_direction(dir)
      stars:set_direction(dir)
    end
  end
)

function entity:on_post_draw(srf)
  local state = self.state and self.state.state or 'free'
  if state:find('sword') then
    self:draw_sword(srf)
  end
  if state == 'sword loading' then
    self:draw_stars(srf)
  end
end

function entity:declare_to_network()
  local id = network.set_net_id(self)
  self:setup_simple_state({})
  local function setup_state(state)
    self:setup_simple_state(state)
  end
  network.get_state(id,'hero',setup_state)
end

function entity:draw_sword(surf)
  local x,y = self:get_position()
  map:draw_visual(sword,x,y)
end

function entity:draw_stars(surf)
  local x,y = self:get_position()
  map:draw_visual(stars,x,y)
end

function entity:trigger_sword_anim(anim_name)
  local mov = self:get_movement()
  if mov then mov:stop() end
  sword:set_animation(anim_name)
  tunic:set_animation(anim_name,function()
                        tunic:set_animation('stopped')
  end)
end

function entity:action_sword_swing()
  self:trigger_sword_anim("sword")
end

function entity:action_spin_attack()
  self:trigger_sword_anim("spin_attack")
end

function entity:set_displayed_name(name)
  self.displayed_name = name
  name_displayer:add_named_entity(self)
end

local state_to_walk_anim = {
  ['sword loading'] = 'sword_loading_walking',
  ['sword tapping'] = 'sword_tapping',
  ['pushing'] = 'pushing',
  jumping = 'jumping',
  carrying = 'carrying_walking',
  hurt = 'hurt'
}

local state_to_stopped_anim = {
  ['sword swinging'] = 'none',
  ['sword spin attack'] = 'none',
  ['sword loading'] = 'sword_loading_stopped',
  ['sword_tapping'] = 'sword_tapping',
  pulling = 'pulling',
  jumping = 'jumping',
  carrying = 'carrying_stopped',
  hurt = 'hurt',
}

function entity:update_animation(mov)
  local mov = mov or entity:get_movement()
  local state = self.state.state
  local walk_anim = state_to_walk_anim[state] or 'walking'
  local stop_anim = state_to_stopped_anim[state] or 'stopped'
  local anim = (mov and mov:get_speed() > 0) and walk_anim or stop_anim
  if(tunic:get_animation() ~= anim) then
    if tunic:has_animation(anim) then
      tunic:set_animation(anim)
    end
    if sword:has_animation(anim) then
      sword:set_animation(anim)
    end
  end
end

function entity:on_movement_changed(mov)
  self:update_animation(mov)
end

function entity:on_removed()
  name_displayer:remove_named_entity(self)
end
