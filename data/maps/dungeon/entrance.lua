-- Lua script of map dungeon/entrance.
-- This script is executed every time the hero enters this map.

-- Feel free to modify the code below.
-- You can add more events and remove the ones you don't need.

-- See the Solarus Lua API documentation:
-- http://www.solarus-games.org/doc/latest
local network = require'scripts/networking/networking'

local map = ...
local game = map:get_game()

-- Event called at initialization time, as soon as this map is loaded.
function map:on_started()

  -- You can initialize the movement and sprites of various
  -- map entities here.
end

local door_prefix = 'door'

map:watch_state_vals(
    'switch_1', 'switch_2',
    function(sw1,sw2)
      if sw1 and sw2 then
        map.state.door_open = true
      end
end)

function map:reset()
  map.state.switch_1 = nil
  map.state.switch_2 = nil
  map.state.door_open = nil
end

map:state_to_door('door_open','door')

function map:on_restore_from_state(state)
  for sw in map:get_entities('switch') do
    map:switch_to_state(sw)
  end

  local reset
  function sensor_reset:on_activated()
    if not reset then
      reset = true
      map:reset()
    end
  end
  --strange work around
  function sensor_return:on_activated()
    local x,y = map:get_hero():get_position()
    map:get_hero():set_position(0,0,0)
    map:get_hero():teleport('castle','from_dungeon')
  end
end
