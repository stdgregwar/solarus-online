-- Lua script of custom entity toggle_switch.
-- This script is executed every time a custom entity with this model is created.

-- Feel free to modify the code below.
-- You can add more events and remove the ones you don't need.

-- See the Solarus Lua API documentation for the full specification
-- of types, events and methods:
-- http://www.solarus-games.org/doc/latest

local entity = ...
local game = entity:get_game()
local map = entity:get_map()
local hero = map:get_hero()
local sprite = entity:get_sprite()
local sword = hero:get_sprite('sword')
-- Event called when the custom entity is initialized.
local activated = false

function entity:on_created()
  entity:set_traversable_by(false)
  entity:set_activated(activated)
end

function entity:set_activated(b,silent)
  activated = b
  local anim = activated and 'activated' or 'inactivated'
  if sprite:has_animation(anim) then
    sprite:set_animation(anim)
  end
  if not silent then
    safe(self.on_changed)(self,activated)
  end
end

function entity:toggle()
  entity:set_activated(not activated)
end

local cool_down

entity:add_collision_test(
  'sprite',
  function(self,ent,_,o_sprite)
    if o_sprite == sword and not cool_down then
      self:toggle()
      sol.audio.play_sound('switch')
      cool_down = true
      sol.timer.start(300,function() cool_down = false end)
    end
end)
