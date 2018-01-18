-- hero movement and action replication primitives


local hero_utils = {}

----------------------------------------------------
-- capture the game commands to deduce hero actions
----------------------------------------------------
function hero_utils.setup_hero_repl_callback(game,hero,network)

  --make a dummy action dispatcher for the hero
  function hero:action_dispatcher()
    -- TODO : find a more elegant way
  end

  local sword_a_states = {free=true,['sword swinging']=true}
  local function on_command_pressed(game,command)
    -- TODO capture other sword events
    local hstate = hero:get_state()
    if command == 'attack' and sword_a_states[hstate] then
      hero:action('sword_swing')
    end
    return false -- by default command isn't handled
  end
  game:register_event('on_command_pressed',on_command_pressed)

  local function on_command_released(game,command)

  end
  game:register_event('on_command_released',on_command_released)
end

return hero_utils
