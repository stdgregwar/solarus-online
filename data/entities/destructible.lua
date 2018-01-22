-- Lua script of custom entity destructible.
-- This script is executed every time a custom entity with this model is created.

-- Feel free to modify the code below.
-- You can add more events and remove the ones you don't need.

-- See the Solarus Lua API documentation for the full specification
-- of types, events and methods:
-- http://www.solarus-games.org/doc/latest
local stateful = require'scripts/metas/stateful'
local network = require'scripts/networking/networking'

local entity = ...
local game = entity:get_game()
local map = entity:get_map()
local hero = map:get_hero()
local sprite = entity:get_sprite()

-- add stateful trait
stateful.setup_meta(entity)

--determine the properties based on the sprite name...
-- will do better when entity properties will be available
local destruction_sound = {
  bush = 'bush',
  grass = 'bush',
  stone_withe = 'stone',
  stone_black = 'stone'
}

local default_sound = 'bush'

local can_be_cut = {
  bush = true,
  grass = true
}

local can_explode = {}

local damage_on_ennemies = {
  bush = 0
}

local weight = {
  grass = -1,
  stone_withe = 1,
  stone_black = 2
}

local ground = {
  grass = 'grass'
}

local respawn_time = 20

local function name_trans(name)
  if name:find('bush') then
    return 'bush'
  end
  return name
end

function entity:disapear(cause)
  entity.state.absent = true
  entity.state.disapear_time = network.server_time_s()
  entity.state.disapear_cause = cause
end

function entity:make_real()
  local anim = sprite:get_animation_set()
  local name = name_trans(anim:sub(10,-1)) -- remove the 'entities/'
  local x,y,l = self:get_position()
  local real = map:create_destructible{
    layer=l,
    x=x,y=y,
    sprite = anim,
    destruction_sound = destruction_sound[name] or default_sound,
    can_be_cut = can_be_cut[name],
    can_explode = can_explode[name],
    damage_on_ennemies = damage_on_ennemies[name],
    ground = ground[name]
  }
  real:get_sprite():fade_in(5)
  self.real = real
  --setup callback to propagate state
  function real:on_cut()
    entity:disapear('destroyed')
  end
  function real:on_lifting()
    entity:disapear('lifted')
    hero:on_lifting(real)
  end
  function real:on_exploded()
    entity:disapear('exploded')
  end
end

function entity:should_respawn()
  return network.server_time_s() - (entity.state.disapear_time or 0) > respawn_time
end


function entity:on_restore_from_state(state)
  if state.absent and self:should_respawn() then
    state.absent = nil
  elseif not state.absent then
    entity:make_real()
  end
end

function entity:play_destroy_anim()
  self:set_visible(true)
  sol.audio.play_sound(self.real:get_destruction_sound())
  sprite:set_animation('destroy',function() self:set_visible(false) end)
end

entity:watch_state_val(
  'absent',
  function(absent)
    if absent and not entity.real:destroyed() then
      entity.real:remove()
      if entity.state.disapear_cause == 'destroyed' or
         entity.state.disapear_cause == 'exploded' then
        entity:play_destroy_anim()
      end
    end
    if not absent then
      entity:make_real()
    end
end)

-- Event called when the custom entity is initialized.
function entity:on_created()
  self:set_visible(false)
  self:set_modified_ground('empty')
  self:set_traversable_by(true)
end
