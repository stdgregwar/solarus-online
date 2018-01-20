local network = require'scripts/networking/networking'
local json = require'json'

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
  function meta:declare_to_network(prefix)
    local id = network.set_net_id(self)
    local function setup_state(state)
      network.register_state(self)
      self:init_state(state,prefix)
    end
    network.get_state(id,prefix,setup_state)
  end

  function meta:update_diff(k,v,old)
    self.__diff = self.__diff or {new={},mod={},rem={}}
    local diff = self.__diff
    if v and old and v ~= old then
      diff.mod[k] = v
    end
    if v and not old then
      diff.new[k] = v
    end
    if not v and old then
      diff.rem[k] = old
    end
  end

  function meta:should_send_diff()
    if not self.__diff then
      return false
    end
    local d = self.__diff
    local s = rawget(self.state,'__state')
    local diff_size = #d.new+#d.rem+#d.mod+3
    local state_size = #s
    return (diff_size < state_size or self.state_is_shared)
      and not self.send_full_state
  end


  function meta:init_state(state,prefix)
    self:setup_net_state(state,prefix)
    safe(self.on_restore_from_state)(self,self.state)
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
      --network.send_state({type=pname,[idname]=net_id,state=t.__state},net_id)
      network.register_sendable_state(self)
      self:update_diff(k,v,old)
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

    --update send method :
    function self:send()
      local packet = {type=pname,[idname]=net_id}
      if self:should_send_diff() then
        packet.diff = self.__diff
      else
        packet.state = rawget(self.state,'__state')
      end
      network.send(packet)
      self.__diff = nil
    end
  end

  function meta:setup_simple_state(state)
    local simple_meta = {}
    function simple_meta.__newindex(t,k,v)
      print('attempt to modify read only state! ignoring...')
    end
    function simple_meta.__index(t,k)
      return t.__state[k]
    end
    function simple_meta:pairs()
      return pairs(self.__state)
    end
    self.state = setmetatable({__state=state},simple_meta)
  end

  function meta:update_from_diff(diff)
    local s = rawget(self.state,'__state')
    for k,v in pairs(diff.new) do
      s[k] = v
    end
    for k,v in pairs(diff.mod) do
      s[k] = v
    end
    for k,v in pairs(diff.rem) do
      s[k] = nil
    end
  end

  -------------------------------------------------------
  -- used internally to notify the state has changed
  -------------------------------------------------------
  function meta:update_state(state)
    --TODO take differential states in account
    local old_state = self.state and rawget(self.state,'__state') or {}
    local diff = state.diff or table_diff(old_state,state.state)
    --set the new state in state proxy
    if state.diff then
      self:update_from_diff(state.diff)
    else
      rawset(self.state,'__state',state.state)
    end
    --call state change handlers
    local handlers = self.__state_handlers or {}
    for k,v in pairs(diff.new) do
      safe(handlers[k])(v)
    end
    for k,v in pairs(diff.mod) do
      safe(handlers[k])(v,old_state[k])
    end
    for k,v in pairs(diff.rem) do
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
  function meta:watch_state_val(key,handler,overwrite)
    self.__state_handlers = self.__state_handlers or {}
    if overwrite then
      self.__state_handler[key] = handler
    else
      local previous_handler = self.__state_handlers[key] or function() end
      self.__state_handlers[key] = function(...)
        return previous_handler(...) or handler(...)
      end
    end
  end

  -----------------------------------------------------
  -- watch for a bunch of state values to change
  -- watch_vals(k1,k2,...,kn,handler)
  -- handler(v1,v2,...,vn)
  -----------------------------------------------------
  function meta:watch_state_vals(...)
    local arg = table.pack(...)
    local handler
    local function call_handler(rk,v,old)
      local pack = {}
      for i,k in ipairs(arg) do
        pack[i] = self.state[k]
      end
      pack.n = arg.n
      handler(unpack(pack))
    end
    for _,k in ipairs(arg) do
      handler = k --to get last arg as handler
      if type(k) ~= 'function' then
        self:watch_state_val(k,call_handler)
      end
    end
    assert(type(handler) == 'function','values handler must be a function')
  end

  return meta
end

function stateful.get_meta()
  smeta = smeta or stateful.setup_meta({})
  return smeta
end

return stateful
