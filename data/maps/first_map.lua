-- Lua script of map first_map.
-- This script is executed every time the hero enters this map.

-- Feel free to modify the code below.
-- You can add more events and remove the ones you don't need.


local map = ...
local game = map:get_game()
local hero = map:get_hero()
local random = math.random
-- Event called at initialization time, as soon as this map becomes is loaded.
function map:on_started()
  map.net_id = map:get_id()
  -- You can initialize the movement and sprites of various
  -- map entities here.
  chest:set_enabled(false)
end

function map:on_restore_from_state(state)
  map:enable_from_state{
    chest='test_chest'
  }
end

map:set_state_val_change_handler('test_chest',function(val,old)
  chest:set_enabled(val and true or false)
  if val and not old then sol.audio.play_sound('secret') end
end)

function map:on_master_setup()
  --Do wathever you want here
  function switch:on_activated()
    map.state.test_chest = true
  end
  function switch:on_inactivated()
    map.state.test_chest = nil
  end
end

