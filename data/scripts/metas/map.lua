require("scripts/libs/utils")
require("scripts/libs/iter")

local stateful = require'scripts/metas/stateful'
local actions = require'scripts/metas/actions'
local network = require'scripts/networking/networking'

local map_meta = sol.main.get_metatable("map")

stateful.setup_meta(map_meta)
actions.setup_meta(map_meta)

-------------------------------------------------------------
-- when map is fully loaded, go trough all enemies and
-- declare them to server
-------------------------------------------------------------
function map_meta:init_net_enabled_entities()
  for ent in self:get_net_enabled_entities() do
    ent:declare_to_network()
  end
end

-- is the given entity a hero?
local function is_hero(e)
  return (e:get_type() == "custom_entity" and e:get_model() == "alter_hero")
    or e:get_type() == "hero"
end

-----------------------------------------------------------------------
-- Returns an iterator to all heroes on map, including the onlines ones
-----------------------------------------------------------------------
function map_meta:get_heroes()
  return iter(self:get_entities_by_type("custom_entity")):filter(
                        function(e) return e:get_model() == "alter_hero" end
         ):chain(array{self:get_hero()})
end

function map_meta:get_net_enabled_entities()
  return iter(self:get_entities()):filter(function(e) return e.net_enabled end)
end

--------------------------------------------------------------
-- get the nearest hero, you should replace every get_hero()
-- call with this or make your own hero choose mechanic
--------------------------------------------------------------
function map_meta:get_nearest_hero(target)
  local dist = nil;
  local nearest = nil;
  for h in self:get_heroes() do
    local nd = h:get_distance(target)
    if nd < (dist or nd+1) then
      dist = nd;
      nearest = h;
    end
  end
  return nearest
end

----------------------------------------------------
-- get an iterator to all heroes in given rectangle
----------------------------------------------------
function map_meta:get_heroes_in_rectangle(x,y,w,h)
  return iter(self:get_entities_in_rectangle(x,y,w,h))
          :filter(is_hero)
end

---------------------------------------------------
-- called when client is choosed to be map master
---------------------------------------------------
function map_meta:on_master_prom(op_state)
  self.master = true
  self.state = self.state or {}

  self:setup_net_state(op_state,'map')
  actions.make_net_action(self,network,'map_action');

  safe(self.on_restore_from_state)(self,self.state)
  safe(self.on_master_setup)(self)
end

---------------------------------------------------
-- called when client is only map slave
---------------------------------------------------
function map_meta:on_slave_prom(op_state)
  self:setup_simple_state(op_state)
  safe(self.on_restore_from_state)(self,self.state)
end

---------------------------------------------------
-- enable / disable entities based on the given
-- table, by default nil = false but a conversion
-- can be passed as second argument
-- table is of the form :
-- {entity_name='key_in_map_state',...}
---------------------------------------------------
function map_meta:enable_from_state(tb,predicate)
  local predicate = predicate or function(v) return v and true or false end
  for k,v in pairs(tb) do
    local ent = self:get_entity(k);
    local state_v = self.state[v]
    if ent then
      ent:set_enabled(predicate(state_v))
    end
  end
end



