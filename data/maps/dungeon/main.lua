-- Lua script of map dungeon/main.
-- This script is executed every time the hero enters this map.

-- Feel free to modify the code below.
-- You can add more events and remove the ones you don't need.

-- See the Solarus Lua API documentation:
-- http://www.solarus-games.org/doc/latest

local map = ...
local game = map:get_game()

function map:reset()
  self.state.tmp_door_right = nil
  self.state.door_right = nil
  self.state.door_left = nil
  self.state.door_key = nil
  self.state.crystals = nil
  self.state.got_key = nil
  self.state.crystals = nil
  self.state.top_door = nil
end

map:watch_state_vals(
  'tmp_door_right','door_right',
  function(tmp_dr,dr)
    map:open_close_doors('door_right',tmp_dr or dr)
    if dr then
      sol.audio.play_sound('secret')
    end
  end
)

map:state_to_door('door_key','door_key')

map:watch_state_val(
  'crystals',
  function(v)
    local bool = v and true or false
    map:set_crystal_state(bool)
    for csw in map:get_entities('switch_crystal') do
      csw:set_activated(v,true) --silently update other crystals
    end
  end
)

map:state_to_door('top_door','door_top');

map:watch_state_vals(
  'top_door1','top_door2',
  function(tpd1,tpd2)
    if tpd1 and tpd2 then
      map.state.top_door = true
    end
  end
)

map:open_doors('start_door')

function map:on_restore_from_state(state)
  self:switch_to_state(switch_tmp,'tmp_door_right')
  self:switch_to_door(switch_1_right,'door_left')
  self:switch_to_state(switch_1_left,'door_right')
  self:switch_to_door(switch_middle_door_left,'door_middle_left')
  self:switch_to_door(switch_middle_door_right,'door_middle_right')
  self:switch_to_state(switch_top_door_1,'top_door1')
  self:switch_to_state(switch_top_door_2,'top_door2')

  local reset
  function sensor_reset:on_activated()
    if not reset then
      map:reset()
      map:close_doors('start_door')
      reset = true
    end
  end

  function door_key:on_opened()
    map.state.door_key = true
  end

  --setup crystal switches
  for csw in map:get_entities('switch_crystal') do
    function csw:on_changed(val)
      map.state.crystals = val
    end
  end
end
