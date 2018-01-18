-- Lua script of enemy tentacle.
-- This script is executed every time an enemy with this model is created.

-- Feel free to modify the code below.
-- You can add more events and remove the ones you don't need.

-- See the Solarus Lua API documentation for the full specification
-- of types, events and methods:
-- http://www.solarus-games.org/doc/latest

local enemy = ...
local map = enemy:get_map()
-- Tentacle: a basic enemy that follows the hero.

function enemy:on_mob_created()
  self.max_life = 1
  print("mob created")
  self:set_damage(2)
  self:create_sprite("enemies/tentacle")
  self:set_size(16, 16)
  self:set_origin(8, 13)
end

function enemy:look_for_hero()
  local m = sol.movement.create("path_finding")
  local hero = map:get_nearest_hero(self)
  m:set_target(hero)
  m:set_speed(32)
  m:start(self)
end

function enemy:on_mob_restarted()
  self:look_for_hero()
  sol.timer.start(self,1000,function() self:look_for_hero(); return true end)
end
