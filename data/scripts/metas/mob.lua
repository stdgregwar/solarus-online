local network = require'scripts/networking/networking'
local mutils = require'scripts/networking/mob_utils'
local stateful = require'scripts/metas/stateful'
local actions = require'scripts/metas/actions'

require'scripts/libs/utils'
local mob = {}

----------------------------------------------------
-- method calling the mob action with given name
-- forwarding given parameters
----------------------------------------------------
function mob:action_dispatcher(action_name,...)
  assert(type(action_name)=='string')
  local action = self['action_'..action_name] or function()end
  action(self,...)
end

mob.MAX_LIVE = 9999

----------------------------------------------------
-- setup all mob common meta methods
----------------------------------------------------
function mob.setup_meta(meta)
  --inherit stateful
  stateful.setup_meta(meta)
  actions.setup_meta(meta)

  function meta:on_created()
    self.actions = {}
    --TODO add a metatable to state to synchronise state changes
    self.state = {death_time=-1000}
    safe(self.__set_life)(self,mob.MAX_LIVE) -- makes mob immortal
    safe(self.on_mob_created)(self)
  end



  meta.action_dispatcher = mob.action_dispatcher
  --make default action handling mecanism the action dispatcher
  meta.action = mob.action_dispatcher

  --When map is loaded, mob needs to know if it is simulated locally or remotely
  --So we declare the mob to the server and ask if mob is already simulated somewhere
  function meta:declare_to_network()
    network.has_mob(self)
  end

  --Called when client is selected to simulate the mob
  function meta:on_master_prom(op_state)
    mutils.make_mob_master_basics(self,self.net_id,network)
    self:setup_net_state(op_state or {})
    safe(self.on_mob_master_setup)(self)
  end

  --create mov if the desired type does not match 
  local mov_or_else = mutils.mov_or_else

  --unserialize entity movement
  meta.movement_from_net = mutils.movement_from_net

  --when a master mob is attacked by a remote player
  function meta:remote_attack(attacker,attack,sprite_id)
    -- TODO
    print(string.format('mob %s is attacked by %s',self.net_id,attacker.net_id))
    local attacker = network.get_entity(attacker.net_id)
    local attacked_sprite = self.__sprite_map[sprite_id]
    local mob = self
    local consequences = {
      normal = function(life_points)
        self:take_normal_damage(attacker,attack,life_points)
      end,
      ignored = function()
      end,
      protected = function()
        --TODO play failure sound
      end,
      immobilized = function()
        self:immobilize()
      end,
      custom = function()
        safe(mob.on_mob_custom_attack_received)(mob,attack,attacked_sprite,attacker)
      end
    }
    local conseq = self:get_attack_consequence_sprite(attacked_sprite,attack)
    print('conseq is ' .. conseq)
    if type(conseq) == 'number' then
      consequences.normal(conseq)
    else --type is normally a string
      consequences[conseq]()
    end
  end

  --Set the name that will follow the entity
  function meta:set_displayed_name(name)
    self.displayed_name = name
    --name_displayer:add_named_entity(self)
  end

  --Called when mob needs to be prepared for remote control
  function meta:on_remote_prom()
    --do nothing by default
  end

  --Event concerning enemies
  function meta:on_suspended() -- enemies should never be suspended
    --TODO : decide what to do with these events    
    --safe(self.on_mob_suspended)(self)
  end  

  ----------------------------------------------------
  -- Should only occur when map is leaved or mob was
  -- unpersistent mob
  ----------------------------------------------------
  function meta:on_removed()
    network.has_not_mob(self)
    name_displayer:remove_named_entity(self)
    safe(self.on_mob_removed)(self)
  end
end

return mob
