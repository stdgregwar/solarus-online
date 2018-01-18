local network = require'scripts/networking/networking'

local stateful = {}

local smeta

--------------------------------------------------------------------------
-- stateful trait add support for a network-shared state to be maintained
-- across the clients, with callback and state change handlers, this form
-- the base of network synchronisation
--------------------------------------------------------------------------

function stateful.setup_meta(meta)
  meta.net_enabled = true
  -- retrieve current state
  function meta:declare_to_network()
    local id = network.set_net_id(self)
    local function setup_state(state)
      self:setup_net_state(state)
      network.register_state(self)
      safe(self.on_restore_from_state)(self,self.state)
    end
    network.get_mob_state(id,setup_state)
  end

  -- make an automatically sended table with a table proxy
  function meta:setup_net_state(state,prefix,modified_handler)
    local function state_change_handle(k,v,old)
      local handlers = self.__state_handlers or {}
      safe(handlers[k])(v,old)
    end
    local modified_handler = modified_handler or state_change_handle
    local prefix = prefix or 'mob'
    local state = state or {}
    local net_meta = {}
    local net_id = self.net_id
    local pname = prefix..'_state'
    local idname = prefix..'_id'
    --when the state is modified it is set over the network
    function net_meta.__newindex(t,k,v)
      local old = t.__state[k]
      t.__state[k] = v
      network.send_state({type=pname,[idname]=net_id,state=t.__state},net_id)
      modified_handler(k,v,old)
    end
    function net_meta.__index(t,k)
      return t.__state[k]
    end
    function net_meta:pairs()
      return pairs(self.__state)
    end
    if not getmetatable(self.state) then --if table is not already netstate
      state = merge_into_table(state,self.state or {})
    end
    self.state = setmetatable({__state=state},net_meta)
  end

  function meta:setup_simple_state(state)
    local simple_meta = {}
    function simple_meta.__newindex(t,k,v)
      print('attempt to modify read only state! ignoring...')
    end
    function simple_meta.__index(t,k)
      return t.__state[k]
    end
    self.state = setmetatable({__state=state},{pairs = function(t) return pairs(t) end})
  end

  local function state_diff(current,new)
    local current = rawget(current,'__state') or current
    return table_diff(current,new);
  end

  -------------------------------------------------------
  -- used internally to notify the state has changed
  -------------------------------------------------------
  function meta:update_state(state)
    --TODO take differential states in account
    local old_state = self.state
    local diff = state_diff(old_state,state)
    --set the new state in state proxy
    rawset(self.state,'__state',state)
    --call state change handlers
    local handlers = self.__state_handlers or {}
    for k,v in pairs(diff.new) do
      safe(handlers[k])(v)
    end
    for k,v in pairs(diff.modified) do
      safe(handlers[k])(v,old_state[k])
    end
    for k,v in pairs(diff.removed) do
      safe(handlers[k])(nil,v)
    end
    safe(self.on_state_changed)(self,self.state,diff)
  end

  ----------------------------------------------------
  -- set a handler for a value change of a particular
  -- state key
  -- function handler(new_val,[old_val])
  -- please note new val could be nil if key was removed
  ----------------------------------------------------
  function meta:set_state_val_change_handler(key,handler)
    self.__state_handlers = self.__state_handlers or {}
    self.__state_handlers[key] = handler
  end

  return meta
end

function stateful.get_meta()
  smeta = smeta or stateful.setup_meta({})
  return smeta
end

return stateful
